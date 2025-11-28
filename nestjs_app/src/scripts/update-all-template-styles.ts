import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { TemplatesService } from '../templates/templates.service';

async function updateAllTemplateStyles() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
  });
  const templatesService = app.get(TemplatesService);

  console.log('\n🔄 템플릿 5 (기본 자유 계약서) 스타일 업데이트 시작...\n');

  // 템플릿 5 업데이트
  const template5 = await templatesService.findOne(5);

  if (!template5) {
    console.error('❌ 템플릿 5를 찾을 수 없습니다.');
    await app.close();
    return;
  }

  // 개선된 HTML 템플릿
  const improvedContent = `
<div class="contract-page" style="width:794px;margin:0 auto;font-family:'Pretendard','Noto Sans KR',sans-serif;color:#1b2733;font-size:13px;line-height:1.7;">
  <style>
    .info-table {
      width: 100%;
      border-collapse: collapse;
      margin: 18px 0;
    }
    .info-table th,
    .info-table td {
      border: 1px solid #d4d9e2;
      padding: 10px 12px;
    }
    .info-table th {
      width: 22%;
      background: #f3f5f9;
      text-align: left;
      font-weight: 600;
    }
    .signature-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 18px;
    }
    .signature-table th,
    .signature-table td {
      border: 1px solid #aeb8ca;
      padding: 10px 12px;
      vertical-align: top;
      line-height: 1.8;
    }
    .signature-table th {
      width: 22%;
      background: #f3f5f9;
      text-align: left;
      font-weight: 600;
    }
  </style>

  <header style="text-align:center;padding:20px 10px 14px;border-bottom:3px solid #0b3954;">
    <h1 style="margin:0;font-size:26px;letter-spacing:0.16em;color:#0b3954;">{{contractName}}</h1>
  </header>

  <section style="padding:18px 12px 0;">
    <table class="info-table">
      <tbody>
        <tr>
          <th>계약 내용</th>
          <td style="white-space:pre-line;">{{details}}</td>
        </tr>
      </tbody>
    </table>
  </section>

  <section style="padding:18px 12px 20px;">
    <table class="signature-table">
      <tbody>
        <tr>
          <th>갑(계약자)</th>
          <td>
            성명 : {{clientName}}<br />
            연락처 : {{clientContact}}<br />
            이메일 : {{clientEmail}}<br />
            서명 : {{clientSignature}} / 서명일 : {{clientSignatureDate}}
          </td>
        </tr>
        <tr>
          <th>을(수행자)</th>
          <td>
            성명 : {{performerName}}<br />
            연락처 : {{performerContact}}<br />
            이메일 : {{performerEmail}}<br />
            서명 : {{performerSignature}} / 서명일 : {{employeeSignatureDate}}
          </td>
        </tr>
      </tbody>
    </table>
  </section>
</div>
`;

  await templatesService.updateTemplate(5, {
    name: template5.name,
    category: template5.category,
    description: template5.description,
    content: improvedContent.trim(),
  });

  console.log('✅ 템플릿 5 업데이트 완료!');
  console.log('   - width: 794px로 통일');
  console.log('   - line-height: 1.7로 통일');
  console.log('   - 테이블 padding: 10px 12px로 통일');
  console.log('   - font-weight 추가\n');

  await app.close();
}

updateAllTemplateStyles()
  .then(() => {
    console.log('🎉 모든 템플릿 스타일 업데이트 완료!\n');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ 오류 발생:', error);
    process.exit(1);
  });
