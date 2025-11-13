import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';

async function checkTemplate() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const templatesService = app.get(TemplatesService);

  const templateId = parseInt(process.argv[2] || '5', 10);

  console.log(`\n🔍 템플릿 ID ${templateId} 검증 중...\n`);

  try {
    const template = await templatesService.findOne(templateId);

    if (!template) {
      console.error(`❌ 템플릿 ID ${templateId}를 찾을 수 없습니다.`);
      await app.close();
      process.exit(1);
    }

    console.log(`📋 템플릿 정보:`);
    console.log(`   이름: ${template.name}`);
    console.log(`   카테고리: ${template.category}`);
    console.log(`   설명: ${template.description}`);
    console.log(`   파일: ${template.fileName || 'N/A'}`);
    console.log('');

    // 템플릿 본문에서 플레이스홀더 추출
    const content = template.content;
    if (!content) {
      console.log('⚠️  템플릿 본문(content)이 없습니다. DOCX 파일만 있을 수 있습니다.');
      console.log('');
    } else {
      const placeholderPattern = /\{\{\s*([^}]+)\s*\}\}/g;
      const placeholders = new Set<string>();
      let match;
      while ((match = placeholderPattern.exec(content)) !== null) {
        placeholders.add(match[1].trim());
      }

      console.log(`📝 템플릿 본문에서 발견된 플레이스홀더 (${placeholders.size}개):`);
      if (placeholders.size === 0) {
        console.log('   (없음)');
      } else {
        Array.from(placeholders).sort().forEach((p) => {
          console.log(`   - {{${p}}}`);
        });
      }
      console.log('');
    }

    // formSchema에서 필드 추출
    const formSchema = template.formSchema;
    if (!formSchema) {
      console.log('⚠️  formSchema가 없습니다.');
      console.log('');
    } else {
      const schemaFieldIds = new Set<string>();
      if (formSchema.sections) {
        for (const section of formSchema.sections) {
          if (section.fields) {
            for (const field of section.fields) {
              schemaFieldIds.add(field.id);
            }
          }
        }
      }

      console.log(`🔧 formSchema에 정의된 필드 (${schemaFieldIds.size}개):`);
      if (schemaFieldIds.size === 0) {
        console.log('   (없음)');
      } else {
        Array.from(schemaFieldIds).sort().forEach((id) => {
          console.log(`   - ${id}`);
        });
      }
      console.log('');
    }

    // 검증 실행
    if (content && formSchema) {
      const validation = templatesService.validateTemplatePlaceholders(content, formSchema);

      console.log('============================================================');
      console.log('📊 검증 결과');
      console.log('============================================================');

      if (validation.valid) {
        console.log('✅ 모든 플레이스홀더가 올바르게 정의되어 있습니다!');
      } else {
        console.log('❌ 검증 실패!');
        console.log('');
        console.log('📌 템플릿 본문에는 있지만 formSchema에 없는 필드:');
        validation.missingFields?.forEach((field) => {
          console.log(`   - {{${field}}}`);
        });
        console.log('');
        console.log('💡 해결 방법:');
        console.log('   1. formSchema에 위 필드들을 추가하거나');
        console.log('   2. 템플릿 본문에서 위 플레이스홀더를 제거하세요.');
      }
      console.log('============================================================');
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }

  await app.close();
}

checkTemplate();
