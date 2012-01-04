#   -*- perl -*-
#
# CMU::WebInt::mach_dns
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

package CMU::WebInt::mach_dns;

use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings );

use CMU::WebInt;
use CMU::Netdb;

use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.03';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(mach_dns_add_res mach_dns_add_res_form mach_dns_add_res_form2
	    mach_dhcp_add_opt mach_dhcp_add_opt_form mach_dns_res_del);

%errmeanings = %CMU::Netdb::errors::errmeanings;

sub mach_dns_add_res_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  if (CMU::WebInt::gParam($q, 'st') eq '2') {
    CMU::WebInt::mach_dns_add_res_form2($q, $errors);
    return;
  }
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dns_resource', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('mach_dns_res_add');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources", $errors);
  &CMU::WebInt::title("Add a DNS Resource");
  print CMU::WebInt::errorDialog($url, $errors);

  print "<br>";
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('dns_resource', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  my $verbose = CMU::WebInt::gParam($q, 'verbose');
  $verbose = 1 if ($verbose ne '0');
  
  print CMU::WebInt::printVerbose('mach_view.dns_resources', $verbose);

  # type
  my $dnsref = CMU::Netdb::get_dns_resource_types($dbh, $user, '');
  if (!ref $dnsref) {
    &CMU::WebInt::admin_mail('mach_dns.pm:mach_dns_add_res_form', 'WARNING',
		'Unable to load any DNS resource types.', {});
    print "Error: Unable to load any DNS resource types.\n";
    $dbh->disconnect();
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @dns_v = keys %$dnsref;

  print "
<form method=get>
<input type=hidden name=op value=mach_dns_res_add>".
$q->hidden('owner_type').$q->hidden('owner_tid').$q->hidden('host').
"<input type=hidden name=st value=2>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{otype}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.type'})."
</tr>
<tr><td>".$q->popup_menu(-name => 'type', -accesskey=>'r',
			 -values => \@dns_v,
			 -labels => $dnsref)."</td></tr>";
  print "</table>\n";
  print "<input type=submit value=\"Continue\">\n";
			 $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);
}

sub mach_dns_add_res {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  my $owner_type = CMU::WebInt::gParam($q, 'owner_type');
  foreach(qw/type name ttl rname rmetric0 rmetric1 rport text0 text1 owner_type owner_tid/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }

  $fields{type} = CMU::WebInt::gParam($q, 'typename');

  my ($res, $errfields) = CMU::Netdb::add_dns_resource($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added DNS resource $fields{name}.";
#    $q->param('id', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    $q->param('id', CMU::WebInt::gParam($q, 'owner_tid'));
    if ($owner_type eq 'dns_zone') {
      CMU::WebInt::zone_view($q, \%nerrors);
    } elsif ($owner_type eq 'service') {
      $q->param('sid', CMU::WebInt::gParam($q, 'owner_tid'));
      CMU::WebInt::svc_view($q, \%nerrors);
    } else {
      # ASSUME $owner_type of 'machine'
      CMU::WebInt::mach_view($q, \%nerrors);
    }
  }else{
    $nerrors{'msg'} = "Error adding DNS resource: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 if ($_ ne 'type'); $nerrors{otype} = 1 if ($_ eq 'type') } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{'code'} = $res;
      $nerrors{'loc'} = 'mach_dns_res_add';
      $nerrors{'fields'} = join(',', @$errfields);
      $nerrors{'type'} = 'ERR';
    }
    $dbh->disconnect();
    &CMU::WebInt::mach_dns_add_res_form2($q, \%nerrors);
  }
}

sub mach_dns_add_res_form2 {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors, $type, $owner_type, $dnsref, $typename, $format);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $type = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'type'));
  $owner_type = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'owner_type'));
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dns_resource_type', $type);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('mach_dns_res_add2');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Resources", $errors);
  &CMU::WebInt::title("Add a DNS Resource");
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('dns_resource_type', 'ADD', $type, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  $dnsref = CMU::Netdb::list_dns_resource_types($dbh, $user, "dns_resource_type.id = '$type'");
  if (!ref $dnsref) {
    print "Error: Unable to load any DNS resource types.\n";
    &CMU::WebInt::admin_mail('mach_dns.pm:mach_dns_add_res_form2', 'WARNING',
		'Unable to load any DNS resource types.', 
		{'dns_resource_type.id' => $type});
    $dbh->disconnect();
    print &CMU::WebInt::stdftr($q);
    return;
  }

  ## get the type name and format
  shift(@$dnsref);
  $typename = $dnsref->[0]->[$CMU::WebInt::dns::dns_r_t_pos{'dns_resource_type.name'}];
  $format = $dnsref->[0]->[$CMU::WebInt::dns::dns_r_t_pos{'dns_resource_type.format'}];


  # Verify that the owner_type is valid for this DNS resource type
  unless ( ($owner_type eq 'dns_zone' && grep /^$typename$/, @CMU::Netdb::structure::dns_resource_zone_types) ||
	   ($owner_type eq 'machine'  && grep /^$typename$/, @CMU::Netdb::structure::dns_resource_mach_types) ||
	   ($owner_type eq 'service' && grep /^$typename$/, @CMU::Netdb::structure::dns_resource_service_types)) {
    print "<hr>Error: Requested resource type ($typename) not applicable to resource ($owner_type)\n";
    $dbh->disconnect();
    print &CMU::WebInt::stdftr($q);
    return;
  }
	   
  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  # type, ttl

  print "
<form method=get>
<input type=hidden name=op value=mach_dns_ares_conf>".
$q->hidden('owner_tid').$q->hidden('owner_type').$q->hidden('host').
$q->hidden('type').$q->hidden('typename', $typename)."
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{otype}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.type'}).
  CMU::WebInt::printPossError(defined $errors{ttl}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.ttl'})."
</tr>
<tr><td>$typename</td><td>".$q->textfield(-name => 'ttl', -accesskey=>'t', -default => '0')."</td>
</tr>\n";
  my ($nameDef, $rnameDef) = ('', '');
  $rnameDef = CMU::WebInt::gParam($q, 'host') if ($typename eq 'CNAME' || $typename eq 'ANAME' || $typename eq 'SRV');
  $nameDef = CMU::WebInt::gParam($q, 'host') unless ($typename eq 'CNAME' || $typename eq 'ANAME' || $typename eq 'SRV');
  
  # name
  print "<tr>";
  print CMU::WebInt::printPossError(defined $errors{name}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.name'});
  print "</tr><tr>\n";
  if ($nameDef ne '') {
    print "<td>$nameDef<input type=hidden name='name' value='$nameDef'></td></tr>\n";
  }else{
    print "<td>".$q->textfield(-name => 'name', -accesskey=>'r')."</td></tr>\n";
  }

# rname, rport
  print "<tr>";
  print CMU::WebInt::printPossError(defined $errors{rname}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.rname'}) if ($format =~ /N/);
  print CMU::WebInt::printPossError(defined $errors{rport}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.rport'}) if ($format =~ /P/);
  print "</tr><tr>\n";
  print "<td>$rnameDef<input type=hidden name='rname' value='$rnameDef'></td>\n" if ($rnameDef ne '' && $format =~ /N/);
  print "<td>".$q->textfield(-name => 'rname', -accesskey=>'h')."</td>" if ($rnameDef eq '' && $format =~ /N/);
  print "<td>".$q->textfield(-name => 'rport', -accesskey=>'h')."</td>" if ($format =~ /P/);
  print "</tr>\n";

  # rmetric0 rmetric1
  print "<tr>";
  print CMU::WebInt::printPossError(defined $errors{rmetric0}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.rmetric0'}) if ($format =~ /M0/);
  print CMU::WebInt::printPossError(defined $errors{rmetric1}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.rmetric1'}) if ($format =~ /M1/);
  print "</tr><tr>\n";
  print "<td>".$q->textfield(-name => 'rmetric0', -accesskey=>'m')."</td>" if ($format =~ /M0/);
  print "<td>".$q->textfield(-name => 'rmetric1', -accesskey=>'m')."</td>" if ($format =~ /M1/);
  print "</tr>\n";

  # text0, text1
  print "<tr>";
  print CMU::WebInt::printPossError(defined $errors{text0}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.text0'}) if ($format =~ /T0/);
  print CMU::WebInt::printPossError(defined $errors{text1}, $CMU::Netdb::structure::dns_resource_printable{'dns_resource.text1'}) if ($format =~ /T1/);
  print "</tr><tr>\n";
  print "<td>".$q->textfield(-name => 'text0', -accesskey=>'t')."</td>" if ($format =~ /T0/);
  print "<td>".$q->textfield(-name => 'text1', -accesskey=>'t')."</td>" if ($format =~ /T1/);
  print "</tr>";

  print "</table>\n";
  print "<input type=submit value=\"Continue\">\n";
			 $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);
}

sub mach_dhcp_add_opt {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $addret);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my ($type, $tid) = (CMU::WebInt::gParam($q, 'type'), CMU::WebInt::gParam($q, 'tid'));
  foreach(qw/type_id value type tid/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  my ($res, $errfields) = CMU::Netdb::add_dhcp_option($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added DHCP option $fields{name}.";
#    $q->param('id', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    if ($type eq 'subnet') {
      $q->param('sid', CMU::WebInt::gParam($q, 'tid'));
      if ($tid == 0) {
	&mach_dns_gdhcp_list($q, \%nerrors);
      }else{
	CMU::WebInt::subnets_view($q, \%nerrors);
      }
    }elsif($type eq 'global') {
      &mach_dns_gdhcp_list;
    }elsif($type eq 'service') {
      $q->param('sid', CMU::WebInt::gParam($q, 'tid'));
      CMU::WebInt::svc_view($q, \%nerrors);
    }else{
      $q->param('id', $tid);
      CMU::WebInt::mach_view($q, \%nerrors);
    }
  }else{
    $nerrors{'msg'} = "Error adding DHCP option: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{'code'} = $res;
      $nerrors{'type'} = 'ERR';
      $nerrors{'loc'} = 'mach_dhcp_addc';
      $nerrors{'fields'} = join(',', @$errfields);
    }
    $dbh->disconnect();
    $q->param('subnet', $tid) if ($type eq 'subnet');
    $q->param('id', $tid) if ($type eq 'machine');

    &CMU::WebInt::mach_dhcp_add_opt_form($q, \%nerrors);
  }
}

sub mach_dhcp_add_opt_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, $rlevel, %errors, $mode, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dhcp_option', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('mach_dhcp_add');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DHCP Options", $errors);
  &CMU::WebInt::title("Add a DHCP Option");
  print CMU::WebInt::errorDialog($url, $errors);

  my ($type, $tid, $printable) = 
    (CMU::WebInt::gParam($q, 'type'),
     CMU::WebInt::gParam($q, 'tid'),
     CMU::WebInt::gParam($q, 'printable'));

  my %typeToOp = ('machine' => 'mach_view',
		  'service' => 'svc_info',
		  'subnet' => 'sub_info');
  my %typeToIDfield = ('machine' => 'id',
		       'service' => 'sid',
		       'submet' => 'sid');
  
  my $prText = '';
  if ($type eq 'subnet' && $tid == 0) {
    $prText = "Adding Subnet Default DHCP Option";
    $rlevel = ($userlevel >= 9 ? 1 : 0);
  }elsif ($type ne 'global' && defined $typeToOp{$type}) {
  
    $prText = "Adding DHCP Option for $type: ";
    $prText .= "<a href=\"$url?op=$typeToOp{$type}&$typeToIDfield{$type}".
      "=$tid\">";
    $prText .= $printable if ($printable ne '');
    $prText .= $tid if ($printable eq '');
    $prText .= "</a>\n";
    $rlevel = CMU::Netdb::get_write_level
      ($dbh, $user, $type, $tid);
  }elsif($type eq 'global') {
    $prText = "Adding global DHCP Option.\n";
    $rlevel = ($userlevel >= 9 ? 1 : 0);
  }else{
    print "Unknown Table!\n";
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  if ($userlevel < 1 || $rlevel < 1) {
    CMU::WebInt::accessDenied('multiple', 'ADD', 0, "1,1", 
			      "$userlevel, $rlevel",
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print CMU::WebInt::subHeading($prText, CMU::WebInt::pageHelpLink(''));
  
  print CMU::WebInt::printVerbose('mach_view.dhcp_options', $verbose);

  # type
  my $dhcpref = CMU::Netdb::get_dhcp_option_types($dbh, $user, '');
  if (!ref $dhcpref) {
    print "Error: Unable to load any DHCP option types.\n";
    &CMU::WebInt::admin_mail('mach_dns.pm:mach_dhcp_add_opt_form', 'WARNING',
		'Unable to load any DHCP option types.', {});
    $dbh->disconnect();
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @dhcp_v = sort { $$dhcpref{$a} cmp $$dhcpref{$b} } keys %$dhcpref;
  $q->param('tid', $id);
  $q->param('type', $type);
  print "\n\n<form method=get>\n".
    $q->hidden('type', $type).
      $q->hidden('tid', $tid).
	$q->hidden('printable', $printable);
  
  print "<input type=hidden name=op value=mach_dhcp_addc>\n".
"<table border=0><tr>".
  CMU::WebInt::printPossError
    (defined $errors{type}, 
     $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option_type.name'}, 
     1, 'dhcp_option.type');
  print "\n</tr><tr><td>\n".
    CMU::WebInt::printVerbose('dhcp_option.type', $verbose).
      $q->popup_menu(-name => 'type_id',  -accesskey => 'o',
		     -values => \@dhcp_v,
		     -labels => $dhcpref)."</td></tr>";

  # value
  print "<tr>".CMU::WebInt::printPossError(defined $errors{value},
			      $CMU::Netdb::structure::dhcp_option_printable{'dhcp_option.value'}, 1, 'dhcp_option.value')."</tr>
<tr><td>".CMU::WebInt::printVerbose('dhcp_option.value', $verbose).
  $q->textfield(-name => 'value', -accesskey => 'o')."</td></tr>\n";

  # If this is a reload because of a possible error, get the format
  # of the DHCP option they specified
  my $TypeID = CMU::WebInt::gParam($q, 'type_id');
  if ($TypeID ne '') {
    print "<tr>".CMU::WebInt::printPossError(0, 'Option Format', 1, '');
    print "</tr>\n<tr><td>".
      CMU::WebInt::printVerbose('dhcp_option_type.format', $verbose);
    my $dho = CMU::Netdb::list_dhcp_option_types
      ($dbh, $user, " dhcp_option_type.id = '$TypeID'");
    if (!ref $dho || !defined $dho->[1]) {
      print "[Unable to list format.]\n";
    }else{
      my %pos = %{CMU::Netdb::makemap($dho->[0])};
      print "Format: <b>".
	$dho->[1]->[$pos{'dhcp_option_type.format'}].
	  "</b>";
    }
    print "</td></tr>\n";
  }

  print "</table>\n";
  print "<input type=submit value=\"Continue\">\n";

  $dbh->disconnect();

  print &CMU::WebInt::stdftr($q);
}

sub mach_dhcp_opt_del {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  if (CMU::WebInt::gParam($q, 'c') eq '1') {
    mach_dhcp_opt_del_conf($q);
    return;
  }
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my ($id, $version, $dnir, $mwl, $oType, $tid);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  CMU::WebInt::setHelpFile('mach_dhcp_opt_del');
  print &CMU::WebInt::stdhdr($q, $dbh, $user, "Delete Option", $errors);
  &CMU::WebInt::title("Delete DHCP Option");

  $dnir = CMU::Netdb::list_dhcp_options($dbh, 'netreg', "dhcp_option.id = '$id'");
  if (!ref $dnir || $#$dnir <= 0) {
    print "Option doesn't exist!\n";
    print &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  $tid = $dnir->[1]->[$CMU::WebInt::dhcp::dhcp_o_pos{'dhcp_option.tid'}];

  $oType = CMU::WebInt::gParam($q, 'type');
  my @sdata = @{$dnir->[1]};

  if ($oType eq 'machine') {
    $mwl = CMU::Netdb::get_write_level($dbh, $user, 'machine', $tid);
  }elsif($oType eq 'subnet') {
    $mwl = CMU::Netdb::get_write_level($dbh, $user, 'subnet', $tid);
  }else{
    # ASSUME global
    $mwl = CMU::Netdb::get_write_level($dbh, $user, 'dhcp_option', 0);
    $mwl = 0 if ($mwl < 9);
  }
  if ($mwl < 1) {
    CMU::WebInt::accessDenied($oType, 'WRITE', $tid, 1, $mwl, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<br><br>Please confirm that you wish to delete the following DHCP option.\n";
  
  my @print_fields = qw/dhcp_option.type_id dhcp_option.value/;

  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::dhcp_option_printable{$f}."</th>
<td>";
    print $sdata[$CMU::WebInt::dhcp::dhcp_o_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=mach_dhcp_opt_del&c=1&id=$id&version=$version&tid=".CMU::WebInt::gParam($q, 'tid')."&type=$oType")."\">
Yes, delete this option";
  my $backOp = 'mach_view';
  $backOp = 'sub_info' if ($oType eq 'subnet' && $tid != 0);
  $backOp = 'mach_dns_gdhcp_list' if ( ($oType eq 'global') ||
				       ($oType eq 'subnet' && $tid == 0 ));
  
  print "<br><a href=\"$url?op=$backOp&id=".CMU::WebInt::gParam($q, 'tid')."\">No, go back</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub mach_dhcp_opt_del_conf {
  my ($q, $errors) = @_;
  my ($url, $msg, $dbh, $ul, $res, $id, $version, $oType, $ref) = @_;
  
  ($id, $version) = (CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'id')), CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'version')));
  my %funcs = ('machine' => \&CMU::WebInt::machines::mach_view,
	       'subnet' => \&CMU::WebInt::subnets::subnets_view,
	       'global' => \&CMU::WebInt::mach_dns::mach_dns_gdhcp_list,
	       'service' => \&CMU::WebInt::services::svc_view);
  $oType = CMU::WebInt::gParam($q, 'type');
  $oType = 'global' if ($oType eq 'subnet' &&
			CMU::WebInt::gParam($q, 'tid') eq '0');

  if ($id eq '') {
    $msg = "Delete DHCP Option: Option ID not specified!";
    $q->param('id', CMU::WebInt::gParam($q, 'tid'));
    $funcs{$oType}->($q, {'msg' => $msg});
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};

  ($res, $ref) = CMU::Netdb::delete_dhcp_option($dbh, $user, $id, $version);
  my %errors;
  if ($res == 1) {
    %errors = ('msg' => 'The DHCP Option was deleted.');
  }else{
    $msg = 'There was an error while deleting the DHCP Option: '.$errmeanings{$res};
    $msg .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." ) "
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $errors{'msg'} = $msg;
    $errors{'code'} = $res;
    $errors{'loc'} = 'mach_dhcp_opt_del_conf';
    $errors{'fields'} = join(',', @$ref);
    $errors{'type'} = 'ERR';
  }
  $q->param('id', CMU::WebInt::gParam($q, 'tid'));
  $q->param('sid', CMU::WebInt::gParam($q, 'tid')) if ($oType eq 'subnet' ||
						       $oType eq 'service');
  $dbh->disconnect();
  $funcs{$oType}->($q, \%errors);
}

sub mach_dns_res_del {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel);
  
  if (CMU::WebInt::gParam($q, 'c') eq '1') {
    mach_dns_res_del_conf($q);
    return;
  }
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my ($id, $version, $dnir, $mwl, $oType, $tid);

  $url = $ENV{SCRIPT_NAME};

  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  CMU::WebInt::setHelpFile('mach_dns_res_del');
  print &CMU::WebInt::stdhdr($q, $dbh, $user, "Delete Resource", $errors);
  &CMU::WebInt::title("Delete DNS Resource");

  $dnir = CMU::Netdb::list_dns_resources($dbh, 'netreg', "dns_resource.id = '$id'");
  if (!ref $dnir || $#$dnir <= 0) {
    print "Resource doesn't exist!\n";
    print &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  $tid = $dnir->[1]->[$CMU::WebInt::dns::dns_r_pos{'dns_resource.owner_tid'}];

  $oType = CMU::WebInt::gParam($q, 'owner_type');
  my @sdata = @{$dnir->[1]};

  if ($oType eq 'dns_zone') {
    $mwl = CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', $tid);
    my $tyref = CMU::Netdb::get_dns_resource_types($dbh,$user,"dns_resource_type.name='$sdata[$CMU::WebInt::dns::dns_r_pos{'dns_resource.type'}]' AND P.rlevel >= 5");
    if ($mwl < 5 || !ref $tyref || !(grep /^$sdata[$CMU::WebInt::dns::dns_r_pos{'dns_resource.type'}]$/, values %$tyref)) {
      CMU::WebInt::accessDenied('dns_zone', 'WRITE', $tid, 5, $mwl, $user);  
      print CMU::WebInt::stdftr($q);
      $dbh->disconnect;
      return;
    }
  }else{
    $mwl = CMU::Netdb::get_write_level($dbh, $user, 'machine', $tid);
    if ($mwl < 1) {
      CMU::WebInt::accessDenied('machine', 'WRITE', $tid, 1, $mwl, $user);
      print CMU::WebInt::stdftr($q);
      $dbh->disconnect;
      return;
    }
  }
  print "<br><br>Please confirm that you wish to delete the following DNS resource.\n";
  
  my @print_fields = qw/dns_resource.name dns_resource.rname dns_resource.type/;

  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::dns_resource_printable{$f}."</th>
<td>";
    print $sdata[$CMU::WebInt::dns::dns_r_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=mach_dns_res_del&c=1&id=$id&version=$version&owner_tid=".CMU::WebInt::gParam($q, 'owner_tid')."&owner_type=$oType")."\">
Yes, delete this resource";
  my $backOp = 'mach_view';
  $backOp = 'zone_info' if ($oType eq 'dns_zone');
  print "<br><a href=\"$url?op=$backOp&id=".CMU::WebInt::gParam($q, 'owner_tid')."\">No, go back</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub mach_dns_res_del_conf {
  my ($q, $errors) = @_;
  my ($url, $msg, $dbh, $ul, $res, $id, $version, $ref) = @_;
  
  ($id, $version) = (CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'id')), CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'version')));
  my %funcs = ('machine' => \&CMU::WebInt::machines::mach_view,
	       'dns_zone' => \&CMU::WebInt::zones::zone_view,
	       'service' => \&CMU::WebInt::services::svc_view);
  my $oType = CMU::WebInt::gParam($q, 'owner_type');
  
  if ($id eq '') {
    $msg = "Delete DNS Resource: Resource ID not specified!";
    $q->param('id', CMU::WebInt::gParam($q, 'owner_tid'));
    $q->param('sid', CMU::WebInt::gParam($q, 'owner_tid')) if ($oType eq 'service');
    $funcs{$oType}->($q, {'msg' => $msg});
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};

  ($res, $ref) = CMU::Netdb::delete_dns_resource($dbh, $user, $id, $version);
  my %errors;
  if ($res == 1) {
    %errors = ('msg' => 'The DNS Resource was deleted.');
  }else{
    $msg = 'There was an error while deleting the DNS Resource: '.$errmeanings{$res};
    $msg .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." ) "
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $errors{'msg'} = $msg;
    $errors{'code'} = $res;
    $errors{'loc'} = 'mach_dns_res_del_conf';
    $errors{'fields'} = join(',', @$ref);
    $errors{'type'} = 'ERR';
  }
  $q->param('id', CMU::WebInt::gParam($q, 'owner_tid'));
  $q->param('sid', CMU::WebInt::gParam($q, 'owner_tid')) if ($oType eq 'service');
  $dbh->disconnect();
  $funcs{$oType}->($q, \%errors);
}

sub mach_dns_write_access_id {
  my ($dbh, $id, $user) = @_;
  return CMU::Netdb::get_write_level($dbh, $user, 'machine', $id);
}

sub mach_dns_write_access_hostname {
  my ($dbh, $hostname, $user) = @_;
  my $lref = CMU::Netdb::list_machines($dbh, $user, "machine.host_name = '$hostname'");
  if ($#$lref <= 0) {
    return 0;
  }
  return mach_dns_write_access_id($dbh, $lref->[1]->[$CMU::WebInt::machines::machine_pos{'machine.id'}], $user);
}

sub mach_dns_write_access_zoneID {
  my ($dbh, $id, $user) = @_;
  return CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', $id);
}

sub mach_dns_write_access_zone {
  my ($dbh, $hostname, $user) = @_;

  my $lref = CMU::Netdb::list_dns_zones($dbh, $user, "dns_zone.name = '$hostname'");
  if ($#$lref <= 0) {
    return 0;
  }
  return mach_dns_write_access_zoneID($dbh, $lref->[1]->[$CMU::WebInt::zones::zone_pos{'dns_zone.id'}], $user);
}

sub mach_dns_gdhcp_list {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};

  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  CMU::WebInt::setHelpFile('mach_dns_ghcp_list');
  print &CMU::WebInt::stdhdr($q, $dbh, $user, "DHCP Options", $errors);
  &CMU::WebInt::title("Global DHCP Options");

  print CMU::WebInt::subHeading("DHCP Options", CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=mach_dhcp_add&type=global\">Add DHCP Option</a></b>]
[<b><a href=\"$url?op=dhcp_o_t_list\">DHCP Option Types</a></b>]\n");

  my $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.type = 'global'");

  if (!ref $ldor) {
    print "Unable to find DHCP Options.\n";
  }elsif($#$ldor == 0) {
    print "[There are no visible global DHCP options.]\n";
  }else{
    CMU::WebInt::generic_tprint($url, $ldor, 
		   ['dhcp_option_type.name', 'dhcp_option.value'],
		   [\&CMU::WebInt::machines::mach_cb_dhcp_opt_del],
		   "global&tid=$id", '', '', \%CMU::WebInt::dhcp::dhcp_o_c_pos, 
		   \%CMU::Netdb::structure::dhcp_option_printable,
		   '', '', '');
  }

### Global Subnet Option

  print "<br><br>";

  print CMU::WebInt::subHeading("Subnet Default DHCP Options");
  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=mach_dhcp_add&type=subnet&tid=0\">".
"Add DHCP Option</a></b>] [<b><a href=\"$url?op=dhcp_o_t_list\">DHCP Option Types</a></b>]\n");

  my $sref = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.type = ".
  " 'subnet' AND dhcp_option.tid=0");

  if (!ref $sref) {
    print "Unable to find Subnet Default DHCP Options.\n";
  }elsif($#$sref == 0) {
    print "[There are no visible subnet default DHCP options.]\n";
  }else{
    CMU::WebInt::generic_tprint($url, $sref,
                   ['dhcp_option_type.name', 'dhcp_option.value'],
                   [\&CMU::WebInt::machines::mach_cb_dhcp_opt_del],
                   "subnet&tid=0", '', '', \%CMU::WebInt::dhcp::dhcp_o_c_pos,
                   \%CMU::Netdb::structure::dhcp_option_printable,
                   '', '', '');
  }

##  HTML Footer
  print &CMU::WebInt::stdftr($q);
}

1;
