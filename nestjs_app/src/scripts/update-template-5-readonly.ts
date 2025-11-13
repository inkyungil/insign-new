import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';
import { TemplateFormSchema } from '../templates/template-form.types';

async function updateTemplate5Readonly() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const templatesService = app.get(TemplatesService);

  const templateId = 5;

  console.log('\n🔄 템플릿 ID 5 서명일 필드를 readonly로 업데이트...\n');

  try {
    const template = await templatesService.findOne(templateId);

    if (!template || !template.formSchema) {
      console.error(`❌ 템플릿 ID ${templateId}의 formSchema를 찾을 수 없습니다.`);
      await app.close();
      process.exit(1);
    }

    const currentSchema = template.formSchema as TemplateFormSchema;

    // 서명 섹션 찾기
    const updatedSections = currentSchema.sections.map((section) => {
      if (section.id === 'signatures') {
        // 서명일 필드에 readonly: true 추가
        const updatedFields = section.fields.map((field) => {
          if (field.id === 'clientSignatureDate' || field.id === 'employeeSignatureDate') {
            console.log(`✅ ${field.id} 필드를 readonly로 설정`);
            return {
              ...field,
              readonly: true,
              helperText: '서명 시 자동으로 기록됩니다.',
            };
          }
          return field;
        });

        return {
          ...section,
          fields: updatedFields,
        };
      }
      return section;
    });

    const updatedSchema = {
      ...currentSchema,
      sections: updatedSections,
    };

    console.log('\n🔧 업데이트된 서명 섹션:');
    const signatureSection = updatedSections.find((s) => s.id === 'signatures');
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
    const updatedTemplate = await templatesService.findOne(templateId);
    if (updatedTemplate && updatedTemplate.formSchema) {
      const signSection = (updatedTemplate.formSchema as TemplateFormSchema).sections.find(
        (s) => s.id === 'signatures',
      );

      console.log('============================================================');
      console.log('📊 최종 확인');
      console.log('============================================================');

      signSection?.fields.forEach((field) => {
        const readonlyStatus = field.readonly ? '✅ readonly' : '⚪ 일반';
        console.log(`   ${field.id}: ${readonlyStatus}`);
      });

      console.log('============================================================\n');
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }

  await app.close();
}

updateTemplate5Readonly();
