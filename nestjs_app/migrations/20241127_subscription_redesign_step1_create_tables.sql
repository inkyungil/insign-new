-- ====================================================================
-- 구독/포인트 시스템 재설계 - Step 1: 테이블 생성
-- ====================================================================
-- 작성일: 2025-11-27
-- 목적: user 테이블에서 분리하여 별도 테이블로 이력 관리
-- ====================================================================

USE insign;

-- 1. subscription_plans (요금제 마스터)
-- ====================================================================
CREATE TABLE IF NOT EXISTS subscription_plans (
  id INT PRIMARY KEY AUTO_INCREMENT,
  tier VARCHAR(20) NOT NULL UNIQUE COMMENT '요금제 티어 (free, premium, business)',
  name VARCHAR(50) NOT NULL COMMENT '요금제 이름 (무료, 프리미엄)',
  description TEXT COMMENT '요금제 설명',

  -- 제한 설정
  monthly_contract_limit INT NOT NULL COMMENT '월 계약서 작성 제한 (-1 = 무제한)',
  monthly_points_limit INT NOT NULL COMMENT '월 포인트 적립 제한 (-1 = 무제한)',
  initial_points INT NOT NULL DEFAULT 0 COMMENT '가입 시 제공 포인트',

  -- 가격
  price_monthly INT NOT NULL DEFAULT 0 COMMENT '월 구독료 (원)',
  price_yearly INT NULL COMMENT '연 구독료 (원)',

  -- 기능
  features JSON COMMENT '제공 기능 (JSON)',

  -- 상태
  is_active BOOLEAN DEFAULT TRUE COMMENT '활성 상태',
  display_order INT DEFAULT 0 COMMENT '표시 순서',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_tier (tier),
  INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='요금제 마스터 데이터';


-- 2. user_subscriptions (사용자 구독 정보)
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL COMMENT '사용자 ID',
  plan_id INT NOT NULL COMMENT '요금제 ID',

  -- 구독 기간
  started_at TIMESTAMP NOT NULL COMMENT '구독 시작일',
  expires_at TIMESTAMP NULL COMMENT '구독 만료일 (NULL = 활성)',

  -- 결제 정보
  payment_method VARCHAR(50) NULL COMMENT '결제 수단 (card, bank_transfer, free)',
  payment_id VARCHAR(100) NULL COMMENT '외부 결제 ID (Iamport 등)',
  amount_paid INT DEFAULT 0 COMMENT '실제 결제 금액',

  -- 상태
  status ENUM('active', 'expired', 'cancelled', 'pending') DEFAULT 'active' COMMENT '구독 상태',
  cancelled_at TIMESTAMP NULL COMMENT '취소 시각',
  cancel_reason TEXT NULL COMMENT '취소 사유',

  -- 자동 갱신
  auto_renew BOOLEAN DEFAULT FALSE COMMENT '자동 갱신 여부',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (plan_id) REFERENCES subscription_plans(id),

  INDEX idx_user_id (user_id),
  INDEX idx_status (status),
  INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='사용자별 구독 이력';


-- 3. points_ledger (포인트 거래 장부)
-- ====================================================================
CREATE TABLE IF NOT EXISTS points_ledger (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL COMMENT '사용자 ID',

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
  ) NOT NULL COMMENT '거래 유형',

  amount INT NOT NULL COMMENT '증감 포인트 (양수=적립, 음수=사용)',
  balance_after INT NOT NULL COMMENT '거래 후 잔액',

  -- 메타데이터
  description VARCHAR(255) NULL COMMENT '설명',
  reference_type VARCHAR(50) NULL COMMENT '참조 타입 (contract, template, user)',
  reference_id INT NULL COMMENT '참조 객체 ID',

  -- 만료 정보
  expires_at DATE NULL COMMENT '포인트 만료일',
  is_expired BOOLEAN DEFAULT FALSE COMMENT '만료 여부',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

  INDEX idx_user_id (user_id),
  INDEX idx_transaction_type (transaction_type),
  INDEX idx_created_at (created_at),
  INDEX idx_expires_at (expires_at),
  INDEX idx_reference (reference_type, reference_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='포인트 거래 내역 (완전한 감사 추적)';


-- 4. monthly_usage (월별 사용량)
-- ====================================================================
CREATE TABLE IF NOT EXISTS monthly_usage (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL COMMENT '사용자 ID',
  year INT NOT NULL COMMENT '연도',
  month INT NOT NULL COMMENT '월 (1~12)',

  -- 사용량
  contracts_created INT DEFAULT 0 COMMENT '이번 달 작성한 계약서 수',
  points_earned INT DEFAULT 0 COMMENT '이번 달 적립한 포인트',
  points_spent INT DEFAULT 0 COMMENT '이번 달 사용한 포인트',

  -- 출석 체크
  checkin_count INT DEFAULT 0 COMMENT '이번 달 출석 일수',
  last_checkin_date DATE NULL COMMENT '마지막 출석 날짜',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

  UNIQUE KEY uk_user_year_month (user_id, year, month),
  INDEX idx_user_id (user_id),
  INDEX idx_year_month (year, month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='월별 사용량 통계';


-- ====================================================================
-- 기본 요금제 데이터 삽입
-- ====================================================================

INSERT INTO subscription_plans (tier, name, description, monthly_contract_limit, monthly_points_limit, initial_points, price_monthly, price_yearly, features, is_active, display_order) VALUES
('free', '무료', '개인 사용자를 위한 기본 플랜', 4, 12, 12, 0, NULL, '{"templates": ["basic"], "ai_summary": false, "statistics": false, "team_members": 0}', TRUE, 1),
('premium', '프리미엄', '무제한 계약서 작성과 고급 기능', -1, -1, 0, 19900, 199000, '{"templates": ["basic", "premium"], "ai_summary": true, "statistics": true, "team_members": 0}', TRUE, 2)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  monthly_contract_limit = VALUES(monthly_contract_limit),
  monthly_points_limit = VALUES(monthly_points_limit),
  features = VALUES(features),
  updated_at = CURRENT_TIMESTAMP;


-- ====================================================================
-- users 테이블에 subscription_plan_id 컬럼 추가 (없으면)
-- ====================================================================

-- subscription_plan_id 컬럼이 없으면 추가
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'subscription_plan_id';

SET @sql = IF(@col_exists = 0,
  'ALTER TABLE users ADD COLUMN subscription_plan_id INT NULL COMMENT ''현재 활성 요금제 ID'' AFTER subscription_tier',
  'SELECT ''subscription_plan_id column already exists'' AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 외래키 추가 (없으면)
SET @fk_exists = 0;
SELECT COUNT(*) INTO @fk_exists
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'insign'
  AND TABLE_NAME = 'users'
  AND CONSTRAINT_NAME = 'fk_users_subscription_plan';

SET @sql = IF(@fk_exists = 0,
  'ALTER TABLE users ADD CONSTRAINT fk_users_subscription_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plans(id)',
  'SELECT ''Foreign key already exists'' AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;


-- ====================================================================
-- 완료 메시지
-- ====================================================================

SELECT '✅ Step 1 완료: 테이블 생성 및 초기 데이터 삽입 완료' AS message;
SELECT CONCAT('subscription_plans: ', COUNT(*), '개 요금제') AS status FROM subscription_plans;
