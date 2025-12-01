ALTER TABLE `templates`
  ADD COLUMN `is_active` TINYINT(1) NOT NULL DEFAULT 1
  AFTER `sample_payload`;

