import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';
import { TemplateFormSchema } from '../templates/template-form.types';

async function generateUpdateQuery() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const templatesService = app.get(TemplatesService);

  const templateId = 5;

  try {
    const template = await templatesService.findOne(templateId);

    if (!template || !template.formSchema) {
      console.error(`❌ 템플릿 ID ${templateId}의 formSchema를 찾을 수 없습니다.`);
      await app.close();
      process.exit(1);
    }

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

    // JSON 문자열로 변환 (MySQL에 저장하기 위해)
    const jsonString = JSON.stringify(updatedSchema);

    // SQL 쿼리 생성 (JSON 이스케이프 처리)
    const escapedJson = jsonString
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/"/g, '\\"');

    console.log('\n============================================================');
    console.log('📝 업데이트된 formSchema (미리보기):');
    console.log('============================================================\n');
    console.log(JSON.stringify(updatedSchema, null, 2));
    console.log('\n============================================================');
    console.log('💾 실행할 SQL 쿼리:');
    console.log('============================================================\n');

    // MySQL JSON 함수 사용
    const sqlQuery = `UPDATE template
SET form_schema = JSON_SET(
  form_schema,
  '$.sections[${(currentSchema.sections || []).length}]',
  JSON_OBJECT(
    'id', 'signatures',
    'title', '서명',
    'role', 'all',
    'fields', JSON_ARRAY(
      JSON_OBJECT(
        'id', 'clientSignature',
        'label', '의뢰인 서명',
        'type', 'signature',
        'role', 'author',
        'required', true
      ),
      JSON_OBJECT(
        'id', 'clientSignatureDate',
        'label', '의뢰인 서명일',
        'type', 'date',
        'role', 'author'
      ),
      JSON_OBJECT(
        'id', 'performerSignature',
        'label', '수행자 서명',
        'type', 'signature',
        'role', 'recipient',
        'required', true
      ),
      JSON_OBJECT(
        'id', 'employeeSignatureDate',
        'label', '수행자 서명일',
        'type', 'date',
        'role', 'recipient'
      )
    )
  )
)
WHERE id = ${templateId};`;

    console.log(sqlQuery);
    console.log('\n============================================================');
    console.log('⚠️  주의사항:');
    console.log('============================================================');
    console.log('1. 쿼리 실행 전 반드시 백업을 생성하세요!');
    console.log('2. 실행 후 검증 스크립트로 다시 확인하세요:');
    console.log(`   npx ts-node -r tsconfig-paths/register src/scripts/check-template.ts ${templateId}`);
    console.log('============================================================\n');

  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }

  await app.close();
}

generateUpdateQuery();
