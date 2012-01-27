#   -*- perl -*-
#
# CMU::Netdb::buildings_cables
# This module provides the necessary API functions for
# manipulating the buildings, cables & outlet tables
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
#

package CMU::Netdb::buildings_cables;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug @building_fields @cable_fields 
	    @outlet_type_fields @outlet_fields @outlet_cable_fields 
	    @activation_q_fields @outlet_subnet_membership_fields @outlet_vlan_membership_fields);
use CMU::Netdb::primitives;
use CMU::Netdb::structure;
use CMU::Netdb::errors;
use CMU::Netdb::validity;
use CMU::Netdb::auth;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     list_buildings list_buildings_ref list_buildingID_ref
	     list_cables list_cables_outlets
	     list_cables_closets
	     list_outlet_types list_outlet_types_ref
	     list_outlets list_outlets_cables 
	     list_outlets_cables_munged_protections
	     list_activation_queue list_activation_queue_ref
	     list_outlet_subnet_memberships
	     list_outlet_vlan_memberships list_outlets_devport
	     list_outlets_attributes_devport
	     
	     add_building
	     add_cable
	     add_outlet_type
	     add_outlet
	     add_outlet_subnet_membership
	     add_outlet_vlan_membership
	     add_activation_queue
	     
	     modify_building
	     modify_cable
	     modify_outlet_type
	     modify_outlet
	     modify_outlet_subnet_membership
	     modify_outlet_vlan_membership
	     modify_activation_queue
	     modify_outlet_state_by_name 

	     delete_building
	     delete_cable
	     delete_outlet_type
	     delete_outlet
	     delete_outlet_subnet_membership
	     delete_outlet_vlan_membership
	     delete_activation_queue

	     expire_outlet

	     check_devport_mapping
	     check_devnet_mapping
	     update_auxvlan
	     
	     get_outlet_state get_outlet_types_ref
	    );

@building_fields = @CMU::Netdb::structure::building_fields;
@cable_fields = @CMU::Netdb::structure::cable_fields;
@outlet_type_fields = @CMU::Netdb::structure::outlet_type_fields;
@outlet_fields = @CMU::Netdb::structure::outlet_fields;
@outlet_subnet_membership_fields = @CMU::Netdb::structure::outlet_subnet_membership_fields;
@outlet_vlan_membership_fields = @CMU::Netdb::structure::outlet_vlan_membership_fields;
@outlet_cable_fields = @CMU::Netdb::structure::outlet_cable_fields;
@activation_q_fields = @CMU::Netdb::structure::activation_q_fields;

$debug = 0;

# Function: list_buildings
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
sub list_buildings {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "building", \@building_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@building_fields];
  }
  
  @data = @$result;
  unshift @data, \@building_fields;
  
  return \@data;
  
}

sub list_activation_queue {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "activation_queue", \@activation_q_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@activation_q_fields];
  }
  
  @data = @$result;
  unshift @data, \@activation_q_fields;
  
  return \@data;
}

sub list_activation_queue_ref {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, %rbdata);
  
  @lfields = ('activation_queue.id', 'activation_queue.name');
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "activation_queue", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: list_buildings_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the building table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an associative array of building.abbreviation => 
#        building.name for each row that matched the query.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_buildings_ref {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, %rbdata);
  
  @lfields = ('building.building', 'building.name');
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "building", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
  
}

# Function: list_buildingID_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the building table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an associative array of building.abbreviation => 
#        building.name for each row that matched the query.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_buildingID_ref {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, %rbdata);
  
  @lfields = ('building.id', 'building.name');
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "building", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
  
}


# Function: list_cables
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the cable table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_cables {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "cable", \@cable_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@cable_fields];
  }
  
  @data = @$result;
  unshift @data, \@cable_fields;
  
  return \@data;
  
}

# sub list_cables_list_fields {
#   my ($dbh, $dbuser, $where) = @_;
#   my ($result, @data, @pfields);
  
#   $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
#   return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
#   @pfields = ('cable.label_from', 'cable.label_to', 'cable.type',
# 	      'cable.destination', 'cable.to_building', 'cable.to_room_number');
  
#   $result = CMU::Netdb::primitives::list($dbh, $dbuser, "cable", \@pfields, $where);
  
#   if (!ref $result) { 
#     return $result;
#   }
  
#   if ($#$result == -1) {
#     return [\@pfields];
#   }
  
#   @data = @$result;
#   unshift @data, \@pfields;
  
#   return \@data;
  
# }


# Function: list_outlet_types
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the outlet_type table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_outlet_types {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "outlet_type", \@CMU::Netdb::structure::outlet_type_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@outlet_type_fields];
  }
  
  @data = @$result;
  unshift @data, \@outlet_type_fields;
  
  return \@data;
  
}


# Function: list_outlet_types_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the outlet_type table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an associative array of outlet.id => 
#        outlet.name for each row that matched the query.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_outlet_types_ref {
  my ($dbh, $dbuser, $type, $where) = @_;
  my ($result, @lfields, %rbdata);
  
  @lfields = ('outlet_type.id', 'outlet_type.name');
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  if ($type eq 'GET') {
    $result = CMU::Netdb::primitives::get($dbh, $dbuser, "outlet_type", \@lfields, $where);
  } else {
    $result = CMU::Netdb::primitives::list($dbh, $dbuser, "outlet_type", \@lfields, $where);
  }
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
  
}

# Function: list_outlets
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the outlet table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_outlets {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
 
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "outlet", \@outlet_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@outlet_fields];
  }
  
  @data = @$result;
  unshift @data, \@outlet_fields;
  
  return \@data;
}

# Function: list_outlets_cable_munged_protections
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
sub list_outlets_cables_munged_protections {
  my ($dbh, $dbuser, $type, $in, $where) = @_;
  my ($result, @data, $query, $sth);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  # if group, make sure they belong to this group
  if ($type eq 'GROUP') {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying group membership.\n" if ($debug >= 1);;
    my $gmem = CMU::Netdb::list_members_of_group($dbh, 'netreg', $in,
						 "credentials.authid = '$dbuser'");
    if (!ref $gmem || !defined $gmem->[1]) {
      return $errcodes{EPERM};
    }
  }
  
  if ($type eq 'USER') {
    if (CMU::Netdb::can_read_all($dbh, $dbuser, 'outlet', "(P.identity = '$in')", '')) {
      $query = "SELECT DISTINCT ".
	join(', ', @CMU::Netdb::structure::outlet_cable_fields).
	  " FROM outlet LEFT JOIN cable ON outlet.cable = cable.id ".
	    "LEFT JOIN building ON building.building = cable.to_building ".
	      "WHERE TRUE \n";
    } else {
      $query = "SELECT DISTINCT ".join(', ', @CMU::Netdb::structure::outlet_cable_fields)."\n".<<END_SELECT;
FROM credentials AS C,
     protections as P,
     outlet
LEFT JOIN cable ON outlet.cable = cable.id
LEFT JOIN building ON building.building = cable.to_building
WHERE C.authid ='$dbuser'
 AND P.tname = 'outlet'
 AND FIND_IN_SET('READ', P.rights)
 AND C.user = P.identity
 AND P.tid = outlet.id
END_SELECT
    }
  } elsif ($type eq 'GROUP') {
    $in = $in*-1;
    if (CMU::Netdb::can_read_all($dbh, $dbuser, 'outlet', "(P.identity = '$in')", '')) {
      $query = "SELECT DISTINCT ".join(', ', @CMU::Netdb::structure::outlet_cable_fields)." FROM outlet LEFT JOIN cable ON outlet.cable = cable.id LEFT JOIN building ON building.building = cable.to_building WHERE TRUE\n";
    } else {
      $query = "SELECT DISTINCT ".join(', ', @CMU::Netdb::structure::outlet_cable_fields)."\n".<<END_SELECT;
FROM credentials AS C, memberships as M, protections as P, outlet LEFT JOIN cable ON outlet.cable = cable.id LEFT JOIN building ON building.building = cable.to_building
WHERE C.authid = '$dbuser'
 AND P.tname = 'outlet'
 AND P.identity = '$in'
 AND FIND_IN_SET('READ', P.rights)
 AND C.user = M.uid AND M.gid*-1 = P.identity
 AND P.tid = outlet.id
END_SELECT
    }
  } elsif ($type eq 'ALL') {
    return CMU::Netdb::list_outlets_cables($dbh, $dbuser, $where);
  } else {
    return $errcodes{ERROR};
  }
  $query .= " AND $where" if ($where ne '');
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::buildings_cables::list_outlets_cables_munged_protections query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::buildings_cables::list_outlets_cables_munged_protections error: $DBI::errstr" if ($debug >= 2);
    $CMU::Netdb::primitives::db_errstr = $DBI::errstr;
    return $errcodes{"EDB"};
  } else {
    my $rows = $sth->fetchall_arrayref();
    if (ref $rows) {
      CMU::Netdb::primitives::prune_restricted_fields($dbh, $dbuser, $rows, \@CMU::Netdb::structure::outlet_cable_fields);
      my @data = @$rows;
      unshift @data, \@outlet_cable_fields;
      return \@data;
    } else {
      return [\@outlet_cable_fields];
    }
  }
}

# Function: list_outlets_cables
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the outlet table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_outlets_cables {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "outlet LEFT JOIN cable ON outlet.cable = cable.id LEFT JOIN building ON cable.to_building = building.building", \@outlet_cable_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@outlet_cable_fields];
  }
  
  @data = @$result;
  unshift @data, \@outlet_cable_fields;
  
  return \@data;
}

sub list_cables_outlets {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "cable LEFT JOIN outlet ON cable.id = outlet.cable LEFT JOIN building ON cable.to_building = building.building", \@outlet_cable_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@outlet_cable_fields];
  }
  
  @data = @$result;
  unshift @data, \@outlet_cable_fields;
  
  return \@data;
}

# only gets closet information
sub list_cables_closets {
  my ($dbh, $dbuser, $building) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, 'cable', ['cable.from_closet'], "cable.from_building = $building");
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [];
  }
  
  my @res = map { $_->[0] } @$result;
  
  return \@res;
}

# Function: add_activation_queue
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_activation_queue {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@activation_q_fields) {
    my $nk = $key;		# required because $key is a reference into activation_q_fields
    $nk =~ s/^activation_queue\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^activation_queue\.$key$/, @activation_q_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find activation_queue.$key!\n".join(',', @activation_q_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("activation_queue.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "activation_queue.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"activation_queue.$key"} = $$fields{$key};
  }
  
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'activation_queue', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return($res, \%warns);
}


# Function: add_building
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_building {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@building_fields) {
    my $nk = $key;		# required because $key is a reference into building_fields
    $nk =~ s/^building\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of building.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^building\.$key$/, @building_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find building.$key!\n".join(',', @building_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("building.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "building.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"building.$key"} = $$fields{$key};
  }		  
  
  $$newfields{"building.abbreviation"} = uc($$newfields{"building.abbreviation"});
  delete $$newfields{'building.activation_queue'}
    if ($$newfields{'building.activation_queue'} eq '');
 
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'building', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
  
}


# Function: add_cable
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_cable {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  $$fields{label_from} = $$fields{prefix}.$$fields{from_building}.
    $$fields{from_wing}.$$fields{from_floor}."-".$$fields{from_closet}.
      $$fields{from_rack}.$$fields{from_panel}."-".$$fields{from_x}.
	$$fields{from_y};
  if ($$fields{destination} eq 'CLOSET' || $$fields{to_closet}) {
    $$fields{label_to} = $$fields{prefix}.$$fields{to_building}.
      $$fields{to_wing}.$$fields{to_floor}."-".$$fields{to_closet}.
	$$fields{to_rack}.$$fields{to_panel}."-".$$fields{to_x}.
	  $$fields{to_y};
  } else {
    $$fields{label_to} = $$fields{prefix}.$$fields{to_building}.
      $$fields{to_wing}.$$fields{to_floor}."-".$$fields{to_floor_plan_x}.
	$$fields{to_floor_plan_y}.$$fields{to_outlet_number};
  }
  if ($$fields{label_to} =~ /^.?-*$/) {
    $$fields{label_to} = '';
  }
  
  foreach $key (@cable_fields) {
    my $nk = $key;		# required because $key is a reference into cable_fields
    $nk =~ s/^cable\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of cable.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^cable\.$key$/, @cable_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find cable.$key!\n".join(',', @cable_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("cable.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "cable.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"cable.$key"} = $$fields{$key};
  }		  
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'cable', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  return ($res);
  
}


# Function: add_outlet_type
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_outlet_type {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@outlet_type_fields) {
    my $nk = $key;		# required because $key is a reference into outlet_type_fields
    $nk =~ s/^outlet_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of outlet_type.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^outlet_type\.$key$/, @outlet_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet_type.$key!\n".join(',', @outlet_type_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet_type.$key"} = $$fields{$key};
  }		  
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'outlet_type', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('id' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
}

sub add_outlet_preconnected {
  my ($dbh, $dbuser, $ul, $fields, $prev) = @_;
  my ($key, $newfields, $mode, $force);

  {
    my $mul = CMU::Netdb::get_add_level($dbh, $dbuser, 'outlet', 0);
    if ($mul < $ul) {
      warn "Privilige escalation attempt for $dbuser\n";
      my $msg = "User $dbuser called add_outlet_preconnected with privilige\n" .
        "level $ul when they only have add level $mul\n\n";
      $msg .= Data::Dumper->Dump([$fields],['fields']);
      my $subj = "Possible Security Violation\n";
      CMU::Netdb::netdb_mail("",$msg, $subj);
      return($CMU::Netdb::errors::errcodes{'EPERM'}, [ 'add' ]);
    }
  }

  $force = 0;
  if (defined $$fields{'force'}) {
    if (($$fields{'force'} eq 'yes') && ($ul >= 9)) {
      $force = 1;
    }
    delete $$fields{'force'};
  }

  if (! $force) {
    $$fields{'attributes'} = '';
    foreach (qw/status device port cable type account/) {
      delete $$fields{$_} if (defined $$fields{$_});
    }
  }

  if ($ul < 5) {
    $$fields{'comment_lvl5'} = $$prev{'comment_lvl5'};
  }    
  
  my %nflags;
  if ($ul < 9) {
    $$fields{'comment_lvl9'} = $$prev{'comment_lvl9'};
    map { $nflags{lc($_)} = 1; } split(',', $$prev{'flags'});
  } else {
    map { $nflags{lc($_)} = 1; } split(',', $$fields{'flags'});
  }  
  # force the activated and permanent flags
  $nflags{'activated'} = 1 if (! $force);
  $nflags{'permanent'} = 1 if (! $force);
  $$fields{'flags'} = join(',', keys %nflags);
  
  ## ASSERT
  ## We know we are going to state OUTLET_PERM_WAIT_ENABLE
  ## as long as we are in OUTLET_PERM_UNACTIVATED at present.
  ## and we are not forcing the change

  # Only check the fields we have set.
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of outlet.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^outlet\.$key$/, @outlet_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet.$key!\n".join(',', @outlet_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet.$key"} = $$fields{$key};
  }		  
  
  if ($force) {
    my $nstate = CMU::Netdb::get_outlet_state($newfields);

    return ($nstate, ['flags', 'attributes', 'device', 'port', 'status']) if ($nstate < 0);
  }


  # FIXME we are doing verification ourselves that this is okay to do.
  # since we're running this as netreg, start the changelog as the real user first.
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
      $xref = shift @{$xref};
  }else{
      return ($xres, $xref);
  }
  CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  my $res = CMU::Netdb::primitives::modify($dbh, 'netreg', 'outlet', $$prev{'id'},
					   $$prev{'version'}, $newfields);
  if ($res < 1) {
    CMU::Netdb::xaction_rollback($dbh);
    return ($res, []);
  }
  my %warns;
  $warns{ID} = $$prev{'id'};
  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($res, \%warns);
}

sub add_outlet_unconnected {
  my ($dbh, $dbuser, $ul, $fields) = @_;
  my ($key, $newfields, $mode, $force);

  {
    my $mul = CMU::Netdb::get_add_level($dbh, $dbuser, 'outlet', 0);
    if ($mul < $ul) {
      warn "Privilege escalation attempt for $dbuser\n";
      my $msg = "User $dbuser called add_outlet_unconnected with privilege\n" .
        "level $ul when they only have add level $mul\n\n";
      $msg .= Data::Dumper->Dump([$fields],['fields']);
      my $subj = "Possible Security Violation\n";
      CMU::Netdb::netdb_mail("",$msg, $subj);
      return($CMU::Netdb::errors::errcodes{'EPERM'}, [ 'add' ]);
    }
  }

  $force = 0;
  if (defined $$fields{'force'}) {
    if (($$fields{'force'} eq 'yes') && ($ul >= 9)) {
      $force = 1;
    }
    delete $$fields{'force'};
  }
  if (! $force) {

    $$fields{'status'} = 'partitioned';
    $$fields{'account'} = '';
    if ($ul < 5) {
      $$fields{"comment_lvl5"} = '';
    }
    if ($ul < 9) {
      foreach (qw/comment_lvl9 device port/) {
        $$fields{$_} = '';
      }
      $$fields{'flags'} = 'activated';
    } else {

      if ($$fields{'flags'} !~ /permanent/ && $$fields{'flags'} !~ /activated/) {
        if ($$fields{flags} eq '') {
          $$fields{'flags'} = 'activated';
        } else {
          $$fields{'flags'} .= ",activated";
        }
      }
    }
  }
  if ($$fields{device} ne '' && $$fields{port} ne '') {
    $$fields{'attributes'} = '';
  } else {
    $$fields{'attributes'} = 'activate';
  }

  # verify they are really allowed to add the type they are requesting
  my $otr = CMU::Netdb::list_outlet_types_ref($dbh, $dbuser, 'GET', "outlet_type.id = '$$fields{'type'}'");
  return ($errcodes{ENOOUTTYPE}, ['type']) if (!ref $otr || !defined $$otr{$$fields{'type'}});
  
  # Verify the outlet transition state.
  { 
    my $nstate = CMU::Netdb::get_outlet_state($fields);
    
    return ($nstate, ['flags', 'attributes', 'device', 'port', 'status']) if ($nstate < 0);
    return ($errcodes{EINVTRANS}, ['flags', 'attributes', 'device', 'port', 
				   'status']) 
      if ((! $force) && (!outlet_transition_safe('OUTLET_UNLINKED', $nstate)));
  }
  
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@outlet_fields) {
    my $nk = $key;		# required because $key is a reference into outlet_fields
    $nk =~ s/^outlet\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of outlet.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^outlet\.$key$/, @outlet_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet.$key!\n".join(',', @outlet_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet.$key"} = $$fields{$key};
  }		  
 
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'outlet', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns;
  $warns{ID} = $CMU::Netdb::primitives::db_insertid;
  return($res, \%warns);
}


# Function: add_outlet
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     User level
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_outlet {
  my ($dbh, $dbuser, $ul, $fields, $perms) = @_;
  my ($key, $newfields, $mode, @outlet, %ofields, @outlet_field_short);
  my ($odev, $oport, $ovlan, $oref, $ocable, $force);

  my $mul = CMU::Netdb::get_add_level($dbh, $dbuser, 'outlet', 0);
  if ($mul < $ul) {
    warn "Privilige escalation attempt for $dbuser\n";
    my $msg = "User $dbuser called add_outlet with privilige\n" .
      "level $ul when they only have add level $mul\n\n";
    $msg .= Data::Dumper->Dump([$fields],['fields']);
    my $subj = "Possible Security Violation\n";
    CMU::Netdb::netdb_mail("",$msg, $subj);
    return($CMU::Netdb::errors::errcodes{'EPERM'}, [ 'add' ]);
  }


  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  return ($errcodes{EBLANK}, ['cable']) if ($$fields{'cable'} eq '');

  # TODO
  # Lock all relevant tables to protect against race conditions
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  $force = 0;
  if (defined $$fields{'force'}) {
    if (($$fields{'force'} eq 'yes') && ($ul >= 9)) {
      $force = 1;
    }
  }

  $odev  = $$fields{'device'};
  $oport = $$fields{'port'};
  $ocable = $$fields{'cable'};  

  if (!($odev =~ /^\d+$/s) && $odev ne '') {
    $$fields{'device'} = CMU::Netdb::valid('outlet.device_string', $$fields{'device'}, $dbuser, 0, $dbh);
    if (CMU::Netdb::getError($$fields{'device'}) != 1) {
      CMU::Netdb::xaction_rollback($dbh);
      return (CMU::Netdb::getError($$fields{'device'}), ['device']);
    }

    my $mach_rows = CMU::Netdb::list_machines($dbh, 'netreg', "machine.host_name = '$odev'");
    if ($#$mach_rows < 1) {
      CMU::Netdb::xaction_rollback($dbh);
      return (-1, ['device']);
    }
    
    my %mach_map = %{CMU::Netdb::makemap($mach_rows->[0])};
    $odev = $mach_rows->[1]->[$mach_map{'machine.id'}];
    $$fields{'device'} = $odev;
  }

  if (!($ocable =~ /^\d+$/s) && $ocable ne '') {
    #FIXME - There is no validity checker for outlet to/from strings, we will have to trust the user here
    #    $$fields{'cable'} = CMU::Netdb::valid('cable.label_from', $$fields{'cable'}, $dbuser, 0, $dbh);
    #    return (CMU::Netdb::getError($$fields{'cable'}), ['cable']) if (CMU::Netdb::getError($$fields{'cable'}) != 1);

    my $cable_rows = CMU::Netdb::list_cables($dbh, 'netreg', "cable.label_from = '$ocable'");
    if ($#$cable_rows < 1) {
      CMU::Netdb::xaction_rollback($dbh);
      return (-1, ['cable']);
    }

    my %cable_map = %{CMU::Netdb::makemap($cable_rows->[0])};
    $ocable = $cable_rows->[1]->[$cable_map{'cable.id'}];
    $$fields{'cable'} = $ocable;
  }

  if ($odev != 0) {
    my $mach_rows = CMU::Netdb::list_machines($dbh, 'netreg', "machine.id = '$odev'");
    if ($#$mach_rows < 1) {
      CMU::Netdb::xaction_rollback($dbh);
      return (-1, ['device']);
    }
  }

  if ($odev != 0 && $oport != 0) {
    $oref = CMU::Netdb::list_outlets($dbh, $dbuser, "outlet.device = '$odev' AND ".
				     " outlet.port = '$oport'");
    if ($#$oref > 0) {
      CMU::Netdb::xaction_rollback($dbh);
      return ($errcodes{EDEVPORTEXIST}, ['device' , 'port'] );
    }

  }

  # check device/trunkset/vlan integrity and make sure that
  # we are not associate device with trunkset which is not associated with
  # this device. Also make sure that we are not creating outlet_vlan_membership
  # entry, if vlan does not exist on this device.
  if ($odev != 0 && $odev ne '') {
    my ($cret, $cref) = check_dev_outlet($dbh, $dbuser, $fields) ;
    if ($cret < 1){
      CMU::Netdb::xaction_rollback($dbh);
      return ($cret, $cref);
    }
    $$fields{'device'} = $cref->[0];
    $odev = $$fields{'device'};
  }
  
  $ovlan = $$fields{'vlan'}; delete $$fields{'vlan'};

  my $orig = CMU::Netdb::list_outlets($dbh, 'netreg', "outlet.cable = '$$fields{'cable'}'");
  if ((!ref $orig) or ($#{$orig} > 1)){
    CMU::Netdb::xaction_rollback($dbh);
    return ($orig, ['cable']);
  }
  $mode = 0;
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "ORIG:: ".$#{$orig}."\n" if ($debug >= 2);
  if ($#{$orig} > 0) {
    foreach (@outlet_fields) {
      my $nk = $_;
      $nk =~ s/^outlet\.//;
      push(@outlet_field_short, $nk);
    }
    {
      my $i = 0;
      map { $ofields{$_} = $ {$$orig[1]}[$i++] } @outlet_field_short;
    }
    
    map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } @outlet_field_short;
    if ($ofields{'flags'} =~ /activated/i) { 
      CMU::Netdb::xaction_rollback($dbh);
      return ($errcodes{EEXISTS}, ['cable']);
    }
    unless ($ofields{'flags'} =~ /permanent/i) {
      CMU::Netdb::xaction_rollback($dbh);
      return ($errcodes{EEXISTS}, ['cable']);
    }
    $mode = 1;
  }
  
  my $dept = $$fields{'dept'};
  delete $$fields{'dept'};
  
  if ($dept eq '') {
    CMU::Netdb::xaction_rollback($dbh);
    return ($errcodes{EBLANK}, ['dept']);
  }
  my $depts = CMU::Netdb::get_departments($dbh, $dbuser, " groups.name = '$dept'", 'ALL', '', 'groups.id');
  if (!ref $depts || !defined $$depts{$dept}) {
    CMU::Netdb::xaction_rollback($dbh);
    return ($errcodes{EPERM}, ['dept']);
  }
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "MODE:: $mode\n" if ($debug >= 2);
  my ($res, $ref);
  ($res, $ref) = 
    add_outlet_preconnected($dbh, $dbuser, $ul, $fields, \%ofields) if ($mode);
  ($res, $ref) = 
    add_outlet_unconnected($dbh, $dbuser, $ul, $fields) if (!$mode);
  
  return ($res, $ref) if ($res < 1);
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "ID:: $$ref{ID}\n" if ($debug >= 2);
  # permissions
  my $success = 0;
  $success++ if ($force);
  my $addret;
  ($addret) = CMU::Netdb::add_group_to_protections($dbh, $dbuser, $dept, 'outlet',
						   $$ref{ID}, 'READ,WRITE', 
						   5, 'RUBIKS_CUBE'); #FIXME level 5 should come from template
  $$ref{$dept} = $errmeanings{$addret} if ($addret < 1);
  warn __FILE__, ':', __LINE__, ' :>'.
    $errmeanings{$addret} if ($addret < 1);
  if ($addret >= 1) {
    my $dadmin = CMU::Netdb::list_members_of_group($dbh, 'netreg', $dept, 
						   "credentials.authid = '$dbuser'");
    $success++ if (ref $dadmin && defined $dadmin->[1]);
    foreach my $k (keys %{$perms}) {
      if ($k =~ /\:/) {
	# group
	warn __FILE__, ':', __LINE__, ' :>'.
	  "Adding group $k : $perms->{$k}->[0] / $perms->{$k}->[1] ";
	($addret) = CMU::Netdb::add_group_to_protections($dbh, $dbuser, $k, 'outlet', 
							 $$ref{ID}, $perms->{$k}->[0],
							 $perms->{$k}->[1], 'RUBIKS_CUBE');
	
	$success++ if ($addret >= 1);
	$$ref{$k} = $errmeanings{$addret} if ($addret < 1);
	warn __FILE__, ':', __LINE__, ' :>'.
	  $errmeanings{$addret} if ($addret < 1);
      } else {
	# user
	warn __FILE__, ':', __LINE__, ' :>'.
	  "Adding user $k : $perms->{$k}->[0] / $perms->{$k}->[1]" if ($debug >= 2);
	($addret) = CMU::Netdb::add_user_to_protections($dbh, $dbuser, $k, 'outlet', 
							$$ref{ID}, $perms->{$k}->[0],
							$perms->{$k}->[1], 'RUBIKS_CUBE');
	$success++ if ($addret >= 1);
	$$ref{$k} = $errmeanings{$addret} if ($addret < 1);
	warn __FILE__, ':', __LINE__, ' :>'.
	  $errmeanings{$addret} if ($addret < 1);
      }
    }
  }
  # in this case, we need to rollback the outlet and tell the user
  if ($success < 1) {
    CMU::Netdb::xaction_rollback($dbh);
    return (0, ['protections'])
  }

  # Here, take care about outlet_vlan_membership, if vlan exist...
  # At this point we assume that we have added row in outlet table, with
  # or without device though. So if vlan and device both exist then create
  # and entry in outlet_vlan_membership, otherwise silently return...
  if (defined $ovlan && $ovlan ne '' && (($odev != 0 ) || $force)) {
    unless ($ovlan =~ /^\d+$/s) {
      CMU::Netdb::xaction_rollback($dbh);
      return (-14, ['vlan']);
    }
    my $vref = CMU::Netdb::list_vlans($dbh, $dbuser, "vlan.id = '$ovlan'");
    if (!ref $vref || $#$vref == 0) {
      CMU::Netdb::xaction_rollback($dbh);
      return (-1, ['vlan']);
    }
      
    my %vfields = ('outlet' => $$ref{ID},
		   'vlan' => $ovlan,
		   'type' => 'primary',
		   'trunk_type' => 'none',
		   'status' => 'request');
    my ($vres, $vvref) = CMU::Netdb::add_outlet_vlan_membership($dbh, $dbuser, \%vfields);
    if ($vres != 1) {
      $$ref{VERROR} = $vvref;
      CMU::Netdb::xaction_rollback($dbh);
      return ($vres, $vvref);
    }
    $$ref{VID} = $$vvref{insertID} if ($vres == 1);
  }

  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($res, $ref);
}

sub get_outlet_version {
  my ($dbh, $dbuser, $where) = @_;
  my ($ml, $i, $vf);
  
  $ml = CMU::Netdb::list_outlets($dbh, $dbuser, $where);
  return -1 if (!ref $ml);
  $i = 0;
  foreach (@{$ml->[0]}) {
    $vf = $i if ($_ eq 'outlet.version');
    $i++;
  }
  return ${$ml->[1]}[$vf];
}

# Function: modify_activation_queue
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
sub modify_activation_queue {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('activation_queue.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('activation_queue.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@activation_q_fields) {
    my $nk = $key;		# required because $key is a reference into activation_q_fields
    $nk =~ s/^activation_queue\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^activation_queue\.$key$/, @activation_q_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find activation_queue.$key!\n".join(',', @activation_q_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("activation_queue.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "activation_queue.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"activation_queue.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'activation_queue', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM activation_queue WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_activation_queue: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_activation_queue: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result);
}

# Function: modify_building
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
sub modify_building {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields, @build_f_short, %ofields, $orig);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('building.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['building.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('building.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['building.version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = CMU::Netdb::list_buildings($dbh, $dbuser, "building.id='$id'");
  return ($orig, ['id']) if (!ref $orig || !defined $orig->[1]);
  
  %ofields = ();
  foreach (@building_fields) {
    my $nk = $_;
    $nk =~ s/^building\.//;
    push(@build_f_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = ${$$orig[1]}[$i++] } @build_f_short;
  }
  map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } @build_f_short;

  ## bidirectional verification of the fields that the user is trying to add

  foreach $key (@building_fields) {
    my $nk = $key;		# required because $key is a reference into building_fields
    $nk =~ s/^building\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }

  foreach $key (keys %$fields) {
    if (! grep /^building\.$key$/, @building_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find building.$key!\n".join(',', @building_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
  
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("building.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "building.$key: $$fields{$key}\n" if ($debug >= 2);
  
    $$newfields{"building.$key"} = $$fields{$key};
  }

  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'building', $id, $version, $newfields);

  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM building WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_building: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_building: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  return ($result);
}


# Function: modify_cable
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
sub modify_cable {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields, @cable_field_short, %ofields, $orig);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('cable.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['cable.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('cable.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['cable.version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = CMU::Netdb::list_cables($dbh, $dbuser, "cable.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@cable_fields) {
    my $nk = $_;
    $nk =~ s/^cable\.//;
    push(@cable_field_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ { $$orig[1]}[$i++] } @cable_field_short;
  }
  
  map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } 
    @cable_field_short;
  
  return ($errcodes{ESTALE}, ['stale']) if ($version != $ofields{'version'});
  
  ## bidirectional verification of the fields that the user is trying to add
  $$fields{label_from} = $$fields{prefix}.$$fields{from_building}.
    $$fields{from_wing}.$$fields{from_floor}."-".$$fields{from_closet}.
      $$fields{from_rack}.$$fields{from_panel}."-".$$fields{from_x}.
	$$fields{from_y};
  if ($$fields{destination} eq 'CLOSET' || $$fields{to_closet}) {
    $$fields{label_to} = $$fields{prefix}.$$fields{to_building}.
      $$fields{to_wing}.$$fields{to_floor}."-".$$fields{to_closet}.
	$$fields{to_rack}.$$fields{to_panel}."-".$$fields{to_x}.
	  $$fields{to_y};
  } else {
    $$fields{label_to} = $$fields{prefix}.$$fields{to_building}.
      $$fields{to_wing}.$$fields{to_floor}."-".$$fields{to_floor_plan_x}.
	$$fields{to_floor_plan_y}.$$fields{to_outlet_number};
  }
  if ($$fields{label_to} =~ /^.?-*$/) {
    $$fields{label_to} = '';
  }
  
  foreach $key (@cable_fields) {
    my $nk = $key;		# required because $key is a reference into cable_fields
    $nk =~ s/^cable\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of cable.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^cable\.$key$/, @cable_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find cable.$key!\n".join(',', @cable_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("cable.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "cable.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"cable.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'cable', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM cable WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_cable: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_cable: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result);
  
}


# Function: modify_outlet_type
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
sub modify_outlet_type {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['outlet_type.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['outlet_type.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@outlet_type_fields) {
    my $nk = $key;		# required because $key is a reference into outlet_type_fields
    $nk =~ s/^outlet_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of outlet_type.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^outlet_type\.$key$/, @outlet_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet_type.$key!\n".join(',', @outlet_type_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet_type.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'outlet_type', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM outlet_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_outlet_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_outlet_type: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result);
  
}

sub check_devport_mapping {
  my ($dbh, $user, $aRef) = @_;

  return (1,[]) if ($aRef->{'userlevel'} < 9  && $aRef->{'qt'} eq '');

  return (1,[]) if ($aRef->{'oldDevice'} == $aRef->{'newDevice'});

  my $oref = CMU::Netdb::list_outlets($dbh, $user, "outlet.device = $aRef->{'newDevice'} AND ".
				      " outlet.port = $aRef->{'newPort'}");
  return ($errcodes{EDEVPORTEXIST},['device','port']) if ($#$oref > 0);

  return (1,[]);
}

sub check_devnet_mapping {
  my ($dbh, $user, $aRef) = @_;
  my ($tref, %trunkset, @ts, $dref, %devs_local, @devArr);
    
  return (1,[]) if ($aRef->{'userlevel'} < 9  && $aRef->{'qt'} eq '');

  return (1,[]) if ($aRef->{'oldDevice'} == $aRef->{'newDevice'});

  $tref = CMU::Netdb::list_vlan_trunkset_presence($dbh, $user, 
						  "trunkset_vlan_presence.vlan = '$aRef->{'newVlan'}'");
  if (ref $tref) {
    map { push (@ts, $_) } keys %$tref;
    foreach my $ts_id (@ts) {
      $dref = CMU::Netdb::list_trunkset_device_presence($dbh, $user,
							"trunkset_machine_presence.trunk_set = '$ts_id'");
      map { push (@devArr, $_) } keys %$dref if (ref $dref);
    }

    return ($errcodes{EDEVNETMISMATCH}, ['device','network-segment']) if (!grep/^$aRef->{'newDevice'}$/, @devArr);
  }
  return (1,[]);
}

sub check_dev_outlet {
  my ($dbh, $user, $fields) = @_;
    
  my ($build_num,$bref, @bdata, $bmap, $bID, $cref, @cdata, $cmap);
  my ($dref, %devs_local, @devArr, $devID, $tref, @ts, $vref, %vlan_local, @vlanArr, $vID);
  my ($cable , @devVlanArr, $oref, $omap, @odata, $otsmach, $ts_mach_row, $ts_mach_map);

  $devID	= $$fields{'device'};
  $vID	= $$fields{'vlan'};
    
  if ($$fields{'cable'} eq '') {
    $oref 	= CMU::Netdb::list_outlets($dbh, $user, "outlet.id = '$$fields{'id'}'");
    return ($oref, ['outlet']) if (!ref($oref));
    $omap	= CMU::Netdb::makemap($oref->[0]);
    $cable  = $oref->[1]->[$omap->{'outlet.cable'}];
  } else {
    $cable  = $$fields{'cable'};
  }

  $cref 	= CMU::Netdb::list_cables($dbh, $user, "cable.id = '$cable'");
  return ($cref, ['cable']) if (!ref($cref));
  $cmap	= CMU::Netdb::makemap($cref->[0]);
  @cdata	= @{$cref->[1]};

  $build_num	= ($cdata[$cmap->{'cable.to_building'}] ne '' ? $cdata[$cmap->{'cable.to_building'}]:$cdata[$cmap->{'cable.from_building'}]);
  $bref 	= CMU::Netdb::list_buildings($dbh, $user, "building.building = '$build_num'");
  return ($bref, ['building']) if (!ref($bref));
  $bmap	= CMU::Netdb::makemap($bref->[0]);
  @bdata	= @{$bref->[1]};
  $bID	= $bdata[$bmap->{'building.id'}];

  $tref 	= CMU::Netdb::list_trunkset_building_presence($dbh, $user, "trunkset_building_presence.buildings = '$bID'");
  return ($errcodes{ERROR} ,['device', 'trunk set']) if (!ref $tref);

  @ts 	= keys %$tref;
  foreach my $ts_id (@ts) {
    $dref 	= CMU::Netdb::list_trunkset_device_presence($dbh, $user, 
							    "trunkset_machine_presence.trunk_set = '$ts_id'");
    if (ref $dref) {
      map {$devs_local{$_} = $dref->{$_} } keys %$dref;
    }
  }

  @devArr 	= keys %devs_local;
  return ($errcodes{EDEVTRUNKSETMISMATCH}, ['device','trunk set']) if (!grep/^$devID$/,@devArr);

  if (defined $vID && $vID ne '') {
    $tref	= CMU::Netdb::list_vlan_trunkset_presence($dbh, $user, 
							  "trunkset_vlan_presence.vlan = '$vID'");
    return ($errcodes{ERROR}, ['vlan','trunk set']) if (!ref($tref));
    @ts 	= ();
    @ts	= keys %$tref;
    foreach my $tID (@ts) {
      $dref = CMU::Netdb::list_trunkset_device_presence($dbh, $user, 
							"trunkset_machine_presence.trunk_set = '$tID'");
      map {push (@devVlanArr, $_) } keys %$dref if (ref $dref);
    }
    return ($errcodes{EDEVNETMISMATCH} , ['vlan', 'device', 'trunk set']) if (!grep /^$devID$/, @devVlanArr);
  } else {
    return ($errcodes{ERROR}, ['vlan', 'outlet']);
  }

  # Figure out trunkset_machine_presence.id from given device
  $ts_mach_row = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'machine',
						     "trunkset_machine_presence.device = '$devID'");
  $ts_mach_map = CMU::Netdb::makemap($ts_mach_row->[0]);
  return ($errcodes{EDEVTRUNKSETMISMATCH}, ['device','trunk set']) if ($#$ts_mach_row == 0);

  shift (@$ts_mach_row);
  $otsmach = 0;
  if ($#$ts_mach_row > 0) {
    foreach my $tr (@$ts_mach_row) {
      my $tID = $tr->[$ts_mach_map->{'trunkset_machine_presence.trunk_set'}];
      my $tsvlanref = CMU::Netdb::list_trunkset_vlan_presence($dbh, 'netreg',
							      "trunkset_vlan_presence.trunk_set = '$tID'");
      if (defined $tsvlanref->{$vID}) {
	$otsmach = $tr->[$ts_mach_map->{'trunkset_machine_presence.id'}];
	last;
      }
    }
  } else {
    $otsmach = $ts_mach_row->[0]->[$ts_mach_map->{'trunkset_machine_presence.id'}];
  }

  return ($errcodes{ERROR}, ['device','trunkset device','vlan']) if ($otsmach == 0);
    
  return (1,[$otsmach]);
}

sub update_primaryvlan  {
  my ($dbh, $user, $aRef) = @_;
  my ($primaryvlan);

  return (1,[]) if (($aRef->{'oldDevice'} == $aRef->{'newDevice'})
		    && ($aRef->{'oldVlan'} == $aRef->{'newVlan'}));

  $primaryvlan = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user,
							  "outlet_vlan_membership.outlet = '$aRef->{'id'}' AND ".
							  "outlet_vlan_membership.type = 'primary'");
  if (ref $primaryvlan && $#$primaryvlan > 0) {
    my $ovlan_map = CMU::Netdb::makemap($primaryvlan->[0]);
    shift @$primaryvlan;
    my %psfields;
    $psfields{'outlet'} = $aRef->{'id'};
    if ($aRef->{'oldVlan'} == $aRef->{'newVlan'}) {
      $psfields{'vlan'} 	= $primaryvlan->[0]->[$ovlan_map->{'outlet_vlan_membership.vlan'}];
    } else {
      $psfields{'vlan'} 	= $aRef->{'newVlan'};
    }
    $psfields{'type'} 	= 'primary';
    $psfields{'status'} = 'request';
    $psfields{'trunk_type'} = 'none';
    my $smid = $primaryvlan->[0]->[$ovlan_map->{'outlet_vlan_membership.id'}];
    my $sver = $primaryvlan->[0]->[$ovlan_map->{'outlet_vlan_membership.version'}];
      
    warn __FILE__." : ".__LINE__.
      "> update_primaryvlan-- vlan=$primaryvlan->[0]->[$ovlan_map->{'outlet_vlan_membership.vlan'}] \n" if ($debug);
    my ($res, $ref) = CMU::Netdb::modify_outlet_vlan_membership($dbh, $user, $smid, $sver, \%psfields);
    return ($res, $ref) if ($res < 1);
  } else {
    my %psfields;
    $psfields{'outlet'} = $aRef->{'id'};
    $psfields{'vlan'} = $aRef->{'newVlan'};
    $psfields{'type'} = 'primary';
    $psfields{'trunk_type'} = 'none';
    $psfields{'status'} = 'request';
    my ($res, $ref) = CMU::Netdb::add_outlet_vlan_membership($dbh, $user, \%psfields);
    return ($res, $ref) if ($res < 1);
  }

  return (1,[]);
}


sub update_auxvlan {
  my ($dbh, $user, $aRef) = @_;
  my ($tref, %trunkset, @ts, $vref, @vArr, $secvlan);
    
  return (1,[]) if ($aRef->{'userlevel'} < 9  && $aRef->{'qt'} eq '');
  return (1,[]) if ($aRef->{'oldDevice'} == $aRef->{'newDevice'});

  $tref = CMU::Netdb::list_device_trunkset_presence($dbh, $user, 
						    "trunkset_machine_presence.device = '$aRef->{'newDevice'}'");

  if (ref $tref) {
    foreach my $ts_id (keys %$tref) {
      $vref = CMU::Netdb::list_trunkset_vlan_presence($dbh, $user,
						      "trunkset_vlan_presence.trunk_set = '$ts_id'");
      map { push (@vArr, $_) } keys %$vref if (ref $vref);
    }

    # Get outlet_vlan_membership , but not primary
    $secvlan = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user,
							"outlet_vlan_membership.outlet = '$aRef->{'id'}' AND ".
							"outlet_vlan_membership.type != 'primary'");
    if (ref $secvlan && $#$secvlan > 0) {
      my $ovlan_map = CMU::Netdb::makemap($secvlan->[0]);
      shift @$secvlan;

      foreach my $svlan (@$secvlan) {
	if (!grep/^$svlan->[$ovlan_map->{'outlet_vlan_membership.vlan'}]$/,@vArr) {
	  my %psfields;
	  $psfields{'outlet'} = $aRef->{'id'};
	  $psfields{'vlan'} 	= $svlan->[$ovlan_map->{'outlet_vlan_membership.vlan'}];
	  $psfields{'type'} 	= $svlan->[$ovlan_map->{'outlet_vlan_membership.type'}];
	  $psfields{'status'} = 'delete';
	  $psfields{'trunk_type'} = $svlan->[$ovlan_map->{'outlet_vlan_membership.trunk_type'}];
	  my $smid = $svlan->[$ovlan_map->{'outlet_vlan_membership.id'}];
	  my $sver = $svlan->[$ovlan_map->{'outlet_vlan_membership.version'}];

	  warn __FILE__." : ".__LINE__.
	    "> update_auxvlan-- vlan=$svlan->[$ovlan_map->{'outlet_vlan_membership.vlan'}] \n" if ($debug);
	  my ($res, $ref) = CMU::Netdb::modify_outlet_vlan_membership($dbh, $user, $smid, $sver, \%psfields);
	  return ($res, $ref) if ($res < 1);
	}
      }
    }
  }

  return (1,[]);
}

# Function: expire_outlet
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
sub expire_outlet {
  my ($dbh, $dbuser, $id, $version, $expires) = @_;

  $dbuser = valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (getError($dbuser), ['dbuser']) if (getError($dbuser) != 1);

  $id = valid('outlet.id', $id, $dbuser, 0, $dbh);
  return (getError($id), ['id']) if (getError($id) != 1);

  $version = valid('outlet.version', $version, $dbuser, 0, $dbh);
  return (getError($version), ['version']) if (getError($version) != 1);

  my $ul = get_write_level($dbh, $dbuser, 'outlet', $id);
  return ($errcodes{EPERM}, ['perm']) if ($ul < 9);


  my %newfields;
  $newfields{'outlet.expires'} = valid('outlet.expires', $expires, $dbuser, 0, $dbh);

  return (getError($newfields{'outlet.expires'}), ['expires'])
    if (getError($newfields{'outlet.expires'}) != 1);

  my $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'outlet', $id, $version, \%newfields);
  return ($errcodes{"ERROR"}, ['unknown']) if ($result != 1);

  return ($result, []);
}


# Function: modify_outlet
# Arguments: 6:
#     An already connected database handle
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
#     Userlevel (1 or 9)
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_outlet {
  my ($dbh, $dbuser, $id, $version, $fields, $ul) = @_;
  my ($key, $result, $query, $sth, $newfields, @outlet_field_short, %ofields, $dept);
  my ($primaryvlan, $oldvlan, $odev, $oport, $oref, $force);
  
  {
    my $mul = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', $id);
    if ($mul < $ul) {
      warn "Privilige escalation attempt for $dbuser\n";
      my $msg = "User $dbuser called modify_outlet with privilige\n" .
        "level $ul when they only have write level $mul\n\n";
      $msg .= Data::Dumper->Dump([$fields],['fields']);
      my $subj = "Possible Security Violation\n";
      CMU::Netdb::netdb_mail("",$msg, $subj);
      return($CMU::Netdb::errors::errcodes{'EPERM'}, [ 'modify' ]);
    }
  }

  $force = 0;
  if (defined $$fields{'force'}) {
    if (($$fields{'force'} eq 'yes') && (CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', $id) >= 9)) {
      $force = 1;
    }
    delete $$fields{'force'};
  }

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['outlet.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['outlet.version']) if (CMU::Netdb::getError($version) != 1);

  # Getting primaryvlan and oldvlan. and then delete those from $$field
  #NR-VLAN
  $primaryvlan 	= $$fields{'##primaryvlan--'}; delete $$fields{'##primaryvlan--'};
  $oldvlan	= $$fields{'##oldvlan--'}; delete $$fields{'##oldvlan--'};

  $odev = $$fields{'device'};
  $oport = $$fields{'port'};

  if (!($odev =~ /^\d+$/s) && $odev ne '') {
    $$fields{'device'} = CMU::Netdb::valid('outlet.device_string', $$fields{'device'}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{'device'}), ['device']) if (CMU::Netdb::getError($$fields{'device'}) != 1);

    my $mach_rows = CMU::Netdb::list_machines($dbh, 'netreg', "machine.host_name = '$odev'");
    return (-1, ['device']) if ($#$mach_rows < 1);
    
    my %mach_map = %{CMU::Netdb::makemap($mach_rows->[0])};
    $odev = $mach_rows->[1]->[$mach_map{'machine.id'}];
    $$fields{'device'} = $odev;
  }


  # check device/trunkset/vlan integrity and make sure that
  # we are not associate device with trunkset which is not associated with
  # this device. Also make sure that we are not creating outlet_vlan_membership
  # entry, if vlan does not exist on this device.
  if (defined $odev) {
    if ($odev != 0 && $odev ne '') {
      $$fields{'vlan'} = $primaryvlan if ($primaryvlan ne '');
      $$fields{'id'} = $id;
      my ($cret, $cref) = check_dev_outlet($dbh, $dbuser, $fields);
      return ($cret, $cref) if ($cret < 1);
      
      $$fields{'device'} = $cref->[0];
      $odev = $$fields{'device'};
      delete $$fields{'vlan'};
      delete $$fields{'id'};
      
      # Check uniqeness of <dev,port> tuple
      if ($oport != 0) {
	$oref = CMU::Netdb::list_outlets($dbh, $dbuser, "outlet.device = $odev AND ".
					 " outlet.port = $oport AND outlet.attributes != 'change'");
	
	return ($errcodes{EDEVPORTEXIST}, ['device' , 'port'] )
	  if ($#$oref > 0 && $primaryvlan eq '' && $oldvlan eq '');
      }
    } else {
      $oport = 0;
      $$fields{'port'} = 0;
    }
  } else {
    undef $$fields{'port'};
  }

  $dept = $$fields{'dept'};
  delete $$fields{'dept'};
  my $depts;
  if ($dept ne '') {
    $depts = CMU::Netdb::get_departments($dbh, $dbuser, " groups.name = '$dept'", 'ALL', '', 'groups.id', 'GET');
    return ($errcodes{EPERM}, ['dept']) if (!ref $depts || !defined $$depts{$dept});
  }
  
  my $orig = CMU::Netdb::list_outlets($dbh, $dbuser, "outlet.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@outlet_fields) {
    my $nk = $_;
    $nk =~ s/^outlet\.//;
    push(@outlet_field_short, $nk);
  }

  {
    my $i = 0;
    map { $ofields{$_} = $ {$$orig[1]}[$i++] } @outlet_field_short;
  }
  map { $$fields{$_} = $ofields{$_} } qw/account comment_lvl9 status device port/ 
    if ($ul < 9);
  $$fields{comment_lvl5} = $ofields{comment_lvl5} if ($ul < 5);
  
  map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } 
    @outlet_field_short;

  # Deciding 'attributes', as well as next_state based on device,vlan,trunk_set
  # NR-VLAN
  my $listUser  = 'netreg';
  my $devID 	= $$fields{device};
  my $ts_rows 	= CMU::Netdb::list_device_trunkset_presence($dbh, $dbuser, 
							    "trunkset_machine_presence.id = $devID");
  my %trunkset  = %$ts_rows;
  my @tsID	= sort { $trunkset{$a} cmp $trunkset{$b} } keys %trunkset;
  my @vlanID;
  foreach my $tid (@tsID) {
    my $vlan_rows = CMU::Netdb::list_trunkset_vlan_presence($dbh, $dbuser, 
							    "trunkset_vlan_presence.trunk_set = \'$tid\'");
    my (%vlan_local, @vlans);
    if (ref $vlan_rows) {
      %vlan_local = %$vlan_rows;
      @vlans = sort { $vlan_local{$a} cmp $vlan_local{$b} } keys %vlan_local;
      map { push @vlanID, $_ } keys %vlan_local;
    }
  }

  $$fields{attributes} 	= 'change' if ($oldvlan ne '' && (!grep /^$primaryvlan$/, @vlanID));
  $$fields{status} 	= 'partitioned' if ( (!grep /^$primaryvlan$/, @vlanID) && 
					     $$fields{attributes} eq 'change'); 

  if ($ul < 9) {
    my (%nflags, %oflags);
    map { $nflags{$_} = 1 } split(/\,/, $$fields{flags});
    map { $oflags{$_} = 1 } split(/\,/, $ofields{flags});
    map { $nflags{$_} = 0 if (!defined $nflags{$_}); 
	  $oflags{$_} = 0 if (!defined $oflags{$_}) } 
      @CMU::Netdb::structure::outlet_flags;
    map { $nflags{$_} = $oflags{$_} } qw/abuse suspend permanent/;
    my @newflags;
    map { push(@newflags, $_) if ($nflags{$_}) } @CMU::Netdb::structure::outlet_flags;
    warn __FILE__, ':', __LINE__, ' :>'.
      "SET_2: ". join(',', @newflags)."\n" if ($debug >= 2);
    $$fields{flags} = join(',', @newflags);
  }
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "FLAGS: $$fields{flags}" if ($debug >= 2);;
  return ($errcodes{ESTALE}, ['stale']) if ($version != $ofields{'version'});
  
  if ($$fields{attributes} eq 'deactivate') {
    my @flags = split(/\,/, $$fields{flags});
    @flags = grep(!/^activated$/, @flags);
    $$fields{attributes} = '' if (grep/^permanent$/, @flags);
    $$fields{flags} = join(',', @flags);
  }

  # Verify the outlet transition state.
  my $ostate = CMU::Netdb::get_outlet_state(\%ofields);
  my $nstate = CMU::Netdb::get_outlet_state($fields);

  warn __FILE__, ':', __LINE__, " :> New outlet state $nstate.  Old outlet state $ostate\n" 
    if ($debug >= 2);

  warn __FILE__, ':', __LINE__, " :> ", Data::Dumper->Dump([\%ofields, $fields],['old-fields', 'new-fields'])
    if ($debug >= 3);

  return ($ostate, ['flags', 'attributes', 'device', 'port', 'status', 'ostate']) if ($ostate < 0 && $ul < 9);
  return ($nstate, ['flags', 'attributes', 'device', 'port', 'status', 'nstate']) if ($nstate < 0);
  unless (($ul >= 9) && ($force == 1)) {
    return ($errcodes{EINVTRANS}, ['flags', 'attributes', 'device', 'port', 
				   'status']) 
      if (!outlet_transition_safe($ostate, $nstate));
  }
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@outlet_fields) {
    my $nk = $key;		# required ebcause $key is a reference into outlet_fields
    $nk =~ s/^outlet\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of outlet.$key.. Stand by\n" if ($debug >= 4);
    if (! grep /^outlet\.$key$/, @outlet_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet.$key!\n".join(',', @outlet_fields) if ($debug >= 4);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 4);
    $$fields{$key} = CMU::Netdb::valid("outlet.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet.$key: $$fields{$key}\n" if ($debug >= 4);
    
    $$newfields{"outlet.$key"} = $$fields{$key};
  }
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  warn  __FILE__, ':', __LINE__, " :> Updating outlet $id:\n" 
    . Data::Dumper->Dump([$newfields],['fields']) if ($debug >= 3);
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'outlet', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM outlet WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_outlet: $query\n" if ($debug >= 2);
    $sth->execute();
    CMU::Netdb::xaction_rollback($dbh);
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_outlet: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }

  if ($nstate eq 'OUTLET_PERM_UNACTIVATED') {
    $query =<<END_DELETE;
DELETE FROM protections WHERE protections.tname = 'outlet' AND 
  protections.tid = '$id'
END_DELETE
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_outlet - query: $query\n" if ($debug >= 2);
    $dbh->do($query);
  }
  
  my %warns;
  # update department
  warn __FILE__, ':', __LINE__, ' :>'.
    "DEPT 2: $dept\n" if ($debug >= 2);
  if ($dept ne '') {
    my @locks = (
		 "_sys_changelog",
		 "_sys_changerec_col",
		 "_sys_changerec_row",
		 "groups",
		 "outlet",
		 "protections",
		 "users"
		);
    my ($lockres, $lockref) = CMU::Netdb::lock_tables($dbh, \@locks);
    unless($lockres == 1){
      CMU::Netdb::xaction_rollback($dbh);
      return ($errcodes{"EDB"}, $lockref);
    }

    $query =<<END_SELECT;
SELECT protections.id
  FROM protections, outlet, groups
 WHERE protections.tid = outlet.id
   AND protections.tname = 'outlet'
   AND outlet.id = '$id'
   AND groups.id = -1*protections.identity
   AND groups.name like 'dept:%'
END_SELECT
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::buildings_cables::modify_outlet:: Query: $query\n" if ($debug >= 2);
    my $sth = $dbh->prepare($query);
    my $res = $sth->execute();
    if (!$res) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::buildings_cables::modify_outlet:: Unknown error\n$DBI::errstr\n" if ($debug);
      # FIXME send mail
      $warns{dept} = 'DBI failure';
      CMU::Netdb::xaction_rollback($dbh);
      return ($result, \%warns);
    }    
    my @row = $sth->fetchrow_array();
    my $nres;
    if (!@row || $row[0] eq '') {
      ($nres) = CMU::Netdb::add_group_to_protections($dbh, $dbuser, $dept, 'outlet',
						     $id, 'READ,WRITE', 5, 'RUBIKS_CUBE'); #FIXME use template
    } else {
      # since we're about to update a db row directly, we have to do logging here
      # first create the changelog entry
      my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
      if ($log) {
	# Now create the changelog row record
	my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $row[0], 'UPDATE');
	if ($rowrec) {
	  # Now create the column entry (only changing one column)
	  CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 'identity', -1*$$depts{$dept}, ['identity', 'protections', "id = '$row[0]'"]);
	}
      }
      $nres = $dbh->do("UPDATE protections SET identity = -1*$$depts{$dept} WHERE id = '$row[0]'");
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::buildings_cables::modify_outlet:: Query: UPDATE protections SET identity = -1*$$depts{$dept} WHERE id = '$row[0]'" if ($debug >= 2);
    }
    if ($nres != 1) {
      $warns{dept} = 'DBI Failure';
      CMU::Netdb::xaction_rollback($dbh);
      return ($result, \%warns);
    }
  }

  warn "Old Vlan $oldvlan, New Vlan $primaryvlan\n" if ($debug);
  my ($vlres, $vlref) = update_primaryvlan($dbh, $dbuser, {'id' => $id, 'newDevice' => '1', 'oldDevice' => '0', 'oldVlan' => $oldvlan, 'newVlan' => $primaryvlan});
  if ($vlres <= 0) {
    CMU::Netdb::xaction_rollback($dbh);
    return ($errcodes{"EPARTIAL"}, ['outlet_vlan_membership', $vlres, @$vlref]);
  }
  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($result, \%warns);
}

# Function: delete_activation_queue
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_activation_queue {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('activation_queue.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('activation_queue.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'activation_queue', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM activation_queue WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_activation_queue: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_activation_queue: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result);
}

# Function: delete_building
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_building {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['name']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('building.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('building.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'building', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM building WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_building: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_building: id/version were stale\n"
	  if ($debug);
      return ($errcodes{"ESTALE"}, ['db']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result);
}

# Function: delete_cable
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_cable {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('cable.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['cable.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('cable.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['cable.version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'cable', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM cable WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_cable: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_cable: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result);
}


# Function: delete_outlet_type
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_outlet_type {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['outlet_type.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['outlet_type.version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'outlet_type', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM outlet_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_outlet_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_outlet_type: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result);
  
}


# Function: delete_outlet
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_outlet {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, @outlet_field_short, %ofields, $dref);
  my ($wl) = get_write_level($dbh, $dbuser, 'outlet', $id);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  my $orig = CMU::Netdb::list_outlets($dbh, $dbuser, "outlet.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@outlet_fields) {
    my $nk = $_;
    $nk =~ s/^outlet\.//;
    push(@outlet_field_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ {$$orig[1]}[$i++] } @outlet_field_short;
  }
  if ($wl < 9) { 
    my $state = CMU::Netdb::get_outlet_state(\%ofields);
    return ($state, ['flags', 'attributes', 'device', 'port', 'status']) if ($state < 0);
    return ($errcodes{EINVTRANS}, ['flags', 'attributes', 'device', 'port', 
				   'status']) 
      if (!outlet_transition_safe($state, 'OUTLET_UNLINKED'));
  }
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'outlet', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM outlet WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_outlet: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_outlet: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  my $result2 = CMU::Netdb::delete_protection_tid($dbh, $dbuser, 'outlet', $id);
  # FIXME error checking here
  return ($result);
  
}

## returns the outlet state
my @outlet_states = 
  qw/OUTLET_UNLINKED 
     OUTLET_WAIT_ACTIVATION
     OUTLET_WAIT_ENABLE
     OUTLET_ACTIVE
     OUTLET_WAIT_PARTITION
     OUTLET_WAIT_DEACTIVATION
     OUTLET_WAIT_CHANGE
  
     OUTLET_PERM_UNACTIVATED
     OUTLET_PERM_WAIT_ENABLE
     OUTLET_PERM_WAIT_CHANGE
     OUTLET_PERM_ACTIVE
     OUTLET_PERM_WAIT_PARTITION/;

my %outlet_trans;
%outlet_trans = ('OUTLET_UNLINKED' => ['OUTLET_WAIT_ACTIVATION', 
				       'OUTLET_WAIT_ENABLE',
				       'OUTLET_PERM_UNACTIVATED'],
		 
		 'OUTLET_WAIT_ACTIVATION' => ['OUTLET_WAIT_ACTIVATION',
					      'OUTLET_WAIT_ENABLE', 
					      'OUTLET_PERM_WAIT_ENABLE',
					      'OUTLET_UNLINKED'],
		 
		 'OUTLET_WAIT_ENABLE' => ['OUTLET_WAIT_ENABLE', 
					  'OUTLET_WAIT_CHANGE',
					  'OUTLET_ACTIVE',
					  'OUTLET_PERM_WAIT_ENABLE'],
		 
		 'OUTLET_ACTIVE' => ['OUTLET_ACTIVE',
				     'OUTLET_WAIT_CHANGE',
				     'OUTLET_WAIT_PARTITION', 
				     'OUTLET_PERM_ACTIVE'],
		 
		 'OUTLET_WAIT_PARTITION' => ['OUTLET_WAIT_PARTITION',
					     'OUTLET_WAIT_DEACTIVATION'],
		 
		 'OUTLET_WAIT_DEACTIVATION' => ['OUTLET_WAIT_DEACTIVATION',
						'OUTLET_UNLINKED', 
						'OUTLET_PERM_UNACTIVATED'],
		 
		 'OUTLET_PERM_UNACTIVATED' => ['OUTLET_PERM_UNACTIVATED',
					       'OUTLET_PERM_WAIT_ENABLE', 
					       'OUTLET_WAIT_DEACTIVATION', 
					       'OUTLET_UNLINKED'],
		 
		 'OUTLET_PERM_WAIT_ENABLE' => ['OUTLET_PERM_WAIT_ENABLE',
					       'OUTLET_PERM_ACTIVE'],

		 'OUTLET_PERM_WAIT_CHANGE' => ['OUTLET_PERM_WAIT_CHANGE',
					       'OUTLET_PERM_UNACTIVATED',
					       'OUTLET_PERM_WAIT_ENABLE'],
		 
		 'OUTLET_PERM_ACTIVE' => ['OUTLET_PERM_ACTIVE',
					  'OUTLET_PERM_WAIT_CHANGE',
					  'OUTLET_PERM_WAIT_PARTITION', 
					  'OUTLET_ACTIVE'],
		 'OUTLET_PERM_WAIT_PARTITION' => ['OUTLET_PERM_WAIT_PARTITION',
						  'OUTLET_PERM_UNACTIVATED'],
                 'OUTLET_WAIT_CHANGE' => ['OUTLET_ACTIVE',
					  'OUTLET_PERM_WAIT_CHANGE',
					  'OUTLET_WAIT_CHANGE',
					  'OUTLET_WAIT_ENABLE',
					  'OUTLET_WAIT_PARTITION',
					  'OUTLET_WAIT_DEACTIVATION',
					  'OUTLET_UNLINKED']);

sub get_outlet_state {
  my ($fields) = @_;
  
  warn __FILE__, '::', __LINE__, ":> Finding outlet state for:\n" .
    Data::Dumper->Dump([$fields],['fields']) if ($debug >= 3);


  if ($$fields{flags} =~ /permanent/) {
    return get_outlet_state_perm($fields);
  }
  
  my @flags = ();
  @flags = split(/\,/, $$fields{flags});
  return 'OUTLET_WAIT_ACTIVATION' 
    if (grep(/^activated$/, @flags) 
	&& $$fields{status} eq 'partitioned' 
	&& $$fields{device} == 0 
	&& ($$fields{port} eq '0' || $$fields{port} eq '') 
	&& ($$fields{attributes} eq 'activate' || $$fields{attributes} eq 'change')
       );
  return $errcodes{EUNKSTATE} if ($$fields{device} == 0  || $$fields{port} eq '');
  
  if ($$fields{status} eq 'partitioned') {
    if (grep (/^activated$/, @flags)) {
      return 'OUTLET_WAIT_ENABLE' if ($$fields{attributes} eq '');
      return 'OUTLET_WAIT_CHANGE' if ($$fields{attributes} eq 'change');
      return $errcodes{EUNKSTATE};
    } else {
      return 'OUTLET_WAIT_DEACTIVATION' if ($$fields{attributes} eq 'deactivate');
      return $errcodes{EUNKSTATE};
    }
  } else {
    if (grep (/^activated$/, @flags)) {
      return 'OUTLET_WAIT_CHANGE' if($$fields{attributes} eq 'change');
      return 'OUTLET_ACTIVE' if ($$fields{attributes} eq '');
      return $errcodes{EUNKSTATE};
    } else {
      return 'OUTLET_WAIT_PARTITION' if ($$fields{attributes} eq 'deactivate');
      return $errcodes{EUNKSTATE};
    }
  }
  # shouldn't be able to get here...
  return $errcodes{EUNKSTATE};
}


# state identification for permanent states
sub get_outlet_state_perm {
  my ($fields) = @_;
  return $errcodes{EUNKSTATE} if ($$fields{attributes} ne 'change'
				  && ($$fields{device} eq '' || $$fields{port} eq ''));
  my @flags = split(/\,/, $$fields{flags});
  if ($$fields{status} eq 'partitioned') {
    return 'OUTLET_PERM_WAIT_CHANGE' if ($$fields{attributes} eq 'change');
    return 'OUTLET_PERM_WAIT_ENABLE' if (grep (/^activated$/, @flags));
    return 'OUTLET_PERM_UNACTIVATED';
  } else {
    return 'OUTLET_PERM_WAIT_CHANGE' if ($$fields{attributes} eq 'change');
    return 'OUTLET_PERM_ACTIVE' if (grep (/^activated$/, @flags));
    return 'OUTLET_PERM_WAIT_PARTITION';
  }
  # shouldn't be able to get here..
  return $errcodes{EUNKSTATE};
}

sub outlet_transition_safe {
  my ($prev, $next) = @_;
  return 1 if (grep /^$next$/, @{$outlet_trans{$prev}});
  return 0;
}

# Function: list_outlet_subnet_memberships
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the outlet_subnet_membership table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_outlet_subnet_memberships {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @fields, $mywhere);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @fields = @outlet_subnet_membership_fields;
  push @fields, @CMU::Netdb::structure::subnet_fields;
  push @fields, @CMU::Netdb::structure::outlet_fields;
  
  $mywhere = "outlet_subnet_membership.subnet = subnet.id AND outlet_subnet_membership.outlet = outlet.id";
  $mywhere .= " AND $where" if ($where ne "");
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "outlet_subnet_membership, subnet, outlet", \@fields, $mywhere);
  
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

# Function: list_outlet_vlan_memberships
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the outlet_subnet_membership table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_outlet_vlan_memberships {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @fields, $mywhere);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @fields = @outlet_vlan_membership_fields;
  push @fields, @CMU::Netdb::structure::vlan_fields;
  push @fields, @CMU::Netdb::structure::outlet_fields;
  
  $mywhere = "outlet_vlan_membership.vlan = vlan.id AND outlet_vlan_membership.outlet = outlet.id";
  $mywhere .= " AND $where" if ($where ne "");
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "outlet_vlan_membership, vlan, outlet", \@fields, $mywhere);
  
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




# Function: add_outlet_subnet_membership
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_outlet_subnet_membership {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@outlet_subnet_membership_fields) {
    my $nk = $key;		# required because $key is a reference into outlet_subnet_membership_fields
    $nk =~ s/^outlet_subnet_membership\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^outlet_subnet_membership\.$key$/, @outlet_subnet_membership_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet_subnet_membership.$key!\n".join(',', @outlet_subnet_membership_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet_subnet_membership.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet_subnet_membership.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet_subnet_membership.$key"} = $$fields{$key};
  }
  
  # verify outlet & subnet exist
  my $scr;
  $scr = CMU::Netdb::list_outlets($dbh, $dbuser, "outlet.id = '$$newfields{'outlet_subnet_membership.outlet'}'");
  return ($CMU::Netdb::errcodes{ENOENT}, ['outlet']) if (!ref $scr || !defined $scr->[1]);
  $scr = CMU::Netdb::get_subnets_ref($dbh, $dbuser, "subnet.id = '$$newfields{'outlet_subnet_membership.subnet'}'", 'subnet.name');
  return ($CMU::Netdb::errcodes{ENOENT}, ['subnet']) if (!ref $scr || !defined $scr->{$$newfields{'outlet_subnet_membership.subnet'}});
  
  # verify permissions on subnet & outlet
  my ($wl, $al);
  $wl = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', 
				    $$newfields{'outlet_subnet_membership.outlet'});
  return ($errcodes{EPERM}, ['outlet']) if ($wl < 1);
  $al = CMU::Netdb::get_add_level($dbh, $dbuser, 'subnet', 
				  $$newfields{'outlet_subnet_membership.subnet'});
  return ($errcodes{EPERM}, ['subnet']) if ($al < 1);
  
  # verify no conflicting entry exists
  # if type = primary, no other primarys may exist on that outlet
  # if type = voice, no other voice's may exist on that outlet
  # also, no other entry for this outlet & subnet may exist
  
  my $mref = list_outlet_subnet_memberships($dbh, "netreg", "outlet_subnet_membership.outlet = ".$newfields->{'outlet_subnet_membership.outlet'});
  if (!ref $mref) {
    return ($mref, []);
  }
  my $map = CMU::Netdb::makemap($mref->[0]);
  my $err = 0;
  for (1..$#$mref) {
    $err = 'type' if ($newfields->{'outlet_subnet_membership.type'} eq 'primary' && 
		      ($mref->[$_][$map->{'outlet_subnet_membership.type'}] eq 'primary'));
    $err = 'type' if ($newfields->{'outlet_subnet_membership.type'} eq 'voice' &&
		      ($mref->[$_][$map->{'outlet_subnet_membership.type'}] eq 'voice'));
    $err = 'subnet' if ($newfields->{'outlet_subnet_membership.subnet'} eq
			$mref->[$_][$map->{'outlet_subnet_membership.subnet'}]);
    $err = 'trunk_type' if (($newfields->{'outlet_subnet_membership.type'} ne 'primary') && 
			    ($mref->[$_][$map->{'outlet_subnet_membership.type'}] ne 'primary') &&
			    ($mref->[$_][$map->{'outlet_subnet_membership.trunk_type'}] 
			     ne $newfields->{'outlet_subnet_membership.trunk_type'}));
  }
  
  if ($err) {
    return ($CMU::Netdb::errcodes{EEXISTS}, [$err])
  }
  
  # verify that the initial status is being set to either active or request
  if (($newfields->{'outlet_subnet_membership.status'} eq 'request')
      || (($wl >=9) && ($newfields->{'outlet_subnet_membership.status'} eq 'active'))) {
    my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'outlet_subnet_membership', $newfields);
    if ($res < 1) {
      return ($res, []);
    }
    my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
    return ($res, \%warns);
  } else {
    return ($CMU::Netdb::errocodes{EPERM}, ['status']);
  }
}

# Function: add_outlet_vlan_membership
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_outlet_vlan_membership {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@outlet_vlan_membership_fields) {
    my $nk = $key;		# required because $key is a reference into outlet_subnet_membership_fields
    $nk =~ s/^outlet_vlan_membership\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^outlet_vlan_membership\.$key$/, @outlet_vlan_membership_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet_vlan_membership.$key!\n".join(',', @outlet_vlan_membership_fields) if ($debug >= 2);
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet_vlan_membership.$key!\n".join(',', @outlet_vlan_membership_fields) ;
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet_vlan_membership.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet_vlan_membership.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet_vlan_membership.$key"} = $$fields{$key};
  }
  
  # verify outlet & vlan exist
  my $scr;
  $scr = CMU::Netdb::list_outlets($dbh, $dbuser, "outlet.id = '$$newfields{'outlet_vlan_membership.outlet'}'");
  return ($CMU::Netdb::errcodes{ENOENT}, ['outlet']) if (!ref $scr || !defined $scr->[1]);
  $scr = CMU::Netdb::get_vlan_ref($dbh, $dbuser, "vlan.id = '$$newfields{'outlet_vlan_membership.vlan'}'", 'vlan.name');
  return ($CMU::Netdb::errcodes{ENOENT}, ['vlan']) if (!ref $scr || !defined $scr->{$$newfields{'outlet_vlan_membership.vlan'}});
  
  # verify permissions on vlan & outlet
  my ($wl, $al);
  $wl = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', 
				    $$newfields{'outlet_vlan_membership.outlet'});
  return ($errcodes{EPERM}, ['outlet']) if ($wl < 1);
  $al = CMU::Netdb::get_add_level($dbh, $dbuser, 'vlan', 
				  $$newfields{'outlet_vlan_membership.vlan'});
  return ($errcodes{EPERM}, ['vlan']) if ($al < 1);
  
  # verify no conflicting entry exists
  # if type = primary, no other primarys may exist on that outlet
  # if type = voice, no other voice's may exist on that outlet
  # also, no other entry for this outlet & subnet may exist
  
  my $mref = list_outlet_vlan_memberships($dbh, "netreg", "outlet_vlan_membership.outlet = ".$newfields->{'outlet_vlan_membership.outlet'});
  if (!ref $mref) {
    return ($mref, []);
  }
  my $map = CMU::Netdb::makemap($mref->[0]);
  my $err = 0;
  for (1..$#$mref) {
    $err = 'type' if ($newfields->{'outlet_vlan_membership.type'} eq 'primary' && 
		      ($mref->[$_][$map->{'outlet_vlan_membership.type'}] eq 'primary'));
    $err = 'type' if ($newfields->{'outlet_vlan_membership.type'} eq 'voice' &&
		      ($mref->[$_][$map->{'outlet_vlan_membership.type'}] eq 'voice'));
    $err = 'subnet' if ($newfields->{'outlet_vlan_membership.subnet'} eq
			$mref->[$_][$map->{'outlet_vlan_membership.subnet'}]);
    $err = 'trunk_type' if (($newfields->{'outlet_vlan_membership.type'} ne 'primary') && 
			    ($mref->[$_][$map->{'outlet_vlan_membership.type'}] ne 'primary') &&
			    ($mref->[$_][$map->{'outlet_vlan_membership.trunk_type'}] 
			     ne $newfields->{'outlet_vlan_membership.trunk_type'}));
  }
  
  if ($err) {
    return ($CMU::Netdb::errcodes{EEXISTS}, [$err])
  }
  
  # verify that the initial status is being set to either active or request
  if (($newfields->{'outlet_vlan_membership.status'} eq 'request')
      || (($wl >=9) && ($newfields->{'outlet_vlan_membership.status'} eq 'active'))) {
    my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'outlet_vlan_membership', $newfields);
    if ($res < 1) {
      return ($res, ['primitives::add']);
    }
    my %warns = ('insertID' => $dbh->last_insert_id(undef, undef, "outlet_vlan_membership", undef);
    return ($res, \%warns);
  } else {
    return ($CMU::Netdb::errocodes{EPERM}, ['status']);
  }
}


# Function: modify_outlet_subnet_membership
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
sub modify_outlet_subnet_membership {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet_subnet_membership.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['outlet_subnet_membership.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet_subnet_membership.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['outlet_subnet_membership.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@outlet_subnet_membership_fields) {
    my $nk = $key;		# required because $key is a reference into outlet_subnet_membership_fields
    $nk =~ s/^outlet_subnet_membership\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^outlet_subnet_membership\.$key$/, @outlet_subnet_membership_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet_subnet_membership.$key!\n".join(',', @outlet_subnet_membership_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet_subnet_membership.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet_subnet_membership.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet_subnet_membership.$key"} = $$fields{$key};
  }
  
  
  # verify various things
  my $mref = list_outlet_subnet_memberships($dbh, "netreg", "outlet_subnet_membership.outlet = ".$newfields->{'outlet_subnet_membership.outlet'});
  if (!ref $mref) {
    return ($mref, []);
  }
  my $map = CMU::Netdb::makemap($mref->[0]);
  
  # outlet can't change (non-sensical)
  if ($mref->[1][$map->{'outlet_subnet_membership.outlet'}] ne $newfields->{'outlet_subnet_membership.outlet'}) {
    return ($errcodes{EINVALID}, ['outlet']);
  }
  # verify subnet exists
  my $scr;
  $scr = CMU::Netdb::get_subnets_ref($dbh, $dbuser, "subnet.id = '$$newfields{'outlet_subnet_membership.subnet'}'", 'subnet.name');
  return ($CMU::Netdb::errcodes{ENOENT}, ['subnet']) if (!ref $scr || !defined $scr->{$$newfields{'outlet_subnet_membership.subnet'}});
  
  # verify permissions on subnet & outlet
  my ($wl, $al);
  $wl = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', 
				    $$newfields{'outlet_subnet_membership.outlet'});
  return ($errcodes{EPERM}, ['outlet']) if ($wl < 1);
  $al = CMU::Netdb::get_add_level($dbh, $dbuser, 'subnet', 
				  $$newfields{'outlet_subnet_membership.subnet'});
  return ($errcodes{EPERM}, ['subnet']) if ($al < 1);
  
  
  # verify no conflicting entry exists
  # if type = primary, no other primarys may exist on that outlet
  # if type = voice, no other voice's may exist on that outlet
  # also, no other entry for this outlet & subnet may exist
  # all non-primary vlans must have the same trunking type.  
  #     --- Is this true everywhere? FIXME
  
  my $err = 0;
  for (1..$#$mref) {
    $err = 'type' if ($newfields->{'outlet_subnet_membership.type'} eq 'primary' && 
		      ($mref->[$_][$map->{'outlet_subnet_membership.type'}] eq 'primary') &&
		      ($mref->[$_][$map->{'outlet_subnet_membership.id'}] ne $id));
    $err = 'type' if ($newfields->{'outlet_subnet_membership.type'} eq 'voice' &&
		      ($mref->[$_][$map->{'outlet_subnet_membership.type'}] eq 'voice') &&
		      ($mref->[$_][$map->{'outlet_subnet_membership.id'}] ne $id));
    $err = 'subnet' if ($newfields->{'outlet_subnet_membership.subnet'} eq
			$mref->[$_][$map->{'outlet_subnet_membership.subnet'}] &&
			($mref->[$_][$map->{'outlet_subnet_membership.id'}] ne $id));
    $err = 'trunk_type' if (($newfields->{'outlet_subnet_membership.type'} ne 'primary') &&
			    ($mref->[$_][$map->{'outlet_subnet_membership.type'}] ne 'primary') &&
			    ($mref->[$_][$map->{'outlet_subnet_membership.trunk_type'}] 
			     ne $newfields->{'outlet_subnet_membership.trunk_type'}) &&
			    ($mref->[$_][$map->{'outlet_subnet_membership.id'}] ne $id));
  }
  
  if ($err) {
    return ($CMU::Netdb::errcodes{EEXISTS}, [$err])
  }
  
  
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'outlet_subnet_membership', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM outlet_subnet_membership WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::buildings_cables::modify_outlet_subnet_membership: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::buildings_cables::modify_outlet_subnet_membership: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
  
}

# Function: modify_outlet_vlan_membership
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
sub modify_outlet_vlan_membership {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet_vlan_membership.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['outlet_vlan_membership.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet_vlan_membership.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['outlet_vlan_membership.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@outlet_vlan_membership_fields) {
    my $nk = $key;		# required because $key is a reference into outlet_subnet_membership_fields
    $nk =~ s/^outlet_vlan_membership\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^outlet_vlan_membership\.$key$/, @outlet_vlan_membership_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find outlet_vlan_membership.$key!\n".join(',', @outlet_vlan_membership_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("outlet_vlan_membership.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "outlet_vlan_membership.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"outlet_vlan_membership.$key"} = $$fields{$key};
  }
  
  
  # verify various things
  my $mref = list_outlet_vlan_memberships($dbh, "netreg", "outlet_vlan_membership.outlet = ".$newfields->{'outlet_vlan_membership.outlet'});
  if (!ref $mref) {
    return ($mref, []);
  }
  my $map = CMU::Netdb::makemap($mref->[0]);
  
  # outlet can't change (non-sensical)
  if ($mref->[1][$map->{'outlet_vlan_membership.outlet'}] ne $newfields->{'outlet_vlan_membership.outlet'}) {
    return ($errcodes{EINVALID}, ['outlet']);
  }
  # verify subnet exists
  my $scr;
  $scr = CMU::Netdb::get_vlan_ref($dbh, $dbuser, "vlan.id = '$$newfields{'outlet_vlan_membership.vlan'}'", 'vlan.name');
  return ($CMU::Netdb::errcodes{ENOENT}, ['vlan']) if (!ref $scr || !defined $scr->{$$newfields{'outlet_vlan_membership.vlan'}});
  
  # verify permissions on subnet & outlet
  my ($wl, $al);
  $wl = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', 
				    $$newfields{'outlet_vlan_membership.outlet'});
  return ($errcodes{EPERM}, ['outlet']) if ($wl < 1);
  $al = CMU::Netdb::get_add_level($dbh, $dbuser, 'vlan', 
				  $$newfields{'outlet_vlan_membership.vlan'});
  return ($errcodes{EPERM}, ['vlan']) if ($al < 1);
  
  
  # verify no conflicting entry exists
  # if type = primary, no other primarys may exist on that outlet
  # if type = voice, no other voice's may exist on that outlet
  # also, no other entry for this outlet & subnet may exist
  # all non-primary vlans must have the same trunking type.  
  #     --- Is this true everywhere? FIXME
  
  my $err = 0;
  for (1..$#$mref) {
    $err = 'type' if ($newfields->{'outlet_vlan_membership.type'} eq 'primary' && 
		      ($mref->[$_][$map->{'outlet_vlan_membership.type'}] eq 'primary') &&
		      ($mref->[$_][$map->{'outlet_vlan_membership.id'}] ne $id));
    $err = 'type' if ($newfields->{'outlet_vlan_membership.type'} eq 'voice' &&
		      ($mref->[$_][$map->{'outlet_vlan_membership.type'}] eq 'voice') &&
		      ($mref->[$_][$map->{'outlet_vlan_membership.id'}] ne $id));
    $err = 'vlan' if ($newfields->{'outlet_vlan_membership.vlan'} eq
		      $mref->[$_][$map->{'outlet_vlan_membership.vlan'}] &&
		      ($mref->[$_][$map->{'outlet_vlan_membership.id'}] ne $id));
    $err = 'trunk_type' if (($newfields->{'outlet_vlan_membership.type'} ne 'primary') &&
			    ($mref->[$_][$map->{'outlet_vlan_membership.type'}] ne 'primary') &&
			    ($mref->[$_][$map->{'outlet_vlan_membership.trunk_type'}] 
			     ne $newfields->{'outlet_vlan_membership.trunk_type'}) &&
			    ($mref->[$_][$map->{'outlet_vlan_membership.id'}] ne $id));
  }
  
  if ($err) {
    return ($CMU::Netdb::errcodes{EEXISTS}, [$err])
  }
  
  
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'outlet_vlan_membership', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM outlet_vlan_membership WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::buildings_cables::modify_outlet_vlan_membership: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::buildings_cables::modify_outlet_vlan_membership: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
  
}


# Function: delete_outlet_subnet_membership
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the server to delete.
#     The 'version' of the server to delete.
# Actions: Verifies authorization and deletes the entry
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_outlet_subnet_membership {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet_subnet_membership.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet_subnet_membership.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  # Verify write access to outlet
  my $mref = list_outlet_subnet_memberships($dbh, "netreg", "outlet_subnet_membership.id=$id");
  if (!ref $mref) {
    return ($mref, []);
  }
  my $map = CMU::Netdb::makemap($mref->[0]);
  
  my $wl = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', 
				       $mref->[1][$map->{'outlet_subnet_membership.outlet'}]);
  return ($errcodes{EPERM}, ['outlet']) if ($wl < 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'outlet_subnet_membership', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM outlet_subnet_membership WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::buildings_cables::delete_outlet_subnet_membership: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::buildings_cables::delete_outlet_subnet_membership: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# Function: delete_outlet_vlan_membership
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the server to delete.
#     The 'version' of the server to delete.
# Actions: Verifies authorization and deletes the entry
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_outlet_vlan_membership {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('outlet_vlan_membership.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('outlet_vlan_membership.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  # Verify write access to outlet
  my $mref = list_outlet_vlan_memberships($dbh, "netreg", "outlet_vlan_membership.id=$id");
  if (!ref $mref) {
    return ($mref, []);
  }
  my $map = CMU::Netdb::makemap($mref->[0]);
  
  my $wl = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', 
				       $mref->[1][$map->{'outlet_vlan_membership.outlet'}]);
  return ($errcodes{EPERM}, ['outlet']) if ($wl < 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'outlet_vlan_membership', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM outlet_vlan_membership WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::buildings_cables::delete_outlet_vlan_membership: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::buildings_cables::delete_outlet_vlan_membership: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

sub list_outlets_devport {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, $map);

  $dbuser = CMU::Netdb::valid('users.name', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $result = CMU::Netdb::primitives::list($dbh, $dbuser, 'outlet,machine,trunkset_machine_presence',
					 \@CMU::Netdb::structure::outlet_machine_fields,
					 "outlet.device = trunkset_machine_presence.id AND ".
					 "trunkset_machine_presence.device = machine.id ".
					 " AND $where");
  if (!ref $result) {
    return $result;
  }

  if ($#$result == -1) {
    return [\@CMU::Netdb::structure::outlet_machine_fields];
  }

  @data = @$result;
  unshift @data, \@CMU::Netdb::structure::outlet_machine_fields;

  return \@data;
}



# Function: list_outlets_attributes_devport
# Arguments: 3:
#     An already connected database handle.
#     The name of the user making the request.
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the attribute table which conform to the WHERE clause (if any)
#          The following tables are added to the query:
#            attribute_spec, outlet, trunkset_machine_presence, machine
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)

sub list_outlets_attributes_devport {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, $map, @fields, $query);

  $dbuser = CMU::Netdb::valid('users.name', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  @fields = 
    (@CMU::Netdb::structure::outlet_fields, 
     @CMU::Netdb::structure::trunkset_machine_presence_fields,
     @CMU::Netdb::structure::machine_fields,
     @CMU::Netdb::structure::attribute_fields,
     @CMU::Netdb::structure::attribute_spec_fields);

  $query = <<END_SQL;
attribute.spec = attribute_spec.id
AND attribute.owner_table = 'outlet'
AND attribute.owner_tid = outlet.id
AND outlet.device = trunkset_machine_presence.id 
AND trunkset_machine_presence.device = machine.id
AND $where
END_SQL


  $result = CMU::Netdb::primitives::list($dbh, $dbuser, 
					 'attribute,attribute_spec,outlet,machine,trunkset_machine_presence',
					 \@fields, $query);

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

# Function: modify_outlet_state_by_name
# Arguments: 5:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     The state name to put the outlet in, one of
#          the keys in $valid_states
#
# Actions: Queries the database in the handle for rows in
#          the attribute table which conform to the WHERE clause (if any)
#          The following tables are added to the query:
#            attribute_spec, outlet, trunkset_machine_presence, machine
# Return value:
#     (1, \%warns) if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
#

sub modify_outlet_state_by_name {
  my ($dbh, $dbuser, $id, $ver, $state) = @_;
  my ($out, $oupos, $ul, $fields, $valid, $tgt);
  my ($valid_states) = {
			OUTLET_ACTIVE => {
                                          flags => [ '!permanent', 'activated' ],


                                          status => [ 'enabled' ],
                                          device => [ 'valid' ],
                                          attributes => [ '!activate','!deactivate','!change' ],
                                          port => [ 'not-blank' ]
                                         },
                        OUTLET_PERM_ACTIVE => {
                                               flags => [ 'permanent', 'activated' ],
                                               status => [ 'enabled' ],
                                               device => [ '!' ],
                                               attributes => [ '!change' ],
                                               port => [ 'not-blank' ]
                                              },
                        OUTLET_PERM_UNACTIVATED => {
                                                    flags => [ 'permanent', '!activated' ],
                                                    status => [ 'partitioned' ],
                                                    device => [ '!' ],
                                                    attributes => [ '!change' ],
                                                    port => [ 'not-blank' ]
                                                   },
                        OUTLET_PERM_WAIT_CHANGE => {
                                                    flags => [ 'permanent' ],
                                                    attributes => [ 'change', '!deactivate', '!activate' ]
                                                   },
                        OUTLET_PERM_WAIT_ENABLE => {
                                                    flags => [ 'permanent', 'activated' ],
                                                    status => [ 'partitioned' ],
                                                    device => [ '!' ],
                                                    attributes => [ '!change' ],
                                                    port => [ 'not-blank' ]
                                                   },
                        OUTLET_PERM_WAIT_PARTITION => {
                                                       flags => [ 'permanent', '!activated' ],
                                                       status => [ 'enabled' ],
                                                       device => [ '!' ],
                                                       attributes => [ '!change'],
						       port => [ 'not-blank' ]
                                                      },
                        OUTLET_WAIT_ACTIVATION => {
                                                   flags => [ 'activated', '!permanent' ],
                                                   status => [ 'partitioned' ],
                                                   device => [ 'invalid' ],
                                                   attributes => [ '!', '!deactivate', '!change', 'activate'],
                                                   port => [ 'not-valid' ]
                                                  },
                        OUTLET_WAIT_CHANGE => {
                                               flags => [ '!permanent', 'activated' ],
                                               device => [ 'valid' ],
                                               attributes => ['!activate', '!deactivate', 'change' ],
                                               port => [ 'not-blank' ]
                                              },
                        OUTLET_WAIT_DEACTIVATION => {
                                                     flags => [ '!activated', '!permanent' ],
                                                     status => [ 'partitioned' ],
                                                     device => [ 'valid' ],
                                                     attributes => [ 'deactivate', '!change', '!activate' ],
                                                     port => [ 'not-blank' ]
                                                    },
                        OUTLET_WAIT_ENABLE => {
                                               flags => [ 'activated', '!permanent' ],
                                               status => [ 'partitioned' ],
                                               device => [ 'valid' ],
                                               attributes => [ '!activate', '!deactivate', '!change' ],
                                               port => [ 'not-blank' ]
                                              },
                        OUTLET_WAIT_PARTITION => {
                                                  flags => [ '!permanent', '!activated'],
                                                  status => [ 'enabled' ],
                                                  attributes => [ 'deactivate', '!activate', '!change' ],
                                                  device => ['valid'],
                                                  port => [ 'not-blank' ]
                                                 }
                       };
  # Error checking/security before we start.

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ["dbuser"]) if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid('outlet.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ["id"]) if (CMU::Netdb::getError($id) != 1);

  $ver = CMU::Netdb::valid('outlet.version', $ver, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($ver), ["version"]) if (CMU::Netdb::getError($ver) != 1);

  return($CMU::Netdb::errors::errcodes{"EUNKSTATE"}, ["state"]) if (! defined $valid_states->{$state});
  $out = CMU::Netdb::list_outlets($dbh, $dbuser, "outlet.id = $id");
  return ($out) if (! ref($out));
  $oupos = CMU::Netdb::makemap(shift(@$out));

  return($CMU::Netdb::errors::errcodes{"ENOENT"}, ["outlet"]) if (! scalar @$out);

  return($CMU::Netdb::errors::errcodes{"EINVALID"}, ["outlet"]) if ((scalar(@$out)) > 1);

  return($CMU::Netdb::errors::errcodes{"ESTALE"}, ["outlet"]) if ($ver ne $out->[0][$oupos->{'outlet.version'}]);

  $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', $id);

  # Get the current fields of interest

  $fields->{force} = 'yes';

  if (defined $valid_states->{$state}{device}) {
    if (($valid_states->{$state}{device} eq 'valid') &&
	($$out->[0][$oupos->{'outlet.device'}] eq '')) {
      return($CMU::Netdb::errors::errcodes{"EINVTRANS"},"device must be assigned")
    } elsif (($valid_states->{$state}{device} eq 'invalid') &&
             ($$out->[0][$oupos->{'outlet.device'}] ne '') &&
             ($$out->[0][$oupos->{'outlet.device'}] ne '0')) {
      return($CMU::Netdb::errors::errcodes{"EINVTRANS"},"device must not be assigned")
    }
  }

  if (defined $valid_states->{$state}{port}) {
    if (($valid_states->{$state}{port} eq 'not-blank') &&
        ($out->[0][$oupos->{'outlet.port'}] eq '')) {
      return($CMU::Netdb::errors::errcodes{"EINVTRANS"},"port must be assigned")
    } elsif (($valid_states->{$state}{port} eq 'not-valid') &&
             ($out->[0][$oupos->{'outlet.port'}] ne '') &&
             ($out->[0][$oupos->{'outlet.port'}] ne '0')) {
      return($CMU::Netdb::errors::errcodes{"EINVTRANS"},"port must not be assigned")
    }
    $fields->{port} = $out->[0][$oupos->{'outlet.port'}];
  }

  if (defined $valid_states->{$state}{attributes}) {
    $fields->{attributes} = apply_outlet_field_constraint($out->[0][$oupos->{'outlet.attributes'}],
                                                          $valid_states->{$state}{attributes});

  }

  if (defined $valid_states->{$state}{flags}) {
    $fields->{flags} = apply_outlet_field_constraint($out->[0][$oupos->{'outlet.flags'}],
                                                     $valid_states->{$state}{flags});
  }

  if (defined $valid_states->{$state}{status}) {
    $fields->{status} = apply_outlet_field_constraint($out->[0][$oupos->{'outlet.status'}],
                                                      $valid_states->{$state}{status});
  }

  return( CMU::Netdb::modify_outlet($dbh, $dbuser, $id, $ver, $fields, $ul));

}

#
# Function: apply_outlet_field_constraint
# Arguments: 2:
#          current value for field
#          constraint list
#
# Actions: removes elements from the list that need to be deleted
#          adds elements that are required
#
# Return value: new value string
#
#
#
sub apply_outlet_field_constraint {
  my ($string, $constraint) = @_;

  warn Data::Dumper->Dump([\@_], ['args']) if ($debug >= 4);
  my ($element, $con);

  foreach (split(/,/,$string)) {
    $element->{$_} = 1;
  }

  warn Data::Dumper->Dump([$element], ['elements']) if ($debug >= 4);

  foreach (@$constraint) {
    # prevent aliasing
    $con = $_;
    if ($con =~ /^!/) {
      $con =~ s/^!//;
      delete $element->{$con} if (exists $element->{$con});
    } else {
      $element->{$con} = 1;
    }
  }

  return join(',', keys %$element);

}

1;
