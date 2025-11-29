import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PointsLedger, TransactionType } from './entities/points-ledger.entity';

@Injectable()
export class PointsService {
  constructor(
    @InjectRepository(PointsLedger)
    private readonly ledgerRepository: Repository<PointsLedger>,
  ) {}

  /**
   * 사용자의 현재 포인트 잔액 조회
   */
  async getBalance(userId: number): Promise<number> {
    const result = await this.ledgerRepository
      .createQueryBuilder('ledger')
      .select('SUM(ledger.amount)', 'balance')
      .where('ledger.userId = :userId', { userId })
      .andWhere('ledger.isExpired = FALSE')
      .getRawOne();

    return result?.balance || 0;
  }

  /**
   * 포인트 적립
   */
  async earn(params: {
    userId: number;
    type: TransactionType;
    amount: number;
    description: string;
    expiresInDays?: number;
    referenceType?: string;
    referenceId?: number;
  }): Promise<PointsLedger> {
    const currentBalance = await this.getBalance(params.userId);
    const newBalance = currentBalance + params.amount;

    // 만료일 계산 (기본 1년)
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + (params.expiresInDays || 365));

    const ledger = this.ledgerRepository.create({
      userId: params.userId,
      transactionType: params.type,
      amount: params.amount,
      balanceAfter: newBalance,
      description: params.description,
      expiresAt,
      referenceType: params.referenceType,
      referenceId: params.referenceId,
      isExpired: false,
    });

    return this.ledgerRepository.save(ledger);
  }

  /**
   * 포인트 사용
   */
  async spend(params: {
    userId: number;
    type: TransactionType;
    amount: number;
    description: string;
    referenceType?: string;
    referenceId?: number;
  }): Promise<PointsLedger> {
    const currentBalance = await this.getBalance(params.userId);

    if (currentBalance < params.amount) {
      throw new BadRequestException(
        `포인트가 부족합니다. (현재: ${currentBalance}, 필요: ${params.amount})`,
      );
    }

    const newBalance = currentBalance - params.amount;

    const ledger = this.ledgerRepository.create({
      userId: params.userId,
      transactionType: params.type,
      amount: -params.amount, // 음수로 저장
      balanceAfter: newBalance,
      description: params.description,
      referenceType: params.referenceType,
      referenceId: params.referenceId,
      isExpired: false,
    });

    return this.ledgerRepository.save(ledger);
  }

  /**
   * 거래 내역 조회
   */
  async getHistory(
    userId: number,
    limit = 50,
    offset = 0,
  ): Promise<PointsLedger[]> {
    return this.ledgerRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
  }

  /**
   * 출석 체크 기록 조회 - 한국 시간 기준 날짜 문자열 반환
   */
  async getCheckInHistory(
    userId: number,
    year: number,
    month: number,
  ): Promise<string[]> {
    const checkIns = await this.ledgerRepository
      .createQueryBuilder('ledger')
      .select("DATE_FORMAT(ledger.createdAt, '%Y-%m-%d')", 'checkInDate')
      .where('ledger.userId = :userId', { userId })
      .andWhere('ledger.transactionType = :type', {
        type: TransactionType.EARN_CHECKIN,
      })
      .andWhere('YEAR(ledger.createdAt) = :year', { year })
      .andWhere('MONTH(ledger.createdAt) = :month', { month })
      .orderBy('ledger.createdAt', 'ASC')
      .getRawMany();

    console.log('🔍 getRawMany 결과:', checkIns);

    // 날짜 문자열로 반환 (YYYY-MM-DD)
    const result = checkIns.map((row) => row.checkInDate);
    console.log('📅 변환된 날짜 배열:', result);

    return result;
  }

  /**
   * 만료 예정 포인트 조회
   */
  async getExpiringPoints(
    userId: number,
    withinDays = 30,
  ): Promise<PointsLedger[]> {
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + withinDays);

    return this.ledgerRepository
      .createQueryBuilder('ledger')
      .where('ledger.userId = :userId', { userId })
      .andWhere('ledger.amount > 0') // 적립만
      .andWhere('ledger.isExpired = FALSE')
      .andWhere('ledger.expiresAt IS NOT NULL')
      .andWhere('ledger.expiresAt <= :endDate', { endDate })
      .orderBy('ledger.expiresAt', 'ASC')
      .getMany();
  }

  /**
   * 만료된 포인트 처리 (크론 작업용)
   */
  async expireOldPoints(): Promise<number> {
    const now = new Date();

    const expiredLedgers = await this.ledgerRepository
      .createQueryBuilder('ledger')
      .where('ledger.amount > 0') // 적립만
      .andWhere('ledger.isExpired = FALSE')
      .andWhere('ledger.expiresAt IS NOT NULL')
      .andWhere('ledger.expiresAt < :now', { now })
      .getMany();

    if (expiredLedgers.length === 0) {
      return 0;
    }

    // 만료 처리
    for (const ledger of expiredLedgers) {
      ledger.isExpired = true;
      await this.ledgerRepository.save(ledger);

      // 만료 기록 추가 (선택사항)
      const currentBalance = await this.getBalance(ledger.userId);
      await this.ledgerRepository.save(
        this.ledgerRepository.create({
          userId: ledger.userId,
          transactionType: TransactionType.EXPIRE,
          amount: -ledger.amount,
          balanceAfter: currentBalance - ledger.amount,
          description: `포인트 만료 (적립일: ${ledger.createdAt.toISOString().split('T')[0]})`,
          referenceType: 'points_ledger',
          referenceId: ledger.id,
          isExpired: false,
        }),
      );
    }

    return expiredLedgers.length;
  }

  /**
   * 포인트 통계
   */
  async getStatistics(userId: number): Promise<{
    currentBalance: number;
    totalEarned: number;
    totalSpent: number;
    totalExpired: number;
    expiringWithin30Days: number;
  }> {
    const currentBalance = await this.getBalance(userId);

    // 총 적립
    const earnedResult = await this.ledgerRepository
      .createQueryBuilder('ledger')
      .select('SUM(ledger.amount)', 'total')
      .where('ledger.userId = :userId', { userId })
      .andWhere('ledger.amount > 0')
      .andWhere(
        'ledger.transactionType NOT IN (:...excludeTypes)',
        { excludeTypes: [TransactionType.EXPIRE, TransactionType.REFUND] },
      )
      .getRawOne();

    // 총 사용
    const spentResult = await this.ledgerRepository
      .createQueryBuilder('ledger')
      .select('SUM(ABS(ledger.amount))', 'total')
      .where('ledger.userId = :userId', { userId })
      .andWhere('ledger.amount < 0')
      .andWhere('ledger.transactionType NOT IN (:...excludeTypes)', {
        excludeTypes: [TransactionType.EXPIRE],
      })
      .getRawOne();

    // 총 만료
    const expiredResult = await this.ledgerRepository
      .createQueryBuilder('ledger')
      .select('SUM(ABS(ledger.amount))', 'total')
      .where('ledger.userId = :userId', { userId })
      .andWhere('ledger.transactionType = :type', {
        type: TransactionType.EXPIRE,
      })
      .getRawOne();

    // 30일 내 만료 예정
    const expiringPoints = await this.getExpiringPoints(userId, 30);
    const expiringSum = expiringPoints.reduce(
      (sum, ledger) => sum + ledger.amount,
      0,
    );

    return {
      currentBalance,
      totalEarned: earnedResult?.total || 0,
      totalSpent: spentResult?.total || 0,
      totalExpired: expiredResult?.total || 0,
      expiringWithin30Days: expiringSum,
    };
  }
}
