import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';
import { TemplateFormSchema } from '../templates/template-form.types';

async function updateTemplate1Signatures() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const templatesService = app.get(TemplatesService);

  const templateId = 1;

  console.log('\n🔄 템플릿 ID 1 서명 필드 추가 중...\n');

  try {
    const template = await templatesService.findOne(templateId);

    if (!template || !template.formSchema) {
      console.error(`❌ 템플릿 ID ${templateId}의 formSchema를 찾을 수 없습니다.`);
      await app.close();
      process.exit(1);
    }

    console.log(`📋 템플릿 정보:`);
    console.log(`   이름: ${template.name}`);
    console.log(`   카테고리: ${template.category}`);
    console.log('');

    const currentSchema = template.formSchema as TemplateFormSchema;

    // 새로운 서명 섹션 추가
    const signatureSection = {
      id: 'signatures',
      title: '서명',
      role: 'all' as const,
      fields: [
        {
          id: 'employerSignature',
          label: '고용주 서명',
          type: 'signature' as const,
          role: 'author' as const,
          required: true,
        },
        {
          id: 'employerSignDate',
          label: '고용주 서명일',
          type: 'date' as const,
          role: 'author' as const,
          readonly: true,
          helperText: '서명 시 자동으로 기록됩니다.',
        },
        {
          id: 'employeeSignature',
          label: '근로자 서명',
          type: 'signature' as const,
          role: 'recipient' as const,
          required: true,
        },
        {
          id: 'employeeSignDate',
          label: '근로자 서명일',
          type: 'date' as const,
          role: 'recipient' as const,
          readonly: true,
          helperText: '서명 시 자동으로 기록됩니다.',
        },
      ],
    };

    // 기존 스키마에 서명 섹션 추가
    const updatedSchema = {
      ...currentSchema,
      sections: [...(currentSchema.sections || []), signatureSection],
    };

    console.log('🔧 추가될 서명 섹션:');
    console.log(JSON.stringify(signatureSection, null, 2));
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

updateTemplate1Signatures();
