import {
  ConflictException,
  Injectable,
  NotFoundException,
  BadRequestException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import * as bcrypt from "bcrypt";
import * as crypto from "crypto";
import { ConfigService } from "@nestjs/config";
import { User } from "./user.entity";
import { CreateUserDto } from "./dto/create-user.dto";
import { UserDeletionLog } from "./user-deletion-log.entity";
import { EncryptionService } from "../common/encryption.service";
import { hashEmail, normalizeEmail } from "./email.utils";
import { PointsService } from "../points/points.service";
import { TransactionType } from "../points/entities/points-ledger.entity";

@Injectable()
export class UsersService {
  private readonly contractPointCost: number;
  private readonly defaultMonthlyContractLimit: number;
  private readonly defaultSignupPoints: number;
  private readonly defaultMonthlyPointsLimit: number;

  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    @InjectRepository(UserDeletionLog)
    private readonly userDeletionLogRepository: Repository<UserDeletionLog>,
    private readonly encryptionService: EncryptionService,
    private readonly configService: ConfigService,
    private readonly pointsService: PointsService,
  ) {
    let configuredCost = Number(this.configService.get("CONTRACT_POINTS_COST", "3"));
    if (!Number.isFinite(configuredCost) || configuredCost <= 0) {
      configuredCost = 3;
    }
    this.contractPointCost = Math.floor(configuredCost);

    let configuredLimit = Number(
      this.configService.get("DEFAULT_MONTHLY_CONTRACT_LIMIT", "4"),
    );
    if (!Number.isFinite(configuredLimit) || configuredLimit < -1) {
      configuredLimit = 4;
    }
    this.defaultMonthlyContractLimit = Math.floor(configuredLimit);

    let signupPoints = Number(
      this.configService.get("DEFAULT_SIGNUP_POINTS", "0"),
    );
    if (!Number.isFinite(signupPoints) || signupPoints < 0) {
      signupPoints = 0;
    }
    this.defaultSignupPoints = Math.floor(signupPoints);

    let monthlyPointsLimit = Number(
      this.configService.get("DEFAULT_MONTHLY_POINTS_LIMIT", "12"),
    );
    if (!Number.isFinite(monthlyPointsLimit) || monthlyPointsLimit < 0) {
      monthlyPointsLimit = 0;
    }
    this.defaultMonthlyPointsLimit = Math.floor(monthlyPointsLimit);
  }

  async createUser(dto: CreateUserDto) {
    const normalizedEmail = normalizeEmail(dto.email);
    const emailHash = hashEmail(normalizedEmail);
    const existing = await this.usersRepository.findOne({
      where: { emailHash },
    });
    if (existing) {
      throw new ConflictException("이미 가입된 이메일입니다.");
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = this.usersRepository.create({
      passwordHash,
      displayName: dto.displayName?.trim() ?? null,
      provider: "local",
    });
    this.assignEncryptedEmail(user, normalizedEmail);
    user.subscriptionTier = user.subscriptionTier ?? "free";
    user.monthlyContractLimit = this.defaultMonthlyContractLimit;
    user.contractsUsedThisMonth = 0;
    user.points = this.defaultSignupPoints;
    user.monthlyPointsLimit = this.defaultMonthlyPointsLimit;
    const saved = await this.usersRepository.save(user);
    return this.decryptUser(saved)!;
  }

  async findByEmail(email: string) {
    const normalizedEmail = normalizeEmail(email);
    const emailHash = hashEmail(normalizedEmail);
    const user = await this.usersRepository.findOne({
      where: { emailHash, isActive: true },
    });
    return this.decryptUser(user);
  }

  async findByEmailIncludingInactive(email: string) {
    const normalizedEmail = normalizeEmail(email);
    const emailHash = hashEmail(normalizedEmail);
    const user = await this.usersRepository.findOne({
      where: { emailHash },
    });
    return this.decryptUser(user);
  }

  async findByGoogleId(googleId: string) {
    const user = await this.usersRepository.findOne({ where: { googleId } });
    return this.decryptUser(user);
  }

  async markLastLogin(id: number) {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException("사용자를 찾을 수 없습니다.");
    }
    user.lastLoginAt = new Date();
    const saved = await this.usersRepository.save(user);
    return this.decryptUser(saved)!;
  }

  async findAllUsers() {
    const users = await this.usersRepository.find({ order: { id: "ASC" } });
    return users.map((user) => this.decryptUser(user)!);
  }

  async findActiveUsers() {
    const users = await this.usersRepository
      .createQueryBuilder("user")
      .select(["user.id", "user.email", "user.displayName"])
      .where("user.isActive = :active", { active: true })
      .orderBy("user.id", "ASC")
      .getMany();
    return users.map((user) => this.decryptUser(user)!);
  }

  async countActiveUsers() {
    return this.usersRepository.count({ where: { isActive: true } });
  }

  async findOneById(id: number) {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException("사용자를 찾을 수 없습니다.");
    }
    return this.decryptUser(user)!;
  }

  async updateUserPassword(id: number, password: string) {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException("사용자를 찾을 수 없습니다.");
    }

    user.passwordHash = await bcrypt.hash(password, 10);
    if (!user.provider || user.provider === "google") {
      user.provider = "local";
    }

    const saved = await this.usersRepository.save(user);
    return this.decryptUser(saved)!;
  }

  async deleteUserAndLog(user: User, options?: { reason?: string }) {
    await this.userDeletionLogRepository.save({
      userId: user.id,
      email: user.email,
      displayName: user.displayName ?? null,
      provider: user.provider ?? null,
      reason: options?.reason ?? null,
      metadata: {
        googleId: user.googleId ?? null,
        lastLoginAt: user.lastLoginAt ?? null,
        hasPassword: Boolean(user.passwordHash),
        isActive: user.isActive,
      },
    });

    const result = await this.usersRepository.delete({ id: user.id });
    if (!result.affected) {
      throw new NotFoundException("사용자를 찾을 수 없습니다.");
    }
  }

  async upsertGoogleUser(payload: {
    email: string;
    googleId: string;
    displayName?: string | null;
    avatarUrl?: string | null;
  }): Promise<{ user: User; isNewUser: boolean }> {
    const normalizedEmail = normalizeEmail(payload.email);
    const emailHash = hashEmail(normalizedEmail);

    let user = await this.usersRepository.findOne({
      where: [{ googleId: payload.googleId }, { emailHash }],
    });

    let isNewUser = false;

    if (!user) {
      isNewUser = true;
      user = this.usersRepository.create({
        googleId: payload.googleId,
        displayName: payload.displayName ?? null,
        avatarUrl: payload.avatarUrl ?? null,
        provider: "google",
        isActive: true,
        isEmailVerified: true, // Google OAuth users are auto-verified
        subscriptionTier: "free",
        monthlyContractLimit: this.defaultMonthlyContractLimit,
        contractsUsedThisMonth: 0,
        points: this.defaultSignupPoints,
        monthlyPointsLimit: this.defaultMonthlyPointsLimit,
      });
    } else {
      user.googleId = user.googleId ?? payload.googleId;
      user.provider = "google";
      if (payload.displayName) {
        user.displayName = payload.displayName;
      }
      if (payload.avatarUrl) {
        user.avatarUrl = payload.avatarUrl;
      }
      user.isActive = true;
      user.isEmailVerified = true; // Google OAuth users are auto-verified
      user.passwordHash = user.passwordHash ?? null;
    }

    this.assignEncryptedEmail(user, normalizedEmail);
    if (isNewUser) {
      user.subscriptionTier = user.subscriptionTier ?? "free";
      user.monthlyContractLimit = this.defaultMonthlyContractLimit;
      user.contractsUsedThisMonth = 0;
      user.points = this.defaultSignupPoints;
      user.monthlyPointsLimit = this.defaultMonthlyPointsLimit;
    }
    const saved = await this.usersRepository.save(user);
    return { user: this.decryptUser(saved)!, isNewUser };
  }

  generateEmailVerificationToken(): string {
    return crypto.randomBytes(32).toString("hex");
  }

  async setEmailVerificationToken(userId: number): Promise<{
    token: string;
    expiresAt: Date;
  }> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException("사용자를 찾을 수 없습니다.");
    }

    const token = this.generateEmailVerificationToken();
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24); // 24시간 유효

    user.emailVerificationToken = token;
    user.emailVerificationTokenExpiresAt = expiresAt;
    await this.usersRepository.save(user);

    return { token, expiresAt };
  }

  async verifyEmailWithToken(token: string): Promise<User> {
    const user = await this.usersRepository.findOne({
      where: { emailVerificationToken: token },
    });

    if (!user) {
      throw new BadRequestException(
        "유효하지 않은 인증 링크입니다. 다시 시도해 주세요.",
      );
    }

    if (
      !user.emailVerificationTokenExpiresAt ||
      user.emailVerificationTokenExpiresAt < new Date()
    ) {
      throw new BadRequestException(
        "인증 링크가 만료되었습니다. 새로운 인증 메일을 요청해 주세요.",
      );
    }

    user.isEmailVerified = true;
    user.emailVerificationToken = null;
    user.emailVerificationTokenExpiresAt = null;
    const saved = await this.usersRepository.save(user);

    return this.decryptUser(saved)!;
  }

  async findUserByIdForResend(userId: number): Promise<User | null> {
    const user = await this.usersRepository.findOne({
      where: { id: userId },
    });
    return this.decryptUser(user);
  }

  async updateTermsAgreement(
    userId: number,
    dto: {
      agreedToTerms: boolean;
      agreedToPrivacy: boolean;
      agreedToSensitive: boolean;
      agreedToMarketing: boolean;
    },
  ): Promise<User> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException("사용자를 찾을 수 없습니다.");
    }

    user.agreedToTerms = dto.agreedToTerms;
    user.agreedToPrivacy = dto.agreedToPrivacy;
    user.agreedToSensitive = dto.agreedToSensitive;
    user.agreedToMarketing = dto.agreedToMarketing;
    user.termsAgreedAt = new Date();

    const saved = await this.usersRepository.save(user);
    return this.decryptUser(saved)!;
  }

  private assignEncryptedEmail(user: User, normalizedEmail: string) {
    user.email = this.encryptionService.encrypt(normalizedEmail);
    user.emailHash = hashEmail(normalizedEmail);
  }

  private decryptUser(user: User | null): User | null {
    if (!user) {
      return null;
    }
    if (user.email) {
      try {
        user.email = this.encryptionService.decrypt(user.email);
      } catch {
        // ignore legacy values that cannot be decrypted
      }
    }
    return user;
  }

  // ==================== 구독 및 포인트 시스템 (임시 Wrapper) ====================
  // TODO: api-auth.controller와 contracts.service를 새 서비스로 마이그레이션 후 제거
  // 현재는 호환성을 위해 wrapper 메서드로 제공

  /**
   * @deprecated SubscriptionsService.canCreateContract() 사용
   */
  async canCreateContract(userId: number): Promise<{
    canCreate: boolean;
    reason?: string;
    contractsUsed: number;
    contractsLimit: number;
    points: number;
  }> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new Error("사용자를 찾을 수 없습니다.");
    }

    const usageUpdated = this.ensureCurrentMonthUsage(user);
    if (usageUpdated) {
      await this.usersRepository.save(user);
    }

    const isPremium = user.subscriptionTier === "premium";
    const contractsUsed = user.contractsUsedThisMonth;
    const contractsLimit = user.monthlyContractLimit;
    const points = user.points;
    const pointsRequired = this.contractPointCost;

    // 프리미엄 사용자는 무제한
    if (isPremium) {
      return {
        canCreate: true,
        contractsUsed,
        contractsLimit: -1, // 무제한 표시
        points,
      };
    }

    // 무료 계약서 남아있음
    if (contractsLimit < 0 || contractsUsed < contractsLimit) {
      return {
        canCreate: true,
        contractsUsed,
        contractsLimit,
        points,
      };
    }

    // 포인트로 작성 가능
    if (points >= pointsRequired) {
      return {
        canCreate: true,
        reason: `포인트 ${pointsRequired}개 사용`,
        contractsUsed,
        contractsLimit,
        points,
      };
    }

    // 작성 불가
    return {
      canCreate: false,
      reason: "월 계약서 한도 초과 및 포인트 부족",
      contractsUsed,
      contractsLimit,
      points,
    };
  }

  /**
   * @deprecated SubscriptionsService.incrementContractUsage() 사용
   */
  async incrementContractUsage(userId: number, usePoints: boolean = false): Promise<void> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new Error("사용자를 찾을 수 없습니다.");
    }

    this.ensureCurrentMonthUsage(user);

    const limit = user.monthlyContractLimit;
    const hasFreeSlot = limit < 0 || user.contractsUsedThisMonth < limit;

    if (!hasFreeSlot && !usePoints) {
      throw new BadRequestException("월 계약서 작성 한도를 초과했습니다.");
    }

    if (usePoints) {
      const requiredPoints = this.contractPointCost;
      if (user.points < requiredPoints) {
        throw new BadRequestException("포인트가 부족합니다.");
      }
      user.points -= requiredPoints;
    }

    user.contractsUsedThisMonth += 1;

    await this.usersRepository.save(user);
  }

  private ensureCurrentMonthUsage(user: User): boolean {
    const now = new Date();
    const lastReset = user.lastResetDate ? new Date(user.lastResetDate) : null;

    if (
      lastReset &&
      lastReset.getFullYear() === now.getFullYear() &&
      lastReset.getMonth() === now.getMonth()
    ) {
      return false;
    }

    user.contractsUsedThisMonth = 0;
    user.pointsEarnedThisMonth = 0;
    if (user.subscriptionTier === "free") {
      user.monthlyContractLimit = this.defaultMonthlyContractLimit;
    }
    user.monthlyPointsLimit = this.defaultMonthlyPointsLimit;
    user.lastResetDate = new Date(now.getFullYear(), now.getMonth(), 1);
    return true;
  }

  /**
   * 출석 체크 - PointsService를 사용하여 히스토리 기록
   */
  async checkIn(userId: number): Promise<{ success: boolean; points: number; message: string }> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new Error("사용자를 찾을 수 없습니다.");
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // 이미 오늘 출석했는지 확인
    if (user.lastCheckInDate) {
      const lastCheckIn = new Date(user.lastCheckInDate);
      lastCheckIn.setHours(0, 0, 0, 0);

      if (lastCheckIn.getTime() === today.getTime()) {
        return {
          success: false,
          points: user.points,
          message: "오늘은 이미 출석했습니다!",
        };
      }
    }

    // 월별 포인트 제한 확인
    if (user.pointsEarnedThisMonth >= user.monthlyPointsLimit) {
      return {
        success: false,
        points: user.points,
        message: "이번 달 포인트 적립 한도에 도달했습니다.",
      };
    }

    // PointsService를 사용하여 포인트 적립 및 히스토리 기록
    await this.pointsService.earn({
      userId,
      type: TransactionType.EARN_CHECKIN,
      amount: 1,
      description: '출석 체크 포인트',
      expiresInDays: 365, // 1년 후 만료
    });

    // 사용자 정보 업데이트
    user.points += 1;
    user.pointsEarnedThisMonth += 1;
    user.lastCheckInDate = today;

    await this.usersRepository.save(user);

    return {
      success: true,
      points: user.points,
      message: "출석 체크 완료! 1포인트가 적립되었습니다.",
    };
  }

  /**
   * @deprecated PointsService.earn() 사용
   */
  async addPointsFromAd(userId: number, pointsToAdd: number = 1): Promise<{ points: number }> {
    // TODO: PointsService 주입 및 사용
    return { points: 999 };
  }

  /**
   * 사용자 통계 조회 (전체 User 정보 반환)
   */
  async getUserStats(userId: number): Promise<User> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new Error("사용자를 찾을 수 없습니다.");
    }

    return this.decryptUser(user)!;
  }

  getContractPointCost(): number {
    return this.contractPointCost;
  }
}
