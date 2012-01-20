e-
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
-- Host: localhost    Database: netdb
-- ------------------------------------------------------
-- Server version	5.0.45

--
-- Simulate the MySQL find_in_set function.  Inefficient, but 
-- requires a lot less re-coding.
--

CREATE OR REPLACE FUNCTION find_in_set(str text, strlist text)
RETURNS boolean AS $$
SELECT true
   FROM generate_subscripts(string_to_array($2,','),1) g(i)
  WHERE (string_to_array($2, ','))[i] = $1
  UNION ALL
  SELECT false
  LIMIT 1
$$ LANGUAGE sql STRICT;

--
-- Table structure for table _sys_changelog
--

DROP TABLE "_sys_changelog" CASCADE\g
DROP SEQUENCE "_sys_changelog_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_changelog_id_seq" ;

CREATE TABLE  "_sys_changelog" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"_sys_changelog_id_seq"') NOT NULL,
   "user" int CHECK ("user" >= 0) NOT NULL default '0',
   "name"   varchar(16) NOT NULL default '', 
   "time"   timestamp without time zone default NULL, 
   "info"   varchar(255) NOT NULL default '', 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update__sys_changelog() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to__sys_changelog BEFORE UPDATE ON "_sys_changelog" FOR EACH ROW EXECUTE PROCEDURE
update__sys_changelog();




--
-- Table structure for table _sys_changerec_col
--

DROP TABLE "_sys_changerec_col" CASCADE\g
DROP SEQUENCE "_sys_changerec_col_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_changerec_col_id_seq" ;

CREATE TABLE  "_sys_changerec_col" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"_sys_changerec_col_id_seq"') NOT NULL,
   "changerec_row" int CHECK ("changerec_row" >= 0) NOT NULL default '0',
   "name"   varchar(255) NOT NULL default '', 
   "data"   text, 
   "previous"   text, 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update__sys_changerec_col() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to__sys_changerec_col BEFORE UPDATE ON "_sys_changerec_col" FOR EACH ROW EXECUTE PROCEDURE
update__sys_changerec_col();


--
-- Table structure for table _sys_changerec_row
--

DROP TABLE "_sys_changerec_row" CASCADE\g
DROP SEQUENCE "_sys_changerec_row_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_changerec_row_id_seq" ;

CREATE TABLE  "_sys_changerec_row" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"_sys_changerec_row_id_seq"') NOT NULL,
   "changelog" int CHECK ("changelog" >= 0) NOT NULL default '0',
   "tname"   varchar(255) NOT NULL default '', 
   "row" int CHECK ("row" >= 0) NOT NULL default '0',
 "type" varchar CHECK ("type" IN ( 'INSERT','UPDATE','DELETE' )) NOT NULL default 'INSERT',
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update__sys_changerec_row() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to__sys_changerec_row BEFORE UPDATE ON "_sys_changerec_row" FOR EACH ROW EXECUTE PROCEDURE
update__sys_changerec_row();



--
-- Table structure for table _sys_dberror
--

DROP TABLE "_sys_dberror" CASCADE\g
DROP SEQUENCE "_sys_dberror_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_dberror_id_seq" ;

CREATE TABLE  "_sys_dberror" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"_sys_dberror_id_seq"') NOT NULL,
 "tname" varchar CHECK ("tname" IN ( 'users','groups','building','cable','outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence','subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource','dns_zone' )) NOT NULL default 'users',
   "tid" int CHECK ("tid" >= 0) NOT NULL default '0',
   "errfields"   varchar(255) NOT NULL default '', 
 "severity" varchar CHECK ("severity" IN ( 'EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTICE','INFO' )) NOT NULL default 'ERROR',
   "errtype" int CHECK ("errtype" >= 0) NOT NULL default '0',
 "fixed" varchar CHECK ("fixed" IN ( 'UNFIXED','FIXED' )) NOT NULL default 'UNFIXED',
   "comment"   text, 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update__sys_dberror() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to__sys_dberror BEFORE UPDATE ON "_sys_dberror" FOR EACH ROW EXECUTE PROCEDURE
update__sys_dberror();

--
-- Table structure for table _sys_errors
--

DROP TABLE "_sys_errors" CASCADE\g
DROP SEQUENCE "_sys_errors_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_errors_id_seq" ;

CREATE TABLE  "_sys_errors" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"_sys_errors_id_seq"') NOT NULL,
   "errcode"   smallint NOT NULL default '0', 
   "location"   varchar(64) NOT NULL default '', 
   "errfields"   varchar(255) NOT NULL default '', 
   "errtext"   text NOT NULL, 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update__sys_errors() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to__sys_errors BEFORE UPDATE ON "_sys_errors" FOR EACH ROW EXECUTE PROCEDURE
update__sys_errors();


--
-- Table structure for table _sys_info
--

DROP TABLE "_sys_info" CASCADE\g
DROP SEQUENCE "_sys_info_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_info_id_seq" ;

CREATE TABLE  "_sys_info" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"_sys_info_id_seq"') NOT NULL,
   "sys_key"   varchar(16) NOT NULL default '', 
   "sys_value"   varchar(128) NOT NULL default '', 
   primary key ("id"),
 unique ("sys_key") 
);
 CREATE OR REPLACE FUNCTION update__sys_info() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to__sys_info BEFORE UPDATE ON "_sys_info" FOR EACH ROW EXECUTE PROCEDURE
update__sys_info();

--
-- Table structure for table _sys_scheduled
--

DROP TABLE "_sys_scheduled" CASCADE\g
DROP SEQUENCE "_sys_scheduled_id_seq" CASCADE ;

CREATE SEQUENCE "_sys_scheduled_id_seq" ;

CREATE TABLE  "_sys_scheduled" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"_sys_scheduled_id_seq"') NOT NULL,
   "name"   varchar(128) NOT NULL default '', 
   "previous_run"   timestamp without time zone default NULL,
   "next_run"   timestamp without time zone default NULL,
   "def_interval"  integer CHECK ("def_interval" >= 0) NOT NULL default '0',
   "blocked_until"   timestamp without time zone default NULL,
   "priority" int CHECK ("priority" >= 0) default '100',
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update__sys_scheduled() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to__sys_scheduled BEFORE UPDATE ON "_sys_scheduled" FOR EACH ROW EXECUTE PROCEDURE
update__sys_scheduled();

--
-- Table structure for table activation_queue
--

DROP TABLE "activation_queue" CASCADE\g
DROP SEQUENCE "activation_queue_id_seq" CASCADE ;

CREATE SEQUENCE "activation_queue_id_seq" ;

CREATE TABLE  "activation_queue" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"activation_queue_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update_activation_queue() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_activation_queue BEFORE UPDATE ON "activation_queue" FOR EACH ROW EXECUTE PROCEDURE
update_activation_queue();


--
-- Table structure for table attribute
--

DROP TABLE "attribute" CASCADE\g
DROP SEQUENCE "attribute_id_seq" CASCADE ;

CREATE SEQUENCE "attribute_id_seq" ;

CREATE TABLE  "attribute" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"attribute_id_seq"') NOT NULL,
   "spec" int CHECK ("spec" >= 0) NOT NULL default '0',
 "owner_table" varchar CHECK ("owner_table" IN ( 'service_membership','service','users','groups','vlan','outlet','subnet' )) default NULL,
   "owner_tid" int CHECK ("owner_tid" >= 0) NOT NULL default '0',
   "data"   text, 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update_attribute() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_attribute BEFORE UPDATE ON "attribute" FOR EACH ROW EXECUTE PROCEDURE
update_attribute();



--
-- Table structure for table attribute_spec
--

DROP TABLE "attribute_spec" CASCADE\g
DROP SEQUENCE "attribute_spec_id_seq" CASCADE ;

CREATE SEQUENCE "attribute_spec_id_seq" ;

CREATE TABLE  "attribute_spec" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"attribute_spec_id_seq"') NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   "format"   text NOT NULL, 
 "scope" varchar CHECK ("scope" IN ( 'service_membership','service','users','groups','vlan','outlet','subnet' )) default NULL,
   "type" int CHECK ("type" >= 0) NOT NULL default '0',
   "ntimes" smallint CHECK ("ntimes" >= 0) NOT NULL default '0',
   "description"   varchar(255) NOT NULL default '', 
   primary key ("id"),
 unique ("name", "type", "scope") 
);
 CREATE OR REPLACE FUNCTION update_attribute_spec() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_attribute_spec BEFORE UPDATE ON "attribute_spec" FOR EACH ROW EXECUTE PROCEDURE
update_attribute_spec();


--
-- Table structure for table billing
--

DROP TABLE "billing" CASCADE\g
DROP SEQUENCE "billing_id_seq" CASCADE ;

CREATE SEQUENCE "billing_id_seq" ;

CREATE TABLE  "billing" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"billing_id_seq"') NOT NULL,
   "user"   varchar(255) NOT NULL default '', 
 "type" varchar CHECK ("type" IN ( 'purchase','refund' )) NOT NULL default 'purchase',
 "status" varchar CHECK ("status" IN ( 'processed','unprocessed' )) NOT NULL default 'unprocessed',
   "share"   int NOT NULL default '0', 
   "category"   varchar(64) NOT NULL default '', 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update_billing() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_billing BEFORE UPDATE ON "billing" FOR EACH ROW EXECUTE PROCEDURE
update_billing();

--
-- Table structure for table building
--

DROP TABLE "building" CASCADE\g
DROP SEQUENCE "building_id_seq" CASCADE ;

CREATE SEQUENCE "building_id_seq" ;

CREATE TABLE  "building" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"building_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   "abbreviation"   varchar(16) NOT NULL default '', 
   "building"   varchar(8) NOT NULL default '', 
   "activation_queue" smallint CHECK ("activation_queue" >= 0) NOT NULL default '0',
   primary key ("id"),
 unique ("building") ,
 unique ("abbreviation") ,
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_building() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_building BEFORE UPDATE ON "building" FOR EACH ROW EXECUTE PROCEDURE
update_building();

--
-- Table structure for table cable
--

DROP TABLE "cable" CASCADE\g
DROP SEQUENCE "cable_id_seq" CASCADE ;

CREATE SEQUENCE "cable_id_seq" ;

CREATE TABLE  "cable" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"cable_id_seq"') NOT NULL,
   "label_from"   varchar(24) NOT NULL default '', 
   "label_to"   varchar(24) NOT NULL default '', 
 "type" varchar CHECK ("type" IN ( 'TYPE1','TYPE2','CAT5','CAT6','CATV','SMF0080','MMF0500','MMF0625','MMF1000','CAT5-TELCO' )) default NULL,
 "destination" varchar CHECK ("destination" IN ( 'OUTLET','CLOSET' )) default NULL,
 "rack" varchar CHECK ("rack" IN ( 'IBM','CAT5/6','CATV','FIBER','TELCO' )) NOT NULL default 'IBM',
   "prefix"   varchar(1) NOT NULL default '', 
   "from_building"   varchar(8) NOT NULL default '', 
   "from_wing"   varchar(1) NOT NULL default '', 
   "from_floor"   varchar(2) NOT NULL default '', 
   "from_closet"   varchar(1) NOT NULL default '', 
   "from_rack"   varchar(1) NOT NULL default '', 
   "from_panel"   varchar(1) NOT NULL default '', 
   "from_x"   varchar(1) NOT NULL default '', 
   "from_y"   varchar(1) NOT NULL default '', 
   "to_building"   varchar(8) default NULL, 
   "to_wing"   varchar(1) default NULL, 
   "to_floor"   varchar(2) default NULL, 
   "to_closet"   varchar(1) default NULL, 
   "to_rack"   varchar(1) default NULL, 
   "to_panel"   varchar(1) default NULL, 
   "to_x"   varchar(1) default NULL, 
   "to_y"   varchar(1) default NULL, 
   "to_floor_plan_x"   varchar(2) default NULL, 
   "to_floor_plan_y"   varchar(2) default NULL, 
   "to_outlet_number"   varchar(1) default NULL, 
   "to_room_number"   varchar(32) default NULL, 
   primary key ("id"),
 unique ("label_from") 
);
 CREATE OR REPLACE FUNCTION update_cable() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_cable BEFORE UPDATE ON "cable" FOR EACH ROW EXECUTE PROCEDURE
update_cable();




--
-- Table structure for table credentials
--

DROP TABLE "credentials" CASCADE\g
DROP SEQUENCE "credentials_id_seq" CASCADE ;

CREATE SEQUENCE "credentials_id_seq" ;

CREATE TABLE  "credentials" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"credentials_id_seq"') NOT NULL,
   "authid"   varchar(255) NOT NULL default '', 
   "user" int CHECK ("user" >= 0) NOT NULL default '0',
   "description"   varchar(255) NOT NULL default '', 
   "fkey"   varchar(255) NOT NULL default '', 
   "source"   varchar(16) NOT NULL default '', 
   primary key ("id"),
 unique ("authid") 
);
 CREATE OR REPLACE FUNCTION update_credentials() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_credentials BEFORE UPDATE ON "credentials" FOR EACH ROW EXECUTE PROCEDURE
update_credentials();


--
-- Table structure for table dhcp_option
--

DROP TABLE "dhcp_option" CASCADE\g
DROP SEQUENCE "dhcp_option_id_seq" CASCADE ;

CREATE SEQUENCE "dhcp_option_id_seq" ;

CREATE TABLE  "dhcp_option" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"dhcp_option_id_seq"') NOT NULL,
   "value"   varchar(255) NOT NULL default '', 
 "type" varchar CHECK ("type" IN ( 'global','share','subnet','machine','service' )) NOT NULL default 'global',
   "tid" int CHECK ("tid" >= 0) NOT NULL default '0',
   "type_id" int CHECK ("type_id" >= 0) NOT NULL default '0',
   primary key ("id"),
 unique ("type_id", "type", "tid", "value") 
);
 CREATE OR REPLACE FUNCTION update_dhcp_option() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dhcp_option BEFORE UPDATE ON "dhcp_option" FOR EACH ROW EXECUTE PROCEDURE
update_dhcp_option();


--
-- Table structure for table dhcp_option_type
--

DROP TABLE "dhcp_option_type" CASCADE\g
DROP SEQUENCE "dhcp_option_type_id_seq" CASCADE ;

CREATE SEQUENCE "dhcp_option_type_id_seq" ;

CREATE TABLE  "dhcp_option_type" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"dhcp_option_type_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   "number" int CHECK ("number" >= 0) NOT NULL default '0',
   "format"   varchar(255) NOT NULL default '', 
 "builtin" varchar CHECK ("builtin" IN ( 'Y','N' )) NOT NULL default 'N',
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_dhcp_option_type() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dhcp_option_type BEFORE UPDATE ON "dhcp_option_type" FOR EACH ROW EXECUTE PROCEDURE
update_dhcp_option_type();


--
-- Table structure for table dns_resource
--

DROP TABLE "dns_resource" CASCADE\g
DROP SEQUENCE "dns_resource_id_seq" CASCADE ;

CREATE SEQUENCE "dns_resource_id_seq" ;

CREATE TABLE  "dns_resource" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"dns_resource_id_seq"') NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   "ttl" int CHECK ("ttl" >= 0) NOT NULL default '0',
   "type"   varchar(8) NOT NULL default '', 
   "rname"   varchar(255) default NULL, 
   "rmetric0" int CHECK ("rmetric0" >= 0) default NULL,
   "rmetric1" int CHECK ("rmetric1" >= 0) default NULL,
   "rport" int CHECK ("rport" >= 0) default NULL,
   "text0"   varchar(1024) default NULL, 
   "text1"   varchar(255) default NULL, 
   "name_zone" int CHECK ("name_zone" >= 0) NOT NULL default '0',
 "owner_type" varchar CHECK ("owner_type" IN ( 'machine','dns_zone','service' )) NOT NULL default 'machine',
   "owner_tid" int CHECK ("owner_tid" >= 0) NOT NULL default '0',
   "rname_tid" int CHECK ("rname_tid" >= 0) default NULL,
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update_dns_resource() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dns_resource BEFORE UPDATE ON "dns_resource" FOR EACH ROW EXECUTE PROCEDURE
update_dns_resource();




--
-- Table structure for table dns_resource_type
--

DROP TABLE "dns_resource_type" CASCADE\g
DROP SEQUENCE "dns_resource_type_id_seq" CASCADE ;

CREATE SEQUENCE "dns_resource_type_id_seq" ;

CREATE TABLE  "dns_resource_type" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"dns_resource_type_id_seq"') NOT NULL,
   "name"   varchar(8) NOT NULL default '', 
   "format"   varchar(8) NOT NULL default '', 
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_dns_resource_type() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dns_resource_type BEFORE UPDATE ON "dns_resource_type" FOR EACH ROW EXECUTE PROCEDURE
update_dns_resource_type();

--
-- Table structure for table dns_zone
--

DROP TABLE "dns_zone" CASCADE\g
DROP SEQUENCE "dns_zone_id_seq" CASCADE ;

CREATE SEQUENCE "dns_zone_id_seq" ;

CREATE TABLE  "dns_zone" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"dns_zone_id_seq"') NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   "soa_host"   varchar(255) NOT NULL default '', 
   "soa_email"   varchar(255) NOT NULL default '', 
   "soa_serial" int CHECK ("soa_serial" >= 0) NOT NULL default '0',
   "soa_refresh" int CHECK ("soa_refresh" >= 0) NOT NULL default '3600',
   "soa_retry" int CHECK ("soa_retry" >= 0) NOT NULL default '900',
   "soa_expire" int CHECK ("soa_expire" >= 0) NOT NULL default '2419200',
   "soa_minimum" int CHECK ("soa_minimum" >= 0) NOT NULL default '3600',
 "type" varchar CHECK ("type" IN ( 'fw-toplevel','rv-toplevel','fw-permissible','rv-permissible','fw-delegated','rv-delegated','external' )) default NULL,
   "last_update"   timestamp without time zone default NULL,
   "soa_default" int CHECK ("soa_default" >= 0) NOT NULL default '86400',
   "parent" int CHECK ("parent" >= 0) NOT NULL default '0',
   "ddns_auth"   text, 
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_dns_zone() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_dns_zone BEFORE UPDATE ON "dns_zone" FOR EACH ROW EXECUTE PROCEDURE
update_dns_zone();


--
-- Table structure for table groups
--

DROP TABLE "groups" CASCADE\g
DROP SEQUENCE "groups_id_seq" CASCADE ;

CREATE SEQUENCE "groups_id_seq" ;

DROP TABLE "groups_flags_constraint_table"  CASCADE\g
create table "groups_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "groups_flags_constraint_table"   values (  'abuse'  )\g
insert into "groups_flags_constraint_table"   values (  'suspend'  )\g
insert into "groups_flags_constraint_table"   values (  'purge_mailusers'  )\g
CREATE TABLE  "groups" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"groups_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
 flags varchar ,    "description"   varchar(64) NOT NULL default '', 
   "comment_lvl9"   varchar(64) NOT NULL default '', 
   "comment_lvl5"   varchar(64) NOT NULL default '', 
   "fkey"  varchar(255) NOT NULL default '',
   "source" varchar(16) NOT NULL default '',
   primary key ("id"),
 unique ("name") 
);
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
-- Table structure for table mac_vendor
--

DROP TABLE "mac_vendor" CASCADE\g
DROP SEQUENCE "mac_vendor_id_seq" CASCADE ;

CREATE SEQUENCE "mac_vendor_id_seq" ;

CREATE TABLE  "mac_vendor" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"mac_vendor_id_seq"') NOT NULL,
   "prefix"   varchar(6) NOT NULL default '', 
   "vendor"   varchar(128) NOT NULL default '', 
   primary key ("id"),
 unique ("prefix") 
);
 CREATE OR REPLACE FUNCTION update_mac_vendor() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_mac_vendor BEFORE UPDATE ON "mac_vendor" FOR EACH ROW EXECUTE PROCEDURE
update_mac_vendor();


--
-- Table structure for table machine
--

DROP TABLE "machine" CASCADE\g
DROP SEQUENCE "machine_id_seq" CASCADE ;

CREATE SEQUENCE "machine_id_seq" ;

DROP TABLE "machine_flags_constraint_table"  CASCADE\g
create table "machine_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "machine_flags_constraint_table"   values (  'abuse'  )\g
insert into "machine_flags_constraint_table"   values (  'suspend'  )\g
insert into "machine_flags_constraint_table"   values (  'stolen'  )\g
insert into "machine_flags_constraint_table"   values (  'no_dnsfwd'  )\g
insert into "machine_flags_constraint_table"   values (  'no_dnsrev'  )\g
insert into "machine_flags_constraint_table"   values (  'roaming'  )\g
insert into "machine_flags_constraint_table"   values (  'independent'  )\g
insert into "machine_flags_constraint_table"   values (  'no_outlet'  )\g
insert into "machine_flags_constraint_table"   values (  'no_dhcp'  )\g
insert into "machine_flags_constraint_table"   values (  'no_expire'  )\g
CREATE TABLE  "machine" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"machine_id_seq"') NOT NULL,
   "mac_address"   varchar(12) NOT NULL default '', 
   "host_name"   varchar(255) NOT NULL default '', 
   "ip_address" inet NOT NULL default '0.0.0.0/32',
 "mode" varchar CHECK ("mode" IN ( 'static','dynamic','reserved','broadcast','pool','base','secondary' )) NOT NULL default 'static',
 flags varchar ,    "comment_lvl9"   varchar(255) NOT NULL default '', 
   "account"   varchar(32) NOT NULL default '', 
   "host_name_ttl" int CHECK ("host_name_ttl" >= 0) NOT NULL default '0',
   "ip_address_ttl" int CHECK ("ip_address_ttl" >= 0) NOT NULL default '0',
   "host_name_zone" int CHECK ("host_name_zone" >= 0) NOT NULL default '0',
   "ip_address_zone" int CHECK ("ip_address_zone" >= 0) NOT NULL default '0',
   "ip_address_subnet" int CHECK ("ip_address_subnet" >= 0) NOT NULL default '0',
   "created"   timestamp without time zone NOT NULL default '1970-01-01 00:00:00', 
   "expires"   date default NULL,
   "comment_lvl1"   varchar(255) NOT NULL default '', 
   "comment_lvl5"   varchar(255) NOT NULL default '', 
 "ostype" varchar CHECK ("ostype" IN ( 'AIX','FreeBSD','HPUX','Irix','Linux','Mac OS 8.X','Mac OS 9.X','Mac OS X','NCDware','Printer','SCO','Solaris','SunOS','tru64 Unix','Ultrix','VMS','Windows 95','Windows 98','Windows CE','Windows ME','Windows XP','Windows NT','Windows 2000','Windows 2003','Other','Pocket PC','Windows Vista','Windows 2008','Windows 7' )) default NULL,
   "model"   varchar(64) default NULL, 
   "serial"   varchar(64) default NULL, 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update_machine() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_machine BEFORE UPDATE ON "machine" FOR EACH ROW EXECUTE PROCEDURE
update_machine();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the machine_flags table
CREATE OR REPLACE FUNCTION check_machine_flags_set(  ) RETURNS TRIGGER AS $$

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
        EXECUTE 'SELECT count(*) FROM "machine_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON machine;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON machine   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_machine_flags_set();








--
-- Table structure for table machine_outlet
--

DROP TABLE "machine_outlet" CASCADE\g
DROP SEQUENCE "machine_outlet_id_seq" CASCADE ;

CREATE SEQUENCE "machine_outlet_id_seq" ;

CREATE TABLE  "machine_outlet" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"machine_outlet_id_seq"') NOT NULL,
   "machine" int CHECK ("machine" >= 0) default NULL,
   "outlet" int CHECK ("outlet" >= 0) default NULL,
   primary key ("id"),
 unique ("machine") 
);
 CREATE OR REPLACE FUNCTION update_machine_outlet() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_machine_outlet BEFORE UPDATE ON "machine_outlet" FOR EACH ROW EXECUTE PROCEDURE
update_machine_outlet();


--
-- Table structure for table memberships
--

DROP TABLE "memberships" CASCADE\g
DROP SEQUENCE "memberships_id_seq" CASCADE ;

CREATE SEQUENCE "memberships_id_seq" ;

CREATE TABLE  "memberships" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"memberships_id_seq"') NOT NULL,
   "uid" int CHECK ("uid" >= 0) NOT NULL default '0',
   "gid"   int NOT NULL default '0', 
   primary key ("id"),
 unique ("uid", "gid") 
);
 CREATE OR REPLACE FUNCTION update_memberships() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_memberships BEFORE UPDATE ON "memberships" FOR EACH ROW EXECUTE PROCEDURE
update_memberships();


--
-- Table structure for table network
--

DROP TABLE "network" CASCADE\g
DROP SEQUENCE "network_id_seq" CASCADE ;

CREATE SEQUENCE "network_id_seq" ;

CREATE TABLE  "network" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"network_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   "subnet" int CHECK ("subnet" >= 0) NOT NULL default '0',
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update_network() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_network BEFORE UPDATE ON "network" FOR EACH ROW EXECUTE PROCEDURE
update_network();


--
-- Table structure for table outlet
--

DROP TABLE "outlet" CASCADE\g
DROP SEQUENCE "outlet_id_seq" CASCADE ;

CREATE SEQUENCE "outlet_id_seq" ;

DROP TABLE "outlet_flags_constraint_table"  CASCADE\g
create table "outlet_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "outlet_flags_constraint_table"   values (  'abuse'  )\g
insert into "outlet_flags_constraint_table"   values (  'suspend'  )\g
insert into "outlet_flags_constraint_table"   values (  'permanent'  )\g
insert into "outlet_flags_constraint_table"   values (  'activated'  )\g
DROP TABLE "outlet_attributes_constraint_table"  CASCADE\g
create table "outlet_attributes_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "outlet_attributes_constraint_table"   values (  'activate'  )\g
insert into "outlet_attributes_constraint_table"   values (  'deactivate'  )\g
CREATE TABLE  "outlet" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"outlet_id_seq"') NOT NULL,
   "type" int CHECK ("type" >= 0) NOT NULL default '0',
   "cable" int CHECK ("cable" >= 0) NOT NULL default '0',
   "device"   varchar(255) NOT NULL default '', 
   "port"   int NOT NULL default '0', 
 attributes varchar ,  flags varchar ,  "status" varchar CHECK ("status" IN ( 'enabled','partitioned' )) NOT NULL default 'enabled',
   "account"   varchar(32) NOT NULL default '', 
   "comment_lvl9"   varchar(255) NOT NULL default '', 
   "comment_lvl1"   varchar(255) NOT NULL default '', 
   "comment_lvl5"   varchar(255) NOT NULL default '', 
   primary key ("id"),
 unique ("cable") 
);
 CREATE OR REPLACE FUNCTION update_outlet() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_outlet BEFORE UPDATE ON "outlet" FOR EACH ROW EXECUTE PROCEDURE
update_outlet();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the outlet_flags table
CREATE OR REPLACE FUNCTION check_outlet_flags_set(  ) RETURNS TRIGGER AS $$

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
        EXECUTE 'SELECT count(*) FROM "outlet_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON outlet;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON outlet   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_outlet_flags_set();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the outlet_attributes table
CREATE OR REPLACE FUNCTION check_outlet_attributes_set(  ) RETURNS TRIGGER AS $$

DECLARE	
----
arg_str VARCHAR ; 
argx VARCHAR := ''; 
nobreak INT := 1;
rec_count INT := 0;
str_in VARCHAR := NEW.attributes;
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
        EXECUTE 'SELECT count(*) FROM "outlet_attributes_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON outlet;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON outlet   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_outlet_attributes_set();


--
-- Table structure for table outlet_subnet_membership
--

DROP TABLE "outlet_subnet_membership" CASCADE\g
DROP SEQUENCE "outlet_subnet_membership_id_seq" CASCADE ;

CREATE SEQUENCE "outlet_subnet_membership_id_seq" ;

CREATE TABLE  "outlet_subnet_membership" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"outlet_subnet_membership_id_seq"') NOT NULL,
   "outlet" int CHECK ("outlet" >= 0) NOT NULL default '0',
   "subnet" int CHECK ("subnet" >= 0) NOT NULL default '0',
 "type" varchar CHECK ("type" IN ( 'primary','voice','other' )) NOT NULL default 'primary',
 "trunk_type" varchar CHECK ("trunk_type" IN ( '802.1Q','ISL','none' )) NOT NULL default '802.1Q',
 "status" varchar CHECK ("status" IN ( 'request','active','delete','error','errordelete' )) NOT NULL default 'request',
   primary key ("id"),
 unique ("outlet", "subnet") 
);
 CREATE OR REPLACE FUNCTION update_outlet_subnet_membership() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_outlet_subnet_membership BEFORE UPDATE ON "outlet_subnet_membership" FOR EACH ROW EXECUTE PROCEDURE
update_outlet_subnet_membership();


--
-- Table structure for table outlet_type
--

DROP TABLE "outlet_type" CASCADE\g
DROP SEQUENCE "outlet_type_id_seq" CASCADE ;

CREATE SEQUENCE "outlet_type_id_seq" ;

CREATE TABLE  "outlet_type" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"outlet_type_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_outlet_type() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_outlet_type BEFORE UPDATE ON "outlet_type" FOR EACH ROW EXECUTE PROCEDURE
update_outlet_type();

--
-- Table structure for table outlet_vlan_membership
--

DROP TABLE "outlet_vlan_membership" CASCADE\g
DROP SEQUENCE "outlet_vlan_membership_id_seq" CASCADE ;

CREATE SEQUENCE "outlet_vlan_membership_id_seq" ;

CREATE TABLE  "outlet_vlan_membership" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"outlet_vlan_membership_id_seq"') NOT NULL,
   "outlet"   int NOT NULL default '0', 
   "vlan"   int NOT NULL default '0', 
 "type" varchar CHECK ("type" IN ( 'primary','voice','other' )) NOT NULL default 'primary',
 "trunk_type" varchar CHECK ("trunk_type" IN ( '802.1Q','ISL','none' )) NOT NULL default '802.1Q',
 "status" varchar CHECK ("status" IN ( 'request','active','delete','error','errordelete' )) NOT NULL default 'request',
   primary key ("id"),
 unique ("outlet", "vlan") 
);
 CREATE OR REPLACE FUNCTION update_outlet_vlan_membership() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_outlet_vlan_membership BEFORE UPDATE ON "outlet_vlan_membership" FOR EACH ROW EXECUTE PROCEDURE
update_outlet_vlan_membership();


--
-- Table structure for table protections
--

DROP TABLE "protections" CASCADE\g
DROP SEQUENCE "protections_id_seq" CASCADE ;

CREATE SEQUENCE "protections_id_seq" ;

DROP TABLE "protections_rights_constraint_table"  CASCADE\g
create table "protections_rights_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "protections_rights_constraint_table"   values (  'READ'  )\g
insert into "protections_rights_constraint_table"   values (  'WRITE'  )\g
insert into "protections_rights_constraint_table"   values (  'ADD'  )\g
CREATE TABLE  "protections" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"protections_id_seq"') NOT NULL,
   "identity"   int NOT NULL default '0', 
 "tname" varchar CHECK ("tname" IN ( 'users','groups','building','cable','outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence','subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource','dns_zone','_sys_scheduled','activation_queue','service','service_membership','service_type','attribute','attribute_spec','outlet_subnet_membership','outlet_vlan_membership','vlan','vlan_presence','vlan_subnet_presence','trunk_set','trunkset_building_presence','trunkset_machine_presence','trunkset_vlan_presence','credentials','subnet_registration_modes','resdrop','machine_outlet','iprange_building_presence','srm_share','mac_vendor' )) NOT NULL default 'users',
   "tid"   int NOT NULL default '0', 
 rights varchar ,    "rlevel" smallint CHECK ("rlevel" >= 0) NOT NULL default '0',
   primary key ("id"),
 unique ("identity", "tname", "tid", "rlevel") 
);
 CREATE OR REPLACE FUNCTION update_protections() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_protections BEFORE UPDATE ON "protections" FOR EACH ROW EXECUTE PROCEDURE
update_protections();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the protections_rights table
CREATE OR REPLACE FUNCTION check_protections_rights_set(  ) RETURNS TRIGGER AS $$

DECLARE	
----
arg_str VARCHAR ; 
argx VARCHAR := ''; 
nobreak INT := 1;
rec_count INT := 0;
str_in VARCHAR := NEW.rights;
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
        EXECUTE 'SELECT count(*) FROM "protections_rights_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON protections;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON protections   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_protections_rights_set();



--
-- Table structure for table resdrop
--

DROP TABLE "resdrop" CASCADE\g
DROP SEQUENCE "resdrop_id_seq" CASCADE ;

CREATE SEQUENCE "resdrop_id_seq" ;

DROP TABLE "resdrop_flags_constraint_table"  CASCADE\g
create table "resdrop_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "resdrop_flags_constraint_table"   values (  'mac_security'  )\g
insert into "resdrop_flags_constraint_table"   values (  'guest_access'  )\g
insert into "resdrop_flags_constraint_table"   values (  'partition'  )\g
CREATE TABLE  "resdrop" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"resdrop_id_seq"') NOT NULL,
   "jack"   varchar(16) default NULL, 
   "building"   varchar(8) default NULL, 
   "switch"   varchar(255) default NULL, 
   "slot" int CHECK ("slot" >= 0) default NULL,
   "port" int CHECK ("port" >= 0) default NULL,
   "vlan" int CHECK ("vlan" >= 0) default NULL,
   "fkey"   int NOT NULL default '0', 
   "flags" varchar ,    primary key ("id"),
   "secondary" varchar(16) default NULL
);
 CREATE OR REPLACE FUNCTION update_resdrop() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_resdrop BEFORE UPDATE ON "resdrop" FOR EACH ROW EXECUTE PROCEDURE
update_resdrop();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the resdrop_flags table
CREATE OR REPLACE FUNCTION check_resdrop_flags_set(  ) RETURNS TRIGGER AS $$

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
        EXECUTE 'SELECT count(*) FROM "resdrop_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON resdrop;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON resdrop   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_resdrop_flags_set();


--
-- Table structure for table service
--

DROP TABLE "service" CASCADE\g
DROP SEQUENCE "service_id_seq" CASCADE ;

CREATE SEQUENCE "service_id_seq" ;

CREATE TABLE  "service" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"service_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   "type" int CHECK ("type" >= 0) NOT NULL default '0',
   "description"   varchar(255) NOT NULL default '', 
   "min_member_level" int CHECK ("min_member_level" >= 0) NOT NULL default '1',
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_service() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_service BEFORE UPDATE ON "service" FOR EACH ROW EXECUTE PROCEDURE
update_service();

--
-- Table structure for table service_membership
--

DROP TABLE "service_membership" CASCADE\g
DROP SEQUENCE "service_membership_id_seq" CASCADE ;

CREATE SEQUENCE "service_membership_id_seq" ;

CREATE TABLE  "service_membership" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"service_membership_id_seq"') NOT NULL,
   "service" int CHECK ("service" >= 0) NOT NULL default '0',
 "member_type" varchar CHECK ("member_type" IN ( 'activation_queue','building','cable','dns_zone','groups','machine','outlet','outlet_type','service','subnet','subnet_share','users','vlan' )) NOT NULL default 'activation_queue',
   "member_tid" int CHECK ("member_tid" >= 0) NOT NULL default '0',
   primary key ("id"),
 unique ("member_type", "member_tid", "service") 
);
 CREATE OR REPLACE FUNCTION update_service_membership() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_service_membership BEFORE UPDATE ON "service_membership" FOR EACH ROW EXECUTE PROCEDURE
update_service_membership();

--
-- Table structure for table service_type
--

DROP TABLE "service_type" CASCADE\g
DROP SEQUENCE "service_type_id_seq" CASCADE ;

CREATE SEQUENCE "service_type_id_seq" ;

CREATE TABLE  "service_type" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"service_type_id_seq"') NOT NULL,
   "name"   varchar(255) NOT NULL default '', 
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_service_type() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_service_type BEFORE UPDATE ON "service_type" FOR EACH ROW EXECUTE PROCEDURE
update_service_type();

--
-- Table structure for table srm_share
--

DROP TABLE "srm_share" CASCADE\g
DROP SEQUENCE "srm_share_id_seq" CASCADE ;

CREATE SEQUENCE "srm_share_id_seq" ;

DROP TABLE "srm_share_flags_constraint_table"  CASCADE\g
create table "srm_share_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "srm_share_flags_constraint_table"   values (  'purchasable'  )\g
CREATE TABLE  "srm_share" (
   "id" integer DEFAULT nextval('"srm_share_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "name"   varchar(64) NOT NULL default '', 
   "abbreviation"   varchar(16) NOT NULL default '', 
 flags varchar ,    primary key ("id"),
 unique ("name") ,
 unique ("abbreviation") 
);
 CREATE OR REPLACE FUNCTION update_srm_share() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_srm_share BEFORE UPDATE ON "srm_share" FOR EACH ROW EXECUTE PROCEDURE
update_srm_share();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the srm_share_flags table
CREATE OR REPLACE FUNCTION check_srm_share_flags_set(  ) RETURNS TRIGGER AS $$

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
        EXECUTE 'SELECT count(*) FROM "srm_share_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON srm_share;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON srm_share   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_srm_share_flags_set();

--
-- Table structure for table subnet
--

DROP TABLE "subnet" CASCADE\g
DROP SEQUENCE "subnet_id_seq" CASCADE ;

CREATE SEQUENCE "subnet_id_seq" ;

DROP TABLE "subnet_flags_constraint_table"  CASCADE\g
create table "subnet_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "subnet_flags_constraint_table"   values (  'no_dhcp'  )\g
insert into "subnet_flags_constraint_table"   values (  'delegated'  )\g
insert into "subnet_flags_constraint_table"   values (  'prereg_subnet'  )\g
DROP TABLE "subnet_default_host_flags_constraint_table"  CASCADE\g
create table "subnet_default_host_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "subnet_default_host_flags_constraint_table"   values (  'abuse'  )\g
insert into "subnet_default_host_flags_constraint_table"   values (  'suspend'  )\g
insert into "subnet_default_host_flags_constraint_table"   values (  'stolen'  )\g
insert into "subnet_default_host_flags_constraint_table"   values (  'no_dnsfwd'  )\g
insert into "subnet_default_host_flags_constraint_table"   values (  'no_dnsrev'  )\g
insert into "subnet_default_host_flags_constraint_table"   values (  'roaming'  )\g
insert into "subnet_default_host_flags_constraint_table"   values (  'independent'  )\g
CREATE TABLE  "subnet" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"subnet_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   "abbreviation"   varchar(16) NOT NULL default '', 
   "base_address" inet NOT NULL default '0.0.0.0',
 "dynamic" varchar CHECK ("dynamic" IN ( 'permit','restrict','disallow','unknown' )) default NULL,
   "expire_static" int CHECK ("expire_static" >= 0) NOT NULL default '0',
   "expire_dynamic" int CHECK ("expire_dynamic" >= 0) NOT NULL default '0',
   "share" int CHECK ("share" >= 0) NOT NULL default '0',
 flags varchar ,  "default_mode" varchar CHECK ("default_mode" IN ( 'static','dynamic','reserved' )) NOT NULL default 'static',
   "purge_interval" int CHECK ("purge_interval" >= 0) NOT NULL default '0',
   "purge_notupd" int CHECK ("purge_notupd" >= 0) NOT NULL default '0',
   "purge_notseen" int CHECK ("purge_notseen" >= 0) NOT NULL default '0',
   "purge_explen" int CHECK ("purge_explen" >= 0) NOT NULL default '0',
   "purge_lastdone"   timestamp without time zone default NULL,
   "vlan"   varchar(8) NOT NULL default '', 
   "default_host_name_zone"   int NOT NULL default '0', 
 default_host_flags varchar ,    primary key ("id"),
 unique ("name") ,
 unique ("abbreviation") 
);
 CREATE OR REPLACE FUNCTION update_subnet() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_subnet BEFORE UPDATE ON "subnet" FOR EACH ROW EXECUTE PROCEDURE
update_subnet();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the subnet_flags table
CREATE OR REPLACE FUNCTION check_subnet_flags_set(  ) RETURNS TRIGGER AS $$

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
        EXECUTE 'SELECT count(*) FROM "subnet_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON subnet;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON subnet   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_subnet_flags_set();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the subnet_default_host_flags table
CREATE OR REPLACE FUNCTION check_subnet_default_host_flags_set(  ) RETURNS TRIGGER AS $$

DECLARE	
----
arg_str VARCHAR ; 
argx VARCHAR := ''; 
nobreak INT := 1;
rec_count INT := 0;
str_in VARCHAR := NEW.default_host_flags;
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
        EXECUTE 'SELECT count(*) FROM "subnet_default_host_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON subnet;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON subnet   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_subnet_default_host_flags_set();


--
-- Table structure for table subnet_domain
--

DROP TABLE "subnet_domain" CASCADE\g
DROP SEQUENCE "subnet_domain_id_seq" CASCADE ;

CREATE SEQUENCE "subnet_domain_id_seq" ;

CREATE TABLE  "subnet_domain" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"subnet_domain_id_seq"') NOT NULL,
   "subnet" int CHECK ("subnet" >= 0) NOT NULL default '0',
   "domain"   varchar(252) NOT NULL default '', 
   primary key ("id"),
 unique ("subnet", "domain") 
);
 CREATE OR REPLACE FUNCTION update_subnet_domain() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_subnet_domain BEFORE UPDATE ON "subnet_domain" FOR EACH ROW EXECUTE PROCEDURE
update_subnet_domain();




--
-- Table structure for table subnet_presence
--

DROP TABLE "subnet_presence" CASCADE\g
DROP SEQUENCE "subnet_presence_id_seq" CASCADE ;

CREATE SEQUENCE "subnet_presence_id_seq" ;

CREATE TABLE  "subnet_presence" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"subnet_presence_id_seq"') NOT NULL,
   "subnet" int CHECK ("subnet" >= 0) NOT NULL default '0',
   "building"   varchar(8) NOT NULL default '', 
   primary key ("id"),
 unique ("subnet", "building") 
);
 CREATE OR REPLACE FUNCTION update_subnet_presence() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_subnet_presence BEFORE UPDATE ON "subnet_presence" FOR EACH ROW EXECUTE PROCEDURE
update_subnet_presence();



--
-- Table structure for table subnet_registration_modes
--

DROP TABLE "subnet_registration_modes" CASCADE\g
DROP SEQUENCE "subnet_registration_modes_id_seq" CASCADE ;

CREATE SEQUENCE "subnet_registration_modes_id_seq" ;

CREATE TABLE  "subnet_registration_modes" (
   "id" integer DEFAULT nextval('"subnet_registration_modes_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "subnet"   int NOT NULL default '0', 
 "mode" varchar CHECK ("mode" IN ( 'static','dynamic','reserved','broadcast','pool','base','secondary' )) NOT NULL default 'static',
 "mac_address" varchar CHECK ("mac_address" IN ( 'required','none' )) NOT NULL default 'required',
 "outlet" varchar CHECK ("outlet" IN ( 'required','none' )) NOT NULL default 'required',
   "share"   int NOT NULL default '0', 
   "quota" int CHECK ("quota" >= 0) default NULL,
   primary key ("id"),
 unique ("subnet", "share", "mode", "mac_address", "outlet", "quota") 
);
 CREATE OR REPLACE FUNCTION update_subnet_registration_modes() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_subnet_registration_modes BEFORE UPDATE ON "subnet_registration_modes" FOR EACH ROW EXECUTE PROCEDURE
update_subnet_registration_modes();


--
-- Table structure for table subnet_share
--

DROP TABLE "subnet_share" CASCADE\g
DROP SEQUENCE "subnet_share_id_seq" CASCADE ;

CREATE SEQUENCE "subnet_share_id_seq" ;

CREATE TABLE  "subnet_share" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"subnet_share_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   "abbreviation"   varchar(16) NOT NULL default '', 
   primary key ("id"),
 unique ("abbreviation") ,
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_subnet_share() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_subnet_share BEFORE UPDATE ON "subnet_share" FOR EACH ROW EXECUTE PROCEDURE
update_subnet_share();

--
-- Table structure for table trunk_set
--

DROP TABLE "trunk_set" CASCADE\g
DROP SEQUENCE "trunk_set_id_seq" CASCADE ;

CREATE SEQUENCE "trunk_set_id_seq" ;

CREATE TABLE  "trunk_set" (
   "id" integer DEFAULT nextval('"trunk_set_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "name"   varchar(255) NOT NULL default '', 
   "abbreviation"   varchar(127) NOT NULL default '', 
   "description"   varchar(255) NOT NULL default '', 
   "primary_vlan"   int NOT NULL default '0', 
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_trunk_set() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_trunk_set BEFORE UPDATE ON "trunk_set" FOR EACH ROW EXECUTE PROCEDURE
update_trunk_set();

--
-- Table structure for table trunkset_building_presence
--

DROP TABLE "trunkset_building_presence" CASCADE\g
DROP SEQUENCE "trunkset_building_presence_id_seq" CASCADE ;

CREATE SEQUENCE "trunkset_building_presence_id_seq" ;

CREATE TABLE  "trunkset_building_presence" (
   "id" integer DEFAULT nextval('"trunkset_building_presence_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "trunk_set"   int NOT NULL default '0', 
   "buildings"   int NOT NULL default '0', 
   primary key ("id"),
 unique ("trunk_set", "buildings") 
);
 CREATE OR REPLACE FUNCTION update_trunkset_building_presence() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_trunkset_building_presence BEFORE UPDATE ON "trunkset_building_presence" FOR EACH ROW EXECUTE PROCEDURE
update_trunkset_building_presence();



--
-- Table structure for table trunkset_machine_presence
--

DROP TABLE "trunkset_machine_presence" CASCADE\g
DROP SEQUENCE "trunkset_machine_presence_id_seq" CASCADE ;

CREATE SEQUENCE "trunkset_machine_presence_id_seq" ;

CREATE TABLE  "trunkset_machine_presence" (
   "id" integer DEFAULT nextval('"trunkset_machine_presence_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "device"   int NOT NULL default '0', 
   "trunk_set"   int NOT NULL default '0', 
   primary key ("id"),
 unique ("trunk_set", "device") 
);
 CREATE OR REPLACE FUNCTION update_trunkset_machine_presence() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_trunkset_machine_presence BEFORE UPDATE ON "trunkset_machine_presence" FOR EACH ROW EXECUTE PROCEDURE
update_trunkset_machine_presence();



--
-- Table structure for table trunkset_vlan_presence
--

DROP TABLE "trunkset_vlan_presence" CASCADE\g
DROP SEQUENCE "trunkset_vlan_presence_id_seq" CASCADE ;

CREATE SEQUENCE "trunkset_vlan_presence_id_seq" ;

CREATE TABLE  "trunkset_vlan_presence" (
   "id" integer DEFAULT nextval('"trunkset_vlan_presence_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "trunk_set"   int NOT NULL default '0', 
   "vlan"   int NOT NULL default '0', 
   primary key ("id"),
 unique ("trunk_set", "vlan") 
);
 CREATE OR REPLACE FUNCTION update_trunkset_vlan_presence() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_trunkset_vlan_presence BEFORE UPDATE ON "trunkset_vlan_presence" FOR EACH ROW EXECUTE PROCEDURE
update_trunkset_vlan_presence();



--
-- Table structure for table users
--

DROP TABLE "users" CASCADE\g
DROP SEQUENCE "users_id_seq" CASCADE ;

CREATE SEQUENCE "users_id_seq" ;

DROP TABLE "users_flags_constraint_table"  CASCADE\g
create table "users_flags_constraint_table"  ( set_values varchar UNIQUE)\g
insert into "users_flags_constraint_table"   values (  'abuse'  )\g
insert into "users_flags_constraint_table"   values (  'suspend'  )\g
insert into "users_flags_constraint_table"   values (  'external'  )\g
CREATE TABLE  "users" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"users_id_seq"') NOT NULL,
 flags varchar ,    "comment"   varchar(64) NOT NULL default '', 
   "fkey"   varchar(255) NOT NULL default '', 
   primary key ("id")
);
 CREATE OR REPLACE FUNCTION update_users() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_users BEFORE UPDATE ON "users" FOR EACH ROW EXECUTE PROCEDURE
update_users();

-- this function is called by the insert/update trigger
-- it checks if the INSERT/UPDATE for the 'set' column
-- contains members which comprise a valid mysql set
-- this TRIGGER function therefore acts like a constraint 
--  provided limited functionality for mysql's set datatype
-- just verifies and matches for string representations of the set at this point
-- though the set datatype uses bit comparisons, the only supported arguments to our
-- set datatype are VARCHAR arguments
-- to add a member to the set add it to the users_flags table
CREATE OR REPLACE FUNCTION check_users_flags_set(  ) RETURNS TRIGGER AS $$

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
        EXECUTE 'SELECT count(*) FROM "users_flags_constraint_table" WHERE set_values = ' || quote_literal(argx) INTO rec_count;
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

drop trigger set_test ON users;
-- make a trigger for each set field
-- make trigger and hard-code in column names
-- see http://archives.postgresql.org/pgsql-interfaces/2005-02/msg00020.php  	
CREATE   TRIGGER    set_test 
BEFORE   INSERT OR   UPDATE  ON users   FOR  EACH  ROW
EXECUTE  PROCEDURE  check_users_flags_set();

--
-- Table structure for table vlan
--

DROP TABLE "vlan" CASCADE\g
DROP SEQUENCE "vlan_id_seq" CASCADE ;

CREATE SEQUENCE "vlan_id_seq" ;

CREATE TABLE  "vlan" (
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "id" integer DEFAULT nextval('"vlan_id_seq"') NOT NULL,
   "name"   varchar(64) NOT NULL default '', 
   "abbreviation"   varchar(16) NOT NULL default '', 
   "number"   int NOT NULL default '0', 
   "description"   varchar(255) NOT NULL default '', 
   primary key ("id"),
 unique ("name") 
);
 CREATE OR REPLACE FUNCTION update_vlan() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_vlan BEFORE UPDATE ON "vlan" FOR EACH ROW EXECUTE PROCEDURE
update_vlan();

--
-- Table structure for table vlan_subnet_presence
--

DROP TABLE "vlan_subnet_presence" CASCADE\g
DROP SEQUENCE "vlan_subnet_presence_id_seq" CASCADE ;

CREATE SEQUENCE "vlan_subnet_presence_id_seq" ;

CREATE TABLE  "vlan_subnet_presence" (
   "id" integer DEFAULT nextval('"vlan_subnet_presence_id_seq"') NOT NULL,
   "version"   timestamp NOT NULL default CURRENT_TIMESTAMP , 
   "subnet"   int NOT NULL default '0', 
   "subnet_share"   int NOT NULL default '0', 
   "vlan"   int NOT NULL default '0', 
   primary key ("id"),
 unique ("subnet", "vlan") 
);
 CREATE OR REPLACE FUNCTION update_vlan_subnet_presence() RETURNS trigger AS '
BEGIN
    NEW.version := CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
' LANGUAGE 'plpgsql';

-- before INSERT is handled by 'default CURRENT_TIMESTAMP'
CREATE TRIGGER add_current_date_to_vlan_subnet_presence BEFORE UPDATE ON "vlan_subnet_presence" FOR EACH ROW EXECUTE PROCEDURE
update_vlan_subnet_presence();
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;


