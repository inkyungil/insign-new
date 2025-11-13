import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";

async function alterContractMailLogs() {
  console.log("🔧 contract_mail_logs.recipient_email 컬럼 확장 시작...\n");

  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  try {
    await dataSource.query(
      `ALTER TABLE contract_mail_logs MODIFY COLUMN recipient_email VARCHAR(255) NULL`,
    );
    console.log("✅ recipient_email 컬럼이 VARCHAR(255)로 확장되었습니다.\n");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn("⚠️  recipient_email 컬럼 변경 생략:", message);
  } finally {
    await app.close();
  }

  console.log("✨ 스키마 변경 완료");
}

alterContractMailLogs()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 스크립트 실패:", error);
    process.exit(1);
  });
