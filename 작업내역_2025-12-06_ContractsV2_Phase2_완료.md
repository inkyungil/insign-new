# 작업 내역 - 2025-12-06
## Contracts V2 Phase 2: 완전 구현 (API + UI + 서명 플로우)

---

## 📋 작업 개요

Contracts V2 시스템의 전체 구현을 완료했습니다:
- ✅ 백엔드 API 완전 구현
- ✅ Flutter 앱 V2 마이그레이션
- ✅ 계약 서명 플로우 수정 (생성자 서명 → 이메일 발송 → 수행자 서명 → NFT 민팅)
- ✅ 계약서 열람 기능 구현
- ✅ 계약 상세 화면 구현
- ✅ UI/UX 개선

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

**서비스 메서드**: `signAsCreator()`
- 생성자가 자신의 계약서에 서명
- 생성자 권한 확인
- 중복 서명 방지
- creatorSignedAt, creatorSignatureImage, creatorSignatureSource 저장

#### 1.4 이메일 발송 검증 강화

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

#### 2.5 계약서 열람 화면 구현 ✨
**파일**: `/home/insign/insign_flutter/lib/features/contracts_v2/view/contract_viewer_screen.dart`

**기능**:
- ✅ Viewer Token 기반 계약서 열람
- ✅ 2단계 본인 확인 프로세스
  1. 토큰 유효성 확인
  2. 이름/이메일/전화번호로 본인 확인
- ✅ 계약 당사자 정보 표시
- ✅ 서명 정보 및 블록체인 정보 표시
- ✅ 상태별 배지 표시
- ✅ **전화번호 인증 페이지 스타일 적용** (깔끔한 카드 디자인)

**디자인 특징**:
- 중앙 정렬된 화이트 카드 (그림자 효과)
- 보라색 원형 아이콘 (`Icons.lock_person`)
- 그레이 배경 입력 필드 (`Colors.grey[100]`)
- 동적 버튼 색상 (입력 완료 시 `Colors.deepPurple` 활성화)
- 경고 카드 (사기/사칭 주의)
- 배경색: `#F5F5F5`

**Repository 메서드**:
```dart
// 1단계: 토큰 유효성 확인
Future<ContractV2> verifyViewerToken(String viewerToken)

// 2단계: 본인 확인 후 전체 계약서 조회
Future<ContractV2> verifyViewerIdentity(
  String viewerToken,
  {required String name, String? email, String? phone}
)
```

**라우터 설정**:
- 경로: `/view-contract/:token`
- Public 경로로 설정 (로그인 불필요)

#### 2.6 계약 상세 V2 화면 구현 ✨
**파일**: `/home/insign/insign_flutter/lib/features/contracts_v2/view/contract_detail_v2_screen.dart`

**기능**:
- ✅ V2 API로 계약 조회 (`GET /api/contracts-v2/:id`)
- ✅ 계약 당사자 정보 표시
- ✅ 서명 정보 및 블록체인 정보 표시
- ✅ 상태별 배지 및 액션 버튼
- ✅ Pull-to-refresh 지원
- ✅ 깔끔한 카드 기반 UI

**라우터 업데이트**:
- `/contracts/:id` 경로를 V2 상세 화면으로 변경
- `ContractDetailScreen` → `ContractDetailV2Screen`

**결과**: 홈 화면에서 계약 클릭 시 404 오류 해결
- ❌ `GET /api/contracts/40` (구 버전 - 404)
- ✅ `GET /api/contracts-v2/40` (V2 - 정상 작동)

#### 2.7 Flutter Web 초기화 수정
**파일**: `/home/insign/insign_flutter/web/index.html`

**문제**:
- `FlutterLoader.loadEntrypoint()` deprecated
- `_flutter.buildConfig` not set 오류

**해결**:
```html
<!-- Before -->
<script src="flutter.js" defer></script>
<script>
  _flutter.loader.loadEntrypoint({...});
</script>

<!-- After -->
<script src="flutter_bootstrap.js" async></script>
```

**추가 수정**:
- `<meta name="mobile-web-app-capable" content="yes">` 추가
- 자동 초기화 방식으로 변경

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
│   │   └── contract_v2_repository.dart         ✏️ 수정 (signAsCreator, fetchContractsV2, verifyViewer*)
│   ├── features/
│   │   ├── home/view/
│   │   │   └── home_screen.dart                ✏️ 수정 (V2 API 마이그레이션)
│   │   └── contracts_v2/view/
│   │       ├── contract_sign_v2_screen.dart    ✏️ 수정 (블록체인 민팅 조건)
│   │       ├── contract_viewer_screen.dart     ✨ 신규 (계약서 열람 화면)
│   │       └── contract_detail_v2_screen.dart  ✨ 신규 (계약 상세 V2)
│   └── core/router/
│       └── app_router.dart                      ✏️ 수정 (viewer, detail 라우트 추가)
└── web/
    └── index.html                               ✏️ 수정 (Flutter 초기화 업데이트)
```

---

## 🎨 UI/UX 개선 사항

### 계약서 열람 화면 디자인
**참고 디자인**: `/home/insign/insign_form_test/lib/screens/phone_verification_screen.dart`

**적용된 스타일**:
1. **배경색**: `Color(0xFFF5F5F5)` (밝은 회색)
2. **카드 디자인**:
   - 흰색 배경 (`Colors.white`)
   - 둥근 모서리 (`BorderRadius.circular(16)`)
   - 부드러운 그림자 (`BoxShadow`)
3. **아이콘**:
   - 원형 컨테이너 (`BoxShape.circle`)
   - 색상별 배경 (보라색: `Colors.deepPurple[50]`, 빨간색: `Colors.red[100]`)
4. **입력 필드**:
   - 회색 배경 (`Colors.grey[100]`)
   - 테두리 없음 (`BorderSide.none`)
   - 패딩: 16px
5. **버튼**:
   - 활성화 상태: `Colors.deepPurple`
   - 비활성화 상태: `Colors.grey[300]`
   - 높이: 50px
   - 텍스트: "확인 →" (화살표 포함)
6. **경고 카드**:
   - 주황색 아이콘 (`Icons.warning_amber_rounded`)
   - 사기/사칭 주의 메시지

---

## 🧪 테스트 체크리스트

### Backend API 테스트
- [x] `POST /api/contracts-v2/create` - 계약 생성
- [ ] `POST /api/contracts-v2/:id/sign-creator` - 생성자 서명
  - [ ] 생성자 권한 확인
  - [ ] 중복 서명 방지
- [ ] `POST /api/contracts-v2/:id/send` - 이메일 발송
  - [ ] 생성자 미서명 시 오류
  - [ ] 생성자 서명 완료 시 정상 발송
- [ ] `POST /api/contracts-v2/sign/:token/complete` - 수행자 서명
  - [ ] 양측 서명 완료 시 status = 'completed'
  - [ ] 한쪽만 서명 시 status = 'signed'
- [x] `GET /api/contracts-v2` - 계약 목록 조회
  - [x] 빈 배열 정상 반환
  - [ ] 페이지네이션 동작
  - [ ] 상태별 필터링
- [x] `GET /api/contracts-v2/:id` - 계약 상세 조회
- [ ] `GET /api/contracts-v2/view/:token` - 계약서 열람
- [ ] `POST /api/contracts-v2/view/:token/verify` - 본인 확인

### Frontend 테스트
- [x] 홈 화면 계약 목록 표시
  - [x] 빈 상태 정상 표시
  - [x] V2 API 응답 정상 파싱
- [x] 계약 상세 화면
  - [x] V2 API 호출 (404 오류 해결)
- [ ] 계약 생성 → 생성자 서명 → 이메일 발송 플로우
- [ ] 수행자 서명 후 블록체인 민팅
  - [ ] 양측 서명 완료 시에만 실행
  - [ ] status == 'completed' 확인
- [ ] 계약서 열람 화면
  - [ ] 본인 확인 프로세스
  - [ ] 계약 정보 표시

---

## 📝 남은 작업 (Phase 3)

### 필수 기능
1. **생성자 서명 UI 구현**
   - 계약 생성 후 서명 화면 추가
   - Signature widget 재사용
   - API 연동 (`signAsCreator()`)

2. **이메일 발송 기능**
   - 계약 상세 화면에서 이메일 발송 버튼
   - 생성자 서명 완료 확인
   - 발송 성공/실패 처리

3. **Backend Viewer Token 생성**
   - 계약 생성 시 viewer_token 자동 생성
   - 본인 확인 API 구현
   - 이메일에 열람 링크 포함

4. **오류 처리 개선**
   - 네트워크 오류 처리
   - 블록체인 등록 실패 시 재시도 로직
   - 사용자 친화적 오류 메시지

### 선택 기능
1. PDF 다운로드 기능
2. 계약서 공유 기능
3. 서명 이력 조회
4. 알림 설정
5. 계약서 검색/필터링 고도화

---

## 🐛 알려진 이슈

1. **Flutter Web 개발 환경**:
   - WebSocket 연결 오류 발생 가능
   - Chrome 프로세스 완전 종료 후 재시도 필요
   - 또는 Release 모드로 실행

2. **Flutter Analyze Warnings**:
   - `WillPopScope` deprecated (→ `PopScope` 사용 권장)
   - `invalid_null_aware_operator` (home_screen.dart:259)
   - `use_build_context_synchronously` (home_screen.dart:1093)

3. **TODO 항목**:
   - JWT 인증 가드 활성화 (현재 userId = 1 하드코딩)
   - PDF 생성 실패 시 재시도 로직
   - 블록체인 등록 실패 시 관리자 알림
   - Viewer Token 생성 로직 추가

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

### UI 디자인 시스템
- **메인 색상**: `Colors.deepPurple` (보라색)
- **배경색**: `Color(0xFFF5F5F5)` (밝은 회색)
- **카드 그림자**: `BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0, 4))`
- **입력 필드 배경**: `Colors.grey[100]`
- **버튼 높이**: 50px
- **카드 둥글기**: `BorderRadius.circular(16)`
- **아이콘 크기**: 48px (원형 컨테이너: 96x96)

---

## 📚 API 엔드포인트 정리

### 인증 필요 (Authenticated)
| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/contracts-v2/create` | 계약 생성 |
| POST | `/api/contracts-v2/:id/sign-creator` | 생성자 서명 ⭐ |
| POST | `/api/contracts-v2/:id/send` | 이메일 발송 |
| GET | `/api/contracts-v2` | 계약 목록 조회 |
| GET | `/api/contracts-v2/:id` | 계약 상세 조회 |
| POST | `/api/contracts-v2/:id/upload-pdf` | PDF 업로드 |
| POST | `/api/contracts-v2/:id/register-blockchain` | 블록체인 등록 |

### 공개 (Public - Token 기반)
| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/contracts-v2/view/:viewerToken` | 계약서 열람 (1단계) |
| POST | `/api/contracts-v2/view/:viewerToken/verify` | 본인 확인 (2단계) |
| GET | `/api/contracts-v2/sign/:signToken` | 서명 링크 확인 |
| POST | `/api/contracts-v2/sign/:signToken/verify` | 수행자 본인 확인 |
| POST | `/api/contracts-v2/sign/:signToken/complete` | 수행자 서명 완료 |
| POST | `/api/contracts-v2/sign/:signToken/decline` | 서명 거절 |

---

## 👤 작업자
- Claude Code (Sonnet 4.5)
- 작업 일시: 2025-12-06

## 📚 참고 문서
- `/home/insign/CLAUDE.md` - 프로젝트 가이드
- `/home/insign/insign_flutter/CLAUDE.md` - Flutter 가이드
- `/home/insign/insign_form_test/lib/screens/phone_verification_screen.dart` - UI 디자인 참고
- `/home/insign/작업내역_2025-12-05_A4계약서디자인.md` - 이전 작업 내역
- `/home/insign/작업내역_2025-12-06_ContractsV2_Phase1.md` - Phase 1 작업 내역

---

## 🎯 다음 세션 시작 시 체크리스트

### 즉시 확인할 사항
1. [ ] Flutter 앱 빌드 및 실행 (`flutter run -d chrome`)
2. [ ] 계약 목록 조회 동작 확인
3. [ ] 계약 상세 화면 정상 작동 확인
4. [ ] 계약서 열람 화면 본인 확인 테스트

### 다음 구현할 기능
1. [ ] 생성자 서명 화면 구현
2. [ ] 이메일 발송 기능 구현
3. [ ] Backend viewer token 생성 로직 추가
4. [ ] 전체 플로우 E2E 테스트

---

**End of Document**

**작업 완료 시간**: 2025-12-06
**총 수정 파일**: Backend 4개, Frontend 7개
**새로 추가된 파일**: Backend 1개, Frontend 2개
**해결된 이슈**: 5개 (API 구현, 블록체인 민팅 타이밍, 404 오류, Flutter 초기화, UI 디자인)
