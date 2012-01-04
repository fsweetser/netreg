#   -*- perl -*-
#
# CMU::WebInt::cables
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

package CMU::WebInt::cables;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings $THCOLOR
	     %cable_pos %cable_p);
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

@EXPORT = qw(cables_main cables_view cables_search cables_s_exec);

%errmeanings = %CMU::Netdb::errors::errmeanings;

%cable_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::cable_fields)};
%cable_p = %CMU::Netdb::structure::cable_printable;

my ($gmcvres);
($gmcvres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'THCOLOR');

sub cables_main {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('cable_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Admin", $errors);
  &CMU::WebInt::title("List of Cables");

  $url = $ENV{SCRIPT_NAME};
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'cable', 0);

  if ($wl >= 9) {
    print CMU::WebInt::smallRight("[<b><a href=\"$url?op=cable_add_s0\">Add Cable</a></b>] " 
    . "[<b><a href=\"$url?op=oact_telco_0\">Telecom Cable Maintenance</a></b>]"
      . " [<b><a href=$url?op=cable_search>Search</a></b>] ".
	CMU::WebInt::pageHelpLink('')."\n");
  } else {
    print CMU::WebInt::smallRight("[<b><a href=\"$url?op=oact_telco_0\">Telecom Cable Maintenance</a></b>]"
      . " [<b><a href=$url?op=cable_search>Search</a></b>] ".
	CMU::WebInt::pageHelpLink('')."\n");
  }

  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'cable.type' if ($sort eq '');
  
  $res = cables_print_cable($user, $dbh, $q, 
			    " 1 ".CMU::Netdb::verify_orderby($sort), 
			    $ENV{SCRIPT_NAME}, "op=cable_list&sort=$sort", 'start');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# cables_print_cable
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the subnet WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub cables_print_cable {
  my ($user, $dbh, $q, $where, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'cable', $where);
  
  return $ctRow if (!ref $ctRow);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DEF_ITEMS_PER_PAGE');
  return 0 if ($vres != 1);

  ($vres, $maxPages) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DEF_MAX_PAGES');
  return 0 if ($vres != 1);

  print &CMU::WebInt::pager_Top($start, $$ctRow[0], $defitems, $maxPages,
		   $url, $oData, $skey);
  $where = "1" if ($where eq '');
  $ruRef = CMU::Netdb::list_cables($dbh, $user, " $where ".
				   CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_cable: ".$errmeanings{$ruRef};
    return 0;
  }
  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, '');

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['cable.label_from', 'cable.label_to',
		  'cable.type', 'cable.destination'],
		 [\&cables_cb_to_building,
		  \&cables_cb_to_room_number], $bref,
		 'cable_list', 'op=cable_view&id=', 
		 \%cable_pos, \%cable_p, 'cable.label_from', 'cable.id',
		 'sort', ['cable.label_from', 'cable.label_to', 'cable.type',
			 'cable.destination', 'cable.to_building', 'cable.to_room_number']);
  
  return 1;
}

sub cables_cb_to_building { 
  my ($url, $dref, $bref) = @_;
  return $cable_p{'cable.to_building'} if (!ref $dref);
  my @rrow = @{$dref};
  
  my $b = $rrow[$cable_pos{'cable.to_building'}];
  return $$bref{$b} if ($b ne '');
  return $b;
}

# called with the url of the refresh, reference to the data,
# and $bref for the building list. this is for subnets_cb_to_building only
sub cables_cb_to_room_number { 
  my ($url, $dref, $bref) = @_;
  return $cable_p{'cable.to_room_number'} if (!ref $dref);
  my @rrow = @{$dref};
  return $rrow[$cable_pos{'cable.to_room_number'}];
}

sub cables_search {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, %groups, $grp, $mem, $gwhere);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('cable_search');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cables", $errors);
  &CMU::WebInt::title("Search Cables");
  $url = $ENV{SCRIPT_NAME};
	       
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print "<ul><li>Enter your search parameters.<li>Fields left blank are ignored.";
  print "<li>Results only include cables that you have read permission to.\n";
  print "<li>For text searches, your input will match any part of the specified
field unless you include % operators to indicate wildcard areas.</ul>\n";
print "<br><form method=get>\n
<input type=hidden name=op value=cable_s_exec>
<table border=1>";

  # type
  my @a = @CMU::Netdb::structure::cable_type;
  unshift(@a, '--select--');
  print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.type'}."</td><td>".$q->popup_menu(-name => 'type', -values => \@a)."</td></tr>";

  # destination
  my @dest = ('--select--', 'OUTLET', 'CLOSET');
  print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.destination'}."</td><td>".$q->popup_menu(-name => 'type', -values => \@dest)."</td></tr>";

  # rack
  @a = @CMU::Netdb::structure::cable_rack;
  unshift(@a, '--select--');
  print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.rack'}."</td><td>".$q->popup_menu(-name => 'type', -values => \@a)."</td></tr>";

  # all the other ones...
  foreach(qw/label_from label_to prefix from_building from_wing from_floor
	  from_closet from_rack from_panel from_x from_y to_building to_wing
	  to_floor to_closet to_rack to_panel to_x to_y to_floor_plan_x
	  to_floor_plan_y to_outlet_number to_room_number/) {
    print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.'.$_}."</td><td>".$q->textfield(-name => $_)."</td></tr>\n";
  }
  print "</table>\n";
  print "<input type=submit value=\"Search\"></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub cables_s_exec {
  my ($q, $errors) = @_;
  my ($dbh, $url, $query, @q);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('cable_s_exec');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cables", $errors);
  &CMU::WebInt::title("Search Cables");
  $url = $ENV{SCRIPT_NAME};

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  my @rurl;
  foreach(qw/label_from label_to prefix from_building from_wing from_floor
	  from_closet from_rack from_panel from_x from_y to_building to_wing
	  to_floor to_closet to_rack to_panel to_x to_y to_floor_plan_x
	  to_floor_plan_y to_outlet_number to_room_number destination 
	  rack type/) {
    if (CMU::WebInt::gParam($q, $_) ne '' && CMU::WebInt::gParam($q, $_) ne '--select--') {
      if (CMU::WebInt::gParam($q, $_) =~ /\%/) {
	push(@q, "cable.$_ like \"".CMU::WebInt::gParam($q, $_)."\"");
      }else{
	push(@q, "cable.$_ like \"%".CMU::WebInt::gParam($q, $_)."%\"");
      }
      push(@rurl, "$_=".CMU::WebInt::gParam($q, $_));
    }
  }
    
  my $gwhere = join(' AND ', @q);
  $gwhere = '1' if ($gwhere eq '');
  print "Query: $gwhere\n";
  my $sort = 'cable.label_from';
  push(@rurl, "sort=$sort");
  my $res = cables_print_cable($user, $dbh, $q, 
			       $gwhere.CMU::Netdb::verify_orderby($sort),
			       $url, "op=cable_s_exec&".join('&', @rurl), 'start', 'cables_s_exec');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub cables_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('cable_view');
  %errors = %$errors if (ref $errors);
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cables", $errors);
  &CMU::WebInt::title('Cable Information');
  $id = CMU::WebInt::gParam($q, 'id');

  $$errors{'msg'} = "Cable ID not specified!" if ($id eq '');

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'cable', $id);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'cable', $id);

  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'READ', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # basic cable information
  my $sref = CMU::Netdb::list_cables($dbh, $user, "cable.id='$id'");
  if (!defined $sref->[1]) {
    print "Cable not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  
  # label from/to
  my $version = $sdata[$cable_pos{'cable.version'}];
  print CMU::WebInt::subHeading("Information for: ".$sdata[$cable_pos{'cable.label_from'}].
		   "/".$sdata[$cable_pos{'cable.label_to'}], CMU::WebInt::pageHelpLink(''));
  if ($wl >= 9) {
    print CMU::WebInt::smallRight("[<b><a href=$url?op=cable_view&id=$id>Refresh</a></b>] \n" .
      "[<b><a href=$url?op=prot_s3&table=cable&tidType=1&tid=$id>View/Update Protections</a></b>]\n" .
 "[<b><a href=\"".CMU::WebInt::encURL("$url?op=cable_del&id=$id&version=$version")."\">Delete Cable</a></b>]\n");
  } else {
    print CMU::WebInt::smallRight("[<b><a href=$url?op=cable_view&id=$id>Refresh</a></b>]\n" . 
      "[<b><a href=$url?op=prot_s3&table=cable&tidType=1&tid=$id>View/Update Protections</a></b>]\n");
  }
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=cable_upd>
<input type=hidden name=version value=\"".$sdata[$cable_pos{'cable.version'}]."\">";
  # type, destination, rack
  print "<tr>".CMU::WebInt::printPossError(defined $errors{type}, $cable_p{'cable.type'}).
    CMU::WebInt::printPossError(defined $errors{destination}, $cable_p{'cable.destination'}).
      CMU::WebInt::printPossError(defined $errors{rack}, $cable_p{'cable.rack'})."</tr>";
  print "<tr><td>".$q->popup_menu(-name => 'type', -accesskey => 't',
				  -default => $sdata[$cable_pos{'cable.type'}],
				  -values => \@CMU::Netdb::structure::cable_type).
				    "</td>";
  print "<td>".$q->popup_menu(-name => 'destination',  -accesskey => 'd',
			      -default => $sdata[$cable_pos{'cable.destination'}],
			      -values => ['OUTLET', 'CLOSET'])."</td>\n";

  print "<td>".$q->popup_menu(-name => 'rack', -accesskey => 'r',
			      -default => $sdata[$cable_pos{'cable.rack'}],
			      -values => \@CMU::Netdb::structure::cable_rack)."</td></tr>\n";
  my $tick = 0; # controls whether we are left or right
  my $round = 0; # controls row 1 vs row 2
  foreach (qw/prefix from_building from_wing from_floor 
	   from_closet from_rack from_panel from_x from_y/) {
    print $q->hidden(-name => $_,
		     -value => $sdata[$cable_pos{'cable.'.$_}]) . "\n";
  }
  my @fields = qw/to_building to_wing to_floor to_closet to_rack
    to_panel to_x to_y to_floor_plan_x to_floor_plan_y to_outlet_number 
      to_room_number/;
  my $i = 0;
  while(1) {
    print "<tr>" if ($tick == 0);
    if ($round == 0) {
      if (!defined $fields[$i]) {
	last if ($tick == 0);
	if ($tick == 2) {
	  print "</tr>\n";
	  $round++;
	  $tick = 0;
	  $i = $i - 2;
	  next;
	}
      }
      print CMU::WebInt::printPossError(defined $errors{$fields[$i]}, $cable_p{'cable.'.$fields[$i]});
      if ($tick == 2) {
	print "</tr>\n";
	$tick = 0;
	$round++;
	$i += -2;
      }else{
	$i++;
	$tick++;
      }
    }else{
      print "<tr>" if ($tick == 0);
      if (!defined $fields[$i]) {
	print "</tr>\n";
	last;
      }
      print "<td>".$q->textfield(-name => $fields[$i], -accesskey => 't',
			  -value => $sdata[$cable_pos{'cable.'.$fields[$i]}])."</td>";
      $i++;
      if ($tick == 2) {
	print "</tr>\n";
	$round = 0;
	$tick = 0;
      }else{
	$tick++;
      }
    }
  }

  print "<tr><td colspan=2>".($wl >= 1 ? $q->submit(-value=>'Update') : '')."</td></tr>\n";
  
  print "</table></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub cables_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'cable', $id);

  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Admin", $errors);
    &CMU::WebInt::title("Update Cable");
    CMU::WebInt::accessDenied('cable', 'WRITE', $id, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  my @fields = qw/rack destination type 
    prefix from_building from_wing from_floor
      from_closet from_rack from_panel from_x from_y to_building to_wing
      to_floor to_closet to_rack to_panel to_x to_y to_floor_plan_x
	to_floor_plan_y to_outlet_number to_room_number/;
  map { $fields{$_} = CMU::WebInt::gParam($q, $_); } @fields;

  my ($res, $errfields) = CMU::Netdb::modify_cable($dbh, $user, $id, $version, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Updated cable.";
    $dbh->disconnect(); 
    &CMU::WebInt::cables_view($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{code} = $res;
    $nerrors{type} = 'ERR';
    $nerrors{fields} = join(',', @$errfields);
    $nerrors{loc} = 'cables_update';
    $dbh->disconnect();
    &CMU::WebInt::cables_view($q, \%nerrors);
  }
}

sub cables_add_s0 {
  my ($q, $errors) = @_;
  my ($dbh,  $id,  $url, $res,  %errors);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  CMU::WebInt::setHelpFile('cable_add');
  %errors = %$errors if (ref  $errors);

  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cables", $errors);
  &CMU::WebInt::title('Add a Cable');
  
  $url  =  $ENV{SCRIPT_NAME};
  my $al = CMU::Netdb::get_add_level($dbh, $user,  'cable', 0);

  if ($al < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $al, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  print "<hr>\n";
  print CMU::WebInt::errorDialog($url, $errors);

  my @fields = qw/prefix from_building from_wing from_floor
      from_closet from_rack from_panel from_x from_y to_building to_wing
	to_floor to_closet to_rack to_panel to_x to_y to_floor_plan_x
	  to_floor_plan_y to_outlet_number to_room_number/;

  print "<table border=0><form method=get>\n";
  print "<tr>".CMU::WebInt::printPossError(defined $errors{type}, $cable_p{'cable.type'}).
    CMU::WebInt::printPossError(defined $errors{destination}, $cable_p{'cable.destination'})."</tr>";  
  print "<input type=hidden name=op value=cable_add_s1>\n";
  print "<tr><td>".$q->popup_menu(-name => 'type',
				  -values => \@CMU::Netdb::structure::cable_type) 
    . "</td>";
  print "<td>".$q->popup_menu(-name => 'destination',
			      -values => ['OUTLET', 'CLOSET'])."</td>\n";
  print "<tr>".CMU::WebInt::printPossError(defined $errors{rack}, $cable_p{'cable.rack'}).
    "</tr>";
  print "<tr><td>".$q->popup_menu(-name => 'rack',
			      -values => \@CMU::Netdb::structure::cable_rack)."</td></tr>\n";
  my $tick = 0; # controls whether we are left or right
  my $round = 0; # controls row 1 vs row 2
  my $i = 0;
  while(1) {
    print "<tr>" if ($tick == 0);
    if ($round == 0) {
      if (!defined $fields[$i]) {
	last if ($tick == 0);
	if ($tick == 1) {
	  print "</tr>\n";
	  $round++;
	  $tick = 0;
	  $i = $i - 1;
	  next;
	}
      }
      print CMU::WebInt::printPossError(defined $errors{$fields[$i]}, $cable_p{'cable.'.$fields[$i]});
      if ($tick == 1) {
	print "</tr>\n";
	$tick = 0;
	$round++;
	$i += -1;
      }else{
	$i++;
	$tick++;
      }
    }else{
      print "<tr>" if ($tick == 0);
      if (!defined $fields[$i]) {
	print "</tr>\n";
	last;
      }
      print "<td>".$q->textfield(-name => $fields[$i]) ."</td>";
      $i++;
      if ($tick == 1) {
	print "</tr>\n";
	$round = 0;
	$tick = 0;
      }else{
	$tick++;
      }
    }
  }

  print "<tr><td colspan=2>".$q->submit(-value=>'Add')."</td></tr>\n";
  
  print "</table></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;

}


sub cables_add_s1 {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);

  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Admin", $errors);
    &CMU::WebInt::title("Add Cable");
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  my @fields = qw/rack destination type 
    prefix from_building from_wing from_floor
      from_closet from_rack from_panel from_x from_y to_building to_wing
      to_floor to_closet to_rack to_panel to_x to_y to_floor_plan_x
	to_floor_plan_y to_outlet_number to_room_number/;
  map { $fields{$_} = CMU::WebInt::gParam($q, $_); } @fields;

  my ($res, $errfields) = CMU::Netdb::add_cable($dbh, $user, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Added cable.";
    $dbh->disconnect(); 
    &CMU::WebInt::cables_main($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{code} = $res;
    $nerrors{type} = 'ERR';
    $nerrors{fields} = join(',', @$errfields);
    $nerrors{loc} = 'cables_add_s0';
    $dbh->disconnect();
    &cables_add_s0($q, \%nerrors);
  }
}

sub cables_delete {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, %nerrors) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('cables_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Admin", $errors);
  print &CMU::WebInt::subHeading("Delete Cable", CMU::WebInt::pageHelpLink(''));
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'cable', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic cable information
  my $sref = CMU::Netdb::list_cables($dbh, $user, "cable.id='$id'");
  if (!ref $sref || !defined $sref->[1]) {
    $nerrors{'msg'} = "Cable not found.";
    $dbh->disconnect;
    &CMU::WebInt::cables_main($q, \%nerrors);
    return;
  }

  my @sdata = @{$sref->[1]};
  print "<br>Please confirm that you wish to delete the following Cable.\n";
  
  my @print_fields = ('cable.label_from', 
		      'cable.label_to');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::cable_printable{$f}."</th>
<td>";
    print $sdata[$cable_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=cable_del_conf&id=$id&version=$version")."\">
Yes, delete this cable";
  print "<br><a href=\"$url?op=cable_list\">No, return to the cables list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub cables_confirm_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res, $ref, %errors, $msg) = @_;
  
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  if ($id eq '') {
    CMU::WebInt::cables_main($q, {'msg' => 'Cable ID not specified!',
		   'code' => $CMU::Netdb::errcodes{ERROR},
		   'loc' => 'cables_del_conf',
		   'fields' => 'id',
		   'type' => 'ERR'});
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'cable', $id);

  if ($ul < 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Admin", {});
    &CMU::WebInt::title('Delete Cable');
    CMU::WebInt::accessDenied('cable', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  ($res, $ref) = CMU::Netdb::delete_cable($dbh, $user, $id, $version);

  if ($res == 1) {
    CMU::WebInt::cables_main($q, {'msg' => "The cable was deleted."});
  }else{
    $msg = 'There was an error while deleting the cable: '.$errmeanings{$res};
    $msg .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." ) "
      if ($res eq $CMU::Netdb::errcodes{EDB});
    
    $dbh->disconnect();
    my %errors = ('msg' => $msg,
		  'loc' => 'cable_del_conf',
		  'code' => $res,
		  'fields' => join(',', @$ref),
		  'type' => 'ERR');
    CMU::WebInt::cables_main($q, \%errors);
  }
}
