import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { ConfigService } from "@nestjs/config";
import { Template } from "./template.entity";
import { TemplateFormSchema } from "./template-form.types";

interface SeedTemplate {
  name: string;
  category: string;
  description: string;
  content: string;
  lastUpdatedAt?: Date;
  formSchema?: TemplateFormSchema;
  samplePayload?: Record<string, unknown>;
}

@Injectable()
export class TemplatesService {

  constructor(
    @InjectRepository(Template)
    private readonly templatesRepository: Repository<Template>,
    private readonly configService: ConfigService,
  ) {}

  async seedTemplates() {
    const now = new Date();
    const seeds: SeedTemplate[] = [
      {
        name: "표준 근로계약서",
        category: "인사/노무",
        description:
          "정규직 및 기간제 근로자와 체결할 때 필요한 핵심 조항(근로조건, 임금, 휴가, 4대보험)을 포함한 표준 근로계약서 양식입니다.",
        content: `

<div class="contract-page" style="width:794px;margin:0 auto;font-family:'Pretendard','Noto Sans KR',sans-serif;color:#1b2733;font-size:13px;line-height:1.65;">
  <style>
    .field-blank {
      display: inline-block;
      min-width: 160px;
      padding: 0 12px;
      border-bottom: 1px solid #1b2733;
      text-align: center;
      font-weight: 600;
    }
    .field-blank.small {
      min-width: 120px;
    }
    .section-title {
      font-size: 15px;
      color: #0b3954;
      margin: 16px 0 10px;
      border-left: 4px solid #0b3954;
      padding-left: 8px;
    }
    .clause {
      margin-bottom: 10px;
    }
    .sign-table {
      width: 100%;
      border-collapse: collapse;
      border: 1px solid #aeb8ca;
      margin-bottom: 12px;
    }
    .sign-table th,
    .sign-table td {
      border: 1px solid #aeb8ca;
      padding: 8px;
    }
    .sign-table th {
      width: 22%;
      background: #f3f5f9;
      text-align: left;
    }
  </style>

  <header style="text-align:center;padding:18px 10px 12px;border-bottom:3px solid #0b3954;">
    <h1 style="margin:0;font-size:28px;letter-spacing:0.14em;color:#0b3954;">표준근로계약서</h1>
    <p style="margin:6px 0 0;font-size:13px;color:#5c6b7a;">스카이코워커와 함께 하게 된 것을 진심으로 환영합니다</p>
  </header>

  <section style="padding:18px 10px 0;">
    <p class="clause"><span class="field-blank">{{employerName}}</span> (이하 “갑”이라 함)과(와) <span class="field-blank">{{employeeName}}</span> (이하 “을”이라 함)은 다음과 같이 근로계약을 체결한다.</p>

    <div class="clause"><strong>1. 근로계약기간 :</strong> <span class="field-blank small">{{employmentStartDate}}</span> 부터 <span class="field-blank small">{{employmentEndDate}}</span> 까지<br /><span style="font-size:12px;color:#586674;">※ 근로계약기간을 정하지 않는 경우에는 근로개시일만 기재하며, 근로종료일 1개월 전 상호 통보가 없으면 1년 단위로 자동 연장됩니다.</span></div>
    <div class="clause"><strong>2. 근무 장소(사업장주소) :</strong> <span class="field-blank">{{workplaceLocation}}</span></div>
    <div class="clause"><strong>3. 업무의 내용 :</strong> <span class="field-blank">{{jobDescription}}</span></div>
    <div class="clause"><strong>4. 소정근로시간 :</strong> <span class="field-blank small">{{dailyWorkHours}}</span> (휴게시간 <span class="field-blank small">{{restTime}}</span>)</div>
    <div class="clause"><strong>5. 근무일/휴일 :</strong> 근무 <span class="field-blank small">{{weeklyWorkDays}}</span> / 주휴일 <span class="field-blank small">{{weeklyHoliday}}</span></div>
    <div class="clause"><strong>6. 임금 :</strong> <span class="field-blank small">{{wageType}}</span> <span class="field-blank small">{{wageAmount}}</span> 원<br /><span style="font-size:12px;color:#586674;">※ 수당 {{allowances}}, 상여금 {{bonusPolicy}}, 퇴직금 {{severancePay}} 포함</span></div>
    <div class="clause"><strong>7. 급여 지급일 :</strong> <span class="field-blank small">{{wagePaymentDate}}</span><br /><span style="font-size:12px;color:#586674;">※ 상기 급여는 12개월로 나누어 매월 해당 지급일에 지급합니다.</span></div>
    <div class="clause"><strong>8. 수습기간 :</strong> 수습 <span class="field-blank small">{{probationMonths}}</span>개월, 수습 중 급여 <span class="field-blank small">{{probationWagePercent}}</span>% 지급. 적격성 미달 시 계약 해지 가능.</div>
    <div class="clause"><strong>9. 4대보험 :</strong> 국민연금 {{nationalPensionStatus}} / 건강보험 {{healthInsuranceStatus}} / 고용보험 {{employmentInsuranceStatus}} / 산재보험 {{industrialAccidentInsuranceStatus}}<br /><span style="font-size:12px;color:#586674;">※ 법에 의한 근로자 부담분은 근로자가 부담합니다.</span></div>
    <div class="clause"><strong>10. 연차유급휴가 :</strong> {{annualLeaveDays}}일 (근로기준법 및 관련 법령에 따름)</div>
    <div class="clause"><strong>11. 근로계약서 교부 :</strong> “갑”은 근로계약 체결과 동시에 본 계약서를 사본하여 “을”에게 교부한다. (근로기준법 제17조)</div>
    <div class="clause"><strong>12. 을의 의무 :</strong><br />① 업무상의 과오 발생 시 즉시 상사에게 보고하고 지시에 따른다.<br />② 계약 중 알게 된 “갑”의 영업비밀 및 기밀을 계약 종료 후에도 유출하거나 이용하지 않는다.<br />③ 본인 또는 타인의 급여 정보를 제3자에게 누설하지 않는다.<br />④ 고의 또는 중대한 과실로 “갑”에게 손해를 끼친 경우 이를 배상한다.<br />⑤ 중도 퇴직 시 최소 1개월 전에 통보하고 인수인계를 완료한다.<br />⑥ 퇴직급여는 퇴직연금(DC형)에 가입하여 지급한다.</div>
    <div class="clause"><strong>13. 기타 :</strong> 이 계약에 정함이 없는 사항은 근로기준법 등 노동관계법령에 따른다.</div>
    <div class="clause"><strong>14. 개인정보 이용·제공·활용 동의 :</strong> 개인정보는 4대보험 신고, 임금 대장 작성, 세무 신고 목적에 한해 사용하며, 「개인정보보호법」에 따라 관리한다. 본 동의는 {{employerName}}이(가) 보유·활용하는 것에 대한 동의이다.</div>
  </section>

  <section style="padding:18px 10px 0;">
    <p style="margin:0 0 12px;text-align:right;">작성일 : <span class="field-blank small">{{contractDate}}</span></p>
    <table class="sign-table">
      <tbody>
        <tr>
          <th>(갑) 사업주</th>
          <td style="line-height:1.8;">
            사업체명 : {{employerName}}<br />
            대표자 : {{employerRepresentative}}<br />
            전화 : {{employerContact}}<br />
            주소 : {{employerAddress}}<br />
            서명 : {{employerSignature}} / 서명일 : {{employerSignDate}}
          </td>
        </tr>
        <tr>
          <th>(을) 근로자</th>
          <td style="line-height:1.8;">
            성명 : {{employeeName}}<br />
            주민번호 : {{employeeResidentId}}<br />
            주소 : {{employeeAddress}}<br />
            서명 : {{employeeSignature}} / 서명일 : {{employeeSignDate}}
          </td>
        </tr>
      </tbody>
    </table>
  </section>
</div>
`,
        lastUpdatedAt: now,
        formSchema: {
          version: 1,
          title: "표준 근로계약서 입력 항목",
          description:
            "고용노동부 표준 서식을 기반으로 한 사용자·근로자 정보와 근로조건, 임금, 휴가, 4대보험 항목입니다.",
          sections: [
            {
              id: "contract-meta",
              title: "계약 개요",
              role: "author",
              fields: [
                {
                  id: "contractTitle",
                  label: "계약서 제목",
                  type: "text",
                  role: "author",
                  required: true,
                  placeholder: "표준 근로계약서",
                },
                {
                  id: "contractDate",
                  label: "계약 체결일",
                  type: "date",
                  role: "author",
                  required: true,
                },
              ],
            },
            {
              id: "employer-info",
              title: "사용자(회사) 정보",
              role: "author",
              fields: [
                {
                  id: "employerName",
                  label: "사업체명",
                  type: "text",
                  role: "author",
                  required: true,
                  placeholder: "예: 인싸인 주식회사",
                },
                {
                  id: "businessRegistrationNumber",
                  label: "사업자등록번호",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "employerRepresentative",
                  label: "대표자 이름",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "employerAddress",
                  label: "사업장 주소",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "employerContact",
                  label: "사업장 연락처",
                  type: "phone",
                  role: "author",
                  placeholder: "032-000-0000",
                },
              ],
            },
            {
              id: "employee-info",
              title: "근로자 정보",
              role: "author",
              fields: [
                {
                  id: "employeeName",
                  label: "근로자 이름",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "employeeResidentId",
                  label: "주민등록번호 / 외국인등록번호",
                  type: "text",
                  role: "author",
                  helperText: "예: 900119-1******",
                },
                {
                  id: "employeeAddress",
                  label: "주소",
                  type: "text",
                  role: "author",
                },
                {
                  id: "employeeContact",
                  label: "연락처",
                  type: "phone",
                  role: "author",
                  placeholder: "010-0000-0000",
                },
              ],
            },
            {
              id: "employment-terms",
              title: "근로조건",
              role: "author",
              fields: [
                {
                  id: "employmentStartDate",
                  label: "근로 시작일",
                  type: "date",
                  role: "author",
                  required: true,
                },
                {
                  id: "employmentEndDate",
                  label: "근로 종료일",
                  type: "date",
                  role: "author",
                  helperText: "무기계약의 경우 공란으로 둘 수 있습니다.",
                },
                {
                  id: "employmentContractType",
                  label: "계약 유형",
                  type: "select",
                  role: "author",
                  required: true,
                  options: [
                    { label: "무기계약", value: "무기계약" },
                    { label: "기간제(3개월)", value: "기간제(3개월)" },
                    { label: "기간제(6개월)", value: "기간제(6개월)" },
                    { label: "기간제(12개월)", value: "기간제(12개월)" },
                    { label: "단시간·파트타임", value: "단시간·파트타임" },
                  ],
                },
                {
                  id: "probationMonths",
                  label: "수습 기간(개월)",
                  type: "number",
                  role: "author",
                  validation: { min: 0 },
                },
                {
                  id: "probationWagePercent",
                  label: "수습 급여 지급 비율(%)",
                  type: "number",
                  role: "author",
                  validation: { min: 0, max: 100 },
                },
                {
                  id: "workplaceLocation",
                  label: "근무 장소",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "jobDescription",
                  label: "업무 내용",
                  type: "textarea",
                  role: "author",
                  required: true,
                },
                {
                  id: "weeklyWorkDays",
                  label: "근로일",
                  type: "text",
                  role: "author",
                  placeholder: "예: 주 5일 (월~금)",
                },
                {
                  id: "dailyWorkHours",
                  label: "근로시간",
                  type: "text",
                  role: "author",
                  placeholder: "예: 09:00 ~ 18:00 (휴게 1시간)",
                },
                {
                  id: "restTime",
                  label: "휴게시간",
                  type: "text",
                  role: "author",
                },
                {
                  id: "overtimePolicy",
                  label: "연장·야간·휴일근로",
                  type: "textarea",
                  role: "author",
                  helperText:
                    "연장근로 승인 절차와 수당 지급 기준을 기재합니다.",
                },
              ],
            },
            {
              id: "wage-terms",
              title: "임금 조건",
              role: "author",
              fields: [
                {
                  id: "wageType",
                  label: "임금 형태",
                  type: "select",
                  role: "author",
                  required: true,
                  options: [
                    { label: "월급제", value: "월급제" },
                    { label: "시급제", value: "시급제" },
                    { label: "연봉제", value: "연봉제" },
                    { label: "건별지급", value: "건별지급" },
                  ],
                },
                {
                  id: "wageAmount",
                  label: "기본급(원)",
                  type: "currency",
                  role: "author",
                  required: true,
                  placeholder: "예: 2800000",
                },
                {
                  id: "wagePaymentDate",
                  label: "임금 지급일",
                  type: "text",
                  role: "author",
                  placeholder: "예: 매월 25일",
                },
                {
                  id: "wagePaymentMethod",
                  label: "지급 방법",
                  type: "select",
                  role: "author",
                  options: [
                    { label: "계좌이체", value: "계좌이체" },
                    { label: "현금지급", value: "현금지급" },
                    { label: "기타", value: "기타" },
                  ],
                },
                {
                  id: "allowances",
                  label: "각종 수당",
                  type: "textarea",
                  role: "author",
                  helperText: "직책·식대·연장수당 등 상세 내역",
                },
                {
                  id: "bonusPolicy",
                  label: "상여금/인센티브",
                  type: "textarea",
                  role: "author",
                },
                {
                  id: "severancePay",
                  label: "퇴직금 지급 기준",
                  type: "select",
                  role: "author",
                  options: [
                    {
                      label: "근로자퇴직급여보장법에 따라 지급",
                      value: "근로자퇴직급여보장법에 따라 지급",
                    },
                    {
                      label: "퇴직금 비대상 (1년 미만 등)",
                      value: "퇴직금 비대상 (1년 미만 등)",
                    },
                    { label: "기타(특약 기재)", value: "기타(특약 기재)" },
                  ],
                },
                {
                  id: "nationalPensionStatus",
                  label: "국민연금",
                  type: "select",
                  role: "author",
                  options: [
                    { label: "가입", value: "가입" },
                    { label: "미가입", value: "미가입" },
                    { label: "해당없음", value: "해당없음" },
                  ],
                },
                {
                  id: "healthInsuranceStatus",
                  label: "건강보험",
                  type: "select",
                  role: "author",
                  options: [
                    { label: "가입", value: "가입" },
                    { label: "미가입", value: "미가입" },
                    { label: "해당없음", value: "해당없음" },
                  ],
                },
                {
                  id: "employmentInsuranceStatus",
                  label: "고용보험",
                  type: "select",
                  role: "author",
                  options: [
                    { label: "가입", value: "가입" },
                    { label: "미가입", value: "미가입" },
                    { label: "해당없음", value: "해당없음" },
                  ],
                },
                {
                  id: "industrialAccidentInsuranceStatus",
                  label: "산재보험",
                  type: "select",
                  role: "author",
                  options: [
                    { label: "가입", value: "가입" },
                    { label: "미가입", value: "미가입" },
                    { label: "해당없음", value: "해당없음" },
                  ],
                },
              ],
            },
            {
              id: "leave-terms",
              title: "휴일·휴가",
              role: "author",
              fields: [
                {
                  id: "weeklyHoliday",
                  label: "주휴일",
                  type: "text",
                  role: "author",
                  placeholder: "예: 주1회 (일요일)",
                },
                {
                  id: "annualLeaveDays",
                  label: "연차 유급휴가(일수)",
                  type: "number",
                  role: "author",
                  validation: { min: 0 },
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
                  label: "특약 사항",
                  type: "textarea",
                  role: "author",
                  helperText:
                    "수습기간, 비밀유지, 겸업금지 등 추가 약정을 기재합니다.",
                },
              ],
            },
            {
              id: "signatures",
              title: "서명",
              role: "all",
              fields: [
                {
                  id: "employerSignature",
                  label: "사용자 서명",
                  type: "signature",
                  role: "author",
                  required: true,
                },
                {
                  id: "employerSignDate",
                  label: "사용자 서명일",
                  type: "date",
                  role: "author",
                },
                {
                  id: "employeeSignature",
                  label: "근로자 서명",
                  type: "signature",
                  role: "recipient",
                  required: true,
                },
                {
                  id: "employeeSignDate",
                  label: "근로자 서명일",
                  type: "date",
                  role: "recipient",
                },
              ],
            },
          ],
        },
        samplePayload: {
          contractTitle: "정규직 근로계약서 (라이브커머스 운영)",
          contractDate: "2025-08-29",
          employerName: "에버트리 주식회사",
          businessRegistrationNumber: "245-88-01457",
          employerRepresentative: "박세연",
          employerAddress: "서울특별시 성동구 연무장11길 33, 에버트리타워 7층",
          employerContact: "02-555-0413",
          employeeName: "김도윤",
          employeeResidentId: "940215-1",
          employeeAddress: "경기도 고양시 일산동구 무궁화로 85, 902호",
          employeeContact: "010-8245-1937",
          employmentStartDate: "2026-03-04",
          employmentEndDate: "2027-03-03",
          employmentContractType: "무기계약",
          probationMonths: 2,
          probationWagePercent: 80,
          workplaceLocation:
            "서울특별시 성동구 연무장11길 33, 에버트리타워 7층",
          jobDescription:
            "라이브커머스 채널 운영, 상품 촬영 기획, 방송 진행 지원",
          weeklyWorkDays: "주 5일 (월~금)",
          dailyWorkHours: "10:00 ~ 19:00 (휴게 13:00 ~ 14:00)",
          restTime: "13:00 ~ 14:00",
          overtimePolicy:
            "사전 승인 후 연장근로 수행, 법정 수당 기준으로 산정하여 익월 급여에 반영",
          wageType: "연봉제",
          wageAmount: "36000000",
          wagePaymentDate: "매월 25일",
          wagePaymentMethod: "계좌이체",
          allowances: "직책수당 150,000원, 통신비 50,000원",
          bonusPolicy: "반기별 KPI 달성률에 따른 성과 인센티브 지급",
          severancePay: "근로자퇴직급여보장법에 따라 지급",
          nationalPensionStatus: "가입",
          healthInsuranceStatus: "가입",
          employmentInsuranceStatus: "가입",
          industrialAccidentInsuranceStatus: "가입",
          weeklyHoliday: "주 1회 (토요일 또는 일요일)",
          annualLeaveDays: 18,
          specialTerms:
            "입사 후 12개월간 스마트스토어 교육 이수(교육비 회사 부담). 외부 라이브 방송 진행 시 사전 승인 필수.",
          employerSignature: "박세연",
          employerSignDate: "2026-03-04",
          employeeSignature: "김도윤",
          employeeSignDate: "2026-03-04",
        },
      },
      {
        name: "비밀유지서약서(입사자)",
        category: "보안/내부통제",
        description:
          "신규 또는 재직 중 임직원이 영업비밀 보호 의무를 확인하고 주요 준수 조항에 서약할 때 사용하는 표준 양식입니다.",
        content: `
<div class="contract-page" style="width:760px;margin:0 auto;font-family:'Pretendard','Noto Sans KR',sans-serif;color:#1b2733;font-size:13px;line-height:1.7;">
  <style>
    .field-blank {
      display: inline-block;
      min-width: 140px;
      border-bottom: 1px solid #1b2733;
      padding: 0 8px;
      font-weight: 600;
      text-align: center;
    }
    .info-table {
      width: 100%;
      border-collapse: collapse;
      margin: 18px 0;
    }
    .info-table th,
    .info-table td {
      border: 1px solid #d4d9e2;
      padding: 8px 12px;
    }
    .info-table th {
      width: 22%;
      background: #f3f5f9;
      text-align: left;
    }
    .clause-list {
      margin: 0;
      padding-left: 20px;
    }
    .clause-list li {
      margin-bottom: 10px;
    }
    .clause-sublist {
      margin-top: 8px;
      padding-left: 18px;
      list-style: disc;
    }
    .clause-sublist li {
      margin-bottom: 6px;
    }
    .signature-block {
      margin-top: 24px;
      border-top: 2px solid #0b3954;
      padding-top: 16px;
    }
    .signature-block p {
      margin: 6px 0;
    }
  </style>
  <header style="text-align:center;padding:18px 10px 12px;border-bottom:3px solid #0b3954;">
    <h1 style="margin:0;font-size:26px;letter-spacing:0.12em;color:#0b3954;">비밀유지서약서</h1>
    <p style="margin:8px 0 0;color:#5c6b7a;">{{companyName}}의 영업비밀 보호 정책을 숙지하고 아래 조항을 준수할 것을 서약합니다.</p>
  </header>
  <section style="padding:20px 12px 0;">
    <table class="info-table">
      <tbody>
        <tr>
          <th>소속</th>
          <td>{{affiliation}}</td>
          <th>성명</th>
          <td>{{employeeName}}</td>
        </tr>
        <tr>
          <th>생년월일</th>
          <td>{{employeeBirthDate}}</td>
          <th>입사일</th>
          <td>{{hireDate}}</td>
        </tr>
        <tr>
          <th>회사명</th>
          <td>{{companyName}}</td>
          <th>대표자</th>
          <td>{{companyRepresentative}}</td>
        </tr>
      </tbody>
    </table>
    <p style="margin:0 0 16px;">본인은 회사의 영업비밀 및 자산의 중요성을 이해하였으며 다음 사항을 준수하겠습니다.</p>
    <ol class="clause-list">
      <li>
        회사의 취업규칙, 영업비밀 관리규정, 방침, 정책을 준수하며 다음과 같은 정보를 영업비밀로 인지합니다.
        <ul class="clause-sublist">
          <li>영업비밀 관리규정 및 회사 내부 규정에 명시된 보호대상</li>
          <li>영업비밀 표시가 있는 기술자료, 설계도면, 금형, 시제품, 매뉴얼, 제조원가, 거래선 자료, 인력정보 등</li>
          <li>통제구역, 시건장치, 패스워드 등으로 접근이 제한된 시스템과 보관 매체</li>
          <li>{{additionalSecretItems}}</li>
          <li>기타 회사가 영업비밀로 지정·관리하는 모든 정보</li>
        </ul>
      </li>
      <li>재직 중 취득한 영업비밀 및 주요 자산을 재직 중은 물론 퇴사 후에도 비밀로 유지하며, 사전 서면 동의 없이 제3자에게 제공하거나 부정하게 사용하지 않습니다.</li>
      <li>회사 연구개발·영업·재산에 관한 유형·무형 정보의 권리가 회사에 귀속됨을 인정하고, 회사 요청 시 즉시 반환합니다.</li>
      <li>승인되지 않은 통제구역이나 정보를 무단으로 열람하지 않으며, 영업비밀을 복제하거나 사적으로 보관하지 않습니다.</li>
      <li>타인의 영업비밀 정보를 회사에 제공하지 않으며, 업무상 필요한 경우 사전 협의를 통해 침해를 방지합니다.</li>
      <li>회사의 사전 승인을 받지 않고 동종·유사업체에 겸직하거나 자문을 수행하지 않습니다.</li>
      <li>{{monitoringConsent}}</li>
      <li>퇴사 시 기밀 자료 일체를 회사에 반납하고, {{returnMethod}}.</li>
    </ol>
    <p style="margin:16px 0 0;">상기 사항을 위반할 경우 관련 법령에 따른 민·형사상 책임을 부담할 것임을 서약합니다.</p>
  </section>
  <section style="padding:20px 12px 16px;">
    <p style="margin:0 0 12px;text-align:right;">작성일 : {{signatureDate}}</p>
    <div class="signature-block">
      <p>서약자 : <span class="field-blank">{{employeeName}}</span></p>
      <p>서명 : {{employeeSignature}}</p>
    </div>
    <p style="margin:24px 0 0;text-align:right;">{{companyName}} 귀하</p>
  </section>
</div>
`,
        lastUpdatedAt: now,
        formSchema: {
          version: 1,
          title: "비밀유지서약서 입력 항목",
          description:
            "입사자 비밀유지 의무 서약서 작성 시 필요한 기본 신상 정보와 추가 비밀 관리 조항을 입력합니다.",
          sections: [
            {
              id: "pledger-profile",
              title: "서약자 정보",
              role: "recipient",
              fields: [
                {
                  id: "affiliation",
                  label: "소속",
                  type: "text",
                  role: "recipient",
                  required: true,
                },
                {
                  id: "employeeName",
                  label: "성명",
                  type: "text",
                  role: "recipient",
                  required: true,
                },
                {
                  id: "employeeBirthDate",
                  label: "생년월일",
                  type: "date",
                  role: "recipient",
                  required: true,
                },
                {
                  id: "hireDate",
                  label: "입사일",
                  type: "date",
                  role: "author",
                  required: true,
                },
              ],
            },
            {
              id: "company-info",
              title: "회사 정보",
              role: "author",
              fields: [
                {
                  id: "companyName",
                  label: "회사명",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "companyRepresentative",
                  label: "대표자",
                  type: "text",
                  role: "author",
                  required: true,
                },
              ],
            },
            {
              id: "confidential-terms",
              title: "비밀 유지 조항",
              role: "author",
              description:
                "추가 지정할 영업비밀 범위와 모니터링, 자료 반납 정책을 입력합니다.",
              fields: [
                {
                  id: "additionalSecretItems",
                  label: "추가 영업비밀 지정 항목",
                  type: "textarea",
                  role: "author",
                  placeholder: "예: 신규 서비스 로드맵, 파트너사 계약 조건",
                },
                {
                  id: "monitoringConsent",
                  label: "모니터링 동의 문구",
                  type: "textarea",
                  role: "author",
                  required: true,
                  helperText:
                    "정보통신망 사용 기록 확인 등 회사 모니터링 범위를 명시합니다.",
                },
                {
                  id: "returnMethod",
                  label: "자료 반납 및 폐기 절차",
                  type: "textarea",
                  role: "author",
                  required: true,
                  placeholder:
                    "예: 노트북·저장매체 반납 및 보안팀 입회 하 폐기",
                },
              ],
            },
            {
              id: "signatures",
              title: "서명",
              role: "recipient",
              fields: [
                {
                  id: "signatureDate",
                  label: "작성일",
                  type: "date",
                  role: "recipient",
                  required: true,
                },
                {
                  id: "employeeSignature",
                  label: "서약자 서명",
                  type: "signature",
                  role: "recipient",
                  required: true,
                },
              ],
            },
          ],
        },
        samplePayload: {
          affiliation: "플랫폼운영팀",
          employeeName: "홍길동",
          employeeBirthDate: "1992-07-18",
          hireDate: "2025-01-02",
          companyName: "인싸인 주식회사",
          companyRepresentative: "김현우",
          additionalSecretItems:
            "신규 출시 제품 로드맵, 미공개 제휴 조건, 미발표 마케팅 캠페인 자료",
          monitoringConsent:
            "회사는 불법 행위 방지와 영업비밀 보호를 위해 정보통신망 사용 기록을 점검할 수 있으며, 필요한 경우 관련 자료를 열람할 수 있음에 동의합니다.",
          returnMethod:
            "퇴사 시 전자·인쇄물 자료를 전부 반납하고, 전자 장비는 정보보안팀 입회 하에 초기화합니다.",
          signatureDate: "2025-03-01",
          employeeSignature: "홍길동",
        },
      },
      {
        name: "일반 차용증",
        category: "법무/재무",
        description:
          "금전 차용 시 원금·이자 조건과 연체, 관할 조항을 명시해 채권자와 채무자가 서명하는 표준 차용증 양식입니다.",
        content: `
<div class="contract-page" style="width:760px;margin:0 auto;font-family:'Pretendard','Noto Sans KR',sans-serif;color:#1b2733;font-size:13px;line-height:1.7;">
  <style>
    .info-table {
      width: 100%;
      border-collapse: collapse;
      margin: 20px 0 12px;
    }
    .info-table th,
    .info-table td {
      border: 1px solid #d4d9e2;
      padding: 8px 12px;
    }
    .info-table th {
      width: 20%;
      background: #f3f5f9;
      text-align: left;
    }
    .clause-list {
      margin: 0 0 18px;
      padding-left: 20px;
    }
    .clause-list li {
      margin-bottom: 10px;
    }
    .clause-sublist {
      margin-top: 6px;
      padding-left: 18px;
      list-style: disc;
    }
    .clause-sublist li {
      margin-bottom: 4px;
    }
    .signature-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 12px;
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
    .signature-table .signature-box {
      display: block;
      width: 100%;
      margin: 6px 0 8px;
    }
    .signature-table .signature-box img,
    .signature-table .signature-box canvas,
    .signature-table .signature-box svg {
      display: block;
      width: 100% !important;
      height: auto !important;
    }
    .signature-table .signature-label {
      display: block;
      font-weight: 600;
      margin-bottom: 2px;
    }
    .signature-table .signature-date {
      display: block;
      margin-top: 6px;
      color: #4d5c6d;
    }
  </style>
  <header style="text-align:center;padding:18px 10px 14px;border-bottom:3px solid #0b3954;">
    <h1 style="margin:0;font-size:26px;letter-spacing:0.18em;color:#0b3954;">차용증</h1>
    <p style="margin:6px 0 0;color:#5c6b7a;">채권·채무자 간 차용 조건과 상환 계획을 명확히 합의합니다.</p>
  </header>
  <section style="padding:18px 12px 0;">
    <table class="info-table">
      <tbody>
        <tr>
          <th>차용일자</th>
          <td>{{loanDate}}</td>
          <th>차용금액</th>
          <td>{{principalAmountInWords}} (₩{{principalAmount}})</td>
        </tr>
        <tr>
          <th>차용목적</th>
          <td colspan="3">{{loanPurpose}}</td>
        </tr>
      </tbody>
    </table>
    <ol class="clause-list">
      <li>채무자 {{borrowerName}}는 채권자 {{lenderName}}으로부터 {{loanDate}}에 상기 금액을 차용하였으며 {{principalRepaymentDate}}까지 변제합니다.</li>
      <li>원금 변제기 : {{principalRepaymentDate}} / 약정 이자율 : {{interestRate}}% / 이자 지급일 : 매월 {{interestPaymentDay}}일.</li>
      <li>원금과 이자는 지정일에 채권자 주소지에 지참·지불하거나, {{remittanceBank}} {{remittanceAccountNumber}} (예금주: {{remittanceAccountHolder}}) 계좌로 송금하여 변제합니다.</li>
      <li>지연 변제 시 채무자는 일 {{lateInterestRate}}%의 지연 손실금을 가산하여 지급합니다.</li>
      <li>
        다음 경우 최고 없이 기한의 이익을 상실하고 잔존 채무 전액을 즉시 변제합니다.
        <ul class="clause-sublist">
          <li>이자의 지급을 {{missedInterestCount}}회 이상 지체할 때</li>
          <li>채무자 또는 연대보증인이 타 채권자로부터 가압류·강제집행을 받거나 파산·회생 절차를 개시할 때</li>
          <li>기타 본 약정 조항을 위반할 때</li>
        </ul>
      </li>
      <li>본 채권을 담보하거나 추심에 필요한 비용은 채무자가 부담합니다.</li>
      <li>본 채권에 관한 분쟁의 관할법원은 {{jurisdictionCourt}}로 합니다.</li>
    </ol>
  </section>
  <section style="padding:0 12px 20px;">
    <table class="signature-table">
      <tbody>
        <tr>
          <th>채권자</th>
          <td>
            성명 : {{lenderName}}<br />
            주소 : {{lenderAddress}}<br />
            주민/사업자등록번호 : {{lenderIdNumber}}<br />
            연락처 : {{lenderContact}}<br />
            <span class="signature-label">서명 :</span>
            <span class="signature-box">{{lenderSignature}}</span>
            <span class="signature-date">서명일 : {{lenderSignDate}}</span>
          </td>
        </tr>
        <tr>
          <th>채무자</th>
          <td>
            성명 : {{borrowerName}}<br />
            주소 : {{borrowerAddress}}<br />
            주민/사업자등록번호 : {{borrowerIdNumber}}<br />
            연락처 : {{borrowerContact}}<br />
            <span class="signature-label">서명 :</span>
            <span class="signature-box">{{borrowerSignature}}</span>
            <span class="signature-date">서명일 : {{borrowerSignDate}}</span>
          </td>
        </tr>
      </tbody>
    </table>
  </section>
</div>
`,
        lastUpdatedAt: now,
        formSchema: {
          version: 1,
          title: "차용증 입력 항목",
          description:
            "금전 차용 계약의 기본 조건, 송금 정보, 서명란을 구조화하여 전자 서명에 활용합니다.",
          sections: [
            {
              id: "loan-overview",
              title: "차용 개요",
              role: "author",
              fields: [
                {
                  id: "loanDate",
                  label: "차용일자",
                  type: "date",
                  role: "author",
                  required: true,
                },
                {
                  id: "principalAmountInWords",
                  label: "차용금액(한글 표기)",
                  type: "text",
                  role: "author",
                  required: true,
                  placeholder: "예: 금 일천만원정",
                },
                {
                  id: "principalAmount",
                  label: "차용금액(숫자)",
                  type: "currency",
                  role: "author",
                  required: true,
                },
                {
                  id: "loanPurpose",
                  label: "차용 목적",
                  type: "textarea",
                  role: "author",
                  required: true,
                  helperText: "자금 사용 용도를 구체적으로 기재합니다.",
                },
              ],
            },
            {
              id: "loan-terms",
              title: "상환 및 이자 조건",
              role: "author",
              fields: [
                {
                  id: "principalRepaymentDate",
                  label: "원금 변제기",
                  type: "date",
                  role: "author",
                  required: true,
                },
                {
                  id: "interestRate",
                  label: "연 이자율(%)",
                  type: "number",
                  role: "author",
                  required: true,
                  validation: { min: 0 },
                },
                {
                  id: "interestPaymentDay",
                  label: "이자 지급일(일)",
                  type: "number",
                  role: "author",
                  required: true,
                  validation: { min: 1, max: 31 },
                },
              ],
            },
            {
              id: "remittance-info",
              title: "송금 계좌",
              role: "author",
              fields: [
                {
                  id: "remittanceBank",
                  label: "은행명",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "remittanceAccountNumber",
                  label: "계좌번호",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "remittanceAccountHolder",
                  label: "예금주",
                  type: "text",
                  role: "author",
                  required: true,
                },
              ],
            },
            {
              id: "default-terms",
              title: "지연 및 관할 조항",
              role: "author",
              fields: [
                {
                  id: "lateInterestRate",
                  label: "지연 손실금 이자율(%)",
                  type: "number",
                  role: "author",
                  required: true,
                  validation: { min: 0 },
                },
                {
                  id: "missedInterestCount",
                  label: "기한이익 상실 기준(회)",
                  type: "number",
                  role: "author",
                  required: true,
                  validation: { min: 1 },
                },
                {
                  id: "jurisdictionCourt",
                  label: "관할법원",
                  type: "text",
                  role: "author",
                  required: true,
                },
              ],
            },
            {
              id: "lender-info",
              title: "채권자 정보",
              role: "author",
              fields: [
                {
                  id: "lenderName",
                  label: "성명",
                  type: "text",
                  role: "author",
                  required: true,
                },
                {
                  id: "lenderAddress",
                  label: "주소",
                  type: "text",
                  role: "author",
                },
                {
                  id: "lenderIdNumber",
                  label: "주민/사업자등록번호",
                  type: "text",
                  role: "author",
                  helperText: "예: 000000-0000000 또는 123-45-67890",
                },
                {
                  id: "lenderContact",
                  label: "연락처",
                  type: "phone",
                  role: "author",
                },
                {
                  id: "lenderSignature",
                  label: "서명",
                  type: "signature",
                  role: "author",
                  required: true,
                },
                {
                  id: "lenderSignDate",
                  label: "서명일",
                  type: "date",
                  role: "author",
                },
              ],
            },
            {
              id: "borrower-info",
              title: "채무자 정보",
              role: "recipient",
              fields: [
                {
                  id: "borrowerName",
                  label: "성명",
                  type: "text",
                  role: "recipient",
                  required: true,
                },
                {
                  id: "borrowerAddress",
                  label: "주소",
                  type: "text",
                  role: "recipient",
                },
                {
                  id: "borrowerIdNumber",
                  label: "주민/사업자등록번호",
                  type: "text",
                  role: "recipient",
                },
                {
                  id: "borrowerContact",
                  label: "연락처",
                  type: "phone",
                  role: "recipient",
                },
                {
                  id: "borrowerSignature",
                  label: "서명",
                  type: "signature",
                  role: "recipient",
                  required: true,
                },
                {
                  id: "borrowerSignDate",
                  label: "서명일",
                  type: "date",
                  role: "recipient",
                },
              ],
            },
          ],
        },
        samplePayload: {
          loanDate: "2025-03-15",
          principalAmountInWords: "금 일천만원정",
          principalAmount: "10000000",
          loanPurpose: "운영자금 보충 및 소규모 설비 확충 비용",
          principalRepaymentDate: "2025-09-15",
          interestRate: 4.5,
          interestPaymentDay: 25,
          remittanceBank: "국민은행",
          remittanceAccountNumber: "123456-01-987654",
          remittanceAccountHolder: "홍길동",
          lateInterestRate: 12,
          missedInterestCount: 2,
          jurisdictionCourt: "서울중앙지방법원",
          lenderName: "홍길동",
          lenderAddress: "서울특별시 강남구 테헤란로 231, 15층",
          lenderIdNumber: "000000-0000000",
          lenderContact: "02-123-4567",
          lenderSignature: "홍길동",
          lenderSignDate: "2025-03-15",
          borrowerName: "김민수",
          borrowerAddress: "경기도 성남시 분당구 판교로 201, 8층",
          borrowerIdNumber: "000000-0000000",
          borrowerContact: "010-2345-6789",
          borrowerSignature: "김민수",
          borrowerSignDate: "2025-03-15",
        },
      },
    ];

    for (const seed of seeds) {
      const existing = await this.templatesRepository.findOne({
        where: { name: seed.name },
      });

      if (existing) {
        existing.category = seed.category;
        existing.description = seed.description;
        existing.content = seed.content;
        existing.formSchema = seed.formSchema ?? null;
        existing.samplePayload = seed.samplePayload ?? null;
        existing.lastUpdatedAt = seed.lastUpdatedAt ?? now;
        await this.templatesRepository.save(existing);
      } else {
        const template = this.templatesRepository.create({
          ...seed,
          lastUpdatedAt: seed.lastUpdatedAt ?? now,
        });
        await this.templatesRepository.save(template);
      }
    }
  }

  findAll() {
    return this.templatesRepository.find({ order: { updatedAt: "DESC" } });
  }

  findOne(id: number) {
    return this.templatesRepository.findOne({ where: { id } });
  }

  async createTemplate(data: {
    name: string;
    category: string;
    description: string;
    content: string | null;
    filePath?: string | null;
    fileName?: string | null;
    originalFileName?: string | null;
    formSchema?: TemplateFormSchema | null;
    samplePayload?: Record<string, unknown> | null;
  }) {
    const template = this.templatesRepository.create({
      ...data,
      formSchema: data.formSchema ?? null,
      samplePayload: data.samplePayload ?? null,
      filePath: data.filePath ?? null,
      fileName: data.fileName ?? null,
      originalFileName: data.originalFileName ?? null,
      lastUpdatedAt: new Date(),
    });
    return this.templatesRepository.save(template);
  }

  async updateTemplate(
    id: number,
    data: {
      name: string;
      category: string;
      description: string;
      content?: string | null;
      filePath?: string | null;
      fileName?: string | null;
      originalFileName?: string | null;
      formSchema?: TemplateFormSchema | null;
      samplePayload?: Record<string, unknown> | null;
    },
  ) {
    const template = await this.findOne(id);
    if (!template) {
      return null;
    }
    template.name = data.name;
    template.category = data.category;
    template.description = data.description;
    template.lastUpdatedAt = new Date();

    // content 업데이트 (제공된 경우에만)
    if (data.content !== undefined) {
      template.content = data.content;
    }

    // 파일 관련 필드 업데이트 (제공된 경우에만)
    if (data.filePath !== undefined) {
      template.filePath = data.filePath;
    }
    if (data.fileName !== undefined) {
      template.fileName = data.fileName;
    }
    if (data.originalFileName !== undefined) {
      template.originalFileName = data.originalFileName;
    }

    if (data.formSchema !== undefined) {
      template.formSchema = data.formSchema;
    }
    if (data.samplePayload !== undefined) {
      template.samplePayload = data.samplePayload;
    }
    return this.templatesRepository.save(template);
  }

  async deleteTemplate(id: number) {
    await this.templatesRepository.delete(id);
  }

  /**
   * 템플릿 본문의 플레이스홀더와 formSchema 필드의 일관성을 검증합니다.
   * @param content 템플릿 본문 (HTML 또는 텍스트)
   * @param formSchema 템플릿 폼 스키마
   * @returns 검증 결과 { valid: boolean, missingFields?: string[] }
   */
  validateTemplatePlaceholders(
    content: string | null,
    formSchema: TemplateFormSchema | null,
  ): { valid: boolean; missingFields?: string[] } {
    if (!content || !formSchema) {
      return { valid: true };
    }

    // 시스템에서 기본으로 제공하는 필드 (Contract entity 필드)
    const systemFields = new Set([
      'contractName',
      'name',
      'clientName',
      'clientContact',
      'clientEmail',
      'performerName',
      'performerEmail',
      'performerContact',
      'startDate',
      'endDate',
      'amount',
      'details',
      'signatureImage',
      'status',
      'createdAt',
      'updatedAt',
    ]);

    // 템플릿 본문에서 모든 {{...}} 플레이스홀더 추출
    const placeholderPattern = /\{\{\s*([^}]+)\s*\}\}/g;
    const placeholders = new Set<string>();
    let match;
    while ((match = placeholderPattern.exec(content)) !== null) {
      placeholders.add(match[1].trim());
    }

    // formSchema에서 모든 필드 ID 수집
    const schemaFieldIds = new Set<string>();
    if (formSchema.sections) {
      for (const section of formSchema.sections) {
        if (section.fields) {
          for (const field of section.fields) {
            schemaFieldIds.add(field.id);
          }
        }
      }
    }

    // 허용되는 필드 = 시스템 필드 + formSchema 필드
    const allowedFields = new Set([...systemFields, ...schemaFieldIds]);

    // 템플릿 본문의 플레이스홀더가 허용 목록에 없는지 확인
    const missingFields: string[] = [];
    for (const placeholder of placeholders) {
      if (!allowedFields.has(placeholder)) {
        missingFields.push(placeholder);
      }
    }

    if (missingFields.length > 0) {
      return { valid: false, missingFields };
    }

    return { valid: true };
  }

  async getDefaultTemplateId(): Promise<number | null> {
    // 1. 환경변수에서 DEFAULT_TEMPLATE_ID 확인
    const configured = this.configService.get<string | number>(
      "DEFAULT_TEMPLATE_ID",
    );
    if (configured !== undefined && configured !== null) {
      const parsed = Number(configured);
      if (!Number.isNaN(parsed)) {
        const template = await this.templatesRepository.findOne({
          where: { id: parsed },
        });
        if (template) {
          return template.id;
        }
      }
    }

    // 2. 이름으로 "기본 자유 계약서" 찾기
    const byName = await this.templatesRepository.findOne({
      where: { name: "기본 자유 계약서" },
    });
    if (byName) {
      return byName.id;
    }

    // 3. 카테고리로 "기본" 찾기
    const byCategory = await this.templatesRepository.findOne({
      where: { category: "기본" },
      order: { id: "ASC" },
    });
    return byCategory?.id ?? null;
  }
}
