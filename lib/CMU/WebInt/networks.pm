#   -*- perl -*-
#
# CMU::WebInt::networks
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

package CMU::WebInt::networks;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings %network_output_ord 
	     %network_pos %network_p);

use CMU::Netdb;
use CMU::WebInt;

use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(net_list net_view net_add net_upd net_upd_conf net_del
	     net_del_conf);

%errmeanings = %CMU::Netdb::errors::errmeanings;
%network_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::network_fields)};
%network_output_ord = (1 => 'network.name', 
		     2 => 'network.subnet');
%network_p = %CMU::Netdb::structure::network_printable;

sub net_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('net_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Network Admin", $errors);
  &CMU::WebInt::title("List of Networks");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'network', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('network', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=net_add_form>Add Network</a></b>] ".
CMU::WebInt::pageHelpLink(''));

  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 1 if ($sort eq '');
  
  $res = net_print_networks($user, $dbh, $q,  
			    " 1 ".
			    CMU::Netdb::verify_orderby($network_output_ord{$sort}), '',
			    $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'net_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# net_print_networks
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
sub net_print_networks {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $maxPages, $vres);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'network', $cwhere);
  
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
  $ruRef = CMU::Netdb::list_networks($dbh, $user, " $where ".
				     CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_networks: ".$errmeanings{$ruRef};
    return 0;
  }

  my $sref = CMU::Netdb::list_subnets_ref($dbh, $user, '', 'subnet.name');
  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['network.name'], [\&net_cb_print_subnet], $sref,
		 'net_list', 'op=net_view&id=',
		 \%network_pos, 
		 \%network_p,
		 'network.name', 'network.id', 'sort');
  return 1;
}

sub net_cb_print_subnet {
  my ($url, $dref, $udata) = @_;

  return $network_p{'network.subnet'} if (!ref $dref);
  my %slist = %$udata;
  my @rrow = @{$dref};

  my $subnet = $rrow[$network_pos{'network.subnet'}];
  return $slist{$subnet} if ($slist{$subnet});
  return 'Unknown'; 
}

sub net_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $id = CMU::WebInt::gParam($q, 'id');

  $$errors{msg} = "Network ID not specified!" if ($id eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('net_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Network Admin", $errors);
  &CMU::WebInt::title("Network Information");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'network', $id);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'network', $id);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('network', 'READ', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
    
  my $bref = CMU::Netdb::list_networks($dbh, $user, "network.id='$id'");
  my @sdata = @{$bref->[1]};
  
  print CMU::WebInt::subHeading("Information for: ".$sdata[$network_pos{'network.name'}], CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=$url?op=net_view&id=$id>Refresh</a></b>]
 [<b><a href=$url?op=prot_s3&table=network&tidType=1&tid=$id>View/Update Protections</a></b>] 
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=net_del&id=$id&version=".
   $sdata[$network_pos{'network.version'}])."\">Delete Network</a></b>]\n");

  # name, subnet
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=net_update>
<input type=hidden name=version value=\"".$sdata[$network_pos{'network.version'}]."\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $network_p{'network.name'}, 1, 'network.name').
  CMU::WebInt::printPossError(defined $errors->{'subnet'}, $network_p{'network.subnet'}, 1, 'subnet').
    "</tr>";

  my $sref = CMU::Netdb::list_subnets_ref($dbh, $user, '', 'subnet.name');
  my @ks = sort {$$sref{$a} cmp $$sref{$b}} keys %$sref;
  
  print "<tr><td>".CMU::WebInt::printVerbose('network.name', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name => 'name', -value => $sdata[$network_pos{'network.name'}],  -accesskey => 'n').
    "</td><td>".CMU::WebInt::printVerbose('network.subnet', $verbose).
      $q->popup_menu(-name => 'subnet',  -accesskey => 'n',
		     -values => \@ks,
		     -default => $sdata[$network_pos{'network.subnet'}],
		     -labels => $sref)."</td></tr>\n";
  }else{
    print $sdata[$network_pos{'network.name'}]."</td><td>".
      CMU::WebInt::printVerbose('network.subnet', $verbose).
      $$sref{$sdata[$network_pos{'network.subnet'}]}."</td></tr>\n";
  }

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update Network')."</td></tr>\n" 
    if ($wl >= 1);
      
  print "</table></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub net_del {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('net_del');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Networks", {});
  &CMU::WebInt::title('Delete Network');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'network', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('network', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic network information
  my $sref = CMU::Netdb::list_networks($dbh, $user, "network.id='$id'");
  if (!defined $sref->[1]) {
    print "Network not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following network.\n";
  
  my @print_fields = ('network.name', 'network.subnet');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$network_p{$f}."</th>
<td>";
    print $sdata[$network_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=net_del_conf&id=$id&version=$version")."\">
Yes, delete this network";
  print "<br><a href=\"$url?op=net_list\">No, return to the networks list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub net_del_conf {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors, $fields);
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'network', $id);
  
  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete network $id\n";
    $dbh->disconnect();
    CMU::WebInt::net_view($q, \%errors);
    return;
  }
  
  ($res, $fields) = CMU::Netdb::delete_network($dbh, $user, $id, $version);
  
  $dbh->disconnect;
  if ($res == 1) {
    %errors = ('msg' => 'The network was deleted.');
    CMU::WebInt::net_list($q, \%errors);
  }else{
    $errors{msg} = "Error while deleting network: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{code} = $res;
    $errors{type} = 'ERR';
    $errors{fields} = join(',', @$fields);
    $errors{loc} = 'net_del_conf';
    CMU::WebInt::net_view($q, \%errors);
  }

}

sub net_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'network', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('net_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Network Admin", $errors);
  &CMU::WebInt::title("Add a Network");
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('network', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  # name, subnet
  my $sref = CMU::Netdb::list_subnets_ref($dbh, $user, '', 'subnet.name');
  my @ks = sort {$$sref{$a} cmp $$sref{$b}} keys %$sref;
  print "
<form method=get>
<input type=hidden name=op value=net_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $network_p{'network.name'}, 1, 'network.name').
  CMU::WebInt::printPossError(defined $errors{subnet}, $network_p{'network.subnet'}, 1, 'subnet')."</tr>
<tr><td>".CMU::WebInt::printVerbose('network.name', $verbose).
  $q->textfield(-name => 'name',  -accesskey => 'n')."</td><td>".
    CMU::WebInt::printVerbose('network.subnet', $verbose).
  $q->popup_menu(-name => 'subnet', -accesskey => 'n',
		 -values => \@ks,
		 -labels => $sref)."</td></tr>\n";

  print "</table>\n";
  print "<input type=submit value=\"Add Network\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub net_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  foreach(qw/name subnet/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }

  my ($res, $errfields) = CMU::Netdb::add_network($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added network $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    CMU::WebInt::net_view($q, \%nerrors);
  }else{
    $nerrors{'msg'} = "Error adding network: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{code} = $res;
      $nerrors{type} = 'ERR';
      $nerrors{fields} = join(',', @$errfields);
      $nerrors{loc} = 'net_add';
    }
    $dbh->disconnect();
    &net_add_form($q, \%nerrors);
  }
}

sub net_upd {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'network', $id);

  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Network Admin", $errors);
    &CMU::WebInt::title("Update Network");
    CMU::WebInt::accessDenied('network', 'WRITE', $id, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  foreach(qw/name subnet/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }

  my ($res, $errfields) = CMU::Netdb::modify_network($dbh, $user, $id, $version, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Updated network.";
    $dbh->disconnect(); 
    &CMU::WebInt::net_view($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{code} = $res;
    $nerrors{type} = 'ERR';
    $nerrors{fields} = join(',', @$errfields);
    $nerrors{loc} = 'net_upd';
    $dbh->disconnect();
    &CMU::WebInt::net_view($q, \%nerrors);
  }
}

1;
