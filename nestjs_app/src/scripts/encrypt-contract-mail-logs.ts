import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";
import { EncryptionService } from "../common/encryption.service";
import { ContractMailLog } from "../contracts/contract-mail-log.entity";

async function encryptContractMailLogs() {
  console.log("🔐 contract_mail_logs.recipient_email 암호화 시작...\n");

  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);
  const encryptionService = app.get(EncryptionService);

  try {
    const repository = dataSource.getRepository(ContractMailLog);
    const logs = await repository.find();
    console.log(`📊 총 ${logs.length}건의 메일 로그를 찾았습니다.\n`);

    let encrypted = 0;
    let skipped = 0;
    let errors = 0;

    for (const log of logs) {
      try {
        if (!log.recipientEmail) {
          skipped++;
          continue;
        }

        if (log.recipientEmail.includes(":")) {
          skipped++;
          continue;
        }

        log.recipientEmail = encryptionService.encrypt(log.recipientEmail);
        await repository.save(log);
        encrypted++;
      } catch (error) {
        errors++;
        console.error(
          `❌ 메일 로그 #${log.id} 처리 실패:`,
          error instanceof Error ? error.message : error,
        );
      }
    }

    console.log("\n" + "=".repeat(60));
    console.log("📋 메일 로그 암호화 결과");
    console.log(`   ✅ 새로 암호화: ${encrypted}건`);
    console.log(`   ⏭️  이미 암호화/빈값: ${skipped}건`);
    console.log(`   ❌ 오류: ${errors}건`);
    console.log("=".repeat(60));
  } catch (error) {
    console.error("❌ 암호화 스크립트 실패:", error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

encryptContractMailLogs()
  .then(() => {
    console.log("\n✨ 스크립트 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 스크립트 실패:", error);
    process.exit(1);
  });
