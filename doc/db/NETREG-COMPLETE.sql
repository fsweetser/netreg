# $Id: NETREG-COMPLETE.sql,v 1.14 2008/03/27 19:42:16 vitroth Exp $
#
# NetReg database schema
#
# Copyright 2001-2003 Carnegie Mellon University
#
# All Rights Reserved
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted,
# provided that the above copyright notice appear in all copies and that
# both that copyright notice and this permission notice appear in
# supporting documentation, and that the name of CMU not be
# used in advertising or publicity pertaining to distribution of the
# software without specific, written prior permission.
#
# CMU DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
# ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
# CMU BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
# ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
# ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
# SOFTWARE.
#

DROP DATABASE IF EXISTS netdb;

CREATE DATABASE netdb;

CONNECT netdb;

SET FOREIGN_KEY_CHECKS=0;

###########################################################################

CREATE TABLE _sys_scheduled (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            VARCHAR(128)       NOT NULL,
        previous_run    DATETIME        NOT NULL,
        next_run        DATETIME        NOT NULL,
        def_interval    MEDIUMINT       UNSIGNED NOT NULL, # minutes    
	blocked_until	DATETIME	NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name)
) Type=InnoDB;

CREATE TABLE _sys_info (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        sys_key         CHAR(16)        NOT NULL,       
        sys_value       CHAR(128)       NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_key       (sys_key)
) Type=InnoDB;

CREATE TABLE _sys_errors (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,

        errcode         SMALLINT        NOT NULL,
        location        VARCHAR(64)        NOT NULL,
        errfields       VARCHAR(255)       NOT NULL,
        errtext         TEXT            NOT NULL,
        
        PRIMARY KEY     index_id        (id),
        KEY             index_error     (errcode, location, errfields(64))
) Type=InnoDB;

CREATE TABLE _sys_dberror (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        tname           ENUM (
                                'users',
                                'groups',
                                'building',
                                'cable',
                                'outlet',
                                'outlet_type',
                                'machine',
                                'network',
                                'subnet',
                                'subnet_share',
                                'subnet_presence',
                                'subnet_domain',
                                'dhcp_option_type',
                                'dhcp_option',
                                'dns_resource_type',
                                'dns_resource',
                                'dns_zone'
                        )               DEFAULT 'users' NOT NULL,
        tid             INT             UNSIGNED NOT NULL,
        errfields       VARCHAR(255)       NOT NULL,
        severity        ENUM ( 'EMERGENCY',
                                'ALERT',
                                'CRITICAL',
                                'ERROR',
                                'WARNING',
                                'NOTICE',
                                'INFO'
                        )               NOT NULL DEFAULT 'ERROR',
        errtype         INT             UNSIGNED NOT NULL,
        fixed           ENUM (
                                'UNFIXED',
                                'FIXED'
                        )               NOT NULL DEFAULT 'UNFIXED',
        comment         TEXT,
        PRIMARY KEY     index_id        (id)
) Type=InnoDB;

CREATE TABLE _sys_changelog (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  user int(10) unsigned NOT NULL,
  name char(16) NOT NULL,
  time datetime,
  info char(255) NOT NULL default '',
  
  PRIMARY KEY  (id),
  KEY index_user (user),
  KEY index_username (name),
  KEY index_time (time)
) Type=InnoDB;


CREATE TABLE _sys_changerec_row (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  changelog int(10) unsigned NOT NULL,
  tname char(255) NOT NULL,
  row int(10) unsigned NOT NULL,
  type enum("INSERT", "UPDATE", "DELETE") NOT NULL,

  PRIMARY KEY  (id),
  KEY index_changelog (changelog),
  KEY index_record (tname, row)
) Type=InnoDB;

CREATE TABLE _sys_changerec_col (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  changerec_row int(10) unsigned NOT NULL,
  name char(255) NOT NULL,
  data TEXT,
  previous TEXT,

  PRIMARY KEY  (id),
  KEY index_record (changerec_row, name)
) Type=InnoDB;

#
# credentials table
#
CREATE TABLE credentials (
	version		TIMESTAMP(14),
	id		INT	UNSIGNED NOT NULL AUTO_INCREMENT,

	authid		VARCHAR(255)	NOT NULL,
	user		INT	UNSIGNED NOT NULL,
        description     VARCHAR(255)    NOT NULL,
	type		VARCHAR(20)	NULL,

	PRIMARY KEY	index_id	(id),
	KEY		index_user	(user),
	UNIQUE		index_authid	(authid),
	FOREIGN KEY	(user) 		REFERENCES	users(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT
);

#
# users table
#
CREATE TABLE users (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,

        flags           SET (
                                'abuse',
                                'suspend'
                        )               NOT NULL,

        comment         CHAR(64)        NOT NULL,
	default_group	INT		UNSIGNED NOT NULL default 0,

        PRIMARY KEY     index_id        (id)
) Type=InnoDB;

#
# groups table
#
CREATE TABLE groups (
        version         TIMESTAMP(14),
        id              INT             NOT NULL AUTO_INCREMENT,
        name            CHAR(32)        NOT NULL,
        flags           SET (
                                'abuse',
                                'suspend',
                                'purge_mailusers'
                        )               NOT NULL,
        description     CHAR(64)        NOT NULL,
        comment_lvl5         CHAR(64)        NOT NULL,
        comment_lvl9         CHAR(64)        NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name)
) Type=InnoDB;

#
# memberships table
#
CREATE TABLE memberships (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        uid             INT             UNSIGNED NOT NULL,
        gid             INT             NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_membership (uid,gid),

        KEY             index_gid       (gid),
	FOREIGN KEY	(uid)		REFERENCES users(id)
			ON UPDATE CASCADE  ON DELETE CASCADE,
	FOREIGN KEY	(gid)		REFERENCES groups(id)
			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;

#
# protections table
#
CREATE TABLE protections (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,

        # users:  identity > 0; identity == users.id
        # groups: identity < 0; -identity == group.id
        identity        INT             NOT NULL,

        # table these proections apply to
        tname           ENUM (
                                'users',
				'credentials',
                                'groups',
                                'building',
                                'cable',
                                'outlet',
                                'outlet_type',
                                'machine',
                                'network',
                                'subnet',
                                'subnet_share',
                                'subnet_presence',
                                'subnet_domain',
                                'subnet_registration_modes',
                                'dhcp_option_type',
                                'dhcp_option',
                                'dns_resource_type',
                                'dns_resource',
                                'dns_zone',
                                '_sys_scheduled',
                                'activation_queue',
                                'service',
                                'service_membership',
                                'service_type',
                                'attribute',
                                'attribute_spec',
                                'outlet_subnet_membership',
				'outlet_vlan_membership',
				'vlan',
				'vlan_presence',
				'vlan_subnet_presence',
				'trunk_set',
				'trunkset_building_presence',
				'trunkset_machine_presence',
				'trunkset_vlan_presence'
                        )               NOT NULL,

        # when tid == 0; the permissions apply to entire table
        tid             INT             NOT NULL,

        # permissions to apply
        rights          SET (
                             'READ',
                             'WRITE',
                             'ADD' )    NOT NULL,
        rlevel          SMALLINT        UNSIGNED NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_nodup       (identity,tname,tid,rlevel),
        KEY             index_protection1 (identity,tname,tid),
        KEY             index_prot6     (tname,rights,identity,tid),
        KEY             tid             (tid),
        KEY             tname           (tname,tid),
        KEY             tname_2         (tname,tid,identity),
        KEY             index_all       (tname,tid,identity,rlevel,rights),
        KEY             index_all_2     (tid,tname,identity,rlevel,rights)
) Type=InnoDB;

###########################################################################

#
# activation queues
#

CREATE TABLE activation_queue (
        version         TIMESTAMP(14),
        id              SMALLINT        UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(64)        NOT NULL,

        PRIMARY KEY     index_id        (id),
        KEY             index_nodup     (name)
) Type=InnoDB;

#
# building table
#
CREATE TABLE building (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(64)        NOT NULL,
        abbreviation    CHAR(16)         NOT NULL,
        building        CHAR(8)         NOT NULL,
        activation_queue        SMALLINT        UNSIGNED NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name),
        UNIQUE          index_abbreviation (abbreviation),
        UNIQUE          index_number    (building),
	KEY		index_aq	(activation_queue),
	FOREIGN KEY	(activation_queue)	REFERENCES activation_queue(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT
) Type=InnoDB;


#
# cable table
#
CREATE TABLE cable  (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,

        label_from      CHAR(24)        NOT NULL,
        label_to        CHAR(24)        NOT NULL,

        type            ENUM (
                                'TYPE1',
                                'TYPE2',
                                'CAT5',
                                'CAT6',
                                'CATV',
                                'SMF0080',
                                'MMF0500',
                                'MMF0625',
                                'MMF1000',
                                'CAT5-TELCO'
                        )               DEFAULT NULL,
        destination     ENUM (
                                'OUTLET',
                                'CLOSET'
                        ),
        rack            ENUM (
                                'IBM',
                                'CAT5/6',
                                'CATV',
                                'FIBER',
                                'TELCO'
                        )               NOT NULL,
        prefix          CHAR(1)         NOT NULL,

        from_building   CHAR(8)         NOT NULL,
        from_wing       CHAR(1)         NOT NULL,
        from_floor      CHAR(2)         NOT NULL,
        from_closet     CHAR(1)         NOT NULL,
        from_rack       CHAR(1)         NOT NULL,
        from_panel      CHAR(1)         NOT NULL,
        from_x          CHAR(1)         NOT NULL,
        from_y          CHAR(1)         NOT NULL,

        to_building     CHAR(8),
        to_wing         CHAR(1),
        to_floor        CHAR(2),

        #
        # if destination is a closet
        #
        to_closet       CHAR(1),
        to_rack         CHAR(1),
        to_panel        CHAR(1),
        to_x            CHAR(1),
        to_y            CHAR(1),

        #
        # if destination is an outlet
        #
        to_floor_plan_x CHAR(2),
        to_floor_plan_y CHAR(2),
        to_outlet_number CHAR(1),
        to_room_number  CHAR(32),
        
        PRIMARY KEY     index_id        (id),
        KEY             index_lfrom     (label_from),
        KEY             index_lto       (label_to),
	KEY		label_from	(label_from,label_to,id),
	KEY		label_to	(label_to,label_from,id,version)
) Type=InnoDB;

#
# outlet type table
#
CREATE TABLE outlet_type (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(64)        NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name)
) Type=InnoDB;

#
# outlet table
#
CREATE TABLE outlet (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        type            INT             UNSIGNED NOT NULL,
        cable           INT             UNSIGNED NOT NULL,
        port            INT             NOT NULL,
        attributes      SET (
                                'activate',             # IN PROGRESS OF BEING ACTIVATED
                                'deactivate'            # IN PROGRESS OF BEING DEACTIVATED
                        )               NOT NULL,
        flags           SET (
                                'abuse',                
                                'suspend',
                                'permanent',            # THE OUTLET IS PERMANENTLY CONNECTED
                                'activated'             # THE OUTLET IS ACTIVATED FOR SOMEONE (ONLY USEFUL w/ PERMANENT)
                        )               NOT NULL,
        status          ENUM (
                                'enabled',              # THE DEVICE PORT IS ENABLED
                                'partitioned'           # THE DEVICE PORT IS DISABLED
                        )               NOT NULL,
        account         CHAR(32)        NOT NULL,
        comment_lvl9    CHAR(255)        NOT NULL,
        comment_lvl1    CHAR(255)        NOT NULL,
        comment_lvl5    CHAR(255)        NOT NULL,
        device          INT		UNSIGNED,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_cable     (cable),
        KEY             index_connect   (device,port),
	FOREIGN KEY	(cable)		REFERENCES cable(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT,
	FOREIGN KEY	(device)	REFERENCES machine(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT
) Type=InnoDB;

#
# oulet - subnet map table
#
CREATE TABLE outlet_subnet_membership (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        outlet          INT             UNSIGNED NOT NULL,
        subnet          INT             UNSIGNED NOT NULL,
        type            ENUM (
                                'primary',
                                'voice',
                                'other'
                        )               NOT NULL,
        trunk_type      ENUM (
                                '802.1Q',
                                'ISL',
                                'none'
                        )               NOT NULL,
        status          ENUM (
                                'request',
                                'active',
                                'delete',
                                'error',
                                'errordelete'
                        )               NOT NULL,
        PRIMARY KEY     index_id        (id),
        UNIQUE          index_membership        (outlet, subnet),
        KEY             index_type (outlet, subnet, type, trunk_type)
) Type=InnoDB;      

#
# outlet_vlan_membership
#

CREATE TABLE outlet_vlan_membership (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,

	outlet		INT UNSIGNED NOT NULL,
	vlan		INT UNSIGNED NOT NULL,

	type 		ENUM (
				'primary',
				'voice',
				'other'
			) 		NOT NULL,
	trunk_type 	ENUM (
				'802.1Q',
				'ISL',
				'none'
			) 		NOT NULL,

	status 		ENUM (
				'request',
				'active',
				'delete',
				'error',
				'errordelete',
				'novlan',
				'nodev'
			) 		NOT NULL,

	PRIMARY KEY  (id),
	UNIQUE KEY index_membership (outlet,vlan),
	KEY index_type (outlet,vlan,type,trunk_type)
) Type=InnoDB;


###########################################################################

#
# machine table
#
CREATE TABLE machine (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        mac_address     CHAR(12)        NOT NULL,
        host_name       CHAR(255)       NOT NULL,
        ip_address      INT             UNSIGNED NOT NULL,

        mode            ENUM (
                                'static',       # mac/host/ip valid only
                                'dynamic',      # mac valid only
                                'reserved',     # host/ip valid only
                                'broadcast',    # broadcast address
                                'pool',         # ip valid only
                                'base',
				'secondary'     # secondary of a machine
                        )               NOT NULL,

        flags           SET ( 'abuse', 'suspend',
			      'stolen', 'no_dnsfwd', 'no_dnsrev') NOT NULL,
	comment_lvl9    CHAR(255)        NOT NULL,
        account         CHAR(32)        NOT NULL,

        host_name_ttl   INT             UNSIGNED NOT NULL,
        ip_address_ttl  INT             UNSIGNED NOT NULL,

        host_name_zone  INT             UNSIGNED NOT NULL,
        ip_address_zone INT             UNSIGNED,
        ip_address_subnet INT           UNSIGNED NOT NULL,
        created         DATETIME        NOT NULL,
        expires         DATE            NOT NULL DEFAULT 0,
        comment_lvl1    CHAR(255)        NOT NULL,
        comment_lvl5    CHAR(255)        NOT NULL,
	lastseen	TIMESTAMP	DEFAULT 0,	
        PRIMARY KEY     index_id        (id),
        KEY             index_host_name (host_name),
        KEY             index_host_name_zone (host_name_zone),
        KEY             index_ip_address_zone (ip_address_zone),
        KEY             index_ip_address_subnet (ip_address_subnet),
        KEY             index_ip_address (ip_address),
        KEY             index_mac_address (mac_address),
        KEY             index_subnet_mac (ip_address_subnet,mac_address),

	FOREIGN KEY	(ip_address_zone)	REFERENCES dns_zone(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT,
	FOREIGN KEY	(host_name_zone)	REFERENCES dns_zone(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT,
	FOREIGN KEY	(ip_address_subnet)	REFERENCES subnet(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT
) Type=InnoDB;


CREATE TABLE network (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,       
        name            CHAR(64)        NOT NULL,
        subnet          INT             UNSIGNED NOT NULL,
        
        PRIMARY KEY     index_id        (id),
        KEY             index_subnet    (subnet)
) Type=InnoDB;

#
# subnet table
#
CREATE TABLE subnet (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(64)        NOT NULL,
        abbreviation    CHAR(16)        NOT NULL,
        base_address    INT             UNSIGNED NOT NULL,
        network_mask    INT             UNSIGNED NOT NULL,

        dynamic         ENUM (
                                'permit',       # permit unregistered dynamics
                                'restrict',     # permit registered dynamics
                                'disallow'      # do not permit dynamics
                        )               NOT NULL,
        expire_static   INT             UNSIGNED NOT NULL,
        expire_dynamic  INT             UNSIGNED NOT NULL,
        share           INT             UNSIGNED NOT NULL,
        flags           SET (
                                'no_dhcp',      # Dont provide DHCP service
                                'delegated',    # Subnet is delegated
				'prereg_subnet' # This is a preregistration subnet (on a subnet share)
                        ) NOT NULL DEFAULT '',
        default_mode    ENUM ('static', 'dynamic', 'reserved') NOT NULL DEFAULT 'static',
        purge_interval  INT             UNSIGNED NOT NULL DEFAULT '0',
        purge_notupd    INT             UNSIGNED NOT NULL DEFAULT '0',
        purge_notseen   INT             UNSIGNED NOT NULL DEFAULT '0',
        purge_explen    INT             UNSIGNED NOT NULL DEFAULT '0',
        purge_lastdone  DATETIME        NOT NULL DEFAULT '0',

        vlan            CHAR(8)         NOT NULL DEFAULT '',

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name),
        KEY             index_share     (share),
        UNIQUE          index_abbreviation (abbreviation)
) Type=InnoDB;

#
# subnet share table
#
CREATE TABLE subnet_share (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(64)        NOT NULL,
        abbreviation    CHAR(16)        NOT NULL,
        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name),
        UNIQUE          index_abbreviation (abbreviation)
) Type=InnoDB;

#
# subnet presence table
#
CREATE TABLE subnet_presence (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        subnet          INT             UNSIGNED NOT NULL,
        building        CHAR(8)         NOT NULL,
        
        PRIMARY KEY     index_id        (id),
        KEY             index_subnet    (subnet),
        KEY             index_building  (building),

        UNIQUE          index_nodup     (subnet,building),
	FOREIGN KEY	(building)	REFERENCES building(building)
			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;

#
# subnet domain table
#
CREATE TABLE subnet_domain (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        subnet          INT             UNSIGNED NOT NULL,
        domain          CHAR(252)       NOT NULL,

        PRIMARY KEY     index_id        (id),
        KEY             index_subnet    (subnet),
        KEY             index_domain    (domain),
        UNIQUE          index_nodup     (subnet,domain),
        KEY             id              (id,domain,subnet),
	FOREIGN KEY	(subnet)	REFERENCES	subnet(id)
			ON UPDATE CASCADE  ON DELETE CASCADE
#	,FOREIGN KEY	(domain)	REFERENCES	dns_zone(name)
#			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;

#
# subnet registration modes table
#
CREATE TABLE subnet_registration_modes (
	id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
	version		TIMESTAMP(14),
	subnet          INT             UNSIGNED NOT NULL,
	mode            ENUM('static','dynamic','reserved','broadcast','pool','base','secondary') NOT NULL,
	mac_address     ENUM('required','none') NOT NULL DEFAULT 'required',
	quota           INT(10)         UNSIGNED,

	PRIMARY KEY     index_id          (id),
	UNIQUE KEY      index_nodup       (subnet, mode, mac_address, quota),
	KEY             index_subnet_mode (subnet,mode),
        FOREIGN KEY     (subnet) REFERENCES subnet(id)
                        ON UPDATE CASCADE ON DELETE CASCADE
) TYPE=InnoDB;

#
# dhcp option type table
#
CREATE TABLE dhcp_option_type (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            VARCHAR(64)     NOT NULL,
        number          INT             UNSIGNED NOT NULL,
        format          VARCHAR(255)    NOT NULL,
        builtin         ENUM('Y','N')   NOT NULL default 'N',

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name),

        KEY             index_number    (number)
) Type=InnoDB;

#
# dhcp option table
#
CREATE TABLE dhcp_option (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        value           CHAR(255)       DEFAULT '' NOT NULL,
        type            ENUM('global','share','subnet','machine','service') NOT NULL,
        tid             INT             UNSIGNED NOT NULL,
        type_id         INT             UNSIGNED NOT NULL,


        PRIMARY KEY     index_id        (id),
        KEY             index_record    (type,tid),
        UNIQUE          index_nodup     (type_id,type,tid,value),
	FOREIGN KEY	(type_id)	REFERENCES	dhcp_option_type(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT
) Type=InnoDB;

#
# dns resource type table
#
CREATE TABLE dns_resource_type (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(8)         NOT NULL,
        format          CHAR(8)         NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name)
) Type=InnoDB;

#
# dns resource table
#
CREATE TABLE dns_resource (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            VARCHAR(255)    NOT NULL,
        ttl             INT             UNSIGNED NOT NULL,
        type            VARCHAR(8)      NOT NULL,
        rname           VARCHAR(255),   # CNAME, MX, NS, SRV
        rmetric0        INT             UNSIGNED,       # SRV, MX
        rmetric1        INT             UNSIGNED,       # SRV
        rport           INT             UNSIGNED,       # SRV
        text0           VARCHAR(255),                       # HINFO, TXT
        text1           VARCHAR(255),                       # HINFO
        name_zone       INT             UNSIGNED NOT NULL,
        owner_type      ENUM ('machine', 'dns_zone', 'service')    NOT NULL,
        owner_tid       INT             UNSIGNED NOT NULL,
        rname_tid       INT             UNSIGNED,

        PRIMARY KEY     index_id        (id),
        KEY             index_name      (name),
        KEY             index_rname     (rname),
        KEY             index_rname_tid (rname_tid),
        KEY             index_name_zone (name_zone),
	KEY		index_type	(type),
	FOREIGN KEY	(type)		REFERENCES dns_resource_type(name)
			ON UPDATE CASCADE  ON DELETE RESTRICT,
	FOREIGN KEY	(name_zone)	REFERENCES dns_zone(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT,
	
) Type=InnoDB;

#
# dns zone table
#
CREATE TABLE dns_zone (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            VARCHAR(255)    NOT NULL,
        soa_host        VARCHAR(255)    NOT NULL,
        soa_email       VARCHAR(255)    NOT NULL,
        soa_serial      INT             UNSIGNED NOT NULL,
        soa_refresh     INT             UNSIGNED DEFAULT '3600' NOT NULL,
        soa_retry       INT             UNSIGNED DEFAULT '900' NOT NULL,
        soa_expire      INT             UNSIGNED DEFAULT '2419200' NOT NULL,
        soa_minimum     INT             UNSIGNED DEFAULT '3600' NOT NULL,
        type            ENUM (
                                'fw-toplevel',          # forward-we SHOULD make a zone file from this
                                'rv-toplevel',          # reverse-dont allow people to put machines here
                                'fw-permissible',       # forward-domain is just allowed - dont make a zone file
                                'rv-permissible',       # reverse is permissible
                                'fw-delegated',         # forward is delegated
                                'rv-delegated'          # reverse is delegated
                                        ) DEFAULT NULL,
        last_update     datetime        NOT NULL,
        soa_default     INT             UNSIGNED DEFAULT '86400' NOT NULL,
        parent          INT             UNSIGNED NOT NULL,      # points to authoritative zone (may be itself)
        ddns_auth       TEXT            DEFAULT '',

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name),
        KEY             id              (id,name),
        KEY             name            (name,id)
) Type=InnoDB;

#
# service
#

CREATE TABLE service (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(64)        NOT NULL,               # string name for this service (i.e. 'Cyrus')
        type            INT             UNSIGNED NOT NULL,      # points to service_type
        description     CHAR(255)       NOT NULL,

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name)
) Type=InnoDB;
        

#
# service_type
#

CREATE TABLE service_type (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            CHAR(255)       NOT NULL,       # Service type (i.e. 'LB Pool')

        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name)
) Type=InnoDB;

#
# service_membership
#

CREATE TABLE service_membership (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        service         INT             UNSIGNED NOT NULL,      
        member_type     ENUM ('activation_queue',
                              'building',
                              'cable',
			      'credentials',
                              'dns_zone',
                              'groups',
                              'machine',
                              'outlet',
                              'outlet_type',
                              'service',
                              'subnet',
                              'subnet_share',
			      'vlan' ) NOT NULL,
        member_tid      INT             UNSIGNED NOT NULL,
        
        PRIMARY KEY     index_id        (id),
        UNIQUE          index_members (member_type, member_tid, service),
	KEY		index_service	(service),
	FOREIGN KEY	(service)	REFERENCES service(id)
			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;

#
# attribute_spec
#
CREATE TABLE attribute_spec (
        version         TIMESTAMP(14),
        id              INT             UNSIGNED NOT NULL AUTO_INCREMENT,
        name            VARCHAR(255)    NOT NULL,
        format          TEXT            NOT NULL,
        scope           ENUM('users',
                             'groups',
                             'service_membership',
                             'service',
                             'outlet',
                             'vlan',
                             'subnet') NOT NULL,
        type            INT             UNSIGNED NOT NULL,
        ntimes          SMALLINT        UNSIGNED NOT NULL,
        description     VARCHAR(255)    NOT NULL,
        
        PRIMARY KEY     index_id        (id),
        UNIQUE          index_name      (name, type, scope),
        KEY             index_type      (type)
) Type=InnoDB;

#
# attribute
#
CREATE TABLE attribute (
        version           TIMESTAMP(14),
        id                INT                UNSIGNED NOT NULL AUTO_INCREMENT,
        spec              INT                UNSIGNED NOT NULL,
        owner_table       ENUM('users',
                               'groups',
                               'service_membership',
                               'service',
                               'outlet',
                               'vlan',
                               'subnet')    NOT NULL,
        owner_tid         INT                UNSIGNED NOT NULL,
        data              TEXT,

        PRIMARY KEY       index_id        (id),
        KEY               index_spec (spec),
        KEY               index_owner (owner_tid),
	FOREIGN KEY	  (spec)	REFERENCES	attribute_spec(id)
 			  ON UPDATE CASCADE  ON DELETE RESTRICT
) Type=InnoDB;
        
#
# trunk_set
#

CREATE TABLE trunk_set (
  	id		INT 	UNSIGNED NOT NULL AUTO_INCREMENT,
	version		TIMESTAMP(14) NOT NULL,

	name		CHAR(255) NOT NULL,
	abbreviation	CHAR(127) NOT NULL,
	description	CHAR(255) NOT NULL,
	primary_vlan	INT NOT NULL,

  	PRIMARY KEY  	index_id	(id),
	UNIQUE 		index_name (name)
) Type=InnoDB;

#
# trunkset_building_presence
#
CREATE TABLE trunkset_building_presence (
	id 		INT	UNSIGNED NOT NULL AUTO_INCREMENT,
	version		TIMESTAMP(14) NOT NULL,

  	trunk_set	INT UNSIGNED NOT NULL,
	buildings	INT UNSIGNED NOT NULL,

	PRIMARY KEY  (id),
	UNIQUE KEY index_nodup (trunk_set,buildings),
  	KEY index_trunkset (trunk_set),
	KEY index_building (buildings),
	FOREIGN KEY	(buildings)	REFERENCES building(id)
			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;

#
# trunkset_machine_presence
#
CREATE TABLE trunkset_machine_presence (
  	id		INT	UNSIGNED NOT NULL AUTO_INCREMENT,
  	version 	TIMESTAMP(14) NOT NULL,

	device		INT UNSIGNED NOT NULL,
	trunk_set 	INT UNSIGNED NOT NULL,
        last_update     DATETIME NOT NULL default '0000-00-00 00:00:00',

	PRIMARY KEY  (id),
	UNIQUE KEY index_nodup (trunk_set,device),
	KEY index_trunkset (trunk_set),
	KEY index_vlan (device),
	FOREIGN KEY	(device)	REFERENCES	machine(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT,
	FOREIGN KEY	(trunk_set)	REFERENCES	trunk_set(id)
			ON UPDATE CASCADE  ON DELETE RESTRICT
) Type=InnoDB;


#
# trunkset_vlan_presence
#

CREATE TABLE trunkset_vlan_presence (
	id 		INT UNSIGNED NOT NULL AUTO_INCREMENT,
	version		TIMESTAMP(14) NOT NULL,

	trunk_set 	INT UNSIGNED NOT NULL,
	vlan		INT UNSIGNED NOT NULL,

	PRIMARY KEY  (id),
	UNIQUE KEY index_nodup (trunk_set,vlan),
	KEY index_trunkset (trunk_set),
	KEY index_vlan (vlan),
	FOREIGN KEY	(vlan)		REFERENCES vlan(id)
			ON UPDATE CASCADE  ON DELETE CASCADE,
	FOREIGN KEY	(trunk_set)	REFERENCES trunk_set(id)
			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;


#
# vlan
#
CREATE TABLE vlan (
	version		TIMESTAMP(14) NOT NULL,
	id 		INT UNSIGNED NOT NULL AUTO_INCREMENT,

	name 		CHAR(64) NOT NULL,
	abbreviation 	CHAR(16) NOT NULL,
	number 		INT NOT NULL,
	description 	CHAR(255) NOT NULL,

	PRIMARY KEY  (id),
	UNIQUE KEY index_name (name)
) Type=InnoDB;

#
# vlan_presence
#
CREATE TABLE vlan_presence (
	version		TIMESTAMP(14) NOT NULL,
	id 		INT UNSIGNED NOT NULL AUTO_INCREMENT,

	vlan 		INT UNSIGNED NOT NULL,
	building	CHAR(8) NOT NULL,

	PRIMARY KEY  (id),
	UNIQUE KEY index_nodup (vlan,building),
	KEY index_vlan (vlan),
	KEY index_building (building),
	FOREIGN KEY	(building)	REFERENCES building(building)
			ON UPDATE CASCADE  ON DELETE CASCADE,
	FOREIGN KEY	(vlan)		REFERENCES vlan(id)
			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;


#
# vlan_subnet_presence
#
CREATE TABLE vlan_subnet_presence (
	version		TIMESTAMP(14) NOT NULL,
	id 		INT UNSIGNED NOT NULL AUTO_INCREMENT,

	subnet		INT UNSIGNED NOT NULL,
	subnet_share	INT UNSIGNED NOT NULL,
	vlan		INT UNSIGNED NOT NULL,

	PRIMARY KEY  (id),
	UNIQUE KEY index_nodup (subnet,vlan),
	KEY index_trunkset (subnet),
	KEY index_vlan (vlan),
	FOREIGN KEY	(subnet)	REFERENCES subnet(id)
			ON UPDATE CASCADE  ON DELETE CASCADE,
	FOREIGN KEY 	(vlan)		REFERENCES vlan(id)
			ON UPDATE CASCADE  ON DELETE CASCADE
) Type=InnoDB;

 
