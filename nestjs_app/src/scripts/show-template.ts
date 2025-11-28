import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';

async function showTemplate() {
  const templateId = parseInt(process.argv[2] || '5', 10);

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
  });
  const templatesService = app.get(TemplatesService);

  const template = await templatesService.findOne(templateId);

  if (!template) {
    console.error(`❌ 템플릿 ID ${templateId}를 찾을 수 없습니다.`);
    await app.close();
    return;
  }

  console.log(`\n템플릿 ID ${template.id}: ${template.name}`);
  console.log('============================================================');
  console.log('Category:', template.category);
  console.log('Description:', template.description);
  console.log('\nContent:');
  console.log('------------------------------------------------------------');
  console.log(template.content || '(no content)');
  console.log('------------------------------------------------------------\n');

  await app.close();
}

showTemplate().catch(console.error);
