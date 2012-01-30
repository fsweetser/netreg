#   -*- perl -*-
#
# CMU::Netdb::reports
#
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


package CMU::Netdb::reports;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug @sys_scheduled_fields 
	    %Queries %Query_Tables);

use CMU::Netdb;
use CMU::Netdb::helper;
use CMU::Netdb::primitives;
use CMU::Netdb::structure;
use CMU::Netdb::errors;
use CMU::Netdb::auth;
use CMU::Netdb::validity;
use CMU::Netdb::vars;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(rep_subnet_utilization rep_cname_by_machine rep_machines_by_user
	     rep_network_info general_query rep_query
	     list_scheduled modify_scheduled add_scheduled delete_scheduled
	     force_scheduled list_history search_history list_orphan_machines);


$debug = 0;

@sys_scheduled_fields = @CMU::Netdb::structure::sys_scheduled_fields;

my $fks =  CMU::Netdb::config::get_multi_conf_var('netdb', 'HistoryIDLookups');

#
# Arguments:
#   $dbh - database handle
#   $user - user to check permissions for
#   $query_name - hash key for %Queries and %Query_Tables hashes
#   $function - ptr to function that takes ptr to 2D array as arg.
#   $bindings - ptr to array of bindings for query
#
# Return value: if $function defined, whatever $function returns
#               otherwise, a ptr to a 2D array containing query results
#               or error code
#
# general_query gets query string and list of tables from %Queries and 
#  %Query_Tables and calls rep_query to perform the actual query.  
#  it will then execute $function (if defined) on the results of rep_query
#
# NOTE: if you are using $bindings but not using $function you MUST pass
#       $function as undef ex:
#
#   CMU::Netdb::general_query($dbh, $user, $query_name, undef, $bindings)
#

sub general_query { 
  my ($dbh, $user, $query_name, $function, $bindings) = @_; 
  
  my ($array_ref);
  
  $array_ref = CMU::Netdb::rep_query($dbh, $user, 
				     $CMU::Netdb::vars::Queries{$query_name}, 
				     $CMU::Netdb::vars::Query_Tables{$query_name},
				     $bindings);
  
  if ( ! ref $array_ref ) { 
    return $array_ref;		# returning error code
  }
  
  if ( ref $function ) { 
    return &$function($array_ref);
  }
  else {
    return $array_ref; 
  }
  
}

#
#  Arguments:
#   $dbh - database handle
#   $user - user to check permissions for
#   $query - string containing query to execute
#   $tables - ptr to array of tables to check $user Read access against. 
#             Note: user MUST have read level access to ALL tables in array
#   $bindings - ptr to array of bindings for string query refs.  
#               Note: $bindings must contain ordered values for each ? in 
#                     the query string.
#               
#   Returns: ptr to 2D array containing query results or error code
#    


sub rep_query {
  my ($dbh, $user, $query, $tables, $bindings) = @_;
  
  my ($rl, $table);
  
  foreach $table (@$tables) {
    $rl = CMU::Netdb::get_read_level($dbh, $user, $table, 0);
    return $errcodes{EPERM} if ($rl < 1);
  }
  
  my $query_results;
  my $sth = $dbh->prepare($query);
  if ( ref $bindings) {
    $sth->execute(@$bindings);
  }
  else { 
    $sth->execute;
  }
  
  $query_results = $sth->fetchall_arrayref;
  
  $sth->finish;
  
  return $query_results;
}

# Returns a list of all machines that have
# no users associated with then via protections
sub list_orphan_machines {
  my ($dbh, $user, $w) = @_;

  my @ret;

  my $rl = CMU::Netdb::get_read_level($dbh, $user, 'machine', 0);
  return $errcodes{EPERM} if ($rl < 9);

  my $query = <<END_ORPH;
select machine.id, machine.host_name, machine.mac_address, machine.ip_address from machine
 where machine.id not in (
     select tid from protections where tname = 'machine'
     and (identity > 0 or
          identity in ( select distinct -groups.id from groups, memberships where
                        (groups.name like 'dept:%' or groups.name like 'notify:%')
                        and groups.id = memberships.gid )
     )
 )
 and machine.mode in ('static', 'dynamic', 'secondary')
END_ORPH
  if($w){
      $query .= " and " . $w;
  }else{
      $query .= " order by machine.host_name";
  }

  my $sth = $dbh->prepare($query);
  $sth->execute;

  while(my @row = $sth->fetchrow_array){
    push @ret, [$row[0], $row[1], $row[2], $row[3]];
  }

  return \@ret;
}

sub rep_subnet_utilization {
  my ($dbh, $user) = @_;
  
  my $rl = CMU::Netdb::get_read_level($dbh, $user, 'subnet', 0);
  return $errcodes{EPERM} if ($rl < 1);
  
  my $query =<<END_SELECT;
SELECT subnet.id, subnet.name, count(machine.id) AS machinecount, 
  (host(broadcast(base_address))::inet - base_address - 2) AS totalnumber,
  machine.mode
  FROM machine, subnet
 WHERE ip_address_subnet = subnet.id
   AND NOT FIND_IN_SET('no_dhcp', subnet.flags)
   AND NOT FIND_IN_SET('delegated', subnet.flags)
   AND (machine.ip_address != '0.0.0.0' OR machine.mode = 'dynamic')
   AND subnet.name NOT LIKE '%QuickReg'
GROUP BY subnet.id, subnet.name, machine.mode, subnet.base_address
END_SELECT
  
  my %subnets;
  my $sth = $dbh->prepare($query);
  $sth->execute;
  my (@row, $sid, $sname, $used, $pool, $dynamic, $total);
  $sid = "";
  
  while(@row = $sth->fetchrow_array) {
    if ($row[0] != $sid) {
      if ($sid ne "") {
	$subnets{$sid} = [$sname, $used, $total, $dynamic, $pool];
      }
      $sid = $row[0];
      $sname = $row[1];
      $total = $row[3];
      $used = 0;
      $pool = 0;
      $dynamic = 0;
    }
    if ($row[4] eq 'dynamic') {
      $dynamic += $row[2];
    } elsif ($row[4] eq 'pool') {
      $pool += $row[2];
      $used += $row[2];
    } else {
      $used += $row[2];
    }
  }
  $subnets{$sid} = [$sname, $used, $total, $dynamic, $pool];
  $sth->finish;
  
  return \%subnets;
}

sub rep_cname_by_machine {
  my ($dbh, $user) = @_;
  
  my $rl = CMU::Netdb::get_read_level($dbh, $user, 'machine', 0);
  return $errcodes{EPERM} if ($rl < 1);
  
  my $query =<<END_SELECT;
SELECT COUNT(dns_resource.id) AS CT, machine.host_name, machine.id
  FROM machine, dns_resource
 WHERE dns_resource.type = 'CNAME'
   AND machine.host_name = dns_resource.rname
GROUP BY machine.host_name, machine.id ORDER BY CT DESC
END_SELECT
  
  my %cnames;
  my $sth = $dbh->prepare($query);
  $sth->execute;
  my @row;
  while(@row = $sth->fetchrow_array) {
    $cnames{$row[1]} = [$row[0], $row[2]];
  }
  $sth->finish;
  
  return \%cnames;
}

sub rep_machines_by_user {
  my ($dbh, $user) = @_;

  my $rl = CMU::Netdb::get_read_level($dbh, $user, 'machine', 0);
  return $errcodes{EPERM} if ($rl < 1);

  my $query =<<END_SELECT;
SELECT C.authid, C.description, COUNT(M.id) AS CT
  FROM machine AS M, credentials AS C LEFT JOIN users AS U ON (C.user = U.id),
       protections AS P
  WHERE U.id = P.identity
    AND P.tname = 'machine'
    AND P.tid = M.id
 GROUP BY C.authid, C.description ORDER BY CT DESC
END_SELECT

  my %stat;
  my $sth = $dbh->prepare($query);
  $sth->execute;
  my @row;
  while(@row = $sth->fetchrow_array) {
    $stat{$row[0]} = [$row[1], $row[2]];
  }
  $sth->finish;

  return \%stat;
}

sub list_scheduled {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "_sys_scheduled", \@sys_scheduled_fields, $where);
  
  if (!ref $result) { 
    return $result;
  }
  
  if ($#$result == -1) {
    return [\@sys_scheduled_fields];
  }
  
  @data = @$result;
  unshift @data, \@sys_scheduled_fields;
  
  return \@data;
}

sub add_scheduled {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@sys_scheduled_fields) {
    my $nk = $key;		# required because $key is a reference into sys_scheduled_fields
    $nk =~ s/^_sys_scheduled\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^_sys_scheduled\.$key$/, @sys_scheduled_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find _sys_scheduled.$key!\n".join(',', @sys_scheduled_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("_sys_scheduled.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "_sys_scheduled.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"_sys_scheduled.$key"} = $$fields{$key};
  }
  
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, '_sys_scheduled', $newfields);
  my %warns = (insertID => $CMU::Netdb::primitives::db_insertid);
  if ($res < 1) {
    return ($res, []);
  }
  return ($res, \%warns);
}

sub modify_scheduled {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields, @sch_short, %ofields, $orig);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('_sys_scheduled.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['sys_scheduled.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('_sys_scheduled.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['sys_scheduled.version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = CMU::Netdb::list_scheduled($dbh, $dbuser, "_sys_scheduled.id='$id'");
  return ($orig, ['id']) if (!ref $orig || !defined $orig->[1]);
  
  my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, '_sys_scheduled', $id);
  return ($errcodes{EPERM}, ['id']) if ($ul < 9);
  
  %ofields = ();
  foreach (@sys_scheduled_fields) {
    my $nk = $_;
    $nk =~ s/^_sys_scheduled\.//;
    push(@sch_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = ${$$orig[1]}[$i++] } @sch_short;
}
map { $$fields{$_} = $ofields{$_} if (!defined $$fields{$_}) } @sch_short;

## bidirectional verification of the fields that the user is trying to add
foreach $key (@sys_scheduled_fields) {
  my $nk = $key;		# required because $key is a reference into sys_scheduled_fields
  $nk =~ s/^_sys_scheduled\.//;
  $$fields{$nk} = '' 
    if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
}

foreach $key (keys %$fields) {
  if (! grep /^_sys_scheduled\.$key$/, @sys_scheduled_fields) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Couldn't find _sys_scheduled.$key!\n".join(',', @sys_scheduled_fields) if ($debug >= 2);
    return ($errcodes{"EINVALID"}, [$key]);
  }
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "Verifying $key\n" if ($debug >= 2);
  $$fields{$key} = CMU::Netdb::valid("_sys_scheduled.$key", $$fields{$key}, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
  warn __FILE__, ':', __LINE__, ' :>'.
    "_sys_scheduled.$key: $$fields{$key}\n" if ($debug >= 2);
  
  $$newfields{"_sys_scheduled.$key"} = $$fields{$key};
}

$result = CMU::Netdb::primitives::modify($dbh, $dbuser, '_sys_scheduled', $id, $version, $newfields);

if ($result == 0) {
  # An error occurred
  $query = "SELECT id FROM _sys_scheduled WHERE id='$id' AND version='$version'";
  $sth = $dbh->prepare($query);
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_scheduled: $query\n" if ($debug >= 2);
  $sth->execute();
  if ($sth->rows() == 0) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_scheduled: id/version were stale\n" if ($debug);
    return ($errcodes{"ESTALE"}, ['stale']);
  } else {
    return ($errcodes{"ERROR"}, ['unknown']);
  }
}

return ($result);

}

sub delete_scheduled {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, @sch_short, %ofields, $orig, $dref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('_sys_scheduled.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['sys_scheduled.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('_sys_scheduled.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['sys_scheduled.version']) if (CMU::Netdb::getError($version) != 1);
  
  $orig = CMU::Netdb::list_scheduled($dbh, $dbuser, "_sys_scheduled.id='$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  foreach (@sys_scheduled_fields) {
    my $nk = $_;
    $nk =~ s/^_sys_scheduled\.//;
    push(@sch_short, $nk);
  }
  {
    my $i = 0;
    map { $ofields{$_} = ${$$orig[1]}[$i++] } @sch_short;
}

($result, $dref) = CMU::Netdb::primitives::delete
  ($dbh, $dbuser, '_sys_scheduled', $id, $version);

if ($result != 1) {
  # An error occurred
  $query = "SELECT id FROM _sys_scheduled WHERE id='$id' AND version='$version'";
  $sth = $dbh->prepare($query);
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_scheduled: $query\n" if ($debug >= 2);
  $sth->execute();
  if ($sth->rows() == 0) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_scheduled: id/version were stale\n" if ($debug);
    return ($errcodes{"ESTALE"}, ['stale']);
  } else {
    return ($result, $dref);
  }
}

return ($result);

}

## Force a run of the scheduler soon.
sub force_scheduled {
  my ($dbh, $dbuser, $id, $version, $force) = @_;
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('_sys_scheduled.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['sys_scheduled.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('_sys_scheduled.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['sys_scheduled.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## Verify level 1 WRITE
  my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, '_sys_scheduled', $id);
  return ($errcodes{EPERM}, ['id']) if ($ul < 1);
  
  ## Send the update
  if ($force eq '1') {
    $dbh->do("UPDATE _sys_scheduled SET next_run = next_run + interval 1 ".
	     "hour WHERE id = '$id' AND version = '$version'");
  }else{
    $dbh->do("UPDATE _sys_scheduled SET next_run = now() WHERE id = '$id' AND version = '$version'");
  }
  return (1, "Update succeeded");
}

# searches for a given string in a specific table and column in the
# history, and returns a list of ids from the history that match it
sub search_history {
    my ($dbh, $dbuser, $table, $col, $match) = @_;

    my ($qstr, $sth, $data, $dapos, $res);

    $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);

    $table = CMU::Netdb::valid('_sys_changerec_row.tname', $table, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($table), ['tname']) if  (CMU::Netdb::getError($table) != 1);

    $col = CMU::Netdb::valid('_sys_changerec_col.name', $col, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($col), ['name']) if  (CMU::Netdb::getError($col) != 1);

    $match = CMU::Netdb::valid($table . '.' . $col, $match, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($match), ['match']) if  (CMU::Netdb::getError($match) != 1);

    return (-2, [$table])
        if (get_read_level($dbh, $dbuser, $table, 0) != 9);

    if ( $col eq 'id' ){
      $qstr = "select distinct _sys_changerec_row.row from _sys_changerec_row
where
 _sys_changerec_row.row = " . $dbh->quote($match) . " and
 _sys_changerec_row.tname = " . $dbh->quote($table) . "
 order by _sys_changerec_row.version";
    } else {

# There are more elegant ways to write this, but this seems fastest.

      $qstr =<<EndThisSelect;
SELECT _sys_changerec_row.row, _sys_changerec_row.version FROM _sys_changerec_row
 JOIN _sys_changerec_col ON _sys_changerec_col.changerec_row = _sys_changerec_row.id
      AND _sys_changerec_row.tname = '$table'
 where
   _sys_changerec_col.name = '$table.$col' and
   _sys_changerec_col.data = '$match'
UNION
SELECT _sys_changerec_row.row, _sys_changerec_row.version FROM _sys_changerec_row
 JOIN _sys_changerec_col ON _sys_changerec_col.changerec_row = _sys_changerec_row.id
      AND _sys_changerec_row.tname = '$table'
 where
   _sys_changerec_col.name = '$col' and
   _sys_changerec_col.data = '$match'
UNION
SELECT _sys_changerec_row.row, _sys_changerec_row.version FROM _sys_changerec_row
 JOIN _sys_changerec_col ON _sys_changerec_col.changerec_row = _sys_changerec_row.id
      AND _sys_changerec_row.tname = '$table'
 where
   _sys_changerec_col.name = '$table.$col' and
   _sys_changerec_col.previous = '$match'
UNION
SELECT _sys_changerec_row.row, _sys_changerec_row.version FROM _sys_changerec_row
 JOIN _sys_changerec_col ON _sys_changerec_col.changerec_row = _sys_changerec_row.id
      AND _sys_changerec_row.tname = '$table'
 where
   _sys_changerec_col.name = '$col' and
   _sys_changerec_col.previous = '$match'
EndThisSelect
    }

    warn __FILE__, ':', __LINE__, ' search_history:> query is '.$qstr if ($debug);

    $sth = $dbh->prepare($qstr);
    $sth->execute;

    $res = $sth->fetchall_arrayref;
    $sth->finish;

    $res = [ map {$_->[0]} sort {$a->[1] <=> $b->[1]} @$res ];

    return (1, $res);
}

sub list_history {
  my ($dbh, $dbuser, $table, $row) = @_;
  my ($sth, $data, $data2, $data3, $dapos);
  my ($query, $data4, $data5, $d2pos, $addons);
  my ($extra, $ind, $tiq_tid, $acl, $accum, $i, $j);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $table = CMU::Netdb::valid('_sys_changerec_row.tname', $table, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($table), ['tname']) if  (CMU::Netdb::getError($table) != 1);
  
  $row = CMU::Netdb::valid('_sys_changerec_row.row', $row, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($row), ['row']) if  (CMU::Netdb::getError($row) != 1);
  
# Make sure user can read the table in question...
  return (-2, [$table])
    if (get_read_level($dbh, $dbuser, $table, 0) != 9);
    

# Get all the rows for the table/row in question
  $query = "SELECT " . join(',', @CMU::Netdb::structure::history_fields);
  $query .= " from _sys_changelog join _sys_changerec_row ";
  $query .= " on _sys_changelog.id = _sys_changerec_row.changelog ";
  $query .= " left join _sys_changerec_col on ";
  $query .= " _sys_changerec_row.id = _sys_changerec_col.changerec_row where ";
  $query .= " _sys_changerec_row.tname = '$table' and _sys_changerec_row.row = '$row'";
  $query .= " order by _sys_changelog.id, _sys_changerec_row.id, _sys_changerec_col.id";
# Don't get Too carried away
  $query .= " limit 1000";

  $sth = $dbh->prepare($query);
  $sth->execute;
  $data = $sth->fetchall_arrayref;
  $sth->finish;

# Get row ID for all protection add/change/delete that contain
#  the table name and row ID in question.
# This may look ugly, but the 'or' version takes 6 minutes to run and this takes less than a second.
  $query =<<END_SELECT2;
 SELECT DISTINCT r1.row 
  FROM _sys_changerec_row r1,
        _sys_changerec_col c1,
        _sys_changerec_col c2
  WHERE c1.changerec_row = c2.changerec_row and
        c1.changerec_row = r1.id and
        r1.tname = 'protections' and
        c1.name = 'tname' and
        (c1.data = '$table') and
        c2.name = 'tid' and
        (c2.data = '$row')
union
 SELECT DISTINCT r1.row
   FROM _sys_changerec_row r1,
        _sys_changerec_col c1,
        _sys_changerec_col c2
  WHERE c1.changerec_row = c2.changerec_row and
        c1.changerec_row = r1.id and
        r1.tname = 'protections' and
        c1.name = 'tname' and
        (c1.previous = '$table') and
        c2.name = 'tid' and
        (c2.data = '$row')
union
 SELECT DISTINCT r1.row
   FROM _sys_changerec_row r1,
        _sys_changerec_col c1,
        _sys_changerec_col c2
  WHERE c1.changerec_row = c2.changerec_row and
        c1.changerec_row = r1.id and
        r1.tname = 'protections' and
        c1.name = 'tname' and
        (c1.previous = '$table') and
        c2.name = 'tid' and
        (c2.previous = '$row')
union
 SELECT DISTINCT r1.row
   FROM _sys_changerec_row r1,
        _sys_changerec_col c1,
        _sys_changerec_col c2
  WHERE c1.changerec_row = c2.changerec_row and
        c1.changerec_row = r1.id and
        r1.tname = 'protections' and
        c1.name = 'tname' and
        (c1.data = '$table') and
        c2.name = 'tid' and
        (c2.previous = '$row')

;

END_SELECT2

  $sth = $dbh->prepare($query);
  $sth->execute();
  $data2 = $sth->fetchall_arrayref;
  $sth->finish;

# grab the row ID for all current protections on the table/row
# in question (So we can get updates too)

  $query =  "SELECT DISTINCT id from protections where ";
  $query .= " tname = '$table' and tid = '$row'";
  
  $sth = $dbh->prepare($query);
  $sth->execute();
  $data4 = $sth->fetchall_arrayref;
  $sth->finish;
  
  push(@$data2, @$data4);
  
  # Get the history fields that are in those change records.
  $query  = "SELECT " . join(',', @CMU::Netdb::structure::history_fields);
  $query .= " from _sys_changelog join _sys_changerec_row ";
  $query .= " on _sys_changelog.id = _sys_changerec_row.changelog ";
  $query .= " left join _sys_changerec_col on ";
  $query .= " _sys_changerec_row.id = _sys_changerec_col.changerec_row where ";
  $query .= " _sys_changerec_row.row in (" . join(',', map {$_->[0]} @$data2) . ")" ;
  $query .= " and _sys_changerec_row.tname = 'protections'";
  
  $sth = $dbh->prepare($query);
  $sth->execute();
  $data3 = $sth->fetchall_arrayref;
  $sth->finish;
  push(@$data, @$data3);
  
  $addons =  CMU::Netdb::config::get_multi_conf_var('netdb', 'HistoryQueries');

  if (defined $addons->{$table}) {
    foreach $extra (keys (%{$addons->{$table}})) {

# Check to make sure that the user can read this table
      next if (($acl = get_read_level($dbh, $dbuser, $extra, 0)) != 9);


# Get the row ID for historic changes      
	$ind = $addons->{$table}{$extra}{indicator};
      $tiq_tid = $addons->{$table}{$extra}{tiq_row};
# This looks ugly, but it is MUCH faster than the 'or'& rlike version.

      $accum = [];
      foreach $i ($ind, "$extra.$ind") {
        foreach $j ($tiq_tid, "$extra.$tiq_tid") {

          $query =  "SELECT DISTINCT r1.row \n";
          $query .= "   FROM _sys_changerec_row r1, \n";
          $query .= "        _sys_changerec_col c1, \n" if ((defined $ind) && ($ind ne ''));
          $query .= "        _sys_changerec_col c2\n";
          $query .= "  WHERE\n";
          $query .= "       c1.changerec_row = c2.changerec_row and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "       c2.changerec_row = r1.id and\n";
          $query .= "   r1.tname = '$extra' and\n";
          $query .= "       c1.name = '$i' and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   (c1.data = '$table') and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   c2.name = '$j' and\n";
          $query .= "   (c2.data = '$row')\n";
          $query .= " UNION \n";
          $query .=  "SELECT DISTINCT r1.row \n";
          $query .= "   FROM _sys_changerec_row r1, \n";
          $query .= "        _sys_changerec_col c1, \n"if ((defined $ind) && ($ind ne '')) ;
          $query .= "        _sys_changerec_col c2\n";
          $query .= "  WHERE\n";
          $query .= "       c1.changerec_row = c2.changerec_row and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "       c2.changerec_row = r1.id and\n";
          $query .= "   r1.tname = '$extra' and\n";
          $query .= "       c1.name = '$i' and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   (c1.data = '$table') and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   c2.name = '$j' and\n";
          $query .= "   (c2.previous = '$row')\n";
          $query .= " UNION \n";
          $query .=  "SELECT DISTINCT r1.row \n";
          $query .= "   FROM _sys_changerec_row r1, \n";
          $query .= "        _sys_changerec_col c1, \n" if ((defined $ind) && ($ind ne ''));
          $query .= "        _sys_changerec_col c2\n";
          $query .= "  WHERE\n";
          $query .= "       c1.changerec_row = c2.changerec_row and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "       c2.changerec_row = r1.id and\n";
          $query .= "   r1.tname = '$extra' and\n";
          $query .= "       c1.name = '$i' and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   (c1.previous = '$table') and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   c2.name = '$j' and\n";
          $query .= "   (c2.data = '$row')\n";
          $query .= " UNION \n";
          $query .=  "SELECT DISTINCT r1.row \n";
          $query .= "   FROM _sys_changerec_row r1, \n";
          $query .= "        _sys_changerec_col c1, \n" if ((defined $ind) && ($ind ne ''));
          $query .= "        _sys_changerec_col c2\n";
          $query .= "  WHERE\n";
          $query .= "       c1.changerec_row = c2.changerec_row and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "       c2.changerec_row = r1.id and\n";
          $query .= "   r1.tname = '$extra' and\n";
          $query .= "       c1.name = '$i' and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   (c1.previous = '$table') and\n" if ((defined $ind) && ($ind ne ''));
          $query .= "   c2.name = '$j' and\n";
          $query .= "   (c2.previous = '$row')";

          $sth = $dbh->prepare($query);
          $sth->execute();
          $data2 = $sth->fetchall_arrayref;
          $sth->finish;
          push(@$accum, @$data2);
        }
      }

      $data2 = $accum;


# Get rows currently associated with entry
      $query =  "SELECT DISTINCT id from $extra where ";
      $query .= "$tiq_tid = '$row'";

      $sth = $dbh->prepare($query);
      $sth->execute();
      $data4 = $sth->fetchall_arrayref;
      $sth->finish;
      
      push(@$data2, @$data4);


      if (@$data2) {
	$query =  "SELECT " . join(',', @CMU::Netdb::structure::history_fields). "\n";
	$query .= " from _sys_changelog join _sys_changerec_row \n";
	$query .= "on _sys_changelog.id = _sys_changerec_row.changelog \n";
	$query .= "left join _sys_changerec_col on \n";
	$query .= "_sys_changerec_row.id = _sys_changerec_col.changerec_row where \n";
	$query .= "_sys_changerec_row.tname = '$extra' and\n";
	$query .= "_sys_changerec_row.row in (" . join(',', map {$_->[0]} @$data2) . ")\n";
	
	$sth = $dbh->prepare($query);
	$sth->execute();
	$data3 = $sth->fetchall_arrayref;
	$sth->finish;

	push(@$data, @$data3);
      }
      
      
    }
  }

  $dapos = CMU::Netdb::makemap(\@CMU::Netdb::structure::history_fields );
  map {
    if ($_->[$dapos->{'_sys_changerec_col.name'}] eq 'identity') {
      if ((defined $_->[$dapos->{'_sys_changerec_col.data'}]) && ($_->[$dapos->{'_sys_changerec_col.data'}] ne '' )) {
	if (($_->[$dapos->{'_sys_changerec_col.data'}] ne '' ) && ($_->[$dapos->{'_sys_changerec_col.data'}] > 0)) {
	  $data2 = CMU::Netdb::list_credentials($dbh, $dbuser, "credentials.user = $_->[$dapos->{'_sys_changerec_col.data'}]");
	} else {
	  $data2 = CMU::Netdb::list_groups($dbh, $dbuser, "groups.id = ($_->[$dapos->{'_sys_changerec_col.data'}] * -1)");
	}
	$d2pos = CMU::Netdb::makemap(shift(@$data2));
	if (scalar($data2)) {
	  if (defined $d2pos->{'credentials.authid'}) {
	    $_->[$dapos->{'_sys_changerec_col.data'}] .= "($data2->[0][$d2pos->{'credentials.authid'}])";
	  } else {
	    $_->[$dapos->{'_sys_changerec_col.data'}] .= "($data2->[0][$d2pos->{'groups.name'}])";
	  }
	}
      }

      if ((defined $_->[$dapos->{'_sys_changerec_col.previous'}]) && ($_->[$dapos->{'_sys_changerec_col.previous'}] ne '' )) {
	if (($_->[$dapos->{'_sys_changerec_col.previous'}] ne '' ) && ($_->[$dapos->{'_sys_changerec_col.previous'}] > 0)) {
	  $data2 = CMU::Netdb::list_credentials($dbh, $dbuser, "credentials.user = $_->[$dapos->{'_sys_changerec_col.previous'}]");
	} else {
	  $data2 = CMU::Netdb::list_groups($dbh, $dbuser, "groups.id = ($_->[$dapos->{'_sys_changerec_col.previous'}] * -1)");
	}
	$d2pos = CMU::Netdb::makemap(shift(@$data2));
	if (scalar($data2)) {
	  if (defined $d2pos->{'credentials.authid'}) {
	    $_->[$dapos->{'_sys_changerec_col.previous'}] .= "($data2->[0][$d2pos->{'credentials.authid'}])";
	  } else {
	    $_->[$dapos->{'_sys_changerec_col.previous'}] .= "($data2->[0][$d2pos->{'groups.name'}])";
	  }
	}
      }

    }
  } @$data;

  $data = [ sort {
    if ($a->[$dapos->{'_sys_changelog.id'}] != $b->[$dapos->{'_sys_changelog.id'}] ) {
      $b->[$dapos->{'_sys_changelog.id'}] <=> $a->[$dapos->{'_sys_changelog.id'}];
    } elsif ($a->[$dapos->{'_sys_changerec_row.id'}] != $b->[$dapos->{'_sys_changerec_row.id'}] ) {
      $a->[$dapos->{'_sys_changerec_row.id'}] <=> $b->[$dapos->{'_sys_changerec_row.id'}];
    } elsif ($a->[$dapos->{'_sys_changerec_col.id'}] != $b->[$dapos->{'_sys_changerec_col.id'}] ) {
      $a->[$dapos->{'_sys_changerec_col.id'}] <=> $b->[$dapos->{'_sys_changerec_col.id'}];
    } else {
      $a->[$dapos->{'_sys_changerec_col.name'}] cmp $b->[$dapos->{'_sys_changerec_col.name'}];
    }
  } @$data ];
  unshift(@$data, [ @CMU::Netdb::structure::history_fields ]);
  return($data);
}

1;
