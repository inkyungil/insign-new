# 작업 내역 - 구독 시스템 리팩토링

**작성일:** 2025-11-27
**작성자:** Claude
**목적:** 코드 수정 없이 DB에서 요금제 관리 가능하도록 구조 개선

---

## 📋 작업 배경

### 기존 구조의 문제점

**현재 설계 (2025-11-27 최초 구현):**
```
users 테이블에 모든 구독 정보 하드코딩
├─ subscription_tier: 'free' | 'premium'
├─ monthly_contract_limit: 4 (고정값)
├─ monthly_points_limit: 12 (고정값)
└─ 별도 plans 테이블 없음
```

**문제:**
- ❌ 요금제 변경 시 **코드 수정 + 배포 필요**
- ❌ 새로운 티어 추가 어려움 (basic, pro, enterprise)
- ❌ 요금제별 가격, 기능 정보를 DB에 저장 불가
- ❌ 관리자가 동적으로 요금제 관리 불가
- ❌ A/B 테스트 불가능

### 왜 이렇게 만들었는가?

**당시 상황 (2025-11-27):**
1. **시간 압박**: 5가지 작업 동시 진행 중
2. **빠른 구현 우선**: MVP 빠르게 출시
3. **단순한 요구사항**: 무료/프리미엄 2개만 필요
4. **확장성 간과**: 동적 관리 필요성 예측 못함

---

## 🎯 개선 목표

### 요구사항
1. ✅ 코드 수정 없이 DB에서 요금제 관리
2. ✅ 새 티어 추가 시 INSERT만으로 가능
3. ✅ 요금제별 가격, 기능 설정 가능
4. ✅ 기존 사용자 데이터 보존
5. ✅ 사용자별 예외 설정 가능 (특정 사용자만 무제한 등)

---

## 🗄️ 새로운 데이터베이스 구조

### 1. subscription_plans 테이블 (신규 생성)

**요금제 마스터 테이블:**

```sql
CREATE TABLE subscription_plans (
  id INT PRIMARY KEY AUTO_INCREMENT,
  tier VARCHAR(20) NOT NULL UNIQUE,        -- 'free', 'premium', 'enterprise'
  name VARCHAR(50) NOT NULL,               -- '무료', '프리미엄', '엔터프라이즈'
  description TEXT,

  -- 제한 설정
  monthly_contract_limit INT NOT NULL,     -- 4, -1(무제한)
  monthly_points_limit INT NOT NULL,       -- 12, -1(무제한)
  initial_points INT NOT NULL,             -- 가입 시 제공 포인트

  -- 가격
  price_monthly INT NOT NULL DEFAULT 0,    -- 월 구독료 (원)
  price_yearly INT NULL,                   -- 연 구독료

  -- 기능 제어 (JSON)
  features JSON,

  -- 상태
  is_active BOOLEAN DEFAULT TRUE,
  display_order INT DEFAULT 0,

  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

**features JSON 구조:**
```json
{
  "templates": ["basic", "premium"],
  "ai_summary": true,
  "statistics": true,
  "team_members": 5,
  "priority_support": true
}
```

### 2. users 테이블 수정

**추가 필드:**
```sql
ALTER TABLE users
ADD COLUMN subscription_plan_id INT NULL,
ADD FOREIGN KEY (subscription_plan_id)
  REFERENCES subscription_plans(id);
```

**필드 사용 전략:**
- `subscription_tier`: 유지 (기존 호환성)
- `subscription_plan_id`: 추가 (새로운 방식)
- `monthly_contract_limit` 등: 유지 (사용자별 오버라이드 가능)

### 3. 우선순위 로직

```typescript
// 사용자의 계약서 제한 조회
async getUserContractLimit(userId: number): Promise<number> {
  const user = await this.findOne(userId);

  // 1순위: 사용자별 개별 설정 (예외 처리)
  if (user.monthly_contract_limit !== null) {
    return user.monthly_contract_limit;
  }

  // 2순위: 요금제 기본값
  if (user.subscriptionPlanId) {
    const plan = await this.plansRepository.findOne(user.subscriptionPlanId);
    return plan.monthlyContractLimit;
  }

  // 3순위: 폴백 (무료 플랜 기본값)
  return 4;
}
```

---

## 📦 기본 요금제 데이터

### Free (무료)
```sql
INSERT INTO subscription_plans VALUES (
  'free',
  '무료',
  '개인 사용자를 위한 기본 플랜',
  4,      -- 월 4개 계약서
  12,     -- 월 12포인트
  12,     -- 가입 시 12포인트
  0,      -- 무료
  NULL,   -- 연 결제 없음
  '{"templates": ["basic"], "ai_summary": false}',
  TRUE,
  1
);
```

### Premium (프리미엄)
```sql
INSERT INTO subscription_plans VALUES (
  'premium',
  '프리미엄',
  '무제한 계약서 작성과 고급 기능',
  -1,     -- 무제한
  -1,     -- 무제한
  0,      -- 포인트 불필요
  19900,  -- 월 19,900원
  199000, -- 연 199,000원 (2개월 할인)
  '{"templates": ["basic", "premium"], "ai_summary": true}',
  TRUE,
  2
);
```

---

## 🔧 백엔드 구현

### 1. SubscriptionPlan Entity

**파일:** `nestjs_app/src/subscription-plans/subscription-plan.entity.ts`

```typescript
import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity({ name: 'subscription_plans' })
export class SubscriptionPlan {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 20, unique: true })
  tier!: string;

  @Column({ type: 'varchar', length: 50 })
  name!: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ name: 'monthly_contract_limit', type: 'int' })
  monthlyContractLimit!: number;

  @Column({ name: 'monthly_points_limit', type: 'int' })
  monthlyPointsLimit!: number;

  @Column({ name: 'initial_points', type: 'int' })
  initialPoints!: number;

  @Column({ name: 'price_monthly', type: 'int', default: 0 })
  priceMonthly!: number;

  @Column({ name: 'price_yearly', type: 'int', nullable: true })
  priceYearly?: number | null;

  @Column({ type: 'json', nullable: true })
  features?: any;

  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive!: boolean;

  @Column({ name: 'display_order', type: 'int', default: 0 })
  displayOrder!: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
```

### 2. User Entity 수정

**파일:** `nestjs_app/src/users/user.entity.ts`

```typescript
// 추가
import { SubscriptionPlan } from '../subscription-plans/subscription-plan.entity';

@Entity({ name: 'users' })
export class User {
  // ... 기존 필드

  // 새로운 관계
  @Column({ name: 'subscription_plan_id', type: 'int', nullable: true })
  subscriptionPlanId?: number | null;

  @ManyToOne(() => SubscriptionPlan)
  @JoinColumn({ name: 'subscription_plan_id' })
  subscriptionPlan?: SubscriptionPlan;

  // 기존 필드 유지 (오버라이드용)
  @Column({
    name: 'subscription_tier',
    type: 'varchar',
    length: 20,
    default: 'free',
  })
  subscriptionTier!: 'free' | 'premium';

  @Column({ name: 'monthly_contract_limit', type: 'int', nullable: true })
  monthlyContractLimit?: number | null;  // NULL이면 plan 기본값 사용
}
```

### 3. UsersService 개선

**파일:** `nestjs_app/src/users/users.service.ts`

```typescript
// 사용자의 실제 계약서 제한 조회
async getEffectiveContractLimit(userId: number): Promise<number> {
  const user = await this.usersRepository.findOne({
    where: { id: userId },
    relations: ['subscriptionPlan'],
  });

  if (!user) {
    throw new NotFoundException('사용자를 찾을 수 없습니다');
  }

  // 1순위: 사용자별 오버라이드
  if (user.monthlyContractLimit !== null && user.monthlyContractLimit !== undefined) {
    return user.monthlyContractLimit;
  }

  // 2순위: 요금제 기본값
  if (user.subscriptionPlan) {
    return user.subscriptionPlan.monthlyContractLimit;
  }

  // 3순위: 폴백 (무료 플랜 기본값)
  return 4;
}

// 포인트 제한도 동일하게
async getEffectivePointsLimit(userId: number): Promise<number> {
  const user = await this.usersRepository.findOne({
    where: { id: userId },
    relations: ['subscriptionPlan'],
  });

  if (user.monthlyPointsLimit !== null && user.monthlyPointsLimit !== undefined) {
    return user.monthlyPointsLimit;
  }

  if (user.subscriptionPlan) {
    return user.subscriptionPlan.monthlyPointsLimit;
  }

  return 12;
}

// 계약서 작성 가능 여부 체크 (수정)
async canCreateContract(userId: number): Promise<{
  canCreate: boolean;
  reason?: string;
  contractsUsed: number;
  contractsLimit: number;
  points: number;
}> {
  await this.checkAndResetMonthlyLimits(userId);

  const user = await this.usersRepository.findOne({
    where: { id: userId },
    relations: ['subscriptionPlan'],
  });

  if (!user) {
    throw new NotFoundException('사용자를 찾을 수 없습니다');
  }

  // 실제 제한값 가져오기
  const contractsLimit = await this.getEffectiveContractLimit(userId);
  const contractsUsed = user.contractsUsedThisMonth;
  const points = user.points;

  // 무제한인 경우 (-1)
  if (contractsLimit === -1) {
    return {
      canCreate: true,
      contractsUsed,
      contractsLimit,
      points,
    };
  }

  // 기본 할당량 내
  if (contractsUsed < contractsLimit) {
    return {
      canCreate: true,
      contractsUsed,
      contractsLimit,
      points,
    };
  }

  // 포인트로 추가 작성
  if (points >= 3) {
    return {
      canCreate: true,
      contractsUsed,
      contractsLimit,
      points,
    };
  }

  // 작성 불가
  return {
    canCreate: false,
    reason: '월 계약서 작성 제한을 초과했습니다. 포인트가 부족합니다.',
    contractsUsed,
    contractsLimit,
    points,
  };
}
```

### 4. SubscriptionPlansService

**파일:** `nestjs_app/src/subscription-plans/subscription-plans.service.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SubscriptionPlan } from './subscription-plan.entity';

@Injectable()
export class SubscriptionPlansService {
  constructor(
    @InjectRepository(SubscriptionPlan)
    private readonly plansRepository: Repository<SubscriptionPlan>,
  ) {}

  // 활성화된 요금제 목록 조회
  async findAllActive(): Promise<SubscriptionPlan[]> {
    return this.plansRepository.find({
      where: { isActive: true },
      order: { displayOrder: 'ASC' },
    });
  }

  // 티어로 조회
  async findByTier(tier: string): Promise<SubscriptionPlan | null> {
    return this.plansRepository.findOne({
      where: { tier, isActive: true },
    });
  }

  // 요금제 생성 (관리자용)
  async create(data: Partial<SubscriptionPlan>): Promise<SubscriptionPlan> {
    const plan = this.plansRepository.create(data);
    return this.plansRepository.save(plan);
  }

  // 요금제 수정 (관리자용)
  async update(id: number, data: Partial<SubscriptionPlan>): Promise<SubscriptionPlan> {
    await this.plansRepository.update(id, data);
    const updated = await this.plansRepository.findOne({ where: { id } });
    if (!updated) {
      throw new NotFoundException('요금제를 찾을 수 없습니다');
    }
    return updated;
  }
}
```

---

## 🌐 API 엔드포인트

### 1. 요금제 목록 조회

```
GET /api/subscription-plans

Response:
[
  {
    "id": 1,
    "tier": "free",
    "name": "무료",
    "description": "개인 사용자를 위한 기본 플랜",
    "monthlyContractLimit": 4,
    "monthlyPointsLimit": 12,
    "priceMonthly": 0,
    "priceYearly": null,
    "features": {
      "templates": ["basic"],
      "ai_summary": false,
      "statistics": false
    }
  },
  {
    "id": 2,
    "tier": "premium",
    "name": "프리미엄",
    "monthlyContractLimit": -1,
    "priceMonthly": 19900,
    "features": {
      "templates": ["basic", "premium"],
      "ai_summary": true,
      "statistics": true
    }
  }
]
```

### 2. 관리자 - 요금제 생성/수정

```
POST /api/admin/subscription-plans
Authorization: Bearer {admin-token}

Body:
{
  "tier": "basic",
  "name": "베이직",
  "monthlyContractLimit": 20,
  "monthlyPointsLimit": 50,
  "priceMonthly": 9900,
  "features": {
    "templates": ["basic", "premium"],
    "ai_summary": false
  }
}

Response:
{
  "id": 3,
  "tier": "basic",
  "name": "베이직",
  ...
}
```

---

## 📱 Flutter 구현

### 1. SubscriptionPlan 모델

**파일:** `insign_flutter/lib/models/subscription_plan.dart`

```dart
class SubscriptionPlan {
  final int id;
  final String tier;
  final String name;
  final String? description;
  final int monthlyContractLimit;  // -1이면 무제한
  final int monthlyPointsLimit;
  final int priceMonthly;
  final int? priceYearly;
  final Map<String, dynamic>? features;
  final bool isActive;
  final int displayOrder;

  SubscriptionPlan({
    required this.id,
    required this.tier,
    required this.name,
    this.description,
    required this.monthlyContractLimit,
    required this.monthlyPointsLimit,
    required this.priceMonthly,
    this.priceYearly,
    this.features,
    required this.isActive,
    required this.displayOrder,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as int,
      tier: json['tier'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      monthlyContractLimit: json['monthlyContractLimit'] as int,
      monthlyPointsLimit: json['monthlyPointsLimit'] as int,
      priceMonthly: json['priceMonthly'] as int,
      priceYearly: json['priceYearly'] as int?,
      features: json['features'] as Map<String, dynamic>?,
      isActive: json['isActive'] as bool,
      displayOrder: json['displayOrder'] as int,
    );
  }

  bool get isUnlimited => monthlyContractLimit == -1;

  bool hasFeature(String feature) {
    if (features == null) return false;
    final value = features![feature];
    if (value is bool) return value;
    if (value is List) return (value as List).isNotEmpty;
    return false;
  }
}
```

### 2. User 모델 수정

**파일:** `insign_flutter/lib/models/user.dart`

```dart
class User {
  // ... 기존 필드

  final int? subscriptionPlanId;
  final SubscriptionPlan? subscriptionPlan;  // 조인된 데이터
  final String subscriptionTier;

  // 사용자별 오버라이드 (null이면 plan 기본값 사용)
  final int? monthlyContractLimit;
  final int? monthlyPointsLimit;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // ...
      subscriptionPlanId: json['subscriptionPlanId'] as int?,
      subscriptionPlan: json['subscriptionPlan'] != null
          ? SubscriptionPlan.fromJson(json['subscriptionPlan'])
          : null,
      subscriptionTier: json['subscriptionTier'] as String,
      monthlyContractLimit: json['monthlyContractLimit'] as int?,
      monthlyPointsLimit: json['monthlyPointsLimit'] as int?,
    );
  }

  // 실제 제한값 계산
  int get effectiveContractLimit {
    if (monthlyContractLimit != null) {
      return monthlyContractLimit!;
    }
    if (subscriptionPlan != null) {
      return subscriptionPlan!.monthlyContractLimit;
    }
    return 4; // 폴백
  }

  bool get hasUnlimitedContracts => effectiveContractLimit == -1;
}
```

---

## 🚀 마이그레이션 실행

### 1. 마이그레이션 적용

```bash
cd nestjs_app

# 1. 테이블 생성 및 데이터 삽입
mysql -u root -p'H./Bv!jPsH*z-[Jo' insign < \
  migrations/20241127_create_subscription_plans_table.sql

# 2. 확인
mysql -u root -p'H./Bv!jPsH*z-[Jo' insign -e "
  SELECT * FROM subscription_plans;
  SELECT id, email, subscription_tier, subscription_plan_id FROM users LIMIT 5;
"
```

### 2. 백엔드 코드 업데이트

```bash
# Entity, Service 생성
# Module 등록
# 기존 코드 수정
```

### 3. 테스트

```bash
# API 테스트
curl http://localhost:8083/api/subscription-plans

# 사용자 통계 조회 (변경사항 확인)
curl -H "Authorization: Bearer {token}" \
  http://localhost:8083/api/auth/stats
```

---

## 📊 Before / After 비교

### Before (기존)

```typescript
// ❌ 코드에 하드코딩
if (user.subscriptionTier === 'free') {
  limit = 4;  // 바꾸려면 코드 수정!
} else if (user.subscriptionTier === 'premium') {
  limit = Infinity;
}

// 새 티어 추가하려면:
// 1. 코드 수정
// 2. 빌드
// 3. 배포
// 4. 서버 재시작
```

### After (개선)

```typescript
// ✅ DB에서 동적으로 가져옴
const limit = await usersService.getEffectiveContractLimit(userId);

// 새 티어 추가하려면:
// 1. DB에 INSERT만 하면 끝!
INSERT INTO subscription_plans VALUES (...);

// 요금제 수정하려면:
UPDATE subscription_plans SET monthly_contract_limit = 10 WHERE tier = 'free';

// 코드 수정, 배포, 재시작 불필요!
```

---

## ✅ 완료 체크리스트

### 데이터베이스
- [x] subscription_plans 테이블 생성
- [x] 기본 요금제 데이터 삽입 (free, premium)
- [x] users.subscription_plan_id 컬럼 추가
- [x] 외래키 제약 조건 추가
- [ ] 마이그레이션 실행

### 백엔드 (NestJS)
- [ ] SubscriptionPlan Entity 생성
- [ ] SubscriptionPlansModule 생성
- [ ] SubscriptionPlansService 구현
- [ ] SubscriptionPlansController 구현
- [ ] UsersService 수정 (getEffectiveContractLimit)
- [ ] API 엔드포인트 추가
- [ ] 기존 코드 호환성 테스트

### 프론트엔드 (Flutter)
- [ ] SubscriptionPlan 모델 추가
- [ ] User 모델 수정
- [ ] 구독 화면 구현 (요금제 목록)
- [ ] 업그레이드 화면
- [ ] 결제 연동 준비

### 테스트
- [ ] 기존 사용자 데이터 보존 확인
- [ ] 무료 사용자 제한 동작 확인
- [ ] 프리미엄 사용자 무제한 확인
- [ ] 사용자별 오버라이드 동작 확인
- [ ] API 엔드포인트 테스트

---

## 🎯 다음 단계

### 즉시 실행
1. 마이그레이션 적용
2. Entity 파일 생성
3. Service 구현
4. API 테스트

### 추후 확장
1. **관리자 페이지**
   - 요금제 CRUD
   - 사용자별 요금제 변경
   - 통계 대시보드

2. **결제 연동**
   - Iamport / Toss Payments
   - 정기 결제 (구독)
   - 환불 처리

3. **추가 티어**
   - Basic (월 20건, 9,900원)
   - Business (월 100건, 39,900원)
   - Enterprise (무제한 + 팀 기능)

---

## 📝 참고사항

### 주의사항
- `subscription_tier` 필드는 기존 호환성 위해 유지
- `monthlyContractLimit` NULL이면 plan 기본값 사용
- 사용자별 예외는 users 테이블에서 오버라이드
- -1 = 무제한 의미

### 테스트 방법
```sql
-- 무료 플랜을 월 10개로 변경 (코드 수정 없이!)
UPDATE subscription_plans
SET monthly_contract_limit = 10
WHERE tier = 'free';

-- 특정 사용자만 무제한으로 설정
UPDATE users
SET monthly_contract_limit = -1
WHERE id = 123;

-- 새 티어 추가
INSERT INTO subscription_plans (tier, name, monthly_contract_limit, price_monthly)
VALUES ('basic', '베이직', 20, 9900);
```

---

**작성일:** 2025-11-27
**버전:** v1.0
**상태:** 설계 완료, 구현 대기
