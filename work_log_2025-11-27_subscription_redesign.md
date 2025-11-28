# 구독/포인트 시스템 재설계

**작성일**: 2025-11-27
**목적**: user 테이블에 직접 추가한 컬럼을 별도 테이블로 분리하여 이력 관리 및 확장성 확보

---

## 🎯 문제점

### 기존 설계 (user 테이블에 직접 추가)

```sql
ALTER TABLE users
ADD COLUMN points INT NOT NULL DEFAULT 12,
ADD COLUMN monthly_points_limit INT NOT NULL DEFAULT 12,
ADD COLUMN points_earned_this_month INT NOT NULL DEFAULT 0,
ADD COLUMN last_check_in_date DATE NULL;
```

**문제**:
- ❌ 포인트 적립/사용 내역 추적 불가 (언제, 어떻게, 얼마나?)
- ❌ 포인트 잔액만 보여서 감사(audit) 불가능
- ❌ 월별 리셋 시 이전 데이터 유실
- ❌ 구독 변경 이력 관리 불가
- ❌ 확장성 부족 (환불, 포인트 구매, 선물 등 추가 어려움)

---

## ✅ 개선된 설계

### 1. subscription_plans (요금제 마스터)

**이미 설계 완료** - `work_log_2025-11-27_subscription_refactoring.md` 참고

```sql
CREATE TABLE subscription_plans (
  id INT PRIMARY KEY AUTO_INCREMENT,
  tier VARCHAR(20) NOT NULL UNIQUE,        -- 'free', 'premium', 'business'
  name VARCHAR(50) NOT NULL,               -- '무료', '프리미엄'
  description TEXT,

  -- 제한 설정
  monthly_contract_limit INT NOT NULL,     -- 4, -1(무제한)
  monthly_points_limit INT NOT NULL,       -- 12, -1(무제한)
  initial_points INT NOT NULL DEFAULT 0,   -- 가입 시 제공 포인트

  -- 가격
  price_monthly INT NOT NULL DEFAULT 0,    -- 월 구독료 (원)
  price_yearly INT NULL,                   -- 연 구독료

  -- 기능
  features JSON,                           -- {"ai_summary": true, ...}

  -- 상태
  is_active BOOLEAN DEFAULT TRUE,
  display_order INT DEFAULT 0,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_tier (tier),
  INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

### 2. user_subscriptions (사용자 구독 정보)

**새로 추가** - 구독 이력 관리

```sql
CREATE TABLE user_subscriptions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  plan_id INT NOT NULL,

  -- 구독 기간
  started_at TIMESTAMP NOT NULL,
  expires_at TIMESTAMP NULL,               -- NULL이면 활성, 값 있으면 만료

  -- 결제 정보
  payment_method VARCHAR(50) NULL,         -- 'card', 'bank_transfer', 'free'
  payment_id VARCHAR(100) NULL,            -- 외부 결제 시스템 ID (Iamport 등)
  amount_paid INT DEFAULT 0,               -- 실제 결제 금액

  -- 상태
  status ENUM('active', 'expired', 'cancelled', 'pending') DEFAULT 'active',
  cancelled_at TIMESTAMP NULL,
  cancel_reason TEXT NULL,

  -- 자동 갱신
  auto_renew BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (plan_id) REFERENCES subscription_plans(id),

  INDEX idx_user_id (user_id),
  INDEX idx_status (status),
  INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**특징**:
- ✅ 사용자의 구독 이력 전체 보관
- ✅ 업그레이드/다운그레이드 추적 가능
- ✅ 결제 정보 연동 가능
- ✅ 취소/환불 사유 기록

---

### 3. points_ledger (포인트 거래 장부)

**새로 추가** - 모든 포인트 증감 내역 기록

```sql
CREATE TABLE points_ledger (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,

  -- 거래 정보
  transaction_type ENUM(
    'earn_checkin',          -- 출석 체크 적립
    'earn_signup',           -- 가입 보너스
    'earn_referral',         -- 추천인 보너스
    'earn_ad',               -- 광고 시청
    'earn_admin',            -- 관리자 수동 지급
    'spend_contract',        -- 계약서 작성 사용
    'spend_template',        -- 프리미엄 템플릿 사용
    'expire',                -- 만료
    'refund'                 -- 환불
  ) NOT NULL,

  amount INT NOT NULL,                     -- 증감 포인트 (양수=적립, 음수=사용)
  balance_after INT NOT NULL,              -- 거래 후 잔액

  -- 메타데이터
  description VARCHAR(255) NULL,           -- 설명
  reference_type VARCHAR(50) NULL,         -- 'contract', 'template', 'user'
  reference_id INT NULL,                   -- 관련 객체 ID

  -- 만료 정보
  expires_at DATE NULL,                    -- 포인트 만료일 (적립 시점부터 1년 등)
  is_expired BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

  INDEX idx_user_id (user_id),
  INDEX idx_transaction_type (transaction_type),
  INDEX idx_created_at (created_at),
  INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**특징**:
- ✅ 모든 포인트 증감 내역 기록 (감사 가능)
- ✅ 잔액 추적 (`balance_after`)
- ✅ 포인트 만료 관리 가능
- ✅ 어떤 계약서/템플릿에 사용했는지 추적
- ✅ 관리자 수동 지급/차감 가능

---

### 4. monthly_usage (월별 사용량)

**새로 추가** - 월별 계약서 작성 횟수 추적

```sql
CREATE TABLE monthly_usage (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  year INT NOT NULL,
  month INT NOT NULL,                      -- 1~12

  -- 사용량
  contracts_created INT DEFAULT 0,         -- 이번 달 작성한 계약서 수
  points_earned INT DEFAULT 0,             -- 이번 달 적립한 포인트
  points_spent INT DEFAULT 0,              -- 이번 달 사용한 포인트

  -- 출석 체크
  checkin_count INT DEFAULT 0,             -- 이번 달 출석 일수
  last_checkin_date DATE NULL,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

  UNIQUE KEY uk_user_year_month (user_id, year, month),
  INDEX idx_user_id (user_id),
  INDEX idx_year_month (year, month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**특징**:
- ✅ 월별 통계 쉽게 조회
- ✅ 리셋 없이 누적 데이터 보관
- ✅ 사용자 행동 패턴 분석 가능

---

### 5. users 테이블 수정

**변경 사항**:
- 포인트 관련 컬럼 **제거**
- subscription_plan_id만 **유지** (현재 활성 플랜 참조용)

```sql
-- 제거할 컬럼
ALTER TABLE users
DROP COLUMN points,
DROP COLUMN monthly_points_limit,
DROP COLUMN points_earned_this_month,
DROP COLUMN last_check_in_date;

-- 남길 컬럼 (기존 설계 유지)
-- subscription_tier VARCHAR(20) - 레거시 호환용
-- subscription_plan_id INT - 현재 활성 플랜 (빠른 조회용)
```

**`subscription_plan_id`는 왜 남기나?**
- 빠른 조회를 위한 **비정규화**
- 매번 `user_subscriptions`를 JOIN하지 않아도 현재 플랜 확인 가능
- `user_subscriptions.status='active'`와 동기화 필요

---

## 📊 데이터 흐름

### 1. 회원가입 시

```sql
-- 1. 무료 플랜 구독 생성
INSERT INTO user_subscriptions (user_id, plan_id, started_at, status, payment_method)
VALUES (123, 1, NOW(), 'active', 'free');

-- 2. users 테이블 업데이트
UPDATE users SET subscription_plan_id = 1 WHERE id = 123;

-- 3. 가입 보너스 포인트 지급 (12 포인트)
INSERT INTO points_ledger (user_id, transaction_type, amount, balance_after, description)
VALUES (123, 'earn_signup', 12, 12, '가입 환영 포인트');

-- 4. 월별 사용량 레코드 생성
INSERT INTO monthly_usage (user_id, year, month)
VALUES (123, 2025, 11);
```

---

### 2. 출석 체크 시

```sql
-- 1. 오늘 이미 출석했는지 확인
SELECT last_checkin_date FROM monthly_usage
WHERE user_id = 123 AND year = 2025 AND month = 11;

-- 2. 포인트 적립 (balance_after는 이전 잔액 + 1)
INSERT INTO points_ledger (user_id, transaction_type, amount, balance_after, description, expires_at)
VALUES (123, 'earn_checkin', 1, 16, '출석 체크', DATE_ADD(NOW(), INTERVAL 1 YEAR));

-- 3. 월별 사용량 업데이트
UPDATE monthly_usage
SET checkin_count = checkin_count + 1,
    last_checkin_date = CURDATE(),
    points_earned = points_earned + 1
WHERE user_id = 123 AND year = 2025 AND month = 11;
```

---

### 3. 계약서 작성 시 (포인트 사용)

```sql
-- 1. 현재 포인트 잔액 조회
SELECT SUM(amount) AS balance
FROM points_ledger
WHERE user_id = 123 AND is_expired = FALSE;

-- 2. 포인트 차감 (3 포인트)
INSERT INTO points_ledger (user_id, transaction_type, amount, balance_after, description, reference_type, reference_id)
VALUES (123, 'spend_contract', -3, 13, '계약서 작성', 'contract', 456);

-- 3. 월별 사용량 업데이트
UPDATE monthly_usage
SET contracts_created = contracts_created + 1,
    points_spent = points_spent + 3
WHERE user_id = 123 AND year = 2025 AND month = 11;
```

---

### 4. 플랜 업그레이드 시

```sql
-- 1. 기존 구독 만료 처리
UPDATE user_subscriptions
SET status = 'expired', expires_at = NOW()
WHERE user_id = 123 AND status = 'active';

-- 2. 새 구독 생성
INSERT INTO user_subscriptions (user_id, plan_id, started_at, status, payment_method, amount_paid, auto_renew)
VALUES (123, 2, NOW(), 'active', 'card', 19900, TRUE);

-- 3. users 테이블 업데이트
UPDATE users SET subscription_plan_id = 2 WHERE id = 123;
```

---

## 🔍 주요 쿼리

### 사용자 현재 포인트 잔액

```sql
SELECT SUM(amount) AS current_balance
FROM points_ledger
WHERE user_id = 123 AND is_expired = FALSE;
```

### 이번 달 사용량 조회

```sql
SELECT *
FROM monthly_usage
WHERE user_id = 123 AND year = YEAR(NOW()) AND month = MONTH(NOW());
```

### 포인트 거래 내역 (최근 30일)

```sql
SELECT
  transaction_type,
  amount,
  balance_after,
  description,
  created_at
FROM points_ledger
WHERE user_id = 123
  AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY created_at DESC;
```

### 현재 활성 구독 조회

```sql
SELECT
  us.*,
  sp.name AS plan_name,
  sp.monthly_contract_limit
FROM user_subscriptions us
JOIN subscription_plans sp ON us.plan_id = sp.id
WHERE us.user_id = 123
  AND us.status = 'active'
ORDER BY us.started_at DESC
LIMIT 1;
```

### 월별 사용량 통계 (최근 6개월)

```sql
SELECT
  CONCAT(year, '-', LPAD(month, 2, '0')) AS month,
  contracts_created,
  points_earned,
  points_spent,
  checkin_count
FROM monthly_usage
WHERE user_id = 123
  AND (year = 2025 OR year = 2024)
ORDER BY year DESC, month DESC
LIMIT 6;
```

---

## 🚀 마이그레이션 계획

### Step 1: 테이블 생성

```bash
cd /home/insign/nestjs_app
mysql -u root -p'H./Bv!jPsH*z-[Jo]' insign < migrations/20241127_subscription_redesign_step1_create_tables.sql
```

### Step 2: 기존 데이터 마이그레이션

```bash
mysql -u root -p'H./Bv!jPsH*z-[Jo]' insign < migrations/20241127_subscription_redesign_step2_migrate_data.sql
```

**마이그레이션 로직**:
```sql
-- 1. 모든 사용자에게 무료 플랜 구독 생성
INSERT INTO user_subscriptions (user_id, plan_id, started_at, status, payment_method)
SELECT
  id,
  (SELECT id FROM subscription_plans WHERE tier = 'free'),
  created_at,
  'active',
  'free'
FROM users;

-- 2. users.subscription_plan_id 업데이트
UPDATE users u
SET u.subscription_plan_id = (
  SELECT id FROM subscription_plans WHERE tier = 'free'
);

-- 3. 기존 포인트를 points_ledger로 이관
INSERT INTO points_ledger (user_id, transaction_type, amount, balance_after, description, created_at)
SELECT
  id,
  'earn_signup',
  COALESCE(points, 12),
  COALESCE(points, 12),
  '기존 데이터 마이그레이션',
  created_at
FROM users
WHERE points IS NOT NULL AND points > 0;

-- 4. 현재 월 사용량 레코드 생성
INSERT INTO monthly_usage (user_id, year, month, contracts_created, points_earned, last_checkin_date)
SELECT
  id,
  YEAR(NOW()),
  MONTH(NOW()),
  COALESCE(contracts_used_this_month, 0),
  COALESCE(points_earned_this_month, 0),
  last_check_in_date
FROM users;
```

### Step 3: 기존 컬럼 제거

```bash
mysql -u root -p'H./Bv!jPsH*z-[Jo]' insign < migrations/20241127_subscription_redesign_step3_cleanup.sql
```

```sql
ALTER TABLE users
DROP COLUMN points,
DROP COLUMN monthly_points_limit,
DROP COLUMN points_earned_this_month,
DROP COLUMN last_check_in_date,
DROP COLUMN contracts_used_this_month,
DROP COLUMN monthly_contract_limit,
DROP COLUMN last_reset_date;
```

---

## 📝 NestJS 구현 가이드

### Entity 생성

```typescript
// src/subscriptions/entities/user-subscription.entity.ts
@Entity('user_subscriptions')
export class UserSubscription {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'user_id' })
  userId!: number;

  @Column({ name: 'plan_id' })
  planId!: number;

  @Column({ name: 'started_at' })
  startedAt!: Date;

  @Column({ name: 'expires_at', nullable: true })
  expiresAt?: Date | null;

  @Column({ type: 'enum', enum: ['active', 'expired', 'cancelled', 'pending'] })
  status!: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => SubscriptionPlan)
  @JoinColumn({ name: 'plan_id' })
  plan!: SubscriptionPlan;
}

// src/points/entities/points-ledger.entity.ts
@Entity('points_ledger')
export class PointsLedger {
  @PrimaryGeneratedColumn('increment', { type: 'bigint' })
  id!: number;

  @Column({ name: 'user_id' })
  userId!: number;

  @Column({ type: 'enum', name: 'transaction_type' })
  transactionType!: 'earn_checkin' | 'earn_signup' | 'spend_contract' | ...;

  @Column()
  amount!: number;

  @Column({ name: 'balance_after' })
  balanceAfter!: number;

  @Column({ nullable: true })
  description?: string;

  @Column({ name: 'expires_at', type: 'date', nullable: true })
  expiresAt?: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user!: User;
}

// src/subscriptions/entities/monthly-usage.entity.ts
@Entity('monthly_usage')
export class MonthlyUsage {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'user_id' })
  userId!: number;

  @Column()
  year!: number;

  @Column()
  month!: number;

  @Column({ name: 'contracts_created', default: 0 })
  contractsCreated!: number;

  @Column({ name: 'points_earned', default: 0 })
  pointsEarned!: number;

  @Column({ name: 'checkin_count', default: 0 })
  checkinCount!: number;

  @Column({ name: 'last_checkin_date', type: 'date', nullable: true })
  lastCheckinDate?: Date;
}
```

### Service 메서드

```typescript
// src/points/points.service.ts
@Injectable()
export class PointsService {
  // 현재 포인트 잔액 조회
  async getBalance(userId: number): Promise<number> {
    const result = await this.ledgerRepository
      .createQueryBuilder('ledger')
      .select('SUM(ledger.amount)', 'balance')
      .where('ledger.userId = :userId', { userId })
      .andWhere('ledger.isExpired = FALSE')
      .getRawOne();

    return result?.balance || 0;
  }

  // 포인트 적립
  async earn(params: {
    userId: number;
    type: 'earn_checkin' | 'earn_signup' | 'earn_ad';
    amount: number;
    description: string;
  }): Promise<PointsLedger> {
    const currentBalance = await this.getBalance(params.userId);
    const newBalance = currentBalance + params.amount;

    const ledger = this.ledgerRepository.create({
      userId: params.userId,
      transactionType: params.type,
      amount: params.amount,
      balanceAfter: newBalance,
      description: params.description,
      expiresAt: moment().add(1, 'year').toDate(), // 1년 후 만료
    });

    return this.ledgerRepository.save(ledger);
  }

  // 포인트 사용
  async spend(params: {
    userId: number;
    type: 'spend_contract' | 'spend_template';
    amount: number;
    description: string;
    referenceType?: string;
    referenceId?: number;
  }): Promise<PointsLedger> {
    const currentBalance = await this.getBalance(params.userId);

    if (currentBalance < params.amount) {
      throw new BadRequestException('포인트가 부족합니다');
    }

    const newBalance = currentBalance - params.amount;

    const ledger = this.ledgerRepository.create({
      userId: params.userId,
      transactionType: params.type,
      amount: -params.amount, // 음수로 저장
      balanceAfter: newBalance,
      description: params.description,
      referenceType: params.referenceType,
      referenceId: params.referenceId,
    });

    return this.ledgerRepository.save(ledger);
  }

  // 거래 내역 조회
  async getHistory(userId: number, limit = 50): Promise<PointsLedger[]> {
    return this.ledgerRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}

// src/subscriptions/monthly-usage.service.ts
@Injectable()
export class MonthlyUsageService {
  // 이번 달 레코드 가져오기 (없으면 생성)
  async getOrCreateCurrentMonth(userId: number): Promise<MonthlyUsage> {
    const year = moment().year();
    const month = moment().month() + 1;

    let usage = await this.usageRepository.findOne({
      where: { userId, year, month },
    });

    if (!usage) {
      usage = this.usageRepository.create({ userId, year, month });
      await this.usageRepository.save(usage);
    }

    return usage;
  }

  // 출석 체크
  async checkIn(userId: number): Promise<boolean> {
    const usage = await this.getOrCreateCurrentMonth(userId);
    const today = moment().format('YYYY-MM-DD');

    // 오늘 이미 출석했는지 확인
    if (usage.lastCheckinDate && moment(usage.lastCheckinDate).format('YYYY-MM-DD') === today) {
      return false; // 이미 출석함
    }

    // 출석 체크
    usage.checkinCount++;
    usage.lastCheckinDate = new Date();
    await this.usageRepository.save(usage);

    // 포인트 적립
    await this.pointsService.earn({
      userId,
      type: 'earn_checkin',
      amount: 1,
      description: '출석 체크',
    });

    // monthly_usage의 points_earned도 증가
    usage.pointsEarned++;
    await this.usageRepository.save(usage);

    return true;
  }

  // 계약서 작성 카운트 증가
  async incrementContractUsage(userId: number): Promise<void> {
    const usage = await this.getOrCreateCurrentMonth(userId);
    usage.contractsCreated++;
    await this.usageRepository.save(usage);
  }
}
```

---

## 🎯 장점

### 기존 설계 (user 테이블에 직접)
- ❌ 이력 추적 불가
- ❌ 감사(audit) 불가능
- ❌ 확장성 부족
- ❌ 월 리셋 시 데이터 유실

### 개선된 설계 (별도 테이블)
- ✅ **완전한 이력 추적** - 모든 포인트 증감 내역 보관
- ✅ **감사 가능** - 언제, 어떻게 적립/사용했는지 명확
- ✅ **월별 통계** - 리셋 없이 누적 데이터 보관
- ✅ **구독 변경 이력** - 업그레이드/다운그레이드 추적
- ✅ **확장성** - 포인트 구매, 환불, 만료, 선물 등 쉽게 추가
- ✅ **성능** - 인덱스 최적화로 빠른 조회
- ✅ **데이터 무결성** - 외래키 제약으로 일관성 보장

---

## 📌 다음 단계

1. ✅ 테이블 구조 설계 (완료)
2. ⏳ 마이그레이션 SQL 작성
3. ⏳ NestJS Entity 생성
4. ⏳ Service 로직 구현
5. ⏳ API 엔드포인트 수정
6. ⏳ 기존 컬럼 제거

---

**작성자**: Claude Code
**버전**: v2.0 (재설계)
