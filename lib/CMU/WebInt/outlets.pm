#   -*- perl -*-
#
# CMU::WebInt::outlets
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
# $Id: outlets.pm,v 1.93 2008/05/15 17:59:45 vitroth Exp $
#

package CMU::WebInt::outlets;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings 
	     %outlet_output_order_by %outlet_pos %outlet_printable
	     %outlet_cable_pos %outlet_cable_printable %cable_pos
	     @outlet_attributes @outlet_flags @outlet_status %outlet_cable_host_pos
	     %outlet_cable_host_printable %outlet_search_order $debug $DEF_ITEMS_PER_PAGE);
use CMU::WebInt;
use CMU::WebInt::helper;
use CMU::WebInt::interface;
use CMU::WebInt::vars;
use CMU::Netdb::helper;
use CMU::Netdb::auth;
use CMU::Netdb::primitives;
use CMU::Netdb::buildings_cables;
use CMU::Netdb::structure;
use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(outlets_info outlets_update outlets_reg_s2
	     outlets_cb_outlet_type outlets_cb_building
	     outlets_delete outlets_confirm_delete
	     %outlet_pos $debug);


%errmeanings = %CMU::Netdb::errors::errmeanings;

%cable_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::cable_fields)};
%outlet_printable = %CMU::Netdb::structure::outlet_printable;
%outlet_cable_printable = %CMU::Netdb::structure::outlet_cable_printable;
%outlet_cable_host_printable = %CMU::Netdb::structure::outlet_cable_host_printable;
%outlet_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::outlet_fields)};
%outlet_cable_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::outlet_cable_fields)};
%outlet_cable_host_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::outlet_cable_host_fields)};
@outlet_attributes = @CMU::Netdb::structure::outlet_attributes;
@outlet_flags = @CMU::Netdb::structure::outlet_flags;
@outlet_status = @CMU::Netdb::structure::outlet_status;

$debug = 0;

my ($gmcvres);
($gmcvres, $DEF_ITEMS_PER_PAGE) = CMU::Netdb::config::get_multi_conf_var
  ('webint', 'DEF_ITEMS_PER_PAGE');

# outlets_print_outlet
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

sub outlets_print_outlet {
  my ($user, $dbh, $q, $t, $td, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $vres);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

#  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'outlet', $cwhere);
#  return $ctRow if (!ref $ctRow);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'MACHINES_PER_PAGE');

  $where = "1" if ($where eq '');
  if ($t eq '0') {
    $ruRef = CMU::Netdb::list_outlets_cables($dbh, $user, " $where ".
					     CMU::Netdb::verify_limit($start, $defitems));
  }else{
    $ruRef = CMU::Netdb::list_outlets_cables_munged_protections($dbh, $user, $t, $td, " $where ".
								CMU::Netdb::verify_limit($start, $defitems));
  }
  if (!ref $ruRef) {
    print "ERROR with list_outlets: ".$errmeanings{$ruRef};
    return 0;
  }
  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, '');
  my $otref = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'LIST', '');
  
  print "Select a column heading to sort by the column field<br>\n";
  $lmach .= "&$oData" if ($oData ne '');
  $ctRow = ($#{$ruRef} < $defitems ? 0 : $start+$defitems+1);
  print &CMU::WebInt::pager_Top($start, $ctRow, $defitems, 0,
		   $url, $oData, $skey);

  $lmach =~ s/\&osort=[^\&]+//;
  $lmach =~ s/\&\&/\&/g;
  $lmach =~ s/\&$//;
  
  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.

  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, ['cable.label_from',
					     'cable.label_to'],
		 [\&CMU::WebInt::outlets::outlets_cb_outlet_type,
		  \&CMU::WebInt::outlets::outlets_cb_to_building,
		  \&CMU::WebInt::outlets::outlets_cb_to_floor,
		  \&CMU::WebInt::outlets::outlets_cb_room_number,
		  \&CMU::WebInt::outlets::outlets_cb_vlan],
		 [$otref, $bref, $dbh], $lmach, 'op=outlets_info&oid=', 
		 \%outlet_cable_pos, \%outlet_cable_printable,
		 'cable.label_from', 'outlet.id', 'osort',
			     ['cable.label_from', 'cable.label_to', 'outlet.type',
			     'building.name', 'cable.to_floor', 'cable.to_room_number']);
  
  return 1;
}

sub outlets_cb_outlet_type {
  my ($url, $dref, $udata) = @_;

  my $otref = $$udata[0];
  return $CMU::Netdb::structure::outlet_printable{'outlet.type'} if (!ref $dref);
  return 'suck' if (!ref $otref);
  my @rrow = @{$dref};

  my $b = $rrow[$outlet_pos{'outlet.type'}];
  return $$otref{$b} if ($$otref{$b} ne '');
  return 'Unknown'; # or $b???
}

sub outlets_cb_to_building {
  my ($url, $dref, $udata) = @_;
  my $bref = $$udata[1];
  return $CMU::Netdb::structure::outlet_cable_printable{'cable.to_building'} if (!ref $dref);
  my @rrow = @{$dref};

  my $b = $rrow[$outlet_cable_pos{'cable.to_building'}];
  return $$bref{$b} if ($$bref{$b} ne '');
  return $b if ($b ne '');
  return 'Unknown';
}

sub outlets_cb_to_floor {
  my ($url, $dref, $udata) = @_;
  my $bref = $$udata[1];
  return $CMU::Netdb::structure::outlet_cable_printable{'cable.to_floor'} if (!ref $dref);
  my @rrow = @{$dref};

  my $b = $rrow[$outlet_cable_pos{'cable.to_floor'}];
  return $b if ($b ne '');
  return '[Unknown]';
}

sub outlets_cb_room_number {
  my ($url, $dref, $udata) = @_;
  my $bref = $$udata[1];
  return $CMU::Netdb::structure::outlet_cable_printable{'cable.to_room_number'} if (!ref $dref);
  my @rrow = @{$dref};

  my $b = $rrow[$outlet_cable_pos{'cable.to_room_number'}];
  return $b if ($b ne '');
  return '[Unknown]';
}


sub outlets_cb_vlan {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return "Network Segment";
  }
  my $osm = CMU::Netdb::list_outlet_vlan_memberships($$udata[2], 'netreg', 
						      'outlet_vlan_membership.outlet = '.$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}]);
  my $map = CMU::Netdb::makemap($osm->[0]);
  shift @$osm;
  my @vlans = map { $_->[$map->{'vlan.abbreviation'}] } @$osm;
  return join(', ', @vlans) if (@vlans);
  return "Unspecified";
}


sub outlets_info {
  my ($q, $errors) = @_;
  my ($dbh, $id, $msg, $url, $pref, $adv_default);

  $id = CMU::WebInt::gParam($q, 'oid');
  $msg = $errors->{'msg'};
  $msg = "Outlet ID not specified!" if ($id eq '');
  my $deptAll = CMU::WebInt::gParam($q, 'deptAll');
  $deptAll = 0 if ($deptAll eq '');
  my $adv = CMU::WebInt::gParam($q, 'adv');
  $adv = 0 if ($adv eq '');

  my $vlanAll = CMU::WebInt::gParam($q, 'vlanAll');
  $vlanAll = 0 if ($vlanAll eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('outlets_info');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets", $errors);
  &CMU::WebInt::title("Outlet Information");

  $url = $ENV{SCRIPT_NAME};

  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'outlet', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('outlet', 'READ', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'outlet', $id);

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # basic outlet information
  my $oref = CMU::Netdb::list_outlets($dbh, $user, "outlet.id='$id'");
  if (!ref $oref || !defined $oref->[1]) {
    print "Outlet not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @odata = @{$oref->[1]};
  my $version = $odata[$outlet_pos{'outlet.version'}];

  # basic attached cable information
  my $cref = CMU::Netdb::list_cables($dbh, $user, "cable.id='$odata[$outlet_pos{'outlet.cable'}]'");
  my @cdata = @{$cref->[1]};

  # outlet type information
  my $otref = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'LIST', "");
  my %otdata = %$otref;

  # FIXME should we handle this?
  $otdata{'0'} = "Unknown";
  my @otvals = keys %otdata;

  # building information
  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, "");
  my %bdata = %$bref;

  # 


  print CMU::WebInt::subHeading("Information for: Outlet " . 
		   $cdata[$cable_pos{'cable.label_from'}] . "/" . 
		   $cdata[$cable_pos{'cable.label_to'}], CMU::WebInt::pageHelpLink(''));
  {
    my $srText = "[<b><a href=$url?op=outlets_info&oid=$id&deptAll=$deptAll>Refresh</a></b>]
 [<b><a href=$url?op=prot_s3&table=outlet&tidType=1&tid=$id>View/Update Protections</a></b>]
 [<b><a href=$url?op=outlets_info&oid=$id&deptAll=1&adv=1>View Advanced Options</a></b>]";
#    $srText .= "[<b><a href=$url?op=outlets_delete&id=$id&version=$version>Delete Outlet</a></b>]" if ($ul >= 9);

    $srText .= "<br />[<a href=$url?op=history&tname=outlet&row=$id><b>Show History</b></a>]"
	if (CMU::Netdb::get_user_admin_status($dbh, $user) == 1);

    print CMU::WebInt::smallRight($srText);
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  print "</font><br>\n";

  print "<table border=0><form method=get>
<input type=hidden name=oid value=$id>
<input type=hidden name=op value=outlets_update>
<input type=hidden name=version value=\"$version\">";

  # outlet type, device/port if not l9, status if l9
  print "<tr>".CMU::WebInt::printPossError(defined $$errors{'otype'}, 
			      $outlet_printable{'outlet.type'}, 
			      1, 'outlet.type');
  print CMU::WebInt::printPossError(defined $$errors{device}, $outlet_printable{'outlet.device'}."/".
		       $outlet_printable{'outlet.port'}, 
			1, 'outlet.device') if ($ul < 9);
  print CMU::WebInt::printPossError(defined $$errors{port}, $outlet_printable{'outlet.status'}, 
		       1, 'outlet.status') if ($ul >= 9);
  print "</tr><tr><td>".CMU::WebInt::printVerbose('outlet.type', $verbose);
  if ($ul >= 9) {
    if (!grep(/^$odata[$outlet_pos{'outlet.type'}]$/, @otvals)) {
      print "$odata[$outlet_pos{'outlet.type'}]";
    }else{
      print $q->popup_menu(-name => 'otype', -accesskey=>'t',
			   -default => $odata[$outlet_pos{'outlet.type'}],
			   -values => \@otvals,
			   -labels => \%otdata)."</td><td>".
			     CMU::WebInt::printVerbose('outlet.status', $verbose).
    $q->radio_group(-name=>'status',
                                                 -values=>['enabled','partitioned'],
                                                 -default=>$odata[$outlet_pos{'outlet.status'}],
                                                 -linebreak=>'true');
	}
  } else {
    # Get device id from trunkset_machine_presence
    my $ts_mach = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'machine', 
			"trunkset_machine_presence.id = '$odata[$outlet_pos{'outlet.device'}]'");
    my $ts_mach_map = CMU::Netdb::makemap($ts_mach->[0]);
    my $dp;
    if ($#$ts_mach > 0) {
	my $mach_rows = CMU::Netdb::list_machines($dbh, 'netreg', 
			    "machine.id = '$ts_mach->[1]->[$ts_mach_map->{'trunkset_machine_presence.device'}]'");
	my %mach_map = %{CMU::Netdb::makemap($mach_rows->[0])};
	my ($d, $p) = ($mach_rows->[1]->[$mach_map{'machine.host_name'}], $odata[$outlet_pos{'outlet.port'}]);
	$dp = "$d:$p";
	$dp = '[unconnected]' if (!defined $d || $d eq '');
    } else {
	$dp = '[unconnected]';
    }
    print "<table border=1><tr><td>".
      $otdata{$odata[$outlet_pos{'outlet.type'}]}."</td></tr></table></td><td>".
      CMU::WebInt::printVerbose('outlet.deviceport', $verbose)."<table border=1><tr><td>".
	"$dp</td></tr></table>";
  }
  print "</td></tr>";
 
  # This should be done to get building.id instead of building.building...:
  # Is this the correct hack ? FIXME:
  my $bldgnum = ($cdata[$cable_pos{'cable.to_building'}] ne '' ? $cdata[$cable_pos{'cable.to_building'}]:$cdata[$cable_pos{'cable.from_building'}]);
  my $dref = CMU::Netdb::list_buildings($dbh, $user, "building.building='$bldgnum'");
  my @ddata = @{$dref->[1]};
  my $bldg_id = $ddata[$CMU::WebInt::buildings::building_pos{'building.id'}];

  my $sref = CMU::Netdb::list_trunkset_building_presence($dbh, $user, 
							"trunkset_building_presence.buildings = '$bldg_id'");
  my (%trunkset, @ts, $nks);
  if (ref $sref) {
    %trunkset = %$sref;
    @ts = sort { $trunkset{$a} cmp $trunkset{$b} } keys %trunkset;
    $nks = keys %trunkset;
  }
 
  # device/port
  if ($ul >= 9) {
    my (@dev_arr, %devs);
    foreach my $ts_id (@ts) {
	$sref = CMU::Netdb::list_trunkset_device_presence($dbh, $user, "trunkset_machine_presence.trunk_set = '$ts_id'");
	my (@devA, %devs_local);
	my $ndks = -1;
	if (ref $sref) {
	    %devs_local = %$sref;
	    @devA = sort { $devs_local{$a} cmp $devs_local{$b} } keys %devs_local;
	    $ndks = keys %devs_local;
	    map { $devs{$_} = $devs_local{$_} } keys %devs_local;
	}
    }
    @dev_arr = sort { $devs{$a} cmp $devs{$b} } keys %devs;

    $devs{0} = 'Unknown Device';
    unshift @dev_arr, 0;

    #Get default device, from outlet.device to trunkset_machine_presence
    my $def_ts_mach = 0;
    my $ts_mach = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'machine',
				"trunkset_machine_presence.id = '$odata[$outlet_pos{'outlet.device'}]'");
    my $ts_mach_map = CMU::Netdb::makemap($ts_mach->[0]);
    if ($#$ts_mach > 0) {
	$def_ts_mach = $ts_mach->[1]->[$ts_mach_map->{'trunkset_machine_presence.device'}];
	$def_ts_mach = 0 if (!defined $devs{$def_ts_mach});
    }

    print "<input type=hidden name=oldd value=$odata[$outlet_pos{'outlet.device'}]>\n";
    print "<input type=hidden name=oldp value=$odata[$outlet_pos{'outlet.port'}]>\n";
    print "<tr>" . CMU::WebInt::printPossError(defined $errors->{'device'}, $outlet_printable{'outlet.device'}, 1, 'outlet.device') .
      CMU::WebInt::printPossError(defined $errors->{'oport'}, $outlet_printable{'outlet.port'}, 1, 'outlet.port'). 
	"</tr><tr><td>".CMU::WebInt::printVerbose('outlet.device', $verbose);
    print $q->popup_menu(-name => 'odevice',
			 -values => \@dev_arr,
			 -default => $def_ts_mach,
			 -labels => \%devs).
			 "</td><td>".
	CMU::WebInt::printVerbose('outlet.port', $verbose).
	$q->textfield(-name => 'oport', -accesskey=>'p',
		      -value => $odata[$outlet_pos{'outlet.port'}]);
    print "</td></tr>\n";
  }

  {
    
    my %ofields = ();
    my @outlet_field_short = ();

    foreach (@CMU::Netdb::structure::outlet_fields) {
      my $nk = $_;
      $nk =~ s/^outlet\.//;
      push(@outlet_field_short, $nk);
    }
    {
      my $i = 0;
      map { $ofields{$_} = $odata[$i++] } @outlet_field_short;
    }
    my $state;
    $state = CMU::Netdb::get_outlet_state(\%ofields);
    my @flags = split(/\,/, $ofields{flags});
    my @attr = split(/\,/, $ofields{attributes});


    # Display current outlet-subnet mappings, and if outlet is currently in 
    # an active state, allow changes.  If 'Advanced Options' was clicked, 
    # display extra subnets interface at bottom of page.

    my $sompref = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user, 
	    "outlet_vlan_membership.outlet = $id and outlet_vlan_membership.type='primary'");
    
    if (!ref $sompref) {
      print "Unable to query outlet-subnet mapping: ".$errmeanings{$sompref}."\n";
      print " (Database: ".$CMU::Netdb::primitives::db_errstr." )" 
	if ($sompref eq $CMU::Netdb::errcodes{EDB});
      print &CMU::WebInt::stdftr($q);
      return;
    }

    my $somps = @$sompref;
    # somps < 2, no primary
    # somps > 2, error
    my ($default,$smid,$smver, $def_name);
    my $sommap = CMU::Netdb::makemap($sompref->[0]);

    if ($somps > 2) {
      print "Error listing outlet-subnet mapping:  Multiple primary subnets\n";
      print &CMU::WebInt::stdftr($q);
      return;
    } elsif ($somps < 2) {
      $default = -1;
    } else {
      ## replaced with outlet_subnet_membership.xxx ::: Change...
      $default = $sompref->[1][$sommap->{'outlet_vlan_membership.vlan'}];
      $smid = $sompref->[1][$sommap->{'outlet_vlan_membership.id'}];
      $smver = $sompref->[1][$sommap->{'outlet_vlan_membership.version'}];
      $def_name = $sompref->[1][$sommap->{'vlan.name'}];
    }

    $adv_default = $default;

    my (@vlan_arr, %vlans );
    if ($vlanAll == 1) {
	# This will be used for complete vlan view.
	foreach my $ts_id (@ts) {
	    $sref = CMU::Netdb::list_trunkset_vlan_presence($dbh, $user, "trunkset_vlan_presence.trunk_set = '$ts_id'");
	    my $nvks = -1;
	    my (%vlan_local, @vlan);
	    if (ref $sref) {
		%vlan_local = %$sref;
		@vlan = sort { $vlan_local{$a} cmp $vlan_local{$b} } keys %vlan_local;
		$nvks = keys %vlan_local;
		map { $vlans{$_} = $vlan_local{$_}} keys %vlan_local;
		map {push(@vlan_arr, $_)} @vlan;
	    }
	}
	foreach my $v_id (@vlan_arr) {
	    $sref = CMU::Netdb::get_vlan_ref($dbh, $user, "vlan.id = $v_id", 'vlan.name');
	    delete $vlans{$v_id} if (!ref $sref || !defined $sref->{$v_id});
	}
	$pref = \%vlans;
    } else {
	# Get trunksets on this device
	$pref = get_vlan_on_device($odata[$outlet_pos{'outlet.device'}] , $dbh, $user);
    }

    my $vlist = "<font face=\"Arial,Helevetica,Geneva,Charter\">".
		"[<b><a href=$url?op=outlets_info&oid=$id&vlanAll=1>View complete list</a></b>]</font>\n" ;
    my @order = sort { $pref->{$a} cmp $pref->{$b} } keys %$pref;

    if ($default == -1) {
      $pref->{-1} = '--Unspecified--';
      unshift @order, -1;
    } elsif (! defined $pref->{$default}) {
      $default = -1;
      $pref->{-1} = "-Select- (Currently vlan invalid \"$def_name\")";
      unshift @order, -1;
    }



    # Check for pending 'other' vlans (trunk) request.
    my $other_ref = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user, 
	    "outlet_vlan_membership.outlet = $id and outlet_vlan_membership.type = 'other' and outlet_vlan_membership.status = 'request'");

    my $otherps = @$other_ref;

    print "<tr>".CMU::WebInt::printPossError(defined $$errors{'subnet'}, "Network Segment", 2, '', '')
	."</tr><tr>".
	"<td colspan=2>".CMU::WebInt::printVerbose('outlet.subnet', $verbose);

    # Added following elsif 'outlet_vlan_membership.status = change'
    if ($default != -1 && $sompref->[1][$sommap->{'outlet_vlan_membership.status'}] ne 'active') {
	my $vref = CMU::Netdb::list_vlans($dbh, $user, "vlan.id = $sompref->[1][$sommap->{'outlet_vlan_membership.vlan'}]");
	my @vArr = @{$vref->[1]};
	my $vName = $vArr[$CMU::WebInt::vlans::vlan_pos{'vlan.name'}];
	print "$pref->{$default} <b>[";
	
	if ($sompref->[1][$sommap->{'outlet_vlan_membership.status'}] eq 'request') {
	    print "Requested, not active yet.";
	    $adv_default = -1;
	} elsif ($sompref->[1][$sommap->{'outlet_vlan_membership.status'}] eq 'delete') { 
	    print "Reset Back To Default Requested, not complete yet.";
	    $adv_default = -1;
	} elsif ($sompref->[1][$sommap->{'outlet_vlan_membership.status'}] eq 'error' || 
	    $sompref->[1][$sommap->{'outlet_vlan_membership.status'}] eq 'errordelete') {
	    print "An error occurred while configuring the device.";
	    $adv_default = -1;
	} elsif ($sompref->[1][$sommap->{'outlet_vlan_membership.status'}] eq 'change') {
	    print "Requested, not changed yet. ";
	    $adv_default = -1;
	} elsif ($sompref->[1][$sommap->{'outlet_vlan_membership.status'}] eq 'novlan' ||
		$sompref->[1][$sommap->{'outlet_vlan_membership.status'}] eq 'nodev') {
	    print "Device does not support multiple networks.";
	    $adv_default = -1;
	} else {
	    print "Unknown Status.";
	    $adv_default = -1;
        }
	if ($ul >= 9) {
	  print "[<b><a href=\"" .
	    CMU::WebInt::encURL("$url?op=outlets_force_vlan_membership" .
				"&oid=$id" .
				"&opt=act" .
				"&v=$sompref->[1][$sommap->{'outlet_vlan_membership.version'}]" .
				"&id=$sompref->[1][$sommap->{'outlet_vlan_membership.id'}]" 
			       ) .
				 "\">Set&nbsp;Active (Database&nbsp;Only)</a></b>]";
	}
	
	print "]</b></td></tr>\n\n";
	print '<tr><td><table border=1><tr><td>'.$vName.'</td></tr></table>';
	print "<input type=hidden name=oldprimary value=$default>\n";
	print "<input type=hidden name=defvlan value=$vArr[$CMU::WebInt::vlans::vlan_pos{'vlan.id'}]>\n" if ($vName ne '');
	print "\n</td></tr>\n";
    } elsif ($otherps > 1) {
	print "<b>[secondary vlan requested for trunking on this outlet]</b>\n\n";
	print "<input type=hidden name=oldprimary value=$default>\n";
	print '<table border=1><tr><td>'.$pref->{$default}.'</td></tr></table></td></tr>';

    } elsif ($state eq 'OUTLET_ACTIVE' || $state eq 'OUTLET_PERM_ACTIVE') {
	my $vlanMenu = $q->popup_menu(-name => 'primarysubnet', -accesskey=>'n',
			   -values => \@order,
			   -default => $default,
			   -labels => $pref);
	$vlanMenu .= $vlist if ($vlanAll == 0);
	print $vlanMenu;
	print "<input type=hidden name=oldprimary value=$default>\n";
	if ($default != -1) {
	    print "<input type=hidden name=smid value=$smid>
	    <input Type=hidden name=smver value=$smver>\n";
	}
	print "</td></tr>\n\n";

    } else {
	print "<input type=hidden name=oldprimary value=$default>\n";
	print "<input type=hidden name=defvlan value=$default>\n";
	print "$pref->{$default}</td></tr>\n\n";
    }
 
    my ($msg1, $msg9, $f1, $f9, @nflags) = ('', '', '', '', ());
    if ($state eq 'OUTLET_WAIT_ACTIVATION') {
      $msg1 = "This outlet is currently <b>not enabled</b> and is ".
	"<b>waiting to be activated</b>";
      @nflags = @flags;
      push(@nflags, 'permanent');
      $f9 = " [<b><a href=\"".CMU::WebInt::encURL("$url?op=outlets_delete&id=$id&version=$version")."\">Delete Outlet</a></b>]";
    }elsif($state eq 'OUTLET_WAIT_ENABLE') {
      $msg1 = 'This outlet is currrently <b>waiting to be enabled</b> and is '.
	'<b>activated</b>';
    }elsif($state eq 'OUTLET_WAIT_CHANGE') {
      $msg1 = 'This outlet is currently <b>activated</b> but <b> not yet connected '.
	  'to the correct network</b>';
    }elsif($state eq 'OUTLET_ACTIVE') {
      $msg1 = 'This outlet is currently <b>enabled</b> and <b>active</b>';
      @nflags = @flags;
      @nflags = grep (!/^activated$/, @nflags);
      $f1 = "[<b><a href=\"".CMU::WebInt::encURL("$url?op=outlets_update&oid=$id&version=$version&qt=2&attributes=deactivate&flags=".join(',', @nflags))."\">Deactivate</a></b>]";
      @nflags = @flags;
      push(@nflags, 'permanent');
      $f9 = "[<b><a href=\"".CMU::WebInt::encURL("$url?op=outlets_update&oid=$id&version=$version&qt=3&flags=".
				    join(',', @nflags))."\">Make Permanent</a>"."</b>] $f1";
    }elsif($state eq 'OUTLET_WAIT_PARTITION') {
      $msg1 = 'This outlet is currently <b>waiting to be partitioned</b> and is '.
	'<b>activated</b>';
    }elsif($state eq 'OUTLET_WAIT_DEACTIVATION') {
      $msg1 = 'This outlet is currently <b>not enabled</b> and is '.
	'<b>waiting to be deactivated</b>';
      $f9 = @nflags = @flags;
      push(@nflags, 'permanent');
      $f9 = "[<b><a href=\"".CMU::WebInt::encURL("$url?op=outlets_update&oid=$id&version=$version&qt=3&flags=".
				    join(',', @nflags))."\">Make Permanent</a>"."</b>]";
    }elsif($state eq 'OUTLET_PERM_UNACTIVATED') {
      $msg9 = 'This permanently-connected outlet is currently <b>activated</b> and '.
	'<b>not enabled</b>, waiting to be registered.';
      $f9 = "[<b><a href=\"".CMU::WebInt::encURL("$url?op=outlets_delete&id=$id&version=$version")."\">Delete Outlet</a></b>]";
    }elsif($state eq 'OUTLET_PERM_WAIT_ENABLE') {
      $msg1 = 'This permanently-connected outlet is currrently <b>waiting to be enabled</b> and is '.
	'<b>activated</b>';
    }elsif($state eq 'OUTLET_PERM_WAIT_CHANGE') {
      $msg1 = 'This permanently-connected outlet is currrently <b>waiting to be rewired</b>.';
    }elsif($state eq 'OUTLET_PERM_ACTIVE') {
      $msg1 = 'This permanently-connected outlet is currently <b>enabled</b> and <b>active</b>';
      @nflags = @flags;
      @nflags = grep(!/^activated$/, @nflags);
      $f1 = "[<b><a href=\"".CMU::WebInt::encURL("$url?op=outlets_update&oid=$id&version=$version&qt=1&flags=".
				    join(',', @nflags))."\">Deactivate</a>"."</b>]";
      @nflags = @flags;
      @nflags = grep(!/^permanent$/, @nflags);
      $f9 = "[<b><a href=\"".CMU::WebInt::encURL("$url?op=outlets_update&oid=$id&version=$version&qt=3&flags=".
				    join(',', @nflags))."\">Make Non-Permanent</a>"."</b>] $f1";
    }elsif($state eq 'OUTLET_PERM_WAIT_PARTITION') {
      $msg1 = 'This permanently-connected outlet is currently <b>waiting to be partitioned</b> and is '.
	'<b>activated</b>';
    }else{
      $msg1 = 'This outlet is currently in an unknown state.';
    }
    
    my $extra = '';
    $extra = $f9 if (defined $f9 && $f9 ne '' && $ul >= 9);
    $extra = $f1 if ($extra eq '' && defined $f1 && $f1 ne '');
    $extra = '&nbsp;' if ($extra eq '');
    print "<tr>".CMU::WebInt::printPossError(0, 'Outlet Summary', 2, '', $extra)."</tr><tr>
<td colspan=2>".CMU::WebInt::printVerbose('outlet.summary', $verbose);
    my $msg = '';
    $msg = $msg9 if (defined $msg9 && $msg9 ne '' && $ul >= 9);
    $msg = $msg1 if ($msg eq '' && defined $msg1 && $msg1 ne '');
    print '<table border=1><tr><td>'.$msg.'</td></tr></table></td></tr>';
  }


  # l9 attributes/flags
  if ($ul >= 9) {
    print "<tr>" . CMU::WebInt::printPossError(defined $errors->{'attributes'}, $outlet_printable{'outlet.attributes'}, 1, 'outlet.attributes')
    .CMU::WebInt::printPossError(defined $errors->{'flags'}, $outlet_printable{'outlet.flags'} , 1, 'outlet.flags');
    print "</tr><tr><td>".CMU::WebInt::printVerbose('outlet.attributes', $verbose);
    my @curattrib = $odata[$outlet_pos{'outlet.attributes'}];
    print $q->checkbox_group(-name => 'oattributes',
			     -defaults => \@curattrib,
			     -values => ['activate', 'deactivate', 'change']);
    print "</td>";
    
    my @curflags = split(/\,/, $odata[$outlet_pos{'outlet.flags'}]);
    print "<td>".CMU::WebInt::printVerbose('outlet.flags', $verbose).
      $q->checkbox_group(-name => 'oflags',
			 -defaults => \@curflags,
			 -values => \@outlet_flags,
			 -linebreak => 'yes') .
			   "</td>";
    print "</tr>";
  }

  print "<tr>" . CMU::WebInt::printPossError(defined $errors->{comment_lvl1}, $outlet_printable{'outlet.comment_lvl1'}, 1, 'outlet.comment_lvl1');
  print CMU::WebInt::printPossError(defined $errors->{comment_lvl5}, $outlet_printable{'outlet.comment_lvl5'}, 1, 'outlet.comment_lvl5') if ($ul >= 5);
  print "</tr>\n";
  my $len = length($odata[$outlet_pos{'outlet.comment_lvl1'}]);
  $len = ($len > 50) ? 60 : $len + 10;
  print "<tr><td>" . CMU::WebInt::printVerbose('outlet.comment_lvl1', $verbose) . 
    $q->textfield(-name => 'ocomment_lvl1', -accesskey=>'u', -size => $len,
		  -value => $odata[$outlet_pos{'outlet.comment_lvl1'}]) .
		    "</td>";
  $len = length($odata[$outlet_pos{'outlet.comment_lvl5'}]);
  $len = ($len > 50) ? 60 : $len + 10;
  print "<td>" . CMU::WebInt::printVerbose('outlet.comment_lvl5', $verbose) .
    $q->textfield(-name => 'ocomment_lvl5', -accesskey=>'d', -size => $len,
		  -value => $odata[$outlet_pos{'outlet.comment_lvl5'}]) . "</td>"
		    if ($ul >= 5);
  print "</tr>";

  if ($ul >= 9) {
    $len = length($odata[$outlet_pos{'outlet.comment_lvl9'}]);
    $len = ($len > 50) ? 60 : $len + 10;
    print "<tr>" . CMU::WebInt::printPossError(defined $errors->{comment_lvl9}, $outlet_printable{'outlet.comment_lvl9'}, 1, 'outlet.comment_lvl9') . "</tr>";
    print "<tr><td colspan=2>". CMU::WebInt::printVerbose('outlet.comment_lvl9', $verbose) .
      $q->textfield(-name => 'ocomment_lvl9', -accesskey=>'a', -size => $len,
		    -value => $odata[$outlet_pos{'outlet.comment_lvl9'}]) .
		      "</td></tr>\n";
  }
  

  # expire
  if ($odata[$outlet_pos{'outlet.expires'}] ne '0000-00-00') {
    print "<tr>".CMU::WebInt::printPossError(0, $outlet_printable{'outlet.expires'}, 1, 'expires')."</tr>
   <tr>".
       "<td>".CMU::WebInt::printVerbose('outlet.expires', $verbose).
         $odata[$outlet_pos{'outlet.expires'}];
    print " <font face=\"Arial,Helvetica,Geneva,Charter\" size=+1>[<b><a tabindex=\"90\" href=\"".CMU::WebInt::encURL("$url?op=outlets_unexpire&id=$id&version=$version&oid=$id")."\">Retain</a></b>]</font>\n" if ($wl >= 1);
    print "</td></tr>\n";
  }


  # department
  { 
    my $cdref = CMU::Netdb::list_protections($dbh, $user, 'outlet', $id);
    my @cdept;
    my $dtitle = '';
    
    $dtitle .= "<font face=\"Arial,Helevetica,Geneva,Charter\">[<b><a href=$url?op=outlets_info&oid=$id&deptAll=1>View complete list</a></b>]\n" 
	if ($deptAll ne '1');
    print "<tr>".CMU::WebInt::printPossError(defined $errors->{'department'}, 'Affiliation', 2, 'department')."</tr>";
    if (!ref $cdref) {
      @cdept = ('[error]','[error]');
      &CMU::WebInt::admin_mail('outlets.pm:outlets_info', 'WARNING',
		'Error in list_protections.', {});
    }else{
      map { @cdept = ($_->[1],'') if ($_->[1] =~ /^dept:/); } @$cdref;
    }
    
    $cdref = CMU::Netdb::list_groups($dbh, $user, "name=\"$cdept[0]\"");
    if (!ref $cdref) {
      @cdept = ('[error]','[Unable to determine current affiliation]');
      &CMU::WebInt::admin_mail('outlets.pm:outlet_info', 'WARNING',
		'Error in list_protections.', {});
    }
    
    $cdept[1] = $cdref->[1]->[$CMU::WebInt::auth::groups_pos{'groups.description'}];
    if ($ul < 1) {
      print "<tr><td colspan=2>$cdept[1]</td></tr>\n";
    }else{
      my $depts;
      if ($deptAll eq '1') {
	$depts = CMU::Netdb::get_departments($dbh, $user, '', 'ALL', '', 'groups.description', 'GET');
      }else{ 
	$depts = CMU::Netdb::get_departments($dbh, $user, '', 'USER', $user, 'groups.description', 'GET');
      }
      if (!ref $depts) {
	print "<tr><td colspan=2>".CMU::WebInt::printVerbose('machine.department', $verbose). 
	  "$cdept[1]<input type=hidden name=dept value=$cdept[0]></td></tr>\n";
      }else{
	$depts->{$cdept[0]} = $cdept[1];
	my @order = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;
	
	print "<tr><td colspan=2>".CMU::WebInt::printVerbose('machine.department', $verbose).
	  $q->popup_menu(-name => 'dept', -accesskey=>'a',
			 -values => \@order,
			 -default => $cdept[0],
			 -labels => $depts).$dtitle;
	print "</td></tr>\n";
      }
    }
  }

  # port speed and duplex attributes, if set or showing advanced options
  # Verify that port-speed and port-duplex attribute exist, and we can add them.
  # otherwise skip the custom UI for those attributes
  my $spec = CMU::Netdb::get_attribute_spec_ref($dbh, $user, "attribute_spec.name IN ('port-speed', 'port-duplex') AND attribute_spec.scope = 'outlet'",
						"attribute_spec.name");

  my ($show_speed, $show_duplex) = (0,0);

  foreach (keys %$spec) {
    $show_speed = 1 if ($spec->{$_} eq 'port-speed');
    $show_duplex = 1 if ($spec->{$_} eq 'port-duplex');
  }

  if ($show_speed || $show_duplex) {
    # At least one of the attributes is defined in the database.  So we display the custom UI
    # for one or both attributes

    my $attrs = CMU::Netdb::list_attribute($dbh, $user, "attribute.owner_table = 'outlet' AND attribute.owner_tid = $id"
					   . " AND attribute_spec.name IN ('port-speed', 'port-duplex')");

    my ($def_speed, $def_duplex) = ('auto', 'auto');;
    my $attrmap = CMU::Netdb::makemap($attrs->[0]);
    shift @$attrs;
    foreach my $a ( @$attrs ) {
      if ($a->[$attrmap->{'attribute_spec.name'}] eq 'port-speed') {
	$def_speed = $a->[$attrmap->{'attribute.data'}];
      }
      if ($a->[$attrmap->{'attribute_spec.name'}] eq 'port-duplex') {
	$def_duplex = $a->[$attrmap->{'attribute.data'}];
      }
    }


    # If we're not showing advanced options, and neither attribute is set to something other then auto
    # then we skip the UI.
    if ($adv || $def_speed ne 'auto' || $def_duplex ne 'auto') {
      # Nope, we've got UI to show.  But since we may only want to show the UI for one of the attributes
      # we must be careful about which UI components to show.
      print "<tr>";

      if ($show_speed) {
	print CMU::WebInt::printPossError(defined $errors->{'port-speed'}, "Port Speed", "outlet.port_speed")."\n";
      }
      if ($show_duplex) {
	print CMU::WebInt::printPossError(defined $errors->{'port-duplex'}, "Port Duplex", "outlet.port_duplex")."\n";
      }
      print "</tr>\n<tr>";

      if ($show_speed) {
	print "<td>".CMU::WebInt::printVerbose('outlet.port_speed', $verbose);
	print $q->popup_menu(-name => 'port-speed',
			     -values => ['auto', 'forced-10', 'forced-100'],
			     -labels => {'auto' => 'Auto Negotiated', 
					 'forced-10' => '10 Megabit Only', 
					 'forced-100' => '100 Megabit only'},
			     -default => $def_speed);
	print "</td>\n";
      }

      if ($show_duplex) {
	print "<td>".CMU::WebInt::printVerbose('outlet.port_duplex', $verbose);
	print $q->popup_menu(-name => 'port-duplex',
			     -values => ['auto', 'forced-half', 'forced-full'],
			     -labels => {'auto' => 'Auto Negotiated', 
					 'forced-half' => 'Half Duplex', 
					 'forced-full' => 'Full Duplex'},
			     -default => $def_duplex);
	print "</td>";
      }

      print "</tr>\n";
    }
  }

 print "<tr><td colspan=2>" . $q->submit(-value=>'Update');
  if ($ul >= 9) {
    print $q->submit(-name=>'force', -value=>'Force Update (Database Only)') . "\n";
  }
  print "</td></tr>\n";
  print "</table></form>\n";


  # Other subnets attached to this outlet
  my $somref;
  if ($ul >= 9) {
    $somref = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user, "outlet = $id AND outlet_vlan_membership.type!='primary'");
  } else {
    $somref = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user, "outlet = $id AND outlet_vlan_membership.type!='primary'".
                                                       " AND outlet_vlan_membership.status != 'delete'");
  }

  if (!ref $somref) {
    print "Unable to query outlet-subnet mapping: ".$errmeanings{$somref}."\n";
    print " (Database: ".$CMU::Netdb::primitives::db_errstr." )" 
      if ($somref eq $CMU::Netdb::errcodes{EDB});
    print &CMU::WebInt::stdftr($q);
    return;
  }
 my %printable = (%CMU::Netdb::structure::outlet_vlan_membership_printable, %CMU::Netdb::structure::vlan_printable);
  my $columns = ['vlan.name',
                 'outlet_vlan_membership.type',
                 'outlet_vlan_membership.trunk_type',
                 'outlet_vlan_membership.status'];

  if ( ($#$somref != 0 || gParam($q, 'adv') == 1) && $adv_default != -1 && $ul >= 5) {
    my $sopos = CMU::Netdb::makemap($somref->[0]);
    print "<br>\n";
    print CMU::WebInt::subHeading("Additional Subnets/Vlans Connected to This Outlet", CMU::WebInt::pageHelpLink('outlet_vlan_membership'));

    $pref = get_vlan_on_device($odata[$outlet_pos{'outlet.device'}] , $dbh, $user);
    $pref->{'##q--'} = $q;
    $pref->{'##oid--'} = $id;

  if ($ul >= 9) {
      push(@{$somref->[0]}, 'Force');
      foreach (1 .. $#$somref) {
	if (($somref->[$_][$sopos->{'outlet_vlan_membership.status'}] eq 'request') ||
	    ($somref->[$_][$sopos->{'outlet_vlan_membership.status'}] eq 'error') || 
	    ($somref->[$_][$sopos->{'outlet_vlan_membership.status'}] eq 'change')) {
	  push(@{$somref->[$_]}, "<b>[<a href=\"$url?op=outlets_force_vlan_membership" .
	       "&oid=$id" .
	       "&v=$somref->[$_][$sopos->{'outlet_vlan_membership.version'}]" .
	       "&id=$somref->[$_][$sopos->{'outlet_vlan_membership.id'}]" .
	       "&opt=act" .
	       "\">" .
	       "Set&nbsp;Active (Database&nbsp;Only)" .
	       "</a>]</b>"
	      );
	} elsif (($somref->[$_][$sopos->{'outlet_vlan_membership.status'}] eq 'active') ||
		 ($somref->[$_][$sopos->{'outlet_vlan_membership.status'}] eq 'errordelete') ||
		 ($somref->[$_][$sopos->{'outlet_vlan_membership.status'}] eq 'delete')) {
	  push(@{$somref->[$_]}, "<b>[<a href=\"$url?op=outlets_force_vlan_membership" .
	       "&oid=$id" .
	       "&v=$somref->[$_][$sopos->{'outlet_vlan_membership.version'}]" .
	       "&id=$somref->[$_][$sopos->{'outlet_vlan_membership.id'}]" .
	       "&opt=del" .
	       "\">" .
	       "Force&nbsp;Delete (Database&nbsp;Only)" .
	       "</a>]</b>"
	      );
	} else {
	  push(@{$somref->[$_]}, "&nbsp;");
	}
      }
      $printable{'Force'} = 'Force (Database Only)';
      push(@$columns, 'Force');
    }

    CMU::WebInt::generic_smTable($url,
                                 $somref,
                                 $columns,
                                 CMU::Netdb::makemap($somref->[0]),
				 \%printable,
				 "oid=$id", 
				'outlet_vlan_membership', 
				'outlets_del_vlan_membership',
				 \&CMU::WebInt::outlets::cb_outlet_add_vlan_membership,
				 $pref);
  }


  # Other attributes attached to this outlet
  print "<br>";
  CMU::WebInt::attr_display($dbh, $user, 'outlet', $id, "attribute_spec.name NOT IN ('port-speed', 'port-duplex')", $adv);


  # Cable info
  print "<br>";
  print CMU::WebInt::subHeading("Attached Cable Information", CMU::WebInt::pageHelpLink(''));
  print "<table border=0><tr>" .
    CMU::WebInt::printPossError(0, $outlet_cable_printable{'cable.from'}, 1, 'label_from').CMU::WebInt::printPossError(0, $outlet_cable_printable{'cable.to'}, 1, 'label_to') . "</tr>";
  print "<tr><td>$cdata[$cable_pos{'cable.label_from'}]</td>
<td>$cdata[$cable_pos{'cable.label_to'}]</td></tr><tr>";

  print CMU::WebInt::printPossError(0, $outlet_cable_printable{'cable.to_building'}, 1, 'cable.to_building').CMU::WebInt::printPossError(0, $outlet_cable_printable{'cable.to_room_number'}, 1, 'cable.to_room_number').
    "</tr><tr><td>";
  if ($bdata{$cdata[$cable_pos{'cable.to_building'}]} ne '') {
    print $bdata{$cdata[$cable_pos{'cable.to_building'}]};
  }
  else {
    print $cdata[$cable_pos{'cable.to_building'}];
  }
  print "</td><td>$cdata[$cable_pos{'cable.to_room_number'}]</td></tr><tr>";

  print CMU::WebInt::printPossError(0, $outlet_cable_printable{'cable.type'}, 1, 'cable.type').
    "</tr><tr><td>$cdata[$cable_pos{'cable.type'}]</td></tr></table>";


  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub get_vlan_on_device {
    my ($devid, $dbh, $user) = @_;
    my (@vlan_arr, %vlans, $sref, $devcount);
    
    return \%vlans if ($devid == 0);

    my $ts_mach = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'machine',
			    "trunkset_machine_presence.id = '$devid'");
    my $ts_mach_map = CMU::Netdb::makemap($ts_mach->[0]);
    return \%vlans if ($#$ts_mach == 0);

    $devid = $ts_mach->[1]->[$ts_mach_map->{'trunkset_machine_presence.device'}];
    my $tsRefs = CMU::Netdb::list_device_trunkset_presence($dbh, $user, "trunkset_machine_presence.device = '$devid'");


    my %tsHash = %$tsRefs;
    foreach my $ts_id (keys %tsHash) {
	$sref = CMU::Netdb::list_trunkset_vlan_presence($dbh, $user, "trunkset_vlan_presence.trunk_set = '$ts_id'");
	my (%vlan_local, @vlan);
	if (ref $sref) {
	    %vlan_local = %$sref;
	    @vlan = sort { $vlan_local{$a} cmp $vlan_local{$b} } keys %vlan_local;
	    map { $vlans{$_} = $vlan_local{$_}} keys %vlan_local;
	    map {push(@vlan_arr, $_)} @vlan;
	}
    }
    foreach my $v_id (@vlan_arr) {
	$sref = CMU::Netdb::get_vlan_ref($dbh, $user, "vlan.id = $v_id", 'vlan.name');
	delete $vlans{$v_id} if (!ref $sref || !defined $sref->{$v_id});
    }
    return \%vlans;
}

sub cb_outlet_add_vlan_membership {
    my ($pref) = @_;
    my ($q, $oid, $primaryvlan, $res, @order);

    $q = $$pref{'##q--'}; delete $$pref{'##q--'};
    $oid = $$pref{'##oid--'}; delete $$pref{'##oid--'};
    $primaryvlan = $$pref{'##primaryvlan--'};
    delete $$pref{'##primaryvlan--'};

    $res = "<tr><td><form method=get>
<input type=hidden name=op value=outlets_add_vlan_membership>
<input type=hidden name=oid value=$oid>
<input type=hidden name=id value=$oid>
<input type=hidden name=primaryvlan value=$primaryvlan>\n";

    @order = sort {$pref->{$a} cmp $pref->{$b}} keys %$pref;
    unshift @order, -1;
    $pref->{-1} = "Select Vlan(secondary)";

    $res .= $q->popup_menu(-name => 'vlan',
			   -values => \@order,
			   -labels => $pref,
			   -default => -1);
    my @noprimary = @CMU::Netdb::structure::outlet_vlan_membership_type;
    shift @noprimary;
    $res .= "</td><td>".$q->popup_menu(-name => 'type',
				       -values => \@noprimary);
    $res .= "</td><td>".$q->popup_menu(-name => 'trunk_type',
				       -values => \@CMU::Netdb::structure::outlet_vlan_membership_trunk_type);
    $res .= "</td><td>\n<input type=submit value=\"Add VLAN\"></form></td></tr>\n";
    return $res;
}


sub cb_outlet_add_membership {
    my ($pref) = @_;
    my $q = $$pref{'##q--'}; delete $$pref{'##q--'};
    my $oid = $$pref{'##oid--'}; delete $$pref{'##oid--'};
    my $subnet = $$pref{'##subnet--'}; delete $$pref{'##subnet--'};
    my $vlan = $$pref{'##vlan--'}; delete $$pref{'##vlan--'};
    my $res;

    if ($subnet ne '') {
	$res = "<tr><td><form method=get>
	    <input type=hidden name=op value=outlets_show_membership>
	    <input type=hidden name=subnet value=$subnet>
	    <input type=hidden name=id value=$oid>\n";
    } elsif ($vlan ne '') {
	$res = "<tr><td><form method=get>
	    <input type=hidden name=op value=outlets_show_membership>
	    <input type=hidden name=vlan value=$vlan>
	    <input type=hidden name=id value=$oid>\n";
    }

}

sub outlets_add_vlan_membership {
    my ($q) = @_;
    my (%fields, $res, %error, $dbh, $ref, $user, $p, $r);

    $dbh = CMU::WebInt::db_connect();
    ($user, $p, $r) = CMU::WebInt::getUserInfo();
    %fields = ('outlet' => CMU::WebInt::gParam($q, 'oid'),
		'vlan' => CMU::WebInt::gParam($q,'vlan'),
		'type' => CMU::WebInt::gParam($q,'type'),
		'trunk_type' => CMU::WebInt::gParam($q, 'trunk_type'),
		'status' => 'request');
    ($res, $ref) = CMU::Netdb::add_outlet_vlan_membership($dbh, $user, \%fields);
    if ($res != 1) {
	$error{msg} = "Error adding vlan mapping: ".$errmeanings{$res};
	$error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
	    if ($res eq $CMU::Netdb::errcodes{EDB});
	$error{msg} .=  " [".join(',',@$ref)."] ";
	$error{type} = 'ERR';
	$error{loc} = 'outlet_add_vlan_membership';
	$error{code} = $res;
	$error{fields} = join(',',@$ref);
    } else {
	$error{msg} = "Outlet/VLAN mapping requested.";
    }

    $dbh->disconnect();
    CMU::WebInt::outlets::outlets_info($q,\%error);

}

sub outlets_del_vlan_membership {
  my ($q) = @_;
  my ($id, $version, $res, %error, $dbh, $ref);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::WebInt::gParam($q, 'id'),
  $version = CMU::WebInt::gParam($q, 'v');

  $ref = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user, "outlet_vlan_membership.id = $id");
  if (!ref $ref) {
    $error{msg} = "Error changing vlan mapping: ".$errmeanings{$ref};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($ref eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'outlets_del_vlan_membership';
    $error{code} = $ref;
    $dbh->disconnect();
    CMU::WebInt::outlets::outlets_info($q, \%error);
    return;
  }
  my $map = CMU::Netdb::makemap($ref->[0]);
  my %fields = ( 'outlet' => $ref->[1][$map->{'outlet_vlan_membership.outlet'}],
		 'vlan' => $ref->[1][$map->{'outlet_vlan_membership.vlan'}],
		 'type' => $ref->[1][$map->{'outlet_vlan_membership.type'}],
		 'trunk_type' => $ref->[1][$map->{'outlet_vlan_membership.trunk_type'}],
		 'status' => 'delete'
	       );
  ($res, $ref) = CMU::Netdb::modify_outlet_vlan_membership($dbh, $user, $id, $version, \%fields);
  if ($res!= 1) {
    $error{msg} = "Error changing vlan mapping: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{msg} .= " [".join(',', @$ref)."] ";
    $error{type} = 'ERR';
    $error{loc} = 'outlets_del_vlan_membership';
    $error{code} = $res;
    $error{fields} = join(',', @$ref);
  } else {
    $error{msg} = "Removal of Outlet/VLAN mapping requested.";
  }
  $dbh->disconnect();
  CMU::WebInt::outlets::outlets_info($q, \%error);

}

sub outlets_force_vlan_membership {
  my ($q) = @_;
  my ($id, $version, $res, %error, $dbh, $ref, $action);
  my ($ul);
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $id = CMU::WebInt::gParam($q, 'id'),
  $version = CMU::WebInt::gParam($q, 'v');
  $action = CMU::WebInt::gParam($q, 'opt');
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', 0);
  if ($ul < 9) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets");
    CMU::WebInt::accessDenied();
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return();
  }

  $ref = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user, "outlet_vlan_membership.id = $id");
  if (!ref $ref) {
    $error{msg} = "Error changing vlan mapping: ".$errmeanings{$ref};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
      if ($ref eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'outlets_del_vlan_membership';
    $error{code} = $ref;
    $dbh->disconnect();
    CMU::WebInt::outlets::outlets_info($q, \%error);
    return;
  }
 my $map = CMU::Netdb::makemap($ref->[0]);

  if ($action eq 'act') {
    my %fields = ( 'outlet' => $ref->[1][$map->{'outlet_vlan_membership.outlet'}],
                   'vlan' => $ref->[1][$map->{'outlet_vlan_membership.vlan'}],
                   'type' => $ref->[1][$map->{'outlet_vlan_membership.type'}],
                   'trunk_type' => $ref->[1][$map->{'outlet_vlan_membership.trunk_type'}],
                   'status' => 'active'
                 );
    ($res, $ref) = CMU::Netdb::modify_outlet_vlan_membership($dbh, $user, $id, $version, \%fields);
    if ($res!= 1) {
      $error{msg} = "Error changing vlan mapping: ".$errmeanings{$res};
      $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
        if ($res eq $CMU::Netdb::errcodes{EDB});
      $error{msg} .= " [".join(',', @$ref)."] ";
      $error{type} = 'ERR';
      $error{loc} = 'outlets_del_vlan_membership';
      $error{code} = $res;
      $error{fields} = join(',', @$ref);
    } else {
      $error{msg} = "Outlet/Vlan status set to active.";
    }
  } elsif ($action eq 'del') {
    ($res, $ref) = CMU::Netdb::delete_outlet_vlan_membership($dbh, $user, $id, $version);
    if ($res!= 1) {
      $error{msg} = "Error changing vlan mapping: ".$errmeanings{$res};
      $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
        if ($res eq $CMU::Netdb::errcodes{EDB});
      $error{msg} .= " [".join(',', @$ref)."] ";
      $error{type} = 'ERR';
      $error{loc} = 'outlets_del_vlan_membership';
      $error{code} = $res;
      $error{fields} = join(',', @$ref);
    } else {
      $error{msg} = "Outlet/Vlan membership deleted.";
    }
  }
  $dbh->disconnect();
  CMU::WebInt::outlets::outlets_info($q, \%error);

}



sub outlets_update {
  my ($q, $errors) = @_;
  my ($dbh, $version, $id, %fields, %error, $primarysubnet, $oldps, $vlanTrunk);
  my ($oldd,$oldpr, $checkHash, $defvlan, $speed, $duplex);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'version');
  $id = CMU::WebInt::gParam($q, 'oid');

  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', $id);
  if ($ul == 0) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets", $errors);
    CMU::WebInt::accessDenied('outlet', 'WRITE', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $qt = CMU::WebInt::gParam($q, 'qt');
  if ($qt eq '1' || $qt eq '3') {
    $fields{'flags'} = CMU::WebInt::gParam($q, 'flags');
  }elsif($qt eq '2') {
    $fields{'attributes'} = CMU::WebInt::gParam($q, 'oattributes');
    $fields{'flags'} = CMU::WebInt::gParam($q, 'flags');
  }

  if ($ul >= 9 && $qt eq '') {
    $fields{'type'} = CMU::WebInt::gParam($q,'otype');
    $fields{'device'} = CMU::WebInt::gParam($q,'odevice');
    $fields{'port'} = CMU::WebInt::gParam($q,'oport');
    $fields{'dept'} = CMU::WebInt::gParam($q, 'dept');
    $fields{'flags'} = join(',', CMU::WebInt::gParam($q, 'oflags'));
    $fields{'comment_lvl9'} = CMU::WebInt::gParam($q,'ocomment_lvl9');
    $fields{'comment_lvl5'} = CMU::WebInt::gParam($q,'ocomment_lvl5');
    $fields{'comment_lvl1'} = CMU::WebInt::gParam($q,'ocomment_lvl1');
    $fields{'attributes'} = CMU::WebInt::gParam($q,'oattributes')
	if (!defined $fields{'attributes'} || $fields{'attributes'} eq '');
    $primarysubnet = CMU::WebInt::gParam($q,'primarysubnet');
    $oldps = CMU::WebInt::gParam($q,'oldprimary');
    $oldd = CMU::WebInt::gParam($q,'oldd');
    $oldpr = CMU::WebInt::gParam($q, 'oldp');
    $speed = CMU::WebInt::gParam($q, 'port-speed');
    $duplex = CMU::WebInt::gParam($q, 'port-duplex');
  } elsif ($ul >= 5 && $qt eq '') {
    $fields{'comment_lvl5'} = CMU::WebInt::gParam($q,'ocomment_lvl5');
    $fields{'comment_lvl1'} = CMU::WebInt::gParam($q,'ocomment_lvl1');
    $fields{'dept'} = CMU::WebInt::gParam($q, 'dept');
    $primarysubnet = CMU::WebInt::gParam($q,'primarysubnet');
    $oldps = CMU::WebInt::gParam($q,'oldprimary');
    $speed = CMU::WebInt::gParam($q, 'port-speed');
    $duplex = CMU::WebInt::gParam($q, 'port-duplex');
  } elsif ($qt eq '') {
    $fields{'comment_lvl1'} = CMU::WebInt::gParam($q,'ocomment_lvl1');
    $fields{'dept'} = CMU::WebInt::gParam($q, 'dept');
    $primarysubnet = CMU::WebInt::gParam($q,'primarysubnet');
    $oldps = CMU::WebInt::gParam($q,'oldprimary');
    $speed = CMU::WebInt::gParam($q, 'port-speed');
    $duplex = CMU::WebInt::gParam($q, 'port-duplex');
  }

  $defvlan			= CMU::WebInt::gParam($q,'defvlan');
  $fields{'##primaryvlan--'} 	= ($primarysubnet ne '' ? $primarysubnet : $defvlan);
  $fields{'##oldvlan--'} = $oldps;
  # Generate hash
  $checkHash->{'id'}		= $id;
  $checkHash->{'newDevice'} 	= $fields{'device'};
  $checkHash->{'newPort'} 	= $fields{'port'};
  $oldd = CMU::WebInt::gParam($q,'oldd');
  if ((defined $oldd) && ($oldd ne '')) {
    warn __FILE__ . ":" . __LINE__ . ": oldd = $oldd\n" if ($debug >= 4);
    warn __FILE__ . ":" . __LINE__ . ": \n" . Data::Dumper->Dump([CMU::Netdb::list_trunkset_device_presence($dbh, $user, "trunkset_machine_presence.id = $oldd")],[qw(presence)]) . "\n" if ($debug >= 4);

    $checkHash->{'oldDevice'}   = ( keys %{CMU::Netdb::list_trunkset_device_presence($dbh, $user, "trunkset_machine_presence.id = $oldd")} )[0] ;
  } else {
    $checkHash->{'oldDevice'} = "";
  }
  $checkHash->{'oldPort'} 	= CMU::WebInt::gParam($q, 'oldp');
  $checkHash->{'newVlan'}	= ($primarysubnet eq ''? $defvlan : $primarysubnet);
  $checkHash->{'oldVlan'}	= $oldps;
  $checkHash->{'userlevel'} 	= $ul;
  $checkHash->{'qt'} 		= $qt;

  # check whether selected device has, selected vlan on it or not.
  my ($res, $field) = CMU::Netdb::check_devnet_mapping($dbh, $user, $checkHash);
  if ($res < 0 ) {
    $errors->{type} = 'ERR';
    $errors->{msg} = $errmeanings{$res};
    $errors->{code} = $res;
    $errors->{loc} = 'outlet_register';
    $errors->{fields} = join(',', @$field);
    CMU::WebInt::outlets_info($q, $errors);
    return;
  }
  # check for duplicate <device,port> tuple.
  if ($primarysubnet != $oldps) {
    ($res, $field) = CMU::Netdb::check_devport_mapping($dbh, $user, $checkHash);
    if ($res < 0) {
	$errors->{type} = 'ERR';
	$errors->{msg} = $errmeanings{$res};
	$errors->{code} = $res;
	$errors->{loc} = 'outlet_register';
	$errors->{fields} = join(',', @$field);
	CMU::WebInt::outlets_info($q, $errors);
	return;
    }
  }

  $fields{'attributes'} = CMU::WebInt::gParam($q, 'attributes') if ($fields{'attributes'} eq '');
  warn __FILE__ . ":" . __LINE__ . ": Comparing devices ($checkHash->{'newDevice'} to $checkHash->{'oldDevice'})\n" if ($debug >= 4);
  $fields{'attributes'} = '' if ($checkHash->{'newDevice'} != $checkHash->{'oldDevice'});

  if ((CMU::WebInt::gParam($q, 'force')) && ($ul >= 9) ) {
    $fields{'status'} = CMU::WebInt::gParam($q, 'status');
    warn __FILE__ . ":" . __LINE__ . ": status being set to $fields{'status'}\n" if ($debug >= 2);
    delete $fields{'status'} if (($fields{'status'} ne 'enabled') && ($fields{'status'} ne 'partitioned'));
    $fields{'force'} = 'yes';
  }
  warn __FILE__ . ":" . __LINE__ . ": Calling modify_outlet with arguments\n" .
    Data::Dumper->Dump([$id, $version, \%fields, $ul],[qw(id version fields ul)]) . "\n" if ($debug >= 4);
  ($res, $field) = CMU::Netdb::modify_outlet($dbh, $user, $id, $version, \%fields, $ul);
  if ($res >= 1) {
#     if ($primarysubnet != $oldps) {
#       my %psfields;
#       $psfields{'outlet'} = $id;
#       $psfields{'vlan'} = $primarysubnet;
#       $psfields{'type'} = 'primary';
#       $psfields{'trunk_type'} = 'none';
#       $psfields{'status'} = 'request';
#       my $smid = gParam($q, 'smid') if ($oldps != -1);
#       my $smver = gParam($q, 'smver') if ($oldps != -1);
 
#       if ($oldps != -1 && $oldps ne '') {
# 	if ($primarysubnet == -1) {
# 	  $psfields{'vlan'} = $oldps;
# 	  $psfields{'status'} = 'delete';
# 	}
# 	($res, $field) = CMU::Netdb::modify_outlet_vlan_membership($dbh, $user, $smid, $smver, \%psfields);
#       } else {
# 	($res, $field) = CMU::Netdb::add_outlet_vlan_membership($dbh, $user, \%psfields) if ($defvlan eq '');
#       }
	  
#       if ($res >= 1) {
#         # Call only if (primaryvlan != oldvlan && newdev != olddev) || newdev != olddev
# 	    if ( ($primarysubnet != $oldps && $fields{'device'} != CMU::WebInt::gParam($q,'oldd')) 
# 		    || $fields{'device'} != CMU::WebInt::gParam($q,'oldd')) {
# 		CMU::Netdb::update_auxvlan($dbh, $user, $checkHash);
# 	    }
# 	$error{msg} = "Outlet information has been updated. With new VLAN: $primarysubnet";
#       } else {
# 	$error{msg} .= "  Unable to update network subnet mapping: ".$errmeanings{$res}."\n";
# 	$error{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr." )" 
# 	  if ($res eq $CMU::Netdb::errcodes{EDB});
# 	$error{type} = 'ERR';
# 	$error{loc} = 'outlets_update';
# 	$error{code} = $res;
# 	$error{fields} = join(',', @$field);
#       } 
#     } else {
      $error{msg} = "Outlet information has been updated.";
#    }
  } else {
    $error{msg} = "Error updating outlet information: " . $errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{msg} .= "[".join(',', @$field)."]";
    $error{type} = 'ERR';
    $error{loc} = 'outlets_update';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
    map { $error{$_} = 1 if ($_ ne 'type'); $error{otype} = 1 if ($_ eq 'type')} @$field;
  }

  # Set port-speed and port-duplex attributes, if necessary.
  if ($speed) {
    my $spec = CMU::Netdb::list_attribute_spec_ref($dbh, $user, "attribute_spec.name = 'port-speed' AND attribute_spec.scope = 'outlet'", 'attribute_spec.name');
    if (!ref $spec) {
      $speed = 'error';
    } elsif (!scalar keys(%$spec)) {
      $speed = 'error';
    } else {
      my $specid;
      foreach (keys %$spec) {
	$specid = $_ if ($spec->{$_} eq 'port-speed');
      }
      if ($specid) {
	my ($res, $fields) = 	CMU::Netdb::set_attribute($dbh, $user, {'spec' => $specid,
									'data' => $speed,
									'owner_table' => 'outlet',
									'owner_tid' => $id});
	if ($res <= 0) {
	  map { $error{$_} = 1 } @$fields if ($res <= 0);
	  $error{'msg'} .= $errmeanings{$res};
	  $error{'msg'} .= " [$res] (".join(',', @$fields).") ";
	  $error{'msg'} .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." )"
	    if ($res == $CMU::Netdb::errcodes{EDB});
	  $error{type} = 'ERR';
	  $error{loc} = 'port-speed';
	  $error{code} = $res;
	  $error{fields} = join(',', @$fields);
	}
      } else {
	$speed = 'error'
      }
    }

    &CMU::WebInt::admin_mail('outlets.pm:outlets_update',  'WARNING',
		'Unable to find port-speed attribute.  Missing attribute_spec?', {});

  }

  if ($duplex) {
    my $spec = CMU::Netdb::list_attribute_spec_ref($dbh, $user, "attribute_spec.name = 'port-duplex' AND attribute_spec.scope = 'outlet'", 'attribute_spec.name');
    if (!ref $spec) {
      $duplex = 'error';
    } elsif (!scalar keys(%$spec)) {
      $duplex = 'error';
    } else {
      my $specid;
      foreach (keys %$spec) {
	$specid = $_ if ($spec->{$_} eq 'port-duplex');
      }
      if ($specid) {
	my ($res, $fields) = CMU::Netdb::set_attribute($dbh, $user, {'spec' => $specid,
								     'data' => $duplex,
								     'owner_table' => 'outlet',
								     'owner_tid' => $id});
	if ($res <= 0) {
	  map { $error{$_} = 1 } @$fields if ($res <= 0);
	  $error{'msg'} .= $errmeanings{$res};
	  $error{'msg'} .= " [$res] (".join(',', @$fields).") ";
	  $error{'msg'} .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." )"
	    if ($res == $CMU::Netdb::errcodes{EDB});
	  $error{type} = 'ERR';
	  $error{loc} = 'port-duplex';
	  $error{code} = $res;
	  $error{fields} = join(',', @$fields);
	}
      } else {
	$duplex = 'error'
      }
    }

    &CMU::WebInt::admin_mail('outlets.pm:outlets_update',  'WARNING',
		'Unable to find port-duplex attribute.  Missing attribute_spec?', {});

  }

  $dbh->disconnect();
  CMU::WebInt::outlets_info($q, \%error);
}

sub outlets_reg_s0 {
  my ($q, $errors) = @_;
  my ($dbh);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('outlets_reg_s0');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Registration", $errors);
  &CMU::WebInt::title("Register a New Outlet");

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  my $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($verbose) {
    print "<hr>".$CMU::WebInt::vars::htext{'outlet.reg0_select'}."<br>";
  }else{
    print "<hr>Choose a method for selecting this outlet.<br>\n";
  }

  print "
<form method=get>
<input type=hidden name=op value=outlets_reg_s1>
<input type=hidden name=bmvm value=$verbose>";

  print &CMU::WebInt::subHeading("Select the Building", CMU::WebInt::pageHelpLink('building'));

  my %buildings = %{CMU::Netdb::list_buildings_ref($dbh, $user, '')};
  my @bk = sort {$buildings{$a} cmp $buildings{$b}} keys %buildings;
  if ($#bk > -1) {
    print "<table border=0 width=620><tr><td width=150><b>
<font face=\"Arial,Helvetica,Geneva,Charter\"><b>".
  CMU::WebInt::inlineHelpLink('building').
    "Building:</a></b></font></td>
<td width=350>".
  $q->popup_menu(-name => 'bldg', -accesskey => 'b',
		 -values => \@bk,
		 -labels => \%buildings);
  }else{
    print "System Error: No buildings available.\n";
    &CMU::WebInt::admin_mail('outlets.pm:outlets_reg_s0', 'WARNING',
		'No buildings available.', {});
  }
  print "</td><td align=right><input type=submit name=buildingNEXT value=\"Continue\"></td></tr></table>";

  print "<br><table border=0 width=100%><tr bgcolor=#a3ffa3><td><center>".
    "<font size=+1><b><i>-or-</i></b></font></center></td></tr></table>\n";
  print &CMU::WebInt::subHeading("Search by Label", CMU::WebInt::pageHelpLink('label'));
  print "<table border=0 width=620><tr><td width=150><b>
<font face=\"Arial,Helvetica,Geneva,Charter\"><b>".CMU::WebInt::inlineHelpLink('label_from').
"Label From:</a></b></font></td><td width=350>".
  $q->textfield(-name => 'from', -accesskey => 'l')."</td></tr>
<tr><td width=150><b><font face=\"Arial,Helvetica,Geneva,Charter\"><b>".CMU::WebInt::inlineHelpLink('label_to').
  "Label To:</a></b></font></td><td width=350>".
    $q->textfield(-name => 'to', -accesskey => 'l')."</td><td align=right><input type=submit name=labelNEXT value=\"Continue\"></td></tr></table>";

  $dbh->disconnect();
  print CMU::WebInt::stdftr($q);
}

sub outlets_reg_s1 {
  my ($q, $err) = @_;
  if (CMU::WebInt::gParam($q, 'labelNEXT') ne '') {
    outlets_reg_s1_tofrom($q, $err);
  }else{
    outlets_reg_s1_building($q, $err);
  }
}

sub outlets_reg_s1_tofrom {
  my ($q, $errors) = @_;
  my ($dbh, $url, $to, $from);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};

  ($to, $from) = (CMU::WebInt::gParam($q, 'to'), CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'from')));
  
  CMU::WebInt::setHelpFile('outlets_reg_s1_tofrom');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Registration", $errors);
  &CMU::WebInt::title("Register a New Outlet");

  print CMU::WebInt::errorDialog($url, $errors);
  
  print &CMU::WebInt::subHeading("Select an Outlet", CMU::WebInt::pageHelpLink(''));

  my $start = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'start'));
  $start = 0 if ($start eq '');

  my @whc;
  push(@whc, "cable.destination = 'OUTLET'");
  push(@whc, "FIND_IN_SET(cable.type, MAKE_SET(1|2|4|8, 'CAT5', 'CAT6', 'TYPE1', 'TYPE2'))");
  push(@whc, "cable.label_from like '%$from%'") if ($from ne '');
  push(@whc, "cable.label_to like '%$to%'") if ($to ne '');

  my $sref = CMU::Netdb::list_cables_outlets
    ($dbh, $user, join(' AND ', @whc).
     CMU::Netdb::verify_limit($start,
			      $DEF_ITEMS_PER_PAGE));

  my $nks = -1;
  my (@outlets, @ks);
  if (ref $sref) {
    @outlets = @$sref;
    $nks = @outlets;
  }
  if ($nks < 1) {
    # no outlets available 
    print "No outlets available!\n";
    print &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<table>\n";
  shift(@outlets);
  my $total = $start;
  $total = $start+$DEF_ITEMS_PER_PAGE+1 if ($nks >= $CMU::WebInt::vars::DEF_ITEMS_PER_PAGE);
  print CMU::WebInt::pager_Top($start, $total, $DEF_ITEMS_PER_PAGE, 
		  0, $url, "op=outlets_reg_s1&to=$to&from=$from&labelNEXT=1", 'start');
 
  my $res = CMU::WebInt::generic_tprint($url, $sref, 
			   ['cable.to_room_number', 'cable.id', 'cable.label_from',
			    'cable.label_to'],
			   [\&CMU::WebInt::outlets::outlet_cb_activate], '', 
			   'op=outlets_reg_s1&to=$to&from=$from&labelNEXT=1',
			   '', \%outlet_cable_pos, 
			   \%outlet_cable_printable,
			   '', '', '', []);
			 
  $dbh->disconnect();
  print CMU::WebInt::stdftr($q);
}

sub outlets_reg_s1_building {
  my ($q, $errors) = @_;
  my ($dbh, $url, $bldg, %errors);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  $bldg = CMU::WebInt::gParam($q, 'bldg');

  CMU::WebInt::setHelpFile('outlets_reg_s1_building');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Registration", $errors);
  &CMU::WebInt::title("Register a New Outlet");

  print CMU::WebInt::errorDialog($url, $errors);

  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, "building.building = '$bldg'");
  if (!ref $bref || !defined $$bref{$bldg}) {
    print "Error loading building information.\n";
    $dbh->disconnect();
    print &CMU::WebInt::stdftr($q);
    return;
  }
  
  print &CMU::WebInt::subHeading("Select a Cable in $$bref{$bldg}", CMU::WebInt::pageHelpLink(''));
  my $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'cable.to_room_number' if ($sort eq '');

  my $start = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'start'));
  $start = 0 if ($start eq '');
  
  my $sref = list_cables_outlets
    ($dbh, $user, " cable.destination = 'OUTLET' AND ".
     "cable.to_building = '$bldg' AND ".
     "FIND_IN_SET(cable.type, MAKE_SET(1|2|4|8, 'CAT5', 'CAT6', 'TYPE1', 'TYPE2')) ".
     CMU::Netdb::verify_orderby($sort).
     CMU::Netdb::verify_limit($start, 
			      $DEF_ITEMS_PER_PAGE));

  my $nks = -1;
  my (@outlets, @ks);
  if (ref $sref) {
    @outlets = @$sref;
    $nks = @outlets;
  }
  if ($nks < 1) {
    &CMU::WebInt::admin_mail('outlets.pm:outlets_reg_s1_building', 'WARNING',
		'Unable to find any outlets in building.', 
		{'cable.to_building' => $bldg});
    print "No outlets available!\n";
    print &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<table>\n";
  shift(@outlets);
  my $total = $start;
  $total = $start+$DEF_ITEMS_PER_PAGE+1 if ($nks >= $CMU::WebInt::vars::DEF_ITEMS_PER_PAGE);
  
  print CMU::WebInt::pager_Top($start, $total, $DEF_ITEMS_PER_PAGE, 
		  0, $url, "op=outlets_reg_s1&where=bldg&bldg=$bldg", 'start');
  my $res = CMU::WebInt::generic_tprint($url, $sref, 
			   ['cable.to_room_number', 'cable.label_from',
			    'cable.label_to'],
			   [\&CMU::WebInt::outlets::outlet_cb_activate], '', 
			   "outlets_reg_s1&bldg=$bldg&where=bldg",
			   '', \%outlet_cable_pos, 
			   \%outlet_cable_printable,
			   '', '', 'sort', 
					['cable.to_room_number', 
					 'cable.label_from', 'cable.label_to',
					 'outlet.flags']);
			 
  $dbh->disconnect();
  print CMU::WebInt::stdftr($q);
}

sub outlets_reg_s2 {
  my ($q, $errors) = @_;
  my ($dbh, $url, $bldg, %errors, $id, @order);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  $id = CMU::WebInt::gParam($q, 'id');
  my $deptAll = CMU::WebInt::gParam($q, 'deptAll');
  $deptAll = 1 if ($deptAll eq 'View Complete List');
  $deptAll = 0 if ($deptAll eq '');

  CMU::WebInt::setHelpFile('outlets_reg_s2');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Registration", $errors);
  &CMU::WebInt::title("Register a New Outlet");

  print CMU::WebInt::errorDialog($url, $errors);
  my ($ul) = CMU::Netdb::get_add_level($dbh, $user, 'outlet', 0);

  if ($ul < 1) {
    CMU::WebInt::accessDenied('outlet', 'ADD', 0, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $or = CMU::Netdb::list_outlets($dbh, 'netreg', "outlet.cable = '$id' AND
FIND_IN_SET('permanent', outlet.flags)");
  if (!ref $or) {
    print "Unable to query outlets: ".$errmeanings{$or}."\n";
    print " (Database: ".$CMU::Netdb::primitives::db_errstr." )" 
      if ($or eq $CMU::Netdb::errcodes{EDB});
    $dbh->disconnect();
    print &CMU::WebInt::stdftr($q);
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  my $ors = @$or;
  # ors < 2 :: outlet not there
  # ors = 2 :: outlet there
  if ($ors == 2 && $ul < 9) {
    print "<br>".&CMU::WebInt::subHeading("Pre-Connected Outlet");
    print "<form>
<input type=hidden name=op value=outlets_reg>
<input type=hidden name=format value=0>
<input type=hidden name=id value=$id>
<input type=hidden name=cable value=$id>
<input type=hidden name=type value=permanent>
<input type=hidden name=IDtype0 value=1>
<input type=hidden name=read0 value=1>
<input type=hidden name=write0 value=1>
<input type=hidden name=ID0 value=$user>
";
    print "<table width=610 border=0><tr><td>
<font face=\"Arial,Helvetica,Geneva,Charter\">
This outlet is pre-connected. Please select your department and 
click \"Activate\" to confirm activation.<br><br></td></tr>\n";
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
    @order = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;
    
    print "<tr><td colspan=2>".
      CMU::WebInt::printVerbose('machine.department', $verbose).
	$q->popup_menu(-name => 'dept',
		       -values => \@order,
		       -default => 'dept:undergraduate',
		       -labels => $depts)." $dtitle </td></tr>\n";
    
    print "</table>";
    
    print "<input type=submit value=\"Activate\">\n";
    print &stdftr;
    $dbh->disconnect();
    return;
  }elsif($ors > 2) {
    &CMU::WebInt::admin_mail('outlets.pm:outlets_reg_s2', 'WARNING',
		'Multiple outlets found.', 
		{'outlet.cable' => $id});
    print "Error: Multiple outlets found.\n";
    $dbh->disconnect();
    print &stdftr;
    return;
  }

  # type
  print "<form method=get><input type=hidden name=cable value=$id>
<input type=hidden name=id value=$id>";

  print "<input type=hidden name=op value=outlets_reg>";

  print &CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  print "<table><tr>".
    CMU::WebInt::printPossError(defined $errors{type}, $outlet_printable{'outlet.type'}, 1, 'outlet.type').
      "</tr>";

  # outlet type
  if ($ors < 2) {
    my $otr = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'GET', '');
    if (!ref $otr) {
      print "Error in outlet_types_ref.\n";
      &CMU::WebInt::admin_mail('outlets.pm:outlets_reg_s2', 'WARNING',
		'Error calling list_outlet_types_ref (1).', {});
      $dbh->disconnect();
      print &stdftr;
      return;
    }
    my @kot = sort {$$otr{$a} cmp $$otr{b}} keys %$otr;
    print "<tr><td>".CMU::WebInt::printVerbose('outlet.type', $verbose).
      $q->popup_menu(-name => 'type', -accesskey => 't',
		     -values => \@kot,
		     -labels => $otr)."</td></tr>\n";
  }else{
    my $otr = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'LIST', '');
    if (!ref $otr) {
      print "Error in outlet_types_ref.\n";
       &CMU::WebInt::admin_mail('outlets.pm:outlets_reg_s2', 'WARNING',
		'Error calling list_outlet_types_ref (2).', {});
      $dbh->disconnect();
      print &stdftr;
      return;
    }
    print "<tr><td>".CMU::WebInt::printVerbose('outlet.type', $verbose).
      $$otr{$or->[1]->[$outlet_pos{'outlet.type'}]}."</td></tr>\n";
  }

  # basic attached cable information
  my $cref = CMU::Netdb::list_cables($dbh, $user, "cable.id=$id");
  my @cdata = @{$cref->[1]};
  
  # This should be done to get building.id instead of building.building..... for Devices..
  my $bldgnum = ($cdata[$cable_pos{'cable.to_building'}] ne '' ? $cdata[$cable_pos{'cable.to_building'}]:$cdata[$cable_pos{'cable.from_building'}]);
  my $dref = CMU::Netdb::list_buildings($dbh, $user, "building.building=\"$bldgnum\"");
  if ($#$dref == 0) {
      print "<b>Error getting building($bldgnum) information</b><br>\n";
      &CMU::WebInt::admin_mail('outlets.pm:outlets_reg_s2', 'FATAL',
			    'Error getting building information, as building number does not exist',{});
      $dbh->disconnect();
      print &stdftr;
      return;
  }
  my @ddata = @{$dref->[1]};
  my $bldg_id = $ddata[$CMU::WebInt::buildings::building_pos{'building.id'}];
 
  my $sref = CMU::Netdb::list_trunkset_building_presence($dbh, $user, "trunkset_building_presence.buildings = \'$bldg_id\'");
  my (%trunkset, @ts, $nks);
  if (ref $sref) {
	%trunkset = %$sref;
	@ts = sort { $trunkset{$a} cmp $trunkset{$b} } keys %trunkset;
	$nks = keys %trunkset;
  }
 
  if ($ul >= 9) {
    # device, port
    my (@dev_arr, %devs);
    foreach my $ts_id (@ts) {
	$sref = CMU::Netdb::list_trunkset_device_presence($dbh, $user, "trunkset_machine_presence.trunk_set = \'$ts_id\'");
	my (@devA, %devs_local);
	my $ndks = -1;
	if (ref $sref) {
	    %devs_local = %$sref;
	    @devA = sort { $devs_local{$a} cmp $devs_local{$b} } keys %devs_local;
	    $ndks = keys %devs_local;
	    map { $devs{$_} = $devs_local{$_} } keys %devs_local;
	}
    }

    @dev_arr = sort { $devs{$a} cmp $devs{$b} } keys %devs;

    $devs{0} = "--Select Device--";
    unshift @dev_arr, 0;
    print "<tr>".CMU::WebInt::printPossError(defined $errors{device}, $outlet_printable{'outlet.device'}, 1, 'outlet.device').
      CMU::WebInt::printPossError(defined $errors{port}, $outlet_printable{'outlet.port'}, 1, 'outlet.port').
	"</tr>";
    print "<tr><td>".CMU::WebInt::printVerbose('outlet.device', $verbose).
	  $q->popup_menu(-name => 'device', 
		     -values => \@dev_arr,
		     -labels => \%devs,
		     -default => -1)."</td><td>".
	  CMU::WebInt::printVerbose('outlet.port', $verbose).
          $q->textfield(-name => 'port', -accesskey => 'p')."</td></tr>\n";

    # flags, comment_lvl9
    my @curflags = split (/\,/, $or->[1]->[$outlet_pos{'outlet.flags'}]);
    print "<tr>".CMU::WebInt::printPossError(defined $errors{flags}, $outlet_printable{'outlet.flags'}, 1, 'outlet.flags').
	CMU::WebInt::printPossError($errors{comment_lvl9}, $outlet_printable{'outlet.comment_lvl9'}, 1, 'outlet.comment_lvl9').
	"</tr>";
    print "<tr><td>".CMU::WebInt::printVerbose('outlet.flags', $verbose).
      $q->checkbox_group(-name => 'flags', 
			 -defaults => \@curflags,
			 -values => \@outlet_flags,
			 -linebreak => 'yes') .
			 "</td><td>".
			 CMU::WebInt::printVerbose('outlet.comment_lvl9', $verbose).
			 $q->textfield(-name => 'comment_lvl9', -accesskey => 'a').
			 "</td></tr>\n";
  }

  # Presenting VLANS to user: Bldg-->TrunkSet-->VLANs
  # First list all the vlans ids from all trunksets. M1
  # XXX: Instead of doing this, copy protections from vlan to trunkset_vlan_presence.
  my (@vlan_arr, %vlans);
  foreach my $ts_id (@ts) {
	$sref = CMU::Netdb::list_trunkset_vlan_presence($dbh, $user, "trunkset_vlan_presence.trunk_set = \'$ts_id\'");
	my $nvks = -1;
	my (%vlan_local, @vlan);
	if (ref $sref) {
	    %vlan_local = %$sref;
	    @vlan = sort { $vlan_local{$a} cmp $vlan_local{$b} } keys %vlan_local;
	    $nvks = keys %vlan_local;
	    map { $vlans{$_} = $vlan_local{$_}} keys %vlan_local;
	    map {push(@vlan_arr, $_)} @vlan;
	}
  }

  foreach my $v_id (@vlan_arr) {
      $sref = CMU::Netdb::get_vlan_ref($dbh, $user, "vlan.id = $v_id", 'vlan.name');
      delete $vlans{$v_id} if (!ref $sref || !defined $sref->{$v_id}); 
  }

  my $pref = \%vlans;
  if (!ref $pref) {
    print "Error getting subnets list: ".$errmeanings{$pref}."\n";
    print "  (Database: ".$CMU::Netdb::primitives::db_errstr." )"
      #if ($pref eq $CMU::Netdb::errcodes{EDB});
      if ($sref eq $CMU::Netdb::errcodes{EDB});
    print &CMU::WebInt::stdftr($q);
    return;
  }

  @order = sort { $pref->{$a} cmp $pref->{$b} } keys %$pref;
  my $defvlan;
  if ($#order > 0) {
    $pref->{0} = '--Unspecified--';
    unshift @order , 0;
    $defvlan = 0;
  } else {
      $defvlan = $order[0];
  }
  print "<tr>".CMU::WebInt::printPossError(defined $$errors{'subnet'}, "Network Segment", 2, 'outlet.subnet', "")."</tr><tr>
<td colspan=2>".CMU::WebInt::printVerbose('outlet.subnet', $verbose);
  
  print $q->popup_menu(-name => 'primarysubnet', -accesskey => 'n',
		       -values => \@order,
		       -default => $defvlan,
		       -labels => $pref);
  print "</td></tr>\n\n";


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
  @order = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;
  
  print "<tr><td colspan=2>".
    CMU::WebInt::printVerbose('machine.department', $verbose).
      $q->popup_menu(-name => 'dept', -accesskey => 'a',
		     -values => \@order,
		     -dept => 'dept:undergraduate',
		     -labels => $depts)." $dtitle </td></tr>\n";

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
<input type=hidden name=level0 value=1>
";
    if (defined $errors{user_perms}) {
      print "ERROR! With protections<br>";
      &CMU::WebInt::admin_mail('outlets.pm:outlets_reg_s2', 'WARNING',
		'Generating an error with permissions we specify.', {});
    }
  }else{
    print "<br>".CMU::WebInt::subHeading("Protections", CMU::WebInt::pageHelpLink(''));
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
  print "</table>\n";
  }

  print "<input type=submit value=\"Activate Outlet\">\n";
  if ($ul >= 9) {
    print $q->submit(-name=>'force', -value=>'Force Activate Outlet (Database Only)') . "\n";
  }
  print "</form>\n";

  print &CMU::WebInt::stdftr($q);
  print $dbh->disconnect();
}

sub outlet_cb_activate {
  my ($url, $row, $edata) = @_;
  return "Activate" if (!ref $row);
  my @rrow = @$row;
  if ($rrow[$outlet_cable_pos{'outlet.cable'}] eq '' ||
      ($rrow[$outlet_cable_pos{'outlet.flags'}] =~ /permanent/ &&
       $rrow[$outlet_cable_pos{'outlet.flags'}] !~ /activated/)) {
    return "<a href=$url?op=outlets_reg_s2&id=".
      $rrow[$outlet_cable_pos{'cable.id'}].">Activate</a>";
  }
  return "Already Activated";
}

sub outlets_register {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);
  my ($netsegment, $checkHash,$odev, $dref, $tref, @ts, %trunkset, @devArr);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'outlet', 0);

  if (CMU::WebInt::gParam($q, 'deptAll') eq 'View Complete List') {
    CMU::WebInt::outlets_reg_s2($q, $errors);
    return;
  }

  $netsegment 	= CMU::WebInt::gParam($q, 'primarysubnet');
  $odev		= CMU::WebInt::gParam($q, 'device');
  if ($netsegment == 0) {
      $errors->{type} = 'ERR';
      $errors->{msg} = $errmeanings{$CMU::Netdb::errcodes{ENONETSEGMENT}};
      $errors->{code} = $CMU::Netdb::errcodes{ENONETSEGMENT};
      $errors->{loc} = 'outlet_register';
      CMU::WebInt::outlets_reg_s2($q, $errors);
      return;
  }

  # Generate hash
  $checkHash->{'newDevice'} 	= CMU::WebInt::gParam($q, 'device');
  $checkHash->{'newPort'} 	= CMU::WebInt::gParam($q, 'port');
  $checkHash->{'oldDevice'} 	= 0;
  $checkHash->{'oldPort'} 	= 0;
  $checkHash->{'newVlan'} 	= $netsegment;
  $checkHash->{'userlevel'} 	= $userlevel;
  $checkHash->{'qt'} 		= '';

  my ($res, $field) = CMU::Netdb::check_devnet_mapping($dbh, $user, $checkHash);
  if ($res < 0) {
    $errors->{type} = 'ERR';
    $errors->{msg} = $errmeanings{$res};
    $errors->{code} = $res;
    $errors->{loc} = 'outlet_register';
    $errors->{fields} = join(',', @$field);
    CMU::WebInt::outlets_reg_s2($q, $errors);
    return;
  }

  if ($userlevel >= 9) {
  # Level 9 fields
    foreach (qw/type cable comment_lvl9 device port dept/) {
      $fields{$_} = CMU::WebInt::gParam($q, $_);
    }
    $fields{'flags'} = join(',', CMU::WebInt::gParam($q, 'flags'));
  }elsif($userlevel >= 1) {
    # Level 1 fields
    %fields = ('type' => CMU::WebInt::gParam($q, 'type'),
	       'cable' => CMU::WebInt::gParam($q, 'cable'),
	       'dept' => CMU::WebInt::gParam($q, 'dept'));
    delete $fields{'type'} if ($fields{'type'} eq "permanent");
  }else{
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets", $errors);
    &CMU::WebInt::title("Add Outlet");
    CMU::WebInt::accessDenied('outlet', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  warn __FILE__, ':', __LINE__, ' :>'.
    "CABLE:: $fields{'cable'}\n" if ($debug >= 2);
  my @permIDs = grep (/IDtype/, $q->param());
  my %perms;
  foreach(@permIDs) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "IDtype: $_\n" if ($debug >= 2);
    /IDtype(\d+)/;
    my $accum .= "READ," if (CMU::WebInt::gParam($q, "read$1") eq '1');
    $accum .= "WRITE," if (CMU::WebInt::gParam($q, "write$1") eq '1');
    my $nlevel = CMU::WebInt::gParam($q, "level$1");
    $nlevel = $userlevel if ($nlevel > $userlevel || $nlevel eq '');
    chop($accum);
    warn __FILE__, ':', __LINE__, ' :>'.
      "accum: $accum\n" if ($debug >= 2);
    next if ($accum eq '');
    $perms{CMU::WebInt::gParam($q, "ID$1")} = [$accum, $nlevel];
  }

  $fields{'vlan'} = $netsegment;
  
  if ((CMU::WebInt::gParam($q, 'force')) && ($userlevel >= 9) ) {
    $fields{'force'} = 'yes';
  }

  my ($ares, $errfields) = CMU::Netdb::add_outlet($dbh, $user, $userlevel, \%fields, \%perms);

  if ($ares > 0) {
    my %warns = %$errfields;
    warn __FILE__."::".__LINE__." > Added outlet: $warns{ID} and device = $fields{'device'}\n";
    $q->param('oid', $warns{ID});
    my $subnet = CMU::WebInt::gParam($q, "primarysubnet");
    if ($subnet != -1 && ($fields{'device'} eq '' || $fields{'device'} == 0 ) ) {
      my %psfields = ('outlet' => $warns{ID},
		      'vlan' => $subnet,
		      'type' => 'primary',
		      'trunk_type' => 'none',
		      'status' => 'request',
		     );
      warn __FILE__, ':', __LINE__, ' :>'.
	"outlet/subnet: $psfields{outlet}/$psfields{vlan}" if ($debug >= 2);
      warn __FILE__, ':', __LINE__, ' :>'.
	"outlet/subnet: $psfields{outlet}/$psfields{vlan}" ;
      my ($res, $field) = CMU::Netdb::add_outlet_vlan_membership($dbh, $user, \%psfields);
      if ($res >= 1) {
	$nerrors{'msg'} = "Added outlet.";
      } else {
	$nerrors{msg} .= "Added outlet, but was unable to update network vlan mapping: ".$errmeanings{$res}."\n";
	$nerrors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr." )" 
	  if ($res eq $CMU::Netdb::errcodes{EDB});
	$nerrors{type} = 'ERR';
	$nerrors{loc} = 'outlets_register';
	$nerrors{code} = $res;
	$nerrors{fields} = join(',', @$field);
      } 
    } else { 
      $nerrors{'msg'} = "Added outlet.";
    }
    
    $dbh->disconnect(); # we use this for the insertid ..
    CMU::WebInt::mach_list($q, \%nerrors);
  }else{
    if ($res <= 0) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database error: ".$CMU::Netdb::primitives::db_errstr." )" if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'outlets_register';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    &CMU::WebInt::outlets_reg_s2($q, \%nerrors);
  }
}

sub outlet_search {
  my ($q, $errors) = @_;
  my ($dbh, $url, $bldg, %errors, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $id = CMU::WebInt::gParam($q, 'id');

  CMU::WebInt::setHelpFile('outlets_search');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Search", $errors);
  &CMU::WebInt::title("Search Your Outlets");

  my $OutletLevel = CMU::Netdb::get_read_level($dbh, $user, 'outlet', 0);

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  CMU::WebInt::printVerbose('machine.search_general', 1);
  
  print &CMU::WebInt::subHeading("Basic Search Parameters", CMU::WebInt::pageHelpLink(''));
  print "<br>You may only search outlets which are already registered, and are registered to you, or to a department you administer.  To search for an outlet you wish to register, visit <b><a href=$url?op=outlets_reg_s0>Register New Outlet</a></b><br>
The percent sign ('\%') can be used as a wildcard (match anything) operator.
<br><form method=get>\n
<input type=hidden name=op value=outlets_s_exec
<table border=1>";

  my ($gmcvres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'THCOLOR');

  # type
  {
    my $sbn = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'LIST', '');
    if (ref $sbn) {
      print "<tr>".CMU::WebInt::printPossError(0, $outlet_printable{'outlet.type'}, 1, 'outlet.type')."<td>";
      my @sbk = sort { $$sbn{$a} cmp $$sbn{$b} } keys %$sbn;
      unshift(@sbk, '--select--');
      print $q->popup_menu(-name => 'type', -accesskey => 't',
			   -values => \@sbk,
			   -labels => $sbn);
      print "</td></tr>\n";
    }else{
      print "<tr><td colspan=2>[Error loading types.]</td></tr>\n";
      &CMU::WebInt::admin_mail('outlets.pm:outlet_search', 'WARNING',
		'Error loading types (list_outlet_types_ref).', {});
    }
  }

  # from
  print "<tr>".CMU::WebInt::printPossError(0, $outlet_cable_printable{'cable.label_from'}, 1, 'cable.label_from')."<td>".$q->textfield(-name => 'label_from', -accesskey => 'f')."</td></tr>";

  # to
  print "<tr>".CMU::WebInt::printPossError(0, $outlet_cable_printable{'cable.label_to'}, 1, 'cable.label_to')."<td>".$q->textfield(-name => 'label_to', -accesskey => 't')."</td></tr>";

  # cable
  print "<tr>".CMU::WebInt::printPossError(0, $outlet_printable{'outlet.cable'}, 1, 'outlet.cable')."<td>".$q->textfield(-name => 'cable', -accesskey => 'c')."</td></tr>";

  # device
  print "<tr>".CMU::WebInt::printPossError(0, $outlet_printable{'outlet.device'}, 1, 'outlet.device')."<td>".$q->textfield(-name => 'device', -accesskey => 'd')."</td></tr>";

  # port
  print "<tr>".CMU::WebInt::printPossError(0, $outlet_printable{'outlet.port'}, 1, 'outlet.port')."<td>".$q->textfield(-name => 'port', -accesskey => 'p')."</td></tr>";

  # attributes
  {
    my @attr = @outlet_attributes;
    unshift(@attr, '--select--');
    print "<tr>".CMU::WebInt::printPossError(0, $outlet_printable{'outlet.attributes'}, 1, 'outlet.attributes').
      "</td><td>".$q->popup_menu(-name => 'attributes', -accesskey => 'a',
				 -values => \@attr)."</td></tr>";
  }
  
  # flags
  if ($OutletLevel >= 9) {
    my @flags = @CMU::Netdb::structure::outlet_flags;
    print "<tr>".CMU::WebInt::printPossError(0, $CMU::Netdb::structure::outlet_printable{'outlet.flags'}, 1, 'flags')."</td><td>";
    my @prItems;
    my @vals = qw/Ignore Unset Set/;

    my $tick = 0;
    foreach(@flags) {
      push(@prItems, "<b>".ucfirst($_)."</b>: ".$q->popup_menu(-name => "flag_$_",
						  -values => \@vals, -accesskey => 'f',
						  -default => 'Ignore'));
      $tick++;
      push(@prItems, "<br>") if ($tick % 3 == 0);
    }
    print join(" &nbsp;&nbsp; \n", @prItems);

    print "</td></tr>\n";
  }

  # status
  {
    my @status = @outlet_status;
    unshift(@status, '--select--');
    print "<tr>".CMU::WebInt::printPossError(0, $outlet_printable{'outlet.status'}, 1, 'outlet.status').
      "</td><td>".$q->popup_menu(-name => 'status', -accesskey => 's',
				 -values => \@status)."</td></tr>";
  }

  print "</table>";

  print "<br>".&CMU::WebInt::subHeading("Users/Groups", CMU::WebInt::pageHelpLink('usersgroups'));
  
  print "<table border=1>";

 my $ugdValueHash = {'USER'  => '', 'GROUP' => '', 'DEPT'  =>''};
  my $ugdAccessKeysHash = {'USER' => { 'accesskey' => 'u' }, 'GROUP' => { 'accesskey' => 'g' }, 'DEPT'  => { 'accesskey' => 'd' } };

  my @ugdValues = qw/USER GROUP DEPT/;
  my @ugdFields = $q->radio_group(-name=>'ugtype',-values=>\@ugdValues,-labels=>$ugdValueHash,-attributes=>$ugdAccessKeysHash);

  # users
 print "<tr><td bgcolor=$THCOLOR>" . $ugdFields[0] . CMU::WebInt::tableHeading('User ID')."</td><td>".
    $q->textfield(-name => 'uid', -accesskey => 'u');

        CMU::WebInt::drawUserRealmPopup($q,"uidrealm","r");

        print "</td></tr>\n";

  # groups
  print "<tr><td bgcolor=$THCOLOR>" . $ugdFields[1] . CMU::WebInt::tableHeading('Group ID')."</td><td>".
    $q->textfield(-name => 'gid', -accesskey => 'g')."</td></tr>\n";

  # departments
  print "<tr><td bgcolor=$THCOLOR>" . $ugdFields[2] .CMU::WebInt::tableHeading('Affiliation')."</td><td>";
  my $depts = CMU::Netdb::get_departments($dbh, $user, '', 'ALL', '', 'groups.description', 'LIST');
  $$depts{'--select--'} = '--select--';
  my @dk = sort { $$depts{$a} cmp $$depts{$b} } keys %$depts;
  print $q->popup_menu(-name => 'dept', -accesskey => 'a',
		      -values => \@dk,
		      -labels => $depts)."</td></tr>\n";
  
  print "</table>\n";
  print "<input type=submit value=\"Search\"></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub outlet_s_exec {
  my ($q, $errors) = @_;
  my ($dbh, $url, $query, @q, $type);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('outlet_s_exec');
  $url = $ENV{SCRIPT_NAME};

  my @rurl;
  # type
  push(@q, 'type = \''.CMU::WebInt::gParam($q, 'type').'\'')
    if (CMU::WebInt::gParam($q, 'type') ne '' && CMU::WebInt::gParam($q, 'type') ne '--select--');

  # label_from
  if (CMU::WebInt::gParam($q, 'label_from') ne '') {
    if (CMU::WebInt::gParam($q, 'label_from') =~ /\%/) {
      push(@q, 'label_from like '.$dbh->quote(CMU::WebInt::gParam($q, 'label_from')));
    }else{
      push(@q, 'label_from like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'label_from').'%'));
    }
  }

  # label_to
  if (CMU::WebInt::gParam($q, 'label_to') ne '') {
    if (CMU::WebInt::gParam($q, 'label_to') =~ /\%/) {
      push(@q, 'label_to like '.$dbh->quote(CMU::WebInt::gParam($q, 'label_to')));
    }else{
      push(@q, 'label_to like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'label_to').'%'));
    }
  }

  # cable
  if (CMU::WebInt::gParam($q, 'cable') ne '') {
    if (CMU::WebInt::gParam($q, 'cable') =~ /\%/) {
      push(@q, 'cable like '.$dbh->quote(CMU::WebInt::gParam($q, 'cable')));
    }else{
      push(@q, 'cable like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'cable').'%'));
    }
  }

  # device
  if (CMU::WebInt::gParam($q, 'device') ne '') {
    if (CMU::WebInt::gParam($q, 'device') =~ /\%/) {
      push(@q, 'machine.host_name like '.$dbh->quote(CMU::WebInt::gParam($q, 'device')));
    }else{
      push(@q, 'machine.host_name like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'device').'%'));
    }
  }
 
  # port
  if (CMU::WebInt::gParam($q, 'port') ne '') {
    if (CMU::WebInt::gParam($q, 'port') =~ /\%/) {
      push(@q, 'port like '.$dbh->quote(CMU::WebInt::gParam($q, 'port')));
    }else{
      push(@q, 'port like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'port').'%'));
    }
  }

  # attributes
  push(@q, 'attributes = \''.CMU::WebInt::gParam($q, 'attributes').'\'')
    if (CMU::WebInt::gParam($q, 'attributes') ne '' && CMU::WebInt::gParam($q, 'attributes') ne '--select--');

  # flags
  foreach(@CMU::Netdb::structure::outlet_flags) {
    if (CMU::WebInt::gParam($q, "flag_$_") eq 'Set') {
      push(@q, "find_in_set('$_', flags)");
      push(@rurl, "flag_$_=".CMU::WebInt::gParam($q, "flag_$_"));
    }
    
    if (CMU::WebInt::gParam($q, "flag_$_") eq 'Unset') {
      push(@q, "not find_in_set('$_', flags)");
      push(@rurl, "flag_$_=".CMU::WebInt::gParam($q, "flag_$_"));
    }
  }

  # status
  push(@q, 'status = \''.CMU::WebInt::gParam($q, 'status').'\'')
    if (CMU::WebInt::gParam($q, 'status') ne '' && CMU::WebInt::gParam($q, 'status') ne '--select--');

  my $tdata;
  if (CMU::WebInt::gParam($q, 'ugtype') eq 'USER' && CMU::WebInt::gParam($q, 'uid') ne '') {
    # users
    $type = 'USER';
    $tdata = CMU::WebInt::gParam($q, 'uid');
        # this tries to figure out what the uidrealm is and if it was there or none, don't set the realm.
        my $uidrealm = CMU::WebInt::helper::gParam($q, 'uidrealm');
        if (($uidrealm ne '--none--') && ($uidrealm ne undef) && ($tdata ne undef)) { $tdata .= "@" . $uidrealm; }
  }elsif(CMU::WebInt::gParam($q, 'ugtype') eq 'GROUP' && CMU::WebInt::gParam($q, 'id') ne '') {
    # groups
    $type = 'GROUP';
    $tdata = CMU::WebInt::gParam($q, 'gid');
  }elsif(CMU::WebInt::gParam($q, 'ugtype') eq 'DEPT' && CMU::WebInt::gParam($q, 'dept') ne '--select--') {
    # departments
    $type = 'GROUP';
    $tdata = CMU::WebInt::gParam($q, 'dept');
  }else{
    $type = 'ALL';
    $tdata = '';
  }

  foreach(qw/label_from label_to type cable device port attributes flags status ugtype uid uidrealm id dept/) {
    push(@rurl, "$_=".CMU::WebInt::gParam($q, $_)) if (CMU::WebInt::gParam($q, $_) ne '' && CMU::WebInt::gParam($q, $_) ne '--select--');
  }

  ## WARNING: don't change this to OR unless you deal with the user/group
  ## join stuff that MUST be AND
  my $gwhere = join(' AND ', @q);
  $gwhere = '1' if ($gwhere eq '');

  my $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'outlet.id' if ($sort eq '');

  push(@rurl, "sort=$sort");
  my ($res, $code, $msg) = outlet_prn_search
    ($user, $dbh, $q, 
     $gwhere.
     CMU::Netdb::verify_orderby($sort),
     $url, join('&', @rurl), 'start', 'outlets_s_exec', $type, $tdata);
  
  if ($res != 1) {
    my %errors = ('type' => 'ERR',
		  'code' => $code,
		  'msg' => $msg,
		  'loc' => 'outlet_s_exec',
		  'fields' => '');
    outlet_search($q, \%errors);
    return;
  }
    
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# outlet_prn_search
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
sub outlet_prn_search {
  my ($user, $dbh, $q, $where, $url, $oData, $skey, $lmach, $type, $tdata) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $defitems = $DEF_ITEMS_PER_PAGE;

  my $prewhere = outlet_search_pre_where($dbh, $type, $tdata);
  $where = "$prewhere AND $where" if ($prewhere ne '');
  my $jointype = ' LEFT JOIN ';
  $jointype = ' JOIN ' if ($where =~ /machine/);
  my $join = 'outlet JOIN cable ON outlet.cable = cable.id ' .
    $jointype . 'trunkset_machine_presence ON outlet.device = trunkset_machine_presence.id ' .
      $jointype . 'machine ON machine.id = trunkset_machine_presence.device';
  warn "$join WHERE $where";
  $ctRow = CMU::Netdb::primitives::count($dbh, $user, $join,
					"$where ");
  $ruRef = CMU::Netdb::primitives::list($dbh, $user, $join,
					\@CMU::Netdb::structure::outlet_cable_host_fields,
					"$where ".
					CMU::Netdb::verify_limit($start, $defitems));
  return (0, $ruRef, "ERROR with list_outlets: ".$errmeanings{$ruRef}) if (!ref $ruRef);
  unshift @$ruRef, \@CMU::Netdb::structure::outlet_cable_host_fields;

  return (0, $CMU::Netdb::errcodes{ENOTFOUND}, "No results found.") if ($#$ruRef == 0);

  $lmach .= "&".$oData if ($oData ne '');
  if (ref $ctRow) {
    my $tmp = $ctRow->[0]; 
    $ctRow = $tmp;
  } else {
    $ctRow = 0 if ($ctRow < 0);
  }

  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets", {});
  &CMU::WebInt::title("Search Outlets");

  $url = $ENV{SCRIPT_NAME};
  print "<hr>";
  print &CMU::WebInt::subHeading("Search Results");

  print &CMU::WebInt::pager_Top($start, $ctRow, $defitems, 10,
		   $url, "op=".$lmach, $skey);

  $lmach =~ s/\&sort=[^\&]+//;
  $lmach =~ s/\&\&/\&/g;
  $lmach =~ s/\&$//;

  my $tref = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'LIST', '');
  return (0, $tref, "Error in list_outlet_types_ref: ".$errmeanings{$tref}) if (!ref $tref);

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($url, $ruRef, 
		 ['outlet.id', 'machine.host_name', 'outlet.port', 'outlet.attributes', 'outlet.flags', 'outlet.status'],
		 [\&CMU::WebInt::outlets::outlet_cb_type,
		 \&CMU::WebInt::outlets::outlet_cb_print_cable,
		 \&CMU::WebInt::outlets::outlet_cb_state],
		 $tref, $lmach,
		 'op=outlets_info&oid=',
		 \%outlet_cable_host_pos, \%outlet_cable_host_printable,
		 'outlet.id', 'outlet.id', 'sort',
			      ['outlet.id', 'machine.host_name', 'outlet.port', 
			       'outlet.attributes', 'outlet.flags', 'outlet.status',
			       'outlet.cable']);
  
  return 1;
}

sub outlet_cb_print_cable {
  my ($url, $row, $edata) = @_;
  return $CMU::Netdb::structure::outlet_cable_printable{'cable.label_from'}.
    "/".$CMU::Netdb::structure::outlet_cable_printable{'cable.label_to'} if (!ref $row);
  my @rrow = @{$row};
  return "<a href=\"".CMU::WebInt::encURL("$url?op=cable_view&id=$rrow[$outlet_cable_host_pos{'outlet.cable'}]")."\">$rrow[$outlet_cable_host_pos{'cable.label_from'}]/<br>".
    "$rrow[$outlet_cable_host_pos{'cable.label_to'}]</a>";
}

sub outlet_cb_type {
  my ($url, $row, $edata) = @_;
  return $CMU::Netdb::structure::outlet_printable{'outlet.type'} if (!ref $row);
  my @rrow = @{$row};
  return $$edata{$rrow[$outlet_cable_host_pos{'outlet.type'}]};
}

sub outlet_cb_state {
  my ($url, $row, $edata) = @_;
  my %fields;
  return 'Outlet State' if (!ref $row);
  my @rrow = @{$row};
  map { $fields{$_} = $rrow[$outlet_cable_host_pos{"outlet.$_"}] } qw/status flags device attributes port type/;
  my $state = CMU::Netdb::get_outlet_state(\%fields);
  if ($state == -30) {
    return '[inCMU::Netdb::valid]';
  }
  return $state;
}

sub outlet_search_pre_where {
  my ($dbh, $type, $tdata) = @_;
  my ($query, $sth);

  if ($type eq 'USER') {
    $query = "SELECT outlet.id ".
      "FROM outlet, users, protections, credentials AS C ".
	"WHERE C.authid = '$tdata' AND users.id = C.user AND ".
	  "users.id = protections.identity AND ".
	    "protections.tid = outlet.id AND protections.tname = 'outlet'";
  }elsif($type eq 'GROUP') {
    $query = "SELECT outlet.id FROM outlet, groups, protections WHERE ".
      "groups.name like '$tdata' AND groups.id = -1*protections.identity AND ".
	"protections.tid = outlet.id AND protections.tname = 'outlet'";
  }else{
    return ' 1 ';
  }
  
  $sth = $dbh->prepare($query);
  $sth->execute;
  my (@ret, @row);
  while(@row = $sth->fetchrow_array) {
    push(@ret, $row[0]);
  }
  $sth->finish;
  if ($#ret > -1) {
    return " outlet.id IN (".join(',', @ret).") ";
  }else{
    return ' 0 ';
  }
}

sub outlet_s_get_device {
    my ($devQuery, $dbh, $dbuser) = @_;
    my (@devID, $ts_mach_map);

    my $mach_ref = CMU::Netdb::list_machines($dbh, $dbuser, $devQuery);
    my $mach_map = CMU::Netdb::makemap($mach_ref->[0]);
    shift(@$mach_ref);

    foreach my $row (@$mach_ref) {
	my $ts_mach = CMU::Netdb::list_trunkset_presences($dbh, $dbuser, 'machine',
			    "trunkset_machine_presence.device = '$row->[$mach_map->{'machine.id'}]'");
	$ts_mach_map = CMU::Netdb::makemap($ts_mach->[0]);
	shift(@$ts_mach);
	foreach my $ts_row (@$ts_mach) {
	    push(@devID, $ts_row->[$ts_mach_map->{'trunkset_machine_presence.id'}]);
	}
    }

    my $inID = 0;
    $inID = join(',',@devID) if ($#devID >= 0);
    return "outlet.device IN ($inID)";
}

#sub outlets_deact {
#  my ($q, $errors) = @_;
#  my ($url, $msg, $dbh, $ul, $res) = @_;

#  if (CMU::WebInt::gParam($q, 'conf') == 1 || CMU::WebInt::gParam($q, 'm') eq 'a') {
#    outlets_deact_conf($q, $errors);
#    return;
#  }
#  $dbh = CMU::WebInt::db_connect();
#  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
#  CMU::WebInt::setHelpFile('outlets_deact');
#  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets");
#  &CMU::WebInt::title('Deactivate Outlet');
#  my $id = CMU::WebInt::gParam($q, 'id');
#  my $version = CMU::WebInt::gParam($q, 'version');
  
#  $url = $ENV{SCRIPT_NAME};
#  $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', $id);
#  if ($ul < 1) {
#    CMU::WebInt::accessDenied();
#    $dbh->disconnect();
#    print CMU::WebInt::stdftr($q);
#    return;
#  }
  
#  # basic attached cable information
#  my $cref = CMU::Netdb::list_outlets_cables($dbh, $user, "outlet.id='$id'");
#  if (!ref $cref || !defined $cref->[1]) {
#    print "Cable for outlet not defined!\n";
#    print &CMU::WebInt::stdftr($q);
#    return;
#  }
#  my @cdata = @{$cref->[1]};
  
#  print "<br><br>Please confirm that you wish to deactivate the following outlet.\n";
  
#  my @print_fields = qw/cable.to_building cable.to_room_number
#    cable.label_from cable.label_to/;

#  print "<table>\n";
#  foreach my $f (@print_fields) {
#    print "<tr><th>".$CMU::Netdb::structure::outlet_cable_printable{$f}."</th>
#<td>";
#    print $cdata[$outlet_cable_pos{$f}];
#    print "</td></tr>\n";
#  }
#  print "</table>\n";
#  print "<BR><a href=\"$url?op=outlets_deact&conf=1&id=$id&version=$version\">
#Yes, deactivate this outlet";
#  print "<br><a href=\"$url?op=outlets_info&oid=$id\">No, return to the outlet information</a>\n";
#  print CMU::WebInt::stdftr($q);
#  $dbh->disconnect();
#}

#sub outlets_deact_conf {
#  my ($q, $errors) = @_;
#  my ($url, $msg, $dbh, $ul, $res, $ref) = @_;
  
#  my $id = CMU::WebInt::gParam($q, 'id');
#  my $version = CMU::WebInt::gParam($q, 'version');
#  my $meth = CMU::WebInt::gParam($q, 'm');
#  $msg = $errors->{'msg'};
#  if ($id eq '') {
#    $msg = "Deactivate Outlet: Outlet ID not specified!" if ($meth ne 'a');
#    $msg = "Activate Outlet: Outlet ID not specified!" if ($meth eq 'a');
#    my %errors = ('msg' => $msg,
#		  'type' => 'ERR',
#		  'fields' => '',
#		  'loc' => 'outlets_del_conf',
#		  'code' => $CMU::Netdb::errcodes{ERROR});
#    $q->param('oid', $id);
#    CMU::WebInt::outlets_info($q, \%errors);
#    return;
#  }

#  $dbh = CMU::WebInt::db_connect();
#  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
#  $url = $ENV{SCRIPT_NAME};
#  $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', $id);

#  if ($ul < 1) {
#    print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets");
#    &CMU::WebInt::title('Activate Outlet') if ($meth eq 'a');
#    &CMU::WebInt::title('Deactive Outlet') if ($meth ne 'a');
#    CMU::WebInt::accessDenied();
#    $dbh->disconnect();
#    print CMU::WebInt::stdftr($q);
#    return;
#  }

#  my %fields;
#  $fields{attributes} = 'deactivate' if ($meth ne 'a');
#  $fields{attributes} = 'activate' if ($meth eq 'a');

#  ($res, $ref) = CMU::Netdb::modify_outlet($dbh, $user, $id, $version, \%fields, $ul);

#  if ($res == 1) {
#    if ($meth ne 'a') {
#      CMU::WebInt::machines::CMU::WebInt::mach_list($q, "The outlet was marked to be deactivated.");
#      return;
#    }
    
#    $q->param('oid', $id);
#    my %errors = ('msg' => 'This outlet was marked to be activated.');
#    CMU::WebInt::outlets_info($q, \%errors);
#  }else{
#    $msg = 'There was an error while deactivating the outlet: '.$errmeanings{$res} if ($meth ne 'a');
#    $msg = "There was an error while activating the outlet: ".$errmeanings{$res} if ($meth eq 'a');
#    $msg .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." ) "
#      if ($res eq $CMU::Netdb::errcodes{EDB});
#    $dbh->disconnect();
#    my %errors = ('msg' => $msg,
#		 'loc' => 'outlets_deact_conf',
#		 'code' => $res,
#		 'type' => 'ERR',
#		 'fields' => join(',', @$ref));
#    $q->param('oid', $id);
#    CMU::WebInt::outlets_info($q, \%errors);
#  }
#}

sub outlets_delete {
  my ($q) = @_;
  my ($url, $msg, $dbh, $ul, $res) = @_;

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  CMU::WebInt::setHelpFile('outlets_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets", {});
  &CMU::WebInt::title('Delete Outlet');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');

  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('outlet', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $sref = CMU::Netdb::list_outlets_cables($dbh, $user, "outlet.id='$id'");
  if (!defined $sref->[1]) {
    print "Outlet not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};

  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, "");
  my %bdata = %$bref;

  print "<br><br>Please confirm that you wish to delete the following outlet.\n";

  my @print_fields = ('cable.label_from', 'cable.label_to',
		      'cable.to_building', 'cable.to_room_number');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>" . $outlet_cable_printable{$f} . "</th><td>";
    if (($f eq 'cable.to_building') &&
	($bdata{$sdata[$outlet_cable_pos{$f}]} ne '')) {
      print $bdata{$sdata[$outlet_cable_pos{$f}]}
    }
    else {
      print $sdata[$outlet_cable_pos{$f}];
    }
    
  }
    print "</td></tr>\n";
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=outlets_confirm_delete&id=$id&version=$version")."\">Yes, Delete this Outlet</a>";
  print "<br><a href=\"$url?op=outlets_list\">No, return to the outlets list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub outlets_confirm_delete {
  my ($q, $errors) = @_;
  my ($url, $msg, $dbh, $ul, $res, $ref) = @_;

  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');

  $msg = $errors->{'msg'};
  if ($id eq '') {
    $msg = "Delete Outlet: Outlet ID not specified!";
    my %errors = ('msg' => $msg,
		  'code' => $CMU::Netdb::errcodes{ERROR},
		  'loc' => 'outlets_del_conf',
		  'fields' => '',
		  'type' => 'ERR');
    CMU::WebInt::outlets_info($q, %errors);
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', $id);

  if ($ul < 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets", $errors);
    &CMU::WebInt::title('Delete Outlet');
    CMU::WebInt::accessDenied('outlet', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  ($res, $ref) = CMU::Netdb::delete_outlet($dbh, $user, $id, $version);

  if ($res == 1) {
    CMU::WebInt::mach_list($q, {'msg' => "The outlet was deleted."});
  }
  else {
    $msg = 'There was an error while deleting the outlet: ' . $errmeanings{$res};
    $msg .= " (Database Error: " . $CMU::Netdb::primitives::db_errstr . " ) "
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $dbh->disconnect();
    my %errors = ('msg' => $msg,
		  'code' => $res,
		  'loc' => 'outlets_del_conf',
		  'fields' => join(',', @$ref),
		  'type' => 'ERR');
    CMU::WebInt::outlets_info($q, \%errors);
  }
}

sub outlets_expire_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $osort, %groups, $grp, $mem, $gwhere);
  my (%groups_pos, %users_pos);

  $dbh = CMU::WebInt::db_connect();
  $sort = CMU::WebInt::helper::gParam($q, 'sort');
  $sort = 'cable.to_building' if ($sort eq '');

  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('outlets_expire_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlets Expiring", $errors);
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
<input type=hidden name=op value=outlets_expire_list>";
    print "Expiring outlets for: ".$q->popup_menu(-name => 'grp',
                                                               -values => \@gk,
                                                               -labels => \%groups,
                                                               -default => -1);
    print " <input type=submit value=\"Refresh\"></form>\n";
  }else{
    print "<font face=\"arial,helvetica,geneva,charter\">Expiring outlets for: <b>$ui->[1]->[$users_pos{'credentials.description'}]</b><br /><br />\n\n";
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
  print &CMU::WebInt::subHeading("Expiring Outlets", CMU::WebInt::pageHelpLink('outlet'));

  $res = outlets_print_expire_outlets($user, $dbh, $q, $gwhere, $grp,
                                    " outlet.expires != 0 ".
                                    CMU::Netdb::verify_orderby($sort),
                                    $url, "sort=$sort&grp=$presentID", 'start', 'outlets_expire_list');

  print "ERROR: ".$errmeanings{$res} if ($res <= 0);
 print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


# outlet_print_expire_outlets
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
sub outlets_print_expire_outlets {
  my ($user, $dbh, $q, $t, $td, $where, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres);

  $start = (CMU::WebInt::helper::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::helper::gParam($q, $skey);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'MACHINES_PER_PAGE');

  $where = "1" if ($where eq '');
  if ($td eq '0') {
    $ruRef = CMU::Netdb::list_outlets_cables($dbh, $user, " $where ".
                                       CMU::Netdb::verify_limit($start, $defitems));
  }else{
    $ruRef = CMU::Netdb::list_outlets_cables_munged_protections($dbh, $user, $t, $td, " $where ".
                                                          CMU::Netdb::verify_limit($start, $defitems));
  }

  if (!ref $ruRef) {
    print "ERROR with list_outlets: ".$errmeanings{$ruRef};
    return 0;
  }
  $lmach .= "&$oData" if ($oData ne '');
  $ctRow = ($#{$ruRef} < $defitems ? 0 : $start+$defitems+1);

  print "The following outlets are set to expire on the date listed. You can prevent ".
    "a outlet from expiring by viewing the outlet information screen and clicking ".
      "'Retain'.<br />\n";
  print &CMU::WebInt::pager_Top($start, $ctRow, $defitems, 0,
                                $url, "op=".$lmach, $skey);

  $lmach =~ s/\&sort=[^\&]+//;
  $lmach =~ s/\&\&/\&/g;
  $lmach =~ s/\&$//;

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of
  # functions calling this function.
#  CMU::WebInt::generic_tprint($url, $ruRef,
#                             ['machine.host_name', 'machine.mac_address',
#                              'machine.expires'],
#                             [\&CMU::WebInt::machines::mach_cb_print_IP,
#                              \&CMU::WebInt::machines::mach_cb_unexp_button],
#                             {'q' => $q}, $lmach,
#                             'op=mach_view&id=',
#                             \%machine_pos,
#                             \%CMU::Netdb::structure::machine_printable,
#                             'machine.host_name', 'machine.id', 'sort',
#                             ['machine.host_name', 'machine.mac_address', 'machine.expires',
#                              'machine.ip_address', '']);

  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, '');
  my $otref = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'LIST', '');


  CMU::WebInt::generic_tprint($url, $ruRef,
          ['cable.label_from', 'cable.label_to'],
         [\&CMU::WebInt::outlets::outlets_cb_outlet_type,
          \&CMU::WebInt::outlets::outlets_cb_to_building,
          \&CMU::WebInt::outlets::outlets_cb_to_floor,
          \&CMU::WebInt::outlets::outlets_cb_room_number,
          \&CMU::WebInt::outlets::outlets_cb_vlan,
          \&CMU::WebInt::outlets::outlets_cb_unexp_button],
                 [$otref, $bref, $dbh, {'ruRef' => $ruRef}, {'q' => $q}], $lmach, 'op=outlets_info&oid=',
         \%outlet_cable_pos, \%outlet_cable_printable,
    'cable.label_from', 'outlet.id', 'osort',
                 ['cable.label_from', 'cable.label_to', 'outlet.type',
                 'building.name', 'cable.to_floor', 'cable.to_room_number']);


  return 1;
}

sub outlets_cb_unexp_button {
  my ($url, $row, $edata) = @_;
  return "Retain" if (!ref $row);

  my $ruRef;
  my $q;

  foreach my $a (@$edata) {
    if (defined $a->{'ruRef'}) {
      $ruRef = $a->{'ruRef'};
    }
    if (defined $a->{'q'}) {
      $q = $a->{'q'};
    }
  }


  #warn Data::Dumper->Dump([$ruRef, $row],['ruRef', 'row']);

  my $grp = CMU::WebInt::helper::gParam($q, 'grp');

  my $hashmap = CMU::Netdb::helper::makemap($ruRef->[0]);

  my $outletid =  $row->[$hashmap->{'outlet.id'}];
  my $outletver = $row->[$hashmap->{'outlet.version'}];

  my $link = "<form action=$url>
  <input type=hidden name=op value=outlets_unexpire>
  <input type=hidden name=id value=$outletid>
  <input type=hidden name=version value=$outletver>
  <input type=hidden name=grp value=$grp>
  <input type=submit value=\"Retain\"></form>\n";

  return $link;
}
sub outlets_unexpire {
  my ($q) = @_;
  my ($dbh, $id, $version, $userlevel, $res, $errfields, %fields, %nerrors);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::WebInt::helper::gParam($q, 'id');
  $version = CMU::WebInt::helper::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'outlet', $id);

  if ($userlevel >= 1) {
    %fields = ('expires' => '0000-00-00');
  }else{
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Update Access Denied", {});
    &CMU::WebInt::title("Update Outlet");
    CMU::WebInt::accessDenied();
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  ($res, $errfields) = CMU::Netdb::modify_outlet($dbh, $user, $id, $version, \%fields, $userlevel);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Unexpired outlet.\n";
    $dbh->disconnect(); # we use this for the insertid ..

    my $grp = CMU::WebInt::helper::gParam($q, 'grp');
    if ($grp) {
      &CMU::WebInt::outlets::outlets_expire_list($q, \%nerrors);
    } else {
      &CMU::WebInt::outlets::outlets_info($q, \%nerrors);
    }
    return;

  }else{
    foreach (@$errfields) {
      $nerrors{$_} = 1;
    }
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
    $nerrors{'type'} = 'ERR';
    $nerrors{'loc'} = 'outlet_unexpire';
    $nerrors{'code'} = $res;
    $nerrors{'fields'} = join(',', @$errfields);
    $dbh->disconnect();
   my $grp = CMU::WebInt::helper::gParam($q, 'grp');
    if ($grp) {
      &CMU::WebInt::outlets::outlets_expire_list($q, \%nerrors);
    } else {
      &CMU::WebInt::outlets::outlets_info($q, \%nerrors);
    }
  }
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 8
# perl-indent-level: 2
# cperl-indent-level: 2
# End:
