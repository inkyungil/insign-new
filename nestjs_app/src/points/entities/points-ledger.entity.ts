import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/user.entity';

export enum TransactionType {
  EARN_CHECKIN = 'earn_checkin', // 출석 체크 적립
  EARN_SIGNUP = 'earn_signup', // 가입 보너스
  EARN_REFERRAL = 'earn_referral', // 추천인 보너스
  EARN_AD = 'earn_ad', // 광고 시청
  EARN_ADMIN = 'earn_admin', // 관리자 수동 지급
  SPEND_CONTRACT = 'spend_contract', // 계약서 작성 사용
  SPEND_TEMPLATE = 'spend_template', // 프리미엄 템플릿 사용
  EXPIRE = 'expire', // 만료
  REFUND = 'refund', // 환불
}

@Entity('points_ledger')
export class PointsLedger {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id!: number;

  @Column({ name: 'user_id' })
  @Index()
  userId!: number;

  // 거래 정보
  @Column({
    name: 'transaction_type',
    type: 'enum',
    enum: TransactionType,
  })
  @Index()
  transactionType!: TransactionType;

  @Column({ type: 'int' })
  amount!: number; // 양수=적립, 음수=사용

  @Column({ name: 'balance_after', type: 'int' })
  balanceAfter!: number; // 거래 후 잔액

  // 메타데이터
  @Column({ type: 'varchar', length: 255, nullable: true })
  description?: string;

  @Column({ name: 'reference_type', type: 'varchar', length: 50, nullable: true })
  @Index('idx_reference')
  referenceType?: string; // 'contract', 'template', 'user'

  @Column({ name: 'reference_id', type: 'int', nullable: true })
  @Index('idx_reference')
  referenceId?: number;

  // 만료 정보
  @Column({ name: 'expires_at', type: 'date', nullable: true })
  @Index()
  expiresAt?: Date | null;

  @Column({ name: 'is_expired', type: 'boolean', default: false })
  isExpired!: boolean;

  @CreateDateColumn({ name: 'created_at' })
  @Index()
  createdAt!: Date;

  // Relations
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  // Helper methods
  isEarn(): boolean {
    return this.amount > 0;
  }

  isSpend(): boolean {
    return this.amount < 0;
  }

  isExpiringSoon(days: number = 30): boolean {
    if (!this.expiresAt) return false;
    const now = new Date();
    const expiryDate = new Date(this.expiresAt);
    const diffTime = expiryDate.getTime() - now.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays > 0 && diffDays <= days;
  }
}
