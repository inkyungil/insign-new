import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { Repository } from 'typeorm';
import { Contract } from '../contracts/contract.entity';
import { Template } from '../templates/template.entity';
import { getRepositoryToken } from '@nestjs/typeorm';
import { EncryptionService } from '../common/encryption.service';

type MetadataRecord = Record<string, unknown>;

function isRecord(value: unknown): value is MetadataRecord {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function deserializeMetadata(
  metadata: Contract['metadata'],
  encryptionService: EncryptionService,
): MetadataRecord {
  if (!metadata) {
    return {};
  }

  if (isRecord(metadata)) {
    return { ...metadata } as MetadataRecord;
  }

  if (typeof metadata === 'string') {
    const trimmed = metadata.trim();
    // 암호화된 JSON이라면 복호화
    if (/^[0-9a-fA-F]+:[0-9a-fA-F]+:[0-9a-fA-F]+$/.test(trimmed)) {
      try {
        return (
          encryptionService.decryptJSON<MetadataRecord>(trimmed) ?? {}
        );
      } catch {
        return {};
      }
    }

    try {
      return JSON.parse(trimmed) as MetadataRecord;
    } catch {
      return {};
    }
  }

  return {};
}

/**
 * 기존 계약서들의 metadata에 templateFormSchema를 추가하는 마이그레이션 스크립트
 *
 * 실행 방법:
 * npx ts-node src/scripts/migrate-contract-templates.ts
 *
 * 또는:
 * npm run build
 * node dist/scripts/migrate-contract-templates.js
 */

async function migrateContractTemplates() {
  console.log('🚀 계약서 템플릿 마이그레이션 시작...\n');

  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const contractRepository = app.get<Repository<Contract>>(
      getRepositoryToken(Contract),
    );
    const templateRepository = app.get<Repository<Template>>(
      getRepositoryToken(Template),
    );
    const encryptionService = app.get(EncryptionService);

    // templateId가 있는 모든 계약서 조회
    const contracts = await contractRepository.find({
      where: {},
    });

    console.log(`📊 총 ${contracts.length}개의 계약서를 확인합니다.\n`);

    let updatedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;
    const errors: { contractId: number; error: string }[] = [];

    for (const contract of contracts) {
      try {
        // templateId가 없는 경우 건너뛰기
        if (!contract.templateId) {
          skippedCount++;
          console.log(
            `⏭️  계약서 #${contract.id} - templateId 없음, 건너뜀`,
          );
          continue;
        }

        // metadata에 이미 templateFormSchema가 있는 경우 건너뛰기
        const currentMetadata = deserializeMetadata(
          contract.metadata,
          encryptionService,
        );
        if (
          currentMetadata.templateFormSchema !== undefined &&
          currentMetadata.templateFormSchema !== null
        ) {
          skippedCount++;
          console.log(
            `✅ 계약서 #${contract.id} - 이미 templateFormSchema 존재, 건너뜀`,
          );
          continue;
        }

        // 템플릿 조회
        const template = await templateRepository.findOne({
          where: { id: contract.templateId },
        });

        if (!template) {
          errorCount++;
          const errorMsg = `템플릿 #${contract.templateId}을 찾을 수 없음`;
          errors.push({ contractId: contract.id, error: errorMsg });
          console.log(`❌ 계약서 #${contract.id} - ${errorMsg}`);
          continue;
        }

        // metadata 업데이트
        const updatedMetadata: MetadataRecord = {
          ...currentMetadata,
          templateFormSchema: template.formSchema ?? null,
        };

        // templateName이 없으면 추가
        if (!updatedMetadata.templateName) {
          updatedMetadata.templateName = template.name;
        }

        // templateSchemaVersion이 없고 formSchema에 version이 있으면 추가
        if (
          !updatedMetadata.templateSchemaVersion &&
          template.formSchema?.version !== undefined
        ) {
          updatedMetadata.templateSchemaVersion = template.formSchema.version;
        }

        // templateRawContent가 없고 template.content가 있으면 추가
        if (
          !updatedMetadata.templateRawContent &&
          template.content &&
          template.content.trim().length > 0
        ) {
          updatedMetadata.templateRawContent = template.content;
        }

        // 계약서 업데이트
        await contractRepository.update(contract.id, {
          metadata: encryptionService.encryptJSON(updatedMetadata),
        });

        updatedCount++;
        console.log(
          `✨ 계약서 #${contract.id} - 템플릿 "${template.name}" 스냅샷 저장 완료`,
        );
      } catch (error) {
        errorCount++;
        const errorMsg =
          error instanceof Error ? error.message : String(error);
        errors.push({ contractId: contract.id, error: errorMsg });
        console.log(`❌ 계약서 #${contract.id} - 오류: ${errorMsg}`);
      }
    }

    // 결과 요약
    console.log('\n' + '='.repeat(60));
    console.log('📈 마이그레이션 결과 요약\n');
    console.log(`총 계약서 수: ${contracts.length}`);
    console.log(`✅ 업데이트 완료: ${updatedCount}개`);
    console.log(`⏭️  건너뛴 계약서: ${skippedCount}개`);
    console.log(`❌ 오류 발생: ${errorCount}개`);
    console.log('='.repeat(60) + '\n');

    if (errors.length > 0) {
      console.log('⚠️  오류 상세 내역:\n');
      errors.forEach(({ contractId, error }) => {
        console.log(`  - 계약서 #${contractId}: ${error}`);
      });
      console.log();
    }

    if (updatedCount > 0) {
      console.log(
        '✅ 마이그레이션이 성공적으로 완료되었습니다!',
      );
      console.log(
        '   이제 기존 계약서들도 원본 템플릿 구조를 유지합니다.\n',
      );
    }
  } catch (error) {
    console.error('❌ 마이그레이션 중 치명적 오류 발생:', error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

// 스크립트 실행
migrateContractTemplates()
  .then(() => {
    console.log('🎉 프로세스 종료');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ 프로세스 오류:', error);
    process.exit(1);
  });
