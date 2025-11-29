import { DataSource } from 'typeorm';
import { User } from '../users/user.entity';
import { PointsLedger } from '../points/entities/points-ledger.entity';

async function checkUserCheckIn() {
  const dataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    username: process.env.DB_USERNAME || 'insign',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'insign',
    entities: [User, PointsLedger],
    synchronize: false,
  });

  await dataSource.initialize();
  console.log('Database connected');

  const userRepo = dataSource.getRepository(User);
  const ledgerRepo = dataSource.getRepository(PointsLedger);

  // 사용자 찾기
  const user = await userRepo.findOne({
    where: { email: 'propose101@gmail.com' }
  });

  if (!user) {
    console.log('❌ 사용자를 찾을 수 없습니다: propose101@gmail.com');
    await dataSource.destroy();
    return;
  }

  console.log('\n=== 사용자 정보 ===');
  console.log('ID:', user.id);
  console.log('Email:', user.email);
  console.log('DisplayName:', user.displayName);
  console.log('마지막 출석일:', user.lastCheckInDate);
  console.log('현재 포인트:', user.points);
  console.log('이번 달 적립 포인트:', user.pointsEarnedThisMonth);

  // 출석 체크 기록 조회 (최근 30일)
  const checkIns = await ledgerRepo
    .createQueryBuilder('ledger')
    .where('ledger.userId = :userId', { userId: user.id })
    .andWhere('ledger.transactionType = :type', { type: 'earn_checkin' })
    .andWhere('ledger.createdAt >= DATE_SUB(NOW(), INTERVAL 30 DAY)')
    .orderBy('ledger.createdAt', 'DESC')
    .getMany();

  console.log('\n=== 최근 30일 출석 기록 (' + checkIns.length + '건) ===');
  if (checkIns.length === 0) {
    console.log('⚠️  출석 기록이 없습니다.');
  } else {
    checkIns.forEach((c, i) => {
      const date = new Date(c.createdAt);
      const kstDate = new Date(date.getTime() + (9 * 60 * 60 * 1000)); // KST
      const dateStr = kstDate.toISOString().split('T')[0];
      const timeStr = kstDate.toISOString().split('T')[1].substring(0, 8);
      console.log(`${i + 1}. ${dateStr} ${timeStr} (KST) - 포인트: +${c.amount}`);
    });
  }

  // 이번 달 출석 기록
  const now = new Date();
  const thisMonth = await ledgerRepo
    .createQueryBuilder('ledger')
    .where('ledger.userId = :userId', { userId: user.id })
    .andWhere('ledger.transactionType = :type', { type: 'earn_checkin' })
    .andWhere('YEAR(ledger.createdAt) = :year', { year: now.getFullYear() })
    .andWhere('MONTH(ledger.createdAt) = :month', { month: now.getMonth() + 1 })
    .orderBy('ledger.createdAt', 'ASC')
    .getMany();

  console.log(`\n=== ${now.getFullYear()}년 ${now.getMonth() + 1}월 출석 기록 (${thisMonth.length}건) ===`);
  if (thisMonth.length === 0) {
    console.log('⚠️  이번 달 출석 기록이 없습니다.');
  } else {
    thisMonth.forEach((c, i) => {
      const date = new Date(c.createdAt);
      const kstDate = new Date(date.getTime() + (9 * 60 * 60 * 1000)); // KST
      const dateStr = kstDate.toISOString().split('T')[0];
      console.log(`${i + 1}. ${dateStr}`);
    });
  }

  await dataSource.destroy();
  console.log('\n✅ 완료');
}

checkUserCheckIn().catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});
