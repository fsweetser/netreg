#   -*- perl -*-
#
# CMU::WebInt::dns
# This module provides the dns screens.
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

package CMU::WebInt::dns;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK $debug %errmeanings %dns_r_pos %dns_r_t_pos
	     $dns_r_pos_s $dns_r_t_pos_s %errcodes);
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

@EXPORT = qw(dns_r_t_list dns_r_t_view dns_r_t_update 
	     dns_r_t_delete dns_r_t_confirm dns_r_t_add dns_r_t_add_form);

$debug = 0;

%errmeanings = %CMU::Netdb::errors::errmeanings;
%errcodes = %CMU::Netdb::errors::errcodes;
%dns_r_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::dns_resource_fields)};
$dns_r_pos_s = $#CMU::Netdb::structure::dns_resource_fields;
%dns_r_t_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::dns_resource_type_fields)};
$dns_r_t_pos_s = $#CMU::Netdb::structure::dns_resource_type_fields;

sub dns_main {
  my ($q, $errors) = @_;
  my ($dbh, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dns_main');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Admin", $errors);
  &CMU::WebInt::title("DNS Administration");

  $url = $ENV{SCRIPT_NAME};

  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::subHeading("DNS Resource Types", CMU::WebInt::pageHelpLink(''));

  print CMU::WebInt::smallRight("[<b><a href=$url?op=dns_r_t_add_form>Add Resource Type</a></b>] \n");

  my $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'dns_resource_type.name' if ($sort eq '');
  
  my $res = dns_r_t_print_type($user, $dbh, $q,  
			       " 1 ".CMU::Netdb::verify_orderby($sort), '',
			       $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'dns_r_t_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print &CMU::WebInt::stdftr($q);
  
}

# ############################################################################
# DNS Resource Types
# ############################################################################

sub dns_r_t_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dns_r_t_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources Types", $errors);
  &CMU::WebInt::title("List of DNS Resources Types");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dns_resource_type', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dns_resource_type', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=dns_r_t_add_form>Add Resource Type</a></b>] ".CMU::WebInt::pageHelpLink(''));

  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'dns_resource_type.name' if ($sort eq '');
  
  $res = dns_r_t_print_type($user, $dbh, $q,  
			     " 1 ".CMU::Netdb::verify_orderby($sort), '',
			     $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'dns_r_t_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# dns_r_t_print_type
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
sub dns_r_t_print_type {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'dns_resource_type', $cwhere);
#  $ctRow = [255];
  
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
  $ruRef = CMU::Netdb::list_dns_resource_types
    ($dbh, $user, " $where ".CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with CMU::Netdb::list_dns_resource_types: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['dns_resource_type.name', 
		 'dns_resource_type.format'], [\&dns_r_t_cb_del], '',
		 'dns_r_t_list', 'op=dns_r_t_view&id=',
		 \%dns_r_t_pos, 
		 \%CMU::Netdb::structure::dns_resource_type_printable,
		 'dns_resource_type.name', 'dns_resource_type.id', 'sort',
			     ['dns_resource_type.name', 'dns_resource_type.format', '']);
  return 1;
}

sub dns_r_t_cb_del {
  my ($url, $row, $edata) = @_;
  return "Delete" if (!ref $row);
  my @rrow = @$row;
  return "<a href=\"".CMU::WebInt::encURL("$url?op=dns_r_t_delete&id=".$rrow[$dns_r_t_pos{'dns_resource_type.id'}]."&version=".$rrow[$dns_r_t_pos{'dns_resource_type.version'}])."\">Delete</a>";
}

sub dns_r_t_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $id = CMU::WebInt::gParam($q, 'id');
  $$errors{msg} = "DNS Resource Type ID not specified!" if ($id eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dns_r_t_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources Types", $errors);
  &CMU::WebInt::title("DNS Resource Type Information");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dns_resource_type', $id);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'dns_resource_type', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dns_resource_type', 'READ', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # dynamic info, expire static, expire dynamic
  my $bref = CMU::Netdb::list_dns_resource_types($dbh, $user, "dns_resource_type.id='$id'");
  my @sdata = @{$bref->[1]};
  
  print CMU::WebInt::subHeading("Information for: ".$sdata[$dns_r_t_pos{'dns_resource_type.name'}], CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=$url?op=dns_r_t_view&id=$id>Refresh</a></b>]
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=dns_r_t_delete&id=$id&version=".
   $sdata[$dns_r_t_pos{'dns_resource_type.version'}])."\">Delete DNS Resource Type</a></b>]\n");

  # name, format
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=dns_r_t_update>
<input type=hidden name=version value=\"".$sdata[$dns_r_t_pos{'dns_resource_type.version'}]."\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $CMU::Netdb::structure::dns_resource_type_printable{'dns_resource_type.name'}, 1, 'dns_resource_type.name').
  CMU::WebInt::printPossError(defined $errors->{'format'}, $CMU::Netdb::structure::dns_resource_type_printable{'dns_resource_type.format'}, 1, 'dns_resource_type.format').
    "</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('dns_resource_type.name', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name => 'name', -value => $sdata[$dns_r_t_pos{'dns_resource_type.name'}]).
    "</td><td>".CMU::WebInt::printVerbose('dns_resource_type.format', $verbose).
      $q->popup_menu(-name => 'format',
		     -values => \@CMU::Netdb::structure::dns_type_formats,
		    -default => $sdata[$dns_r_t_pos{'dns_resource_type.format'}])."</td></tr>\n";
  }else{
    print $sdata[$dns_r_t_pos{'dns_resource_type.name'}]."</td><td>".
      CMU::WebInt::printVerbose('dns_resource_type.format', $verbose).
      $sdata[$dns_r_t_pos{'dns_resource_type.format'}]."</td></tr>\n";
  }

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n" 
    if ($wl >= 1);
      
  print "</table></form>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub dns_r_t_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'dns_resource_type', $id);

  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources Types", $errors);
    &CMU::WebInt::title("Update DNS Resource Type");
    CMU::WebInt::accessDenied('dns_resource_type', 'WRITE', $id, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'format' => CMU::WebInt::gParam($q, 'format'));

  my ($res, $errfields) = CMU::Netdb::modify_dns_resource_type($dbh, $user, $id, $version, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Updated DNS Resource Type.";
    $dbh->disconnect(); 
    &CMU::WebInt::dns_r_t_view($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{code} = $res;
    $nerrors{type} = 'ERR';
    $nerrors{fields} = join(',', @$errfields);
    $nerrors{loc} = 'dns_r_t_update';
    $dbh->disconnect();
    &CMU::WebInt::dns_r_t_view($q, \%nerrors);
  }
}

sub dns_r_t_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dns_r_t_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources Types", {});
  &CMU::WebInt::title('Delete DNS Resources Types');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'dns_resource_type', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dns_resource_type', 'WRITE', $id, 1, $ul,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic dns_resource_type infromation
  my $sref = CMU::Netdb::list_dns_resource_types($dbh, $user, "dns_resource_type.id='$id'");
  if (!defined $sref->[1]) {
    print "DNS Resource Type not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following DNS Resource Type.\n";
  
  my @print_fields = ('dns_resource_type.name', 'dns_resource_type.format');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::dns_resource_type_printable{$f}."</th>
<td>";
    print $sdata[$dns_r_t_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
 print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=dns_r_t_confirm&id=$id&version=$version")."\">
Yes, delete this DNS Resource Type";
  print "<br><a href=\"$url?op=dns_r_t_list\">No, return to the DNS Resource Type list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub dns_r_t_confirm {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'dns_resource_type', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete dns_resource_type $id\n";
    $dbh->disconnect();
    CMU::WebInt::subnets_view_share($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_dns_resource_type($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    CMU::WebInt::dns_r_t_list($q, {'msg' => "The DNS Resource Type was deleted."});
  }else{
    $errors{msg} = "Error while deleting DNS Resource Type: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{code} = $res;
    $errors{type} = 'ERR';
    $errors{fields} = join(',', @$fields);
    $errors{loc} = 'dns_r_t_delete';
    CMU::WebInt::dns_r_t_view($q, \%errors);
  }

}

sub dns_r_t_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dns_resource_type', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('dns_r_t_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources Types", $errors);
  &CMU::WebInt::title("Add a DNS Resource Type");

  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('dns_resource_type', 'ADD', 0, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  # name, format
  print "
<form method=get>
<input type=hidden name=op value=dns_r_t_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $CMU::Netdb::structure::dns_resource_type_printable{'dns_resource_type.name'}, 1, 'dns_resource_type.name').
  CMU::WebInt::printPossError(defined $errors{format}, $CMU::Netdb::structure::dns_resource_type_printable{'dns_resource_type.format'}, 1, 'dns_resource_type.format')."</tr>
<tr><td>".CMU::WebInt::printVerbose('dns_resource_type.name', $verbose).
  $q->textfield(-name => 'name')."</td><td>".
    CMU::WebInt::printVerbose('dns_resource_type.format', $verbose).
      $q->popup_menu(-name => 'format',
		     -values => \@CMU::Netdb::structure::dns_type_formats)."</td></tr>\n";

  print "</table>\n";
  print "<input type=submit value=\"Add DNS Resource Type\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub dns_r_t_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'format' => CMU::WebInt::gParam($q, 'format'));

  my ($res, $errfields) = CMU::Netdb::add_dns_resource_type($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added DNS Resource Type $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect(); 
    CMU::WebInt::dns_r_t_view($q, \%nerrors);
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
      $nerrors{loc} = 'dns_r_t_add';
    }
    $dbh->disconnect();
    CMU::WebInt::dns_r_t_add_form($q, \%nerrors);
  }
}

sub dns_upd_serial {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dns_resource_type', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Serials", $errors);
  &CMU::WebInt::title("Update DNS Serials");
  
  my $res = CMU::Netdb::update_zone_serials($dbh, $user);
  print "Result: $res\n";
  $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);
}

sub dns_r_search {
  my ($q, $errors) = @_;
  my ($dbh, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dns_search');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources", $errors);
  &CMU::WebInt::title("Search DNS Resources");

  my $MachLevel = CMU::Netdb::get_read_level($dbh, $user, 'machine', 0);

  $url = $ENV{SCRIPT_NAME};
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # level 0 can search by: all


  CMU::WebInt::printVerbose('dns_resource.search_general', 1);

  print &CMU::WebInt::subHeading("Basic Search Parameters", 
				 CMU::WebInt::pageHelpLink(''));

  print "<br>You may only search resources which are owned by machines ".
    "administered by you.<br>The percent sign ('\%') can be used as a ".
      "wildcard (match anything) operator.<br> ";
  
  print "<form method=get>\n".
    "<input type=hidden name=op value=dns_r_s_exec>".
      "<table border=0>";

  # Type
  {
    my @ResType = CMU::Netdb::unique
      (sort { $a cmp $b } (@CMU::Netdb::structure::dns_resource_zone_types,
			   @CMU::Netdb::structure::dns_resource_mach_types,
			   @CMU::Netdb::structure::dns_resource_service_types)
       );
    unshift(@ResType, '--select--');
    print "<tr>".CMU::WebInt::printPossError
      (0, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.type'},
       1, 'type')."</td><td>";
    
    print $q->popup_menu(-name => 'type',
			 -values => \@ResType);
    print "</td></tr>\n";
  }
  
  # Name/RName
  print "<tr>".CMU::WebInt::printPossError
    (0, "Name/RName", 1, 'name')."</td><td>\n".
      $q->textfield(-name => 'name', -size => 25)."</td></tr>\n\n";

  # Metric
  print "<tr>".CMU::WebInt::printPossError
    (0, "Metric", 1, 'rmetric0')."</td><td>\n".
      $q->textfield(-name => 'metric', -size => 8)."</td></tr>\n\n";

  # Port
  print "<tr>".CMU::WebInt::printPossError
    (0, "Port",
     1, 'port')."</td><td>\n".
       $q->textfield(-name => 'port', -size => 8)."</td></tr>\n\n";
  
  # Text
  print "<tr>".CMU::WebInt::printPossError
    (0, "Text", 1, 'text0')."</td><td>\n".
      $q->textfield(-name => 'text', -size => 25)."</td></tr>\n\n";
  
  print "</table>\n";

  print "<br><input type=submit value=\"Search\"></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub dns_r_s_exec {
  my ($q, $errors) = @_;
  my ($dbh, $url, $query, @q);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('dns_r_s_exec');
  $url = $ENV{SCRIPT_NAME};
  my @rurl;

  # Type
  if (CMU::WebInt::gParam($q, 'type') ne '' &&
      CMU::WebInt::gParam($q, 'type') ne '--select--') {
    my $t = CMU::WebInt::gParam($q, 'type');
    if ($t =~ /\%/) {
      push(@q, 'type like '.$dbh->quote($t));
    }else{
      push(@q, 'type like '.$dbh->quote('%'.$t.'%'));
    }
  }

  # Name/RName
  if (CMU::WebInt::gParam($q, 'name') ne '') {
    my $n = CMU::WebInt::gParam($q, 'name');
    if ($n =~ /\%/) {
      push(@q, ' (dns_resource.name like '.$dbh->quote($n).' OR rname like '.$dbh->quote($n).') ');
    }else{
      push(@q, ' (dns_resource.name like '.$dbh->quote('%'.$n.'%').' OR rname like '
	   .$dbh->quote('%'.$n.'%').') ');
    }
  }

  # Metric
  if (CMU::WebInt::gParam($q, 'metric') ne '') {
    my $n = CMU::WebInt::gParam($q, 'metric');
    if ($n =~ /\%/) {
      push(@q, ' (rmetric0 like '.$dbh->quote($n).' OR rmetric1 like '.$dbh->quote($n).') ');
    }else{
      push(@q, ' (rmetric0 like '.$dbh->quote('%'.$n.'%').' OR rmetric1 like '.$dbh->quote('%'.$n.'%').') ');
    }
  }

  # Port
  if (CMU::WebInt::gParam($q, 'port') ne '') {
    my $n = CMU::WebInt::gParam($q, 'port');
    if ($n =~ /\%/) {
      push(@q, ' port like '.$dbh->quote($n).'');
    }else{
      push(@q, ' port like '.$dbh->quote('%'.$n.'%'));
    }
  }
  
  # Text
  if (CMU::WebInt::gParam($q, 'text') ne '') {
    my $n = CMU::WebInt::gParam($q, 'text');
    if ($n =~ /\%/) {
      push(@q, ' (text0 like '.$dbh->quote($n).' OR text1 like '.$dbh->quote($n).') ');
    }else{
      push(@q, ' (text0 like '.$dbh->quote('%'.$n.'%').' OR text1 like '.$dbh->quote('%'.$n.'%').') ');
    }
  }

  # Build up the refresh URL
  @rurl = ();
  foreach (qw/type name metric port text/) {
    push(@rurl, "$_=".CMU::WebInt::gParam($q, $_)) 
      if (CMU::WebInt::gParam($q, $_) ne '' &&
	  CMU::WebInt::gParam($q, $_) ne '--select--');
  }
  my $gwhere = join(' AND ', @q);
  $gwhere = '1' if ($gwhere eq '');

  my $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'dns_resource.name' if ($sort eq '');

  push(@rurl, "sort=$sort");
  my ($res, $code, $msg) = dns_r_print_r_search
    ($user, $dbh, $q, $gwhere.CMU::Netdb::verify_orderby($sort),
     $url, join('&', @rurl), 'start', 'dns_r_s_exec');
  
  if ($res != 1) {
    my %errors = ('type' => 'ERR',
		  'code' => $code,
		  'msg' => $msg,
		  'loc' => 'dns_r_s_exec',
		  'fields' => '');
    CMU::WebInt::dns::dns_r_search($q, \%errors);
    return;
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


# dns_r_print_r_search
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the list WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key for start
#   - the key for the list

sub dns_r_print_r_search {
  my ($user, $dbh, $q, $where, $url, $oData, 
      $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : 
    CMU::WebInt::gParam($q, $skey);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'MACHINES_PER_PAGE');

  my $listUser = 'netreg';

  $ruRef = CMU::Netdb::primitives::list
    ($dbh, $listUser, 'dns_resource',
     \@CMU::Netdb::structure::dns_resource_fields,
     "$where ".
     CMU::Netdb::verify_limit($start, $defitems));

  return (0, $ruRef, "ERROR with list (dns resources): ".$errmeanings{$ruRef}) 
    if (!ref $ruRef);

  unshift @$ruRef, \@CMU::Netdb::structure::dns_resource_fields;

  if ($#$ruRef == 0) {
    return(0,
	   $CMU::Netdb::errors::errcodes{ENOTFOUND},
	   "No results found.");
  }

  $lmach .= "&$oData" if ($oData ne '');
  $ctRow = ($#{$ruRef} < $defitems ? 0 : $start+$defitems+1);

  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources", {});
  &CMU::WebInt::title("Search DNS Resources");

  $url = $ENV{SCRIPT_NAME};
  print "<hr>";

  print &CMU::WebInt::pager_Top($start, $ctRow, $defitems,
				0,
				$url, "op=".$lmach, $skey);
  
  $lmach =~ s/\&sort=[^\&]+//;
  $lmach =~ s/\&\&/\&/g;
  $lmach =~ s/\&$//;

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of
  # functions calling this function.
  CMU::WebInt::generic_tprint
    ($url, $ruRef,
     ['dns_resource.type'],
     [\&CMU::WebInt::dns::dns_cb_print_specific,
      \&CMU::WebInt::dns::dns_cb_r_owner],
     '', $lmach, '', \%dns_r_pos,
     \%CMU::Netdb::structure::dns_resource_printable,
     '', '', 'sort',
     ['dns_resource.type']
    );

  return 1;
}

sub dns_cb_print_specific {
  my ($url, $row, $dbh) = @_;

  return "Contents" if (!ref $row);
  my $type = $row->[$dns_r_pos{'dns_resource.type'}];
  
  my $Ret;
  my ($n, $rn, $m0, $m1, $p, $t0, $t1) =
    ($row->[$dns_r_pos{'dns_resource.name'}],
     $row->[$dns_r_pos{'dns_resource.rname'}],
     $row->[$dns_r_pos{'dns_resource.rmetric0'}],
     $row->[$dns_r_pos{'dns_resource.rmetric1'}],
     $row->[$dns_r_pos{'dns_resource.rport'}],
     $row->[$dns_r_pos{'dns_resource.text0'}],
     $row->[$dns_r_pos{'dns_resource.text1'}]);
  
  if ($type eq 'AFSDB') {
    $Ret .= "Type: $m0; Host: $rn";
  }elsif($type eq 'ANAME' || $type eq 'CNAME') {
    $Ret .= "Extra Name: $n<br>Registered Name: $rn";
  }elsif($type eq 'HINFO') {
    $Ret .= "$t0 $t1\n";
  }elsif($type eq 'RP') {
    $Ret .= "$t0 $t1\n";
  }elsif($type eq 'MX') {
    $Ret .= "Metric: $m0<br>Host: $rn";
  }elsif($type eq 'NS') {
    $Ret .= "Server: $rn";
  }elsif($type eq 'SRV') {
    $Ret .= "Pri: $m0; Weight: $m1<br>Port: $p, Host: $rn";
  }elsif($type eq 'TXT') {
    $Ret .= "Text: $t0\n";
  }elsif($type eq 'AAAA') {
    $Ret .= "IPv6 Address: $t0\n";
  }elsif($type eq 'LOC') {
    $Ret .= "Location: $t0\n";
  }
  return $Ret;
}

sub dns_cb_r_owner {
  my ($url, $row) = @_;
  
  return "Owner" if (!ref $row);
  my $type = $row->[$dns_r_pos{'dns_resource.owner_type'}];
  my $tid = $row->[$dns_r_pos{'dns_resource.owner_tid'}];
  
  my $iURL = '';
  my $pType = '';

  my $rt = $row->[$dns_r_pos{'dns_resource.type'}];
  if ($rt eq 'CNAME' || $rt eq 'ANAME') {
    $pType = $row->[$dns_r_pos{'dns_resource.rname'}];
  }else{
    $pType = $row->[$dns_r_pos{'dns_resource.name'}];
  }

  if ($type eq 'machine') {
    $iURL = "$url?op=mach_view&id=$tid";
  }elsif($type eq 'dns_zone') {
    $iURL = "$url?op=zone_info&id=$tid";
  }elsif($type eq 'service') {
    $iURL = "$url?op=svc_info&sid=$tid";
    $pType = '[service]';
  }else{
    $iURL = "$url";
  }
  return "<a href=\"$iURL\">$pType</a>\n";
}
  

1;
