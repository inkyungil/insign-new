import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MonthlyUsage } from './entities/monthly-usage.entity';
import { PointsService } from '../points/points.service';
import { TransactionType } from '../points/entities/points-ledger.entity';

@Injectable()
export class MonthlyUsageService {
  constructor(
    @InjectRepository(MonthlyUsage)
    private readonly usageRepository: Repository<MonthlyUsage>,
    private readonly pointsService: PointsService,
  ) {}

  /**
   * 이번 달 사용량 레코드 가져오기 (없으면 생성)
   */
  async getOrCreateCurrentMonth(userId: number): Promise<MonthlyUsage> {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1; // 0-based이므로 +1

    let usage = await this.usageRepository.findOne({
      where: { userId, year, month },
    });

    if (!usage) {
      usage = this.usageRepository.create({
        userId,
        year,
        month,
        contractsCreated: 0,
        pointsEarned: 0,
        pointsSpent: 0,
        checkinCount: 0,
      });
      await this.usageRepository.save(usage);
    }

    return usage;
  }

  /**
   * 특정 월 사용량 조회
   */
  async getUsage(
    userId: number,
    year: number,
    month: number,
  ): Promise<MonthlyUsage | null> {
    return this.usageRepository.findOne({
      where: { userId, year, month },
    });
  }

  /**
   * 최근 N개월 사용량 조회
   */
  async getRecentMonths(
    userId: number,
    months = 6,
  ): Promise<MonthlyUsage[]> {
    return this.usageRepository.find({
      where: { userId },
      order: { year: 'DESC', month: 'DESC' },
      take: months,
    });
  }

  /**
   * 출석 체크
   */
  async checkIn(userId: number): Promise<{
    success: boolean;
    points: number;
    message: string;
  }> {
    const usage = await this.getOrCreateCurrentMonth(userId);

    // 오늘 이미 출석했는지 확인
    if (!usage.canCheckInToday()) {
      const currentPoints = await this.pointsService.getBalance(userId);
      return {
        success: false,
        points: currentPoints,
        message: '오늘은 이미 출석 체크를 완료했습니다.',
      };
    }

    // 포인트 적립
    await this.pointsService.earn({
      userId,
      type: TransactionType.EARN_CHECKIN,
      amount: 1,
      description: '출석 체크',
    });

    // 월별 사용량 업데이트
    usage.checkIn();
    usage.incrementPointsEarned(1);
    await this.usageRepository.save(usage);

    const currentPoints = await this.pointsService.getBalance(userId);

    return {
      success: true,
      points: currentPoints,
      message: '출석 체크 완료! 1포인트가 적립되었습니다.',
    };
  }

  /**
   * 계약서 작성 카운트 증가
   */
  async incrementContractUsage(userId: number): Promise<void> {
    const usage = await this.getOrCreateCurrentMonth(userId);
    usage.incrementContract();
    await this.usageRepository.save(usage);
  }

  /**
   * 포인트 사용 카운트 증가
   */
  async incrementPointsSpent(userId: number, amount: number): Promise<void> {
    const usage = await this.getOrCreateCurrentMonth(userId);
    usage.incrementPointsSpent(amount);
    await this.usageRepository.save(usage);
  }

  /**
   * 사용자 통계 조회
   */
  async getUserStats(userId: number): Promise<{
    currentMonth: {
      contractsCreated: number;
      pointsEarned: number;
      pointsSpent: number;
      checkinCount: number;
      lastCheckinDate: Date | null;
    };
    recentMonths: Array<{
      yearMonth: string;
      contractsCreated: number;
      pointsEarned: number;
      pointsSpent: number;
    }>;
  }> {
    const currentMonthUsage = await this.getOrCreateCurrentMonth(userId);
    const recentMonths = await this.getRecentMonths(userId, 6);

    return {
      currentMonth: {
        contractsCreated: currentMonthUsage.contractsCreated,
        pointsEarned: currentMonthUsage.pointsEarned,
        pointsSpent: currentMonthUsage.pointsSpent,
        checkinCount: currentMonthUsage.checkinCount,
        lastCheckinDate: currentMonthUsage.lastCheckinDate || null,
      },
      recentMonths: recentMonths.map((usage) => ({
        yearMonth: usage.getYearMonth(),
        contractsCreated: usage.contractsCreated,
        pointsEarned: usage.pointsEarned,
        pointsSpent: usage.pointsSpent,
      })),
    };
  }

  /**
   * 월별 리셋 (크론 작업용 - 매월 1일 실행)
   * 참고: 이제 리셋할 필요 없음. 데이터 누적 보관.
   * 다만 새 월이 시작되면 자동으로 새 레코드 생성됨.
   */
  async createNewMonthRecordsIfNeeded(): Promise<number> {
    // 모든 활성 사용자의 이번 달 레코드 생성
    // 이미 있으면 스킵됨 (getOrCreateCurrentMonth)
    // 실제로는 필요 시 자동 생성되므로 이 메서드는 선택사항
    return 0;
  }
}
