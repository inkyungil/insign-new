import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';

async function reseedTemplates() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
  });
  const templatesService = app.get(TemplatesService);

  console.log('\n🔄 템플릿 1, 2, 3 업데이트 시작 (seedTemplates 실행)...\n');

  await templatesService.seedTemplates();

  console.log('\n✅ 템플릿 1, 2, 3 업데이트 완료!');
  console.log('   - 템플릿 1: 표준 근로계약서');
  console.log('   - 템플릿 2: 비밀유지서약서(입사자)');
  console.log('   - 템플릿 3: 일반 차용증\n');

  await app.close();
}

reseedTemplates()
  .then(() => {
    console.log('🎉 모든 템플릿이 ID 6 스타일로 업데이트되었습니다!\n');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ 오류 발생:', error);
    process.exit(1);
  });
