import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';
import { TemplateFormSchema } from '../templates/template-form.types';

async function updateTemplate5() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const templatesService = app.get(TemplatesService);

  const templateId = 5;

  console.log('\n🔄 템플릿 ID 5 업데이트 시작...\n');

  try {
    const template = await templatesService.findOne(templateId);

    if (!template || !template.formSchema) {
      console.error(`❌ 템플릿 ID ${templateId}의 formSchema를 찾을 수 없습니다.`);
      await app.close();
      process.exit(1);
    }

    // 백업 출력
    console.log('📦 현재 formSchema 백업:');
    console.log(JSON.stringify(template.formSchema, null, 2));
    console.log('\n============================================================\n');

    const currentSchema = template.formSchema as TemplateFormSchema;

    // 새로운 서명 섹션 추가
    const signatureSection = {
      id: 'signatures',
      title: '서명',
      role: 'all' as const,
      fields: [
        {
          id: 'clientSignature',
          label: '의뢰인 서명',
          type: 'signature' as const,
          role: 'author' as const,
          required: true,
        },
        {
          id: 'clientSignatureDate',
          label: '의뢰인 서명일',
          type: 'date' as const,
          role: 'author' as const,
        },
        {
          id: 'performerSignature',
          label: '수행자 서명',
          type: 'signature' as const,
          role: 'recipient' as const,
          required: true,
        },
        {
          id: 'employeeSignatureDate',
          label: '수행자 서명일',
          type: 'date' as const,
          role: 'recipient' as const,
        },
      ],
    };

    // 기존 스키마에 서명 섹션 추가
    const updatedSchema = {
      ...currentSchema,
      sections: [...(currentSchema.sections || []), signatureSection],
    };

    console.log('🔧 업데이트할 formSchema:');
    console.log(JSON.stringify(updatedSchema, null, 2));
    console.log('\n============================================================\n');

    // 업데이트 실행
    await templatesService.updateTemplate(templateId, {
      name: template.name,
      category: template.category,
      description: template.description,
      formSchema: updatedSchema,
    });

    console.log('✅ 템플릿 업데이트 완료!\n');

    // 검증
    console.log('🔍 업데이트 검증 중...\n');
    const updatedTemplate = await templatesService.findOne(templateId);
    if (updatedTemplate && updatedTemplate.formSchema) {
      const validation = templatesService.validateTemplatePlaceholders(
        updatedTemplate.content,
        updatedTemplate.formSchema,
      );

      console.log('============================================================');
      console.log('📊 검증 결과');
      console.log('============================================================');

      if (validation.valid) {
        console.log('✅ 모든 플레이스홀더가 올바르게 정의되어 있습니다!');
      } else {
        console.log('❌ 여전히 문제가 있습니다:');
        console.log(`   누락된 필드: ${validation.missingFields?.join(', ')}`);
      }
      console.log('============================================================\n');
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }

  await app.close();
}

updateTemplate5();
