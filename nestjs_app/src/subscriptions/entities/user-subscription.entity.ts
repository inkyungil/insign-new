import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/user.entity';
import { SubscriptionPlan } from '../../subscription-plans/entities/subscription-plan.entity';

export enum SubscriptionStatus {
  ACTIVE = 'active',
  EXPIRED = 'expired',
  CANCELLED = 'cancelled',
  PENDING = 'pending',
}

@Entity('user_subscriptions')
export class UserSubscription {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'user_id' })
  @Index()
  userId!: number;

  @Column({ name: 'plan_id' })
  planId!: number;

  // 구독 기간
  @Column({ name: 'started_at', type: 'timestamp' })
  startedAt!: Date;

  @Column({ name: 'expires_at', type: 'timestamp', nullable: true })
  @Index()
  expiresAt?: Date | null; // NULL이면 활성, 값 있으면 만료

  // 결제 정보
  @Column({ name: 'payment_method', type: 'varchar', length: 50, nullable: true })
  paymentMethod?: string | null; // 'card', 'bank_transfer', 'free'

  @Column({ name: 'payment_id', type: 'varchar', length: 100, nullable: true })
  paymentId?: string | null; // 외부 결제 시스템 ID (Iamport 등)

  @Column({ name: 'amount_paid', type: 'int', default: 0 })
  amountPaid!: number; // 실제 결제 금액

  // 상태
  @Column({
    type: 'enum',
    enum: SubscriptionStatus,
    default: SubscriptionStatus.ACTIVE,
  })
  @Index()
  status!: SubscriptionStatus;

  @Column({ name: 'cancelled_at', type: 'timestamp', nullable: true })
  cancelledAt?: Date | null;

  @Column({ name: 'cancel_reason', type: 'text', nullable: true })
  cancelReason?: string | null;

  // 자동 갱신
  @Column({ name: 'auto_renew', type: 'boolean', default: false })
  autoRenew!: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relations
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => SubscriptionPlan)
  @JoinColumn({ name: 'plan_id' })
  plan!: SubscriptionPlan;

  // Helper methods
  isActive(): boolean {
    return this.status === SubscriptionStatus.ACTIVE;
  }

  isExpired(): boolean {
    if (!this.expiresAt) return false;
    return new Date() > this.expiresAt;
  }

  daysUntilExpiration(): number | null {
    if (!this.expiresAt) return null;
    const now = new Date();
    const diff = this.expiresAt.getTime() - now.getTime();
    return Math.ceil(diff / (1000 * 60 * 60 * 24));
  }
}
