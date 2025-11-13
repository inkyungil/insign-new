import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { DataSource } from 'typeorm';

async function createPoliciesTable() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  console.log('\n🔄 policies 테이블 생성 중...\n');

  try {
    await dataSource.query(`
      CREATE TABLE IF NOT EXISTS \`policies\` (
        \`id\` int NOT NULL AUTO_INCREMENT,
        \`type\` enum('privacy_policy','terms_of_service') NOT NULL,
        \`title\` varchar(255) NOT NULL,
        \`content\` text NOT NULL,
        \`version\` varchar(50) DEFAULT NULL,
        \`isActive\` tinyint NOT NULL DEFAULT '0',
        \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        \`updatedAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
        PRIMARY KEY (\`id\`),
        KEY \`IDX_TYPE\` (\`type\`),
        KEY \`IDX_ACTIVE\` (\`isActive\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    console.log('✅ policies 테이블 생성 완료!');

    // 샘플 데이터 확인
    const count = await dataSource.query('SELECT COUNT(*) as count FROM policies');

    if (count[0].count === 0) {
      console.log('\n📝 샘플 데이터 추가 중...\n');

      await dataSource.query(`
        INSERT INTO \`policies\` (\`type\`, \`title\`, \`content\`, \`version\`, \`isActive\`) VALUES
        ('privacy_policy', '개인정보 처리방침 v1.0', '<h1>개인정보 처리방침</h1><p>본 개인정보 처리방침은 인싸인(이하 "회사")이 제공하는 서비스를 이용하는 이용자의 개인정보를 보호하기 위하여 정보통신망 이용촉진 및 정보보호 등에 관한 법률, 개인정보보호법 등 관련 법령을 준수하고 있습니다.</p><h2>제1조 개인정보의 수집 및 이용 목적</h2><p>회사는 다음의 목적을 위하여 개인정보를 처리합니다. 처리하고 있는 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, 이용 목적이 변경되는 경우에는 개인정보보호법에 따라 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.</p><ul><li>회원 가입 및 관리</li><li>서비스 제공</li><li>고객 상담 및 불만 처리</li></ul>', '1.0', 1),
        ('terms_of_service', '이용약관 v1.0', '<h1>이용약관</h1><p>본 약관은 인싸인(이하 "회사")이 제공하는 서비스의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.</p><h2>제1조 목적</h2><p>본 약관은 회사가 제공하는 모든 서비스(이하 "서비스")의 이용조건 및 절차, 회사와 이용자 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.</p><h2>제2조 용어의 정의</h2><ul><li>"서비스"라 함은 회사가 제공하는 전자계약 및 전자서명 관련 서비스를 의미합니다.</li><li>"이용자"라 함은 본 약관에 따라 회사가 제공하는 서비스를 받는 자를 의미합니다.</li></ul>', '1.0', 1);
      `);

      console.log('✅ 샘플 데이터 추가 완료!');
      console.log('   - 개인정보 처리방침 v1.0 (활성화)');
      console.log('   - 이용약관 v1.0 (활성화)');
    } else {
      console.log(`\n✅ 이미 ${count[0].count}개의 정책이 존재합니다.`);
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }

  await app.close();
}

createPoliciesTable();
