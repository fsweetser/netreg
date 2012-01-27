#   -*- perl -*-
#
# CMU::Netdb::primitives
# This module provides the necessary primitive functions for
# listing, adding and modifying any single table.
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

# First we define what package/modules this is, and set some ground rules.

package CMU::Netdb::primitives;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug $db_errstr $db_insertid $changelog_id $changelog_user $changelog_info $changelog_row $changelog_row_type $changelog_row_table $netevent $netevent_process_columns);
use CMU::Netdb::errors;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(can_read_all);


BEGIN {
  require CMU::Netdb::config; import CMU::Netdb::config;
  my $res;
  ($res, $netevent) = CMU::Netdb::config::get_multi_conf_var('netdb', 'ENABLE_NETEVENT');

  if ($netevent == 1) {
    require CMU::NetEvent;
    import CMU::NetEvent;
    $netevent = new CMU::NetEvent || die "Unable to initialize NetEvent object";
    $netevent_process_columns = 0;
  } else {
    $netevent = undef;
  }
}




# Now we'll define some globals we'll be using in our package.

# $debug controls whether the module outputs debuging information
# This can be set from a client script before calling the routines.
$db_errstr = '';
$db_insertid = 0;
$debug = 0;
$changelog_id = 0;
$changelog_user = "";
$changelog_info = "";
$changelog_row_table = "";
$changelog_row = "";
$changelog_row_type = "";


# type is CHECK_ALL to join users/memberships
## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses.
sub can_read_all {
  my ($dbh, $dbuser, $table, $mwhere, $type) = @_;

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return 0 if (CMU::Netdb::getError($dbuser) != 1);

  $table = CMU::Netdb::validity::valid('local.table_name',
				       $table, $dbuser, 0, $dbh);
  return 0 if (CMU::Netdb::validity::getError($table) != 1);

  if (!defined $mwhere or $mwhere eq '') {
    warn __FILE__, ':', __LINE__, ' :>'.
      "can_read_all: Must specify valid WHERE clause.";
    return 0;
  }

  my ($query, $sth);
  $query = "SELECT P.tid ";

  if ($type eq 'CHECK_ALL') {
    $query .= "FROM credentials AS C JOIN users as U ON C.user = U.id ".
      "LEFT JOIN memberships as M ON U.id = M.uid, ".
	"protections as P WHERE C.authid = '$dbuser' AND ";
  }else{
    $query .= "FROM protections as P WHERE ";
  }
  $query .=<<END_SELECT;
P.tname = '$table'
AND FIND_IN_SET('READ', P.rights)
AND $mwhere
AND P.tid = 0
END_SELECT
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::can_read_all query: $query\n" if ($debug >= 3);
  $sth = $dbh->prepare($query);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::can_read_all error: $DBI::errstr";
    $db_errstr = $DBI::errstr;
    return $CMU::Netdb::errors::errcodes{"EDB"};
  } 
  my @row = $sth->fetchrow_array();
  return 1 if (@row && defined $row[0] && $row[0] eq '0');
  return 0;
}

## Safety Note: This function does not use caller-supplied arguments in an
## unsafe manner.
sub prune_restricted_fields {
  my ($dbh, $dbuser, $rows, $fields) = @_;
  #return;
  warn __FILE__, ':', __LINE__, ": entering prune_restricted_fields at ".localtime(time)." with ".scalar(@$rows)." rows of data, with ".scalar(@$fields)." columns.\n" if ($debug >= 3);

  my %map = %{CMU::Netdb::makemap($fields)};

  my %access_levels;

  my %columns;

  foreach my $column (@$fields) {
    next unless (defined $CMU::Netdb::structure::restricted_access_fields{$column});
    my $Required = $CMU::Netdb::structure::restricted_access_fields{$column};
    my $table = $column;
    $table =~ s/\..*//;

    warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::primitives::prune_restricted_fields: Reviewing access to $column\n"
	  if ($debug >= 3);

    unless (defined $map{"$table.id"}) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::primitives::prune_restricted_fields: No ID column found for table $table. ".
	  "Unable to prune restricted fields!\n";
      next;
    }

    unless (defined $access_levels{$table}->{'0'}) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::primitives::prune_restricted_fields: Determining read access to $table/0\n"
	  if ($debug >= 3);

      $access_levels{$table}->{'0'} = CMU::Netdb::get_read_level($dbh, $dbuser, $table, 0);
        warn __FILE__, ':', __LINE__, ' :>'.
  	  "CMU::Netdb::primitives::prune_restricted_fields: Found level $access_levels{$table}->{0} read access to $table/0\n"
	    if ($debug >= 3);
    }

    if ($access_levels{$table}->{'0'} < $Required) {
      $columns{$map{$column}} = [$table, $map{"$table.id"}, $Required];
    }
  }

  if (scalar(keys %columns) == 0) {
    warn __FILE__, ':', __LINE__, ' :>'.
      'CMU::Netdb::primitives::prune_restricted_fields: Returning (no work to do) '.
	'at '.localtime(time)."\n"
	if ($debug >= 3);
    return;
  }

  foreach my $row (@$rows) {
    foreach my $CID (keys %columns) {
      my ($Table, $TableIDCol, $ReqAccessLevel) = @{$columns{$CID}};

      unless (defined $access_levels{$Table}->{$row->[$TableIDCol]}) {
        warn __FILE__, ':', __LINE__, ' :>'.
  	  "CMU::Netdb::primitives::prune_restricted_fields: Determining read access to $Table/$row->[$TableIDCol]\n"
	    if ($debug >= 3);
	$access_levels{$Table}->{$row->[$TableIDCol]} = 
	  CMU::Netdb::get_read_level($dbh, $dbuser, $Table, $row->[$TableIDCol]);
        warn __FILE__, ':', __LINE__, ' :>'.
  	  "CMU::Netdb::primitives::prune_restricted_fields: Found level $access_levels{$Table}->{$row->[$TableIDCol]} read access to $Table/$row->[$TableIDCol]\n"
	    if ($debug >= 3);
      }

      if ($access_levels{$Table}->{$row->[$TableIDCol]} < $ReqAccessLevel) {
	$row->[$CID] = undef;
      }
    }
  }

  warn __FILE__, ':', __LINE__, ' :>'.
    'CMU::Netdb::primitives::prune_restricted_fields: Returning at '.localtime(time)."\n"
      if ($debug >= 3);

}

# Function: List
# Arguments: 2:
#     An already connected database handle.
#     The name of the user performing the query
#     The name of the table to be queried
#     A reference to an array of field names for that table
#     An optional string to be used as a WHERE clause.  i.e. "name = \"ju22\""
# Actions: Queries the database in the handle for rows is the users table
#          which conform to the WHERE clause (if any), and are viewable 
#          by this database user.
# Return value: 
#     A reference to an array of references to arrays containing the 
#        field values for each row which matched the query
#        Test for CMU::Netdb::valid return by (ref $result)
#        Access the first field of the first record by $result->[0]->[0]
#        The outer array will be empty if the query succeeded but returned
#           nothing
#     An error code is returned if a problem occurs (see CMU::netdb::errors.pm)

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses.
sub list {
  my ($dbh, $dbuser, $tablename, $tablefields, $where) = @_;
  my ($sth, $query, $key, $rows, $sTable);
  my @data = ();

  $tablename = CMU::Netdb::validity::valid('local.table_name_mult',
					   $tablename, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($tablename)
    if (CMU::Netdb::validity::getError($tablename) != 1);

  $dbuser = CMU::Netdb::valid('credentials.authid_perm', $dbuser, $dbuser, 0, 
			      $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  return $CMU::Netdb::errors::errcodes{'EINVREF'}
    unless (defined $tablefields && ref $tablefields eq 'ARRAY');

  return $CMU::Netdb::errors::errcodes{'EINVALID'}
    if ($where =~ m/union[\s\n]+select/is);

  $sTable = $tablename;
  # get rid of extra tables. ASSUME the first table is the key table
  $sTable =~ s/(\,|\s).*//;	# get rid of extra tables.

  my $CRA = CMU::Netdb::primitives::can_read_all
    ($dbh, $dbuser, $sTable,
     "(P.identity = 0 OR (U.id = P.identity)".
     "OR (CAST(M.gid AS SIGNED INT) * -1 = P.identity))", 'CHECK_ALL');

  if ($CRA) {
    $query = "SELECT DISTINCT ".(join ', ', @$tablefields)." FROM $tablename";
    $query .= " WHERE $where " if ($where ne '');
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::list query: $query\n" if ($debug >= 2);
    $sth = $dbh->prepare($query);
    if (!($sth->execute())) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::primitives::list error: $DBI::errstr\nquery: $query\nCaller: ".join('::',caller())."\n";
      $db_errstr = $DBI::errstr;
      return $CMU::Netdb::errors::errcodes{"EDB"};
    } else {
      $rows = $sth->fetchall_arrayref();
      if (ref $rows) {
	prune_restricted_fields($dbh, $dbuser, $rows, $tablefields);
	return $rows;
      } else {
	return [];
      }
    }
  }

  $query = "SELECT DISTINCT " . (join ', ', @$tablefields) . <<ENDSELECT;

FROM  credentials AS C
 JOIN users as U ON C.user = U.id
 JOIN protections as P
LEFT JOIN memberships as M ON (M.uid = U.id AND P.identity = CAST(M.gid AS SIGNED INT) * -1),
     $tablename
WHERE C.authid = '$dbuser'
AND P.tname = '$sTable'
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, U.id, 0)
AND FIND_IN_SET('READ', P.rights)
AND (P.tid = $sTable.id)
ENDSELECT

  $query .= " AND $where" if (defined $where && $where ne '');

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::list query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::list error: $DBI::errstr";
    $db_errstr = $DBI::errstr;
    return $CMU::Netdb::errors::errcodes{"EDB"};
  } else {
    $rows = $sth->fetchall_arrayref();
    if (ref $rows) {
      prune_restricted_fields($dbh, $dbuser, $rows, $tablefields);
      return $rows;
    } else {
      return [];
    }
  }
}

# Function: get
## Just like 'list' but searches for find_in_set of ADD
# Arguments: 2:
#     An already connected database handle.
#     The name of the user performing the query
#     The name of the table to be queried
#     A reference to an array of field names for that table
#     An optional string to be used as a WHERE clause.  i.e. "name = \"ju22\""
# Actions: Queries the database in the handle for rows is the users table
#          which conform to the WHERE clause (if any), and are viewable 
#          by this database user.
# Return value: 
#     A reference to an array of references to arrays containing the 
#        field values for each row which matched the query
#        Test for CMU::Netdb::valid return by (ref $result)
#        Access the first field of the first record by $result->[0]->[0]
#        The outer array will be empty if the query succeeded but returned
#           nothing
#     An error code is returned if a problem occurs (see CMU::netdb::errors.pm)

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses.
sub get {
  my ($dbh, $dbuser, $tablename, $tablefields, $where) = @_;
  my ($sth, $query, $key, $rows, $sTable);
  my @data = ();

  $tablename = CMU::Netdb::validity::valid('local.table_name_mult',
					   $tablename, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($tablename)
    if (CMU::Netdb::validity::getError($tablename) != 1);

  $dbuser = CMU::Netdb::valid('credentials.authid_perm', $dbuser, $dbuser, 0, 
			      $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  return $CMU::Netdb::errors::errcodes{'EINVREF'}
    unless (defined $tablefields && ref $tablefields eq 'ARRAY');

  return $CMU::Netdb::errors::errcodes{'EINVALID'}
    if ($where =~ m/union[\s\n]+select/is);

  $sTable = $tablename;
  # get rid of extra tables. ASSUME the first table is the key table
  $sTable =~ s/(\,|\s).*//;	# get rid of extra tables.

  $query = "SELECT DISTINCT " . (join ', ', @$tablefields) . <<ENDSELECT;

FROM  (credentials AS C
 JOIN users as U ON C.user = U.id
 JOIN protections as P)
LEFT JOIN memberships as M ON (M.uid = U.id AND P.identity = CAST(M.gid AS SIGNED INT) * -1),
     $tablename
WHERE C.authid = '$dbuser'
AND P.tname = '$sTable'
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, U.id, 0)
AND FIND_IN_SET('ADD', P.rights)
AND (P.tid = $sTable.id)
ENDSELECT

  $query .= "AND $where" if (defined $where && $where ne '');

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::get query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::get error: $DBI::errstr";
    $db_errstr = $DBI::errstr;
    return $CMU::Netdb::errors::errcodes{"EDB"};
  } else {
    $rows = $sth->fetchall_arrayref();
    if (ref $rows) {
      prune_restricted_fields($dbh, $dbuser, $rows, $tablefields);
      return $rows;
    } else {
      return [];
    }
  }
}

# Function: Add
# Arguments: 4:
#     An already connected database handle.
#     The name of the user performing the query
#     The name of the table to be queried.
#     A reference to a hash table of field->value pairs
# Actions: Adds the row to the table, if authorized.
# Return value: 
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::netdb::errors.pm)

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses and unvalidated EXPRs in the fields.
sub add {
  my ($dbh, $dbuser, $tablename, $fields) = @_;
  my ($sth, $query, $key, $result, $sTable);

  $tablename = CMU::Netdb::validity::valid('local.table_name_mult',
					   $tablename, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($tablename)
    if (CMU::Netdb::validity::getError($tablename) != 1);

  # Will verify the user is not suspended
  $dbuser = CMU::Netdb::valid('credentials.authid_perm', $dbuser, $dbuser, 0,
			      $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $sTable = $tablename;
  # get rid of extra tables. ASSUME the first table is the key table
  $sTable =~ s/\,.*//;		# get rid of extra tables.

  $query =<<ENDSELECT;
SELECT DISTINCT P.tname 
FROM (credentials AS C, protections AS P)
LEFT JOIN memberships as M
  ON (C.user = M.uid AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
WHERE
  C.authid = '$dbuser'
  AND P.tname = '$sTable'
  AND FIND_IN_SET('ADD', P.rights)
  AND (C.user = P.identity
       OR P.identity = 0
       OR (CAST(M.gid AS SIGNED INT) * -1 = P.identity
           AND C.user = M.uid))
  AND P.tid = 0
ENDSELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::add query: $query\n" if ($debug >= 2);

  $sth = $dbh->prepare($query);
  $sth->execute();
  if (!($sth->rows() >= 1)) {
    # Not authorized
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::add:  $dbuser is not authorized to add data to table $tablename\n" if ($debug);
    return $CMU::Netdb::errors::errcodes{"EPERM"};
  }
  
  delete $$fields{"$sTable.id"} if (defined $$fields{"$sTable.id"});
  delete $$fields{"$sTable.version"} if (defined $$fields{"$sTable.version"});

  $query = "INSERT INTO $sTable (";
  $query .= join ', ', sort keys %$fields;
  $query .= ") VALUES (";
  foreach $key (sort keys %$fields) {
    unless ($key =~ /^$sTable\./) {
      return $CMU::Netdb::errors::errcodes{'EINVFIELD'};
    }

    $query .= $dbh->quote($$fields{$key}) unless ($$fields{$key} =~ /^\*EXPR\: /);
    if ($$fields{$key} =~ /^\*EXPR\: /) {
      $$fields{$key} =~ s/\*EXPR\: //;
      $query .= "$$fields{$key}";
    }
    $query .= " , ";
  }
  substr($query, -2) = ")";
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::add query: $query\n" if ($debug >= 2);
  if (!($result = $dbh->do($query))) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::add error: $DBI::errstr\n";
    $db_errstr = $DBI::errstr;
    return $CMU::Netdb::errors::errcodes{"EDB"};
  } else {
    # LOG ALL CHANGES
    # First create the changelog record
    my $row = $dbh->{'mysql_insertid'};
    my $log = changelog_id($dbh, $dbuser);
    if ($log) {
      # Now create the changelog row record
      my $rowrec = changelog_row($dbh, $log, $sTable, $row, 'INSERT');
      if ($rowrec > 0) {
	# Now create the changelog column records
	foreach $key (keys %$fields) {
	  changelog_col($dbh, $rowrec, $key, $$fields{$key});
	}
      }
    }
    # Our caller may need the original insert id, but we can't reset
    # it, so we invent a new place to put it
    $db_insertid = $row;
  }

  return $result;
}

# Function: Modify
# Arguments: 6:
#     An already connected database handle.
#     The name of the user making the change
#     The name of the table
#     A row id to be matched against the id column of the table.
#     A row version (timestamp) to be verified against the table.
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::netdb::errors.pm)

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses and unvalidated EXPRs in the fields.
sub modify {
  my ($dbh, $dbuser, $tablename, $id, $version, $fields) = @_;
  my ($query, $key, $result, $sTable, $prequery, $sth, $row);

  $tablename = CMU::Netdb::validity::valid('local.table_name_mult',
					   $tablename, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($tablename)
    if (CMU::Netdb::validity::getError($tablename) != 1);

  $dbuser = CMU::Netdb::valid('credentials.authid_perm', $dbuser, $dbuser, 0,
			      $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $sTable = $tablename;
  # get rid of extra tables. ASSUME the first table is the key table
  $sTable =~ s/\..*$//;		# get rid of extra tables.

  $id = CMU::Netdb::valid("$sTable.id", $id, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($id) if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid("$sTable.version", $version, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($version)
    if (CMU::Netdb::getError($version) != 1);

  my $wl = CMU::Netdb::get_write_level($dbh, $dbuser, $sTable, $id);

  if ($wl < 1) {
    # Not authorized
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::modify:  $dbuser is not authorized to modify data in table $tablename\n" if ($debug);
    return $CMU::Netdb::errors::errcodes{"EPERM"};
  }

  delete $$fields{"$sTable.id"} if (defined $$fields{"$sTable.id"});
  delete $$fields{"$sTable.version"} if (defined $$fields{"$sTable.version"});

  $query = "UPDATE $tablename SET ";
  foreach $key (sort keys %$fields) {
    $query .= "$key=" . $dbh->quote($$fields{$key}) . ", " unless ($$fields{$key} =~ /^\*EXPR\: /);
    if ($$fields{$key} =~ /^\*EXPR\: /) {
      $$fields{$key} =~ s/\*EXPR\: //;
      $query .= "$key= $$fields{$key}" .", ";
    }
  }
  substr($query, -2) = " WHERE id='$id' AND version='$version'";
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::modify query: $query\n" if ($debug >= 2);

  # If we have transactional capabilities, use them.
  my ($res, $errf) = CMU::Netdb::xaction_begin($dbh);
  return $res if ($res <= 0);

  # LOG ALL CHANGES
  # First, prefetch the existing row
  $prequery  = "SELECT ".(join ', ', sort keys %$fields)." FROM $tablename WHERE id = '$id' AND version = '$version' FOR UPDATE";
  $sth = $dbh->prepare($prequery);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::modify error during logging prefetch: $DBI::errstr";
  } else {
    $row = $sth->fetchrow_arrayref();

    unless (ref $row eq 'ARRAY') {
      # If there were no results, assume version mismatch

      my ($xr, $xd) = CMU::Netdb::xaction_rollback($dbh);
      if ($xr < 1) {
	warn __FILE__, ':', __LINE__, ' :>'.
	  "CMU::Netdb::primitives::modify STALEERR / x_rollback: $xr [".
	    join(',', @$xd)."]\n";
      }

      return $CMU::Netdb::errors::errcodes{'ESTALE'};
    }

    my (@fieldnames) = sort keys %$fields;
    # Now create the changelog record
    my $log = changelog_id($dbh, $dbuser);
    if ($log) {
      # Now create the changelog row record
      my $rowrec = changelog_row($dbh, $log, $tablename, $id, 'UPDATE');
      if ($rowrec > 0) {
	# Now create one changelog column record for every changed column
	foreach my $col (@$row) {
	  my $key = shift @fieldnames;
	  # Don't bother to log if no change
	  next unless ($col ne $$fields{$key});
	  # Add the record
	  changelog_col($dbh, $rowrec, $key, $$fields{$key}, $col);
	}
      }
    }
  }

  $result = $dbh->do($query);

  if (!defined $result || $result eq '0') {
    # The update failed, but we logged it. Need to roll back the log..

    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::modify error: $DBI::errstr\n";
    $db_errstr = $DBI::errstr;

    my ($xr, $xd) = CMU::Netdb::xaction_rollback($dbh);
    if ($xr < 1) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::primitives::modify X2ERR / x_rollback: $xr [".
	  join(',', @$xd)."]\n";
    }
    return $CMU::Netdb::errors::errcodes{"EDB"};
  }

  my ($xr, $xd) = CMU::Netdb::xaction_commit($dbh);
  if ($xr != 1) {
    # Failed to properly commit; xr == 2 means it rolled back successfully
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::modify XCOMMITERR: $xr [".
	join(',', @$xd)."]\n";
    return 0;
  }

  # Note that ($result eq '0E0') could mean that there was a version mismatch.
  # We should have caught this earlier in the logging phase.

  return 1;
}



# Function: Delete
# Arguments: 3:
#     An already connected database handle.
#     The name of the user making the request
#     The name of the table
#     A row id to be matched against the id column of the table.
#     A row version (timestamp) to be verified against the table.
# Actions: Deletes the specified row, if authorized.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::netdb::errors.pm)

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses.
sub delete {
  my ($dbh, $dbuser, $tablename, $id, $version) = @_;

  $tablename = CMU::Netdb::validity::valid('local.table_name',
					   $tablename, $dbuser, 0, $dbh);
  return (CMU::Netdb::validity::getError($tablename), ['local.table_name'])
    if (CMU::Netdb::validity::getError($tablename) != 1);

  $dbuser = CMU::Netdb::valid('credentials.authid_perm', $dbuser, $dbuser, 0,
			      $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid_perm'])
    if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid("$tablename.id", $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ["$tablename.id"])
    if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid("$tablename.version", $version, $dbuser,
			       0, $dbh);
  return (CMU::Netdb::getError($version), ["$tablename.version"])
    if (CMU::Netdb::getError($version) != 1);

  # If we have transactional capabilities, use them.
  my ($res, $errf) = CMU::Netdb::xaction_begin($dbh);
  return ($res, $errf) if ($res <= 0);
  
  my ($cdRes, $rData) = CMU::Netdb::primitives::delete_cascade_check
    ($dbh, $dbuser, $tablename, $id, 1);
  
  warn __FILE__, ':', __LINE__, ' :>'.
    " primitives::delete: result $cdRes [".join(',', @$rData)."]\n"
      if ($debug >= 2);

  if ($cdRes < 1) {
    my ($xr, $xd) = CMU::Netdb::xaction_rollback($dbh);
    if ($xr < 1) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::primitives::delete X2ERR / x_rollback: $xr [".
	  join(',', @$xd)."]\n";
    }
    return ($cdRes, $rData);
  }

  unshift(@$rData, [$tablename, $id, $version]);

  # Cascade deletion was fine. Now go through the table/ids and 
  # check if we have permission to delete them
  foreach my $elem (@$rData) {
    my ($dpRes, $dpRef) = CMU::Netdb::primitives::delete_permission_check
      ($dbh, $dbuser, $elem->[0], $elem->[1]);
    if ($dpRes <= 0 || !defined $elem->[2]) {
      warn __FILE__, ':', __LINE__, ' :>'.
          " primitives::delete / permission check problem: $dpRes\n"
	    if ($debug >= 2);

      # Failure -- EPERM most likely
      my ($xr, $xd) = CMU::Netdb::xaction_rollback($dbh);
      if ($xr < 1) {
	warn __FILE__, ':', __LINE__, ' :>'.
	  "CMU::Netdb::primitives::delete X2ERR / x_rollback: $xr [".
	    join(',', @$xd)."]\n";
      }
      return ($dpRes, $dpRef);
    }
  }
  
  # All of the DelRecs were checked for permissions, and we can delete all
  # of them safely.

 # Now, uniquify the list so we don't try to delete something twice.

  warn  __FILE__, ':', __LINE__, ' :>'.
    "delete: Non-Uniq list is " . Data::Dumper->Dump([$rData],[qw(rData)]) . "\n"
      if ($debug >= 5);

  my $uniq = {};
  map { $uniq->{join('--CUT--',@$_)} = 1 } @$rData;
  $rData = [ map { [ split(/--CUT--/, $_) ] } sort keys %$uniq ];

  warn  __FILE__, ':', __LINE__, ' :>'.
    "delete: Uniq list is " . Data::Dumper->Dump([$rData],[qw(rData)]) . "\n"
      if ($debug >= 5);


  # LOG ALL CHANGES
  # All these deletions will be logged together
  # First create the changelog entry
  my $log = changelog_id($dbh, $dbuser);

  foreach my $elem (@$rData) {

    warn  __FILE__, ':', __LINE__, ' :>'.
          "delete: DELETING $elem->[0]/$elem->[1] [version $elem->[2]]\n"
	    if ($debug >= 2);
    if ($log) {
      # Create the changelog row record
      my $rowrec = changelog_row($dbh, $log, $elem->[0], $elem->[1], 'DELETE');
      if ($rowrec > 0) {
	# Now fetch the existing row, for logging
	my @fields;
	eval '@fields = @CMU::Netdb::structure::'.$elem->[0].'_fields;';
	if ($@) {
	  warn __FILE__, ':', __LINE__, ' :>'.
	    "CMU::Netdb::primitives::delete error: No matching table structure\n";
	} else {
	  # If the _fields array has any fields from other tables, the
	  # query will fail. But this should not be the case..
	  @fields = map { $_ =~ s/^$elem->[0]\.//; $_; } @fields;

	  my $sth = $dbh->prepare("SELECT ".(join ', ', @fields).
				  " FROM $elem->[0]".
				  " WHERE id = '$elem->[1]'".
				  " AND version = '$elem->[2]'");
	  if (!($sth->execute())) {
	    warn __FILE__, ':', __LINE__, ' :>'.
	      'CMU::Netdb::primitives::delete error during logging prefetch: '.
		$DBI::errstr;
	  } else {
	    my $row = $sth->fetchrow_arrayref();

	    # Now create one changelog column record for every column
	    foreach my $col (@$row) {
	      my $col_name = shift @fields;
	      # Don't bother to log the id column
	      next if ($col_name eq "id");

	      # Add the record
	      changelog_col($dbh, $rowrec, $col_name, undef, $col);
	    }
	  }
	}
      }
    }
    my $query = "DELETE FROM $elem->[0] WHERE ".
      " id = '$elem->[1]' AND version = '$elem->[2]'";

    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::delete query: $query\n" if ($debug >= 2);

    my $result = $dbh->do($query);
    if (!defined $result || $result eq '0' || $result eq '0E0') {
      # The delete failed. We need to roll back the log and any other
      # deletes.

      my ($xr, $xd) = CMU::Netdb::xaction_rollback($dbh);
      if ($xr < 1) {
	warn __FILE__, ':', __LINE__, ' :>'.
	  "CMU::Netdb::primitives::delete X2ERR / x_rollback: $xr [".
	    join(',', @$xd)."]\n";
      }
      $db_errstr = $DBI::errstr; 
      if (!defined $result || $result eq '0') {
	return ($CMU::Netdb::errors::errcodes{"EDB"}, ["delete: ".$db_errstr]);
      }else{
	# result == 0e0, so it was successful but no records changed
	return ($CMU::Netdb::errors::errcodes{"ENOENT"}, []);
      }
    }
  }

  # Success. Go ahead and commit
  my ($xr, $xd) = CMU::Netdb::xaction_commit($dbh);
  if ($xr != 1) {
    # Failed to properly commit; xr == 2 means it rolled back successfully
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::delete XCOMMITERR: $xr [".
	join(',', @$xd)."]\n";
    return ($xr, $xd);
  }

  # Commit succeeded, so we're done.
  return (1, []);
}

# Recursively checks for things that need to be deleted along with this
# item, or things that impede this item from being deleted.

## Safety Note: This function does not use caller-specified variables
## in an unsafe manner.
sub delete_cascade_check {
  my ($dbh, $dbuser, $table, $tid, $depth) = @_;

  warn __FILE__, ':', __LINE__, ' :>'.
    " delete_cascade_check [$dbuser]: $table:$tid [depth $depth]\n"
      if ($debug >= 2);

  my ($res, $max_cd) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'MAX_CASCADE_DEPTH');
  return ($res, $max_cd) if ($res != 1);

  if ($depth > $max_cd) {
    # Longer than this and we might be in a loop, so we're just
    # gonna have to fatal out. Sorry, kids.
    return ($CMU::Netdb::errors::errcodes{"ECASCADEDEPTH"}, []);
  }

  my %Casc = %CMU::Netdb::structure::cascades;
  my @ForeignKeys = grep (/^$table\./, keys %Casc);

  my @ReturnRecs;
  foreach my $FK (@ForeignKeys) {
    foreach my $CR (@{$Casc{$FK}}) {
      my ($crRes, $crRecs) = CMU::Netdb::primitives::delete_cascade_xone
	($dbh, $table, $tid, $FK, $CR);
      return ($crRes, $crRecs) if ($crRes <= 0);
      foreach my $cdEntry (@$crRecs) {
	my ($lTable, $lTID) = @$cdEntry;
	my ($lxRes, $lxRef) = CMU::Netdb::primitives::delete_cascade_check
	  ($dbh, $dbuser, $lTable, $lTID, $depth + 1);
	return ($lxRes, $lxRef) if ($lxRes <= 0);
	push(@ReturnRecs, @$lxRef);
	push(@ReturnRecs, $cdEntry);
      }
    }
  }

  # Now we need to go through the ones that involve a table field 
  # referencing the foreign key table/tid.
  my %MRef = %CMU::Netdb::structure::multirefs;
  my @MKeys = grep { defined $MRef{$_}->{TableTrans}->{$table} } keys %MRef;

  # MKeys is now a list of all the MRef keys that we need to check
  foreach my $MK (@MKeys) {
    my ($mkRes, $mkRecs) = CMU::Netdb::primitives::delete_cascade_xmrone
      ($dbh, $table, $tid, $MK, $MRef{$MK});
    return ($mkRes, $mkRecs) if ($mkRes <= 0);
    foreach my $cdEntry (@$mkRecs) {
      my ($lTable, $lTID) = @$cdEntry;
      my ($lxRes, $lxRef) = CMU::Netdb::primitives::delete_cascade_check
	($dbh, $dbuser, $lTable, $lTID, $depth + 1);
      return ($lxRes, $lxRef) if ($lxRes <= 0);
      push(@ReturnRecs, @$lxRef);
      push(@ReturnRecs, $cdEntry);
    }
  }

  # We're all clear
  return (1, \@ReturnRecs);
}

# Check a single ref from %cascades

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified variables.
sub delete_cascade_xone {
  my ($dbh, $CTable, $CTID, $FK, $CR) = @_;

  my $saveSQLtime = '';
  if ($CR->{Outcome} ne 'delete' &&
      $CR->{Outcome} ne 'deleteOrUpdate') {
    # If the result is going to be fatal, no sense wasting the
    # SQL server's time giving us every record
    $saveSQLtime = ' LIMIT 0,1';
  }

  my $CascTable = $CR->{Primary};
  my $CTableName = $CascTable;
  my $CTableRef = $CascTable;
  if ($CascTable =~ /(\S+)\s+AS\s+(\S+)/i) {
    $CTableName = $1;
    $CTableRef = $2;
  }
  my $Query = "SELECT \"$CTableName\", $CTableRef.id, ".
    "$CTableRef.version FROM ".
    "$CTable, $CascTable WHERE $CTable.id = $CTID AND ".
      "$CR->{Where} $saveSQLtime";
  my $dref = $dbh->selectall_arrayref($Query);
  if (!ref $dref) {
    $db_errstr = $DBI::errstr;
    return ($CMU::Netdb::errors::errcodes{EDB}, 
	    ['d_c_xone', $CTable, $CTID, $FK, 
	     "selectall: $db_errstr"]);
  }

  if ($CR->{Outcome} ne 'delete' &&
      $CR->{Outcome} ne 'deleteOrUpdate') {
    # fatal if any rows were returned
    return ($CMU::Netdb::errors::errcodes{"ECASCADEFATAL"}, 
	    [$CascTable, $FK]) if ($#$dref != -1);
    return (1, []);
  }

  # we can cascade delete any records
  return (1, $dref);
}

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified variables.
sub delete_cascade_xmrone {
  my ($dbh, $CTable, $CTID, $MRName, $MR) = @_;

  my $saveSQLtime = '';
  if ($MR->{Outcome} ne 'delete' &&
      $MR->{Outcome} ne 'deleteOrUpdate') {
    # If the result is going be fatal, no sense wasting the
    # SQL server's time giving us every record
    $saveSQLtime = ' LIMIT 0,1';
  }
  
  my $TableRef = $MR->{TableRef};
  my $TIDRef = $MR->{TidRef};
  return ($CMU::Netdb::errors::errcodes{ENOENT}, [$CTable, 'table_trans'])
    unless (defined $MR->{TableTrans}->{$CTable});
  
  my $TableNeed = $MR->{TableTrans}->{$CTable};
  my $ForeignTable = $TableRef;
  $ForeignTable =~ s/\..*$//;

  my $Query = "SELECT \"$ForeignTable\", $ForeignTable.id, ".
    " $ForeignTable.version FROM $ForeignTable ".
      "WHERE $TableRef = '$TableNeed' AND $TIDRef = '$CTID' ".
	$saveSQLtime;
  
  warn __FILE__, ':', __LINE__, ' :>'.
    " delete_cascade_xmrone ($CTable, $CTID) query: $Query\n"
      if ($debug >= 2);
  
  my $dref = $dbh->selectall_arrayref($Query);
  if (!ref $dref) {
    $db_errstr = $DBI::errstr;
    return ($CMU::Netdb::errors::errcodes{EDB}, ['d_c_xmrone', $CTable, $CTID,
			     "selectall: $db_errstr"]);
  }
  
  if ($MR->{Outcome} ne 'delete' &&
      $MR->{Outcome} ne 'deleteOrUpdate') {
    # fatal if any rows returned
    return ($CMU::Netdb::errors::errcodes{"ECASCADEFATAL"}, 
	    [$ForeignTable, $MRName])
      if ($#$dref != -1);
    return (1, []);
  }
   
  # we can cascade delete any records
  return (1, $dref);
}

# Checks the permission to delete a specified table/record. We're
# modularizing this piece so that we can develop a list of all
# the cascade deletions that need to be done and then check permission
# to delete all the elements. If a single one fails, the whole thing
# needs to.
# Arguments:
#  - db handle
#  - database user
#  - table deleting from
#  - tid of table being deleted
# Returns:
#  - two element array
#    + first element: <= 0 is failure, == 1 is success
#    + second element: ref to array of return codes
#
## Safety Note: This functions does not use caller-specified variables
## in an unsafe manner.
sub delete_permission_check {
  my ($dbh, $dbuser, $table, $id) = @_;

  # If the table is 'protections', assume they have access; otherwise
  # we'd fail to verify access somewhere else. Protections entries
  # should only be deleted as part of a cascade delete addition
  return (1, []) if ($table eq 'protections');

  my $accessLevel = CMU::Netdb::auth::get_write_level($dbh, $dbuser, $table,
							$id);
  return (1, []) if ($accessLevel > 0);
  return ($CMU::Netdb::errors::errcodes{"EPERM"}, [$table, $id]);
}

# Function: Count
# Arguments: 3
#     An already connected database handle.
#     The name of the user performing the query
#     The name of the table to be queried
#     An optional where clause
# Actions: Counts the number of entries the user can see.
# Return value: 
#     A reference to an array, the 0th element being the integer count
#        Test for CMU::Netdb::valid return by (ref $result)
#     An error code is returned if a problem occurs (see CMU::netdb::errors.pm)

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses.
sub count {
  my ($dbh, $dbuser, $tablename, $where) = @_;
  my ($sth, $query, $key, $rows, $sTable, $tname);
  my @data = ();

  $tablename = CMU::Netdb::validity::valid('local.table_name_mult',
					   $tablename, $dbuser, 0, $dbh);
  return CMU::Netdb::validity::getError($tablename)
    if (CMU::Netdb::validity::getError($tablename) != 1);

  $dbuser = CMU::Netdb::valid('credentials.authid_perm', $dbuser, $dbuser, 0,
			      $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  return $CMU::Netdb::errors::errcodes{'EINVALID'}
    if ($where =~ m/union[\s\n]+select/is);

  $sTable = $tablename;
  # get rid of extra tables. ASSUME the first table is the key table
  $sTable =~ s/(\,|\s).*//;		# get rid of extra tables.
  $query = "SELECT P.tid ".<<END_SELECT;
FROM  (credentials AS C
 JOIN users as U ON C.user = U.id
 JOIN protections as P)
LEFT JOIN memberships as M ON (U.id = M.uid AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
WHERE
C.authid = '$dbuser'
AND P.tname = '$sTable'
AND FIND_IN_SET('READ', P.rights)
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, U.id, 0)
AND P.tid = 0
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::count query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::count error: $DBI::errstr";
    $db_errstr = $DBI::errstr;
    return $CMU::Netdb::errors::errcodes{"EDB"};
  } 
  my @row = $sth->fetchrow_array();
  if (@row && defined $row[0] && $row[0] eq '0') {
    $query = "SELECT COUNT($sTable.id) FROM $tablename";
    $query .= " WHERE $where " if ($where ne '');
    $sth = $dbh->prepare($query);
    if (!($sth->execute())) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::primitives::count error: $DBI::errstr";
      $db_errstr = $DBI::errstr;
      return $CMU::Netdb::errors::errcodes{"EDB"};
    } else {
      $rows = $sth->fetchrow_arrayref();
      if (ref $rows) {
	return $rows;
      } else {
	return [0];
      }
    }
  }
  
  $query = "SELECT COUNT(DISTINCT $sTable.id) ".<<ENDSELECT;
FROM  (credentials AS C
 JOIN users as U ON C.user = U.id, protections as P)
LEFT JOIN memberships as M ON (U.id = M.uid AND P.identity = CAST(M.gid AS SIGNED INT) * -1),
     $tablename
WHERE
C.authid = '$dbuser'
AND P.tname = '$sTable'
AND FIND_IN_SET('READ', P.rights)
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, U.id, 0)
AND
  (P.tid = $sTable.id)
ENDSELECT
  
  $query .= " AND $where " if ($where ne '');
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::primitives::count query: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  if (!($sth->execute())) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::count error: $DBI::errstr";
    $db_errstr = $DBI::errstr;
    return $CMU::Netdb::errors::errcodes{"EDB"};
  } else {
    $rows = $sth->fetchrow_arrayref();
    if (ref $rows) {
      return $rows;
    } else {
      return [0];
    }
  }
}


# Create an entry in _sys_changelog and return the rowid.
# args: database handle and user

## Safety Note: This function validates all caller-specified parameters
## except for the database handle.
sub changelog_start {
  my ($dbh, $dbuser) = @_;

  $dbuser = CMU::Netdb::valid('credentials.authid_perm', $dbuser, $dbuser, 0,
			      $dbh);
  return 0 if (CMU::Netdb::getError($dbuser) != 1);

  my $query = "INSERT INTO _sys_changelog (user, name, time, info) ".
    "SELECT C.user, '$dbuser', now(), '$changelog_info' ".
      "FROM credentials AS C WHERE C.authid = '$dbuser'";

  my $res = $dbh->do($query);
  if (!$res) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::changelog_start adding changelog: $DBI::errstr\n";
    return 0;
  } else {
    my $log = $dbh->{'mysql_insertid'};
    return $log;
  }
}

# If no changelog is already started, call changelog_start and store the 
# resulting rowid in $CMU::Netdb::primitives::changelog_id
# If a changelog is already started, just return that id, unless
# we're processing a request for a different user for some reason.
# FIXME: More logic should probably be added for when to change changelogs, but
# FIXME: this works for now
# args: database handle, user, and an optional third arg which if true will force
#       a new changelog creation.  if zero, forces inheritance.  if undef, default
#       behavior happens (currently always inherits)

## Safety Note: This function does not use caller-supplied arguments in an unsafe
## manner.

sub changelog_id {
  my ($dbh, $dbuser, $new) = @_;

  if ($new) {
    # caller forced new changelog generation
    $changelog_id = changelog_start($dbh, $dbuser);
    $changelog_user = $dbuser;
  } elsif (defined $new && $new == 0) {
    # caller force changelog inheritance
    # if no current changelog exists, or the changelog is for the wrong user, we 
    # must create a new one anyway
    if (!$changelog_id || ($changelog_user ne $dbuser && $dbuser ne 'netreg')) {
      $changelog_id = changelog_start($dbh, $dbuser);
      $changelog_user = $dbuser;
    }
  } else {
    # default behavior.
    # inherit existing changelogs
    # FIXME might change this to be different for web interface vs non web interface.

    if (!$changelog_id || ($changelog_user ne $dbuser && $dbuser ne 'netreg')) {
      # current log is for wrong user, create a new one
      $changelog_id = changelog_start($dbh, $dbuser);
      $changelog_user = $dbuser;
    }
    #elsif ($ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/) {
    #  # Running web interface, use the existing changelog id
    #} else {
    #  # create new changelog
    #}
  }

  return $changelog_id;

};

# clears any existing changelog id

## Safety Note: This function cleanses all caller-specified parameters.

sub clear_changelog {
  $changelog_id = 0;
  $changelog_user = "";
  $db_insertid = undef;
  $changelog_info = CMU::Netdb::helper::cleanse($_[0]) if (defined $_[0]);
}

# create a _sys_changerec_row entry, for one db row that is being changed.
# args: database handle, changelog id, table name, table row id, and
#       change type (INSERT, UPDATE, or DELETE)

## Safety Note: This function validates all caller-specified parameters
## except for the database handle.

sub changelog_row {
  my ($dbh, $log, $table, $row, $type) = @_;
  my ($clrow, $res); 

  $log = CMU::Netdb::validity::valid('_sys_changerec_row.changelog',
				     $log, 'netreg', 0, $dbh);
  return CMU::Netdb::validity::getError($log)
    if (CMU::Netdb::validity::getError($log) != 1);

  $table = CMU::Netdb::validity::valid('_sys_changerec_row.tname',
				       $table, 'netreg', 0, $dbh);
  return CMU::Netdb::validity::getError($table)
    if (CMU::Netdb::validity::getError($table) != 1);

  $row = CMU::Netdb::validity::valid('_sys_changerec_row.row',
				     $row, 'netreg', 0, $dbh);
  return CMU::Netdb::validity::getError($row)
    if (CMU::Netdb::validity::getError($row) != 1);

  $type = CMU::Netdb::validity::valid('_sys_changerec_row.type',
				     $type, 'netreg', 0, $dbh);
  return CMU::Netdb::validity::getError($type)
    if (CMU::Netdb::validity::getError($type) != 1);

  $res = $dbh->do("INSERT INTO _sys_changerec_row ".
		  "(changelog, tname, row, type) ".
		  " VALUES ('$log', '$table', '$row', '$type')");

  if (!$res) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::changelog_row error adding changerec_row: ".
	"$DBI::errstr\n";
    return 0;
  }

  $clrow = $dbh->{'mysql_insertid'};

  if ($netevent) {
    my ($count, $more) = $netevent->notify_row('netdb', $table, $row, $type);
    if ($more) {
      $netevent_process_columns = 1;
      $changelog_row_table = $table;
      $changelog_row = $row;
      $changelog_row_type = $type;
    } else {
      $netevent_process_columns = 0;
      $changelog_row_table = '';
      $changelog_row = '';
      $changelog_row_type = '';
    }
  }
  return $clrow;
}


# create a _sys_changerec_col entry, for one column of a db row that is being changed
# args: database handle, changelog_row id, column name, new column data, old column data
#       either the new or old data may be a reference to an array of a
#       column name, table, and a where clause, which will result in 
#       copying the data from the matching row into a changrec_col entry.
#       the where clause should only match one row, otherwise the results will
#       be nonsensical

## Safety Warning: This function is not safe for general export, due to the unvalidated
## use of caller-specified "where" clauses.

sub changelog_col {
  my ($dbh, $logrow, $name, $data, $previous) = @_;

  if (ref $data && ref $previous) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::changelog_col error two references passed in, aborting\n";
    return 0;
  }

  $logrow = CMU::Netdb::validity::valid('_sys_changerec_col.changerec_row',
					$logrow, 'netreg', 0, $dbh);
  return CMU::Netdb::validity::getError($logrow)
    if (CMU::Netdb::validity::getError($logrow) != 1);

  $name = CMU::Netdb::validity::valid('_sys_changerec_col.name',
				      $name, 'netreg', 0, $dbh);
  return CMU::Netdb::validity::getError($name)
    if (CMU::Netdb::validity::getError($name) != 1);

  my $insert = "INSERT INTO _sys_changerec_col (changerec_row, name";
  $insert .= ", data" if (defined $data);
  $insert .= ", previous" if (defined $previous);
  if (ref $data || ref $previous) {
    $insert .= ") SELECT '$logrow', '$name'";
  } else {
    $insert .= ") VALUES ( '$logrow', '$name'";
  }
  if (defined $data) {
    if (ref $data) {
      $data->[0] = CMU::Netdb::validity::valid('_sys_changerec_col.data_ref',
					       $data->[0], 'netreg', 0, $dbh);
      return CMU::Netdb::validity::getError($data->[0])
	if (CMU::Netdb::validity::getError($data->[0]) != 1);

      $insert .= ", " .$data->[0];
    } else {
      $insert .= ", " .$dbh->quote($data);
    }
  }
  if (defined $previous) {
    if (ref $previous) {
      $previous->[0] = CMU::Netdb::validity::valid
	('_sys_changerec_col.previous_ref', $previous->[0], 'netreg', 0, $dbh);

      return CMU::Netdb::validity::getError($previous->[0])
	if (CMU::Netdb::validity::getError($previous->[0]) != 1);

      $insert .= ", " .$previous->[0];
    } else {
      $insert .= ", " .$dbh->quote($previous);
    }
  }
  if (ref $data) {
    $data->[1] = CMU::Netdb::validity::valid('local.table_name',
					     $data->[1], 'netreg', 0, $dbh);
    return CMU::Netdb::validity::getError($data->[1])
      if (CMU::Netdb::validity::getError($data->[1]) != 1);

    # FIXME validate data->[2]. For now this falls into the general class
    # of "where clauses are hard to validate"

    $insert .= " FROM $data->[1] WHERE $data->[2]";
  } elsif (ref $previous) {
    $previous->[1] = CMU::Netdb::validity::valid('local.table_name',
						 $previous->[1], 'netreg',
						 0, $dbh);

    return CMU::Netdb::validity::getError($previous->[1])
      if (CMU::Netdb::validity::getError($previous->[1]) != 1);

    # FIXME validate previous->[2]. For now this falls into the general class
    # of "where clauses are hard to validate"

    $insert .= " FROM $previous->[1] WHERE $previous->[2]";
  } else {
    $insert .= ")";
  }

  warn __FILE__, ':', __LINE__, " :> CMU::Netdb::primitives::changelog_col: ".
    "query is $insert" if ($debug >= 3);
  my $res = $dbh->do($insert);
  if (!$res) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::primitives::changelog_row error adding changerec_col: ".
	"$DBI::errstr\n";
  }
  
  if ($netevent && $netevent_process_columns) {
    $netevent->notify_col($dbh, 'netdb', $changelog_row_table, $changelog_row, $changelog_row_type, $name, $data, $previous);
  }

  return 1;
}


1;
