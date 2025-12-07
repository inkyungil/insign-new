-- ========================================
-- 템플릿 업데이트 SQL
-- 작성일: 2025-12-07
-- ========================================

USE insign;

-- ========================================
-- 1. 기본 자유 계약서 (ID: 5)
-- ========================================
UPDATE templates SET
  content = '<div style="font-family:\'Pretendard\',\'Noto Sans KR\',\'Malgun Gothic\',sans-serif;color:#1b2733;font-size:11pt;line-height:1.8;padding:40px 50px;">

  <h1 style="text-align:center;font-size:24pt;font-weight:700;color:#1b2733;margin:0 0 10px 0;letter-spacing:-0.5px;">{{contractName}}</h1>

  <div style="text-align:center;font-size:10pt;color:#6b7280;margin-bottom:30px;padding-bottom:15px;border-bottom:2px solid #1b2733;">
    계약 당사자 간 자유 조건의 상호 계약을 명확히 합니다.
  </div>

  <table style="width:100%;border-collapse:collapse;margin-bottom:20px;border:1px solid #d1d5db;">
    <tbody>
      <tr>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;width:25%;">
          계약 내용
        </th>
        <td style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;line-height:1.9;white-space:pre-line;">
          {{details}}
        </td>
      </tr>
    </tbody>
  </table>

  <table style="width:100%;border-collapse:collapse;margin-top:30px;border:1px solid #d1d5db;">
    <tbody>
      <tr>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;width:25%;">
          갑(계약자)
        </th>
        <td style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;line-height:1.7;">
          <strong>성명 :</strong> {{clientName}}<br>
          <strong>연락처 :</strong> {{clientContact}}<br>
          <strong>이메일 :</strong> {{clientEmail}}<br>
          <strong>서명 :</strong> {{clientSignature}} / <strong>서명일 :</strong> {{clientSignatureDate}}
        </td>
      </tr>
      <tr>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;width:25%;">
          을(수행자)
        </th>
        <td style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;line-height:1.7;">
          <strong>성명 :</strong> {{performerName}}<br>
          <strong>연락처 :</strong> {{performerContact}}<br>
          <strong>이메일 :</strong> {{performerEmail}}<br>
          <strong>서명 :</strong> {{performerSignature}} / <strong>서명일 :</strong> {{employeeSignatureDate}}
        </td>
      </tr>
    </tbody>
  </table>

</div>',
  sample_payload = '{
  "contractName": "프리랜서 디자인 용역 계약서",
  "details": "1. 계약 목적\\n   본 계약은 갑이 을에게 웹사이트 리디자인 프로젝트를 의뢰하고, 을이 이를 수행하는 조건을 명확히 하기 위함입니다.\\n\\n2. 프로젝트 범위\\n   - 메인 페이지 디자인 (PC/모바일 반응형)\\n   - 서브 페이지 5개 디자인\\n   - UI/UX 개선안 제시 및 적용\\n   - 최종 결과물: Figma 디자인 파일 + 이미지 에셋\\n\\n3. 작업 기간 및 일정\\n   - 시작일: 2025년 1월 15일\\n   - 종료일: 2025년 3월 15일 (2개월)\\n   - 중간 검토: 매주 금요일 온라인 미팅\\n\\n4. 계약 금액 및 지급 조건\\n   - 총 계약 금액: 5,000,000원 (부가세 별도)\\n   - 착수금: 2,000,000원 (계약 체결 후 7일 이내)\\n   - 중도금: 2,000,000원 (1차 시안 승인 후)\\n   - 잔금: 1,000,000원 (최종 납품 후 7일 이내)\\n   - 지급 방법: 을의 지정 계좌로 계좌 이체\\n\\n5. 지식재산권\\n   - 최종 결과물의 저작권은 잔금 지급 완료 후 갑에게 양도됩니다.\\n   - 을은 포트폴리오 목적으로 결과물을 활용할 수 있습니다.\\n\\n6. 수정 및 변경 사항\\n   - 각 단계별 2회까지 무료 수정 가능\\n   - 추가 수정 요청 시 별도 협의\\n\\n7. 비밀 유지\\n   - 양 당사자는 본 프로젝트와 관련된 정보를 제3자에게 누설하지 않습니다.\\n\\n8. 계약 해지\\n   - 일방의 귀책사유로 계약이 해지될 경우, 위약금으로 계약 금액의 20%를 배상합니다.\\n   - 천재지변 등 불가항력적 사유로 인한 해지 시 상호 협의합니다.\\n\\n9. 기타 사항\\n   - 본 계약서에 명시되지 않은 사항은 관련 법령 및 상관례에 따릅니다.",
  "clientName": "김의뢰",
  "clientContact": "010-1234-5678",
  "clientEmail": "kim.client@company.com",
  "clientSignature": "김의뢰",
  "clientSignatureDate": "2025-01-10",
  "performerName": "이수행",
  "performerContact": "010-9876-5432",
  "performerEmail": "lee.designer@freelance.com",
  "performerSignature": "이수행",
  "employeeSignatureDate": "2025-01-10"
}',
  last_updated_at = NOW()
WHERE id = 5;


-- ========================================
-- 2. 일반 차용증 (ID: 3)
-- ========================================
UPDATE templates SET
  content = '<div style="font-family:\'Pretendard\',\'Noto Sans KR\',\'Malgun Gothic\',sans-serif;color:#1b2733;font-size:11pt;line-height:1.8;padding:40px 50px;">

  <h1 style="text-align:center;font-size:24pt;font-weight:700;color:#1b2733;margin:0 0 10px 0;letter-spacing:-0.5px;">차용증</h1>

  <div style="text-align:center;font-size:10pt;color:#6b7280;margin-bottom:30px;padding-bottom:15px;border-bottom:2px solid #1b2733;">
    채권·채무자 간 차용 조건과 상환 계획을 명확히 합의합니다.
  </div>

  <table style="width:100%;border-collapse:collapse;margin-bottom:20px;border:1px solid #d1d5db;">
    <tbody>
      <tr>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;width:20%;">
          차용일자
        </th>
        <td style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;width:30%;">
          {{loanDate}}
        </td>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;width:20%;">
          차용금액
        </th>
        <td style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;width:30%;">
          {{principalAmountInWords}} (₩{{principalAmount}})
        </td>
      </tr>
      <tr>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;">
          차용목적
        </th>
        <td colspan="3" style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;">
          {{loanPurpose}}
        </td>
      </tr>
    </tbody>
  </table>

  <ol style="margin:30px 0;padding-left:24px;font-size:10pt;line-height:1.9;color:#1f2937;">
    <li style="margin-bottom:12px;">
      채무자 <strong>{{borrowerName}}</strong>는 채권자 <strong>{{lenderName}}</strong>으로부터 {{loanDate}}에 상기 금액을 차용하였으며 {{principalRepaymentDate}}까지 변제합니다.
    </li>
    <li style="margin-bottom:12px;">
      원금 변제기 : {{principalRepaymentDate}} / 약정 이자율 : {{interestRate}}% / 이자 지급일 : 매월 {{interestPaymentDay}}일.
    </li>
    <li style="margin-bottom:12px;">
      원금과 이자는 지정일에 채권자 주소지에 지참·지불하거나, {{remittanceBank}} {{remittanceAccountNumber}} (예금주: {{remittanceAccountHolder}}) 계좌로 송금하여 변제합니다.
    </li>
    <li style="margin-bottom:12px;">
      지연 변제 시 채무자는 일 {{lateInterestRate}}%의 지연 손실금을 가산하여 지급합니다.
    </li>
    <li style="margin-bottom:12px;">
      다음 경우 최고 없이 기한의 이익을 상실하고 잔존 채무 전액을 즉시 변제합니다.
      <ul style="margin:8px 0;padding-left:24px;list-style-type:circle;">
        <li style="margin-bottom:6px;">이자의 지급을 {{missedInterestCount}}회 이상 지체할 때</li>
        <li style="margin-bottom:6px;">채무자 또는 연대보증인이 타 채권자로부터 가압류·강제집행을 받거나 파산·회생 절차를 개시할 때</li>
        <li style="margin-bottom:6px;">기타 본 약정 조항을 위반할 때</li>
      </ul>
    </li>
    <li style="margin-bottom:12px;">
      본 채권을 담보하거나 추심에 필요한 비용은 채무자가 부담합니다.
    </li>
    <li style="margin-bottom:12px;">
      본 채권에 관한 분쟁의 관할법원은 <strong>{{jurisdictionCourt}}</strong>로 합니다.
    </li>
  </ol>

  <table style="width:100%;border-collapse:collapse;margin-top:30px;border:1px solid #d1d5db;">
    <tbody>
      <tr>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;width:25%;">
          채권자
        </th>
        <td style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;line-height:1.7;">
          <strong>성명 :</strong> {{lenderName}}<br>
          <strong>주소 :</strong> {{lenderAddress}}<br>
          <strong>주민/사업자등록번호 :</strong> {{lenderIdNumber}}<br>
          <strong>연락처 :</strong> {{lenderContact}}<br>
          <strong>서명 :</strong> {{lenderSignature}} / <strong>서명일 :</strong> {{lenderSignDate}}
        </td>
      </tr>
      <tr>
        <th style="background-color:#f3f4f6;font-weight:600;text-align:center;padding:12px 15px;border:1px solid #d1d5db;font-size:10.5pt;color:#374151;">
          채무자
        </th>
        <td style="padding:12px 15px;border:1px solid #d1d5db;font-size:10pt;color:#1f2937;line-height:1.7;">
          <strong>성명 :</strong> {{borrowerName}}<br>
          <strong>주소 :</strong> {{borrowerAddress}}<br>
          <strong>주민/사업자등록번호 :</strong> {{borrowerIdNumber}}<br>
          <strong>연락처 :</strong> {{borrowerContact}}<br>
          <strong>서명 :</strong> {{borrowerSignature}} / <strong>서명일 :</strong> {{borrowerSignDate}}
        </td>
      </tr>
    </tbody>
  </table>

</div>',
  last_updated_at = NOW()
WHERE id = 3;


-- ========================================
-- 업데이트 완료 확인
-- ========================================
SELECT id, name, '업데이트 완료' as status FROM templates WHERE id IN (3, 5);
