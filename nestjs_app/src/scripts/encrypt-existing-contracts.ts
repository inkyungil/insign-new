import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";
import { EncryptionService } from "../common/encryption.service";
import { Contract } from "../contracts/contract.entity";

/**
 * 기존 계약 데이터를 암호화하는 마이그레이션 스크립트
 *
 * 실행 방법:
 * npm run migrate:encrypt-contracts
 */
async function encryptExistingContracts() {
  console.log("🔐 계약 데이터 암호화 마이그레이션 시작...\n");

  // NestJS 애플리케이션 초기화
  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);
  const encryptionService = app.get(EncryptionService);

  try {
    // 모든 계약 조회
    const contracts = await dataSource.getRepository(Contract).find();
    console.log(`📊 총 ${contracts.length}개의 계약을 찾았습니다.\n`);

    let encryptedCount = 0;
    let alreadyEncryptedCount = 0;
    let errorCount = 0;

    for (const contract of contracts) {
      try {
        let needsUpdate = false;

        // performerContact 암호화 확인
        if (contract.performerContact && !contract.performerContact.includes(":")) {
          console.log(`[계약 ID ${contract.id}] performerContact 암호화 중...`);
          const originalContact = contract.performerContact;
          contract.performerContact = encryptionService.encrypt(originalContact);
          needsUpdate = true;
          console.log(`  ✅ 암호화 완료: ${originalContact.substring(0, 5)}*** → ${contract.performerContact.substring(0, 20)}...`);
        } else if (contract.performerContact && contract.performerContact.includes(":")) {
          console.log(`[계약 ID ${contract.id}] performerContact 이미 암호화됨 (건너뜀)`);
          alreadyEncryptedCount++;
        }

        // metadata 암호화 확인
        if (contract.metadata) {
          // metadata가 객체면 평문 - 암호화 필요
          if (typeof contract.metadata === "object") {
            console.log(`[계약 ID ${contract.id}] metadata 암호화 중... (객체 타입)`);
            const originalMetadata = JSON.stringify(contract.metadata);
            const encryptedMeta = encryptionService.encryptJSON(contract.metadata);
            contract.metadata = encryptedMeta as any;
            needsUpdate = true;
            console.log(`  ✅ metadata 암호화 완료 (크기: ${originalMetadata.length} → ${String(encryptedMeta).length} bytes)`);
          } else if (typeof contract.metadata === "string") {
            const metaStr = contract.metadata as unknown as string;
            // JSON 문자열인지 확인 (평문)
            if (metaStr.trim().startsWith('{') || metaStr.trim().startsWith('[')) {
              console.log(`[계약 ID ${contract.id}] metadata 암호화 중... (JSON 문자열)`);
              try {
                const parsed = JSON.parse(metaStr);
                const encryptedMeta = encryptionService.encryptJSON(parsed);
                contract.metadata = encryptedMeta as any;
                needsUpdate = true;
                console.log(`  ✅ metadata 암호화 완료 (크기: ${metaStr.length} → ${String(encryptedMeta).length} bytes)`);
              } catch (e) {
                console.log(`  ⚠️  JSON 파싱 실패, 건너뜀`);
              }
            } else if (metaStr.match(/^[0-9a-f]+:[0-9a-f]+:[0-9a-f]+/i)) {
              // hex:hex:hex 형식이면 암호화됨
              console.log(`[계약 ID ${contract.id}] metadata 이미 암호화됨 (건너뜀)`);
            } else {
              console.log(`[계약 ID ${contract.id}] metadata 형식 불명 (건너뜀)`);
            }
          }
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
    console.log("=" .repeat(60));
    console.log("📋 마이그레이션 완료!\n");
    console.log(`✅ 새로 암호화된 계약: ${encryptedCount}개`);
    console.log(`⏭️  이미 암호화된 계약: ${alreadyEncryptedCount}개`);
    console.log(`❌ 오류 발생: ${errorCount}개`);
    console.log(`📊 전체 계약: ${contracts.length}개`);
    console.log("=" .repeat(60));

    // 검증: 암호화되지 않은 데이터가 남아있는지 확인
    const unencryptedContracts = await dataSource
      .getRepository(Contract)
      .createQueryBuilder("contract")
      .where("contract.performerContact IS NOT NULL")
      .andWhere("contract.performerContact NOT LIKE '%:%'")
      .getCount();

    if (unencryptedContracts > 0) {
      console.log(`\n⚠️  경고: ${unencryptedContracts}개의 계약에 암호화되지 않은 performerContact가 남아있습니다.`);
    } else {
      console.log("\n✅ 모든 계약 데이터가 암호화되었습니다!");
    }
  } catch (error) {
    console.error("❌ 마이그레이션 중 치명적인 오류 발생:", error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

// 스크립트 실행
encryptExistingContracts()
  .then(() => {
    console.log("\n✨ 스크립트 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 스크립트 실패:", error);
    process.exit(1);
  });
