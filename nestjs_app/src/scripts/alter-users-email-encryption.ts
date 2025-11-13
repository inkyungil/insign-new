import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";

function formatError(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

async function alterUsersEmailSchema() {
  console.log("🔧 users.email 암호화를 위한 스키마 변경 시작...\n");

  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  try {
    console.log("1️⃣ email 컬럼 길이 확장 (VARCHAR(255))");
    await dataSource.query(
      `ALTER TABLE users MODIFY COLUMN email VARCHAR(255) NOT NULL`,
    );
    console.log("   ✅ email 컬럼 변경 완료\n");
  } catch (error) {
    console.warn("   ⚠️ email 컬럼 변경 생략:", formatError(error));
  }

  try {
    console.log("2️⃣ email_hash 컬럼 추가 (CHAR(64))");
    await dataSource.query(
      `ALTER TABLE users ADD COLUMN email_hash CHAR(64) NULL AFTER email`,
    );
    console.log("   ✅ email_hash 컬럼 추가 완료\n");
  } catch (error) {
    console.warn("   ⚠️ email_hash 컬럼 추가 생략:", formatError(error));
  }

  try {
    console.log("3️⃣ 기존 데이터의 email_hash 채우기");
    await dataSource.query(
      `UPDATE users SET email_hash = LOWER(SHA2(LOWER(TRIM(email)), 256)) WHERE email IS NOT NULL AND (email_hash IS NULL OR email_hash = '')`,
    );
    console.log("   ✅ email_hash 값 채우기 완료\n");
  } catch (error) {
    console.warn("   ⚠️ email_hash 업데이트 생략:", formatError(error));
  }

  try {
    console.log("4️⃣ email_hash 컬럼 NOT NULL 지정");
    await dataSource.query(
      `ALTER TABLE users MODIFY COLUMN email_hash CHAR(64) NOT NULL`,
    );
    console.log("   ✅ email_hash NOT NULL 적용\n");
  } catch (error) {
    console.warn("   ⚠️ email_hash NOT NULL 적용 생략:", formatError(error));
  }

  try {
    console.log("5️⃣ email_hash 유니크 인덱스 생성");
    await dataSource.query(
      `CREATE UNIQUE INDEX idx_users_email_hash ON users (email_hash)`,
    );
    console.log("   ✅ 유니크 인덱스 생성 완료\n");
  } catch (error) {
    console.warn("   ⚠️ 유니크 인덱스 생성 생략:", formatError(error));
  }

  console.log("=".repeat(60));
  console.log("✅ users 테이블 스키마 변경 완료");
  console.log("=".repeat(60));

  await app.close();
}

alterUsersEmailSchema()
  .then(() => {
    console.log("\n✨ 스크립트 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 스크립트 실패:", error);
    process.exit(1);
  });
