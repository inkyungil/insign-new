CREATE TABLE IF NOT EXISTS `user_deletion_logs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int unsigned NOT NULL,
  `email` varchar(190) NOT NULL,
  `display_name` varchar(120) DEFAULT NULL,
  `provider` varchar(20) DEFAULT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `metadata` json DEFAULT NULL,
  `deleted_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_deletion_logs_user_id` (`user_id`),
  KEY `idx_user_deletion_logs_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
