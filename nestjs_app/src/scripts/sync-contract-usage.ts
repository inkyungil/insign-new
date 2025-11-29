/**
 * 기존 계약 데이터를 기준으로 users.contracts_used_this_month를 동기화합니다.
 *
 * 실행 예시:
 * DB_HOST=localhost DB_PORT=3306 DB_USERNAME=root DB_PASSWORD=secret DB_NAME=insign \
 * npx ts-node -r tsconfig-paths/register src/scripts/sync-contract-usage.ts
 */

import { createConnection } from 'typeorm';

async function main() {
  console.log('='.repeat(60));
  console.log('계약 사용량 동기화 시작');
  console.log('='.repeat(60));

  const connection = await createConnection({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 3306,
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'insign',
    synchronize: false,
  });

  try {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    console.log(`대상 기간: ${monthStart.toISOString()} ~ ${monthEnd.toISOString()}`);

    const usageRows = await connection.query(
      `
      SELECT created_by_user_id AS userId, COUNT(*) AS usageCount
      FROM contracts
      WHERE created_by_user_id IS NOT NULL
        AND created_at >= ? AND created_at < ?
      GROUP BY created_by_user_id
    `,
      [monthStart, monthEnd],
    );

    console.log(`집계된 사용자 수: ${usageRows.length}`);

    console.log('users 테이블 초기화...');
    await connection.query(
      `
      UPDATE users
      SET contracts_used_this_month = 0,
          last_reset_date = ?
    `,
      [monthStart],
    );
    console.log('초기화 완료');

    for (const row of usageRows) {
      const userId = row.userId as number;
      const usageCount = Number(row.usageCount) || 0;
      await connection.query(
        `
        UPDATE users
        SET contracts_used_this_month = ?,
            last_reset_date = ?
        WHERE id = ?
      `,
        [usageCount, monthStart, userId],
      );
    }

    console.log('사용량 동기화 완료');
    console.log('='.repeat(60));
  } catch (error) {
    console.error('❌ 동기화 실패:', error);
    throw error;
  } finally {
    await connection.close();
  }
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
