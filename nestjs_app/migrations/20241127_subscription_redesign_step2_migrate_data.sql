-- ====================================================================
-- 구독/포인트 시스템 재설계 - Step 2: 기존 데이터 마이그레이션
-- ====================================================================
-- 작성일: 2025-11-27
-- 목적: users 테이블의 기존 데이터를 새 테이블로 이관
-- ====================================================================

USE insign;

-- ====================================================================
-- 1. 모든 사용자에게 무료 플랜 구독 생성
-- ====================================================================

-- 이미 구독이 있는 사용자는 제외하고 생성
INSERT INTO user_subscriptions (user_id, plan_id, started_at, status, payment_method)
SELECT
  u.id,
  (SELECT id FROM subscription_plans WHERE tier = 'free' LIMIT 1),
  u.created_at,
  'active',
  'free'
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM user_subscriptions us WHERE us.user_id = u.id AND us.status = 'active'
);

SELECT CONCAT('✅ ', ROW_COUNT(), '명의 사용자에게 무료 플랜 구독 생성 완료') AS message;


-- ====================================================================
-- 2. users.subscription_plan_id 업데이트
-- ====================================================================

UPDATE users u
SET u.subscription_plan_id = (
  SELECT id FROM subscription_plans WHERE tier = 'free' LIMIT 1
)
WHERE u.subscription_plan_id IS NULL;

SELECT CONCAT('✅ ', ROW_COUNT(), '명의 사용자 subscription_plan_id 업데이트 완료') AS message;


-- ====================================================================
-- 3. 기존 포인트를 points_ledger로 이관
-- ====================================================================

-- points 컬럼이 존재하는지 확인
SET @points_col_exists = 0;
SELECT COUNT(*) INTO @points_col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'points';

-- points 컬럼이 있으면 이관
SET @migrate_points_sql = IF(@points_col_exists > 0,
  'INSERT INTO points_ledger (user_id, transaction_type, amount, balance_after, description, created_at)
   SELECT
     id,
     ''earn_signup'',
     COALESCE(points, 12),
     COALESCE(points, 12),
     ''기존 데이터 마이그레이션 (초기 포인트)'',
     created_at
   FROM users
   WHERE NOT EXISTS (
     SELECT 1 FROM points_ledger pl WHERE pl.user_id = users.id
   )',
  'SELECT ''points 컬럼이 없어 포인트 마이그레이션 스킵'' AS message'
);

PREPARE stmt FROM @migrate_points_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT CONCAT('✅ 포인트 마이그레이션 완료') AS message;


-- ====================================================================
-- 4. 현재 월 사용량 레코드 생성
-- ====================================================================

-- contracts_used_this_month, points_earned_this_month 컬럼 존재 확인
SET @usage_cols_exist = 0;
SELECT COUNT(*) INTO @usage_cols_exist
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign'
  AND TABLE_NAME = 'users'
  AND COLUMN_NAME IN ('contracts_used_this_month', 'points_earned_this_month');

-- 컬럼이 있으면 이관
SET @migrate_usage_sql = IF(@usage_cols_exist >= 2,
  'INSERT INTO monthly_usage (user_id, year, month, contracts_created, points_earned, last_checkin_date)
   SELECT
     id,
     YEAR(NOW()),
     MONTH(NOW()),
     COALESCE(contracts_used_this_month, 0),
     COALESCE(points_earned_this_month, 0),
     last_check_in_date
   FROM users
   WHERE NOT EXISTS (
     SELECT 1 FROM monthly_usage mu
     WHERE mu.user_id = users.id
       AND mu.year = YEAR(NOW())
       AND mu.month = MONTH(NOW())
   )',
  'INSERT INTO monthly_usage (user_id, year, month, contracts_created, points_earned)
   SELECT
     id,
     YEAR(NOW()),
     MONTH(NOW()),
     0,
     0
   FROM users
   WHERE NOT EXISTS (
     SELECT 1 FROM monthly_usage mu
     WHERE mu.user_id = users.id
       AND mu.year = YEAR(NOW())
       AND mu.month = MONTH(NOW())
   )'
);

PREPARE stmt FROM @migrate_usage_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT CONCAT('✅ 월별 사용량 레코드 생성 완료') AS message;


-- ====================================================================
-- 5. 데이터 검증
-- ====================================================================

-- 검증 쿼리
SELECT '=== 데이터 마이그레이션 결과 ===' AS '';

SELECT
  '활성 구독' AS item,
  COUNT(*) AS count
FROM user_subscriptions
WHERE status = 'active';

SELECT
  '포인트 거래 내역' AS item,
  COUNT(*) AS count
FROM points_ledger;

SELECT
  '월별 사용량 레코드' AS item,
  COUNT(*) AS count
FROM monthly_usage;

SELECT
  '사용자 subscription_plan_id 설정' AS item,
  COUNT(*) AS count
FROM users
WHERE subscription_plan_id IS NOT NULL;

-- 사용자별 포인트 잔액 샘플 (상위 10명)
SELECT
  u.id AS user_id,
  u.email,
  COALESCE(SUM(pl.amount), 0) AS current_balance
FROM users u
LEFT JOIN points_ledger pl ON u.id = pl.user_id AND pl.is_expired = FALSE
GROUP BY u.id, u.email
ORDER BY u.id
LIMIT 10;

SELECT '✅ Step 2 완료: 기존 데이터 마이그레이션 완료' AS message;
