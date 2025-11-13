import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";
import { EncryptionService } from "../common/encryption.service";
import { Contract } from "../contracts/contract.entity";

/**
 * 모든 개인정보 필드를 암호화하는 마이그레이션 스크립트
 * - clientContact (의뢰인 전화번호)
 * - clientEmail (의뢰인 이메일)
 * - performerEmail (수행자 이메일)
 * - performerContact (수행자 전화번호) - 이미 암호화되어 있음
 * - metadata (계약 메타데이터) - 이미 암호화되어 있음
 *
 * 실행 방법:
 * npm run migrate:encrypt-all-personal-data
 */
async function encryptAllPersonalData() {
  console.log("🔐 모든 개인정보 필드 암호화 마이그레이션 시작...\n");

  // NestJS 애플리케이션 초기화
  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);
  const encryptionService = app.get(EncryptionService);

  try {
    // 모든 계약 조회
    const contracts = await dataSource.getRepository(Contract).find();
    console.log(`📊 총 ${contracts.length}개의 계약을 찾았습니다.\n`);

    let encryptedCount = 0;
    let errorCount = 0;

    const stats = {
      clientContact: { encrypted: 0, alreadyEncrypted: 0, empty: 0 },
      clientEmail: { encrypted: 0, alreadyEncrypted: 0, empty: 0 },
      clientName: { encrypted: 0, alreadyEncrypted: 0, empty: 0 },
      performerEmail: { encrypted: 0, alreadyEncrypted: 0, empty: 0 },
      performerContact: { encrypted: 0, alreadyEncrypted: 0, empty: 0 },
      performerName: { encrypted: 0, alreadyEncrypted: 0, empty: 0 },
      metadata: { encrypted: 0, alreadyEncrypted: 0, empty: 0 },
    };

    for (const contract of contracts) {
      try {
        let needsUpdate = false;

        // clientContact 암호화
        if (contract.clientContact) {
          if (!contract.clientContact.includes(":")) {
            console.log(`[계약 ID ${contract.id}] clientContact 암호화 중...`);
            const original = contract.clientContact;
            contract.clientContact = encryptionService.encrypt(original);
            needsUpdate = true;
            stats.clientContact.encrypted++;
            console.log(`  ✅ 암호화 완료: ${original.substring(0, 5)}*** → ${contract.clientContact.substring(0, 20)}...`);
          } else {
            stats.clientContact.alreadyEncrypted++;
            console.log(`[계약 ID ${contract.id}] clientContact 이미 암호화됨 (건너뜀)`);
          }
        } else {
          stats.clientContact.empty++;
        }

        // clientEmail 암호화
        if (contract.clientEmail) {
          if (!contract.clientEmail.includes(":")) {
            console.log(`[계약 ID ${contract.id}] clientEmail 암호화 중...`);
            const original = contract.clientEmail;
            contract.clientEmail = encryptionService.encrypt(original);
            needsUpdate = true;
            stats.clientEmail.encrypted++;
            console.log(`  ✅ 암호화 완료: ${original.substring(0, 5)}*** → ${contract.clientEmail.substring(0, 20)}...`);
          } else {
            stats.clientEmail.alreadyEncrypted++;
            console.log(`[계약 ID ${contract.id}] clientEmail 이미 암호화됨 (건너뜀)`);
          }
        } else {
          stats.clientEmail.empty++;
        }

        // clientName 암호화
        if (contract.clientName) {
          if (!contract.clientName.includes(":")) {
            console.log(`[계약 ID ${contract.id}] clientName 암호화 중...`);
            const original = contract.clientName;
            contract.clientName = encryptionService.encrypt(original);
            needsUpdate = true;
            stats.clientName.encrypted++;
            console.log(
              `  ✅ 암호화 완료: ${original.substring(0, 5)}*** → ${contract.clientName.substring(0, 20)}...`,
            );
          } else {
            stats.clientName.alreadyEncrypted++;
            console.log(`[계약 ID ${contract.id}] clientName 이미 암호화됨 (건너뜀)`);
          }
        } else {
          stats.clientName.empty++;
        }

        // performerEmail 암호화
        if (contract.performerEmail) {
          if (!contract.performerEmail.includes(":")) {
            console.log(`[계약 ID ${contract.id}] performerEmail 암호화 중...`);
            const original = contract.performerEmail;
            contract.performerEmail = encryptionService.encrypt(original);
            needsUpdate = true;
            stats.performerEmail.encrypted++;
            console.log(`  ✅ 암호화 완료: ${original.substring(0, 5)}*** → ${contract.performerEmail.substring(0, 20)}...`);
          } else {
            stats.performerEmail.alreadyEncrypted++;
            console.log(`[계약 ID ${contract.id}] performerEmail 이미 암호화됨 (건너뜀)`);
          }
        } else {
          stats.performerEmail.empty++;
        }

        // performerName 암호화
        if (contract.performerName) {
          if (!contract.performerName.includes(":")) {
            console.log(`[계약 ID ${contract.id}] performerName 암호화 중...`);
            const original = contract.performerName;
            contract.performerName = encryptionService.encrypt(original);
            needsUpdate = true;
            stats.performerName.encrypted++;
            console.log(
              `  ✅ 암호화 완료: ${original.substring(0, 5)}*** → ${contract.performerName.substring(0, 20)}...`,
            );
          } else {
            stats.performerName.alreadyEncrypted++;
            console.log(`[계약 ID ${contract.id}] performerName 이미 암호화됨 (건너뜀)`);
          }
        } else {
          stats.performerName.empty++;
        }

        // performerContact 암호화 (기존 로직)
        if (contract.performerContact) {
          if (!contract.performerContact.includes(":")) {
            console.log(`[계약 ID ${contract.id}] performerContact 암호화 중...`);
            const original = contract.performerContact;
            contract.performerContact = encryptionService.encrypt(original);
            needsUpdate = true;
            stats.performerContact.encrypted++;
            console.log(`  ✅ 암호화 완료: ${original.substring(0, 5)}*** → ${contract.performerContact.substring(0, 20)}...`);
          } else {
            stats.performerContact.alreadyEncrypted++;
            console.log(`[계약 ID ${contract.id}] performerContact 이미 암호화됨 (건너뜀)`);
          }
        } else {
          stats.performerContact.empty++;
        }

        // metadata 암호화 (기존 로직)
        if (contract.metadata) {
          if (typeof contract.metadata === "object") {
            console.log(`[계약 ID ${contract.id}] metadata 암호화 중... (객체 타입)`);
            const originalMetadata = JSON.stringify(contract.metadata);
            const encryptedMeta = encryptionService.encryptJSON(contract.metadata);
            contract.metadata = encryptedMeta as unknown as Contract["metadata"];
            needsUpdate = true;
            stats.metadata.encrypted++;
            console.log(`  ✅ metadata 암호화 완료 (크기: ${originalMetadata.length} → ${String(encryptedMeta).length} bytes)`);
          } else if (typeof contract.metadata === "string") {
            const metaStr = contract.metadata as string;
            if (metaStr.trim().startsWith("{") || metaStr.trim().startsWith("[")) {
              console.log(`[계약 ID ${contract.id}] metadata 암호화 중... (JSON 문자열)`);
              try {
                const parsed = JSON.parse(metaStr);
                const encryptedMeta = encryptionService.encryptJSON(parsed);
                contract.metadata = encryptedMeta as unknown as Contract["metadata"];
                needsUpdate = true;
                stats.metadata.encrypted++;
                console.log(`  ✅ metadata 암호화 완료 (크기: ${metaStr.length} → ${String(encryptedMeta).length} bytes)`);
              } catch {
                console.log(`  ⚠️  JSON 파싱 실패, 건너뜀`);
              }
            } else if (metaStr.match(/^[0-9a-f]+:[0-9a-f]+:[0-9a-f]+/i)) {
              stats.metadata.alreadyEncrypted++;
              console.log(`[계약 ID ${contract.id}] metadata 이미 암호화됨 (건너뜀)`);
            } else {
              console.log(`[계약 ID ${contract.id}] metadata 형식 불명 (건너뜀)`);
            }
          }
        } else {
          stats.metadata.empty++;
        }

        // 변경사항이 있으면 저장
        if (needsUpdate) {
          await dataSource.getRepository(Contract).save(contract);
          encryptedCount++;
          console.log(`[계약 ID ${contract.id}] 💾 DB 저장 완료\n`);
        }
      } catch (error) {
        errorCount++;
        console.error(`[계약 ID ${contract.id}] ❌ 오류 발생:`, error);
        console.log("");
      }
    }

    // 결과 요약
    console.log("=".repeat(70));
    console.log("📋 마이그레이션 완료!\n");
    console.log(`✅ 업데이트된 계약: ${encryptedCount}개`);
    console.log(`❌ 오류 발생: ${errorCount}개`);
    console.log(`📊 전체 계약: ${contracts.length}개\n`);

    console.log("📊 필드별 암호화 통계:");
    console.log("-".repeat(70));
    console.log(`clientContact    : 새로 암호화 ${stats.clientContact.encrypted}개, 이미 암호화 ${stats.clientContact.alreadyEncrypted}개, 빈값 ${stats.clientContact.empty}개`);
    console.log(`clientEmail      : 새로 암호화 ${stats.clientEmail.encrypted}개, 이미 암호화 ${stats.clientEmail.alreadyEncrypted}개, 빈값 ${stats.clientEmail.empty}개`);
    console.log(`clientName       : 새로 암호화 ${stats.clientName.encrypted}개, 이미 암호화 ${stats.clientName.alreadyEncrypted}개, 빈값 ${stats.clientName.empty}개`);
    console.log(`performerEmail   : 새로 암호화 ${stats.performerEmail.encrypted}개, 이미 암호화 ${stats.performerEmail.alreadyEncrypted}개, 빈값 ${stats.performerEmail.empty}개`);
    console.log(`performerName    : 새로 암호화 ${stats.performerName.encrypted}개, 이미 암호화 ${stats.performerName.alreadyEncrypted}개, 빈값 ${stats.performerName.empty}개`);
    console.log(`performerContact : 새로 암호화 ${stats.performerContact.encrypted}개, 이미 암호화 ${stats.performerContact.alreadyEncrypted}개, 빈값 ${stats.performerContact.empty}개`);
    console.log(`metadata         : 새로 암호화 ${stats.metadata.encrypted}개, 이미 암호화 ${stats.metadata.alreadyEncrypted}개, 빈값 ${stats.metadata.empty}개`);
    console.log("=".repeat(70));

    // 검증: 암호화되지 않은 데이터가 남아있는지 확인
    const unencryptedClientContact = await dataSource
      .getRepository(Contract)
      .createQueryBuilder("contract")
      .where("contract.clientContact IS NOT NULL")
      .andWhere("contract.clientContact NOT LIKE '%:%'")
      .getCount();

    const unencryptedClientEmail = await dataSource
      .getRepository(Contract)
      .createQueryBuilder("contract")
      .where("contract.clientEmail IS NOT NULL")
      .andWhere("contract.clientEmail NOT LIKE '%:%'")
      .getCount();

    const unencryptedPerformerEmail = await dataSource
      .getRepository(Contract)
      .createQueryBuilder("contract")
      .where("contract.performerEmail IS NOT NULL")
      .andWhere("contract.performerEmail NOT LIKE '%:%'")
      .getCount();

    const unencryptedClientName = await dataSource
      .getRepository(Contract)
      .createQueryBuilder("contract")
      .where("contract.clientName IS NOT NULL")
      .andWhere("contract.clientName NOT LIKE '%:%'")
      .getCount();

    const unencryptedPerformerName = await dataSource
      .getRepository(Contract)
      .createQueryBuilder("contract")
      .where("contract.performerName IS NOT NULL")
      .andWhere("contract.performerName NOT LIKE '%:%'")
      .getCount();

    const unencryptedPerformerContact = await dataSource
      .getRepository(Contract)
      .createQueryBuilder("contract")
      .where("contract.performerContact IS NOT NULL")
      .andWhere("contract.performerContact NOT LIKE '%:%'")
      .getCount();

    console.log("\n🔍 최종 검증:");
    console.log("-".repeat(70));
    if (
      unencryptedClientContact > 0 ||
      unencryptedClientEmail > 0 ||
      unencryptedClientName > 0 ||
      unencryptedPerformerName > 0 ||
      unencryptedPerformerEmail > 0 ||
      unencryptedPerformerContact > 0
    ) {
      console.log("⚠️  경고: 암호화되지 않은 데이터가 남아있습니다:");
      if (unencryptedClientContact > 0) {
        console.log(`   - clientContact: ${unencryptedClientContact}개`);
      }
      if (unencryptedClientEmail > 0) {
        console.log(`   - clientEmail: ${unencryptedClientEmail}개`);
      }
      if (unencryptedClientName > 0) {
        console.log(`   - clientName: ${unencryptedClientName}개`);
      }
      if (unencryptedPerformerName > 0) {
        console.log(`   - performerName: ${unencryptedPerformerName}개`);
      }
      if (unencryptedPerformerEmail > 0) {
        console.log(`   - performerEmail: ${unencryptedPerformerEmail}개`);
      }
      if (unencryptedPerformerContact > 0) {
        console.log(`   - performerContact: ${unencryptedPerformerContact}개`);
      }
    } else {
      console.log("✅ 모든 개인정보 필드가 암호화되었습니다!");
    }
    console.log("=".repeat(70));
  } catch (error) {
    console.error("❌ 마이그레이션 중 치명적인 오류 발생:", error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

// 스크립트 실행
encryptAllPersonalData()
  .then(() => {
    console.log("\n✨ 스크립트 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 스크립트 실패:", error);
    process.exit(1);
  });
