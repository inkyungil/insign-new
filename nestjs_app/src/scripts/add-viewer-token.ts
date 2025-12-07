import { DataSource } from 'typeorm';
import { randomBytes } from 'crypto';

async function addViewerTokenColumn() {
  const dataSource = new DataSource({
    type: 'mysql',
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 3306,
    username: process.env.DB_USERNAME || 'root',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'insign',
  });

  try {
    await dataSource.initialize();
    console.log('✅ 데이터베이스 연결 성공');

    // Check if column already exists
    const checkColumnQuery = `
      SELECT COUNT(*) as count
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = ?
      AND TABLE_NAME = 'contracts_v2'
      AND COLUMN_NAME = 'viewer_token'
    `;

    const [result] = await dataSource.query(checkColumnQuery, [process.env.DB_NAME || 'insign']);

    if (result.count > 0) {
      console.log('⚠️  viewer_token 컬럼이 이미 존재합니다.');
    } else {
      // Add viewer_token column
      console.log('📝 viewer_token 컬럼 추가 중...');
      await dataSource.query(`
        ALTER TABLE contracts_v2
        ADD COLUMN viewer_token VARCHAR(128) NULL UNIQUE,
        ADD INDEX idx_viewer_token (viewer_token)
      `);
      console.log('✅ viewer_token 컬럼 추가 완료');
    }

    // Generate viewer tokens for existing contracts without one
    console.log('\n📝 기존 계약서에 viewer_token 생성 중...');

    const contracts = await dataSource.query(
      'SELECT id FROM contracts_v2 WHERE viewer_token IS NULL'
    );

    console.log(`📊 총 ${contracts.length}개의 계약서에 토큰 생성 필요`);

    for (const contract of contracts) {
      const viewerToken = randomBytes(32).toString('hex');
      await dataSource.query(
        'UPDATE contracts_v2 SET viewer_token = ? WHERE id = ?',
        [viewerToken, contract.id]
      );
    }

    console.log(`✅ ${contracts.length}개 계약서에 viewer_token 생성 완료`);
    console.log('\n✅ 마이그레이션 완료!');

  } catch (error) {
    console.error('❌ 마이그레이션 실패:', error);
    throw error;
  } finally {
    if (dataSource.isInitialized) {
      await dataSource.destroy();
    }
  }
}

addViewerTokenColumn()
  .then(() => {
    console.log('✅ 스크립트 실행 완료');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ 스크립트 실행 실패:', error);
    process.exit(1);
  });
