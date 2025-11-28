import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('subscription_plans')
export class SubscriptionPlan {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 20, unique: true })
  @Index()
  tier!: string; // 'free', 'premium', 'business'

  @Column({ type: 'varchar', length: 50 })
  name!: string; // '무료', '프리미엄'

  @Column({ type: 'text', nullable: true })
  description?: string | null;

  // 제한 설정
  @Column({ name: 'monthly_contract_limit', type: 'int' })
  monthlyContractLimit!: number; // 4, -1(무제한)

  @Column({ name: 'monthly_points_limit', type: 'int' })
  monthlyPointsLimit!: number; // 12, -1(무제한)

  @Column({ name: 'initial_points', type: 'int', default: 0 })
  initialPoints!: number; // 가입 시 제공 포인트

  // 가격
  @Column({ name: 'price_monthly', type: 'int', default: 0 })
  priceMonthly!: number; // 월 구독료 (원)

  @Column({ name: 'price_yearly', type: 'int', nullable: true })
  priceYearly?: number | null; // 연 구독료 (원)

  // 기능 (JSON)
  @Column({ type: 'json', nullable: true })
  features?: Record<string, any> | null; // {"templates": ["basic", "premium"], "ai_summary": true}

  // 상태
  @Column({ name: 'is_active', type: 'boolean', default: true })
  @Index()
  isActive!: boolean;

  @Column({ name: 'display_order', type: 'int', default: 0 })
  displayOrder!: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Helper methods
  isUnlimited(): boolean {
    return this.monthlyContractLimit === -1;
  }

  hasFeature(feature: string): boolean {
    if (!this.features) return false;
    return this.features[feature] === true;
  }
}
