-- MySQL dump 10.11
--
-- Host: localhost    Database: netdb
-- ------------------------------------------------------
-- Server version	5.0.45

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `_sys_changelog`
--

DROP TABLE IF EXISTS `_sys_changelog`;
CREATE TABLE `_sys_changelog` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `user` int(10) unsigned NOT NULL default '0',
  `name` char(16) NOT NULL default '',
  `time` datetime default NULL,
  `info` char(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `index_user` (`user`),
  KEY `index_username` (`name`),
  KEY `index_time` (`time`)
);

--
-- Table structure for table `_sys_changerec_col`
--

DROP TABLE IF EXISTS `_sys_changerec_col`;
CREATE TABLE `_sys_changerec_col` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `changerec_row` int(10) unsigned NOT NULL default '0',
  `name` varchar(255) NOT NULL default '',
  `data` text,
  `previous` text,
  PRIMARY KEY  (`id`),
  KEY `index_record` (`changerec_row`,`name`)
);

--
-- Table structure for table `_sys_changerec_row`
--

DROP TABLE IF EXISTS `_sys_changerec_row`;
CREATE TABLE `_sys_changerec_row` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `changelog` int(10) unsigned NOT NULL default '0',
  `tname` char(255) NOT NULL default '',
  `row` int(10) unsigned NOT NULL default '0',
  `type` enum('INSERT','UPDATE','DELETE') NOT NULL default 'INSERT',
  PRIMARY KEY  (`id`),
  KEY `index_changelog` (`changelog`),
  KEY `index_record` (`tname`,`row`)
);

--
-- Table structure for table `_sys_dberror`
--

DROP TABLE IF EXISTS `_sys_dberror`;
CREATE TABLE `_sys_dberror` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `tname` enum('users','groups','building','cable','outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence','subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource','dns_zone') NOT NULL default 'users',
  `tid` int(10) unsigned NOT NULL default '0',
  `errfields` varchar(255) NOT NULL default '',
  `severity` enum('EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTICE','INFO') NOT NULL default 'ERROR',
  `errtype` int(10) unsigned NOT NULL default '0',
  `fixed` enum('UNFIXED','FIXED') NOT NULL default 'UNFIXED',
  `comment` text,
  PRIMARY KEY  (`id`)
);

--
-- Table structure for table `_sys_errors`
--

DROP TABLE IF EXISTS `_sys_errors`;
CREATE TABLE `_sys_errors` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `errcode` smallint(6) NOT NULL default '0',
  `location` varchar(64) NOT NULL default '',
  `errfields` varchar(255) NOT NULL default '',
  `errtext` text NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `index_error` (`errcode`,`location`,`errfields`)
);

--
-- Table structure for table `_sys_info`
--

DROP TABLE IF EXISTS `_sys_info`;
CREATE TABLE `_sys_info` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `sys_key` char(16) NOT NULL default '',
  `sys_value` char(128) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_key` (`sys_key`)
);

--
-- Table structure for table `_sys_scheduled`
--

DROP TABLE IF EXISTS `_sys_scheduled`;
CREATE TABLE `_sys_scheduled` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(128) NOT NULL default '',
  `previous_run` datetime NOT NULL default '0000-00-00 00:00:00',
  `next_run` datetime NOT NULL default '0000-00-00 00:00:00',
  `def_interval` mediumint(8) unsigned NOT NULL default '0',
  `blocked_until` datetime NOT NULL default '0000-00-00 00:00:00',
  `priority` int(10) unsigned default '100',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `activation_queue`
--

DROP TABLE IF EXISTS `activation_queue`;
CREATE TABLE `activation_queue` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `index_nodup` (`name`)
);

--
-- Table structure for table `attribute`
--

DROP TABLE IF EXISTS `attribute`;
CREATE TABLE `attribute` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `spec` int(10) unsigned NOT NULL default '0',
  `owner_table` enum('service_membership','service','users','groups','vlan','outlet','subnet') default NULL,
  `owner_tid` int(10) unsigned NOT NULL default '0',
  `data` text,
  PRIMARY KEY  (`id`),
  KEY `index_owner` (`owner_tid`),
  KEY `index_spec` (`spec`)
);

--
-- Table structure for table `attribute_spec`
--

DROP TABLE IF EXISTS `attribute_spec`;
CREATE TABLE `attribute_spec` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `format` text NOT NULL,
  `scope` enum('service_membership','service','users','groups','vlan','outlet','subnet') default NULL,
  `type` int(10) unsigned NOT NULL default '0',
  `ntimes` smallint(5) unsigned NOT NULL default '0',
  `description` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`,`type`,`scope`),
  KEY `index_type` (`type`)
);

--
-- Table structure for table `billing`
--

DROP TABLE IF EXISTS `billing`;
CREATE TABLE `billing` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `user` varchar(255) NOT NULL default '',
  `type` enum('purchase','refund') NOT NULL default 'purchase',
  `status` enum('processed','unprocessed') NOT NULL default 'unprocessed',
  `share` int(11) NOT NULL default '0',
  `category` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`id`)
);

--
-- Table structure for table `building`
--

DROP TABLE IF EXISTS `building`;
CREATE TABLE `building` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  `abbreviation` char(16) NOT NULL default '',
  `building` char(8) NOT NULL default '',
  `activation_queue` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_number` (`building`),
  UNIQUE KEY `index_abbreviation` (`abbreviation`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `cable`
--

DROP TABLE IF EXISTS `cable`;
CREATE TABLE `cable` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `label_from` char(24) NOT NULL default '',
  `label_to` char(24) NOT NULL default '',
  `type` enum('TYPE1','TYPE2','CAT5','CAT6','CATV','SMF0080','MMF0500','MMF0625','MMF1000','CAT5-TELCO') default NULL,
  `destination` enum('OUTLET','CLOSET') default NULL,
  `rack` enum('IBM','CAT5/6','CATV','FIBER','TELCO') NOT NULL default 'IBM',
  `prefix` char(1) NOT NULL default '',
  `from_building` char(8) NOT NULL default '',
  `from_wing` char(1) NOT NULL default '',
  `from_floor` char(2) NOT NULL default '',
  `from_closet` char(1) NOT NULL default '',
  `from_rack` char(1) NOT NULL default '',
  `from_panel` char(1) NOT NULL default '',
  `from_x` char(1) NOT NULL default '',
  `from_y` char(1) NOT NULL default '',
  `to_building` char(8) default NULL,
  `to_wing` char(1) default NULL,
  `to_floor` char(2) default NULL,
  `to_closet` char(1) default NULL,
  `to_rack` char(1) default NULL,
  `to_panel` char(1) default NULL,
  `to_x` char(1) default NULL,
  `to_y` char(1) default NULL,
  `to_floor_plan_x` char(2) default NULL,
  `to_floor_plan_y` char(2) default NULL,
  `to_outlet_number` char(1) default NULL,
  `to_room_number` char(32) default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `label_from_2` (`label_from`),
  KEY `index_lfrom` (`label_from`),
  KEY `index_lto` (`label_to`),
  KEY `label_from` (`label_from`,`label_to`,`id`),
  KEY `label_to` (`label_to`,`label_from`),
  KEY `label_to_2` (`label_to`,`label_from`,`id`,`version`)
);

--
-- Table structure for table `credentials`
--

DROP TABLE IF EXISTS `credentials`;
CREATE TABLE `credentials` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `authid` varchar(255) NOT NULL default '',
  `user` int(10) unsigned NOT NULL default '0',
  `description` varchar(255) NOT NULL default '',
  `fkey` varchar(255) NOT NULL default '',
  `source` varchar(16) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_authid` (`authid`),
  KEY `index_user` (`user`)
);

--
-- Table structure for table `dhcp_option`
--

DROP TABLE IF EXISTS `dhcp_option`;
CREATE TABLE `dhcp_option` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `value` char(255) NOT NULL default '',
  `type` enum('global','share','subnet','machine','service') NOT NULL default 'global',
  `tid` int(10) unsigned NOT NULL default '0',
  `type_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`type_id`,`type`,`tid`,`value`),
  KEY `index_record` (`type`,`tid`)
);

--
-- Table structure for table `dhcp_option_type`
--

DROP TABLE IF EXISTS `dhcp_option_type`;
CREATE TABLE `dhcp_option_type` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(64) NOT NULL default '',
  `number` int(10) unsigned NOT NULL default '0',
  `format` varchar(255) NOT NULL default '',
  `builtin` enum('Y','N') NOT NULL default 'N',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`),
  KEY `index_number` (`number`)
);

--
-- Table structure for table `dns_resource`
--

DROP TABLE IF EXISTS `dns_resource`;
CREATE TABLE `dns_resource` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `ttl` int(10) unsigned NOT NULL default '0',
  `type` varchar(8) NOT NULL default '',
  `rname` varchar(255) default NULL,
  `rmetric0` int(10) unsigned default NULL,
  `rmetric1` int(10) unsigned default NULL,
  `rport` int(10) unsigned default NULL,
  `text0` varchar(1024) default NULL,
  `text1` varchar(255) default NULL,
  `name_zone` int(10) unsigned NOT NULL default '0',
  `owner_type` enum('machine','dns_zone','service') NOT NULL default 'machine',
  `owner_tid` int(10) unsigned NOT NULL default '0',
  `rname_tid` int(10) unsigned default NULL,
  PRIMARY KEY  (`id`),
  KEY `index_name` (`name`),
  KEY `index_rname` (`rname`),
  KEY `index_name_zone` (`name_zone`)
);

--
-- Table structure for table `dns_resource_type`
--

DROP TABLE IF EXISTS `dns_resource_type`;
CREATE TABLE `dns_resource_type` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(8) NOT NULL default '',
  `format` char(8) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `dns_zone`
--

DROP TABLE IF EXISTS `dns_zone`;
CREATE TABLE `dns_zone` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `soa_host` varchar(255) NOT NULL default '',
  `soa_email` varchar(255) NOT NULL default '',
  `soa_serial` int(10) unsigned NOT NULL default '0',
  `soa_refresh` int(10) unsigned NOT NULL default '3600',
  `soa_retry` int(10) unsigned NOT NULL default '900',
  `soa_expire` int(10) unsigned NOT NULL default '2419200',
  `soa_minimum` int(10) unsigned NOT NULL default '3600',
  `type` enum('fw-toplevel','rv-toplevel','fw-permissible','rv-permissible','fw-delegated','rv-delegated','external') default NULL,
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  `soa_default` int(10) unsigned NOT NULL default '86400',
  `parent` int(10) unsigned NOT NULL default '0',
  `ddns_auth` text,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`),
  KEY `id` (`id`,`name`),
  KEY `name` (`name`,`id`)
);

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
CREATE TABLE `groups` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) NOT NULL auto_increment,
  `name` char(32) NOT NULL default '',
  `flags` set('abuse','suspend','purge_mailusers') NOT NULL default '',
  `description` char(64) NOT NULL default '',
  `comment_lvl9` char(64) NOT NULL default '',
  `comment_lvl5` char(64) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `mac_vendor`
--

DROP TABLE IF EXISTS `mac_vendor`;
CREATE TABLE `mac_vendor` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `prefix` varchar(6) NOT NULL default '',
  `vendor` varchar(128) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `prefix` (`prefix`),
  KEY `index_prefix` (`prefix`)
);

--
-- Table structure for table `machine`
--

DROP TABLE IF EXISTS `machine`;
CREATE TABLE `machine` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `mac_address` varchar(12) NOT NULL default '',
  `host_name` varchar(255) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `mode` enum('static','dynamic','reserved','broadcast','pool','base','secondary') NOT NULL default 'static',
  `flags` set('abuse','suspend','stolen','no_dnsfwd','no_dnsrev','roaming','independent','no_outlet','no_dhcp','no_expire') default NULL,
  `comment_lvl9` varchar(255) NOT NULL default '',
  `account` varchar(32) NOT NULL default '',
  `host_name_ttl` int(10) unsigned NOT NULL default '0',
  `ip_address_ttl` int(10) unsigned NOT NULL default '0',
  `host_name_zone` int(10) unsigned NOT NULL default '0',
  `ip_address_zone` int(10) unsigned NOT NULL default '0',
  `ip_address_subnet` int(10) unsigned NOT NULL default '0',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `expires` date NOT NULL default '0000-00-00',
  `comment_lvl1` varchar(255) NOT NULL default '',
  `comment_lvl5` varchar(255) NOT NULL default '',
  `ostype` enum('AIX','FreeBSD','HPUX','Irix','Linux','Mac OS 8.X','Mac OS 9.X','Mac OS X','NCDware','Printer','SCO','Solaris','SunOS','tru64 Unix','Ultrix','VMS','Windows 95','Windows 98','Windows CE','Windows ME','Windows XP','Windows NT','Windows 2000','Windows 2003','Other','Pocket PC','Windows Vista','Windows 2008') default NULL,
  `model` varchar(64) default NULL,
  `serial` varchar(64) default NULL,
  PRIMARY KEY  (`id`),
  KEY `index_host_name` (`host_name`),
  KEY `index_host_name_zone` (`host_name_zone`),
  KEY `index_ip_address_zone` (`ip_address_zone`),
  KEY `index_ip_address_subnet` (`ip_address_subnet`),
  KEY `index_ip_address` (`ip_address`),
  KEY `index_mac_address` (`mac_address`),
  KEY `index_subnet_mac` (`ip_address_subnet`,`mac_address`)
);

--
-- Table structure for table `machine_outlet`
--

DROP TABLE IF EXISTS `machine_outlet`;
CREATE TABLE `machine_outlet` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `machine` int(10) unsigned default NULL,
  `outlet` int(10) unsigned default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`machine`),
  KEY `index_machine_outlet` (`machine`,`outlet`)
);

--
-- Table structure for table `memberships`
--

DROP TABLE IF EXISTS `memberships`;
CREATE TABLE `memberships` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `uid` int(10) unsigned NOT NULL default '0',
  `gid` int(10) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_membership` (`uid`,`gid`),
  KEY `index_gid` (`gid`)
);

--
-- Table structure for table `network`
--

DROP TABLE IF EXISTS `network`;
CREATE TABLE `network` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  `subnet` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `index_subnet` (`subnet`)
);

--
-- Table structure for table `outlet`
--

DROP TABLE IF EXISTS `outlet`;
CREATE TABLE `outlet` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `type` int(10) unsigned NOT NULL default '0',
  `cable` int(10) unsigned NOT NULL default '0',
  `device` char(255) NOT NULL default '',
  `port` int(11) NOT NULL default '0',
  `attributes` set('activate','deactivate') NOT NULL default '',
  `flags` set('abuse','suspend','permanent','activated') NOT NULL default '',
  `status` enum('enabled','partitioned') NOT NULL default 'enabled',
  `account` char(32) NOT NULL default '',
  `comment_lvl9` char(255) NOT NULL default '',
  `comment_lvl1` char(255) NOT NULL default '',
  `comment_lvl5` char(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_cable` (`cable`),
  KEY `index_connect` (`device`,`port`)
);

--
-- Table structure for table `outlet_subnet_membership`
--

DROP TABLE IF EXISTS `outlet_subnet_membership`;
CREATE TABLE `outlet_subnet_membership` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `outlet` int(10) unsigned NOT NULL default '0',
  `subnet` int(10) unsigned NOT NULL default '0',
  `type` enum('primary','voice','other') NOT NULL default 'primary',
  `trunk_type` enum('802.1Q','ISL','none') NOT NULL default '802.1Q',
  `status` enum('request','active','delete','error','errordelete') NOT NULL default 'request',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_membership` (`outlet`,`subnet`),
  KEY `index_type` (`outlet`,`subnet`,`type`,`trunk_type`)
);

--
-- Table structure for table `outlet_type`
--

DROP TABLE IF EXISTS `outlet_type`;
CREATE TABLE `outlet_type` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `outlet_vlan_membership`
--

DROP TABLE IF EXISTS `outlet_vlan_membership`;
CREATE TABLE `outlet_vlan_membership` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) NOT NULL auto_increment,
  `outlet` int(10) NOT NULL default '0',
  `vlan` int(10) NOT NULL default '0',
  `type` enum('primary','voice','other') NOT NULL default 'primary',
  `trunk_type` enum('802.1Q','ISL','none') NOT NULL default '802.1Q',
  `status` enum('request','active','delete','error','errordelete') NOT NULL default 'request',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_membership` (`outlet`,`vlan`),
  KEY `index_type` (`outlet`,`vlan`,`type`,`trunk_type`)
);

--
-- Table structure for table `protections`
--

DROP TABLE IF EXISTS `protections`;
CREATE TABLE `protections` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `identity` int(11) NOT NULL default '0',
  `tname` enum('users','groups','building','cable','outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence','subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource','dns_zone','_sys_scheduled','activation_queue','service','service_membership','service_type','attribute','attribute_spec','outlet_subnet_membership','outlet_vlan_membership','vlan','vlan_presence','vlan_subnet_presence','trunk_set','trunkset_building_presence','trunkset_machine_presence','trunkset_vlan_presence','credentials','subnet_registration_modes','resdrop','machine_outlet','iprange_building_presence','srm_share','mac_vendor') NOT NULL default 'users',
  `tid` int(11) NOT NULL default '0',
  `rights` set('READ','WRITE','ADD') NOT NULL default '',
  `rlevel` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`identity`,`tname`,`tid`,`rlevel`),
  KEY `index_protection1` (`identity`,`tname`,`tid`),
  KEY `index_prot6` (`tname`,`rights`,`identity`,`tid`),
  KEY `tid` (`tid`),
  KEY `tname` (`tname`,`tid`),
  KEY `tname_2` (`tname`,`tid`,`identity`),
  KEY `index_all` (`tname`,`tid`,`identity`,`rlevel`,`rights`),
  KEY `index_all_2` (`tid`,`tname`,`identity`,`rlevel`,`rights`)
);

--
-- Table structure for table `resdrop`
--

DROP TABLE IF EXISTS `resdrop`;
CREATE TABLE `resdrop` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `jack` varchar(16) default NULL,
  `building` varchar(8) default NULL,
  `switch` varchar(255) default NULL,
  `slot` int(10) unsigned default NULL,
  `port` int(10) unsigned default NULL,
  `vlan` int(10) unsigned default NULL,
  `fkey` int(11) NOT NULL default '0',
  `flags` set('mac_security','guest_access','partition') default NULL,
  `secondary` varchar(16) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `building` (`building`,`id`)
);

--
-- Table structure for table `service`
--

DROP TABLE IF EXISTS `service`;
CREATE TABLE `service` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  `type` int(10) unsigned NOT NULL default '0',
  `description` char(255) NOT NULL default '',
  `min_member_level` int(10) unsigned NOT NULL default '1',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `service_membership`
--

DROP TABLE IF EXISTS `service_membership`;
CREATE TABLE `service_membership` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `service` int(10) unsigned NOT NULL default '0',
  `member_type` enum('activation_queue','building','cable','dns_zone','groups','machine','outlet','outlet_type','service','subnet','subnet_share','users','vlan') NOT NULL default 'activation_queue',
  `member_tid` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_members` (`member_type`,`member_tid`,`service`)
);

--
-- Table structure for table `service_type`
--

DROP TABLE IF EXISTS `service_type`;
CREATE TABLE `service_type` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `srm_share`
--

DROP TABLE IF EXISTS `srm_share`;
CREATE TABLE `srm_share` (
  `id` int(10) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `name` char(64) NOT NULL default '',
  `abbreviation` char(16) NOT NULL default '',
  `flags` set('purchasable') default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `abbreviation` (`abbreviation`)
);

--
-- Table structure for table `subnet`
--

DROP TABLE IF EXISTS `subnet`;
CREATE TABLE `subnet` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  `abbreviation` char(16) NOT NULL default '',
  `base_address` int(10) unsigned NOT NULL default '0',
  `network_mask` int(10) unsigned NOT NULL default '0',
  `dynamic` enum('permit','restrict','disallow','unknown') default NULL,
  `expire_static` int(10) unsigned NOT NULL default '0',
  `expire_dynamic` int(10) unsigned NOT NULL default '0',
  `share` int(10) unsigned NOT NULL default '0',
  `flags` set('no_dhcp','delegated','prereg_subnet') default NULL,
  `default_mode` enum('static','dynamic','reserved') NOT NULL default 'static',
  `purge_interval` int(10) unsigned NOT NULL default '0',
  `purge_notupd` int(10) unsigned NOT NULL default '0',
  `purge_notseen` int(10) unsigned NOT NULL default '0',
  `purge_explen` int(10) unsigned NOT NULL default '0',
  `purge_lastdone` datetime NOT NULL default '0000-00-00 00:00:00',
  `vlan` char(8) NOT NULL default '',
  `default_host_name_zone` int(10) NOT NULL default '0',
  `default_host_flags` set('abuse','suspend','stolen','no_dnsfwd','no_dnsrev','roaming','independent') default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`),
  UNIQUE KEY `index_abbreviation` (`abbreviation`),
  KEY `index_share` (`share`)
);

--
-- Table structure for table `subnet_domain`
--

DROP TABLE IF EXISTS `subnet_domain`;
CREATE TABLE `subnet_domain` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `subnet` int(10) unsigned NOT NULL default '0',
  `domain` char(252) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`subnet`,`domain`),
  KEY `index_subnet` (`subnet`),
  KEY `index_domain` (`domain`),
  KEY `id` (`id`,`domain`,`subnet`)
);

--
-- Table structure for table `subnet_presence`
--

DROP TABLE IF EXISTS `subnet_presence`;
CREATE TABLE `subnet_presence` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `subnet` int(10) unsigned NOT NULL default '0',
  `building` char(8) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`subnet`,`building`),
  KEY `index_subnet` (`subnet`),
  KEY `index_building` (`building`)
);

--
-- Table structure for table `subnet_registration_modes`
--

DROP TABLE IF EXISTS `subnet_registration_modes`;
CREATE TABLE `subnet_registration_modes` (
  `id` int(10) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `subnet` int(10) NOT NULL default '0',
  `mode` enum('static','dynamic','reserved','broadcast','pool','base','secondary') NOT NULL default 'static',
  `mac_address` enum('required','none') NOT NULL default 'required',
  `outlet` enum('required','none') NOT NULL default 'required',
  `share` int(10) NOT NULL default '0',
  `quota` int(10) unsigned default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `subnet` (`subnet`,`share`,`mode`,`mac_address`,`outlet`,`quota`),
  KEY `index_subnet_mode` (`subnet`,`mode`)
);

--
-- Table structure for table `subnet_share`
--

DROP TABLE IF EXISTS `subnet_share`;
CREATE TABLE `subnet_share` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  `abbreviation` char(16) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_abbreviation` (`abbreviation`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `trunk_set`
--

DROP TABLE IF EXISTS `trunk_set`;
CREATE TABLE `trunk_set` (
  `id` int(10) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `name` char(255) NOT NULL default '',
  `abbreviation` char(127) NOT NULL default '',
  `description` char(255) NOT NULL default '',
  `primary_vlan` int(10) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `trunkset_building_presence`
--

DROP TABLE IF EXISTS `trunkset_building_presence`;
CREATE TABLE `trunkset_building_presence` (
  `id` int(10) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `trunk_set` int(10) NOT NULL default '0',
  `buildings` int(10) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`trunk_set`,`buildings`),
  KEY `index_trunkset` (`trunk_set`),
  KEY `index_building` (`buildings`)
);

--
-- Table structure for table `trunkset_machine_presence`
--

DROP TABLE IF EXISTS `trunkset_machine_presence`;
CREATE TABLE `trunkset_machine_presence` (
  `id` int(10) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `device` int(10) NOT NULL default '0',
  `trunk_set` int(10) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`trunk_set`,`device`),
  KEY `index_trunkset` (`trunk_set`),
  KEY `index_vlan` (`device`)
);

--
-- Table structure for table `trunkset_vlan_presence`
--

DROP TABLE IF EXISTS `trunkset_vlan_presence`;
CREATE TABLE `trunkset_vlan_presence` (
  `id` int(10) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `trunk_set` int(10) NOT NULL default '0',
  `vlan` int(10) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`trunk_set`,`vlan`),
  KEY `index_trunkset` (`trunk_set`),
  KEY `index_vlan` (`vlan`)
);

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `flags` set('abuse','suspend','external') default NULL,
  `comment` varchar(64) NOT NULL default '',
  `fkey` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`)
);

--
-- Table structure for table `vlan`
--

DROP TABLE IF EXISTS `vlan`;
CREATE TABLE `vlan` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` char(64) NOT NULL default '',
  `abbreviation` char(16) NOT NULL default '',
  `number` int(4) NOT NULL default '0',
  `description` char(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
);

--
-- Table structure for table `vlan_subnet_presence`
--

DROP TABLE IF EXISTS `vlan_subnet_presence`;
CREATE TABLE `vlan_subnet_presence` (
  `id` int(10) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `subnet` int(10) NOT NULL default '0',
  `subnet_share` int(10) NOT NULL default '0',
  `vlan` int(10) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_nodup` (`subnet`,`vlan`),
  KEY `index_trunkset` (`subnet`),
  KEY `index_vlan` (`vlan`)
);
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2009-03-29 13:15:06
