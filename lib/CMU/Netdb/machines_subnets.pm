#   -*- perl -*-
#
# CMU::Netdb::machines_subnets
# This module provides the necessary API functions for
# manipulating the machine & subnet tables.
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
# $Id: machines_subnets.pm,v 1.164 2008/05/15 17:56:41 vitroth Exp $
#


package CMU::Netdb::machines_subnets;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug @machine_fields 
	    @subnet_fields @subnet_share_fields @subnet_presence_fields 
	    @subnet_domain_fields @subnet_domain_zone_fields
            @domain_subnet_fields
 	    @network_fields $IPSuperMask
	    @subnet_registration_modes_fields
	    %AllocationMethods @vlan_fields @vlan_subnet_presence_fields
	    @vlan_subnet_presence_subnetvlan_fields);
	    

use CMU::Netdb;
use CMU::Netdb::helper;
use CMU::Netdb::primitives;
use CMU::Netdb::structure;
use CMU::Netdb::errors;
use CMU::Netdb::auth;
use CMU::Netdb::validity;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::dhcp_lease_search;

use Data::Dumper;

BEGIN {
  require CMU::Netdb::config; import CMU::Netdb::config;
  my ($vres, $ab_suspend) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'AUTHBRIDGE_SUSPEND');

  if ($ab_suspend == 1) {
    require CMU::AuthBridge; import CMU::AuthBridge;
    require CMU::AuthBridge::AuthBridge; import CMU::AuthBridge::AuthBridge;
  }
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     get_machine_modes
	     list_machines list_machines_munged_protections
	     list_machines_fw_zones list_machines_rv_zones
	     list_machines_subnets list_machines_protections
	     add_machine
	     modify_machine
	     delete_machine
	     expire_machine
	     count_machines

	     get_subnets get_subnets_ref get_subnets_with_presence
	     get_subnet_registration_modes list_subnet_registration_modes
	     list_subnets list_subnets_ref
	     add_subnet
	     modify_subnet
	     purged_subnet
	     delete_subnet
	     register_ips

	     list_subnet_shares list_subnet_shares_ref
	     add_subnet_share
	     modify_subnet_share
	     delete_subnet_share

	     list_subnet_presences
	     list_vlan_subnet_presences
	     list_subnet_building_presences
	     add_subnet_presence
	     modify_subnet_presence
	     delete_subnet_presence

	     list_subnet_domains
	     list_domain_subnets
	     get_domains_for_subnet
	     add_subnet_domain
	     add_subnet_registration_mode
	     modify_subnet_domain
	     delete_subnet_domain
	     delete_subnet_registration_mode

	     get_networks_ref
	     list_networks
	     add_network
	     modify_network
	     delete_network

	     get_subnet_vlan_presence
	     get_vlan_subnet_presence

	     search_leases
	    );


@machine_fields = @CMU::Netdb::structure::machine_fields;
@subnet_fields = @CMU::Netdb::structure::subnet_fields;
@subnet_share_fields = @CMU::Netdb::structure::subnet_share_fields;
@subnet_presence_fields = @CMU::Netdb::structure::subnet_presence_fields;
@subnet_domain_fields = @CMU::Netdb::structure::subnet_domain_fields;
@subnet_domain_zone_fields = @CMU::Netdb::structure::subnet_domain_zone_fields;
@domain_subnet_fields = @CMU::Netdb::structure::domain_subnet_fields;
@subnet_registration_modes_fields = @CMU::Netdb::structure::subnet_registration_modes_fields;
@network_fields = @CMU::Netdb::structure::network_fields;

@vlan_fields = @CMU::Netdb::structure::vlan_fields;
@vlan_subnet_presence_fields = @CMU::Netdb::structure::vlan_subnet_presence_fields;
@vlan_subnet_presence_subnetvlan_fields = @CMU::Netdb::structure::vlan_subnet_presence_subnetvlan_fields;

$IPSuperMask = '(0x100000000 - 1)';
%AllocationMethods = %CMU::Netdb::structure::AllocationMethods;

$debug = 0;

# Function: get_machine_modes
# Arguments: 2:
#     An already connected database handle
#     The name of the user making the request
#     The subnet to get modes for
#     An optional fourth argument thats causes the return structure 
#       to contain more data, and be a hash.
# Actions: Based on the user's ID, returns the valid modes that the user
#          can select
# Return value:
#    A reference to an array containing the valid modes, or a hash containing
#     the registration quotas.
#    On error, a return code
sub get_machine_modes {
  my ($dbh, $dbuser, $subnet, $extra) = @_;
  my $ul = CMU::Netdb::get_add_level($dbh, $dbuser, 'machine', 0);
  return [] if ($ul <= 0);
  my $filterDynamics = 0;
  my $filterStatics = 0;
  my $filterSecondaries = 0;
  my $slr;

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($dbuser) 
    if (CMU::Netdb::validity::getError($dbuser) != 1);

  $subnet = CMU::Netdb::validity::valid('subnet.id', $subnet, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($subnet) 
    if (CMU::Netdb::validity::getError($subnet) != 1);

  my $res = CMU::Netdb::get_subnet_registration_modes($dbh, $dbuser, "subnet_registration_modes.subnet = '$subnet'");
  return ($res) if (!ref $res);
  my $quota_map = CMU::Netdb::makemap(shift @$res);
  my %quotas;
  foreach my $quota (@$res) {
    my $mode = $quota->[$quota_map->{'subnet_registration_modes.mode'}];
    my $limit = $quota->[$quota_map->{'subnet_registration_modes.quota'}];
    my $mac_address = $quota->[$quota_map->{'subnet_registration_modes.mac_address'}];

    if (!exists($quotas{$subnet}{$mode}{$mac_address})) {
      $quotas{$subnet}{$mode}{$mac_address} = $limit;
    } elsif (defined($quotas{$subnet}{$mode}{$mac_address}) && 
	     (!defined($limit) || ($limit > $quotas{$subnet}{$mode}{$mac_address}))) {
      $quotas{$subnet}{$mode}{$mac_address} = $limit;
    }
  }

  warn __FILE__, ':', __LINE__, " :> Quotas retrieved for $subnet:\n" .
    Data::Dumper->Dump([%quotas],['quotas']) if ($debug >= 2);

  my @rA;
  if (!$extra) {
    foreach my $mode (keys %{$quotas{$subnet}}) {
      push @rA, $mode;
    }
  }

  $slr = CMU::Netdb::get_subnets_ref($dbh, $dbuser, "subnet.id = '$subnet'", 'subnet.default_mode');
  if (ref $slr && ($slr->{$subnet} ne "")) {
    if (!$extra) {
      @rA = grep(!/^$slr->{$subnet}$/, @rA);
      unshift(@rA, $slr->{$subnet});
    } else {
      $quotas{$subnet}{'_default_mode'} = $slr->{$subnet};
    }
  }
  return \@rA if (!$extra);
  return $quotas{$subnet};
}

# Function: list_machines
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Querie the database in the handle for rows in
#          the machine table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_machines {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::validity::valid
    ('credentials.authid', $dbuser, $dbuser, 0, $dbh);

  return CMU::Netdb::validity::getError($dbuser) 
    if (CMU::Netdb::validity::getError($dbuser) != 1);
 
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "machine", \@machine_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@machine_fields];
  }
  
  @data = @$result;
  unshift @data, \@machine_fields;
  
  return \@data;
}

# Function list_machines_protections
# see list_machine
# Adds protection array to end of each row
#
sub list_machines_protections {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, $data, $header, $dapos, $prots);

  $data = list_machines($dbh, $dbuser, $where);
  return($data) if (! ref $data);

  $header = shift(@$data);
  $header = [ @$header, "protections" ];

  $dapos = CMU::Netdb::makemap($header);

  foreach (@$data) {
    print STDERR ".";
    push (@$_, CMU::Netdb::list_protections($dbh, $dbuser, 'machine', $_->[$dapos->{'machine.id'}]));
  }
  unshift(@$data, $header);
  return($data);
}

# Function: list_machines_subnets
# see list_machines
sub list_machines_subnets {
  my ($dbh, $dbuser, $where) = @_;
  my (@fields, $result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $where = '1' if ($where eq '');
  my $nwhere = "subnet.id = machine.ip_address_subnet AND $where";
  
  @fields = @machine_fields;
  push @fields, @subnet_fields;
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "machine, subnet", \@fields, $nwhere);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@fields];
  }
  
  @data = @$result;
  unshift @data, \@fields;
  
  return \@data;
}

# Function: list_machines_fw_zones
# see list_machines
sub list_machines_fw_zones {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $where = '1' if ($where eq '');
  my $nwhere = "dns_zone.id = machine.host_name_zone AND $where";
  
  my @f = (@machine_fields, @CMU::Netdb::structure::dns_zone_fields);
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "machine, dns_zone", 
					 \@f, $nwhere);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@f];
  }
  
  @data = @$result;
  unshift @data, \@f;
  
  return \@data;
}

# Function: list_machines_rv_zones
# see list_machines
sub list_machines_rv_zones {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $where = '1' if ($where eq '');
  my $nwhere = "dns_zone.id = machine.ip_address_zone AND $where";
  
  my @f = (@machine_fields, @CMU::Netdb::structure::dns_zone_fields);
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "machine, dns_zone", 
					 \@f, $nwhere);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@f];
  }
  
  @data = @$result;
  unshift @data, \@f;
  
  return \@data;
}

# Function: list_machines_munged_protections
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     The type of protection munging
#     Input to munging as necessary
#     Additional where clause
#
# This is for (primarily) the mainpage query which can have well-optimized
# SQL calls given what it is trying to accomplish. I hate making another
# API call for this, but speeding up accesses by multiple seconds for every
# mainpage hit seems like a good idea to me

# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_machines_munged_protections {
  my ($dbh, $dbuser, $type, $in, $where) = @_;
  my ($result, @data, $query, $sth);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  if ($type eq 'USER') {
    if ($in =~ /^\d+$/) {

      # If the user can't read the whole table, deny the search unless they're looking up
      # their own machines.
      if (CMU::Netdb::get_read_level($dbh, $dbuser, 'machine', 0) < 1) {
	my $users = CMU::Netdb::list_users($dbh, $dbuser, "credentials.authid = '$dbuser' AND users.id = $in");
	if (!ref $users || $#$users == 0) {
	  return $errcodes{EPERM};
	}
      }

      $query = "SELECT STRAIGHT_JOIN DISTINCT ".join(', ', @CMU::Netdb::structure::machine_fields)."\n"."
FROM protections as P, machine
WHERE P.identity = $in
 AND P.tname = 'machine'
 AND FIND_IN_SET('READ', P.rights)
 AND P.tid = machine.id
";

    } else {

      # If the user can't real the whole table, deny the search unless they're looking up
      # their own machines.
      if (CMU::Netdb::get_read_level($dbh, $dbuser, 'machine', 0) < 1
	  && $dbuser ne $in) {
	return $errcodes{EPERM};
      }

      $in = CMU::Netdb::valid('credentials.authid', $in, $dbuser, 0, $dbh);
      return CMU::Netdb::getError($in) if (CMU::Netdb::getError($in) != 1);

      $query = "SELECT STRAIGHT_JOIN DISTINCT ".join(', ', @CMU::Netdb::structure::machine_fields)."\n"."
FROM credentials AS C, protections as P, machine
WHERE C.authid = '$in'
 AND P.tname = 'machine'
 AND FIND_IN_SET('READ', P.rights)
 AND C.user = P.identity
 AND P.tid = machine.id
";
    }
  }elsif($type eq 'GROUP') { 

    # if group, make sure they belong to this group, or can read the whole table
    if (CMU::Netdb::get_read_level($dbh, $dbuser, 'machine', 0) < 1) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Verifying group membership.\n" if ($debug >= 2);
      my $gmem = CMU::Netdb::list_members_of_group($dbh, 'netreg', $in, 
						   "credentials.authid = '$dbuser'");
      if (!ref $gmem || !defined $gmem->[1]) {
	return $errcodes{EPERM};
      }
    }

   if ($in =~ /^\d+$/) {
      $in = $in*-1;

      if (CMU::Netdb::can_read_all($dbh, $dbuser, 'machine', "(P.identity = '$in')", '')) {
        $query = "SELECT ".join(', ', @CMU::Netdb::structure::machine_fields)." FROM machine WHERE 1\n";
      } else {
        $query = "SELECT STRAIGHT_JOIN DISTINCT ".join(', ', @CMU::Netdb::structure::machine_fields)."
FROM credentials AS C, memberships as M, protections as P, machine
WHERE C.authid = '$dbuser'
 AND P.tname = 'machine'
 AND P.identity = '$in'
 AND FIND_IN_SET('READ', P.rights)
 AND C.user = M.uid AND CAST(M.gid AS SIGNED INT)*-1 = P.identity
 AND P.tid = machine.id
";
      }
    } else {
      $in = CMU::Netdb::valid('groups.name', $in, $dbuser, 0, $dbh);
      return CMU::Netdb::getError($in) if (CMU::Netdb::getError($in) != 1);

      $query = "SELECT STRAIGHT_JOIN DISTINCT ".join(', ', @CMU::Netdb::structure::machine_fields)."
FROM groups as G, protections as P, machine 
WHERE G.name = '$in'
 AND P.tname = 'machine'
 AND P.identity = G.id * -1
 AND FIND_IN_SET('READ', P.rights)
 AND P.tid = machine.id
";
    }
  } elsif ($type eq 'WRITE') {
    if ($in =~ /^\d+$/) {
      # If the user can't read the whole table, deny the search unless they're looking up
      # their own machines.
      if (CMU::Netdb::get_read_level($dbh, $dbuser, 'machine', 0) < 1) {
	my $users = CMU::Netdb::list_users($dbh, $dbuser, "credentials.authid = '$dbuser' AND users.id = $in");
	if (!ref $users || $#$users == 0) {
	  return $errcodes{EPERM};
	}
      }

  $query = "SELECT DISTINCT " . (join ', ', @CMU::Netdb::structure::machine_fields) . "
FROM  users as U
 JOIN protections as P
 LEFT JOIN memberships as M 
  ON (M.uid = U.id AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
 JOIN machine
WHERE U.id = $in
AND P.tname = 'machine'
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, U.id, 0)
AND FIND_IN_SET('WRITE', P.rights)
AND (P.tid = machine.id OR P.tid=0)
";

    } else {

      # If the user can't read the whole table, deny the search unless they're looking up
      # their own machines.
      if ((CMU::Netdb::get_read_level($dbh, $dbuser, 'machine', 0) < 1)
          && lc($dbuser) ne lc($in)) {
	return $errcodes{EPERM};
      }


  $query = "SELECT DISTINCT " . (join ', ', @CMU::Netdb::structure::machine_fields) . "
FROM  credentials AS C
 JOIN users as U ON C.user = U.id
 JOIN protections as P
 LEFT JOIN memberships as M ON (M.uid = U.id AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
 JOIN machine
WHERE C.authid = '$in'
AND P.tname = 'machine'
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, U.id, 0)
AND FIND_IN_SET('WRITE', P.rights)
AND (P.tid = machine.id OR P.tid = 0)
";
    }


  }elsif($type eq 'ALL') {
    return CMU::Netdb::list_machines($dbh, $dbuser, $where);
  }else{
    return $errcodes{ERROR};
  }
  $query .= " AND $where" if ($where ne '');
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::machines_subnets::list_machines_munged_protections query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::list_machines_munged_protections error: $DBI::errstr" if ($debug >= 2);
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{"EDB"};
  } else {
    my $rows = $sth->fetchall_arrayref();
    if (ref $rows) {
      CMU::Netdb::primitives::prune_restricted_fields($dbh, $dbuser, $rows, \@CMU::Netdb::structure::machine_fields);
      my @data = @$rows;
      unshift @data, \@machine_fields;
      return \@data;
    } else {
      return [\@machine_fields];
    }
  }
}

sub get_machine_version {
  my ($dbh, $dbuser, $where) = @_;
  my ($ml, $i, $vf);
  
  $ml = CMU::Netdb::list_machines($dbh, $dbuser, $where);
  $i = 0;
  foreach (@{$ml->[0]}) {
    $vf = $i if ($_ eq 'machine.version');
    $i++;
  }
  return ${$ml->[1]}[$vf];
}


# Function: list_subnets
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the subnet table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnets {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Entering list_subnets ($dbuser)\n" if ($debug >= 2);
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  if (CMU::Netdb::getError($dbuser) != 1) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "ERROR executing credentials.authid verification\n" if ($debug >= 2);
    return CMU::Netdb::getError($dbuser);
  }
  warn  __FILE__, ':', __LINE__, ' :>'.
    "User is now: $dbuser\n" if ($debug >= 2);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "subnet", \@subnet_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@subnet_fields];
  }
  
  @data = @$result;
  unshift @data, \@subnet_fields;
  
  return \@data;
}

# Function: get_subnets
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the subnet table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_subnets {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Entering get_subnets ($dbuser)\n" if ($debug >= 2);
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  if (CMU::Netdb::getError($dbuser) != 1) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "ERROR executing credentials.authid verification\n" if ($debug >= 2);
    return CMU::Netdb::getError($dbuser);
  }
  warn  __FILE__, ':', __LINE__, ' :>'.
    "User is now: $dbuser\n" if ($debug >= 2);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "subnet", \@subnet_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@subnet_fields];
  }
  
  @data = @$result;
  unshift @data, \@subnet_fields;
  
  return \@data;
}

# Function: list_networks
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the building table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_networks {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "network", \@network_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@network_fields];
  }
  
  @data = @$result;
  unshift @data, \@network_fields;
  
  return \@data;
  
}

# Function: list_subnet_shares
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the subnet_share table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnet_shares {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "subnet_share", \@subnet_share_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@subnet_share_fields];
  }
  
  @data = @$result;
  unshift @data, \@subnet_share_fields;
  
  return \@data;
  
}

# Function: list_subnet_shares_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the subnet_share table which conform to the WHERE clause (if any)
# Return value:
#     An associative array of the possible values
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnet_shares_ref {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, %rbdata, @fields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @fields = ('subnet_share.id', 'subnet_share.name');
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "subnet_share", \@fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}


# Function: list_subnet_presences
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the subnet_presence table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnet_presences {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @fields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $where .= " AND " if ($where ne '');
  $where .= " vlan.id = vlan_subnet_presence.vlan AND subnet.id = vlan_subnet_presence.subnet ";
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "vlan_subnet_presence, vlan, subnet", \@vlan_subnet_presence_subnetvlan_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@vlan_subnet_presence_subnetvlan_fields];
  }
  
  @data = @$result;
  unshift @data, \@vlan_subnet_presence_subnetvlan_fields;
  
  return \@data;
  
}

# Function: list_subnet_building_presences
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the subnet_presence table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnet_building_presences {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @fields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $where .= " AND " if ($where ne '');
  $where .= " building.building = subnet_presence.building AND subnet.id = subnet_presence.subnet ";
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "subnet_presence, building, subnet", \@subnet_presence_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@subnet_presence_fields];
  }
  
  @data = @$result;
  unshift @data, \@subnet_presence_fields;
  
  return \@data;
  
}

# Function: get_subnets_with_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the subnet ID and name 
#          for the subnet_presence rows specified
# Return value:
#     A reference to an associative array of subnet_presence.subnet =>
#        subnet.name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_subnets_with_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('subnet_presence.subnet', 'subnet.name');
  $lwhere = 'subnet_presence.subnet = subnet.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "subnet, subnet_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: list_subnets_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (subnet.name or subnet.abbrevation, mostly)
# Actions: Queries the database and retrieves the subnet ID and name 
#          for the subnet_presence rows specified
# Return value:
#     A reference to an associative array of subnet.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnets_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('subnet.id', $efield);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "subnet", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: get_subnets_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (subnet.name or subnet.abbrevation, mostly)
# Actions: Queries the database and retrieves the subnet ID and name 
#          for the subnet_presence rows specified
# Return value:
#     A reference to an associative array of subnet.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_subnets_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('subnet.id', $efield);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "subnet", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: get_subnets_mode_quotas
# Arguments: 4:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the data
#          for the matching rows in the subnet_registration_modes
#          on which the user as ADD permission
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_subnet_registration_modes {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);


  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "subnet_registration_modes", \@CMU::Netdb::structure::subnet_registration_modes_fields, $where);

  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@CMU::Netdb::structure::subnet_registration_modes_fields];
  }
  
  @data = @$result;
  unshift @data, \@CMU::Netdb::structure::subnet_registration_modes_fields;
  
  return \@data;

}

# Function: list_subnets_registration_modes
# Arguments: 4:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the data
#          for the matching rows in the subnet_registration_modes 
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnet_registration_modes {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);


  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "subnet_registration_modes", \@CMU::Netdb::structure::subnet_registration_modes_fields, $where);

  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@CMU::Netdb::structure::subnet_registration_modes_fields];
  }
  
  @data = @$result;
  unshift @data, \@CMU::Netdb::structure::subnet_registration_modes_fields;
  
  return \@data;

}



# Function: get_networks_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (subnet.name or subnet.abbrevation, mostly)
# Actions: Queries the database and retrieves the subnet ID and name 
#          for the subnet_presence rows specified
# Return value:
#     A reference to an associative array of subnet.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_networks_ref {
  my ($dbh, $dbuser, $where, $field1, $field2) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ($field1, $field2);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "network", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: get_domains_for_subnet
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Lists the domains that can be in a particular subnet (via WHERE)
# Return value:
#     A reference to an array of the domains
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_domains_for_subnet {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @lfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('subnet_domain.domain');
  
  my $nwhere = 'dns_zone.name = subnet_domain.domain ';
  $nwhere .= ' AND '.$where if ($where ne '');
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "dns_zone, subnet_domain", \@lfields, $nwhere);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [];
  }
  
  map { push(@data, $_->[0]) } @$result;
  
  return \@data;
  
}

# Function: list_domain_subnets
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database in the handle for joit entries in the
#          subnet and subnet_domain tables which conform to the WHERE clause
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_domain_subnets {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $result = CMU::Netdb::primitives::list($dbh, $dbuser,
             "subnet_domain join subnet on subnet_domain.subnet = subnet.id",
             \@domain_subnet_fields, $where);

  if (!ref $result) {
    return $result;
  }

  if ($#$result == -1) {
    return [\@domain_subnet_fields];
  }

  @data = @$result;
  unshift @data, \@domain_subnet_fields;

  return \@data;

}

# Function: list_subnet_domains
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
#     $withzone - join to the zone table if true
# Actions: Queries the database in the handle for rows in
#          the subnet_domain table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_subnet_domains {
  my ($dbh, $dbuser, $where, $withzone) = @_;
  my ($result, @data);
  my $fields_ref = \@subnet_domain_fields;



  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
 if ($withzone) {
    $fields_ref = \@subnet_domain_zone_fields;
    $result = CMU::Netdb::primitives::list($dbh, $dbuser,
          "subnet_domain join dns_zone on dns_zone.name = subnet_domain.domain",
          $fields_ref, $where);
  } else {
    $result = CMU::Netdb::primitives::list($dbh, $dbuser,
          "subnet_domain",
          $fields_ref, $where);
  }
  

  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [$fields_ref];
  }
  
  @data = @$result;
  unshift @data, $fields_ref;
  
  return \@data;
  
}

## This does the add_machine when mode == secondary.
## see add_machine
sub add_mod_machine_secondary {
  my ($dbh, $dbuser, $ul, $fields, $upd, $prev, $version) = @_;  
  
  my %ofields = %$prev if (ref $prev);
  
  # clean fields
  my ($key,$newfields);
  foreach $key (keys %$fields) {
    if (! grep /^machine\.$key$/, @machine_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find machine.$key!\n".Dumper($fields, \@machine_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    #verifying the ip address causes hell later since it uses dot2long
    next if ($key eq 'ip_address');
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "machine.$key: $$fields{$key}\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("machine.$key", $$fields{$key}, $dbuser, $ul, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "machine.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"machine.$key"} = $$fields{$key};
  }
  
  my $subnet = $$newfields{'machine.ip_address_subnet'};
  
  # make sure that this is secondary to something non-secondary 
  # on the same subnet
  my $priref = &CMU::Netdb::list_machines($dbh,'netreg',"machine.mac_address='".$$newfields{'machine.mac_address'}."' AND machine.mode != 'secondary' AND machine.ip_address_subnet=".$subnet);  
  if (!ref $priref->[1]) {
    return ($CMU::Netdb::errcodes{'ENOENT'},['machine.mac_address']);
  }
  
  # FIXME, secondary quotas?!?
  #sub check_registration_quota {
  #my ($dbh, $dbuser, $subnet, $type, $virtual, $update, $subnet_changed, $mode_changed, $was_virtual) = @_;
  if ($upd == 0) {
    my ($res, $reason) = check_registration_quota($dbh, $dbuser, $subnet, 'secondary', 0, 0, 0, 0, 0);

    return ($res, $reason) if ($res <= 0);

  }
  # check quota
#   if ($upd == 0) {
#     my $secref = &CMU::Netdb::list_machines($dbh,'netreg',"machine.mac_address='".$$newfields{'machine.mac_address'}."' AND machine.mode = 'secondary' AND machine.ip_address_subnet=".$subnet);  
#     my $sul = CMU::Netdb::get_add_level($dbh, $dbuser, 'subnet', $subnet);
#     if ($sul < 1) {
#       return ($CMU::Netdb::errcodes{'EPERM'},['machine.ip_address_subnet']);
#     } elsif ($sul < 5) {
#       return ($CMU::Netdb::errcodes{'ESECONDARYQUOTA'},['machine.ip_address_subnet'])
#         if ($#$secref > 0);	  
#     }
#   }
  
#   # make sure that secondaries are allowed on this subnet
#   my $suref = CMU::Netdb::list_subnets($dbh, $dbuser, "subnet.id = $subnet AND FIND_IN_SET('allow_secondaries', subnet.flags)", 'subnet.flags');
#   return ($errcodes{ENOSECONDARY}, ['ip_address_subnet'])
#     if (!ref $suref || !defined $suref->[1]);
  
  # try to add the machine statically
  return &add_mod_machine_static($dbh, $dbuser, $ul, $fields, $upd, $prev, $version);
}

## This does the add_machine when mode == static. 
## see add_machine
## $upd is 0 if adding, > 0 otherwise
sub add_mod_machine_static {
  my ($dbh, $dbuser, $ul, $fields, $upd, $prev, $version) = @_;
  my ($key, $newfields, $domain, $ip, @ipc, $hzones, @hzones, %warns, $host, $noHostname);
  my $sul = CMU::Netdb::get_add_level($dbh,$dbuser,'subnet',$$fields{'ip_address_subnet'});
  
  my %ofields = %$prev if (ref $prev);
  
  # first, if the user is not high level, we're gonna clean up the input a bit
  # and make sure they aren't trying to pull any fast ones
  if ($ul < 5) {
    if (!$upd) {
      map { $$fields{$_} = ''; }
      ('comment_lvl5');
    }else{
      map { $$fields{$_} = $ofields{$_} } 
      ('comment_lvl5');
    }
  }
  
  unless ($ul >= 9) {
    # reset restricted fields
    if (!$upd) {
      map { $$fields{$_} = ''; }
      ('comment_lvl9', 'flags', 'account', 'host_name_ttl', 'ip_address_ttl');
      $$fields{'ip_address'} = ''
        unless($sul >= 5);
    }else{
      map { $$fields{$_} = $ofields{$_} } 
      ('comment_lvl9', 'flags', 'account', 'host_name_ttl', 'ip_address_ttl');
      warn  __FILE__, ':', __LINE__, ' :>'.
	"2 IP: $ofields{ip_address}\n" if ($debug >= 2);
      $$fields{ip_address} = '' if ($ofields{ip_address} eq '0');
      $$fields{ip_address} = CMU::Netdb::long2dot($ofields{ip_address})
        if ($$fields{ip_address} ne '' && $sul < 5);
      warn  __FILE__, ':', __LINE__, ' :>'.
	"3 IP: $$fields{ip_address}\n" if ($debug >= 2);
    }
  }


  warn  __FILE__, ':', __LINE__, ' :>'.
    "#### add_mod_machine_static entered. ($upd)\n" if ($debug >= 2);
  
  # if the ip address is set, make sure it isn't a broadcast or broadcast 
  if ($$fields{ip_address} ne '') {
    warn  __FILE__, ':', __LINE__, ' :>'.
      " ### IP Address: $$fields{'ip_address'}\n" if ($debug >= 2);
    $ip = CMU::Netdb::dot2long($$fields{'ip_address'});
    #$ip = $$fields{'ip_address'};
    my $IPSuperMask = '(0xffffffff)';
    $hzones = CMU::Netdb::list_subnets_ref($dbh, $dbuser, " ((base_address |".
					   "(~network_mask&$IPSuperMask)) ".
					   " ='$ip' ".
					   "OR base_address = '$ip')", 
					   'subnet.name');
    return ($hzones, ['ip_address']) if (!ref $hzones);
    my $hzk = keys %$hzones;
    return ($errcodes{EBROADCAST}, ['ip_address']) if ($hzk >= 1);

  }


  # figure out the host_name_zone
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Host Name: $$fields{'host_name'}\n" if ($debug >= 2);
  return ($errcodes{EINVALID}, ['host_name']) if ($$fields{'host_name'} eq '');
  # Patch: Correctly identifying host_name and domain e.g. andrew.cmu.edu where
  # andrew is host_name and cmu.edu is domain, and not domain = andrew.cmu.edu
  ($host, $domain) = splitHostname($$fields{'host_name'});
  @hzones = keys %{CMU::Netdb::list_zone_ref($dbh, $dbuser,
					     "dns_zone.name = '$domain' ", 'GET')};
  return ($errcodes{EDOMAIN}, ['host_name']) if ($#hzones != 0);
  $$fields{'host_name_zone'} = $hzones[0];

  ## Verify that the domain is allowed on the subnet
  if ($upd == 0 || $ofields{host_name} ne $$fields{host_name}) {
    my $subnet = $$fields{'ip_address_subnet'};
    my $sul = CMU::Netdb::get_add_level($dbh, $dbuser, 'subnet', $subnet);
    my $ldsr = CMU::Netdb::get_domains_for_subnet($dbh, $dbuser, 
						  "subnet_domain.domain = '$domain' and subnet_domain.subnet = '$subnet'");
    return ($ldsr, ['host_name']) if (!ref $ldsr);
    my $ldsc = $#$ldsr;
    return ($errcodes{EBADIP}, ['host_name']) if ($sul < 9 && $ldsc < 0);
  }
  
  ## if they set the IP (L9) and also the ip_address_subnet, make sure 
  ## they match. Also verify that this address is not already registered.
  if ($$fields{'ip_address'} ne '') {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "### IP is: $$fields{'ip_address'}\n" if ($debug >= 2);
    if ($$fields{'ip_address'} =~ /^\d+\.\d+\.\d+\.\d+$/) {
      $ip = CMU::Netdb::dot2long($$fields{'ip_address'});
    } else {
      $ip = $$fields{'ip_address'};
    }
    $hzones = CMU::Netdb::list_subnets_ref($dbh, $dbuser, " (base_address = ('$ip' & network_mask)) ", 'subnet.name');
    return ($hzones, ['ip_address']) if (!ref $hzones);
    my $hzk = keys %$hzones;
    my @hza = keys %$hzones;
    # $hzk=1 means list_subnets_ref returned exactly one match
    return ($errcodes{ESUBNET}, ['ip_address',$$fields{'ip_address'}," foobar (base_address = ('$ip' & network_mask))"]) if ($hzk != 1);
    return ($errcodes{EBADIP}, ['ip_address']) if ($$fields{'ip_address_subnet'} != $hza[0]);
    my $hip;
    if ($upd) {
      $hip = CMU::Netdb::list_machines($dbh, 'netreg', "machine.ip_address=$ip AND machine.id != " . $ofields{'id'});
    } else {
      $hip = CMU::Netdb::list_machines($dbh, 'netreg', "machine.ip_address=$ip");
    }
    return ($hip, ['ip_address']) if (!ref ($hip));
    # count the rows in the array
    $hip=@$hip;
    # $hip=1 means list_machines returned no matches
    return ($errcodes{EEXISTS}, ['ip_address']) if ($hip != 1);
  }
  
  $noHostname = 0;
  # ugly hack - if there is no hostname, we'll assign one, but we tack on 
  # a default hostname to get through the CMU::Netdb::validity checking
  if ($host eq '') {
    $noHostname = 1;
    $$fields{'host_name'} = "HOSTNAME-UNASSIGNED.$domain";
  }
  
  # Check for permission to add static hosts, and registration quotas.
  my ($virtual, $subnet_changed, $mode_changed, $was_virtual);
  $virtual = $$fields{'mac_address'} eq '' ? 1 : 0;
  $subnet_changed = $$fields{'ip_address_subnet'} != $ofields{'ip_address_subnet'} ? 1 : 0;
  $mode_changed = $$fields{'mode'} ne $ofields{'mode'} ? 1 : 0 ;
  $was_virtual = $ofields{'mac_address'} eq '' ? 1 : 0 ;

  my ($res, $reason) = check_registration_quota($dbh, $dbuser, $$fields{'ip_address_subnet'}, 'static', 
						$virtual, $upd, $subnet_changed, $mode_changed, $was_virtual);

  return ($res, $reason) if ($res <= 0);

  warn  __FILE__, ':', __LINE__, ' :>'.
    "##### Entering bidirectional verification stage in add_mod_machine_satic.\n" if ($debug >= 3);
  ## bidirectional verification of the fields that the user is trying to add
  
  ## WARNING: ip_address_zone should be OKAY'd even if it isn't a number
  ## since it won't be set until we actually know the IP address
  foreach $key (@machine_fields) {
    my $nk = $key;		# required because $key is a reference into machine_fields
    $nk =~ s/^machine\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^machine\.$key$/, @machine_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find machine.$key!\n".Dumper($fields, \@machine_fields) if ($debug >= 3);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 3);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "machine.$key: $$fields{$key}\n" if ($debug >= 3);
    $$fields{$key} = CMU::Netdb::valid("machine.$key", $$fields{$key}, $dbuser, $ul, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "machine.$key: $$fields{$key}\n" if ($debug >= 3);
    
    $$newfields{"machine.$key"} = $$fields{$key};
}
  
  delete($$newfields{'machine.created'}) if ($upd);


  $dbh->do("LOCK TABLES machine WRITE, machine AS M1 READ, machine as M2 READ,
subnet AS S1 READ, subnet AS S2 READ, users as U READ, groups as G READ,
protections as P read, dns_zone READ, memberships as M READ, subnet READ,
dns_resource as DR read, _sys_changelog WRITE , _sys_changerec_row WRITE,
_sys_changerec_col WRITE, credentials AS C READ");
  
  
  if ($$newfields{'machine.mac_address'} ne '' &&
      !verify_mac_subnet_unique($dbh, $newfields, $upd) && 
      $$newfields{'machine.mode'} ne 'secondary') {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EEXISTS}, ['mac_address']);
  }
  
  ## assign a hostname if they didn't request one
  if ($noHostname) {
    my ($h, $d) = CMU::Netdb::splitHostname($$newfields{'machine.host_name'});
    $$newfields{'machine.host_name'} = getRandomHostname($dbh, $d);
    if ($$newfields{'machine.host_name'} eq '') {
      $dbh->do("UNLOCK TABLES");
      return ($errcodes{ESYSTEM}, ['host_name']);
    }
  }
  
  ## verify uniqueness of hostname
  unless(check_host_unique($dbh, $dbuser, $newfields, $upd)) {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EEXISTS}, ['host_name']);
  }
  
  ## find an IP for this machine and set it
  if ($$newfields{'machine.ip_address'} eq '') {
    warn  __FILE__, ':', __LINE__, ' :>'.
      ">>>> finding available IP\n" if ($debug >= 2);
    my $newip = find_available_ip($dbh, $newfields);
    if (!ref $newip) {
      $dbh->do("UNLOCK TABLES");
      return ($newip, ['ip_address']);
    }
    $$newfields{'machine.ip_address'} = $$newip[0];
    $$fields{ip_address} = $$newfields{'machine.ip_address'};
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Got IP: $$newfields{'machine.ip_address'}\n" if ($debug >= 2);
  }
  
  # figure out the ip_address_zone
  if ($$newfields{'machine.ip_address'} eq '') {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EINVALID}, ['ip_address']);
  }
  warn  __FILE__, ':', __LINE__, ' :>'.
    "ipaddr: ".$$newfields{'machine.ip_address'}." is " . CMU::Netdb::long2dot($$newfields{'machine.ip_address'}) . "\n" if ($debug >= 2);
  @ipc = split(/\./, CMU::Netdb::long2dot($$newfields{'machine.ip_address'}));
  @hzones = keys %{CMU::Netdb::list_zone_ref($dbh, $dbuser, 
					     " dns_zone.name = '$ipc[2].$ipc[1].$ipc[0].in-addr.arpa' ", 'GET')};
  if ($#hzones != 0) {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EDOMAIN}, ['ip_address']);
  }
  $$newfields{'machine.ip_address_zone'} = $hzones[0];
  
  $warns{IP} = CMU::Netdb::long2dot($$newfields{'machine.ip_address'});
  
  # okay, we're ready to go.
  if ($upd) {
    delete $$newfields{'machine.id'};
    delete $$newfields{'machine.version'};
    
    $res = CMU::Netdb::primitives::modify($dbh, $dbuser, 'machine', 
					  $upd, $version, $newfields);
    $warns{insertID} = $upd;
  }else{
    $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'machine', $newfields);
    $warns{insertID} = $CMU::Netdb::primitives::db_insertid;

    if($noHostname){

        ## Saving Old host Name
        my $oldHostname =  $$newfields{'machine.host_name'};

        ##Assigning Unique Name
        $$newfields{'machine.host_name'} = getUniqueHostname($dbh, $$newfields{'machine.host_name'});

        changeHostname($dbh, 'netreg', $oldHostname, $$newfields{'machine.host_name'});

    }

  }
  $dbh->do("UNLOCK TABLES");
  $warns{host_name} = $$newfields{'machine.host_name'};
  return ($res, {'new' => $newfields}) if ($res < 1);
  return ($res, \%warns);
}

# add machines with mode == dynamic
# see add_machine
sub add_mod_machine_dynamic {
  my ($dbh, $dbuser, $ul, $fields, $upd, $prev, $version) = @_;
  my ($key, $newfields, $domain, $ip, @ipc, $hzones, @hzones, %warns, $host);
  
  my %ofields = %$prev if (ref $prev);

  # first, if the user is not high level, we're gonna clean up the input a bit
  # and make sure they aren't trying to pull any fast ones
  if ($ul < 5) {
    if (!$upd) {
      map { $$fields{$_} = ''; }
      ('comment_lvl5');
    }else{
      map { $$fields{$_} = $ofields{$_} } 
      ('comment_lvl5');
    }
  }
  unless ($ul >= 9) {
    # reset restricted fields
    if (!$upd) {
      map { $$fields{$_} = '' if (defined $$fields{$_}) }
      ('comment_lvl9', 'flags', 'account', 'host_name_ttl', 'ip_address_ttl');
    }else{
      map { $$fields{$_} = $ofields{$_} } 
      ('comment_lvl9', 'flags', 'account', 'host_name_ttl', 'ip_address_ttl');
    }
  }
  
  $$fields{'ip_address_zone'} = '*EXPR: NULL';
  $$fields{'ip_address'} = '0.0.0.0';
  
  # figure out the host_name_zone
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Host Name: $$fields{'host_name'}\n" if ($debug >= 2);
  return ($errcodes{EINVALID}, ['host_name']) if ($$fields{'host_name'} eq '');
  # Patch: Correctly identifying host_name and domain e.g. andrew.cmu.edu where
  # andrew is host_name and cmu.edu is domain, and not domain = andrew.cmu.edu
  ($host, $domain) = splitHostname($$fields{'host_name'});
  @hzones = keys %{CMU::Netdb::list_zone_ref($dbh, $dbuser,
					     "dns_zone.name = '$domain' ", 'GET')};
  return ($errcodes{EDOMAIN}, ['host_name']) if ($#hzones != 0);
  $$fields{'host_name_zone'} = $hzones[0];

  ## Verify that the domain is allowed on the subnet
  if ($upd == 0 || $ofields{host_name} ne $$fields{host_name}) {
    my $subnet = $$fields{'ip_address_subnet'};
    my $sul = CMU::Netdb::get_add_level($dbh, $dbuser, 'subnet', $subnet);
    my $ldsr = CMU::Netdb::get_domains_for_subnet
      ($dbh, $dbuser, 
       "subnet_domain.domain = '$domain' and ".
       "subnet_domain.subnet = '$subnet'");
    return ($ldsr, ['host_name']) if (!ref $ldsr);
    my $ldsc = $#$ldsr;
    return ($errcodes{EBADIP}, ['host_name']) if ($sul < 9 && $ldsc < 0);
  }
  

  my ($subnet, $virtual, $subnet_changed, $mode_changed, $was_virtual);

  $subnet = $$fields{'ip_address_subnet'};
  $virtual = $$fields{'mac_address'} eq '' ? 1 : 0 ;
  $subnet_changed = ($upd && ($$fields{'ip_address_subnet'} ne $ofields{'ip_address_subnet'})) ? 1 : 0;
  $mode_changed = ($upd && ($$fields{'mode'} ne $ofields{'mode'})) ? 1 : 0;
  $was_virtual = ($upd && ($ofields{'mac_address'} ne '')) ? 1 : 0 ;

  my ($res, $reason) = check_registration_quota($dbh, $dbuser, $subnet, 'dynamic', $virtual,
						$upd, $subnet_changed, $mode_changed, $was_virtual);

  if ($res <= 0) {
    return ($res, $reason);
  }

  
  my $noHostname = 0;
  # ugly hack - if there is no hostname, we'll assign one, but we tack on
  # a default hostname to get through the CMU::Netdb::validity checking
  if ($host eq '') {
    $noHostname = 1;
    $$fields{'host_name'} = "HOSTNAME-UNASSIGNED.$domain";
  }
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Dynamics allowed\n" if ($debug >= 2);
  ## bidirectional verification of the fields that the user is trying to add
  
  ## WARNING: ip_address_zone should be OKAY'd even if it isn't a number
  ## since it won't be set until we actually know the IP address
  foreach $key (@machine_fields) {
    my $nk = $key;		# required because $key is a reference into machine_fields
    $nk =~ s/^machine\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep ($_ eq "machine.$key", @machine_fields)) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find machine.$key!\n".Dumper($fields, \@machine_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    next if (($key eq 'host_name' && $$fields{$key} eq '') || 
	     ($key eq 'host_name_zone' && $$fields{'host_name'} eq '') || 
	     $key eq 'ip_address_zone');
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("machine.$key", $$fields{$key}, $dbuser, $ul, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "machine.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"machine.$key"} = $$fields{$key};
  }
  delete($$newfields{'machine.created'}) if ($upd);
  if ($$fields{'host_name'} eq '') {
    foreach(qw/host_name host_name_zone/) {
      $$newfields{"machine.$_"} = $$fields{$_};
    }
  }
  $$newfields{'machine.ip_address_zone'} = $$fields{'ip_address_zone'};
  
  $dbh->do("LOCK TABLES machine WRITE, machine AS M1 READ, machine as M2 READ,
subnet AS S1 READ, subnet AS S2 READ, users as U READ, groups as G READ,
protections as P read, dns_zone READ, memberships as M READ, subnet READ, 
dns_resource as DR READ, _sys_changelog WRITE , _sys_changerec_row WRITE, 
_sys_changerec_col WRITE, credentials AS C READ");
  
  # verify a bunch of properties about the MAC address
  if ($$newfields{'machine.mac_address'} eq '000000000000') {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EINVALID}, ['mac_address']);
  }
  if (!$virtual) {
    my $lmqr = "machine.ip_address_subnet = \"" . $$newfields{'machine.ip_address_subnet'}.
      "\" AND machine.mac_address = '".$$newfields{'machine.mac_address'}."'";
    $lmqr .= " AND machine.id != '$upd'" if ($upd > 0);
    my $mcref = CMU::Netdb::list_machines($dbh, 'netreg', $lmqr);
    if (!ref $mcref) {
      $dbh->do("UNLOCK TABLES");
      return ($mcref, ['mac_address']) 
    }
    my $mcc = $#$mcref;
    if ($mcc > 0) {
      $dbh->do("UNLOCK TABLES");
      return ($errcodes{EEXISTS}, ['mac_address']);
    }
  }
  
 
  if ($$newfields{'machine.mac_address'} ne '') {
    # Make sure this MAC isn't registered dynamically too many times
    my $r_mac_list = list_machines($dbh, 'netreg', "machine.mac_address = '$$newfields{'machine.mac_address'}' AND machine.mode = 'dynamic'");
    shift @$r_mac_list;
    my $MAX_DYN_MAC;
    ($res, $MAX_DYN_MAC) = CMU::Netdb::config::get_multi_conf_var('netdb', 'MAX_DYN_MAC');

    $MAX_DYN_MAC= 5 if ($res != 1);

    if (@$r_mac_list > $MAX_DYN_MAC) {
      $dbh->do("UNLOCK TABLES");
      return ($errcodes{EMAXMAC}, ['mac_address']);
    }
  }


  ## assign a hostname if they didn't request one
  if ($noHostname) {
    my ($h, $d) = CMU::Netdb::splitHostname($$newfields{'machine.host_name'});
    $$newfields{'machine.host_name'} = getRandomHostname($dbh, $d);
    if ($$newfields{'machine.host_name'} eq '') {
      $dbh->do("UNLOCK TABLES");
      return ($errcodes{ESYSTEM}, ['host_name']);
    }
  }
  
  ## verify uniqueness of hostname
  unless(($$fields{'host_name'} eq '') || (check_host_unique($dbh, $dbuser, $newfields, $upd))) {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EEXISTS}, ['host_name']);
  }
  
  # okay, we're ready to go.
  if ($upd) {
    delete $$newfields{'machine.id'};
    delete $$newfields{'machine.version'};
    $res = CMU::Netdb::primitives::modify($dbh, $dbuser, 'machine', 
					  $upd, $version, $newfields);
    $warns{insertID} = $upd;

  }else{
    $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'machine', $newfields);
    $warns{insertID} = $CMU::Netdb::primitives::db_insertid;

    ## If there was no hostname give, this will replace the tempory hostname
    ## generated at creation with a unique hostname

    if($noHostname){

        ## Saving Old host Name
        my $oldHostname =  $$newfields{'machine.host_name'};

        ##Assigning Unique Name
        $$newfields{'machine.host_name'} = getUniqueHostname($dbh, $$newfields{'machine.host_name'});

        changeHostname($dbh, 'netreg', $oldHostname, $$newfields{'machine.host_name'});

    }

  }
  $dbh->do("UNLOCK TABLES");
  
  $warns{host_name} = $$newfields{'machine.host_name'};
  return ($res, {'new' => $newfields}) if ($res < 1);
  return ($res, \%warns);
}

sub add_mod_machine_pool {
  my ($dbh, $dbuser, $ul, $fields, $upd, $prev, $version) = @_;
  my ($key, $newfields, $domain, $ip, @ipc, $hzones, @hzones, %warns, $host, $hzk);
  my $sul = CMU::Netdb::get_add_level($dbh,$dbuser,'subnet',$$fields{'ip_address_subnet'});
  
  my %ofields = %$prev if (ref $prev);
  
  # first, if the user is not high level, we're gonna clean up the input a bit
  # and make sure they aren't trying to pull any fast ones
  if ($ul < 5) {
    if (!$upd) {
      map { $$fields{$_} = ''; }
      ('comment_lvl5');
    }else{
      map { $$fields{$_} = $ofields{$_} } 
      ('comment_lvl5');
    }
  }
  unless ($ul >= 9) {
    # reset restricted fields
    if (!$upd) {
      map { $$fields{$_} = ''; }
      ('comment_lvl9', 'flags', 'account', 'host_name_ttl', 'ip_address_ttl');
      $$fields{'ip_address'} = ''
        unless ($sul >= 5);
    }else{
      map { $$fields{$_} = $ofields{$_} } 
      ('comment_lvl9', 'flags', 'account', 'host_name_ttl', 'ip_address_ttl');
      $$fields{ip_address} = CMU::Netdb::long2dot($ofields{ip_address})
        if ($$fields{ip_address} ne '' && $sul < 5);
    }
  }
  
  if ($$fields{ip_address} eq '' && $$fields{mode} ne 'reserved') {
    warn "exit 1" if ($debug);
    return ($errcodes{EBLANK}, ['ip_address']);
  }
  
  # verify that the user can add machines to this subnet
  {
    my $dselect = CMU::Netdb::get_subnets_ref($dbh, $dbuser, "subnet.id = '$$fields{'ip_address_subnet'}'", 'subnet.name');
    warn "exit 2" if ($debug);
    return ($errcodes{ESUBNET}, ['ip_address_subnet']) if (!ref $dselect || !defined $$dselect{$$fields{'ip_address_subnet'}});

    my $virtual = ($$fields{'mac_address'} eq '') ? 1 : 0;
    my $subnet_changed = ($ofields{'ip_address_subnet'} ne $$fields{'ip_address_subnet'}) ? 1 : 0;
    my $mode_changed = ($ofields{'mode'} ne $$fields{'mode'}) ? 1 : 0;
    my $was_virtual = ($ofields{'mac_address'} eq '') ? 1 : 0;
    my ($res, $reason) = check_registration_quota($dbh, $dbuser, 
						  $$fields{'ip_address_subnet'},
						  $$fields{'mode'},
						  $virtual, $upd,
						  $subnet_changed, $mode_changed,
						  $was_virtual);
    return ($res, $reason) if ($res <= 0);
  }
  
  # not broadcast
  if ($$fields{ip_address} ne '') {
    $ip = CMU::Netdb::dot2long($$fields{'ip_address'});
    $hzones = CMU::Netdb::list_subnets_ref($dbh, $dbuser, 
					   " (base_address | ".
					   "(~network_mask&$IPSuperMask)) ".
					   "='$ip' ", 'subnet.name');
    warn "exit 3" if ($debug);
    return ($hzones, ['ip_address']) if (!ref $hzones);
    $hzk = keys %$hzones;
    if ($$fields{'mode'} eq 'broadcast') {
      warn "exit 4" if ($debug);
      return ($errcodes{EBROADCAST}, ['mode', 'ip_address']) if ($hzk < 1);
    }else{
      warn "exit 5" if ($debug);
      return ($errcodes{EBROADCAST}, ['mode', 'ip_address']) if ($hzk >= 1);
    }
    
    # and not base
    $hzones = CMU::Netdb::list_subnets_ref($dbh, $dbuser, " base_address='$ip' ", 'subnet.name');
    warn "exit 6" if ($debug);
    return ($hzones, ['ip_address']) if (!ref $hzones);
    $hzk = keys %$hzones;
    if ($$fields{'mode'} eq 'base') {
      warn "exit 7" if ($debug);
      return ($errcodes{EBROADCAST}, ['mode', 'ip_address']) if ($hzk < 1);
    }else{
      warn "exit 8" if ($debug);
      return ($errcodes{EBROADCAST}, ['mode', 'ip_address']) if ($hzk >= 1);
    }
  }
  
  # figure out the host_name_zone
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Host Name: $$fields{'host_name'}\n" if ($debug >= 2);
  warn "exit 9" if ($debug);
  return ($errcodes{EINVALID}, ['host_name']) if ($$fields{'host_name'} eq '');
  # Patch: Correctly identifying host_name and domain e.g. andrew.cmu.edu where
  # andrew is host_name and cmu.edu is domain, and not domain = andrew.cmu.edu
  ($host, $domain) = splitHostname($$fields{'host_name'});
  @hzones = keys %{CMU::Netdb::list_zone_ref($dbh, $dbuser,
					     "dns_zone.name = '$domain' ", 'GET')};
  warn "exit 10" if ($debug);
  return ($errcodes{EDOMAIN}, ['host_name']) if ($#hzones != 0);
  $$fields{'host_name_zone'} = $hzones[0];
  
  ## Verify that the domain is allowed on the subnet
  if ($$fields{'ip_address_subnet'} ne '') {
    my $gdUser = $dbuser;
    $gdUser = 'netreg' if ($upd > 0 && ($ofields{host_name} eq $$fields{host_name}));
    my $ldsr = CMU::Netdb::get_domains_for_subnet($dbh, $gdUser, 
						  "subnet_domain.domain = '$domain' and subnet_domain.subnet = '$$fields{'ip_address_subnet'}'");
    warn "exit 11" if ($debug);
    return ($ldsr, ['host_name']) if (!ref $ldsr);
    my $ldsc = $#$ldsr;
    warn "exit 12" if ($debug);
    return ($errcodes{EBADIP}, ['host_name']) if ($ldsc < 0);
  }
  
  ## if they set the IP (L9) and also the ip_address_subnet, make sure 
  ## they match.  Also verify that this address is not already registered.
  unless ($$fields{mode} eq 'reserved' && $$fields{ip_address} eq '') {
    $ip = CMU::Netdb::dot2long($$fields{'ip_address'});
    $hzones = CMU::Netdb::list_subnets_ref($dbh, $dbuser, " (base_address = ('$ip' & network_mask)) ", 'subnet.name');
    warn "exit 13" if ($debug);
    return ($hzones, ['ip_address']) if (!ref $hzones);
    $hzk = keys %$hzones;
    my @hza = keys %$hzones;
    warn "exit 14" if ($debug);
    return ($errcodes{ESUBNET}, ['ip_address']) if ($hzk != 1);
    warn "exit 15" if ($debug);
    return ($errcodes{EBADIP}, ['ip_address']) if ($$fields{'ip_address_subnet'} != $hza[0]);
    my $hip;
    if ($upd) {
      $hip = CMU::Netdb::list_machines($dbh, 'netreg', "machine.ip_address=$ip AND machine.id != " . $ofields{'id'});
    } else {
      $hip = CMU::Netdb::list_machines($dbh, 'netreg', "machine.ip_address=$ip");
    }
    warn "exit 16" if ($debug);
    return ($hip, ['ip_address']) if (!ref ($hip));
    # count the rows in the array
    $hip=@$hip;
    # $hip=1 means list_machines returned no matches
    warn "exit 17" if ($debug);
    return ($errcodes{EEXISTS}, ['ip_address']) if ($hip != 1);
  }
  ## bidirectional verification of the fields that the user is trying to add
  
  ## WARNING: ip_address_zone should be OKAY'd even if it isn't a number
  ## since it won't be set until we actually know the IP address
  foreach $key (@machine_fields) {
    my $nk = $key;		# required because $key is a reference into machine_fields
    $nk =~ s/^machine\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^machine\.$key$/, @machine_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find machine.$key!\n".Dumper($fields, @machine_fields) if ($debug >= 2);
      warn "exit 18" if ($debug);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    if ($key eq 'mac_address') {
      if ($$fields{mode} ne 'reserved') {
	next;
      }
      if ($$fields{mac_address} eq '') {
	$$newfields{"machine.mac_address"} = '';
	next;
      }
    }
    next if ($key eq 'ip_address_subnet' && $$fields{ip_address} eq '' &&
	     $$fields{mode} eq 'reserved' &&
	     $$fields{ip_address_subnet} eq '');
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("machine.$key", $$fields{$key}, $dbuser, $ul, $dbh);
    warn "exit 19" if ($debug);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "machine.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"machine.$key"} = $$fields{$key};
  }
  delete($$newfields{'machine.created'}) if ($upd);
  
  $dbh->do("LOCK TABLES machine WRITE, machine AS M1 READ, machine as M2 READ,
subnet AS S1 READ, subnet AS S2 READ, users as U READ, groups as G READ,
protections as P read, dns_zone READ, memberships as M READ, subnet READ,
dns_resource as DR read, _sys_changelog WRITE , _sys_changerec_row WRITE, 
_sys_changerec_col WRITE, credentials AS C READ");
  
  $$newfields{'machine.mac_address'} = '' if ($$fields{mode} ne 'reserved');
  
  # verify MAC address uniqueness
  if ($$newfields{'machine.mac_address'} ne '') {
    my $lmqr = "machine.mac_address = '".$$newfields{'machine.mac_address'}."'";
    $lmqr .= " AND machine.id != '$upd'" if ($upd > 0);
    my $mcref = CMU::Netdb::list_machines($dbh, 'netreg', $lmqr);
    if (!ref $mcref) {
      $dbh->do("UNLOCK TABLES");
      warn "exit 20" if ($debug);
      return ($mcref, ['mac_address']) 
    }
    my $mcc = $#$mcref;
    if ($mcc > 0) {
      $dbh->do("UNLOCK TABLES");
      warn "exit 21" if ($debug);
      return ($errcodes{EEXISTS}, ['mac_address']);
    }
  }
  
  ## verify uniqueness of hostname
  {
    unless(check_host_unique($dbh, $dbuser, $newfields, $upd)) {
      $dbh->do("UNLOCK TABLES");
      warn "exit 22" if ($debug);
      return ($errcodes{EEXISTS}, ['host_name']);
    }
  }
  
  ## find an IP for this machine and set it
  if ($$newfields{'machine.ip_address'} eq '' && $$newfields{'machine.mode'} ne 'reserved') {
    my $newip = find_available_ip($dbh, $newfields);
    if (!ref $newip) {
      $dbh->do("UNLOCK TABLES");
      warn "exit 23" if ($debug);
      return ($newip, ['ip_address']);
    }
    $$newfields{'machine.ip_address'} = $$newip[0];
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Got IP: $$newfields{'machine.ip_address'}\n" if ($debug >= 2);
  }
  
  # figure out the ip_address_zone
  if ($$newfields{'machine.ip_address'} ne '') {
    @ipc = split(/\./, CMU::Netdb::long2dot($$newfields{'machine.ip_address'}));
    @hzones = keys %{CMU::Netdb::list_zone_ref($dbh, $dbuser, 
					       " dns_zone.name = '$ipc[2].$ipc[1].$ipc[0].in-addr.arpa' ",'GET')};
    if ($#hzones != 0) {
      $dbh->do("UNLOCK TABLES");
      warn "exit 24" if ($debug);
      return ($errcodes{EDOMAIN}, ['ip_address']);
    }
    $$newfields{'machine.ip_address_zone'} = $hzones[0];
    $warns{IP} = CMU::Netdb::long2dot($$newfields{'machine.ip_address'});
  }else{
    # No IP, set the ip_address_zone to null
    $$newfields{'machine.ip_address_zone'} = '*EXPR: NULL';
    $warns{IP} = '';
  }
  
  # okay, we're ready to go.
  my $res;
  if ($upd) {
    delete $$newfields{'machine.id'};
    delete $$newfields{'machine.version'};
    $res = CMU::Netdb::primitives::modify($dbh, $dbuser, 'machine', 
					  $upd, $version, $newfields);
#    warn "modified but res: $res";
    $warns{insertID} = $upd;
  }else{
    $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'machine', $newfields);
    $warns{insertID} = $CMU::Netdb::primitives::db_insertid;
  }
  $dbh->do("UNLOCK TABLES");
  
  $warns{host_name} = $$newfields{'machine.host_name'};
  warn "exit 25" if ($debug);
  return ($res, {'new' => $newfields}) if ($res < 1);
  return ($res, \%warns);
}

# Function: add_machine
# Arguments: 
#     An already connected database handle
#     The name of the user performing the query
#     The user's add level
#     A reference to a hash table of field->value pairs
#     A reference to an associative array of user => permissions
# Actions:  Adds the row to the table, if authorized
# It also inserts protections, and will back out the machine addition
# if none of the protections can be added.
# Return value:
#   returns an array (code, info).
#   if code < 1, that is the error code, and info will be a reference to
#   an array containing the fields that caused the error
#   if code == 1, info will be a reference to an associative array. if the
#   array is null, everything went okay. if certain fields are set, the
#   insert actually ABORTED because of problems inserting protections
#   FIXME: doc (describe those fields)
sub add_machine {
  my ($dbh, $dbuser, $ul, $fields, $perms) = @_;
  my ($dept);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid'])
    if (CMU::Netdb::getError($dbuser) != 1);

  return ($errcodes{EPERM}, []) if ($ul < 1);

  $dept = $$fields{'dept'};
  delete $$fields{'dept'};

  return ($errcodes{EBLANK}, ['dept']) if ((! defined $dept) || ($dept eq ''));
  return ($errcodes{EBLANK}, ['mode']) if ($$fields{'mode'} eq '');
  my $depts = CMU::Netdb::get_departments($dbh, $dbuser, " groups.name = '$dept'", 'ALL', '', 'groups.id');
  return ($errcodes{EPERM}, ['dept']) if (!ref $depts || !defined $$depts{$dept});
  
  my ($res, $ref);
  ($res, $ref) = add_mod_machine_static($dbh, $dbuser, $ul, $fields, 0, 0, 0)
    if ($$fields{'mode'} eq 'static');
  ($res, $ref) = add_mod_machine_secondary($dbh, $dbuser, $ul, $fields, 0, 0, 0)
    if ($$fields{'mode'} eq 'secondary');
  ($res, $ref) = add_mod_machine_dynamic($dbh, $dbuser, $ul, $fields, 0, 0, 0)
    if ($$fields{'mode'} eq 'dynamic');
  ($res, $ref) = add_mod_machine_pool($dbh, $dbuser, $ul, $fields, 0, 0, 0)
    if ($$fields{'mode'} eq 'broadcast' || $$fields{'mode'} eq 'base');
  ($res, $ref) = add_mod_machine_pool($dbh, $dbuser, $ul, $fields, 0, 0, 0)
    if ($$fields{'mode'} eq 'pool');
  ($res, $ref) = add_mod_machine_pool($dbh, $dbuser, $ul, $fields, 0, 0, 0)
    if ($$fields{'mode'} eq 'reserved');
  
  return ($res, $ref) if ($res < 1);
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    "last insert ID: $$ref{insertID}\n" if ($debug >= 2);
  
  # some problems have come up where the insertid was being set to 0. this is
  # bad, as it results in table-level grants being given to randoms.
  if (!defined $$ref{insertID} || $$ref{insertID} == 0) {
    my $mailstring = "User ".$dbuser."'s had an insertid of 0!\n\nDump of fields follows:\n";
    foreach my $key (keys %{$fields}) {
      $mailstring .= "$key = $fields->{$key}\n";
    }
    &CMU::Netdb::netdb_mail('CMU::Netdb::machines_subnets:add_machine', $mailstring);
    return (0, ['insert_id']);
  }
  
  # done. now add the initial permissions
  # FIXME: if we have transactions, this should be included and a rollback
  # performed if the machine isn't associated with one user
  my $success = 0;
  my $addret;
  # set the dept
  ($addret) = CMU::Netdb::add_group_to_protections($dbh, $dbuser, $dept, 'machine',
						   $$ref{insertID}, 'READ,WRITE', 
						   5, 'RUBIKS_CUBE'); # FIXME level 5 shouldn't be hardcoded, use template.
  $$ref{$dept} = $errmeanings{$addret} if ($addret < 1);
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    $errmeanings{$addret} if (($addret < 1) && ($debug >= 2));
  if ($addret >= 1) {
#    $CMU::Netdb::auth::debug = 2;
    
    # allow no user to be added if calling user is a member of the dept group
    # or netreg:admins
    my $dadmin = CMU::Netdb::list_members_of_group($dbh, 'netreg', $dept, 
						   "credentials.authid = '$dbuser'");
    $success = 1 if ((ref $dadmin && defined $dadmin->[1]) 
		    || CMU::Netdb::get_user_netreg_admin($dbh, $dbuser));
    foreach my $k (keys %{$perms}) {
      if ($k =~ /\:/) {
	# group
	warn  __FILE__, ':', __LINE__, ' :>'.
	  "Adding group $k : $perms->{$k}->[0] / $perms->{$k}->[1] " if ($debug >=2);
	($addret) = CMU::Netdb::add_group_to_protections($dbh, $dbuser, $k, 'machine', 
							 $$ref{insertID}, $perms->{$k}->[0],
							 $perms->{$k}->[1], 'RUBIKS_CUBE');
	
	$success++ if ($addret >= 1);
	$$ref{$k} = $errmeanings{$addret} if ($addret < 1);
	warn  __FILE__, ':', __LINE__, ' :>'.
	  $errmeanings{$addret} if (($addret < 1) && ($debug >= 2));
      }else{
	# user
	warn  __FILE__, ':', __LINE__, ' :>'.
	  "Adding user $k : $perms->{$k}->[0] / $perms->{$k}->[1]" if ($debug >= 2);
	($addret) = CMU::Netdb::add_user_to_protections($dbh, $dbuser, $k, 'machine', 
							$$ref{insertID}, $perms->{$k}->[0],
							$perms->{$k}->[1], 'RUBIKS_CUBE');
	$success++ if ($addret >= 1);
	$$ref{$k} = $errmeanings{$addret} if ($addret < 1);
	warn  __FILE__, ':', __LINE__, ' :>'.
	  $errmeanings{$addret} if (($addret < 1) && ($debug >= 2));
      }
    }
  }
  # in this case, we need to rollback the machine and tell the user
  if ($success < 1) {
    # find the version field. grr. this sucks.
    my $version = get_machine_version($dbh, 'netreg', 
				      " machine.id = '$$ref{insertID}' ");
    # since we're running this as netreg, start the changelog as the real user first.
    CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
    my $dm = CMU::Netdb::delete_machine($dbh, 'netreg', $$ref{insertID}, $version);
    if ($dm == 1) {
      $$ref{'delete_machine'} = "Machine removed.";
    }else{
      $$ref{'delete_machine'} = "Error deleting machine: ".$errmeanings{$dm}; # FIXME send mail?
    }
    return (0, ['protections']);
  }
  return (1, $ref);
}

# Function: add_subnet
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_subnet {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields, $query, $sth, @row);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  ## bidirectional verification of the fields that the user is trying to add
  
  ## verify the subnet is unique
  
  foreach $key (@subnet_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_fields
    $nk =~ s/^subnet\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet\.$key$/, @subnet_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet.$key!\n".Dumper($fields, \@subnet_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet.$key"} = $$fields{$key};
  }
  
  my ($nb, $nn) = ($$newfields{'subnet.base_address'}, $$newfields{'subnet.network_mask'});
  $query = "
SELECT COUNT(subnet.id)
FROM subnet
WHERE ('$nb' BETWEEN base_address AND (base_address | (~network_mask & 
$IPSuperMask)))
   OR (('$nb' | (~'$nn' & $IPSuperMask)) BETWEEN base_address AND 
  (base_address | (~network_mask & $IPSuperMask))) ";

#This is checking to see if a subnet already occupies that range

  $sth = $dbh->prepare($query);
  warn  __FILE__, ':', __LINE__, ' :>'.
    "add_subnet query: $query\n" if ($debug >= 2);
  $sth->execute;
  @row = $sth->fetchrow_array();
  return ($errcodes{EEXISTS}, ['subnet.base_address', 'subnet.network_mask'])
    if (@row && defined $row[0] && $row[0] > 0);
  
  # Silently make the base address the true base address of this subnet
  # given the network mask. Things silently break in annoying ways if 
  # the base address is not truly the base
  my $TrueBase = $nb & $nn;
  if ($TrueBase != $nb) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      " [Advisory] Calculated subnet base (".
	CMU::Netdb::long2dot($TrueBase).") did not equal ".
	  "specified base (".
	    CMU::Netdb::long2dot($nb)."/".
	      CMU::Netdb::long2dot($nn).").\n";
    $$newfields{'subnet.base_address'} = $TrueBase;
  }
  
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'subnet', $newfields);    if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);

  ## Addition was successful. Go ahead and add default permissions.
  ## Failure here is not fatal; permissions just need to be dealt with 
  ## manually.
  ## FIXME transactions possibly useful here.
  if ($warns{insertID} == 0) {
    # This probably indicates a bug in DBI, because an insertid of 0
    # is completely bogus, but possible if the version of DBD::mysql
    # and the mysql libraries are out of sync between client and server
    warn __FILE__, ':', __LINE__, ' :>'.
      "MySQL insertID returned is 0; probably a client/server incompatibility".
	" between DBD::mysql and mysql libraries.\n";
  }else{
    my ($ARes, $AErrf) = CMU::Netdb::apply_prot_profile
      ($dbh, $dbuser, 'admin_default_add', 'subnet', $warns{insertID}, '', {});
    
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "subnet/$warns{insertID}: ".join(',', @$AErrf)."\n";
    }

    my @modes_to_add = ( ['static','required'],
			 ['reserved','required'],
			 ['reserved','none'],
			 ['broadcast','none'],
			 ['base','none'] );
    if ($$newfields{'subnet.default_mode'} eq 'dynamic' 
	|| $$newfields{'subnet.dynamic'} ne 'disallow') {
      push @modes_to_add, ['pool', 'none'];
      push @modes_to_add, ['dynamic', 'required'];
    }


    foreach my $mode (@modes_to_add) {
      ($ARes, $AErrf) = CMU::Netdb::add_subnet_registration_mode($dbh, $dbuser,
							       {'subnet' => $warns{insertID},
								'mode' => $mode->[0],
								'quota' => undef,
								'mac_address' => $mode->[1]});
      if ($ARes < 0) {
	warn __FILE__, ':', __LINE__, ' :>'.
	"failure adding mode entries for ".
	  "subnet/$warns{insertID}: ".join(',', @$AErrf)."\n";
      } 
    }
  }
  
  
  return ($res, \%warns);
}

# Function: add_network
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_network {
  my ($dbh, $dbuser, $fields) = @_;
    my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@network_fields) {
    my $nk = $key;		# required because $key is a reference into network_fields
    $nk =~ s/^network\.//;
    $$fields{$nk} = '' 
	if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of network.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^network\.$key$/, @network_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find network.$key!\n".Dumper($fields, @network_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("network.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "network.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"network.$key"} = $$fields{$key};
  }		  
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'network', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
  
}

# Function: add_subnet_share
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_subnet_share {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@subnet_share_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_share_fields
    $nk =~ s/^subnet_share\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet_share\.$key$/, @subnet_share_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet_share.$key!\n".Dumper($fields, @subnet_share_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet_share.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet_share.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet_share.$key"} = $$fields{$key};
  }
  
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'subnet_share', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return($res, \%warns);
}


# Function: add_subnet_presence
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_subnet_presence {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@vlan_subnet_presence_fields) {
    my $nk = $key;		# required because $key is a reference into vlan_subnet_presence
    $nk =~ s/^vlan_subnet_presence\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^vlan_subnet_presence\.$key$/, @vlan_subnet_presence_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find vlan_subnet_presence.$key!\n".join(',', @vlan_subnet_presence_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("vlan_subnet_presence.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "vlan_subnet_presence.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"vlan_subnet_presence.$key"} = $$fields{$key};
  }	  
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'vlan_subnet_presence', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
  
}

# Function: add_subnet_domain
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_subnet_domain {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@subnet_domain_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_domain_fields
    $nk =~ s/^subnet_domain\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet_domain\.$key$/, @subnet_domain_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet_domain.$key!\n".Dumper($fields, @subnet_domain_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet_domain.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet_domain.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet_domain.$key"} = $$fields{$key};
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'subnet_domain', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
}

# Function: add_subnet_registration_modes
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
#     An optional reference to an array of names of 
#       protection profiles to apply to the new entry
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_subnet_registration_mode {
  my ($dbh, $dbuser, $fields, $profiles) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@subnet_registration_modes_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_registration_modes_fields
    $nk =~ s/^subnet_registration_modes\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet_registration_modes\.$key$/, @subnet_registration_modes_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet_registration_modes.$key!\n".Dumper($fields, @subnet_registration_modes_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet_registration_modes.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet_registration_modes.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet_registration_modes.$key"} = $$fields{$key};
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'subnet_registration_modes', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  $profiles = [] if (!ref $profiles);
  push @$profiles, 'admin_default_add' if (!grep(/^admin_default_add$/, @$profiles));
  foreach my $prot_profile (@$profiles) {
    my ($ARes, $AErrf) = CMU::Netdb::apply_prot_profile
      ($dbh, $dbuser, $prot_profile, 'subnet_registration_modes', $warns{insertID}, '', {});

    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "subnet_registration_modes/$warns{insertID}: ".join(',', @$AErrf)."\n";
    }
  }

  return ($res, \%warns);
}

# Function: expire_machine
# Arguments 6:
#     An already connected database handle
#     The name of the user performing the query
#     The 'id' of the row to change
#     The 'version' of the row to change
#     The expiration date (2001-10-30)
# Actions: Updates the specified row, if authorized
# Return value:
#    1 if successful
#    An error code otherwise
sub expire_machine {
  my ($dbh, $dbuser, $id, $version, $expires) = @_;
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (getError($dbuser), ['dbuser']) if (getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('machine.id', $id, $dbuser, 0, $dbh);
  return (getError($id), ['id']) if (getError($id) != 1);
  
  $version = CMU::Netdb::valid('machine.version', $version, $dbuser, 0, $dbh);
  return (getError($version), ['version']) if (getError($version) != 1);
  
  my $ul = get_write_level($dbh, $dbuser, 'machine', $id);
  return ($errcodes{EPERM}, ['perm']) if ($ul < 9);
  
  
  my %newfields;
  $newfields{'machine.expires'} = CMU::Netdb::valid('machine.expires', $expires, $dbuser, 0, $dbh);
  
  return (getError($newfields{'machine.expires'}), ['expires']) 
    if (getError($newfields{'machine.expires'}) != 1);
  
  my $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'machine', $id, $version, \%newfields);
  return ($errcodes{"ERROR"}, ['unknown']) if ($result != 1);
  
  return ($result, []);
}

# Function: ab_del_mac
# Arguments: 2:
# 	subnet id, either ab/wireless or ab/netbar
#	mac-address to be deleted
# Action: Delete specified mac-address from appropriate ab server
# Return value:
#	1 if successful
#	An error code is returned if a problem occurs
sub ab_del_mac {
  my ($lsubnet_id, $lmac_address) = @_;

  my ($res, $ABCF, $ABDC);

  ($res, $ABCF) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'AUTHBRIDGE_CONFIG_FILE');
  return -1 if ($res < 1);

  ($res, $ABDC) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'AUTHBRIDGE_DEL_COMMAND');

  my $AB = new CMU::AuthBridge;
  my $config = $AB->load_ab_server($lsubnet_id, $ABCF);
  return -1 if ($config == -1);

  $AB->{ABRegRes} = $AB->authbridge_register
    ('netreg', $lmac_address, 0, $ABDC);

  return $AB->{ABRegRes};
}


# Function: modify_machine
# Arguments: 6:
#     An already connected database handle
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     Userlevel
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_machine {
  my ($dbh, $dbuser, $id, $version, $ul, $fields) = @_;
  my (%ofields, @mach_field_short, $orig, $query, $dept, $hnChange);

  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('machine.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('machine.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  return ($errcodes{EPERM}, ['perm']) if ($ul < 1);
  
  $dept = $$fields{'dept'};
  delete $$fields{'dept'};
  my $depts;
  if ((defined $dept) &&  ($dept ne '')) {
    $depts = CMU::Netdb::get_departments($dbh, $dbuser, " groups.name = '$dept'", 'ALL', '', 'groups.id', 'GET');
    return ($errcodes{EPERM}, ['dept']) if (!ref $depts || !defined $$depts{$dept});
  }
  
  $hnChange = 0;		# hostname change
  
  $orig = CMU::Netdb::list_machines($dbh, "netreg", "machine.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@machine_fields) {
    my $nk = $_;
    $nk =~ s/^machine\.//;
    push(@mach_field_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ { $$orig[1]}[$i++] } @mach_field_short;
  }
  
  my ($oldZoneFw, $oldZoneRv) = ($ofields{host_name_zone}, $ofields{ip_address_zone});
  $$fields{ip_address} = CMU::Netdb::long2dot($ofields{ip_address}) if (!defined $$fields{ip_address});
  map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } 
  @mach_field_short;

  if ($version != $ofields{'version'}) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_machine: id/version were stale\n" if ($debug);
    return ($errcodes{ESTALE}, ['stale']);
  }

  ## reject abuse/suspended updates
  return ($errcodes{EPERM}, ['flags'])
    if ($ul < 9 && $ofields{'flags'} =~ /(abuse|suspend)/);

  ## authbridge abuse/suspend
  my ($ABSres, $ABS) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'AUTHBRIDGE_SUSPEND');

  if ($ABSres == 1 && $ABS == 1 && $$fields{'flags'} =~ /suspend/) {
    my $ab_ret = ab_del_mac($ofields{'ip_address_subnet'}, $ofields{'mac_address'});
  }

  $hnChange = 1 if ($$fields{'host_name'} ne $ofields{host_name});
  warn  __FILE__, ':', __LINE__, ' :>'.
    ">>> '$$fields{'host_name'}' '$ofields{host_name}'\n" if ($debug >= 2);
  my ($res, $ref) = ($errcodes{ERROR}, []);
  ($res, $ref) = add_mod_machine_static($dbh, $dbuser, $ul, $fields, $id, \%ofields, $version)
    if ($$fields{'mode'} eq 'static');
  ($res, $ref) = add_mod_machine_secondary($dbh, $dbuser, $ul, $fields, $id, \%ofields, $version)
    if ($$fields{'mode'} eq 'secondary');	
  ($res, $ref) = add_mod_machine_dynamic($dbh, $dbuser, $ul, $fields, $id, \%ofields, $version)
    if ($$fields{'mode'} eq 'dynamic');
  ($res, $ref) = add_mod_machine_pool($dbh, $dbuser, $ul, $fields, $id, \%ofields, $version)
    if ($$fields{'mode'} eq 'broadcast' || $$fields{'mode'} eq 'base');
  ($res, $ref) = add_mod_machine_pool($dbh, $dbuser, $ul, $fields, $id, \%ofields, $version)
    if ($$fields{'mode'} eq 'pool');
  ($res, $ref) = add_mod_machine_pool($dbh, $dbuser, $ul, $fields, $id, \%ofields, $version)
    if ($$fields{'mode'} eq 'reserved');

  if ($res < 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_machine:: ".
	"After type-specific (".$$fields{'mode'}.
	  ") add_mod_machine, returning $res";

    return ($res, $ref);
  }

  # update resources - dhcp resources don't need to be updated since 
  # they reference the table ID directly
  if ($hnChange && $$fields{'mode'} ne 'dynamic') {
    # FIXME not logging for now, since its just matching the hostname change thats
    # logged elsewhere -vitroth
    my $sth = $dbh->prepare("UPDATE dns_resource SET name = '$$ref{host_name}' WHERE owner_type = 'machine' AND owner_tid = '$id' AND type != 'CNAME' AND type != 'ANAME'");
    return ($errcodes{EMACHCASCADE}, ['dns_resources']) if (!$sth->execute());
    $sth->finish();
    $sth = $dbh->prepare("UPDATE dns_resource SET rname = '$$ref{host_name}' WHERE owner_type = 'machine' AND owner_tid = '$id' AND (type = 'CNAME' OR type = 'ANAME')");
    return ($errcodes{EMACHCASCADE}, ['dns_resources']) if (!$sth->execute());
    $sth->finish();
  }
  
  # update department
  if ((defined $dept) && ($dept ne '')) {
    $dbh->do("LOCK TABLES protections WRITE, machine READ, groups READ, 
_sys_changelog WRITE , _sys_changerec_row WRITE, _sys_changerec_col WRITE, 
credentials AS C READ");
    $query = "
SELECT protections.id
  FROM protections, machine, groups
 WHERE protections.tid = machine.id
   AND protections.tname = 'machine'
   AND machine.id = '$id'
   AND groups.id = -1*protections.identity
   AND groups.name like 'dept:%'
";
      
    my $sth = $dbh->prepare($query);
    my $result = $sth->execute();
    if (!$result) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::modify_machine:: Unknown error\n$DBI::errstr\n" if ($debug);
      $$ref{dept} = 'DBI failure';
      $dbh->do("UNLOCK TABLES");
      return ($res, $ref);
    }    
    my @row = $sth->fetchrow_array();
    my $nres;
    if (!@row || $row[0] eq '') {
      ($nres) = CMU::Netdb::add_group_to_protections($dbh, $dbuser, $dept, 'machine',
						     $id, 'READ,WRITE', 5, 'RUBIKS_CUBE'); #FIXME
    }else{
      # since we're about to update a db row directly, we have to do logging here
      # first create the changelog entry
      my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
      if ($log) {
	# Now create the changelog row record
	my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $row[0], 'UPDATE');
	if ($rowrec) {
	  # Now create the column entry (only changing one column)
	  # FIXME need to do extra query to be able to use changelog_col
	  CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 'identity', -1*$$depts{$dept}, ['identity', 'protections', "id = '$row[0]'"]);
	}
      }
      $nres = $dbh->do("UPDATE protections SET identity = -1*$$depts{$dept} WHERE id = '$row[0]'");
    }
    $$ref{dept} = 'DBI Failure' if ($nres != 1);
    $dbh->do("UNLOCK TABLES");
  }
  warn  __FILE__, ':', __LINE__, ' :>'.
    "zone updates: $oldZoneFw; $oldZoneRv\n" if ($debug >= 2);
  CMU::Netdb::force_zone_update($dbh, $oldZoneFw);
  CMU::Netdb::force_zone_update($dbh, $oldZoneRv);
  
 my $resources = CMU::Netdb::list_dns_resources($dbh,"netreg","dns_resource.owner_type = 'machine' AND dns_resource.owner_tid = $id");

  if ($#$resources) {
    my $resmap = CMU::Netdb::makemap($resources->[0]);
    shift @$resources;
    foreach my $r (@$resources) {
      warn  __FILE__, ':', __LINE__, ' :>'.
        "zone update for dns_resource : $r->[$resmap->{'dns_resource.name_zone'}]" if ($debug >= 2);;
      CMU::Netdb::force_zone_update($dbh, $r->[$resmap->{'dns_resource.name_zone'}]);
    }
  }

  return ($res, $ref);
}


# Function: modify_subnet
# Arguments: 5:
#     An already connected database handle
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code and the field it refers to is returned if a problem 
#     occurs (see CMU::Netdb::errors.pm)
#     
sub modify_subnet {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields, %ofields, $orig, @subnet_field_short);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  return ($errcodes{"EINVALID"}, ['id', 'subnet_default']) if ($id eq '0');
  
  $version = CMU::Netdb::valid('subnet.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = CMU::Netdb::list_subnets($dbh, "netreg", "subnet.id='$id'");
  return ($orig, ['id']) if (!ref $orig);

  foreach (@subnet_fields) {
    my $nk = $_; #copy the field before stripping the table name
    $nk =~ s/^subnet\.//;
    push(@subnet_field_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ { $$orig[1]}[$i++] } @subnet_field_short;
  }

  map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } @subnet_field_short;

  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@subnet_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_fields
    $nk =~ s/^subnet\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet\.$key$/, @subnet_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet.$key!\n".Dumper($fields, @subnet_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet.$key"} = $$fields{$key};
  }
  
  my ($nb, $nn) = ($$newfields{'subnet.base_address'}, 
		   $$newfields{'subnet.network_mask'});
  
  # Silently make the base address the true base address of this subnet
  # given the network mask. Things silently break in annoying ways if 
  # the base address is not truly the base
  my $TrueBase = $nb & $nn;
  if ($TrueBase != $nb) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      " [Advisory] Calculated subnet base (".
	CMU::Netdb::long2dot($TrueBase).") did not equal ".
	  "specified base (".
	    CMU::Netdb::long2dot($nb)."/".
	      CMU::Netdb::long2dot($nn).").\n";
    $$newfields{'subnet.base_address'} = $TrueBase;
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'subnet', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM subnet WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_subnet: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::modify_subnet: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
}

# Function: purged_subnet
# Arguments 6:
#     An already connected database handle
#     The name of the user performing the query
#     The 'id' of the row to change
#     The 'version' of the row to change
#     The last done time
# Actions: Updates the specified row, if authorized
# Return value:
#    1 if successful
#    An error code otherwise
sub purged_subnet {
  my ($dbh, $dbuser, $id, $version, $lastdone) = @_;
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (getError($dbuser), ['dbuser']) if (getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet.id', $id, $dbuser, 0, $dbh);
  return (getError($id), ['id']) if (getError($id) != 1);

  $version = CMU::Netdb::valid('subnet.version', $version, $dbuser, 0, $dbh);
  return (getError($version), ['version']) if (getError($version) != 1);
  
  my $ul = get_write_level($dbh, $dbuser, 'subnet', $id);
  return ($errcodes{EPERM}, ['perm']) if ($ul < 9);
  
  my %newfields;
  $newfields{'subnet.purge_lastdone'} = CMU::Netdb::valid('subnet.purge_lastdone', $lastdone, $dbuser, 0, $dbh);
  
  return (getError($newfields{'subnet.purge_lastdone'}), ['purge_lastdone']) 
    if (getError($newfields{'subnet.purge_lastdone'}) != 1);
  
  my $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'subnet', $id, $version, \%newfields);
  return ($errcodes{"ERROR"}, ['unknown']) if ($result != 1);
  
  return ($result, []);
}

# Function: modify_network
# Arguments: 5:
#     An already connected database handle
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_network {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('network.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['network.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('network.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['network.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@network_fields) {
    my $nk = $key;		# required because $key is a reference into network_fields
    $nk =~ s/^network\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^network\.$key$/, @network_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find network.$key!\n".Dumper($fields, @network_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("network.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "network.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"network.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'network', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM network WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_network: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::modify_network: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  return ($result, []);
}


# Function: modify_subnet_share
# Arguments: 5:
#     An already connected database handle
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_subnet_share {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet_share.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet_share.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@subnet_share_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_share_fields
    $nk =~ s/^subnet_share\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet_share\.$key$/, @subnet_share_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet_share.$key!\n".Dumper($fields, @subnet_share_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet_share.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet_share.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet_share.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'subnet_share', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM subnet_share WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_subnet_share: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::modify_subnet_share: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
  
}


# Function: modify_subnet_presence
# Arguments: 5:
#     An already connected database handle
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_subnet_presence {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet_presence.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet_presence.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@subnet_presence_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_presence_fields
    next if ($nk eq 'building.name');
    next if ($nk eq 'subnet.name');
    $nk =~ s/^subnet_presence\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet_presence\.$key$/, @subnet_presence_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet_presence.$key!\n".Dumper($fields, @subnet_presence_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet_presence.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet_presence.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet_presence.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'subnet_presence', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM subnet_presence WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_subnet_presence: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::modify_subnet_presence: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
  
}


# Function: modify_subnet_domain
# Arguments: 5:
#     An already connected database handle
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_subnet_domain {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet_domain.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet_domain.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@subnet_domain_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_domain_fields
    $nk =~ s/^subnet_domain\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^subnet_domain\.$key$/, @subnet_domain_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find subnet_domain.$key!\n".Dumper($fields, @subnet_domain_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("subnet_domain.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "subnet_domain.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"subnet_domain.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'subnet_domain', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM subnet_domain WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_subnet_domain: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::modify_subnet_domain: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
  
}


# Function: delete_subnet_domain
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_subnet_domain {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet_domain.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet_domain.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
 ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'subnet_domain', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM subnet_domain WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_subnet_domain: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_subnet_domain: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}


# Function: delete_subnet_registration_mode
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_subnet_registration_mode {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet_registration_modes.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet_registration_modes.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
 ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'subnet_registration_modes', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM subnet_registration_modes WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_subnet_registration_mode: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_subnet_registration_mode: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}


# Function: delete_machine
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_machine {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, %ofields, $orig, @mach_field_short,
      $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('machine.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('machine.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = CMU::Netdb::list_machines($dbh, "netreg", "machine.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@machine_fields) {
    my $nk = $_;
    $nk =~ s/^machine\.//;
    push(@mach_field_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ {$$orig[1]}[$i++] } @mach_field_short;
  }
  
  my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'machine', $id);
  my ($oldZoneFw, $oldZoneRv) = ($ofields{host_name_zone}, $ofields{ip_address_zone});
  
  ## reject abuse/suspended updates
  return ($errcodes{EPERM}, ['flags']) if ($ul < 9 && $ofields{'flags'} =~ /(abuse|suspend)/);
  
  return ($errcodes{EPERM}, ['id']) if ($ul < 1);
  
  # reject deletion of machines with secondary IP's: they must be deleted first
  if ($ofields{mode} ne 'secondary') {
    my $ref = &CMU::Netdb::list_machines($dbh,"netreg","machine.mac_address='$ofields{'mac_address'}' AND ip_address_subnet=$ofields{'ip_address_subnet'} AND mode='secondary'");
    if (ref $ref && $#$ref > 0) {
      return ($errcodes{ESECONDARY}, ['id']);
    }
  }
  
  my $resources = CMU::Netdb::list_dns_resources($dbh,"netreg","dns_resource.owner_type = 'machine' AND dns_resource.owner_tid = $id");
  return ($resources, ['dns_resources']) if (!ref $resources);

  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'machine', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM machine WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_machine: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_machine: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  my $result2 = CMU::Netdb::delete_protection_tid($dbh, $dbuser, 'machine', $id);
  # FIXME error checking here? 
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    "zone updates: fw $oldZoneFw; rv $oldZoneRv\n" if ($debug >= 2);;

  CMU::Netdb::force_zone_update($dbh, $oldZoneFw);
  CMU::Netdb::force_zone_update($dbh, $oldZoneRv);
  
 if ($#$resources) {
    my $resmap = CMU::Netdb::makemap($resources->[0]);
    shift @$resources;
    foreach my $r (@$resources) {
      warn Data::Dumper->Dump([$r, $resmap], ['resource', 'resmap']);
      warn  __FILE__, ':', __LINE__, ' :>'.
        "zone update for dns_resource : $r->[$resmap->{'dns_resource.name_zone'}]" if ($debug >= 2);;
      CMU::Netdb::force_zone_update($dbh, $r->[$resmap->{'dns_resource.name_zone'}]);
    }
  }

  return ($result, []);
  
}


# Function: delete_subnet
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)

#  FIXME 9: kevinm: make this cascade delete subnet_presence and subnet_domain
#  FIXME 3: kevinm: does this really return ESTALE ever? or for that matter,
#           if the key doesn't even exist?

sub delete_subnet {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'subnet', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM subnet WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_subnet: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_subnet: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# Function: delete_network
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_network {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['name']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('network.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('network.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'network', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM network WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_network: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_network: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['db']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
}

# Function: delete_subnet_share
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)

# FIXME 9: kevinm: make this cascade change all references to this subnet share
# in 'subnet' to '0'
sub delete_subnet_share {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet_share.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet_share.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'subnet_share', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM subnet_share WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_subnet_share: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_subnet_share: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
}


# Function: delete_subnet_presence
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_subnet_presence {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('vlan_subnet_presence.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('vlan_subnet_presence.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'vlan_subnet_presence', $id, $version);

  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM vlan_subnet_presence WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_vlan_subnet_presence: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_vlan_subnet_presence: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# Function: get_subnet_vlan_presence
# Arguments: 4:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (subnet.{name,abbreviation} vlan.{name,abbreviation}
# Actions: Queries the database and retrieves the subnet ID and name 
#          for the vlan_subnet_presence rows specified
# Return value:
#     A reference to an associative array of vlan_subnet_presence.subnet =>
#        $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_subnet_vlan_presence {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('vlan_subnet_presence.subnet', $efield);
  $lwhere = 'vlan_subnet_presence.subnet = subnet.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "subnet, vlan_subnet_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}

# Function: get_vlan_subnet_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the subnet ID and name 
#          for the subnet_presence rows specified
# Return value:
#     A reference to an associative array of subnet_presence.subnet =>
#        subnet.name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_vlan_subnet_presence {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('vlan_subnet_presence.vlan');
  push @lfields, $efield if ($efield);
  $lwhere = 'vlan_subnet_presence.vlan = vlan.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "vlan, vlan_subnet_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}

# Function: list_vlan_subnet_presences
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "subnet = 106"
# Actions: Queries the database in the handle for rows in
#          the vlan_subnet_presence table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_vlan_subnet_presences {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @fields);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "vlan_subnet_presence", \@vlan_subnet_presence_fields, $where);

  if (!ref $result) {
    return $result;
  }

  if ($#$result == -1) {
    return [\@vlan_subnet_presence_fields];
  }

  @data = @$result;
  unshift @data, \@vlan_subnet_presence_fields;

  return \@data;
}

## find_available_ip
## Attempts to find an available IP on the specified subnet

## WARNING: changing the table aliases in the queries may require
## changes to the locking semantics of functions that use find_available_ip

sub find_available_ip {
  my ($dbh, $fields) = @_;
  my ($query, $sth, @row, $base, $last, $ip);
  my ($res, $BASE_SAVE, $TOP_SAVE);
  ($res, $BASE_SAVE) = CMU::Netdb::config::get_multi_conf_var('netdb', 'BASE_SAVE');
  $BASE_SAVE = 2 if ($res != 1);
  ($res, $TOP_SAVE) = CMU::Netdb::config::get_multi_conf_var('netdb', 'TOP_SAVE');
  $TOP_SAVE = 2 if ($res != 1);

  warn __FILE__, ':', __LINE__, ' :>', "BASE_SAVE = $BASE_SAVE\nTOP_SAVE = $TOP_SAVE\n" if ($debug >= 2);
  # first pass: try to be somewhat intelligent and have the database spoon
  # feed us an IP
  $query = "
SELECT M1.ip_address+1
FROM subnet AS S1, machine as M1 LEFT JOIN machine as M2
  ON M1.ip_address+1 = M2.ip_address 
WHERE M1.ip_address_subnet = '$$fields{'machine.ip_address_subnet'}'
  AND M2.ip_address IS NULL 
  AND M1.ip_address != 0
  AND M1.ip_address_subnet = S1.id
  AND M1.ip_address > (S1.base_address + $BASE_SAVE)
  AND M1.ip_address < ((S1.base_address | (~S1.network_mask & $IPSuperMask)) - ($TOP_SAVE + 1))
ORDER BY M1.ip_address LIMIT 1
";
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "find_available_ip quick lookup query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  @row = $sth->fetchrow_array();
  if (defined $row[0] && $row[0] ne '') {
    $ip = $row[0];
    my $hzones = CMU::Netdb::list_subnets_ref($dbh, "netreg", 
					      " ((base_address | ".
					      " (~network_mask&$IPSuperMask))".
					      " ='$ip' OR base_address = '$ip')", 'subnet.name');
    return ($hzones, ['ip_address']) if (!ref $hzones);
    my $hzk = keys %$hzones;
    if (!($hzk >= 1)) {
      # The address isn't a subnet or broadcast address.
      # But is it in the right subnet?
      $hzones = CMU::Netdb::list_subnets_ref($dbh, "netreg", " (base_address = ('$ip' & network_mask)) ", 'subnet.name');
      return ($hzones, ['ip_address']) if (!ref $hzones);
      my @hza = keys %$hzones;
      $hzk = @hza;
      if (($hzk == 1) && ($$fields{"machine.ip_address_subnet"} eq $hza[0])) {
	warn __FILE__, ':', __LINE__, ' :>', "Quick IP Lookup found ".CMU::Netdb::long2dot($ip)."\n" if ($debug >= 2);
	return [$ip];
      } else {
	warn  __FILE__, ':', __LINE__, ' :>'.
	  "$ip is in the wrong subnet\n" if ($debug >= 2);
      }
    } else {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"$ip is a network or broadcast address\n" if ($debug >= 2);
    }
  }
  
  # no IP for us... yet
  $query = "
SELECT S1.base_address, (S1.base_address | (~network_mask & $IPSuperMask))
FROM subnet AS S1 WHERE id = '$$fields{'machine.ip_address_subnet'}'
";
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "find_available_ip secondary query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  @row = $sth->fetchrow_array();
  if (!defined $row[0] || !defined $row[1]) {
    return $errcodes{ESUBNET};
  }
  $sth->finish;
  $base = $row[0];
  $last = $row[1];
  
  $query = "
SELECT M1.ip_address
FROM machine as M1
WHERE M1.ip_address_subnet = '$$fields{'machine.ip_address_subnet'}'
";
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "find_available_ip subnet usage query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  my %IPused;
  while(@row = $sth->fetchrow_array()) {
    $IPused{$row[0]} = 1;
  }
  $sth->finish;
  #  $last = CMU::Netdb::dot2long(CMU::Netdb::calc_bcast(CMU::Netdb::long2dot($base), CMU::Netdb::long2dot($last)))-3;
  $last = $last-$TOP_SAVE;
  $base = "0".$base;
  $base += $BASE_SAVE + 1;
  while($base < $last) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "$base\n" if ($debug >= 3);
    if (!defined $IPused{$base}) {
      warn __FILE__, ':', __LINE__, ' :>', "Secondary IP Lookup found ".CMU::Netdb::long2dot($base)."\n" if ($debug >= 2);

      return [$base];
    }
    $base++;
  }
  
  # nope.. they're all taken. send off some email to the netreg folks
  # FIXME 8: send mail that we're out of IPs on this subnet 
  # Better make this an option, there is at least one program that uses
  # up a subnet on purpose.
  return $errcodes{ENOIP};
}    

## verify_mac_subnet_unique
## Given the MAC and subnet, verifies they are unique.
## Complicated by the fact that it needs to be unique amongst all subnets
## that are "shared", also it is immediately non-unique if the MAC is
## used by a dynamic machine
## Returns: 1 if the MAC can be used, 0 if not

## WARNING: changing the table aliases may require changes to the locking
## semantics of functions that use verify_mac_subnet_unique
sub verify_mac_subnet_unique {
  my ($dbh, $fields, $update) = @_;
  my ($sth, @row, $query);
  
  $query = "
SELECT DISTINCT M1.mac_address
FROM machine as M1, subnet as S1, subnet as S2
WHERE 
";
    $query .= "M1.id != '$update' AND " if ($update > 0);
  $query .= "
      S1.id = '$$fields{'machine.ip_address_subnet'}'
  AND M1.mac_address = '$$fields{'machine.mac_address'}'
  AND M1.mode != 'secondary'
  AND ((S1.share = 0 
       AND M1.ip_address_subnet = S1.id)
  OR (S1.share != 0
      AND S1.share = S2.share
      AND M1.ip_address_subnet = S2.id )
  OR (
    M1.mac_address = '$$fields{'machine.mac_address'}'
  AND M1.mode = 'reserved')) ";

    warn  __FILE__, ':', __LINE__, ' :>'.
      "verify_mac_subnet_unique query: $query\n" if ($debug >= 2);
  
  $sth = $dbh->prepare($query);
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  @row = $sth->fetchrow_array();
  return 0 if (defined $row[0] && $row[0] ne '');
  return 1;
}

## check_host_unique
## Given the host name and subnet, verifies they are unique

sub check_host_unique {
  my ($dbh, $dbuser, $fields, $update) = @_;
  my ($sth, @row, $query);
  
  ## check machine table
  $query = "
SELECT DISTINCT M1.host_name, M1.ip_address_subnet
FROM machine as M1
WHERE ";

    $query .= "M1.id != '$update' AND " if ($update > 0);
  $query .= "M1.host_name = \'$$fields{'machine.host_name'}\'";
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    "check_host_unique query: $query\n" if ($debug >= 2);
  
  $sth = $dbh->prepare($query);
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  @row = $sth->fetchrow_array();
  return 0 if (defined $row[0] && $row[0] ne '');
  
  ## check dns resource table
  $query = "
SELECT DISTINCT DR.name
FROM dns_resource as DR
WHERE DR.name = '$$fields{'machine.host_name'}' AND type = 'CNAME' ";
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "check_host_unique query: $query\n" if ($debug >= 2);
  
  $sth = $dbh->prepare($query);
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  @row = $sth->fetchrow_array();
  return 0 if (defined $row[0] && $row[0] ne '');
  return 1;
}

######################################################
#
# This generates the first part of a Unique Hostname
# It pulls a UUID to use for the tempory hostname
# The mysql UUID is conprised of a timestamp (down to 
# the tenths of mircoseconds), MAC addy of the host,
# and a random number and thus should have enough 
# uniqueness for us.
#  
# The second part of the process is handled by 
# getUniqueHostname.
######################################################

sub getRandomHostname {

  my ($dbh, $domain) = @_;

  ## Ask mysql for a UUID to use for the random part
  ## of the tempory hostname
  my $query = "SELECT UUID()";
  warn  __FILE__, ':', __LINE__, ' :>'.
    "getRandomHostname query: $query\n" if ($debug >= 2);

  my $sth = $dbh->prepare($query);
  $sth->execute;

  my @row = $sth->fetchrow_array;
  return '' if (!@row);

  $sth->finish();

  warn  __FILE__, ':', __LINE__, ' :>'.
      "getRandomHostname results: ". Data::Dumper->Dump([\@row], ['row'])."\n" if ($debug >= 2);
  ## Putting the two pieces together and returning
  return $row[0] . ".$domain";
}

######################################################
#
# This handles the second part of generating a Unique
# Host Name. 
# It pulls the default host name prefix from the netdb-
# conf file and appends to it the machine's proper ID
# and the correct domain.
#####################################################

sub getUniqueHostname {

  my ($dbh, $hostname) = @_;

  my ($host, $domain) = splitHostname($hostname);

  ##Grabbing the Host Name prefix from the netdb conf
  my ($res, $hn_prefix) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'HN_PREFIX');

  # FIXME, next row insert id is different columns for different db versions!
  # return $hn_prefix.$row[9].".$domain";  # mysql 4.*
  #  return $hn_prefix.$row[10].".$domain"; # mysql 5.*

  ## Combining the two parts to from the new unique hostname and
  ## and returning result
  return $hn_prefix.getHostnameID($dbh, $hostname).".".$domain;

}

######################################################
#
# This takes a database handler and hostname and 
# returns an ID
#####################################################

sub getHostnameID {
  my ($dbh, $hostname) = @_;

  ## Query to grab the ID from the hostname
  my $query = "SELECT id FROM machine WHERE host_name = '$hostname'";

  my ($h, $d) = splitHostname($hostname);
  my $sth = $dbh->prepare($query);
  $sth->execute;

  my @row = $sth->fetchrow_array;
  return '' if (!@row);

  return $row[0];
}

#####################################################
#
# This takes a database handler and hostname and 
# returns a version
#####################################################

sub getHostnameVersion {
  my ($dbh, $hostname) = @_;

  ## Query to grab version from the hostname
  my $query = "SELECT version FROM machine WHERE host_name = '$hostname'";

  my ($h, $d) = splitHostname($hostname);
  my $sth = $dbh->prepare($query);
  $sth->execute;

  my @row = $sth->fetchrow_array;
  return '' if (!@row);

  return $row[0];
}

sub changeHostname {
  my ($dbh, $dbuser, $old, $new) = @_;

  my $id = getHostnameID($dbh, $old);
  my $version = getHostnameVersion($dbh, $old);

  my $res = CMU::Netdb::primitives::modify($dbh, $dbuser, 'machine', 
					   $id, $version, 
					   { 'host_name' => $new }
					  );
}

sub register_ips {
  my ($dbh, $dbuser, $sid, $nIP, $mode, $amethod, $hn, $dept, $user) = @_;
  
  $mode = CMU::Netdb::valid('subnet.machine_mode', $mode, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($mode), ['mode'])
    if (CMU::Netdb::getError($mode) != 1);
  
  $amethod = CMU::Netdb::valid('subnet.allocation_method', $amethod, $dbuser,
			       0, $dbh);
  return (CMU::Netdb::getError($amethod), ['amethod'])
    if (CMU::Netdb::getError($amethod) != 1);
  
  # Validate the hostname with a fake IP substitution
  {
    my $Uhn = $hn;
    $Uhn =~ s/\%ip/127-0-0-1/i;
    $Uhn = CMU::Netdb::valid('subnet.hostname', $Uhn, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($Uhn), ['hostname', $hn])
      if (CMU::Netdb::getError($Uhn) != 1);
  }
  
  $nIP = CMU::Netdb::valid('subnet.number_of_ips', $nIP, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($nIP), ['number_of_ips'])
    if (CMU::Netdb::getError($nIP) != 1);
  
  # Prepare a list of all the available IPs in the subnet
  my $rAvailIPs = subnets_get_free_ip_list($dbh, $dbuser, $sid);
  
  # Call the allocation method
  # Error < 1; 1 == allocated all; 2 == allocated some, ran out of IPs
  my ($res, $rUseIPs) = $AllocationMethods{$amethod}->($dbh, $dbuser, 
						       $rAvailIPs,
						       $nIP);
  return $res if ($res < 1);
  my @Messages;
  push(@Messages, "Unable to allocate all IPs; no free space.")
    if ($res == 2);
  
  # Allocate all these IPs
  my %fields;
  my %perms;
  unless ($user eq '') {
    $perms{$user}->[0] = 'READ,WRITE';
    $perms{$user}->[1] = 1;
  }
  
  $fields{mode} = $mode;
  $fields{mac_address} = '';
  $fields{ip_address_subnet} = $sid;
  
  foreach my $IP (@$rUseIPs) {
    my $prIP = CMU::Netdb::long2dot($IP);
    my $prHN = $hn;
    $fields{ip_address} = $prIP;
    
    $fields{dept} = $dept;
    
    $prIP =~ s/\./\-/g;
    $prHN =~ s/\%ip/$prIP/i;
    
    $fields{host_name} = $prHN;
    
    my $PreAddStatus = Dumper(\%fields)." -- ".Dumper(\%perms);
    my ($res, $ref) = CMU::Netdb::add_machine($dbh, $dbuser, 9, \%fields,
					      \%perms);
    if ($res < 0) {
      push(@Messages, "Error adding $prIP: <b>".
	   "$CMU::Netdb::errors::errmeanings{$res}</b> [$res] (".
	   join(',', @$ref).") ".Dumper(\%fields)." -- $PreAddStatus");
    }else{
      push(@Messages, "Added $prIP successfully ($prHN)");
    }
  }
  
  return (1, \@Messages);
}

sub subnets_get_free_ip_list {
  my ($dbh, $dbuser, $sid) = @_;
  
  my $query;
  my $sth;
  $query = "
  SELECT S1.base_address, (S1.base_address | (~network_mask & $IPSuperMask))
FROM subnet AS S1 WHERE id = '$sid' ";
    
    $sth = $dbh->prepare($query);
  
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  
  my @row = $sth->fetchrow_array();
  if (!defined $row[0] || !defined $row[1]) {
    return $errcodes{ESUBNET};
  }
  
  $sth->finish;
  my $base = $row[0];
  my $last = $row[1];
  warn  __FILE__, ':', __LINE__, ' :>'.
    "b/l $base/$last\n" if ($debug);
  
  $query = "
SELECT M1.ip_address
FROM machine as M1
WHERE M1.ip_address_subnet = '$sid'
  AND M1.ip_address != 0 ";
    
    $sth = $dbh->prepare($query);
  if (!$sth->execute()) {
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{EDB};
  }
  
  my %IPused;
  while(@row = $sth->fetchrow_array()) {
    $IPused{$row[0]} = 1;
  }
  $sth->finish;
  
  my @Unused;
  my $ip = $base;
  while($ip++ <= $last) {
    push(@Unused, $ip) unless (defined $IPused{$ip} ||
			       ($ip-$base <= 3) ||
			       ($last-$ip <= 3));
  }
  
  return \@Unused;
}

sub subnets_am_lowfirst {
  my ($dbh, $dbuser, $rAvailableIPs, $Num) = @_;
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Entering low first\n";
  my @UseIPs;
  my @A = sort { $a <=> $b } @$rAvailableIPs;
  while($Num-- > 0) {
    return (2, \@UseIPs) if ($#A == -1);
    push(@UseIPs, shift(@A));
  }
  return (1, \@UseIPs);
}

sub subnets_am_highfirst {
  my ($dbh, $dbuser, $rAvailableIPs, $Num) = @_;
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Entering high first\n" if ($debug);
  my @UseIPs;
  my @A = sort { $b <=> $a } @$rAvailableIPs;
  while($Num-- > 0) {
    return (2, \@UseIPs) if ($#A == -1);
    push(@UseIPs, shift(@A));
  }
  return (1, \@UseIPs);
}

sub subnets_am_largeblock {
  my ($dbh, $dbuser, $rAvailableIPs, $Num) = @_;
  my @UseIPs;
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    "Entering largest block\n" if ($debug);
  # figure out the sizes of various blocks
  my %Runs;
  my %RunContents;
  
  my $runcount = 0;
  my $lastIP = -1;
  my $startIP = -1;
  my @contents = ();
  
  foreach my $ip (sort { $a <=> $b } @$rAvailableIPs) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Running: $ip, last: $lastIP, start: $startIP, cnt: $runcount\n";
    if ($lastIP + 1 != $ip ) {
      # Save the run
      if ($runcount != 0 && $startIP != -1 ) {
	push(@{$Runs{$runcount}}, $startIP);
	my @C = @contents;
	$RunContents{$startIP} = \@C;
	$startIP = $ip;
	$runcount = 1;
	$lastIP = $ip;
	@contents = ($ip);
      }else{
	$startIP = $ip;
	$lastIP = $ip;
	$runcount = 1;
	@contents = ($ip);
      }
    }else{
      $runcount++;
      $lastIP = $ip;
      push(@contents, $ip);
    }
  }
  
  # Save the last run
  if ($runcount != 0 && $startIP != -1) {
    push(@{$Runs{$runcount}}, $startIP);
    my @C = @contents;
    $RunContents{$startIP} = \@C;
  }  
  
  warn  __FILE__, ':', __LINE__, ' :>'.
    Dumper(\%Runs) if ($debug >= 2);
  warn  __FILE__, ':', __LINE__, ' :>'.
    Dumper(\%RunContents) if ($debug >= 2);
  
  # Divide the runs into those blocks >= the number of IPs
  # we want to allocate, and those < that number.
  my @Sizes = keys %Runs;
  my @Higher = sort { $a <=> $b } grep { $_ >= $Num } @Sizes; 
  my @Lower = sort { $b <=> $a } grep { $_ < $Num} @Sizes;

  foreach my $size (@Higher) {
    foreach my $RunEnt (@{$Runs{$size}}) {
      goto am_lb_end if ($Num == 0);
      next if (!defined $RunContents{$RunEnt});
      
      warn __FILE__, ':', __LINE__, ' :>'.
	"Allocating block, size $size / start $RunEnt\n"
	  if ($debug >= 2);

      if ($Num < $size) {
	push(@UseIPs, @{$RunContents{$RunEnt}}[0..$Num-1]);
	goto am_lb_end;
      }else{
	push(@UseIPs, @{$RunContents{$RunEnt}});
	$Num = $Num - $size;
      }
      delete $RunContents{$RunEnt};
    }
  }

  foreach my $size (@Lower) {
    foreach my $RunEnt (@{$Runs{$size}}) {
      goto am_lb_end if ($Num == 0);
      next if (!defined $RunContents{$RunEnt});
      
      warn __FILE__, ':', __LINE__, ' :>'.
	"Allocating block, size $size / start $RunEnt\n"
	  if ($debug >= 2);
      delete $Runs{$size} if ($#{$Runs{$size}} == -1);
      push(@UseIPs, @{$RunContents{$RunEnt}});
      delete $RunContents{$RunEnt};
      $Num = $Num - $size;
    }
  }
  
 am_lb_end:
  return (1, \@UseIPs);
}


sub check_registration_quota {
  my ($dbh, $dbuser, $subnet, $mode, $virtual, $update, $subnet_changed, $mode_changed, $was_virtual) = @_;


  # verify that the user can add machines of this mode to this subnet, and isn't over quota

  warn __FILE__, ':', __LINE__, " :> Entering check_registration_quota.  Arguments are:\n" .
    "subnet=$subnet\nmode=$mode\nvirtual=$virtual\nupdate=$update\nsubnet_changed=$subnet_changed\n" .
      "mode_changed=$mode_changed\nwas_virtual=$was_virtual\n" if ($debug >= 2);

  # Verify the subnet exists.
  my $dselect = CMU::Netdb::get_subnets_ref($dbh, $dbuser, "subnet.id = '$subnet'", 'subnet.name');
  return ($errcodes{ESUBNET}, ['ip_address_subnet']) if (!ref $dselect || !defined $$dselect{$subnet});

  # Fetch the users' add level on the subnet directly, and error if no access allowed
  my $sul = CMU::Netdb::get_add_level($dbh, $dbuser, 'subnet', $subnet);
  return ($errcodes{EPERM}, ['ip_address_subnet']) if ($sul < 1);

  # Fetch the users' static registration quota for the subnet
  my $quotas = CMU::Netdb::get_subnet_registration_modes($dbh, $dbuser, "subnet_registration_modes.subnet = '$subnet' AND subnet_registration_modes.mode = '$mode'");
  return ($quotas) if (!ref $quotas);
  my $quota_map = CMU::Netdb::makemap(shift @$quotas);

  # If no quota entry exists, no registrations of this mode allowed.
  # i.e. an entry MUST exist if registrations are to be allowed.
  # If the mode is allowed, with no quota, the quota column will be set to NULL
  # and we'll set maxquota{,_virtual} to undef
  my $maxquota = 0;
  my $maxquota_virtual = 0;

  foreach my $quota (@$quotas) {
    # don't change $maxquota if its already undef

    if (defined $maxquota) {
      # Update $maxquota if this row's quota is undef, or higher then $maxquota
      $maxquota = $quota->[$quota_map->{'subnet_registration_modes.quota'}]
	if ((!defined($quota->[$quota_map->{'subnet_registration_modes.quota'}])
	     || ($quota->[$quota_map->{'subnet_registration_modes.quota'}] > $maxquota))
	    && ($quota->[$quota_map->{'subnet_registration_modes.mac_address'}] eq 'required'));
    }
    # don't change $maxquota_virtual if its already undef
    if (defined $maxquota_virtual) {
      # Update $maxquota_virtual if this row's quota is undef, or higher then $maxquota
      $maxquota_virtual = $quota->[$quota_map->{'subnet_registration_modes.quota'}]
	if ((!defined($quota->[$quota_map->{'subnet_registration_modes.quota'}])
	     || ($quota->[$quota_map->{'subnet_registration_modes.quota'}] > $maxquota))
	    && ($quota->[$quota_map->{'subnet_registration_modes.mac_address'}] eq 'none'));
    }
  }

  warn  __FILE__, ':', __LINE__, " :> Virtual registration quota $maxquota_virtual, Normal quota $maxquota\n" if ($debug);

  if ($virtual) {
    # Virtual host registration
    warn  __FILE__, ':', __LINE__, " :> Checking virtual host registration quota.  Quota is $maxquota_virtual\n"
      if ($debug >= 2);
	
    # if maxquota_virtual is undef, the registration is allowed, with no quota.
    # so we're only doing any checking at all if its defined...
    if (defined $maxquota_virtual) {

      # if maxquota_virtual is zero, the registration is disallowed
      # But we'll allow it if its an update to an existing record, and the existing
      # record is already virtual.
      if ($maxquota_virtual == 0 && (!$update || !$was_virtual)) {
	if (!defined($maxquota) || $maxquota > 0) {
	  return ($errcodes{EBLANK}, ['mac_address']);
	} else {
	  return ($errcodes{EPERM}, ['ip_address_subnet, mode']);
	}
      }

      # drat, neither edge case is true, so we must count the registrations directly owned by the user
      my ($query, $sth);
      $query = "SELECT STRAIGHT_JOIN COUNT(DISTINCT machine.id)
FROM credentials as C, protections as P, machine 
WHERE C.authid = '$dbuser' 
 AND P.tname = 'machine'
 AND FIND_IN_SET('READ', P.rights)
 AND C.user = P.identity       
 AND P.tid = machine.id
 AND machine.ip_address_subnet = '$subnet'
 AND machine.mode = '$mode'
 AND machine.mac_address = ''
";

      warn  __FILE__, ':', __LINE__, " :> Quota usage query is $query\n"
	if ($debug >= 2);

      $sth = $dbh->prepare($query);
      if (!($sth->execute())) {
	warn  __FILE__, ':', __LINE__, ' :>'.
	  "CMU::Netdb::machines_subnets::add_machine_mod_static error: $DBI::errstr" if ($debug >= 2);
	$CMU::Netdb::primitives::db_errstr = $DBI::errstr;
	return $errcodes{"EDB"};
      } else {
	my @rows = $sth->fetchrow_array();
	if (scalar(@rows) && $rows[0] >= $maxquota_virtual ) {
	  return ($errcodes{EQUOTA}, ["mode=$mode, quota=$maxquota_virtual"])
	    if (!$update
		|| $subnet_changed
		|| $mode_changed);

	}
      }
    }
    # If we got to here, adding to the subnet was allowed...

  } else {
    # Normal host registration

    warn  __FILE__, ':', __LINE__, " :> Checking host registration quota.  Quota is $maxquota\n"
      if ($debug >= 2);
	
    # if maxquota is undef, the registration is allowed, with no quota.
    # so we're only doing any checking at all if its defined...
    if (defined $maxquota) {

      # if maxquota is zero, the registration is disallowed
      # But we'll allow it if its an update to an existing record, and the mac_address
      # hasn't been changed.
      if ($maxquota == 0 && (!$update || $was_virtual)) {
	if (!defined($maxquota_virtual) || $maxquota_virtual > 0) {
	  return ($errcodes{ENOIWANTTOBEBLANK}, ['mac_address']);
	} else {
	  return ($errcodes{EPERM}, ['ip_address_subnet']);
	}
      }

      # drat, neither edge case is true, so we must count the registrations directly owned by the user
      my ($query, $sth);
      $query = "SELECT STRAIGHT_JOIN COUNT(DISTINCT machine.id)
FROM credentials as C, protections as P, machine 
WHERE C.authid = '$dbuser' 
 AND P.tname = 'machine'
 AND FIND_IN_SET('READ', P.rights)
 AND C.user = P.identity       
 AND P.tid = machine.id
 AND machine.ip_address_subnet = '$subnet'
 AND machine.mode = '$mode'
 AND machine.mac_address != ''
";

      warn  __FILE__, ':', __LINE__, " :> Quota usage query is $query\n"
	if ($debug >= 2);

      $sth = $dbh->prepare($query);
      if (!($sth->execute())) {
	warn  __FILE__, ':', __LINE__, ' :>'.
	  "CMU::Netdb::machines_subnets::add_machine_mod_static error: $DBI::errstr" if ($debug >= 2);
	$CMU::Netdb::primitives::db_errstr = $DBI::errstr;
	return $errcodes{"EDB"};
      } else {
	my @row = $sth->fetchrow_array();
	if (scalar(@row) && $row[0] >= $maxquota ) {
	  return ($errcodes{EQUOTA}, ["mode=$mode, quota=$maxquota"])
	    if (!$update
		|| $subnet_changed
		|| $mode_changed);
	}
      }
    }

    # If we got to here, adding to the subnet was allowed
	
  }

  return 1;

}

sub search_leases {
    my ($dbh, $dbuser, $fields, $time) = @_;

    # Check user access
    my $sul = CMU::Netdb::get_add_level($dbh, $dbuser, 'machine', 0);
    return ($errcodes{EPERM}, ['machine']) if ($sul < 9);

    # See if we have an archive directory
    my ($res, $fdir) = CMU::Netdb::config::get_multi_conf_var
	('netdb', 'DHCP_LEASE_ARCHIVE_DIR');

    if ($res != 1 || $fdir eq '') {
	return (0, ['filedir']);
    }
    
    # Get the lease search object
    my $lq = new CMU::Netdb::dhcp_lease_search(filedir => $fdir);

    # Construct the search string
    my $search = '';
    my $termcnt = -1;

    if ($fields->{'ip_address'} ne '') {
        $search .= $fields->{'ip_address'} . ' $ip_address = ';
	#$search .= $fields->{'ip_address'} . ' $ip_address =~ ';
	#Changed this so a string comp is done (vs regex compare)
	$termcnt++;
    }
    if ($fields->{'mac_address'} ne ':::::') {
	$search .= $fields->{'mac_address'} . ' $mac_address =~ ';
	$termcnt++;
    }
    if ($fields->{'name'} ne '') {
	$search .= $fields->{'name'} . '$client_hostname =~ ';
	$search .= $fields->{'name'} . '$ddns_fwdname =~ OR ';
	$termcnt++;
    }

    #Tech that is an exclusive search and only good to the second hand.
    $search .= 'active' . ' $binding_state = AND ' . $time . ' $start > AND ';

    $search .= ' AND'x$termcnt;

    my $lres = $lq->find_lease($search, $time);

    return ($lres, [$search, $time]) unless (ref $lres);

    return (1, $lres);
}

# Function: count_machines
# Arguments: :
#     An already connected database handle
#     The name of the user making the request
#     An optional where clause limiting the search.
# Actions: Counts the machines that the user can see.
# Return value:
#     Ref to standard return array or integer error code.

sub count_machines{
  my ($dbh, $dbuser, $where) = @_;
  my $count;

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($dbuser)
    if (CMU::Netdb::validity::getError($dbuser) != 1);

  $count = CMU::Netdb::primitives::count($dbh, $dbuser, 'machine', $where);
  if (ref $count) {
    return ([['Count'],$count]);
  }
  return($count);
}


1;
