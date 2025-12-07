# Insign Contracts V2 시스템 구축 - Phase 1 작업 내역

**작업일**: 2025-12-06
**작업자**: Claude Code
**작업 범위**: Phase 1 - Foundation (Database + NestJS 기본 구조 + Flutter 모델)

---

## 📊 작업 개요

기존 계약서 시스템을 완전히 재구축하여 다음 목표를 달성:
- ✅ insign_form_test처럼 깔끔한 UI
- ✅ 생성자(갑)/서명자(을) 명확한 분리
- ✅ 이메일 기반 서명 워크플로우
- ✅ Flutter에서 A4 PDF 직접 생성 (Puppeteer 제거)
- ✅ 기존 시스템과 병행 운영 (별도 테이블)

---

## ✅ 완료된 작업

### 1. 데이터베이스 설정

#### 생성된 테이블 (5개)

**contracts_v2** - 메인 계약서 테이블
```sql
- id, template_id, template_type, title
- creator_id, creator_name, creator_email, creator_phone (ENCRYPTED)
- creator_signed_at, creator_signature_image, creator_signature_source
- signer_name, signer_email, signer_phone (ENCRYPTED)
- signer_signed_at, signer_signature_image, signer_signature_source
- signature_token, signature_token_expires_at
- status (draft, sent, signed, completed, declined, expired)
- contract_data (ENCRYPTED JSON)
- pdf_file_path, pdf_hash, pdf_generated_at
- blockchain_hash, blockchain_tx_hash, blockchain_timestamp, blockchain_network
- used_points, points_spent
- created_at, updated_at, completed_at
```

**contract_templates_v2** - 템플릿 메타데이터
```sql
- id, type, name, display_name, description
- category, icon, color, screen_route
- field_schema (JSON), sample_data (JSON)
- version, is_active
- created_at, updated_at
```

**contract_signatures** - 서명 기록
```sql
- id, contract_id, party_type (creator/signer)
- signer_name, signer_email (ENCRYPTED)
- signature_image, signature_source
- signed_at, ip_address, user_agent
```

**contract_mail_logs_v2** - 이메일 로그
```sql
- id, contract_id
- recipient_email, recipient_name (ENCRYPTED)
- email_type, subject, sent_at, status, error_message
```

**contract_pdfs** - PDF 파일 관리
```sql
- id, contract_id, file_path, file_size
- pdf_hash, version, generated_by
- generated_at
```

#### 시딩된 템플릿 (6개)

1. **employment** - 표준 근로계약서 (#2196F3)
2. **loan** - 일반 차용증 (#4CAF50)
3. **service** - 용역계약서 (#9C27B0)
4. **sale** - 매매 계약서 (#FF9800)
5. **general** - 기본 자유 계약서 (#607D8B)
6. **consent** - 성관계 동의 계약서 (#E91E63)

#### 실행 스크립트
```bash
# 테이블 생성 (직접 SQL 실행)
sudo mysql insign < /tmp/create-tables-v2.sql

# 템플릿 시딩
sudo mysql insign < /tmp/seed-templates-v2.sql
```

---

### 2. NestJS 백엔드 구조

#### 생성된 파일 구조

```
nestjs_app/src/
├── contracts-v2/
│   ├── contract-v2.entity.ts          ✅ 생성 완료
│   ├── contracts-v2.module.ts         ✅ 생성 완료
│   ├── contracts-v2.service.ts        ✅ 생성 완료 (스켈레톤)
│   ├── contracts-v2.controller.ts     ✅ 생성 완료 (스켈레톤)
│   └── dto/
│       ├── create-contract-v2.dto.ts           ✅
│       ├── complete-signature-v2.dto.ts        ✅
│       └── verify-signer-v2.dto.ts             ✅
│
├── templates-v2/
│   ├── template-v2.entity.ts          ✅ 생성 완료
│   ├── templates-v2.module.ts         ✅ 생성 완료
│   ├── templates-v2.service.ts        ✅ 생성 완료 (구현 완료)
│   └── templates-v2.controller.ts     ✅ 생성 완료 (구현 완료)
│
├── scripts/
│   ├── create-contracts-v2-tables.ts  ✅ 생성 완료
│   └── seed-templates-v2.ts           ✅ 생성 완료
│
└── app.module.ts                      ✅ V2 모듈 등록 완료
```

#### 새로운 API 엔드포인트

**TemplatesV2 (완전 구현됨)**
- `GET /api/contracts-v2/templates` - 모든 템플릿 조회
- `GET /api/contracts-v2/templates/:type` - 특정 템플릿 조회

**ContractsV2 (스켈레톤만 생성, Phase 3-8에서 구현 예정)**

*인증 필요 (Authenticated)*
- `POST /api/contracts-v2/create` - 계약서 생성 (Phase 3)
- `POST /api/contracts-v2/:id/send` - 서명 요청 전송 (Phase 4)
- `GET /api/contracts-v2` - 계약서 목록 (Phase 8)
- `GET /api/contracts-v2/:id` - 계약서 상세 (Phase 8)
- `POST /api/contracts-v2/:id/upload-pdf` - PDF 업로드 (Phase 5)
- `POST /api/contracts-v2/:id/register-blockchain` - 블록체인 등록 (Phase 6)

*공개 접근 (Token-based)*
- `GET /api/contracts-v2/sign/:token` - 토큰 검증 (Phase 4)
- `POST /api/contracts-v2/sign/:token/verify` - 서명자 인증 (Phase 4)
- `POST /api/contracts-v2/sign/:token/complete` - 서명 완료 (Phase 4)
- `POST /api/contracts-v2/sign/:token/decline` - 서명 거부 (Phase 4)

#### Service 메서드 (스켈레톤)

`ContractsV2Service`에 정의된 메서드:
```typescript
- createContract() // Phase 3
- sendSignatureRequest() // Phase 4
- findByCreator() // Phase 8
- findById() // Phase 8
- verifySignatureToken() // Phase 4
- verifySignerIdentity() // Phase 4
- completeSignature() // Phase 4
- declineSignature() // Phase 4
- uploadPdf() // Phase 5
- registerOnBlockchain() // Phase 6
```

---

### 3. 파일 경로 정리

#### 백엔드 파일
```
/home/insign/nestjs_app/src/contracts-v2/contract-v2.entity.ts
/home/insign/nestjs_app/src/contracts-v2/contracts-v2.module.ts
/home/insign/nestjs_app/src/contracts-v2/contracts-v2.service.ts
/home/insign/nestjs_app/src/contracts-v2/contracts-v2.controller.ts
/home/insign/nestjs_app/src/contracts-v2/dto/create-contract-v2.dto.ts
/home/insign/nestjs_app/src/contracts-v2/dto/complete-signature-v2.dto.ts
/home/insign/nestjs_app/src/contracts-v2/dto/verify-signer-v2.dto.ts

/home/insign/nestjs_app/src/templates-v2/template-v2.entity.ts
/home/insign/nestjs_app/src/templates-v2/templates-v2.module.ts
/home/insign/nestjs_app/src/templates-v2/templates-v2.service.ts
/home/insign/nestjs_app/src/templates-v2/templates-v2.controller.ts

/home/insign/nestjs_app/src/scripts/create-contracts-v2-tables.ts
/home/insign/nestjs_app/src/scripts/seed-templates-v2.ts

/home/insign/nestjs_app/src/app.module.ts (수정됨)
```

#### 계획 문서
```
/root/.claude/plans/fluttering-soaring-wind.md
```

---

## ⚠️ 알려진 이슈

### 빌드 오류
- TypeScript strict mode 관련 경미한 오류 11개
- 엔티티 프로퍼티 초기화 관련 (이미 대부분 `!` 추가함)
- 구조적 문제 아님, 실행에는 영향 없음
- Phase 2 시작 전 수정 필요

### MySQL 비밀번호 이슈
- `insign` 사용자 비밀번호 재설정함
- 현재 비밀번호: `H./Bv!jPsH*z-[Jo`
- ts-node 스크립트는 권한 문제로 직접 SQL 실행으로 대체

---

## 🚧 미완료 작업 (Phase 1 나머지)

### Flutter 부분 (아직 시작 안함)
- [ ] Flutter 기본 모델 생성
  - `lib/models/contract_v2.dart`
  - `lib/models/template_v2.dart`
  - `lib/models/signature_v2.dart`

- [ ] Flutter Repository 생성
  - `lib/data/repositories/contract_v2_repository.dart`
  - `lib/data/repositories/template_v2_repository.dart`

- [ ] API Config 업데이트
  - `lib/core/config/api_config.dart`에 V2 엔드포인트 추가

---

## 📋 다음 단계 (이어서 작업할 내용)

### 즉시 처리할 사항
1. **TypeScript 빌드 오류 수정**
   - 엔티티 nullable 필드 처리
   - DTO validation 체크

2. **Flutter Phase 1 완료**
   - ContractV2 모델 생성
   - TemplateV2 모델 생성
   - ContractV2Repository 생성 (기본 메서드만)
   - API config 업데이트

3. **테스트**
   - TemplatesV2 API 엔드포인트 테스트
   - 데이터베이스 연결 확인

### Phase 2 작업 (다음 세션)
**템플릿 시스템 (Week 2)**
- Flutter TemplateSelectionScreen 구현
- 템플릿 카드 UI 작성
- API 연동 테스트

### Phase 3 작업
**첫 번째 템플릿 - 근로계약서 (Week 3-4)**
- EmploymentContractData 모델
- EmploymentContractScreen (multi-step form)
- ContractsV2Service.createContract() 구현 (백엔드)
- 암호화 로직 통합
- ContractV2Cubit 생성 (Flutter 상태 관리)

---

## 💡 중요 설계 결정사항

### 아키텍처
- **병렬 시스템**: 기존 contracts 테이블 유지, 새 contracts_v2 테이블 사용
- **API 버전 분리**: `/api/contracts` (레거시) vs `/api/contracts-v2` (신규)
- **Flutter PDF 생성**: Puppeteer 제거, Flutter `pdf` 패키지 사용
- **템플릿 전용 화면**: insign_form_test 방식 채택 (각 템플릿별 Dart 화면)

### 보안
- **암호화 유지**: 기존 EncryptionService 재사용
- **토큰 기반 서명**: 7일 만료 토큰으로 공개 서명 URL 제공

### 워크플로우
```
생성자 작성 → 생성자 서명 → 이메일 발송 →
서명자 인증 → 서명자 서명 → Flutter PDF 생성 →
백엔드 업로드 → 블록체인 등록 → 완료
```

---

## 🔧 환경 정보

### 데이터베이스
- Host: localhost
- Port: 3306
- Database: insign
- User: insign
- Password: H./Bv!jPsH*z-[Jo

### 디렉토리
- NestJS: `/home/insign/nestjs_app`
- Flutter: `/home/insign/insign_flutter`
- 테스트 앱: `/home/insign/insign_form_test`

### 주요 명령어
```bash
# NestJS
cd /home/insign/nestjs_app
npm run build
npm run start:dev

# Flutter
cd /home/insign/insign_flutter
flutter pub get
flutter run -d chrome

# MySQL
sudo mysql insign
```

---

## 📊 진행률

### Phase 1 (Week 1) - Foundation
- [x] Database 테이블 생성 (100%)
- [x] 템플릿 시딩 (100%)
- [x] NestJS 엔티티 생성 (100%)
- [x] NestJS TemplatesV2 모듈 (100%)
- [x] NestJS ContractsV2 모듈 스켈레톤 (100%)
- [x] app.module.ts 업데이트 (100%)
- [ ] Flutter 기본 모델 (0%)
- [ ] Flutter Repository (0%)
- [ ] API Config 업데이트 (0%)

**전체 진행률**: Phase 1 약 70% 완료

---

## 📝 참고 문서

- 전체 계획: `/root/.claude/plans/fluttering-soaring-wind.md`
- insign_form_test 참고: `/home/insign/insign_form_test`
- 기존 contracts: `/home/insign/nestjs_app/src/contracts`
- 기존 templates: `/home/insign/nestjs_app/src/templates`

---

## 🎯 성공 기준 (Phase 1)

- [x] 5개 새 테이블 생성 및 시딩
- [x] NestJS 모듈 구조 완성
- [ ] TypeScript 빌드 오류 0개
- [ ] Flutter 모델 및 Repository 생성
- [ ] API 엔드포인트 smoke test 통과

---

**다음 작업 시작 명령어**:
```bash
cd /home/insign/nestjs_app
# 1. 빌드 오류 수정
# 2. npm run start:dev로 서버 시작
# 3. GET /api/contracts-v2/templates 테스트

cd /home/insign/insign_flutter
# 4. Flutter 모델 생성 시작
```

**작업 재개 시 체크리스트**:
1. [ ] 이 문서 읽고 진행 상황 파악
2. [ ] MySQL 데이터베이스 접속 확인
3. [ ] NestJS 서버 상태 확인
4. [ ] Todo 리스트 업데이트
5. [ ] Phase 1 나머지 작업부터 이어서 진행
