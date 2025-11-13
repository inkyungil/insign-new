import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";
import { EncryptionService } from "../common/encryption.service";
import { User } from "../users/user.entity";
import { hashEmail, normalizeEmail } from "../users/email.utils";

async function encryptUserEmails() {
  console.log("🔐 users.email 암호화 마이그레이션 시작...\n");

  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);
  const encryptionService = app.get(EncryptionService);

  try {
    const userRepository = dataSource.getRepository(User);
    const users = await userRepository.find();
    console.log(`📊 총 ${users.length}명의 사용자를 찾았습니다.\n`);

    let updated = 0;
    let skipped = 0;
    let errors = 0;

    for (const user of users) {
      try {
        if (!user.email) {
          skipped++;
          continue;
        }

        let normalizedEmail: string | null = null;
        let needsUpdate = false;

        if (user.email.includes(":")) {
          try {
            normalizedEmail = normalizeEmail(
              encryptionService.decrypt(user.email),
            );
          } catch (error) {
            console.warn(
              `⚠️  사용자 #${user.id}: 이메일 복호화 실패, 건너뜀 (${error instanceof Error ? error.message : error})`,
            );
            skipped++;
            continue;
          }
        } else {
          normalizedEmail = normalizeEmail(user.email);
          user.email = encryptionService.encrypt(normalizedEmail);
          needsUpdate = true;
        }

        const emailHash = hashEmail(normalizedEmail);
        if (user.emailHash !== emailHash) {
          user.emailHash = emailHash;
          needsUpdate = true;
        }

        if (needsUpdate) {
          await userRepository.save(user);
          updated++;
          console.log(`✅ 사용자 #${user.id} 암호화/해시 갱신 완료`);
        } else {
          skipped++;
        }
      } catch (error) {
        errors++;
        console.error(`❌ 사용자 #${user.id} 처리 중 오류:`, error);
      }
    }

    console.log("\n" + "=".repeat(70));
    console.log("📋 사용자 이메일 암호화 결과");
    console.log(`   ✅ 업데이트: ${updated}명`);
    console.log(`   ⏭️  변경 없음: ${skipped}명`);
    console.log(`   ❌ 오류: ${errors}명`);
    console.log("=".repeat(70));
  } catch (error) {
    console.error("❌ 마이그레이션 실패:", error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

encryptUserEmails()
  .then(() => {
    console.log("\n✨ 스크립트 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 스크립트 실패:", error);
    process.exit(1);
  });
