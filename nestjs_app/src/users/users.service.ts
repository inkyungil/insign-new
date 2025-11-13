import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import * as bcrypt from "bcrypt";
import { User } from "./user.entity";
import { CreateUserDto } from "./dto/create-user.dto";
import { UserDeletionLog } from "./user-deletion-log.entity";
import { EncryptionService } from "../common/encryption.service";
import { hashEmail, normalizeEmail } from "./email.utils";

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    @InjectRepository(UserDeletionLog)
    private readonly userDeletionLogRepository: Repository<UserDeletionLog>,
    private readonly encryptionService: EncryptionService,
  ) {}

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
  }) {
    const normalizedEmail = normalizeEmail(payload.email);
    const emailHash = hashEmail(normalizedEmail);

    let user = await this.usersRepository.findOne({
      where: [{ googleId: payload.googleId }, { emailHash }],
    });

    if (!user) {
      user = this.usersRepository.create({
        googleId: payload.googleId,
        displayName: payload.displayName ?? null,
        avatarUrl: payload.avatarUrl ?? null,
        provider: "google",
        isActive: true,
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
      user.passwordHash = user.passwordHash ?? null;
    }

    this.assignEncryptedEmail(user, normalizedEmail);
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
}
