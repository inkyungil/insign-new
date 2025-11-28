-- Add missing consent columns to users table (MySQL 5.7 compatible)

-- agreed_to_terms
SET @column_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'agreed_to_terms'
);
SET @add_column_sql := IF(
  @column_exists = 0,
  'ALTER TABLE `users` ADD COLUMN `agreed_to_terms` TINYINT(1) NOT NULL DEFAULT 0 AFTER `last_login_at`;',
  'SELECT 1'
);
PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- agreed_to_privacy
SET @column_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'agreed_to_privacy'
);
SET @add_column_sql := IF(
  @column_exists = 0,
  'ALTER TABLE `users` ADD COLUMN `agreed_to_privacy` TINYINT(1) NOT NULL DEFAULT 0 AFTER `agreed_to_terms`;',
  'SELECT 1'
);
PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- agreed_to_sensitive
SET @column_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'agreed_to_sensitive'
);
SET @add_column_sql := IF(
  @column_exists = 0,
  'ALTER TABLE `users` ADD COLUMN `agreed_to_sensitive` TINYINT(1) NOT NULL DEFAULT 0 AFTER `agreed_to_privacy`;',
  'SELECT 1'
);
PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- agreed_to_marketing
SET @column_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'agreed_to_marketing'
);
SET @add_column_sql := IF(
  @column_exists = 0,
  'ALTER TABLE `users` ADD COLUMN `agreed_to_marketing` TINYINT(1) NOT NULL DEFAULT 0 AFTER `agreed_to_sensitive`;',
  'SELECT 1'
);
PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- terms_agreed_at
SET @column_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'terms_agreed_at'
);
SET @add_column_sql := IF(
  @column_exists = 0,
  'ALTER TABLE `users` ADD COLUMN `terms_agreed_at` DATETIME NULL AFTER `agreed_to_marketing`;',
  'SELECT 1'
);
PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
