#   -*- perl -*-
#
# CMU::WebInt::machines
# Machines
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
# $Id: machines.pm,v 1.129 2008/04/29 20:03:53 vitroth Exp $
#
#

package CMU::WebInt::machines;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings $THCOLOR $TACOLOR %machine_pos
	     %mach_p %htext $debug);

use CMU::WebInt;
use CMU::WebInt::quickreg;
use CMU::Netdb;

use Time::ParseDate;

require CMU::WebInt::auth; # for users_pos below
use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.03';
}

use Data::Dumper;
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(mach_reg_s0 mach_reg_s1 mach_reg_s2 mach_reg_s3 mach_list
	     mach_view mach_delete mach_confirm_delete mach_update mach_expire_list
	     mach_update_subnet mach_search mach_s_exec mach_conf_view
	     mach_history_search mach_find
	     device_add_presence);

%errmeanings = %CMU::Netdb::errors::errmeanings;

%machine_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::machine_fields)};

%mach_p = %CMU::Netdb::structure::machine_printable;

$debug = 0;
my ($gmcvres);
($gmcvres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'THCOLOR');
($gmcvres, $TACOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'TACOLOR');

my $LEASE_ARCHIVE_DIR;
($gmcvres, $LEASE_ARCHIVE_DIR) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'DHCP_LEASE_ARCHIVE_DIR');

sub mach_reg_s0 {
  my ($q, $errors) = @_;
  my ($dbh);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_reg_s0');
  if (CMU::WebInt::gParam($q, 'id') ne '') {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Change Subnet", $errors);
    my $hn = CMU::WebInt::gParam($q, 'h').".".CMU::WebInt::gParam($q, 'd');
    &CMU::WebInt::title("Changing Subnet") if ($hn eq '');
    &CMU::WebInt::title("Changing Subnet for Host: $hn") if ($hn ne '');
  }else{
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Machine Registration", $errors);
    &CMU::WebInt::title("Register a New Machine");
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  my $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($verbose) {
    print "<hr>".$CMU::WebInt::vars::htext{'machine.reg0_select'}."<br />";
  }else{
    print "<hr>Select the location for this machine.<br />\n";
  }

  print "<form name=main method=get>
<input type=hidden name=op value=mach_reg_s1>
<input type=hidden name=bmvm value=$verbose>";

  if (CMU::WebInt::gParam($q, 'id') ne '') {
    print "<input type=hidden name=id value=".CMU::WebInt::gParam($q, 'id').">
<input type=hidden name=h value=".CMU::WebInt::gParam($q, 'h').">
<input type=hidden name=d value=".CMU::WebInt::gParam($q, 'd').">";
  }
  
  my ($vres, $en) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_NETWORKS');
  if ($en == 1) {
    print &CMU::WebInt::subHeading("Select the <u>N</u>etwork", CMU::WebInt::pageHelpLink('network'));
    my %networks = %{CMU::Netdb::get_networks_ref($dbh, $user, '', 'network.subnet', 'network.name')};
    my @nk = sort {$networks{$a} cmp $networks{$b}} keys %networks;
    if ($#nk > -1) {
      unshift(@nk, '-1');
      $networks{-1} = '--select--';
      print "<table border=0 width=620><tr><td width=150><b>
 <font face=\"Arial,Helvetica,Geneva,Charter\"><b>".CMU::WebInt::inlineHelpLink('network').
   "Network:</a></b></font></td>
 <td width=350>".
   $q->popup_menu(-name => 'network',
		  -accesskey => 'n',
		  -values => \@nk,
		  -labels => \%networks);
    }else{
      print "<table border=0 width=620><tr><td width=150><b>
<font face=\"Arial,Helvetica,Geneva,Charter\"><b>".CMU::WebInt::inlineHelpLink('network').
  "Network:</a></b></font></td>
 <td width=350>No networks available.";
    }
    
    print "</td><td align=right><input type=submit name=networkNEXT value=\"Continue\"></td></tr></table>";
    
    print "<br /><table border=0 width=100%><tr bgcolor=#a3ffa3><td><center>".
      "<font size=+1><b><i>-or-</i></b></font></center></td></tr></table>\n";
  }

  my ($vbres, $eb) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_BUILDINGS');
  if ($eb == 1) {
    print &CMU::WebInt::subHeading("Select the <u>B</u>uilding", CMU::WebInt::pageHelpLink('building'));
    my %buildings = %{CMU::Netdb::list_buildings_ref($dbh, $user, '')};
    my @kb = sort {$buildings{$a} cmp $buildings{$b}} keys %buildings;
    
    if ($#kb > -1) {
      unshift(@kb, '-1');
      $buildings{-1} = '--select--';
      print "<table border=0 width=620><tr><td width=150><b>
 <font face=\"Arial,Helvetica,Geneva,Charter\"><b>".CMU::WebInt::inlineHelpLink('building').
   "Building:</a></b></font></td>
 <td width=350>".
   $q->popup_menu(-name => 'building',
		  -accesskey => 'b',
		  -values => \@kb,
		  -labels => \%buildings);
    }else{
      print "System Error: No buildings available.\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_reg_s0', 'WARNING',
			       'No buildings available.', {});
    }
    print "</td><td align=right><input type=submit name=buildingNEXT value=\"Continue\"></td></tr></table>";
    
    print "<br /><table border=0 width=100%><tr bgcolor=#a3ffa3><td><center>".
      "<font size=+1><b><i>-or-</i></b></font></center></td></tr></table>\n";
  }
  
  print &CMU::WebInt::subHeading("Select the <u>S</u>ubnet", 
				 "[<b><a href=\"$url?op=subnets_lookup\">".
				 "Lookup Subnet by IP Address</a></b>]  ".
				 "[<b><a href=\"$url?op=subnets_show_policy\">".
				 "View Subnet Policies</a></b>] ".
				 CMU::WebInt::pageHelpLink('subnet'));
  my %subnets = %{CMU::Netdb::get_subnets_ref($dbh, $user, "(P.rlevel >=9 OR subnet.dynamic='permit' OR subnet.dynamic='restrict' OR NOT FIND_IN_SET('no_static', subnet.flags))", 'subnet.name')};
  my @ks = sort {$subnets{$a} cmp $subnets{$b}} keys %subnets;
  if ($#ks > -1) {
    unshift(@ks, '-1');
    $subnets{-1} = '--select--';
    my @ks = sort {$subnets{$a} cmp $subnets{$b}} keys %subnets;
    print "<table border=0 width=620><tr><td width=150><b>
 <font face=\"Arial,Helvetica,Geneva,Charter\"><b>".CMU::WebInt::inlineHelpLink('subnet').
   "Subnet:</a></b></font></td>
 <td width=350>".
   $q->popup_menu(-name => 'subnet',
		  -accesskey => 's',
		  -values => \@ks,
		  -labels => \%subnets);
    }else{
      print "System Error: No subnets available.\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_reg_s0', 'WARNING',
			       'No subnets available.', {});
      
    }
    print "</td><td align=right><input type=submit name=subnetNEXT value=\"Continue\"></td></tr></table></form>";

  print CMU::WebInt::stdftr($q);
}

sub mach_reg_s1 {
  my ($q, $errors) = @_;

  my $where = '';
  $where = 'network' if (CMU::WebInt::gParam($q, 'networkNEXT') ne '');
  $where = 'bldg' if (CMU::WebInt::gParam($q, 'buildingNEXT') ne '');
  $where = 'subnet' if (CMU::WebInt::gParam($q, 'subnetNEXT') ne '');

  if ($where eq 'network') {
    $where = 'subnet';
    $q->param('subnet', CMU::WebInt::gParam($q, 'network'));
  }

  if ($where eq 'subnet') {
    if (CMU::WebInt::gParam($q, 'id') ne '') {
      mach_upd_sub_form($q, $errors);
    }else{
      CMU::WebInt::machines::mach_reg_s2($q, $errors);
    }
  }elsif($where eq 'bldg') {
    mach_reg_s1_building($q, $errors);
  }else {
    my $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Machine Registration", $errors);
    &CMU::WebInt::title("Error Processing New Registration");
    &CMU::WebInt::admin_mail('machines.pm:mach_reg_s1', 'WARNING',
		'Unknown where-code.', {});
    print "<br /><br />There was an error processing your new registration.";
    print &CMU::WebInt::stdftr($q);
  }
}

sub mach_upd_sub_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $bldg, %errors, @sdata, $version, $id, $sref, $mode, $subnet);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  $id = CMU::WebInt::gParam($q, 'id');

  # basic machine infromation
  $sref = CMU::Netdb::list_machines($dbh, $user, "machine.id='$id'");
  if (!defined $sref->[1]) {
    print "Machine not defined!\n";
    print &CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  @sdata = @{$sref->[1]};
  $version = $sdata[$machine_pos{'machine.version'}];
  $mode = $sdata[$machine_pos{'machine.mode'}];
  $subnet = CMU::WebInt::gParam($q, 'subnet');

  if ($mode eq 'dynamic') {
    $dbh->disconnect();
    $q->param('version', $version);
    $q->param('method', 'new');
    $q->param('newhost', '');
    $q->param('newdomain', '');
    CMU::WebInt::mach_update_subnet($q);
    return;
  }

  if ($mode eq 'broadcast' || $mode eq 'base') {
    # can only be one of these per subnet, so lets verify
    my $error;
    my $lmr = CMU::Netdb::list_machines($dbh, 'netreg', "ip_address_subnet = '$subnet' AND mode = '$mode'");
    if (!ref $lmr) {
      $error = "Error calling CMU::Netdb::list_machines: ".$errmeanings{$lmr};
    }else{
      $error = "Registration already exists for mode '$mode' on requested subnet." if (defined $lmr->[1]);
    }
    if ($error ne '') {
      $dbh->disconnect();
      if (CMU::WebInt::gParam($q, 'op') eq 'mach_reg_s2') {
	mach_reg_s1_building($q, {'msg' => $error});
      }else{
	CMU::WebInt::mach_reg_s0($q, {'msg' => $error,
			 'loc' => 'mach_upd_sub_form',
			 'code' => $CMU::Netdb::errcodes{ERROR},
			 'fields' => '',
			 'type' => 'ERR'});
      }
      return;
    }

  }

  CMU::WebInt::setHelpFile('mach_upd_sub');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Change Subnet", $errors);
  my $hn = CMU::WebInt::gParam($q, 'h').".".CMU::WebInt::gParam($q, 'd');
  &CMU::WebInt::title("Changing Subnet") if ($hn eq '.');
  &CMU::WebInt::title("Changing Subnet for Host: $hn") if ($hn ne '.');
  print CMU::WebInt::errorDialog($url, $errors);

  my @domains = @{CMU::Netdb::get_domains_for_subnet($dbh, $user, "subnet_domain.subnet = '$subnet'")};
  my $save = 0;
  foreach(@domains) {
    $save = 1 if (uc($_) eq uc(CMU::WebInt::gParam($q, 'd')));
  }

  my $hostname = $sdata[$machine_pos{'machine.host_name'}];
  my ($nh, $nd) = CMU::Netdb::splitHostname($hostname);
  print "
<form method=get>
<input type=hidden name=op value=mach_upd_sub>
<input type=hidden name=id value=$id>
<input type=hidden name=version value=\"$version\">
<input type=hidden name=subnet value=$subnet>
<input type=hidden name=h value=".CMU::WebInt::gParam($q, 'h').">
<input type=hidden name=d value=".CMU::WebInt::gParam($q, 'd').">
<table><tr><td bgcolor=$THCOLOR colspan=2>".
CMU::WebInt::tableHeading("Machine Hostname")."</td></tr>";
  if ($save) {
    print "<tr><td><input type=radio name=method value=save></td>".
      "<td>Same hostname: $hostname</td></tr>";
  }
  print "<tr><td><input type=radio name=method value=new ".
    ($save ? '' : 'CHECKED')."></td>
<td><input type=text name=newhost value=\"$nh\">.".
  $q->popup_menu(-name=>'newdomain',
		 -values=>\@domains)."
</td></tr>
<tr><td colspan=2><input type=submit value=\"Update Machine\"></td></tr>
</table>";

  $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);
}

sub mach_update_subnet {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'machine', $id);

  if($userlevel >= 1) {
    # Level 1 fields
    %fields = ('ip_address_subnet' => CMU::WebInt::gParam($q, 'subnet'),
	       'ip_address' => '');
    $fields{'host_name'} = CMU::WebInt::gParam($q, 'newhost').'.'.CMU::WebInt::gParam($q, 'newdomain')
      if (CMU::WebInt::gParam($q, 'method') eq 'new');
  }else{
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Update Access Denied", $errors);
    &CMU::WebInt::title("Update Machine");
    CMU::WebInt::accessDenied('machine', 'WRITE', $id, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # look for secondaries to update later
  my $maref = &CMU::Netdb::list_machines($dbh, $user, "machine.id = $id");
     $maref = &CMU::Netdb::list_machines($dbh, $user, "machine.mac_address='$maref->[1][$machine_pos{'machine.mac_address'}]' AND machine.mode='secondary' AND machine.ip_address_subnet=$maref->[1][$machine_pos{'machine.ip_address_subnet'}]");    

  warn __FILE__, ':', __LINE__, ' :>'.
    "Calling modify_machine..\n" if ($debug >= 1);
  my ($res, $errfields) = CMU::Netdb::modify_machine($dbh, $user, $id, $version, $userlevel, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Updated machine.";
	
	# look for secondaries and update them too
    my $c = 1;
	while (ref $maref && defined $maref->[$c]) {
      $nerrors{'msg'} .= "<BR />Attempting to update secondary: $maref->[$c][$machine_pos{'machine.host_name'}]: ";
	  my ($host,$domain) = &CMU::Netdb::splitHostname($maref->[$c][$machine_pos{'machine.host_name'}]);
      %fields = ('ip_address_subnet' => CMU::WebInt::gParam($q, 'subnet'),
                 'ip_address' => '');
      $fields{'host_name'} = $host.'.'.CMU::WebInt::gParam($q, 'newdomain')
        if (CMU::WebInt::gParam($q, 'method') eq 'new');
      ($res, $errfields) = CMU::Netdb::modify_machine($dbh, $user, $maref->[$c][$machine_pos{'machine.id'}], $maref->[$c][$machine_pos{'machine.version'}], $userlevel, \%fields);	  
      if ($res > 0) {
        $nerrors{'msg'} .= "OK";
	  } else {
        $nerrors{'msg'} .= $errmeanings{$res};
        $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";	  
	  }
	  $c++;
	}
	
    $dbh->disconnect(); # we use this for the insertid ..
    &CMU::WebInt::mach_view($q, \%nerrors);
  }else{
    foreach (@$errfields) {
      $nerrors{$_} = 1;
    }
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
    $nerrors{'type'} = 'ERR';
    $nerrors{'loc'} = 'mach_upd_sub';
    $nerrors{'code'} = $res;
    $nerrors{'fields'} = join(',', @$errfields);
    $dbh->disconnect();
    &mach_reg_s0($q, \%nerrors);
  }
}

sub mach_reg_s1_building {
  my ($q, $errors) = @_;
  my ($dbh, $url, $bldg, %errors);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  $bldg = CMU::WebInt::gParam($q, 'building');
  
  if ($bldg eq '-1') {
    CMU::WebInt::mach_reg_s0($q, {'msg' => 'Building not specified!',
		     'loc' => 'mach_reg_s1_building',
		     'fields' => 'building',
		     'code' => $CMU::Netdb::errcodes{ERROR},
		     'type' => 'ERR'});
    $dbh->disconnect();
    return;
  }

  ## This should be done to get building.id instead of building.building...:Kunal
  my $aref = CMU::Netdb::list_buildings($dbh, $user, "building.building=\'$bldg\'");
  my @adata = @{$aref->[1]};
  my $bldg_id = $adata[$CMU::WebInt::buildings::building_pos{'building.id'}];

  my $sref = CMU::Netdb::list_trunkset_building_presence($dbh, $user, "trunkset_building_presence.buildings = \'$bldg_id\'");
  my $nks = -1;
  my (%trunkset, @ts);
  if (ref $sref) {
    %trunkset= %$sref;
    @ts = sort { $trunkset{$a} cmp $trunkset{$b} } keys %trunkset;
    $nks = keys %trunkset;
  }

  my @vlan_arr;
  foreach my $ts_id (@ts) {
      $sref = CMU::Netdb::list_trunkset_vlan_presence($dbh, $user, "trunkset_vlan_presence.trunk_set = \'$ts_id\'");
      my $nvks = -1;
      my (%vlans, @vlan);
      if (ref $sref) {
	  %vlans = %$sref;
	  @vlan = sort {$vlans{$a} cmp $vlans{$b} } keys %vlans;
	  $nvks = keys %vlans;
	  map {push(@vlan_arr,$_) } @vlan;
      }
  }

  my $svks = -1;
  my (%subnets, @ks, @snet);
  foreach my $v_id (@vlan_arr) {
      $sref = CMU::Netdb::get_subnet_vlan_presence($dbh, $user, "vlan_subnet_presence.vlan = \'$v_id\' AND (P.rlevel >=9 OR subnet.dynamic='permit' OR subnet.dynamic='restrict' OR NOT FIND_IN_SET('no_static', subnet.flags))", 'subnet.name');
      if (ref $sref) {
	my (%subnets_local);
        %subnets_local = %$sref;
	@snet = sort {$subnets_local{$a} cmp $subnets_local{$b} } keys %subnets_local;
	# delete duplicate entries
	for (my $i = 0; $i<=$#snet; $i++) {
	    # dups
	    if (grep/^$snet[$i]$/,@ks) {
		delete $subnets_local{$snet[$i]};
		delete $snet[$i];
	    }
	}
	map {$subnets{$_} = $subnets_local{$_}} keys %subnets_local;
	map {push(@ks, $_) } @snet;
      }
  }


  $svks = keys %subnets;

  if ($svks == 1) {
    $q->param('subnetNEXT', '1');
    $q->param('subnet', $ks[0]);
    $dbh->disconnect;
    &CMU::WebInt::mach_reg_s1($q, $errors);
    return;
  }

  CMU::WebInt::setHelpFile('mach_reg_s1');
  if (CMU::WebInt::gParam($q, 'id') ne '') {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Change Subnet", $errors);
    my $hn = CMU::WebInt::gParam($q, 'h').".".CMU::WebInt::gParam($q, 'd');
    &CMU::WebInt::title("Changing Subnet") if ($hn eq '');
    &CMU::WebInt::title("Changing Subnet for Host: $hn") if ($hn ne '');
    print CMU::WebInt::errorDialog($url, $errors);
  }else{
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Machine Registration", $errors);
    print CMU::WebInt::errorDialog($url, $errors);
    print CMU::WebInt::subHeading("Register a New Machine", CMU::WebInt::pageHelpLink(''));
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print CMU::WebInt::printVerbose('machines.reg_s1', $verbose);

  print "<table border=0>

<form method=get>
<input type=hidden name=op value=mach_reg_s2>
<input type=hidden name=bmvm value=$verbose>";

  if (CMU::WebInt::gParam($q, 'id') ne '') {
    print "<input type=hidden name=id value=".CMU::WebInt::gParam($q, 'id').">
<input type=hidden name=h value=".CMU::WebInt::gParam($q, 'h').">
<input type=hidden name=d value=".CMU::WebInt::gParam($q, 'd').">";
  }

print "
<tr>".
  CMU::WebInt::printPossError(defined $errors{subnet}, $mach_p{'machine.ip_address_subnet'}, 1, 'subnet')."</tr><tr><td>";
  
  if ($nks < 1) {
    CMU::WebInt::admin_mail('machines.pm:mach_reg_s1_building', 'INFO', 'No subnets available!', {'building' => $bldg});
    print "No subnets available!\n";
  } elsif ($svks < 2) {
    # one subnet -- never reached, in theory.

    print "<input type=hidden name=subnet value=$ks[0]>
	$subnets{$ks[0]}";
  } else {
    # lots of subnets. let them choose
    unshift(@ks, '-1');
    $subnets{-1} = '--select--';
    print $q->popup_menu(-name=>'subnet',
		    -accesskey => 's',
			 -values=>\@ks,
			 -labels=>\%subnets);
  }

  print "</td></tr>
<tr><td>
<input type=hidden name=building value=$bldg>
<input type=submit value=Continue></form></td></tr>
</table>
";
  print CMU::WebInt::stdftr($q);
}

##
## Functions of this page
##
## - Select domain
## - Enter hostname
## - Select mode (static/dynamic if WRITE0) (all choices if WRITE9)
## - Enter comment (if WRITE9)
## - TTLs (if WRITE9)
## - CNAMEs
## - Protections
sub mach_reg_s2 {
  my ($q, $errors) = @_;
  my ($dbh, $url, $mac, $subnet, %errors, $userlevel);

  return mach_upd_sub_form($q, $errors) if (CMU::WebInt::gParam($q, 'id') ne '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'machine', 0);
  my $deptAll = CMU::WebInt::gParam($q, 'deptAll');
  $deptAll = 1 if ($deptAll eq 'View Complete List');
  $deptAll = 0 if ($deptAll eq '');
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  $subnet = CMU::Netdb::valid('machine.ip_address_subnet',
		  CMU::WebInt::gParam($q, 'subnet'), $user, $userlevel, $dbh);
  
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);

  if ($subnet eq '' || CMU::Netdb::getError($subnet) != 1) {
    my %errors = ('msg' => 'Error! No subnet specified.',
		  'loc' => 'mach_reg_s2',
		  'type' => 'ERR',
		  'code' => $CMU::Netdb::errcodes{ESUBNET},
		  'fields' => 'subnet');
    if (CMU::WebInt::gParam($q, 'networkNEXT') ne '' || CMU::WebInt::gParam($q, 'subnetNEXT') ne '' || CMU::WebInt::gParam($q, 'buildingNEXT') ne '') {
      CMU::WebInt::mach_reg_s0($q, \%errors);
    }else{
      $q->param('buildingNEXT', '1');
      CMU::WebInt::mach_reg_s1($q, \%errors);
    }

    $dbh->disconnect();
    return;
  }

  my $al = CMU::Netdb::get_add_level($dbh,$user,'subnet',$subnet);

  CMU::WebInt::setHelpFile('mach_reg_s2');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machine Registration", $errors);
  &CMU::WebInt::title("Register a New Machine");
  
  print CMU::WebInt::errorDialog($url, $errors);

  # QuickReg
  my $QR_Text = $CMU::WebInt::vars::htext{'quickreg.user_text'};
  print "$QR_Text<br>\n" if (CMU::WebInt::gParam($q, 'quickreg') eq '1');
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('machine', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  my $sref = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$subnet'", 'subnet.name');
  my %subnets;
  %subnets = %{$sref} if (ref $sref);

  # subnet first
  print "
<form method=get>
<input type=hidden name=op value=mach_reg_s3>
<input type=hidden deptAll value=1>
<input type=hidden name=subnet value=\"$subnet\">
<table border=0>
<tr>".CMU::WebInt::printPossError(0, $mach_p{'machine.ip_address_subnet'}, 2, 'ip_address_subnet')."</tr>
<tr><td colspan=2>".$subnets{$subnet}."</td></tr>
";

  # host
print "<tr>".CMU::WebInt::printPossError(defined $errors{host_name}, $mach_p{'machine.host_name'}, 2, 'host_name')."</tr><tr><td colspan=2>\n".
  CMU::WebInt::printVerbose('machine.host_name', $verbose).
    $q->textfield(-name => 'host').".";
  
  # domain
  my @domains = sort {$a cmp $b} @{CMU::Netdb::get_domains_for_subnet($dbh, $user, "subnet_domain.subnet = '$subnet'")};
  if ($#domains == 0) {
    print "<font size=+1>$domains[0]<input type=hidden name=domain value=\"$domains[0]\">";
  }else{
    unshift(@domains, '--select--');
    print $q->popup_menu(-name=>'domain',
			 -values=>\@domains);
  }
  print "</td></tr>";
  
  # mode
print "<tr>".CMU::WebInt::printPossError(defined $errors{mode}, $mach_p{'machine.mode'}, 2, 'mode').
"</tr><tr><td colspan=2>";
  if ($userlevel >= 9) {
    print CMU::WebInt::printVerbose('machine.mode_l9', $verbose);
  }else{
    print CMU::WebInt::printVerbose('machine.mode', $verbose);
  }
  my $modes_plus = CMU::Netdb::get_machine_modes($dbh, $user, $subnet, 1);
  {
    my $default;
    my @modes;
    if (exists $modes_plus->{'_default_mode'}) {
      $default = $modes_plus->{'_default_mode'};
      delete $modes_plus->{'_default_mode'};
    }

    @modes = keys %$modes_plus;
    if ($#modes > 0) {
      if (defined $default) {
	print $q->popup_menu(-name => 'mode',
			     -values => \@modes,
			     -default => $default);
      } else {
	print $q->popup_menu(-name => 'mode',
			     -values => \@modes);
      }
    }else{
      print "<input type=hidden name=mode value=$default>
<table border=1><tr><td>$default</td></tr></table>";
    }
    print "</td></tr>";
  }

  # mac address
  {
    my ($qrres, $qrmac) = CMU::Netdb::config::get_multi_conf_var
	('webint', 'QUICKREG_HIDE_MACADDRESS');



    my $need_mac = 0;
    my $no_mac = 0;
    foreach my $mode (keys %$modes_plus) {
      foreach my $mac_setting (keys %{$modes_plus->{$mode}}) {
	$need_mac++ if ($mac_setting eq 'required');
	$no_mac++ if ($mac_setting eq 'none');
      }
    }
    if ($need_mac) {
      print "<tr>".
	CMU::WebInt::printPossError(defined $errors{mac_address}, $mach_p{'machine.mac_address'}, 2, 'mac_address').
	    "</tr><tr><td colspan=2>".
	      CMU::WebInt::printVerbose('machine.mac_address', $verbose) .
		  $q->textfield(-name => 'mac_address');
      print " (Optional)" if ($no_mac);
      print "</td></tr>\n";
    } else {
      print "<input type=hidden name=mac_address value=''>\n";
    }
  }

  # department
  my $dtitle = '';
  $dtitle = "<input type=submit name=deptAll value=\"View Complete List\">" 
    if ($deptAll != 1);
  print "<tr>".CMU::WebInt::printPossError(defined $errors{department}, "Affiliation", 2, 'department');
  my $depts;
  if (!$deptAll) {
    $depts = CMU::Netdb::get_departments($dbh, $user, '', 'USER', $user, 'groups.description', 'GET');
  }else{
    $depts = CMU::Netdb::get_departments($dbh, $user, '', 'ALL', $user, 'groups.description', 'GET');
  }
    
  if (!ref $depts) {
    print "<tr><td colspan=2>[error]</td></tr>\n";
  }
 
  my ($dGrpRes, $defaultGroup) = CMU::Netdb::list_user_default_group($dbh, $user, $user);
  if ($dGrpRes == 1) {
    $depts->{$defaultGroup->{'group'}} = $defaultGroup->{'desc'};
  }else{
    $defaultGroup = {};
  }

  my @order = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;

  print "<tr><td colspan=2>".
    CMU::WebInt::printVerbose('machine.department', $verbose).
      $q->popup_menu(-name => 'dept',
                     -values => \@order,
                     -default => $defaultGroup->{'group'},
                     -labels => $depts)." $dtitle </td></tr>\n";
 
  ### if user is level 9 (ie network admin)

  if ($al >= 5) {
    # ip_address
    print "<tr>".CMU::WebInt::printPossError(defined $errors{ip_address}, $mach_p{'machine.ip_address'}, 2, 'ip_address').
      "</tr><tr><td colspan=2>".CMU::WebInt::printVerbose('machine.ip_address_l9', $verbose).
	$q->textfield(-name => 'ip_address')."</td></tr>";
  }

  if ($userlevel >= 9) {
    # host_name_ttl
    print "<tr>".CMU::WebInt::printPossError(defined $errors{host_name_ttl}, $mach_p{'machine.host_name_ttl'}, 2, 'host_name_ttl')."</tr><tr><td colspan=2>".
      CMU::WebInt::printVerbose('machine.host_name_ttl', $verbose).
$q->textfield(-name => 'host_name_ttl', -value => '0')."</td></tr>";

    # ip_address_ttl
    print "<tr>".
      CMU::WebInt::printPossError(defined $errors{ip_address_ttl}, $mach_p{'machine.ip_address_ttl'}, 2, 'ip_address_ttl').
"</tr><tr><td colspan=2>".
  CMU::WebInt::printVerbose('machine.ip_address_ttl', $verbose).
$q->textfield(-name => 'ip_address_ttl', -value => '0')."</td></tr>";
    
    # comment, flags
    print "<tr>".CMU::WebInt::printPossError(defined $errors{comment_lvl9}, $mach_p{'machine.comment_lvl9'}, 1, 'comments');
    print CMU::WebInt::printPossError(defined $errors{flags}, $mach_p{'machine.flags'}, 1, 'machine.flags');
    print "</tr><tr><td>";
    print $q->textfield(-name => 'comment_lvl9')."</td><td>".CMU::WebInt::printVerbose('machine.flags', $verbose);
    
    foreach(@CMU::Netdb::structure::machine_flags) {
      print $q->checkbox(-name => $_,
			 -value => 1);
    }
    print "</td></tr>\n";
  }

  print "</table>\n";

  # protections
  my $groupref = CMU::Netdb::list_memberships_of_user($dbh, $user, $user);
  # the user is not a member of any groups
  if ($#$groupref == 0) {
    print "
<input type=hidden name=IDtype0 value=0>
<input type=hidden name=ID0 value=\"$user\">
<input type=hidden name=read0 value=1>
<input type=hidden name=write0 value=1>
";
    if (defined $errors{user_perms}) {
      print "ERROR! with protections<br />";
      &CMU::WebInt::admin_mail('machines.pm:mach_reg_s2', 'WARNING',
		'Error in the protections we specify..', {});
    }
  }else{
    print "<br />".CMU::WebInt::subHeading("Protections", CMU::WebInt::pageHelpLink('protections')).
      CMU::WebInt::printVerbose('mach_reg_s2.protections', $verbose);
    if (defined $errors{user_perms}) {
      print "Error: You must specify some protections.\n";
    }
    print "
<table border=0><tr><th>Identity</th><th>Permissions</th></tr>\n";
    print CMU::WebInt::permMatrix(0, $user, 0, 1, 1);
    my $i = 1;
    if (ref $groupref) {
      foreach my $k (@$groupref) {
	next if ($k->[0] eq 'groups.id' || $k->[$CMU::WebInt::auth::groups_pos{'groups.name'}] =~ /^dept\:/);
	print CMU::WebInt::permMatrix(1, 
			 $k->[$CMU::WebInt::auth::groups_pos{'groups.name'}], 
			 $i++, 0, 0);
      }
    }
    print "<tr><td><input type=text name=ID$i>
<input type=hidden name=IDtype$i value=0></td>
<td>Read: <input type=checkbox name=read$i value=1> Write: <input type=checkbox name=write$i value=1></td></tr>\n";

  print "</table>\n";
  }
  print "<input type=submit value=\"Continue\">\n";

  $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);
}

## 
## Functions of this page
## - Add the host to the database, if everything checks out
## FIXME: Verify each component of this registration and send them back
## to mach_reg_s2 with any errors
sub mach_reg_s3 {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  if (CMU::WebInt::gParam($q, 'deptAll') eq 'View Complete List') {
    CMU::WebInt::mach_reg_s2($q, $errors);
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'machine', 0);
  my $url = $ENV{SCRIPT_NAME};
  if ($userlevel >= 9) {
  # Level 9 fields
    %fields = ('mac_address' => CMU::WebInt::gParam($q, 'mac_address'),
	       'host_name' => CMU::WebInt::gParam($q, 'host').'.'.CMU::WebInt::gParam($q, 'domain'),
	       'mode' => CMU::WebInt::gParam($q, 'mode'),
	       'comment_lvl9' => CMU::WebInt::gParam($q, 'comment_lvl9'),
	       'host_name_ttl' => CMU::WebInt::gParam($q, 'host_name_ttl'),
	       'ip_address_ttl' => CMU::WebInt::gParam($q, 'ip_address_ttl'),
	       'ip_address_subnet' => CMU::WebInt::gParam($q, 'subnet'),
	       'dept' => CMU::WebInt::gParam($q, 'dept'),
	      );
    my $al = CMU::Netdb::get_add_level($dbh,$user,'subnet',$fields{'ip_address_subnet'});
    if ($al >= 5) {
      $fields{'ip_address'} = CMU::WebInt::gParam($q, 'ip_address');
    }

    $fields{'flags'} = join(',', map { $_ if (CMU::WebInt::gParam($q, $_) eq '1') } (@CMU::Netdb::structure::machine_flags));
  }else{
    # Level 1 fields
    %fields = ('mac_address' => CMU::WebInt::gParam($q, 'mac_address'),
	       'host_name' => CMU::WebInt::gParam($q, 'host').'.'.CMU::WebInt::gParam($q, 'domain'),
	       'ip_address_subnet' => CMU::WebInt::gParam($q, 'subnet'),
	       'mode' => CMU::WebInt::gParam($q, 'mode'),
	       'dept' => CMU::WebInt::gParam($q, 'dept')
	      );
    my $al = CMU::Netdb::get_add_level($dbh,$user,'subnet',$fields{'ip_address_subnet'});
    if ($al >= 5) {
      $fields{'ip_address'} = CMU::WebInt::gParam($q, 'ip_address');
    }
  }


  my @permIDs = grep (/IDtype/, $q->param());
  my %perms;
  my $success = 0;
 
  if ($fields{'mode'} eq 'secondary') {
    # find the primary
    my $maref = CMU::Netdb::list_machines($dbh, $user, "machine.mac_address = '$fields{'mac_address'}' && machine.ip_address_subnet = $fields{'ip_address_subnet'} && machine.mode != 'secondary'");

    if (ref $maref && defined $maref->[1]) {
      # suck up its protections
      my $prot = CMU::Netdb::list_protections($dbh, $user, 'machine', $maref->[1][$machine_pos{'machine.id'}], "");

      # and add them instead
      if (ref $prot) {
        map {
          $perms{$_->[1]} = [$_->[2],$_->[3]];
        } @$prot;
        $success = 1;
      }
    }
  }

  if ($success == 0) {
    foreach(@permIDs) {
      /IDtype(\d+)/;
      my $accum .= "READ," if (CMU::WebInt::gParam($q, "read$1") eq '1');
      $accum .= "WRITE," if (CMU::WebInt::gParam($q, "write$1") eq '1');
      my $nlevel = CMU::WebInt::gParam($q, "level$1");
      $nlevel = 1 if ($nlevel eq '');
      $nlevel = $userlevel if ($nlevel > $userlevel);
      chop($accum);
      next if ($accum eq '');
      $perms{CMU::WebInt::gParam($q, "ID$1")} = [$accum, $nlevel];
    }
  }

  my ($res, $errfields) = CMU::Netdb::add_machine($dbh, $user, $userlevel, \%fields, \%perms);

  if ($res > 0) {
    my ($mtres, $MachRegText) = CMU::Netdb::config::get_multi_conf_var
	('webint', 'MachineRegText');

    my $msg = "Your computer has now been registered:<br><br> ".
	"<a href=\"$url?op=mach_view&id=$$errfields{insertID}\">".
         "$$errfields{host_name}</a>.";
    if ($mtres == 1 && $MachRegText ne '') {
       $msg .= "<br>$MachRegText";
    }
#    $q->param('id', $warns{insertID});
    $dbh->disconnect();
    &CMU::WebInt::mach_list($q, {'msg' => $msg});
  }else{
    if ($res <= 0) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0 && 
					       ref $errfields eq 'ARRAY');
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] ";
      $nerrors{'msg'} .= "(".join(',', @$errfields).") " if (ref $errfields eq 'ARRAY'); 
      $nerrors{'loc'} = 'mach_reg_s3',
      $nerrors{'type'} = 'ERR';
      $nerrors{'fields'} = join(',', @$errfields) if (ref $errfields eq 'ARRAY');
      $nerrors{'code'} = $res;
    }
    $dbh->disconnect();
    &CMU::WebInt::mach_reg_s2($q, \%nerrors);
  }
}

sub mach_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines", $errors);
  &CMU::WebInt::title('Machine Information');
  $id = CMU::WebInt::gParam($q, 'id');
  my $deptAll = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'deptAll'));
  $deptAll = 0 if ($deptAll eq '');
  my $adv = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'adv'));
  $adv = 0 if ($adv eq '');
  my $verbose = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'bmvm'));
  $verbose = 1 if ($verbose ne '0');

  $$errors{msg} = "Machine ID not specified!" if ($id eq '');

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'machine', $id);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'machine', $id);
  
  $deptAll = 1 if ($wl >= 9);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('machine', 'READ', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<hr>".CMU::WebInt::errorDialog($url, $errors);

  ## *********************************************************************
  ## DNS Resources / DHCP options -- figure out if any exist
  ## and override $adv if so.

  # DNS
  my $DNSquery = "dns_resource.owner_type = 'machine' AND dns_resource.owner_tid = '$id'";
  my $ldrr = CMU::Netdb::list_dns_resources($dbh, 'netreg', $DNSquery);
  if (!ref $ldrr) {
    print "Unable to list DNS resources.\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Unable to list DNS resources.', 
		{ 'id' => $id});
  }

  # DHCP

  my $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid='$id' and dhcp_option.type = 'machine'");
  
  if (!ref $ldor) {
    print "Unable to list DHCP Options.\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Unable to list DHCP options.',
		{'id' => $id });
  }elsif($#$ldor > 0) {
    $adv = 1;
  }

  # service groups
  my $servicequery = "service_membership.member_type = 'machine' AND ".
    "service_membership.member_tid = '$id'";
  my ($lsmr, $rMemRow, $rMemSum, $rMemData) = 
    CMU::Netdb::list_service_members($dbh, 'netreg', $servicequery);
  if ($lsmr < 0) {
    print "Unable to list Service Groups ($lsmr).\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
			     'Unable to list Service Groups ($lsmr).', 
			     { 'id' => $id});
  }

  # trunkset presences
  my ($tsver, $tsen) = CMU::Netdb::config::get_multi_conf_var
			('webint', 'ENABLE_TRUNK_SET');
  my $tsref;
  if ($tsen == 1) {
    $tsref = CMU::Netdb::list_trunkset_presences($dbh, $user, 'machine', "trunkset_machine_presence.device = $id");
    if (!ref $tsref) {
      print "Unable to list trunkset presences ($tsref).\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
			       'Unable to list trunkset presences ($tsref).', 
			       { 'id' => $id});
    }
  }

  ## *************************************************************8

  # basic machine information
  my $sref = CMU::Netdb::list_machines($dbh, $user, "machine.id='$id'");
  if (!defined $sref->[1]) {
    print "Machine not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  my $sul = CMU::Netdb::get_add_level($dbh,$user,'subnet',$sdata[$machine_pos{'machine.ip_address_subnet'}]);
  my $version = $sdata[$machine_pos{'machine.version'}];
  my $mode = $sdata[$machine_pos{'machine.mode'}];
  if ($sdata[$machine_pos{'machine.mode'}] eq 'dynamic') {
    print CMU::WebInt::subHeading("Information for Dynamic Host (MAC ".$sdata[$machine_pos{'machine.mac_address'}].")", CMU::WebInt::pageHelpLink(''));
  }else{
    print CMU::WebInt::subHeading("Information for: ".$sdata[$machine_pos{'machine.host_name'}], CMU::WebInt::pageHelpLink(''));
  }
  { 
    my $pr = "[<a tabindex=\"90\" href=$url?op=mach_view&id=$id&deptAll=$deptAll&adv=$adv><b>Refresh</b></a>]";
    $pr .= "[<a tabindex=\"90\" href=$url?op=prot_s3&table=machine&tidType=1&tid=$id><b>View/Update Protections</b></a>]" if ($mode ne 'secondary');
    $pr .= "[<a tabindex=\"90\" href=\"".CMU::WebInt::encURL("$url?op=mach_del&id=$id&version=$version")."\"><b>Delete Machine</b></a>]" if ($wl >= 1);
    $pr .= "<br />";
    $pr .= "[<a tabindex=\"90\" href=$url?op=mach_view&id=$id&deptAll=$deptAll&adv=1><b>View Advanced Options</b></a>]" if ($adv != 1);
    $pr .= "[<a tabindex=\"90\" href=$url?op=mach_conf_view&id=$id><b>View Network Configuration Information</b></a>]" if ($mode eq "static");
    $pr .= "<br />[<a tabindex=\"90\" href=$url?op=history&tname=machine&row=$id><b>Show History</b></a>]"
      if (CMU::Netdb::get_user_admin_status($dbh, $user) == 1);
    my $spec = CMU::Netdb::list_attribute_spec_ref($dbh, $user, "attribute_spec.name  = 'Extra Menu Item' AND attribute_spec.scope = 'subnet'", "attribute_spec.name");
    if (ref $spec && scalar(keys(%$spec)) == 1) {
      my $attrs = CMU::Netdb::list_attribute($dbh, $user, 
					     "attribute.owner_table = 'subnet' AND attribute.owner_tid = ".$sdata[$machine_pos{'machine.ip_address_subnet'}]
					     . " AND attribute_spec.name = 'Extra Menu Item' ORDER BY attribute.id");
      my $attrmap = CMU::Netdb::makemap($attrs->[0]);
      shift @$attrs;
      foreach my $a (@$attrs) {
	my $output = $a->[$attrmap->{'attribute.data'}];
	warn __FILE__, ':', __LINE__, " :> Found extra menu item '$output'" if ($debug >= 2);
	$output =~ s/(?<!\%)\%id/$id/;
	my $host = $sdata[$machine_pos{'machine.host_name'}];
	$output =~ s/(?<!\%)\%hostname/$host/;
	my $ip = CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}]);
	$output =~ s/(?<!\%)\%ip/$ip/;
	$output =~ s/(?<!\%$)\%amp/\&/g;
	$output =~ s/\%\%/\%/g;
	warn __FILE__, ':', __LINE__, " :> Expanded extra menu item '$output'" if ($debug >= 2);
	$pr .= $output;
      }
    }

    print CMU::WebInt::smallRight($pr);
  }
  CMU::WebInt::printVerbose('machine.view_general', $verbose);
  
  # start the madness..
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=mach_upd>
<input type=hidden name=version value=\"".$sdata[$machine_pos{'machine.version'}]."\">";

  # host name/domain
  my ($host, $domain) = CMU::Netdb::splitHostname($sdata[$machine_pos{'machine.host_name'}]);
  print "<tr>".CMU::WebInt::printPossError(defined $errors->{'host_name'} || 
			      defined $errors->{'domain'}, $mach_p{'machine.host_name'}, 2, 'host_name').
				"</tr>";

  my $domainAllowed = CMU::Netdb::get_domains_for_subnet($dbh, $user, 
					     "subnet_domain.subnet='$sdata[$machine_pos{'machine.ip_address_subnet'}]'");
  
  $q->delete('host_name');
  $q->param('host_name', $host);
  $q->param('domain', $domain);
  my $domainPrint;
  if ($domain eq "" || grep ($_ eq $domain, @$domainAllowed)) {
    my @sorteddomains = sort @$domainAllowed;
    $domainPrint = $q->popup_menu(-name => 'domain', -default => $domain, -values => \@sorteddomains, -tabindex => "10");
  }else{
    $domainPrint = "<input type=hidden name=domain value=$domain>$domain\n";
  }
  print "<tr><td colspan=2>".CMU::WebInt::printVerbose('machine.host_name', $verbose);
  if ($wl > 0) {
    print $q->textfield(-name => 'host_name', -accesskey => 'h', -tabindex => "10").'.'.$domainPrint;
  }else{
    print '<table border=1><tr><td>'.$host.'.'.$domain.'</td></tr></table>';
  }
  print "</td></tr>\n";
  
  # mac address / subnet
  my $sbnref = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$sdata[$machine_pos{'machine.ip_address_subnet'}]'", 'subnet.name');
  my $smsg;
  if (!ref $sbnref) {
    $smsg = "Error loading subnet.";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Error loading subnet.', 
		{'subnet.id' => $sdata[$machine_pos{'machine.ip_address_subnet'}]});
  }else{
    $smsg = "<a href=$url?op=sub_info&sid=$sdata[$machine_pos{'machine.ip_address_subnet'}]>" . $$sbnref{$sdata[$machine_pos{'machine.ip_address_subnet'}]} . "</a>".

      ($wl >= 1 ? " [<a tabindex=\"10\" href=$url?op=mach_reg&id=$id&h=$host&d=$domain>Change</a>]\n" :
       '');
  }
  $q->param('mac_address', $sdata[$machine_pos{'machine.mac_address'}]);

  my $modes_plus = CMU::Netdb::get_machine_modes($dbh, $user, $sdata[$machine_pos{'machine.ip_address_subnet'}], 1);
  delete $modes_plus->{'_default_mode'};

  my $need_mac = 0;
  my $no_mac = 0;
  foreach my $mode (keys %$modes_plus) {
    foreach my $mac_setting (keys %{$modes_plus->{$mode}}) {
      $need_mac++ if ($mac_setting eq 'required');
      $no_mac++ if ($mac_setting eq 'none');
    }
  }

  if ($verbose) {
    if ($need_mac) {
      print "<tr>".CMU::WebInt::printPossError(defined $errors->{'mac_address'}, 
					       $mach_p{'machine.mac_address'}, 2, 
					       'mac_address')."</tr><tr><td colspan=2>";
      print CMU::WebInt::printVerbose('machine.mac_address', 1);
      if ($wl > 0) {
	if ($no_mac) {
	  print $q->textfield(-name => 'mac_address', -accesskey => 'h',
			      -value => $sdata[$machine_pos{'machine.mac_address'}], -tabindex => "10")
	    . " (Optional)";
	} else {
	  print $q->textfield(-name => 'mac_address', -accesskey => 'h',
			      -value => $sdata[$machine_pos{'machine.mac_address'}], -tabindex => "10");
	}
      } else {
	print $sdata[$machine_pos{'machine.mac_address'}]."</td></tr>";
      }
    } else {
      print "<input type=hidden name=mac_address value=''>\n";
    }
    print "<tr>". 
      CMU::WebInt::printPossError(defined $errors->{'ip_address_subnet'},
				  $mach_p{'machine.ip_address_subnet'}, 2, 
				  'ip_address_subnet')."</tr><tr><td colspan=2>";
    print CMU::WebInt::printVerbose('machine.ip_address_subnet', $verbose).
      "<table border=2><tr><td colspan=2>$smsg</td></tr></table></td></tr>";

  }else{
    print "<tr>";
    if ($need_mac) {
      print CMU::WebInt::printPossError(defined $errors->{'mac_address'}, 
					$mach_p{'machine.mac_address'}, 1, 'mac_address');
    }
    print CMU::WebInt::printPossError(defined $errors->{'ip_address_subnet'}, 
				      $mach_p{'machine.ip_address_subnet'}, 1, 'subnet');
    print "</tr><tr>";
    if ($need_mac) {
      print "<td>";
      if ($wl > 0) {
	print $q->textfield(-name => 'mac_address', -accesskey => 'u',
			    -value => $sdata[$machine_pos{'machine.mac_address'}], -tabindex => "10");
	print " (Optional)" if ($no_mac);
      }else{
	print '<table border=1><tr><td>'.
	  $sdata[$machine_pos{'machine.mac_address'}].
	    '</td></tr></table>';
      }
      print "</td>";
    } else {
      print "<input type=hidden name=mac_address value=''>\n";
    }
    print "<td>$smsg</td></tr>";
  }

  # IP address / mode
  if ($verbose) {
    print "<tr>".
      CMU::WebInt::printPossError(defined $errors->{'ip_address'}, 
		     $mach_p{'machine.ip_address'}, 2, 'ip_address') .
		       "</tr><tr><td colspan=2>";
    if ($wl < 9 && $sul < 5) {
      print CMU::WebInt::printVerbose('machine.ip_address', $verbose);
      print "<table border=1><tr><td>".
        CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}]).
          "</td></tr></table>";
    } else {
      print CMU::WebInt::printVerbose('machine.ip_address_l9', $verbose);
      $q->param('ip_address', CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}])); 
      print $q->textfield(-name => 'ip_address', -accesskey => 'i',
			  -value => CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}]), -tabindex => "10");
    }
    print "</td></tr>\n";
    print "<tr>".CMU::WebInt::printPossError(defined $errors->{'mode'}, 
				$mach_p{'machine.mode'}, 2, 'mode').
      "</tr><tr><td colspan=2>".CMU::WebInt::printVerbose('machine.mode', 1);
    $q->param('mode', $mode);
    my @modes = keys %$modes_plus;
    push(@modes, $mode) if (!grep ($_ eq $mode, @modes));
    my $modestr = ($wl >= 1 ? 
     $q->popup_menu(-name => 'mode',
		    -accesskey => 'm',
		    -default => $mode,
		    -values => \@modes, 
		    -tabindex => "10")
     : "<table border=1><tr><td>$mode</td></tr></table>")."</td></tr>\n";
    print $modestr;
  }else{
    print "
<tr>".
  CMU::WebInt::printPossError(defined $errors->{'ip_address'}, 
		 $mach_p{'machine.ip_address'}, 1, 'ip_address').
    CMU::WebInt::printPossError(defined $errors->{'mode'}, 
		   $mach_p{'machine.mode'}, 1, 'ip_address').
      "</tr>";
    print "<tr><td>";
    print "<table border=1><tr><td>".
      CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}]).
	"</td></tr></table>" if ($wl < 9);
    if ($wl >= 9) {
      $q->param('ip_address', CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}])); 
      print $q->textfield(-name => 'ip_address', -accesskey => 'i',
			  -value => CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}]),
			  -tabindex => "10");
    }
    $q->param('mode', $mode);
    my @modes = keys %$modes_plus;
    print "</td><td>";
    push(@modes, $mode) if (!grep ($_ eq $mode, @modes));
    if ($wl >= 1) {
      print $q->popup_menu(-name => 'mode',
			   -accesskey => 'm',
			   -default => $mode,
			   -values => \@modes, 
			   -tabindex => "10");
    }else{
      print "<table border=1><tr><td>$mode</td></tr><tr>";
    }
    print "</td></tr>\n";
  }
  print "<tr>".
    CMU::WebInt::printPossError(defined $errors->{'comment_lvl1'}, $mach_p{'machine.comment_lvl1'}, 1, 'comment_lvl1');
  print CMU::WebInt::printPossError(defined $errors->{'comment_lvl5'}, $mach_p{'machine.comment_lvl5'}, 1, 'comment_lvl5') if ($ul >= 5);
  print "</tr>";

  my $sz = length($sdata[$machine_pos{'machine.comment_lvl1'}]);
  $sz = 20 if ($sz < 20);
  $q->param('comment_lvl1', $sdata[$machine_pos{'machine.comment_lvl1'}]);
  print "<tr><td>".CMU::WebInt::printVerbose('machine.comment_lvl1', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name => 'comment_lvl1',
			-accesskey => 'u',
			-value => $sdata[$machine_pos{'machine.comment_lvl1'}],
			-size => $sz, -tabindex => "10");
  }else{
    print '<table border=1><tr><td>'.$sdata[$machine_pos{'machine.comment_lvl1'}].
      '</td></tr></table>';
  }
  print "</td>\n";

  if ($ul >= 5) {
    $sz = length($sdata[$machine_pos{'machine.comment_lvl5'}]);
    $sz = 20 if ($sz < 20);
    $q->param('comment_lvl5', $sdata[$machine_pos{'machine.comment_lvl5'}]);
    print "<td>".CMU::WebInt::printVerbose('machine.comment_lvl5', $verbose);
    if ($wl >= 5) {
      print $q->textfield(-name => 'comment_lvl5', -accesskey => 'd',
			  -value => $sdata[$machine_pos{'machine.comment_lvl5'}],
			  -size => $sz, 
			  -tabindex => "10");
    }else{
      print '<table border=1><tr><td>'.
	$sdata[$machine_pos{'machine.comment_lvl5'}].'</tr></td></table>';
    }
    print "</td></tr>\n";

  } else {
    print "</tr>\n";
  }

  if ($ul >= 5 && $ul < 9) {
    print "<tr>".
	CMU::WebInt::printPossError(defined $errors->{'flags'}, 
				    $mach_p{'machine.flags'}, 2, 
				    'machine.flags')."\n</tr>\n<tr><td colspan=2>";
      print CMU::WebInt::printVerbose('machine.flags_l5', $verbose);
      print "<b>Flags: ";
      my $nflags = 0;
      foreach(@CMU::Netdb::structure::machine_flags) {
	if ($sdata[$machine_pos{'machine.flags'}] =~ /$_/) {
	  print "," if ($nflags > 0);
	  print " $_";
	  $nflags++;
	}
      }
      print "[None]" if ($nflags == 0);
      print "</b></td></tr>\n";
  }elsif ($ul >= 9) {
    # flags / comment
    print "<tr>".
      CMU::WebInt::printPossError(defined $errors->{'comment_lvl9'}, 
				  $mach_p{'machine.comment_lvl9'}, 1, 
				  'comment_lvl9');
    print CMU::WebInt::printPossError(defined $errors->{'flags'}, 
				      $mach_p{'machine.flags'}, 1, 
				      'machine.flags')."</tr>";
    print "<tr>";

    my $sz = length($sdata[$machine_pos{'machine.comment_lvl9'}]);
    $sz = 20 if ($sz < 20);
    $q->param('comment_lvl9', $sdata[$machine_pos{'machine.comment_lvl9'}]);
    print "<td>".CMU::WebInt::printVerbose('machine.comment_lvl9', $verbose);
    if ($wl >= 9) {
      print $q->textfield(-name => 'comment_lvl9', -accesskey => 'a',
			  -value => $sdata[$machine_pos{'machine.comment_lvl9'}],
			  -size => $sz, 
			  -tabindex => "10");
    }else{
      print '<table border=1><tr><td>'.
	$sdata[$machine_pos{'machine.comment_lvl9'}].'</td></tr></table>';
    }
    print "</td><td>\n";

    print CMU::WebInt::printVerbose('machine.flags', $verbose);

    foreach(@CMU::Netdb::structure::machine_flags) {
      print $q->checkbox
	(-name => $_,
	 -value => 1,
	 -tabindex => "10",
	 -checked => ($sdata[$machine_pos{'machine.flags'}] =~ /$_/));

    }
    print "</td></tr>\n";

    # TTLs;
    print "\n<tr>".
      CMU::WebInt::printPossError(defined $errors->{'host_name_ttl'}, $mach_p{'machine.host_name_ttl'}, 1, 'host_name_ttl').
	CMU::WebInt::printPossError(defined $errors->{'ip_address_ttl'}, $mach_p{'machine.ip_address_ttl'}, 1, 'ip_address_ttl').
	  "</tr>";
    $q->param('host_name_ttl', $sdata[$machine_pos{'machine.host_name_ttl'}]);
    $q->param('ip_address_ttl', $sdata[$machine_pos{'machine.ip_address_ttl'}]);
    print "<tr><td>".CMU::WebInt::printVerbose('machine.host_name_ttl', $verbose).
      ($wl >= 9 ?
       $q->textfield(-name => 'host_name_ttl', -accesskey => 'h',
		     -value => $sdata[$machine_pos{'machine.host_name_ttl'}], 
		     -tabindex => "10")
       : $sdata[$machine_pos{'machine.host_name_ttl'}])."
</td><td>".CMU::WebInt::printVerbose('machine.ip_address_ttl', $verbose).
  ($wl >= 9 ? $q->textfield(-name => 'ip_address_ttl', -accesskey => 'i',
			    -value => $sdata[$machine_pos{'machine.ip_address_ttl'}], 
			    -tabindex => "10")
   : $sdata[$machine_pos{'machine.ip_address_ttl'}])."</td></tr>\n";
    
  }
  # expire
  if ($sdata[$machine_pos{'machine.expires'}] ne '0000-00-00') {
    print "<tr>".CMU::WebInt::printPossError(0, $mach_p{'machine.expires'}, 1, 'expires')."</tr>
   <tr>".
       "<td>".CMU::WebInt::printVerbose('machine.expires', $verbose).
	 $sdata[$machine_pos{'machine.expires'}];
    print " <font face=\"Arial,Helvetica,Geneva,Charter\" size=+1>[<b><a tabindex=\"90\" href=\"".CMU::WebInt::encURL("$url?op=mach_unexpire&id=$id&version=$version")."\">Retain</a></b>]</font>\n" if ($wl >= 1);
    print "</td></tr>\n";
  }

  # department
  { 
    my $cdref = CMU::Netdb::list_protections($dbh, $user, 'machine', $id);
    my @cdept;

    my $dtitle = '';
    $dtitle .= "<font face=\"Arial,Helevetica,Geneva,Charter\">[<b><a tabindex=\"90\" href=$url?op=mach_view&id=$id&deptAll=1>View complete list</a></b>]\n" if ($deptAll ne '1');
    print "<tr>".CMU::WebInt::printPossError(defined $errors->{'department'}, 'Affiliation', 2, 'department')."</tr>";
    if (!ref $cdref) {
      @cdept = ('[error]','[error]');
      &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Error in list_protections.', {});
    }else{
      map { @cdept = ($_->[1],'') if ($_->[1] =~ /^dept:/); } @$cdref;
    }

    $cdref = CMU::Netdb::list_groups($dbh, $user, "groups.name=\"$cdept[0]\"");
    if (!ref $cdref) {
      @cdept = ('[error]','[Unable to determine current affiliation]');
      &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Error in list_protections.', {});
    }

    $cdept[1] = $cdref->[1]->[$CMU::WebInt::auth::groups_pos{'groups.description'}];
    if ($wl < 1) {
      print "<tr><td colspan=2>$cdept[1]</td></tr>\n";
    }else{
      my $depts;
      if ($deptAll eq '1') {
	$depts = CMU::Netdb::get_departments($dbh, $user, '', 'ALL', '', 'groups.description', 'GET');
      }else{ 
	$depts = CMU::Netdb::get_departments($dbh, $user, '', 'USER', $user, 'groups.description', 'GET');
      }
      if (!ref $depts)  {
	print "<tr><td colspan=2>".CMU::WebInt::printVerbose('machine.department', $verbose)."
	  $cdept[1]<input type=hidden name=dept value=$cdept[0]></td></tr>\n";
      }else{
	$depts->{$cdept[0]} = $cdept[1];
	my @order = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;
	
	print "<tr><td colspan=2>".CMU::WebInt::printVerbose('machine.department', $verbose).
	  $q->popup_menu(-name => 'dept',
			 -accesskey => 'a',
			 -values => \@order,
			 -default => $cdept[0],
			 -labels => $depts, 
			 -tabindex => "10").$dtitle;
	print "</td></tr>\n";
      }
    }
  }
  
  # created / last updated
  print "<tr>".CMU::WebInt::printPossError(0, $mach_p{'machine.created'}).
    CMU::WebInt::printPossError(0, $mach_p{'machine.version'})."</tr><tr><td>".
      $sdata[$machine_pos{'machine.created'}]."</td><td>";
   my $updDate;
  if ($sdata[$machine_pos{'machine.version'}] =~ /(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
    $updDate = "$1-$2-$3 $4:$5:$6\n";
  } else {
    $updDate = $sdata[$machine_pos{'machine.version'}];
  }
  print $updDate."</td></tr>\n";

  print "<tr><td colspan=2>".($wl >= 1 ? $q->submit(-value=>'Update', -tabindex => "10") : '')."</td></tr>\n";
  
  print "</table></form>\n";

  ## SECONDARY IP'S
  if ($sdata[$machine_pos{'machine.mode'}] eq 'static' || $sdata[$machine_pos{'machine.mode'}] eq 'reserved') {
    my $saref = &CMU::Netdb::list_machines($dbh,$user,"machine.mac_address='$sdata[$machine_pos{'machine.mac_address'}]' AND machine.mode='secondary' AND machine.ip_address_subnet=$sdata[$machine_pos{'machine.ip_address_subnet'}] ORDER by machine.host_name");	 
    my @modes = keys %$modes_plus;
    if (($adv == 1 && grep(/^secondary$/,@modes)) || $#$saref > 0) {
      print CMU::WebInt::subHeading("Secondary IP Addresses",(grep(/^secondary$/,@modes)?"<A tabindex=\"90\" HREF=\"$url?op=mach_reg_s1&domain=$domain&subnetNEXT=continue&subnet=".$sdata[$machine_pos{'machine.ip_address_subnet'}]."&mode=secondary&mac_address=".$sdata[$machine_pos{'machine.mac_address'}]."\">Add Secondary IP</A>":""));
      print CMU::WebInt::printVerbose('machine.secondary_ip_address', $verbose) if ($wl < 9);
      print CMU::WebInt::printVerbose('machine.secondary_ip_address_l9', $verbose) if ($wl >= 9);
      CMU::WebInt::generic_tprint($url,$saref,['machine.host_name'],[\&mach_cb_print_IP],{'q' => $q},
                                  "mach_view&id=$id","op=mach_view&id=",\%machine_pos,
                                  \%CMU::Netdb::structure::machine_printable,'machine.host_name','machine.id','',[]);
      print "<BR />";
    }
  } elsif ($sdata[$machine_pos{'machine.mode'}] eq 'secondary') {
    print CMU::WebInt::subHeading("Secondary IP Addresses","");
    my $saref = &CMU::Netdb::list_machines($dbh,$user,"machine.mac_address='$sdata[$machine_pos{'machine.mac_address'}]' AND machine.mode!='secondary' AND machine.ip_address_subnet=$sdata[$machine_pos{'machine.ip_address_subnet'}] ORDER by machine.host_name");
    print "This machine is secondary to <A tabindex=\"90\" HREF=\"$url?op=mach_view&id=$saref->[1][$machine_pos{'machine.id'}]\">$saref->[1][$machine_pos{'machine.host_name'}] (".CMU::Netdb::long2dot($saref->[1][$machine_pos{'machine.ip_address'}]).")</A>";
  }

  ## DNS Resources
  if (($#$ldrr > 0) || ($adv == 1)) {
    print CMU::WebInt::subHeading("DNS Resources", "<a tabindex=\"90\" href=\"$url?op=mach_dns_res_add&owner_tid=$id&host=$host.$domain&owner_type=machine\">Add DNS Resource</a>\n");
    print CMU::WebInt::printVerbose('mach_view.dns_resources');
    
    if($#$ldrr == 0) {
      print "[There are no DNS resources for this host.]\n";
    }else{
      print "<table border=0><tr bgcolor=".$TACOLOR.">";
      print "<td><b>Type</b></td><td colspan=2><b>Options</b></td>";
      print "<td><b>Delete</b></td>" if ($wl >= 1);
      print "</tr>\n";
      
      my $i = 1;
      my ($Res, $Type);
      my %pos = %CMU::WebInt::dns::dns_r_pos;
      my $FS = $CMU::WebInt::interface::SMFONT;
      while($Res = $$ldrr[$i]) {
	print "<tr>" if ($i % 2 == 1);
	print "<tr bgcolor=".$TACOLOR.">" if ($i % 2 == 0);
	$i++;
	## Customized code for DNS resource types
	$Type = $$Res[$pos{'dns_resource.type'}];
	if ($Type eq 'CNAME' || $Type eq 'ANAME') {
	  print "<td><B>$Type</B></TD>\n";
	  if ($$Res[$pos{'dns_resource.name'}] eq "$host.$domain") {
	    # error
	    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'ERROR',
		        'CNAME/ANAME Error', 
                       {'Registered machine' => "$host.$domain",
                        'name' => $$Res[$pos{'dns_resource.name'}],
                        'rname' => $$Res[$pos{'dns_resource.rname'}],
                        'id' => $$Res[$pos{'dns_resource.id'}]});

        }elsif($Type eq 'RP') {
	  print "<td><b>RP</b></td>\n";
          my $t0 = $$Res[$pos{'dns_resource.text0'}];
          $t0 =~ s/\./\@/;
          my $t1 = $$Res[$pos{'dns_resource.text1'}];
          print "<td>${FS}Contact: $t0</td><td>Text Info Record: $t1</td>\n";
	    print "<td colspan=2>[error]</td>\n";
	  }else{
	    print "<td>${FS}Name: $$Res[$pos{'dns_resource.name'}]</td>\n".
	      "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
	  }
	}elsif($Type eq 'NS') {
	  print "<td><B>NS</B></TD>\n";
	  print "<td>${FS}Nameserver: $$Res[$pos{'dns_resource.rname'}]<br />".
	    "Host/domain: $$Res[$pos{'dns_resource.name'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
	}elsif($Type eq 'MX') {
	  print "<td><B>MX</B></TD>\n";
	  print "<td>${FS}Mail exchanger: $$Res[$pos{'dns_resource.rname'}]<br />".
	    "Host/domain: $$Res[$pos{'dns_resource.name'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]<BR />\n".
	    "Metric: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
	}elsif($Type eq 'TXT') {
	  print "<td><b>TXT</b></td>\n";
	  print "<td>${FS}Text Information: $$Res[$pos{'dns_resource.text0'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td><BR />\n";
	}elsif($Type eq 'HINFO') {
	  print "<td><b>HINFO</b></td>\n";
	  print "<td>${FS}Field 0: $$Res[$pos{'dns_resource.text0'}]<br />".
	    "Field 1: $$Res[$pos{'dns_resource.text1'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
	}elsif($Type eq 'SRV') {
	  print "<td><b>SRV</b></td>\n";
	  print "<td>${FS}Resource/Port: $$Res[$pos{'dns_resource.name'}] / $$Res[$pos{'dns_resource.rport'}]<br />".
	    "Priority: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]<br />".
	    "Weight: $$Res[$pos{'dns_resource.rmetric1'}]</td>\n";
	}elsif($Type eq 'AFSDB') {
	  print "<td><b>AFSDB</b></td>\n";
	  print "<td>${FS}DB Server: $$Res[$pos{'dns_resource.rname'}]</td>";
	  print "<td>Type: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
	}elsif($Type eq 'AAAA') {
	  print "<td><b>AAAA</b></td>\n";
	  print "<td>${FS}IPv6 Address: $$Res[$pos{'dns_resource.text0'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td><BR />\n";
	}elsif($Type eq 'LOC') {
          print "<td><b>LOC</b></td>\n";
          print "<td>${FS}Location: $$Res[$pos{'dns_resource.text0'}]</td>\n";
          print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td><BR />\n";
        }else{
	  print "<td><b>$Type</b></td><td colspan=2>[no format information]</td>\n";
	}
        print "<td><a tabindex=\"90\" href=\"".CMU::WebInt::encURL("$url?op=mach_dns_res_del&id=$$Res[$pos{'dns_resource.id'}]&version=$$Res[$pos{'dns_resource.version'}]&owner_type=machine&owner_tid=$id")."\">Delete</a></td>\n" if ($wl >= 1);
	print "</tr>\n";
      }
      print "</table>\n";
    }

    print "<br /><br />\n";
  }
  if ($adv == 1) {
    ## DHCP Options
    print CMU::WebInt::subHeading
      ("DHCP Options", 
       "<a tabindex=\"90\" href=\"$url?op=mach_dhcp_add&type=machine&tid=$id".
       "&printable=$host.$domain\">Add DHCP Option</a>\n");
    
    print CMU::WebInt::printVerbose('mach_view.dhcp_options');
    
    if($#$ldor == 0) {
      print "[There are no DHCP options for this host.]\n";
    }else{
      CMU::WebInt::generic_tprint($url, $ldor, 
		     ['dhcp_option_type.name', 'dhcp_option.value'],
		     [\&mach_cb_dhcp_opt_del],
		     "machine&tid=$id", '', '', \%CMU::WebInt::dhcp::dhcp_o_c_pos, 
		     \%CMU::Netdb::structure::dhcp_option_printable,
		     '', '', '', []);
    }
    
  }

  # Service Group
  if ($lsmr > 0 || ($adv == 1)) {
    my $gsrr = CMU::Netdb::get_services_ref($dbh, $user, '', 'service.name');
    if ( (keys %$gsrr) > 0) {
	print "<br />" . CMU::WebInt::subHeading("Service Groups","");
	print CMU::WebInt::printVerbose('mach_view.service_groups');
	
	my @data = map {
	  ["<a tabindex=\"90\" href=\"$url?op=svc_info&sid=".$rMemRow->{$_}->{'service.id'}."\">".
	   $rMemRow->{$_}->{'service.name'}."</a>", $rMemRow->{$_}->{'service_membership.id'},
	   $rMemRow->{$_}->{'service_membership.version'}];
	} keys %$rMemRow;
	unshift(@data, ['service.name']);
	my %printable = (%CMU::Netdb::structure::machine_printable, %CMU::Netdb::structure::service_printable);
	$$gsrr{'##q--'} = $q;
	$$gsrr{'##mid--'} = $id;
	CMU::WebInt::generic_smTable($url, \@data, ['service.name'],
				     {'service.name' => 0,
				     'service_membership.id' => 1,
				     'service_membership.version' => 2},
				     \%printable,
				     "mid=$id&back=machine", 'service_membership', 'svc_del_member',
				     \&CMU::WebInt::machines::cb_mach_add_service,
				     $gsrr);
    }
    
  }

  ## TrunkSet Presence
    if ($tsen == 1) {
      if ((ref($tsref) && ($#$tsref > 0)) || $adv == 1) {
	my $tref = CMU::Netdb::get_trunkset_ref($dbh, $user, '', 'trunk_set.name');
	if (ref $tref && ( (keys %$tref) > 0) ) {
	  $$tref{'##q--'} 	= $q;
	  $$tref{'##mid--'} 	= $id;
	  $$tref{'##type--'} 	= 'machine';

	  my %ts_device_pos   = %{CMU::Netdb::makemap
	      (\@CMU::Netdb::structure::trunkset_machine_presence_ts_machine_fields)};
	  print CMU::WebInt::subHeading("Trunk Set Presence", "");
	  print CMU::WebInt::printVerbose('mach_view.trunk_set');

	  CMU::WebInt::generic_smTable($url, $tsref, ['trunk_set.name'],\%ts_device_pos,
				       \%CMU::Netdb::structure::trunkset_machine_presence_ts_machine_printable,
				       "mid=$id",'trunkset_machine_presence', 'ts_del_member',
				       \&CMU::WebInt::trunkset::trunkset_cb_add_presence, $tref,
				       'trunkset_machine_presence.trunk_set',"op=trunkset_view&tid=");
	}
      }
    }
  
  ## Attributes
  print "<br>";
  CMU::WebInt::attr_display($dbh, $user, 'machine', $id, undef, $adv);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub cb_mach_add_service {
  my ($sref) = @_;
  my $q = $$sref{'##q--'}; delete $$sref{'##q--'};
  my $id = $$sref{'##mid--'}; delete $$sref{'##mid--'};
  my $res = "<tr><td><form method=get>
<input type=hidden name=op value=svc_add_member>
<input type=hidden name=machine value=$id>
<input type=hidden name=id value=$id>
<input type=hidden name=back value=machine>\n";
  my @ss = sort {$sref->{$a} cmp $sref->{$b}} keys %$sref;
  $res .= $q->popup_menu(-name=>'sid',
			 -values=>\@ss,
			 -labels=> $sref);
  $res .= "</td><td>\n<input type=submit value=\"Add to Service Group\"></form></td></tr>\n";

}

sub mach_conf_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines", $errors);
  &CMU::WebInt::title('Machine Configuration Information');
  $id = CMU::WebInt::gParam($q, 'id');
  my $deptAll = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'deptAll'));
  $deptAll = 0 if ($deptAll eq '');
  my $adv = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'adv'));
  $adv = 0 if ($adv eq '');
  my $verbose = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'bmvm'));
  $verbose = 1 if ($verbose ne '0');

  $$errors{msg} = "Machine ID not specified!" if ($id eq '');

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'machine', $id);
  
  if ($ul < 1) {
    CMU::WebInt::accessDenied('machine', 'READ', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<hr>".CMU::WebInt::errorDialog($url, $errors);
  
  # basic machine information
  my $sref = CMU::Netdb::list_machines($dbh, $user, "machine.id ='$id'");
  if (!defined $sref->[1]) {
    print "Machine not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};

  print CMU::WebInt::smallRight("[<a href=$url?op=mach_dhcpconf_view&id=$id><b>View Other Network Configuration Information Provided Via DHCP</b></a>]<br />");

  # host name/domain
  print "Hostname: ".$sdata[$machine_pos{'machine.host_name'}]."<br />\n";

  # Subnet
  my $sbnref = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$sdata[$machine_pos{'machine.ip_address_subnet'}]'", 'subnet.name');
  if (!ref $sbnref) {
    print "Error loading subnet.<br />\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Error loading subnet.', 
		{'subnet.id' => $sdata[$machine_pos{'machine.ip_address_subnet'}]});
  }else{
    print "Subnet: ".
      $$sbnref{$sdata[$machine_pos{'machine.ip_address_subnet'}]}."<br />\n";
  }

  # IP address / mode
  print "IP Address: ".CMU::Netdb::long2dot($sdata[$machine_pos{'machine.ip_address'}])
    ."<br />\n";
  
  # Network Mask
  my $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid='$id' and dhcp_option.type = 'machine' and dhcp_option_type.name = 'option subnet-mask'");
  
  if (!ref $ldor) {
    print "Unable to list DHCP Options.\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Unable to list DHCP options.',
		{'id' => $id });
  }elsif($#$ldor > 0) {
    print "Network Mask: ".$ldor->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]."<br />\n";
  }else{
    $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid="
			      .$sdata[$machine_pos{'machine.ip_address_subnet'}]
			      ." and dhcp_option.type = 'subnet' and dhcp_option_type.name = 'option subnet-mask'");
    
    if (!ref $ldor) {
      print "Unable to list DHCP Options.\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		  'Unable to list DHCP options.',
		  {'id' => $id });
    }elsif($#$ldor > 0) {
      print "Network Mask: ".$ldor->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]."<br />\n";
    }
  }
  # Router
  $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid='$id' and dhcp_option.type = 'machine' and dhcp_option_type.name = 'option routers'");
  
  if (!ref $ldor) {
    print "Unable to list DHCP Options.\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Unable to list DHCP options.',
		{'id' => $id });
  }elsif($#$ldor > 0) {
    print "Gateway Router: ".$ldor->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]."<br />\n";
  }else{
    $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid="
			      .$sdata[$machine_pos{'machine.ip_address_subnet'}]
			      ." and dhcp_option.type = 'subnet' and dhcp_option_type.name = 'option routers'");
    
    if (!ref $ldor) {
      print "Unable to list DHCP Options.\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		  'Unable to list DHCP options.',
		  {'id' => $id });
    }elsif($#$ldor > 0) {
      print "Gateway Router: ".$ldor->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]."<br />\n";
    }
  }
  # Broadcast address
  $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid='$id' and dhcp_option.type = 'machine' and dhcp_option_type.name = 'option broadcast.address'");
  
  if (!ref $ldor) {
    print "Unable to list DHCP Options.\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Unable to list DHCP options.',
		{'id' => $id });
  }elsif($#$ldor > 0) {
    print "Broadcast Address: ".$ldor->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]."<br />\n";
  }else{
    $ldor = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid="
			      .$sdata[$machine_pos{'machine.ip_address_subnet'}]
			      ." and dhcp_option.type = 'subnet' and dhcp_option_type.name = 'option broadcast-address'");
    
    if (!ref $ldor) {
      print "Unable to list DHCP Options.\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		  'Unable to list DHCP options.',
		  {'id' => $id });
    }elsif($#$ldor > 0) {
      print "Broadcast Address: ".$ldor->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]."<br />\n";
    }
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
  
}

sub mach_dhcpconf_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines", $errors);
  &CMU::WebInt::title('Machine Configuration Information Provided Via DHCP');
  $id = CMU::WebInt::gParam($q, 'id');
  my $deptAll = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'deptAll'));
  $deptAll = 0 if ($deptAll eq '');
  my $adv = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'adv'));
  $adv = 0 if ($adv eq '');
  my $verbose = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'bmvm'));
  $verbose = 1 if ($verbose ne '0');

  $$errors{msg} = "Machine ID not specified!" if ($id eq '');

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'machine', $id);
  
  if ($ul < 1) {
    CMU::WebInt::accessDenied('machine', 'READ', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<hr>".CMU::WebInt::errorDialog($url, $errors);
  
  # basic machine information
  my $sref = CMU::Netdb::list_machines($dbh, $user, "machine.id='$id'");
  if (!defined $sref->[1]) {
    print "Machine not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};

  my $sbnref = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$sdata[$machine_pos{'machine.ip_address_subnet'}]'", 'subnet.share');
  my $ldor;
  if (!ref $sbnref) {
    print "Error loading subnet.<br />\n";
    &CMU::WebInt::admin_mail('machines.pm:mach_view', 'WARNING',
		'Error loading subnet.', 
		{'subnet.id' => $sdata[$machine_pos{'machine.ip_address_subnet'}]});
    $ldor = CMU::Netdb::list_dhcp_options($dbh, $user, "((dhcp_option.type='machine' and dhcp_option.tid = $id) OR (dhcp_option.type = 'subnet' AND dhcp_option.tid = $sdata[$machine_pos{'machine.ip_address_subnet'}]) OR dhcp_option.type = 'global') ORDER BY dhcp_option.type");
  }else{
    if ($$sbnref{$sdata[$machine_pos{'machine.ip_address_subnet'}]} != 0) {
      $ldor = CMU::Netdb::list_dhcp_options($dbh, $user, "((dhcp_option.type='machine' and dhcp_option.tid = $id) OR (dhcp_option.type = 'subnet' AND dhcp_option.tid = $sdata[$machine_pos{'machine.ip_address_subnet'}]) OR (dhcp_option.type = 'share' AND dhcp_option.tid = $$sbnref{$sdata[$machine_pos{'machine.ip_address_subnet'}]}) OR dhcp_option.type = 'global') ORDER BY dhcp_option.type, dhcp_option_type.name");
    } else {
      $ldor = CMU::Netdb::list_dhcp_options($dbh, $user, "((dhcp_option.type='machine' and dhcp_option.tid = $id) OR (dhcp_option.type = 'subnet' AND dhcp_option.tid = $sdata[$machine_pos{'machine.ip_address_subnet'}]) OR dhcp_option.type = 'global') ORDER BY dhcp_option.type, dhcp_option_type.name");
    }
  }
  
  if (!ref $ldor) {
    print "Unable to find DHCP Options.\n";
  }elsif($#$ldor == 0) {
    print "[There are no visible global DHCP options.]\n";
  }else{
    CMU::WebInt::generic_tprint($url, $ldor, 
		   ['dhcp_option.type', 'dhcp_option_type.name', 'dhcp_option.value'],
		   [], '', '', '', \%CMU::WebInt::dhcp::dhcp_o_c_pos, 
		   \%CMU::Netdb::structure::dhcp_option_printable,
		   '', '', '', []);
  }
  print &CMU::WebInt::stdftr($q);

}

sub mach_cb_dhcp_opt_del {
  my ($url, $row, $edata) = @_;
  return "Delete" if (!ref $row);
  my @rrow = @$row;
  return "<a tabindex=\"90\" href=\"".CMU::WebInt::encURL("$url?op=mach_dhcp_opt_del&id=".
    $rrow[$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.id'}].
      "&version=".
	$rrow[$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.version'}].
	  "&type=$edata")."\">Delete</a>";
}

sub mach_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines", {});
  print &CMU::WebInt::subHeading("Delete Machine", CMU::WebInt::pageHelpLink(''));
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'machine', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('machine', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic machine infromation
  my $sref = CMU::Netdb::list_machines($dbh, $user, "machine.id='$id'");
  if (!ref $sref || !defined $sref->[1]) {
    print "Machine not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br />Please confirm that you wish to delete the following machine.\n";
  
  my @print_fields = ('machine.ip_address', 
		      'machine.host_name', 
		      'machine.mac_address');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::machine_printable{$f}."</th>
<td>";
    print $sdata[$machine_pos{$f}] if ($f ne 'machine.ip_address');
    print CMU::Netdb::long2dot($sdata[$machine_pos{$f}]) if ($f eq 'machine.ip_address');
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR /><a href=\"".CMU::WebInt::encURL("$url?op=mach_del_conf&id=$id&version=$version")."\">
Yes, delete this machine";
  print "<br /><a href=\"$url?op=mach_list\">No, return to the machines list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub mach_confirm_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res, $ref, %errors, $msg) = @_;
  
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  if ($id eq '') {
    CMU::WebInt::mach_view($q, {'msg' => 'Machine ID not specified!',
		   'code' => $CMU::Netdb::errcodes{ERROR},
		   'loc' => 'mach_del_conf',
		   'fields' => '',
		   'type' => 'ERR'});
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'machine', $id);

  if ($ul < 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines", {});
    &CMU::WebInt::title('Delete Machine');
    CMU::WebInt::accessDenied('machine', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  ($res, $ref) = CMU::Netdb::delete_machine($dbh, $user, $id, $version);

  if ($res == 1) {
    CMU::WebInt::mach_list($q, {'msg' => "The machine was deleted."});
  }else{
    $msg = 'There was an error while deleting the machine: '.
      $errmeanings{$res}.
	" [".join(',', @$ref)."] ";
    
    $msg .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." ) "
      if ($res eq $CMU::Netdb::errcodes{EDB});
    
    $dbh->disconnect();
    my %errors = ('msg' => $msg,
		  'loc' => 'mach_del_conf',
		  'code' => $res,
		  'fields' => join(',', @$ref),
		  'type' => 'ERR');
    CMU::WebInt::mach_view($q, \%errors);
  }
}

sub mach_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'machine', $id);
  my $sref = CMU::Netdb::list_machines($dbh,$user,"machine.id=$id");
  return ($CMU::Netdb::errcodes{'ENOENT'},['id']) if (!defined $sref->[1]);
  my @sdata = @{$sref->[1]};
  my $al = CMU::Netdb::get_add_level($dbh, $user, 'subnet', $sdata[$machine_pos{'machine.ip_address_subnet'}]);

  if ($userlevel >= 9) {
  # Level 9 fields
    foreach my $field (qw/mac_address ip_address mode comment_lvl9 comment_lvl5 comment_lvl1 host_name_ttl
			  ip_address_ttl dept/) {
      $fields{$field} = scalar CMU::WebInt::helper::gParam($q, $field);
    }
    my $HN = CMU::WebInt::helper::gParam($q, 'host_name');
    my $domain = CMU::WebInt::helper::gParam($q, 'domain');
    $fields{'host_name'} = "$HN.$domain";

    $fields{'flags'} = join(',', map { $_ if (CMU::WebInt::helper::gParam($q, $_) eq '1') } (@CMU::Netdb::structure::machine_flags));
  } elsif ($userlevel >= 5) {
    # Level 5 fields
    foreach my $field (qw/mac_address mode comment_lvl5 comment_lvl1 dept/) {
      $fields{$field} = scalar CMU::WebInt::helper::gParam($q, $field);
    }
    my $HN = CMU::WebInt::helper::gParam($q, 'host_name');
    my $domain = CMU::WebInt::helper::gParam($q, 'domain');
    $fields{'host_name'} = "$HN.$domain";

    $fields{'ip_address'} = CMU::WebInt::helper::gParam($q, 'ip_address')
      if ($al >= 5);
  }elsif($userlevel >= 1) {
    # Level 1 fields
    foreach my $field (qw/mac_address mode comment_lvl1 dept/) {
      $fields{$field} = scalar CMU::WebInt::helper::gParam($q, $field);
    }
    my $HN = CMU::WebInt::helper::gParam($q, 'host_name');
    my $domain = CMU::WebInt::helper::gParam($q, 'domain');
    $fields{'host_name'} = "$HN.$domain";

    $fields{'ip_address'} = CMU::WebInt::helper::gParam($q, 'ip_address')
      if ($al >= 5);
  }else{
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Update Access Denied", $errors);
    &CMU::WebInt::title("Update Machine");
    CMU::WebInt::accessDenied('machine', 'WRITE', $id, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # Clear the ip address field if specified and == 0
  $fields{'ip_address'} = '' if ($fields{'ip_address'} eq '0.0.0.0');

  my ($res, $errfields) = CMU::Netdb::modify_machine($dbh, $user, $id, $version, $userlevel, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Updated machine.";
    $dbh->disconnect(); # we use this for the insertid ..
    &CMU::WebInt::mach_view($q, \%nerrors);
  }else{
    foreach (@$errfields) {
      $nerrors{$_} = 1;
    }
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
    $nerrors{'type'} = 'ERR';
    $nerrors{'code'} = $res;
    $nerrors{'fields'} = join(',', @$errfields);
    $nerrors{'loc'} = 'mach_upd';
    $dbh->disconnect();
    &CMU::WebInt::mach_view($q, \%nerrors);
  }
}

sub mach_expire_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $osort, %groups, $grp, $mem, $gwhere);
  my (%groups_pos, %users_pos);
  
  $dbh = CMU::WebInt::db_connect();
  $sort = CMU::WebInt::helper::gParam($q, 'sort');
  $sort = 'machine.ip_address' if ($sort eq '');

  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_expire_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines Expiring", $errors);
  $url = $ENV{SCRIPT_NAME};

  print CMU::WebInt::errorDialog($url, $errors);

  $mem = CMU::Netdb::list_memberships_of_user($dbh, $user, $user);
  my $ui = CMU::Netdb::list_users($dbh, $user, "credentials.authid = '$user'");
  if (!ref $ui || !defined $ui->[1]) {
    print "Unable to view user information.";
    print &CMU::WebInt::stdftr($q);
    return;
  }


  if (ref $mem) {
    %groups_pos = %{CMU::Netdb::makemap($mem->[0])};
    shift(@$mem) if (ref $mem);

    map { $groups{$_->[$groups_pos{'groups.id'}]} = 
	    $_->[$groups_pos{'groups.description'}] } @$mem;
  }

  %users_pos = %{CMU::Netdb::makemap($ui->[0])};

  my @gk = sort { $groups{$a} cmp $groups{$b} } keys %groups;

  if (scalar @gk > 1) {
    $groups{0} = "[All]";
    unshift @gk, (0);
  };

  $groups{-1} = $ui->[1]->[$users_pos{'credentials.description'}];
  unshift @gk, (-1);

  $grp = CMU::WebInt::helper::gParam($q, 'grp');
  if ($#gk >= 1) {
    $grp = '-1' if ($grp eq '');
    print "<form method=get>
<input type=hidden name=sort value=$sort>
<input type=hidden name=op value=mach_expire_list>";
    print "Expiring machines for: ".$q->popup_menu(-name => 'grp',
							       -values => \@gk,
							       -labels => \%groups,
							       -default => -1);
    print " <input type=submit value=\"Refresh\"></form>\n";
  }else{
    print "<font face=\"arial,helvetica,geneva,charter\">Expiring machines for: <b>$ui->[1]->[$users_pos{'credentials.description'}]</b><br /><br />\n\n";
    $grp = '-1' if ($grp eq '');
  }

  if ($grp eq '-1') {
    $gwhere = 'USER';
    $grp = $ui->[1]->[$users_pos{'users.id'}];
  }elsif ($grp eq '0') {
    $gwhere = 'ALL'; # nasty hack because we use GROUP BY below...
  }else{
    $gwhere = 'GROUP';
  }
  
  my $presentID = -1 if ($gwhere eq 'USER');
  $presentID = 0 if ($gwhere eq 'ALL');
  $presentID = $grp if ($gwhere eq 'GROUP');
  print &CMU::WebInt::subHeading("Expiring Machines", CMU::WebInt::pageHelpLink('machine'));

  $res = mach_print_expire_machines($user, $dbh, $q, $gwhere, $grp,
				    " machine.expires != 0 ".
				    CMU::Netdb::verify_orderby($sort),
				    $url, "sort=$sort&grp=$presentID", 'start', 'mach_expire_list');

  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


# mach_print_expire_machines
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - whether this is a special munge_protections request
#   - extra munge_protections info
#   - any parameters to the list WHERE clause
#   - parameters to the count statement
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
#   - the key for the list
sub mach_print_expire_machines {
  my ($user, $dbh, $q, $t, $td, $where, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres);

  $start = (CMU::WebInt::helper::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::helper::gParam($q, $skey);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'MACHINES_PER_PAGE');

  $where = "TRUE" if ($where eq '');
  if ($td eq '0') {
    $ruRef = CMU::Netdb::list_machines($dbh, $user, " $where ".
				       CMU::Netdb::verify_limit($start, $defitems));
  }else{
    $ruRef = CMU::Netdb::list_machines_munged_protections($dbh, $user, $t, $td, " $where ".
							  CMU::Netdb::verify_limit($start, $defitems));
  }
  
  if (!ref $ruRef) {
    print "ERROR with list_machine: ".$errmeanings{$ruRef};
    return 0;
  }

  $lmach .= "&$oData" if ($oData ne '');
  $ctRow = ($#{$ruRef} < $defitems ? 0 : $start+$defitems+1);

  print "The following machines are set to expire on the date listed. You can prevent ".
    "a machine from expiring by viewing the machine information screen and clicking ".
      "'Retain'.<br />\n";
  print &CMU::WebInt::pager_Top($start, $ctRow, $defitems, 0,
				$url, "op=".$lmach, $skey);

  $lmach =~ s/\&sort=[^\&]+//;
  $lmach =~ s/\&\&/\&/g;
  $lmach =~ s/\&$//;

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($url, $ruRef, 
			      ['machine.host_name', 'machine.mac_address', 
			       'machine.expires'],
			      [\&CMU::WebInt::machines::mach_cb_print_IP,
			       \&CMU::WebInt::machines::mach_cb_unexp_button],
			      {'q' => $q}, $lmach,
			      'op=mach_view&id=',
			      \%machine_pos, 
			      \%CMU::Netdb::structure::machine_printable,
			      'machine.host_name', 'machine.id', 'sort',
			      ['machine.host_name', 'machine.mac_address', 'machine.expires',
			       'machine.ip_address', '']);
  
  return 1;
}

sub mach_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $osort, %groups, $grp, $mem, $gwhere);
  my (%users_pos, %groups_pos);

  $dbh = CMU::WebInt::db_connect();
  $sort = CMU::WebInt::helper::gParam($q, 'sort');
  $sort = 'host_name' if ($sort eq '');
  $osort = CMU::WebInt::helper::gParam($q, 'osort');
  $osort = 'label_from' if ($osort eq '');

  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  my $ui = CMU::Netdb::list_users($dbh, $user, "credentials.authid = '$user'");
  if (!ref $ui || !defined $ui->[1]) {
      my ($jitRes, $jitInfo) = CMU::Netdb::config::get_multi_conf_var('webint', 'JustInTime_UserLookup');

      if ($jitRes == 1 && defined $jitInfo && ref $jitInfo eq 'HASH') {
          mach_jit_add_user($dbh, $user, $jitInfo);
          $ui = CMU::Netdb::list_users($dbh, $user, "credentials.authid = '$user'");
      }

      if (!ref $ui || !defined $ui->[1]) {
          my ($vres, $user_mail) = CMU::Netdb::config::get_multi_conf_var
              ('webint', 'USER_MAIL');

          print CMU::WebInt::stdhdr($q, $dbh, $user, "Main", $errors);
          print "Unable to view user information (authenticated as: $user).";
          print "<br /><br />Most likely you are not registered with the NetReg system.<br /><br />\n";
          print "If this persists for more than a day, please contact $user_mail.\n";
          print &CMU::WebInt::stdftr($q);
          return;
      }
  }

  $mem = CMU::Netdb::list_memberships_of_user($dbh, $user, $user);

  # Check for the quick registration
  my $op = CMU::WebInt::helper::gParam($q, 'op');

  my ($vres, $eqr) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_QUICKREG');

  if (($op eq '' || $op eq 'login')
      && $vres == 1 && $eqr == 1) {
    my ($qregRes, $errf) = CMU::WebInt::quickreg::qreg_loginhook($q, $dbh, $user);
    return if ($qregRes == 1);
  }
  
  CMU::WebInt::setHelpFile('main');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Main", $errors);
  $url = $ENV{SCRIPT_NAME};

  print CMU::WebInt::errorDialog($url, $errors);

  if (ref $mem) {
    %groups_pos = %{CMU::Netdb::makemap($mem->[0])};
    shift(@$mem);
    map { $groups{$_->[$groups_pos{'groups.id'}]} = 
		$_->[$groups_pos{'groups.description'}]
	      } @$mem;
  }

  %users_pos = %{CMU::Netdb::makemap($ui->[0])};

  my @gk = sort { $groups{$a} cmp $groups{$b} } keys %groups;

  if (scalar @gk > 1) {
    $groups{0} = "[All]";
    unshift @gk, (0);
  };

  $groups{-1} = $ui->[1]->[$users_pos{'credentials.description'}];
  unshift @gk, (-1);

  $grp = CMU::WebInt::helper::gParam($q, 'grp');

  my ($eco);
  ($vres, $eco) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_CABLES_OUTLETS');

  if ($#gk >= 1) {
    $grp = '-1' if ($grp eq '');
    print "<form method=get>
<input type=hidden name=sort value=$sort>
<input type=hidden name=osort value=$osort>
<input type=hidden name=op value=mach_list>";
    print "<label accesskey=r for=grp><u>R</u>egistered machines";
    print " and outlets" if ($eco == 1);
    print " for:</label> ".$q->popup_menu(-name => 'grp',
						   -id => 'grp',
					      -values => \@gk,
					      -labels => \%groups,
					      -default => -1);
    print "<input type=submit value=\"Refresh\"></form>\n";
  }else{
    print "<font face=\"arial,helvetica,geneva,charter\">Registered machines";
    print " and outlets" if ($eco == 1);
    print " for: <b>$ui->[1]->[$users_pos{'credentials.description'}]</b><br /><br />\n\n";
    $grp = '-1' if ($grp eq '');
  }

  if ($grp eq '-1') {
    $gwhere = 'USER';
    $grp = $ui->[1]->[$users_pos{'users.id'}];
  }elsif ($grp eq '0') {
    $gwhere = 'ALL'; # nasty hack because we use GROUP BY below...
  }else{
    $gwhere = 'GROUP';
  }
  
  my $presentID = -1 if ($gwhere eq 'USER');
  $presentID = 0 if ($gwhere eq 'ALL');
  $presentID = $grp if ($gwhere eq 'GROUP');
  print &CMU::WebInt::subHeading("Registered Machines", CMU::WebInt::pageHelpLink('machine')).
    CMU::WebInt::smallRight("[<b><a href=$url?op=mach_reg>Register New Machine</a></b>] [<b><a href=$url?op=mach_search>Search Your Machines</a></b>] [<b><a href=\"$url?op=mach_expire_list\">View Expiring Machines</a></b>]");
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "GWHERE: $gwhere; GRP: $grp\n" if ($debug >= 1);
  $res = mach_print_machines($user, $dbh, $q, $gwhere, $grp,
			     " TRUE ".
			     CMU::Netdb::verify_orderby($sort),
			     $url, "sort=$sort&osort=$osort&grp=$presentID", 'start', 'mach_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  ## Outlets ##
  if ($eco == 1) {
    print "<br />".CMU::WebInt::subHeading("Registered Outlets", CMU::WebInt::pageHelpLink('outlet')).
      CMU::WebInt::smallRight("[<b><a href=$url?op=outlets_reg_s0>Register New Outlet</a></b>] ".
			      "[<b><a href=$url?op=outlets_search>Search Your Activated Outlets</a></b>] ".
			      "[<b><a href=\"$url?op=outlets_expire_list\">View Expiring Outlets</a></b>]");
    $res = CMU::WebInt::outlets::outlets_print_outlet
      ($user, $dbh, $q, $gwhere, $grp, " TRUE ".
       CMU::Netdb::verify_orderby($osort), '',
       $url, "sort=$sort&osort=$osort&grp=$presentID", 'ostart', 'mach_list');
    
    print "ERROR: ".$errmeanings{$res} if ($res <= 0);
    print " (Database: ".$CMU::Netdb::primitives::db_errstr." ) "
      if ($CMU::Netdb::errcodes{EDB} == $res);
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# mach_print_machines
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - whether this is a special munge_protections request
#   - extra munge_protections info
#   - any parameters to the list WHERE clause
#   - parameters to the count statement
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
#   - the key for the list
sub mach_print_machines {
  my ($user, $dbh, $q, $t, $td, $where, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres);

  $start = (CMU::WebInt::helper::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::helper::gParam($q, $skey);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'MACHINES_PER_PAGE');

  $where = "TRUE" if ($where eq '');
  if ($td eq '0') {
    $ruRef = CMU::Netdb::list_machines($dbh, $user, 
				       " $where ".
				       CMU::Netdb::verify_limit($start, $defitems));
  }else{
    $ruRef = CMU::Netdb::list_machines_munged_protections($dbh, $user, $t, $td,
							  " $where ".
							  CMU::Netdb::verify_limit($start, $defitems));
  }
  
  if (!ref $ruRef) {
    print "ERROR with list_machine: ".$errmeanings{$ruRef};
    return 0;
  }
  my $sref = CMU::Netdb::list_subnets_ref($dbh, $user, '', 'subnet.abbreviation');

  $lmach .= "&$oData" if ($oData ne '');
  $ctRow = ($#{$ruRef} < $defitems ? 0 : $start+$defitems+1);

  print "Select a column heading to sort by the column field.<br />\n";
  print &CMU::WebInt::pager_Top($start, $ctRow, $defitems, 0,
		   $url, "op=".$lmach, $skey);

  $lmach =~ s/\&sort=[^\&]+//;
  $lmach =~ s/\&\&/\&/g;
  $lmach =~ s/\&$//;

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($url, $ruRef, 
			      ['machine.host_name', 'machine.mac_address', 'machine.mode'],
			      [\&CMU::WebInt::machines::mach_cb_print_IP,
			       \&CMU::WebInt::machines::mach_cb_print_sabbr], 
			      { 'sref' => $sref }, $lmach,
			      'op=mach_view&id=',
			      \%machine_pos, 
			      \%CMU::Netdb::structure::machine_printable,
			      'machine.host_name', 'machine.id', 'sort',
			      ['machine.host_name', 'machine.mac_address',
			       'machine.mode', 'machine.ip_address', 
			       'machine.ip_address_subnet']);
  
  return 1;
}

sub mach_cb_unexp_button {
  my ($url, $row, $edata) = @_;
  return "Retain" if (!ref $row);
  
  my $q = $edata->{q};
  my @rrow = @{$row};
  my @vars = $q->param();
  my $link = "<form action=$url>
<input type=hidden name=op value=mach_unexpire>
<input type=hidden name=id value=$rrow[$machine_pos{'machine.id'}]>
<input type=hidden name=version value=\"".$rrow[$machine_pos{'machine.version'}]."\">\n";

  foreach(@vars) {
    next if ($_ =~ /back_/);
    $link .= "<input type=hidden name=back_$_ value=\"".$q->param($_)."\">\n";
  }
  $link .= "<input type=submit value=\"Retain\">
</form>\n";
  return $link;  
}    

sub mach_cb_print_IP {
  my ($url, $row, $edata) = @_;
  return $CMU::Netdb::structure::machine_printable{'machine.ip_address'} if (!ref $row);
  my @rrow = @{$row};
  return CMU::Netdb::long2dot($rrow[$machine_pos{'machine.ip_address'}]);
}

sub mach_cb_print_MAC_search {
  my ($url, $row, $edata) = @_;

  my $dbh = $edata->{'dbh'};
  return $CMU::Netdb::structure::machine_printable{'machine.mac_address'} if (!ref $row);
  my @rrow = @{$row};

  my $IP = $rrow[$machine_pos{'machine.ip_address'}];
  my $MAC = $rrow[$machine_pos{'machine.mac_address'}];
  my $mode = $rrow[$machine_pos{'machine.mode'}];
  return $MAC if ($mode ne 'pool');

  if ($LEASE_ARCHIVE_DIR eq '' || !grep(/^trall$/, $edata->{'dynlookup'})) {
      return 'pool';
  }

  my %fields;
  $fields{'ip_address'} = CMU::Netdb::long2dot($IP);
  $fields{'mac_address'} = ':::::';
  
  my ($res, $leases) = CMU::Netdb::search_leases($dbh, 'netreg', \%fields, time());
  if ($res < 1) {
      warn "Error searching leases for $IP: $res ".Dumper($leases);
      return '';
  }

  my @MACs = CMU::Netdb::helper::unique map { $leases->{$_}->{'mac_address'} } keys %$leases;
  return '<i>no active lease</i>' if (scalar(@MACs) == 0);

  return "<i>".join(',', @MACs)."</i>";
}

sub mach_cb_print_mode_search {
  my ($url, $row, $edata) = @_;

  return $CMU::Netdb::structure::machine_printable{'machine.mode'} if (!ref $row);
  return $row->[$machine_pos{'machine.mode'}];
}
  
sub mach_cb_print_IP_search {
  my ($url, $row, $edata) = @_;

  my $dbh = $edata->{'dbh'};
  return $CMU::Netdb::structure::machine_printable{'machine.ip_address'} if (!ref $row);
  my @rrow = @{$row};

  my $IP = $rrow[$machine_pos{'machine.ip_address'}];
  my $mode = $rrow[$machine_pos{'machine.mode'}];
  if ($mode ne 'dynamic') {
      return CMU::Netdb::long2dot($IP);
  }

  if ($LEASE_ARCHIVE_DIR eq '' || !grep(/^trall$/, $edata->{'dynlookup'})) {
      return 'dynamic';
  }

  my %fields;
  my $MAC = $rrow[$machine_pos{'machine.mac_address'}];
  $fields{'mac_address'} = join(':', map { substr($MAC, $_, 2) } (0,2,4,6,8,10));
  
  my ($res, $leases) = CMU::Netdb::search_leases($dbh, 'netreg', \%fields, time());
  if ($res < 1) {
      warn "Error searching leases for $MAC: $res ".Dumper($leases);
      return '';
  }

  my @IPs = CMU::Netdb::helper::unique map { $leases->{$_}->{'ip_address'} } keys %$leases;
  return '<i>no active lease</i>' if (scalar(@IPs) == 0);

  return "<i>".join(',', @IPs)."</i>";
}


# Note, this callback is called from two places, changing the content of edata requires changing
# both callers.
sub mach_cb_print_sabbr {
  my ($url, $row, $edata) = @_;

  my $sref = $edata->{'sref'};
  return "Subnet" if (!ref $row); # DO NOT set this to _printable!
  my @rrow = @{$row};
  return $$sref{$rrow[$machine_pos{'machine.ip_address_subnet'}]};
}

sub mach_search {
  my ($q, $errors) = @_;
  my ($dbh, $defitems, $res, $url, $sort, %groups, $grp, $mem, $gwhere);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_search');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines", $errors);
  &CMU::WebInt::title("Search Your Machines");

  my $MachLevel = CMU::Netdb::get_read_level($dbh, $user, 'machine', 0);

  $url = $ENV{SCRIPT_NAME};
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # level 0 can search by: mac_address, ip_address, host_name, mode, subnet, 
  # host_name_zone, ip_address_zone
  # level 9 (read on the entire table) can search by: (l0 plus): flags, comment

  CMU::WebInt::printVerbose('machine.search_general', 1);

  print &CMU::WebInt::subHeading
    ("Basic Search Parameters", 
     (CMU::Netdb::get_user_admin_status($dbh, $user) ?
      "[<b><a href=\"$url?op=mach_history_search\">Machine History Search</a></b>] " :
      "") . "[<b><a href=\"$url?op=dns_r_search\">DNS Resource Search</a></b>] ".CMU::WebInt::pageHelpLink(''));
  print "<br />You may only search machines which are registered to you, or ".
    "to a department you administer.<br />The percent sign ('\%') can be ".
      "used as a wildcard (match anything) operator.<br /> ";
  if ($MachLevel >= 9) {
    print "<br /><a href=\"$url?op=rep_abuse_suspend\">Abuse/Suspend Report".
      "</a><br />\n";
  }

  print "<form method=get>\n
<input type=hidden name=op value=mach_s_exec>
<table border=0>";

  # mac_address
  print "<tr>".
    CMU::WebInt::printPossError
      (0, 
       $CMU::Netdb::structure::machine_printable{'machine.mac_address'}, 
       1, 'mac_address')."</td><td>".$q->textfield(-name => 'mac_address', -accesskey => 'h').
	 "</td></tr>";
  
  # ip_address

         my $ipHash = {'is'  => '', 'btw' => ''};

        my @ipValues = qw/is btw/;
        my @ipControls = $q->radio_group(-name=>'ipt',-values=>\@ipValues,-labels=>$ipHash);

  print "<tr>".CMU::WebInt::printPossError
    (0, 
     $CMU::Netdb::structure::machine_printable{'machine.ip_address'}, 
     1, 'ip_address')."</td><td>";

  print $ipControls[0] . "is: ".
    $q->textfield(-name => 'ip_address', accesskey => 'i');

  print "<br />" . $ipControls[1] . "between: ".
    $q->textfield(-name => 'ip1', -size => 15, accesskey => 'i')." and ".
      $q->textfield(-name => 'ip2', -size => 15, accesskey => 'i')."</td></tr>";
  
  # host_name
  print "<tr>".CMU::WebInt::printPossError
    (0, $CMU::Netdb::structure::machine_printable{'machine.host_name'}, 
     1, 'host_name')."</td><td>".
       $q->textfield(-name => 'host_name', -size => 40, accesskey => 'h')."</td></tr>";
  
  # mode
  {
    my @mode = @CMU::Netdb::structure::subnet_registration_modes_modes;
    unshift(@mode, '--select--');
    print "<tr>".CMU::WebInt::printPossError
      (0, $CMU::Netdb::structure::machine_printable{'machine.mode'}, 
       1, 'mode').
	 "</td><td>".$q->popup_menu(-name => 'mode', accesskey => 'm',
				    -values => \@mode)."</td></tr>";
  }
  
  # flags
  if ($MachLevel >= 9) {
    my @flags = @CMU::Netdb::structure::machine_flags;
    print "<tr>".CMU::WebInt::printPossError
      (0, 
       $CMU::Netdb::structure::machine_printable{'machine.flags'}, 
       1, 'flags')."</td><td>";
    my @prItems;
    my @vals = qw/Ignore Unset Set/;
    
    foreach(@flags) {
      push(@prItems, "<b>".ucfirst($_)."</b>: ".
	   $q->popup_menu(-name => "flag_$_",
              -accesskey => 'f',
			  -values => \@vals,
			  -default => 'Ignore'));
    }
    print join(" &nbsp;&nbsp; \n", @prItems);
    
    print "</td></tr>\n";
  }

  # subnet
  {
    my $sbn = CMU::Netdb::list_subnets_ref($dbh, $user, '', 'subnet.name');
    if (ref $sbn) {
      print "<tr>".CMU::WebInt::printPossError
	(0, 
	 $CMU::Netdb::structure::machine_printable{'machine.ip_address_subnet'}, 
	 1, 'ip_address_subnet')."</td><td>";
      my @sbk = sort { $$sbn{$a} cmp $$sbn{$b} } keys %$sbn;
      unshift(@sbk, '--select--');
      print $q->popup_menu(-name => 'ip_address_subnet',
               -accesskey => 's',
			   -values => \@sbk,
			   -labels => $sbn);
      print "</td></tr>\n";
    }else{
      print "<tr><td colspan=2>[Error loading subnets.]</td></tr>\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
		'Error loading subnets (list_subnets_ref).', {});
    }
  }

  # host_name_zone
  {
    my $fwz = CMU::Netdb::list_zone_ref($dbh, $user, "type like \"fw-%\"");
    if (ref $fwz) {
      print "<tr>".CMU::WebInt::printPossError
	(0, 
	 $CMU::Netdb::structure::machine_printable{'machine.host_name_zone'}, 
	 1, 'host_name_zone')."</td><td>";
      my @fwk = sort { $$fwz{$a} cmp $$fwz{$b} } keys %$fwz;
      unshift(@fwk, '--select--');
      print $q->popup_menu(-name => 'host_name_zone',
               -accesskey => 'h',
			   -values => \@fwk,
			   -labels => $fwz);
      print "</td></tr>\n";
    }else{
      print "<tr><td colspan=2>(Error loading forward zones.)</td></tr>\n";
      &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
		'Error loading forward zones (list_zone_ref).', 
		  {'type' => 'fw-%'});
    }
  }

  # ip_address_zone
  {
    my $rvz = CMU::Netdb::list_zone_ref($dbh, $user, "type like \"rv-%\"");
    if (ref $rvz) {
      print "<tr>".CMU::WebInt::printPossError(0, $CMU::Netdb::structure::machine_printable{'machine.ip_address_zone'}, 1, 'ip_address_zone')."</td><td>";
      my @rvk = sort { rev_name($$rvz{$a}) <=> rev_name($$rvz{$b}) } keys %$rvz;
      unshift(@rvk, '--select--');
      print $q->popup_menu(-name => 'ip_address_zone',
               -accesskey => 'i',
                           -values => \@rvk,
                           -labels => $rvz);
    }else{
      print "<tr><td colspan=2>(Error loading reverse zones.)</td></tr>\n";
       &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
                'Error loading reverse zones (list_zone_ref).',
                  {'type' => 'rv-%'});
    }
  }
  print "</table>";

  print "<br />".&CMU::WebInt::subHeading("Users/Groups", CMU::WebInt::pageHelpLink('usersgroups'));

  my $ugdValueHash = {'USER'  => '', 'GROUP' => '', 'DEPT'  =>''};
  my $ugdAccessKeysHash = {'USER' => { 'accesskey' => 'u' }, 'GROUP' => { 'accesskey' => 'g' }, 'DEPT'  => { 'accesskey' => 'd' } };

  my @ugdValues = qw/USER GROUP DEPT/;
  my @ugdFields = $q->radio_group(-name=>'ugtype',-values=>\@ugdValues,-labels=>$ugdValueHash,-attributes=>$ugdAccessKeysHash);

  print "<table border=1>";
  # users
  print "<tr><td bgcolor=$THCOLOR>" . $ugdFields[0] . CMU::WebInt::tableHeading('User ID')."</td><td>".
    $q->textfield(-name => 'uid', accesskey => 'u');

  CMU::WebInt::drawUserRealmPopup($q,"uidrealm","r");

  print "</td></tr>\n";

  # groups
  print "<tr><td bgcolor=$THCOLOR>".$ugdFields[1].CMU::WebInt::tableHeading('Group ID')."</td><td>".
    $q->textfield(-name => 'gid', accesskey => 'g')."</td></tr>\n";

  # departments
  print "<tr><td bgcolor=$THCOLOR>".$ugdFields[2].CMU::WebInt::tableHeading('Affiliation')."</td><td>";
  my $depts = CMU::Netdb::get_departments($dbh, $user, '', 'ALL', '', 'groups.description', 'LIST');
  $$depts{'--select--'} = '--select--';
  my @dk = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;
  print $q->popup_menu(-name => 'dept',
              -accesskey => 'a',
		      -values => \@dk,
		      -labels => $depts)."</td></tr>\n";
  
  print "</table>\n";
  print "<input type=submit value=\"Search\"></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub mach_history_search {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors, $hits, $col, $match);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined($errors);

  print CMU::WebInt::stdhdr($q, $dbh, $user, "Search Machine History", $errors);
  &CMU::WebInt::title("Search Machine History");
  
  if( not CMU::Netdb::get_user_admin_status($dbh, $user) > 0 ) {
      CMU::WebInt::accessDenied();
      $dbh->disconnect();
      print CMU::WebInt::stdftr($q);
      return;
  }

  my $method   = CMU::WebInt::gParam($q, "method");
  my $mac      = CMU::WebInt::gParam($q, "mac");
  my $hostname = CMU::WebInt::gParam($q, "hostname");
  my $ip       = CMU::WebInt::gParam($q, "ip");

  print "<table border=1><tr><th>Search By</th><th>(Exact Matches Only)</th></tr>\n";

  print "<form method=get>\n";
  print "<input type=hidden name=op value=mach_history_search>\n";

  print "<tr><td><input type=radio name=method value=hostname " . 
      ($method eq 'hostname' ? "checked" : "") . 
      "> Hostname</td><td><input type=text name=hostname value=\"$hostname\"></td></tr>\n";

  print "<tr><td><input type=radio name=method value=mac " .
      ($method eq 'mac' ? "checked" : "") .
      "> Mac Address</td><td><input type=text name=mac value=\"$mac\"></td></tr>\n";

  print "<tr><td><input type=radio name=method value=ip " .
      ($method eq 'ip' ? "checked" : "") .
      "> IP Address</td><td><input type=text name=ip value=\"$ip\"></td></tr>\n";

  print "<tr><td colspan=2 align=center><input type=submit value=Search></td></tr>\n";

  print "</table>\n";

  if($method eq 'hostname' and $hostname) {
      $col = "host_name";
      $match = $hostname;
  }elsif($method eq 'mac' and $mac) {
      $col = "mac_address";
      $match = $mac;
  }elsif($method eq 'ip' and $ip){
      $col = "ip_address";
      $match = $ip;
  }

  if($col){
      my ($res, $hits) = CMU::Netdb::search_history($dbh, $user, "machine", $col, $match);
      print CMU::WebInt::subHeading("Search Results");
      if($res == 1 and defined $hits->[0]){
          print "<table border=1>\n";
          foreach my $row ( @{$hits} ){
              print "<tr><td>ID $row</td><td><a href=$url?op=history&tname=machine&row=$row>View History</a></td><td>" . 
                  (CMU::Netdb::count_machines($dbh, $user, "machine.id = $row")->[1][0] ?
                   "<a href=$url?op=mach_view&id=$row>Current Record</a>" :
                   "Record Deleted") .
                   "</td></tr>\n";
          }
          print "</table>";
      } else {
          print "No Results Found";
      }
  }

  print CMU::WebInt::stdftr($q);
}



sub rev_name {
  my ($in) = @_;
  my @a = split(/\./, $in);
  return $a[2]*256*256+$a[1]*256+$a[0];
}

# address can be specified in the following formats:
#  - 00aabbccddee
#  - 00:aa:bb:cc:dd:ee
#  - 0:a:b:c:d:e (assume leading 0s)
#  - 00aa.bbcc.ddee
#  - 00-aa-bb-cc-dd-ee
sub canon_macaddr {
  my ($in)=@_;
  my (@components);

  $in = uc($in);
  # Blank is ok
  return $in if ($in eq '');

  # dotted format
  if ($in =~ /\./) {
    my @a = split(/\./, $in);
    map { push(@components, (substr($_, 0, 2), substr($_, 2, 2))) } @a;

  # colons, requires 0 padding
  }elsif($in =~ /\:/) {
    @components = split(/\:/, $in);
    @components = map { if (length($_) == 1) { "0".$_ } else { $_ } } @components;

  # dashes
  }elsif($in =~ /\-/) {
    @components = split(/\-/, $in);
  }else{
    return $in 
      unless ($in =~ /^[A-F0-9]{12}$/s);
    @components = map { substr($in, $_, 2) } (0,2,4,6,8,10);
  }
  my $rstring = join('', @components);
  return $rstring;
}

sub mach_s_exec {
  my ($q, $errors) = @_;
  my ($dbh, $url, $query, @q, $type);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('mach_s_exec');
  $url = $ENV{SCRIPT_NAME};
  my @rurl;

  # mac_address
  if (CMU::WebInt::helper::gParam($q, 'mac_address') ne '') {
    my $m=CMU::WebInt::helper::gParam($q, 'mac_address');
    $m=canon_macaddr($m);
    if ($m =~ /\%/) {
      push(@q, 'mac_address like '.$dbh->quote($m));
    }else{
      push(@q, 'mac_address like '.$dbh->quote('%'.$m.'%'));
    }
  }

  # ip_address
  if (CMU::WebInt::helper::gParam($q, 'ipt') eq 'is') {
    push(@q, 'ip_address = '.CMU::Netdb::dot2long(CMU::WebInt::helper::gParam($q, 'ip_address')))
      if (CMU::WebInt::helper::gParam($q, 'ip_address') ne '');
  }elsif(CMU::WebInt::helper::gParam($q, 'ipt') eq 'btw') {
    unless (CMU::WebInt::helper::gParam($q, 'ip1') eq '' || CMU::WebInt::helper::gParam($q, 'ip2') eq '') {
      my ($a, $b) = (CMU::Netdb::dot2long(CMU::WebInt::helper::gParam($q, 'ip1')), CMU::Netdb::dot2long(CMU::WebInt::helper::gParam($q, 'ip2')));
      if ($a > $b) {
	my $c = $a;
	$a = $b;
	$b = $c;
      }
      push(@q, "ip_address >= $a and ip_address <= $b");
    }
  }
  # host_name
  if (CMU::WebInt::helper::gParam($q, 'host_name') ne '') {
    if (CMU::WebInt::helper::gParam($q, 'host_name') =~ /\%/) {
      push(@q, 'host_name like '.$dbh->quote(CMU::WebInt::helper::gParam($q, 'host_name')));
    }else{
      push(@q, 'host_name like '.$dbh->quote('%'.CMU::WebInt::helper::gParam($q, 'host_name').'%'));
    }
  }

  # flags
  foreach(@CMU::Netdb::structure::machine_flags) {
    if (CMU::WebInt::helper::gParam($q, "flag_$_") eq 'Set') {
      push(@q, "find_in_set('$_', flags)");
      push(@rurl, "flag_$_=".CMU::WebInt::helper::gParam($q, "flag_$_"));
    }
    
    if (CMU::WebInt::helper::gParam($q, "flag_$_") eq 'Unset') {
      push(@q, "not find_in_set('$_', flags)");
      push(@rurl, "flag_$_=".CMU::WebInt::helper::gParam($q, "flag_$_"));
    }
  }
    
  # mode
  push(@q, 'mode = \''.CMU::WebInt::helper::gParam($q, 'mode').'\'')
    if (CMU::WebInt::helper::gParam($q, 'mode') ne '' && CMU::WebInt::helper::gParam($q, 'mode') ne '--select--');
  # subnet
  push(@q, 'ip_address_subnet = '.CMU::WebInt::helper::gParam($q, 'ip_address_subnet'))
    if (CMU::WebInt::helper::gParam($q, 'ip_address_subnet') ne '' && 
	CMU::WebInt::helper::gParam($q, 'ip_address_subnet') ne '--select--');
  # host_name_zone
  push(@q, 'host_name_zone = '.CMU::WebInt::helper::gParam($q, 'host_name_zone'))
    if (CMU::WebInt::helper::gParam($q, 'host_name_zone') ne '' && 
	CMU::WebInt::helper::gParam($q, 'host_name_zone') ne '--select--');
  # ip_address_zone
  push(@q, 'ip_name_zone = '.CMU::WebInt::helper::gParam($q, 'ip_name_zone'))
    if (CMU::WebInt::helper::gParam($q, 'ip_name_zone') ne '' && 
	CMU::WebInt::helper::gParam($q, 'ip_name_zone') ne '--select--');

  foreach(qw /mac_address ip_address ipt ip1 ip2 host_name mode 
	  ip_address_subnet host_name_zone ip_address_zone
	  uid uidrealm gid ugtype dept/) {
    push(@rurl, "$_=".CMU::WebInt::helper::gParam($q, $_)) if (CMU::WebInt::helper::gParam($q, $_) ne '' && CMU::WebInt::helper::gParam($q, $_) ne '--select--');
  }
  my $tdata;
  if (CMU::WebInt::helper::gParam($q, 'ugtype') eq 'USER' && CMU::WebInt::helper::gParam($q, 'uid') ne '') {
    # users
    $type = 'USER';
    $tdata = CMU::WebInt::helper::gParam($q, 'uid');
 # this tries to figure out what the uidrealm is and if it was there or none, don't set the realm.
        my $uidrealm = CMU::WebInt::helper::gParam($q, 'uidrealm');
        if (($uidrealm ne '--none--') && ($uidrealm ne undef) && ($tdata ne undef)) { $tdata .= "@" . $uidrealm; }
  }elsif(CMU::WebInt::helper::gParam($q, 'ugtype') eq 'GROUP' && CMU::WebInt::helper::gParam($q, 'gid') ne '') {
    # groups
    $type = 'GROUP';
    $tdata = CMU::WebInt::helper::gParam($q, 'gid');
  }elsif(CMU::WebInt::helper::gParam($q, 'ugtype') eq 'DEPT' && CMU::WebInt::helper::gParam($q, 'dept') ne '--select--') {
    # departments
    $type = 'GROUP';
    $tdata = CMU::WebInt::helper::gParam($q, 'dept');
  }else{
    $type = 'ALL';
    $tdata = '';
  }
  
  ## WARNING: don't change this to OR unless you deal with the user/group
  ## join stuff that MUST be AND
  my $gwhere = join(' AND ', @q);
  $gwhere = 'TRUE' if ($gwhere eq '');

  my $sort = CMU::WebInt::helper::gParam($q, 'sort');
  $sort = 'machine.host_name' if ($sort eq '');

  push(@rurl, "sort=$sort");
  my ($res, $code, $msg) = mach_print_mach_search($user, $dbh, $q, 
						  $gwhere.
						  CMU::Netdb::verify_orderby($sort),
						  $url, join('&', @rurl), 'start', 'mach_s_exec', $type, $tdata);
  
  if ($res != 1) {
    if ($code == $CMU::Netdb::errors::errcodes{ENOTFOUND}) {
      if ($#rurl == 1 && grep (/^host_name/, @rurl)) {
	my $hn = CMU::WebInt::helper::gParam($q, 'host_name');
	$msg .= " You may wish to try a ".
	  "<a href=\"$url?op=dns_r_s_exec&name=$hn\">DNS Resource Search</a>.";
      }
    }
    my %errors = ('type' => 'ERR',
		  'code' => $code,
		  'msg' => $msg,
		  'loc' => 'mach_s_exec',
		  'fields' => '');
    CMU::WebInt::mach_search($q, \%errors);
    return;
  }
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# mach_print_mach_search
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the list WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
#   - the key for the list
#   - type of query (USER, GROUP, ALL)
#   - type data
sub mach_print_mach_search {
  my ($user, $dbh, $q, $where, $url, $oData, $skey, $lmach, $type, $tdata) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres);

  $start = (CMU::WebInt::helper::gParam($q, $skey) eq '') ? 0 : 
    CMU::WebInt::helper::gParam($q, $skey);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'MACHINES_PER_PAGE');

  my $prewhere = mach_search_pre_where($dbh, $type, $tdata);
  $where = "$prewhere AND $where" if ($prewhere ne '');
  
  my $listUser = $user;
# can you say a security hole to drive a semi trough???
#  if ($prewhere eq ' 1 ') {
#    $listUser = 'netreg';
#  }
  $ruRef = CMU::Netdb::primitives::list
    ($dbh, $listUser, 'machine', \@CMU::Netdb::structure::machine_fields,
     "$where ".CMU::Netdb::verify_limit($start, $defitems));

  return (0, $ruRef, "ERROR with list_machine: ".$errmeanings{$ruRef}) 
    if (!ref $ruRef);
  
  unshift @$ruRef, \@CMU::Netdb::structure::machine_fields;

  my $sref = CMU::Netdb::list_subnets_ref
    ($dbh, $user, '', 'subnet.abbreviation');
  return (0, $sref, "Error in list_subnets_ref: ".$errmeanings{$sref})
    if (!ref $sref);

  if ($#$ruRef == 0) {
    if ($prewhere ne ' TRUE ') {
      return (0, 
	      $CMU::Netdb::errors::errcodes{ENOTFOUND}, 
	      "No results found. Due to user/group specification, we ".
	      "could not search for non-writable matches.");
    }else{
      return(0,
	     $CMU::Netdb::errors::errcodes{ENOTFOUND},
	     "No results found.");
    }
  }
  
  $lmach .= "&$oData" if ($oData ne '');
  $ctRow = ($#{$ruRef} < $defitems ? 0 : $start+$defitems+1);
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines", {});
  &CMU::WebInt::title("Search Machines");

  $url = $ENV{SCRIPT_NAME};
  print "<hr>";

  print &CMU::WebInt::pager_Top($start, $ctRow, $defitems,
				0, $url, "op=".$lmach, $skey);
  
  $lmach =~ s/\&sort=[^\&]+//;
  $lmach =~ s/\&\&/\&/g;
  $lmach =~ s/\&$//;

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  my $udata = {'dbh' => $dbh,
	       'sref' => $sref,
	       'dynlookup' => CMU::WebInt::helper::gParam($q, 'dynlookup')};
  CMU::WebInt::generic_tprint
    ($url, $ruRef, 
     ['machine.host_name'],
     [\&CMU::WebInt::machines::mach_cb_print_MAC_search,
      \&CMU::WebInt::machines::mach_cb_print_mode_search,
      \&CMU::WebInt::machines::mach_cb_print_IP_search,
      \&CMU::WebInt::machines::mach_cb_print_sabbr], 
     $udata, $lmach, 'op=mach_view&id=', \%machine_pos, 
     \%CMU::Netdb::structure::machine_printable,
     'machine.host_name', 'machine.id', 'sort',
     ['machine.host_name', 'machine.mac_address', 'machine.mode',
      'machine.ip_address', 'machine.ip_address_subnet']);
  
  return 1;
}

sub mach_search_pre_where {
  my ($dbh, $type, $tdata) = @_;
  my ($query, $sth);

  if ($type eq 'USER') {
    $query = "SELECT machine.id ".
      "FROM machine, users, protections, credentials AS C ".
	"WHERE C.authid = ".$dbh->quote($tdata)." AND C.user = users.id AND ".
	  "users.id = protections.identity AND ".
	"protections.tid = machine.id AND protections.tname = 'machine'";
  }elsif($type eq 'GROUP') {
    $query = "SELECT machine.id FROM machine, groups, protections WHERE ".
      "groups.name like ".$dbh->quote($tdata)." AND groups.id = -1*protections.identity AND ".
	"protections.tid = machine.id AND protections.tname = 'machine'";
  }else{
    # If this is changed, change the reference above for counts
    return ' TRUE ';
  }

  $sth = $dbh->prepare($query);
  $sth->execute;
  my (@ret, @row);
  while(@row = $sth->fetchrow_array) {
    push(@ret, $row[0]);
  }
  $sth->finish;
  if ($#ret > -1) {
    return " machine.id IN (".join(',', @ret).") ";
  }else{
    return ' 0 ';
  }
}

sub mach_unexpire {
  my ($q) = @_;
  my ($dbh, $id, $version, $userlevel, $res, $errfields, %fields, %nerrors);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::WebInt::helper::gParam($q, 'id');
  $version = CMU::WebInt::helper::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'machine', $id);

  if ($userlevel >= 1) {
    %fields = ('expires' => '0000-00-00');
  }else{
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Update Access Denied", {});
    &CMU::WebInt::title("Update Machine");
    CMU::WebInt::accessDenied('machine', 'WRITE', $id, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  ($res, $errfields) = CMU::Netdb::modify_machine($dbh, $user, $id, $version, $userlevel, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Unexpired machine.\n";
    $dbh->disconnect(); # we use this for the insertid ..
    
    if (CMU::WebInt::helper::gParam($q, 'back_op') eq 'mach_expire_list') {
      my @vars = $q->param();
      foreach my $oldvar (@vars) {
	my $new = $oldvar;
	if ($new =~ /^back_/) {
	  $new =~ s/^back_//;
	  $q->param($new, $q->param($oldvar));
	}else{
	  $q->delete($oldvar);
	}
      }
      &CMU::WebInt::mach_expire_list($q, \%nerrors);
      return;
    }

    &CMU::WebInt::mach_view($q, \%nerrors);
  }else{
    foreach (@$errfields) {
      $nerrors{$_} = 1;
    }
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
    $nerrors{'type'} = 'ERR';
    $nerrors{'loc'} = 'mach_unexpire';
    $nerrors{'code'} = $res;
    $nerrors{'fields'} = join(',', @$errfields);
    $dbh->disconnect();
    &CMU::WebInt::mach_view($q, \%nerrors);
  }
}

sub mach_expire {
  my ($q) = @_;
  my ($dbh);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
 
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'machine', 0);

  if ($ul < 9) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Expire Access Denied", {});
    &CMU::WebInt::title("Expire Access Denied");
    CMU::WebInt::accessDenied('machine', 'WRITE', 0, 9, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }  
  print &CMU::WebInt::stdhdr($q, $dbh, $user, "Expire Machines", {});
  CMU::WebInt::title("Expire Machines");
  print &CMU::WebInt::subHeading("Expiration Results");
  print "<ul>";
  
  my $ndays = CMU::WebInt::helper::gParam($q, 'days');
  if ($ndays eq '') {
    print "<li>No interval specified, setting machines to expire 30 days from now.";
    $ndays = 30;
  }else{
    print "<li>Setting machines to expire <b>$ndays</b> from now";
  }

  my @expire = CMU::WebInt::helper::gParam($q, 'i');
  foreach(@expire) {
    my ($id, $version) = split('-', $_);
    my ($res, $errfields) = CMU::Netdb::expire_machine($dbh, $user, $id, $version, 
						       "(now() + interval $ndays day)");
    if ($res > 0) {
      print "<li>Successfully expired $id\n";
    }else{
      print "<li>Error expiring $id (".$errmeanings{$res}."); fields: [".join(', ', @$errfields)."]\n";
    }    
  }
  print "</ul>\n";
  print CMU::WebInt::stdftr($q);
}

sub device_add_presence {
    my ($q, $errors) = @_;
    my (%fields, $res, %error, $dbh, $ref, $userlevel);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();

    %fields = ('trunk_set' => CMU::WebInt::gParam($q, 'tid'),
		'type' => 'machine');
    $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'trunkset_machine_presence', 0);
    if($userlevel < 9) {
	print &CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", $errors);
	&CMU::WebInt::title("Add Error");
	CMU::WebInt::accessDenied('trunkset_machine_presence', 'ADD', 0,
				  9, $userlevel, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    my $dev_name = CMU::WebInt::gParam($q, 'device');
    my $sref  = CMU::Netdb::list_machines($dbh, $user, "machine.host_name=\"$dev_name\"");
    if (!ref $sref) {
	$error{msg} = "Error Getting Device Information ";
	$error{type} = 'ERR';
	$error{loc} = 'device_add_presence';
    } else {
	if (!defined $sref->[1]) {
	    $error{msg} = "Error Finding $dev_name from machine";
	    $error{type} = 'ERR';
	    $error{loc} = 'device_add_presence';
	} else {
	    my @mdata = @{$sref->[1]};
	    my $dev_id = $mdata[$CMU::WebInt::machine::machine_pos{'machine.id'}];
	    $fields{device} = $dev_id;
	    ($res, $ref) = CMU::Netdb::add_trunkset_presence($dbh, $user, \%fields);
	    if ($res != 1) {
		$error{msg} = "Error adding  Device to Trunk Set: ".$errmeanings{$res};
		$error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
		    if ($res eq $CMU::Netdb::errcodes{EDB});
		$error{msg} .= " [".join(',', @$ref)."] ";
		$error{type} = 'ERR';
		$error{loc} = 'device_add_presence';
		$error{code} = $res;
		$error{fields} = join(',', @$ref);
	    } else {
		$error{msg} = "Device Added to Trunk Set";
	    }
	}
    }

    $dbh->disconnect();
    &CMU::WebInt::trunkset_view($q,\%error);
}

## Just In Time lookup of a user
## When a user enters the system and it doesn't have any information about
## them, exec an administrator-defined utility that can perform whatever
## local functions are necesary to retrieve user information (name, full
## userid, comment, flags) and insert the user ID into the system.
sub mach_jit_add_user {
    my ($dbh, $user, $jitInfo) = @_;

    if (!defined $jitInfo->{'exec'} ||
	!defined $jitInfo->{'insert_user'}) {

	warn __FILE__, ':', __LINE__, ' :>'.
	    "JustInTime user lookup: cannot run as 'exec' or 'insert_user' ".
	    "undefined in netreg-webint configuration.";
	return;
    }

    warn __FILE__, ':', __LINE__, ' :>'.
	"JustInTime lookup of $user: begin." if ($debug >= 1);

    alarm(10);
    my $exec = $jitInfo->{'exec'};
    alarm(0);

    my $jitUserInfo = `$exec $user`;
    my ($userid, $name, $comment, $flags, $dgname, $dgdesc) = split(/\n/, $jitUserInfo);
    return if ($userid eq '');

    # Resolve the default group name into an ID
    my $DGID = 0;
    if ($dgname ne '') {
      my $grpRef = CMU::Netdb::list_groups($dbh, $jitInfo->{'insert_user'},
	                                   " name = \"$dgname\" ");

      if (ref $grpRef && scalar(@$grpRef) > 1) {
        my %grpMap = %{CMU::Netdb::makemap($grpRef->[0])};
        $DGID = $grpRef->[1]->[$grpMap{'groups.id'}];
      }elsif(ref $grpRef && scalar(@$grpRef) == 1) {
        # No entries
        my $grpRes;
        ($grpRes, $grpRef) = CMU::Netdb::add_group($dbh, $jitInfo->{'insert_user'},
						   {'name' => $dgname,
						    'description' => $dgdesc});
        if ($grpRes == 1) {
          $DGID = $grpRef->{'insertID'};
        }
      }
    }

    CMU::Netdb::xaction_begin($dbh);

    my ($res, $ref) = CMU::Netdb::add_user($dbh, $jitInfo->{'insert_user'},
					   {'flags' => $flags,
					    'comment' => $comment,
					    'default_group' => $DGID});
    if ($res != 1) {
	warn __FILE__, ':', __LINE__, ' :>'.
	    "JustInTime: error in add_user: $res, ".join(',', @$ref)
	    if ($debug >= 1);
	CMU::Netdb::xaction_rollback($dbh);
	return;
    }

    ($res, $ref) = CMU::Netdb::add_credentials($dbh, $jitInfo->{'insert_user'},
					       {'authid' => $userid,
						'description' => $name,
						'user' => $ref->{'insertID'}});
    if ($res != 1) {
	warn __FILE__, ':', __LINE__, ' :>'.
	    "JustInTime: error in add_credentials: $res, ".join(',', @$ref)
	    if ($debug >= 1);
	CMU::Netdb::xaction_rollback($dbh);
	return;
    }
    CMU::Netdb::xaction_commit($dbh);

    warn __FILE__, ':', __LINE__, ' :>'.
	"JustInTime lookup of $user: success." if ($debug >= 1);
}

sub mach_find_lease {
    my ($q, $errors) = @_;
    my ($dbh, $res, $url, $leases);
    
    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    CMU::WebInt::setHelpFile('mach_find_lease');
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Leases", $errors);
    &CMU::WebInt::title("Find Leases");
    
    $url = $ENV{SCRIPT_NAME};
    print "<hr>";
    print CMU::WebInt::errorDialog($url, $errors);

    # Print the form

    # IP Address, MAC Address, Client Hostname, Time
    print $q->start_form(-method => 'GET');
    print $q->hidden(-name => 'op',
		     -override => 1,
		     -value => 'mach_find_lease_exec');
    print "<table border=0>";

    # MAC
    print "<tr>".
      CMU::WebInt::printPossError
      (0, $CMU::Netdb::structure::machine_printable{'machine.mac_address'},
       1, 'mac_address')."</td><td>".$q->textfield(-name => 'mac_address',
						   -accesskey => 'm').
						   "</td></tr>";

    # IP
    print "<tr>".
      CMU::WebInt::printPossError
      (0, $CMU::Netdb::structure::machine_printable{'machine.ip_address'},
       1, 'ip_address')."</td><td>".$q->textfield(-name => 'ip_address',
						   -accesskey => 'i').
						   "</td></tr>";    
    # Host name
    print "<tr>".
	CMU::WebInt::printPossError
	(0, $CMU::Netdb::structure::machine_printable{'machine.host_name'},
	 1, 'host_name')."</td><td>".$q->textfield(-name => 'name',
						   -accesskey => 'h').
						   "</td></tr>";

    # Time
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time)
;
    $year += 1900;
    $mon += 1;
    my ($cur_date) = sprintf( "%02d/%02d/%04d", $mon, $mday, $year);
    my ($cur_time) = sprintf( "%02d:%02d:%02d", $hour, $min, $sec);

    print "<tr>".
	CMU::WebInt::printPossError
	(0, 'Time',
	 1, 'time')."</td><td>";
    print $q->textfield(-name => 'time',
			-default => "$cur_date $cur_time",
			-accesskey => 't').
			    "</td></tr>";

    print "<tr><td>".$q->submit(-value => 'Search Leases')."</td></tr>\n";
    print "</table>\n";
    
    print CMU::WebInt::stdftr($q);
    return;
}

sub mach_find_lease_exec {
    my ($q, $errors) = @_;
    my ($dbh, $res, $url, $leases);
    
    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    CMU::WebInt::setHelpFile('mach_find_lease');
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Leases", $errors);
    &CMU::WebInt::title("Find Leases");
    
    $url = $ENV{SCRIPT_NAME};
    print "<hr>";
    print CMU::WebInt::errorDialog($url, $errors);

    my %fields;

    foreach my $f (qw/ip_address name mac_address/) {
	$fields{$f} = CMU::WebInt::gParam($q, $f);
    }
    my $M = canon_macaddr($fields{'mac_address'});
    $fields{'mac_address'} = join(':', map { substr($M, $_, 2) } (0,2,4,6,8,10));

    my $time = CMU::WebInt::gParam($q, 'time');
    my $ptime = Time::ParseDate::parsedate($time);
    
    ($res, $leases) = CMU::Netdb::search_leases($dbh, $user, \%fields, $ptime);
    if ($res != 1) {
	my %err = ('msg' => "Error executing lease search [$res]: ".join(',', @$leases),
		   'type' => 'ERR',
		   'loc' => 'find_lease',
		   'code' => $res,
		   'fields' => join(',', @$leases));
	print CMU::WebInt::errorDialog($url, \%err);
	print CMU::WebInt::stdftr($q);
	return;
    }

    # Work on the data a bit
    my @Data;
    
    my @Header = qw/ip_address mac_address start end binding_state
	client_hostname /;
    push(@Data, \@Header);
    foreach my $K (keys %$leases) {
	my @Row;
	foreach my $F (@Header) {
	    my $V = $leases->{$K}->{$F};
	    if ($F eq 'ip_address') {
		$V = "<a href=\"$url?op=mach_s_exec&ipt=is&ip_address=$V\">$V</a>";
	    }elsif($F eq 'mac_address') {
		$V = "<a href=\"$url?op=mach_s_exec&mac_address=$V\">$V</a>";
	    }elsif($F eq 'client_hostname') {
		$V = "<a href=\"$url?op=mach_s_exec&host_name=$V\">$V</a>";
	    }elsif($F eq 'ddns_fwdname') {
		$V = "<a href=\"$url?op=mach_s_exec&host_name=$V\">$V</a>";
	    }elsif($F eq 'start' || $F eq 'end') {
		$V = localtime($V);
	    }

	    push(@Row, $V);
	}
	push(@Data, \@Row);
    }

    my %pos = %{CMU::Netdb::makemap(\@Header)};
    my %printable = ('ip_address' => 'IP Address',
		     'mac_address' => 'MAC Address',
		     'start' => 'Start',
		     'end' => 'End',
		     'binding_state' => 'State',
		     'client_hostname' => 'Client Hostname');
    

    CMU::WebInt::generic_smTable($url, \@Data, \@Header, \%pos, \%printable,
		    '', '', '', '', '');

    print CMU::WebInt::stdftr($q);
    return;
}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 8
# perl-indent-level: 2
# cperl-indent-level: 2
# End:
