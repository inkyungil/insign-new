import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';

async function listTemplates() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
  });
  const templatesService = app.get(TemplatesService);

  const templates = await templatesService.findAll();

  console.log('\n템플릿 목록:');
  console.log('============================================================');
  templates.forEach(t => {
    const contentLength = t.content ? t.content.length : 0;
    console.log(`ID: ${t.id} | Name: ${t.name} | Category: ${t.category} | Content: ${contentLength > 0 ? contentLength + ' chars' : 'none'}`);
  });
  console.log('============================================================\n');

  await app.close();
}

listTemplates().catch(console.error);
