-- Add column only when missing (works on MySQL 5.7+)
SET @column_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'contract_mail_logs'
    AND COLUMN_NAME = 'contract_id'
);

SET @add_column_sql := IF(
  @column_exists = 0,
  'ALTER TABLE `contract_mail_logs` ADD COLUMN `contract_id` int unsigned NULL AFTER `id`;',
  'SELECT 1'
);
PREPARE stmt_column FROM @add_column_sql;
EXECUTE stmt_column;
DEALLOCATE PREPARE stmt_column;

-- Add index only when missing
SET @index_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'contract_mail_logs'
    AND INDEX_NAME = 'idx_contract_mail_logs_contract_id'
);

SET @create_index_sql := IF(
  @index_exists = 0,
  'ALTER TABLE `contract_mail_logs` ADD INDEX `idx_contract_mail_logs_contract_id` (`contract_id`);',
  'SELECT 1'
);
PREPARE stmt_index FROM @create_index_sql;
EXECUTE stmt_index;
DEALLOCATE PREPARE stmt_index;

-- Add FK when missing
SET @fk_exists := (
  SELECT COUNT(1)
  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'contract_mail_logs'
    AND COLUMN_NAME = 'contract_id'
    AND REFERENCED_TABLE_NAME = 'contracts'
);

SET @add_fk_sql := IF(
  @fk_exists = 0,
  'ALTER TABLE `contract_mail_logs` ADD CONSTRAINT `fk_contract_mail_logs_contract_id` FOREIGN KEY (`contract_id`) REFERENCES `contracts`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;',
  'SELECT 1'
);
PREPARE stmt_fk FROM @add_fk_sql;
EXECUTE stmt_fk;
DEALLOCATE PREPARE stmt_fk;
