import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';
import { TemplateFormSchema } from '../templates/template-form.types';

async function checkReadonlyTemplate2() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const templatesService = app.get(TemplatesService);

  const templateId = 2;

  console.log('\n🔍 템플릿 ID 2 readonly 필드 확인 중...\n');

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

    const schema = template.formSchema as TemplateFormSchema;

    console.log('🔧 필드 상세 정보:\n');
    console.log('============================================================');

    let needsUpdate = false;
    const signatureFields: string[] = [];
    const dateFields: string[] = [];

    schema.sections.forEach((section) => {
      console.log(`\n📂 섹션: ${section.title} (id: ${section.id})`);
      console.log('-----------------------------------------------------------');

      section.fields.forEach((field) => {
        const readonlyStatus = field.readonly ? '✅ readonly' : '⚪ 일반';
        const requiredStatus = field.required ? '(필수)' : '(선택)';

        console.log(`   ${field.id}:`);
        console.log(`      - 타입: ${field.type}`);
        console.log(`      - 역할: ${field.role}`);
        console.log(`      - 상태: ${readonlyStatus} ${requiredStatus}`);

        if (field.type === 'signature') {
          signatureFields.push(field.id);
        }

        if (field.type === 'date' && field.id.toLowerCase().includes('date')) {
          dateFields.push(field.id);
          if (!field.readonly) {
            console.log(`      ⚠️  서명일 필드인데 readonly가 아닙니다!`);
            needsUpdate = true;
          }
        }
      });
    });

    console.log('\n============================================================');
    console.log('📊 요약');
    console.log('============================================================');
    console.log(`서명 필드: ${signatureFields.join(', ')}`);
    console.log(`날짜 필드: ${dateFields.join(', ')}`);

    if (needsUpdate) {
      console.log('\n⚠️  서명일 필드에 readonly 설정이 필요합니다!');
    } else {
      console.log('\n✅ 모든 필드가 올바르게 설정되어 있습니다!');
    }
    console.log('============================================================\n');

  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }

  await app.close();
}

checkReadonlyTemplate2();
