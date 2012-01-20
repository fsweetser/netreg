-- MySQL dump 10.11
--
-- Host: localhost    Database: netmon
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
-- Table structure for table `_locks`
--

DROP TABLE IF EXISTS `_locks`;
CREATE TABLE `_locks` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `count` int(11) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `_sys_info`
--

DROP TABLE IF EXISTS `_sys_info`;
CREATE TABLE `_sys_info` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `sys_key` char(64) default NULL,
  `sys_value` char(128) NOT NULL default '',
  `attime` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `sys_key` (`sys_key`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `arp_archive`
--

DROP TABLE IF EXISTS `arp_archive`;
CREATE TABLE `arp_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `registered` enum('N','Y') NOT NULL default 'N',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `ip_address` (`ip_address`),
  KEY `host` (`host`),
  KEY `end` (`end`)
) ENGINE=InnoDB AUTO_INCREMENT=14297447 DEFAULT CHARSET=latin1;

--
-- Table structure for table `arp_capture`
--

DROP TABLE IF EXISTS `arp_capture`;
CREATE TABLE `arp_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` varchar(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `registered` enum('N','Y') NOT NULL default 'N',
  `capture_id` int(10) unsigned NOT NULL default '0',
  `seen` enum('N','Y') NOT NULL default 'N',
  `interface` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `capture_id` (`capture_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10944173 DEFAULT CHARSET=latin1;

--
-- Table structure for table `arp_capture_extra`
--

DROP TABLE IF EXISTS `arp_capture_extra`;
CREATE TABLE `arp_capture_extra` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `mode` char(15) NOT NULL default '',
  `extra_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `extra_id` (`extra_id`),
  KEY `ip_address` (`ip_address`),
  KEY `host` (`host`)
) ENGINE=InnoDB AUTO_INCREMENT=760829209 DEFAULT CHARSET=latin1;

--
-- Table structure for table `arp_lastseen`
--

DROP TABLE IF EXISTS `arp_lastseen`;
CREATE TABLE `arp_lastseen` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `host_ip` (`host`,`ip_address`),
  KEY `ip_address` (`ip_address`),
  KEY `last_update` (`last_update`)
) ENGINE=InnoDB AUTO_INCREMENT=833580 DEFAULT CHARSET=latin1;

--
-- Table structure for table `arp_map`
--

DROP TABLE IF EXISTS `arp_map`;
CREATE TABLE `arp_map` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `arp_track` int(10) unsigned NOT NULL default '0',
  `interface` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `ind_arp` (`device`,`arp_track`),
  KEY `arp_t` (`arp_track`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `arp_tracking`
--

DROP TABLE IF EXISTS `arp_tracking`;
CREATE TABLE `arp_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `registered` enum('N','Y') NOT NULL default 'N',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `ip_address` (`ip_address`),
  KEY `host` (`host`),
  KEY `end` (`end`)
) ENGINE=InnoDB AUTO_INCREMENT=16305921 DEFAULT CHARSET=latin1;

--
-- Table structure for table `arp_tracking_archive`
--

DROP TABLE IF EXISTS `arp_tracking_archive`;
CREATE TABLE `arp_tracking_archive` (
  `id` int(10) unsigned NOT NULL default '0',
  `begin` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `spurious` enum('Y','N') NOT NULL default 'N',
  `unreg` enum('Y','N') NOT NULL default 'N',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `cam_archive`
--

DROP TABLE IF EXISTS `cam_archive`;
CREATE TABLE `cam_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `vlan` smallint(5) unsigned NOT NULL default '0',
  `registered` enum('N','Y') NOT NULL default 'N',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `end` (`end`),
  KEY `host` (`host`)
) ENGINE=InnoDB AUTO_INCREMENT=49202450 DEFAULT CHARSET=latin1;

--
-- Table structure for table `cam_capture`
--

DROP TABLE IF EXISTS `cam_capture`;
CREATE TABLE `cam_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `vlan` smallint(5) unsigned NOT NULL default '0',
  `registered` enum('N','Y') NOT NULL default 'N',
  `capture_id` int(10) unsigned NOT NULL default '0',
  `seen` enum('N','Y') NOT NULL default 'N',
  PRIMARY KEY  (`id`),
  KEY `capture_id` (`capture_id`)
) ENGINE=InnoDB AUTO_INCREMENT=204497569 DEFAULT CHARSET=latin1;

--
-- Table structure for table `cam_capture_extra`
--

DROP TABLE IF EXISTS `cam_capture_extra`;
CREATE TABLE `cam_capture_extra` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `extra_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `host` (`host`),
  KEY `extra_id` (`extra_id`)
) ENGINE=InnoDB AUTO_INCREMENT=760797850 DEFAULT CHARSET=latin1;

--
-- Table structure for table `cam_lastseen`
--

DROP TABLE IF EXISTS `cam_lastseen`;
CREATE TABLE `cam_lastseen` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `vlan` smallint(5) unsigned NOT NULL default '0',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `host_vl` (`host`,`vlan`),
  KEY `last_update` (`last_update`),
  KEY `vlan` (`vlan`)
) ENGINE=InnoDB AUTO_INCREMENT=136928 DEFAULT CHARSET=latin1;

--
-- Table structure for table `cam_tracking`
--

DROP TABLE IF EXISTS `cam_tracking`;
CREATE TABLE `cam_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `vlan` smallint(5) unsigned NOT NULL default '0',
  `registered` enum('N','Y') NOT NULL default 'N',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `end` (`end`),
  KEY `host_end` (`host`,`end`)
) ENGINE=InnoDB AUTO_INCREMENT=54697807 DEFAULT CHARSET=latin1;

--
-- Table structure for table `cam_tracking_archive`
--

DROP TABLE IF EXISTS `cam_tracking_archive`;
CREATE TABLE `cam_tracking_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `device` int(10) unsigned NOT NULL default '0',
  `port` smallint(5) unsigned NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `unregistered` enum('Y','N') NOT NULL default 'Y',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  `vlan` smallint(5) unsigned NOT NULL default '0',
  `assumed_location` enum('Y','N') NOT NULL default 'Y',
  PRIMARY KEY  (`id`),
  KEY `index_host` (`host`),
  KEY `index_ctdev` (`device`),
  KEY `index_end` (`end`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `capture_timings`
--

DROP TABLE IF EXISTS `capture_timings`;
CREATE TABLE `capture_timings` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `capture_type` enum('ARP','CAM','Ping','DevMAC','MCast','NetSage','Interface','Stalker','Routes','Topology','Ports','Device','Wifi') default NULL,
  `time` datetime NOT NULL default '0000-00-00 00:00:00',
  `extra` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `capture_type` (`capture_type`)
) ENGINE=InnoDB AUTO_INCREMENT=7561045 DEFAULT CHARSET=latin1;

--
-- Table structure for table `device`
--

DROP TABLE IF EXISTS `device`;
CREATE TABLE `device` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `read_comm` varchar(255) NOT NULL default 'public',
  `slow` tinyint(3) unsigned NOT NULL default '0',
  `netreg_id` int(10) unsigned NOT NULL default '0',
  `function` varchar(255) NOT NULL default '',
  `system_id` text,
  `stamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `seen` enum('y','n') NOT NULL default 'n',
  `snmp_version` enum('1','2') NOT NULL default '2',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name_id` (`name`,`netreg_id`),
  KEY `netreg_id` (`netreg_id`)
) ENGINE=InnoDB AUTO_INCREMENT=398 DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_capture`
--

DROP TABLE IF EXISTS `device_capture`;
CREATE TABLE `device_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `netreg_id` int(10) unsigned NOT NULL default '0',
  `function` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `netreg_id` (`netreg_id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=29604 DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_interface`
--

DROP TABLE IF EXISTS `device_interface`;
CREATE TABLE `device_interface` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `int_name` varchar(255) NOT NULL default '',
  `primary_ip` int(10) unsigned NOT NULL default '0',
  `primary_netmask` int(10) unsigned NOT NULL default '0',
  `mac_address` varchar(12) NOT NULL default '',
  `secondary_ips` text,
  `interface_id` int(10) unsigned NOT NULL default '0',
  `int_description` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `ind_dev_int` (`device`,`interface_id`),
  CONSTRAINT `0_629` FOREIGN KEY (`device`) REFERENCES `device` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_mac`
--

DROP TABLE IF EXISTS `device_mac`;
CREATE TABLE `device_mac` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device_id` int(10) unsigned NOT NULL default '0',
  `mac_address` char(12) NOT NULL default '',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `dev_mac` (`device_id`,`mac_address`),
  KEY `index_mac` (`mac_address`),
  CONSTRAINT `0_631` FOREIGN KEY (`device_id`) REFERENCES `device` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_port`
--

DROP TABLE IF EXISTS `device_port`;
CREATE TABLE `device_port` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `name` char(255) NOT NULL default '',
  `port` int(4) unsigned NOT NULL default '0',
  `portmap` char(255) NOT NULL default '',
  `remote_ip` int(10) unsigned NOT NULL default '0',
  `remote_port` int(4) unsigned NOT NULL default '0',
  `last_update` datetime default NULL,
  `type` enum('uplink','user','other') default NULL,
  PRIMARY KEY  (`id`),
  KEY `index_device` (`device`),
  KEY `index_name` (`name`),
  KEY `index_time` (`last_update`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_timings`
--

DROP TABLE IF EXISTS `device_timings`;
CREATE TABLE `device_timings` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `capture_type` varchar(255) NOT NULL default '',
  `last_begin` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_end` datetime NOT NULL default '0000-00-00 00:00:00',
  `activate` enum('Yes','No') NOT NULL default 'No',
  `upd_interval` int(10) unsigned NOT NULL default '3600',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `dev_capt` (`device`,`capture_type`),
  CONSTRAINT `0_839` FOREIGN KEY (`device`) REFERENCES `device` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1197 DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_timings_default`
--

DROP TABLE IF EXISTS `device_timings_default`;
CREATE TABLE `device_timings_default` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device_type` varchar(255) NOT NULL default '',
  `capture_type` varchar(255) NOT NULL default '',
  `upd_interval` int(10) unsigned NOT NULL default '3600',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `dev_cap_type` (`device_type`,`capture_type`)
) ENGINE=InnoDB AUTO_INCREMENT=72 DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_types`
--

DROP TABLE IF EXISTS `device_types`;
CREATE TABLE `device_types` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `type` varchar(255) NOT NULL default '',
  `pattern` varchar(255) NOT NULL default '',
  `read_comm` varchar(255) NOT NULL default 'public',
  PRIMARY KEY  (`id`),
  KEY `type` (`type`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_uplink`
--

DROP TABLE IF EXISTS `device_uplink`;
CREATE TABLE `device_uplink` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device_id` int(10) unsigned NOT NULL default '0',
  `port` smallint(5) unsigned NOT NULL default '0',
  `vlan` smallint(5) unsigned NOT NULL default '0',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `dev_port_vlan` (`device_id`,`port`,`vlan`),
  CONSTRAINT `0_635` FOREIGN KEY (`device_id`) REFERENCES `device` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `device_vlan`
--

DROP TABLE IF EXISTS `device_vlan`;
CREATE TABLE `device_vlan` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device_id` int(10) unsigned NOT NULL default '0',
  `vlan` int(10) unsigned NOT NULL default '0',
  `name` char(255) default NULL,
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device_id` (`device_id`),
  CONSTRAINT `0_637` FOREIGN KEY (`device_id`) REFERENCES `device` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `devmac_archive`
--

DROP TABLE IF EXISTS `devmac_archive`;
CREATE TABLE `devmac_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `end` (`end`),
  KEY `host` (`host`)
) ENGINE=InnoDB AUTO_INCREMENT=23976 DEFAULT CHARSET=latin1;

--
-- Table structure for table `devmac_capture`
--

DROP TABLE IF EXISTS `devmac_capture`;
CREATE TABLE `devmac_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `capture_id` int(10) unsigned NOT NULL default '0',
  `seen` enum('N','Y') NOT NULL default 'N',
  PRIMARY KEY  (`id`),
  KEY `capture_id` (`capture_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9507305 DEFAULT CHARSET=latin1;

--
-- Table structure for table `devmac_lastseen`
--

DROP TABLE IF EXISTS `devmac_lastseen`;
CREATE TABLE `devmac_lastseen` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  `device` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `host` (`host`,`iid`),
  KEY `last_update` (`last_update`)
) ENGINE=InnoDB AUTO_INCREMENT=25415 DEFAULT CHARSET=latin1;

--
-- Table structure for table `devmac_tracking`
--

DROP TABLE IF EXISTS `devmac_tracking`;
CREATE TABLE `devmac_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `end` (`end`),
  KEY `host` (`host`,`end`)
) ENGINE=InnoDB AUTO_INCREMENT=43976 DEFAULT CHARSET=latin1;

--
-- Table structure for table `dhcp_fingerprints`
--

DROP TABLE IF EXISTS `dhcp_fingerprints`;
CREATE TABLE `dhcp_fingerprints` (
  `id` bigint(20) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `first` datetime NOT NULL default '0000-00-00 00:00:00',
  `last` datetime NOT NULL default '0000-00-00 00:00:00',
  `host` char(12) NOT NULL default '',
  `vcid` char(64) NOT NULL default '',
  `optlist` char(128) NOT NULL default '',
  `macprefix` char(6) NOT NULL default '',
  `cnt` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `searchfields` (`optlist`,`vcid`,`macprefix`,`host`,`first`),
  KEY `host` (`host`)
) ENGINE=InnoDB AUTO_INCREMENT=264100 DEFAULT CHARSET=latin1;

--
-- Table structure for table `dhcp_fingerprints_lib`
--

DROP TABLE IF EXISTS `dhcp_fingerprints_lib`;
CREATE TABLE `dhcp_fingerprints_lib` (
  `id` bigint(20) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `vcid` varchar(64) NOT NULL default '',
  `optlist` varchar(128) NOT NULL default '',
  `macprefix` varchar(6) NOT NULL default '',
  `category` varchar(32) NOT NULL default '',
  `os` varchar(64) default NULL,
  `bad` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `searchfields` (`optlist`,`vcid`,`macprefix`)
) ENGINE=InnoDB AUTO_INCREMENT=166 DEFAULT CHARSET=latin1;

--
-- Table structure for table `dhcp_leases`
--

DROP TABLE IF EXISTS `dhcp_leases`;
CREATE TABLE `dhcp_leases` (
  `id` bigint(20) NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `type` enum('static','dynamic') NOT NULL default 'static',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `client_hostname` char(64) default NULL,
  `dhcp_server` char(32) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `index_ip` (`ip_address`),
  KEY `ind_end` (`end`),
  KEY `ind_start` (`start`),
  KEY `host` (`host`)
) ENGINE=InnoDB AUTO_INCREMENT=7409662 DEFAULT CHARSET=latin1;

--
-- Table structure for table `dhcp_leases_archive`
--

DROP TABLE IF EXISTS `dhcp_leases_archive`;
CREATE TABLE `dhcp_leases_archive` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `type` enum('static','dynamic') NOT NULL default 'static',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `client_hostname` char(64) default NULL,
  `dhcp_server` char(32) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `index_ip` (`ip_address`),
  KEY `ind_end` (`end`),
  KEY `ind_start` (`start`)
) ENGINE=InnoDB AUTO_INCREMENT=6193585 DEFAULT CHARSET=latin1;

--
-- Table structure for table `group_info`
--

DROP TABLE IF EXISTS `group_info`;
CREATE TABLE `group_info` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `groupname` char(8) NOT NULL default 'basic',
  `description` char(128) default NULL,
  PRIMARY KEY  (`id`),
  KEY `groupname` (`groupname`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `group_timings`
--

DROP TABLE IF EXISTS `group_timings`;
CREATE TABLE `group_timings` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `groupid` int(10) unsigned NOT NULL default '0',
  `capture_type` enum('ARP','CAM','Ping','DevMAC','MCast','NetSage','Interface','Stalker') default NULL,
  `last_begin` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_end` datetime NOT NULL default '0000-00-00 00:00:00',
  `activate` enum('Yes','No') NOT NULL default 'No',
  `upd_interval` smallint(5) unsigned NOT NULL default '3600',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `grp_capt` (`groupid`,`capture_type`),
  KEY `capt_type` (`capture_type`),
  KEY `index_grp` (`groupid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
CREATE TABLE `groups` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) NOT NULL default '0',
  `name` char(32) NOT NULL default '',
  `flags` set('abuse','suspend','purge_mailusers') NOT NULL default '',
  `description` char(64) NOT NULL default '',
  `comment_lvl9` char(64) NOT NULL default '',
  `comment_lvl5` char(64) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `groups_attrs`
--

DROP TABLE IF EXISTS `groups_attrs`;
CREATE TABLE `groups_attrs` (
  `id` int(11) NOT NULL auto_increment,
  `grp` int(11) NOT NULL default '0',
  `name` varchar(255) NOT NULL default '',
  `data` text,
  PRIMARY KEY  (`id`),
  KEY `grp` (`grp`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `groups_cache`
--

DROP TABLE IF EXISTS `groups_cache`;
CREATE TABLE `groups_cache` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `grp` int(10) unsigned NOT NULL default '0',
  `dev` int(10) unsigned NOT NULL default '0',
  `stamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`),
  KEY `grp` (`grp`),
  KEY `stamp` (`stamp`),
  KEY `dev` (`dev`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `groups_cache_old`
--

DROP TABLE IF EXISTS `groups_cache_old`;
CREATE TABLE `groups_cache_old` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `grp` int(10) unsigned NOT NULL default '0',
  `dev` int(10) unsigned NOT NULL default '0',
  `stamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`),
  KEY `grp` (`grp`),
  KEY `dev` (`dev`),
  KEY `stamp` (`stamp`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `groups_rules`
--

DROP TABLE IF EXISTS `groups_rules`;
CREATE TABLE `groups_rules` (
  `id` int(11) NOT NULL auto_increment,
  `grp` int(11) NOT NULL default '0',
  `type` varchar(255) default NULL,
  `glue` enum('AND','AND NOT','OR','OR NOT','NIL') NOT NULL default 'AND',
  `rule` text,
  `stamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`),
  KEY `grp_id` (`grp`),
  KEY `stamp` (`stamp`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `interface_capture`
--

DROP TABLE IF EXISTS `interface_capture`;
CREATE TABLE `interface_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `port` int(10) unsigned NOT NULL default '0',
  `status` int(11) default '0',
  `time` datetime default NULL,
  `capture_id` int(10) unsigned NOT NULL default '0',
  `tag` enum('Y','N') default NULL,
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  CONSTRAINT `0_645` FOREIGN KEY (`device`) REFERENCES `device` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=133260 DEFAULT CHARSET=latin1;

--
-- Table structure for table `interface_process`
--

DROP TABLE IF EXISTS `interface_process`;
CREATE TABLE `interface_process` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `port` int(10) unsigned NOT NULL default '0',
  `status` int(11) default '0',
  `good` tinyint(1) default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_state` (`device`,`port`,`start`,`end`,`status`),
  UNIQUE KEY `index_state2` (`device`,`port`,`start`,`status`),
  KEY `index_device` (`device`),
  KEY `index_end` (`end`),
  KEY `index_start` (`start`),
  KEY `index_port` (`port`)
) ENGINE=InnoDB AUTO_INCREMENT=19903 DEFAULT CHARSET=latin1;

--
-- Table structure for table `landb`
--

DROP TABLE IF EXISTS `landb`;
CREATE TABLE `landb` (
  `switch` varchar(64) default NULL,
  `iid` varchar(8) default NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `mcast_capture`
--

DROP TABLE IF EXISTS `mcast_capture`;
CREATE TABLE `mcast_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `mgroup` int(10) unsigned NOT NULL default '0',
  `source` int(10) unsigned NOT NULL default '0',
  `netmask` int(10) unsigned NOT NULL default '0',
  `usneighbor` int(10) unsigned NOT NULL default '0',
  `int_in` int(10) NOT NULL default '0',
  `time` datetime default NULL,
  PRIMARY KEY  (`id`),
  KEY `index_time` (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `mcast_capture_dsn`
--

DROP TABLE IF EXISTS `mcast_capture_dsn`;
CREATE TABLE `mcast_capture_dsn` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `parent` int(10) unsigned NOT NULL default '0',
  `int_out` int(10) NOT NULL default '0',
  `num_hops` int(10) default NULL,
  `time` datetime default NULL,
  PRIMARY KEY  (`id`),
  KEY `time` (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `membership`
--

DROP TABLE IF EXISTS `membership`;
CREATE TABLE `membership` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `level` enum('0','1','2','3','4','5','6','7','8','9') NOT NULL default '0',
  `uid` int(10) unsigned NOT NULL default '0',
  `gid` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `uid` (`uid`),
  KEY `gid` (`gid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `mibs`
--

DROP TABLE IF EXISTS `mibs`;
CREATE TABLE `mibs` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `oid` varchar(255) NOT NULL,
  `label` varchar(64) NOT NULL,
  `leaf` tinyint(4) NOT NULL default '0',
  `keep` tinyint(4) NOT NULL default '0',
  `syntax` varchar(32) default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `oid` (`oid`)
) ENGINE=InnoDB AUTO_INCREMENT=39827 DEFAULT CHARSET=latin1;

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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

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
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `ports_archive`
--

DROP TABLE IF EXISTS `ports_archive`;
CREATE TABLE `ports_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `port` varchar(255) NOT NULL default '',
  `type` varchar(255) NOT NULL default '',
  `mac` varchar(12) NOT NULL default '',
  `name` varchar(255) NOT NULL default '',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `end` (`end`),
  KEY `device` (`device`,`iid`)
) ENGINE=InnoDB AUTO_INCREMENT=17141 DEFAULT CHARSET=latin1;

--
-- Table structure for table `ports_capture`
--

DROP TABLE IF EXISTS `ports_capture`;
CREATE TABLE `ports_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `port` varchar(255) NOT NULL default '',
  `type` varchar(255) NOT NULL default '',
  `mac` varchar(12) NOT NULL default '',
  `name` varchar(255) NOT NULL default '',
  `capture_id` int(10) unsigned NOT NULL default '0',
  `seen` enum('N','Y') NOT NULL default 'N',
  PRIMARY KEY  (`id`),
  KEY `capture_id` (`capture_id`)
) ENGINE=InnoDB AUTO_INCREMENT=137148 DEFAULT CHARSET=latin1;

--
-- Table structure for table `ports_tracking`
--

DROP TABLE IF EXISTS `ports_tracking`;
CREATE TABLE `ports_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `iid` smallint(5) unsigned NOT NULL default '0',
  `port` varchar(255) NOT NULL default '',
  `type` varchar(255) NOT NULL default '',
  `mac` varchar(12) NOT NULL default '',
  `name` varchar(255) NOT NULL default '',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `end` (`end`),
  KEY `device_iid` (`device`,`iid`),
  KEY `device_port` (`device`,`port`)
) ENGINE=InnoDB AUTO_INCREMENT=75311 DEFAULT CHARSET=latin1;

--
-- Table structure for table `routes_archive`
--

DROP TABLE IF EXISTS `routes_archive`;
CREATE TABLE `routes_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `known` enum('unknown','found','known') NOT NULL default 'unknown',
  `netregid` int(10) unsigned NOT NULL default '0',
  `route` int(10) unsigned NOT NULL default '0',
  `mask` int(10) unsigned NOT NULL default '0',
  `gateway` int(10) unsigned NOT NULL default '0',
  `type` varchar(5) NOT NULL default '',
  `interface` varchar(255) NOT NULL default '',
  `distance` tinyint(3) unsigned NOT NULL default '0',
  `metric` tinyint(3) unsigned NOT NULL default '0',
  `source` int(10) unsigned NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `route` (`route`),
  KEY `end` (`end`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `routes_capture`
--

DROP TABLE IF EXISTS `routes_capture`;
CREATE TABLE `routes_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `known` enum('unknown','found','known') NOT NULL default 'unknown',
  `netregid` int(10) unsigned NOT NULL default '0',
  `route` int(10) unsigned NOT NULL default '0',
  `mask` int(10) unsigned NOT NULL default '0',
  `gateway` int(10) unsigned NOT NULL default '0',
  `type` varchar(5) NOT NULL default '',
  `interface` varchar(255) NOT NULL default '',
  `distance` tinyint(3) unsigned NOT NULL default '0',
  `metric` tinyint(3) unsigned NOT NULL default '0',
  `source` int(10) unsigned NOT NULL default '0',
  `capture_id` int(10) unsigned NOT NULL default '0',
  `seen` enum('N','Y') NOT NULL default 'N',
  `idx` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `capture_id` (`capture_id`),
  KEY `idx` (`idx`),
  KEY `route` (`route`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `routes_capture_extra`
--

DROP TABLE IF EXISTS `routes_capture_extra`;
CREATE TABLE `routes_capture_extra` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `base` int(10) unsigned NOT NULL default '0',
  `mask` int(10) unsigned NOT NULL default '0',
  `subid` int(10) unsigned NOT NULL default '0',
  `extra_id` int(10) unsigned NOT NULL default '0',
  `idx` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `extra_id` (`extra_id`)
) ENGINE=InnoDB AUTO_INCREMENT=586189 DEFAULT CHARSET=latin1;

--
-- Table structure for table `routes_tracking`
--

DROP TABLE IF EXISTS `routes_tracking`;
CREATE TABLE `routes_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `known` enum('unknown','found','known') NOT NULL default 'unknown',
  `netregid` int(10) unsigned NOT NULL default '0',
  `route` int(10) unsigned NOT NULL default '0',
  `mask` int(10) unsigned NOT NULL default '0',
  `gateway` int(10) unsigned NOT NULL default '0',
  `type` varchar(5) NOT NULL default '',
  `interface` varchar(255) NOT NULL default '',
  `distance` tinyint(3) unsigned NOT NULL default '0',
  `metric` tinyint(3) unsigned NOT NULL default '0',
  `source` int(10) unsigned NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `route` (`route`),
  KEY `end` (`end`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalk_capture`
--

DROP TABLE IF EXISTS `stalk_capture`;
CREATE TABLE `stalk_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `mac` char(12) default NULL,
  `snr` int(3) NOT NULL default '0',
  `time` datetime NOT NULL default '0000-00-00 00:00:00',
  `delete_me` enum('Y','N0','N') NOT NULL default 'N',
  PRIMARY KEY  (`id`),
  KEY `ind_time` (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalk_tracking`
--

DROP TABLE IF EXISTS `stalk_tracking`;
CREATE TABLE `stalk_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `mac` char(12) NOT NULL default '',
  `snr` int(3) NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  `assumed_location` enum('Y','N') NOT NULL default 'Y',
  PRIMARY KEY  (`id`),
  KEY `int_key` (`mac`),
  KEY `ind_device` (`device`),
  KEY `ind_end` (`end`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalk_tracking_archive`
--

DROP TABLE IF EXISTS `stalk_tracking_archive`;
CREATE TABLE `stalk_tracking_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `mac` char(12) NOT NULL default '',
  `snr` int(3) NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  `assumed_location` enum('Y','N') NOT NULL default 'Y',
  PRIMARY KEY  (`id`),
  KEY `int_key` (`mac`),
  KEY `ind_device` (`device`),
  KEY `ind_end` (`end`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalker_archive`
--

DROP TABLE IF EXISTS `stalker_archive`;
CREATE TABLE `stalker_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `snr` float NOT NULL default '0',
  `snr_min` tinyint(3) unsigned NOT NULL default '0',
  `snr_max` tinyint(3) unsigned NOT NULL default '0',
  `count` smallint(5) unsigned NOT NULL default '1',
  `registered` enum('N','Y') NOT NULL default 'N',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `host` (`host`),
  KEY `end` (`end`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalker_capture`
--

DROP TABLE IF EXISTS `stalker_capture`;
CREATE TABLE `stalker_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `snr` tinyint(3) unsigned NOT NULL default '0',
  `snr_min` tinyint(3) unsigned NOT NULL default '0',
  `snr_max` tinyint(3) unsigned NOT NULL default '0',
  `count` smallint(5) unsigned NOT NULL default '1',
  `registered` enum('N','Y') NOT NULL default 'N',
  `capture_id` int(10) unsigned NOT NULL default '0',
  `seen` enum('N','Y') NOT NULL default 'N',
  PRIMARY KEY  (`id`),
  KEY `capture_id` (`capture_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalker_capture_extra`
--

DROP TABLE IF EXISTS `stalker_capture_extra`;
CREATE TABLE `stalker_capture_extra` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `extra_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `host` (`host`),
  KEY `extra_id` (`extra_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalker_lastseen`
--

DROP TABLE IF EXISTS `stalker_lastseen`;
CREATE TABLE `stalker_lastseen` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` char(12) NOT NULL default '',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `last_update` (`last_update`),
  KEY `host` (`host`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `stalker_tracking`
--

DROP TABLE IF EXISTS `stalker_tracking`;
CREATE TABLE `stalker_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `snr` float NOT NULL default '0',
  `snr_min` tinyint(3) unsigned NOT NULL default '0',
  `snr_max` tinyint(3) unsigned NOT NULL default '0',
  `count` smallint(5) unsigned NOT NULL default '1',
  `registered` enum('N','Y') NOT NULL default 'N',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `host` (`host`),
  KEY `end` (`end`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `topology`
--

DROP TABLE IF EXISTS `topology`;
CREATE TABLE `topology` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device_parent` int(10) unsigned NOT NULL default '0',
  `device_child` int(10) unsigned NOT NULL default '0',
  `time` datetime NOT NULL default '0000-00-00 00:00:00',
  `parent_vlan` smallint(5) unsigned NOT NULL default '0',
  `child_vlan` smallint(5) unsigned NOT NULL default '0',
  `relationship` enum('L3toL2','L2toL2') NOT NULL default 'L2toL2',
  `parent_int` smallint(5) unsigned NOT NULL default '0',
  `child_int` smallint(5) unsigned NOT NULL default '0',
  `type` enum('v1','v2-s3a') NOT NULL default 'v1',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `index_pchild` (`device_parent`,`parent_vlan`,`device_child`),
  KEY `index_parent` (`device_parent`),
  KEY `device_child` (`device_child`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `topology_staging`
--

DROP TABLE IF EXISTS `topology_staging`;
CREATE TABLE `topology_staging` (
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `port` int(10) unsigned NOT NULL default '0',
  `vlan` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`device`,`host`,`port`,`vlan`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `topology_staging_arp`
--

DROP TABLE IF EXISTS `topology_staging_arp`;
CREATE TABLE `topology_staging_arp` (
  `device` int(10) unsigned NOT NULL default '0',
  `host` char(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `interface` smallint(6) NOT NULL default '0',
  PRIMARY KEY  (`device`,`host`,`ip_address`,`interface`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `topology_tree`
--

DROP TABLE IF EXISTS `topology_tree`;
CREATE TABLE `topology_tree` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` varchar(255) NOT NULL default '',
  `display` varchar(255) NOT NULL default '',
  `parent` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `parent` (`parent`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Temporary table structure for view `trap_varbinds`
--

DROP TABLE IF EXISTS `trap_varbinds`;
/*!50001 DROP VIEW IF EXISTS `trap_varbinds`*/;
/*!50001 CREATE TABLE `trap_varbinds` (
  `id` int(10) unsigned,
  `version` timestamp,
  `trap` int(10) unsigned,
  `oid` varchar(255),
  `iid` varchar(255),
  `val` longblob,
  `label` varchar(255)
) */;

--
-- Table structure for table `trap_varbinds_raw`
--

DROP TABLE IF EXISTS `trap_varbinds_raw`;
CREATE TABLE `trap_varbinds_raw` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `trap` int(10) unsigned NOT NULL,
  `oid_raw` varchar(255) NOT NULL,
  `oid` varchar(255) default NULL,
  `iid` varchar(255) default NULL,
  `val_raw` blob NOT NULL,
  `val` blob,
  PRIMARY KEY  (`id`),
  KEY `val` (`val`(8)),
  KEY `iid` (`iid`),
  KEY `trap` (`trap`)
) ENGINE=InnoDB AUTO_INCREMENT=2330480 DEFAULT CHARSET=latin1;

--
-- Table structure for table `traps`
--

DROP TABLE IF EXISTS `traps`;
CREATE TABLE `traps` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `captured` datetime NOT NULL,
  `device_name` varchar(255) NOT NULL,
  `ip_address` int(10) unsigned NOT NULL default '0',
  `oid` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `oid` (`oid`)
) ENGINE=InnoDB AUTO_INCREMENT=496594 DEFAULT CHARSET=latin1;

--
-- Table structure for table `user`
--

DROP TABLE IF EXISTS `user`;
CREATE TABLE `user` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `username` char(8) NOT NULL default '',
  `fullname` char(128) default NULL,
  `level` enum('0','1','3','6','9') NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `level` (`level`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;

--
-- Table structure for table `wifi_archive`
--

DROP TABLE IF EXISTS `wifi_archive`;
CREATE TABLE `wifi_archive` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` varchar(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `vlan` varchar(32) NOT NULL default '',
  `ap` varchar(16) NOT NULL default '',
  `username` varchar(64) NOT NULL default '',
  `encryption` varchar(8) NOT NULL default '',
  `radio` varchar(8) NOT NULL default '0',
  `ssid` varchar(32) NOT NULL default '',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `end` (`end`),
  KEY `host_end` (`host`,`end`)
) ENGINE=InnoDB AUTO_INCREMENT=2130286 DEFAULT CHARSET=latin1;

--
-- Table structure for table `wifi_capture`
--

DROP TABLE IF EXISTS `wifi_capture`;
CREATE TABLE `wifi_capture` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` varchar(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `vlan` varchar(32) NOT NULL default '',
  `ap` varchar(16) NOT NULL default '',
  `username` varchar(64) NOT NULL default '',
  `encryption` varchar(8) NOT NULL default '',
  `radio` varchar(8) NOT NULL default '0',
  `ssid` varchar(32) NOT NULL default '',
  `capture_id` int(10) unsigned NOT NULL default '0',
  `seen` enum('N','Y') NOT NULL default 'N',
  PRIMARY KEY  (`id`),
  KEY `capture_id` (`capture_id`)
) ENGINE=InnoDB AUTO_INCREMENT=247001 DEFAULT CHARSET=latin1;

--
-- Table structure for table `wifi_lastseen`
--

DROP TABLE IF EXISTS `wifi_lastseen`;
CREATE TABLE `wifi_lastseen` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `host` varchar(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `vlan` varchar(32) NOT NULL default '',
  `ap` varchar(16) NOT NULL default '',
  `username` varchar(64) NOT NULL default '',
  `encryption` varchar(8) NOT NULL default '',
  `radio` varchar(8) NOT NULL default '0',
  `ssid` varchar(32) NOT NULL default '',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `last_update` (`last_update`),
  KEY `host` (`host`,`ip_address`,`vlan`,`ap`,`username`)
) ENGINE=InnoDB AUTO_INCREMENT=1149673 DEFAULT CHARSET=latin1;

--
-- Table structure for table `wifi_tracking`
--

DROP TABLE IF EXISTS `wifi_tracking`;
CREATE TABLE `wifi_tracking` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `device` int(10) unsigned NOT NULL default '0',
  `host` varchar(12) NOT NULL default '',
  `ip_address` int(10) unsigned NOT NULL default '0',
  `vlan` varchar(32) NOT NULL default '',
  `ap` varchar(16) NOT NULL default '',
  `username` varchar(64) NOT NULL default '',
  `encryption` varchar(8) NOT NULL default '',
  `radio` varchar(8) NOT NULL default '0',
  `ssid` varchar(32) NOT NULL default '',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_update` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `device` (`device`),
  KEY `end` (`end`),
  KEY `host_end` (`host`,`end`)
) ENGINE=InnoDB AUTO_INCREMENT=2624468 DEFAULT CHARSET=latin1;

--
-- Table structure for table `wl_location`
--

DROP TABLE IF EXISTS `wl_location`;
CREATE TABLE `wl_location` (
  `version` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `id` int(10) unsigned NOT NULL auto_increment,
  `mac` char(12) NOT NULL default '',
  `user` char(16) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `mac` (`user`,`mac`),
  KEY `index_mac` (`mac`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Final view structure for view `trap_varbinds`
--

/*!50001 DROP TABLE IF EXISTS `trap_varbinds`*/;
/*!50001 DROP VIEW IF EXISTS `trap_varbinds`*/;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `trap_varbinds` AS select `t`.`id` AS `id`,`t`.`version` AS `version`,`t`.`trap` AS `trap`,coalesce(`t`.`oid`,`t`.`oid_raw`) AS `oid`,`t`.`iid` AS `iid`,coalesce(`t`.`val`,`t`.`val_raw`) AS `val`,coalesce(`m`.`label`,`t`.`oid`,`t`.`oid_raw`) AS `label` from (`trap_varbinds_raw` `t` left join `mibs` `m` on((`t`.`oid` = `m`.`oid`))) */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2009-03-30  2:16:49
