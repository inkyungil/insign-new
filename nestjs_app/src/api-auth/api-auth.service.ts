import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { ConfigService } from "@nestjs/config";
import { OAuth2Client } from "google-auth-library";
import * as bcrypt from "bcrypt";
import { UsersService } from "../users/users.service";
import { RegisterDto } from "./dto/register.dto";
import { LoginDto } from "./dto/login.dto";
import { GoogleLoginDto } from "./dto/google-login.dto";
import { AuthResponse } from "./dto/auth-response.dto";
import { User } from "../users/user.entity";
import { DeleteAccountDto } from "./dto/delete-account.dto";
import { ChangePasswordDto } from "./dto/change-password.dto";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Contract } from "../contracts/contract.entity";
import { MailService } from "../mail/mail.service";
import { PointsService } from "../points/points.service";

@Injectable()
export class ApiAuthService {
  private readonly tokenTtlSeconds: number;
  private readonly googleClient: OAuth2Client;
  private readonly googleClientIds: string[];

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly mailService: MailService,
    @InjectRepository(Contract)
    private readonly contractRepository: Repository<Contract>,
    private readonly pointsService: PointsService,
  ) {
    const configuredTtl = Number(
      this.configService.get<string>("JWT_ACCESS_TTL_SECONDS", "3600"),
    );
    this.tokenTtlSeconds = Number.isFinite(configuredTtl) && configuredTtl > 0
      ? Math.floor(configuredTtl)
      : 3600;

    this.googleClientIds = [
      this.configService.get<string>("GOOGLE_WEB_CLIENT_ID"),
      this.configService.get<string>("GOOGLE_EXPO_CLIENT_ID"),
      this.configService.get<string>("GOOGLE_ANDROID_CLIENT_ID"),
      this.configService.get<string>("GOOGLE_IOS_CLIENT_ID"),
    ].filter((value): value is string => Boolean(value));

    this.googleClient = new OAuth2Client(this.googleClientIds[0] ?? undefined);
  }

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const user = await this.usersService.createUser(dto);

    // 이메일 회원가입의 경우 이메일 인증 메일 발송
    const { token } = await this.usersService.setEmailVerificationToken(
      user.id,
    );
    const verificationLink = `${this.configService.get<string>("FRONTEND_URL", "https://dev.in-sign.shop")}/auth/verify-email?token=${token}`;

    await this.mailService.sendEmailVerificationMail({
      to: user.email,
      verificationLink,
    });

    return this.buildAuthResponse(user);
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.usersService.findByEmail(dto.email);
    if (!user) {
      throw new UnauthorizedException(
        "이메일 또는 비밀번호가 올바르지 않습니다.",
      );
    }

    if (user.provider !== "local" || !user.passwordHash) {
      throw new UnauthorizedException(
        "이메일 또는 비밀번호가 올바르지 않습니다.",
      );
    }

    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException(
        "이메일 또는 비밀번호가 올바르지 않습니다.",
      );
    }

    // 이메일 인증 확인
    if (!user.isEmailVerified) {
      throw new UnauthorizedException(
        "이메일 인증이 필요합니다. 가입 시 받은 이메일을 확인해 주세요.",
      );
    }

    const updatedUser = await this.usersService.markLastLogin(user.id);
    return this.buildAuthResponse(updatedUser);
  }

  async logout(): Promise<void> {
    return;
  }

  async loginWithGoogle(dto: GoogleLoginDto): Promise<AuthResponse> {
    if (!this.googleClientIds.length) {
      throw new UnauthorizedException(
        "Google 로그인 설정이 올바르지 않습니다.",
      );
    }

    const ticket = await this.googleClient.verifyIdToken({
      idToken: dto.idToken,
      audience: this.googleClientIds,
    });

    const payload = ticket.getPayload();

    if (!payload?.email || !payload.sub) {
      throw new UnauthorizedException(
        "Google 사용자 정보를 가져오지 못했습니다.",
      );
    }

    const { user, isNewUser } = await this.usersService.upsertGoogleUser({
      email: payload.email,
      googleId: payload.sub,
      displayName: payload.name ?? null,
      avatarUrl: payload.picture ?? null,
    });

    // 신규 사용자이거나 약관 미동의 시
    const needsTermsAgreement = isNewUser || !user.agreedToTerms || !user.agreedToPrivacy || !user.agreedToSensitive;

    if (needsTermsAgreement) {
      // 약관 동의 필요 - 임시 토큰 발급
      const tempPayload = { sub: user.id, email: user.email, temp: true };
      const tempToken = await this.jwtService.signAsync(tempPayload, {
        expiresIn: 3600, // 1시간
      });

      return {
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName ?? null,
          lastLoginAt: user.lastLoginAt ?? null,
          provider: user.provider,
          avatarUrl: user.avatarUrl ?? null,
          agreedToTerms: user.agreedToTerms,
          agreedToPrivacy: user.agreedToPrivacy,
          agreedToSensitive: user.agreedToSensitive,
          agreedToMarketing: user.agreedToMarketing,
        },
        accessToken: tempToken,
        expiresIn: 3600,
        requiresTermsAgreement: true, // 약관 동의 필요 플래그
      } as any;
    }

    // 기존 사용자 + 약관 동의 완료 - 정상 로그인
    const updatedUser = await this.usersService.markLastLogin(user.id);
    return this.buildAuthResponse(updatedUser);
  }

  private async buildAuthResponse(user: User): Promise<AuthResponse> {
    const payload = { sub: user.id, email: user.email };
    const accessToken = await this.jwtService.signAsync(payload, {
      expiresIn: this.tokenTtlSeconds,
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName ?? null,
        lastLoginAt: user.lastLoginAt ?? null,
        provider: user.provider,
        avatarUrl: user.avatarUrl ?? null,
        agreedToTerms: user.agreedToTerms,
        agreedToPrivacy: user.agreedToPrivacy,
        agreedToSensitive: user.agreedToSensitive,
        agreedToMarketing: user.agreedToMarketing,
      },
      accessToken,
      expiresIn: this.tokenTtlSeconds,
    };
  }

  async deleteAccount(userId: number, dto: DeleteAccountDto): Promise<void> {
    const user = await this.usersService.findOneById(userId);

    if (user.provider === "local") {
      if (!dto.password || !dto.password.trim()) {
        throw new BadRequestException("비밀번호를 입력해 주세요.");
      }

      if (!user.passwordHash) {
        throw new BadRequestException("비밀번호를 확인할 수 없습니다.");
      }

      const matches = await bcrypt.compare(dto.password, user.passwordHash);
      if (!matches) {
        throw new UnauthorizedException("비밀번호가 올바르지 않습니다.");
      }
    }

    await this.contractRepository.update(
      { createdByUserId: userId },
      { createdByUserId: null },
    );

    await this.usersService.deleteUserAndLog(user, {
      reason: dto.reason?.trim() || undefined,
    });
  }

  async changePassword(
    userId: number,
    dto: ChangePasswordDto,
  ): Promise<void> {
    const user = await this.usersService.findOneById(userId);

    if (!user.passwordHash) {
      throw new BadRequestException(
        "비밀번호 변경은 이메일로 가입한 계정에서만 가능합니다.",
      );
    }

    const currentPassword = dto.currentPassword.trim();
    const newPassword = dto.newPassword.trim();

    if (currentPassword === newPassword) {
      throw new BadRequestException(
        "새 비밀번호가 현재 비밀번호와 동일합니다.",
      );
    }

    const matches = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!matches) {
      throw new UnauthorizedException("현재 비밀번호가 올바르지 않습니다.");
    }

    await this.usersService.updateUserPassword(userId, newPassword);
  }

  async verifyEmail(token: string): Promise<void> {
    await this.usersService.verifyEmailWithToken(token);
  }

  async resendVerificationEmail(email: string): Promise<void> {
    const user = await this.usersService.findByEmailIncludingInactive(email);

    if (!user) {
      throw new BadRequestException("사용자를 찾을 수 없습니다.");
    }

    if (user.provider !== "local") {
      throw new BadRequestException(
        "소셜 로그인 계정은 이메일 인증이 필요하지 않습니다.",
      );
    }

    if (user.isEmailVerified) {
      throw new BadRequestException("이미 인증된 이메일입니다.");
    }

    // 새로운 인증 토큰 생성
    const { token } = await this.usersService.setEmailVerificationToken(
      user.id,
    );
    const verificationLink = `${this.configService.get<string>("FRONTEND_URL", "https://dev.in-sign.shop")}/auth/verify-email?token=${token}`;

    await this.mailService.sendEmailVerificationMail({
      to: user.email,
      verificationLink,
    });
  }

  async completeRegistration(
    userId: number,
    dto: {
      agreedToTerms: boolean;
      agreedToPrivacy: boolean;
      agreedToSensitive: boolean;
      agreedToMarketing: boolean;
    },
  ): Promise<AuthResponse> {
    const user = await this.usersService.findOneById(userId);

    if (!dto.agreedToTerms || !dto.agreedToPrivacy || !dto.agreedToSensitive) {
      throw new BadRequestException(
        "필수 약관에 동의해야 합니다.",
      );
    }

    // 약관 동의 정보 업데이트
    await this.usersService.updateTermsAgreement(userId, {
      agreedToTerms: dto.agreedToTerms,
      agreedToPrivacy: dto.agreedToPrivacy,
      agreedToSensitive: dto.agreedToSensitive,
      agreedToMarketing: dto.agreedToMarketing,
    });

    // 정식 로그인 처리
    const updatedUser = await this.usersService.markLastLogin(userId);
    return this.buildAuthResponse(updatedUser);
  }

  async getUsageHistory(userId: number, limit: number = 20) {
    const safeLimit = Math.min(Math.max(limit, 1), 100);
    const [contracts, pointLedgers] = await Promise.all([
      this.contractRepository.find({
        where: { createdByUserId: userId },
        order: { createdAt: "DESC" },
        take: safeLimit,
      }),
      this.pointsService.getHistory(userId, safeLimit, 0),
    ]);

    const contractEntries = contracts.map((contract) => ({
      type: "contract",
      contractId: contract.id,
      name: contract.name,
      status: contract.status,
      createdAt: contract.createdAt,
      usedPointsForCreation: contract.usedPointsForCreation ?? false,
      pointsSpentForCreation: contract.pointsSpentForCreation ?? 0,
      contractsUsedBeforeCreation: contract.contractsUsedBeforeCreation,
      contractLimitAtCreation: contract.contractLimitAtCreation,
    }));

    const pointEntries = pointLedgers.map((ledger) => ({
      type: "points",
      ledgerId: Number(ledger.id),
      transactionType: ledger.transactionType,
      amount: ledger.amount,
      balanceAfter: ledger.balanceAfter,
      description: ledger.description,
      referenceType: ledger.referenceType,
      referenceId: ledger.referenceId,
      createdAt: ledger.createdAt,
    }));

    const combined = [...contractEntries, ...pointEntries];
    combined.sort((a, b) => {
      const timeA = new Date(a.createdAt).getTime();
      const timeB = new Date(b.createdAt).getTime();
      return timeB - timeA;
    });

    return combined.slice(0, safeLimit).map((entry) => ({
      ...entry,
      createdAt: entry.createdAt instanceof Date
        ? entry.createdAt.toISOString()
        : entry.createdAt,
    }));
  }
}
