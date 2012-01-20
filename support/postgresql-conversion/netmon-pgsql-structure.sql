--
-- Generated from mysql2pgsql.perl
-- http://gborg.postgresql.org/project/mysql2psql/
-- (c) 2001 - 2007 Jose M. Duarte, Joseph Speigle
--

-- warnings are printed for drop tables if they do not exist
-- please see http://archives.postgresql.org/pgsql-novice/2004-10/msg00158.php

-- ##############################################################
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
-- MySQL dump 10.11
--
-- Host: localhost    Database: netmon
-- ------------------------------------------------------
-- Server version	5.0.45


--
-- Table structure for table _locks
--

DROP TABLE "_locks" CASCADE\g
DROP SEQUENCE "_locks_id_seq" CASCADE ;

CREATE SEQUENCE "_locks_id_seq" ;

CREATE TABLE  "_locks" (
   "id" integer DEFAULT nextval('"_locks_id_seq"') NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   "count"   int NOT NULL default '0', 
   primary key ("id"),
 unique ("name") 
)  ;

--
-- Table structure for table _sys_info
--

DROP TABLE "_sys_info" CASCADE\g
DROP SEQUENCE "_sys_info_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_info_id_seq" ;

CREATE TABLE  "_sys_info" (
   "id" integer DEFAULT nextval('"_sys_info_id_seq"') NOT NULL,
   "sys_key"   varchar(64) default NULL, 
   "sys_value"   varchar(128) NOT NULL default '', 
   "attime"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id"),
 unique ("sys_key") 
)  ;

--
-- Table structure for table arp_archive
--

DROP TABLE "arp_archive" CASCADE\g
DROP SEQUENCE "arp_archive_id_seq" CASCADE ;

CREATE SEQUENCE "arp_archive_id_seq"  ;

CREATE TABLE  "arp_archive" (
   "id" integer DEFAULT nextval('"arp_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "iid" int CHECK ("iid" >= 0) NOT NULL default '0',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;





--
-- Table structure for table arp_capture
--

DROP TABLE "arp_capture" CASCADE\g
DROP SEQUENCE "arp_capture_id_seq" CASCADE ;

CREATE SEQUENCE "arp_capture_id_seq"  ;

CREATE TABLE  "arp_capture" (
   "id" integer DEFAULT nextval('"arp_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "iid" int CHECK ("iid" >= 0) NOT NULL default '0',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   "interface"   varchar(255) NOT NULL default '', 
   primary key ("id")
)   ;


--
-- Table structure for table arp_capture_extra
--

DROP TABLE "arp_capture_extra" CASCADE\g
DROP SEQUENCE "arp_capture_extra_id_seq" CASCADE ;

CREATE SEQUENCE "arp_capture_extra_id_seq"  ;

CREATE TABLE  "arp_capture_extra" (
   "id" integer DEFAULT nextval('"arp_capture_extra_id_seq"') NOT NULL,
   "host"   macaddr,
   "ip_address" inet NOT NULL,
   "mode"   varchar(15) NOT NULL default '', 
   "extra_id" int CHECK ("extra_id" >= 0) NOT NULL default '0',
   primary key ("id")
)   ;




--
-- Table structure for table arp_lastseen
--

DROP TABLE "arp_lastseen" CASCADE\g
DROP SEQUENCE "arp_lastseen_id_seq" CASCADE ;

CREATE SEQUENCE "arp_lastseen_id_seq"  ;

CREATE TABLE  "arp_lastseen" (
   "id" integer DEFAULT nextval('"arp_lastseen_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id"),
 unique ("host", "ip_address") 
)   ;



--
-- Table structure for table arp_map
--

DROP TABLE "arp_map" CASCADE\g
DROP SEQUENCE "arp_map_id_seq" CASCADE ;

CREATE SEQUENCE "arp_map_id_seq" ;

CREATE TABLE  "arp_map" (
   "id" integer DEFAULT nextval('"arp_map_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "arp_track" int CHECK ("arp_track" >= 0) NOT NULL default '0',
   "interface" smallint CHECK ("interface" >= 0) NOT NULL default '0',
   primary key ("id"),
 unique ("device", "arp_track") 
)  ;


--
-- Table structure for table arp_tracking
--

DROP TABLE "arp_tracking" CASCADE\g
DROP SEQUENCE "arp_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "arp_tracking_id_seq"  ;

CREATE TABLE  "arp_tracking" (
   "id" integer DEFAULT nextval('"arp_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "iid" integer CHECK ("iid" >= 0) NOT NULL default '0',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone default '1970-01-01 00:00:00', 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;





--
-- Table structure for table arp_tracking_archive
--

DROP TABLE "arp_tracking_archive" CASCADE\g
CREATE TABLE  "arp_tracking_archive" (
   "id" int CHECK ("id" >= 0) NOT NULL default '0',
   "begin"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
 "spurious" varchar CHECK ("spurious" IN ( 'Y','N' )) NOT NULL default 'N',
 "unreg" varchar CHECK ("unreg" IN ( 'Y','N' )) NOT NULL default 'N',
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)  ;

--
-- Table structure for table cam_archive
--

DROP TABLE "cam_archive" CASCADE\g
DROP SEQUENCE "cam_archive_id_seq" CASCADE ;

CREATE SEQUENCE "cam_archive_id_seq"  ;

CREATE TABLE  "cam_archive" (
   "id" integer DEFAULT nextval('"cam_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "vlan" smallint CHECK ("vlan" >= 0) NOT NULL default '0',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;




--
-- Table structure for table cam_capture
--

DROP TABLE "cam_capture" CASCADE\g
DROP SEQUENCE "cam_capture_id_seq" CASCADE ;

CREATE SEQUENCE "cam_capture_id_seq"  ;

CREATE TABLE  "cam_capture" (
   "id" integer DEFAULT nextval('"cam_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "vlan" smallint CHECK ("vlan" >= 0) NOT NULL default '0',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   primary key ("id")
)   ;


--
-- Table structure for table cam_capture_extra
--

DROP TABLE "cam_capture_extra" CASCADE\g
DROP SEQUENCE "cam_capture_extra_id_seq" CASCADE ;

CREATE SEQUENCE "cam_capture_extra_id_seq"  ;

CREATE TABLE  "cam_capture_extra" (
   "id" integer DEFAULT nextval('"cam_capture_extra_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "extra_id" int CHECK ("extra_id" >= 0) NOT NULL default '0',
   primary key ("id")
)   ;



--
-- Table structure for table cam_lastseen
--

DROP TABLE "cam_lastseen" CASCADE\g
DROP SEQUENCE "cam_lastseen_id_seq" CASCADE ;

CREATE SEQUENCE "cam_lastseen_id_seq"  ;

CREATE TABLE  "cam_lastseen" (
   "id" integer DEFAULT nextval('"cam_lastseen_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "vlan" smallint CHECK ("vlan" >= 0) NOT NULL default '0',
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id"),
 unique ("host", "vlan") 
)   ;



--
-- Table structure for table cam_tracking
--

DROP TABLE "cam_tracking" CASCADE\g
DROP SEQUENCE "cam_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "cam_tracking_id_seq"  ;

CREATE TABLE  "cam_tracking" (
   "id" integer DEFAULT nextval('"cam_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "vlan" smallint CHECK ("vlan" >= 0) NOT NULL default '0',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone default NULL, 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;




--
-- Table structure for table cam_tracking_archive
--

DROP TABLE "cam_tracking_archive" CASCADE\g
DROP SEQUENCE "cam_tracking_archive_id_seq" CASCADE ;

CREATE SEQUENCE "cam_tracking_archive_id_seq" ;

CREATE TABLE  "cam_tracking_archive" (
   "id" integer DEFAULT nextval('"cam_tracking_archive_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "port" smallint CHECK ("port" >= 0) NOT NULL default '0',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
 "unregistered" varchar CHECK ("unregistered" IN ( 'Y','N' )) NOT NULL default 'Y',
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "vlan" smallint CHECK ("vlan" >= 0) NOT NULL default '0',
 "assumed_location" varchar CHECK ("assumed_location" IN ( 'Y','N' )) NOT NULL default 'Y',
   primary key ("id")
)  ;




--
-- Table structure for table capture_timings
--

DROP TABLE "capture_timings" CASCADE\g
DROP SEQUENCE "capture_timings_id_seq" CASCADE ;

CREATE SEQUENCE "capture_timings_id_seq"  ;

CREATE TABLE  "capture_timings" (
   "id" integer DEFAULT nextval('"capture_timings_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
 "capture_type" varchar CHECK ("capture_type" IN ( 'ARP','CAM','Ping','DevMAC','MCast','NetSage','Interface','Stalker','Routes','Topology','Ports','Device','Wifi', 'NDP' )) default NULL,
   "time"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "extra" int CHECK ("extra" >= 0) NOT NULL default '0',
   primary key ("id")
)   ;


--
-- Table structure for table device
--

DROP TABLE "device" CASCADE\g
DROP SEQUENCE "device_id_seq" CASCADE ;

CREATE SEQUENCE "device_id_seq"  ;

CREATE TABLE  "device" (
   "id" integer DEFAULT nextval('"device_id_seq"') NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   "read_comm"   varchar(255) NOT NULL default 'public', 
   "slow"  smallint CHECK ("slow" >= 0) NOT NULL default '0',
   "netreg_id" int CHECK ("netreg_id" >= 0) NOT NULL default '0',
   "function"   varchar(255) NOT NULL default '', 
   "system_id"   text, 
   "stamp"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
 "seen" varchar CHECK ("seen" IN ( 'y','n' )) NOT NULL default 'n',
 "snmp_version" varchar CHECK ("snmp_version" IN ( '1','2' )) NOT NULL default '2',
   primary key ("id"),
 unique ("name", "netreg_id") 
)   ;
 CREATE OR REPLACE FUNCTION update_device() RETURNS trigger AS '
BEGIN
    NEW.stamp := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_device BEFORE UPDATE ON "device" FOR EACH ROW EXECUTE PROCEDURE
update_device();


--
-- Table structure for table device_capture
--

DROP TABLE "device_capture" CASCADE\g
DROP SEQUENCE "device_capture_id_seq" CASCADE ;

CREATE SEQUENCE "device_capture_id_seq"  ;

CREATE TABLE  "device_capture" (
   "id" integer DEFAULT nextval('"device_capture_id_seq"') NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   "netreg_id" int CHECK ("netreg_id" >= 0) NOT NULL default '0',
   "function"   varchar(255) NOT NULL default '', 
   primary key ("id")
)   ;



--
-- Table structure for table device_interface
--

DROP TABLE "device_interface" CASCADE\g
DROP SEQUENCE "device_interface_id_seq" CASCADE ;

CREATE SEQUENCE "device_interface_id_seq" ;

CREATE TABLE  "device_interface" (
   "id" integer DEFAULT nextval('"device_interface_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "int_name"   varchar(255) NOT NULL default '', 
   "primary_ip" inet NOT NULL,
   "primary_netmask" inet NOT NULL,
   "mac_address"   macaddr NOT NULL,
   "secondary_ips"   text, 
   "interface_id" int CHECK ("interface_id" >= 0) NOT NULL default '0',
   "int_description"   varchar(255) NOT NULL default '', 
   primary key ("id"),
 unique ("device", "interface_id") 
)  ;
ALTER TABLE "device_interface" ADD FOREIGN KEY ("device") REFERENCES "device" ("id");

--
-- Table structure for table device_mac
--

DROP TABLE "device_mac" CASCADE\g
DROP SEQUENCE "device_mac_id_seq" CASCADE ;

CREATE SEQUENCE "device_mac_id_seq" ;

CREATE TABLE  "device_mac" (
   "id" integer DEFAULT nextval('"device_mac_id_seq"') NOT NULL,
   "device_id" int CHECK ("device_id" >= 0) NOT NULL default '0',
   "mac_address"   macaddr NOT NULL,
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id"),
 unique ("device_id", "mac_address") 
)  ;

ALTER TABLE "device_mac" ADD FOREIGN KEY ("device_id") REFERENCES "device" ("id");

--
-- Table structure for table device_port
--

DROP TABLE "device_port" CASCADE\g
DROP SEQUENCE "device_port_id_seq" CASCADE ;

CREATE SEQUENCE "device_port_id_seq" ;

CREATE TABLE  "device_port" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"device_port_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "name"   varchar(255) NOT NULL default '', 
   "port" int CHECK ("port" >= 0) NOT NULL default '0',
   "portmap"   varchar(255) NOT NULL default '', 
   "remote_ip" inet NOT NULL,
   "remote_port" int CHECK ("remote_port" >= 0) NOT NULL default '0',
   "last_update"   timestamp without time zone default NULL, 
 "type" varchar CHECK ("type" IN ( 'uplink','user','other' )) default NULL,
   primary key ("id")
)  ;
 CREATE OR REPLACE FUNCTION update_device_port() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_device_port BEFORE UPDATE ON "device_port" FOR EACH ROW EXECUTE PROCEDURE
update_device_port();




--
-- Table structure for table device_timings
--

DROP TABLE "device_timings" CASCADE\g
DROP SEQUENCE "device_timings_id_seq" CASCADE ;

CREATE SEQUENCE "device_timings_id_seq"  ;

CREATE TABLE  "device_timings" (
   "id" integer DEFAULT nextval('"device_timings_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "capture_type"   varchar(255) NOT NULL default '', 
   "last_begin"   timestamp without time zone default NULL,
   "last_end"   timestamp without time zone default NULL,
 "activate" varchar CHECK ("activate" IN ( 'Yes','No' )) NOT NULL default 'No',
   "upd_interval" int CHECK ("upd_interval" >= 0) NOT NULL default '3600',
   primary key ("id"),
 unique ("device", "capture_type") 
)   ;
ALTER TABLE "device_timings" ADD FOREIGN KEY ("device") REFERENCES "device" ("id");

--
-- Table structure for table device_timings_default
--

DROP TABLE "device_timings_default" CASCADE\g
DROP SEQUENCE "device_timings_default_id_seq" CASCADE ;

CREATE SEQUENCE "device_timings_default_id_seq"  ;

CREATE TABLE  "device_timings_default" (
   "id" integer DEFAULT nextval('"device_timings_default_id_seq"') NOT NULL,
   "device_type"   varchar(255) NOT NULL default '', 
   "capture_type"   varchar(255) NOT NULL default '', 
   "upd_interval" int CHECK ("upd_interval" >= 0) NOT NULL default '3600',
   primary key ("id"),
 unique ("device_type", "capture_type") 
)   ;

--
-- Table structure for table device_types
--

DROP TABLE "device_types" CASCADE\g
DROP SEQUENCE "device_types_id_seq" CASCADE ;

CREATE SEQUENCE "device_types_id_seq"  ;

CREATE TABLE  "device_types" (
   "id" integer DEFAULT nextval('"device_types_id_seq"') NOT NULL,
   "type"   varchar(255) NOT NULL default '', 
   "pattern"   varchar(255) NOT NULL default '', 
   "read_comm"   varchar(255) NOT NULL default 'public', 
   primary key ("id")
)   ;


--
-- Table structure for table device_uplink
--

DROP TABLE "device_uplink" CASCADE\g
DROP SEQUENCE "device_uplink_id_seq" CASCADE ;

CREATE SEQUENCE "device_uplink_id_seq" ;

CREATE TABLE  "device_uplink" (
   "id" integer DEFAULT nextval('"device_uplink_id_seq"') NOT NULL,
   "device_id" int CHECK ("device_id" >= 0) NOT NULL default '0',
   "port" smallint CHECK ("port" >= 0) NOT NULL default '0',
   "vlan" smallint CHECK ("vlan" >= 0) NOT NULL default '0',
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id"),
 unique ("device_id", "port", "vlan") 
)  ;
ALTER TABLE "device_uplink" ADD FOREIGN KEY ("device_id") REFERENCES "device" ("id");

--
-- Table structure for table device_vlan
--

DROP TABLE "device_vlan" CASCADE\g
DROP SEQUENCE "device_vlan_id_seq" CASCADE ;

CREATE SEQUENCE "device_vlan_id_seq" ;

CREATE TABLE  "device_vlan" (
   "id" integer DEFAULT nextval('"device_vlan_id_seq"') NOT NULL,
   "device_id" int CHECK ("device_id" >= 0) NOT NULL default '0',
   "vlan" int CHECK ("vlan" >= 0) NOT NULL default '0',
   "name"   varchar(255) default NULL, 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)  ;

ALTER TABLE "device_vlan" ADD FOREIGN KEY ("device_id") REFERENCES "device" ("id");

--
-- Table structure for table devmac_archive
--

DROP TABLE "devmac_archive" CASCADE\g
DROP SEQUENCE "devmac_archive_id_seq" CASCADE ;

CREATE SEQUENCE "devmac_archive_id_seq"  ;

CREATE TABLE  "devmac_archive" (
   "id" integer DEFAULT nextval('"devmac_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr,
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;




--
-- Table structure for table devmac_capture
--

DROP TABLE "devmac_capture" CASCADE\g
DROP SEQUENCE "devmac_capture_id_seq" CASCADE ;

CREATE SEQUENCE "devmac_capture_id_seq"  ;

CREATE TABLE  "devmac_capture" (
   "id" integer DEFAULT nextval('"devmac_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr,
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   primary key ("id")
)   ;


--
-- Table structure for table devmac_lastseen
--

DROP TABLE "devmac_lastseen" CASCADE\g
DROP SEQUENCE "devmac_lastseen_id_seq" CASCADE ;

CREATE SEQUENCE "devmac_lastseen_id_seq"  ;

CREATE TABLE  "devmac_lastseen" (
   "id" integer DEFAULT nextval('"devmac_lastseen_id_seq"') NOT NULL,
   "host"   macaddr,
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   primary key ("id")
)   ;



--
-- Table structure for table devmac_tracking
--

DROP TABLE "devmac_tracking" CASCADE\g
DROP SEQUENCE "devmac_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "devmac_tracking_id_seq"  ;

CREATE TABLE  "devmac_tracking" (
   "id" integer DEFAULT nextval('"devmac_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr,
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone default NULL,
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;




--
-- Table structure for table dhcp_fingerprints
--

DROP TABLE "dhcp_fingerprints" CASCADE\g
DROP SEQUENCE "dhcp_fingerprints_id_seq" CASCADE ;

CREATE SEQUENCE "dhcp_fingerprints_id_seq"  ;

CREATE TABLE  "dhcp_fingerprints" (
   "id" integer DEFAULT nextval('"dhcp_fingerprints_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "first"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "last"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "host"   varchar(12) NOT NULL default '', 
   "vcid"   varchar(64) NOT NULL default '', 
   "optlist"   varchar(128) NOT NULL default '', 
   "macprefix"   varchar(6) NOT NULL default '', 
   "cnt" int CHECK ("cnt" >= 0) NOT NULL default '0',
   primary key ("id"),
 unique ("optlist", "vcid", "macprefix", "host", "first") 
)   ;
 CREATE OR REPLACE FUNCTION update_dhcp_fingerprints() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dhcp_fingerprints BEFORE UPDATE ON "dhcp_fingerprints" FOR EACH ROW EXECUTE PROCEDURE
update_dhcp_fingerprints();


--
-- Table structure for table dhcp_fingerprints_lib
--

DROP TABLE "dhcp_fingerprints_lib" CASCADE\g
DROP SEQUENCE "dhcp_fingerprints_lib_id_seq" CASCADE ;

CREATE SEQUENCE "dhcp_fingerprints_lib_id_seq"  ;

CREATE TABLE  "dhcp_fingerprints_lib" (
   "id" integer DEFAULT nextval('"dhcp_fingerprints_lib_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "vcid"   varchar(64) NOT NULL default '', 
   "optlist"   varchar(128) NOT NULL default '', 
   "macprefix"   varchar(6) NOT NULL default '', 
   "category"   varchar(32) NOT NULL default '', 
   "os"   varchar(64) default NULL, 
   "bad"    smallint NOT NULL default '0', 
   primary key ("id")
)   ;
 CREATE OR REPLACE FUNCTION update_dhcp_fingerprints_lib() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dhcp_fingerprints_lib BEFORE UPDATE ON "dhcp_fingerprints_lib" FOR EACH ROW EXECUTE PROCEDURE
update_dhcp_fingerprints_lib();


--
-- Table structure for table dhcp_leases
--

DROP TABLE "dhcp_leases" CASCADE\g
DROP SEQUENCE "dhcp_leases_id_seq" CASCADE ;

CREATE SEQUENCE "dhcp_leases_id_seq"  ;

CREATE TABLE  "dhcp_leases" (
   "id" integer DEFAULT nextval('"dhcp_leases_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
 "type" varchar CHECK ("type" IN ( 'static','dynamic' )) NOT NULL default 'static',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "client_hostname"   varchar(64) default NULL, 
   "dhcp_server"   varchar(32) NOT NULL default '', 
   "circuit_id"   varchar(64) NOT NULL default '', 
   primary key ("id")
)   ;
 CREATE OR REPLACE FUNCTION update_dhcp_leases() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dhcp_leases BEFORE UPDATE ON "dhcp_leases" FOR EACH ROW EXECUTE PROCEDURE
update_dhcp_leases();





--
-- Table structure for table dhcp_leases_archive
--

DROP TABLE "dhcp_leases_archive" CASCADE\g
DROP SEQUENCE "dhcp_leases_archive_id_seq" CASCADE ;

CREATE SEQUENCE "dhcp_leases_archive_id_seq"  ;

CREATE TABLE  "dhcp_leases_archive" (
   "id" integer DEFAULT nextval('"dhcp_leases_archive_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
 "type" varchar CHECK ("type" IN ( 'static','dynamic' )) NOT NULL default 'static',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "client_hostname"   varchar(64) default NULL, 
   "dhcp_server"   varchar(32) NOT NULL default '', 
   "circuit_id"   varchar(64) NOT NULL default '', 
   primary key ("id")
)   ;
 CREATE OR REPLACE FUNCTION update_dhcp_leases_archive() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dhcp_leases_archive BEFORE UPDATE ON "dhcp_leases_archive" FOR EACH ROW EXECUTE PROCEDURE
update_dhcp_leases_archive();




--
-- Table structure for table group_info
--

DROP TABLE "group_info" CASCADE\g
DROP SEQUENCE "group_info_id_seq" CASCADE ;

CREATE SEQUENCE "group_info_id_seq" ;

CREATE TABLE  "group_info" (
   "id" integer DEFAULT nextval('"group_info_id_seq"') NOT NULL,
   "groupname"   varchar(8) NOT NULL default 'basic', 
   "description"   varchar(128) default NULL, 
   primary key ("id")
)  ;


--
-- Table structure for table group_timings
--

DROP TABLE "group_timings" CASCADE\g
DROP SEQUENCE "group_timings_id_seq" CASCADE ;

CREATE SEQUENCE "group_timings_id_seq" ;

CREATE TABLE  "group_timings" (
   "id" integer DEFAULT nextval('"group_timings_id_seq"') NOT NULL,
   "groupid" int CHECK ("groupid" >= 0) NOT NULL default '0',
 "capture_type" varchar CHECK ("capture_type" IN ( 'ARP','CAM','Ping','DevMAC','MCast','NetSage','Interface','Stalker' )) default NULL,
   "last_begin"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "last_end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
 "activate" varchar CHECK ("activate" IN ( 'Yes','No' )) NOT NULL default 'No',
   "upd_interval" smallint CHECK ("upd_interval" >= 0) NOT NULL default '3600',
   primary key ("id"),
 unique ("groupid", "capture_type") 
)  ;



--
-- Table structure for table groups
--

DROP TABLE "groups" CASCADE\g
DROP TABLE "groups_flags_constraint_table"  CASCADE\g
create table "groups_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "groups_flags_constraint_table"   values (  'abuse'  )\g
insert into "groups_flags_constraint_table"   values (  'suspend'  )\g
insert into "groups_flags_constraint_table"   values (  'purge_mailusers'  )\g
CREATE TABLE  "groups" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id"   int NOT NULL default '0', 
   "name"   varchar(32) NOT NULL default '', 
 flags varchar ,    "description"   varchar(64) NOT NULL default '', 
   "comment_lvl9"   varchar(64) NOT NULL default '', 
   "comment_lvl5"   varchar(64) NOT NULL default '', 
   primary key ("id"),
 unique ("name") 
)  ;
 CREATE OR REPLACE FUNCTION update_groups() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_groups BEFORE UPDATE ON "groups" FOR EACH ROW EXECUTE PROCEDURE
update_groups();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the groups_flags table
CREATE OR REPLACE FUNCTION check_groups_flags_set(  ) RETURNS TRIGGER AS $$

DECLARE	
----
arg_str VARCHAR ; 
argx VARCHAR := ''; 
nobreak INT := 1;
rec_count INT := 0;
str_in VARCHAR := NEW.flags;
----
BEGIN
----
IF str_in IS NULL THEN RETURN NEW ; END IF;
IF str_in = '' THEN RETURN NEW ; END IF;
arg_str := REGEXP_REPLACE(str_in, E'\',\'', ',');  -- str_in is CONSTANT
arg_str := REGEXP_REPLACE(arg_str, E'^\'', '');
arg_str := REGEXP_REPLACE(arg_str, E'\'$', '');

argx := substring(arg_str from '^[^,]*');
arg_str := substring(arg_str from ',(.*$)');

WHILE nobreak LOOP
--      RAISE NOTICE 'argx "%" arg_str "%"',argx,arg_str;
        EXECUTE 'SELECT count(*) FROM "groups_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
        IF rec_count = 0 THEN RAISE EXCEPTION 'Set value "%" was not found',argx;
        END IF;
        IF char_length(arg_str) > 0 THEN
                argx := substring(arg_str from '^[^,]*');
                arg_str := substring(arg_str from ',(.*$)');
        ELSE
                nobreak = 0;
        END IF;

END LOOP;
RETURN NEW;
----
END;
$$ LANGUAGE 'plpgsql' VOLATILE;

drop trigger set_test ON groups;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON groups   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_groups_flags_set();

--
-- Table structure for table groups_attrs
--

DROP TABLE "groups_attrs" CASCADE\g
DROP SEQUENCE "groups_attrs_id_seq" CASCADE ;

CREATE SEQUENCE "groups_attrs_id_seq" ;

CREATE TABLE  "groups_attrs" (
   "id" integer DEFAULT nextval('"groups_attrs_id_seq"') NOT NULL,
   "grp"   int NOT NULL default '0', 
   "name"   varchar(255) NOT NULL default '', 
   "data"   text, 
   primary key ("id")
)  ;



--
-- Table structure for table groups_cache
--

DROP TABLE "groups_cache" CASCADE\g
DROP SEQUENCE "groups_cache_id_seq" CASCADE ;

CREATE SEQUENCE "groups_cache_id_seq" ;

CREATE TABLE  "groups_cache" (
   "id" integer DEFAULT nextval('"groups_cache_id_seq"') NOT NULL,
   "grp" int CHECK ("grp" >= 0) NOT NULL default '0',
   "dev" int CHECK ("dev" >= 0) NOT NULL default '0',
   "stamp"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   primary key ("id")
)  ;
 CREATE OR REPLACE FUNCTION update_groups_cache() RETURNS trigger AS '
BEGIN
    NEW.stamp := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_groups_cache BEFORE UPDATE ON "groups_cache" FOR EACH ROW EXECUTE PROCEDURE
update_groups_cache();




--
-- Table structure for table groups_cache_old
--

DROP TABLE "groups_cache_old" CASCADE\g
DROP SEQUENCE "groups_cache_old_id_seq" CASCADE ;

CREATE SEQUENCE "groups_cache_old_id_seq" ;

CREATE TABLE  "groups_cache_old" (
   "id" integer DEFAULT nextval('"groups_cache_old_id_seq"') NOT NULL,
   "grp" int CHECK ("grp" >= 0) NOT NULL default '0',
   "dev" int CHECK ("dev" >= 0) NOT NULL default '0',
   "stamp"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   primary key ("id")
)  ;
 CREATE OR REPLACE FUNCTION update_groups_cache_old() RETURNS trigger AS '
BEGIN
    NEW.stamp := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_groups_cache_old BEFORE UPDATE ON "groups_cache_old" FOR EACH ROW EXECUTE PROCEDURE
update_groups_cache_old();




--
-- Table structure for table groups_rules
--

DROP TABLE "groups_rules" CASCADE\g
DROP SEQUENCE "groups_rules_id_seq" CASCADE ;

CREATE SEQUENCE "groups_rules_id_seq" ;

CREATE TABLE  "groups_rules" (
   "id" integer DEFAULT nextval('"groups_rules_id_seq"') NOT NULL,
   "grp"   int NOT NULL default '0', 
   "type"   varchar(255) default NULL, 
 "glue" varchar CHECK ("glue" IN ( 'AND','AND NOT','OR','OR NOT','NIL' )) NOT NULL default 'AND',
   "rule"   text, 
   "stamp"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   primary key ("id")
)  ;
 CREATE OR REPLACE FUNCTION update_groups_rules() RETURNS trigger AS '
BEGIN
    NEW.stamp := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_groups_rules BEFORE UPDATE ON "groups_rules" FOR EACH ROW EXECUTE PROCEDURE
update_groups_rules();



--
-- Table structure for table interface_capture
--

DROP TABLE "interface_capture" CASCADE\g
DROP SEQUENCE "interface_capture_id_seq" CASCADE ;

CREATE SEQUENCE "interface_capture_id_seq"  ;

CREATE TABLE  "interface_capture" (
   "id" integer DEFAULT nextval('"interface_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "port" int CHECK ("port" >= 0) NOT NULL default '0',
   "status"   int default '0', 
   "time"   timestamp without time zone default NULL, 
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "tag" varchar CHECK ("tag" IN ( 'Y','N' )) default NULL,
   primary key ("id")
)   ;

ALTER TABLE "interface_capture" ADD FOREIGN KEY ("device") REFERENCES "device" ("id");

--
-- Table structure for table interface_process
--

DROP TABLE "interface_process" CASCADE\g
DROP SEQUENCE "interface_process_id_seq" CASCADE ;

CREATE SEQUENCE "interface_process_id_seq"  ;

CREATE TABLE  "interface_process" (
   "id" integer DEFAULT nextval('"interface_process_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "port" int CHECK ("port" >= 0) NOT NULL default '0',
   "status"   int default '0', 
   "good"    smallint default '0', 
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone default NULL, 
   primary key ("id"),
 unique ("device", "port", "start", "end", "status") ,
 unique ("device", "port", "start", "status") 
)   ;





--
-- Table structure for table landb
--

DROP TABLE "landb" CASCADE\g
CREATE TABLE  "landb" (
   "switch"   varchar(64) default NULL, 
   "iid"   varchar(8) default NULL 
)  ;

--
-- Table structure for table mcast_capture
--

DROP TABLE "mcast_capture" CASCADE\g
DROP SEQUENCE "mcast_capture_id_seq" CASCADE ;

CREATE SEQUENCE "mcast_capture_id_seq" ;

CREATE TABLE  "mcast_capture" (
   "id" integer DEFAULT nextval('"mcast_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "mgroup" int CHECK ("mgroup" >= 0) NOT NULL default '0',
   "source" int CHECK ("source" >= 0) NOT NULL default '0',
   "netmask" int CHECK ("netmask" >= 0) NOT NULL default '0',
   "usneighbor" int CHECK ("usneighbor" >= 0) NOT NULL default '0',
   "int_in"   int NOT NULL default '0', 
   "time"   timestamp without time zone default NULL, 
   primary key ("id")
)  ;


--
-- Table structure for table mcast_capture_dsn
--

DROP TABLE "mcast_capture_dsn" CASCADE\g
DROP SEQUENCE "mcast_capture_dsn_id_seq" CASCADE ;

CREATE SEQUENCE "mcast_capture_dsn_id_seq" ;

CREATE TABLE  "mcast_capture_dsn" (
   "id" integer DEFAULT nextval('"mcast_capture_dsn_id_seq"') NOT NULL,
   "parent" int CHECK ("parent" >= 0) NOT NULL default '0',
   "int_out"   int NOT NULL default '0', 
   "num_hops"   int default NULL, 
   "time"   timestamp without time zone default NULL, 
   primary key ("id")
)  ;


--
-- Table structure for table membership
--

DROP TABLE "membership" CASCADE\g
DROP SEQUENCE "membership_id_seq" CASCADE ;

CREATE SEQUENCE "membership_id_seq" ;

CREATE TABLE  "membership" (
   "id" integer DEFAULT nextval('"membership_id_seq"') NOT NULL,
 "level" varchar CHECK ("level" IN ( '0','1','2','3','4','5','6','7','8','9' )) NOT NULL default '0',
   "uid" int CHECK ("uid" >= 0) NOT NULL default '0',
   "gid" int CHECK ("gid" >= 0) NOT NULL default '0',
   primary key ("id")
)  ;



--
-- Table structure for table mibs
--

DROP TABLE "mibs" CASCADE\g
DROP SEQUENCE "mibs_id_seq" CASCADE ;

CREATE SEQUENCE "mibs_id_seq"  ;

CREATE TABLE  "mibs" (
   "id" integer DEFAULT nextval('"mibs_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "oid"   varchar(255) NOT NULL, 
   "label"   varchar(64) NOT NULL, 
   "leaf"    smallint NOT NULL default '0', 
   "keep"    smallint NOT NULL default '0', 
   "syntax"   varchar(32) default NULL, 
   primary key ("id"),
 unique ("oid") 
)   ;
 CREATE OR REPLACE FUNCTION update_mibs() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_mibs BEFORE UPDATE ON "mibs" FOR EACH ROW EXECUTE PROCEDURE
update_mibs();

--
-- Table structure for table ports_archive
--

DROP TABLE "ports_archive" CASCADE\g
DROP SEQUENCE "ports_archive_id_seq" CASCADE ;

CREATE SEQUENCE "ports_archive_id_seq"  ;

CREATE TABLE  "ports_archive" (
   "id" integer DEFAULT nextval('"ports_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "port"   varchar(255) NOT NULL default '', 
   "type"   varchar(255) NOT NULL default '', 
   "mac"   macaddr,
   "name"   varchar(255) NOT NULL default '', 
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;



--
-- Table structure for table ports_capture
--

DROP TABLE "ports_capture" CASCADE\g
DROP SEQUENCE "ports_capture_id_seq" CASCADE ;

CREATE SEQUENCE "ports_capture_id_seq"  ;

CREATE TABLE  "ports_capture" (
   "id" integer DEFAULT nextval('"ports_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "port"   varchar(255) NOT NULL default '', 
   "type"   varchar(255) NOT NULL default '', 
   "mac"   macaddr NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   primary key ("id")
)   ;


--
-- Table structure for table ports_tracking
--

DROP TABLE "ports_tracking" CASCADE\g
DROP SEQUENCE "ports_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "ports_tracking_id_seq"  ;

CREATE TABLE  "ports_tracking" (
   "id" integer DEFAULT nextval('"ports_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "iid" smallint CHECK ("iid" >= 0) NOT NULL default '0',
   "port"   varchar(255) NOT NULL default '', 
   "type"   varchar(255) NOT NULL default '', 
   "mac"   macaddr,
   "name"   varchar(255) NOT NULL default '', 
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone default NULL, 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;



--
-- Table structure for table routes_archive
--

DROP TABLE "routes_archive" CASCADE\g
DROP SEQUENCE "routes_archive_id_seq" CASCADE ;

CREATE SEQUENCE "routes_archive_id_seq" ;

CREATE TABLE  "routes_archive" (
   "id" integer DEFAULT nextval('"routes_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
 "known" varchar CHECK ("known" IN ( 'unknown','found','known' )) NOT NULL default 'unknown',
   "netregid" int CHECK ("netregid" >= 0) NOT NULL default '0',
   "route" inet NOT NULL,
   "mask" inet NOT NULL,
   "gateway" inet NOT NULL,
   "type"   varchar(5) NOT NULL default '', 
   "interface"   varchar(255) NOT NULL default '', 
   "distance"  smallint CHECK ("distance" >= 0) NOT NULL default '0',
   "metric"  smallint CHECK ("metric" >= 0) NOT NULL default '0',
   "source" int CHECK ("source" >= 0) NOT NULL default '0',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)  ;




--
-- Table structure for table routes_capture
--

DROP TABLE "routes_capture" CASCADE\g
DROP SEQUENCE "routes_capture_id_seq" CASCADE ;

CREATE SEQUENCE "routes_capture_id_seq" ;

CREATE TABLE  "routes_capture" (
   "id" integer DEFAULT nextval('"routes_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
 "known" varchar CHECK ("known" IN ( 'unknown','found','known' )) NOT NULL default 'unknown',
   "netregid" int CHECK ("netregid" >= 0) NOT NULL default '0',
   "route" inet NOT NULL,
   "mask" inet NOT NULL,
   "gateway" inet NOT NULL,
   "type"   varchar(5) NOT NULL default '', 
   "interface"   varchar(255) NOT NULL default '', 
   "distance"  smallint CHECK ("distance" >= 0) NOT NULL default '0',
   "metric"  smallint CHECK ("metric" >= 0) NOT NULL default '0',
   "source" int CHECK ("source" >= 0) NOT NULL default '0',
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   "idx" smallint CHECK ("idx" >= 0) NOT NULL default '0',
   primary key ("id")
)  ;




--
-- Table structure for table routes_capture_extra
--

DROP TABLE "routes_capture_extra" CASCADE\g
DROP SEQUENCE "routes_capture_extra_id_seq" CASCADE ;

CREATE SEQUENCE "routes_capture_extra_id_seq"  ;

CREATE TABLE  "routes_capture_extra" (
   "id" integer DEFAULT nextval('"routes_capture_extra_id_seq"') NOT NULL,
   "base" cidr NOT NULL,
   "subid" int CHECK ("subid" >= 0) NOT NULL default '0',
   "extra_id" int CHECK ("extra_id" >= 0) NOT NULL default '0',
   "idx" int CHECK ("idx" >= 0) NOT NULL default '0',
   primary key ("id")
)   ;


--
-- Table structure for table routes_tracking
--

DROP TABLE "routes_tracking" CASCADE\g
DROP SEQUENCE "routes_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "routes_tracking_id_seq" ;

CREATE TABLE  "routes_tracking" (
   "id" integer DEFAULT nextval('"routes_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
 "known" varchar CHECK ("known" IN ( 'unknown','found','known' )) NOT NULL default 'unknown',
   "netregid" int CHECK ("netregid" >= 0) NOT NULL default '0',
   "route" inet NOT NULL,
   "mask" inet NOT NULL,
   "gateway" inet NOT NULL,
   "type"   varchar(5) NOT NULL default '', 
   "interface"   varchar(255) NOT NULL default '', 
   "distance"  smallint CHECK ("distance" >= 0) NOT NULL default '0',
   "metric"  smallint CHECK ("metric" >= 0) NOT NULL default '0',
   "source" int CHECK ("source" >= 0) NOT NULL default '0',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)  ;




--
-- Table structure for table stalk_capture
--

DROP TABLE "stalk_capture" CASCADE\g
DROP SEQUENCE "stalk_capture_id_seq" CASCADE ;

CREATE SEQUENCE "stalk_capture_id_seq" ;

CREATE TABLE  "stalk_capture" (
   "id" integer DEFAULT nextval('"stalk_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "mac"   macaddr NOT NULL,
   "snr"   int NOT NULL default '0', 
   "time"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
 "delete_me" varchar CHECK ("delete_me" IN ( 'Y','N0','N' )) NOT NULL default 'N',
   primary key ("id")
)  ;


--
-- Table structure for table stalk_tracking
--

DROP TABLE "stalk_tracking" CASCADE\g
DROP SEQUENCE "stalk_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "stalk_tracking_id_seq" ;

CREATE TABLE  "stalk_tracking" (
   "id" integer DEFAULT nextval('"stalk_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "mac"   macaddr NOT NULL,
   "snr"   int NOT NULL default '0', 
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
 "assumed_location" varchar CHECK ("assumed_location" IN ( 'Y','N' )) NOT NULL default 'Y',
   primary key ("id")
)  ;




--
-- Table structure for table stalk_tracking_archive
--

DROP TABLE "stalk_tracking_archive" CASCADE\g
DROP SEQUENCE "stalk_tracking_archive_id_seq" CASCADE ;

CREATE SEQUENCE "stalk_tracking_archive_id_seq" ;

CREATE TABLE  "stalk_tracking_archive" (
   "id" integer DEFAULT nextval('"stalk_tracking_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "mac"   macaddr NOT NULL,
   "snr"   int NOT NULL default '0', 
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
 "assumed_location" varchar CHECK ("assumed_location" IN ( 'Y','N' )) NOT NULL default 'Y',
   primary key ("id")
)  ;




--
-- Table structure for table stalker_archive
--

DROP TABLE "stalker_archive" CASCADE\g
DROP SEQUENCE "stalker_archive_id_seq" CASCADE ;

CREATE SEQUENCE "stalker_archive_id_seq" ;

CREATE TABLE  "stalker_archive" (
   "id" integer DEFAULT nextval('"stalker_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "snr"   float NOT NULL default '0', 
   "snr_min"  smallint CHECK ("snr_min" >= 0) NOT NULL default '0',
   "snr_max"  smallint CHECK ("snr_max" >= 0) NOT NULL default '0',
   "count" smallint CHECK ("count" >= 0) NOT NULL default '1',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)  ;




--
-- Table structure for table stalker_capture
--

DROP TABLE "stalker_capture" CASCADE\g
DROP SEQUENCE "stalker_capture_id_seq" CASCADE ;

CREATE SEQUENCE "stalker_capture_id_seq" ;

CREATE TABLE  "stalker_capture" (
   "id" integer DEFAULT nextval('"stalker_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "snr"  smallint CHECK ("snr" >= 0) NOT NULL default '0',
   "snr_min"  smallint CHECK ("snr_min" >= 0) NOT NULL default '0',
   "snr_max"  smallint CHECK ("snr_max" >= 0) NOT NULL default '0',
   "count" smallint CHECK ("count" >= 0) NOT NULL default '1',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   primary key ("id")
)  ;


--
-- Table structure for table stalker_capture_extra
--

DROP TABLE "stalker_capture_extra" CASCADE\g
DROP SEQUENCE "stalker_capture_extra_id_seq" CASCADE ;

CREATE SEQUENCE "stalker_capture_extra_id_seq" ;

CREATE TABLE  "stalker_capture_extra" (
   "id" integer DEFAULT nextval('"stalker_capture_extra_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "extra_id" int CHECK ("extra_id" >= 0) NOT NULL default '0',
   primary key ("id")
)  ;



--
-- Table structure for table stalker_lastseen
--

DROP TABLE "stalker_lastseen" CASCADE\g
DROP SEQUENCE "stalker_lastseen_id_seq" CASCADE ;

CREATE SEQUENCE "stalker_lastseen_id_seq" ;

CREATE TABLE  "stalker_lastseen" (
   "id" integer DEFAULT nextval('"stalker_lastseen_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)  ;



--
-- Table structure for table stalker_tracking
--

DROP TABLE "stalker_tracking" CASCADE\g
DROP SEQUENCE "stalker_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "stalker_tracking_id_seq" ;

CREATE TABLE  "stalker_tracking" (
   "id" integer DEFAULT nextval('"stalker_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "snr"   float NOT NULL default '0', 
   "snr_min"  smallint CHECK ("snr_min" >= 0) NOT NULL default '0',
   "snr_max"  smallint CHECK ("snr_max" >= 0) NOT NULL default '0',
   "count" smallint CHECK ("count" >= 0) NOT NULL default '1',
 "registered" varchar CHECK ("registered" IN ( 'N','Y' )) NOT NULL default 'N',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)  ;




--
-- Table structure for table topology
--

DROP TABLE "topology" CASCADE\g
DROP SEQUENCE "topology_id_seq" CASCADE ;

CREATE SEQUENCE "topology_id_seq" ;

CREATE TABLE  "topology" (
   "id" integer DEFAULT nextval('"topology_id_seq"') NOT NULL,
   "device_parent" int CHECK ("device_parent" >= 0) NOT NULL default '0',
   "device_child" int CHECK ("device_child" >= 0) NOT NULL default '0',
   "time"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "parent_vlan" smallint CHECK ("parent_vlan" >= 0) NOT NULL default '0',
   "child_vlan" smallint CHECK ("child_vlan" >= 0) NOT NULL default '0',
 "relationship" varchar CHECK ("relationship" IN ( 'L3toL2','L2toL2' )) NOT NULL default 'L2toL2',
   "parent_int" smallint CHECK ("parent_int" >= 0) NOT NULL default '0',
   "child_int" smallint CHECK ("child_int" >= 0) NOT NULL default '0',
 "type" varchar CHECK ("type" IN ( 'v1','v2-s3a' )) NOT NULL default 'v1',
   primary key ("id"),
 unique ("device_parent", "parent_vlan", "device_child") 
)  ;



--
-- Table structure for table topology_staging
--

DROP TABLE "topology_staging" CASCADE\g
CREATE TABLE  "topology_staging" (
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   varchar(12) NOT NULL default '', 
   "port" int CHECK ("port" >= 0) NOT NULL default '0',
   "vlan" smallint CHECK ("vlan" >= 0) NOT NULL default '0',
   primary key ("device", "host", "port", "vlan")
)  ;

--
-- Table structure for table topology_staging_arp
--

DROP TABLE "topology_staging_arp" CASCADE\g
CREATE TABLE  "topology_staging_arp" (
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "interface"   smallint NOT NULL default '0', 
   primary key ("device", "host", "ip_address", "interface")
)  ;

--
-- Table structure for table topology_tree
--

DROP TABLE "topology_tree" CASCADE\g
DROP SEQUENCE "topology_tree_id_seq" CASCADE ;

CREATE SEQUENCE "topology_tree_id_seq" ;

CREATE TABLE  "topology_tree" (
   "id" integer DEFAULT nextval('"topology_tree_id_seq"') NOT NULL,
   "device"   varchar(255) NOT NULL default '', 
   "display"   varchar(255) NOT NULL default '', 
   "parent" int CHECK ("parent" >= 0) NOT NULL default '0',
   primary key ("id")
)  ;


--
-- Table structure for table trap_varbinds_raw
--

DROP TABLE "trap_varbinds_raw" CASCADE\g
DROP SEQUENCE "trap_varbinds_raw_id_seq" CASCADE ;

CREATE SEQUENCE "trap_varbinds_raw_id_seq"  ;

CREATE TABLE  "trap_varbinds_raw" (
   "id" integer DEFAULT nextval('"trap_varbinds_raw_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "trap" int CHECK ("trap" >= 0) NOT NULL,
   "oid_raw"   varchar(255) NOT NULL, 
   "oid"   varchar(255) default NULL, 
   "iid"   varchar(255) default NULL, 
   "val_raw"   bytea NOT NULL, 
   "val"   bytea, 
   primary key ("id")
)   ;
 CREATE OR REPLACE FUNCTION update_trap_varbinds_raw() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_trap_varbinds_raw BEFORE UPDATE ON "trap_varbinds_raw" FOR EACH ROW EXECUTE PROCEDURE
update_trap_varbinds_raw();


DROP VIEW trap_varbinds;

CREATE VIEW trap_varbinds AS
  SELECT t.id AS id,
         t.version AS version,
         t.trap AS trap,
         coalesce(t.oid,t.oid_raw) AS oid,
         t.iid AS iid,coalesce(t.val, t.val_raw) AS val,
         coalesce(m.label,t.oid,t.oid_raw) AS label
  FROM (trap_varbinds_raw t left join mibs m ON((t.oid = m.oid)));

--
-- Table structure for table traps
--

DROP TABLE "traps" CASCADE\g
DROP SEQUENCE "traps_id_seq" CASCADE ;

CREATE SEQUENCE "traps_id_seq"  ;

CREATE TABLE  "traps" (
   "id" integer DEFAULT nextval('"traps_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "captured"   timestamp without time zone NOT NULL, 
   "device_name"   varchar(255) NOT NULL, 
   "ip_address" inet NOT NULL,
   "oid"   varchar(255) NOT NULL, 
   primary key ("id")
)   ;
 CREATE OR REPLACE FUNCTION update_traps() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_traps BEFORE UPDATE ON "traps" FOR EACH ROW EXECUTE PROCEDURE
update_traps();


--
-- Table structure for table user
--

DROP TABLE "user" CASCADE\g
DROP SEQUENCE "user_id_seq" CASCADE ;

CREATE SEQUENCE "user_id_seq"  ;

CREATE TABLE  "user" (
   "id" integer DEFAULT nextval('"user_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "username"   varchar(8) NOT NULL default '', 
   "fullname"   varchar(128) default NULL, 
 "level" varchar CHECK ("level" IN ( '0','1','3','6','9' )) NOT NULL default '0',
   primary key ("id"),
 unique ("username") 
)   ;
 CREATE OR REPLACE FUNCTION update_user() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_user BEFORE UPDATE ON "user" FOR EACH ROW EXECUTE PROCEDURE
update_user();


--
-- Table structure for table wifi_archive
--

DROP TABLE "wifi_archive" CASCADE\g
DROP SEQUENCE "wifi_archive_id_seq" CASCADE ;

CREATE SEQUENCE "wifi_archive_id_seq"  ;

CREATE TABLE  "wifi_archive" (
   "id" integer DEFAULT nextval('"wifi_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "vlan"   varchar(32) NOT NULL default '', 
   "ap"   varchar(16) NOT NULL default '', 
   "username"   varchar(64) NOT NULL default '', 
   "encryption"   varchar(8) NOT NULL default '', 
   "radio"   varchar(8) NOT NULL default '0', 
   "ssid"   varchar(32) NOT NULL default '', 
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;




--
-- Table structure for table wifi_capture
--

DROP TABLE "wifi_capture" CASCADE\g
DROP SEQUENCE "wifi_capture_id_seq" CASCADE ;

CREATE SEQUENCE "wifi_capture_id_seq"  ;

CREATE TABLE  "wifi_capture" (
   "id" integer DEFAULT nextval('"wifi_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "vlan"   varchar(32) NOT NULL default '', 
   "ap"   varchar(16) NOT NULL default '', 
   "username"   varchar(64) NOT NULL default '', 
   "encryption"   varchar(8) NOT NULL default '', 
   "radio"   varchar(8) NOT NULL default '0', 
   "ssid"   varchar(32) NOT NULL default '', 
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
 "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   primary key ("id")
)   ;


--
-- Table structure for table wifi_lastseen
--

DROP TABLE "wifi_lastseen" CASCADE\g
DROP SEQUENCE "wifi_lastseen_id_seq" CASCADE ;

CREATE SEQUENCE "wifi_lastseen_id_seq"  ;

CREATE TABLE  "wifi_lastseen" (
   "id" integer DEFAULT nextval('"wifi_lastseen_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "vlan"   varchar(32) NOT NULL default '', 
   "ap"   varchar(16) NOT NULL default '', 
   "username"   varchar(64) NOT NULL default '', 
   "encryption"   varchar(8) NOT NULL default '', 
   "radio"   varchar(8) NOT NULL default '0', 
   "ssid"   varchar(32) NOT NULL default '', 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;



--
-- Table structure for table wifi_tracking
--

DROP TABLE "wifi_tracking" CASCADE\g
DROP SEQUENCE "wifi_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "wifi_tracking_id_seq"  ;

CREATE TABLE  "wifi_tracking" (
   "id" integer DEFAULT nextval('"wifi_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip_address" inet NOT NULL,
   "vlan"   varchar(32) NOT NULL default '', 
   "ap"   varchar(16) NOT NULL default '', 
   "username"   varchar(64) NOT NULL default '', 
   "encryption"   varchar(8) NOT NULL default '', 
   "radio"   varchar(8) NOT NULL default '0', 
   "ssid"   varchar(32) NOT NULL default '', 
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone default NULL, 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;




--
-- Table structure for table wl_location
--

DROP TABLE "wl_location" CASCADE\g
DROP SEQUENCE "wl_location_id_seq" CASCADE ;

CREATE SEQUENCE "wl_location_id_seq" ;

CREATE TABLE  "wl_location" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"wl_location_id_seq"') NOT NULL,
   "mac"   macaddr NOT NULL,
   "user"   varchar(16) NOT NULL default '', 
   primary key ("id"),
 unique ("user", "mac") 
)  ;
 CREATE OR REPLACE FUNCTION update_wl_location() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_wl_location BEFORE UPDATE ON "wl_location" FOR EACH ROW EXECUTE PROCEDURE
update_wl_location();

--
-- Table structure for table ndp_archive
--

DROP TABLE "ndp_archive" CASCADE\g
DROP SEQUENCE "ndp_archive_id_seq" CASCADE ;

CREATE SEQUENCE "ndp_archive_id_seq";

CREATE TABLE  "ndp_archive" (
   "id" integer DEFAULT nextval('"ndp_archive_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip6_address" inet NOT NULL,
   "iid" int CHECK ("iid" >= 0) NOT NULL default '0',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;

--
-- Table structure for table ndp_capture
--

DROP TABLE "ndp_capture" CASCADE\g
DROP SEQUENCE "ndp_capture_id_seq" CASCADE ;

CREATE SEQUENCE "ndp_capture_id_seq"  ;

CREATE TABLE  "ndp_capture" (
   "id" integer DEFAULT nextval('"ndp_capture_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip6_address" inet NOT NULL,
   "iid" int CHECK ("iid" >= 0) NOT NULL default '0',
   "capture_id" int CHECK ("capture_id" >= 0) NOT NULL default '0',
   "seen" varchar CHECK ("seen" IN ( 'N','Y' )) NOT NULL default 'N',
   primary key ("id")
)   ;

--
-- Table structure for table ndp_lastseen
--

DROP TABLE "ndp_lastseen" CASCADE\g
DROP SEQUENCE "ndp_lastseen_id_seq" CASCADE ;

CREATE SEQUENCE "ndp_lastseen_id_seq"  ;

CREATE TABLE  "ndp_lastseen" (
   "id" integer DEFAULT nextval('"ndp_lastseen_id_seq"') NOT NULL,
   "host"   macaddr NOT NULL,
   "ip6_address" inet NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "iid" int CHECK ("iid" >= 0) NOT NULL default '0',
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id"),
 unique ("host", "ip6_address", "iid", "device") 
)   ;

--
-- Table structure for table ndp_tracking
--

DROP TABLE "ndp_tracking" CASCADE\g
DROP SEQUENCE "ndp_tracking_id_seq" CASCADE ;

CREATE SEQUENCE "ndp_tracking_id_seq"  ;

CREATE TABLE  "ndp_tracking" (
   "id" integer DEFAULT nextval('"ndp_tracking_id_seq"') NOT NULL,
   "device" int CHECK ("device" >= 0) NOT NULL default '0',
   "host"   macaddr NOT NULL,
   "ip6_address" inet NOT NULL,
   "iid" integer CHECK ("iid" >= 0) NOT NULL default '0',
   "start"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "end"   timestamp without time zone default '1970-01-01 00:00:00', 
   "last_update"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   primary key ("id")
)   ;

/*!50001 DROP VIEW IF EXISTS trap_varbinds*/;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=root@localhost SQL SECURITY DEFINER */
/*!50001 VIEW trap_varbinds AS select t.id AS id,t.version AS version,t.trap AS trap,coalesce(t.oid,t.oid_raw) AS oid,t.iid AS iid,coalesce(t.val,t.val_raw) AS val,coalesce(m.label,t.oid,t.oid_raw) AS label from (trap_varbinds_raw t left join mibs m on((t.oid = m.oid))) */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

