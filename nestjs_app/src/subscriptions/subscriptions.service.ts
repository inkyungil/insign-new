import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DeepPartial } from 'typeorm';
import { UserSubscription, SubscriptionStatus } from './entities/user-subscription.entity';
import { SubscriptionPlan } from '../subscription-plans/entities/subscription-plan.entity';
import { User } from '../users/user.entity';
import { MonthlyUsageService } from './monthly-usage.service';
import { PointsService } from '../points/points.service';
import { AdminCreateSubscriptionDto } from './dto/admin-create-subscription.dto';
import { AdminUpdateSubscriptionDto } from './dto/admin-update-subscription.dto';

interface AdminSubscriptionFilters {
  status?: SubscriptionStatus;
  planId?: number;
  userId?: number;
  keyword?: string;
  take?: number;
  skip?: number;
}

@Injectable()
export class SubscriptionsService {
  constructor(
    @InjectRepository(UserSubscription)
    private readonly subscriptionRepository: Repository<UserSubscription>,
    @InjectRepository(SubscriptionPlan)
    private readonly planRepository: Repository<SubscriptionPlan>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly monthlyUsageService: MonthlyUsageService,
    private readonly pointsService: PointsService,
  ) {}

  /**
   * 사용자의 현재 활성 구독 조회
   */
  async getActiveSubscription(userId: number): Promise<UserSubscription | null> {
    return this.subscriptionRepository.findOne({
      where: { userId, status: SubscriptionStatus.ACTIVE },
      relations: ['plan'],
      order: { startedAt: 'DESC' },
    });
  }

  /**
   * 사용자의 구독 이력 조회
   */
  async getSubscriptionHistory(userId: number): Promise<UserSubscription[]> {
    return this.subscriptionRepository.find({
      where: { userId },
      relations: ['plan'],
      order: { startedAt: 'DESC' },
    });
  }

  /**
   * 계약서 작성 가능 여부 체크
   */
  async canCreateContract(userId: number): Promise<{
    canCreate: boolean;
    reason?: string;
    contractsUsed: number;
    contractsLimit: number;
    currentBalance: number;
    needsPoints: boolean;
  }> {
    // 현재 활성 구독 조회
    const subscription = await this.getActiveSubscription(userId);

    if (!subscription || !subscription.plan) {
      throw new NotFoundException('활성 구독을 찾을 수 없습니다');
    }

    const plan = subscription.plan;
    const usage = await this.monthlyUsageService.getOrCreateCurrentMonth(userId);
    const currentBalance = await this.pointsService.getBalance(userId);

    const contractsLimit = plan.monthlyContractLimit;
    const contractsUsed = usage.contractsCreated;

    // 무제한 플랜
    if (contractsLimit === -1) {
      return {
        canCreate: true,
        contractsUsed,
        contractsLimit,
        currentBalance,
        needsPoints: false,
      };
    }

    // 기본 할당량 내
    if (contractsUsed < contractsLimit) {
      return {
        canCreate: true,
        contractsUsed,
        contractsLimit,
        currentBalance,
        needsPoints: false,
      };
    }

    // 포인트로 추가 작성 (3 포인트 = 1 계약서)
    if (currentBalance >= 3) {
      return {
        canCreate: true,
        contractsUsed,
        contractsLimit,
        currentBalance,
        needsPoints: true,
      };
    }

    // 작성 불가
    return {
      canCreate: false,
      reason: '월 계약서 작성 제한을 초과했습니다. 포인트가 부족합니다.',
      contractsUsed,
      contractsLimit,
      currentBalance,
      needsPoints: false,
    };
  }

  /**
   * 계약서 작성 시 사용량 증가 및 포인트 차감
   */
  async incrementContractUsage(
    userId: number,
    contractId?: number,
  ): Promise<{ pointsUsed: number }> {
    const check = await this.canCreateContract(userId);

    if (!check.canCreate) {
      throw new BadRequestException(
        check.reason || '계약서를 작성할 수 없습니다',
      );
    }

    let pointsUsed = 0;

    // 포인트 사용이 필요한 경우
    if (check.needsPoints) {
      await this.pointsService.spend({
        userId,
        type: 'spend_contract' as any,
        amount: 3,
        description: '계약서 작성',
        referenceType: 'contract',
        referenceId: contractId,
      });
      await this.monthlyUsageService.incrementPointsSpent(userId, 3);
      pointsUsed = 3;
    }

    // 월별 사용량 증가
    await this.monthlyUsageService.incrementContractUsage(userId);

    return { pointsUsed };
  }

  /**
   * 사용자 구독 상태 및 통계
   */
  async getUserSubscriptionStats(userId: number): Promise<{
    subscription: {
      tier: string;
      planName: string;
      status: string;
      startedAt: Date;
      expiresAt: Date | null;
    };
    usage: {
      contractsUsed: number;
      contractsLimit: number;
      canCreate: boolean;
    };
    points: {
      currentBalance: number;
      totalEarned: number;
      totalSpent: number;
    };
  }> {
    const subscription = await this.getActiveSubscription(userId);

    if (!subscription || !subscription.plan) {
      throw new NotFoundException('활성 구독을 찾을 수 없습니다');
    }

    const canCreateResult = await this.canCreateContract(userId);
    const pointsStats = await this.pointsService.getStatistics(userId);

    return {
      subscription: {
        tier: subscription.plan.tier,
        planName: subscription.plan.name,
        status: subscription.status,
        startedAt: subscription.startedAt,
        expiresAt: subscription.expiresAt || null,
      },
      usage: {
        contractsUsed: canCreateResult.contractsUsed,
        contractsLimit: canCreateResult.contractsLimit,
        canCreate: canCreateResult.canCreate,
      },
      points: {
        currentBalance: pointsStats.currentBalance,
        totalEarned: pointsStats.totalEarned,
        totalSpent: pointsStats.totalSpent,
      },
    };
  }

  /**
   * 관리자용 구독 목록 조회
   */
  async listSubscriptionsForAdmin(filters: AdminSubscriptionFilters = {}) {
    const qb = this.subscriptionRepository
      .createQueryBuilder('subscription')
      .leftJoinAndSelect('subscription.plan', 'plan')
      .leftJoinAndSelect('subscription.user', 'user')
      .orderBy('subscription.createdAt', 'DESC');

    if (filters.status) {
      qb.andWhere('subscription.status = :status', { status: filters.status });
    }

    if (typeof filters.planId === 'number') {
      qb.andWhere('subscription.planId = :planId', { planId: filters.planId });
    }

    if (typeof filters.userId === 'number') {
      qb.andWhere('subscription.userId = :userId', { userId: filters.userId });
    } else if (filters.keyword) {
      const keyword = `%${filters.keyword.toLowerCase()}%`;
      qb.andWhere(
        'LOWER(plan.name) LIKE :keyword OR LOWER(plan.tier) LIKE :keyword OR LOWER(user.displayName) LIKE :keyword OR CAST(subscription.id AS CHAR) LIKE :keyword OR CAST(subscription.userId AS CHAR) LIKE :keyword',
        { keyword },
      );
    }

    const take = typeof filters.take === 'number' ? filters.take : 50;
    if (take > 0) {
      qb.take(take);
    }

    if (typeof filters.skip === 'number' && filters.skip > 0) {
      qb.skip(filters.skip);
    }

    return qb.getMany();
  }

  async getSubscriptionStatusSummary() {
    const rows = await this.subscriptionRepository
      .createQueryBuilder('subscription')
      .select('subscription.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .groupBy('subscription.status')
      .getRawMany<{ status: SubscriptionStatus; count: string }>();

    const summary = {
      total: 0,
      active: 0,
      pending: 0,
      expired: 0,
      cancelled: 0,
    };

    for (const row of rows) {
      const count = Number(row.count) || 0;
      summary.total += count;
      switch (row.status) {
        case SubscriptionStatus.ACTIVE:
          summary.active = count;
          break;
        case SubscriptionStatus.PENDING:
          summary.pending = count;
          break;
        case SubscriptionStatus.EXPIRED:
          summary.expired = count;
          break;
        case SubscriptionStatus.CANCELLED:
          summary.cancelled = count;
          break;
        default:
          break;
      }
    }

    return summary;
  }

  async listPlansForAdmin(includeInactive = true) {
    return this.planRepository.find({
      where: includeInactive ? {} : { isActive: true },
      order: { displayOrder: 'ASC', id: 'ASC' },
    });
  }

  async findSubscriptionWithRelations(id: number) {
    const subscription = await this.subscriptionRepository.findOne({
      where: { id },
      relations: ['plan', 'user'],
    });

    if (!subscription) {
      throw new NotFoundException('구독 정보를 찾을 수 없습니다');
    }

    return subscription;
  }

  async createSubscriptionForAdmin(dto: AdminCreateSubscriptionDto) {
    const user = await this.userRepository.findOne({ where: { id: dto.userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다');
    }

    const plan = await this.planRepository.findOne({ where: { id: dto.planId } });
    if (!plan) {
      throw new NotFoundException('구독 플랜을 찾을 수 없습니다');
    }

    const startedAt = this.parseDateInput(dto.startedAt, '시작일');
    if (!startedAt) {
      throw new BadRequestException('시작일을 입력해 주세요.');
    }
    const expiresAt = this.parseDateInput(dto.expiresAt, '만료일', true);

    const payload: DeepPartial<UserSubscription> = {
      userId: user.id,
      planId: plan.id,
      startedAt,
      expiresAt,
      status: dto.status ?? SubscriptionStatus.ACTIVE,
      autoRenew: dto.autoRenew ?? false,
      paymentMethod: dto.paymentMethod?.trim() || null,
      paymentId: dto.paymentId?.trim() || null,
      amountPaid: dto.amountPaid ?? 0,
      cancelReason: null,
    };

    const subscription = this.subscriptionRepository.create(payload);

    const saved = await this.subscriptionRepository.save(subscription);
    return this.findSubscriptionWithRelations(saved.id);
  }

  async updateSubscriptionForAdmin(id: number, dto: AdminUpdateSubscriptionDto) {
    const subscription = await this.subscriptionRepository.findOne({
      where: { id },
    });

    if (!subscription) {
      throw new NotFoundException('구독 정보를 찾을 수 없습니다');
    }

    if (dto.status) {
      subscription.status = dto.status;
    }

    if (dto.autoRenew !== undefined) {
      subscription.autoRenew = dto.autoRenew;
    }

    if (dto.expiresAt !== undefined) {
      subscription.expiresAt = this.parseDateInput(dto.expiresAt, '만료일', true);
    }

    if (dto.paymentMethod !== undefined) {
      subscription.paymentMethod = dto.paymentMethod?.trim() || null;
    }

    if (dto.paymentId !== undefined) {
      subscription.paymentId = dto.paymentId?.trim() || null;
    }

    if (dto.amountPaid !== undefined) {
      subscription.amountPaid = dto.amountPaid ?? 0;
    }

    if (dto.cancelReason !== undefined) {
      subscription.cancelReason = dto.cancelReason?.trim() || null;
    }

    const saved = await this.subscriptionRepository.save(subscription);
    return this.findSubscriptionWithRelations(saved.id);
  }

  private parseDateInput(value: string | undefined, label: string, allowNull = false): Date | null {
    if (value === undefined || value === null || value === '') {
      if (allowNull) {
        return null;
      }
      throw new BadRequestException(`${label}을(를) 입력해 주세요.`);
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`${label} 형식이 올바르지 않습니다.`);
    }

    return date;
  }

  /**
   * 플랜 업그레이드/다운그레이드
   */
  async changePlan(
    userId: number,
    newPlanTier: string,
    paymentInfo?: {
      method: string;
      paymentId: string;
      amountPaid: number;
    },
  ): Promise<UserSubscription> {
    // 새 플랜 조회
    const newPlan = await this.planRepository.findOne({
      where: { tier: newPlanTier, isActive: true },
    });

    if (!newPlan) {
      throw new NotFoundException('요금제를 찾을 수 없습니다');
    }

    // 기존 구독 만료 처리
    const currentSubscription = await this.getActiveSubscription(userId);
    if (currentSubscription) {
      currentSubscription.status = SubscriptionStatus.EXPIRED;
      currentSubscription.expiresAt = new Date();
      await this.subscriptionRepository.save(currentSubscription);
    }

    // 새 구독 생성
    const newSubscription = this.subscriptionRepository.create({
      userId,
      planId: newPlan.id,
      startedAt: new Date(),
      status: SubscriptionStatus.ACTIVE,
      paymentMethod: paymentInfo?.method || 'free',
      paymentId: paymentInfo?.paymentId,
      amountPaid: paymentInfo?.amountPaid || 0,
      autoRenew: false,
    });

    await this.subscriptionRepository.save(newSubscription);

    // users 테이블 업데이트
    await this.userRepository.update(userId, {
      subscriptionPlanId: newPlan.id,
      subscriptionTier: newPlan.tier as 'free' | 'premium',
    });

    return newSubscription;
  }

  /**
   * 구독 취소
   */
  async cancelSubscription(
    userId: number,
    reason?: string,
  ): Promise<UserSubscription> {
    const subscription = await this.getActiveSubscription(userId);

    if (!subscription) {
      throw new NotFoundException('활성 구독을 찾을 수 없습니다');
    }

    subscription.status = SubscriptionStatus.CANCELLED;
    subscription.cancelledAt = new Date();
    subscription.cancelReason = reason;

    return this.subscriptionRepository.save(subscription);
  }
}
