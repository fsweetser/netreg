#   -*- perl -*-
#
# CMU::WebInt::subnets
# This module provides the subnet management interfaces.
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
# $Id: subnets.pm,v 1.78 2008/03/27 19:42:38 vitroth Exp $
#
# Change

package CMU::WebInt::subnets;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings %subnet_pos 
	     %subnet_pres_pos %subnet_dom_pos %subnet_dom_zone_pos
	     %subnet_vlan_pres_pos %subnet_registration_modes_pos
	     %subnet_sh_pos %subnet_p %AllocationMethods $debug);
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

@EXPORT = qw(subnets_main subnets_view subnets_add_domain subnets_del_domain
	     subnets_add_presence subnets_del_presence subnets_update
	     subnets_delete subnets_deleteConfirm subnets_share_list
	     subnets_view_share subnets_add_share_form subnets_add_share
	     subnets_del_share subnets_del_share_confirm subnets_share_update
	     subnets_add_form subnets_add subnets_show_policy vlan_subnet_presence_add
	     vlan_subnet_presence_del);

%errmeanings = %CMU::Netdb::errors::errmeanings;
%subnet_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_fields)};
%subnet_pres_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_presence_fields)};
%subnet_dom_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_domain_fields)};
%subnet_dom_zone_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_domain_zone_fields)};
%subnet_sh_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_share_fields)};
%subnet_vlan_pres_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::vlan_subnet_presence_subnetvlan_fields)};
%subnet_registration_modes_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_registration_modes_fields)};

%subnet_p = %CMU::Netdb::structure::subnet_printable;

%AllocationMethods = %CMU::Netdb::structure::AllocationMethods;

$debug = 0;

sub subnets_main {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('sub_main');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Admin", $errors);
  &CMU::WebInt::title("List of Subnets");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'subnet', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  print CMU::WebInt::smallRight("[<b><a href=\'$url?op=listShare\'>List Subnet Shares</a></b>]".
				" [<b><a href=\'$url?op=sub_add_form\'>Add Subnet</a></b>] ".
				CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::errorDialog($url, $errors);

  my $sbn = CMU::Netdb::list_subnets_ref($dbh, $user, '', 'subnet.name');
  if (ref $sbn) {
    my @sbk = sort { $$sbn{$a} cmp $$sbn{$b} } keys %$sbn;
    unshift(@sbk, '--select--');
    print "<form method=get>\n<input type=hidden name=op value=sub_info>\n";
    print CMU::WebInt::smallRight($q->popup_menu(-name => 'sid',
						 -accesskey => 's',
						 -values => \@sbk,
						 -labels => $sbn) 
				  . "\n<input type=submit value=\"View Subnet\"></form>\n");

  } else {
    &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
			     'Error loading subnets (list_subnets_ref).', {});
  }


  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'subnet.base_address' if ($sort eq '');
  
  $res = subnets_print_subnet($user, $dbh, $q,
			      " subnet.id != 0 ".
                              CMU::Netdb::verify_orderby($sort), '',
			      $ENV{SCRIPT_NAME}, "op=sub_main&sort=$sort", 'start');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub subnets_lookup {
  my ($q, $errors) = @_;
  
  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $url = $ENV{SCRIPT_NAME};

  CMU::WebInt::setHelpFile('sub_lookup');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Lookup", $errors);
  &CMU::WebInt::title("Subnet Lookup");

  print "<hr>This page allows you to lookup the name of a subnet based on a known ".
    "IP address in the subnet and retrieve basic configuration information ".
      "of the subnet.<br>";
  
  print "<form method=get><input type=hidden name=op value=subnets_lookup>\n";

  print CMU::WebInt::subHeading("Subnet Query");
  print "Enter the IP Address that you wish to retrieve subnet information for.<br><br>";
  print "<font size=+1><B>IP Address:</B></font> <input type=text name=qip>&nbsp;
<input type=submit value=\"Lookup Subnet of IP\">";

  my $Q_IP = CMU::WebInt::gParam($q, 'qip');
  if ($Q_IP eq '') {
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  print "<br><br>".CMU::WebInt::subHeading("Query Results");

  my $subnet = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.base_address = (INET_ATON('$Q_IP') & ".
					    "subnet.network_mask)", 'subnet.name');
  if (!ref $subnet) {
    print "Error reading subnet.<br>\n";
    &CMU::WebInt::admin_mail('machines.pm:subnets_lookup', 'WARNING',
		'Error loading subnet.',
		{"Query" => $Q_IP});
  }else{
    my @MatchingSubnets = keys %$subnet;
    if ($#MatchingSubnets < 0) {
      print "No subnets matching the query were found.\n";
    }elsif($#MatchingSubnets == 0) {
      my $SID = $MatchingSubnets[0];
      print "The IP <B>$Q_IP</B> is in the subnet: <b>$subnet->{$SID}</b>.";
      ## See if they can register on this subnet
      my $sGet = CMU::Netdb::get_subnets_ref($dbh, $user, "subnet.id = '$SID'", 'subnet.name');
      if (!ref $sGet || !defined $sGet->{$SID}) {
	print "<br>You do not have authorization to register machines in this subnet.";
      }else{
	print "<br>You can <a href=\"$url?op=mach_reg_s1&subnet=$MatchingSubnets[0]&subnetNEXT=Continue\">".
	  "Register a New Machine</a> on this subnet by selecting the link.";
      }
      print "<br><br>The following subnet configuration information is presented with the following ".
	"notice: We strongly encourage the use of DHCP, as it provides all the necessary settings ".
	  "and enables network changes with minimal disruption to your network connectivity.";
      print "<br><ul>";

      # Base Address -- Get from the subnet information
      print "<li>";
      my $base = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$SID'", 'subnet.base_address');
      my $BASE_ADDR;
      if (!ref $base | !defined $base->{$SID}) {
	print " Base address could not be located.\n";
      }else{
	$BASE_ADDR = CMU::Netdb::long2dot($base->{$SID});
	print "<B>Base Address</B>: $BASE_ADDR\n";
      }

      # Network Mask -- GET FROM DHCP, or fall back to using the subnet netmask
      print "<li>";
      my $dhcp_nm = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid = '$SID' ".
						  "AND dhcp_option.type = 'subnet' AND ".
						  " dhcp_option_type.name = 'option subnet-mask'");
      my $NETMASK;
      if (ref $dhcp_nm && $#$dhcp_nm > 0) {
	print "<B> Network Mask: </B>".
	  $dhcp_nm->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]." (DHCP Option)\n";
      }else{
	my $netmask = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$SID'", 'subnet.network_mask');

	if (!ref $netmask || !defined $netmask->{$SID}) {
	  print " Network mask could not be located.\n";
	}else{
	  $NETMASK = CMU::Netdb::long2dot($netmask->{$SID});
	  print "<B>Network Mask: </B>$NETMASK (from subnet configuration)\n";
	}
      }

      # Broadcast address -- GET FROM DHCP, or fall back to using the calculated broadcast
      print "<li>";
      my $dhcp_bcast = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid = '$SID' ".
						     "AND dhcp_option.type = 'subnet' AND ".
						     " dhcp_option_type.name = 'option broadcast-address'");
      
      if (ref $dhcp_bcast && $#$dhcp_bcast > 0) {
	print "<B> Broadcast Address: </B>".
	  $dhcp_bcast->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]." (DHCP Option)\n";
      }else{
	my $BROADCAST = CMU::Netdb::long2dot(CMU::Netdb::dot2long($BASE_ADDR) |
					     ~CMU::Netdb::dot2long($NETMASK));
	print "<B>Broadcast Address: </B>$BROADCAST (calculated)\n";
      }

      # Default Gateway -- GET FROM DHCP
      print "<li>";
      my $dhcp_dg = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid = '$SID' ".
						  "AND dhcp_option.type = 'subnet' AND ".
						  " dhcp_option_type.name = 'option routers'");
      if (ref $dhcp_dg && $#$dhcp_dg > 0) {
	print "<B> Default Gateway: </B>".
	  $dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}]." (DHCP Option)\n";
      }else{
	print " Default gateway is unknown (not a DHCP option).\n";
      }
    }else{
      print "The IP <B>$Q_IP</B> is in multiple subnets:\n<ul>\n";
      foreach(@MatchingSubnets) {
	print "<li>$subnet->{$_}\n";
      }
      print "</ul>";
      print "<br>This is most likely a system error; registration on these subnets may not provide".
	"network connectivity.";
    }
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


# subnets_print_subnet
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the subnet WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub subnets_print_subnet {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'subnet', $cwhere);
  
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
  $ruRef = CMU::Netdb::list_subnets($dbh, $user, " $where ".
				    CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_subnet: ".$errmeanings{$ruRef};
    return 0;
  }

  

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['subnet.name', 'subnet.abbreviation'],
		 [\&CMU::WebInt::subnets::subnets_cb_base_address,
		  \&CMU::WebInt::subnets::subnets_cb_network_mask], '',
		 'sub_main', 'op=sub_info&sid=',
		 \%subnet_pos, 
		 \%CMU::Netdb::structure::subnet_printable,
			      'subnet.name', 'subnet.id', 'sort', 
			      ['subnet.name', 'subnet.abbreviation', 'subnet.base_address',
			       'subnet.network_mask']);
  
  return 1;
}

# callbacks to print the addresses
sub subnets_cb_print_IP {
  my ($key, $url, $row, $edata) = @_;
  return $CMU::Netdb::structure::subnet_printable{$key} if (!ref $row);
  my @rrow = @{$row};
  return CMU::Netdb::long2dot($rrow[$subnet_pos{$key}]);
}

sub subnets_cb_base_address { subnets_cb_print_IP('subnet.base_address', @_); }
sub subnets_cb_network_mask { subnets_cb_print_IP('subnet.network_mask', @_); }

sub subnets_cb_delete_share {
  my ($url, $row, $edata) = @_;
  return "Operations" if (!ref $row);
  return "<a href=\"$url?op=deleteShare&sid=".$$row[$subnet_pos{'subnet.share'}].
    "\">Delete</a>\n";
}



########################################################################
## subnets_view
##  -- Prints info about a subnet

sub subnets_view {
  my ($q, $errors) = @_;
  my ($dbh, $sid, $url, $res);
  my (@sharekey);

  $sid = CMU::WebInt::gParam($q, 'sid');
  $$errors{msg} = "Subnet ID not specified!" if ($sid eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('sub_info');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Admin", $errors);
  &CMU::WebInt::title("Subnet Information");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'subnet', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # basic subnet information (name, abbreviation, base address, netmask
  # dynamic info, expire static, expire dynamic
  my $sref = CMU::Netdb::list_subnets($dbh, $user, "subnet.id='$sid'");
  if (!ref $sref) {
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  if ($#$sref == 0) {
    print "The specified subnet ID does not exist.<br><br>\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  my @sdata = @{$sref->[1]};
  
  print CMU::WebInt::subHeading("Information for: ".$sdata[$subnet_pos{'subnet.name'}], CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=$url?op=sub_info&sid=$sid>Refresh</a></b>] 
 [<b><a href=$url?op=prot_s3&table=subnet&tidType=1&tid=$sid>View/Update Protections</a></b>] 
 [<b><a href=$url?op=sub_delete&sid=$sid>Delete Subnet</a></b>]<br>
 [<b><a href=$url?op=mach_s_exec&ip_address_subnet=$sid>View Machines</a></b>]
 [<b><a href=$url?op=subnets_addips&sid=$sid>Bulk IP Registration</a></b>]");

  # name, abbreviation
  print "<table border=0><form method=get>
<input type=hidden name=sid value=$sid>
<input type=hidden name=op value=sub_update>
<input type=hidden name=version value=\"".$sdata[$subnet_pos{'subnet.version'}]."\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $subnet_p{'subnet.name'}, 1, 'subnet.name').
  CMU::WebInt::printPossError(defined $errors->{'abbreviation'}, $subnet_p{'subnet.abbreviation'}, 1, 'subnet.abbreviation').
    "</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('subnet.name', $verbose).
  $q->textfield(-name => 'sname', -accesskey => 's', -value => $sdata[$subnet_pos{'subnet.name'}]).
    "</td><td>".CMU::WebInt::printVerbose('subnet.abbreviation', $verbose).
      $q->textfield(-name => 'abbr', -accesskey => 'a',
		    -value => $sdata[$subnet_pos{'subnet.abbreviation'}])."</td></tr>\n";

  # base address, network mask
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'base_address'}, $subnet_p{'subnet.base_address'}, 1, 'subnet.base_address').
CMU::WebInt::printPossError(defined $errors->{'network_mask'}, $subnet_p{'subnet.network_mask'}, 1, 'subnet.network_mask').
"</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('subnet.base_address', $verbose).
  $q->textfield(-name=> 'base_address', -accesskey => 'b',
		-value=>CMU::Netdb::long2dot($sdata[$subnet_pos{'subnet.base_address'}]))."</td><td>".CMU::WebInt::printVerbose('subnet.network_mask', $verbose).
  $q->textfield(-name=> 'network_mask', -accesskey => 'n',
		-value=>CMU::Netdb::long2dot($sdata[$subnet_pos{'subnet.network_mask'}]))."</td></tr>\n";

  # network summary, vlan number
  print "<tr>".CMU::WebInt::printPossError(0, "Network Summary", 1);
#.CMU::WebInt::printPossError(0,$subnet_p{'subnet.vlan'}, 1, 'subnet.vlan').
  print "</tr><tr><td>Range of addresses: ".CMU::Netdb::long2dot($sdata[$subnet_pos{'subnet.base_address'}])." - ".
    CMU::Netdb::calc_bcast(CMU::Netdb::long2dot($sdata[$subnet_pos{'subnet.base_address'}]),
			   CMU::Netdb::long2dot($sdata[$subnet_pos{'subnet.network_mask'}]))."</td></tr>\n";
#<td>".CMU::WebInt::printVerbose('subnet.vlan',$verbose).
#  $q->textfield(-name=>'vlan', -accesskey => 'v', -value=>$sdata[$subnet_pos{'subnet.vlan'}])."</td></tr>\n";

  # expire static, expire dynamic
print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'expire_static'}, $subnet_p{'subnet.expire_static'}, 1, 'subnet.expire_static').
CMU::WebInt::printPossError(defined $errors->{'expire_dynamic'}, $subnet_p{'subnet.expire_dynamic'}, 1, 'subnet.expire_dynamic')."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('subnet.expire_static', $verbose).
  $q->textfield(-name=> 'expire_static', -accesskey => 'e',
		-value=>$sdata[$subnet_pos{'subnet.expire_static'}])." sec.";
  print "</td><td>".CMU::WebInt::printVerbose('subnet.expire_dynamic', $verbose).
  $q->textfield(-name=> 'expire_dynamic', -accesskey => 'e',
		-value=>$sdata[$subnet_pos{'subnet.expire_dynamic'}])." sec.</td></tr>\n";

  # dynamic and share
  my $sshares = CMU::Netdb::list_subnet_shares_ref($dbh, $user, '');

  if (!ref $sshares) {
    print "ERROR: ".$errmeanings{$sshares};
  }else{
    @sharekey = sort {lc($sshares->{$a}) cmp lc($sshares ->{$b})} keys %$sshares;
    unshift(@sharekey, 0);
    $$sshares{0} = 'None';
  }

  my @sdynamic = @CMU::Netdb::structure::subnet_dynamic;
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'dynamic'}, $subnet_p{'subnet.dynamic'}, 1, 'subnet.dynamic').
CMU::WebInt::printPossError(defined $errors->{'share'}, $subnet_p{'subnet.share'}, 1, 'subnet.share')."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('subnet.dynamic', $verbose).
    $q->popup_menu(-name=> 'dynamic', -accesskey => 'd',
		   -default=>$sdata[$subnet_pos{'subnet.dynamic'}],
		   -values=>\@sdynamic).
		     "</td><td>".CMU::WebInt::printVerbose('subnet.share', $verbose);
  my $share = $sdata[$subnet_pos{'subnet.share'}];
  
  if (!grep(/$share/, @sharekey)) {
    print "$share<input type=submit name=share value=$share>\n";
  }else{
    print $q->popup_menu(-name => 'share', -accesskey => 's',
			 -default=>$sdata[$subnet_pos{'subnet.share'}],
			 -values=>\@sharekey,
			 -labels=>$sshares).
			   "</td></tr>";
  }
  
  # flags, default_mode
  print "<tr>".CMU::WebInt::printPossError(defined $errors->{'flags'}, $subnet_p{'subnet.flags'}, 1, 'subnet.flags') . CMU::WebInt::printPossError(defined $errors->{'default_mode'}, $subnet_p{'subnet.default_mode'}, 1, 'subnet.default_mode');
  my @pflag = split(/\,/, $sdata[$subnet_pos{'subnet.flags'}]);
  print "</tr><tr><td>".CMU::WebInt::printVerbose('subnet.flags', $verbose).
    $q->checkbox_group(-name => 'flags',
		       -values => \@CMU::Netdb::structure::subnet_flags,
		       -default => \@pflag,
		       -linebreak => 'true').
			 "</td>\n";
  my @sdefaultmodes = @CMU::Netdb::structure::subnet_default_mode;
  print "<td>".CMU::WebInt::printVerbose('subnet.default_mode', $verbose).
    $q->popup_menu(-name=> 'default_mode', -accesskey => 'd',
		   -default=>$sdata[$subnet_pos{'subnet.default_mode'}],
		   -values=>\@sdefaultmodes).
		     "</td></tr>\n";

  # purge_interval, purge_explen
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'purge_interval'}, $subnet_p{'subnet.purge_interval'}, 1, 'subnet.purge_interval').
CMU::WebInt::printPossError(defined $errors->{'purge_explen'}, $subnet_p{'subnet.purge_explen'}, 1, 'subnet.purge_explen')."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('subnet.purge_interval', $verbose).
  $q->textfield(-name=> 'purge_interval', -accesskey => 'p',
		-value=>$sdata[$subnet_pos{'subnet.purge_interval'}])." days";
  print "</td><td>".CMU::WebInt::printVerbose('subnet.purge_explen', $verbose).
  $q->textfield(-name=> 'purge_explen', -accesskey => 'p',
		-value=>$sdata[$subnet_pos{'subnet.purge_explen'}])." days</td></tr>\n";

  # purge_notseen, purge_notupd
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'purge_notseen'}, $subnet_p{'subnet.purge_notseen'}, 1, 'subnet.purge_notseen').
CMU::WebInt::printPossError(defined $errors->{'purge_notupd'}, $subnet_p{'subnet.purge_notupd'}, 1, 'subnet.purge_notupd')."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('subnet.purge_notseen', $verbose).
  $q->textfield(-name=> 'purge_notseen', -accesskey => 'p',
		-value=>$sdata[$subnet_pos{'subnet.purge_notseen'}])." days";
  print "</td><td>".CMU::WebInt::printVerbose('subnet.purge_notupd', $verbose).
  $q->textfield(-name=> 'purge_notupd', -accesskey => 'p',
		-value=>$sdata[$subnet_pos{'subnet.purge_notupd'}])." days</td></tr>\n";

  # Last update, last purge
  print "<tr>".CMU::WebInt::printPossError(0, $subnet_p{'subnet.version'}).
    CMU::WebInt::printPossError(0, $subnet_p{'subnet.purge_lastdone'}).
      "</tr><tr><td>";
  my $LU;
  if ($sdata[$subnet_pos{'subnet.version'}] =~ /(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
    $LU = "$1-$2-$3 $4:$5:$6\n";
  } else {
    $LU = $sdata[$subnet_pos{'subnet.version'}];
  }
  my $PLD = $sdata[$subnet_pos{'subnet.purge_lastdone'}];
  
  print "$LU</td><td>$PLD</td></tr>\n";

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n";
  
  print "</table></form>\n";

  # Registration types/quotas
  print "<br>\n".CMU::WebInt::subHeading("Registration Types & Quotas", CMU::WebInt::pageHelpLink('subnet_registration_modes'));
  my $modes = CMU::Netdb::list_subnet_registration_modes($dbh, $user, "subnet_registration_modes.subnet='$sid' ORDER BY subnet_registration_modes.mode ASC, subnet_registration_modes.mac_address ASC, subnet_registration_modes.quota DESC");
  my $extra;
  $extra->{'##q--'} = $q;
  $extra->{'##sid--'} = $sid;
  $extra->{'##dbh--'} = $dbh;
  $extra->{'##dbuser--'} = $user;
  foreach my $entry (@$modes) {
    if (!defined($entry->[$subnet_registration_modes_pos{'subnet_registration_modes.quota'}])) {
      $entry->[$subnet_registration_modes_pos{'subnet_registration_modes.quota'}] = "Unlimited";
    }
  }

  CMU::WebInt::generic_tprint($url, $modes, 
			      ['subnet_registration_modes.mode',
			       'subnet_registration_modes.mac_address',
			       'subnet_registration_modes.quota'],
			      [\&CMU::WebInt::subnets::subnets_cb_mode_permissions, 
			       \&CMU::WebInt::subnets::subnets_cb_mode_operations],
			      $extra,
			      'sub_info',
			      undef,
			      \%subnet_registration_modes_pos,
			      \%CMU::Netdb::structure::subnet_registration_modes_printable,
			      undef,
			      'subnet_registration_modes.id',
			      'sort_modes',
			      undef,
			      \&CMU::WebInt::subnets::subnets_cb_add_mode,
			      $extra);


  # vlans in this subnet
  print "<br>\n".CMU::WebInt::subHeading("VLANS in this Subnet", CMU::WebInt::pageHelpLink('subnet_vlan'));
  my $vref = CMU::Netdb::list_subnet_presences($dbh, $user, "vlan_subnet_presence.subnet='$sid'");
  my $sname = CMU::Netdb::list_vlans_ref($dbh, $user, '' ,'vlan.name');
  $$sname{'##q--'}	= $q;
  $$sname{'##sid--'}	= $sid;
  my %printable = (%CMU::Netdb::structure::vlan_subnet_presence_printable, 
		   %CMU::Netdb::structure::vlan_printable);
  CMU::WebInt::generic_smTable($url, $vref, ['vlan.name'], \%subnet_vlan_pres_pos,
				\%printable,
				"sid=$sid", 'vlan_subnet_presence', 'sub_del_pres',
				\&CMU::WebInt::subnets::subnets_cb_add_presence,
				$sname, 'vlan_subnet_presence.vlan', "op=vlan_info&vid=");

  # subnet domains (list of domains)
 print "<br>\n".CMU::WebInt::subHeading("Domains Allowed on this Subnet",
                                   CMU::WebInt::pageHelpLink('subnet_domain'));
  my $dref = CMU::Netdb::list_subnet_domains($dbh, $user,
                                "subnet='$sid' ORDER BY subnet_domain.domain",
                                1);
  # grab only forward zones
  $sname = CMU::Netdb::list_zone_ref($dbh, $user, 'type like \'fw%\'');
  $$sname{'##q--'}   = $q;
  $$sname{'##sid--'} = $sid;
  CMU::WebInt::generic_smTable($url, $dref, ['subnet_domain.domain'], 
 		               \%subnet_dom_zone_pos, 
		               \%CMU::Netdb::structure::subnet_domain_printable, 
			       "sid=$sid", 'subnet_domain', 'sub_del_domain',
			       \&CMU::WebInt::subnets::subnets_cb_add_domain, $sname,
			       'dns_zone.id', "op=zone_info&id=");

  # DHCP options
  print CMU::WebInt::subHeading("DHCP Options", CMU::WebInt::pageHelpLink('dhcp_option'));
  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=subnets_ddo&sid=$sid\">".
				"Set Standard Options</a></b>]  ".
				"[<b><a href=\"$url?op=mach_dhcp_add&tid=$sid&type=subnet\">".
				"Add DHCP Option</a></b>]\n");
  
  my $ldor = CMU::Netdb::list_dhcp_options($dbh, $user, " dhcp_option.tid = '$sid' AND ".
					   " dhcp_option.type = 'subnet'");
  
  if (!ref $ldor) {
    print "Unable to find DHCP Options.\n";
  }else{
    CMU::WebInt::generic_tprint($url, $ldor, 
		   ['dhcp_option_type.name', 'dhcp_option.value'],
		   [\&CMU::WebInt::machines::mach_cb_dhcp_opt_del],
		   "subnet&tid=$sid", '', '', \%CMU::WebInt::dhcp::dhcp_o_c_pos, 
		   \%CMU::Netdb::structure::dhcp_option_printable,
		   '', '', '', []);
  }


  # Attributes
  print "<br>";
  CMU::WebInt::attr_display($dbh, $user, 'subnet', $sid, "", 1);


  # Service Groups
  my $servicequery = "service_membership.member_type = 'subnet' AND ".
    "service_membership.member_tid = '$sid'";

  my ($lsmr, $rMemRow, $rMemSum, $rMemData) =
    CMU::Netdb::list_service_members($dbh, 'netreg', $servicequery);

  if ($lsmr < 0) {
    print "Unable to list Service Groups ($lsmr).\n";
    &CMU::WebInt::admin_mail('subnets.pm:subnets_view', 'WARNING',
                             'Unable to list Service Groups ($lsmr).',
                             { 'id' => $sid});
  }else {
    print "<br>" . CMU::WebInt::subHeading("Service Groups","");
    print CMU::WebInt::printVerbose('subnet_view.service_groups');

    my @data = map {
      ["<a href=\"$url?op=svc_info&sid=".$rMemRow->{$_}->{'service.id'}."\">".
       $rMemRow->{$_}->{'service.name'}."</a>", $rMemRow->{$_}->{'service_membership.id'},
       $rMemRow->{$_}->{'service_membership.version'}];
    } keys %$rMemRow;
    unshift(@data, ['service.name']);
    my $gsrr = CMU::Netdb::get_services_ref($dbh, $user, '', 'service.name');
    my %printable = (%CMU::Netdb::structure::subnets_printable, %CMU::Netdb::structure::service_printable);
    $$gsrr{'##q--'} = $q;
    $$gsrr{'##mid--'} = $sid;

    CMU::WebInt::generic_smTable($url, \@data, ['service.name'],
				 {'service.name' => 0,
				  'service_membership.id' => 1,
				  'service_membership.version' => 2},
                                 \%printable,
                                 "sid=$sid&back=subnet", 'service_membership', 'svc_del_member',
				 \&CMU::WebInt::subnets::cb_subnet_add_service,
                                 $gsrr);
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


sub subnets_cb_mode_permissions {
  my ($url, $row, $edata) = @_;
  my $dbh = $edata->{'##dbh--'};
  my $dbuser = $edata->{'##dbuser--'};
  return "Access Granted To" if (!ref $row);
  my @rrow = @$row;
  my $prots = CMU::Netdb::list_protections($dbh, $dbuser, 
					   'subnet_registration_modes',
					   $rrow[$subnet_registration_modes_pos{'subnet_registration_modes.id'}],
					   "FIND_IN_SET('ADD', P.rights)");
  if (ref $prots) {
    my (@groups, @users);
    foreach my $entry (@$prots) {
      push @groups, $entry->[1] if ($entry->[0] eq 'group');
      push @users, $entry->[1] if ($entry->[0] eq 'user');
    }
    if (@groups || @users) {
      return join(', ', sort(@groups), sort(@users));
    } else {
      return "Nobody";
    }
  } else {
    warn __FILE__, ' : ', __LINE__, "Error ($prots) while fetching protections for subnet_registration_modes entry $rrow[$subnet_registration_modes_pos{'subnet_registration_modes.id'}].";
  }
  return "";

}


sub subnets_cb_mode_operations {
  my ($url, $row, $edata) = @_;
  return "Delete" if (!ref $row);
  my @rrow = @$row;
  my $output = "<a href=$url?op=prot_s3&table=subnet_registration_modes&tidType=1&tid=".
    $rrow[$subnet_registration_modes_pos{'subnet_registration_modes.id'}].'>Modify&nbsp;Permissions</a>';

  $output .= " <a href=\"".CMU::WebInt::encURL("$url?op=subnets_del_reg_mode&id=".
    $rrow[$subnet_registration_modes_pos{'subnet_registration_modes.id'}].
      "&version=".
	$rrow[$subnet_registration_modes_pos{'subnet_registration_modes.version'}].
          "&sid=".$edata->{'##sid--'})."\">Delete</a>";

  return $output;
}

sub subnets_cb_add_mode {
  my ($cdata) = @_;
  my $subnet = $cdata->{'##sid--'};
  my $q = $cdata->{'##q--'};
  my $output = "<tr><form method=get><td>
<input type=hidden name=op value=subnets_add_reg_mode>
<input type=hidden name=sid value=$subnet>";
  $output .= $q->popup_menu(-name=>'mode',
			    -values=>\@CMU::Netdb::structure::subnet_registration_modes_modes);
  $output .= "</td>\n<td>";
  $output .= $q->popup_menu(-name=>'mac_address',
			    -values=>\@CMU::Netdb::structure::subnet_registration_modes_mac_address);
  $output .= "</td>\n<td><input type=text name=quota></td>
<td>Set permissions after creation.</td><td><input type=submit value=\"Add Mode\"></td></form></tr>\n";
}

sub cb_subnet_add_service {
  my ($sref) = @_;
  my $q = $$sref{'##q--'}; delete $$sref{'##q--'};
  my $id = $$sref{'##mid--'}; delete $$sref{'##mid--'};
  my $res = "<tr><td><form method=get>
<input type=hidden name=op value=svc_add_member>
<input type=hidden name=subnet value=$id>
<input type=hidden name=id value=$id>
<input type=hidden name=back value=subnet>\n";
  my @ss = sort {$sref->{$a} cmp $sref->{$b}} keys %$sref;
  $res .= $q->popup_menu(-name=>'sid',
                         -values=>\@ss,
                         -labels=> $sref);
  $res .= "</td><td>\n<input type=submit value=\"Add to Service Group\"></form></td></tr>\n";

}


sub subnets_set_def_dhcp_options {
  my ($q, $errors) = @_;

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $sid = CMU::WebInt::gParam($q, 'sid');
  return subnets_def_dhcp_options($q, $errors) if (!defined $sid || $sid eq '');

  # For each option type selected, go through and update the DHCP options accordingly.
  
  CMU::WebInt::setHelpFile('subnets_def_dhcp_options');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Set Default DHCP Options", 
			    $errors);
  &CMU::WebInt::title("Set Default DHCP Options");

  my $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', $sid);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'WRITE', $sid, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my %fields;
  
  print "<hr>Now setting requested DHCP options... <br><br>";
  print "<ul>";
  
  ## Load all the Option Types
  my $otl = CMU::Netdb::get_dhcp_option_types($dbh, $user, '');
  if (!ref $otl) {
    print "<li> Unable to load DHCP option types!\n</ul>";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my %OTNameToNum;
  map { $OTNameToNum{$otl->{$_}} = $_ } keys %$otl;
 
  #############################################################################
  ## If you want to add any more DHCP options that can be automatically added,
  ## put them here.
  #############################################################################

  # routers
  my $BASE_ADDRESS; # used in broadcast address calculations
  if (CMU::WebInt::gParam($q, 'routers') eq 'on') {
    ## See if one already exists, and delete it.
     my $dhcp_dg = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid = '$sid' ".
						  "AND dhcp_option.type = 'subnet' AND ".
						  " dhcp_option_type.name = 'option routers'");
     if (ref $dhcp_dg && $#$dhcp_dg > 0) {
       my ($res, $err) = CMU::Netdb::delete_dhcp_option($dbh, $user, 
							$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.id'}],
							$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.version'}]);
       if ($res > 0) {
	 print "<li><b>option routers: </b>Deleted existing option ".
	   "(".$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}].")";
       }else{
	 print "<li><b>option routers: </b>Error deleting existing option ".
	   "(".$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}].") :: ".
	     "$res [".join(',', @$err)."]";
       }
     }

     ## Get the new value
      # Get the base address + 1
     my $sinfo = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$sid'", 'subnet.base_address');
     if (!defined $sinfo || !defined $sinfo->{$sid}) {
       print "<li><B>option routers: </b>Could not load subnet information to calculate new value\n";
     }else{
       $BASE_ADDRESS = CMU::Netdb::long2dot($sinfo->{$sid}+1);
       ## Set fields
       $fields{type_id} = $OTNameToNum{'option routers'};
       $fields{value} = $BASE_ADDRESS;
       $fields{type} = 'subnet';
       $fields{tid} = $sid;
       
       ## Add the option
       my ($r, $err) = CMU::Netdb::add_dhcp_option($dbh, $user, \%fields);
       if ($r > 0) {
	 print "<li><B>option routers: </b> Added value '$BASE_ADDRESS'.\n";
       }else{
	 print "<li><B>option routers: </b> Error adding ($r): ".$errmeanings{$r}." [".
	   join(',', @$err)."]\n";
       }
     }
   }

  # subnet mask
  my $SUBNET_MASK = ''; # used in broadcast address as well
  if (CMU::WebInt::gParam($q, 'subnet-mask') eq 'on') {
    ## See if one already exists, and delete it.
    my $dhcp_dg = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid = '$sid' ".
						  "AND dhcp_option.type = 'subnet' AND ".
						  " dhcp_option_type.name = 'option subnet-mask'");
    if (ref $dhcp_dg && $#$dhcp_dg > 0) {
      my ($res, $err) = CMU::Netdb::delete_dhcp_option($dbh, $user, 
						       $dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.id'}],
						       $dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.version'}]);
      if ($res > 0) {
	print "<li><b>option subnet-mask: </b>Deleted existing option ".
	  "(".$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}].")";
      }else{
	print "<li><b>option subnet-mask: </b>Error deleting existing option ".
	  "(".$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}].") :: ".
	    "$res [".join(',', @$err)."]";
      }						  
    }
    
     ## Get the new value
      # Get the base address + 1
     my $sinfo = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$sid'", 'subnet.network_mask');
     if (!defined $sinfo || !defined $sinfo->{$sid}) {
       print "<li><B>option subnet-mask: </b>Could not load subnet information to calculate new value\n";
     }else{
       $SUBNET_MASK = CMU::Netdb::long2dot($sinfo->{$sid});
       ## Set fields
       $fields{type_id} = $OTNameToNum{'option subnet-mask'};
       $fields{value} = $SUBNET_MASK;
       $fields{type} = 'subnet';
       $fields{tid} = $sid;
       
       ## Add the option
       my ($r, $err) = CMU::Netdb::add_dhcp_option($dbh, $user, \%fields);
       if ($r > 0) {
	 print "<li><B>option subnet-mask: </b> Added value '$SUBNET_MASK'.\n";
       }else{
	 print "<li><B>option subnet-mask: </b> Error adding ($r): ".$errmeanings{$r}." [".
	   join(',', @$err)."]\n";
       }
     }
  }

  # broadcast address
  if (CMU::WebInt::gParam($q, 'broadcast-address') eq 'on') {
    ## See if one already exists, and delete it.
     my $dhcp_dg = CMU::Netdb::list_dhcp_options($dbh, 'netreg', " dhcp_option.tid = '$sid' ".
						  "AND dhcp_option.type = 'subnet' AND ".
						  " dhcp_option_type.name = 'option broadcast-address'");
     if (ref $dhcp_dg && $#$dhcp_dg > 0) {
       my ($res, $err) = CMU::Netdb::delete_dhcp_option($dbh, $user, 
							$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.id'}],
							$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.version'}]);
       if ($res > 0) {
	 print "<li><b>option broadcast-address: </b>Deleted existing option ".
	   "(".$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}].")";
       }else{
	 print "<li><b>option broadcast-address: </b>Error deleting existing option ".
	   "(".$dhcp_dg->[1][$CMU::WebInt::dhcp::dhcp_o_c_pos{'dhcp_option.value'}].") :: ".
	     "$res [".join(',', @$err)."]";
       }						  
     }
     
     ## Get the new value
     if ($BASE_ADDRESS eq '' || $SUBNET_MASK eq '') {
       my $sinfo = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$sid'", 'subnet.base_address');
       if (!defined $sinfo || !defined $sinfo->{$sid}) {
	 print "<li><B>option broadcast-address: </b>Could not load subnet information to calculate new value\n";
       }else{
	 $BASE_ADDRESS = CMU::Netdb::long2dot($sinfo->{$sid});
       }
       $sinfo = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$sid'", 'subnet.network_mask');
       if (!defined $sinfo || !defined $sinfo->{$sid}) {
	 print "<li><B>option broadcast-address: </b>Could not load subnet information to calculate new value\n";
       }else{
	 $SUBNET_MASK = CMU::Netdb::long2dot($sinfo->{$sid});
       }
     }

     # Get the base address + 1
     my $VAL = CMU::Netdb::long2dot(CMU::Netdb::dot2long($BASE_ADDRESS) |
				    ~CMU::Netdb::dot2long($SUBNET_MASK));
     ## Set fields
     $fields{type_id} = $OTNameToNum{'option broadcast-address'};
     $fields{value} = $VAL;
     $fields{type} = 'subnet';
     $fields{tid} = $sid;
     
     ## Add the option
     my ($r, $err) = CMU::Netdb::add_dhcp_option($dbh, $user, \%fields);
     if ($r > 0) {
       print "<li><B>option broadcast-address: </b> Added value '$VAL'.\n";
     }else{
       print "<li><B>option broadcast-address: </b> Error adding ($r): ".$errmeanings{$r}." [".
	 join(',', @$err)."]\n";
     }
   }


  #############################################################################

# Done. Send them back home.
print "</ul>All done. <a href=\"$url?op=sub_info&sid=$sid\">Return to Subnet Information</a>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();

}  

sub subnets_def_dhcp_options {
  my ($q, $errors) = @_;

  my $sop = CMU::WebInt::gParam($q, 'sop');
  
  return subnets_set_def_dhcp_options($q, $errors) if ($sop ne '');

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('subnets_def_dhcp_options');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Set Default DHCP Options",
			    $errors);
  &CMU::WebInt::title("Set Default DHCP Options");

  my $url = $ENV{SCRIPT_NAME};
  
  ## Get the specified subnet ID
  my $sid = CMU::WebInt::gParam($q, 'sid');
  if (!defined $sid) {
    print "Subnet ID not specified!";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  ## Verify access to the subnet
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', $sid);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'WRITE', $sid, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  ## Lookup the subnet name
  my $name = CMU::Netdb::get_subnets_ref($dbh, $user, "subnet.id = '$sid'", 'subnet.name');
  if (!defined $name || !defined $name->{$sid}) {
    print "Could not load subnet information.";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  print CMU::WebInt::subHeading("DHCP Options for: $name->{$sid}");

  print "This screen will take care of adding DHCP Options that are easily ".
    "added with \"standard\" values. Select the options below that you want ".
      "to add to this subnet. <b>Pre-existing conflicting options will be removed.</b> ";

  print "<form method=get><input type=hidden name=op value=subnets_ddo>".
    "<input type=hidden name=sid value=$sid>";
  print "The options for adding options are: <br><ul>";

  ## option routers
  print "<li><input type=checkbox name=routers CHECKED> <b>option routers</b>: ".
    " The value is set to the base address + 1.";
  
  ## option subnet-mask
  print "<li><input type=checkbox name=subnet-mask CHECKED> <b>option subnet-mask</b>: ".
    " The value is set to the configured subnet mask.";

  ## option broadcast-address
  print "<li><input type=checkbox name=broadcast-address CHECKED> <b>option broadcast-address</b>: ".
    " The value is set to the calculated broadcast address (base |~mask).";
  
  print "</ul><br><input type=submit name=sop value=\"Add/Delete Options\"></form>\n";
  print CMU::WebInt::stdftr($q);
}

sub subnets_cb_add_domain {
  my ($zref) = @_;
  my $q = $$zref{'##q--'}; delete $$zref{'##q--'};
  my $sid = $$zref{'##sid--'}; delete $$zref{'##sid--'};
  my @zs = sort values %$zref;
  my $res = "
<tr><td colspan=2><form method=get>
<input type=hidden name=op value=sub_add_domain>
<input type=hidden name=sid value=$sid>
";
  $res .= $q->popup_menu(-name => 'newDomain',
                         =>values => \@zs);
  $res .= "
<input type=submit value=\"Add Domain\"></form></td></tr>
";
  return $res;
}

sub subnets_cb_add_presence {
  my ($bref) = @_;
  my $q = $$bref{'##q--'}; delete $$bref{'##q--'};
  my $sid = $$bref{'##sid--'}; delete $$bref{'##sid--'};
  my $back = $$bref{'##back--'}; delete $$bref{'##back--'};
  my $vid = $$bref{'##vid--'}; delete $$bref{'##vid--'};
  my $id = $$bref{'##id--'}; delete $$bref{'##id--'};

  my @bs = sort {$bref->{$a} cmp $bref->{$b}} keys %$bref;

  if ($back ne 'vlan') {
    my $res = "<tr><td><form method=get>
<input type=hidden name=op value=sub_add_pres>
<input type=hidden name=sid value=$sid>
"; 
    
    $res .= $q->popup_menu(-name => 'newVlan',
			   -values => \@bs,
			   -labels => $bref);
    $res .= "
<input type=submit value=\"Add VLAN\"></form></td></tr>
";
    return $res;
  }else{
    my $res = "<tr><td><form method=get>
<input type=hidden name=op value=sub_add_pres>
<input type=hidden name=newVlan value=$vid>
<input type=hidden name=back value=vlan>
<input type=hidden name=vid value=$vid>
"; 
    
    $res .= $q->popup_menu(-name => 'sid',
			   -values => \@bs,
			   -labels => $bref);
    $res .= "
<input type=submit value=\"Add Subnet\"></form></td></tr>
";
    return $res;
  }
}

sub subnets_delete {
  my ($q) = @_;
  my ($dbh, $where, $sid, $url, $res);

  $sid = CMU::WebInt::gParam($q, 'sid');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('sub_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Admin", {});
  &CMU::WebInt::title("Delete Subnet");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  $where = " subnet.id=$sid ";

  # basic subnet information (name, abbreviation, base address, netmask
  # dynamic info, expire static, expire dynamic
  my $sref = CMU::Netdb::list_subnets($dbh, $user, "subnet.id='$sid'");
  my @sdata = @{$sref->[1]};
  
  print CMU::WebInt::subHeading("Confirm Deletion of: ".$sdata[$subnet_pos{'subnet.name'}]);
  print "Please confirm that you wish to delete the following subnet.";
  print "<br>Clicking \"Delete Subnet\" below will cause this subnet and all ".
    "associated information to be deleted.\n";
  
  print "<table border=0>
<tr><td bgcolor=lightyellow>Name</td><td>$sdata[$subnet_pos{'subnet.name'}]</td></tr>
<tr><td bgcolor=lightyellow>Abbreviation</td><td>$sdata[$subnet_pos{'subnet.abbreviation'}]</td></tr>
<tr><td bgcolor=lightyellow>Base Address</td><td>".CMU::Netdb::long2dot($sdata[$subnet_pos{'subnet.base_address'}])."</td></tr>
<tr><td bgcolor=lightyellow>Network Mask</td><td>".CMU::Netdb::long2dot($sdata[$subnet_pos{'subnet.network_mask'}])."</td></tr>
</table>
<form method=get>
<input type=hidden name=op value=sub_del_conf>
<input type=hidden name=sid value=$sid>
<input type=hidden name=version value=\"".$sdata[$subnet_pos{'subnet.version'}]."\">
<input type=submit value=\"Delete Subnet\">
</form>
";
  $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);


}

sub subnets_deleteConfirm {
  my ($q) = @_;
  my ($dbh, $id, $version);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::WebInt::gParam($q, 'sid');
  $version = CMU::WebInt::gParam($q, 'version');
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my ($res, $ref) = CMU::Netdb::delete_subnet($dbh, $user, $id, $version);
  my %errors;
  if ($res != 1) {
    $errors{msg} = "Error deleting subnet: ".$errmeanings{$res}." [".
      join(',', @$ref)."] ";

    $errors{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $errors{type} = 'ERR';
    $errors{loc} = 'subnet_del_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$ref);
  }else{
    $errors{msg} = "Subnet deleted.";
  }
  
  $dbh->disconnect();
  CMU::WebInt::subnets_main($q, \%errors);
}

sub subnets_update {
  my ($q) = @_;
  my ($dbh, $version, $id, %fields, %error);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'version');
  $id = CMU::WebInt::gParam($q, 'sid');
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', $id);
  if ($ul == 0) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Update",{});
    &CMU::WebInt::title("Update Error");
    CMU::WebInt::accessDenied('subnet', 'WRITE', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  %fields = ('name' => CMU::WebInt::gParam($q, 'sname'),
	     'abbreviation' => CMU::WebInt::gParam($q, 'abbr'),
	     'base_address' => CMU::WebInt::gParam($q, 'base_address'),
	     'network_mask' => CMU::WebInt::gParam($q, 'network_mask'),
	     'dynamic' => CMU::WebInt::gParam($q, 'dynamic'),
	     'expire_static' => CMU::WebInt::gParam($q, 'expire_static'),
	     'expire_dynamic' => CMU::WebInt::gParam($q, 'expire_dynamic'),
	     'default_mode' => CMU::WebInt::gParam($q, 'default_mode'),
	     'share' => CMU::WebInt::gParam($q, 'share'),
	     'purge_interval' => CMU::WebInt::gParam($q, 'purge_interval'),
	     'purge_notupd' => CMU::WebInt::gParam($q, 'purge_notupd'),
	     'purge_notseen' => CMU::WebInt::gParam($q, 'purge_notseen'),
	     'purge_explen' => CMU::WebInt::gParam($q, 'purge_explen')
);
  
  $fields{'flags'} = join(',', CMU::WebInt::gParam($q, 'flags'));
  
  my ($res, $field) = CMU::Netdb::modify_subnet($dbh, $user, $id, $version, \%fields);
  if ($res >= 1) {
    $error{msg} = "Subnet information has been updated.";
  }else{
    $error{msg} = "Error updating subnet information: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'subnet_upd';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
    $error{$field} = 1;
  }
  $dbh->disconnect();
  CMU::WebInt::subnets_view($q, \%error);
}


#####################################################################
## Add/delete domain from a subnet
##

sub subnets_del_domain {
  my ($q) = @_;
  my ($dbh, $res, $version, $id, $url, %error, $field, $zid);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'v');
  $id = CMU::WebInt::gParam($q, 'id');  # id in subnet_domain table
  $zid = CMU::WebInt::gParam($q, 'zid'); # id in zone table
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  ($res, $field) = CMU::Netdb::delete_subnet_domain($dbh, $user, $id, $version);
  if ($res != 1) {
    $error{msg} = "Error deleting domain from subnet: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'subnet_del_domain';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
  }else{
    $error{msg} = "Domain deleted from the subnet.";
  }
  $dbh->disconnect();
  if ($zid ne '') {
    # we're coming from the zone view, go back there
    $q->param('id', $zid);      # copy zone id as "id" in URL
    CMU::WebInt::zone_view($q, \%error);
  } else {
    CMU::WebInt::subnets_view($q, \%error);
  }
}
    
sub subnets_add_domain {
  my ($q) = @_;
  my (%fields, $res, %error, $dbh, $ref, $zid);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $zid = CMU::WebInt::gParam($q, 'zid'); # id in zone table
  %fields = ('subnet' => CMU::WebInt::gParam($q, 'sid'),
		'domain' => uc(CMU::WebInt::gParam($q, 'newDomain')));
  ($res, $ref) = CMU::Netdb::add_subnet_domain($dbh, $user, \%fields);
  if ($res != 1) {
    $error{msg} = "Error adding domain to subnet: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{msg} .= "[".join(',', @$ref)."]";
    $error{type} = 'ERR';
    $error{loc} = 'subnet_add_domain';
    $error{code} = $res;
    $error{fields} = join(',', @$ref);
  }else{
    $error{msg} = "Domain $fields{domain} added to the subnet.";
  }
  $dbh->disconnect();
  if ($zid ne '') {
    # we're coming from the zone view, go back there
    $q->param('id', $zid);      # copy zone id as "id" in URL
    CMU::WebInt::zone_view($q, \%error);
  } else {
    CMU::WebInt::subnets_view($q, \%error);
  }
}

#####################################################################
## Add/delete domain from a subnet
##

sub subnets_del_reg_mode {
  my ($q) = @_;
  my ($dbh, $res, $version, $id, $url, %error, $field);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'version');
  $id = CMU::WebInt::gParam($q, 'id');
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('subnet', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  ($res, $field) = CMU::Netdb::delete_subnet_registration_mode($dbh, $user, $id, $version);
  if ($res != 1) {
    $error{msg} = "Error deleting registration mode from subnet: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'subnets_del_reg_mode';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
  }else{
    $error{msg} = "Registration mode deleted from the subnet.";
  }
  $dbh->disconnect();
  CMU::WebInt::subnets_view($q, \%error);
}
    

#####################################################################
## Add/delete building from a subnet
##

sub subnets_add_reg_mode {
  my ($q) = @_;
  my (%fields, $res, %error, $dbh, $ref);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  %fields = ('subnet' => CMU::WebInt::gParam($q, 'sid'),
	     'mode' => lc(CMU::WebInt::gParam($q, 'mode')),
	     'quota' => CMU::WebInt::gParam($q, 'quota'),
	     'mac_address' => lc(CMU::WebInt::gParam($q, 'mac_address')));

  $fields{quota} = undef if ($fields{quota} eq '');

  ($res, $ref) = CMU::Netdb::add_subnet_registration_mode($dbh, $user, \%fields);
  if ($res != 1) {
    $error{msg} = "Error adding registration mode to subnet: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{msg} .= "[".join(',', @$ref)."]";
    $error{type} = 'ERR';
    $error{loc} = 'subnet_add_reg_mode';
    $error{code} = $res;
    $error{fields} = join(',', @$ref);
  }else{
    $error{msg} = "Registration mode added to the subnet.";
  }
  $dbh->disconnect();
  CMU::WebInt::subnets_view($q, \%error);
}

sub subnets_del_presence {
  my ($q, $errors) = @_;
  my ($dbh, $res, $version, $id, %error, $url, $errfields);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'v');
  $id = CMU::WebInt::gParam($q, 'id');

  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'vlan_subnet_presence', $id);
  if ($ul < 9) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Admin", $errors);
    &CMU::WebInt::title("Delete Error");
    CMU::WebInt::accessDenied('vlan_subnet_presence', 'WRITE', $id, 9, $ul,
			      $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  ($res, $errfields) = CMU::Netdb::delete_subnet_presence($dbh, $user, $id, $version);
  if ($res != 1) {
    $error{msg} = "Error deleting vlan presence from subnet: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'subnet_del_presence';
    $error{code} = $res;
    $error{fields} = join(',', @$errfields);
  }else{
    $error{msg} = "vlan presence deleted from the subnet.";
  }
  $dbh->disconnect();
  if (CMU::WebInt::gParam($q, 'vid') ne '') {
    $q->param('vid', CMU::WebInt::gParam($q, 'vid'));
    CMU::WebInt::vlans_view($q, \%error);
  }else{
    CMU::WebInt::subnets_view($q, \%error);
  }
}
    
sub subnets_add_presence {
  my ($q, $errors) = @_;
  my (%fields, $res, %error, $dbh, $ref);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  %fields = ('subnet' => CMU::WebInt::gParam($q, 'sid'),
		'vlan' => CMU::WebInt::gParam($q, 'newVlan'));
  warn __FILE__, ':', __LINE__, ' :>'.
    "\n******* $fields{subnet} <-> $fields{vlan}\n" if ($debug >= 2);
  my $sul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', $fields{subnet});
  my $vul = CMU::Netdb::get_write_level($dbh, $user, 'vlan', $fields{vlan});
  if ($sul < 9 || $vul < 9) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Admin", $errors);
    &CMU::WebInt::title("Add Error");
    if($sul < 9){
    CMU::WebInt::accessDenied('vlan_subnet_presence', 'ADD', $fields{'subnet'},
			      9, $sul, $user);
    }
    else{
    CMU::WebInt::accessDenied('vlan_subnet_presence', 'ADD', $fields{'subnet'},
                              9, $vul, $user);
    }
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  ($res, $ref) = CMU::Netdb::add_subnet_presence($dbh, $user, \%fields);
  if ($res != 1) {
    $error{msg} = "Error adding vlan presence to subnet: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{msg} .= " [".join(',', @$ref)."] ";
    $error{type} = 'ERR';
    $error{loc} = 'subnet_add_presence';
    $error{code} = $res;
    $error{fields} = join(',', @$ref);
  }else{
    $error{msg} = "VLAN $fields{vlan} added to the subnet.";
  }
  $dbh->disconnect();
  if (CMU::WebInt::gParam($q, 'back') eq 'vlan') {
    CMU::WebInt::vlans_view($q, \%error);
  }else{
    CMU::WebInt::subnets_view($q, \%error);
  }
}

sub subnets_share_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('sub_listShare');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Admin", $errors);
  &CMU::WebInt::title("List of Subnet Shares");

  $url = $ENV{SCRIPT_NAME};
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=addShare\">Add Shared Network</a></b>]\n".CMU::WebInt::pageHelpLink(''));
  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'subnet_share.abbreviation' if ($sort eq '');
  
  $res = subnets_print_shares($user, $dbh, $q, 
			      " 1 ".
			      CMU::Netdb::verify_orderby($sort),
			      $ENV{SCRIPT_NAME}, "op=listShare&sort=$sort", 'start');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub subnets_view_share {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res, $msg);
  
  $id = CMU::WebInt::gParam($q, 'id');
  $msg = $errors->{'msg'};
  $msg = "Subnet Share not specified!" if ($id eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('viewshare');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Shared Network Admin", $errors);
  &CMU::WebInt::title("Shared Subnet Information");

  $url = $ENV{SCRIPT_NAME};
  
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  my $sref = CMU::Netdb::list_subnet_shares($dbh, $user, " subnet_share.id='$id' ");
  my @sdata = @{$sref->[1]};
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  my $version = $sdata[$subnet_sh_pos{'subnet_share.version'}];
  print CMU::WebInt::subHeading("Information for: ".$sdata[$subnet_sh_pos{'subnet_share.name'}], CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=$url?op=viewshare&id=$id>Refresh</a></b>]
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=deleteShare&id=$id&version=$version")."\">Delete Share</a></b>]\n");

  # name, abbreviation
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=updateShare>
<input type=hidden name=version value=\"".$sdata[$subnet_sh_pos{'subnet_share.version'}]."\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $CMU::Netdb::structure::subnet_share_printable{'subnet_share.name'}, 1, 'subnet_share.name').
  CMU::WebInt::printPossError(defined $errors->{'abbreviation'}, $CMU::Netdb::structure::subnet_share_printable{'subnet_share.abbreviation'}, 1, 'subnet_share.abbreviation').
    "</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('subnet_share.name', $verbose).
  $q->textfield(-name => 'name', -value => $sdata[$subnet_sh_pos{'subnet_share.name'}], -size => length($sdata[$subnet_sh_pos{'subnet_share.name'}])+5).
    "</td><td>".CMU::WebInt::printVerbose('subnet_share.abbreviation', $verbose).
      $q->textfield(-name => 'abbreviation', 
		    -value => $sdata[$subnet_sh_pos{'subnet_share.abbreviation'}])."</td></tr>\n";

  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n";
  
  print "</table></form>\n";

  ## subnets that use this share
  print CMU::WebInt::subHeading("Subnets on this Shared Network", CMU::WebInt::pageHelpLink('subnet'));
  my $ssref = CMU::Netdb::list_subnets($dbh, $user, "subnet.share='$id'");
  
  if (!ref $ssref) {
    print "ERROR with list_subnets: ".$errmeanings{$ssref};
    print "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($ssref eq $CMU::Netdb::errcodes{EDB});
    return 0;
  }

  CMU::WebInt::generic_tprint($url, $ssref, 
		 ['subnet.name'],
		 [\&CMU::WebInt::subnets::subnets_cb_base_address,
		  \&CMU::WebInt::subnets::subnets_cb_network_mask],
#		  \&CMU::WebInt::subnets::subnets_cb_delete_share], '',
		  '', '', 'op=sub_info&sid=', \%subnet_pos,
		  \%CMU::Netdb::structure::subnet_printable, 'subnet.name', 
		 'subnet.id', '', []);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# subnets_print_shares
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the subnet WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub subnets_print_shares {
  my ($user, $dbh, $q, $where, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'subnet_share', $where);
  
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
  $ruRef = CMU::Netdb::list_subnet_shares($dbh, $user, " $where ".
					  CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_subnet_shares: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
			      ['subnet_share.name', 'subnet_share.abbreviation'],
			      [], '', 'listShare', 'op=viewshare&id=',
			      \%subnet_sh_pos, 
			      \%CMU::Netdb::structure::subnet_share_printable,
			      'subnet_share.name', 'subnet_share.id', 'sort',
			      ['subnet_share.name', 'subnet_share.abbreviation']);
  
  return 1;
}

sub subnets_add_share_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'subnet_share', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('addShare');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Shared Subnets", $errors);
  &CMU::WebInt::title("Add a Shared Subnet");
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('subnet_share', 'ADD', 0, 1, $userlevel, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  # name, abbreviation
  print "
<form method=get>
<input type=hidden name=op value=addShareReal>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $CMU::Netdb::structure::subnet_share_printable{'subnet_share.name'}, 1, 'subnet_share.name').
  CMU::WebInt::printPossError(defined $errors{abbreviation}, $CMU::Netdb::structure::subnet_share_printable{'subnet_share.abbreviation'}, 1, 'subnet_share.abbreviation')."</tr>
<tr><td>".CMU::WebInt::printVerbose('subnet_share.name', $verbose).
  $q->textfield(-name => 'name')."</td><td>".
    CMU::WebInt::printVerbose('subnet_share.abbreviation', $verbose).
      $q->textfield(-name => 'abbreviation')."</td></tr>\n";
  
  print "</table>\n";
  print "<input type=submit value=\"Add Shared Subnet\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub subnets_add_share {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'abbreviation' => CMU::WebInt::gParam($q, 'abbreviation'));

  my ($res, $errfields) = CMU::Netdb::add_subnet_share($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added shared network $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    CMU::WebInt::subnets_view_share($q, \%nerrors);
  }else{
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'subnets_add_share';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    CMU::WebInt::subnets_add_share_form($q, \%nerrors);
  }
}

sub subnets_del_share {
  my ($q) = @_;
  my ($url, $msg, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('deleteShare');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Shared Subnets", {});
  &CMU::WebInt::title('Delete Shared Network');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet_share', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('subnet_share', 'WRITE', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my $sref = CMU::Netdb::list_subnet_shares($dbh, $user, "subnet_share.id='$id'");
  if (!defined $sref->[1]) {
    print "Shared Network not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following shared network.\n";
  
  my @print_fields = ('subnet_share.name', 'subnet_share.abbreviation');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::subnet_share_printable{$f}."</th>
<td>";
    print $sdata[$subnet_sh_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=confShareDelete&id=$id&version=$version")."\">
Yes, delete this shared network";
  print "<br><a href=\"$url?op=listShare\">No, return to the shared network list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub subnets_del_share_confirm {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet_share', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete subnet_share $id\n";
    $dbh->disconnect();
    CMU::WebInt::subnets_view_share($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_subnet_share($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    $errors{msg} = "The subnet share was deleted.";
    CMU::WebInt::subnets_share_list($q, \%errors);
  }else{
    $errors{msg} = "Error while deleting shared network: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{type} = 'ERR';
    $errors{loc} = 'subnets_del_share_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    CMU::WebInt::subnets_view_share($q, \%errors);
  }

}

sub subnets_share_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'subnet_share', $id);

  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Shared Subnets", $errors);
    &CMU::WebInt::title("Update Shared Network");
    CMU::WebInt::accessDenied('subnet_share', 'WRITE', $id, 1, $userlevel,
			      $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'abbreviation' => CMU::WebInt::gParam($q, 'abbreviation'));

  my ($res, $errfields) = CMU::Netdb::modify_subnet_share($dbh, $user, $id, $version, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Updated shared subnet.";
    $dbh->disconnect(); 
    &CMU::WebInt::subnets_view_share($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{type} = 'ERR';
    $nerrors{loc} = 'subnets_share_upd';
    $nerrors{code} = $res;
    $nerrors{fields} = join(',', @$errfields);
    $dbh->disconnect();
    &CMU::WebInt::subnets_view_share($q, \%nerrors);
  }
}

sub subnets_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'subnet', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('sub_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Admin", $errors);
  &CMU::WebInt::title("Add a Subnet");

  print CMU::WebInt::errorDialog($url, $errors);

  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('subnet', 'ADD', 0, 1, $userlevel, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  # name, abbreviation
  print "
<form method=get>
<input type=hidden name=op value=sub_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $subnet_p{'subnet.name'}, 1, 'subnet.name').
  CMU::WebInt::printPossError(defined $errors{abbreviation}, $subnet_p{'subnet.abbreviation'}, 1, 'subnet.abbreviation')."</tr>
<tr><td>".CMU::WebInt::printVerbose('subnet.name', $verbose).
  $q->textfield(-name => 'name', -accesskey => 's')."</td><td>".CMU::WebInt::printVerbose('subnet.abbreviation', $verbose).
  $q->textfield(-name => 'abbreviation',  -accesskey => 'a')."</td></tr>\n";

  # base_address, network_mask
  print "
<tr>".CMU::WebInt::printPossError(defined $errors{base_address}, $subnet_p{'subnet.base_address'}, 1, 'subnet.base_address').
  CMU::WebInt::printPossError(defined $errors{network_mask}, 
		 $subnet_p{'subnet.network_mask'}, 1, 'subnet.network_mask').
		   "</tr><tr><td>".CMU::WebInt::printVerbose('subnet.base_address', $verbose).
		     $q->textfield(-name => 'base_address', -accesskey => 'b').
		     "</td><td>".CMU::WebInt::printVerbose('subnet.network_mask', $verbose).
		       $q->textfield(-name => 'network_mask', -accesskey => 'n')."</td></tr>\n";

  # dynamic, share
  my $sshares = CMU::Netdb::list_subnet_shares_ref($dbh, $user, '');
  my @sharekey;
  if (!ref $sshares) {
    print "ERROR: ".$errmeanings{$sshares};
    @sharekey = ();
    $sshares = {};
  }else{
    @sharekey = sort { $sshares->{$a} cmp $sshares->{$b} } keys %$sshares; 
    $$sshares{0} = 'None';
    unshift @sharekey, (0);
  }

  print "
<tr>".CMU::WebInt::printPossError(defined $errors{dynamic}, $CMU::Netdb::structure::subnet_printable{'subnet.dynamic'}, 1, 'subnet.dynamic').
  CMU::WebInt::printPossError(defined $errors{share}, $CMU::Netdb::structure::subnet_printable{'subnet.share'}, 1, 'subnet.share')."</tr>
<tr><td>".CMU::WebInt::printVerbose('subnet.dynamic', $verbose).
  $q->popup_menu(-name => 'dynamic', -accesskey => 'd',
			 -values => \@CMU::Netdb::structure::subnet_dynamic).
			   "</td><td>".
			     CMU::WebInt::printVerbose('subnet.share', $verbose).
  $q->popup_menu(-name => 'share', -accesskey => 's',
		 -values => \@sharekey,
		-labels => $sshares)."</td></tr>\n";

  # expire_static, expire_dynamic
  print "
<tr>".CMU::WebInt::printPossError(defined $errors{expire_static}, $CMU::Netdb::structure::subnet_printable{'subnet.expire_static'}, 1, 'subnet.expire_static').
  CMU::WebInt::printPossError(defined $errors{expire_dynamic}, $CMU::Netdb::structure::subnet_printable{'subnet.expire_dynamic'}, 1, 'subnet.expire_dynamic')."</tr>
<tr><td>".CMU::WebInt::printVerbose('subnet.expire_static', $verbose).
  $q->textfield(-name => 'expire_static', -accesskey => 'e')."</td><td>".
    CMU::WebInt::printVerbose('subnet.expire_dynamic', $verbose).
  $q->textfield(-name => 'expire_dynamic', -accesskey => 'e')."</td></tr>\n";


  # flags, default_mode
   print "<tr>".CMU::WebInt::printPossError(defined $errors->{'flags'}, $subnet_p{'subnet.flags'}, 1, 'subnet.flags') . CMU::WebInt::printPossError(defined $errors->{'default_mode'}, $subnet_p{'subnet.default_mode'}, 1, 'subnet.default_mode');
  print "</tr><tr><td>".CMU::WebInt::printVerbose('subnet.flags', $verbose).
    $q->checkbox_group(-name => 'flags',
		       -values => \@CMU::Netdb::structure::subnet_flags,
		       -linebreak => 'true').
			 "</td>\n";
  my @sdefaultmodes = @CMU::Netdb::structure::subnet_default_mode;
  print "<td>".CMU::WebInt::printVerbose('subnet.default_mode', $verbose).
    $q->popup_menu(-name=> 'default_mode', -accesskey => 'd',
		   -default=>'static',
		   -values=>\@sdefaultmodes).
		     "</td></tr>\n";

  # purge_interval, purge_explen
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'purge_interval'}, $subnet_p{'subnet.purge_interval'}, 1, 'subnet.purge_interval').
CMU::WebInt::printPossError(defined $errors->{'purge_explen'}, $subnet_p{'subnet.purge_explen'}, 1, 'subnet.purge_explen')."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('subnet.purge_interval', $verbose).
  $q->textfield(-name=> 'purge_interval', -accesskey => 'p')." days";
  print "</td><td>".CMU::WebInt::printVerbose('subnet.purge_explen', $verbose).
  $q->textfield(-name=> 'purge_explen', -accesskey => 'p')." days</td></tr>\n";

  # purge_notseen, purge_notupd
  print "
<tr>".
CMU::WebInt::printPossError(defined $errors->{'purge_notseen'}, $subnet_p{'subnet.purge_notseen'}, 1, 'subnet.purge_notseen').
CMU::WebInt::printPossError(defined $errors->{'purge_notupd'}, $subnet_p{'subnet.purge_notupd'}, 1, 'subnet.purge_notupd')."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('subnet.purge_notseen', $verbose).
  $q->textfield(-name=> 'purge_notseen', -accesskey => 'p')." days";
  print "</td><td>".CMU::WebInt::printVerbose('subnet.purge_notupd', $verbose).
  $q->textfield(-name=> 'purge_notupd', -accesskey => 'p')." days</td></tr>\n";


  print "</table>\n";
  print "<input type=submit value=\"Add Subnet\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub subnets_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'subnet', 0);
  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Subnets", $errors);
    &CMU::WebInt::title("Add Subnet");
    CMU::WebInt::accessDenied('subnet', 'ADD', 0, 1, $userlevel, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  
  foreach (qw/name abbreviation base_address network_mask dynamic
	   expire_static expire_dynamic share
	   default_mode purge_interval purge_notupd purge_notseen purge_explen/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  $fields{'flags'} = join(',', CMU::WebInt::gParam($q, 'flags'));

  my ($res, $errfields) = CMU::Netdb::add_subnet($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added subnet.";
    $q->param('sid', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    &CMU::WebInt::subnets_view($q, \%nerrors);
  }else{
    if ($res <= 0) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." )" 
	if ($res == $CMU::Netdb::errcodes{EDB});
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'subnets_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    &CMU::WebInt::subnets_add_form($q, \%nerrors);
  }
}

sub subnets_show_policy {
  my ($q, $errors) = @_;
  my ($dbh, $query, $sth, $res, @row, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('subnet_policies');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Policies", $errors);
  
  my $verbose = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'bmvm'));
  $verbose = 1 if ($verbose ne '0');

  my $sref = CMU::Netdb::get_subnets($dbh, $user,"");

  if (ref $sref) {
    for(my $i=1;$i<=$#$sref; $i++){
      my ($smachine, $dmachine);
      my @sdata = @{$sref->[$i]};
      my $smsg  = $sdata[$subnet_pos{'subnet.name'}];
      my $dtime = int($sdata[$subnet_pos{'subnet.expire_dynamic'}]/3600);
      my $stime = int($sdata[$subnet_pos{'subnet.expire_static'}]/3600);

      my $quotas = CMU::Netdb::get_machine_modes($dbh, $user, $sdata[$subnet_pos{'subnet.id'}], 1);
      if (!ref $quotas) {
	warn __FILE__, ' : ', __LINE__, " :> Error retrieving modes for $sdata[$subnet_pos{'subnet.id'}]: $quotas\n";
	next;
      }

      if (!exists($quotas->{static}{required}) &&
	  !exists($quotas->{static}{none}) &&
	  !exists($quotas->{dynamic}{required}) &&
	  !exists($quotas->{dynamic}{none})) {
	next;
      } else {
	print "<table border=0 width=100%><tr><td><center>".
	  CMU::WebInt::subHeading($smsg, '')."</center></td></tr></table>";

	print "<font face=\"Arial,Helvetica,Geneva,Charter\"><ul>\n";

	if (!exists($quotas->{static}{required}) &&
	    !exists($quotas->{static}{none})) {
	  print "<li>You cannot create any static machine registrations on this network.\n";
	} else {
	  print "<li>";
	  if (!exists $quotas->{static}{required}) {
	    print "You cannot create any normal static machine registrations.\n";
	  } elsif (!defined $quotas->{static}{required}) {
	    print "There are no restrictions on normal static machine registrations.\n";
	  } else {
	    my $pl = 's';
	    $pl = '' if ($quotas->{static}{required} eq '1');
	    print "You can have <b>$quotas->{static}{required}</b> normal static machine registration$pl.";
	  }

	  print "<li>";
	  if (!exists $quotas->{static}{none}) {
	    print "You cannot create any static machine registrations without hardware addresses.\n";
	  } elsif (!defined $quotas->{static}{none}) {
	    print "There are no restrictions on static machine registrations without hardware addresses.\n";
	  } else {
	    my $pl = 's without hardware addresses';
	    $pl = 'without a hardware address' if ($quotas->{static}{none} eq '1');
	    print "You can have <b>$quotas->{static}{none}</b> static machine registration$pl.";
	  }
	}

	if (!exists($quotas->{dynamic}{required}) &&
	    !exists($quotas->{dynamic}{none})) {
	  print "<li>You cannot create any dynamic registrations on this network.\n";
	} else {
	  print "<li>";
	  if (!exists $quotas->{dynamic}{required}) {
	    print "You cannot create any normal dynamic machine registrations.\n";
	  } elsif (!defined $quotas->{dynamic}{required}) {
	    print "There are no restrictions on normal dynamic machine registrations.\n";
	  } else {
	    my $pl = 's';
	    $pl = '' if ($quotas->{dynamic}{required} eq '1');
	    print "You can have <b>$quotas->{dynamic}{required}</b> normal dynamic machine registration$pl.";
	  }

	  print "<li>";
	  if (!exists $quotas->{dynamic}{none}) {
	    print "You cannot create any dynamic machine registrations without hardware addresses.\n";
	  } elsif (!defined $quotas->{dynamic}{none}) {
	    print "There are no restrictions on static machine registrations without hardware addresses.\n";
	  } else {
	    my $pl = 's without hardware addresses';
	    $pl = 'without a hardware address' if ($quotas->{dynamic}{none} eq '1');
	    print "You can have <b>$quotas->{dynamic}{none}</b> static machine registration$pl.";
	  }
	}
      }
      my $HourText;
      if ($dtime == 1) {
	$HourText = 'hour.';
      } else {
	$HourText = 'hours.';
      }
      print "<li>The DHCP lease time for dynamic registrations is approximately  <b>$dtime</b> $HourText\n";
      
      print "</ul><br><br>\n";
    }
  }
  print CMU::WebInt::stdftr($q);
}

sub subnets_addips_exec {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, %errors) = @_;

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $sid = CMU::WebInt::gParam($q, 'sid');
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', $sid);

  if ($ul < 9) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet AddIPs", $errors);
    &CMU::WebInt::title("AddIPs Error");
    CMU::WebInt::accessDenied('subnet', 'WRITE', $sid, 9, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my ($nIP, $mode, $amethod, $hn, $dept, $nuser) =
    (CMU::WebInt::gParam($q, 'nIPs'),
     CMU::WebInt::gParam($q, 'mode'),
     CMU::WebInt::gParam($q, 'alloc_method'),
     CMU::WebInt::gParam($q, 'hostname_format'),
     CMU::WebInt::gParam($q, 'dept'),
     CMU::WebInt::gParam($q, 'user')
    );
  
  my %nerrors;

  my ($res, $err) = CMU::Netdb::register_ips($dbh, $user, 
					     $sid, $nIP, $mode, $amethod, $hn,
					     $dept, $nuser);
  warn __FILE__, ':', __LINE__, ' :>'.
    "REGISTER_IP returns $res\n" if ($debug >= 2);
  if ($res != 1) {
    $nerrors{type} = 'ERR';
    $nerrors{msg} = "Error [$res] (".join(',', @$err).")";
    $nerrors{code} = $res;
    $nerrors{fields} = join(',', @$err);
    $dbh->disconnect();
    return subnets_addips($q, \%nerrors);
  }
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Bulk IP Register", $errors);
  &CMU::WebInt::title("Bulk IP Register");
  print "<br><ul><li>".join("\n<li>", @$err)."</ul>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub subnets_addips {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, %errors) = @_;
  
  my $sid = CMU::WebInt::gParam($q, 'sid');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'subnet', $sid);

  print &CMU::WebInt::stdhdr($q, $dbh, $user, "Subnets", $errors);

  print CMU::WebInt::errorDialog($url, $errors);

  &CMU::WebInt::title("Bulk IP Register");
  
  if ($ul < 9) {
    CMU::WebInt::accessDenied('subnet', 'WRITE', $sid, 9, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  
  my $subnet = CMU::Netdb::list_subnets_ref($dbh, $user,
					    "subnet.id = $sid",
					    'subnet.name');
  if (!ref $subnet || !defined $subnet->{$sid}) {
    print "<br>Subnet ID $sid not defined.\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  
  my $SubnetName = $subnet->{$sid};
  my $verbose = 1;
  
  print CMU::WebInt::subHeading("Adding IPs to Subnet: $SubnetName",
				CMU::WebInt::pageHelpLink(''));

  print "<table border=0><form method=get>
<input type=hidden name=sid value=$sid>
<input type=hidden name=op value=subnets_addips_exec>";

  ## Hostname Format; Number of IPs
  print "<tr>".
    CMU::WebInt::printPossError
      (defined $errors->{'hostname_format'}, 
       "Hostname Format", 1, 
       'subnet.hostname_format').
	 CMU::WebInt::printPossError
	   (defined $errors->{'nIPs'},
	    "Number of IPs", 1, 'subnet.number_ips');
  
  print "</tr><tr><td>".CMU::WebInt::printVerbose('subnet.hostname_format', 
						  $verbose);
  print $q->textfield(-name => 'hostname_format', -accesskey => 'h',
		      -size => 30);
  print "</td><td>".CMU::WebInt::printVerbose('subnet.number_ips',
					      $verbose);
  print $q->textfield(-name => 'nIPs', -accesskey => 'n',
		      -size => 10);
  print "</td></tr>\n";

  # Mode (pool/reserved); Allocation Method
  print "<tr>".
    CMU::WebInt::printPossError
      (defined $errors->{'mode'}, 'Machine Mode', 1, 'subnet.mode').
	CMU::WebInt::printPossError
	  (defined $errors->{'alloc_method'}, 'Allocation Method',
	   1, 'subnet.allocation_method');
  
  print "</tr><tr><td>".CMU::WebInt::printVerbose('subnet.mode',
						  $verbose);

  my @modes = grep (/pool|reserved/, 
		    @{CMU::Netdb::get_machine_modes($dbh, $user, $sid)});

  if (@modes) {
    print $q->popup_menu(-name => 'mode', -accesskey => 'm',
			 -values => \@modes);
  }else{
    print "-error-";
  }
  print "</td><td>".CMU::WebInt::printVerbose('subnet.alloc_method',
					      $verbose);
  my @Methods = keys %AllocationMethods;
  print $q->popup_menu(-name => 'alloc_method', -accesskey => 'a',
		       -values => \@Methods);

  print "</td></tr>\n";
  
  print "<tr>".
    CMU::WebInt::printPossError
      (defined $errors->{'dept'}, 'Department', 1, 'groups.name').
	CMU::WebInt::printPossError(defined $errors->{'user'}, 'User',
				    1, 'credentials.authid');
  print "<tr><tr><td>".CMU::WebInt::printVerbose('register_ips.dept', $verbose);
  my $depts = CMU::Netdb::get_departments($dbh, $user, '', 'ALL', $user, 'groups.description', 'GET');
  if (!ref $depts) {
    print "[error]\n";
  }
  my @order = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;
  
  print $q->popup_menu(-name => 'dept',
		       -values => \@order,
		       -default => 'dept:undergraduate',
		       -labels => $depts);
  
  print "</td><td>".CMU::WebInt::printVerbose('register_ips.user', $verbose);

  print $q->textfield(-name => 'user', -accesskey => 'u',
		      -size => 10);

  print "</td></tr>\n";
  
  print "<tr><td colspan=2><input type=submit value=\"Add IPs\">".
    "</td></tr></table>\n";
  
  $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);
}

1;
