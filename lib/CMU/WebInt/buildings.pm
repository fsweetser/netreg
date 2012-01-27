#   -*- perl -*-
#
# CMU::WebInt::buildings
#  Operations on building information
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

package CMU::WebInt::buildings;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings
	     %building_pos %build_p);
use CMU::WebInt;
use CMU::Netdb;

use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(build_list build_view build_delete build_confirm_del
	     build_add_form build_add build_s_exec build_search build_update);

%errmeanings = %CMU::Netdb::errors::errmeanings;
%building_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::building_fields)};

%build_p = %CMU::Netdb::structure::building_printable;

sub build_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('build_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Building Admin", $errors);
  &CMU::WebInt::title("List of Buildings");
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'building', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('buildings', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=build_search>Search Buildings</a></b>]  
[<b><a href=$url?op=build_add_form>Add Building</a></b>] ".CMU::WebInt::pageHelpLink(''));


  my $bld = CMU::Netdb::list_buildingID_ref($dbh, $user, '', 'building.name');
  if (ref $bld) {
    my @bldk = sort { $$bld{$a} cmp $$bld{$b} } keys %$bld;
    unshift(@bldk, '--select--');
    print "<form method=get>\n<input type=hidden name=op value=build_view>\n";
    print CMU::WebInt::smallRight($q->popup_menu(-name => 'id',
						 -accesskey => 'b',
						 -values => \@bldk,
						 -labels => $bld) 
				  . "\n<input type=submit value=\"View Building\"></form>\n");

  } else {
    &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
			     'Error loading buildings (list_buildings_ref).', {});
  }


  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'building.name' if ($sort eq '');
  
  $res = build_print_building($user, $dbh, $q,  
			      " TRUE ".
                              CMU::Netdb::verify_orderby($sort), '',
			      $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'build_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# build_print_buildings
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
sub build_print_building {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'building', $cwhere);
#  $ctRow = [72];
  
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
  $ruRef = CMU::Netdb::list_buildings($dbh, $user, " $where ".
				      CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_buildings: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['building.name', 'building.abbreviation'], [], '',
		 'build_list', 'op=build_view&id=',
		 \%building_pos, 
		 \%build_p,
		 'building.name', 'building.id', 'sort',
			     ['building.name', 'building.abbreviation']);
  return 1;
}

sub build_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $id = CMU::WebInt::gParam($q, 'id');

  $$errors{msg} = "Building ID not specified!" if ($id eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('build_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Building Admin", $errors);
  &CMU::WebInt::title("Building Information");
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'building', $id);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'building', $id);

  if ($ul == 0) {
    CMU::WebInt::accessDenied('building', 'READ', $id, 1, 0, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  my $bref = CMU::Netdb::list_buildings($dbh, $user, "building.id='$id'");
  if (!ref $bref) {
    print "<br>Building ID not found.\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my @sdata = @{$bref->[1]};
  
  print CMU::WebInt::subHeading("Information for: ".$sdata[$building_pos{'building.name'}],
		  CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=\"".CMU::WebInt::encURL("$url?op=build_view&id=$id")."\">Refresh</a></b>]
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=build_del&id=$id&version=".
   $sdata[$building_pos{'building.version'}])."\">Delete Building</a></b>]\n");

  # name, abbreviation
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=build_update>
<input type=hidden name=version value=\"".$sdata[$building_pos{'building.version'}]."\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $build_p{'building.name'}, 1, 'building.name').
  CMU::WebInt::printPossError(defined $errors->{'abbreviation'}, $build_p{'building.abbreviation'}, 1, 'building.abbreviation').
    "</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('building.name', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name => 'name', -accesskey=> 'n', -value => $sdata[$building_pos{'building.name'}]).
    "</td><td>".CMU::WebInt::printVerbose('building.abbreviation', $verbose).
      $q->textfield(-name => 'abbreviation', -accesskey => 'a',
		-value => $sdata[$building_pos{'building.abbreviation'}])."</td></tr>\n";
  }else{
    print $sdata[$building_pos{'building.name'}]."</td><td>".
      $sdata[$building_pos{'building.abbreviation'}]."</td></tr>\n";
  }

  # number
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'building'}, $build_p{'building.building'}, 1, 'building.number')."</tr>\n";

  print "<tr><td>".CMU::WebInt::printVerbose('building.number', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name=> 'building', -accesskey => 'b',
			-value=> $sdata[$building_pos{'building.building'}])."</td></tr>\n";
  }else{
    print $sdata[$building_pos{'building.building'}]."</td></tr>\n";
  }

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n" 
    if ($wl >= 1);
      
  print "</table></form>\n";

  ## building presence in trunk-set
  my ($vres, $en) = CMU::Netdb::config::get_multi_conf_var
		    ('webint', 'ENABLE_TRUNK_SET');
  if ($en == 1) {
      print CMU::WebInt::subHeading("Trunk Set in Buildings",CMU::WebInt::pageHelpLink(''));
      my $pref = CMU::Netdb::list_trunkset_presences($dbh,$user,'building',"buildings='$id'");
      my $bref = CMU::Netdb::list_trunkset_ref($dbh,$user, '','trunk_set.name');
      $$bref{'##q--'}	= $q;
      $$bref{'##bid--'}	= $id;
      $$bref{'##type--'} 	= 'building';
      CMU::WebInt::generic_smTable($url,$pref,['trunk_set.name'],
				    \%CMU::WebInt::trunkset::ts_building_tsb_pos,
				    \%CMU::Netdb::structure::trunkset_building_presence_ts_building_printable,
				    "bid=$id",'trunkset_building_presence','ts_del_member',
				    \&CMU::WebInt::trunkset::trunkset_cb_add_presence,
				    $bref, 'trunkset_building_presence.trunk_set', "op=trunkset_info&tid=");
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub build_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('build_del');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Buildings", {});
  print &CMU::WebInt::subHeading("Delete Building", CMU::WebInt::pageHelpLink(''));
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'building', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('buildings', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic building infromation
  my $sref = CMU::Netdb::list_buildings($dbh, $user, "building.id='$id'");
  if (!defined $sref->[1]) {
    print "Building not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following building.\n";
  
  my @print_fields = ('building.name', 'building.abbreviation');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$build_p{$f}."</th>
<td>";
    print $sdata[$building_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=build_del_conf&id=$id&version=$version")."\">
Yes, delete this building";
  print "<br><a href=\"$url?op=build_list\">No, return to the buildings list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub build_confirm_del {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'building', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete building $id\n";
    $dbh->disconnect();
    CMU::WebInt::build_view($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_building($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    CMU::WebInt::build_list($q, {'msg' => "The building was deleted."});
  }else{
    $errors{msg} = "Error while deleting building: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{type} = 'ERR';
    $errors{loc} = 'build_del_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    CMU::WebInt::build_view($q, \%errors);
  }

}

sub build_search {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, %groups, $grp, $mem, $gwhere);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('build_search');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Buildings", $errors);
  &CMU::WebInt::title("Search Buildings");
  $url = $ENV{SCRIPT_NAME};
	       
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::printVerbose('machine.search_general', 1);

  print &CMU::WebInt::subHeading("Search Parameters", CMU::WebInt::pageHelpLink(''));
  
print "<br><form method=get>\n
<input type=hidden name=op value=build_s_exec>
<table border=1>";

  # name
  print "<tr>".CMU::WebInt::printPossError(0, $build_p{'building.name'}, 1, 'building.name').
    "<td>".$q->textfield(-name => 'name')."</td></tr>";
  
  # abbreviation
  print "<tr>".CMU::WebInt::printPossError(0, $build_p{'building.abbreviation'}, 1, 'building.abbreviation').
    "<td>".$q->textfield(-name => 'abbreviation')."</td></tr>";
  
  # building
  print "<tr>".CMU::WebInt::printPossError(0, $build_p{'building.building'}, 1, 'building.number').
    "<td>".$q->textfield(-name => 'building')."</td></tr>";
  
  print "</table>\n";
  print "<input type=submit value=\"Search\"></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub build_s_exec {
  my ($q, $errors) = @_;
  my ($dbh, $url, $query, @q);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('build_s_exec');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Buildings", $errors);
  &CMU::WebInt::title("Search Buildings");
  $url = $ENV{SCRIPT_NAME};

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print &CMU::WebInt::subHeading("Search Results", CMU::WebInt::pageHelpLink(''));
  # name
  if (CMU::WebInt::gParam($q, 'name') ne '') {
    if (CMU::WebInt::gParam($q, 'name') =~ /\%/) {
      push(@q, 'building.name like '.$dbh->quote(CMU::WebInt::gParam($q, 'name')));
    }else{
      push(@q, 'building.name like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'name').'%'));
    }
  }
  # abbreviation
  if (CMU::WebInt::gParam($q, 'abbreviation') ne '') {
    if (CMU::WebInt::gParam($q, 'abbreviation') =~ /\%/) {
      push(@q, 'abbreviation like '.$dbh->quote(CMU::WebInt::gParam($q, 'abbreviation')));
    }else{
      push(@q, 'abbreviation like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'abbreviation').'%'));
    }
  }
  # building
  if (CMU::WebInt::gParam($q, 'building') ne '') {
    if (CMU::WebInt::gParam($q, 'building') =~ /\%/) {
      push(@q, 'building like '.$dbh->quote(CMU::WebInt::gParam($q, 'building')));
    }else{
      push(@q, 'building like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'building').'%'));
    }
  }
  my @rurl;
  foreach('name', 'abbreviation', 'building') {
    push(@rurl, "$_=".CMU::WebInt::gParam($q, $_)) if (CMU::WebInt::gParam($q, $_) ne '');
  }

  my $gwhere = join(' AND ', @q);
  $gwhere = '1' if ($gwhere eq '');

  my $sort = 'building.name';
  push(@rurl, "sort=$sort");
  my $res = build_print_building($user, $dbh, $q, 
				 $gwhere.
				 CMU::Netdb::verify_orderby($sort), 
				 $gwhere,
				 $url, join('&', @rurl), 'start', 'build_s_exec');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub build_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'building', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('build_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Building Admin", $errors);
  &CMU::WebInt::title("Add a Building");

  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('building', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  # name, abbreviation
  print "
<form method=get>
<input type=hidden name=op value=build_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $build_p{'building.name'}, 1, 'building.name').
  CMU::WebInt::printPossError(defined $errors{abbreviation}, $build_p{'building.abbreviation'}, 1, 'building.abbreviation')."</tr>
<tr><td>".CMU::WebInt::printVerbose('building.name', $verbose).
  $q->textfield(-name => 'name')."</td><td>".
    CMU::WebInt::printVerbose('building.abbreviation', $verbose).
  $q->textfield(-name => 'abbreviation')."</td></tr>\n";

  # 8-digit building number
  print "<tr>".
    CMU::WebInt::printPossError(defined $errors{building}, $build_p{'building.building'}, 1, 'building.number').
	"</tr><tr><td>".CMU::WebInt::printVerbose('building.number', $verbose).
	  $q->textfield(-name => 'building', -size => 8)."</td></tr>";

  print "</table>\n";
  print "<input type=submit value=\"Add Building\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub build_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'abbreviation' => CMU::WebInt::gParam($q, 'abbreviation'),
	     'building' => CMU::WebInt::gParam($q, 'building'));

  my ($res, $errfields) = CMU::Netdb::add_building($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added building $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    CMU::WebInt::build_view($q, \%nerrors);
  }else{
    $nerrors{'msg'} = "Error adding building: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'build_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    &CMU::WebInt::build_add_form($q, \%nerrors);
  }
}

sub build_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'building', $id);

  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Building Admin", $errors);
    &CMU::WebInt::title("Update Building");
    CMU::WebInt::accessDenied('building', 'WRITE', $id, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'abbreviation' => CMU::WebInt::gParam($q, 'abbreviation'),
	     'building' => CMU::WebInt::gParam($q, 'building'));

  my ($res, $errfields) = CMU::Netdb::modify_building($dbh, $user, $id, $version, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Updated building.";
    $dbh->disconnect(); 
    &CMU::WebInt::build_view($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{type} = 'ERR';
    $nerrors{loc} = 'build_upd';
    $nerrors{code} = $res;
    $nerrors{fields} = join(',', @$errfields);
    $dbh->disconnect();
    &CMU::WebInt::build_view($q, \%nerrors);
  }
}

1;
