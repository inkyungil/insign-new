# 작업 내역 - 2025-12-06
## Contracts V2 Phase 2: API 구현 및 서명 플로우 수정

---

## 📋 작업 개요

Contracts V2 시스템의 백엔드 API 구현 및 Flutter 앱 연동을 완료했습니다.
주요 이슈였던 블록체인 민팅 타이밍 문제를 수정하여 올바른 계약 서명 플로우를 구현했습니다.

---

## 🔧 주요 수정 사항

### 1. Backend API 구현 (NestJS)

#### 1.1 계약 목록 조회 API 구현
**파일**: `/home/insign/nestjs_app/src/contracts-v2/contracts-v2.service.ts`

**추가된 메서드**: `findByCreator()`
```typescript
async findByCreator(
  creatorId: number,
  status?: string,
  page: number = 1,
  limit: number = 20,
): Promise<{ contracts: ContractV2[]; total: number }>
```

**기능**:
- 사용자별 계약 목록 조회
- 상태별 필터링 지원 (draft, sent, signed, completed, declined, expired)
- 페이지네이션 지원 (page, limit)
- 암호화된 필드 자동 복호화
- 최신순 정렬 (createdAt DESC)

#### 1.2 데이터베이스 스키마 수정
**파일**:
- `/home/insign/nestjs_app/src/scripts/create-contracts-v2-tables.ts`
- 직접 SQL 실행

**추가된 컬럼**:
```sql
ALTER TABLE contracts_v2
ADD COLUMN viewer_token VARCHAR(128) UNIQUE NULL AFTER signature_request_sent_at,
ADD INDEX idx_viewer_token (viewer_token);
```

**목적**: 계약서 열람용 보안 토큰 지원

#### 1.3 생성자 서명 기능 추가 ⭐

**새로운 DTO**: `/home/insign/nestjs_app/src/contracts-v2/dto/sign-creator-v2.dto.ts`
```typescript
export class SignCreatorV2Dto {
  @IsString()
  signatureImage!: string; // Base64 signature image

  @IsString()
  @IsIn(['draw', 'upload'])
  signatureSource!: string;
}
```

**새로운 엔드포인트**: `POST /api/contracts-v2/:id/sign-creator`
**파일**: `/home/insign/nestjs_app/src/contracts-v2/contracts-v2.controller.ts`

**서비스 메서드**: `signAsCreator()`
```typescript
async signAsCreator(
  contractId: number,
  creatorId: number,
  dto: SignCreatorV2Dto,
): Promise<ContractV2>
```

**기능**:
- 생성자가 자신의 계약서에 서명
- 생성자 권한 확인
- 중복 서명 방지
- creatorSignedAt, creatorSignatureImage, creatorSignatureSource 저장

#### 1.4 이메일 발송 검증 강화
**파일**: `/home/insign/nestjs_app/src/contracts-v2/contracts-v2.service.ts`

**수정된 메서드**: `sendSignatureRequest()`

**추가된 검증**:
```typescript
// Verify creator has signed first
if (!contract.creatorSignedAt) {
  throw new BadRequestException(
    '생성자가 먼저 서명해야 이메일을 발송할 수 있습니다.',
  );
}
```

#### 1.5 양측 서명 완료 감지 및 상태 관리 ⭐
**파일**: `/home/insign/nestjs_app/src/contracts-v2/contracts-v2.service.ts`

**수정된 메서드**: `completeSignature()`

**핵심 로직**:
```typescript
// Check if both parties have signed
const bothSigned = contract.creatorSignedAt && contract.signerSignedAt;
contract.status = bothSigned ? 'completed' : 'signed';

if (bothSigned) {
  contract.completedAt = new Date();
}
```

**효과**: 양측 서명 완료 여부를 자동으로 감지하여 상태 업데이트

---

### 2. Frontend 수정 (Flutter)

#### 2.1 API 응답 형식 수정
**파일**: `/home/insign/insign_flutter/lib/data/contract_v2_repository.dart`

**문제**: API가 `{contracts: [], total: 0}` 형식으로 응답하는데 `requestList()`가 직접 배열만 받도록 되어 있어 오류 발생

**해결**:
```dart
Future<List<ContractV2>> fetchContractsV2({required String token}) async {
  final response = await ApiClient.request<Map<String, dynamic>>(
    path: ApiConfig.contractsV2,
    method: 'GET',
    token: token,
    fromJson: (json) => json,
  );

  final contractsJson = response['contracts'] as List<dynamic>?;
  if (contractsJson == null) {
    return [];
  }

  return contractsJson
      .whereType<Map<String, dynamic>>()
      .map((json) => ContractV2.fromJson(json))
      .toList();
}
```

#### 2.2 홈 화면 V2 API 마이그레이션
**파일**: `/home/insign/insign_flutter/lib/features/home/view/home_screen.dart`

**변경 사항**:
1. Repository 변경: `ContractRepository` → `ContractV2Repository`
2. Model 변경: `Contract` → `ContractV2`
3. Status 값 변경:
   - `'active'` → `ContractStatus.sent`
   - `'signature_completed'` → `ContractStatus.completed`
   - `'signature_declined'` → `ContractStatus.declined`
4. 필드명 변경:
   - `name` → `title`
   - `clientName` → `creatorName`
   - `performerName` → `signerName`
   - `updatedAt ?? createdAt` → `updatedAt` (non-nullable)

#### 2.3 생성자 서명 Repository 메서드 추가
**파일**: `/home/insign/insign_flutter/lib/data/contract_v2_repository.dart`

**추가된 메서드**:
```dart
Future<ContractV2> signAsCreator(
  String contractId,
  Map<String, dynamic> signDto,
  {required String token}
) async {
  return ApiClient.request<ContractV2>(
    path: '${ApiConfig.contractsV2}/$contractId/sign-creator',
    method: 'POST',
    token: token,
    body: signDto,
    fromJson: (json) => ContractV2.fromJson(json),
  );
}
```

#### 2.4 블록체인 민팅 조건 수정 ⭐
**파일**: `/home/insign/insign_flutter/lib/features/contracts_v2/view/contract_sign_v2_screen.dart`

**기존 문제**: 수행자 서명 직후 무조건 블록체인 민팅 실행

**수정 후**:
```dart
final completedContract = await _repository.completeSignature(
  widget.signatureToken,
  {
    'signatureImage': base64,
    'signatureSource': 'draw',
  }
);

// 양측 서명 완료 시에만 PDF 생성 및 블록체인 등록
if (contract != null && completedContract.status == ContractStatus.completed) {
  try {
    final pdfBytes = await buildContractV2Pdf(
      completedContract,
      signerSignatureBytes: bytes,
    );
    await _repository.uploadPdfBytes(contract.id, pdfBytes);
    await _repository.registerOnBlockchain(contract.id);
  } catch (e) {
    print('V2 PDF/Blockchain error: $e');
  }
}
```

**반환 타입 변경**:
```dart
// Before
Future<void> completeSignature(String signToken, Map<String, dynamic> completeDto)

// After
Future<ContractV2> completeSignature(String signToken, Map<String, dynamic> completeDto)
```

---

## 📊 계약 서명 플로우 (수정 전 vs 수정 후)

### ❌ 수정 전 (잘못된 플로우)
```
1. 생성자: 계약 생성 (draft)
2. 생성자: 이메일 발송 (sent)
3. 수행자: 서명 (signed)
   └─> ⚠️ 즉시 NFT 민팅 (잘못됨!)
```

### ✅ 수정 후 (올바른 플로우)
```
1. 생성자: 계약 생성 (draft)
   └─> POST /api/contracts-v2/create

2. 생성자: 본인 서명 (draft → draft with creator signature)
   └─> POST /api/contracts-v2/:id/sign-creator
   └─> creatorSignedAt, creatorSignatureImage 저장

3. 생성자: 이메일 발송 (draft → sent)
   └─> POST /api/contracts-v2/:id/send
   └─> ✓ 생성자 서명 여부 확인 (필수)
   └─> signatureToken 생성 및 이메일 발송

4. 수행자: 이메일 링크로 접속
   └─> GET /api/contracts-v2/sign/:token
   └─> 계약서 내용 확인

5. 수행자: 본인 확인 후 서명 (sent → completed)
   └─> POST /api/contracts-v2/sign/:token/verify
   └─> POST /api/contracts-v2/sign/:token/complete
   └─> signerSignedAt, signerSignatureImage 저장
   └─> ✓ 양측 서명 완료 감지 (creatorSignedAt && signerSignedAt)
   └─> status: 'completed', completedAt 설정

6. 양측 서명 완료 후 NFT 민팅 (completed 상태일 때만)
   └─> Flutter에서 status == ContractStatus.completed 확인
   └─> PDF 생성: buildContractV2Pdf()
   └─> POST /api/contracts-v2/:id/upload-pdf
   └─> POST /api/contracts-v2/:id/register-blockchain
   └─> ✓ 블록체인 등록 완료
```

---

## 🗂️ 수정된 파일 목록

### Backend (NestJS)
```
nestjs_app/
├── src/
│   ├── contracts-v2/
│   │   ├── contracts-v2.controller.ts         ✏️ 수정 (생성자 서명 엔드포인트 추가)
│   │   ├── contracts-v2.service.ts            ✏️ 수정 (findByCreator, signAsCreator, 양측 서명 감지)
│   │   └── dto/
│   │       └── sign-creator-v2.dto.ts         ✨ 신규 (생성자 서명 DTO)
│   └── scripts/
│       └── create-contracts-v2-tables.ts       ✏️ 수정 (viewer_token 컬럼 추가)
└── Database
    └── contracts_v2 테이블                      ✏️ 수정 (viewer_token 컬럼 및 인덱스 추가)
```

### Frontend (Flutter)
```
insign_flutter/
├── lib/
│   ├── data/
│   │   └── contract_v2_repository.dart         ✏️ 수정 (signAsCreator, fetchContractsV2 응답 형식, completeSignature 반환 타입)
│   └── features/
│       ├── home/view/
│       │   └── home_screen.dart                ✏️ 수정 (V2 API 마이그레이션, 상태/필드명 변경)
│       └── contracts_v2/view/
│           └── contract_sign_v2_screen.dart    ✏️ 수정 (블록체인 민팅 조건 추가)
```

---

## 🧪 테스트 체크리스트

### Backend API 테스트
- [ ] `POST /api/contracts-v2/create` - 계약 생성
- [ ] `POST /api/contracts-v2/:id/sign-creator` - 생성자 서명
  - [ ] 생성자 권한 확인
  - [ ] 중복 서명 방지
- [ ] `POST /api/contracts-v2/:id/send` - 이메일 발송
  - [ ] 생성자 미서명 시 오류
  - [ ] 생성자 서명 완료 시 정상 발송
- [ ] `POST /api/contracts-v2/sign/:token/complete` - 수행자 서명
  - [ ] 양측 서명 완료 시 status = 'completed'
  - [ ] 한쪽만 서명 시 status = 'signed'
- [ ] `GET /api/contracts-v2` - 계약 목록 조회
  - [ ] 빈 배열 정상 반환
  - [ ] 페이지네이션 동작
  - [ ] 상태별 필터링

### Frontend 테스트
- [ ] 홈 화면 계약 목록 표시
  - [ ] 빈 상태 정상 표시
  - [ ] V2 API 응답 정상 파싱
- [ ] 계약 생성 → 생성자 서명 → 이메일 발송 플로우
- [ ] 수행자 서명 후 블록체인 민팅
  - [ ] 양측 서명 완료 시에만 실행
  - [ ] status == 'completed' 확인

---

## 📝 남은 작업 (Phase 3)

### 필수 기능
1. **생성자 서명 UI 구현**
   - 계약 생성 후 서명 화면 추가
   - Signature widget 재사용
   - API 연동 (`signAsCreator()`)

2. **계약 상세 화면**
   - 생성자/수행자 서명 상태 표시
   - 블록체인 등록 정보 표시
   - PDF 다운로드 기능

3. **오류 처리 개선**
   - 네트워크 오류 처리
   - 블록체인 등록 실패 시 재시도 로직
   - 사용자 친화적 오류 메시지

### 선택 기능
1. 계약서 미리보기
2. 서명 이력 조회
3. 알림 설정
4. 계약서 검색/필터링 고도화

---

## 🐛 알려진 이슈

1. **Flutter Analyze Warnings**:
   - `WillPopScope` deprecated (→ `PopScope` 사용 권장)
   - `invalid_null_aware_operator` (line 259)
   - `use_build_context_synchronously` (line 1093)

2. **TODO 항목**:
   - JWT 인증 가드 활성화 (현재 userId = 1 하드코딩)
   - PDF 생성 실패 시 재시도 로직
   - 블록체인 등록 실패 시 관리자 알림

---

## 💡 기술 노트

### 암호화된 필드 처리
- Backend: `EncryptionService`로 자동 암호화/복호화
- 암호화 대상: creatorName, creatorEmail, creatorPhone, signerName, signerEmail, signerPhone, contractData

### 상태 관리
- Contract Status: draft → sent → signed → completed
- creatorSignedAt: 생성자 서명 시점
- signerSignedAt: 수행자 서명 시점
- completedAt: 양측 서명 완료 시점

### 보안
- signatureToken: 수행자 서명용 토큰 (7일 만료)
- viewerToken: 계약서 열람용 토큰 (만료 없음)
- 각 토큰은 64자리 랜덤 hex (randomBytes(32))

---

## 👤 작업자
- Claude Code (Sonnet 4.5)
- 작업 일시: 2025-12-06

## 📚 참고 문서
- `/home/insign/CLAUDE.md` - 프로젝트 가이드
- `/home/insign/insign_flutter/CLAUDE.md` - Flutter 가이드
- `/home/insign/작업내역_2025-12-05_A4계약서디자인.md` - 이전 작업 내역
- `/home/insign/작업내역_2025-12-06_ContractsV2_Phase1.md` - Phase 1 작업 내역

---

**End of Document**
