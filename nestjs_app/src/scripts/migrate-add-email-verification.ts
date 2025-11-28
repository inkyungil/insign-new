/**
 * 이메일 인증 필드 추가 마이그레이션 스크립트
 *
 * 실행 방법:
 * DB_HOST=localhost DB_PORT=3306 DB_USERNAME=insign \
 * DB_PASSWORD='H./Bv!jPsH*z-[Jo' DB_NAME=insign \
 * npx ts-node -r tsconfig-paths/register src/scripts/migrate-add-email-verification.ts
 */

import { createConnection } from "typeorm";

async function main() {
  console.log("=".repeat(60));
  console.log("이메일 인증 필드 추가 마이그레이션 시작");
  console.log("=".repeat(60));

  const connection = await createConnection({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 3306,
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME || "insign",
    synchronize: false,
  });

  try {
    // 1. 컬럼 추가
    console.log("\n[1/3] 컬럼 추가 중...");

    await connection.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS is_email_verified TINYINT NOT NULL DEFAULT 0 AFTER is_active,
      ADD COLUMN IF NOT EXISTS email_verification_token VARCHAR(64) NULL AFTER is_email_verified,
      ADD COLUMN IF NOT EXISTS email_verification_token_expires_at DATETIME NULL AFTER email_verification_token
    `);

    console.log("✓ 컬럼 추가 완료");

    // 2. 기존 구글 사용자 인증 처리
    console.log("\n[2/3] 구글 사용자 이메일 인증 처리 중...");

    const googleResult = await connection.query(`
      UPDATE users
      SET is_email_verified = 1
      WHERE provider = 'google'
    `);

    console.log(
      `✓ 구글 사용자 ${googleResult.affectedRows}명 인증 처리 완료`,
    );

    // 3. 이메일 사용자 통계 출력
    console.log("\n[3/3] 이메일 사용자 통계 확인 중...");

    const [stats] = await connection.query(`
      SELECT
        COUNT(*) as total_users,
        SUM(CASE WHEN provider = 'google' THEN 1 ELSE 0 END) as google_users,
        SUM(CASE WHEN provider = 'local' THEN 1 ELSE 0 END) as local_users,
        SUM(CASE WHEN is_email_verified = 1 THEN 1 ELSE 0 END) as verified_users,
        SUM(CASE WHEN is_email_verified = 0 THEN 1 ELSE 0 END) as unverified_users
      FROM users
      WHERE is_active = 1
    `);

    console.log("\n=== 사용자 통계 ===");
    console.log(`전체 활성 사용자: ${stats[0].total_users}명`);
    console.log(`구글 사용자: ${stats[0].google_users}명 (자동 인증됨)`);
    console.log(`이메일 사용자: ${stats[0].local_users}명`);
    console.log(`인증된 사용자: ${stats[0].verified_users}명`);
    console.log(`미인증 사용자: ${stats[0].unverified_users}명`);

    if (stats[0].unverified_users > 0) {
      console.log("\n⚠️  주의: 이메일 사용자는 다음 로그인 시 이메일 인증이 필요합니다.");
    }

    console.log("\n=".repeat(60));
    console.log("✅ 마이그레이션 완료!");
    console.log("=".repeat(60));
  } catch (error) {
    console.error("\n❌ 마이그레이션 실패:", error);
    throw error;
  } finally {
    await connection.close();
  }
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
