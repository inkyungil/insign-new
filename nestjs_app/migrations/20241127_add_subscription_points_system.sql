-- 구독 및 포인트 시스템 필드 추가
-- 실행: mysql -u root -p insign < migrations/20241127_add_subscription_points_system.sql

USE insign;

-- 구독 티어 필드 추가 (free/premium)
ALTER TABLE users
ADD COLUMN subscription_tier VARCHAR(20) NOT NULL DEFAULT 'free' AFTER terms_agreed_at,
ADD COLUMN monthly_contract_limit INT NOT NULL DEFAULT 4 AFTER subscription_tier,
ADD COLUMN contracts_used_this_month INT NOT NULL DEFAULT 0 AFTER monthly_contract_limit,
ADD COLUMN last_reset_date DATE NULL AFTER contracts_used_this_month,
ADD COLUMN points INT NOT NULL DEFAULT 12 AFTER last_reset_date,
ADD COLUMN monthly_points_limit INT NOT NULL DEFAULT 12 AFTER points,
ADD COLUMN points_earned_this_month INT NOT NULL DEFAULT 0 AFTER monthly_points_limit,
ADD COLUMN last_check_in_date DATE NULL AFTER points_earned_this_month;

-- 기존 사용자에게 기본값 설정
UPDATE users
SET
  subscription_tier = 'free',
  monthly_contract_limit = 4,
  contracts_used_this_month = 0,
  points = 12,
  monthly_points_limit = 12,
  points_earned_this_month = 0
WHERE subscription_tier IS NULL OR subscription_tier = '';

SELECT '✅ 구독 및 포인트 시스템 필드가 추가되었습니다.' AS result;
