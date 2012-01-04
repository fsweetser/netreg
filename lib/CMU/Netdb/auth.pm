#   -*- perl -*-
#
# CMU::Netdb::auth
# This module provides the necessary API functions for
# manipulating user/group/memberships/protections data
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

## ************************************************************************
## A few words about groups
##   The system is beginning to have hard-coded assumptions about groups
## and the like. This is a quick record of what the assumptions are.
##
## netreg:admins is the god-group. Can update all protections, etc.
## netreg:% means you will receive the admin status bar but DOES NOT
##  give you any additional system access. This must be done through the
##  protections table.
## dept:% means you are a department admin. These groups are treated
##  differently since i.e. all machines must be affiliated via this mechanism
##  with one department
## *************************************************************************

package CMU::Netdb::auth;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug @users_fields @groups_fields
	    @credentials_fields
	    @memberships_fields @protections_fields %groups_pos
	    $useradm $useradmStatus $usergroupadm $usergroupadmStatus
	    $userdeptadm $userdeptadmStatus
);

use CMU::Netdb;
use CMU::Netdb::structure;
use CMU::Netdb::errors;
use CMU::Netdb::validity;

use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(clear_user_admin_status
	     clear_user_deptadmin_status
	     clear_user_group_admin_status

	     list_users
	     list_credentials
	     list_groups
	     list_groups_administered_by_user
	     list_memberships_of_user
	     list_members_of_group
	     list_protections
	     get_departments
             list_user_default_group

	     add_user
	     add_group
	     add_user_to_group
	     add_user_to_protections
	     add_group_to_protections
	     add_credentials

	     modify_user
	     modify_group
	     modify_user_protection
	     modify_group_protection
	     modify_credentials

	     delete_user_from_group
	     delete_user_from_protections
	     delete_group_from_protections
	     delete_protection_tid

	     delete_user
	     delete_group
	     delete_credentials

	     get_add_level
	     get_read_level
	     get_write_level
	     get_user_admin_status
	     get_user_group_admin_status
	     get_user_deptadmin_status
	     get_user_netreg_admin

	     apply_prot_profile
	    );

@users_fields = @CMU::Netdb::structure::users_fields;
@credentials_fields = @CMU::Netdb::structure::credentials_fields;
@groups_fields = @CMU::Netdb::structure::groups_fields;
@protections_fields = @CMU::Netdb::structure::protections_fields;
@memberships_fields = @CMU::Netdb::structure::memberships_fields;

%groups_pos = %{CMU::Netdb::helper::makemap(\@CMU::Netdb::structure::groups_fields)};

$debug = 0;
($useradm, $useradmStatus, $usergroupadm, $usergroupadmStatus,
 $userdeptadm, $userdeptadmStatus) = ('', 0, '', 0, '', 0);

# Function: get_add_level
# Arguments: 4:
#    db handle
#    user
#    table
#    table ID
# Actions: returns the add level for the user on the specified table
# Returns: add level or <= 0, error code (0 if no level at all)
sub get_add_level {
  my ($dbh, $user, $table, $tid) = @_;
  my ($query, $result, $sth, @data, @tables, @row);

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::get_add_level: Caller: ".join('::',caller())."\n" if ($debug >= 2);

  $user = CMU::Netdb::valid('credentials.authid', $user, $user, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  # I believe this is wrong, add permissions have different semantics on
  # rows vs. tables.  I've looked at every piece of code that currently calls
  # get_add_level with $tid non-zero, and I believe they all expect the 'add access to row'
  # behavior, which should really be changed to a new permission right, called REFER.
  # -vitroth 11/2/2004
  # my $TidSelect = ($tid == 0 ? "P.tid = 0" : "(P.tid = '$tid' OR P.tid = 0)");

  my $TidSelect = ($tid == 0 ? "P.tid = 0" : "P.tid = '$tid'");

  $query = <<END_SELECT;
SELECT MAX(P.rlevel)
FROM (credentials AS C, protections as P)
LEFT JOIN memberships as M ON (C.user = M.uid AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
WHERE
  C.authid = '$user'
AND  P.tname = '$table'
AND  FIND_IN_SET('ADD', P.rights)
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, C.user, 0)
AND $TidSelect
GROUP BY P.tname
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::get_add_level: $query\n" if ($debug >= 2);

  $sth = $dbh->prepare($query);

  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'. 
      "CMU::Netdb::auth::get_add_level: $DBI::errstr";
    return $errcodes{"ERROR"};
  } else {
    @row = $sth->fetchrow_array;
    if (@row && defined $row[0]) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Returning $row[0]\n" if ($debug >= 2);
      return $row[0];
    }else{
      return 0;
    }
  }
}

# Function: get_read_level
# Arguments: 3:
#    db handle
#    user
#    table
# Actions: returns the read level for the user on the specified table
# Returns: read level or <= 0, error code (0 if no level at all)
sub get_read_level {
  my ($dbh, $user, $table, $tid) = @_;
  my ($query, $result, $sth, @data, @tables, @row);

  $user = CMU::Netdb::valid('credentials.authid', $user, $user, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  my $TidSelect = ($tid == 0 ? "P.tid = 0" : "(P.tid = '$tid' OR P.tid = 0)");

  $query = <<END_SELECT;
SELECT MAX(P.rlevel)
FROM (credentials AS C, protections as P)
LEFT JOIN memberships as M ON (C.user = M.uid AND P.identity = CAST(M.gid AS SIGNED INT) * -1)

WHERE
  C.authid = '$user'
AND  P.tname = '$table'
AND  FIND_IN_SET('READ', P.rights)
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, C.user, 0)
AND $TidSelect
GROUP BY P.tname
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::get_read_level: $query\n" if ($debug >= 2);

  $sth = $dbh->prepare($query);

  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::get_read_level: $DBI::errstr";
    return $errcodes{"ERROR"};
  } else {
    @row = $sth->fetchrow_array;
    if (@row && defined $row[0]) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Returning $row[0]\n" if ($debug >= 2);
      return $row[0];
    }else{
      return 0;
    }
  }
}

# Function: get_write_level
# Arguments: 3:
#    db handle
#    user
#    table
# Actions: returns the write level for the user on the specified table
# Returns: write level or <= 0, error code (0 if no level at all)
sub get_write_level {
  my ($dbh, $user, $table, $tid) = @_;
  my ($query, $result, $sth, @data, @tables, @row);

  $user = CMU::Netdb::valid('credentials.authid', $user, $user, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  my $TidSelect = ($tid == 0 ? "P.tid = 0" : "(P.tid = '$tid' OR P.tid = 0)");

  $query = <<END_SELECT;
SELECT MAX(P.rlevel)
FROM (credentials AS C, protections as P)
LEFT JOIN memberships as M ON (C.user = M.uid AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
WHERE
  C.authid = '$user'
AND  P.tname = '$table'
AND  FIND_IN_SET('WRITE', P.rights)
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, C.user, 0)
AND $TidSelect
GROUP BY P.tname
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::get_write_level: $query\n" if ($debug >= 2);

  $sth = $dbh->prepare($query);

  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::get_write_level: $DBI::errstr";
    return $errcodes{"ERROR"};
  } else {
    @row = $sth->fetchrow_array;
    if (@row && defined $row[0]) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Returning $row[0]\n" if ($debug >= 2);
      return $row[0];
    }else{
      return 0;
    }
  }
}

# Function: list_users
# Arguments: 3:
#     An already connected database handle.
#     The name of the user making the request
#     An optional string to be used as a WHERE clause.  
#        i.e. "name = \"ju22's group\""
# Actions: Queries the database in the handle for rows in the users table
#          which conform to the WHERE clause (if any)
# Return value: 
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_users {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  my @Fields = (@users_fields, @credentials_fields);

  # This is a little hacky, but this query is taking too long otherwise.
  my $Join = 'LEFT JOIN';
  if ($where =~ /credentials.\w+\s*=/ || $where =~ /credentials.\w+\s*like/) {
    $Join = 'JOIN';
  }

  $result = CMU::Netdb::primitives::list
    ($dbh, $dbuser, "users $Join credentials ON credentials.user = users.id",
     \@Fields, $where);

  if (!ref $result) {
    return $result;
  }

  if ($#$result == -1) {
    return [\@Fields];
  }

  @data = @$result;
  unshift @data, \@Fields;

  return \@data;
}

# Function: list_credentials
# Arguments: 3:
#     An already connected database handle.
#     The name of the user making the request
#     An optional string to be used as a WHERE clause.
# Actions: Queries the database in the handle for rows in the crednetials table
#          which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_credentials {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  my @Fields = @credentials_fields;

  $result = CMU::Netdb::primitives::list($dbh, $dbuser, 'credentials',
					 \@Fields, $where);

  if (!ref $result) {
    return $result;
  }

  if ($#$result == -1) {
    return [\@Fields];
  }

  @data = @$result;
  unshift @data, \@Fields;

  return \@data;
}

# Function: list_user_default_group
# Arguments: 3:
#     An already connected database handle.
#     The name of the user making the request
#     The user in question
# Actions: Queries the database to determine the default group for this user
# Return value:
#     A reference to an hash containing two keys, 'group' and 'desc', which contain
#     information regarding the default group
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_user_default_group {
  my ($dbh, $dbuser, $user) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('credentials.authid', $dbuser, $user, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  my @Fields = (@users_fields, @groups_fields);

  $result = CMU::Netdb::primitives::list($dbh, $dbuser, 'users, groups, credentials',
                                         \@Fields, 'users.default_group = groups.id AND '.
				         'users.id = credentials.user AND '.
					 'credentials.authid = "'.$user.'"');

  if (!ref $result) {
    return(-1, {});
  }

  if ($#$result == -1) {
    return (-1, {});
  }

  my %map = %{CMU::Netdb::makemap(\@Fields)};
  my %DGroup = ('group' => $result->[0]->[$map{'groups.name'}],
		'desc' => $result->[0]->[$map{'groups.description'}]);

  return (1, \%DGroup);
}

# Function: list_groups
# Arguments: 3:
#     An already connected database handle.
#     The name of the user making the request
#     An optional string to be used as a WHERE clause.
#        i.e. "name = \"ju22's group\""
# Actions: Queries the database in the handle for rows in the groups table
#          which conform to the WHERE clause (if any)
# Return value:
#     A reference to an array of references to arrays containing values
#        for each row which matched the query.  The first array contains
#        the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_groups {
  my ($dbh, $dbuser, $where) = @_;
  my ($result, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $result = CMU::Netdb::primitives::list($dbh, $dbuser, "groups", 
					 \@groups_fields, $where);

  if (! ref $result) {
    return $result;
  }
  if ($#$result == -1) {
    return [\@groups_fields];
  }

  @data = @$result;
  unshift @data, \@groups_fields;

  return \@data;
}


# Function: list_memberships_of_user
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     The name of the user whose memberhsips are to be queried
# Actions: Queries the database for the users memberships
# Return value: 
#     A reference to an array of references to arrays containing 
#        values for each group which matched the query.  The first array 
#        contains the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_memberships_of_user {
  my ($dbh, $dbuser, $user) = @_;
  my ($query, $result, $rows, $sth, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);
  
  if (CMU::Netdb::get_user_admin_status($dbh, $dbuser) > 0) {
    $query = "SELECT " . (join ', ', @groups_fields) . <<END_SELECT;

FROM groups, credentials, memberships
WHERE 
  credentials.authid = '$user'
AND 
  credentials.user = memberships.uid
AND 
  groups.id = memberships.gid
END_SELECT
  } else {
    $query = "SELECT DISTINCT " . (join ', ', @groups_fields) . <<END_SELECT;
    
FROM (groups, credentials, memberships, credentials AS C, protections as P)
LEFT JOIN memberships as M ON (M.uid = C.user AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
WHERE C.authid = '$dbuser'
AND P.tname = 'groups'
AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, C.user, 0)
AND FIND_IN_SET('READ', P.rights)
AND P.rlevel >= 5
AND (P.tid = groups.id OR P.tid = 0)
AND groups.id = memberships.gid
AND memberships.uid = credentials.user
AND credentials.authid = '$user'
END_SELECT

  }
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::list_memberships_of_user: $query\n" if ($debug >= 2);

  $sth = $dbh->prepare($query);

  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::list_memberships_of_user: $DBI::errstr";
    return $errcodes{"ERROR"};
  } else {
    $rows = $sth->fetchall_arrayref();
    if (ref $rows) {
      @data = @$rows;
      unshift @data, \@groups_fields;
      return \@data;
    } else {
      return [\@users_fields];
    }
  }
}


# Function: list_groups_administered_by_user
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     The name of the user whose memberhsips are to be queried
# Actions: Queries the database for the list of groups the user has write 
#          access to at level 5 or higher
# Return value: 
#     A reference to an array of references to arrays containing 
#        values for each group which matched the query.  The first array 
#        contains the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_groups_administered_by_user {
  my ($dbh, $dbuser, $user) = @_;
  my ($query, $result, $rows, $sth, @data);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  return $errcodes{EPERM}
    if (!(
	  ($dbuser == $user) || 
	  (CMU::Netdb::get_user_admin_status($dbh, $dbuser) > 0)
	 ));

  $query = "SELECT DISTINCT " . (join ', ', @groups_fields) . <<END_SELECT;

FROM      groups, credentials AS C, protections
LEFT JOIN memberships ON (memberships.uid = C.user AND
                          protections.identity = CAST(memberships.gid AS SIGNED INT) * -1)
WHERE
  C.authid = '$user'
AND protections.tname = 'groups'
AND protections.identity IN (CAST(memberships.gid AS SIGNED INT) * -1, C.user, 0)
AND FIND_IN_SET('WRITE', protections.rights)
AND protections.rlevel >= 5
AND groups.id = protections.tid
END_SELECT
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::list_groups_administered_by_user: $query\n" if ($debug >= 2);
  
  $sth = $dbh->prepare($query);
  
  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::list_groups_administered_by_user: $DBI::errstr";
    return $errcodes{"ERROR"};
  } else {
    $rows = $sth->fetchall_arrayref();
    if (ref $rows) {
      @data = @$rows;
      unshift @data, \@groups_fields;
      return \@data;
    } else {
      return [\@users_fields];
    }
  }
}

# Function: list_members_of_group
# Arguments: 3:
#     An already connected database handle
#     The name of the user making the request
#     The name of the group whose memberhsips are to be queried
# Actions: Queries the database for the groups memberships
# Return value: 
#     A reference to an array of references to arrays containing 
#        values for each user which matched the query.  The first array 
#        contains the field names.
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_members_of_group {
  my ($dbh, $dbuser, $group, $where) = @_;
  my ($query, $result, $rows, $sth, @data);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  my $ul = CMU::Netdb::get_read_level($dbh, $dbuser, 'groups', $group);
  return $errcodes{EPERM} if ($ul < 5);

  my @Fields = (@users_fields, @credentials_fields);
  my $grIDquery = '';
  if ($group =~ /^\d+$/) {
    $grIDquery = "groups.id = '$group'";
  }else{
    $grIDquery = "groups.name = '$group'";
  }

  $query = "SELECT " . (join ', ', @Fields) . <<END_SELECT;

FROM groups, users, memberships, credentials
WHERE
  credentials.user = users.id
AND $grIDquery
AND users.id = memberships.uid
AND groups.id = memberships.gid
END_SELECT
  $query .= " AND $where" if ($where ne '');

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::list_members_of_group: $query\n" if ($debug >= 2);

  $sth = $dbh->prepare($query);

  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::list_members_of_group: $DBI::errstr";
    return $errcodes{"ERROR"};
  } else {

    $rows = $sth->fetchall_arrayref();
    if (ref $rows) {
      @data = @$rows;
      unshift @data, \@Fields;
      return \@data;
    } else {
      return [\@Fields];
    }
  }
}


# Function: list_protections
# Arguments: :
#     An already connect database handle.
#     The name of the user performing the query.
#     The table to query the protections of
#     The row to query the protections of
# Actions: Queries the database for users and groups with access to
#          the table/row specified.  NOTE: This only returns explicit matches,
#          If you want to see who has access to the ENTIRE table, you must
#          search on row id 0.
# Return value:
#     If successful, a reference to an array of arrays, of the form
#       [["user", "username", "rights", "rlevel"],["user","username", "rights"],
#        ["group", "groupname", "rights, ... ]
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub list_protections {
  my ($dbh, $dbuser, $table, $row, $where) = @_;
  my ($query, $sth, $result, @data, $rows, $i);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($table) if (CMU::Netdb::getError($table) != 1);
  
  $row = CMU::Netdb::valid("$table.id", $row, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($row) if (CMU::Netdb::getError($row) != 1);
  
  return $errcodes{EPERM} if (auth_prot_op($dbh, $dbuser, $table, $row, 1, 'READ', '', '') < 1);
  
  $query = <<END_SELECT;
SELECT C.authid, G.name, P.rights, P.rlevel
FROM protections AS P
  LEFT JOIN users AS U
    ON P.identity = U.id
  LEFT JOIN credentials AS C
    ON U.id = C.user
  LEFT JOIN groups AS G
    ON P.identity = (CAST(G.id AS SIGNED INT) * -1)
WHERE
  P.tname = \"$table\"
AND
  P.tid = '$row'
END_SELECT
  $query .= " AND $where" if ((defined $where) && ($where ne ''));

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::list_protections: $query\n" if ($debug >= 2);

  $sth = $dbh->prepare($query);
  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::list_protections: Unknown error\n$DBI::errstr\n" if ($debug);
    return $errcodes{"ERROR"};
  }
  
  $rows = $sth->fetchall_arrayref();
  
  for ($i = 0; $i <= $#$rows; $i++) {
    if ($rows->[$i]->[0]) {
      push @data, ["user", $rows->[$i]->[0], $rows->[$i]->[2], $rows->[$i]->[3]];
    } elsif ($rows->[$i]->[1]) {
      push @data, ["group", $rows->[$i]->[1], $rows->[$i]->[2], $rows->[$i]->[3]];
    } else {
      push @data, ["group", "system:anyuser", $rows->[$i]->[2], $rows->[$i]->[3]];
      # No matching entries, an error???  FIXME
    }
  }
  return \@data;
}



# Function: add_user
# Arguments: 3
#     An already connect database handle.
#     The name of the user performing the query.
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_user {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid']) if (CMU::Netdb::getError($dbuser) != 1);
  
  
  ## bidirectional verification of the fields that the user is trying to add
  
  foreach $key (@users_fields) {
    my $nk = $key; 
    $nk =~ s/^users\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^users\.$key$/, @users_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find users.$key!\n".join(',', @users_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("users.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "users.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"users.$key"} = $$fields{$key};
  }
  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'users', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
}

# Function: add_credentials
# Arguments: 3
#     An already connect database handle.
#     The name of the user performing the query.
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_credentials {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid'])
    if (CMU::Netdb::getError($dbuser) != 1);

  ## bidirectional verification of the fields that the user is trying to add

  foreach $key (@credentials_fields) {
    my $nk = $key;
    $nk =~ s/^credentials\.//;
    $$fields{$nk} = ''
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }

  foreach $key (keys %$fields) {
    if (! grep /^credentials\.$key$/, @credentials_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
        "Couldn't find credentials.$key!\n".join(',', @credentials_fields)
	  if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }

    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("credentials.$key", $$fields{$key},
				       $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key])
      if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "credentials.$key: $$fields{$key}\n" if ($debug >= 2);

    $$newfields{"credentials.$key"} = $$fields{$key};
  }

  # Verify that the referenced user exists
  my $UID = $$newfields{"credentials.user"};
  my $uref = CMU::Netdb::auth::list_users($dbh, 'netreg', "users.id = '$UID'");
  return ($uref, ['credentials.user']) unless (ref $uref);
  return ($errcodes{"EUSER"}, ['credentials.user', scalar(@$uref)])
    unless (scalar(@$uref) >= 2);

  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'credentials',
					$newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  return ($res, \%warns);
}


# Function: add_group
# Arguments: 3
#     An already connect database handle.
#     The name of the user performing the query.
#     A reference to a hash table of field->value pairs
# Actions:  Adds the row to the table, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_group {
  my ($dbh, $dbuser, $fields) = @_;
  my ($key, $newfields, $res, $ref);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['user']) if (CMU::Netdb::getError($dbuser) != 1);
  
  return ($errcodes{EINVALID}, ['name']) if ($$fields{'name'} eq 'system:anyuser');
  
  foreach $key (keys %$fields) {
    if (! grep /^groups\.$key$/, @groups_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find groups.$key!\n".join(',', @groups_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("groups.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "groups.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"groups.$key"} = $$fields{$key};
  }
  
  $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'groups', $newfields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);
  
  ($res, $ref) = CMU::Netdb::auth::add_group_to_protections($dbh, "netreg", $$newfields{"groups.name"}, "groups", $warns{insertID}, "READ", 5, '');
  if ($res < 1) {
    return ($res, $ref);
  }
  
  ($res, $ref) = CMU::Netdb::auth::add_group_to_protections($dbh, "netreg", $$newfields{"groups.name"}, "groups", $warns{insertID}, "WRITE", 1, '');
  if ($res < 1) {
    return ($res, $ref);
  }
  
  if ($$newfields{"groups.name"} =~ /^dept:/) {
    ($res, $ref) = CMU::Netdb::auth::add_group_to_protections($dbh, "netreg", "system:anyuser", "groups", $warns{insertID}, "ADD", 1, '');
    if ($res < 1) {
      return ($res, $ref);
    }
  }
  
  return ($res, \%warns);
}


# Function: add_user_to_group
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The name of the user to add.
#     The group name.
# Actions: Adds an entry to the memberships table for this user&group
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_user_to_group {
  my ($dbh, $dbuser, $user, $gid) = @_;
  my ($query, $result, $sth, $rows);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid']) if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['credentials.authid']) if (CMU::Netdb::getError($user) != 1);

  $gid = CMU::Netdb::valid('groups.id', $gid, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['groups.id']) if (CMU::Netdb::getError($user) != 1);

  # First, lock the tables
  if (! $dbh->do("LOCK TABLES memberships WRITE, users READ, groups as G READ,
credentials AS C READ, credentials READ, protections as P READ, users as U READ, 
memberships as M READ, _sys_changelog WRITE, _sys_changerec_row WRITE,
_sys_changerec_col WRITE")) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_user_to_group: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return ($errcodes{"ERROR"}, ['db_lock']);
  }

  my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'groups', $gid);
  if ($ul < 5) {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EPERM}, []);
  }

  # Prepare & execute the insertion
  $query = 
    "INSERT INTO memberships (uid, gid) SELECT C.user, G.id " .
      "FROM credentials AS C, groups AS G WHERE C.authid = '$user' " .
	"AND G.id='$gid'";

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_user_to_group: $query\n" if ($debug >= 2);

  $result = $dbh->do($query);

  # If all went well, log the change and return.  But we won't unlock the tables
  # until after we check.

  if ($result == 1) {
    # since we just inserted a db row directly, we have to do logging here
    # first create the changelog entry
    my $rowid = $dbh->{'mysql_insertid'};
    my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
    if ($log) {
      # Now create the changelog row record
      my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'memberships', $rowid, 'INSERT');
      if ($rowrec) {
	my $rowrec = $dbh->{'mysql_insertid'};
	# Now create the column entries
	CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 'gid', $gid);
	CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 'uid', 
					      ['user', 'credentials',
					       "credentials.authid = '$user'"]);
      }
    }
    # Our caller may need the original insert id, but we can't reset
    # it, so we invent a new place to put it
    $CMU::Netdb::primitives::db_insertid = $rowid;
    $dbh->do("UNLOCK TABLES");
    return ($result, {});
  }

  # The insertion failed.  Why?
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_user_to_group: Insertion failed\n" if ($debug);
  # Did the user exist?
  $rows = CMU::Netdb::primitives::list
    ($dbh, $dbuser, "credentials",
     \@credentials_fields, "credentials.authid = \"$user\"");
  return ($rows, ['credentials.authid']) if (!ref $rows);
  if ($#$rows == -1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_user_to_group: No such user\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EUSER"}, ['credentials.authid']);
  }

  # Did the membership already exist?

  $query = <<END_SELECT;
SELECT memberships.uid, memberships.gid
FROM memberships, credentials AS C, groups AS G
WHERE C.authid ="$user" AND G.id = '$gid'
AND C.user = memberships.uid AND G.id = memberships.gid
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_user_to_group: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  $sth->execute();
  if ($sth->rows() == 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_user_to_group: $user is already a member of group\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return (1, {});
  }
  
  # Unknown error
  $dbh->do("UNLOCK TABLES");
  return ($errcodes{"ERROR"}, ['unknown_end']);
}

# Function: add_user_to_protections
# Arguments: 6:
#     An already connected database handle.
#     The name of the user making the request.
#     The user to add to the protections
#     The table we're granting access to
#     The row in that table (0 for the whole table)
#     A string representing the rights to be granted (e.g. "read,write")
#     Level to grant rights at
# Actions: Adds the appropriate entry to the protections table
# Return value: 
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_user_to_protections {
  my ($dbh, $dbuser, $user, $table, $row, $rights, $rlevel, $caller) = @_;
  my ($query, $result, $rows, $sth);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser'])
    if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['user'])
    if (CMU::Netdb::getError($user) != 1);

  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($table), ['tname'])
    if (CMU::Netdb::getError($table) != 1);

  $row = CMU::Netdb::valid("$table.id", $row, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($row), ['row'])
    if (CMU::Netdb::getError($row) != 1);

  $rights = CMU::Netdb::valid('protections.rights', $rights, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($rights), ['rights'])
    if (CMU::Netdb::getError($rights) != 1);

  $rlevel = CMU::Netdb::valid('protections.rlevel', $rlevel, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($rlevel), ['rlevel'])
    if (CMU::Netdb::getError($rlevel) != 1);

  if (($table eq "protections") || ($table eq "memberships")) {
    # No explicit protections for these tables, access rights are 
    # implied from other data.
    return ($errcodes{"EINVALID"}, ['table']);
  }

  # First, lock the tables
  $query = "LOCK TABLES protections as P WRITE, protections WRITE,
users as U READ, credentials AS C READ, credentials READ, users READ,
groups as G READ, groups READ, memberships as M READ, $table as T READ,
_sys_changelog WRITE , _sys_changerec_row WRITE,_sys_changerec_col WRITE";
  $query .= ", $table READ" if (($table ne "users") && ($table ne "groups") &&
				($table ne "credentials"));
  if (! $dbh->do($query)) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_user_to_protections: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return ($errcodes{"ERROR"}, ['lock']);
  }
  
  {
    ## Allow users with L5 ADD access on the table to grant L(<5) ADD to 
    ## users and groups
    if ($rights eq 'ADD' && $rlevel < 5) {
      goto AUTP_AUTH if (get_add_level($dbh, $dbuser, $table, $row) >= 5);
    }
    
    my $al = auth_prot_op($dbh, $dbuser, $table, $row, $rlevel, 'ADD', $user, $caller);
    if ($al < 1) {
      $dbh->do("UNLOCK TABLES");
      return ($al, ['authorization']);
    }
  }
 AUTP_AUTH:
  
  $query = <<END_SELECT;
INSERT INTO protections (identity, tname, tid, rights, rlevel) 
SELECT DISTINCT C.user, "$table", $row, "$rights", "$rlevel"
FROM credentials AS C, $table as T
WHERE C.authid = "$user"
END_SELECT
  
  $query .= " AND T.id = '$row'" if ($row != 0);


  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_user_to_protections: $query\n" if ($debug >= 2);
  $result = $dbh->do($query);
  
  if ($result == 1) {
    my $rowid = $dbh->{'mysql_insertid'};
    # since we just inserted a db row directly, we have to do logging here
    # first create the changelog entry
    my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
    if ($log) {
      # Now create the changelog row record
      my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $rowid, 'INSERT');
      if ($rowrec) {
	# Now create the column entries

	my %columns = ( 'tname' => $table,
			'tid' => $row,
			'rights' => $rights,
			'rlevel' => $rlevel );
	
	foreach (keys %columns) {
	  CMU::Netdb::primitives::changelog_col($dbh, $rowrec, $_,  $columns{$_});
	}
	CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 
					      'identity',
					      ['user', 'credentials',
					       "credentials.authid = '$user'"]);
      }
    }
    # Our caller may need the original insert id, but we can't reset
    # it, so we invent a new place to put it
    $CMU::Netdb::primitives::db_insertid = $rowid;

    $dbh->do("UNLOCK TABLES");
    return ($result, {});
  }

  # The insertion failed.  Why?
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_user_to_protections: Insertion failed\n" if ($debug);
  # Did the user exist?
  $rows = CMU::Netdb::primitives::list
    ($dbh, $dbuser, 'credentials',
     \@credentials_fields, 'credentials.authid = "$user"');
  return ($rows, ['user']) if (!ref $rows);
  if ($#$rows == -1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_user_to_protections: No such user\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EUSER"}, ['user']);
  }

  # Does the row exist in the table?
  $rows = CMU::Netdb::primitives::list($dbh, 'netreg', $table, 
				       eval("\\\@CMU::Netdb::structure::" . $table . "_fields"), "$table.id = $row");
  return ($rows, ['row']) if (!ref $rows);
  if ($#$rows == -1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_user_to_protections: No such row in $table\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EINVALID"}, ['row']);
  }

  # Did the protection already exist?

  $query = <<END_SELECT;
SELECT P.rights
FROM protections as P, credentials AS C
WHERE C.authid = "$user"
AND P.identity = C.user
AND P.tname = "$table"
AND P.tid = '$row'
AND P.rlevel = '$rlevel'
END_SELECT
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_user_to_protections: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  $sth->execute();
  if ($sth->rows() == 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_user_to_protections: A protection entry already existed\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EEXISTS"}, ['tid', 'row']);
  }
  
  # Unknown error
  $dbh->do("UNLOCK TABLES");
  return ($errcodes{"ERROR"}, ['unknown']);
  
}


# Function: add_group_to_protections
# Arguments: 6:
#     An already connected database handle.
#     The name of the user making the request.
#     The group to add to the protections
#     The table we're granting access to
#     The row in that table (0 for the whole table)
#     A string representing the rights to be granted (e.g. "read,write")
#     Level to add access at
#     Caller
# Actions: Adds the appropriate entry to the protections table
# Return value: 
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub add_group_to_protections {
  my ($dbh, $dbuser, $group, $table, $row, $rights, $rlevel, $caller) = @_;
  my ($query, $result, $rows, $sth, $identity);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['user'])
    if (CMU::Netdb::getError($dbuser) != 1);

  $group = CMU::Netdb::valid('groups.name', $group, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($group), ['group'])
    if (CMU::Netdb::getError($group) != 1);

  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($table), ['table'])
    if (CMU::Netdb::getError($table) != 1);

  $row = CMU::Netdb::valid("$table.id", $row, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($row), ['row', "$table.id", 'valid'])
    if (CMU::Netdb::getError($row) != 1);

  $rights = CMU::Netdb::valid('protections.rights', $rights, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($rights), ['rights'])
    if (CMU::Netdb::getError($rights) != 1);

  $rlevel = CMU::Netdb::valid('protections.rlevel', $rlevel, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($rlevel), ['rlevel'])
    if (CMU::Netdb::getError($rlevel) != 1);

  if (($table eq "protections") || ($table eq "memberships")) {
    # No explicit protections for these tables, access rights are
    # implied from other data.
    return ($errcodes{"EINVALID"}, ['table']);
  }

  # First, lock the tables
  $query = "LOCK TABLES protections as P WRITE, protections WRITE,
users as U READ, credentials AS C READ, credentials READ, users READ,
groups as G READ, groups READ, memberships as M READ, $table as T READ,
memberships READ, _sys_changelog WRITE,
_sys_changerec_row WRITE, _sys_changerec_col WRITE";
  $query .= ", $table READ" if (($table ne "users") && ($table ne "groups") &&
				($table ne "credentials"));
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_group_to_protections: $query\n" if ($debug >= 2);
  if (! $dbh->do($query)) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_group_to_protections: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return ($errcodes{"ERROR"}, ['db_lock']);
  }

  {
    ## Allow users with L5 ADD access on the table to grant L(<5) ADD to 
    ## users and groups
    if ($rights eq 'ADD' && $rlevel < 5) {
      goto AGTP_AUTH if (get_add_level($dbh, $dbuser, $table, $row) >= 5);
    }
    my $al = auth_prot_op($dbh, $dbuser, $table, $row, $rlevel, 'ADD', $group, $caller);
    if ($al < 1) {
      $dbh->do("UNLOCK TABLES");
      return ($al, ['auth']);
    }
  }
 AGTP_AUTH:
  if ($row != 0) {
    # Does the row exist in the table?
    $rows = CMU::Netdb::primitives::list($dbh, 'netreg', "$table", 
					 eval("\\\@CMU::Netdb::structure::" . $table . "_fields"), "$table.id = $row");
    return ($rows, ["$table.id", 'row']) if (!ref $rows);

    if ($#$rows == -1) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::add_group_to_protections: ".
	  "No such row ($row) in $table\n";
      $dbh->do("UNLOCK TABLES");
      return ($errcodes{"EINVALID"}, ["$table.id", 'row', 'no_such_row']);
    }
  }

  if ($group eq 'system:anyuser') {
    $query = <<END_SELECT;
INSERT INTO protections (identity, tname, tid, rights, rlevel) 
VALUES (0, "$table", $row, "$rights", "$rlevel")
END_SELECT
  }else{
    $query = <<END_SELECT;
INSERT INTO protections (identity, tname, tid, rights, rlevel) 
SELECT CAST(G.id AS SIGNED INT) * -1, "$table", $row, "$rights", "$rlevel"
FROM groups as G
WHERE G.name = "$group"
END_SELECT
  }
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_group_to_protections: $query\n" if ($debug >= 2);
  $result = $dbh->do($query);


  if ($result == 1) {
    my $rowid = $dbh->{'mysql_insertid'};
    # since we just inserted a db row directly, we have to do logging here
    # first create the changelog entry
    my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
    if ($log) {
      # Now create the changelog row record
      my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $rowid, 'INSERT');
      if ($rowrec) {
	# Now create the column entries
	my %columns = ( 'tname' => $table,
			'tid' => $row,
			'rights' => $rights,
			'rlevel' => $rlevel );

	if ($group eq 'system:anyuser') {
	  $columns{identity} = 0;
	} else {
	  CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 'identity', ['-groups.id', 'groups', "groups.name = '$group'"]);
	}
	foreach (keys %columns) {
	  CMU::Netdb::primitives::changelog_col($dbh, $rowrec, $_, $columns{$_});
	}
      }
    }
    # Our caller may need the original insert id, but we can't reset
    # it, so we invent a new place to put it
    $CMU::Netdb::primitives::db_insertid = $rowid;
    $dbh->do("UNLOCK TABLES");
    return ($result, ['unknown']);
  }
  
  # The insertion failed.  Why?
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_group_to_protections: Insertion failed\n" if ($debug);
  # Did the group exist?
  $rows = CMU::Netdb::primitives::list($dbh, $dbuser, "groups", 
				       \@groups_fields, "groups.name = \"$group\"");
  return ($rows, ['group']) if (!ref $rows);
  if ($#$rows == -1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_group_to_protections: No such group\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EGROUP"}, ['group']);
  }
  
  # Did the protection already exist?
  
  $query = <<END_SELECT;
SELECT P.rights
FROM protections as P, groups as G
WHERE G.name = "$group"
AND P.identity = CAST(G.id AS SIGNED INT) * -1
AND P.tname = "$table"
AND P.tid = '$row'
AND P.rlevel = '$rlevel'
END_SELECT
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::add_group_to_protections: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  $sth->execute();
  if ($sth->rows() == 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::add_group_to_protections: A protection entry already existed\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EEXISTS"}, ['row']);
  }
  
  # Unknown error
  $dbh->do("UNLOCK TABLES");
  return ($errcodes{"ERROR"}, ['unknown']);
  
}


# Function: modify_user
# Arguments: 5:
#     An already connect database handle.
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_user {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('users.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['users.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('users.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['users.version']) if (CMU::Netdb::getError($version) != 1);
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@users_fields) {
    my $nk = $key;		# required because $key is a reference into users_fields
    $nk =~ s/^users\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^users\.$key$/, @users_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find users.$key!\n".join(',', @users_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("users.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "users.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"users.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'users', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM users WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_user: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_user: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result, []);
}

# Function: modify_credentials
# Arguments: 5:
#     An already connect database handle.
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_credentials {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser'])
    if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid('credentials.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['credentials.id'])
    if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid('credentials.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['credentials.version'])
    if (CMU::Netdb::getError($version) != 1);

  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@credentials_fields) {
    my $nk = $key;              # required because $key is a reference into users_fields
    $nk =~ s/^credentials\.//;
    $$fields{$nk} = ''
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }

  foreach $key (keys %$fields) {
    if (! grep /^credentials\.$key$/, @credentials_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
        "Couldn't find credentials.$key!\n".join(',', @credentials_fields)
	  if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }

    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("credentials.$key", $$fields{$key},
				       $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key])
      if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "credentials.$key: $$fields{$key}\n" if ($debug >= 2);

    $$newfields{"credentials.$key"} = $$fields{$key};
  }

  # Verify that the referenced user exists
  my $UID = $$newfields{"credentials.user"};
  my $uref = CMU::Netdb::auth::list_users($dbh, 'netreg', "users.id = '$UID'");
  return ($uref, ['credentials.user']) unless (ref $uref);
  return ($errcodes{"EUSER"}, ['credentials.user'])
    unless (scalar(@$uref) >= 2);

  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'credentials',
					   $id, $version, $newfields);

  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM credentials WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_credentials: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
        "CMU::Netdb::auth::modify_credentials: id/version were stale\n"
	  if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }

  return ($result, []);
}

# Function: modify_group
# Arguments: 5:
#     An already connect database handle.
#     The name of the user performing the query.
#     The 'id' of the row to change
#     The 'version' of the row to change
#     A reference to a hash table of field->value pairs
# Actions: Updates the specified row, if authorized
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_group {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;
  my ($key, $result, $query, $sth, $newfields, $orig, $ul);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if  (CMU::Netdb::getError($dbuser) != 1);
  
  $id = CMU::Netdb::valid('groups.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['groups.id']) if (CMU::Netdb::getError($id) != 1);
  
  $version = CMU::Netdb::valid('groups.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['groups.version']) if (CMU::Netdb::getError($version) != 1);
  
  $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'groups', $id);
  return ($errcodes{EPERM}, ['permissions']) if ($ul < 1);
  $orig = CMU::Netdb::list_groups($dbh, $dbuser, "groups.id = '$id'");
  return ($orig, ['id']) if (!ref $orig);
  
  if ($ul < 9) {
    $$fields{name} = $$orig[1][$groups_pos{"groups.name"}];
    $$fields{flags} = $$orig[1][$groups_pos{"groups.flags"}];
    $$fields{comment_lvl9} = $$orig[1][$groups_pos{"groups.comment_lvl9"}];
  }
  if ($ul < 5) { 
    $$fields{comment_lvl5} = $$orig[1][$groups_pos{"groups.comment_lvl5"}];
  }
  
  ## bidirectional verification of the fields that the user is trying to add
  foreach $key (@groups_fields) {
    my $nk = $key;		# required because $key is a reference into groups_fields
    $nk =~ s/^groups\.//;
    $$fields{$nk} = '' 
      if (!defined $$fields{$nk} && $nk ne 'id' && $nk ne 'version');
  }
  
  foreach $key (keys %$fields) {
    if (! grep /^groups\.$key$/, @groups_fields) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"Couldn't find groups.$key!\n".join(',', @groups_fields) if ($debug >= 2);
      return ($errcodes{"EINVALID"}, [$key]);
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Verifying $key\n" if ($debug >= 2);
    $$fields{$key} = CMU::Netdb::valid("groups.$key", $$fields{$key}, $dbuser, 0, $dbh);
    return (CMU::Netdb::getError($$fields{$key}), [$key]) if (CMU::Netdb::getError($$fields{$key}) != 1);
    warn __FILE__, ':', __LINE__, ' :>'.
      "groups.$key: $$fields{$key}\n" if ($debug >= 2);
    
    $$newfields{"groups.$key"} = $$fields{$key};
  }
  
  $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'groups', $id, $version, $newfields);
  
  if ($result == 0) {
    # An error occurred
    $query = "SELECT id FROM groups WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_user: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::modify_user: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($errcodes{"ERROR"}, ['unknown']);
    }
  }
  
  return ($result);
}

# Function: modify_user_protection
# Arguments: 6:
#     An already connected database handle.
#     The name of the user making the request.
#     The user to whose access we are modifying
#     The table we're modifying the rights on
#     The row in that table (0 for the whole table)
#     A string representing the rights to be granted (e.g. "read,write")
# Actions: Changes the user's rights on the table entry
# Return value:
#     1 if success
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_user_protection {
  my ($dbh, $dbuser, $user, $table, $row, $rights, $rlevel) = @_;
  my ($query, $result, @row, $sth, $id);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);
  
  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($table) if (CMU::Netdb::getError($table) != 1);
  
  $row = CMU::Netdb::valid("$table.id", $row, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($row) if (CMU::Netdb::getError($row) != 1);
  
  $rights = CMU::Netdb::valid('protections.rights', $rights, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($rights) if (CMU::Netdb::getError($rights) != 1);
  
  $rlevel = CMU::Netdb::valid('protections.rlevel', $rlevel, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($rlevel) if (CMU::Netdb::getError($rlevel) != 1);
  
  if (($table eq "protections") || ($table eq "memberships")) {
    # No explicit protections for these tables, access rights are 
    # implied from other data.
    return $errcodes{"EINVALID"};
  }
  
  $query = "LOCK TABLES protections WRITE, users READ, users AS U READ,
memberships READ, credentials AS C READ, credentials READ, groups READ,
groups as G READ, protections as P READ, memberships AS M READ, 
_sys_changelog WRITE, _sys_changerec_row WRITE, _sys_changerec_col WRITE";
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_user_protection: $query\n" if ($debug >= 2);
  if (! $dbh->do($query)) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_user_protection: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return $errcodes{"ERROR"};
  }
  
  {
    my $al = auth_prot_op($dbh, $dbuser, $table, $row, $rlevel, 'WRITE', $user, '');
    if ($al < 1) {
      $dbh->do("UNLOCK TABLES");
      return $al;
    }
  }
  
  $query = <<END_SELECT;
SELECT C.user, protections.id 
FROM credentials AS C LEFT JOIN protections ON protections.identity = C.user
WHERE C.authid = "$user"
AND (((protections.tname = "$table")
      AND
      (protections.tid = '$row') AND (protections.rlevel = '$rlevel'))
     OR ISNULL(protections.tname))
END_SELECT
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_user_protection: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_user_protection: Unknown error\n$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"ERROR"};
  }
  
  if ($sth->rows() != 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_user_protection: No such user\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"EUSER"};
  }
  
  @row = $sth->fetchrow;
  if (!$row[1]) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_user_protection: No such protection entry\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"ENOENT"};
  }
  $id = $row[1];
  # since we're about to update a db row directly, we have to do logging here
  # first create the changelog entry
  my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  if ($log) {
    # Now create the changelog row record
      my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $id, 'UPDATE');
      if ($rowrec) {
      my $rowrec = $dbh->{'mysql_insertid'};
      # Now create the column entry (only changing one column)
      CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 'rights', $rights, ['rights', 'protections', "protections.id = '$id'"]);
    }
  }
  $query = "UPDATE protections SET rights=\"$rights\" WHERE id='$id'";
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_user_protection: $query\n" if ($debug >= 2);
  $result = $dbh->do($query);
  
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_user_protection: Unknown error\n$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"ERROR"};
  }
  $dbh->do("UNLOCK TABLES");
  return 1;
  
}



# Function: modify_group_protection
# Arguments: 6:
#     An already connected database handle.
#     The name of the user making the request.
#     The group to whose access we are modifying
#     The table we're modifying the rights on
#     The row in that table (0 for the whole table)
#     A string representing the rights to be granted (e.g. "read,write")
# Actions: Changes the group's rights on the table entry
# Return value:
#     1 if success
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub modify_group_protection {
  my ($dbh, $dbuser, $group, $table, $row, $rights, $rlevel) = @_;
  my ($query, $result, @row, $sth, $id);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);

  $group = CMU::Netdb::valid('groups.name', $group, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($group) if (CMU::Netdb::getError($group) != 1);

  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($table) if (CMU::Netdb::getError($table) != 1);

  $row = CMU::Netdb::valid("$table.id", $row, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($row) if (CMU::Netdb::getError($row) != 1);

  $rights = CMU::Netdb::valid('protections.rights', $rights, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($rights) if (CMU::Netdb::getError($rights) != 1);

  $rlevel = CMU::Netdb::valid('protections.rlevel', $rlevel, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($rlevel) if (CMU::Netdb::getError($rlevel) != 1);

  if (($table eq "protections") || ($table eq "memberships")) {
    # No explicit protections for these tables, access rights are 
    # implied from other data.
    return $errcodes{"EINVALID"};
  }

  $query = "LOCK TABLES protections WRITE, groups READ, groups as G READ,
users READ, credentials AS C READ, credentials READ, memberships as M READ,
users as U READ, protections as P READ, memberships READ, _sys_changelog WRITE,
_sys_changerec_row WRITE,_sys_changerec_col WRITE";
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_group_protection: $query\n" if ($debug >= 2);
  if (! $dbh->do($query)) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_group_protection: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return $errcodes{"ERROR"};
  }
  
  {
    my $al = auth_prot_op($dbh, $dbuser, $table, $row, $rlevel, 'WRITE', $group, '');
    if ($al < 1) {
      $dbh->do("UNLOCK TABLES");
      return $al;
    }
  }
  
  if ($group eq 'system:anyuser') {
    $query = <<END_SELECT;
SELECT 0, protections.id 
FROM protections
WHERE protections.identity = 0
AND (((protections.tname = "$table")
      AND
      (protections.tid = '$row') AND protections.rlevel = '$rlevel')
     OR ISNULL(protections.tname))
END_SELECT
  }else{
    $query = <<END_SELECT;
SELECT groups.id, protections.id 
FROM groups LEFT JOIN protections ON protections.identity = (CAST(groups.id AS SIGNED INT) * -1)
WHERE groups.name = '$group'
AND (((protections.tname = '$table')
      AND
      (protections.tid = '$row') AND (protections.rlevel = '$rlevel'))
     OR ISNULL(protections.tname))
END_SELECT
  }
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_group_protection: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  $result = $sth->execute();
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_group_protection: Unknown error\n$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"ERROR"};
  }
  
  if ($sth->rows() != 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_group_protection: No such group\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"EGROUP"};
  }
  
  @row = $sth->fetchrow;
  if (!$row[1]) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_group_protection: No such protection entry\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"ENOENT"};
  }
  $id = $row[1];
  # since we're about to update a db row directly, we have to do logging here
  # first create the changelog entry
  my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  if ($log) {
    # Now create the changelog row record
    my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $id, 'UPDATE');
    if ($rowrec) {
      # Now create the column entry (only changing one column)
      CMU::Netdb::primitives::changelog_col($dbh, $rowrec, 'rights', $rights, ['rights', 'protections', "id = '$id'"]);
    }
  }

  $query = "UPDATE protections SET rights=\"$rights\" WHERE id='$id'";
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::modify_group_protection: $query\n" if ($debug >= 2);
  $result = $dbh->do($query);
  
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::modify_group_protection: Unknown error\n$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return $errcodes{"ERROR"};
  }
  
  $dbh->do("UNLOCK TABLES");
  return 1;
  
}



# Function: delete_user_from_group
# Arguments: 4:
#     An already connected database handle.
#     The name of the user making the request.
#     The name of the user to delete.
#     The group ID.
# Actions: Delete an entry from the memberships table for this user&group
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_user_from_group {
  my ($dbh, $dbuser, $user, $gid) = @_;
  my ($query, $result, $sth, $uid, $rows);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid']) if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['credentials.authid']) if (CMU::Netdb::getError($user) != 1);

  $gid = CMU::Netdb::valid('groups.id', $gid, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['groups.id']) if (CMU::Netdb::getError($gid) != 1);

  # First, lock the tables
  if (! $dbh->do("LOCK TABLES memberships WRITE, users READ, groups AS G READ, 
credentials AS C READ, credentials READ,
protections as P READ, users as U READ, memberships as M READ, _sys_changelog WRITE, 
_sys_changerec_row WRITE,_sys_changerec_col WRITE")) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::delete_user_from_group: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return ($errcodes{"ERROR"}, ['db_lock'])
  }

  # Get the uid
  $rows = CMU::Netdb::primitives::list
    ($dbh, $dbuser, "credentials",
     \@credentials_fields, "credentials.authid = \"$user\"");
  return ($rows, ['credentials.authid']) if (!ref $rows);
  if ($#$rows == -1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_user_from_group: No such user\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EUSER"}, ['credentials.authid']);
  }

  my %cmap = %{CMU::Netdb::makemap(\@credentials_fields)};
  $uid = $rows->[0]->[$cmap{'credentials.user'}];

  my $ul = CMU::Netdb::get_write_level($dbh, $dbuser, 'groups', $gid);

  if ($ul < 5) {
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{EPERM}, ['permissions']);
  }

  # prefetch the rowid, for logging
  my ($delid, $delver) = $dbh->selectrow_array("SELECT id,version FROM memberships WHERE uid='$uid' and gid='$gid'");
  # Delete the entry
  $query = "DELETE FROM memberships WHERE uid='$uid' and gid='$gid'";

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_user_from_group: $query\n" if ($debug >= 2);

  $result = $dbh->do($query);

  if ($result == 1) {
    # We just made a change directly, log it.
    # first create the changelog entry
    my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
    if ($log) {
      my $log = $dbh->{'mysql_insertid'};
      # Now create the changelog row record
      my $rowrec = CMU::Netdb::primitives::changelog_row
	($dbh, $log, 'memberships', $delid, 'DELETE');
      if ($rowrec) {
	# Now create the column entries
	my %columns = ( 'version' => $delver,
			'uid' => $uid,
			'gid' => $gid );
	foreach (keys %columns) {
	  CMU::Netdb::primitives::changelog_col($dbh, $rowrec, $_, undef, $columns{$_});
	}
      }
    }
    $dbh->do("UNLOCK TABLES");
    return (1, {});
  }
  
  # Perhaps there was no such entry
  # Have to query this directly, due to protections issues
  
  $query = "SELECT id FROM memberships WHERE uid='$uid' AND gid='$gid'";
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_user_from_group: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  $sth->execute();
  if ($sth->rows() == 0) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_user_from_group: $user is already not a member of group\n";
    $dbh->do("UNLOCK TABLES");
    return (1, {});
  }
  
  # Unknown error
  
  $dbh->do("UNLOCK TABLES");
  return ($errcodes{"ERROR"}, ['unknown']);
}

# Function: delete_user
# Arguments: :
#     An already connected database handle.
#     The name of the user making the request.
#     The user to delete
# Actions: Verifies authorization and deletes the user.
# Return value: 
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_user {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid('user.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid('user.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);

  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'users', $id, $version);

  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM users WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_user: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_user: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  return ($result);
}

# Function: delete_credentials
# Arguments: :
#     An already connected database handle.
#     The name of the user making the request.
#     The credential to delete
# Actions: Verifies authorization and deletes the credential entry.
# Return value:
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_credentials {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser'])
    if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid('credentials.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid('credentials.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version'])
    if (CMU::Netdb::getError($version) != 1);

  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'credentials', $id, $version);

  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM credentials WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_credentials: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
        "CMU::Netdb::auth::delete_credentials: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  return ($result);
}

# Function: delete_group
# Arguments: :
#     An already connected database handle.
#     The name of the user making the request.
#     The group to delete
# Actions: Verifies authorization and deletes the group.
# Return value: 
#     1 if successful
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_group {
  my ($dbh, $dbuser, $id, $version) = @_;
  my ($query, $sth, $result, $uid, @row, $dref);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid('groups.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id'])  if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid('groups.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);

  ($result, $dref) = CMU::Netdb::primitives::delete
    ($dbh, $dbuser, 'groups', $id, $version);

  if ($result != 1) {
    # An error occurred
    $query = "SELECT id FROM groups WHERE id='$id' AND version='$version'";
    $sth = $dbh->prepare($query);
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_group: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_group: id/version were stale\n" if ($debug);
      return ($errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  return ($result);
}



# Function: delete_user_from_protections
# Arguments: :
#     An already connected database handle.
#     The name of the user making the request.
#     The user to whose access we are removing
#     The table we're removing the rights on
#     The row in that table (0 for the whole table)
# Actions: Deletes the matching entry from the protections table
#          if it exists
# Return value:
#     1 if success
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_user_from_protections {
  my ($dbh, $dbuser, $user, $table, $row, $rlevel, $caller) = @_;
  my ($query, $result, $sth);

  warn __FILE__, ':', __LINE__, ' :>'.
    "delete_u_f_p: $user $table $row $rlevel\n" if ($debug >= 1);
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['user']) if (CMU::Netdb::getError($user) != 1);

  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($table), ['tname']) if (CMU::Netdb::getError($table) != 1);

  $row = CMU::Netdb::valid("$table.id", $row, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($row), ['row']) if (CMU::Netdb::getError($row) != 1);

  $rlevel = CMU::Netdb::valid('protections.rlevel', $rlevel, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($rlevel), ['rlevel']) if (CMU::Netdb::getError($rlevel) != 1);

  if (($table eq "protections") || ($table eq "memberships")) {
    # No explicit protections for these tables, access rights are 
    # implied from other data.
    return ($errcodes{"EINVALID"}, ['tname']);
  }

  $query = <<END_SELECT;
SELECT C.user
FROM credentials AS C
WHERE C.authid = "$user"
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_user_from_protections: $query\n" if ($debug >= 2);
  $sth = $dbh->prepare($query);
  $result = $sth->execute();

  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_user_from_protections: Unknown error\n$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"ERROR"}, ['unknown']);
  }

  if ($sth->rows() != 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_user_from_protections: No such user\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"EUSER"}, ['user']);
  }

  $result = $sth->fetchrow_arrayref();
   warn __FILE__ . ":" . __LINE__ . ":>" .
     "User Info:\n" . Data::Dumper->Dump([$result],[qw(result)]) . "\n" if ($debug >= 2); 

  {
    ## Allow users with L5 ADD access on the table to grant L(<5) ADD to 
    ## users and groups
    if ($rlevel < 5) {
      my $lp = CMU::Netdb::list_protections($dbh, $dbuser, $table, $row, 
					    "P.rlevel = $rlevel ".
					    "AND P.rights = 'ADD' ".
					    "AND P.identity = $result->[0]");
      if (ref $lp && defined $lp->[0]) {
        # Verify that the protections entry is ADD only
        goto DUFP_AUTH if (get_add_level($dbh, $dbuser, $table, $row) >= 5);
      }
    }
    my $al = auth_prot_op($dbh, $dbuser, $table, $row, $rlevel, 'WRITE', $user, $caller);
    return ($al, ['auth']) if ($al < 1);
  }
 DUFP_AUTH:

  # First, lock the tables
  $query = "LOCK TABLES protections WRITE, users READ, users as U READ, _sys_changelog WRITE,
credentials AS C READ, credentials READ,
_sys_changerec_row WRITE,_sys_changerec_col WRITE";
  if (! $dbh->do($query)) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_user_from_protections: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return ($errcodes{"ERROR"}, ['lock']);
  }

  # prefetch the row id and rights for logging
  my $delident = $result->[0];

  my ($delid, $delrights, $delver) = $dbh->selectrow_array("SELECT id,rights,version FROM protections WHERE identity='$delident' AND tname=\"$table\" AND tid = \"$row\" AND rlevel=\"$rlevel\"");

  # If no rows match that query, just pretend that all is right with the world.
  if (!$delid) {
    $dbh->do("UNLOCK TABLES");
    return (1, {});
  }

  # delete the row
  $query = "DELETE FROM protections WHERE identity='$delident' AND tname=\"$table\" AND tid = \"$row\" AND rlevel=\"$rlevel\"";

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_user_from_protections: $query\n" if ($debug >= 2);

  $result = $dbh->do($query);

  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_user_from_protections: Unknown error\n$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"ERROR"}, ['unknown']);
  }

  $dbh->do("UNLOCK TABLES");
  # We just made a change directly, log it.
  # first create the changelog entry
  my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  if ($log) {
    # Now create the changelog row record
    my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $delid, 'DELETE');
    if ($rowrec) {
      # Now create the column entries
      my %columns = ( 'version' => $delver,
		      'identity' => $delident,
		      'tname' => $table,
		      'tid' => $row,
		      'rlevel' => $rlevel,
		      'rights' => $delrights );
      foreach (keys %columns) {
	CMU::Netdb::primitives::changelog_col($dbh, $rowrec, $_, undef, $columns{$_});
      }
    }
  }
  return (1, {});
}


# Function: delete_protection_tid
# Arguments: :
#     An already connected database handle.
#     The name of the user making the request.
#     The table we're removing the rights on
#     The tid we're removing the rights on
# Actions: Deletes the matching entries from the protections table
# Return value:
#     1 if success
#     An error code is returned if a problem occurs (see CMU::Netdb::errors.pm)
sub delete_protection_tid {
  my ($dbh, $dbuser, $table, $tid) = @_;
  my ($query, $result, $sth, $identity);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid']) if (CMU::Netdb::getError($dbuser) != 1);
  
  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($table), ['tname']) if (CMU::Netdb::getError($table) != 1);
  
  if (($table eq "protections") || ($table eq "memberships")) {
    # No explicit protections for these tables, access rights are 
    # implied from other data.
    return ($errcodes{"EINVALID"}, ['tname']);
  }
  
  # First, lock the tables
  $query = "LOCK TABLES protections WRITE, memberships READ, groups as G READ, users READ,
credentials AS C READ, credentials READ,
users as U READ, memberships as M READ, protections as P READ, _sys_changelog WRITE, 
_sys_changerec_row WRITE,_sys_changerec_col WRITE";
  if (! $dbh->do($query)) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_protection_tid: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return ($errcodes{"ERROR"}, ['lock']);
  }
  
  {
    my $al = CMU::Netdb::get_write_level($dbh, $dbuser, $table, $tid);
    if ($al < 1) {
      $dbh->do("UNLOCK TABLES");
      return $al;
    }
  }
  
  # prefetch the row data for logging
  my $delrows = $dbh->selectall_arrayref("SELECT id,identity,rights,rlevel,version FROM protections WHERE tname=\"$table\" AND tid = \"$tid\""); 
  # delete the row
  $query = "DELETE FROM protections WHERE tname=\"$table\" AND tid = \"$tid\"";
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_protection_tid: $query\n" if ($debug >= 2);
  
  $result = $dbh->do($query);
  
  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_protection_tid: Unknown error\n$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"ERROR"}, ['unknown']);
  }
  # We just made a change directly, log it.
  # first create the changelog entry
  my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  if ($log) {
    # log each protections entry that was deleted
    foreach my $deleted (@$delrows) {
      # Now create the changelog row record
      my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 'protections', $deleted->[0], 'DELETE');
      if ($rowrec) {
	# Now create the column entries
	my %columns = ( 'version' => $deleted->[4],
			'identity' => $deleted->[1],
			'tname' => $table,
			'tid' => $tid,
			'rlevel' => $deleted->[3],
			'rights' => $deleted->[2]);
	foreach (keys %columns) {
	  CMU::Netdb::primitives::changelog_col($dbh, $rowrec, $_, undef, $columns{$_});
	}
      }
    }
  }

  $dbh->do("UNLOCK TABLES");
  return 1;
}

sub delete_group_from_protections {
  my ($dbh, $dbuser, $group, $table, $row, $rlevel, $caller) = @_;
  my ($query, $result, $sth, $identity);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['credentials.authid']) if (CMU::Netdb::getError($dbuser) != 1);

  $group = CMU::Netdb::valid('groups.name', $group, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($group), ['groups.name']) if (CMU::Netdb::getError($group) != 1);

  $table = CMU::Netdb::valid('protections.tname', $table, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($table), ['tname']) if (CMU::Netdb::getError($table) != 1);

  $row = CMU::Netdb::valid("$table.id", $row, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($row), ["$table.row"]) if (CMU::Netdb::getError($row) != 1);

  $rlevel = CMU::Netdb::valid('protections.rlevel', $rlevel, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($rlevel), ['rlevel']) if (CMU::Netdb::getError($rlevel) != 1);

  if (($table eq "protections") || ($table eq "memberships")) {
    # No explicit protections for these tables, access rights are 
    # implied from other data.
    return ($errcodes{"EINVALID"}, ['tname']);
  }

  # First, lock the tables
  $query = "LOCK TABLES protections WRITE, groups READ, users READ, memberships READ,
credentials AS C READ, credentials READ,
users as U READ, memberships as M READ, protections as P READ, groups as G READ, _sys_changelog WRITE,
_sys_changerec_row WRITE,_sys_changerec_col WRITE";
  if (! $dbh->do($query)) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_group_from_protections: Failed to lock tables\n$DBI::errstr\n" if ($debug);
    return ($errcodes{"ERROR"}, ['lock']);
  }

  if ($group eq 'system:anyuser') {
    $identity = 0;
  }else{
    $query = <<END_SELECT;
SELECT groups.id 
FROM groups 
WHERE groups.name = "$group"
END_SELECT

    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_group_from_protections: $query\n" if ($debug >= 2);
    $sth = $dbh->prepare($query);
    $result = $sth->execute();

    if (!$result) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_group_from_protections: Unknown error\n$DBI::errstr\n" if ($debug);
      $dbh->do("UNLOCK TABLES");
      return ($errcodes{"ERROR"}, ['groups.name']);
    }

    if ($sth->rows() != 1) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::auth::delete_group_from_protections: No such group\n" if ($debug);
      $dbh->do("UNLOCK TABLES");
      return ($errcodes{"EGROUP"}, ['groups.name']);
    }

    $result = $sth->fetchrow_arrayref();
    $identity = ($result->[0] * -1);
  }

  {
    ## Allow users with L5 ADD access on the table to grant L(<5) ADD to 
    ## users and groups
    if ($rlevel < 5) {
      my $lp = CMU::Netdb::list_protections($dbh, $dbuser, $table, $row, 
					    "P.rlevel = $rlevel ".
					    "AND P.rights = 'ADD' ".
					    "AND P.identity = $identity");
      if (ref $lp && defined $lp->[0]) {
        # Verify that the protections entry is ADD only
        goto DGFP_AUTH if (get_add_level($dbh, $dbuser, $table, $row) >= 5);
      }
    }

    my $al = auth_prot_op($dbh, $dbuser, $table, $row, $rlevel, 'WRITE', $group, $caller);
    if ($al < 1) {
      $dbh->do("UNLOCK TABLES");
      return ($al, ['auth2']);
    }
  }

 DGFP_AUTH:

  # prefetch the row id and rights for logging
  my ($delid, $delrights, $delver) = $dbh->selectrow_array
    ("SELECT id,rights,version FROM protections ".
     "WHERE identity='$identity' AND tname=\"$table\" AND ".
     "tid = \"$row\" AND rlevel = \"$rlevel\"");

  # delete the row
  $query = "DELETE FROM protections WHERE identity='$identity' AND ".
    "tname=\"$table\" AND tid = \"$row\" AND rlevel = \"$rlevel\"";

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::auth::delete_group_from_protections: $query\n"
      if ($debug >= 2);

  $result = $dbh->do($query);

  if (!$result) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::auth::delete_group_from_protections: Unknown error\n".
	"$DBI::errstr\n" if ($debug);
    $dbh->do("UNLOCK TABLES");
    return ($errcodes{"ERROR"}, ['unknown']);
  }

  # We just made a change directly, log it.
  # first create the changelog entry
  my $log = CMU::Netdb::primitives::changelog_id($dbh, $dbuser);
  if ($log) {
    # Now create the changelog row record
    my $rowrec = CMU::Netdb::primitives::changelog_row($dbh, $log, 
						       'protections', $delid,
						       'DELETE');
    if ($rowrec) {
      # Now create the column entries
      my %columns = ( 'version' => $delver,
		      'identity' => $identity,
		      'tname' => $table,
		      'tid' => $row,
		      'rlevel' => $rlevel,
		      'rights' => $delrights );
      foreach (keys %columns) {
	CMU::Netdb::primitives::changelog_col($dbh, $rowrec, $_, undef, 
					      $columns{$_});
      }
    }
  }

  $dbh->do("UNLOCK TABLES");
  return (1, {});
}

## get_departments
## arguments: db handle, db user, where clause, type of request, extra info
## where 'type of request' is one of: USER or ALL
## and extra info would indicate userID of the target user if USER selected
## the field to get as the second entry
##
## NOTE:
## Cases: type ALL with 'where' clause: where clause overrides, uses specified
## method. type ALL without 'where' clause: 


## Returns: an associative array of group ID => dept name

sub get_departments {
  my ($dbh, $dbuser, $where, $type, $einfo, $field, $method) = @_;
  my ($ref, $nwhere, $sth, @ids, @row);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  
  if ($type eq 'USER') {
    $einfo =  CMU::Netdb::valid('credentials.authid', $dbuser, $einfo, 0, $dbh);
    return CMU::Netdb::getError($dbuser) if (CMU::Netdb::getError($dbuser) != 1);
  }
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "get_departments type: $type\n" if ($debug >= 2); 
  if ($type eq 'USER') {
    $nwhere = <<END_SELECT;
SELECT DISTINCT groups.id
FROM
credentials AS C
LEFT JOIN memberships as M ON C.user = M.uid
LEFT JOIN protections as P1 ON P1.identity = C.user
LEFT JOIN protections as P2 ON P1.tname = P2.tname AND P1.tid = P2.tid,
groups
WHERE C.authid = '$einfo'
AND (M.gid = groups.id
     OR groups.id = -1*P2.identity)
AND groups.name like 'dept:%'
END_SELECT

    $sth = $dbh->prepare($nwhere);
    $sth->execute();
    while(@row = $sth->fetchrow_array) {
      push(@ids, $row[0]);
    }
    $sth->finish;
    if ($#ids > -1) {
      $nwhere = "groups.id IN (".join(',', @ids).") ";
      $nwhere .= " AND $where" if ($where ne '');
    }else{
      $nwhere = "groups.name LIKE 'dept:%'";
      $nwhere .= " AND $where" if ($where ne '');
    }
    if ($method eq 'LIST') {
      $ref = CMU::Netdb::primitives::list($dbh, $dbuser, 'groups',
					  ['groups.name', $field], 
					  $nwhere);
    }else{
      $ref = CMU::Netdb::primitives::get($dbh, $dbuser, 'groups',
					 ['groups.name', $field], 
					 $nwhere);
    }
    $type = 'ALL' if (!defined $ref || !defined $ref->[0]);
  }
  
  if ($type eq 'ALL') {
    $nwhere = "groups.name like 'dept:%'";
    $nwhere .= " AND $where" if ($where ne '');
    
    if ((defined $method) && ($method eq 'LIST')) {
      $ref = CMU::Netdb::primitives::list($dbh, $dbuser, 'groups',
					  ['groups.name', $field],
					  $nwhere);
    }else{
      $ref = CMU::Netdb::primitives::get($dbh, $dbuser, 'groups',
					 ['groups.name', $field],
					 $nwhere);
    }
  }
  return {} if (!ref $ref);
  
  my %result;
  map { $result{$_->[0]} = $_->[1] } @$ref;
  return \%result;
}

# Is this user is any of the netreg:* groups?
# Also checks for user suspension
# Arguments:
#  - DB Handle
#  - User Name (e.g. 'ju33');
# Returns:
#  - If the user is suspended, -1
#  - If the user is not an administrator, 0
#  - If the user is an administrator, 1
sub get_user_admin_status {
  my ($dbh, $user) = @_;
  my ($query);

  return $useradmStatus if ($useradm eq $user);

  $query =<<END_SELECT;
SELECT G.id, U.flags
FROM        credentials AS C
  LEFT JOIN users AS U ON C.user = U.id
  LEFT JOIN memberships AS M ON M.uid = U.id
  LEFT JOIN groups AS G on G.id = M.gid
WHERE C.authid = '$user' AND
      (G.name like 'netreg:%' OR
       FIND_IN_SET('suspend', U.flags))
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::get_user_admin_status: $query" if ($debug >= 2);
  my $sth = $dbh->prepare($query);
  $sth->execute;
  my @row = $sth->fetchrow_array();
  $sth->finish;
  $useradm = $user;

  $useradmStatus = 0;
  if ($#row != -1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "get_user_admin_status row: ".join(',', @row) if ($debug >= 2);

    if ($row[1] =~ /suspend/) {
      $useradmStatus = -1;
    }elsif($row[0] ne '') {
      $useradmStatus = 1;
    }  
  }

  return $useradmStatus;
}

sub clear_user_admin_status {
  $useradm = '';
  $useradmStatus = 0;
}

# Is this user a departmental administrator?
sub get_user_deptadmin_status {
  my ($dbh, $user) = @_;
  my ($query);

  return $userdeptadmStatus if ($userdeptadm eq $user);

  $query =<<END_SELECT;
SELECT G.id FROM memberships AS M, groups as G, credentials AS C
WHERE C.authid = '$user'
  AND M.uid = C.user
  AND M.gid = G.id
  AND G.name like 'dept:%'
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::get_user_deptadmin_status: $query"
      if ($debug >= 2);
  my $sth = $dbh->prepare($query);
  $sth->execute;
  my @row = $sth->fetchrow_array();
  $sth->finish;
  $userdeptadm = $user;
  $userdeptadmStatus = (@row && defined $row[0] && $row[0] ne '');
  return $userdeptadmStatus;
}

sub clear_user_deptadmin_status {
  $userdeptadm = '';
  $userdeptadmStatus = 0;
}

# Does this user have read or write access of level 5 or higher on any groups?
sub get_user_group_admin_status {
  my ($dbh, $user) = @_;
  my ($query);

  return $usergroupadmStatus if ($usergroupadm eq $user);

  $query =<<END_SELECT;
SELECT P.tid FROM (credentials AS C, protections as P) 
LEFT JOIN memberships AS M ON (M.uid = C.user AND P.identity = CAST(M.gid AS SIGNED INT) * -1)
WHERE C.authid = '$user'
  AND P.tname = 'groups'
  AND P.identity IN (CAST(M.gid AS SIGNED INT) * -1, C.user, 0)
  AND (FIND_IN_SET('READ', P.rights)
       OR FIND_IN_SET('WRITE', P.rights))
  AND P.rlevel >= 5
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "CMU::Netdb::get_user_group_admin_status: $query" if ($debug >= 2);
  my $sth = $dbh->prepare($query);

  $sth->execute;

  my @row = $sth->fetchrow_array();
  $sth->finish;
  $usergroupadm = $user;
  $usergroupadmStatus = (@row && defined $row[0] && $row[0] ne '');
  return $usergroupadmStatus;
}

sub clear_user_group_admin_status {
  $usergroupadm = '';
  $usergroupadmStatus = 0;
}


# Returns true if user is in netreg:admins or netreg:datacomm
# (Added netreg:datacomm so datacomm people could modify permissions.
#  At present, this is ONLY used to determine who can make protections 
#  changes.  If it becomes used elsewhere, perhaps that should be 
#  reconsidered)
sub get_user_netreg_admin {
  my ($dbh, $user) = @_;
  my ($query);

  my $admStatus = 0;

  $query =<<END_SELECT;
SELECT G.id FROM memberships AS M, groups as G, credentials AS C
WHERE C.authid = '$user'
  AND M.uid = C.user
  AND M.gid = G.id
  AND (G.name like 'netreg:admins' OR
       G.name like 'netreg:datacomm')
END_SELECT

  warn __FILE__, ':', __LINE__, ' :>'.
    "get_user_netreg_admin: $query" if ($debug >= 2);
  my $sth = $dbh->prepare($query);
  $sth->execute;
  my @row = $sth->fetchrow_array();
  $sth->finish;

  $admStatus = (@row && defined $row[0] && $row[0] ne '');
  return $admStatus;
}


## This is the general clearinghouse for determining who can perform
## operations on the protections table
## - database handle
## - user
## - table to verify access against
## - table ID to verify
## - level of access requested
## - operation being performed (ADD WRITE READ)
## - target (group/user)
## - caller
sub auth_prot_op {
  my ($dbh, $user, $table, $tid, $rlevel, $operation, $target, $caller) = @_;
  my ($query, $sth, @row);
  
  my $uAdmin = get_user_netreg_admin($dbh, $user);
  
  return 1 if ($uAdmin eq '1' && ($operation eq 'READ' || $target !~ /^dept\:/));
  
  #return $errcodes{EPERM} if ($table ne 'machine' && $table ne 'outlet');
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "Verifying $operation access (target $target, rlevel $rlevel) for $table/$tid, user: $user ($caller)\n" if ($debug >= 2);
  
  my $permLevel = 0;
  if ($caller eq '' || $caller eq 'DEFAULT') {
    if ($operation eq 'READ') {
      $permLevel = CMU::Netdb::get_read_level($dbh, $user, $table, $tid);
    }elsif($operation eq 'WRITE' || $operation eq 'ADD') {
      if ($target =~ /^dept\:/) {
	if ($operation eq 'WRITE') {
	  # Disallow changes to dept: group entries on machines & outlets, 
	  # those are special and handled below
	  return $errcodes{EPERM} if (($table eq 'machine')||($table eq 'outlet'));
	  # Allow change if user has higher write level then he is granting
	  $permLevel = CMU::Netdb::get_write_level($dbh, $user, $table, $tid);
	  return $errcodes{EPERM} if ($permLevel < $rlevel);
	} 
	if ($operation eq 'ADD') {
	  # Disallow changes to dept: group entries on machines & outlets, 
	  # those are special and handled below
	  return $errcodes{EPERM} if (($table eq 'machine')||($table eq 'outlet'));
# This code used to prevent more then one dept:* group from being added to any database record.
# I don't see a reason to enforce that on anything but machines & outlets
#         my $lpr = CMU::Netdb::list_protections($dbh, $user, $table, $tid,
#                                                " G.name like 'dept:%' AND P.rlevel = $rlevel");
#         $permLevel = CMU::Netdb::get_write_level($dbh, $user, $table, $tid)
#           if (ref $lpr && !defined $lpr->[0]);

# So the new behavior is you can add dept:* entries with rlevel <= your write level on the record.
          $permLevel = CMU::Netdb::get_write_level($dbh, $user, $table, $tid);
	  return $errcodes{EPERM} if ($permLevel < $rlevel);
	}
      } 
      $query =<<END_SELECT;
SELECT P.rlevel
FROM protections as P, memberships as M, groups as G, credentials AS C
WHERE C.authid = '$user'
  AND C.user = M.uid
  AND M.gid = G.id
  AND (G.name like 'dept:%' OR G.name like 'netreg:%')
  AND P.tname = '$table'
  AND (P.tid = '$tid' OR P.tid = 0)
  AND FIND_IN_SET('WRITE',P.rights)
  AND P.identity = CAST(G.id AS SIGNED INT) * -1
  ORDER BY P.rlevel DESC
END_SELECT
      warn __FILE__, ':', __LINE__, ' :>'.
	"auth_prot_op: query: $query\n" if ($debug >= 2);
      $sth = $dbh->prepare($query);
      $sth->execute;
      @row = $sth->fetchrow_array();
      $permLevel = $row[0] if (@row && defined $row[0] && $row[0] > $permLevel);
    }
  }elsif($caller eq 'RUBIKS_CUBE') { 
    # stuff like adding/deleting entire machines
    # WRITE just gets set to 0. sorry, dude.
    if ($operation eq 'READ') {
      $permLevel = CMU::Netdb::get_read_level($dbh, $user, $table, $tid);
    }elsif($operation eq 'ADD') {
      ## allowed to add a single dept: and their own userid. nothing else.
      if ($target =~ /^dept:/) {
	my $lpr = CMU::Netdb::list_protections($dbh, 'netreg', $table, $tid, 
				   " G.name like 'dept:%'");
	$permLevel = 5 if (ref $lpr && !defined $lpr->[1]);
      }elsif ($user eq $target) {
        $permLevel = 1;
      } else {
        my $wl = CMU::Netdb::get_write_level($dbh, $user, $table, $tid);
        $permLevel = 1 if ($wl > 1);
      }
    }
  }else{
    # can't help you. buh-bye.
  }
  warn __FILE__, ':', __LINE__, ' :>'.
    "PERMS: $permLevel, $rlevel\n" if ($debug >= 2);
  return $errcodes{EPERM} if ($permLevel < $rlevel);
  return $permLevel;
}

# Function: apply_prot_profile  
# Apply a given protections profile to the specified values
# and add a variety of protections entries
# Arguments:
#  - dbh : database handle
#  - dbuser : effective user
#  - PName : name of profile to apply
#  - table name : name of table that the protections are being applied to
#  - table id : id of the record in the table that the protections apply to
#  - update auth : will be passed as the 'caller' to add_*_to_protections 
#  - parameters ( see below )
# Parameters:
#  The parameters field specifies values for variable entries in the 
#  protections profile. For example, %user in the profile will be replaced
#  by the username (if 'user' is passed to us as a parameter)
# Returns: 
#  Two element array.
#    If first element:
#      < 0, error, second element is reference to an array of problem fields
#      1, full success, no second element
#      2, partial success, error fields from one error
sub apply_prot_profile {
  my ($dbh, $dbuser, $profile, $table, $tid, $auth, $parms) = @_;

  return (-1, ['parameters']) unless (ref $parms);
  my %Parms = %$parms;

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);
  
  my ($pres, $Profiles) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'PROTECTION_PROFILES');
  return ($pres, $Profiles) if ($pres < 1);

  return (-1, ['profiles'])
    if (!defined $Profiles || 
	!ref $Profiles eq 'HASH' || 
	!defined $Profiles->{$profile} ||
	!defined $Profiles->{$profile}->{entries} ||
	!ref $Profiles->{$profile}->{entries});

  # Make an array if only one entry actually exists
  $Profiles->{$profile}->{entries} = [$Profiles->{$profile}->{entries}]
    if (ref $Profiles->{$profile}->{entries} eq 'HASH');

  warn __FILE__, ':', __LINE__, ' :> '.
    "protection profiles: ".Dumper($Profiles) if ($debug >= 2);

  my $LastErrfields;
  my ($Success, $Failure) = (0,0);
  foreach my $PEntry (@{$Profiles->{$profile}->{entries}}) {
    # Substitute values from parms
    # Should be able to do this with a map {} but something's not
    # working as it should.
    my ($UserGroup, $Level, $Rights) = ($PEntry->{'id'}, $PEntry->{'level'},
					$PEntry->{'permission'});
    $UserGroup =~ s/\%([^\s\%]+)\%/$Parms{$1}/g;
    $Level =~ s/\%([^\s\%]+)\%/$Parms{$1}/g;
    $Rights =~ s/\%([^\s\%]+)\%/$Parms{$1}/g;

    my $res;
    warn __FILE__, ':', __LINE__, ' :>'.
	"Adding protections entry [$UserGroup, $table, $tid, $Rights, ".
	  "$Level] ($auth/$dbuser)\n" if ($debug >= 2);
    if ($UserGroup =~ /\:/) {
      # Assume it's a group because a colon is present
      ($res, $LastErrfields) = CMU::Netdb::add_group_to_protections
	($dbh, $dbuser, $UserGroup, $table, $tid, $Rights, $Level, $auth);
    }else{
      ($res, $LastErrfields) = CMU::Netdb::add_user_to_protections
	($dbh, $dbuser, $UserGroup, $table, $tid, $Rights, $Level, $auth);
    }
    $Failure++ if ($res != 1);
    $Success++ if ($res == 1);
  }

  if ($Success && $Failure) {
    return (2, $LastErrfields);
  }elsif($Success) {
    return (1, []);
  }
  return (-1, $LastErrfields);
}

1;  

  
 
