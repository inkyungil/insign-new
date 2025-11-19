import { DataSource } from "typeorm";
import { Template } from "../templates/template.entity";
import { TemplateFormSchema } from "../templates/template-form.types";

async function addConsentTemplate() {
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

  const formSchema: TemplateFormSchema = {
    version: 1,
    title: "성관계 동의서 입력 항목",
    description:
      "성인 간 명확한 합의와 권리 보호를 위한 동의서 작성 시 필요한 정보를 입력합니다.",
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
        fields: [
          {
            id: "partyAName",
            label: "성명",
            type: "text",
            role: "author",
            required: true,
          },
          {
            id: "partyABirthDate",
            label: "생년월일",
            type: "date",
            role: "author",
            required: true,
            helperText: "만 19세 이상 성인만 작성 가능합니다.",
          },
          {
            id: "partyAIdNumber",
            label: "주민등록번호 뒷자리",
            type: "text",
            role: "author",
            helperText: "예: 1******",
          },
          {
            id: "partyAAddress",
            label: "주소",
            type: "text",
            role: "author",
          },
          {
            id: "partyAContact",
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
        fields: [
          {
            id: "partyBName",
            label: "성명",
            type: "text",
            role: "recipient",
            required: true,
          },
          {
            id: "partyBBirthDate",
            label: "생년월일",
            type: "date",
            role: "recipient",
            required: true,
            helperText: "만 19세 이상 성인만 작성 가능합니다.",
          },
          {
            id: "partyBIdNumber",
            label: "주민등록번호 뒷자리",
            type: "text",
            role: "recipient",
            helperText: "예: 2******",
          },
          {
            id: "partyBAddress",
            label: "주소",
            type: "text",
            role: "recipient",
          },
          {
            id: "partyBContact",
            label: "연락처",
            type: "phone",
            role: "recipient",
            required: true,
          },
        ],
      },
      {
        id: "consent-details",
        title: "동의 내용",
        role: "author",
        description: "동의하는 행위와 조건을 명확히 기재합니다.",
        fields: [
          {
            id: "consentStartDate",
            label: "동의 시작일",
            type: "date",
            role: "author",
            required: true,
          },
          {
            id: "consentEndDate",
            label: "동의 종료일",
            type: "date",
            role: "author",
            helperText: "기간 제한이 없는 경우 공란으로 둘 수 있습니다.",
          },
          {
            id: "consentLocation",
            label: "동의 장소",
            type: "text",
            role: "author",
            placeholder: "예: 서울특별시 강남구 소재 주거지",
          },
          {
            id: "specificConsent",
            label: "구체적 동의 내용",
            type: "textarea",
            role: "author",
            required: true,
            helperText:
              "양 당사자가 동의하는 구체적인 행위를 명시합니다.",
          },
        ],
      },
      {
        id: "prohibition-clauses",
        title: "금지 조항",
        role: "author",
        description: "촬영, 녹음 등 금지되는 행위를 명시합니다.",
        fields: [
          {
            id: "recordingProhibition",
            label: "촬영·녹음 금지 동의",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: true,
            helperText:
              "양 당사자는 사전 명시적 동의 없이 사진, 동영상, 음성 녹음 등 일체의 기록물 생성을 금지하는 데 동의합니다.",
          },
          {
            id: "recordingExceptions",
            label: "촬영·녹음 예외 사항",
            type: "textarea",
            role: "author",
            placeholder: "예외적으로 허용되는 경우를 명시 (없으면 공란)",
            helperText: "양 당사자가 명시적으로 합의한 경우에만 기재",
          },
          {
            id: "dataUsageProhibition",
            label: "자료 유출 및 사용 금지",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: true,
            helperText:
              "본 동의서와 관련된 모든 정보를 제3자에게 공개, 유출, 배포하는 것을 금지하는 데 동의합니다.",
          },
          {
            id: "privacyProtection",
            label: "개인정보 보호 약정",
            type: "textarea",
            role: "author",
            required: true,
            placeholder:
              "양 당사자는 상대방의 개인정보를 보호하고 제3자에게 제공하지 않을 것을 약정합니다.",
          },
        ],
      },
      {
        id: "mutual-agreement",
        title: "상호 합의 조항",
        role: "author",
        fields: [
          {
            id: "voluntaryConsent",
            label: "자발적 동의 확인",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: true,
            helperText:
              "양 당사자는 어떠한 강압이나 협박 없이 자유로운 의사로 본 동의서에 서명함을 확인합니다.",
          },
          {
            id: "withdrawalRight",
            label: "철회권 인정",
            type: "checkbox",
            role: "all",
            required: true,
            defaultValue: true,
            helperText:
              "양 당사자는 언제든지 동의를 철회할 수 있는 권리가 있음을 인정합니다.",
          },
          {
            id: "safetyMeasures",
            label: "안전 조치",
            type: "textarea",
            role: "author",
            placeholder:
              "예: 안전한 환경 제공, 상호 존중, 건강 상태 확인 등",
            helperText: "상호 안전과 건강을 위한 조치를 명시합니다.",
          },
        ],
      },
      {
        id: "violation-consequences",
        title: "위반 시 조치",
        role: "author",
        fields: [
          {
            id: "violationConsequences",
            label: "위반 시 법적 책임",
            type: "textarea",
            role: "author",
            required: true,
            placeholder:
              "본 동의서의 조항을 위반할 경우 민·형사상 책임을 질 것에 동의합니다.",
            helperText:
              "촬영·녹음 금지 위반, 개인정보 유출 등에 대한 책임을 명시합니다.",
          },
          {
            id: "disputeResolution",
            label: "분쟁 해결 방법",
            type: "text",
            role: "author",
            placeholder: "예: 당사자 간 협의, 조정 또는 관할 법원",
          },
          {
            id: "jurisdictionCourt",
            label: "관할 법원",
            type: "text",
            role: "author",
            placeholder: "예: 서울중앙지방법원",
          },
        ],
      },
      {
        id: "special-terms",
        title: "특별 약정",
        role: "author",
        fields: [
          {
            id: "specialTerms",
            label: "추가 특약 사항",
            type: "textarea",
            role: "author",
            helperText:
              "양 당사자가 추가로 합의한 사항이 있으면 기재합니다.",
          },
        ],
      },
      {
        id: "signatures",
        title: "서명",
        role: "all",
        fields: [
          {
            id: "partyASignature",
            label: "갑(제1당사자) 서명",
            type: "signature",
            role: "author",
            required: true,
          },
          {
            id: "partyASignDate",
            label: "갑 서명일",
            type: "date",
            role: "author",
            readonly: true,
            helperText: "서명 시 자동으로 기록됩니다.",
          },
          {
            id: "partyBSignature",
            label: "을(제2당사자) 서명",
            type: "signature",
            role: "recipient",
            required: true,
          },
          {
            id: "partyBSignDate",
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
      <span class="field-blank">{{partyAName}}</span> (이하 "갑"이라 함)과(와)
      <span class="field-blank">{{partyBName}}</span> (이하 "을"이라 함)은
      상호 존중과 명확한 의사소통을 바탕으로 다음과 같이 동의한다.
    </p>

    <div class="section-title">제1조 (당사자 정보)</div>
    <table class="info-table">
      <tbody>
        <tr>
          <th>갑(제1당사자)</th>
          <td colspan="3">
            성명: {{partyAName}}<br />
            생년월일: {{partyABirthDate}}<br />
            주소: {{partyAAddress}}<br />
            연락처: {{partyAContact}}
          </td>
        </tr>
        <tr>
          <th>을(제2당사자)</th>
          <td colspan="3">
            성명: {{partyBName}}<br />
            생년월일: {{partyBBirthDate}}<br />
            주소: {{partyBAddress}}<br />
            연락처: {{partyBContact}}
          </td>
        </tr>
      </tbody>
    </table>

    <div class="section-title">제2조 (동의 기간 및 장소)</div>
    <div class="clause">
      <strong>1. 동의 기간:</strong> <span class="field-blank small">{{consentStartDate}}</span> 부터
      <span class="field-blank small">{{consentEndDate}}</span> 까지<br />
      <span style="font-size:12px;color:#586674;">※ 종료일이 명시되지 않은 경우 일회적 동의로 간주됩니다.</span>
    </div>
    <div class="clause">
      <strong>2. 동의 장소:</strong> <span class="field-blank">{{consentLocation}}</span>
    </div>

    <div class="section-title">제3조 (동의 내용)</div>
    <div class="clause">
      <p style="margin:0 0 8px;">양 당사자는 다음 사항에 대해 자유로운 의사로 동의합니다:</p>
      <p style="margin:0;padding:10px;background:#f9fafb;border-left:3px solid #0b3954;">
        {{specificConsent}}
      </p>
    </div>

    <div class="prohibition-box">
      <strong>🚫 제4조 (촬영·녹음 금지 조항)</strong>
      <ol style="margin:6px 0 0;padding-left:20px;font-size:13px;line-height:1.7;">
        <li>양 당사자는 상대방의 <strong>사전 명시적 서면 동의 없이</strong> 사진, 동영상, 음성 녹음 등 일체의 시청각 자료를 생성하거나 보관하는 것을 <strong>절대적으로 금지</strong>합니다.</li>
        <li>이 조항은 스마트폰, 카메라, 녹음기, CCTV, 웨어러블 기기 등 모든 형태의 기록 장치에 적용됩니다.</li>
        <li>예외 사항: {{recordingExceptions}}</li>
        <li>본 조항을 위반할 경우 「성폭력범죄의 처벌 등에 관한 특례법」 제14조(카메라등이용촬영), 「정보통신망 이용촉진 및 정보보호 등에 관한 법률」 등 관련 법령에 따라 민·형사상 책임을 집니다.</li>
      </ol>
    </div>

    <div class="section-title">제5조 (개인정보 보호 및 비밀유지)</div>
    <div class="clause">
      <strong>1. 자료 유출 금지:</strong> 양 당사자는 본 동의서 및 관련 정보를 제3자에게 공개, 유출, 배포하지 않습니다.
    </div>
    <div class="clause">
      <strong>2. 개인정보 보호:</strong><br />
      <p style="margin:6px 0 0;padding:10px;background:#f9fafb;border-left:3px solid #0b3954;">
        {{privacyProtection}}
      </p>
    </div>

    <div class="section-title">제6조 (상호 합의 및 권리)</div>
    <div class="clause">
      <strong>1. 자발적 동의:</strong> 양 당사자는 어떠한 강압, 협박, 사기, 기망 없이 자유로운 의사로 본 동의서에 서명합니다.
    </div>
    <div class="clause">
      <strong>2. 철회권:</strong> 양 당사자는 언제든지 구두 또는 서면으로 동의를 철회할 수 있으며, 상대방은 이를 즉시 존중해야 합니다.
    </div>
    <div class="clause">
      <strong>3. 안전 조치:</strong><br />
      <p style="margin:6px 0 0;padding:10px;background:#f9fafb;">
        {{safetyMeasures}}
      </p>
    </div>

    <div class="section-title">제7조 (위반 시 법적 책임)</div>
    <div class="clause">
      <p style="margin:0 0 8px;">본 동의서의 조항(특히 촬영·녹음 금지, 개인정보 보호)을 위반할 경우:</p>
      <p style="margin:0;padding:10px;background:#fff3cd;border-left:3px solid #ffc107;">
        {{violationConsequences}}
      </p>
    </div>
    <div class="clause">
      <strong>분쟁 해결:</strong> {{disputeResolution}}<br />
      <strong>관할 법원:</strong> {{jurisdictionCourt}}
    </div>

    <div class="section-title">제8조 (특별 약정)</div>
    <div class="clause">
      {{specialTerms}}
    </div>

    <div class="section-title">제9조 (기타)</div>
    <div class="clause">
      본 동의서에 명시되지 않은 사항은 민법, 형법, 성폭력처벌법 등 관련 법령에 따릅니다.
    </div>
  </section>

  <section style="padding:18px 12px 20px;">
    <p style="margin:0 0 12px;text-align:right;">작성일: <span class="field-blank small">{{contractDate}}</span></p>
    <table class="signature-table">
      <tbody>
        <tr>
          <th>갑(제1당사자)</th>
          <td>
            성명: {{partyAName}}<br />
            생년월일: {{partyABirthDate}}<br />
            연락처: {{partyAContact}}<br />
            서명: {{partyASignature}} / 서명일: {{partyASignDate}}
          </td>
        </tr>
        <tr>
          <th>을(제2당사자)</th>
          <td>
            성명: {{partyBName}}<br />
            생년월일: {{partyBBirthDate}}<br />
            연락처: {{partyBContact}}<br />
            서명: {{partyBSignature}} / 서명일: {{partyBSignDate}}
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
    contractDate: "2025-11-19",
    partyAName: "홍길동",
    partyABirthDate: "1990-05-15",
    partyAIdNumber: "1******",
    partyAAddress: "서울특별시 강남구 테헤란로 123",
    partyAContact: "010-1234-5678",
    partyBName: "김영희",
    partyBBirthDate: "1992-08-22",
    partyBIdNumber: "2******",
    partyBAddress: "서울특별시 서초구 반포대로 456",
    partyBContact: "010-9876-5432",
    consentStartDate: "2025-11-19",
    consentEndDate: "",
    consentLocation: "서울특별시 강남구 소재 주거지",
    specificConsent:
      "양 당사자는 상호 존중을 바탕으로 친밀한 관계를 형성하는 데 동의하며, 상대방의 의사를 최우선으로 존중합니다.",
    recordingProhibition: true,
    recordingExceptions: "없음 (일체의 촬영·녹음 금지)",
    dataUsageProhibition: true,
    privacyProtection:
      "양 당사자는 상대방의 개인정보(성명, 연락처, 주소 등)를 제3자에게 제공하지 않으며, 본 동의서의 존재 자체도 비밀로 유지합니다.",
    voluntaryConsent: true,
    withdrawalRight: true,
    safetyMeasures:
      "양 당사자는 안전하고 사적인 환경을 제공하며, 상호 건강 상태를 확인하고 존중합니다.",
    violationConsequences:
      "본 동의서 조항(특히 촬영·녹음 금지)을 위반할 경우 「성폭력범죄의 처벌 등에 관한 특례법」, 「정보통신망법」 등에 따라 민·형사상 책임을 지며, 손해배상 청구 대상이 됩니다.",
    disputeResolution: "당사자 간 협의 후 법적 조치",
    jurisdictionCourt: "서울중앙지방법원",
    specialTerms:
      "본 동의서는 양 당사자의 권리를 보호하기 위해 작성되었으며, 일방적인 요구나 강요는 허용되지 않습니다.",
    partyASignature: "홍길동",
    partyASignDate: "2025-11-19",
    partyBSignature: "김영희",
    partyBSignDate: "2025-11-19",
  };

  const templateData = {
    name: "성인 간 성관계 동의서",
    category: "개인/권리보호",
    description:
      "성인 간 명확한 합의와 권리 보호를 위한 동의서입니다. 사적 촬영·녹음 금지, 개인정보 보호, 상호 존중 조항을 포함합니다.",
    content,
    formSchema,
    samplePayload,
    lastUpdatedAt: now,
  };

  // 기존 템플릿 확인
  const existing = await templateRepo.findOne({
    where: { name: templateData.name },
  });

  if (existing) {
    console.log("⚠️  이미 동일한 이름의 템플릿이 존재합니다.");
    console.log(`   ID: ${existing.id}, Name: ${existing.name}`);
    console.log("   기존 템플릿을 업데이트하시겠습니까? (Y/N)");

    // 자동으로 업데이트
    Object.assign(existing, templateData);
    await templateRepo.save(existing);
    console.log("✅ 템플릿 업데이트 완료!");
    console.log(`   ID: ${existing.id}`);
  } else {
    const newTemplate = templateRepo.create(templateData);
    const saved = await templateRepo.save(newTemplate);
    console.log("✅ 새 템플릿 생성 완료!");
    console.log(`   ID: ${saved.id}`);
    console.log(`   Name: ${saved.name}`);
    console.log(`   Category: ${saved.category}`);
  }

  await dataSource.destroy();
  console.log("✅ Database connection closed");
}

// Run the script
addConsentTemplate()
  .then(() => {
    console.log("\n🎉 작업 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 오류 발생:", error);
    process.exit(1);
  });
