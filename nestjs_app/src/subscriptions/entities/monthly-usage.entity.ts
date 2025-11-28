import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  Unique,
} from 'typeorm';
import { User } from '../../users/user.entity';

@Entity('monthly_usage')
@Unique('uk_user_year_month', ['userId', 'year', 'month'])
export class MonthlyUsage {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'user_id' })
  @Index()
  userId!: number;

  @Column({ type: 'int' })
  @Index('idx_year_month')
  year!: number; // 2025

  @Column({ type: 'int' })
  @Index('idx_year_month')
  month!: number; // 1~12

  // 사용량
  @Column({ name: 'contracts_created', type: 'int', default: 0 })
  contractsCreated!: number; // 이번 달 작성한 계약서 수

  @Column({ name: 'points_earned', type: 'int', default: 0 })
  pointsEarned!: number; // 이번 달 적립한 포인트

  @Column({ name: 'points_spent', type: 'int', default: 0 })
  pointsSpent!: number; // 이번 달 사용한 포인트

  // 출석 체크
  @Column({ name: 'checkin_count', type: 'int', default: 0 })
  checkinCount!: number; // 이번 달 출석 일수

  @Column({ name: 'last_checkin_date', type: 'date', nullable: true })
  lastCheckinDate?: Date | null; // 마지막 출석 날짜

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relations
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  // Helper methods
  canCheckInToday(): boolean {
    if (!this.lastCheckinDate) return true;

    const today = new Date();
    const lastCheckin = new Date(this.lastCheckinDate);

    // 날짜만 비교 (시간 제거)
    today.setHours(0, 0, 0, 0);
    lastCheckin.setHours(0, 0, 0, 0);

    return today.getTime() !== lastCheckin.getTime();
  }

  getYearMonth(): string {
    return `${this.year}-${String(this.month).padStart(2, '0')}`;
  }

  isCurrentMonth(): boolean {
    const now = new Date();
    return this.year === now.getFullYear() && this.month === now.getMonth() + 1;
  }

  incrementContract(): void {
    this.contractsCreated++;
  }

  incrementPointsEarned(amount: number): void {
    this.pointsEarned += amount;
  }

  incrementPointsSpent(amount: number): void {
    this.pointsSpent += amount;
  }

  checkIn(): boolean {
    if (!this.canCheckInToday()) {
      return false;
    }

    this.checkinCount++;
    this.lastCheckinDate = new Date();
    return true;
  }
}
