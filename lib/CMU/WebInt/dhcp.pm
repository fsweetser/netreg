#   -*- perl -*-
#
# CMU::WebInt::dhcp
# This module provides the dns/dhcp screens.
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

package CMU::WebInt::dhcp;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings %dhcp_o_pos %dhcp_o_t_pos
	    $dhcp_o_pos_s $dhcp_o_t_pos_s
	    %dhcp_o_c_pos);
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

@EXPORT = qw(dhcp_o_t_list dhcp_o_t_view dhcp_o_t_update 
	     dhcp_o_t_delete dhcp_o_t_confirm dhcp_o_t_add dhcp_o_t_add_form);

%errmeanings = %CMU::Netdb::errors::errmeanings;

%dhcp_o_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::dhcp_option_fields)};
$dhcp_o_pos_s = $#CMU::Netdb::structure::dhcp_option_fields;
%dhcp_o_t_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::dhcp_option_type_fields)};
$dhcp_o_t_pos_s = $#CMU::Netdb::structure::dhcp_option_type_fields;
{
  my @a = @CMU::Netdb::structure::dhcp_option_fields;
  push(@a, @CMU::Netdb::structure::dhcp_option_type_fields);
%dhcp_o_c_pos = %{CMU::Netdb::makemap(\@a)};
}

# ############################################################################
# DHCP Option Types
# ############################################################################

sub dhcp_o_t_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dhcp_o_t_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DHCP Option Types", $errors);
  &CMU::WebInt::title("List of DHCP Option Types");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dhcp_option_type', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dhcp_option_type', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=dhcp_o_t_add_form>Add Option Type</a></b>]
[<b><a href=$url?op=mach_dns_gdhcp_list>List Global DHCP Options</a></b>] ".
CMU::WebInt::pageHelpLink(''));

  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'dhcp_option_type.name' if ($sort eq '');
  
  $res = dhcp_o_t_print_type($user, $dbh, $q,  
			     " TRUE ".CMU::Netdb::verify_orderby($sort), '',
			     $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'dhcp_o_t_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# dhcp_o_t_print_type
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the WHERE clause
#   - parameters to count WHERE
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
#   - lmach
sub dhcp_o_t_print_type {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'dhcp_option_type', $cwhere);
  
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
  $ruRef = CMU::Netdb::list_dhcp_option_types
    ($dbh, $user, " $where ".CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_dhcp_option_types: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint
    ($ENV{SCRIPT_NAME}, $ruRef, 
     ['dhcp_option_type.name', 'dhcp_option_type.number',
      'dhcp_option_type.builtin',
      'dhcp_option_type.format'], [\&dhcp_o_t_cb_del], '',
     'dhcp_o_t_list', 'op=dhcp_o_t_view&id=',
     \%dhcp_o_t_pos, 
     \%CMU::Netdb::structure::dhcp_option_printable,
     'dhcp_option_type.name', 'dhcp_option_type.id', 'sort',
     ['dhcp_option_type.name', 'dhcp_option_type.number',
      'dhcp_option_type.format']);
  return 1;
}

sub dhcp_o_t_cb_del {
  my ($url, $row, $edata) = @_;
  return "Delete" if (!ref $row);
  my @rrow = @$row;
  return "<a href=\"".CMU::WebInt::encURL("$url?op=dhcp_o_t_delete&id=".$rrow[$dhcp_o_t_pos{'dhcp_option_type.id'}]."&version=".$rrow[$dhcp_o_t_pos{'dhcp_option_type.version'}])."\">Delete</a>";
}

sub dhcp_o_t_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $id = CMU::WebInt::gParam($q, 'id');
  $$errors{msg} = "DHCP Option Type ID not specified!" if ($id eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dhcp_o_t_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DHCP Option Types", $errors);
  &CMU::WebInt::title("DHCP Option Type Information");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dhcp_option_type', $id);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'dhcp_option_type', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dhcp_option_type', 'READ', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # dynamic info, expire static, expire dynamic
  my $bref = CMU::Netdb::list_dhcp_option_types($dbh, $user, "dhcp_option_type.id='$id'");
  my @sdata = @{$bref->[1]};
  
  print CMU::WebInt::subHeading("Information for: ".$sdata[$dhcp_o_t_pos{'dhcp_option_type.name'}], CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=$url?op=dhcp_o_t_view&id=$id>Refresh</a></b>]
 [<b><a href=\"$url?op=prot_s3&table=dhcp_option_type&tidType=1&tid=$id\">View/Update Protections</a></b>]
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=dhcp_o_t_delete&id=$id&version=".
   $sdata[$dhcp_o_t_pos{'dhcp_option_type.version'}])."\">Delete DHCP Option Type</a></b>]\n");

  # name, number
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=dhcp_o_t_update>
<input type=hidden name=version value=\"".$sdata[$dhcp_o_t_pos{'dhcp_option_type.version'}]."\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.name'}, 1, 'dhcp_option_type.name').
  CMU::WebInt::printPossError(defined $errors->{'number'}, $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.number'}, 1, 'dhcp_option_type.number').
    "</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('dhcp_option_type.name', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name => 'name', -value => $sdata[$dhcp_o_t_pos{'dhcp_option_type.name'}]).
    "</td><td>".CMU::WebInt::printVerbose('dhcp_option_type.number', $verbose).
      $q->textfield(-name => 'number', 
		-value => $sdata[$dhcp_o_t_pos{'dhcp_option_type.number'}])."</td></tr>\n";
  }else{
    print $sdata[$dhcp_o_t_pos{'dhcp_option_type.name'}]."</td><td>".
      CMU::WebInt::printVerbose('dhcp_option_type.number', $verbose).
      $sdata[$dhcp_o_t_pos{'dhcp_option_type.number'}]."</td></tr>\n";
  }

  # format
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'format'}, $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.format'}, 2, 'dhcp_option_type.format')."</tr>\n";

  print "<tr><td colspan=2>".
    CMU::WebInt::printVerbose('dhcp_option_type.format', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name => 'format',
			-value => $sdata[$dhcp_o_t_pos{'dhcp_option_type.format'}],
			-size => 50);
    print "</td></tr>\n";
  }else{
    print $sdata[$dhcp_o_t_pos{'dhcp_option_type.format'}]."</td></tr>\n";
  }

  # builtin
  print "<tr>".
    CMU::WebInt::printPossError(defined $errors->{'builtin'},
				$CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.builtin'}, 1, 'dhcp_option_type.builtin')."</tr>\n";
  
  print "<tr><td>".
    CMU::WebInt::printVerbose('dhcp_option_type.builtin', $verbose);
  if ($wl >= 1) {
    print $q->popup_menu(-name => 'builtin',
			 -values => ['Y', 'N'],
			 -default => $sdata[$dhcp_o_t_pos{'dhcp_option_type.builtin'}]);
    print "</td></tr>\n";
  }else{
    print $sdata[$dhcp_o_t_pos{'dhcp_option_type.builtin'}]."</td></tr>\n";
  }

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n" 
    if ($wl >= 1);
      
  print "</table></form>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub dhcp_o_t_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);


  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'dhcp_option_type', $id);

  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "DHCP Option Types", $errors);
    &CMU::WebInt::title("Update DHCP Option Type");
    CMU::WebInt::accessDenied('dhcp_option_type', 'WRITE', $id, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'number' => CMU::WebInt::gParam($q, 'number'),
	     'format' => CMU::WebInt::gParam($q, 'format'),
	     'builtin' => CMU::WebInt::gParam($q, 'builtin'));

  my ($res, $errfields) = CMU::Netdb::modify_dhcp_option_type($dbh, $user, $id, $version, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Updated DHCP Option Type.";
    $dbh->disconnect(); 
    &CMU::WebInt::dhcp_o_t_view($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{code} = $res;
    $nerrors{type} = 'ERR';
    $nerrors{fields} = join(',', @$errfields);
    $nerrors{loc} = 'dhcp_o_t_update';
    $dbh->disconnect();
    &CMU::WebInt::dhcp_o_t_view($q, \%nerrors);
  }
}

sub dhcp_o_t_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dhcp_o_t_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DHCP Option Types", {});
  &CMU::WebInt::title('Delete DHCP Option Types');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'dhcp_option_type', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dhcp_option_type', 'WRITE', $id, 1, $ul,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic dhcp_option_type infromation
  my $sref = CMU::Netdb::list_dhcp_option_types($dbh, $user, "dhcp_option_type.id='$id'");
  if (!defined $sref->[1]) {
    print "DHCP Option Type not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following DHCP Option Type.\n";
  
  my @print_fields = ('dhcp_option_type.name', 'dhcp_option_type.number');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::dhcp_option_printable{$f}."</th>
<td>";
    print $sdata[$dhcp_o_t_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=dhcp_o_t_confirm&id=$id&version=$version")."\">
Yes, delete this DHCP Option Type";
  print "<br><a href=\"$url?op=dhcp_o_t_list\">No, return to the DHCP Option Type list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub dhcp_o_t_confirm {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'dhcp_option_type', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete dhcp_option_type $id\n";
    $dbh->disconnect();
    CMU::WebInt::dhcp_o_t_view($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_dhcp_option_type($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    CMU::WebInt::dhcp_o_t_list($q, {'msg' => "The DHCP Option Type was deleted."});
  }else{
    $errors{msg} = "Error while deleting DHCP Option Type: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{code} = $res;
    $errors{type} = 'ERR';
    $errors{fields} = join(',', @$fields);
    $errors{loc} = 'dhcp_o_t_delete';
    CMU::WebInt::dhcp_o_t_view($q, \%errors);
  }

}

sub dhcp_o_t_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dhcp_option_type', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('dhcp_o_t_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DHCP Option Types", $errors);
  &CMU::WebInt::title("Add a DHCP Option Type");
  
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('dhcp_option_type', 'ADD', 0, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose eq '0');

  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  # name, number
  print "
<form method=get>
<input type=hidden name=op value=dhcp_o_t_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.name'}, 1, 'dhcp_option_type.name').
  CMU::WebInt::printPossError(defined $errors{number}, $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.number'}, 1, 'dhcp_option_type.number')."</tr>
<tr><td>".CMU::WebInt::printVerbose('dhcp_option_type.name', $verbose).
  $q->textfield(-name => 'name')."</td><td>".
    CMU::WebInt::printVerbose('dhcp_option_type.number', $verbose).
  $q->textfield(-name => 'number')."</td></tr>\n";

  # format
  print "<tr>".CMU::WebInt::printPossError(defined $errors{format}, $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.format'}, 2, 'dhcp_option_type.format').
    "</td><tr><td colspan=2>".CMU::WebInt::printVerbose('dhcp_option_type.format', $verbose).
      $q->textfield(-name => 'format',
		    -size => 50)."</td></tr>\n";

  # builtin
  print "<tr>".
    CMU::WebInt::printPossError
      (defined $errors{builtin}, 
       $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.builtin'}, 
       1, 'dhcp_option_type.builtin');
  print "</td><tr><td colspan=2>".
    CMU::WebInt::printVerbose('dhcp_option_type.builtin', $verbose).
      $q->popup_menu(-name => 'builtin',
		     -values => ['Y', 'N'],
		     -default => 'N')."</td></tr>\n";

  print "</table>\n";
  print "<input type=submit value=\"Add DHCP Option Type\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub dhcp_o_t_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  foreach (qw/name number format builtin/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }

  my ($res, $errfields) = CMU::Netdb::add_dhcp_option_type($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added DHCP Option Type $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect(); 
    CMU::WebInt::dhcp_o_t_view($q, \%nerrors);
  }else{
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{code} = $res;
      $nerrors{type} = 'ERR';
      $nerrors{fields} = join(',', @$errfields);
      $nerrors{loc} = 'dhcp_o_t_add';
    }
    $dbh->disconnect();
    CMU::WebInt::dhcp_o_t_add_form($q, \%nerrors);
  }
}

1;
