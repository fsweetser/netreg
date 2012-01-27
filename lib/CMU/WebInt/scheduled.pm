#   -*- perl -*-
#
# CMU::WebInt::scheduled
#
# $Id: scheduled.pm,v 1.17 2008/03/27 19:42:38 vitroth Exp $
#
# $Log: scheduled.pm,v $
# Revision 1.17  2008/03/27 19:42:38  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.16.8.1  2007/10/11 20:59:43  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.16.6.1  2007/09/20 18:43:06  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.2  2004/12/04 23:25:27  kcmiller
# * Update accessDenied everywhere
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.13  2004/02/20 03:14:25  kevinm
# * External config file updates
#
# Revision 1.12  2003/06/27 13:19:23  kevinm
# * Incorrect op code in paging call, noticed by Kurt Eckert
#
# Revision 1.11  2002/08/20 14:48:12  kevinm
# * Added $errors to stdhdr everywhere
#
# Revision 1.10  2002/07/29 21:49:39  ebardsle
# Included HTML 4.01 ACCESSKEY and LABEL tags.
#
# Revision 1.9  2002/03/04 16:54:38  kevinm
# * Fixed ORDER BY statements
#
# Revision 1.8  2002/02/28 02:54:58  kevinm
# Back off for scheduler
#
# Revision 1.7  2002/02/28 02:20:37  kevinm
# Don't die on invalid update
#
# Revision 1.6  2002/02/27 18:27:53  kevinm
# Added scheduler note text link
#
# Revision 1.5  2002/02/27 18:05:14  kevinm
# Changed protection level for seeing scheduler tasks.
#
# Revision 1.4  2002/02/27 18:03:02  kevinm
# Text changes, scheduler frontend done
#
# Revision 1.3  2002/01/03 20:56:32  kevinm
# * Changed variables from interface/vars to config
# * Changed service_attribute to attribute
# * Initial parts of user attributes added (sorting changed from numeric to table name)
# * Added option for disabling outlet/cable/telecom portions in config
# *
#
# Revision 1.2  2001/11/07 18:13:57  kevinm
# Removed high debugging levels.
#
# Revision 1.1  2001/10/08 14:36:57  kevinm
# Initial checkin for forcing scheduled stuff. Not ready for primetime.
#
#
#

package CMU::WebInt::scheduled;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %errmeanings %network_pos $debug %sch_pos %sch_p);

use CMU::WebInt;
use CMU::Netdb;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw/sch_main sch_upd sch_force sch_add_form sch_add/;

$debug = 0;
%sch_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::sys_scheduled_fields)};
%sch_p = %CMU::Netdb::structure::sys_scheduled_printable;
%errmeanings = %CMU::Netdb::errors::errmeanings;

sub sch_main {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('sch_main');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Scheduled Process Admin", 
			    $errors);
  &CMU::WebInt::title("List of Processes");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, '_sys_scheduled', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('_sys_scheduled', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print smallRight "[<b><a href=\"$url?op=sch_add_form\">Add Process</a></b>] ".
    CMU::WebInt::pageHelpLink('');

  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'id' if ($sort eq '');

  $res = sch_print_scheduled($user, $dbh, $q,  
			     " TRUE ".
			     CMU::Netdb::verify_orderby($sort), '',
			     $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'sch_main');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  &sch_add_form($q, $errors);
  
  print CMU::WebInt::subHeading("Scheduler Notes");
  print $CMU::WebInt::vars::htext{'scheduler_notes'};

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub sch_add {
  my ($q, $errors) = @_;

  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 
					   '_sys_scheduled', $id);
  
  if ($userlevel < 9) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Scheduled Process Admin",
			      $errors);
    &CMU::WebInt::title("Add Scheduled Process");

    &CMU::WebInt::accessDenied('_sys_scheduled', 'WRITE', $id, 9, $userlevel,
			       $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  foreach (qw/name def_interval/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  
  my ($res, $errfields) = CMU::Netdb::add_scheduled($dbh, $user, 
						    \%fields);
  if ($res > 0) {
    $nerrors{'msg'} = "Added process $fields{name}.";

    $dbh->disconnect(); # we use this for the insertid ..
    return CMU::WebInt::sch_main($q, \%nerrors);
  }else{
    $nerrors{'msg'} = "Error adding process: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{code} = $res;
      $nerrors{type} = 'ERR';
      $nerrors{fields} = join(',', @$errfields);
      $nerrors{loc} = 'sch_add';
    }
    $dbh->disconnect();
    return &CMU::WebInt::sch_main($q, \%nerrors);
  }
}

sub sch_add_form {
  my ($q, $rErrors) = @_;

  my %errors = %$rErrors if (ref $rErrors);
  print "<br>";
  print CMU::WebInt::subHeading("<u>A</u>dd Scheduled Process");
  print "Enter the name of the scheduled process, and the default number of minutes ".
    "to wait between each run of this process. Note that you must update <tt>scheduled.pl</tt> ".
      "with the ID of this record as a pointer to the script that will be run.<br><br>".
	"The script cannot be specified in this database to provide separation in Unix ".
	  "user permissions.<br>";
  print "<form method=get>".
    "<input type=hidden name=op value=sch_add>";
  
  print "<table border=0>".
    "<tr>".CMU::WebInt::printPossError(defined $errors{name},
				  $sch_p{'_sys_scheduled.name'},
				  1, '_sys_scheduled.name');
  print CMU::WebInt::printPossError(defined $errors{def_interval},
				    $sch_p{'_sys_scheduled.def_interval'},
				    1, '_sys_scheduled.def_interval');
  print "</tr><tr><td><input accesskey=a type=text name='name'></td>".
    "<td><input type=text name='def_interval' size=5> min.</td></tr>\n";
  print "<tr><td><input type=submit value=\"Add Process\"></td></tr>\n";
  print "</table>\n";
}

# sch_print_scheduled
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the building WHERE clause
#   - parameters to count WHERE
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
#   - lmach
sub sch_print_scheduled {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, '_sys_scheduled', $cwhere);
  
  return $ctRow if (!ref $ctRow);
  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DEF_ITEMS_PER_PAGE');
  return 0 if ($vres != 1);

  ($vres, $maxPages) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DEF_MAX_PAGES');
  return 0 if ($vres != 1);

  $lmach .= "&$oData" if ($oData ne '');
  print &CMU::WebInt::pager_Top($start, $$ctRow[0], $defitems, $maxPages,
		   $url, "op=".$lmach, $skey);
  $where = "1" if ($where eq '');
  $ruRef = CMU::Netdb::list_scheduled($dbh, $user, " $where ".
				      CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_scheduled: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint
    ($ENV{SCRIPT_NAME}, $ruRef, 
     [],
#     ['_sys_scheduled.name', '_sys_scheduled.previous_run', '_sys_scheduled.next_run'], 
     [\&sch_cb_name, \&sch_cb_pr, \&sch_cb_nr, \&sch_cb_bu, \&sch_cb_def, \&sch_cb_upd], '',
     'sch_main', '',
     \%sch_pos, 
     \%sch_p,
     '_sys_scheduled.name', '_sys_scheduled.id', 'sort', 
     ['name', 'previous_run', 'next_run', 'def_interval', 'blocked_until', 'id']);
  return 1;
}

sub sch_upd {
  my ($q, $errors) = @_;

  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 
					   '_sys_scheduled', $id);
  
  if ($userlevel < 9) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Scheduled Process Admin",
			      $errors);
    &CMU::WebInt::title("Update Schedule");

    &CMU::WebInt::accessDenied('_sys_scheduled', 'WRITE', $id, 9, $userlevel,
			       $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  foreach (qw/name def_interval blocked_until/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  
  my ($res, $errfields) = CMU::Netdb::modify_scheduled($dbh, $user, 
						       $id, $version, 
						       \%fields);
  if ($res > 0) {
    $nerrors{'msg'} = "Updated process $fields{name}.";

    $dbh->disconnect(); # we use this for the insertid ..
    return CMU::WebInt::sch_main($q, \%nerrors);
  }else{
    $nerrors{'msg'} = "Error updating process: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{code} = $res;
      $nerrors{type} = 'ERR';
      $nerrors{fields} = join(',', @$errfields);
      $nerrors{loc} = 'sch_upd';
    }
    $dbh->disconnect();
    return &CMU::WebInt::sch_main($q, \%nerrors);
  }
}

sub sch_force {
  my ($q, $errors) = @_;
  my %nerrors;
  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  my $userlevel = CMU::Netdb::get_write_level($dbh, $user, '_sys_scheduled', $id);
  
  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Scheduled Process Admin",
			       $errors);
    &CMU::WebInt::title("Force Run");
    CMU::WebInt::accessDenied('_sys_scheduled', 'WRITE', $id, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $force = CMU::WebInt::gParam($q, 'force');
  $force = 0 if ($force eq '');
  my ($res, $errfields) = CMU::Netdb::force_scheduled($dbh, $user, $id, $version, $force);
  if ($res > 0) {
    if ($force eq '1') {
      $nerrors{'msg'} = "Backed off run of #$id.";
    }else{
      $nerrors{'msg'} = "Forced run of #$id.";
    }

    $dbh->disconnect(); # we use this for the insertid ..
    return CMU::WebInt::sch_main($q, \%nerrors);
  }else{
    $nerrors{'msg'} = "Error forcing run: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{code} = $res;
      $nerrors{type} = 'ERR';
      $nerrors{fields} = join(',', @$errfields);
      $nerrors{loc} = 'sch_force';
    }
    $dbh->disconnect();
    return CMU::WebInt::sch_main($q, \%nerrors);
  }
}

sub sch_cb_def {
  my ($url, $dref, $udata) = @_;

  return 'Interval' if (!ref $dref);
  my @rrow = @{$dref};

  return "<input accesskey=i type=text name=def_interval size=5 value='$rrow[$sch_pos{'_sys_scheduled.def_interval'}]'> min";
}

sub sch_cb_pr {
  my ($url, $dref, $udata) = @_;

  return "Previous" if (!ref $dref);
  my @rrow = @{$dref};

  my $Date = $rrow[$sch_pos{'_sys_scheduled.previous_run'}];
  my @DA = split(/\s+/, $Date);
  return join('<br>', @DA);
}

sub sch_cb_nr {
  my ($url, $dref, $udata) = @_;

  return "Next" if (!ref $dref);
  my @rrow = @{$dref};

  my $Date = $rrow[$sch_pos{'_sys_scheduled.next_run'}];
  my @DA = split(/\s+/, $Date);
  return join('<br>', @DA);
 }


sub sch_cb_bu {
  my ($url, $dref, $udata) = @_;

  return "Blocked" if (!ref $dref);
  my @rrow = @{$dref};

  my $Date = $rrow[$sch_pos{'_sys_scheduled.blocked_until'}];
  
  return "<input accesskey=b type=text name=blocked_until value=\"$Date\" size=10>\n";
}

sub sch_cb_force {
  my ($url, $dref, $udata) = @_;

  return "Force Run" if (!ref $dref);
  my @rrow = @{$dref};

  return "<a href=\"".CMU::WebInt::encURL("$url?op=sch_force&id=$rrow[$sch_pos{'_sys_scheduled.id'}]&version=$rrow[$sch_pos{'_sys_scheduled.version'}]")."\">Force</a>";
}

sub sch_cb_name {
  my ($url, $dref, $udata) = @_;

  return $sch_p{'_sys_scheduled.name'} if (!ref $dref);
  my @rrow = @{$dref};

  return "<form method=get><input type=hidden name=id value='$rrow[$sch_pos{'_sys_scheduled.id'}]'>
<input type=hidden name=version value=\"".$rrow[$sch_pos{'_sys_scheduled.version'}]."\">
<input type=hidden name=op value=sch_upd>
<input accesskey=n type=text name=name size=25 value='$rrow[$sch_pos{'_sys_scheduled.name'}]'>";
}

sub sch_cb_upd {
  my ($url, $dref, $udata) = @_;

  return "Operations" if (!ref $dref);
  my @rrow = @{$dref};

  my $URL = CMU::WebInt::encURL("$url?op=sch_force&id=$rrow[$sch_pos{'_sys_scheduled.id'}]".

    "&version=$rrow[$sch_pos{'_sys_scheduled.version'}]");
  
  return "<br><a href=\"$URL&force=0\">Force Run</a><br>".
    "<a href=\"$URL&force=1\">Back Off</a><br>".
      "<input type=submit value='Update'></form>\n";
}



1;
