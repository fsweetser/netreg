#   -*- perl -*-
#
# CMU::WebInt::outlet_type
# This module provides the outlet type modification screens.
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

package CMU::WebInt::outlet_type;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings %outlet_t_pos 
	    %errmeanings $outlet_t_pos_s %outlet_t_output_order);

use CMU::WebInt::vars;
use CMU::WebInt::interface;
use CMU::WebInt::helper;
use CMU::Netdb;
use CMU::Netdb::buildings_cables;
use CMU::Netdb::auth;
use CMU::Netdb::helper;
use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(outlet_t_list outlet_t_view outlet_t_update outlet_t_delete
	     outlet_t_confirm outlet_t_add outlet_t_add_form);


%errmeanings = %CMU::Netdb::errors::errmeanings;
%outlet_t_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::outlet_type_fields)};
$outlet_t_pos_s = $#CMU::Netdb::structure::outlet_type_fields;

%outlet_t_output_order = (1 => 'outlet_type.name');

# ############################################################################
# Outlet Types
# ############################################################################

sub outlet_t_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Types", $errors);
  &CMU::WebInt::title("List of Outlet Types");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'outlet_type', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('outlet_type', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=outlet_t_add_form>Add Outlet Type</a></b>] \n");

  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 1 if ($sort eq '');
  
  $res = outlet_t_print_type($user, $dbh, $q,  
			     " 1 ".
			     CMU::Netdb::verify_orderby($outlet_t_output_order{$sort}), '',
			     $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'outlet_t_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# outlet_t_print_type
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
sub outlet_t_print_type {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $maxPages, $vres);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'outlet_type', $cwhere);

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
  $ruRef = CMU::Netdb::list_outlet_types
    ($dbh, $user, " $where ".CMU::Netdb::verify_limit($start, $defitems));

  if (!ref $ruRef) {
    print "ERROR with list_outlet_types: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['outlet_type.name'],
		 [\&outlet_t_cb_prot, \&outlet_t_cb_del], '',
		 'list', '',
		 \%outlet_t_pos, 
		 \%CMU::Netdb::structure::outlet_type_printable,
		 '', '', 'sort');
  return 1;
}

sub outlet_t_cb_del {
  my ($url, $row, $edata) = @_;
  return "Delete" if (!ref $row);
  my @rrow = @$row;
  return "<a href=\"".CMU::WebInt::encURL("$url?op=outlet_t_delete&id=".$rrow[$outlet_t_pos{'outlet_type.id'}]."&version=".$rrow[$outlet_t_pos{'outlet_type.version'}])."\">Delete</a>";
}

sub outlet_t_cb_prot {
  my ($url, $row, $edata) = @_;
  return "Protections" if (!ref $row);
  my @rrow = @$row;
  return "<a href=$url?op=prot_s3&table=outlet_type&tidType=1&tid=".$rrow[$outlet_t_pos{'outlet_type.id'}].">View/Update</a>";
}

sub outlet_t_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Types", {});
  &CMU::WebInt::title('Delete Outlet Type');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');

  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet_type', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('outlet_type', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic outlet_type infromation
  my $sref = CMU::Netdb::list_outlet_types($dbh, $user, "outlet_type.id=$id");
  if (!defined $sref->[1]) {
    print "Outlet Type not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following Outlet Type.\n";
  
  my @print_fields = ('outlet_type.name');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::outlet_type_printable{$f}."</th>
<td>";
    print $sdata[$outlet_t_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=outlet_t_confirm&id=$id&version=$version")."\">
Yes, delete this Outlet Type";
  print "<br><a href=\"$url?op=outlet_t_list\">No, return to the Outlet Type list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub outlet_t_confirm {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet_type', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete outlet_type $id\n";
    $dbh->disconnect();
    CMU::WebInt::outlet_t_list($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_outlet_type($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    $errors{msg} = "The Outlet Type was deleted.";
    CMU::WebInt::outlet_t_list($q, \%errors);
  }else{
    $errors{msg} = "Error while deleting Outlet Type: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{type} = 'ERR';
    $errors{loc} = 'outlet_t_confirm';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    CMU::WebInt::outlet_t_list($q, \%errors);
  }

}

sub outlet_t_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'outlet_type', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Types", $errors);
  &CMU::WebInt::title("Add an Outlet Type");
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('outlet_type', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # name, number
  print "
<form method=get>
<input type=hidden name=op value=outlet_t_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $CMU::Netdb::structure::outlet_type_printable{'outlet_type.name'})."</tr>

<tr><td>".$q->textfield(-name => 'name')."</td></tr>\n";

  print "</table>\n";
  print "<input type=submit value=\"Add Outlet Type\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub outlet_t_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  %fields = ('name' => CMU::WebInt::gParam($q, 'name'));

  my ($res, $errfields) = CMU::Netdb::add_outlet_type($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $dbh->disconnect(); 
    CMU::WebInt::outlet_t_list($q, {'msg' => 'Added Outlet Type '.$fields{name}});
  }else{
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'outlet_t_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    CMU::WebInt::outlet_t_add_form($q, \%nerrors);
  }
}




