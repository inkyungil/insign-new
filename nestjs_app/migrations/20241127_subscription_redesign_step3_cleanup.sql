-- ====================================================================
-- 구독/포인트 시스템 재설계 - Step 3: 기존 컬럼 제거
-- ====================================================================
-- 작성일: 2025-11-27
-- 목적: users 테이블의 불필요한 컬럼 제거
-- 주의: 이 스크립트는 Step 1, 2가 완료된 후에만 실행해야 합니다!
-- ====================================================================

USE insign;

-- ====================================================================
-- 경고 메시지
-- ====================================================================

SELECT '⚠️  주의: 이 스크립트는 users 테이블의 컬럼을 삭제합니다!' AS warning;
SELECT '⚠️  반드시 Step 1, 2가 완료되고 데이터가 정상 이관되었는지 확인하세요!' AS warning;
SELECT '⚠️  백업을 먼저 생성하는 것을 권장합니다!' AS warning;


-- ====================================================================
-- 최종 확인: 데이터가 제대로 이관되었는지 검증
-- ====================================================================

SELECT '=== 데이터 검증 중 ===' AS '';

-- 1. 모든 사용자가 활성 구독을 가지고 있는지 확인
SELECT
  '활성 구독 없는 사용자' AS check_item,
  COUNT(*) AS count,
  CASE WHEN COUNT(*) = 0 THEN '✅ 통과' ELSE '❌ 실패' END AS status
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM user_subscriptions us
  WHERE us.user_id = u.id AND us.status = 'active'
);

-- 2. subscription_plan_id가 설정되지 않은 사용자 확인
SELECT
  'subscription_plan_id가 NULL인 사용자' AS check_item,
  COUNT(*) AS count,
  CASE WHEN COUNT(*) = 0 THEN '✅ 통과' ELSE '❌ 실패' END AS status
FROM users
WHERE subscription_plan_id IS NULL;

-- 3. 포인트 데이터 확인
SELECT
  '포인트 거래 내역' AS check_item,
  COUNT(*) AS count,
  CASE WHEN COUNT(*) > 0 THEN '✅ 통과' ELSE '⚠️  주의: 포인트 데이터 없음' END AS status
FROM points_ledger;


-- ====================================================================
-- 백업 테이블 생성 (선택사항)
-- ====================================================================

-- 혹시 모를 상황을 대비해 제거할 컬럼 데이터를 백업
DROP TABLE IF EXISTS users_subscription_backup;

CREATE TABLE users_subscription_backup AS
SELECT
  id,
  subscription_tier,
  COALESCE(monthly_contract_limit, 0) AS monthly_contract_limit,
  COALESCE(contracts_used_this_month, 0) AS contracts_used_this_month,
  last_reset_date,
  COALESCE(points, 0) AS points,
  COALESCE(monthly_points_limit, 0) AS monthly_points_limit,
  COALESCE(points_earned_this_month, 0) AS points_earned_this_month,
  last_check_in_date,
  NOW() AS backup_created_at
FROM users;

SELECT CONCAT('✅ 백업 테이블 생성 완료: users_subscription_backup (', COUNT(*), '건)') AS message
FROM users_subscription_backup;


-- ====================================================================
-- 컬럼 제거
-- ====================================================================

SELECT '=== 컬럼 제거 시작 ===' AS '';

-- 각 컬럼이 존재하는지 확인하고 제거

-- 1. points
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'points';

SET @sql = IF(@col_exists > 0,
  'ALTER TABLE users DROP COLUMN points',
  'SELECT ''points 컬럼이 이미 없습니다'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@col_exists > 0, '✅ points 컬럼 제거 완료', 'ℹ️  points 컬럼 없음') AS status;


-- 2. monthly_points_limit
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'monthly_points_limit';

SET @sql = IF(@col_exists > 0,
  'ALTER TABLE users DROP COLUMN monthly_points_limit',
  'SELECT ''monthly_points_limit 컬럼이 이미 없습니다'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@col_exists > 0, '✅ monthly_points_limit 컬럼 제거 완료', 'ℹ️  monthly_points_limit 컬럼 없음') AS status;


-- 3. points_earned_this_month
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'points_earned_this_month';

SET @sql = IF(@col_exists > 0,
  'ALTER TABLE users DROP COLUMN points_earned_this_month',
  'SELECT ''points_earned_this_month 컬럼이 이미 없습니다'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@col_exists > 0, '✅ points_earned_this_month 컬럼 제거 완료', 'ℹ️  points_earned_this_month 컬럼 없음') AS status;


-- 4. last_check_in_date
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'last_check_in_date';

SET @sql = IF(@col_exists > 0,
  'ALTER TABLE users DROP COLUMN last_check_in_date',
  'SELECT ''last_check_in_date 컬럼이 이미 없습니다'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@col_exists > 0, '✅ last_check_in_date 컬럼 제거 완료', 'ℹ️  last_check_in_date 컬럼 없음') AS status;


-- 5. contracts_used_this_month
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'contracts_used_this_month';

SET @sql = IF(@col_exists > 0,
  'ALTER TABLE users DROP COLUMN contracts_used_this_month',
  'SELECT ''contracts_used_this_month 컬럼이 이미 없습니다'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@col_exists > 0, '✅ contracts_used_this_month 컬럼 제거 완료', 'ℹ️  contracts_used_this_month 컬럼 없음') AS status;


-- 6. monthly_contract_limit
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'monthly_contract_limit';

SET @sql = IF(@col_exists > 0,
  'ALTER TABLE users DROP COLUMN monthly_contract_limit',
  'SELECT ''monthly_contract_limit 컬럼이 이미 없습니다'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@col_exists > 0, '✅ monthly_contract_limit 컬럼 제거 완료', 'ℹ️  monthly_contract_limit 컬럼 없음') AS status;


-- 7. last_reset_date
SET @col_exists = 0;
SELECT COUNT(*) INTO @col_exists
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'last_reset_date';

SET @sql = IF(@col_exists > 0,
  'ALTER TABLE users DROP COLUMN last_reset_date',
  'SELECT ''last_reset_date 컬럼이 이미 없습니다'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SELECT IF(@col_exists > 0, '✅ last_reset_date 컬럼 제거 완료', 'ℹ️  last_reset_date 컬럼 없음') AS status;


-- ====================================================================
-- 최종 확인
-- ====================================================================

SELECT '' AS '';
SELECT '=== 컬럼 제거 후 users 테이블 구조 ===' AS '';

-- users 테이블의 subscription 관련 컬럼 확인
SELECT
  COLUMN_NAME,
  DATA_TYPE,
  IS_NULLABLE,
  COLUMN_DEFAULT,
  COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'insign'
  AND TABLE_NAME = 'users'
  AND (
    COLUMN_NAME LIKE '%subscription%'
    OR COLUMN_NAME LIKE '%point%'
    OR COLUMN_NAME LIKE '%contract%'
  )
ORDER BY ORDINAL_POSITION;


-- ====================================================================
-- 완료 메시지
-- ====================================================================

SELECT '' AS '';
SELECT '✅ Step 3 완료: 기존 컬럼 제거 완료' AS message;
SELECT '✅ 백업 테이블: users_subscription_backup' AS backup_info;
SELECT '' AS '';
SELECT '=== 남은 컬럼 ===' AS '';
SELECT '- subscription_tier (레거시 호환용, 향후 제거 예정)' AS info;
SELECT '- subscription_plan_id (현재 활성 플랜 참조용)' AS info;
SELECT '' AS '';
SELECT '🎉 구독/포인트 시스템 재설계 완료!' AS final_message;
