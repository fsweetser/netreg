#   -*- perl -*-
#
# CMU::Netdb::structure
# This module defines the structure of the database
# ALL modules should refer to this to get information about
# the database structure, or to verify data CMU::Netdb::validity.  (i.e. text
# where text should be, ints where ints should be)
#
# Copyright 2001-2004 Carnegie Mellon University
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
# $Id: structure.pm,v 1.108 2008/03/27 19:42:35 vitroth Exp $
#
#

package CMU::Netdb::structure;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug

	    %cascades %multirefs

	    @users_fields @groups_fields @memberships_fields
	    @credentials_fields @protections_fields @dns_zone_fields
	    @dns_resource_type_fields @dns_resource_fields
	    @dhcp_option_fields @dhcp_option_type_fields
	    @subnet_domain_zone_fields
	    @subnet_domain_fields @domain_subnet_fields
	    @service_member_types
	    @service_fields @service_type_fields @service_membership_fields
	    @subnet_presence_fields @subnet_share_fields
	    @subnet_fields @machine_fields @outlet_fields
	    @output_type_fields @cable_fields @building_fields
	    @outlet_cable_fields @outlet_cable_host_fields 
	    @outlet_type_fields @outlet_machine_fields @network_fields
	    @vlan_fields @vlan_presence_fields
	    @sys_scheduled_fields @error_fields @activation_q_fields
	    @trunkset @trunk_set_fields

	    @trunkset_building_presence_fields
	    @trunkset_building_presence_ts_building_fields
	    @trunkset_vlan_presence_fields
	    @trunkset_vlan_presence_ts_vlan_fields
	    @trunkset_machine_presence_fields
	    @trunkset_machine_presence_ts_machine_fields

	    @outlet_vlan_membership_fields @vlan_subnet_presence_fields
	    @vlan_subnet_presence_subnetvlan_fields @sys_changerec_row_type

	    @activation_queue_fields

	    %users_printable %groups_printable %credentials_printable
	    %dhcp_option_printable
	    @subnet_registration_modes_fields

	    %subnet_printable %subnet_presence_printable
	    %outlet_printable @outlet_cable_fields @outlet_cable_host_fields
	    %outlet_cable_printable %outlet_cable_host_printable
 	    %subnet_domain_printable
	    %domain_subnet_printable
	    %building_printable %cable_printable %outlet_machine_printable
	    %subnet_share_printable %machine_printable
	    %outlet_printable %outlet_cable_printable %outlet_cable_host_printable
	    %dns_zone_printable %dns_resource_type_printable
	    %dns_resource_printable %outlet_type_printable
	    %service_printable %service_type_printable
	    @attribute_fields %attribute_printable
	    @attribute_owners @attribute_spec_fields
	    %attribute_spec_printable @attribute_spec_scope
	    %attr_spec_scope_pr %vlan_printable %vlan_presence_printable
	    %network_printable %sys_scheduled_printable
	    %activation_q_printable %service_member_type_fields
	    %AllocationMethods
	    %trunk_set_printable
	    %trunkset_building_presence_printable
	    %trunkset_building_presence_ts_building_printable

	    %trunkset_vlan_presence_printable
	    %trunkset_vlan_presence_ts_vlan_printable
	    %trunkset_machine_presence_printable
	    %trunkset_machine_presence_ts_machine_printable
	    %outlet_vlan_membership_printable %vlan_subnet_presence_printable
	    %vlan_subnet_presence_subnetvlan_printable
	    %activation_queue_printable %memberships_printable
	    %service_membership_printable %dhcp_option_type_printable
	    %protections_printable
	    %subnet_registration_modes_printable

	    @subnet_dynamic
	    @subnet_registration_modes_modes @subnet_registration_modes_mac_address
	    @subnet_default_mode @users_flags @groups_flags %groups_flags_pr
	    @machine_flags @outlet_attributes @outlet_status
	    @outlet_flags @dns_type_formats
	    @valid_tables @valid_perms %perm_map @dns_zone_types
	    @cable_type @cable_rack @subnet_flags @dhcp_option_types
	    @dns_resource_owner_types @dns_resource_mach_types
	    @dns_resource_service_types
	    @dns_resource_zone_types 
	    @archive_tables

	    @outlet_vlan_membership_type
	    @outlet_vlan_membership_status @outlet_vlan_membership_trunk_type

	    %restricted_access_fields

	    @history_fields
	    %history_fields_printable
            @user_type_fields
            %user_type_printable
            @user_type_flags

	   );

use CMU::Netdb;

require Exporter;
@ISA = qw(Exporter);

#@EXPORT = qw/valid_tables/;
@users_fields = qw/users.id users.version users.flags users.comment users.default_group/;

%users_printable = ('users.id' => 'ID',
		    'users.flags' => 'Flags',
		    'users.comment' => 'Administrative Comment',
		    'users.version' => 'Version',
		    'users.default_group' => 'Default Group');
@users_flags = qw/abuse suspend/;

@credentials_fields = qw/credentials.id credentials.version credentials.user
			 credentials.authid credentials.description credentials.type/;

%credentials_printable = ('credentials.id' => 'Creds ID',
			  'credentials.version' => 'Creds Version',
			  'credentials.authid' => 'Authentication Identity',
			  'credentials.user' => 'User ID',
			  'credentials.description' => 'Full Name',
              'credentials.type' => 'Credential Type'
            );

@user_type_fields = qw/user_type.id user_type.version user_type.name
            user_type.expire_days_mach user_type.expire_days_outlet
            user_type.flags/;

%user_type_printable = (
            'user_type.id' => 'User Types ID',
            'user_type.version' => 'User Types Version',
            'user_type.name' => 'User Type',
            'user_type.expire_days_mach' => 'Machine Expire in Days',
            'user_type.expire_days_outlet' => 'Outlet Expire in Days',
            'user_type.flags' => 'Flags');

@user_type_flags = qw/send_email_mach send_email_outlet disable_acct/;

@groups_fields = ("groups.id", "groups.name", "groups.flags", 
		  "groups.comment_lvl9", "groups.comment_lvl5", 
		  "groups.version", 'groups.description');

%groups_printable = ('groups.id' => 'ID',
		     'groups.name' => 'Group ID',
		     'groups.flags' => 'Flags',
		     'groups.description' => 'Group Name',
		     'groups.comment_lvl9' => 'Administrative Comment',
		     'groups.comment_lvl5' => 'Department Comment',
		     'groups.version' => 'Version');

@groups_flags = ('abuse', 'suspend', 'purge_mailusers');
%groups_flags_pr = ('abuse' => 'Abuse',
		    'suspend' => 'Suspend',
		    'purge_mailusers' => 'Mail Users of Purge');

@protections_fields = ("protections.id", "protections.identity", 
		       "protections.tname", "protections.tid", 
		       "protections.rights", "protections.version",
		       'protections.rlevel');

%protections_printable = ('protections.id' => 'Protections ID',
			  'protections.version' => 'Lats Update',
			  'protections.identity' => 'Identity',
			  'protections.tname' => 'Table',
			  'protections.tid' => 'Table ID',
			  'protections.rights' => 'Rights',
			  'protections.rlevel' => 'Rights Level');

@memberships_fields = ("memberships.id", "memberships.uid", "memberships.gid",
		       "memberships.version");

%memberships_printable = ('memberships.id' => 'Memberships ID',
			  'memberships.version' => 'Last Updated',
			  'memberships.uid' => 'User ID',
			  'memberships.gid' => 'Group ID');

@dns_zone_fields = ("dns_zone.id","dns_zone.name","dns_zone.soa_host",
		    "dns_zone.soa_email","dns_zone.soa_serial",
		    "dns_zone.soa_refresh","dns_zone.soa_retry",
		    "dns_zone.soa_expire","dns_zone.soa_minimum",
		    "dns_zone.version",'dns_zone.type', 'dns_zone.last_update',
		    'dns_zone.soa_default', 'dns_zone.parent', 
		    'dns_zone.ddns_auth');

@dns_zone_types = qw/fw-toplevel rv-toplevel fw-permissible rv-permissible 
  fw-delegated rv-delegated/;
@dns_resource_owner_types = ('machine', 'dns_zone', 'service');

%dns_zone_printable = ('dns_zone.name' => 'Name',
		       'dns_zone.soa_host' => 'Host',
		       'dns_zone.soa_email' => 'Email',
		       'dns_zone.soa_serial' => 'Serial',
		       'dns_zone.soa_refresh' => 'Refresh',
		       'dns_zone.soa_retry' => 'Retry',
		       'dns_zone.soa_expire' => 'Expire',
		       'dns_zone.soa_minimum' => 'Minimum',
		       'dns_zone.soa_default' => 'Default',
		       'dns_zone.parent' => 'Parent Zone',
		       'dns_zone.type' => 'Type',
		       'dns_zone.ddns_auth' => 'DDNS Authorization',
		       'dns_zone.id' => 'DNS Zone ID',
		       'dns_zone.version' => 'Last Updated',
		       'dns_zone.last_update' => 'Last Update');

@dns_resource_fields = ("dns_resource.id","dns_resource.name",
			"dns_resource.ttl", "dns_resource.type",
			"dns_resource.rname","dns_resource.rmetric0",
			"dns_resource.rmetric1","dns_resource.rport",
			"dns_resource.text0","dns_resource.text1",
			"dns_resource.name_zone","dns_resource.version",
			'dns_resource.owner_type','dns_resource.owner_tid',
			'dns_resource.rname_tid');

%dns_resource_printable = ('dns_resource.name' => 'Resource Name',
			   'dns_resource.ttl' => 'TTL',
			   'dns_resource.type' => 'Resource Type',
			   'dns_resource.rname' => 'Hostname #1',
			   'dns_resource.rmetric0' => 'Metric #0',
			   'dns_resource.rmetric1' => 'Metric #1',
			   'dns_resource.rport' => 'Port',
			   'dns_resource.text0' => 'Text 0',
			   'dns_resource.text1' => 'Text 1',
			   'dns_resource.owner_type' => 'Owner Type',
			   'dns_resource.owner_tid' => 'Owner ID',
			   'dns_resource.version' => 'Last Updated',
			   'dns_resource.id' => 'DNS Resource ID',
			   'dns_resource.name_zone' => 'Resource Zone',
			   'dns_resource.rname_tid' => 'Resource Name ID Ref');

@dns_resource_zone_types = qw/MX NS AFSDB AAAA LOC TXT/;
@dns_resource_mach_types = qw/CNAME MX HINFO SRV TXT ANAME AFSDB SRV AAAA LOC RP/;
@dns_resource_service_types = qw/CNAME MX HINFO SRV TXT ANAME AFSDB SRV AAAA LOC RP/;

@dns_resource_type_fields = ("dns_resource_type.id","dns_resource_type.name",
			     "dns_resource_type.format",
			     "dns_resource_type.version");

%dns_resource_type_printable = 
  ('dns_resource_type.name' => 'Type Name',
   'dns_resource_type.format' => 'Resource Format',
  'dns_resource_type.id' => 'DNS Resource Type ID',
  'dns_resource_type.version' => 'Last Updated');


@dns_type_formats = ('N', 'NM0', 'T0', 'NM0M1P', 'T0T1');
@service_fields = ('service.id', 'service.name', 'service.description', 
		   'service.type', 'service.version');

%service_printable = ('service.name' => 'Service Name',
		      'service.description' => 'Service Description',
		      'service.id' => 'Service ID',
		      'service.version' => 'Last Updated',
		      'service.type' => 'Service Type');

@service_type_fields = 
  ('service_type.id', 'service_type.name', 'service_type.version');

%service_type_printable = ('service_type.name' => 'Service Type',
			   'service_type.version' => 'Last Updated',
			   'service_type.id' => 'Service Type ID');

@service_membership_fields = ('service_membership.id', 
			      'service_membership.member_type', 
			      'service_membership.member_tid',
			      'service_membership.service', 
			      'service_membership.version');
%service_membership_printable = 
  ('service_membership.id' => 'Service Membership ID',
   'service_membership.version' => 'Last Updated',
   'service_membership.member_type' => 'Member Type',
   'service_membership.member_tid' => 'Member ID',
   'service_membership.service' => 'Service ID',
  );

@service_member_types = 
  qw/activation_queue building cable dns_zone
  groups machine outlet outlet_type service subnet subnet_share trunk_set users vlan/;

%service_member_type_fields = 
  ('activation_queue' => 'activation_queue.name',
   'building' => 'building.name',
   'cable' => 'cable.id',
   'credentials' => 'credentials.authid',
   'dns_zone' => 'dns_zone.name',
   'groups' => 'groups.name',
   'machine' => 'machine.host_name',
   'outlet' => 'outlet.id',
   'outlet_type' => 'outlet_type.name',
   'service' => 'service.name',
   'subnet' => 'subnet.name',
   'subnet_share' => 'subnet_share.name',
   'trunk_set' => 'trunk_set.name',
   'vlan' => 'vlan.name');

@attribute_fields = ('attribute.id', 'attribute.version',
		     'attribute.spec', 'attribute.owner_table',
		     'attribute.owner_tid', 'attribute.data');

%attribute_printable = ('attribute.version' => 'Last Updated',
			'attribute.spec' => 'Attribute Specification',
			'attribute.owner_table' => 'Owner Table',
			'attribute.owner_tid' => 'Owner ID',
			'attribute.data' => 'Attribute Data',
			'attribute.id' => 'Attribute ID');

@attribute_owners = qw/service_membership service users groups outlet vlan subnet machine/;
@attribute_spec_fields = ('attribute_spec.id', 
			  'attribute_spec.version',
			  'attribute_spec.name',
			  'attribute_spec.format',
			  'attribute_spec.scope',
			  'attribute_spec.type',
			  'attribute_spec.description',
			  'attribute_spec.ntimes');

%attribute_spec_printable = ('attribute_spec.version' => 'Last Updated',
			     'attribute_spec.name' => 'Attribute Name',
			     'attribute_spec.format' => 'Data Format',
			     'attribute_spec.scope' => 'Scope',
			     'attribute_spec.type' => 'Service Type',
			     'attribute_spec.description' => 'Description',
			     'attribute_spec.ntimes' => 'MaxN',
			     'attribute_spec.id' => 'Attribute Spec ID');

@attribute_spec_scope = qw/service_membership service users groups outlet vlan subnet machine/;
%attr_spec_scope_pr = ('service_membership' => 'Service Member',
		       'service' => 'Service',
		       'users' => 'Users',
		       'groups' => 'Groups',
		       'outlet' => 'Outlets',
		       'vlan' => 'Vlan',
		       'subnet' => 'Subnet',
		       'machine' => 'Machine',
		      );

@dhcp_option_fields = 
  ("dhcp_option.id","dhcp_option.type_id","dhcp_option.value",
   "dhcp_option.type", "dhcp_option.tid", "dhcp_option.version");

@dhcp_option_types = qw/global subnet machine service share/;
%dhcp_option_printable = ('dhcp_option.id' => 'ID',
			  'dhcp_option.type_id' => 'Option Type',
			  'dhcp_option.value' => 'Option Value',
			  'dhcp_option.type' => 'Option Scope',
			  'dhcp_option.tid' => 'Table ID',
			  'dhcp_option.version' => 'Version',
			  'dhcp_option_type.name' => 'Option Type Name',
			  'dhcp_option_type.number' => 'Option Number',
			  'dhcp_option_type.format' => 'Format',
			  'dhcp_option_type.builtin' => 'Built-In Option');

@dhcp_option_type_fields = 
  ("dhcp_option_type.id","dhcp_option_type.name", 
   "dhcp_option_type.number","dhcp_option_type.format",
   "dhcp_option_type.version", "dhcp_option_type.builtin");

%dhcp_option_type_printable = 
  ('dhcp_option_type.id' => 'DHCP Option Type ID',
   'dhcp_option_type.version' => 'Last Updated',
   'dhcp_option_type.name' => 'Option Type Name',
   'dhcp_option_type.number' => 'Option Number',
   'dhcp_option_type.format' => 'Format',
   'dhcp_option_type.builtin' => 'Built-In Option');

@subnet_domain_zone_fields = ("subnet_domain.id","subnet_domain.subnet",
                              "subnet_domain.domain","subnet_domain.version",
                              "dns_zone.id");

@subnet_domain_fields = ("subnet_domain.id","subnet_domain.subnet", 
			 "subnet_domain.domain","subnet_domain.version");

%subnet_domain_printable = ('subnet_domain.id' => 'ID',
			    'subnet_domain.subnet' => 'Subnet',
			    'subnet_domain.domain' => 'Domain',
			    'subnet_domain.version' => 'Version');

@domain_subnet_fields = ("subnet_domain.id","subnet_domain.version",
                         "subnet.name","subnet.abbreviation", "subnet.id");

%domain_subnet_printable = ('subnet_domain.id', => 'ID',
                            'subnet_domain.version' => 'Version',
                            'subnet.name' => 'Subnet',
                            'subnet.abbreviation' => 'Abbreviation');

@subnet_presence_fields = 
  ("subnet_presence.id","subnet_presence.subnet",
   "subnet_presence.building","subnet_presence.version", 
   'building.name', 'subnet.name');

%subnet_presence_printable = ("subnet_presence.id" => 'ID',
			      "subnet_presence.subnet" => 'Subnet',
			      "subnet_presence.building" => 'Building',
			      "subnet_presence.version" => 'Version',
			      'building.name' => 'Building Name',
			      'subnet.name' => 'Subnet Name');

@subnet_share_fields = 
  ("subnet_share.id","subnet_share.name",
   "subnet_share.abbreviation","subnet_share.version");

%subnet_share_printable = ('subnet_share.name' => 'Share Name',
			   'subnet_share.abbreviation' => 'Share Abbreviation',
			   'subnet_share.id' => 'Subnet Share ID',
			   'subnet_share.version' => 'Last Updated');
@subnet_fields = 
  ("subnet.id","subnet.name","subnet.abbreviation","subnet.base_address",
   "subnet.network_mask","subnet.dynamic","subnet.expire_static",
   "subnet.expire_dynamic","subnet.share","subnet.flags","subnet.version",
   "subnet.default_mode",
   "subnet.purge_interval", "subnet.purge_notupd", "subnet.purge_notseen",
   "subnet.purge_explen", "subnet.purge_lastdone");

@subnet_flags = qw/no_dhcp delegated prereg_subnet/;
@subnet_dynamic = ('permit', 'restrict', 'disallow');
@subnet_default_mode = ('static', 'dynamic', 'reserved');

%subnet_printable = 
  ('subnet.id' => 'ID', 
   'subnet.name' => 'Subnet Name',
   'subnet.abbreviation' => 'Abbreviation',
   'subnet.base_address' => 'Base Address',
   'subnet.network_mask' => 'Network Mask',
   'subnet.dynamic' => 'Dynamics',
   'subnet.expire_static' => 'Expire static',
   'subnet.expire_dynamic' => 'Expire dynamic',
   'subnet.default_mode' => 'Default Mode',
   'subnet.share' => 'Subnet Share',
   'subnet.flags' => 'Flags',
   'subnet.version' => 'Last Updated',
   'subnet.purge_interval' => 'Purge Interval',
   'subnet.purge_notupd' => 'Purge Exclusion for Record Update',
   'subnet.purge_notseen' => 'Purge Exclusion for Network Use',
   'subnet.purge_explen' => 'Purge Expiration Time',
   'subnet.purge_lastdone' => 'Last Purge Time',
  );

@subnet_registration_modes_fields = 
  ('subnet_registration_modes.id','subnet_registration_modes.version','subnet_registration_modes.subnet','subnet_registration_modes.mode','subnet_registration_modes.mac_address','subnet_registration_modes.quota');

@subnet_registration_modes_modes = ('static', 'dynamic', 'reserved','broadcast','pool','base','secondary');
@subnet_registration_modes_mac_address = ('required','none');

%subnet_registration_modes_printable =
  ('subnet_registration_modes.mode' => 'Machine Registration Mode',
   'subnet_registration_modes.mac_address' => 'Machine Mac Address Requirement',
   'subnet_registration_modes.quota' => 'Registration Quota');

@network_fields = qw/network.id network.version network.name network.subnet/;
%network_printable = ('network.id' => 'ID',
		      'network.version' => 'Version',
		      'network.name' => 'Network Name',
		      'network.subnet' => 'Network Subnet');

@machine_fields = 
  ("machine.id","machine.mac_address","machine.host_name",
   "machine.ip_address","machine.mode","machine.flags",
   "machine.comment_lvl1","machine.comment_lvl5","machine.comment_lvl9",
   "machine.account","machine.host_name_ttl","machine.ip_address_ttl",
   "machine.host_name_zone","machine.ip_address_zone",
   "machine.ip_address_subnet","machine.version", 'machine.created', 
   'machine.expires');

%machine_printable = ('machine.host_name' => 'Hostname',
		      'machine.mac_address' => 'Hardware Address',
		      'machine.ip_address' => 'IP Address',
		      'machine.flags' => 'Flags',
		      'machine.mode' => 'Mode',
		      'machine.comment_lvl1' => 'User Comment',
		      'machine.comment_lvl5' => 'Department Comment',
		      'machine.comment_lvl9' => 'Administrative Comment',
		      'machine.host_name_ttl' => 'Hostname TTL',
		      'machine.ip_address_ttl' => 'IP Address TTL',
		      'machine.ip_address_subnet' => 'Subnet',
		      'machine.ip_address_zone' => 'IP Address Zone',
		      'machine.host_name_zone' => 'Hostname Zone',
		      'machine.created' => 'Created',
		      'machine.expires' => 'Expires',
		      'machine.version' => 'Last Updated',
		      'machine.id' => 'Machine ID',
		      'machine.account' => 'Account');

@building_fields = qw/building.id building.name building.abbreviation 
  building.building building.version building.activation_queue/;

%building_printable = ('building.name' => 'Name',
		       'building.abbreviation' => 'Abbreviation',
		       'building.building' => 'Building Number',
		       'building.activation_queue' => 'Activation Queue',
		       'building.id' => 'Building ID',
		      'building.version' => 'Last Updated');

@machine_flags = ('abuse', 'suspend', 'stolen', 'no_dnsfwd', 'no_dnsrev');
@outlet_fields = ("outlet.id", "outlet.type", "outlet.cable",
		  "outlet.device","outlet.port","outlet.attributes",
		  "outlet.flags","outlet.status","outlet.account",
		  "outlet.comment_lvl9","outlet.comment_lvl5",
		  "outlet.comment_lvl1","outlet.version","outlet.expires");

%outlet_printable = ('outlet.id' => 'ID',
		     'outlet.version' => 'Last Updated',
		     'outlet.account' => 'Account',
		     'outlet.type' => 'Type',
		     'outlet.cable' => 'Cable',
		     'outlet.device' => 'Device',
		     'outlet.port' => 'Port',
		     'outlet.attributes' => 'Attributes',
		     'outlet.flags' => 'Flags',
		     'outlet.status' => 'Status',
		     'outlet.comment_lvl9' => 'Administrative Comment',
		     'outlet.comment_lvl5' => 'Department Comment',
		     'outlet.comment_lvl1' => 'User Comment',
             'outlet.expires' => 'Expires'
		    );

@outlet_attributes = ("activate", "deactivate", "change");
@outlet_flags = qw/abuse suspend permanent activated/;
@outlet_status = qw/enabled partitioned/;

@outlet_type_fields = ("outlet_type.id","outlet_type.name",
		       "outlet_type.version");

%outlet_type_printable = ('outlet_type.name' => 'Type Name',
			  'outlet_type.id' => 'Outlet Type ID',
			  'outlet_type.version' => 'Last Updated');

@outlet_vlan_membership_fields = ('outlet_vlan_membership.id', 'outlet_vlan_membership.version',
				  'outlet_vlan_membership.outlet', 'outlet_vlan_membership.vlan',
				  'outlet_vlan_membership.type', 'outlet_vlan_membership.trunk_type',
				  'outlet_vlan_membership.status');
%outlet_vlan_membership_printable = ('outlet_vlan_membership.type' => "VLAN Type", 
				     'outlet_vlan_membership.trunk_type' => "VLAN Trunk-Type",
				     'outlet_vlan_membership.status' => "Current Status",
				     'outlet_vlan_membership.id' => "ID",
				     'outlet_vlan_membership.version' => "Last Update",
				     'outlet_vlan_membership.outlet' => "Outlet",
				     'outlet_vlan_membership.vlan' => "Vlan",
				     );
@outlet_vlan_membership_type = ('primary','other','voice');
@outlet_vlan_membership_trunk_type = ('802.1Q','ISL','none');
@outlet_vlan_membership_status = ('request','active','delete',
				    'error', 'errordelete', 'novlan', 'nodev');

#@activation_queue_fields = qw/activation_queue.id activation_queue.version
#			      activation_queue.name/;
#%activation_queue_printable = ('activation_queue.id' => 'Activation Queue ID',
#			       'activation_queue.version' => 'Version',
#			       'activation_queue.name' => 'Activation Queue Name');

@cable_fields = 
  ("cable.id","cable.label_from","cable.label_to","cable.type",
   "cable.destination","cable.rack","cable.prefix","cable.from_building",
   "cable.from_wing","cable.from_floor","cable.from_closet",
   "cable.from_rack","cable.from_panel","cable.from_x","cable.from_y",
   "cable.to_building","cable.to_wing","cable.to_floor","cable.to_closet",
   "cable.to_rack","cable.to_panel","cable.to_x","cable.to_y",
   "cable.to_floor_plan_x","cable.to_floor_plan_y",
   "cable.to_outlet_number","cable.to_room_number","cable.version");

%cable_printable = ('cable.id' => 'Cable ID',
		    'cable.label_from' => 'From',
		    'cable.label_to' => 'To',
		    'cable.type' => 'Type',
		    'cable.destination' => 'Dest',
		    'cable.rack' => 'Rack',
		    'cable.prefix' => 'Prefix',
		    'cable.from_building' => "From Building",
		    'cable.from_wing' => 'From Wing',
		    'cable.from_floor' => 'From Floor',
		    'cable.from_closet' => 'From Closet',
		    'cable.from_rack' => 'From Rack',
		    'cable.from_panel' => 'From Panel',
		    'cable.from_x' => 'From X',
		    'cable.from_y' => 'From Y',
		    'cable.to_building' => 'To Building',
		    'cable.to_wing' => 'To Wing',
		    'cable.to_floor' => 'To Floor',
		    'cable.to_closet' => 'To Closet',
		    'cable.to_rack' => 'To Rack',
		    'cable.to_panel' => 'To Panel',
		    'cable.to_x' => 'To X',
		    'cable.to_y' => 'To Y',
		    'cable.to_floor_plan_x' => 'To Floor Plan X',
		    'cable.to_floor_plan_y' => 'To Floor Plan Y',
		    'cable.to_outlet_number' => 'To Outlet Number',
		    'cable.to_room_number' => 'To Room Number',
		    'cable.version' => 'Version');

@cable_type = qw/TYPE1 TYPE2 CAT5 CAT6 CAT5-TELCO CATV SMF0080
  MMF0500 MMF0625 MMF1000/;

@cable_rack = ('IBM', 'CAT5/6', 'CATV', 'FIBER', 'TELCO');

@outlet_cable_fields = (@outlet_fields, @cable_fields, @building_fields);

@outlet_machine_fields = 
  (@outlet_fields, @trunkset_machine_presence_fields, @machine_fields);

%outlet_machine_printable = ('outlet.id' => 'Id',
			   'outlet.version' => 'Date',
			   'outlet.type' => 'Type',
			   'outlet.cable' => 'Cable',
			   'outlet.device' => 'Device',
			   'outlet.port' => 'Port',
			   'outlet.attributes' => 'Attributes',
			   'outlet.flags' => 'Flags',
			   'outlet.status' => 'Status',
			   'outlet.comment_lvl9' => 'Administrative Comment',
			   'outlet.comment_lvl5' => 'Department Comment',
			   'outlet.comment_lvl1' => 'User Comment');

@outlet_cable_host_fields = 
  ("outlet.id","outlet.type","outlet.cable","outlet.device",
   "outlet.port","outlet.attributes","outlet.flags","outlet.status",
   "outlet.comment_lvl9","outlet.comment_lvl5","outlet.comment_lvl1",
   "cable.label_from","cable.label_to","cable.to_building",
   "cable.to_room_number", "cable.id", "cable.to_floor", "outlet.version", 
   "machine.host_name", "trunkset_machine_presence.id");

%outlet_cable_printable = ('outlet.id' => 'Id',
			   'outlet.version' => 'Date',
			   'outlet.type' => 'Type',
			   'outlet.cable' => 'Cable',
			   'outlet.device' => 'Device',
			   'outlet.port' => 'Port',
			   'outlet.attributes' => 'Attributes',
			   'outlet.flags' => 'Flags',
			   'outlet.status' => 'Status',
			   'outlet.comment_lvl9' => 'Administrative Comment',
			   'outlet.comment_lvl5' => 'Department Comment',
			   'outlet.comment_lvl1' => 'User Comment',
			   'cable.to_floor' => 'Floor',
			   'cable.id' => 'Cable',
			   'cable.label_from' => 'From',
			   'cable.label_to' => 'To',
			   'cable.to_building' => 'Building',
			   'cable.to_room_number' => 'Room Number');

%outlet_cable_host_printable = ('outlet.id' => 'Id',
			   'outlet.version' => 'Date',
			   'outlet.type' => 'Type',
			   'outlet.cable' => 'Cable',
			   'outlet.device' => 'Device',
			   'outlet.port' => 'Port',
			   'outlet.attributes' => 'Attributes',
			   'outlet.flags' => 'Flags',
			   'outlet.status' => 'Status',
			   'outlet.comment_lvl9' => 'Administrative Comment',
			   'outlet.comment_lvl5' => 'Department Comment',
			   'outlet.comment_lvl1' => 'User Comment',
			   'cable.to_floor' => 'Floor',
			   'cable.id' => 'Cable',
			   'cable.label_from' => 'From',
			   'cable.label_to' => 'To',
			   'cable.to_building' => 'Building',
			   'cable.to_room_number' => 'Room Number',
			   'machine.host_name' => 'Device Name',
			   'trunkset_machine_presence.id' => 'Device Outlet');


@vlan_fields =
  ("vlan.version", "vlan.id", "vlan.name", "vlan.abbreviation", "vlan.number", "vlan.description");
%vlan_printable =
  ('vlan.version' => 'Date',
   'vlan.id' => 'ID',
   'vlan.name' => 'VLAN Name',
   'vlan.abbreviation' => 'Abbreviation',
   'vlan.number' => 'VLAN Number',
   'vlan.description' => 'VLAN Description');

@vlan_presence_fields =
  ("vlan_presence.version", "vlan_presence.id", "vlan_presence.vlan", "vlan_presence.building");
%vlan_presence_printable =
  ('vlan_presence.version' => 'Date',
   'vlan_presence.id' => 'ID',
   'vlan_presence.vlan' => 'VLAN Name',
   'vlan_presence.building' => 'Building');

@vlan_subnet_presence_fields = ("vlan_subnet_presence.version","vlan_subnet_presence.id","vlan_subnet_presence.vlan",
				"vlan_subnet_presence.subnet","vlan_subnet_presence.subnet_share");
%vlan_subnet_presence_printable = ( 'vlan_subnet_presence.version' => 'Date',
				    'vlan_subnet_presence.id' => 'ID',  
				    'vlan_subnet_presence.vlan' => 'VLAN Name',  
				    'vlan_subnet_presence.subnet' => 'Subnet Name',  
				    'vlan_subnet_presence.subnet_share' => 'Subnet Share');

@vlan_subnet_presence_subnetvlan_fields = ("vlan_subnet_presence.version","vlan_subnet_presence.id","vlan_subnet_presence.vlan",
					   "vlan_subnet_presence.subnet","vlan_subnet_presence.subnet_share",
					   @subnet_fields,@vlan_fields);
%vlan_subnet_presence_subnetvlan_printable = ( 'vlan_subnet_presence.version' => 'Date',
					       'vlan_subnet_presence.id' => 'ID',  
					       'vlan_subnet_presence.vlan' => 'VLAN Name',  
					       'vlan_subnet_presence.subnet' => 'Subnet Name',  
					       'vlan_subnet_presence.subnet_share' => 'Subnet Share',
					       'subnet.name' => 'Subnet Name',
					       'vlan.name' => 'VLAN Name');

@activation_q_fields = qw/activation_queue.version activation_queue.id
  activation_queue.name/;

%activation_q_printable = ('activation_queue.name' => 'Queue Name');
@error_fields = qw/_sys_errors.version _sys_errors.id _sys_errors.errcode
  _sys_errors.location _sys_errors.errfields _sys_errors.errtext/;

@sys_scheduled_fields = qw/_sys_scheduled.version _sys_scheduled.id
  _sys_scheduled.previous_run _sys_scheduled.next_run _sys_scheduled.name
  _sys_scheduled.def_interval _sys_scheduled.blocked_until/;

%sys_scheduled_printable = 
  ('_sys_scheduled.name' => 'Name',
   '_sys_scheduled.next_run' => 'Next Run',
   '_sys_scheduled.previous_run' => 'Previous Run',
   '_sys_scheduled.def_interval' => 'Default Interval',
   '_sys_scheduled.blocked_until' => 'Blocked Until');

## For TrunkSet ...:
@trunkset = qw/trunk_set.version trunk_set.id trunk_set.name trunk_set.abbreviation trunk_set.description trunk_set.primary_vlan/;
@trunk_set_fields = @trunkset;

%trunk_set_printable = ( 'trunk_set.id' => 'ID',
			'trunk_set.version' => 'Date',
			'trunk_set.name' => 'TrunkSet Name',
			'trunk_set.abbreviation' => 'Abbreviation',
			'trunk_set.description' => 'Description',
			'trunk_set.primary_vlan' => 'Native VLAN');

@trunkset_building_presence_fields = qw/trunkset_building_presence.id trunkset_building_presence.version
  trunkset_building_presence.trunk_set trunkset_building_presence.buildings/; 

%trunkset_building_presence_printable = ('trunkset_building_presence.id' => 'ID',
				'trunkset_building_presence.version' => 'Date',
				'trunkset_building_presence.trunk_set' => 'Trunk Set',
				'trunkset_building_presence.buildings' => 'Building');

@trunkset_building_presence_ts_building_fields = (@trunkset_building_presence_fields, @building_fields, @trunk_set_fields);

%trunkset_building_presence_ts_building_printable = ('trunkset_building_presence.id' => 'ID',
				'trunkset_building_presence.version' => 'Date',
				'trunkset_building_presence.trunk_set' => 'Trunk Set',
				'trunkset_building_presence.buildings' => 'Building',
				'trunk_set.name' => 'TrunkSet Name',
				'building.name' => 'Building Name');

@trunkset_machine_presence_fields = qw/trunkset_machine_presence.id trunkset_machine_presence.version 
  trunkset_machine_presence.trunk_set trunkset_machine_presence.device trunkset_machine_presence.last_update/;

%trunkset_machine_presence_printable = ('trunkset_machine_presence.id' => 'ID',
				'trunkset_machine_presence.version' => 'Date',
				'trunkset_machine_presence.trunk_set' => 'Trunk Set',
				'trunkset_machine_presence.device' => 'Device',
				'trunkset_machine_presence.last_update' => 'Last Update');

@trunkset_machine_presence_ts_machine_fields = (@trunkset_machine_presence_fields, @machine_fields, @trunk_set_fields);

%trunkset_machine_presence_ts_machine_printable = ('trunkset_machine_presence.id' => 'ID',
				'trunkset_machine_presence.version' => 'Date',
				'trunkset_machine_presence.trunk_set' => 'Trunk Set',
				'trunkset_machine_presence.device' => 'Device',
				'trunkset_machine_presence.device' => 'Last Update',
				'trunk_set.name' => 'TrunkSet Name',
				'machine.host_name' => 'Device Name');

@trunkset_vlan_presence_fields = qw/trunkset_vlan_presence.id trunkset_vlan_presence.version
  trunkset_vlan_presence.trunk_set trunkset_vlan_presence.vlan/;

%trunkset_vlan_presence_printable = ('trunkset_vlan_presence.id' => 'ID',
				'trunkset_vlan_presence.version' => 'Date',
				'trunkset_vlan_presence.trunk_set' => 'Trunk Set',
				'trunkset_vlan_presence.vlan' => 'Vlan');

@trunkset_vlan_presence_ts_vlan_fields = (@trunkset_vlan_presence_fields, @trunk_set_fields, @vlan_fields);

%trunkset_vlan_presence_ts_vlan_printable = ('trunkset_vlan_presence.id' => 'ID',
				'trunkset_vlan_presence.version' => 'Date',
				'trunkset_vlan_presence.trunk_set' => 'Trunk Set',
				'trunkset_vlan_presence.vlan' => 'Vlan',
				'trunk_set.name' => 'TrunkSet Name',
				'vlan.name' => 'VLAN Name',
				'vlan.number' => 'VLAN Number');

@valid_tables = qw/
		   _sys_changelog
		   _sys_changerec_col
		   _sys_changerec_row
		   _sys_dberror
		   _sys_errors
		   _sys_info
		   _sys_scheduled
		   activation_queue
		   attribute
		   attribute_spec
		   building
		   cable
		   credentials
		   dhcp_option
		   dhcp_option_type
		   dns_resource
		   dns_resource_type
		   dns_zone
		   groups
		   machine
		   memberships
		   network
		   outlet
		   outlet_type
		   outlet_vlan_membership
		   protections
		   service
		   service_membership
		   service_type
		   subnet
		   subnet_domain
		   subnet_presence
		   subnet_registration_modes
		   subnet_share
		   trunk_set
		   trunkset_building_presence
		   trunkset_machine_presence
		   trunkset_vlan_presence
		   users
		   user_type
		   vlan
		   vlan_presence
		   vlan_subnet_presence
		   /;

@archive_tables = grep(!/^_sys_change/, @valid_tables);

@valid_perms = qw/READ WRITE ADD/;

@sys_changerec_row_type = qw/INSERT UPDATE DELETE/;

%perm_map = ('groups' => [1,5,9],
	     'machine' => [1,5,9],
	     'outlet' => [1,5,9]);

%AllocationMethods = ('Lowest First' => 
		      \&CMU::Netdb::machines_subnets::subnets_am_lowfirst,
                      'Highest First' => 
		      \&CMU::Netdb::machines_subnets::subnets_am_highfirst,
                      'Largest Block' => 
		      \&CMU::Netdb::machines_subnets::subnets_am_largeblock);


%restricted_access_fields = ( 'dns_zone.ddns_auth' => 9,
			      'machine.comment_lvl5' => 5,
			      'machine.comment_lvl9' => 9,
			      'machine.flags' => 5,
			      'groups.comment_lvl5' => 5,
			      'groups.comment_lvl9' => 9,
			      'outlet.comment_lvl5' => 5,
			      'outlet.comment_lvl9' => 9,
			    );

@history_fields = ( '_sys_changelog.id',
                    '_sys_changelog.version',
		    '_sys_changelog.user',
		    '_sys_changelog.name',
                    '_sys_changelog.time',
                    '_sys_changelog.info',
                    '_sys_changerec_row.id',
                    '_sys_changerec_row.version',
                    '_sys_changerec_row.tname',
                    '_sys_changerec_row.row',
                    '_sys_changerec_row.type',
                    '_sys_changerec_col.id',
                    '_sys_changerec_col.version',
                    '_sys_changerec_col.name',
                    '_sys_changerec_col.data',
                    '_sys_changerec_col.previous'
                  );

%history_fields_printable = ( '_sys_changelog.id' => "Transaction ID",
                              '_sys_changelog.version' => "Version",
                              '_sys_changelog.name' => "Done by",
                              '_sys_changelog.user' => "Credential ID",
                              '_sys_changelog.time' => "When",
                              '_sys_changelog.info' => "From where",
                              '_sys_changerec_row.id' => "ID",
                              '_sys_changerec_row.version' => "Version",
                              '_sys_changerec_row.tname' => "Table",
                              '_sys_changerec_row.type' => "Type",
                              '_sys_changerec_row.row' => "Row ID",
                              '_sys_changerec_col.id' => "ID",
                              '_sys_changerec_col.version' => "Version",
                              '_sys_changerec_col.name' => "Column",
                              '_sys_changerec_col.data' => "Set to",
                              '_sys_changerec_col.previous' => "Changed from"
                  );


# Cascade deletions/assertions
#  - This is run when modifying or deleting records. We assume
#    *.id cannot be modified, only deleted. Other records will
#    be checked prior to update as well. See CMU::Netdb::helper::CheckCascades
# [Field] => array of MatchArray
#  Field is: table.field; table is automatically included in join
#  MatchArray is: 
#    CheckTables: list of additional tables to join, comma separated
#                 DON'T INCLUDE the table being modified
#    Where:  "WHERE" clause to match records in CheckTables
#            MAKE SURE to include proper join statements
#    Outcome: 'fatal' or 'delete'. default: 'fatal'. if fatal, returns
#             error on existing records. if 'delete', deletes matching
#             records, 'deleteOrUpdate' -- delete or update the record (not .id)
# Primary, ExTables, Where, Outcome
%cascades = 
  ('activation_queue.id' => [ { Primary => 'building',
				Where => 'building.activation_queue = '.
				'activation_queue.id',
				Outcome => 'fatal'
			      }
			    ],
   'attribute_spec.id' => [ { Primary => 'attribute',
			      Where => 'attribute.spec = attribute_spec.id',
			      Outcome => 'fatal'
			    }
			  ],
   'building.building' => [ { Primary => 'cable',
			      Where => '(cable.from_building = '.
			      'building.building OR cable.to_building = '.
			      'building.building)',
			      Outcome => 'fatal'
			    },
			    { Primary => 'subnet_presence',
			      Where => 'subnet_presence.building = '.
			      'building.building',
			      Outcome => 'delete'
			    }
			  ],
   'building.id' => [ { Primary => 'trunkset_building_presence',
			Where => 'trunkset_building_presence.buildings = building.id',
			Outcome => 'delete'	
		      }
		    ],
   'cable.id' => [ { Primary => 'outlet',
		     Where => 'outlet.cable = cable.id',
		     Outcome => 'fatal'
		   }
		 ],
   'dhcp_option_type.id' => [ { Primary => 'dhcp_option',
				Where => 'dhcp_option.type_id = '.
				' dhcp_option_type.id',
				Outcome => 'fatal'
			      }
			    ],
   'dns_resource_type.name' => [ { Primary => 'dns_resource',
				   Where => 'dns_resource.type = '.
				   'dns_resource_type.name',
				   Outcome => 'fatal'
				 }
			       ],
   'dns_zone.id' => [ { Primary => 'machine',
			Where => '(machine.host_name_zone = dns_zone.id OR '.
			' machine.ip_address_zone = dns_zone.id ) ',
			Outcome => 'fatal'
		      },
		      { Primary => 'dns_zone AS D2',
			Where => ' D2.parent = dns_zone.id AND '.
			' D2.id != dns_zone.id ',
			Outcome => 'fatal'
		      },
		      { Primary => 'dns_resource',
			Where => 'dns_resource.name_zone = dns_zone.id ',
			Outcome => 'delete'
		      }
		    ],
   'dns_zone.name' => [ {Primary => 'subnet_domain',
			 Where => 'subnet_domain.domain = dns_zone.name',
			 Outcome => 'deleteOrUpdate',
			 UpdField => 'subnet_domain.domain'
			}
		      ],
   'groups.id' => [ { Primary => 'memberships',
		      Where => 'memberships.gid = groups.id ',
		      Outcome => 'delete'
		    },
		    { Primary => 'protections',
		      Where => 'protections.identity < 0 AND '.
		      ' protections.identity = -1*groups.id ',
		      Outcome => 'delete'
		    }
		  ],
   'machine.id' => [ { Primary => 'trunkset_machine_presence',
	               Where => 'trunkset_machine_presence.device = machine.id',
		       Outcome => 'delete'
		     }
		    ],
   'outlet.id' => [ { Primary => 'outlet_vlan_membership',
		      Where => 'outlet_vlan_membership.outlet = outlet.id',
		      Outcome => 'delete'
		    }
		  ],
   'outlet_type.id' => [ { Primary => 'outlet',
			   Where => 'outlet.type = outlet_type.id',
			   Outcome => 'fatal'
			 }
		       ],
   'service.id' => [ { Primary => 'service_membership',
		       Where => 'service_membership.service = service.id',
		       Outcome => 'delete'
		     }
		   ],
   'service_type.id' => [ { Primary => 'attribute_spec',
			    Where => 'attribute_spec.type = service_type.id',
			    Outcome => 'fatal'
			  },
			  { Primary => 'service',
			    Where => 'service.type = service_type.id',
			    Outcome => 'fatal'
			  }
			],
   'subnet.id' => [
		    { Primary => 'machine',
		      Where => ' machine.ip_address_subnet = subnet.id',
		      Outcome => 'fatal'
		    },
		    { Primary => 'network',
		      Where => ' network.subnet = subnet.id',
		      Outcome => 'delete'
		    },
		    { Primary => 'subnet_presence',
		      Where => ' subnet_presence.subnet = subnet.id',
		      Outcome => 'delete'
		    },
		    { Primary => 'subnet_domain',
		      Where => ' subnet_domain.subnet = subnet.id',
		      Outcome => 'delete'
		    },
		    { Primary => 'vlan_subnet_presence',
		      Where => 'vlan_subnet_presence.subnet = subnet.id',
		      Outcome => 'delete'
		    }
		  ],
   'subnet_share.id' => [ { Primary => 'subnet',
			    Where => 'subnet.share = subnet_share.id',
			    Outcome => 'fatal'
			  }
			],
    'trunk_set.id' => [ { Primary => 'trunkset_vlan_presence',
			  Where => 'trunkset_vlan_presence.trunk_set = trunk_set.id',
			  Outcome => 'delete'
			},
			{ Primary => 'trunkset_building_presence',
			  Where => 'trunkset_building_presence.trunk_set = trunk_set.id',
			  Outcome => 'delete'
			},
			{ Primary => 'trunkset_machine_presence',
			  Where => 'trunkset_machine_presence.trunk_set = trunk_set.id',
			  Outcome => 'fatal'
			}
		      ],
    'trunkset_machine_presence.id' => [ { Primary => 'outlet',
					  Where => 'outlet.device = trunkset_machine_presence.id',
					  Outcome => 'fatal'
					}
				      ],

   'users.id' => [ { Primary => 'memberships',
		     Where => 'memberships.uid = users.id ',
		     Outcome => 'delete'
		   },
		   { Primary => 'protections',
		     Where => 'protections.identity > 0 AND '.
		     ' protections.identity = users.id',
		     Outcome => 'delete'
		   },
		   { Primary => 'credentials',
		     Where => 'credentials.user = users.id ',
		     Outcome => 'delete'
		   },
		 ],
    'vlan.id' => [ { Primary => 'trunkset_vlan_presence',
		     Where => 'trunkset_vlan_presence.vlan = vlan.id',
		     Outcome => 'delete'
		    },
		    { Primary => 'vlan_subnet_presence',
		      Where => 'vlan_subnet_presence.vlan = vlan.id',
		      Outcome => 'delete'
		    },
		    { Primary => 'outlet_vlan_membership',
		      Where => 'outlet_vlan_membership.vlan = vlan.id',
		      Outcome => 'delete'
		    }
		  ],

   'user_type.id' => [ { Primary => 'credentials',
                         Where => 'credentials.type = user_type.id',
                         Outcome => 'fatal'
                       }
                     ],
  );

# TableTrans: [real table name] => [enum member]
%multirefs = 
  ('attribute.owner_tid' => 
   { TableRef => 'attribute.owner_table',
     TidRef => 'attribute.owner_tid',
     TableTrans => { 'users' => 'users',
		     'groups' => 'groups',
		     'service_membership' => 'service_membership',
		     'service' => 'service',
		     'outlet' => 'outlet',
		     'subnet' => 'subnet',
		     'vlan' => 'vlan',
		   },
     Outcome => 'delete'
   },

   'dhcp_option.tid' => 
   { TableRef => 'dhcp_option.type',
     TidRef => 'dhcp_option.tid',
     TableTrans => { 'subnet_share' => 'share',
		     'subnet' => 'subnet',
		     'machine' => 'machine',
		     'service' => 'service'
		   },
     Outcome => 'delete'
   },

   'dns_resource.owner_tid' =>
   { TableRef => 'dns_resource.owner_type',
     TidRef => 'dns_resource.owner_tid',
     TableTrans => { 'machine' => 'machine',
		     'dns_zone' => 'dns_zone',
		     'service' => 'service'
		   },
     Outcome => 'delete'
   },

   # 'dns_resource.rname_tid' => { }   # FIXME FIXME

   'protections.tid' => 
   { TableRef => 'protections.tname',
     TidRef => 'protections.tid',
     TableTrans => { 'users' => 'users',
		     'groups' => 'groups',
		     'building' => 'building',
		     'cable' => 'cable',
		     'outlet' => 'outlet',
		     'outlet_type' => 'outlet_type',
		     'machine' => 'machine',
		     'network' => 'network',
		     'subnet' => 'subnet',
		     'subnet_share' => 'subnet_share',
		     'subnet_presence' => 'subnet_presence',
		     'subnet_domain' => 'subnet_domain',
		     'subnet_registration_modes' => 'subnet_registration_modes',
		     'dhcp_option_type' => 'dhcp_option_type',
		     'dhcp_option' => 'dhcp_option',
		     'dns_resource_type' => 'dns_resource_type',
		     'dns_resource' => 'dns_resource',
		     'dns_zone' => 'dns_zone',
		     '_sys_scheduled' => '_sys_scheduled',
		     'activation_queue' => 'activation_queue',
		     'service' => 'service',
		     'service_membership' => 'service_membership',
		     'service_type' => 'service_type',
		     'attribute' => 'attribute',
		     'attribute_spec' => 'attribute_spec',
		   },
     Outcome => 'delete',
   },

   'service_membership.member_tid' =>
   { TableRef => 'service_membership.member_type',
     TidRef => 'service_membership.member_tid',
     TableTrans => { 'users' => 'users',
		     'groups' => 'groups',
		     'building' => 'building',
		     'cable' => 'cable',
		     'outlet' => 'outlet',
		     'outlet_type' => 'outlet_type',
		     'machine' => 'machine',
		     'subnet' => 'subnet',
		     'subnet_share' => 'subnet_share',
		     'dns_zone' => 'dns_zone',
		     'activation_queue' => 'activation_queue',
		     'service' => 'service',
		   },
     Outcome => 'fatal'
   }
);


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 8
# perl-indent-level: 2
# cperl-indent-level: 2
# End:

__END__
