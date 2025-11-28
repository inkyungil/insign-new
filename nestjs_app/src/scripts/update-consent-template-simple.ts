import { DataSource } from "typeorm";
import { Template } from "../templates/template.entity";
import { TemplateFormSchema } from "../templates/template-form.types";
import * as dotenv from "dotenv";
import * as path from "path";

// .env 파일 로드
dotenv.config({ path: path.join(__dirname, "../../.env") });

/**
 * 성관계 동의서 템플릿 단순화 버전
 * - 이메일 인증으로 당사자 확인
 * - 필수 체크박스만 포함
 * - 서명만 받고 완료
 */
async function updateConsentTemplateSimple() {
  console.log("🔧 Database configuration:");
  console.log(`   Host: ${process.env.DB_HOST}`);
  console.log(`   Port: ${process.env.DB_PORT}`);
  console.log(`   Username: ${process.env.DB_USERNAME}`);
  console.log(`   Database: ${process.env.DB_NAME}`);

  const dataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 3306,
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME || "insign",
    entities: [Template],
  });

  await dataSource.initialize();
  console.log("✅ Database connected");

  const templateRepo = dataSource.getRepository(Template);

  const now = new Date();

  // 단순화된 폼 스키마 - 필수 항목만!
  const formSchema: TemplateFormSchema = {
    version: 2,
    title: "성관계 동의서 (간편 작성)",
    description:
      "이메일 인증 후 필수 동의 체크박스와 서명만으로 간편하게 작성할 수 있습니다.",
    sections: [
      {
        id: "contract-meta",
        title: "계약 개요",
        role: "author",
        fields: [
          {
            id: "contractDate",
            label: "동의서 작성일",
            type: "date",
            role: "author",
            required: true,
          },
        ],
      },
      {
        id: "party-a-info",
        title: "갑(제1당사자) 정보",
        role: "author",
        description: "작성자(갑)의 기본 정보입니다. 이메일 인증으로 확인됩니다.",
        fields: [
          {
            id: "clientName",
            label: "성명",
            type: "text",
            role: "author",
            required: true,
          },
          {
            id: "clientEmail",
            label: "이메일",
            type: "email",
            role: "author",
            required: true,
            helperText: "이메일 인증이 필요합니다.",
          },
          {
            id: "clientContact",
            label: "연락처",
            type: "phone",
            role: "author",
            required: true,
          },
        ],
      },
      {
        id: "party-b-info",
        title: "을(제2당사자) 정보",
        role: "recipient",
        description:
          "상대방(을)의 기본 정보입니다. 이메일 인증으로 확인됩니다.",
        fields: [
          {
            id: "performerName",
            label: "성명",
            type: "text",
            role: "recipient",
            required: true,
          },
          {
            id: "performerEmail",
            label: "이메일",
            type: "email",
            role: "recipient",
            required: true,
            helperText: "이메일 인증이 필요합니다.",
          },
          {
            id: "performerContact",
            label: "연락처",
            type: "phone",
            role: "recipient",
            required: true,
          },
        ],
      },
      {
        id: "consent-agreements",
        title: "필수 동의 사항",
        role: "all",
        description:
          "성인 간 성관계 동의를 위한 필수 체크 항목입니다. 모두 동의해야 합니다.",
        fields: [
          {
            id: "recordingProhibition",
            label: "촬영·녹음 금지 동의",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: false,
            helperText:
              "양 당사자는 상대방의 사전 명시적 동의 없이 사진, 동영상, 음성 녹음 등 일체의 기록물 생성을 금지하는 데 동의합니다.",
          },
          {
            id: "dataUsageProhibition",
            label: "자료 유출 및 사용 금지 동의",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: false,
            helperText:
              "본 동의서와 관련된 모든 정보를 제3자에게 공개, 유출, 배포하는 것을 금지하는 데 동의합니다.",
          },
          {
            id: "voluntaryConsent",
            label: "자발적 동의 확인",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: false,
            helperText:
              "양 당사자는 어떠한 강압이나 협박 없이 자유로운 의사로 본 동의서에 서명함을 확인합니다.",
          },
          {
            id: "withdrawalRight",
            label: "철회권 인정",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: false,
            helperText:
              "양 당사자는 언제든지 동의를 철회할 수 있는 권리가 있음을 인정합니다.",
          },
        ],
      },
      {
        id: "signatures",
        title: "서명",
        role: "all",
        description: "양 당사자의 서명으로 동의서가 완성됩니다.",
        fields: [
          {
            id: "authorSignature",
            label: "갑(제1당사자) 서명",
            type: "signature",
            role: "author",
            required: true,
          },
          {
            id: "authorSignDate",
            label: "갑 서명일",
            type: "date",
            role: "author",
            readonly: true,
            helperText: "서명 시 자동으로 기록됩니다.",
          },
          {
            id: "performerSignature",
            label: "을(제2당사자) 서명",
            type: "signature",
            role: "recipient",
            required: true,
          },
          {
            id: "performerSignDate",
            label: "을 서명일",
            type: "date",
            role: "recipient",
            readonly: true,
            helperText: "서명 시 자동으로 기록됩니다.",
          },
        ],
      },
    ],
  };

  // 단순화된 HTML 템플릿 - 체크박스 결과만 표시
  const content = `
<div class="contract-page" style="width:794px;margin:0 auto;font-family:'Pretendard','Noto Sans KR',sans-serif;color:#1b2733;font-size:13px;line-height:1.7;">
  <style>
    .field-blank {
      display: inline-block;
      min-width: 140px;
      padding: 0 8px;
      border-bottom: 1px solid #1b2733;
      text-align: center;
      font-weight: 600;
    }
    .field-blank.small {
      min-width: 100px;
    }
    .section-title {
      font-size: 15px;
      color: #0b3954;
      margin: 18px 0 10px;
      border-left: 4px solid #0b3954;
      padding-left: 8px;
      font-weight: 600;
    }
    .clause {
      margin-bottom: 12px;
      line-height: 1.8;
    }
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
      width: 24%;
      background: #f3f5f9;
      text-align: left;
      font-weight: 600;
    }
    .warning-box {
      background: #fff3cd;
      border: 2px solid #ffc107;
      border-radius: 6px;
      padding: 14px;
      margin: 18px 0;
    }
    .warning-box strong {
      color: #856404;
      display: block;
      margin-bottom: 6px;
    }
    .prohibition-box {
      background: #f8d7da;
      border: 2px solid #dc3545;
      border-radius: 6px;
      padding: 14px;
      margin: 18px 0;
    }
    .prohibition-box strong {
      color: #721c24;
      display: block;
      margin-bottom: 8px;
      font-size: 14px;
    }
    .agreement-list {
      background: #e7f3ff;
      border: 2px solid #0b3954;
      border-radius: 6px;
      padding: 16px;
      margin: 18px 0;
    }
    .agreement-list .agreement-item {
      padding: 10px 0;
      border-bottom: 1px solid #d4d9e2;
      font-size: 13px;
      line-height: 1.7;
    }
    .agreement-list .agreement-item:last-child {
      border-bottom: none;
    }
    .agreement-list .check-mark {
      display: inline-block;
      width: 20px;
      height: 20px;
      background: #28a745;
      color: white;
      text-align: center;
      line-height: 20px;
      border-radius: 3px;
      margin-right: 8px;
      font-weight: bold;
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
    }
  </style>

  <header style="text-align:center;padding:20px 10px 14px;border-bottom:3px solid #0b3954;">
    <h1 style="margin:0;font-size:26px;letter-spacing:0.16em;color:#0b3954;">성인 간 성관계 동의서</h1>
    <p style="margin:8px 0 0;font-size:13px;color:#5c6b7a;">상호 존중과 명확한 합의를 바탕으로 한 동의 문서</p>
  </header>

  <section style="padding:18px 12px 0;">
    <div class="warning-box">
      <strong>⚠️ 중요 고지사항</strong>
      <p style="margin:0;font-size:12.5px;line-height:1.6;">
        본 동의서는 <strong>만 19세 이상 성인</strong> 간의 자유롭고 명시적인 합의를 문서화하기 위한 것입니다.
        어떠한 강압, 협박, 사기 등의 부당한 방법으로 작성된 동의서는 법적 효력이 없으며,
        양 당사자는 언제든지 동의를 철회할 수 있는 권리를 가집니다.
      </p>
    </div>

    <p class="clause">
      <span class="field-blank">{{clientName}}</span> (이하 "갑"이라 함)과(와)
      <span class="field-blank">{{performerName}}</span> (이하 "을"이라 함)은
      상호 존중과 명확한 의사소통을 바탕으로 다음과 같이 동의한다.
    </p>

    <div class="section-title">제1조 (당사자 정보 및 이메일 인증)</div>
    <table class="info-table">
      <tbody>
        <tr>
          <th>갑(제1당사자)</th>
          <td>
            성명: {{clientName}}<br />
            이메일: {{clientEmail}} (인증 완료)<br />
            연락처: {{clientContact}}
          </td>
        </tr>
        <tr>
          <th>을(제2당사자)</th>
          <td>
            성명: {{performerName}}<br />
            이메일: {{performerEmail}} (인증 완료)<br />
            연락처: {{performerContact}}
          </td>
        </tr>
      </tbody>
    </table>

    <div class="section-title">제2조 (필수 동의 사항)</div>
    <div class="agreement-list">
      <div class="agreement-item">
        <span class="check-mark">✓</span>
        <strong>촬영·녹음 금지:</strong> 양 당사자는 상대방의 사전 명시적 동의 없이 사진, 동영상, 음성 녹음 등 일체의 시청각 자료를 생성하거나 보관하는 것을 절대적으로 금지합니다. 본 조항을 위반할 경우 「성폭력범죄의 처벌 등에 관한 특례법」 제14조 등 관련 법령에 따라 민·형사상 책임을 집니다.
      </div>
      <div class="agreement-item">
        <span class="check-mark">✓</span>
        <strong>자료 유출 및 사용 금지:</strong> 양 당사자는 본 동의서와 관련된 모든 정보를 제3자에게 공개, 유출, 배포하지 않으며, 상대방의 개인정보를 보호할 의무가 있습니다.
      </div>
      <div class="agreement-item">
        <span class="check-mark">✓</span>
        <strong>자발적 동의:</strong> 양 당사자는 어떠한 강압, 협박, 사기, 기망 없이 자유로운 의사로 본 동의서에 서명하며, 성인(만 19세 이상)임을 확인합니다.
      </div>
      <div class="agreement-item">
        <span class="check-mark">✓</span>
        <strong>철회권 인정:</strong> 양 당사자는 언제든지 구두 또는 서면으로 동의를 철회할 수 있는 권리가 있으며, 상대방은 이를 즉시 존중해야 합니다.
      </div>
    </div>

    <div class="section-title">제3조 (기타 조항)</div>
    <div class="clause">
      <p style="margin:0 0 8px;"><strong>1. 개인정보 보호:</strong> 양 당사자는 상대방의 개인정보(성명, 이메일, 연락처 등)를 제3자에게 제공하지 않으며, 본 동의서의 존재 자체도 비밀로 유지합니다.</p>
      <p style="margin:0 0 8px;"><strong>2. 안전과 존중:</strong> 양 당사자는 안전하고 사적인 환경을 제공하며, 상호 건강 상태를 확인하고 존중합니다.</p>
      <p style="margin:0;"><strong>3. 법적 효력:</strong> 본 동의서에 명시되지 않은 사항은 민법, 형법, 성폭력처벌법 등 관련 법령에 따릅니다.</p>
    </div>
  </section>

  <section style="padding:18px 12px 20px;">
    <p style="margin:0 0 12px;text-align:right;">작성일: <span class="field-blank small">{{contractDate}}</span></p>
    <table class="signature-table">
      <tbody>
        <tr>
          <th>갑(제1당사자)</th>
          <td>
            성명: {{clientName}}<br />
            이메일: {{clientEmail}}<br />
            연락처: {{clientContact}}<br />
            서명: {{authorSignature}} / 서명일: {{authorSignDate}}
          </td>
        </tr>
        <tr>
          <th>을(제2당사자)</th>
          <td>
            성명: {{performerName}}<br />
            이메일: {{performerEmail}}<br />
            연락처: {{performerContact}}<br />
            서명: {{performerSignature}} / 서명일: {{performerSignDate}}
          </td>
        </tr>
      </tbody>
    </table>

    <div style="margin-top:20px;padding:12px;background:#e7f3ff;border:1px solid #0b3954;border-radius:4px;">
      <p style="margin:0;font-size:12px;color:#0b3954;line-height:1.6;">
        <strong>📌 법적 고지:</strong> 본 동의서는 성인 간의 자유롭고 명시적인 합의를 문서화한 것으로,
        강압, 협박, 미성년자 대상 행위 등 불법 행위를 정당화하지 않습니다.
        양 당사자는 관련 법령을 준수할 의무가 있으며, 위법 행위 시 본 동의서는 법적 효력이 없습니다.
      </p>
    </div>
  </section>
</div>
`;

  const samplePayload = {
    contractDate: "2025-11-27",
    clientName: "홍길동",
    clientEmail: "hong@example.com",
    clientContact: "010-1234-5678",
    performerName: "김영희",
    performerEmail: "kim@example.com",
    performerContact: "010-9876-5432",
    recordingProhibition: true,
    dataUsageProhibition: true,
    voluntaryConsent: true,
    withdrawalRight: true,
    authorSignature: "홍길동",
    authorSignDate: "2025-11-27",
    performerSignature: "김영희",
    performerSignDate: "2025-11-27",
  };

  const templateData = {
    name: "성인 간 성관계 동의서",
    category: "개인/권리보호",
    description:
      "이메일 인증 후 필수 체크박스와 서명만으로 간편하게 작성할 수 있는 성관계 동의서입니다. 촬영·녹음 금지, 자료 유출 금지, 자발적 동의, 철회권 인정 등 핵심 조항을 포함합니다.",
    content,
    formSchema,
    samplePayload,
    lastUpdatedAt: now,
  };

  // 기존 템플릿 찾아서 업데이트
  const existing = await templateRepo.findOne({
    where: { name: templateData.name },
  });

  if (existing) {
    console.log("✅ 기존 템플릿을 단순화된 버전으로 업데이트합니다...");
    console.log(`   ID: ${existing.id}, Name: ${existing.name}`);

    Object.assign(existing, templateData);
    await templateRepo.save(existing);
    console.log("✅ 템플릿 업데이트 완료!");
    console.log(`   - 입력 필드: 복잡한 텍스트 필드 제거 → 이메일 인증 + 체크박스만`);
    console.log(`   - 필수 체크박스: 4개 (촬영금지, 자료유출금지, 자발적동의, 철회권)`);
    console.log(`   - 서명: 갑/을 서명만`);
  } else {
    console.log("✅ 새 템플릿을 생성합니다...");
    const newTemplate = templateRepo.create(templateData);
    const saved = await templateRepo.save(newTemplate);
    console.log("✅ 템플릿 생성 완료!");
    console.log(`   ID: ${saved.id}`);
    console.log(`   Name: ${saved.name}`);
  }

  await dataSource.destroy();
  console.log("✅ Database connection closed");
}

// Run the script
updateConsentTemplateSimple()
  .then(() => {
    console.log("\n🎉 성관계 동의서 템플릿 단순화 완료!");
    console.log(
      "   이제 이메일 인증 → 체크박스 체크 → 서명 으로 간편하게 작성할 수 있습니다.",
    );
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 오류 발생:", error);
    process.exit(1);
  });
