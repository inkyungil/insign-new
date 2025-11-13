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

@Injectable()
export class ApiAuthService {
  private readonly tokenTtlSeconds: number;
  private readonly googleClient: OAuth2Client;
  private readonly googleClientIds: string[];

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @InjectRepository(Contract)
    private readonly contractRepository: Repository<Contract>,
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

    const user = await this.usersService.upsertGoogleUser({
      email: payload.email,
      googleId: payload.sub,
      displayName: payload.name ?? null,
      avatarUrl: payload.picture ?? null,
    });

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
}
