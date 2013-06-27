CREATE TABLE `clients` (
  `id` int(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `signature` char(16) DEFAULT NULL,
  `status` enum('active','disabled','deleted') DEFAULT NULL,
  `level` smallint(5) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `photo_fingerprints` (
  `id` bigint(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` bigint(20) unsigned NOT NULL,
  `created_at` datetime NOT NULL,
  `photo_count` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `fingerprint` (`value`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `photos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `client_id` smallint(5) unsigned DEFAULT NULL,
  `url` varchar(250) DEFAULT NULL,
  `fingerprint` bigint(20) unsigned DEFAULT NULL,
  `status` enum('pending','delivering','completed','deleted') NOT NULL DEFAULT 'pending',
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `status` (`status`,`created_at`),
  KEY `fingerprint` (`fingerprint`),
  KEY `url` (`url`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=FIXED;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `use_log_caches` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(250) CHARACTER SET latin1 NOT NULL DEFAULT '',
  `date` date NOT NULL DEFAULT '0000-00-00',
  `count` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `date` (`date`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `use_log_categories` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned NOT NULL DEFAULT '0',
  `name` varchar(50) NOT NULL,
  `description` varchar(250) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `parent_id` (`parent_id`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `use_log_data` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `category_id` int(10) unsigned NOT NULL DEFAULT '0',
  `date` date NOT NULL DEFAULT '0000-00-00',
  `count` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `date` (`date`,`category_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `votes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime NOT NULL,
  `worker_id` int(10) unsigned NOT NULL,
  `photo_id` bigint(20) unsigned DEFAULT NULL,
  `taskname` enum('nudity','video_approval') DEFAULT NULL,
  `decision` enum('pass','fail') NOT NULL,
  `weight` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `correct` enum('pending','yes','no','unknown') NOT NULL DEFAULT 'pending',
  `video_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `workers` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `turk_id` bigint(20) unsigned DEFAULT NULL,
  `username` varchar(100) DEFAULT NULL,
  `password` varchar(32) DEFAULT NULL,
  `clearance` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `weight` tinyint(2) unsigned NOT NULL DEFAULT '1',
  `token` varchar(32) DEFAULT NULL,
  `status` enum('active','deleted','suspended','banned','bot') NOT NULL DEFAULT 'active',
  `created_at` datetime NOT NULL,
  `creating_ip` char(15) DEFAULT NULL,
  `total_votes` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `rating` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `turk_id` (`turk_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

INSERT INTO schema_migrations (version) VALUES ('20130111210021');

INSERT INTO schema_migrations (version) VALUES ('20130627004528');

INSERT INTO schema_migrations (version) VALUES ('20130627154717');

INSERT INTO schema_migrations (version) VALUES ('20130627155450');