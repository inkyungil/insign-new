import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";

/**
 * 암호화를 위한 DB 스키마 변경 스크립트
 *
 * 실행 방법:
 * npm run migrate:alter-schema
 */
async function alterSchemaForEncryption() {
  console.log("🔧 암호화를 위한 DB 스키마 변경 시작...\n");

  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  try {
    console.log("1️⃣ performer_contact 컬럼 크기 변경 (VARCHAR(60) → VARCHAR(255))");
    await dataSource.query(`
      ALTER TABLE contracts
      MODIFY COLUMN performer_contact VARCHAR(255) NULL
    `);
    console.log("   ✅ performer_contact 변경 완료\n");

    console.log("2️⃣ metadata 컬럼 타입 변경 (JSON → LONGTEXT)");
    await dataSource.query(`
      ALTER TABLE contracts
      MODIFY COLUMN metadata LONGTEXT NULL
    `);
    console.log("   ✅ metadata 변경 완료\n");

    console.log("=" .repeat(60));
    console.log("✅ DB 스키마 변경 완료!");
    console.log("=" .repeat(60));

    // 변경사항 확인
    const columns = await dataSource.query(`
      SHOW COLUMNS FROM contracts
      WHERE Field IN ('performer_contact', 'metadata')
    `);

    console.log("\n📋 변경된 컬럼 정보:");
    columns.forEach((col: any) => {
      console.log(`   ${col.Field}: ${col.Type} ${col.Null === 'YES' ? 'NULL' : 'NOT NULL'}`);
    });

  } catch (error) {
    console.error("❌ 스키마 변경 중 오류 발생:", error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

alterSchemaForEncryption()
  .then(() => {
    console.log("\n✨ 스크립트 완료! 이제 암호화 마이그레이션을 실행할 수 있습니다.");
    console.log("   실행: npm run migrate:encrypt-contracts\n");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 스크립트 실패:", error);
    process.exit(1);
  });
