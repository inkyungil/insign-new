import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from "typeorm";
import { SubscriptionPlan } from "../subscription-plans/entities/subscription-plan.entity";

@Entity({ name: "users" })
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: "varchar", length: 255 })
  email!: string;

  @Index({ unique: true })
  @Column({ name: "email_hash", type: "char", length: 64 })
  emailHash!: string;

  @Column({
    name: "password_hash",
    type: "varchar",
    length: 255,
    nullable: true,
  })
  passwordHash?: string | null;

  @Column({
    name: "display_name",
    type: "varchar",
    length: 120,
    nullable: true,
  })
  displayName?: string | null;

  @Column({ type: "varchar", length: 20, default: "local" })
  provider!: "local" | "google";

  @Column({
    name: "google_id",
    type: "varchar",
    length: 64,
    nullable: true,
    unique: true,
  })
  googleId?: string | null;

  @Column({ name: "avatar_url", type: "varchar", length: 255, nullable: true })
  avatarUrl?: string | null;

  @Column({ name: "is_active", type: "tinyint", default: true })
  isActive!: boolean;

  @Column({ name: "is_email_verified", type: "tinyint", default: false })
  isEmailVerified!: boolean;

  @Column({
    name: "email_verification_token",
    type: "varchar",
    length: 64,
    nullable: true,
  })
  emailVerificationToken?: string | null;

  @Column({
    name: "email_verification_token_expires_at",
    type: "datetime",
    nullable: true,
  })
  emailVerificationTokenExpiresAt?: Date | null;

  @Column({ name: "last_login_at", type: "datetime", nullable: true })
  lastLoginAt?: Date | null;

  // 약관 동의 필드
  @Column({ name: "agreed_to_terms", type: "tinyint", default: false })
  agreedToTerms!: boolean;

  @Column({ name: "agreed_to_privacy", type: "tinyint", default: false })
  agreedToPrivacy!: boolean;

  @Column({ name: "agreed_to_sensitive", type: "tinyint", default: false })
  agreedToSensitive!: boolean;

  @Column({ name: "agreed_to_marketing", type: "tinyint", default: false })
  agreedToMarketing!: boolean;

  @Column({ name: "terms_agreed_at", type: "datetime", nullable: true })
  termsAgreedAt?: Date | null;

  // 구독 시스템
  @Column({
    name: "subscription_tier",
    type: "varchar",
    length: 20,
    default: "free",
  })
  subscriptionTier!: "free" | "premium";

  @Column({ name: "monthly_contract_limit", type: "int", default: 4 })
  monthlyContractLimit!: number;

  @Column({ name: "contracts_used_this_month", type: "int", default: 0 })
  contractsUsedThisMonth!: number;

  @Column({ name: "last_reset_date", type: "date", nullable: true })
  lastResetDate?: Date | null;

  @Column({ name: "points", type: "int", default: 0 })
  points!: number;

  @Column({ name: "monthly_points_limit", type: "int", default: 0 })
  monthlyPointsLimit!: number;

  @Column({ name: "points_earned_this_month", type: "int", default: 0 })
  pointsEarnedThisMonth!: number;

  @Column({ name: "last_check_in_date", type: "date", nullable: true })
  lastCheckInDate?: Date | null;

  // 현재 활성 요금제 참조
  @Column({ name: "subscription_plan_id", type: "int", nullable: true })
  subscriptionPlanId?: number | null;

  @ManyToOne(() => SubscriptionPlan)
  @JoinColumn({ name: "subscription_plan_id" })
  subscriptionPlan?: SubscriptionPlan;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt!: Date;
}
