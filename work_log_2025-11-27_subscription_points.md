# 작업 내역 - 2025-11-27

## 📋 작업 요약

1. 한글 파일명 영문화
2. 계약 상태 필터 개선
3. Inbox 메시지 저장 기능 추가
4. UI 레이아웃 조정
5. **구독 및 포인트 시스템 구축** ⭐

---

## 1️⃣ 한글 파일명 → 영문 변경

### 변경된 파일들
```
작업내역_2025-11-27.md → work_log_2025-11-27.md
작업내역_2025-11-26.md → work_log_2025-11-26.md
앱_개선안_분석_2025-11-27.md → app_improvement_analysis_2025-11-27.md
작업내역_2025-11-07_PlayStore배포준비.md → work_log_2025-11-07_playstore_deployment.md
작업내역_개인정보_암호화_확장.md → work_log_privacy_encryption_extension.md
작업내역_2025-11-01_3차.md → work_log_2025-11-01_phase3.md
```

### 이유
- 에디터에서 한글 파일명 열기 문제 해결
- 버전 관리 호환성 향상

---

## 2️⃣ 계약 상태 필터 개선

### 변경 파일
- `insign_flutter/lib/features/contracts/view/contracts_screen.dart`

### 기존 필터
```dart
['전체', '진행중', '완료', '기한만료']
```

### 개선된 필터
```dart
['전체', '작성중', '서명대기', '완료', '거절됨', '기한만료']
```

### 필터별 설명
| 필터 | 상태 | 설명 |
|------|------|------|
| 전체 | - | 모든 계약서 표시 |
| 작성중 | `draft` | 기안 완료 상태 |
| 서명대기 | `active` | 서명 요청 전송됨 |
| 완료 | `signature_completed` | 서명 완료 |
| 거절됨 | `signature_declined` | 서명 거절 |
| 기한만료 | `expired` | endDate가 지난 계약 |

---

## 3️⃣ Inbox 메시지 저장 기능 추가

### 문제
- 계약 서명 완료 시 Push 알림만 전송
- Inbox 메시지함에 기록되지 않음

### 해결
**파일:** `nestjs_app/src/contracts/contracts.module.ts`
```typescript
import { InboxModule } from "../inbox/inbox.module";

@Module({
  imports: [
    // ...
    InboxModule,
  ],
})
```

**파일:** `nestjs_app/src/contracts/contracts.service.ts`
```typescript
// 서명 완료 알림 전송
if (saved.createdByUserId) {
  // 1. Inbox에 메시지 저장
  await this.inboxService.createForUser(saved.createdByUserId, {
    kind: 'alert',
    title: '계약서 서명 완료',
    body: `${performerName}님이 "${contractName}" 계약서에 서명했습니다.`,
    tags: ['push/admin/contract', 'signature_completed'],
    metadata: { contractId, contractName, type: 'contract_completed' },
  });

  // 2. Push 알림 전송
  await this.pushNotificationsService.sendContractCompletedNotification(...);
}
```

### 결과
- ✅ Inbox "계약 진행" 필터에 메시지 표시
- ✅ Push 알림과 Inbox 모두 저장

---

## 4️⃣ UI 레이아웃 조정

### 상단 여백 조정
**변경 파일:**
- `contracts_screen.dart`
- `templates_screen.dart`
- `inbox_screen.dart`
- `profile_screen.dart`

**변경 내용:**
```dart
// Before: 36px
padding: const EdgeInsets.fromLTRB(20, 36, 20, 12)

// After: 15px
padding: const EdgeInsets.fromLTRB(20, 15, 20, 12)
```

### 프로필 화면 설명 수정
**파일:** `profile_screen.dart`

```dart
// Before
Text(user?.email ?? '로그인 정보를 확인할 수 없습니다.')

// After
const Text('내 정보와 설정을 관리할 수 있어요.')
```

---

## 5️⃣ 구독 및 포인트 시스템 구축 ⭐

### 📊 비즈니스 모델

#### 무료 플랜 (FREE)
```
월 4개 계약서 무료 제공
├─ 기본 제공: 4개/월
├─ 추가 작성: 포인트 3개 = 계약서 1개
└─ 매월 1일 자동 리셋
```

#### 포인트 시스템
```
월 12포인트 제공
├─ 출석 체크: 매일 1포인트
├─ 광고 시청: 1포인트 (나중에 구현)
└─ 월 최대 12포인트 획득 가능
```

#### 프리미엄 플랜 (나중에)
```
무제한 계약서 작성
├─ 광고 없음
└─ 우선 지원
```

---

### 🗄️ 데이터베이스 스키마

#### User 테이블 추가 필드
**파일:** `nestjs_app/src/users/user.entity.ts`

```typescript
// 구독 티어
@Column({ name: "subscription_tier", type: "varchar", length: 20, default: "free" })
subscriptionTier!: "free" | "premium";

// 계약서 제한
@Column({ name: "monthly_contract_limit", type: "int", default: 4 })
monthlyContractLimit!: number;

@Column({ name: "contracts_used_this_month", type: "int", default: 0 })
contractsUsedThisMonth!: number;

@Column({ name: "last_reset_date", type: "date", nullable: true })
lastResetDate?: Date | null;

// 포인트 시스템
@Column({ name: "points", type: "int", default: 12 })
points!: number;

@Column({ name: "monthly_points_limit", type: "int", default: 12 })
monthlyPointsLimit!: number;

@Column({ name: "points_earned_this_month", type: "int", default: 0 })
pointsEarnedThisMonth!: number;

@Column({ name: "last_check_in_date", type: "date", nullable: true })
lastCheckInDate?: Date | null;
```

#### 마이그레이션
**파일:** `migrations/20241127_add_subscription_points_system.sql`

```sql
ALTER TABLE users
ADD COLUMN subscription_tier VARCHAR(20) NOT NULL DEFAULT 'free',
ADD COLUMN monthly_contract_limit INT NOT NULL DEFAULT 4,
ADD COLUMN contracts_used_this_month INT NOT NULL DEFAULT 0,
ADD COLUMN last_reset_date DATE NULL,
ADD COLUMN points INT NOT NULL DEFAULT 12,
ADD COLUMN monthly_points_limit INT NOT NULL DEFAULT 12,
ADD COLUMN points_earned_this_month INT NOT NULL DEFAULT 0,
ADD COLUMN last_check_in_date DATE NULL;
```

---

### 🔧 백엔드 로직

#### UsersService 메소드
**파일:** `nestjs_app/src/users/users.service.ts`

##### 1. 월간 리셋
```typescript
async checkAndResetMonthlyLimits(userId: number): Promise<void>
```
- 매월 1일 자동 리셋
- `contractsUsedThisMonth = 0`
- `pointsEarnedThisMonth = 0`
- 무료 사용자: `points = monthlyPointsLimit`

##### 2. 계약서 작성 가능 여부 체크
```typescript
async canCreateContract(userId: number): Promise<{
  canCreate: boolean;
  reason?: string;
  contractsUsed: number;
  contractsLimit: number;
  points: number;
}>
```
- 프리미엄: 무제한
- 무료: 월 4개 기본
- 초과 시: 포인트 3개로 1개 작성

##### 3. 계약서 작성 카운트 증가
```typescript
async incrementContractUsage(userId: number, usePoints: boolean = false): Promise<void>
```
- `contractsUsedThisMonth++`
- 포인트 사용 시: `points -= 3`

##### 4. 출석 체크
```typescript
async checkIn(userId: number): Promise<{
  success: boolean;
  points: number;
  message: string;
}>
```
- 하루 1회 제한
- +1 포인트 적립
- `lastCheckInDate` 업데이트

##### 5. 광고 포인트 적립
```typescript
async addPointsFromAd(userId: number, pointsToAdd: number = 1): Promise<{ points: number }>
```
- 광고 시청 시 포인트 적립 (나중에 사용)
- 월 12포인트 제한

##### 6. 사용자 통계
```typescript
async getUserStats(userId: number): Promise<{
  subscriptionTier: string;
  contractsUsedThisMonth: number;
  monthlyContractLimit: number;
  points: number;
  pointsEarnedThisMonth: number;
  monthlyPointsLimit: number;
}>
```

---

### 🌐 API 엔드포인트

#### 1. 사용자 통계 조회
```
POST /api/auth/stats
Authorization: Bearer {token}

Response:
{
  "subscriptionTier": "free",
  "contractsUsedThisMonth": 2,
  "monthlyContractLimit": 4,
  "points": 15,
  "pointsEarnedThisMonth": 3,
  "monthlyPointsLimit": 12
}
```

#### 2. 출석 체크
```
POST /api/auth/check-in
Authorization: Bearer {token}

Response:
{
  "success": true,
  "points": 16,
  "message": "출석 체크 완료! 1포인트가 적립되었습니다."
}
```

#### 3. 광고 포인트 적립 (나중에 사용)
```
POST /api/auth/add-points-from-ad
Authorization: Bearer {token}
Body: { "points": 1 }

Response:
{
  "points": 17
}
```

---

### 🔗 계약서 작성 제한 통합

**파일:** `nestjs_app/src/contracts/contracts.service.ts`

```typescript
async createContract(dto: CreateContractDto, createdByUserId?: number | null) {
  // 계약서 작성 제한 체크
  if (createdByUserId) {
    const canCreate = await this.usersService.canCreateContract(createdByUserId);

    if (!canCreate.canCreate) {
      throw new BadRequestException(
        canCreate.reason || "계약서 작성 제한을 초과했습니다."
      );
    }

    // 포인트 사용 여부 판단
    const usePoints = canCreate.contractsUsed >= canCreate.contractsLimit;

    // 카운트 증가
    await this.usersService.incrementContractUsage(createdByUserId, usePoints);
  }

  // 계약서 생성 로직...
}
```

---

### 🎮 동작 흐름

#### 무료 사용자 시나리오

**초기 상태:**
```
contractsUsedThisMonth: 0
monthlyContractLimit: 4
points: 12
```

**계약서 작성 1~4개:**
```
✅ 작성 가능 (무료)
contractsUsedThisMonth++
```

**계약서 작성 5개 (포인트 사용):**
```
✅ points >= 3 → 작성 가능
points -= 3
contractsUsedThisMonth++
```

**포인트 부족 시:**
```
❌ 작성 불가
message: "월 계약서 작성 제한을 초과했습니다. 포인트가 부족합니다."
```

**매월 1일 자동 리셋:**
```
contractsUsedThisMonth = 0
points = 12
pointsEarnedThisMonth = 0
lastResetDate = 현재 날짜
```

#### 출석 체크
```
하루 1회 가능
points += 1
pointsEarnedThisMonth += 1
lastCheckInDate = 현재 날짜
```

---

## 📁 수정된 파일 목록

### 백엔드 (NestJS)
```
nestjs_app/
├── migrations/
│   └── 20241127_add_subscription_points_system.sql (NEW)
├── src/
│   ├── users/
│   │   ├── user.entity.ts (MODIFIED)
│   │   └── users.service.ts (MODIFIED)
│   ├── api-auth/
│   │   └── api-auth.controller.ts (MODIFIED)
│   ├── contracts/
│   │   ├── contracts.module.ts (MODIFIED)
│   │   └── contracts.service.ts (MODIFIED)
│   └── inbox/
│       └── inbox.service.ts (기존 - 참조용)
```

### 프론트엔드 (Flutter)
```
insign_flutter/lib/features/
├── contracts/view/contracts_screen.dart (MODIFIED)
├── templates/view/templates_screen.dart (MODIFIED)
├── settings/view/inbox_screen.dart (MODIFIED)
├── profile/view/profile_screen.dart (MODIFIED)
└── auth/view/
    ├── login_screen.dart (MODIFIED - 약관 동의)
    └── terms_agreement_screen.dart (MODIFIED - 약관 동의)
```

### 모델
```
insign_flutter/lib/models/
└── user.dart (MODIFIED - 약관 동의 필드)
```

---

## 🚀 다음 단계 (프론트엔드 구현 필요)

### 1. 사용자 통계 UI
- [ ] 홈 화면에 통계 표시
- [ ] 프로필 화면에 구독 정보 표시
- [ ] 진행 바 (4개 중 2개 사용)

### 2. 출석 체크
- [ ] 출석 체크 버튼 추가
- [ ] 출석 완료 애니메이션
- [ ] 포인트 획득 피드백

### 3. 계약서 작성 제한
- [ ] 작성 전 제한 확인
- [ ] 포인트 부족 시 안내 화면
- [ ] 업그레이드 안내

### 4. 광고 시스템 (나중에)
- [ ] Google AdMob SDK 통합
- [ ] 보상형 광고 화면
- [ ] 광고 시청 후 포인트 적립

---

## ✅ 완료 체크리스트

- [x] DB 스키마 설계 및 마이그레이션
- [x] 월간 리셋 로직 구현
- [x] 계약서 작성 제한 체크
- [x] 출석 체크 API
- [x] 광고 포인트 API (준비)
- [x] 사용자 통계 API
- [x] 계약서 작성 시 제한 적용
- [x] Inbox 메시지 저장
- [x] UI 레이아웃 조정
- [ ] Flutter 프론트엔드 구현
- [ ] 광고 SDK 통합

---

## 🎯 비즈니스 모델 정리

### 가격 전략 (향후)
```
무료:
  - 월 4개 계약서
  - 광고 시청으로 추가 작성 가능
  - 출석 체크 포인트

프리미엄: 월 4,900원
  - 무제한 계약서
  - 광고 없음
  - 우선 지원
```

### 수익 구조
1. 광고 수익 (무료 사용자)
2. 구독 수익 (프리미엄 사용자)
3. 포인트 직접 구매 (나중에 고려)

---

## 📝 참고 사항

### 테스트 계정
- 모든 사용자는 기본적으로 `free` 티어
- 초기 포인트: 12
- 월 계약서 제한: 4개

### 운영 고려사항
- 매월 1일 자동 리셋 (서버 로직)
- 포인트 획득 제한 (월 12포인트)
- 프리미엄 전환 시 제한 해제

---

## 🔗 관련 이슈

- [x] Google 로그인 약관 동의 처리
- [x] 계약 상태 필터 개선
- [x] Inbox 메시지 저장
- [x] 구독 시스템 구축

---

**작성일:** 2025-11-27
**작성자:** Claude
**버전:** v1.0
