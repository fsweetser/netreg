#   -*- perl -*-
#
# CMU::Netdb::consistency
# This module provides consistency checking of the database.
#
# Copyright 2001 Carnegie Mellon University 
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


package CMU::Netdb::consistency;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $consistency_queries $debug);

use CMU::Netdb;
use CMU::Netdb::helper;

use IO::File;

require Exporter;
@ISA = qw(Exporter);
@EXPORT= qw(consis_query run_all_queries);
$debug = 0;

#select count(machine.host_name) from machine inner join protections
#as p1 on machine.id = p1.tid and p1.tname = 'machine' and p1.identity
#< 0 inner join groups as g1 on g1.id * -1 = p1.identity inner join
#protections as p2 on machine.id = p2.tid and p2.tname = 'machine' and
#p2.identity < 0 and p2.id != p1.id inner join groups as g2 on g2.id * -1
#= p2.identity where g1.id!=g2.id and g1.name like 'dept:%' and g2.name
#like 'dept:%' order by machine.host_name;

# queries consist of multiple component. valid components are:
# title: Name of this query, used when sending mail about problems. OPTIONAL
# table: Primary table for the query, id and version from this table
#        will be the first two components of the data passed to the helper
#        functions.  REQUIRED
# other_fields: Other fields for the query to return.  They'll be passed to
#               the helper functions. OPTIONAL
# other_tables: Tables to join to, including any explicit join clauses. 
#               REQUIRED
# where: the where clause for the query. REQUIRED
# print_header: helper function to print the header for the data to
#               be displayed.  OPTIONAL
# print_row: helper function to print an individual row of data.  OPTIONAL
# fix_row: helper function to fix the problem with an individual row of
#          data.  OPTIONAL
# primary_contact: email address to receive a copy of any mail sent about this 
#                  query.  OPTIONAL
$consistency_queries=
  {
   '15_machineWithoutDept'=>
   {title=>"Machines with No Department",
    table=>"machine",
    other_fields=>"machine.host_name, INET_NTOA(machine.ip_address), ".
    "machine.mac_address",
    other_tables=>"LEFT JOIN protections ON protections.tname = 'machine' AND ".
    "protections.tid = machine.id and protections.identity < 0",
    where=>"protections.tid IS NULL",
    print_header=>\&machineNoDept_print_header,
    print_row=>\&machineNoDept_print_row
   },
   '80_existsaclgroups'=> 
   {title=>"Unknown groups referenced",
    table=>"protections",
    other_fields=>"protections.tname, protections.tid, protections.identity",
    other_tables=>"LEFT JOIN groups ON protections.identity < 0 AND protections.identity=-1*groups.id",
    where=>"protections.identity < 0 AND groups.id IS NULL",
    print_header=>\&protgroup_print_header,
    print_row=>\&protgroup_print_row,
    fix_row=>\&protgroup_fix_row
   },
   '80_existsaclusers'=> 
   {title=>"Unknown users referenced",
    table=>"protections",
    other_fields=>"protections.tname, protections.tid, protections.identity",
    other_tables=>"LEFT JOIN users ON protections.identity=users.id",
    where=>"protections.identity > 0 AND users.id IS NULL",
    print_header=>\&protuser_print_header,
    print_row=>\&protuser_print_row,
    fix_row=>\&protuser_fix_row
   },
   '30_existsoutletcable'=>
   {title=>"Unknown cable referenced",
    table=>"outlet",
    other_fields=>"outlet.cable, outlet.device, outlet.port",
    other_tables=>"LEFT JOIN cable on cable.id=outlet.cable",
    where=>"cable.id IS NULL",
    print_header=>\&outlet_print_header,
    print_row=>\&outlet_print_row,
    fix_row=>\&outlet_fix_row
   },
   '10_validmachineipsubnet'=> 
   {title=>"Incorrect ip_address_subnet",
    table=>"machine",
    other_fields=>"machine.host_name, INET_NTOA(machine.ip_address), subnet2.abbreviation, subnet.id, subnet.abbreviation",
    other_tables=>",subnet, subnet AS subnet2",
    where=>"machine.ip_address & subnet.network_mask=subnet.base_address AND subnet2.id=machine.ip_address_subnet AND subnet.id != subnet2.id",
    print_header=>\&machineipsubnet_print_header,
    print_row=>\&machineipsubnet_print_row,
    fix_row=>\&machineipsubnet_fix_row
   },
   '15_duplicatecablefrom'=>
   {title=>"Duplicate Cables (From)",
    table=>"cable",
    other_fields=>"cable.label_from, cable.label_to, c.id, c.label_from, c.label_to",
    other_tables=>",cable AS c",
    where=>"cable.label_from != '' AND cable.label_from = c.label_from AND cable.id < c.id",
    print_header=>\&dupcable_print_header,
    print_row=>\&dupcable_print_row
   },
   '15_duplicatecableto'=>
   {title=>"Duplicate Cables (To)",
    table=>"cable",
    other_fields=>"cable.label_from, cable.label_to, c.id, c.label_from, c.label_to",
    other_tables=>",cable AS c",
    where=>"cable.label_to = c.label_to AND cable.label_to != '' AND cable.id < c.id",
    print_header=>\&dupcable_print_header,
    print_row=>\&dupcable_print_row
   },
   '10_duplicateipaddress'=>
   {title=>"Duplicate IP Addresses",
    table=>"machine",
    other_fields=>"machine.host_name, INET_NTOA(machine.ip_address)",
    other_tables=>",machine AS m",
    where=>"machine.ip_address != 0 AND machine.ip_address=m.ip_address AND machine.id != m.id GROUP BY machine.id ORDER BY machine.ip_address, machine.id",
    print_header=>\&dupip_print_header,
    print_row=>\&dupip_print_row
   },
   '10_duplicatehostname'=>
   {title=>"Duplicate Hostname",
    table=>"machine",
    other_fields=>"machine.host_name",
    other_tables=>",machine AS m",
    where=>"machine.host_name != '' AND machine.host_name=m.host_name AND machine.id != m.id GROUP BY machine.id ORDER BY machine.host_name, machine.id",
    print_header=>\&dupname_print_header,
    print_row=>\&dupname_print_row
   },
   '50_incompleteoutletactivations'=>
   {title=>"Bad activation status",
    table=>"outlet",
    other_fields=>"cable.label_from,cable.label_to,machine.host_name,outlet.port,outlet.attributes,outlet.flags,outlet.status,TO_DAYS(NOW()) - TO_DAYS(outlet.version)",
    other_tables=>",cable,trunkset_machine_presence,machine",
    where=>"TO_DAYS(NOW()) - TO_DAYS(outlet.version) > 0 AND outlet.device != '' and cable.id=outlet.cable and trunkset_machine_presence.id = outlet.device and machine.id = trunkset_machine_presence.device and ((outlet.attributes='' AND FIND_IN_SET('activated',outlet.flags) AND NOT FIND_IN_SET('suspend',outlet.flags) AND outlet.status='partitioned') or (outlet.attributes='deactivate' and NOT FIND_IN_SET('activated',outlet.flags) and outlet.status='enabled')) order by cable.from_building,cable.from_wing,cable.from_floor,cable.from_closet,cable.from_rack,cable.from_panel,outlet.device,outlet.port",
    print_header=>\&outletstatus_print_header,
    print_row=>\&outletstatus_print_row
   },
   '50_vlan_update_errors' =>
   {title=>"Error updating vlans",
    table=>'outlet_vlan_membership',
    other_fields=>'outlet.id, machine.host_name, outlet.port, vlan.abbreviation, outlet_vlan_membership.type, outlet_vlan_membership.trunk_type, outlet_vlan_membership.status',
    other_tables=>", outlet, vlan, trunkset_machine_presence, machine",
    where=>"outlet.device = trunkset_machine_presence.id AND trunkset_machine_presence.device = machine.id AND outlet.id = outlet_vlan_membership.outlet AND vlan.id = outlet_vlan_membership.vlan AND outlet_vlan_membership.status IN ('error', 'errordelete')",
    print_header=>\&outletvlan_print_header,
    print_row=>\&outletvlan_print_row,
   },
   '99_staleprotectionsmachines'=>
   {title=>"Stale protections entries (Machines)",
    table=>"protections",
    other_fields=>"'machine', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN machine ON protections.tname='machine' and protections.tid = machine.id",
    where=>"protections.tname = 'machine' and protections.tid != 0 and machine.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row
   },
   '99_staleprotectionsoutlets'=>
   {title=>"Stale protections entries (Outlets)",
    table=>"protections",
    other_fields=>"'outlet', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN outlet ON protections.tname='outlet' and protections.tid = outlet.id",
    where=>"protections.tname = 'outlet' and protections.tid != 0 and outlet.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row
   },
   '99_staleprotectionssubnets'=>
   {title=>"Stale protections entries (Subnets)",
    table=>"protections",
    other_fields=>"'subnet', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN subnet ON protections.tname='subnet' and protections.tid = subnet.id",
    where=>"protections.tname = 'subnet' and protections.tid != 0 and subnet.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row
   },
   '99_staleprotectionscables'=>
   {title=>"Stale protections entries (Cables)",
    table=>"protections",
    other_fields=>"'cable', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN cable ON protections.tname='cable' and protections.tid = cable.id",
    where=>"protections.tname = 'cable' and protections.tid != 0 and cable.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row
   },
   '99_staleprotectionsdnsresources'=>
   {title=>"Stale protections entries (DNS Resources)",
    table=>"protections",
    other_fields=>"'dns_resource', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN dns_resource ON protections.tname='dns_resource' and protections.tid = dns_resource.id",
    where=>"protections.tname = 'dns_resource' and protections.tid != 0 and dns_resource.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row
   },
   '99_staleprotectionsdhcpoptions'=>
   {title=>"Stale protections entries (DHCP Options)",
    table=>"protections",
    other_fields=>"'dhcp_option', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN dhcp_option ON protections.tname='dhcp_option' and protections.tid = dhcp_option.id",
    where=>"protections.tname = 'dhcp_option' and protections.tid != 0 and dhcp_option.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row
   },
   '99_staleprotectionsdnszones'=>
   {title=>"Stale protections entries (DNS Zones)",
    table=>"protections",
    other_fields=>"'dns_zone', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN dns_zone ON protections.tname='dns_zone' and protections.tid = dns_zone.id",
    where=>"protections.tname = 'dns_zone' and protections.tid != 0 and dns_zone.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row,
   },
   '99_staleprotectionsgroups'=>
   {title=>"Stale protections entries (Groups)",
    table=>"protections",
    other_fields=>"'groups', protections.tid, protections.identity",
    other_tables=>"LEFT JOIN groups ON protections.tname='groups' and protections.tid = groups.id",
    where=>"protections.tname = 'groups' and protections.tid != 0 and groups.id IS NULL",
    print_header=>\&staleprot_print_header,
    print_row=>\&staleprot_print_row,
    fix_row=>\&staleprot_fix_row,
   },
   #   '100_stale_dns_resource_machines' =>
   #   {title=>"Stale dnsresource entries with no owners (machines)",
   #    table=>"dns_resource",
   #    other_fields=>"'machine', dns_resource.owner_tid",
   #    other_tables=>"LEFT JOIN machine ON dns_resource.owner_type='machine' and dns_resource.owner_tid = machine.id",
   #    where=>"dns_resource.owner_type='machine' and dns_resource.owner_tid != 0 and machine.id IS NULL",
   #    print_header=>\&staledns_print_header,
   #    print_row=>\&staledns_print_row,
   #    ##fix_row=>\&staledns_fix_row,
   #   },
   '90_stale_dns_resource_dnszones' =>
   {title=>"Stale dnsresource entries with no owners(dns_zones)",	
    table=>"dns_resource",
    other_fields=>"'dns_zone', dns_resource.owner_tid",
    other_tables=>"LEFT JOIN dns_zone ON dns_resource.owner_type='dns_zone' and dns_resource.owner_tid = dns_zone.id",
    where=>"dns_resource.owner_type='dns_zone' and dns_resource.owner_tid != 0 and dns_zone.id IS NULL",
    print_header=>\&staledns_print_header,
    print_row=>\&staledns_print_row,
    #fix_row=>\&staledns_fix_row,
   },
   '10_duppermissions'=>
   {title=>"Duplicate group permissions (protections)",
    table=>"protections",
    other_fields=>"protections.tname, protections.tid, g1.name, protections.rlevel, g2.name, p2.rlevel",
    other_tables=>",protections as p2, groups as g1, groups as g2",
    where=>"protections.tname = 'machine' and protections.tname = p2.tname and protections.tid = p2.tid and protections.id < p2.id and protections.identity = p2.identity and protections.identity < 0 and g1.id = protections.identity * -1 and g1.name like 'dept:%' and g2.id = protections.identity * -1 and g2.name like 'dept:%'",
    print_header=>\&dup_perm_print_header,
    print_row=>\&dup_perm_print_row,
   },
   
   
   '90_staleactivation_queue_in_building'=>
   {title=>"Stale activation queue (building)",
    table=>"building",
    other_fields=>"building.name, building.activation_queue",
    other_tables=>"LEFT JOIN activation_queue ON building.activation_queue = activation_queue.id",
    where=>"activation_queue.id IS NULL",
    print_header=>\&stalebuilding_print_header,
    print_row=>\&stalebuilding_print_row,
   },
   '10_dupmachine_subnet_and_macaddress'=>
   {title=>"Duplicate mac_address and subnet (machines)",
    table=>"machine",
    other_fields=>"machine.mac_address, machine.ip_address_subnet",
    other_tables=>",machine AS m",
    where=>"machine.id != m.id and machine.ip_address_subnet != '' and machine.ip_address_subnet = m.ip_address_subnet and machine.mac_address = m.mac_address and machine.mac_address != '' and m.mode != 'secondary' and machine.mode != 'secondary'",
    print_header=>\&illegal_machine_print_header,
    print_row=>\&illegal_machine_print_row,
   },
   '50_illegal_dynamic_machine'=>
   {title=>"Machine illegally registered as dynamic",
    table=>"machine",
    other_fields=>"machine.host_name, subnet.name, machine.id",
    other_tables=>",subnet",
    where=>"machine.ip_address_subnet = subnet.id and machine.mode='dynamic' and subnet.dynamic='disallow'",
    print_header=>\&illegal_machine_print_header,
    print_row=>\&illegal_machine_print_row,
   },
   '90_stale_network_subnet'=>
   {title=>"Stable subnet (network)",
    table=>"network",
    other_fields=>"network.subnet, network.id",
    other_tables=>"LEFT JOIN subnet ON network.subnet = subnet.id",
    where=>"subnet.id IS NULL",
    print_header=>\&stale_network_print_header,
    print_row=>\&stale_network_print_row,
   },
   '50_illegal_subnet_default_mode'=>
   {title=>"Default mode is dynamic where dynamic='disallow'",
    table=>"subnet",
    other_fields=>"subnet.default_mode, subnet.dynamic",
    other_tables=>'',
    where=>"subnet.dynamic='disallow' and subnet.default_mode='dynamic'",
    print_header=>\&illegal_subnet_print_header,
    print_row=>\&illegal_subnet_print_row,
    #fix_row=>\&illegal_subnet_fix_row,
   },
   '90_stale_subnet_share'=>
   {title=>"Stale subnet share (subnet)",
    table=>"subnet",
    other_fields=>"subnet.name, subnet.share",
    other_tables=>"LEFT JOIN subnet_share ON subnet.share = subnet_share.id",
    where=>"subnet.share != 0 AND subnet_share.id IS NULL",
    print_header=>\&stale_subnet_print_header,
    print_row=>\&stale_subnet_print_row,
    #fix_row=>\&stale_subnet_fix_row,
   },
   
   '90_stale_subnet_presence_building'=>
   {title=>"Stale building (subnet_presence)",
    table=>"subnet_presence",
    other_fields=>"subnet_presence.building, subnet_presence.subnet",
    other_tables=>"LEFT JOIN building ON subnet_presence.building=building.building",
    where=>"building.id IS NULL",
    print_header=>\&stale_subpresence_print_header,
    print_row=>\&stale_subpresence_print_row
   },
   
   '90_stale_subnet_presence_subnet'=>
   {title=>"Stale subnet (subnet_presence)",
    table=>"subnet_presence",
    other_fields=>"subnet_presence.building, subnet_presence.subnet",
    other_tables=>"LEFT JOIN subnet ON subnet_presence.subnet = subnet.id",
    where=>"subnet.id IS NULL",
    print_header=>\&stale_subpresence_print_header,
    print_row=>\&stale_subpresence_print_row
   },
   
   '90_stale_subnet_domain_subnet'=>
   {title=>"Stale subnet (subnet_domain)",
    table=>"subnet_domain",
    other_fields=>"subnet_domain.subnet, subnet_domain.domain",
    other_tables=>"LEFT JOIN subnet ON subnet_domain.subnet = subnet.id",
    where=>"subnet.id IS NULL",
    print_header=>\&stale_subnet_domain_print_header,
    print_row=>\&stale_subnet_domain_print_row
   },
   
   '90_stale_subnet_domain_domain'=>
   {title=>"Stale domain (subnet_domain)",
    table=>"subnet_domain",
    other_fields=>"subnet_domain.subnet, subnet_domain.domain",
    other_tables=>"LEFT JOIN dns_zone ON subnet_domain.domain = dns_zone.name",
    where=>"dns_zone.id IS NULL",
    print_header=>\&stale_subnet_domain_print_header,
    print_row=>\&stale_subnet_domain_print_row
   },
   
   '90_stale_dhcp_option_share'=>
   {title=>"Stale dhcp option owner (share)",
    table=>"dhcp_option",
    other_fields=>"'share', dhcp_option.tid",
    other_tables=>"LEFT JOIN subnet_share ON dhcp_option.type = 'share' and dhcp_option.tid =subnet_share.id",
    where=>"dhcp_option.tid != 0 and dhcp_option.type = 'share' and subnet_share.id IS NULL",
    print_header=>\&stale_dhcp_option_print_header,
    print_row=>\&stale_dhcp_option_print_row
   },
   '90_stale_dhcp_option_machine'=>
   {title=>"Stale dhcp option owner (machine)",
    table=>"dhcp_option",
    other_fields=>"'machine', dhcp_option.tid",
    other_tables=>"LEFT JOIN machine ON dhcp_option.type='machine' and dhcp_option.tid = machine.id",
    where=>"dhcp_option.tid !=0 and dhcp_option.type='machine' and machine.id IS NULL",
    print_header=>\&stale_dhcp_option_print_header,
    print_row=>\&stale_dhcp_option_print_row
   },
   '90_stale_dhcp_option_subnet'=>
   {title=>"Stale dhcp option owner (subnet)",
    table=>"dhcp_option",
    other_fields=>"dhcp_option.type, dhcp_option.tid",
    other_tables=>"LEFT JOIN subnet ON dhcp_option.type ='subnet' and dhcp_option.tid = subnet.id",
    where=>"dhcp_option.tid != 0 and dhcp_option.type = 'subnet' and subnet.id IS NULL",
    print_header=>\&stale_dhcp_option_print_header,
    print_row=>\&stale_dhcp_option_print_row,
   },
   '90_stale_vlan_outlet'=>
   {title=>"Stale vlan membership (outlet)",
    table=>"outlet_vlan_membership",
    other_fields=>"outlet_vlan_membership.outlet, outlet_vlan_membership.vlan",
    other_tables=>"LEFT JOIN outlet ON outlet_vlan_membership.outlet = outlet.id",
    where=>"outlet.id IS NULL",
    print_header=>\&stale_vlan_print_header,
    print_row=>\&stale_vlan_print_row,
   },
   '90_stale_vlan_subnet'=>
   {title=>"Stale vlan membership (subnet)",
    table=>"outlet_subnet_membership",
    other_fields=>"outlet_subnet_membership.outlet, outlet_subnet_membership.subnet",
    other_tables=>"LEFT JOIN subnet ON outlet_subnet_membership.subnet = subnet.id",
    where=>"subnet.id IS NULL",
    print_header=>\&stale_vlan_print_header,
    print_row=>\&stale_vlan_print_row,
   },
   #  '99_stale_service_type'=>
   #  {title=>"Stale service service_type",
   #   table=>"service",
   #   other_fields=>"service.id, service.type",
   #   other_tables=>"LEFT JOIN service_type ON service.type = service_type.id",
   #   where=>"service.id != 0 and service.id IS NULL",
   #   print_header=>\&service_print_header,
   #   print_row=>\&service_print_row,
   #  },
   #  '99_stale_service_membership_machine'=>
   #  {title=>"Stale service_membership machine",
   #   table=>"service_membership",
   #   other_fields=>"service_membership.id, service_membership.machine",
   #   other_tables=>"LEFT JOIN machine ON service_membership.machine = machine.id",
   #   where=>"service_membership.id !=0 and machine.id IS NULL",
   #   print_header=>\&service_membership_print_header,
   #   print_row=>\&service_membership_print_row,
   #  },
   #   '99_stale_service_membership_service'=>
   #  {title=>"Stale service_membership service",
   #   table=>"service_membership",
   #   other_fields=>"service_membership.id, service_membership.service",
   #   other_tables=>"LEFT JOIN service ON service_membership.service = service.id",
   #   where=>"service_membership.id !=0 and service.id IS NULL",
   #   print_header=>\&service_membership_print_header,
   #   print_row=>\&service_membership_print_row
   #  },
   
  };

sub machineNoDept_print_header {
  my ($func, $arg) = @_;
  my ($header);

  $header = sprintf("%8.8s %30.30s %15.15s %12.12s ", "Mach ID", 
		    "Hostname", "IP Address", "MAC Address");
  &{$func}($arg, $header);
}

sub machineNoDept_print_row {
  my ($func, $arg, $data) = @_;
  my ($string);

  $string = sprintf("%8.8s %30.30s %15.15s %12.12s", $data->[0], $data->[2], 
		    $data->[3], $data->[4]);
  &{$func}($arg, $string);
}

sub staledns_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%8.8s %15.15s %11.11s", "Row ID", "Table",
                    "Table ID");
  &{$func}($arg, $header);
}

sub staledns_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%8.8s %15.15s %11.11s",
		    $data->[0], $data->[2], $data->[3]);
  
  &{$func}($arg, $string);
}

sub dup_perm_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%8.8s %15.15s %11.11s %8.8s %5.5s %8.8s %5.5s", "Row ID", "Table",
                    "Table ID", "Identity", "Level", "Identity", "Level");
  &{$func}($arg, $header);
}

sub dup_perm_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%8.8s %15.15s %11.11s %8.8s %5.5s %8.8s %5.5s", 
		    $data->[0], $data->[2], $data->[3], $data->[4], $data->[5], $data->[6], $data->[7]);
  
  &{$func}($arg, $string);
}

sub staleprot_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%8.8s %15.15s %11.11s %8.8s", "Row ID", "Table", 
		    "Table ID", "Identity" );
  &{$func}($arg, $header);
}

sub staleprot_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%8.8s %15.15s %11.11s %8.8s",
		    $data->[0], $data->[2], $data->[3], $data->[4]);
  &{$func}($arg, $string);
}

sub staleprot_fix_row {
  my ($dbh, $data)=@_;
  my ($upd);
  $upd=sprintf("delete from protections where id=%s and version=%s",
	       $data->[0], $data->[1]);
  return $dbh->do($upd);
}

sub protgroup_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header=sprintf("%8.8s %15.15s %10.10s %8.8s",
                  "Row id", "Table", "Table Row", "Group id" );
  &{$func}($arg, $header);
}

sub protgroup_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string=sprintf("%8.8s %15.15s %10.10s %8.8s",
                  $data->[0], $data->[2], $data->[3], -1 * $data->[4]);
  &{$func}($arg, $string);
}

sub protgroup_fix_row {
  my ($dbh, $data)=@_;
  my ($upd);
  $upd=sprintf("delete from protections where id=%s and version=%s",
	       $data->[0], $data->[1]);
  return $dbh->do($upd);
}

sub protuser_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header=sprintf("%8.8s %15.15s %10.10s %8.8s",
                  "Row id", "Table", "Table Row", "User id" );
  &{$func}($arg, $header);
}

sub protuser_print_row {
  my ($func, $arg, $data)=@_;
  my ($string,$upd);
  
  $string=sprintf("%8.8s %15.15s %10.10s %8.8s",
                  $data->[0], $data->[2], $data->[3], $data->[4]);
  &{$func}($arg, $string);
}

sub protuser_fix_row {
  my ($dbh, $data)=@_;
  my ($upd);
  $upd=sprintf("delete from protections where id=%s and version=%s",
	       $data->[0], $data->[1]);
  return $dbh->do($upd);
}

sub outlet_print_header {
  my($func, $arg) = @_;
  my ($header);
  $header="NOTE: outlet name unknown since it's stored in the cable table\n";
  $header .= sprintf("%8.8s %30.30s %8.8s %8.8s", "Row Id",  "Connected device", "port", "Cable id");
  &{$func}($arg, $header);
}

sub outlet_print_row {
  my ($func, $arg, $data)=@_;
  my ($string, $upd);
  
  $string = sprintf("%8.8s %30.30s %8.8s %8.8s", $data->[0], $data->[3],
                    $data->[4], $data->[2]);
  &{$func}($arg, $string); 
}

sub outlet_fix_row {
  my ($dbh, $data)=@_;
  my ($upd);
  $upd=sprintf("delete from outlet where id=%s and version=%s",
               $data->[0], $data->[1]);
  return $dbh->do($upd);
}

sub machineipsubnet_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header=sprintf("%53.53s %8.8s %8.8s\n%6.6s %30.30s %15.15s %8.8s %8.8s", 
                  "","Actual", "Correct", "Row id", "Hostname", 
                  "IP Address", "Subnet", "Subnet");
  &{$func}($arg, $header);
}

sub machineipsubnet_print_row {
  my ($func, $arg, $data)=@_;
  my ($string, $upd);
  
  $string=sprintf("%6.6s %30.30s %15.15s %8.8s %8.8s", 
                  $data->[0], $data->[2],
                  $data->[3], $data->[4], $data->[6]);
  &{$func}($arg, $string);
}

sub machineipsubnet_fix_row {
  my ($dbh, $data)=@_;
  my ($upd);
  $upd=sprintf("update machine set ip_address_subnet=%s where id=%s and version=%s",
               $data->[5], $data->[0], $data->[1]); 
  return $dbh->do($upd);
}

sub dupcable_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header=sprintf("%6.6s %14.14s %14.14s %6.6s %14.14s %14.14s", 
                  "Row id", "From", "To", "Row id", "From", "To");
  &{$func}($arg, $header);
}
sub dupcable_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string=sprintf("%6.6s %14.14s %14.14s %6.6s %14.14s %14.14s", 
                  $data->[0], $data->[2], $data->[3], $data->[4], 
		  $data->[5], $data->[6]);
  &{$func}($arg, $string);
}

sub dupip_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header=sprintf("%6.6s %45.45s %15.15s", 
                  "Row id", "Hostname", 
                  "IP Address");
  &{$func}($arg, $header);
}
sub dupip_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string=sprintf("%6.6s %45.45s %15.15s", 
                  $data->[0], $data->[2],
                  $data->[3]);
  &{$func}($arg, $string);
}

sub dupname_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header=sprintf("%6.6s %45.45s", 
                  "Row id", "Hostname");
  
  &{$func}($arg, $header);
}

sub dupname_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string=sprintf("%6.6s %45.45s", 
                  $data->[0], $data->[2]);
  &{$func}($arg, $string);
}

sub outletcable_print_header {
  my ($func, $arg) = @_;
  my ($header);
  $header = sprintf("%8.8s %25.25s %30.30s %8.8s", "Row Id", 
                    "Outlet Label", "Connected device", "port");
  &{$func}($arg, $header);
}

sub outletcable_print_row {
  my ($func, $arg, $data)=@_;
  my ($string, $upd, $label);
  $label=sprintf("%s/%s", $data->[2], $data->[3]);
  
  $string = sprintf("%8.8s %25.25s %30.30s %8.8s", $data->[0], $label,
                    $data->[4], $data->[5]);
  
  &{$func}($arg, $string); 
}
sub outletstatus_print_header {
  my ($func, $arg) = @_;
  my ($header);
  $header = "   Flag meanings: D = deactivate request P = permanent\n";
  $header .="                  A =   activate request e=enabled p=partitioned\n\n";
  $header .= sprintf("%6.6s %25.25s %25.25s %8.8s %4.4s %4.4s", "Row", 
		     "Outlet Label", "Connected device", "Port", "Flag", 
                     "Days");
  &{$func}($arg, $header);
}

sub outletstatus_print_row {
  my ($func, $arg, $data)=@_;
  my ($string, $upd, $label, $f);
  
  $label=sprintf("%s/%s", $data->[2], $data->[3]);
  $f="";
  $f.="D" if ($data->[6] eq "deactivate");
  $f.="A" if ($data->[7] =~ /activated/);
  $f.="P" if ($data->[7] =~ /permanent/);
  $f.="e" if ($data->[8] eq "enabled");
  $f.="p" if ($data->[8] eq "partitioned");
  
  $string = sprintf("%6.6s %25.25s %25.25s %8.8s %4.4s %4.4s", $data->[0], 
                    $label, $data->[4], $data->[5], $f, $data->[9]);
  
  &{$func}($arg, $string); 
}

sub outletvlan_print_header {
  my ($func, $arg) = @_;
  my ($header);
  $header .= sprintf("%6.6s %6.6s %17.17s %4.4s %10.10s %8.8s %6.6s %11.11s",
		     "Row", "Outlet ID", "Connected device", "Port", "Subnet", 
                     "Type", "Trunk", "Status");
  &{$func}($arg, $header);
}

sub outletvlan_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %6.6s %17.17s %4.4s %10.10s %8.8s %6.6s %11.11s",
		    $data->[0], $data->[2], $data->[3], $data->[4], $data->[5], $data->[6], $data->[7], $data->[8], $data->[9]);
  &{$func}($arg, $string);
}

sub stalebuilding_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%8.8s %20.20s %10.10s", "Row ID", "Name",
                    "Queue");
  &{$func}($arg, $header);
}

sub stalebuilding_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%8.8s %20.20s %10.10s",
		    $data->[0], $data->[2], $data->[3]);
  
  &{$func}($arg, $string);
}

sub illegal_machine_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %30.30s %45.45s", "Row ID",
		    "HostName", "Subnet");
  &{$func}($arg, $header);
}

sub illegal_machine_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %30.30s %45.45s",
		    $data->[0], $data->[2], $data->[3]);
  &{$func}($arg, $string);
}

sub stale_network_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %30.30s %45.45s", "Row ID", "name", 
		    "Subnet");
  &{$func}($arg, $header);
}

sub stale_network_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %30.30s %45.45s",
		    $data->[0], $data->[1], $data->[2]);
  &{$func}($arg, $string);
}

sub illegal_subnet_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %30.30s %45.45s %15.15s %15.15s", "Row ID", "name", 
		    "abbreviation", "dynamic", "mode");
  &{$func}($arg, $header);
}

sub illegal_subnet_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %30.30s %45.45s %15.15s %15.15s",
		    $data->[0], $data->[1], $data->[2], $data->[5], $data->[12]);
  &{$func}($arg, $string);
}

sub stale_subnet_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %30.30s %10.10s", "Row ID", "Name", 
		    "Share");
  &{$func}($arg, $header);
}

sub stale_subnet_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %30.30s %10.10s",
		    $data->[0], $data->[2], $data->[3]);
  &{$func}($arg, $string);
}

sub stale_subpresence_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %10.10s %10.10s", "Row ID", "Building", 
		    "Subnet");
  &{$func}($arg, $header);
}

sub stale_subpresence_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %10.10s %10.10s",
		    $data->[0], $data->[2], $data->[3]);
  &{$func}($arg, $string);
}

sub stale_subnet_domain_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %10.10s %30.30s", "Row ID", "Subnet", 
		    "Domain");
  &{$func}($arg, $header);
}

sub stale_subnet_domain_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %10.10s %30.30s",
		    $data->[0], $data->[2], $data->[3]);
  &{$func}($arg, $string);
}

sub stale_dhcp_option_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %6.6s %10.10s", "Row ID", "Type", 
		    "TID");
  &{$func}($arg, $header);
}

sub stale_dhcp_option_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %6.6s %10.10s",
		    $data->[0], $data->[2], $data->[3]);
  &{$func}($arg, $string);
}

sub stale_vlan_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %6.6s %6.6s", "Row ID", "Outlet", 
		    "Subnet");
  &{$func}($arg, $header);
}

sub stale_vlan_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %6.6s %6.6s",
		    $data->[0], $data->[2], $data->[3]);
  &{$func}($arg, $string);
}

sub service_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %15.15s %6.6s", "Row ID", "name", 
		    "type");
  &{$func}($arg, $header);
}

sub service_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %15.15s %6.6s",
		    $data->[0], $data->[1], $data->[2]);
  &{$func}($arg, $string);
}

sub service_membership_print_header {
  my ($func, $arg)=@_;
  my ($header);
  
  $header = sprintf("%6.6s %6.6s %6.6s", "Row ID", "machine", 
		    "service");
  &{$func}($arg, $header);
}

sub service_membership_print_row {
  my ($func, $arg, $data)=@_;
  my ($string);
  
  $string = sprintf("%6.6s %6.6s %6.6s",
		    $data->[0], $data->[1], $data->[2]);
  &{$func}($arg, $string);
}



sub myprint {
  my ($fh, $str)=@_;
  
  if (ref($fh) eq "GLOB") {
    print $fh $str . "\n";
  } else {
    print $str . "\n";
  }
}

sub mysprint {
  my ($buffer, $str)=@_;
  $$buffer .= $str;
  $$buffer .= "\n";
}


sub consis_query {
  my ($dbh, $flags, $queryname) =@_;
  my ($queryinfo, $rows, $query, $subject, $message, $data, $prfunc);
  my ($dofix, $domail, $quiet, $verbose, $rc);
  
  if (ref $flags) {
    $domail=defined($flags->{domail});
    $dofix=defined($flags->{dofix});
    $verbose=defined($flags->{verbose});
    $quiet=defined($flags->{quiet});
  }
  
  unless (defined $consistency_queries->{$queryname}) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Unknown consistency query $queryname\n" if ($verbose);
    return 0;
  }
  $queryinfo=$consistency_queries->{$queryname};
  die "consistency query $queryname is broken"
    unless (ref $queryinfo eq "HASH");
  die "consistency query $queryname is broken"
    unless (defined($queryinfo->{table}) and 
            defined($queryinfo->{other_tables}) and 
            defined($queryinfo->{where}));
  
  if ($queryinfo->{other_fields}) {
    $query=sprintf("select %s.id, %s.version, %s from %s %s where %s",
                   $queryinfo->{table}, $queryinfo->{table}, 
                   $queryinfo->{other_fields}, $queryinfo->{table},
                   $queryinfo->{other_tables}, $queryinfo->{where});
  } else {
    $query=sprintf("select %s.id, %s.version from %s %s where %s",
                   $queryinfo->{table}, $queryinfo->{table},
                   $queryinfo->{table}, $queryinfo->{other_tables},
                   $queryinfo->{where});
  }
  warn __FILE__, ':', __LINE__, ' :>'.
    "Executing: $query\n" if ($debug >= 2);
  $rows=$dbh->selectall_arrayref($query);
  if ($DBI::err) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "DB error $DBI::errstr while executing $queryname\n" 
	if ($verbose);
    return 0;
  };
  return 1 unless(@$rows);
  unless (defined($queryinfo->{print_header}) and 
          defined($queryinfo->{print_row}) and 
          ref($queryinfo->{print_header}) eq "CODE" and 
          ref($queryinfo->{print_row}) eq "CODE") { 
    warn __FILE__, ':', __LINE__, ' :>'.
      "Query $queryname has no output functions\n" 
	if ($verbose);
    return 0;
  }
  
  unless (defined($queryinfo->{fix_row}) and 
          ref($queryinfo->{fix_row}) eq "CODE") { 
    warn __FILE__, ':', __LINE__, ' :>'.
      "Query $queryname has no fix functions\n" 
	if ($dofix and $verbose);
    $dofix=0;
  }
  
  if ($domail or $quiet) {
    $subject="Consistency report: $queryinfo->{title} in table $queryinfo->{table}\n";
    $prfunc=\&mysprint;
  } else {
    print "$queryinfo->{title} in table $queryinfo->{table}\n";
    $prfunc=\&myprint;
  }
  
  &{$queryinfo->{print_header}}($prfunc, \$message);
  foreach $data (@$rows) {
    &{$queryinfo->{print_row}}($prfunc, \$message, $data);
    &{$queryinfo->{fix_row}}($dbh, $data) if ($dofix);
  }
  if ($domail) {
    if (! exists $queryinfo->{primary_contact}) {
      CMU::Netdb::netdb_mail("", $message, $subject);
    } else {
      CMU::Netdb::netdb_mail("", $message, $subject, $queryinfo->{primary_contact});
    }
  }
  return 2;
}

sub run_all_queries {
  my ($dbh, $flags)=@_;
  my ($queryname, $res, $tot, $bad, $errors, $logfile, $nolog, $fh, $t);
  my ($verbose);
  if (ref $flags) {
    $nolog = defined($flags->{nolog});
    $verbose = defined($flags->{verbose});
  }
  foreach $queryname (sort keys %$consistency_queries) {
    print "Running $queryname\n" if ($verbose);
    $res = consis_query($dbh, $flags, $queryname);
    $tot++;
    $errors++ if ($res == 0);
    $bad++ if ($res == 2);
  }
  unless ($nolog) {
    $fh = new IO::File '>/home/netreg/logs/consistency.log' or return 1;
    $t = localtime(time);
    if ($errors) {
      print $fh "$t Consistency checker ran $tot checks\n\tfound problems in $bad categories\n\t$errors tests failed (BUG!)\n";
    } else {
      print $fh "$t Consistency checker ran $tot checks\n\tfound problems in $bad categories\n";
    }
  }
}

1;
