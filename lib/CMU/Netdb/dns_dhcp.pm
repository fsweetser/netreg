#   -*- perl -*-
#
# CMU::Netdb::dns_dhcp
# This module provides the necessary API functions for
# manipulating the dns and dchp related tables
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


package CMU::Netdb::dns_dhcp;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug @dns_zone_fields @dns_resource_fields 
            @dns_resource_type_fields @dhcp_option_fields @dhcp_option_type_fields );

use CMU::Netdb;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     list_dns_zones list_zone_ref
	     list_dns_resources
	     list_dns_resource_types list_dns_resource_types_ref
	     list_dns_resource_zones
	     list_dhcp_options
	     list_dhcp_option_types
	     list_dhcp_subnet_options
	     list_dhcp_machine_options
	     list_default_dhcp_options
	     
	     get_dns_zones_l5_add
	     get_dns_resource_types
	     get_dhcp_option_types
	     
	     add_dns_zone
	     add_dns_resource
	     add_dns_resource_type
	     add_dhcp_option
	     add_dhcp_option_type
	     
	     modify_dns_zone
	     modify_dns_resource
	     modify_dns_resource_type
	     modify_dhcp_option
	     modify_dhcp_option_type
	     
	     delete_dns_zone
	     delete_dns_resource
	     delete_dns_resource_type
	     delete_dhcp_option
	     delete_dhcp_option_type
	     
	     force_zone_update
	     update_zone_serials
	     getParent
	    );

@dns_zone_fields = @CMU::Netdb::structure::dns_zone_fields;
@dns_resource_fields = @CMU::Netdb::structure::dns_resource_fields;
@dns_resource_type_fields = @CMU::Netdb::structure::dns_resource_type_fields;
@dhcp_option_fields = @CMU::Netdb::structure::dhcp_option_fields;
@dhcp_option_type_fields = @CMU::Netdb::structure::dhcp_option_type_fields;

$debug = 0;

# Function: list_dns_zones
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the dns_zone table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_dns_zones {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dns_zone", \@dns_zone_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@dns_zone_fields];
  }
  
  @data = @$result;
  unshift @data, \@dns_zone_fields;
  
  return \@data;
  
}

## get_dns_zones_l5_add
##  Get all the zones for which the user has level 5 or greater ADD access
## Arguments:
##  - dbh: Database handle
##  - dbuser: The user running the query
##  - where: the where clause for the query
## Returns:
##  errorcode on failure
##  reference to an array of refs to arrays of data
sub get_dns_zones_l5_add {
  my ($dbh, $dbuser, $where) = @_;
  
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  my $pwhere = "P.rlevel >= 5";
  $pwhere .= " AND $where" if ($where);
  
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "dns_zone", \@dns_zone_fields, $pwhere);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@dns_zone_fields];
  }
  
  @data = @$result;
  unshift @data, \@dns_zone_fields;
  
  return \@data;
}

# Function: list_zone_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the dns_zone table which conform to the WHERE clause (if any)
# Return value:
#     FIXME 1: document return values
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_zone_ref {
  my ($dbh, $dbuser, $where, $type) = @_;
  my ($result, %rdata, @fields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @fields = ('dns_zone.id', 'dns_zone.name');
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "list_zone_ref: calling list ($where)\n" if ($debug >= 2);
  if ($type eq 'GET') {
    $result = CMU::Netdb::primitives::get($dbh, $dbuser, "dns_zone", \@fields, $where);
  }else{
    $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dns_zone", \@fields, 
					   $where);
  }
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rdata;
}


# Function: list_dns_resources
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the dns_resource table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_dns_resources {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, $row);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  my @fields;
  push @fields, @dns_resource_fields;
  push @fields, @CMU::Netdb::structure::machine_fields;
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dns_resource LEFT JOIN machine on dns_resource.rname_tid = machine.id", \@fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@fields];
  }
  
  @data = @$result;
  my $pos = CMU::Netdb::makemap(\@fields);
  foreach $row (@data) {
    if (defined $row->[$pos->{'machine.host_name'}]) {
      $row->[$pos->{'dns_resource.rname'}] = $row->[$pos->{'machine.host_name'}];
    }
  }
  
  unshift @data, \@fields;
  
  return \@data;
}

sub list_dns_resource_zones {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $where = 'TRUE' if ($where eq '');
  my $nwhere = "dns_zone.id = dns_resource.name_zone AND $where";
  my @f = (@dns_resource_fields, @dns_zone_fields);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dns_resource, dns_zone", \@f, $nwhere);
  
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

# Function: get_dns_resource_types
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Returns the resources types the user is allowed to insert
#  Calls GET instead of LIST (which checks for ADD)
# Return value:
#     A reference to an associative array containing the type name => id
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_dns_resource_types {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, %rdata, @lfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  
  @lfields = ('dns_resource_type.id', 'dns_resource_type.name');
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "dns_resource_type", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rdata;
  
}

# Function: get_dhcp_option_types
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Returns the resources types the user is allowed to insert
#  Calls GET instead of LIST (which checks for ADD)
# Return value:
#     A reference to an associative array containing the type name => id
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub get_dhcp_option_types {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, %rdata, @lfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  @lfields = ('dhcp_option_type.id', 'dhcp_option_type.name');
  $result = CMU::Netdb::primitives::get($dbh, $dbuser, "dhcp_option_type", \@lfields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rdata;
}

# Function: list_dns_resource_types
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the dns_resource_type table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_dns_resource_types {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dns_resource_type", \@dns_resource_type_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@dns_resource_type_fields];
  }
  
  @data = @$result;
  unshift @data, \@dns_resource_type_fields;
  
  return \@data;
  
}

# Function: list_dns_resource_types_ref
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the dns_resource_type table which conform to the WHERE clause (if any)
# Return value:
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_dns_resource_types_ref {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, %rbdata);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dns_resource_type", ['dns_resource_type.name', 'dns_resource_type.format'], $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return {};
  }
  
  map { $rbdata{$_->[0]} = $_->[1] } @$result;
  
  return \%rbdata;
}


# Function: list_dhcp_option_types
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the dhcp_option_type table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_dhcp_option_types {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dhcp_option_type", \@dhcp_option_type_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@dhcp_option_type_fields];
  }
  
  @data = @$result;
  unshift @data, \@dhcp_option_type_fields;
  
  return \@data;
}


# Function: list_dhcp_options
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     An optional string to be used a WHERE clause
#        i.e. "name = \"FOO.CMU.EDU\""
# Actions: Queries the database in the handle for rows in
#          the dhcp_option table which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_dhcp_options {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, $rwhere, @header);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $rwhere = "dhcp_option.type_id = dhcp_option_type.id";
  $rwhere .= " AND $where" if ($where && $where ne '');
  
  map { push (@header, $_) } @dhcp_option_fields;
  map { push (@header, $_) } @dhcp_option_type_fields;
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dhcp_option, dhcp_option_type", \@header, $rwhere);
  
  if (!ref $result) { 
    return ($result,[]);
  }
  
  if ($#$result == -1) {
    return [\@header];
  }
  
  @data = @$result;
  unshift @data, \@header;
  
  return \@data;
  
}

sub list_dhcp_subnet_options {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, $rwhere, @header);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $rwhere = "dhcp_option.type_id = dhcp_option_type.id AND dhcp_option.type = 'subnet' AND dhcp_option.tid = subnet.id ";
  $rwhere .= " AND $where" if ($where && $where ne '');
  
  map { push (@header, $_) } @dhcp_option_fields;
  map { push (@header, $_) } @dhcp_option_type_fields;
  map { push (@header, $_) } @CMU::Netdb::structure::subnet_fields;
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "dhcp_option, dhcp_option_type, subnet", \@header, $rwhere);
  
  if (!ref $result) { 
    return ($result,[]);
  }
  
  if ($#$result == -1) {
    return [\@header];
  }
  
  @data = @$result;
  unshift @data, \@header;
  
  return \@data;
  
}

sub list_dhcp_machine_options {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data, $rwhere, @header);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  map { push (@header, $_) } @dhcp_option_fields;
  map { push (@header, $_) } @dhcp_option_type_fields;
  map { push (@header, $_) } @CMU::Netdb::structure::machine_fields;
  
  $result = CMU::Netdb::primitives::list
    ($dbh, $dbuser, 
     "machine LEFT JOIN dhcp_option ON dhcp_option.tid = machine.id AND " .
     "dhcp_option.type = 'machine' LEFT JOIN dhcp_option_type ON " .
     "dhcp_option.type_id = dhcp_option_type.id", \@header, $where);
  
  if (!ref $result) { 
    return ($result,[]);
  }
  
  if ($#$result == -1) {
    return [\@header];
  }
  
  @data = @$result;
  unshift @data, \@header;
  
  return \@data;
  
}

# Function: add_dns_zone
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_dns_zone {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  my $level = CMU::Netdb::get_add_level($dbh, $dbuser, 'dns_zone', 0);
  return ($CMU::Netdb::errcodes{EPERM}, ['dns_zone']) if ($level < 9);

  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@dns_zone_fields) {
    my $nk = $key;		# required because $key is a reference into dns_zone_fields
    $nk =~ s/^dns_zone\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Initiating full probe of dns_zone.$key.. Stand by\n" if ($debug >= 2);
    if (! grep /^dns_zone\.$key$/, @dns_zone_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find dns_zone.$key!\n".join(',', @dns_zone_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    unless ($$fields{'type'} =~ /toplevel/) {
      if ($key =~ /soa_/) {
	$$fields{$key} = '';
	next;
      }
    }
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("dns_zone.$key", $$fields{$key}, $dbuser, $level, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "dns_zone.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"dns_zone.$key"} = $$fields{$key};
  }
  {
    my $r = getParent($$newfields{'dns_zone.name'}, $dbh, $dbuser);
    $r = 0 if ($r < 1);
    #return ($CMU::Netdb::errcodes{EDOMAIN}, ['parent']) if ($r < 1);
    $$newfields{'dns_zone.parent'} = $r;
  }
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'dns_zone', $newfields);
  my %warns = (insertID => $CMU::Netdb::primitives::db_insertid);
  if ($res < 1) {
    CMU::Netdb::xaction_rollback($dbh);
    return ($res, []);
  }
  
  ## We successfully added the zone. Now set the parent to itself if
  ## we are a toplevel zone.
  if ($$newfields{'dns_zone.type'} =~ /-toplevel$/) {
    # FIXME should this be logged?  not bothering for now. -vitroth
    $dbh->do("UPDATE dns_zone SET parent = $warns{insertID} WHERE ".
	     "id = $warns{insertID}");
  }

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
      ($dbh, $dbuser, 'zone_admin_default_add', 'dns_zone', $warns{insertID}, 
       '', {});
    
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "dns_zone/$warns{insertID}: ".join(',', @$AErrf)."\n";
    }
  }

  CMU::Netdb::xaction_commit($dbh, $xref);    
  return ($res, \%warns);
}


# Function: add_dns_resource
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_dns_resource {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields, $rlevel);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) 
    if (CMU::Netdb::getError($dbuser) != 1);
  
  $$fields{'name'} = uc($$fields{'name'});
  $$fields{'rname'} = uc($$fields{'rname'});
  
  # need to do a bit more verification for access
  return ($CMU::Netdb::errcodes{EBLANK}, ['type']) 
    if ($$fields{type} eq '');
  
  if ($$fields{owner_type} eq 'machine') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 
					  'machine', $$fields{owner_tid});
    
  }elsif($$fields{owner_type} eq 'dns_zone') {
    # require add level 5 on the zones to add dns resources
    $rlevel = CMU::Netdb::get_add_level($dbh, $dbuser, 'dns_zone', $$fields{owner_tid});
    return ($CMU::Netdb::errcodes{EPERM}, ['tid']) if ($rlevel < 5);
  }elsif($$fields{owner_type} eq 'service') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 
					  'service', $$fields{owner_tid});
    
  }else{
    $rlevel = 1;		# we'll get 'em in the owner_type CMU::Netdb::validity checks
  }
  return ($CMU::Netdb::errcodes{EPERM}, ['tid']) if ($rlevel < 1);  
  
  warn  __FILE__, ':', __LINE__, ' :> add_dns_resource: user level is '.$rlevel."\n" if ($debug >= 1);

  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@dns_resource_fields) {
    my $nk = $key;		
    # required because $key is a reference into dns_resource_fields
    
    $nk =~ s/^dns_resource\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^dns_resource\.$key$/, @dns_resource_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find dns_resource.$key!\n".
	  join(',', @dns_resource_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    if (uc($$fields{'type'}) eq 'SRV' && lc($key) eq 'name') {
      # SRV records are magic, and can have underscores in strange places
      $$fields{$key} = CMU::Netdb::valid("dns_resource.name_srvrecord", 
					 $$fields{$key}, $dbuser, $rlevel, $dbh);
      
    } else {
      $$fields{$key} = CMU::Netdb::valid("dns_resource.$key", 
					 $$fields{$key}, $dbuser, $rlevel, $dbh);
    }
    
    # skip error reporting for rnames associated w/ TXT and HINFO 
    # - XXX test this
    unless (lc($key) eq 'rname' && (uc($$fields{'type'}) eq 'TXT' ||
				    uc($$fields{'type'}) eq 'HINFO' ||
				    uc($$fields{'type'}) eq 'AAAA' ||
				    uc($$fields{'type'}) eq 'LOC' ||
				    uc($$fields{'type'}) eq 'RP' ) ) {
      return (CMU::Netdb::getError($$fields{$key}), [$key]) 
	if (CMU::Netdb::getError($$fields{$key}) != 1);
      
      warn __FILE__, ':', __LINE__, ' :>'.
	"dns_resource.$key: $$fields{$key}\n" if ($debug >= 2);
    } else {			# it is a rname in these specific situations
      $$fields{$key} = '';
    }
    $$newfields{"dns_resource.$key"} = $$fields{$key};
  }	  
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "Got past standard validity checking...\n" if ($debug >= 2);
  
  # verify the type
  my $tyref = list_dns_resource_types
    ($dbh, $dbuser, 
     "dns_resource_type.name = '$$fields{'type'}'");
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "list_dns_resource_type size: ".$#$tyref."\n" if ($debug >= 2);
  return ($CMU::Netdb::errcodes{ENORESTYPE}, ['type']) 
    if (!ref $tyref || !defined $tyref->[1]);
  
  my $format = '-1';
  {
    my $pos = CMU::Netdb::makemap($tyref->[0]);
    $format = $tyref->[1]->[$pos->{'dns_resource_type.format'}] 
      if (defined $pos->{'dns_resource_type.format'});
  }
  return ($CMU::Netdb::errcodes{ENORESTYPE}, ['type']) if ($format eq '-1');
  
  # also need to perform a GET to make sure they can add it..
  # check to see if they need a certain add level (like for dns_zone)
  my $where;
  if ($$fields{'owner_type'} eq 'dns_zone') {
    $where = "AND P.rlevel >= 5";
  }
  $tyref = get_dns_resource_types($dbh, $dbuser, "dns_resource_type.name='$$fields{'type'}' $where");
  return ($CMU::Netdb::errcodes{ENORESTYPE}, ['type']) if (!ref $tyref || !(grep /^$$fields{'type'}$/, values %$tyref));
  
  ## Verify all the DNS fields
  warn __FILE__, ':', __LINE__, ' :>'.
    "format: $format\n" if ($debug >= 2);
  
  if ($format =~ /N/ && $$fields{type} eq 'NS') {
    warn __FILE__, ':', __LINE__, ' :>'.
      "*** rname: $$newfields{'dns_resource.rname'}\n" 
	if ($debug >= 2);
    $$newfields{"dns_resource.rname"} = 
      CMU::Netdb::validity::verify_host($$newfields{"dns_resource.rname"}, 
					'netreg', $rlevel, $dbh);
    
    return (CMU::Netdb::getError($$newfields{"dns_resource.rname"}), 
	    ['rname']) 
      if (CMU::Netdb::getError($$newfields{"dns_resource.rname"}) != 1);
  }
  
  if ($format =~ /M0/) { 
    $$newfields{"dns_resource.rmetric0"} = 
      CMU::Netdb::validity::verify_integer_err_default
	($$newfields{"dns_resource.rmetric0"});
    return (CMU::Netdb::getError($$newfields{"dns_resource.rmetric0"}), 
	    ['rmetric0']) 
      if (CMU::Netdb::getError($$newfields{"dns_resource.rmetric0"}) != 1);
  }
  
  if ($format =~ /M1/) {
    $$newfields{"dns_resource.rmetric1"} = 
      CMU::Netdb::validity::verify_integer_err_default
	($$newfields{"dns_resource.rmetric1"});
    return (CMU::Netdb::getError($$newfields{"dns_resource.rmetric1"}), 
	    ['rmetric1']) 
      if (CMU::Netdb::getError($$newfields{"dns_resource.rmetric1"}) != 1);
  }
  
  if ($format =~ /P/) {
    $$newfields{"dns_resource.rport"} = 
      CMU::Netdb::validity::verify_integer_err_default
	($$newfields{"dns_resource.rport"});
    return (CMU::Netdb::getError($$newfields{"dns_resource.rport"}), 
	    ['rport']) 
      if (CMU::Netdb::getError($$newfields{"dns_resource.rport"}) != 1);
  }
  
  if ($format =~ /T0/) {
    return ($CMU::Netdb::errcodes{EDATA}, ['text0']) 
      if (length($$newfields{"dns_resource.text0"}) < 1);
  }
  
  if ($format =~ /T1/) {
    return ($CMU::Netdb::errcodes{EDATA}, ['text1']) 
      if (length($$newfields{"dns_resource.text1"}) < 1);
  }
  
  #############################################
  # type-specific checking
  
  my $setMachineOwner = '';
  
  # CNAMEs
  if ($$newfields{'dns_resource.type'} eq 'CNAME' ||
      $$newfields{'dns_resource.type'} eq 'ANAME') {
    return ($CMU::Netdb::errcodes{EINCDNSRES}, ['type', 'owner_type']) 
      if (($$newfields{'dns_resource.owner_type'} ne 'machine') && 
	  ($$newfields{'dns_resource.owner_type'} ne 'service'));
    
    # verify that 'name' is really a hostname
    $$newfields{'dns_resource.name'} = 
      CMU::Netdb::validity::verify_hostname_zone_lookup
	($$newfields{'dns_resource.name'}, $dbuser, $rlevel, $dbh);
    
    return (CMU::Netdb::getError($$newfields{'dns_resource.name'}), ['name']) 
      if (CMU::Netdb::getError($$newfields{'dns_resource.name'}) != 1);
    
    # verify that 'name' is unique
    return ($CMU::Netdb::errcodes{EEXISTS}, ['name']) 
      unless ($$newfields{'dns_resource.type'} eq 'ANAME' ||
	      CMU::Netdb::machines_subnets::check_host_unique
	      ($dbh, $dbuser, 
	       {'machine.host_name' => $$newfields{'dns_resource.name'}, 
		'machine.mac_address' => '01'}, 0));
    
    # verify the zone exists and they can add items to this zone
    $$newfields{'dns_resource.name'} = 
      CMU::Netdb::validity::valid('machine.host_name', 
				  $$newfields{'dns_resource.name'}, 
				  $dbuser, $rlevel, $dbh); 
    
    # set rname to owner_tid.host_name
    if ($$newfields{'dns_resource.owner_type'} eq 'machine') {
      $setMachineOwner = 'rname';
      
    } elsif ($$newfields{'dns_resource.owner_type'} eq 'service') {
      $setMachineOwner = 'rname';
      my $sref = CMU::Netdb::list_services
	($dbh, $dbuser, 
	 "service.id = '".$$newfields{'dns_resource.owner_tid'}."'");
      
      return ($CMU::Netdb::errcodes{ENOENT}, ['service']) 
	if (!ref $sref || !defined $sref->[1]);
    }
  }
  
  # NS records
  if ($$newfields{'dns_resource.type'} eq 'NS') {
    return ($CMU::Netdb::errcodes{EINCDNSRES}, ['type', 'owner_type']) 
      if ($$newfields{'dns_resource.owner_type'} ne 'dns_zone');
    
    # set the name to the dns_zone name
    my $where = "dns_zone.id = '".$$newfields{'dns_resource.owner_tid'}."'";
    my $miref = list_zone_ref($dbh, $dbuser, $where);
    return ($CMU::Netdb::errcodes{EDOMAIN}, ['name']) if (!ref $miref);
    
    $$newfields{'dns_resource.name'} = 
      $$miref{$$newfields{'dns_resource.owner_tid'}};
    
    return ($CMU::Netdb::errcodes{EDOMAIN}, ['name']) 
      if ($$newfields{'dns_resource.rname'} eq '');
  }
  
  # MX/AFSDB records
  if ($$newfields{'dns_resource.type'} eq 'MX' ||
      $$newfields{'dns_resource.type'} eq 'AFSDB') {
    # set the name as appropriate
    if ($$newfields{'dns_resource.owner_type'} eq 'dns_zone') {
      my $where = "dns_zone.id = '".$$newfields{'dns_resource.owner_tid'}."'";
      my $miref = list_zone_ref($dbh, $dbuser, $where);
      return ($CMU::Netdb::errcodes{EDOMAIN}, ['name']) if (!ref $miref);
      $$newfields{'dns_resource.name'} = 
	$$miref{$$newfields{'dns_resource.owner_tid'}};
      return ($CMU::Netdb::errcodes{EDOMAIN}, ['name']) 
	if ($$newfields{'dns_resource.rname'} eq '');
      
    }elsif ($$newfields{'dns_resource.owner_type'} eq 'service') {
      my $sref = CMU::Netdb::list_services
	($dbh, $dbuser, 
	 "service.id = '".$$newfields{'dns_resource.owner_tid'}."'");
      
      return ($CMU::Netdb::errcodes{ENOENT}, ['service']) 
	if (!ref $sref || !defined $sref->[1]);
      $setMachineOwner = 'name';
      
    } else {
      
      # ASSUME machine
      $setMachineOwner = 'name';
    }
  }
  
  # TXT
  if ($$newfields{'dns_resource.type'} eq 'TXT') {
    if ($$newfields{'dns_resource.owner_type'} eq 'machine') {
      $setMachineOwner = 'name';
    } elsif ($$newfields{'dns_resource.owner_type'} eq 'dns_zone') {
      $setMachineOwner = '';
    } else {
      return ($CMU::Netdb::errcodes{EINCDNSRES}, ['type', 'owner_type']);
    }
  }
 
  # SRV
  if ($$newfields{'dns_resource.type'} eq 'SRV') {
    return ($CMU::Netdb::errcodes{EINCDNSRES}, ['type', 'owner_type']) 
      if ($$newfields{'dns_resource.owner_type'} ne 'machine' &&
	  $$newfields{'dns_resource_owner_type'} ne 'service');
    
    #    $$newfields{'dns_resource.name'} = 
    #      CMU::Netdb::validity::valid
    #	('machine.host_name', 
    #	 $$newfields{'dns_resource.name'}, $dbuser, 1, $dbh); 
    # set rname to the owner machine hostname
    $setMachineOwner = 'rname';
  }
  
  # AAAA/LOC
  if ($$newfields{'dns_resource.type'} eq 'AAAA' ||
      $$newfields{'dns_resource.type'} eq 'LOC') {
    $setMachineOwner = 'name';
  }
  
  # HINFO
  if ($$newfields{'dns_resource.type'} eq 'HINFO') {
    return ($CMU::Netdb::errcodes{EINCDNSRES}, ['type', 'owner_type']) 
      if ($$newfields{'dns_resource.owner_type'} ne 'machine');
    $setMachineOwner = 'name';
  }

  # RP
  if ($$newfields{'dns_resource.type'} eq 'RP') {
    return ($CMU::Netdb::errcodes{EINCDNSRES}, ['type', 'owner_type'])
      if ($$newfields{'dns_resource.owner_type'} ne 'machine');
    $setMachineOwner = 'name';

    # Perform additional basic validity checking against the RP fields
    # force a dot at the end
    my $T0 = CMU::Netdb::valid('dns_resource.text0_rp', 
			       $$newfields{'dns_resource.text0'}, 
			       $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($T0), ['text0'])
      if (CMU::Netdb::getError($T0) != 1);

    my $T1 = CMU::Netdb::valid('dns_resource.text1_rp', 
			       $$newfields{'dns_resource.text1'},
			       $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($T1), ['text1'])
      if (CMU::Netdb::getError($T1) != 1);
   
    $$newfields{'dns_resource.text0'} = $T0.'.';
    $$newfields{'dns_resource.text1'} = $T1.'.';
  } 
  
  # set the name/rname field as necessary
  if ($setMachineOwner ne '') {
    if ($$newfields{'dns_resource.owner_type'} ne 'service') {
      warn __FILE__, ':', __LINE__, ' :>'.
	"** Set Machine owner: ($setMachineOwner) ".
	  "$$newfields{'dns_resource.owner_tid'}\n" if ($debug >= 2);
      
      my $where = "machine.id = '".$$newfields{'dns_resource.owner_tid'}."'";
      my $miref = CMU::Netdb::machines_subnets::list_machines
	($dbh, $dbuser, $where);
      return ($CMU::Netdb::errcodes{EHOST}, [$setMachineOwner]) 
	if (!ref $miref || !defined $miref->[1]);
      
      my $map = CMU::Netdb::makemap($miref->[0]);
      $$newfields{"dns_resource.$setMachineOwner"} = 
	$miref->[1]->[$map->{'machine.host_name'}];
      
      $$newfields{"dns_resource.rname_tid"} = 
	$miref->[1]->[$map->{'machine.id'}] 
	  if ($setMachineOwner eq "rname");
      
      return ($CMU::Netdb::errcodes{EHOST}, [$setMachineOwner]) 
	if ($$newfields{"dns_resource.$setMachineOwner"} eq '');
    } else {
      
      # For services the 'owner' side of the resource must be determined 
      # at zone generation/update time.
      $$newfields{"dns_resource.$setMachineOwner"} = '';
    }
  }
  
  ## final chance for permissions verification (POST name/rname completion)
  # CNAMEs
  if ($$newfields{'dns_resource.type'} eq 'CNAME' ||
      $$newfields{'dns_resource.type'} eq 'ANAME') {
    # if they have level 9 access, they can put a CNAME to whatever zone
    # they have ADD on. Otherwise it restricts them to being in the same
    # zone
    my ($h1, $d1) = CMU::Netdb::splitHostname
      ($$newfields{'dns_resource.name'});
    
    my ($h2, $d2) = CMU::Netdb::splitHostname
      ($$newfields{'dns_resource.rname'});
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "HOSTNAMES: *$d2 *$d1\n" if ($debug >= 2);
    if ($$newfields{'dns_resource.owner_type'} eq 'machine') {
      my $where = "machine.id = '".$$newfields{'dns_resource.owner_tid'}."'";
      my $miref = CMU::Netdb::machines_subnets::list_machines
	($dbh, $dbuser, $where);
      return ($CMU::Netdb::errcodes{EHOST}, ['owner_tid']) 
	if (!ref $miref || !defined $miref->[1]);
      
      my $map = CMU::Netdb::makemap($miref->[0]);
      my $subnet = $miref->[1]->[$map->{'machine.ip_address_subnet'}];
      my $sul = CMU::Netdb::get_add_level($dbh, $dbuser, 'subnet', $subnet);
      my $ldsr = CMU::Netdb::get_domains_for_subnet($dbh, $dbuser, 
                                                    "subnet_domain.domain = '$d1' and subnet_domain.subnet = '$subnet'");
      return ($ldsr, ['name']) if (!ref $ldsr);
      my $ldsc = $#$ldsr;
      return ($CMU::Netdb::errcodes{EPERM}, ['name']) 
        if ($sul < 9 && $ldsc < 0);
    } elsif ($$newfields{'dns_resource.owner_type'} eq 'service') {
      # how should this work?
      return ($CMU::Netdb::errcodes{EPERM}, ['name']) 
        if ($d2 ne $d1 && $rlevel < 9);
    }
  }
  
  ###############################################
  # figure out the name_zone
  { 
    my ($h, $findzone) = ('', '');
    
    if (!(($$newfields{'dns_resource.owner_type'} eq 'service') && 
	  ($$newfields{'dns_resource.name'} eq ''))) {
      return ($CMU::Netdb::errcodes{EINVALID}, ['name']) 
	if ($$newfields{'dns_resource.name'} eq '');
      
      my @hzones;

      if ($$fields{'type'} eq 'SRV') {
        # SRV records are "special" because they're always two components.
        # i.e. _KERBEROS._UDP.EXAMPLE.EDU.  So go two levels up to find 
        # the parent zone
        
	my $h2;
	($h, $findzone) = CMU::Netdb::splitHostname($$newfields{'dns_resource.name'});
	($h2, $findzone) = CMU::Netdb::splitHostname($findzone);
	$h .= $h2;
      } elsif ($$fields{'type'} eq 'NS') {
        # NS records always go up one zone, so start up a level
	if ($$newfields{'dns_resource.owner_type'} eq 'dns_zone') {
	  ($h, $findzone) = CMU::Netdb::splitHostname
	    ($$newfields{'dns_resource.name'});
	}
      } elsif ($$fields{'type'} eq 'CNAME') {
        # CNAMES can't be on zone names, so start up a level
	($h, $findzone) = CMU::Netdb::splitHostname
	  ($$newfields{'dns_resource.name'});
      } else {
        # Other record types can have names which are zone names, so start with
        # the base name.
	$findzone = $$newfields{'dns_resource.name'};
      }
      @hzones = keys 
	%{CMU::Netdb::dns_dhcp::list_zone_ref
	    ($dbh, $dbuser, " dns_zone.name = '$findzone' ")};

      if ($#hzones != 0 && $h eq '') {
	($h, $findzone) = CMU::Netdb::splitHostname
	  ($$newfields{'dns_resource.name'});
	
	@hzones = keys 
	  %{CMU::Netdb::dns_dhcp::list_zone_ref
	      ($dbh, $dbuser, " dns_zone.name = '$findzone' ")};
      }
      return ($CMU::Netdb::errcodes{EDOMAIN}, ['name']) if ($#hzones != 0);
      $$newfields{'dns_resource.name_zone'} = $hzones[0];
    }
  }

  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'dns_resource', 
					$newfields);
  if ($res < 0) {
    CMU::Netdb::xaction_rollback($dbh);
    return ($res, ['prim_add']);
  }
  
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  CMU::Netdb::force_zone_update($dbh, $$newfields{'dns_resource.name_zone'});
  CMU::Netdb::force_zone_update($dbh, $$newfields{owner_tid})
      if ($$newfields{type} == 'dns_zone' && $$newfields{owner_tid} != $$newfields{name_zone});;
  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($res, \%warns);
}

# Function: add_dns_resource_type
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_dns_resource_type {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@dns_resource_type_fields) {
    my $nk = $key;		# required because $key is a reference into dns_resource_type_fields
    $nk =~ s/^dns_resource_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^dns_resource_type\.$key$/, @dns_resource_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find dns_resource_type.$key!\n".join(',', @dns_resource_type_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("dns_resource_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "dns_resource_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"dns_resource_type.$key"} = $$fields{$key};
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'dns_resource_type', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
}


# Function: add_dhcp_option_type
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_dhcp_option_type {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@dhcp_option_type_fields) {
    my $nk = $key;		# required because $key is a reference into dhcp_option_type_fields
    $nk =~ s/^dhcp_option_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^dhcp_option_type\.$key$/, @dhcp_option_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find dhcp_option_type.$key!\n".join(',', @dhcp_option_type_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("dhcp_option_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "dhcp_option_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"dhcp_option_type.$key"} = $$fields{$key};
  }		
  
  # Verify the format conforms to valid format specifications
  {
    my $Res = CMU::Netdb::validity::verify_dhcp_option_format($$newfields{"dhcp_option_type.format"});
    return (CMU::Netdb::getError($Res), ['format'])
      if (CMU::Netdb::getError($Res) != 1);
    $$newfields{"dhcp_option_type.format"} = $Res;
  }

  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'dhcp_option_type', $newfields);
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
      ($dbh, $dbuser, 'admin_default_add', 'dhcp_option_type', 
       $warns{insertID}, '', {});
    
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "dhcp_option_type/$warns{insertID}: ".join(',', @$AErrf)."\n";
    }
  }
  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($res, \%warns);
  
}


# Function: add_dhcp_option
# Arguments: 3
#     An already connected database handle
#     The name of the user performing the query
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_dhcp_option {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields, $rlevel);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  # need to do a bit more verification for access
  return ($CMU::Netdb::errcodes{EBLANK}, ['type']) if ($$fields{type} eq '');
  if ($$fields{type} eq 'machine') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'machine', $$fields{tid});
  }elsif($$fields{type} eq 'subnet') {
    if ($$fields{tid} eq '0') {
      $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'dhcp_option', 0);
      $rlevel = 0 if ($rlevel < 9);
    }else{
      $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'subnet', $$fields{tid});
    }
  }elsif($$fields{type} eq 'service') {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifiying service / $$fields{tid}\n";
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'service', $$fields{tid});
  }else{
    # assume global. if not, we'll get caught soon enough
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'dhcp_option', 0);
    $rlevel = 0 if ($rlevel < 9);
    $$fields{tid} = 0;
  }
  return ($CMU::Netdb::errcodes{EPERM}, ['tid']) if ($rlevel < 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@dhcp_option_fields) {
    my $nk = $key;		# required because $key is a reference into dhcp_option_fields
    $nk =~ s/^dhcp_option\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^dhcp_option\.$key$/, @dhcp_option_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find dhcp_option.$key!\n".join(',', @dhcp_option_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    
    $$fields{$key} = CMU::Netdb::valid("dhcp_option.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "dhcp_option.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"dhcp_option.$key"} = $$fields{$key};
  }
  
  ## verify access
  my $ul;
  if ($$newfields{'dhcp_option.type'} eq 'subnet') {
    # verify they can write to the subnet
    # if tid = 0, it's a global subnet default
    unless ($$newfields{'dhcp_option.tid'} eq '0') {
      $ul = CMU::Netdb::auth::get_write_level
	($dbh, $dbuser, 'subnet', $$newfields{'dhcp_option.tid'});
      return ($CMU::Netdb::errcodes{EPERM}, ['type']) 
	if ($ul < 1);
    }
  }elsif ($$newfields{'dhcp_option.type'} eq 'machine') {
    # verify access to the machine
    $ul = CMU::Netdb::auth::get_write_level
      ($dbh, $dbuser, 'machine', $$newfields{'dhcp_option.tid'});
    return ($CMU::Netdb::errcodes{EPERM}, ['type']) if ($ul < 1);
  }elsif ($$newfields{'dhcp_option.type'} eq 'service') {
    # verify access to the service
    $ul = CMU::Netdb::auth::get_write_level
      ($dbh, $dbuser, 'service', $$newfields{'dhcp_option.tid'});
    return ($CMU::Netdb::errcodes{EPERM}, ['type']) if ($ul < 1);
  }
  
  # verify machine/subnet exists
  my $msr;
  if ($$newfields{'dhcp_option.type'} eq 'subnet' &&
      $$newfields{'dhcp_option.tid'} ne '0') {
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "add_dhcp_option: verifying subnet ".
	"($$newfields{'dhcp_option.tid'})\n" if ($debug);
    
    $msr = CMU::Netdb::machines_subnets::list_subnets_ref
      ($dbh, $dbuser, "subnet.id =' $$newfields{'dhcp_option.tid'}'", 
       'subnet.name');
    
    return ($CMU::Netdb::errcodes{ESUBNET}, ['type', 'tid'])
      if (!ref $msr || !defined $$msr{$$newfields{'dhcp_option.tid'}});
    
  }elsif ($$newfields{'dhcp_option.type'} eq 'machine') {
    
    $msr = CMU::Netdb::machines_subnets::list_machines
      ($dbh, $dbuser, "machine.id = '$$newfields{'dhcp_option.tid'}'");
    
    return ($CMU::Netdb::errcodes{EHOST}, ['type', 'tid'])
      if (!ref $msr || !defined $msr->[1]);
    
  }elsif ($$newfields{'dhcp_option.type'} eq 'service') {
    $msr = CMU::Netdb::list_services
      ($dbh, $dbuser, "service.id = '$$newfields{'dhcp_option.tid'}'");
    
    return ($CMU::Netdb::errcodes{EHOST}, ['type', 'tid'])
      if (!ref $msr || !defined $msr->[1]);
    
  } else {
    $$newfields{'dhcp_option.tid'} = 0;
  }
  
  # verify they can GET the dhcp option type
  my $otref = get_dhcp_option_types($dbh, $dbuser, "dhcp_option_type.id = '$$newfields{'dhcp_option.type_id'}'");
  return ($CMU::Netdb::errcodes{EPERM}, ['type_id', 'tid']) 
    if (!ref $otref || !defined $otref->{$$newfields{'dhcp_option.type_id'}});
  
  # verify the option value conforms to the DHCP option format
  {
    my $dhcp_op = list_dhcp_option_types($dbh, $dbuser, "dhcp_option_type.id = '$$newfields{'dhcp_option.type_id'}'");
    return ($CMU::Netdb::errcodes{EPERM}, ['type_id', 'tid', 'format'])
      if (!ref $dhcp_op || !defined $dhcp_op->[1]);
    my %pos = %{CMU::Netdb::makemap($dhcp_op->[0])};
    my $Res = CMU::Netdb::validity::verify_dhcp_option_value
      ($$newfields{'dhcp_option.value'}, $dhcp_op->[1]->[$pos{'dhcp_option_type.format'}]);
    return (CMU::Netdb::getError($Res), ['type_id', 'format']) 
      if (CMU::Netdb::getError($Res) != 1);
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'dhcp_option', $newfields);
  return ($res, []) if ($res < 1);
  my %warns = ('id' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
}


# Function: modify_dns_zone
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
sub modify_dns_zone {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields, @zone_f_short, %ofields, $orig, $ul);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dns_zone.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dns_zone.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dns_zone.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dns_zone.version']) if (CMU::Netdb::getError($version) != 1);
  
  $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'dns_zone', $id);
  return $CMU::Netdb::errcodes{EPERM} if ($ul < 1);


  $orig = list_dns_zones($dbh, $dbuser, "dns_zone.id='$id'");
  return ($orig, ['id']) if (!ref $orig || !defined $orig->[1]);
  
  %ofields = ();
  foreach (@dns_zone_fields) {
    my $nk = $_;
    $nk =~ s/^dns_zone\.//;
    push(@zone_f_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = ${$$orig[1]}[$i++] } @zone_f_short;
}
map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } @zone_f_short;

## bidirectional verification of the fields that the user is trying to add
foreach $key (@dns_zone_fields) {
  my $nk = $key;		# required because $key is a reference into dns_zone_fields
  $nk =~ s/^dns_zone\.//;
  $$fields{$nk} = '' 
    if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
}

foreach $key (keys %$fields) {
  if (! grep /^dns_zone\.$key$/, @dns_zone_fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Couldn't find dns_zone.$key!\n".join(',', @dns_zone_fields) if ($debug >= 2);
    return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
  }
  
  unless ($$fields{'type'} =~ /toplevel/) {
    if ($key =~ /soa_/) {
      $$fields{$key} = '';
      next;
    }
  }
  warn __FILE__, ':', __LINE__, ' :>'.
    "Verifying $key\n" if ($debug >= 2);
  $$fields{$key} = CMU::Netdb::valid("dns_zone.$key", $$fields{$key}, $dbuser, $ul, $dbh);
  return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
  warn __FILE__, ':', __LINE__, ' :>'.
    "dns_zone.$key: $$fields{$key}\n" if ($debug >= 2);
  
  $$newfields{"dns_zone.$key"} = $$fields{$key};
}

## figure out the zone parent
if ($$newfields{'dns_zone.type'} =~ /-toplevel$/) {
  $$newfields{'dns_zone.parent'} = $id;
}else{
  my $r = getParent($$newfields{'dns_zone.name'}, $dbh, $dbuser);
  $r = 0 if ($r < 1);
  #    return ($CMU::Netdb::errcodes{EDOMAIN}, ['parent']) if ($r < 1); 
  $$newfields{'dns_zone.parent'} = $r;
}

  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

$result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'dns_zone', $id, $version, $newfields);

if ($result == 0) {
  # An error occurred
  $query = "SELECT id FROM dns_zone WHERE id='$id' AND version='$version'";
  $sth = $dbh->prepare($query);
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_dns_zone: $query\n" if ($debug >= 2);
  $sth->execute();
  if ($sth->rows() == 0) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_dns_zone: id/version were stale\n" if ($debug);
    CMU::Netdb::xaction_rollback($dbh);
    return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
  } else {
    CMU::Netdb::xaction_rollback($dbh);
    return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
  }
}

CMU::Netdb::xaction_commit($dbh, $xref);
return ($result,[]);

}

# Function: modify_dns_resource_type
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
sub modify_dns_resource_type {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dns_resource_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dns_resource_type.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dns_resource_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dns_resource_type.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@dns_resource_type_fields) {
    my $nk = $key;		# required because $key is a reference into dns_resource_type_fields
    $nk =~ s/^dns_resource_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^dns_resource_type\.$key$/, @dns_resource_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find dns_resource_type.$key!\n".join(',', @dns_resource_type_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("dns_resource_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "dns_resource_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"dns_resource_type.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'dns_resource_type', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM dns_resource_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_dns_resource_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_dns_resource_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result,[]);
  
}


# Function: modify_dhcp_option_type
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
sub modify_dhcp_option_type {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dhcp_option_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dhcp_option_type.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dhcp_option_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dhcp_option_type.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@dhcp_option_type_fields) {
    my $nk = $key;		# required because $key is a reference into dhcp_option_type_fields
    $nk =~ s/^dhcp_option_type\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^dhcp_option_type\.$key$/, @dhcp_option_type_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find dhcp_option_type.$key!\n".join(',', @dhcp_option_type_fields) if ($debug >= 2);
      return ($CMU::Netdb::errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("dhcp_option_type.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "dhcp_option_type.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"dhcp_option_type.$key"} = $$fields{$key};
  }
  
  # Verify the format
  {
    my $Res = CMU::Netdb::validity::verify_dhcp_option_format($$newfields{"dhcp_option_type.format"});
    return (CMU::Netdb::getError($Res), ['format'])
      if (CMU::Netdb::getError($Res) != 1);
    $$newfields{"dhcp_option_type.format"} = $Res;
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'dhcp_option_type', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM dhcp_option_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_dhcp_option_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_dhcp_option_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result,[]);
  
}

# Function: delete_dns_zone
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_dns_zone {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, @zone_f_short, %ofields, $orig, $dref, $ul);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dns_zone.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dns_zone.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dns_zone.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dns_zone.version']) if (CMU::Netdb::getError($version) != 1);
  
  $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'dns_zone', $id);
  return $CMU::Netdb::errcodes{EPERM} if ($ul < 1);

  $orig = list_dns_zones($dbh, $dbuser, "dns_zone.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@dns_zone_fields) {
    my $nk = $_;
    $nk =~ s/^dns_zone\.//;
    push(@zone_f_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = ${$$orig[1]}[$i++] } @zone_f_short;
}

($result, $dref) = CMU::Netdb::primitives::delete
  ($dbh, $dbuser, 'dns_zone', $id, $version);

if ($result != 1) {
  # An error occurred
  $query = "SELECT id FROM dns_zone WHERE id='$id' AND version='$version'";
  $sth = $dbh->prepare($query);
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_dns_zone: $query\n" if ($debug >= 2);
  $sth->execute();
  if ($sth->rows() == 0) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_dns_zone: id/version were stale\n" if ($debug);
    return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
  } else {
    return ($result, $dref);
  }
}

return ($result, []);

}


# Function: delete_dns_resource
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_dns_resource {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $rlevel, %ofields, $orig, 
      @dns_res_short, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dns_resource.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dns_resource.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dns_resource.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dns_resource.version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = list_dns_resources($dbh, 'netreg', " dns_resource.id = '$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@dns_resource_fields) {
    my $nk = $_;
    $nk =~ s/^dns_resource\.//;
    push(@dns_res_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ {$$orig[1]}[$i++] } @dns_res_short;
  }
  
  # need to do a bit more verification for access
  return ($CMU::Netdb::errcodes{EBLANK}, ['type']) if ($ofields{owner_type} eq '');
  if ($ofields{owner_type} eq 'machine') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'machine', $ofields{owner_tid});
  }elsif($ofields{owner_type} eq 'dns_zone') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'dns_zone', $ofields{owner_tid});
    #require higher level to delete dns_zone resources
    return ($CMU::Netdb::errcodes{EPERM}, ['owner_tid', 'write_level']) if ($rlevel < 5);
    
    # require L5 A on the dns resource type in this case
    my %repos = %{CMU::Netdb::makemap($orig->[0])};
    my $Type = $orig->[1][$repos{'dns_resource.type'}];
    my $tyref = &get_dns_resource_types($dbh, $dbuser, "dns_resource_type.name='$Type' AND P.rlevel >= 5");
    print STDERR Dumper ($tyref) if ($debug >= 1);
    return ($CMU::Netdb::errcodes{EPERM}, ['owner_tid', 'add_level', $Type]) 
      unless (ref $tyref && (grep /^$Type$/, values %$tyref));
  } elsif ($ofields{owner_type} eq 'service') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'service', $ofields{owner_tid});
    # require level 9 write on the service to modify attributes
    return ($CMU::Netdb::errcodes{EPERM}, ['owner_tid', 'write_level', 'service'])
      unless ($rlevel >= 9);
  }else{
    warn __FILE__,'::',__LINE__, ":> Unknown dns resource owner type during delete\n";
    return ($CMU::Netdb::errcodes{ERROR}, ['type']);
    # FIXME send mail
  }
  return ($CMU::Netdb::errcodes{EPERM}, ['owner_tid', 'low_rights']) if ($rlevel < 1);

  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }
  
  # since we're running this as netreg, start the changelog as the real user first.
  CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  ## see above re: running this as netreg
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, 'netreg', 'dns_resource', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM dns_resource WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_dns_resource: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_dns_resource: id/version were stale\n" if ($debug);
      CMU::Netdb::xaction_rollback($dbh);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      CMU::Netdb::xaction_rollback($dbh);
      return ($result, $dref);
    }
  }
  
  CMU::Netdb::force_zone_update($dbh, $ofields{name_zone});
  CMU::Netdb::force_zone_update($dbh, $ofields{owner_tid})
      if ($ofields{type} == 'dns_zone' && $ofields{owner_tid} != $ofields{name_zone});
  CMU::Netdb::xaction_commit($dbh, $xref);
  return ($result, []);
  
}

# Function: delete_dns_resource_type
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_dns_resource_type {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dns_resource_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dns_resource_type.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dns_resource_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dns_resource_type.version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'dns_resource_type', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM dns_resource_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_dns_resource_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_dns_resource_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
}


# Function: delete_dhcp_option_type
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_dhcp_option_type {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dhcp_option_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dhcp_option_type.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dhcp_option_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dhcp_option_type.version']) if (CMU::Netdb::getError($version) != 1);
  
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'dhcp_option_type', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM dhcp_option_type WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_dhcp_option_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_dhcp_option_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
}

# Function: delete_dhcp_option
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The 'id' of the zone to delete.
#     The 'version' of the zone to delete.
# Actions: Verifies authorization and deletes the zone.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_dhcp_option {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $rlevel, %ofields, 
      $orig, @dhcp_option_short, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('dhcp_option.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['dhcp_option.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('dhcp_option.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['dhcp_option.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## NOTE: we're gonna handle delete verification and run the delete query
  ## as netreg
  $orig = list_dhcp_options($dbh, 'netreg', " dhcp_option.id = '$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@dhcp_option_fields) {
    my $nk = $_;
    $nk =~ s/^dhcp_option\.//;
    push(@dhcp_option_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = $ {$$orig[1]}[$i++] } @dhcp_option_short;
  }
  
  # need to do a bit more verification for access
  return ($CMU::Netdb::errcodes{EBLANK}, ['type']) if ($ofields{type} eq '');
  if ($ofields{type} eq 'machine') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'machine', $ofields{tid});
  }elsif($ofields{type} eq 'subnet') {
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'subnet', $ofields{tid});
  }else{
    # ASSUME global
    $rlevel = CMU::Netdb::get_write_level($dbh, $dbuser, 'dhcp_option', 0);
    $rlevel = 0 if ($rlevel < 9);
  }
  return ($CMU::Netdb::errcodes{EPERM}, ['tid']) if ($rlevel < 1);
  
  # since we're running this as netreg, start the changelog as the real user first.
  CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  ## see above re: running this as netreg
  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, 'netreg', 'dhcp_option', $id, $version);
  
  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM dhcp_option WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_dhcp_option: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_dhcp_option: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
  
}

# updates all zone serials that have changed since the last update
sub update_zone_serials {
  my ($dbh, $dbuser) = @_;
  my ($query, $sth, $res) = @_;
  
  # get the current mysql time
  $query = "SELECT now()-1";
  $sth = $dbh->prepare($query);
  $res = $sth->execute;		# FIXME check return
  my @row = $sth->fetchrow_array();
  return 0 if (!@row || !defined $row[0]);
  my $updtime = $row[0];
  
  # don't allow this unless they have full read access to machines, 
  # dns_resources and read/write access to dns_zone
  my $ul = CMU::Netdb::get_read_level($dbh, $dbuser, 'dns_resource', 0);
  return $CMU::Netdb::errcodes{EPERM} if ($ul < 1);
  $ul = CMU::Netdb::get_read_level($dbh, $dbuser, 'machine', 0);
  return $CMU::Netdb::errcodes{EPERM} if ($ul < 1);
  $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'dns_zone', 0);
  return $CMU::Netdb::errcodes{EPERM} if ($ul < 1);
  
  my @queries = (
 	"SELECT DISTINCT dns_zone.parent FROM dns_zone, dns_zone AS DZ, machine WHERE dns_zone.id = machine.host_name_zone AND DZ.id = dns_zone.parent AND machine.version >= DZ.last_update",
        "SELECT DISTINCT dns_zone.parent FROM dns_zone, dns_zone AS DZ, machine WHERE dns_zone.id = machine.ip_address_zone AND DZ.id = dns_zone.parent AND machine.version >= DZ.last_update",
        "SELECT DISTINCT dns_zone.parent FROM dns_zone, dns_zone AS DZ, dns_resource WHERE dns_zone.id = dns_resource.name_zone AND DZ.id = dns_zone.parent AND dns_resource.version >= DZ.last_update",
         "SELECT DISTINCT dns_zone.parent FROM dns_zone, dns_zone AS DZ where DZ.id = dns_zone.parent AND dns_zone.version >= DZ.last_update",
         "SELECT DISTINCT dns_zone.id FROM dns_zone, dns_resource WHERE dns_zone.id = dns_resource.owner_tid and dns_resource.owner_type = 'dns_zone' AND dns_resource.version >= dns_zone.last_update",
         "SELECT DISTINCT dns_zone.id FROM dns_zone, dns_resource, machine WHERE dns_zone.id = dns_resource.name_zone AND dns_resource.owner_type = 'machine' AND dns_resource.owner_tid = machine.id AND machine.version > dns_zone.last_update",

		);
  my %updzones;
  foreach $query (@queries) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU:Netdb::dns_dhcp::update_zone_serials::query: $query\n";
    $sth = $dbh->prepare($query);
    $sth->execute;		# check return FIXME
    while(@row = $sth->fetchrow_array()) {
      $updzones{$row[0]} = 1;
    }
  }
  
  if (keys %updzones) {
    # FIXME not logging zone serial updates, for now.  -vitroth
    my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
    if ($xres == 1){
	$xref = shift @{$xref};
    }else{
	return ($xres, $xref);
    }
    # hrm. I wonder how large an IN statement can be :)
    $query = "UPDATE dns_zone SET soa_serial = soa_serial + 1, last_update = '$updtime', version=version ".
      " WHERE id IN (".join(',', keys %updzones).")";
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU:Netdb::dns_dhcp::update_zone_serials::query: $query\n";
    $dbh->do($query);
    # FIXME check return value
    CMU::Netdb::xaction_commit($dbh, $xref);
  }
  
  return 1;
}

# This will force-update a particular zone ID
sub force_zone_update {
  my ($dbh, $zone) = @_;
  my $pzone = getParent($zone, $dbh, 'netreg');
  my $query = "UPDATE dns_zone SET last_update = now(), version=version ".
    " WHERE id = $pzone";
  $dbh->do($query);
  warn __FILE__, ':', __LINE__, ' :>'.
    "force_zone_update: $zone -> $pzone\n" if ($debug >= 2);	
  # FIXME check return value
  # FIXME not logging zone serial updates, for now.  -vitroth
  return 1;
}


# given a dns_zone, will find the toplevel zone for it.
sub getParent {
  my ($d, $dbh, $dbuser) = @_;
  my ($h, $ref);
  
 warn __FILE__, ':', __LINE__, ' :>'.
    "CMU:Netdb::dns_dhcp::getParent: Looking for parent of '$d'\n" if ($debug >= 2);
  if ($d =~ /^\d+$/) {
    # If passed a numeric zone pointer, translate to the zone name.
    $ref = CMU::Netdb::dns_dhcp::list_zone_ref($dbh, $dbuser, "dns_zone.id = $d");
    return 0 if (!ref $ref);
    return 0 if (!exists $ref->{$d});
    $d = $ref->{$d};
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU:Netdb::dns_dhcp::getParent: Translated numeric zone id to $d\n" if ($debug >= 2);
  }

  do {
    $ref = CMU::Netdb::dns_dhcp::list_zone_ref($dbh, $dbuser, 
					       " dns_zone.name = '$d' AND (dns_zone.type like '%toplevel%' OR dns_zone.type like '%delegated%') ");
     if (keys %$ref) {
      warn __FILE__, ':', __LINE__, ' :>'.
        "CMU:Netdb::dns_dhcp::getParent: Parent of $d is ".[%$ref]->[0]."\n" if ($debug >= 2);
      return [%$ref]->[0];
    }
 
    ($h, $d) = CMU::Netdb::splitHostname($d);
  } while ($d ne '');
  
  return 0;
}

## NOTE:: This function (incorrectly) DOES NOT prepend the header row
## to returned data. When fixed, any use of this function must also be
## fixed.
sub list_default_dhcp_options {
  my ($dbh, $dbuser, $scope) = @_;
  
  my ($result, @data, $rwhere, @header);
  my %valid_scope = ('subnet' => 1,
		     'pool' => 1);
  
  return (-1, ['scope']) unless (defined $valid_scope{$scope});
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) 
    if (CMU::Netdb::getError($dbuser) != 1);
  
  # Get only the fields of interest
  @header = qw/dhcp_option_type.name dhcp_option.value/;
  
  # SQL WHERE statement to restrict rows returned.
  $rwhere = "dhcp_option.type_id = dhcp_option_type.id AND " .
    "dhcp_option.type = '$scope' AND dhcp_option.tid = 0 ";
  
  # Send the SQL query and get results.
  $result = CMU::Netdb::primitives::list
    ($dbh, $dbuser, 
     "dhcp_option, dhcp_option_type", \@header, $rwhere);
  
  if (!ref $result) {
    return ($result, ['dhcp_option', 'dhcp_option_type']);
  }
  
  if ($#$result == -1) {
    return [];
  }
  
  @data = @$result;
  if ($debug >= 1) {
    foreach my $temp (@data) {
      warn __FILE__, ':', __LINE__, ' :>'.
	@$temp,"\n\n";
    }
  }
  
  return \@data;
}



1;
