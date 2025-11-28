-- 구독 요금제 마스터 테이블 생성
-- 코드 수정 없이 DB에서 요금제 관리 가능하도록 개선

USE insign;

-- 1. 요금제 마스터 테이블 생성
CREATE TABLE subscription_plans (
  id INT PRIMARY KEY AUTO_INCREMENT,
  tier VARCHAR(20) NOT NULL UNIQUE COMMENT '티어 식별자 (free, premium, enterprise 등)',
  name VARCHAR(50) NOT NULL COMMENT '요금제 이름 (무료, 프리미엄 등)',
  description TEXT COMMENT '요금제 설명',

  -- 계약서 제한
  monthly_contract_limit INT NOT NULL DEFAULT 4 COMMENT '월 계약서 개수 (-1: 무제한)',

  -- 포인트 제한
  monthly_points_limit INT NOT NULL DEFAULT 12 COMMENT '월 포인트 획득 한도',
  initial_points INT NOT NULL DEFAULT 12 COMMENT '가입 시 제공 포인트',

  -- 가격
  price_monthly INT NOT NULL DEFAULT 0 COMMENT '월 구독료 (원)',
  price_yearly INT NULL COMMENT '연 구독료 (원, NULL이면 제공 안함)',

  -- 기능 제어
  features JSON COMMENT '기능 목록 (템플릿, AI, 통계 등)',

  -- 상태
  is_active BOOLEAN DEFAULT TRUE COMMENT '활성화 여부',
  display_order INT DEFAULT 0 COMMENT '표시 순서',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. 기본 요금제 데이터 삽입
INSERT INTO subscription_plans (
  tier,
  name,
  description,
  monthly_contract_limit,
  monthly_points_limit,
  initial_points,
  price_monthly,
  features,
  display_order
) VALUES
-- 무료 플랜
(
  'free',
  '무료',
  '개인 사용자를 위한 기본 플랜',
  4,
  12,
  12,
  0,
  JSON_OBJECT(
    'templates', JSON_ARRAY('basic'),
    'ai_summary', false,
    'statistics', false,
    'team_members', 0,
    'priority_support', false
  ),
  1
),
-- 프리미엄 플랜
(
  'premium',
  '프리미엄',
  '무제한 계약서 작성과 고급 기능',
  -1,  -- 무제한
  -1,  -- 무제한
  0,   -- 포인트 필요없음
  19900,
  JSON_OBJECT(
    'templates', JSON_ARRAY('basic', 'premium'),
    'ai_summary', true,
    'statistics', true,
    'team_members', 0,
    'priority_support', true
  ),
  2
);

-- 3. users 테이블에 plan_id 추가
ALTER TABLE users
ADD COLUMN subscription_plan_id INT NULL AFTER subscription_tier,
ADD CONSTRAINT fk_users_subscription_plan
  FOREIGN KEY (subscription_plan_id)
  REFERENCES subscription_plans(id);

-- 4. 기존 사용자들에게 plan_id 할당
UPDATE users u
JOIN subscription_plans sp ON sp.tier = u.subscription_tier
SET u.subscription_plan_id = sp.id;

-- 5. 인덱스 추가
CREATE INDEX idx_subscription_plans_tier ON subscription_plans(tier);
CREATE INDEX idx_subscription_plans_active ON subscription_plans(is_active);
CREATE INDEX idx_users_subscription_plan ON users(subscription_plan_id);

SELECT '✅ 구독 요금제 마스터 테이블이 생성되었습니다.' AS result;
SELECT '✅ 이제 코드 수정 없이 DB에서 요금제를 관리할 수 있습니다.' AS result;

-- 6. 확인 쿼리
SELECT
  id,
  tier,
  name,
  monthly_contract_limit,
  monthly_points_limit,
  price_monthly,
  is_active
FROM subscription_plans
ORDER BY display_order;
