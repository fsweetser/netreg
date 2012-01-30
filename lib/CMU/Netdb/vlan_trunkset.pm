#   -*- perl -*-
#
# CMU::Netdb::vlan_trunkset
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
# $Id: vlan_trunkset.pm,v 1.14 2006/10/31 18:31:56 vitroth Exp $
#
#


package CMU::Netdb::vlan_trunkset;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug @machine_fields 
	    @subnet_fields @subnet_share_fields @subnet_presence_fields 
	    @subnet_domain_fields @vlan_fields @vlan_presence_fields 
	    @trunkset_building_presence @trunkset_vlan_presence @trunkset
	    @trunkset_machine_presence @trunkset_building_presence_tsb 
	    @trunkset_vlan_presence_tsv @trunkset_machine_presence_tsd
	    @vlan_subnet_presence_fields);

use CMU::Netdb;
use CMU::Netdb::helper;
use CMU::Netdb::primitives;
use CMU::Netdb::structure;
use CMU::Netdb::errors;
use CMU::Netdb::auth;
use CMU::Netdb::validity;
use CMU::Netdb::dns_dhcp;

use Data::Dumper;


require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     add_vlan
	     delete_vlan
	     list_vlans list_vlans_ref
	     modify_vlan
	     get_vlan_ref

	     add_vlan_presence
	     list_vlan_presences
	     delete_vlan_presence

	     list_trunkset
	     list_trunkset_ref
	     get_trunkset_ref
	     add_trunkset
	     delete_trunkset
	     modify_trunkset

	     list_trunkset_building_presence
	     list_trunkset_device_presence
	     list_device_trunkset_presence
	     list_trunkset_vlan_presence
	     list_vlan_trunkset_presence
	     list_trunkset_presences
	     add_trunkset_presence
	     delete_trunkset_presence
	     get_trunkset_building_presence
	     get_trunkset_vlan_presence
	     get_trunkset_device_presence
	     modify_trunkset_machine_presence
	    );


@machine_fields = @CMU::Netdb::structure::machine_fields;
@subnet_fields = @CMU::Netdb::structure::subnet_fields;
@subnet_share_fields = @CMU::Netdb::structure::subnet_share_fields;
@subnet_presence_fields = @CMU::Netdb::structure::subnet_presence_fields;

@vlan_fields = @CMU::Netdb::structure::vlan_fields;
@vlan_presence_fields = @CMU::Netdb::structure::vlan_presence_fields;
@vlan_subnet_presence_fields = @CMU::Netdb::structure::vlan_subnet_presence_fields;

@trunkset_building_presence = @CMU::Netdb::structure::trunkset_building_presence_fields;
@trunkset_machine_presence   = @CMU::Netdb::structure::trunkset_machine_presence_fields;
@trunkset_vlan_presence     = @CMU::Netdb::structure::trunkset_vlan_presence_fields;
@trunkset = @CMU::Netdb::structure::trunkset;

@trunkset_building_presence_tsb = @CMU::Netdb::structure::trunkset_building_presence_ts_building_fields;
@trunkset_machine_presence_tsd   = @CMU::Netdb::structure::trunkset_machine_presence_ts_machine_fields;
@trunkset_vlan_presence_tsv     = @CMU::Netdb::structure::trunkset_vlan_presence_ts_vlan_fields;

$debug = 0;

# Function: add_vlan
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_vlan {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields, $query, $sth, @row);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  ## bidirectional verification of the fields that the user is trying to add
  
  ## verify the vlan is unique
  
  foreach $key (@vlan_fields) {
    my $nk = $key;		# required because $key is a reference into vlan_fields
    $nk =~ s/^vlan\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^vlan\.$key$/, @vlan_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find vlan.$key!\n".join(',', @vlan_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("vlan.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "vlan.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"vlan.$key"} = $$fields{$key};
  }
 
  #my ($nb, $nn) = ($$newfields{'vlan.base_address'}, $$newfields{'vlan.network_mask'});
#  $query = "SELECT COUNT(vlan.id) FROM vlan WHERE vlan.number='".$$newfields{"vlan.number"}."'";
#  $sth = $dbh->prepare($query);
#  warn  __FILE__, ':', __LINE__, ' :>'.
#    "add_vlan query: $query\n" if ($debug >= 2);
#  $sth->execute;
#  @row = $sth->fetchrow_array();
#  return ($errcodes{EEXISTS}, ['vlan.number'])
#    if (@row && defined $row[0] && $row[0] > 0);
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'vlan', $newfields);
  if ($res < 1) {
    CMU::Netdb::xaction_rollback($dbh);
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
      ($dbh, $dbuser, 'admin_default_add', 'vlan', $warns{insertID}, '', {});
    
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "vlan/$warns{insertID}: ".join(',', @$AErrf)."\n";
      CMU::Netdb::xaction_rollback($dbh);
      return ($ARes, $AErrf);
    }
  }

  CMU::Netdb::xaction_commit($dbh, $xref);  
  return ($res, \%warns);
}

# Function: delete_vlan
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)

#  FIXME 9: kevinm: make this cascade delete vlan_presence
#  FIXME 3: kevinm: does this really return ESTALE ever? or for that matter,
#           if the key doesn't even exist?

sub delete_vlan {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('vlan.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('vlan.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'vlan', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM vlan WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_vlan: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_vlan: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# Function: list_vlans
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the vlan table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_vlans {
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
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "vlan", \@vlan_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@vlan_fields];
  }
  
  @data = @$result;
  unshift @data, \@vlan_fields;
  
  return \@data;
}

# Function: list_vlans_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (vlan.name or vlan.abbrevation, mostly)
# Actions: Queries the database and retrieves the vlan ID and name 
#          for the vlan_presence rows specified
# Return value:
#     A reference to an associative array of vlan.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_vlans_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('vlan.id', $efield);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "vlan", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: modify_vlan
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
sub modify_vlan {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields, $orig, %ofields, @vlan_field_short);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('vlan.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  return ($errcodes{"EINVALID"}, ['id', 'vlan_default']) if ($id eq '0');
  
  $version = CMU::Netdb::valid('vlan.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = CMU::Netdb::list_vlans($dbh, "netreg", "vlan.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  warn "modify_vlan: copying old field data\n" if ($debug >= 2);
  foreach (@vlan_fields) {
    my $nk = $_; #copy the field before stripping the table name
    $nk =~ s/^vlan\.//;
    push(@vlan_field_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ { $$orig[1]}[$i++] } @vlan_field_short;
  }
  
  map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } @vlan_field_short;
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@vlan_fields) {
    my $nk = $key;		# required because $key is a reference into vlan_fields
    $nk =~ s/^vlan\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^vlan\.$key$/, @vlan_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find vlan.$key!\n".join(',', @vlan_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("vlan.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "vlan.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"vlan.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'vlan', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM vlan WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_vlan: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_vlan: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
}

# Function: get_vlan_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (vlan.name or vlan.abbrevation, mostly)
# Actions: Queries the database and retrieves the vlan ID and name 
#          for the vlan rows specified
# Return value:
#     A reference to an associative array of subnet.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_vlan_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('vlan.id', $efield);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "vlan", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: add_vlan_presence
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_vlan_presence {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@vlan_presence_fields) {
    my $nk = $key;		# required because $key is a reference into vlan_presence
    next if ($nk eq 'building.name');
    next if ($nk eq 'vlan.name');
    $nk =~ s/^vlan_presence\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^vlan_presence\.$key$/, @vlan_presence_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find vlan_presence.$key!\n".join(',', @vlan_presence_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("vlan_presence.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "vlan_presence.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"vlan_presence.$key"} = $$fields{$key};
  }	  
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'vlan_presence', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
  
}

# Function: list_vlan_presences
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the vlan_presence table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_vlan_presences {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @fields, $query);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $query .= " building.building = vlan_presence.building AND vlan.id = vlan_presence.vlan ";
  $query .= " AND " if ($where ne '');
  
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "vlan_presence, building, vlan", \@vlan_presence_fields, $query);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@vlan_presence_fields];
  }
  
  @data = @$result;
  unshift @data, \@vlan_presence_fields;
  
  return \@data;
}

# Function: delete_vlan_presence
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_vlan_presence {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('vlan_presence.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('vlan_presence.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'vlan_presence', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM vlan_presence WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_vlan_presence: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_vlan_presence: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}



# Function: add_trunkset
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_trunkset {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields, $query, $sth, @row);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  ## bidirectional verification of the fields that the user is trying to add
  
  ## verify the vlan is unique
  
  foreach $key (@trunkset) {
    my $nk = $key;		# required because $key is a reference into vlan_fields
    $nk =~ s/^trunk_set\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^trunk_set\.$key$/, @trunkset) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find trunk_set.$key!\n".join(',', @trunkset) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("trunk_set.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "trunk_set.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"trunk_set.$key"} = $$fields{$key};
  }
  
  #my ($nb, $nn) = ($$newfields{'vlan.base_address'}, $$newfields{'vlan.network_mask'});
  
  $query = "SELECT COUNT(trunk_set.id) FROM trunk_set WHERE trunk_set.name='".$$newfields{"trunk_set.name"}."'";
  $sth = $dbh->prepare($query);
  warn  __FILE__, ':', __LINE__, ' :>'.
    "add_trunkset query: $query\n" if ($debug >= 2);
  $sth->execute;
  @row = $sth->fetchrow_array();
  return ($errcodes{EEXISTS}, ['trunk_set.name'])
    if (@row && defined $row[0] && $row[0] > 0);
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'trunk_set', $newfields);
  if ($res < 1) {
    CMU::Netdb::xaction_rollback($dbh);
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);

  ## Addition was successful. Go ahead and add default permissions.
  if ($warns{insertID} == 0) {
    # This probably indicates a bug in DBI, because an insertid of 0
    # is completely bogus, but possible if the version of DBD::mysql
    # and the mysql libraries are out of sync between client and server
    warn __FILE__, ':', __LINE__, ' :>'.
      "MySQL insertID returned is 0; probably a client/server incompatibility".
	" between DBD::mysql and mysql libraries.\n";
  }else{
    my ($ARes, $AErrf) = CMU::Netdb::apply_prot_profile
      ($dbh, $dbuser, 'admin_default_add', 'trunk_set', $warns{insertID}, '', {});
    
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "trunk_set/$warns{insertID}: ".join(',', @$AErrf)."\n";
      CMU::Netdb::xaction_rollback($dbh);
      return ($ARes, $AErrf);
    }
  }

  CMU::Netdb::xaction_commit($dbh, $xref);  
  return ($res, \%warns);
}


# Function: delete_trunkset
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
#  ****   : ktrivedi: What if this trunk_set.id is refered by other tables ?
#		      i.e., trunkset_{vlan,building}_presence. Get Foriegn Key
#		      Constraint error. Or should I iterate through those tables
# 		      and delete all related entries ?
#  FIXME 3: kevinm: does this really return ESTALE ever? or for that matter,
#           if the key doesn't even exist?  .... ????

sub delete_trunkset {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('trunk_set.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('trunk_set.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'trunk_set', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM trunk_set WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_trunkset: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_trunkset: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
}

# Function: modify_trunkset
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
sub modify_trunkset {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('trunk_set.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  return ($errcodes{"EINVALID"}, ['id', 'trunkset_default']) if ($id eq '0');
  
  $version = CMU::Netdb::valid('trunk_set.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@trunkset) {
    my $nk = $key;		# required because $key is a reference into vlan_fields
    $nk =~ s/^trunk_set\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^trunk_set\.$key$/, @trunkset) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find vlan.$key!\n".join(',', @trunkset) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("trunk_set.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "trunk_set.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"trunk_set.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'trunk_set', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM trunk_set WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_trunkset: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_trunkset: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
}

# Function: modify_trunkset_machine_presence
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
sub modify_trunkset_machine_presence {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('trunkset_machine_presence.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  return ($errcodes{"EINVALID"}, ['id']) if ($id eq '0');
  
  $version = CMU::Netdb::valid('trunkset_machine_presence.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@trunkset_machine_presence) {
    my $nk = $key;		# required because $key is a reference into vlan_fields
    $nk =~ s/^trunkset_machine_presence\.//;
    $$fields{$nk} = '' 
      if (exists $$fields{$nk} && !defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^trunkset_machine_presence\.$key$/, @trunkset_machine_presence) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find vlan.$key!\n".join(',', @trunkset_machine_presence) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("trunkset_machine_presence.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "trunkset_machine_presence.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"trunkset_machine_presence.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'trunkset_machine_presence', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM trunkset_machine_presence WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_trunkset_machine_presence: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_trunkset_machine_presence: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
}



# Function: list_trunkset
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the trunk_set table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_trunkset {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  warn  __FILE__, ':', __LINE__, ' :>'.
    "Entering list_trunkset ($dbuser)\n" if ($debug >= 2);
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  if (CMU::Netdb::getError($dbuser) != 1) {
    warn  __FILE__, ':', __LINE__, ' :>'.
      "ERROR executing credentials.authid verification\n" if ($debug >= 2);
    return CMU::Netdb::getError($dbuser);
  }
  warn  __FILE__, ':', __LINE__, ' :>'.
    "User is now: $dbuser\n" if ($debug >= 2);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "trunk_set", \@trunkset, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@trunkset];
  }
  
  @data = @$result;
  unshift @data, \@trunkset;
  
  return \@data;
}


# Function: list_trunkset_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (trunk_set.name or trunk_set.abbrevation, mostly)
# Actions: Queries the database and retrieves the trunk_set.ID and name 
#          for the trunkset_xxx_presence rows specified
# Return value:
#     A reference to an associative array of vlan.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_trunkset_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunk_set.id', $efield);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "trunk_set", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }

  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: get_trunkset_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (trunk_set.name or trunk_set.abbrevation, mostly)
# Actions: Queries the database and retrieves the trunk_set.ID and name 
#          for the trunkset_xxx_presence rows specified
# Return value:
#     A reference to an associative array of vlan.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_trunkset_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunk_set.id', $efield);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "trunk_set", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }

  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}


# Function: add_trunkset_presence
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_trunkset_presence {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields, $prefix_type, @trunkset_presence_fields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  @trunkset_presence_fields = ($$fields{type} eq 'vlan'?@trunkset_vlan_presence:($$fields{type} eq 'building'?@trunkset_building_presence:@trunkset_machine_presence));
  $prefix_type = 'trunkset_vlan_presence' if ($$fields{type} eq 'vlan');
  $prefix_type = 'trunkset_building_presence' if ($$fields{type} eq 'building');
  $prefix_type = 'trunkset_machine_presence' if ($$fields{type} eq 'machine');
  delete $$fields{type};

  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@trunkset_presence_fields) {
    my $nk = $key;# required because $key is a reference into vlan_presence
    next if ($nk eq 'building.name');
    next if ($nk eq 'vlan.name');
    next if ($nk eq 'trunk_set.name');
    next if ($nk eq 'machine.host_name');
    $nk =~ s/^$prefix_type\.// ;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^$prefix_type\.$key$/, @trunkset_presence_fields) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find $prefix_type.$key!\n".join(',', @trunkset_presence_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn  __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("$prefix_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "$prefix_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"$prefix_type.$key"} = $$fields{$key};
  }	  
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, $prefix_type, $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
  
}

# Function: delete_trunkset_presence
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_trunkset_presence {
  my ($dbh, $dbuser, $type, $id, $version) = @_;
  my ($query, $sth, $result, $uid, $dref, $tabletype, $checkts, @row);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $tabletype = "trunkset_".$type."_presence";
  
  $id = CMU::Netdb::valid("$tabletype.id", $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid("$tabletype.version", $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);

  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, "$tabletype", $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM $tabletype WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_trunkset_.$tabletype.presence: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_trunkset_.$tabletype._presence: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# Function: list_trunkset_presences
# Arguments: 4:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to identify trunkset in
#	 'vlan', 'building' or machine. default is 'vlan'
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the trunkset_xxx_presence table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_trunkset_presences {
  my ($dbh, $dbuser, $type,$where) = @_;
  my ($result, @data, @fields, $query, $presTable, @ts_type_presence);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $type = 'vlan' if($type eq '');
  if ($type eq 'building') {
    $query .= " building.id = trunkset_building_presence.buildings AND trunk_set.id = trunkset_building_presence.trunk_set ";
    @ts_type_presence = @trunkset_building_presence_tsb;
  } elsif ($type eq 'machine') {
    $query .= " machine.id = trunkset_machine_presence.device AND trunk_set.id = trunkset_machine_presence.trunk_set ";
    @ts_type_presence = @trunkset_machine_presence_tsd;
  } else {
    # Assume vlan instead of throwing an error
    $query .= " vlan.id = trunkset_vlan_presence.vlan AND trunk_set.id = trunkset_vlan_presence.trunk_set ";
    @ts_type_presence = @trunkset_vlan_presence_tsv;
  }
  $query .= " AND $where" if ($where ne '');

  $presTable = "trunkset_".$type."_presence";

  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "$presTable, trunk_set, $type",
				    \@ts_type_presence, $query);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@ts_type_presence];
  }
  
  @data = @$result;
  unshift @data, \@ts_type_presence;

  return \@data;
}

# Function: get_trunkset_building_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the trunk_set ID and name 
#          for the trunkset_building_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_building_presence.trunk_set =>
#        trunk_set.name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_trunkset_building_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_building_presence.trunk_set', 'trunk_set.name');
  $lwhere = 'trunkset_building_presence.trunk_set = trunk_set.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "trunk_set, trunkset_building_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}

# Function: list_trunkset_building_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the trunk_set ID and name 
#          for the trunkset_building_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_building_presence.trunk_set =>
#        trunk_set.name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_trunkset_building_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_building_presence.trunk_set', 'trunk_set.name');
  $lwhere = 'trunkset_building_presence.trunk_set = trunk_set.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "trunk_set, trunkset_building_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}


# Function: get_runkset_vlan_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the vlan ID and name 
#          for the trunkset_vlan_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_vlan_presence.vlan =>
#        vlan.name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_trunkset_vlan_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_vlan_presence.vlan', 'vlan.name');
  $lwhere = 'trunkset_vlan_presence.vlan = vlan.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "vlan, trunkset_vlan_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}

# Function: list_trunkset_vlan_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the vlan ID and name 
#          for the trunkset_vlan_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_vlan_presence.vlan =>
#        vlan.name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_trunkset_vlan_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_vlan_presence.vlan', 'vlan.name');
  $lwhere = 'trunkset_vlan_presence.vlan = vlan.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "vlan , trunkset_vlan_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}

# Function: list_vlan_trunkset_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the trunkset ID and name 
#          for the trunkset_vlan_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_vlan_presence.trunk_set =>
#        trunk_set.name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_vlan_trunkset_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_vlan_presence.trunk_set', 'trunk_set.name');
  $lwhere = 'trunkset_vlan_presence.trunk_set = trunk_set.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "trunk_set, trunkset_vlan_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;

}

# Function: get_trunkset_device_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the trunk_set ID and name 
#          for the trunkset_machine_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_machine_presence.device =>
#        machine.host_name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_trunkset_device_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_machine_presence.device', 'machine.host_name');
  $lwhere = 'trunkset_machine_presence.device = machine.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "machine, trunkset_machine_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}


# Function: list_trunkset_device_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the trunk_set ID and name 
#          for the trunkset_machine_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_machine_presence.device =>
#        machine.host_name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_trunkset_device_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_machine_presence.device', 'machine.host_name');
  $lwhere = 'trunkset_machine_presence.device = machine.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "machine, trunkset_machine_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}

# Function: list_device_trunkset_presence
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
# Actions: Queries the database and retrieves the trunk_set ID and name 
#          for the trunkset_machine_presence rows specified
# Return value:
#     A reference to an associative array of trunkset_machine_presence.device =>
#        machine.host_name
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_device_trunkset_presence {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @lfields, $lwhere, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('trunkset_machine_presence.trunk_set', 'trunk_set.name');
  $lwhere = 'trunkset_machine_presence.trunk_set = trunk_set.id';
  $where = ($where eq '' ? $lwhere : $where." AND ".$lwhere);

  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "trunk_set, trunkset_machine_presence", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;

  return \%rbdata;
}

1;
