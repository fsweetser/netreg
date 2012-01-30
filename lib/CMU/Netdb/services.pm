#   -*- perl -*-
#
# CMU::Netdb::services
# This module provides the necessary API functions for
# manipulating the service* tables.
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
# $Id: services.pm,v 1.31 2008/05/22 20:08:30 vitroth Exp $
#
# Revision 1.29  2007/08/31 15:13:35  fk03
# Fixed bug that was causing failures in verification of attribute data from
# being reported.
#
# $Id: services.pm,v 1.31 2008/05/22 20:08:30 vitroth Exp $
# Fixed cut/paste error in error message from delete_attribute.
#
# $Log: services.pm,v $
# Revision 1.31  2008/05/22 20:08:30  vitroth
# removed an extraneous piece that never ran (after a return statement)
#
# Revision 1.30  2008/03/27 19:42:35  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.29.4.2  2008/02/06 20:09:22  vitroth
# added list_services_ref
#
# Revision 1.29.4.1  2007/10/11 20:59:39  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.29.2.1  2007/09/20 18:43:04  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.4  2007/06/05 20:56:50  kcmiller
# * updating to match netreg1
#
# Revision 1.3  2005/08/14 04:26:08  kcmiller
# * Syncing to mainline
#
# Revision 1.23  2005/07/25 22:03:13  vitroth
# list_service_full_ref no longer returns attributes unless the user has
# greater then level 1 read access
#
# Revision 1.22  2004/11/08 12:34:31  vitroth
# Added support to both the API and Web UI for attributes on outlets,
# subnets and vlans.
#
# Added generic attribute type add/view interface at top level.
#
# Added set_attribute API, which allows attributes with ntimes == 1
# to be set by applications in a single call.  (i.e. an attribute which
# can only exist once on a object can be set via set_attribute, without
# the application needing to know if its already set.)
#
# Added custom UI for port-speed and port-duplex attributes on outlets.
# If those attributes exist, we present them to the user as if they
# are additional columns on the outlet table.  Since WebInt is merely
# an application using the API, albeit the *primary* application, this doesn't
# violate the model that nothing internal to the API may refer to specific
# attribute types.
#
# Revision 1.21  2004/09/01 11:09:03  vitroth
# Fixed a bug where it wasn't checking the right object for access when
# deleting service member attributes.
#
# Revision 1.20  2004/06/24 02:05:32  kevinm
# * Credentials/machine type pulled to head
#
# Revision 1.19.6.1  2004/06/21 15:53:40  vitroth
# Merging credentials & machine type permissions branches.
# Inital merge complete, no testing done yet.
# Still need to update convert script and schema.
#
# Revision 1.19.2.1  2004/06/11 18:27:16  kevinm
# * User credentials changes
#
# Revision 1.19  2004/05/21 18:16:25  kevinm
# * Removed trailing spaces froml table names in ::list calls
#
# Revision 1.18  2003/11/20 18:51:40  vitroth
# More places where an update is done as netreg, so we need to start the log
# by hand if it isn't already started, to make sure the correct user is logged.
#
# Revision 1.17  2003/11/14 15:48:23  vitroth
# Extensive changes to add logging of all database updates.
# The most important change is that $dbh->{'mysql_insertid'} should no longer
# be used after calling a primitive, as the primitives now do multiple
# inserts into the logging tables.  Use $CMU::Netdb::primitives::db_insertid
# instead.
#
# Revision 1.16  2003/03/25 20:27:29  fk03
# Moved random output to debug level 1.
#
# Revision 1.15  2002/10/03 22:34:06  kevinm
# * replacing "print STDERR" with "warn" everywhere
#
# Revision 1.14  2002/09/30 20:08:27  kevinm
# * Cascade deletion changes
#
# Revision 1.13  2002/08/20 21:38:49  kevinm
# * [Bug 1355] Add default protections to zones, buildings, dhcp options, and services.
#
# Revision 1.12  2002/08/20 13:44:01  kevinm
# * Added __FILE__ and __LINE__ to all STDERR output
#
# Revision 1.11  2002/06/12 20:40:14  ebardsle
# fixed type of kevin's ($user -> $dbuser)
#
# Revision 1.10  2002/06/12 17:39:56  kevinm
# * Changed permissions on deleting member from service group
#
# Revision 1.9  2002/03/08 00:56:30  kevinm
# * Redeclaration fixed (Thanks: Mike Nguyen)
#
# Revision 1.8  2002/03/04 06:19:07  kevinm
# * Add DHCP resource information to service dump
#
# Revision 1.7  2002/03/04 00:34:08  kevinm
# * New DHCP Option Type stuff
#
# Revision 1.6  2002/02/21 03:00:46  kevinm
# * Service member changes
#
# Revision 1.5  2002/01/03 20:52:39  kevinm
# Changed service_attribute to attribute everywhere.
#
# Revision 1.4  2001/11/07 18:17:21  kevinm
# Added true values to the bottom of primitives.
#
# Revision 1.3  2001/11/07 18:13:35  kevinm
# Changed debug level.
#
# Revision 1.2  2001/11/06 18:10:12  kevinm
# Added DNS resources to the master ref array we get
#
# Revision 1.1  2001/11/05 21:14:53  kevinm
# Integrating service stuff.
#
#
#


package CMU::Netdb::services;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug
	    @service_fields @service_type_fields @service_membership_fields);
use CMU::Netdb;
use CMU::Netdb::helper;
use CMU::Netdb::primitives;
use CMU::Netdb::structure;
use CMU::Netdb::errors;
use CMU::Netdb::auth;
use CMU::Netdb::validity;
use CMU::Netdb::dns_dhcp;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     list_services 
	     list_services_ref
	     list_service_types 
	     list_service_types_ref
	     list_service_members
	     list_attribute_spec
	     list_attribute
	     list_attribute_spec_ref
	     list_service_full_ref

	     get_service_types
	     get_services_ref
	     get_attribute_spec
	     get_attribute_spec_ref
	     
	     add_service
	     add_service_type
	     add_service_membership
	     add_attribute_spec
	     add_attribute

	     modify_service
	     modify_service_type
	     modify_attribute_spec

	     delete_service
	     delete_service_type
	     delete_service_membership
	     delete_attribute_spec
	     delete_attribute

	     set_attribute
	    );


@service_fields = @CMU::Netdb::structure::service_fields;
@service_type_fields = @CMU::Netdb::structure::service_type_fields;
@service_membership_fields = @CMU::Netdb::structure::service_membership_fields;
@service_type_fields = @CMU::Netdb::structure::service_type_fields;

$debug = 0;

# Function: list_services
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the service table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_services {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "service", \@service_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@service_fields];
  }
  
  @data = @$result;
  unshift @data, \@service_fields;
  
  return \@data;
  
}

# Function: get_services_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (service.name mostly)
# Actions: Queries the database and retrieves the service ID and name 
# Return value:
#     A reference to an associative array of service.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_services_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('service.id', $efield);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "service", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: list_services_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (service.name mostly)
# Actions: Queries the database and retrieves the service ID and name 
# Return value:
#     A reference to an associative array of service.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_services_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('service.id', $efield);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "service", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: list_attribute_spec_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (service.name mostly)
# Actions: Queries the database and retrieves the service attribute ID and field
# Return value:
#     A reference to an associative array of service.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_attribute_spec_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('attribute_spec.id', $efield);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "attribute_spec", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}


# Function: list_service_types_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (service_type.name mostly)
# Actions: Queries the database and retrieves the service_type ID and name 
# Return value:
#     A reference to an associative array of service_type.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_service_types_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('service_type.id', $efield);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "service_type", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Function: list_service_types
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the service_type table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_service_types {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "service_type", \@service_type_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@service_type_fields];
  }
  
  @data = @$result;
  unshift @data, \@service_type_fields;
  
  return \@data;
}

# Function: get_attribute_spec_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#     The field to get (service.name mostly)
# Actions: Queries the database and retrieves the service attribute ID and field
# Return value:
#     A reference to an associative array of service.id => $efield
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_attribute_spec_ref {
  my ($dbh, $dbuser, $where, $efield) = @_;
  my ($result, @lfields, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('attribute_spec.id', $efield);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "attribute_spec", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}

# Functions: get_attribute_spec
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the attribute table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_attribute_spec {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  my @fields = (@CMU::Netdb::structure::attribute_spec_fields);
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "attribute_spec", \@fields, $where);

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


# Function: get_service_types
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the service_type table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_service_types {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "service_type", \@service_type_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@service_type_fields];
  }
  
  @data = @$result;
  unshift @data, \@service_type_fields;
  
  return \@data;
}

# Function: list_service_members
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the service table, joined to the service_membership and machine 
#          tables, which conform to the WHERE clause (if any)
# Return value:
#    - Result code (see CMU::Netdb::errors.pm) -- number of rows or error code
#    If result == error:
#      - fields
#    Else:
#      - reference to MemberRow (see below for format)
#      - reference to MemberSummary (see below for format)
#      - reference to MemberData (see below for format)
sub list_service_members {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, @fields, $mywhere);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  # More complicated than with just machine members. First we're going to get the
  # membership list out of service_membership, then query the corresponding tables
  # one at a time to get the membership data.
  @fields = @service_fields;
  push @fields, @service_membership_fields;
  
  $mywhere = "service.id = service_membership.service ";
  $mywhere .= " AND $where " if ($where ne '');
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "service, service_membership",
					 \@fields, $mywhere);
  
  if (!ref $result) { 
    return ($result, []);
  }
  
  if ($#$result == -1) {
    return (0, {}, {}, {});
  }
  
  my $RowCount = $#$result+1;
  
  # MemberRow:
  #  hash of service_mem.id => { 'service_membership.id' => ID, etc. }
  my %MemberRow;
  
  # MemberSummary: 
  #  hash of member_type => [member_tid, member_tid, etc]
  my %MemberSummary;
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "Row Count: $RowCount\n" if ($debug >= 1);
  my %fieldPos = %{CMU::Netdb::makemap(\@fields)};
  foreach my $Row (@$result) {
    push(@{$MemberSummary{$Row->[$fieldPos{'service_membership.member_type'}]}},
	 $Row->[$fieldPos{'service_membership.member_tid'}]);
    my $Key = $Row->[$fieldPos{'service_membership.id'}];
    $MemberRow{$Key} = {};
    
    foreach (@fields) {
      $MemberRow{$Key}->{$_} = $Row->[$fieldPos{$_}];
    }
  }
  
  # Now go through all the member table types and load the data from them
  # MemberData:
  #  hash of 'table:id' => ('machine.host_name' => FOO, 
  #                         'machine.ip_address' => BAR, etc)
  my %MemberData;
  foreach my $Table (keys %MemberSummary) {
    my @fields;
    {
      no strict 'refs';
      my $ar_name = 'CMU::Netdb::structure::'.$Table.'_fields';
      @fields = @$ar_name;
    }
    
    my $Where = " $Table.id IN (".join(',', @{$MemberSummary{$Table}}).") ";
    $result = CMU::Netdb::primitives::list($dbh, $dbuser, $Table,
					   \@fields, $Where);
    if (!ref $result) {
      return ($result, [$Table]);
    }
    my %TablePos = %{CMU::Netdb::makemap(\@fields)};
    
    foreach my $Line (@$result) {
      my $Key = "$Table:".$Line->[$TablePos{"$Table.id"}];
      $MemberData{$Key} = {};
      foreach (@fields) {
	$MemberData{$Key}->{$_} = $Line->[$TablePos{$_}];
      }
    }      
  }
  
  ## Okay, all member data is loaded and ready to send back
  return ($RowCount, \%MemberRow, \%MemberSummary, \%MemberData);
}

sub service_member_table_join {
  my @Arr = @CMU::Netdb::structure::service_member_types;
  
  return (" ( ".join(" OR ", map { 
    " ( service_membership.member_type = '$_' AND ".
      "service_membership.member_tid = $_.id )"
    } @Arr )." ) ", join(", ", @Arr));
}

# Function: add_service
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_service {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@service_fields) {
    my $nk = $key;		# required because $key is a reference into service_fields
    $nk =~ s/^service\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^service\.$key$/, @service_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find service.$key!\n".join(',', @service_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("service.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "service.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"service.$key"} = $$fields{$key};
  }
  
  # verify service_type exists and we have ADD access to it
  my $scr;
  $scr = CMU::Netdb::get_service_types($dbh, $dbuser, "service_type.id = '$$newfields{'service.type'}'");
  return ($CMU::Netdb::errcodes{ENOENT}, ['type']) if (!ref $scr || !defined $scr->[1]);
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'service', $newfields);
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
      ($dbh, $dbuser, 'admin_default_add', 'service',
       $warns{insertID}, '', {});
    
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "service/$warns{insertID}: ".join(',', @$AErrf)."\n";
      CMU::Netdb::xaction_rollback($dbh);
      return ($ARes, $AErrf);
    }
  }
  return ($res, \%warns);
}


# Function: add_service_type
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_service_type {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@service_type_fields) {
    my $nk = $key;		# required because $key is a reference into service_type_fields
    $nk =~ s/^service_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^service_type\.$key$/, @service_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find service_type.$key!\n".join(',', @service_type_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("service_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "service_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"service_type.$key"} = $$fields{$key};
  }
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'service_type', $newfields);
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
      ($dbh, $dbuser, 'admin_default_add', 'service_type',
       $warns{insertID}, '', {});
    
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "service_type/$warns{insertID}: ".join(',', @$AErrf)."\n";
      CMU::Netdb::xaction_rollback($dbh);
      return ($ARes, $AErrf);
    }
  }
  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($res, \%warns);
}


# Function: add_service_membership
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_service_membership {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@service_membership_fields) {
    my $nk = $key;		# required because $key is a reference into service_membership_fields
    $nk =~ s/^service_membership\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^service_membership\.$key$/, @service_membership_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find service_membership.$key!\n".join(',', @service_membership_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("service_membership.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "service_membership.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"service_membership.$key"} = $$fields{$key};
  }
  
  # verify service & member exist
  my $Table = $$newfields{"service_membership.member_type"};
  {
    my $scr;
    $scr = CMU::Netdb::primitives::list($dbh, $dbuser, $Table, 
					["$Table.id"], 
					"$Table.id = '".
					$$newfields{"service_membership.member_tid"}."'");
    
    return ($CMU::Netdb::errcodes{ENOENT}, ['member_tid', $scr]) if (!ref $scr || !defined $scr->[0]);
    
    $scr = CMU::Netdb::get_services_ref($dbh, $dbuser, "service.id = '$$newfields{'service_membership.service'}'", 'service.name');
    return ($CMU::Netdb::errcodes{ENOENT}, ['service']) if (!ref $scr || !defined $scr->{$$newfields{'service_membership.service'}});
  }
  
  # verify permissions on service & member
  my ($rl, $al);
  $rl = CMU::Netdb::get_read_level($dbh, $dbuser, $Table, 
				   $$newfields{'service_membership.member_tid'});
  return ($errcodes{EPERM}, [$Table]) if ($rl < 1);
  $al = CMU::Netdb::get_add_level($dbh, $dbuser, 'service', 
				  $$newfields{'service_membership.service'});
  return ($errcodes{EPERM}, ['service']) if ($al < 1);
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'service_membership', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
}


# Function: modify_service
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
sub modify_service {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('service.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['service.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('service.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['service.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@service_fields) {
    my $nk = $key;		# required because $key is a reference into service_fields
    $nk =~ s/^service\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^service\.$key$/, @service_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find service.$key!\n".join(',', @service_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("service.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "service.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"service.$key"} = $$fields{$key};
  }
  
  ## Do not allow the type to change... too much involvement with attributes, etc.
  my $res = CMU::Netdb::list_services($dbh, $dbuser, "service.id = $id");
  return ($errcodes{EDB}, ['id']) if (!ref $res);
  return ($errcodes{ENOENT}, ['id']) if (!defined $res->[1]);
  my %serv_pos = %{CMU::Netdb::makemap($res->[0])};
  
  return ($errcodes{EINUSE}, ['type']) if ($$newfields{"service.type"} ne 
					   $res->[1]->[$serv_pos{'service.type'}]);
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'service', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM service WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::services::modify_service: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::services::modify_service: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
  
}

# Function: modify_service_type
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
sub modify_service_type {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('service_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['service_type.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('service_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['service_type.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@service_type_fields) {
    my $nk = $key;		# required because $key is a reference into service_type_fields
    $nk =~ s/^service_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^service_type\.$key$/, @service_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find service_type.$key!\n".join(',', @service_type_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("service_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "service_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"service_type.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'service_type', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM service_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::services::modify_service_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::services::modify_service_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
  
}

# Function: delete_service
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the config to delete.
#     The 'version' of the config to delete.
# Actions: Verifies authorization and deletes the entry
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_service {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $retref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser'])
    if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('service.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) 
    if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('service.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) 
    if (CMU::Netdb::getError($version) != 1);
  
  ($result, $retref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'service', $id, $version);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM service WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::services::delete_service: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::services::delete_service: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $retref);
    }
  }
  
  return ($result, []);
}

# Function: delete_service_type
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the config to delete.
#     The 'version' of the config to delete.
# Actions: Verifies authorization and deletes the entry
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_service_type {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('service_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('service_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'service_type', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM service_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::services::delete_service_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::services::delete_service_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}


# Function: delete_service_membership
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the server to delete.
#     The 'version' of the server to delete.
# Actions: Verifies authorization and deletes the entry
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_service_membership {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('service_membership.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('service_membership.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## If you have ADD access to the service, then you can delete the member
  my ($mach, $rMemRow, $rMemSum, $rMemData) = 
    CMU::Netdb::list_service_members($dbh, 'netreg', 
				     "service_membership.id = '$id'");
  my $ul = 0;
  if ($mach > 0) {
    $ul = CMU::Netdb::get_add_level($dbh, $dbuser, 'service', 
				    $rMemRow->{$id}->{'service.id'});
  }
  return ($errcodes{EPERM}, ['service']) if ($ul < 1);
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  # since we're running this as netreg, start the changelog as the real user first.
  CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, 'netreg', 'service_membership', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM service_membership WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::dns_dhcp::delete_service_membership: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::dns_dhcp::delete_service_membership: id/version were stale\n" if ($debug);
      CMU::Netdb::xaction_rollback($dbh);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      CMU::Netdb::xaction_rollback($dbh);
      return ($result, $dref);
    }
  }

  CMU::Netdb::xaction_commit($dbh, $xref);  
  return ($result, []);
  
}

# Function: add_attribute_spec
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_attribute_spec {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@CMU::Netdb::structure::attribute_spec_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_presence
    $nk =~ s/^attribute_spec\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^attribute_spec\.$key$/, @CMU::Netdb::structure::attribute_spec_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find attribute_spec.$key!\n".join(',', @CMU::Netdb::structure::attribute_spec_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("attribute_spec.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "attribute_spec.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"attribute_spec.$key"} = $$fields{$key};
  }	  
  
  ## Verify that the type we're trying to add exists and we have ADD access
  my $scope = $$newfields{'attribute_spec.scope'};
  
  if ($scope eq 'service_membership' || $scope eq 'service') {
    my $scr;
    $scr = CMU::Netdb::get_service_types($dbh, $dbuser, "service_type.id = '$$newfields{'attribute_spec.type'}'");
    return ($CMU::Netdb::errcodes{ENOENT}, ['type']) if (!ref $scr || !defined $scr->[1]);
  }else{
    $$newfields{'attribute_spec.type'} = 0;
  }

  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'attribute_spec', $newfields);
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
      ($dbh, $dbuser, 'admin_default_add', 'attribute_spec',
       $warns{insertID}, '', {});

    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "attribute_spec/$warns{insertID}: ".join(',', @$AErrf)."\n";
      CMU::Netdb::xaction_rollback($dbh);
      return ($ARes, $AErrf);
    }
  }

  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($res, \%warns);
}

# Function: set_attribute
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Sets the named attribute as desired, regardless of whether or not
#     the attribute already exists.  Only works if the attribute_spec sets the maximum
#     attribute count to 1.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub set_attribute {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  if (! $fields->{spec} ) {
    return ($errcodes{"EINVALID"}, ['attribute.spec']);
  }

  if (! $fields->{owner_tid} ) {
    return ($errcodes{"EINVALID"}, ['attribute.owner_tid']);
  }

  $fields->{spec} = CMU::Netdb::valid("attribute.spec", $fields->{spec}, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($fields->{spec}), ['attribute.spec']) 
    if (CMU::Netdb::getError($fields->{spec}) != 1);

  my $spec = CMU::Netdb::list_attribute_spec_ref($dbh, $dbuser, "attribute_spec.id = $fields->{spec}", 'attribute_spec.ntimes');

  if (!ref $spec) {
    return $spec;
  } elsif (!defined $spec->{$fields->{spec}}) {
    return ($errcodes{"EINVALID"}, ['attribute.spec']);
  } elsif ($spec->{$fields->{spec}} != 1) {
    return ($errcodes{"EINVALID"}, ['attribute_spec.ntimes']);
  } else {
    my $attrs = CMU::Netdb::list_attribute($dbh, $dbuser, "attribute.spec = $fields->{spec} AND attribute.owner_tid = $fields->{'owner_tid'}");
    if (!ref $attrs) {
      return $attrs;
    } elsif ($#$attrs == 0) {
      return CMU::Netdb::add_attribute($dbh, $dbuser, $fields);
    } else {
      my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
      if ($xres == 1){
	$xref = shift @{$xref};
      }else{
	return ($xres, $xref);
      }
      my $attrmap = CMU::Netdb::makemap($attrs->[0]);
      my $id = $attrs->[1][$attrmap->{'attribute.id'}];
      my $version = $attrs->[1][$attrmap->{'attribute.version'}];

      my ($res, $ref) = CMU::Netdb::delete_attribute($dbh, $dbuser, $id, $version);
      if ($res != 1) {
	CMU::Netdb::xaction_rollback($dbh);
	return ($res, $ref);
      }

      ($res, $ref) = CMU::Netdb::add_attribute($dbh, $dbuser, $fields);
      if($res != 1) {
	CMU::Netdb::xaction_rollback($dbh);
      } else {
	CMU::Netdb::xaction_commit($dbh, $xref);
      }
      return ($res, $ref);
    }
  }
}


# Function: add_attribute
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_attribute {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@CMU::Netdb::structure::attribute_fields) {
    my $nk = $key;		# required because $key is a reference into subnet_presence
    $nk =~ s/^attribute\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^attribute\.$key$/, @CMU::Netdb::structure::attribute_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find attribute.$key!\n".join(',', @CMU::Netdb::structure::attribute_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("attribute.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "attribute.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"attribute.$key"} = $$fields{$key};
  }	  
  
  # verify owner/tid exists and we have ADD access to the service
  {
    my $id = $$newfields{'attribute.owner_tid'};
    if ($$newfields{'attribute.owner_table'} eq 'service_membership') {
      my ($mach, $rMemRow, $rMemSum, $rMemData) = 
	CMU::Netdb::list_service_members($dbh, $dbuser, "service_membership.id = '$id'");
      
      return ($errcodes{EDB}, ['owner_table']) if ($mach < 0);
      return ($errcodes{ENOENT}, ['owner_tid']) if ($mach < 1);
      warn __FILE__, ':', __LINE__, ' :>'.
	"add_attribute: SERVICE ID $rMemRow->{$id}->{'service.id'}\n" if ($debug);
      my $ul = CMU::Netdb::get_add_level($dbh, $dbuser, 'service', 
					 $rMemRow->{$id}->{'service.id'});
      return ($errcodes{EPERM}, ['owner_table']) if ($ul < 1);
    }elsif($$newfields{'attribute.owner_table'} eq 'service') {
      my $serv = CMU::Netdb::get_services_ref($dbh, $dbuser, " service.id = \'$id\' ", 
					      'service.name');
      return ($errcodes{EDB}, ['owner_table']) if (!ref $serv);
      return ($errcodes{ENOENT}, ['owner_tid']) if (!defined $serv->{$id});
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'service', $id);
      return ($errcodes{EPERM}, ['owner_tid']) if ($ul < 1);
    }elsif($$newfields{'attribute.owner_table'} eq 'users') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'users', $id);
      return ($errcodes{EPERM}, ['owner_tid']) if ($ul < 1);
    }elsif($$newfields{'attribute.owner_table'} eq 'groups') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'groups', $id);
      return ($errcodes{EPERM}, ['owner_tid']) if ($ul < 5);
    }elsif($$newfields{'attribute.owner_table'} eq 'outlet') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', $id);
      return ($errcodes{EPERM}, ['owner_tid']) if ($ul < 1);
      $ul = CMU::Netdb::get_add_level($dbh, $dbuser, 'attribute_spec',
				      $$newfields{'attribute.spec'});
      warn "Add level for attribute_spec is $ul\n" if ($debug > 2);
      return ($errcodes{EPERM}, ['spec']) if ($ul < 1);
    }elsif($$newfields{'attribute.owner_table'} eq 'vlan') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'vlan', $id);
      return ($errcodes{EPERM}, ['owner_tid']) if ($ul < 1);
    }elsif($$newfields{'attribute.owner_table'} eq 'subnet') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'subnet', $id);
      return ($errcodes{EPERM}, ['owner_tid']) if ($ul < 1);
    }elsif($$newfields{'attribute.owner_table'} eq 'machine') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'machine', $id);
      return ($errcodes{EPERM}, ['owner_tid']) if ($ul < 1);
    }else{
      return ($errcodes{ENOENT}, ['owner_table']);
    }
  }    
  
  # verify the data meets the format
  {
    my $specID = $$newfields{'attribute.spec'};
    my $format = CMU::Netdb::list_attribute_spec_ref($dbh, $dbuser,
						     " attribute_spec.id = \'$specID\' ",
						     'attribute_spec.format');
    return ($errcodes{EDB}, ['data']) if (!ref $format);
    return ($errcodes{ENOENT}, ['data']) if (!defined $format->{$specID});
    my ($res, $str) = CMU::Netdb::validity::verify_attr_data($$newfields{'attribute.data'},
							     $format->{$specID});
    return ($res, ['data']) if ($res != 1);
  }
  
  # verify that ntimes constraints are met
  {
    my $specID = $$newfields{'attribute.spec'};
    my $ot = $$newfields{'attribute.owner_table'};
    my $tid = $$newfields{'attribute.owner_tid'};
    my $ntimes = CMU::Netdb::list_attribute_spec_ref
      ($dbh, $dbuser,
       " attribute_spec.id = \'$specID\' ",
       ' attribute_spec.ntimes');
    
    return ($errcodes{EDB}, ['data']) if (!ref $ntimes);
    return ($errcodes{ENOENT}, ['data']) if (!defined $ntimes->{$specID});
    my $nt = $ntimes->{$specID};
    
    if ($nt != 0) {
      ## Select the number from the database as a count
      my $rref = CMU::Netdb::primitives::count
	($dbh, $dbuser, 'attribute', 
	 " attribute.spec = \'$specID\' AND ".
	 "attribute.owner_table = '$ot' AND ".
	 " attribute.owner_tid = '$tid' ".
	 ' GROUP BY (attribute.spec) ');
      
      return ($errcodes{EDB}, ['ntimes']) if (!ref $rref || !defined $rref->[0]);
      return ($errcodes{ENUMATTRS}, ['ntimes']) if ($rref->[0] >= $nt);
    }
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'attribute', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
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
  
  $id = CMU::Netdb::valid('subnet_presence.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet_presence.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'subnet_presence', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM subnet_presence WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_subnet_presence: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_subnet_presence: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# Functions: list_attribute
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the attribute table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)

# NOTE: NOT SAFE FOR EXPORT TO SOAP
# Because of overbroad permissions on attributes table, exporting this to soap
# would expose DDNS keys from service groups!
# FIXME FIXME FIXME

sub list_attribute {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  if ($where ne '') {
    $where = "attribute.spec = attribute_spec.id AND " . $where;
  }else{
    $where = " attribute.spec = attribute_spec.id ";
  }
  
  my @fields = (@CMU::Netdb::structure::attribute_fields,
		@CMU::Netdb::structure::attribute_spec_fields);
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "attribute, ".
					 " attribute_spec", 
					 \@fields, $where);
  
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

# Functions: list_attribute_spec
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the attribute table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_attribute_spec {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  my @fields = (@CMU::Netdb::structure::attribute_spec_fields);
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "attribute_spec", \@fields, $where);
  
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

# Function: modify_attribute_spec
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
sub modify_attribute_spec {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('subnet.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('subnet.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@CMU::Netdb::structure::attribute_spec_fields) {
    my $nk = $key;		# required because $key is a reference into array
    $nk =~ s/^attribute_spec\.//;
    $$fields{$nk} = ''
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^attribute_spec\.$key$/, @CMU::Netdb::structure::attribute_spec_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find attribute_spec.$key!\n".join(',', @CMU::Netdb::structure::attribute_spec_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("attribute_spec.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "attribute_spec.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"attribute_spec.$key"} = $$fields{$key};
  }
  
  ## Verify that the type we're trying to add exists and we have ADD access
  my $scope = $$newfields{'attribute_spec.scope'};
  if ($scope eq 'service_membership' || $scope eq 'service') {
    my $scr;
    $scr = CMU::Netdb::get_service_types($dbh, $dbuser, "service_type.id = '$$newfields{'attribute_spec.type'}'");
    return ($CMU::Netdb::errcodes{ENOENT}, ['type']) if (!ref $scr || !defined $scr->[1]);
  }else{
    $$newfields{'attribute_spec.type'} = 0;
  }
  
  ## See if any of the changes will require us to verify that the spec is not
  ## being violated.
  my $res2 = CMU::Netdb::list_attribute_spec($dbh, $dbuser,
					     "attribute_spec.id = '$id'");
  return ($res2, ['id']) if (!ref $res2);
  return ($CMU::Netdb::errcodes{ENOENT}, ['id']) if (!defined $res2->[1]);
  my %serv_pos = %{CMU::Netdb::makemap($res2->[0])};
  my $ChangeOkay = 1;
  {
    # Type may not be changed
    $ChangeOkay = 0 if ($res2->[1]->[$serv_pos{'attribute_spec.type'}] ne
			$$newfields{'attribute_spec.type'});
    # Desc is fine to change
    # Ntimes is okay to change (well, you could then have a violation, but assume
    #                           they will figure this out)
    # Name is fine to change
    # Format is okay if it includes the old format as well
    $ChangeOkay = 0 if (CMU::Netdb::validity::verify_attr_spec_format_compat($res2->[1]->[$serv_pos{'attribute_spec.format'}],
									     $$newfields{'attribute_spec.format'}) != 1);
    
    # Scope cannot be changed
    $ChangeOkay = 0 if ($res2->[1]->[$serv_pos{'attribute_spec.scope'}] ne
			$$newfields{'attribute_spec.scope'});
    
  }
  
  # Verify that the attribute spec is not in use if ChangeOkay forces us to verify
  if ($ChangeOkay != 1) {
    my $res = CMU::Netdb::list_attribute($dbh, $dbuser, "attribute_spec.id = '$id'");
    return ($res, ['id']) if (!ref $res);
    return ($CMU::Netdb::errcodes{EINUSE}, ['id']) if ($#$res > 0);
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'attribute_spec', $id, $version, $newfields);
  
  if ($result == 0) {		# An error occurred
    $query = "SELECT id FROM attribute_spec WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_attribute_spec: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_attribute_spec: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
}

# Function: delete_attribute_spec
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_attribute_spec {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('attribute_spec.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('attribute_spec.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  my $sref = CMU::Netdb::list_attribute_spec($dbh, $dbuser, "attribute_spec.id='$id'");
  return ($errcodes{EDB}, ['type']) if (!ref $sref);
  
  return ($errcodes{ENOENT}, []) if (!defined $sref->[1]);
  my %stype_pos = %{CMU::Netdb::makemap($sref->[0])};
  my @sdata = @{$sref->[1]};
  
  # Verify that they have access to the service_type
  # FIXME: this looks incorrect, and doesn't deal with non-service attributes
  my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'service_type', $sdata[$stype_pos{'attribute_spec.type'}]);
  return ($errcodes{EPERM}, ['type']) if ($ul < 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'attribute_spec', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM attribute_spec WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_attribute_spec: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_attribute_spec: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
}

# Function: delete_attribute
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_attribute {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('attribute.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('attribute.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);
  
  my $sref = CMU::Netdb::list_attribute($dbh, $dbuser, "attribute.id='$id'");
  return ($errcodes{EDB}, ['type']) if (!ref $sref);
  
  my %stype_pos = %{CMU::Netdb::makemap($sref->[0])};
  return ($errcodes{ENOENT}, []) if (!defined $sref->[1]);
  my @sdata = @{$sref->[1]};
  
  # verify owner/tid exists and we have ADD access to the service
  {
    my $owner_id = $sdata[$stype_pos{'attribute.owner_tid'}];
    my $owner_table = $sdata[$stype_pos{'attribute.owner_table'}];
    my $spec = $sdata[$stype_pos{'attribute.spec'}];
    
    if ($owner_table eq 'service_membership') {
      my ($mach, $rMemRow, $rMemSum, $rMemData) = 
	CMU::Netdb::list_service_members($dbh, $dbuser, "service_membership.id = '$owner_id'");
      
      return ($errcodes{EDB}, ['owner_table']) if ($mach < 0);
      return ($errcodes{ENOENT}, ['owner_tid']) if ($mach < 1);
      warn Data::Dumper->Dump([$rMemRow, $rMemSum, $rMemData], ['rMemRow', 'rMemSum', 'rMemData']) if ($debug > 2);
      warn __FILE__, ':', __LINE__, ' :>'.
	"delete_attribute: SERVICE ID $rMemRow->{$owner_id}->{'service.id'}\n" if ($debug);
      my $ul = CMU::Netdb::get_add_level($dbh, $dbuser, 'service', 
					 $rMemRow->{$owner_id}->{'service.id'});
      return ($errcodes{EPERM}, ['owner_table', 'owner_id']) if ($ul < 1);
    }elsif($owner_table eq 'service') {
      my $serv = CMU::Netdb::get_services_ref($dbh, $dbuser, " service.id = \'$owner_id\' ", 
					      'service.name');
      return ($errcodes{EDB}, ['owner_table']) if (!ref $serv);
      return ($errcodes{ENOENT}, ['owner_tid']) if (!defined $serv->{$owner_id});
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'service', $owner_id);
      return ($errcodes{EPERM}, ['owner_table', 'owner_id']) if ($ul < 1);
    }elsif($owner_table eq 'users') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'users', $owner_id);
      return ($errcodes{EPERM}, ['owner_tid', 'owner_id']) if ($ul < 1);
    }elsif($owner_table eq 'groups') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'groups', $owner_id);
      return ($errcodes{EPERM}, ['owner_tid', 'owner_id']) if ($ul < 5);
    }elsif($owner_table eq 'vlan') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'vlan', $owner_id);
      return ($errcodes{EPERM}, ['owner_tid', 'owner_id']) if ($ul < 1);
    }elsif($owner_table eq 'subnet') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'subnet', $owner_id);
      return ($errcodes{EPERM}, ['owner_tid', 'owner_id']) if ($ul < 1);
    }elsif($owner_table eq 'outlet') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'outlet', $owner_id);
      return ($errcodes{EPERM}, ['owner_tid', 'owner_id']) if ($ul < 1);
      $ul = CMU::Netdb::get_add_level($dbh, $dbuser, 'attribute_spec', $spec);
      return ($errcodes{EPERM}, ['spec']) if ($ul < 1);
    }elsif($owner_table eq 'machine') {
      my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'machine', $owner_id);
      return ($errcodes{EPERM}, ['owner_tid', 'owner_id']) if ($ul < 1);
      $ul = CMU::Netdb::get_add_level($dbh, $dbuser, 'attribute_spec', $spec);
      return ($errcodes{EPERM}, ['spec']) if ($ul < 1);
    }else{
      return ($errcodes{ENOENT}, ['owner_table']);
    }
  }
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'attribute', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM attribute WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_attribute: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_attribute: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# Function: list_service_full_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     Service ID to return information for
# Actions: Returns all of the service information (service info,
#          machines in the service, attributes of the machines,
#          and attributes of the service.
# Return value:
#     A reference to an associative array. Format:
#     %ref:
#        service_name => Name of the service
#        service_desc => Description of the service
#        service_type => Type of the service
#        version      => Version of the service info
#        memberRow    => ref to member row     (from list_service_members)
#        memberSum    => ref to member summary (from list_service_members)
#        memberData   => ref to member data    (from list_service_members)
#        attributes (ref to associative array):     ( attributes of the service )
#          attr_name1 => [attr_val1.1, attr_val1.2] (all attributes of name)
#        member_attr:
#          [member table:id] (ref to associative array):
#            attr_name1 => [attr_val1.1, attr_val1.2] (all attributes of name)
#
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_service_full_ref {
  my ($dbh, $dbuser, $sid) = @_;
  my ($result, @data, $mywhere, $where, $ul);
  
  my %service;
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $sid = CMU::Netdb::valid('service.id', $sid, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($sid) if (CMU::Netdb::getError($sid) != 1);

  $ul = CMU::Netdb::get_read_level($dbh, $dbuser, 'service', $sid);
  return ($errcodes{EPERM}, ['service']) if ($ul < 1);

  my @fields = (@service_fields, 'service_type.name');
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "service, service_type", 
					 \@fields,
					 "service.id = '$sid' AND service.type = service_type.id ");
  return $result if (!ref $result);
  return \%service if ($#$result == -1);
  my %serv_pos = %{CMU::Netdb::makemap(\@fields)};
  
  $service{'service_name'} = $result->[0]->[$serv_pos{'service.name'}];
  $service{'service_desc'} = $result->[0]->[$serv_pos{'service.description'}];
  $service{'service_type'} = $result->[0]->[$serv_pos{'service.type'}];
  $service{'service_type_name'} = $result->[0]->[$serv_pos{'service_type.name'}];
  $service{'version'} = $result->[0]->[$serv_pos{'service.version'}];

  ## Get the members of the service
  my ($msres, $rMemRow, $rMemSum, $rMemData) =
      CMU::Netdb::list_service_members($dbh, $dbuser, "service_membership.service = '$sid'");

  if ($msres < 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	  "Error ($msres) in list_service_members: ".join(',', @$rMemRow)."\n";
  }

  warn __FILE__, ':', __LINE__, ' :>'.
      "list_service_members result: $msres\n" if ($debug >= 1);
  $service{memberRow} = $rMemRow;
  $service{memberSum} = $rMemSum;
  $service{memberData} = $rMemData;

  # Only fetch attributes if the user has read access > 1
  if ($ul > 1) {
    ## Get the attributes of the service
    @fields = (@CMU::Netdb::structure::attribute_fields,
	       @CMU::Netdb::structure::attribute_spec_fields);

    $result = CMU::Netdb::primitives::list($dbh, $dbuser, "service, attribute, attribute_spec",
					   \@fields,
					   "attribute.owner_table = 'service' AND attribute.owner_tid = '$sid' AND attribute.spec = attribute_spec.id AND service.id = attribute.owner_tid");

    return $result if (!ref $result);

    my %serv_attr_pos = %{CMU::Netdb::makemap(\@fields)};

    $service{attributes} = {};
    foreach my $m (@$result) {
      my ($k, $v) = ($m->[$serv_attr_pos{'attribute_spec.name'}],
		     $m->[$serv_attr_pos{'attribute.data'}]);
      push(@{$service{attributes}->{$k}}, $v);
    }

    if ($msres > 0) {
      ## Get the attributes of the members
      $service{member_attr} = {};
      my @memRow = keys %$rMemRow;
      if ($#memRow != -1) {
	@fields = (@CMU::Netdb::structure::attribute_fields,
		   @CMU::Netdb::structure::attribute_spec_fields);

	$where = "attribute.owner_table = 'service_membership' AND ".
	  " attribute.spec = attribute_spec.id AND ".
	    "attribute.owner_tid IN (".join(',', @memRow).") ";

	$result = CMU::Netdb::primitives::list($dbh, $dbuser, "attribute, ".
					       "attribute_spec",
					       \@fields, $where);

	return $result if (!ref $result);

	my %sm_pos = %{CMU::Netdb::makemap(\@fields)};
	$service{member_attr} = {};
	foreach my $m (@$result) {
	  my ($o, $k, $v, $i, $ve) = ($m->[$sm_pos{'attribute.owner_tid'}],
				      $m->[$sm_pos{'attribute_spec.name'}],
				      $m->[$sm_pos{'attribute.data'}],
				      $m->[$sm_pos{'attribute.id'}],
				      $m->[$sm_pos{'attribute.version'}]);
	  my $Key = $rMemRow->{$o}->{'service_membership.member_type'}.":".
	    $rMemRow->{$o}->{'service_membership.member_tid'};
	  push(@{$service{member_attr}->{$Key}->{$k}}, [$v, $i, $ve]);
	}
      }
    }
  }


  ## Get the service's DNS resources
  $where = " dns_resource.owner_type = 'service' AND ".
    "dns_resource.owner_tid = '$sid'";
  $result = CMU::Netdb::list_dns_resources($dbh, 'netreg', $where);
  return $result if (!ref $result);
  
  $service{dnsResPos} = CMU::Netdb::makemap($result->[0]);
  shift(@$result);
  $service{dnsResources} = $result;
  
  ## Get the service's DHCP resources
  $where = " dhcp_option.type = 'service' AND ".
    "dhcp_option.tid = '$sid'";
  $result = CMU::Netdb::list_dhcp_options($dbh, 'netreg', $where);
  return $result if (!ref $result);
  $service{dhcpOptPos} = CMU::Netdb::makemap($result->[0]);
  shift(@$result);
  $service{dhcpOptions} = $result;

  ## Okay, that's it. We've got all the info..
  return \%service;
}

1;
