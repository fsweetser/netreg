#   -*- perl -*-
#
# CMU::WebInt::outlet_act
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


package CMU::WebInt::outlet_act;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings @panelSizes %omap
	     %oact_aq_pos $debug);
use CMU::Netdb;
use CMU::WebInt;
use Data::Dumper;

use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(oact_list_0);

$debug = 0;
%errmeanings = %CMU::Netdb::errors::errmeanings;
@panelSizes = ('Default', '24 (Cat 5/6)', '48 (Cat 5/6)');
%omap = ('24 (Cat 5/6)' => ['01', '02', '03', '04', '05', '06', '07', '08',
                            '09', '10', '11', '12', '13', '14', '15', '16',
                            '17', '18', '19', '20', '21', '22', '23', '24'],
         '48 (Cat 5/6)' => ['01', '02', '03', '04', '05', '06', '07', '08',
                            '09', '10', '11', '12', '13', '14', '15', '16',
                            '17', '18', '19', '20', '21', '22', '23', '24',
                            '25', '26', '27', '28', '29', '30', '31', '32',
                            '33', '34', '35', '36', '37', '38', '39', '40',
                            '41', '42', '43', '44', '45', '46', '47', '48'],
	 'IBM' => ['A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 
		   'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8',
		   'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 
		   'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8',
		   'E1', 'E2', 'E3', 'E4', 'E5', 'E6', 'E7', 'E8', 
		   'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8',
		   'G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8', 
		   'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'H7', 'H8'],
	 'CATV' => ['01', '02', '03', '04', '05', '06', '07', '08',
		    '09', '10', '11', '12', '13', '14', '15', '16'],
	);
%oact_aq_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::activation_q_fields)};

sub oact_list_0 {
  my ($q, $msg) = @_;
  my ($dbh, $res, $url, $sort);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Activation", {});
  &CMU::WebInt::title("Outlet Activation");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('outlet', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, {'msg' => $msg});
  
  &oact_form($url, $dbh, $user, $q);
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub oact_form {
  my ($url, $dbh, $user, $q) = @_;
  
  my $blist = CMU::Netdb::list_buildings_ref($dbh, $user, '');
  if (!ref $blist) {
    print "[error: unable to list_buildings_ref]\n";
    # FIXME send mail
  }
  my @bs = sort {$$blist{$a} cmp $$blist{$b}} keys %$blist;
  
  my $qlist = CMU::Netdb::list_activation_queue_ref($dbh, $user, '');
  if (!ref $qlist) {
    print "[error: unable to list_activation_queue_ref]\n";
    # FIXME send mail
  }
  my @qv = sort {$$qlist{$a} cmp $$qlist{$b}} keys %$qlist;
  
  print &CMU::WebInt::subHeading("Outlet Activation Query",
				 "[<b><a href=$url?op=oact_aq_list>Activation Queues</a></b>] ".CMU::WebInt::pageHelpLink(''));
  print "<form method=get>
<input type=hidden name=op value=oact_list_1>
Select the building or queue to view outlet activations for: 
<table border=0 width=100%>\n
<tr><td><font face=\"Arial,Helvetica,Geneva,Charter\">
<label accesskey=b for=building><u>B</u>uilding</label></td>
<td>".
  $q->popup_menu(-name => 'building',
		 -id => 'building',
		 -values => \@bs,
		 -labels => $blist,
		 -size => 5)."
</td><td align=right><input type=submit name=buildingNEXT value=Continue></td></tr>

<tr><td colspan=3 bgcolor=	#a3ffa3><font size=+1><b><i>-or-</i></b></td></tr>
<tr><td><font face=\"Arial,Helvetica,Geneva,Charter\">
<label accesskey=q for=queue><u>Q</u>ueue</td>
<td>".$q->popup_menu(-name => 'queue',
		     -id => 'queue',
		     -values => \@qv,
		     -labels => $qlist,
		     -size => 5).
		       "</td><td align=right><input type=submit name=queueNEXT value=Continue></td></tr></table>
</form>\n";
}

sub oact_list_1 {
  my ($q, $msg) = @_;
  my ($dbh, $res, $url, $sort, $oact, $blist, $qlist, $type, $building, $queue);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_list_1');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Activation", {});
  &CMU::WebInt::title("Outlet Activation");
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('outlet', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, {'msg' => $msg});
  
  $type = 0;
  $type = 1 if (CMU::WebInt::gParam($q, 'queueNEXT') ne '');
  my $start = CMU::WebInt::gParam($q, 'start');
  $start = 0 if ($start eq '');
  my $ITEMS = 20;
  
  print &CMU::WebInt::subHeading("Pending Activations", CMU::WebInt::pageHelpLink(''));
  my $ret;
  my $ctRow;
  if ($type) {
    $ret = "op=oact_list_1&queueNEXT=1&queue=".CMU::WebInt::gParam($q, 'queue');
    print CMU::WebInt::smallRight("[<b><a href=$url?$ret>Refresh</a></b>]\n");
    $queue = CMU::WebInt::gParam($q, 'queue');
    $qlist = CMU::Netdb::list_activation_queue_ref($dbh, $user, '');
    $blist = CMU::Netdb::list_buildings_ref($dbh, $user, '');
    my $wbr = CMU::Netdb::list_buildings($dbh, $user, "building.activation_queue = $queue");
    if (!ref $wbr) {
      print "<br>Error calling list_buildings_ref<br>\n";
    }else{
      shift(@$wbr);
      my @buildings = map { $_->[3] } @$wbr; # FIXME use position map
      my @bquery = map { "'$_'" } @buildings;
      #      $CMU::Netdb::building_cables::debug = 2;
      #      $CMU::Netdb::primitives::debug = 2;
      my $where = "cable.to_building IN (".join(',', @bquery).") AND outlet.attributes != '' AND status = 'partitioned' ";
      $ctRow = CMU::Netdb::primitives::count($dbh, $user, "outlet LEFT JOIN cable ON outlet.cable = cable.id LEFT JOIN building ON cable.to_building = building.building", $where);
      $oact = CMU::Netdb::list_outlets_cables($dbh, $user, 
					    $where . " ORDER BY cable.label_from "
					    . CMU::Netdb::verify_limit($start, $ITEMS));
      if (ref $blist) {
	print "Viewing activations for: ".
	  join(', ', map { $$blist{$_} } sort { $$blist{$a} cmp $$blist{$b} } @buildings)."<br>\n";
      }else{
	print "Error! calling list_buildings_ref<br>\n";
	# FIXME send mail
      }
    }
  }else{
    $ret = "op=oact_list_1&buildingNEXT=1&building=".CMU::WebInt::gParam($q, 'building');
    print CMU::WebInt::smallRight("[<b><a href=$url?$ret>Refresh</a></b>]\n");
    $building = CMU::WebInt::gParam($q, 'building');
    $blist = CMU::Netdb::list_buildings_ref($dbh, $user, '');
    if (ref $blist) {
      print "Viewing activations for: ".$$blist{$building}."<br>\n";
    }else{
      print "Error! calling list_buildings_ref<br>\n";
      # FIXME send mail
    }

    my $where = "cable.to_building = '$building' AND outlet.attributes != '' AND status = 'partitioned' ";
      $ctRow = CMU::Netdb::primitives::count($dbh, $user, "outlet LEFT JOIN cable ON outlet.cable = cable.id LEFT JOIN building ON cable.to_building = building.building", $where);
    $oact = CMU::Netdb::list_outlets_cables($dbh, $user, 
					    $where . " ORDER BY cable.label_from "
					    . CMU::Netdb::verify_limit($start, $ITEMS));
  }
  
  if (ref $ctRow) {
    my $tmp = $ctRow->[0]; 
    $ctRow = $tmp;
    print "$ctRow activations pending.\n";
  } else {
    $ctRow = 0 if ($ctRow < 0);
  }

  warn __FILE__,':',__LINE__, ":> ".Data::Dumper->Dump([$oact, $ctRow], ['oact', 'ctRow']) if ($debug >= 3);;

  print "<form method=post>
<input type=hidden name=op value=oact_update>";
  
  my $otref = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'LIST', '');
  my %udata = ('q' => $q,
	       'otypes' => $otref,
	       'blist' => $blist,
	       'dbh' => $dbh);


  print &CMU::WebInt::pager_Top($start, $ctRow, $ITEMS,
				5, $url, $ret, 'start');
  
  CMU::WebInt::generic_tprint($url, $oact, [],
#[\&oact_cb_date, \&oact_cb_label, \&oact_cb_type, \&oact_cb_checkbox, \&oact_cb_deviceport, \&oact_cb_user, \&oact_cb_subnets],
			      [\&oact_cb_date, \&oact_cb_label, \&oact_cb_type, \&oact_cb_checkbox, \&oact_cb_deviceport, \&oact_cb_user, \&oact_cb_vlans],
			      \%udata, '', '', 
			      \%CMU::WebInt::outlets::outlet_cable_pos,
			      \%CMU::WebInt::outlets::outlet_cable_printable,
			      '', '', '', '', '', '');
  
  print "<input type=submit value=Update>\n";
  print "<br>*Note: [] indicates existing device <br>\n";
  print "</form>\n";
  print "<hr>";

  &oact_form($url, $dbh, $user, $q);
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub oact_cb_date {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return "Date";
  }
  if ($dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.version'}] =~ /^\d+$/) {
    $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.version'}] =~ /(....)(..)(..)(..)(..)(..)/;
    return "$1-$2-$3<br>$4:$5:$6\n";
  } else {
    return $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.version'}];
  }
}

sub oact_cb_label {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return "Label From/To ";
  }
  return "<a href=$url?op=outlets_info&oid=".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}].">".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'cable.label_from'}]."<br>".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'cable.label_to'}]."</a>";
}

sub oact_cb_label_to {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return $CMU::WebInt::outlets::outlet_cable_printable{'cable.label_to'};
  }
  return $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'cable.label_to'}];
}

sub oact_cb_user {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return "User";
  }
  my $pq = CMU::Netdb::list_protections($$udata{dbh}, 'netreg', 'outlet', 
					$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}], ' P.identity > 0');
  my @users = map { $_->[1] } @$pq;
  return join(', ', @users);
}

sub oact_cb_subnets {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return "Subnets";
  }
  my $osm = CMU::Netdb::list_outlet_subnet_memberships($$udata{dbh}, 'netreg', 
						       'outlet_subnet_membership.outlet = '.$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}]);
  my $map = CMU::Netdb::makemap($osm->[0]);
  shift @$osm;
  my @subnets = map { $_->[$map->{'subnet.name'}] } @$osm;
  return join(', ', @subnets) if (@subnets);
  return "Unspecified";
}

sub oact_cb_vlans {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return "Vlans";
  }
  my $osm = CMU::Netdb::list_outlet_vlan_memberships($$udata{dbh}, 'netreg', 
						       'outlet_vlan_membership.outlet = '.$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}]." AND outlet_vlan_membership.type = 'primary'");
  my $map = CMU::Netdb::makemap($osm->[0]);
  shift @$osm;
  my @vlans = map { $_->[$map->{'vlan.name'}] } @$osm;
  return join(', ', @vlans) if (@vlans);
  return "Unspecified";
}

sub oact_cb_type {
  my ($url, $dref, $udata) = @_;
  my ($q, %otypes, $id, $type, @attr, @ks);
  $q = $$udata{'q'};
  %otypes = %{$$udata{'otypes'}};
  @ks = sort keys %otypes;
  
  if (!ref $dref) {
    return $CMU::WebInt::outlets::outlet_cable_printable{'outlet.type'};
  }
  $id = $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}];
  $type = $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.type'}];
  @attr = split(/\,/, $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.attributes'}]);
  if (grep /deactivate/, @attr) {
    return $otypes{$type};
  }
  my $default = $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.type'}];
  return "<input type=hidden name=TYPE$id value=$default>$default\n" if (!grep(/$default/, @ks));
  return $q->popup_menu(-name => "TYPE$id",
			-values => \@ks,
			-labels => $$udata{'otypes'},
			-default => $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.type'}]);
}

sub oact_cb_checkbox {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return "Update";
  }
  my @attr = split(/\,/, $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.attributes'}]);
  my $id = $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}];
  if (grep /deactivate/, @attr) {
    return "<img src=/img/off.png><input type=checkbox name=OFF$id>
<input type=hidden name=V$id value=\"".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.version'}]."\">\n";
  }elsif(grep /^activate/, @attr) {
    return "<img src=/img/on.gif><input type=checkbox name=ON$id><input type=hidden name=V$id value=\"".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.version'}]."\">\n";
  }elsif(grep /^change/, @attr) {
    return "<img src=/img/on.gif><input type=checkbox name=ON$id><input type=hidden name=V$id value=\"".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.version'}]."\">\n";
  }else{
    return "[unknown]\n";
  }
}

sub oact_cb_deviceport {
  my ($url, $dref, $udata) = @_;
  if (!ref $dref) {
    return $CMU::WebInt::outlets::outlet_cable_printable{'outlet.device'}.'/'.
      $CMU::WebInt::outlets::outlet_cable_printable{'outlet.port'};
  }

  my ($q, $id, $device, $port, $ts_mach, $ts_mach_map);
  
  $q = $$udata{'q'};
  $id = $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}];

  $device = $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.device'}];
  $port = $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.port'}];
  $ts_mach = CMU::Netdb::list_trunkset_presences($$udata{dbh}, 'netreg', 'machine',
			    "trunkset_machine_presence.id = '$device'");
  $ts_mach_map = CMU::Netdb::makemap($ts_mach->[0]);
  $device = $ts_mach->[1]->[$ts_mach_map->{'trunkset_machine_presence.device'}] if ($#$ts_mach > 0);
  $device = 0 if ($#$ts_mach == 0);
  
  my ($dev_arr, $devs) =
	oact_get_devices($$udata{'dbh'}, $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}], $device);
  
  my @attr = split(/\,/, $dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.attributes'}]);
  if (grep /deactivate/, @attr) {
    return $$devs{$device}.'<br>/'.$port;
  }
  
  return $q->popup_menu(-name => "DEV".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}],
			-values => $dev_arr,
			-default => $device,
			-labels => $devs).
		    "/ <input type=text name=PORT".$dref->[$CMU::WebInt::outlets::outlet_cable_pos{'outlet.id'}]." value=\"$port\" size=5>";
}

sub oact_get_devices {
  my ($dbh, $outlet_id, $device) = @_;

  my ($osm, $map, @vlans, @ts, @dev_arr, %devs);
  my ($mach_rows, $mach_count, $mach_map, $devName);
  
  # Get VLAN id
  $osm = CMU::Netdb::list_outlet_vlan_memberships($dbh, 'netreg', 
						 "outlet_vlan_membership.outlet = ".$outlet_id."  AND outlet_vlan_membership.type = 'primary' ");
  if ($#$osm > 0) {
      $map = CMU::Netdb::makemap($osm->[0]);
      shift @$osm;
      @vlans = map { $_->[$map->{'vlan.id'}] } @$osm;

      # Get Trunk Sets
      foreach my $v (@vlans) {
	  my $sref = CMU::Netdb::list_vlan_trunkset_presence($dbh, 'netreg', "trunkset_vlan_presence.vlan = $v");
	  if (ref $sref) {
	      my %ts_local = %$sref;
	      map { push(@ts, $_)} keys %ts_local;
	  }
      }

      foreach my $ts_id (@ts) {
	 my $sref = CMU::Netdb::list_trunkset_device_presence($dbh, 'netreg', "trunkset_machine_presence.trunk_set = \'$ts_id\'");
	 my ( %devs_local);
	 if (ref $sref) {
	    %devs_local = %$sref;
	    map { $devs{$_} = $devs_local{$_} } keys %devs_local;
	    #map { push(@dev_arr, $_) } keys %devs_local;
	 }
      }
      @dev_arr = sort { $devs{$a} cmp $devs{$b} } keys %devs;
  } else {
      my $ts_ref = CMU::Netdb::list_trunkset($dbh, 'netreg', '');
      my $tsmap = CMU::Netdb::makemap($ts_ref->[0]);
      shift @$ts_ref;
      foreach my $ts (@$ts_ref) {
	  my $sref = CMU::Netdb::list_trunkset_device_presence($dbh, 'netreg', 
			    "trunkset_machine_presence.trunk_set = \'$ts->[$tsmap->{'trunk_set.id'}]\'");
	  my (%devs_local);
	  if (ref $sref) {
	      %devs_local = %$sref;
	      map { $devs{$_} = $devs_local{$_} } keys %devs_local;
	  }
      }
      @dev_arr = sort { $devs{$a} cmp $devs{$b} } keys %devs;
  }
  
  if ($device ne '') {
    $mach_rows = CMU::Netdb::list_machines($dbh, 'netreg', "machine.id = \'$device\'");
    $mach_map = CMU::Netdb::makemap($mach_rows->[0]);
    $mach_count = $#$mach_rows;
    shift (@$mach_rows);
    
    $devName = $mach_rows->[0]->[$mach_map->{'machine.host_name'}] if ($mach_count > 0);
    $devName = "Device Selection Required" if ($mach_count < 1);
    $devs{$device} = "[ ".$devName." ]";
    @dev_arr = grep(!/^$device$/, @dev_arr);
    unshift @dev_arr, $device;
  }

  return (\@dev_arr, \%devs);
}

sub oact_update {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_update');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Activation", $errors);
  &CMU::WebInt::title("Outlet Activation");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'outlet', 0);
  if ($ul < 9) {
    CMU::WebInt::accessDenied('outlet', 'WRITE', 0, 9, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  print &CMU::WebInt::subHeading("Activations");
  print "<table border=1><tr><td>".CMU::WebInt::tableHeading("Outlet ID")."</td>
<td>".CMU::WebInt::tableHeading("Activation Status")."</td></tr>\n";
  foreach(grep(/^ON/, $q->param())) {
    $id = $_;
    $id =~ s/ON//;
    oact_activate($dbh, $user, $q, $id);
  }
  print "</table>\n";
  
  print &CMU::WebInt::subHeading("Dectivations");
  print "<table border=1><tr><td>".CMU::WebInt::tableHeading("Outlet ID")."</td>
<td>".CMU::WebInt::tableHeading("Deactivation Status")."</td></tr>\n";
  foreach(grep(/^OFF/, $q->param())) {
    $id = $_;
    $id =~ s/OFF//;
    oact_deactivate($dbh, $user, $q, $id);
  }
  print "</table>\n";
  
  $dbh->disconnect;
  print &CMU::WebInt::stdftr($q);
}

sub oact_activate {
  my ($dbh, $user, $q, $id) = @_;
  my ($version, %outlet, $msg, $mach_rows, $mach_count, $device, $checkHash);
  
  $version = CMU::WebInt::gParam($q, 'V'.$id);
  $version =~ s/^V//;
  %outlet = ('attributes' => '');
  $outlet{device} = CMU::WebInt::gParam($q, 'DEV'.$id);
  $outlet{port} = CMU::WebInt::gParam($q, 'PORT'.$id);
  $outlet{type} = CMU::WebInt::gParam($q, 'TYPE'.$id);
  
  $outlet{device} =~ s/^DEV//;
  $outlet{port} =~ s/^PORT//;
  $outlet{type} =~ s/^TYPE//;

  $checkHash->{'id'} 		= $id;
  $checkHash->{'newDevice'} 	= $outlet{device};
  $checkHash->{'newPort'} 	= $outlet{port};
  $checkHash->{'oldDevice'} 	= 0;
  $checkHash->{'oldPort'} 	= 0;
  $checkHash->{'newVlan'} 	= '';
  $checkHash->{'userlevel'} 	= CMU::Netdb::get_write_level($dbh, $user, 'outlet', 0);
  $checkHash->{'qt'} 		= '';

  
  my ($dev_arr, $devs) = oact_get_devices($dbh, $id, '');

  unless (grep /$outlet{device}/, @$dev_arr) {
      $msg = "Error updating outlet: Device is not in appropriate vlan ";
      print "<tr><td>$id</td><td>$msg</td></tr>\n";
      return;
  }
  warn __FILE__, ':', __LINE__, ' :>'.
    "outlet: $outlet{device} /$outlet{port} / $outlet{type} $outlet{attributes}\n";

  my $osm = CMU::Netdb::list_outlet_vlan_memberships($dbh, 'netreg', 
			" outlet_vlan_membership.outlet = '$id' ".
			" AND outlet_vlan_membership.type = 'primary'");
  my $map = CMU::Netdb::makemap($osm->[0]);
  shift @$osm;
  $outlet{'vlan'} = $osm->[0]->[$map->{'outlet_vlan_membership.vlan'}];

  my ($res, $ref) = CMU::Netdb::modify_outlet($dbh, $user, $id, $version, \%outlet, 9);
  if ($res < 1) {
    $msg = "Error updating outlet: ".$errmeanings{$res};
    $msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $CMU::Netdb::errcodes{EDB});
    $msg .= " [".join(',', @$ref)."]";
  }else{
    CMU::Netdb::update_auxvlan($dbh, $user, $checkHash);
    $msg = "Outlet updated.\n";
  }
  print "<tr><td>$id</td><td>$msg</td></tr>\n";
}

sub oact_deactivate {
  my ($dbh, $user, $q, $id) = @_;
  my ($version, %outlet, %fields, $msg);
  
  $version = CMU::WebInt::gParam($q, 'V'.$id);
  $version =~ s/^V//;
  %outlet = ('attributes' => '');
  $outlet{device} = CMU::WebInt::gParam($q, 'DEV'.$id);
  $outlet{port} = CMU::WebInt::gParam($q, 'PORT'.$id);
  $outlet{type} = CMU::WebInt::gParam($q, 'TYPE'.$id);
  
  $outlet{device} =~ s/^DEV//;
  $outlet{port} =~ s/^PORT//;
  $outlet{type} =~ s/^TYPE//;

  my ($res, $ref) = CMU::Netdb::delete_outlet($dbh, $user, $id, $version);
  
  if ($res < 1) {
    $msg = "Error updating outlet: ".$errmeanings{$res};
    $msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $CMU::Netdb::errcodes{EDB});
    $msg .= " [".join(',', @$ref)."]";
  }else{
    $msg = "Outlet deleted.\n";
  }
  print "<tr><td>$id</td><td>$msg</td></tr>\n";
  
}

## **************************************************************
## telecom interface stuff
##
## screen 0: select the building and type (add/modify closet)
sub oact_telco_0 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_0');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  print $CMU::WebInt::vars::htext{'oact_telco_0.select'}."<br>";
  
  print "<form name=main method=post>
<input type=hidden name=op value=oact_telco_1>
<input type=hidden name=bmvm value=$verbose>";
  
  print &CMU::WebInt::subHeading("Select the <u>B</u>uilding", CMU::WebInt::pageHelpLink('building'));
  my %buildings = %{CMU::Netdb::list_buildings_ref($dbh, $user, '')};
  my @kb = sort {$buildings{$a} cmp $buildings{$b}} keys %buildings;
  
  if ($#kb > -1) {
    print "<table border=0 width=620><tr><td width=150><b>
 <font face=\"Arial,Helvetica,Geneva,Charter\"><b>".CMU::WebInt::inlineHelpLink('building').
   "Building:</a></b></font></td>
 <td width=350>".
   $q->popup_menu(-name => 'from_building',
		  -accesskey => 'b',
		  -values => \@kb,
		  -labels => \%buildings);
  }else{
    print "System Error: No buildings available.\n";
    &CMU::WebInt::admin_mail('outlet_act.pm:oact_telco_0', 'WARNING',
			     'No buildings available.', {});
  }
  print "</td><td align=right><input type=submit name=addNEXT value=\"Add Closets\"><br><input type=submit name=modNEXT value=\"Modify Closets\"><br><input type=submit name=dumpNEXT value=\"Generate Cable Dump\"></td></tr></table></form>";
  
  &CMU::WebInt::title("Other Telecom Operations");
  print "<hr><ul>\n";
  print "<li><a href=$url?op=rep_printlabels>Print Outlet Labels</a></li>\n";
  print "<li><a href=$url?op=oact_telco_1&dumpNEXT=1>Dump Cable Changes for all buildings</a></li>\n";
		   
  print "</ul>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub oact_telco_1 {
  my ($q, $e) = @_;
  if (CMU::WebInt::gParam($q, 'addNEXT') ne '') {
    oact_telco_add_closet_1($q, $e);
  } elsif (CMU::WebInt::gParam($q, 'modNEXT') ne '') {
    oact_telco_mod_closet_1($q, $e);
  } elsif (CMU::WebInt::gParam($q, 'dumpNEXT') ne '') {
    CMU::WebInt::reports::rep_telecomdump($q, $e);
  } else {
    oact_telco_0($q, $e);
  }
}

## ADD
## screen a1: display closets in the DB. request new closet number, 
## wing/tower, floor, and number of racks
sub oact_telco_add_closet_1 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_add_closet_1');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  my %errors = %$errors if (ref $errors);
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  my $building = CMU::WebInt::gParam($q, 'from_building');
  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, "building.building = '$building'");
  
  print &CMU::WebInt::subHeading("New Closet Information", CMU::WebInt::pageHelpLink(''));
  
  my $closetRef = CMU::Netdb::list_cables_closets($dbh, $user, $building);
  print "<font face=\"Arial,Helvetica,Geneva,Charter\">New closet in building: ".$$bref{$building}."</font><br>" if (ref $bref);
  print "<font face=\"Arial,Helvetica,Geneva,Charter\">Existing closets: ".
    join(' ', sort @$closetRef)."</font><br>" if (ref $closetRef);
  
  print "<form name=main method=post>
<input type=hidden name=op value=oact_telco_add_closet_2>
<input type=hidden name=bmvm value=$verbose>".
  $q->hidden('from_building');
  
  # Closet Number, wing
  print "<table><tr>".CMU::WebInt::printPossError(defined $errors{from_closet}, $CMU::Netdb::structure::cable_printable{'cable.from_closet'}, 1, 'from_closet').
    CMU::WebInt::printPossError(defined $errors{'cable.from_wing'}, $CMU::Netdb::structure::cable_printable{'cable.from_wing'}, 1, 'from_wing')."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('cable.from_closet', $verbose).
    $q->textfield(-name => 'from_closet', -accesskey => 'f').
      "</td><td>".
	CMU::WebInt::printVerbose('cable.from_wing', $verbose).
	  $q->textfield(-name => 'from_wing', -accesskey => 'f')."</td></tr>\n";
  
  # Floor, number of racks
  print "<tr>".CMU::WebInt::printPossError(defined $errors{from_floor}, $CMU::Netdb::structure::cable_printable{'cable.from_floor'}, 1, 'from_floor').
    CMU::WebInt::printPossError(defined $errors{num_racks}, 'Number of Racks', 1)."</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('cable.from_floor', $verbose).
    $q->textfield(-name => 'from_floor', -accesskey => 'f').
      "</td><td>".
	$q->textfield(-name => 'num_racks', -accesskey => 'n')."</td></tr>\n";
  print "</table>\n";
  
  print $q->submit(-value => 'Continue');
  print "</form>";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

## screen a2: present page with # of racks. select type, # panels,
## panel size
sub oact_telco_add_closet_2 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id);
  
  my $nr = CMU::WebInt::gParam($q, 'num_racks');
  if ($nr !~ /^\d+$/) {
    oact_telco_add_closet_1($q, {'msg' => 'num_racks is non-numeric',
				 'type' => 'ERR',
				 'code' => $CMU::Netdb::errcodes{ERROR},
				 'loc' => 'oact_telco_add_closet_2',
				 'fields' => 'num_racks'});
    return;
  }
  
  my %errors = %$errors if (ref $errors);
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_add_closet_2');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  print "<form name=main method=post>
<input type=hidden name=op value=oact_telco_add_closet_3>
<input type=hidden name=bmvm value=$verbose>".
  $q->hidden('from_closet').$q->hidden('from_wing').
    $q->hidden('from_floor').$q->hidden('num_racks').
      $q->hidden('from_building').$q->hidden;
  
  for my $rackNum (1..$nr) {
    print &CMU::WebInt::subHeading("Rack $rackNum");
    
    # Cable Rack
    my @Types = @CMU::Netdb::structure::cable_type;
    print "<table><tr>".CMU::WebInt::printPossError(defined $errors{'rack'.$rackNum}, $CMU::Netdb::structure::cable_printable{'cable.rack'}, 1, 'cable.rack').CMU::WebInt::printPossError(defined $errors{'rack'}, $CMU::Netdb::structure::cable_printable{'cable.type'}, 1, 'cable.type')."</tr><tr>".
      "<td>".CMU::WebInt::printVerbose('cable.rack', $verbose).
	$q->popup_menu(-name => 'rack'.$rackNum,
		       -values => \@CMU::Netdb::structure::cable_rack).
			 "</td><td>".
			   $q->popup_menu(-name => 'type',
					  -values => \@Types,
					  -default => 'Default')."</td></tr>\n";
    
    # num. panels, panel size
    print "<tr>".CMU::WebInt::printPossError(defined $errors{'npanels'.$rackNum}, 'Number of Panels', 1).
      CMU::WebInt::printPossError(defined $errors{'psize'.$rackNum}, 'Panel Size').
	"</tr><tr>".
	  "<td>".$q->textfield(-name => 'npanels'.$rackNum)."</td><td>".
	    $q->popup_menu(-name => 'psize'.$rackNum,
			   -values => \@panelSizes)."</td></tr>\n";
    print "</table>\n";
  }
  print $q->submit(-value => 'Create')."</form>\n";
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

## screen a3: add closet to DB, send back to screen 0
sub oact_telco_add_closet_3 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_add_closet_3');
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  my %fields = ();
  foreach (qw/from_building from_wing from_floor from_closet/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  $fields{from_floor} = '0'.$fields{from_floor} if (length($fields{from_floor}) == 1);
  
  $fields{destination} = 'OUTLET';
  my $nracks = CMU::WebInt::gParam($q, 'num_racks');
  my ($stTotal, $stError) = (0,0);
  
  my @logmsg = ();
  
  for my $nr (1..$nracks) {
    $fields{from_rack} = $nr;
    $fields{rack} = CMU::WebInt::gParam($q, 'rack'.$nr);
    my $type = CMU::WebInt::gParam($q, 'type'.$nr);
    if ($fields{rack} eq 'TELCO') {
      $fields{type} = 'CAT5-TELCO';
      $fields{prefix} = 'W';
    }elsif($fields{rack} eq 'CAT5/6') {
      if ($type ne 'Default' && ($type eq 'CAT5' || $type eq 'CAT6')) {
	$fields{type} = $type;
      }else{
	$fields{type} = 'CAT5';
      }
      $fields{prefix} = 'R';
    }elsif($fields{rack} eq 'IBM') {
      $fields{type} = 'TYPE2';
      $fields{prefix} = '';
    }elsif($fields{rack} eq 'CATV') {
      $fields{type} = 'CATV';
      $fields{prefix} = 'C';
    }else{
      push(@logmsg, "In CMU::Netdb::valid rack type: $fields{rack} for rack #$nr\n");
      $stError++;
      next;
    }
    
    warn __FILE__, ':', __LINE__, ' :>'.
      "Adding Rack $nr ($fields{type}/$fields{prefix})\n";
    for my $pr (1..CMU::WebInt::gParam($q, 'npanels'.$nr)) {
      if ($pr > 9) {
	my $newpr = "A";
	for (11..$pr) {
	  $newpr++;
	}
	$pr = $newpr;
      }
      
      $fields{from_panel} = $pr;
      warn __FILE__, ':', __LINE__, ' :>'.
	"Adding panel $pr\n";
      my @addFields = ();
      my $typeID = CMU::WebInt::gParam($q, 'psize'.$nr);
      warn __FILE__, ':', __LINE__, ' :>'.
	"TypeID: $typeID\n";
      warn __FILE__, ':', __LINE__, ' :>'.
	"OMAP IBM: $omap{IBM}\n";
      if ($typeID eq 'Default') {
	if ($fields{rack} eq 'IBM') {
	  @addFields = @{$omap{'IBM'}};
	}elsif($fields{rack} eq 'CATV') {
	  @addFields = @{$omap{'CATV'}};
	}elsif($fields{rack} eq 'CAT5/6' || $fields{rack} eq 'TELCO') {
	  @addFields = @{$omap{'24 (Cat 5/6)'}};
	}
      }else{
	@addFields = @{$omap{$typeID}} if (defined $omap{$typeID});
      }
      
      foreach my $af (@addFields) {
	my @afs = split(//, $af);
	($fields{from_x}, $fields{from_y}) = ($afs[0], $afs[1]);
	my ($res, $ref) = CMU::Netdb::add_cable($dbh, $user, \%fields);
	if ($res < 1) {
	  $stError++;
	  push(@logmsg, "Error $res adding $af/panel $pr/rack $nr: [".join(',', @$ref)."]\n");
	}	       
	$stTotal++;
      }
    }
  }
  
  print "<hr>";
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  print "Added $nracks racks, $stTotal cables. $stError errors.\n<br>";
  if ($#logmsg > -1) {
    print "Errors:<br><ul>\n";
    foreach(@logmsg) {
      print "<li>$_\n";
    }
    print "</ul>\n";
  }
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
  
}

## MODIFY
## screen b1: display closets in the DB. select a closet
sub oact_telco_mod_closet_1 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_mod_closet_1');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  my $building = CMU::WebInt::gParam($q, 'from_building');
  my $closetRef = CMU::Netdb::list_cables_closets($dbh, $user, $building);
  my @closets = sort @$closetRef;
  print &CMU::WebInt::subHeading("Select a Closet");
  print "<form method=post><input type=hidden name=op value=oact_telco_mod_closet_2>".
    $q->hidden('from_building');
  print "<u>C</u>loset: ".$q->popup_menu(-name => 'from_closet',
					 -accesskey => 'c',
					 -values => \@closets);
  print "<input type=submit value=\"Continue\"></form>\n";
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

## screen b2: display racks in the closet (editable). 
## select rack and enter info to add
sub oact_telco_mod_closet_2 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_mod_closet_2');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  %errors = %$errors if (ref $errors);
  
  ## Real work
  my ($building, $closet) = (CMU::WebInt::gParam($q, 'from_building'), 
			     CMU::WebInt::gParam($q, 'from_closet'));
  
  print "<font face=\"Arial,Helvetica,Geneva,Charter\">Editing building $building; closet $closet\n</font>\n<br><br>";
  
  print &CMU::WebInt::subHeading("Modify existing racks");
  my $cableRef = CMU::Netdb::list_cables($dbh, $user, "cable.from_building = \"$building\" AND cable.from_closet = \"$closet\"");
  if (!ref $cableRef) {
    print "Error getting cable list: $cableRef -- ".$errmeanings{$cableRef};
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  
  my %panels;			# associative array of rack => associative array of panel => type
  shift @$cableRef;
  foreach my $cr (@$cableRef) {
    my ($rack, $panel, $x, $y, $type) = 
      ($cr->[$CMU::WebInt::cables::cable_pos{'cable.from_rack'}],
       $cr->[$CMU::WebInt::cables::cable_pos{'cable.from_panel'}],
       $cr->[$CMU::WebInt::cables::cable_pos{'cable.from_x'}],
       $cr->[$CMU::WebInt::cables::cable_pos{'cable.from_y'}],
       $cr->[$CMU::WebInt::cables::cable_pos{'cable.rack'}]);
    $panels{$type}->{$rack}->{$panel} = 1;
  }
  
  my ($type, $rack, $panel, $lastpanel, $panelcount);
  foreach $type (sort keys %panels) {
    foreach $rack (sort keys %{$panels{$type}}) {
      
      print "<br><font face=\"Arial,Helvetica,Geneva,Charter\">$type Rack $rack contains panels: ";
      warn __FILE__, ':', __LINE__, ' :>'.
	"$type Rack $rack contains panels: " if ($debug >= 2);
      $panelcount=0;
      foreach $panel (sort keys %{$panels{$type}{$rack}}) {
	$panelcount++;
	print "<a href=\"$url?op=oact_telco_mod_closet_3&rack=$type&from_rack=$rack&from_building=$building&from_closet=$closet&startpanel=$panelcount&npanels=1&modpanel=1\">$panel</a> \n";
	warn __FILE__, ':', __LINE__, ' :>'.
	  "$panel " if ($debug >= 2);
	$lastpanel = $panel;
      }
      #    print "<br><a href=\"$url?op=oact_telco_delete&from_rack=$rack&from_building=$building&from_closet=$closet&from_panel=ALL\">Delete Entire Panel</a>\n"
      warn __FILE__, ':', __LINE__, ' :>'.
	"\n" if ($debug >= 2);
      warn __FILE__, ':', __LINE__, ' :>'.
	"\$lastpanel is $lastpanel\n" if ($debug >= 2);
      warn __FILE__, ':', __LINE__, ' :>'.
	"\$panelcount is $panelcount\n" if ($debug >= 2);
      
      print "<form method=post><input type=hidden name=op value=oact_telco_mod_closet_3>
<input type=hidden name=rack value=".$type."><input type=hidden name=from_rack value=$rack>
<input type=hidden name=from_building value=$building>
<input type=hidden name=from_closet value=$closet>
<input type=hidden name=startpanel value=".($panelcount + 1).">
 Number of panels to add: <input type=text name=npanels size=5>";
      
      if ($type eq 'CAT5/6') {
	my @types = qw/CAT5 CAT6/;
	print " Type: ".$q->popup_menu(-name => 'type', -values => \@types);
      }
      print "
 Size: " . $q->popup_menu(-name => 'psize', -values => \@panelSizes).
   "<input type=submit value=\"Add\"></form>\n";
    }
  }
  
  
  # add a new rack
  print "<hr><form name=main method=post>
<input type=hidden name=op value=oact_telco_mod_closet_3>
<input type=hidden name=bmvm value=$verbose>
<input type=hidden name=startpanel value=1>".
  $q->hidden('from_closet').$q->hidden('from_building');
  
  print &CMU::WebInt::subHeading("<u>A</u>dd a rack");
  
  print "<table><tr>".CMU::WebInt::printPossError(defined $errors{from_rack}, 
						  $CMU::Netdb::structure::cable_printable{'cable.from_rack'}, 1, 'cable.from_rack');
  print "</tr><tr><td>".CMU::WebInt::printVerbose('cable.from_rack', $verbose).
    $q->textfield(-accesskey => 'a', -name => 'from_rack')."</td></tr>\n";
  
  # Cable Rack
  my @Types = @CMU::Netdb::structure::cable_type;
  unshift(@Types, 'Default');
  print "<tr>".CMU::WebInt::printPossError(defined $errors{'rack'}, $CMU::Netdb::structure::cable_printable{'cable.rack'}, 1, 'cable.rack').CMU::WebInt::printPossError(defined $errors{'rack'}, $CMU::Netdb::structure::cable_printable{'cable.type'}, 1, 'cable.type')."</tr><tr>".
    "<td>".CMU::WebInt::printVerbose('cable.rack', $verbose).
      $q->popup_menu(-name => 'rack', -accesskey => 'r',
		     -values => \@CMU::Netdb::structure::cable_rack).
		       "</td><td>".
			 $q->popup_menu(-name => 'type', -accesskey => 't',
					-values => \@Types,
					-default => 'Default')."</td></tr>\n";
  
  # num. panels, panel size
  print "<tr>".CMU::WebInt::printPossError(defined $errors{'npanels'}, 'Number of Panels', 1).
    CMU::WebInt::printPossError(defined $errors{'psize'}, 'Panel Size').
      "</tr><tr>".
	"<td>".$q->textfield(-name => 'npanels', -accesskey => 'n')."</td><td>".
	  $q->popup_menu(-name => 'psize', -accesskey => 'p',
			 -values => \@panelSizes)."</td></tr>\n";
  print "</table><input type=submit value=\"Add Rack\"></form>\n";
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

# screen b3: display list of outlets to be added, so 'to' sides can be 
# filled in, en masse
sub oact_telco_mod_closet_3 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id, $oldcables);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_mod_closet_3');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  my %fields = ();
  foreach (qw/from_building from_closet from_rack rack/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  my $npanels = CMU::WebInt::gParam($q, 'npanels');
  my $startpanel = CMU::WebInt::gParam($q, 'startpanel');
  my $psize = CMU::WebInt::gParam($q, 'psize');
  my $modpanel = CMU::WebInt::gParam($q, 'modpanel');
  my $alphapanel;
  
  
  #  $CMU::Netdb::buildings_cables::debug = 2;
  #  $CMU::Netdb::primitives::debug = 2;
  
  # FIXME: Verify rack doesn't already exist
  my $cableRef = CMU::Netdb::list_cables($dbh, $user, 
					 "cable.from_building=\"" . $fields{from_building}
					 . "\" AND cable.from_closet=\"" . 
					 $fields{from_closet} . "\"");
  if (!ref $cableRef) {
    print "Error getting cable list: $cableRef -- ".$errmeanings{$cableRef};
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    
    return;
  }
  
  if ($fields{rack} eq 'TELCO') {
    $fields{prefix} = 'W';
  }elsif($fields{rack} eq 'CAT5/6') {
    $fields{prefix} = 'R';
  }elsif($fields{rack} eq 'IBM') {
    $fields{prefix} = '';
  }elsif($fields{rack} eq 'CATV') {
    $fields{prefix} = 'C';
  }
  
  #FIXME:  Deal w/ bogus closet
  if ($#$cableRef != 0) {
    $fields{from_wing} = $cableRef->[1]->[$CMU::WebInt::cables::cable_pos{'cable.from_wing'}];
    $fields{from_floor} = $cableRef->[1]->[$CMU::WebInt::cables::cable_pos{'cable.from_floor'}];
    
    my @cables;
    if ($modpanel == 1) {
      if ($startpanel > 9){
	$alphapanel = 'A';
	for (11 .. $startpanel){
	  $alphapanel++;
	}
      } else {
	$alphapanel = $startpanel;
      }
	

      warn __FILE__, ':', __LINE__, ' :>'.
	"\nModifying panel $alphapanel\n\n" if ($debug >= 2);
      $cableRef = CMU::Netdb::list_cables($dbh, $user, 
					  "cable.from_building=\"" . $fields{from_building}
					  . "\" AND cable.from_closet=\"" . 
					  $fields{from_closet} . 
					  "\" AND cable.from_rack=\"$fields{from_rack}\" " . 
					  "AND cable.from_panel=\"$alphapanel\" " .
					  "AND cable.prefix=\"$fields{prefix}\"" );

      if (!ref $cableRef) {
	print "Error getting cable list: $cableRef -- ".$errmeanings{$cableRef};
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	
	return;
      }
      
      for (1..$#$cableRef) {
	$oldcables->{$cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.from_x'}] . $cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.from_y'}]} = [$cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.label_to'}], $cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.to_room_number'}], $cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.id'}],$cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.version'}]];
      }
      
      warn Data::Dumper->Dump([$oldcables],['$oldcables']);
      if ($fields{rack} eq 'IBM') {
	@cables = @{$omap{'IBM'}};
      } elsif ($fields{rack} eq 'CATV') {
	@cables = @{$omap{'CATV'}};
      } else {
	my ($last, @rest) = reverse sort keys %$oldcables;
	
	if ($last > 24 ) {
	  @cables = @{$omap{'48 (Cat 5/6)'}};
	} else { 
	  @cables = @{$omap{'24 (Cat 5/6)'}};
	}
      }
      
    } else {
      warn __FILE__, ':', __LINE__, ' :>'.
	"\nAdding panel $startpanel\n\n" if ($debug >= 2);
      
      if ($psize eq "Default") {
	if ($fields{rack} eq 'IBM') {
	  @cables = @{$omap{'IBM'}};
	}elsif($fields{rack} eq 'CATV') {
	  @cables = @{$omap{'CATV'}};
	} elsif ($fields{rack} eq 'CAT5/6' || $fields{rack} eq 'TELCO') {
	  @cables = @{$omap{'24 (Cat 5/6)'}};
	}
      } else {
	@cables = @{$omap{$psize}} if (defined $omap{$psize});
      }
    }
    print "<form method=post><input type=hidden name=op value=oact_telco_mod_closet_4>" . 
      $q->hidden('from_building') . $q->hidden('from_closet') . $q->hidden('from_rack') . 
	$q->hidden('rack') . $q->hidden('npanels') . $q->hidden('startpanel') . $q->hidden('type') .
	  $q->hidden('psize') . $q->hidden(-name => 'from_wing', -value => $fields{from_wing}) . 
	    $q->hidden(-name => 'from_floor', -value => $fields{from_floor}) . 
	      $q->hidden(-name => 'modpanel') . "\n";
    
    my ($xy, $panelNum);
    if ($modpanel == 1 ) {
      print &CMU::WebInt::subHeading("Modifying Rack " . $fields{from_rack} . " in building " . 
				     $fields{from_building} . " closet " . 
				     $fields{from_closet});
    } else {
      print &CMU::WebInt::subHeading("Adding Rack " . $fields{from_rack} . " to building " . 
				     $fields{from_building} . " closet " . 
				     $fields{from_closet});
    }
    for $panelNum ($startpanel..($startpanel + $npanels - 1)) {
      if ($panelNum > 9) {
	my $newpn = "A";
	for (11..$panelNum) {
	  $newpn++;
	}
	$panelNum = $newpn;
      }
      
      foreach my $xy (@cables) {
	my $ob = $fields{prefix} . $fields{from_building} . $fields{from_wing} . $fields{from_floor} .'-'. $fields{from_closet} . $fields{from_rack} . $panelNum;
	
	if ($modpanel == 1) {
	  if ($oldcables->{$xy}[0] ne "") {
	    print "<br>From: $ob-$xy <a href=\"$url?op=cable_view&id=$oldcables->{$xy}[2]\" target=_blank>To: $oldcables->{$xy}[0] Room: $oldcables->{$xy}[1]</a>\n";
	  } else {
	    print "<br>From: $ob-$xy To: " . $q->textfield(-name => "label_to_$panelNum$xy", -value => $oldcables->{$xy}[0]) . "Room: " . $q->textfield(-name => "to_room_number_$panelNum$xy", -value => $oldcables->{$xy}[1]) . "\n";
	  }
	} else {
	  print "<br>From: $ob-$xy To: " . $q->textfield(-name => "label_to_$panelNum$xy") . "Room: " . $q->textfield(-name => "to_room_number_$panelNum$xy") . "\n";
	}
      }
    }
    
    if ($modpanel  == 1) {
      print "<br><input type=submit value=\"Modify cables\"></form>\n";
    } else { 
      print "<br><input type=submit value=\"Add cables\"></form>\n";
    }
  }
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub oact_telco_mod_closet_4 {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, $id);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_telco_mod_closet_4');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Maintenance", $errors);
  &CMU::WebInt::title("Cable Plant Maintenance");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'cable', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('cable', 'ADD', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  my %fields = ();
  foreach (qw/from_building from_closet from_rack from_wing from_floor rack/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  my $npanels = CMU::WebInt::gParam($q, 'npanels');
  my $startpanel = CMU::WebInt::gParam($q, 'startpanel');
  my $modpanel = CMU::WebInt::gParam($q, 'modpanel');
  my $psize = CMU::WebInt::gParam($q, 'psize');
  my $type = CMU::WebInt::gParam($q, 'type');
  my $alphapanel;
  
  my (@cables_to_create, $oldcables, $cableRef);
  if ($fields{rack} eq 'TELCO') {
    $fields{type} = 'CAT5-TELCO';
    $fields{prefix} = 'W';
  }elsif($fields{rack} eq 'CAT5/6') {
    if ($type ne 'Default' && ($type eq 'CAT5' || $type eq 'CAT6')) {
      $fields{type} = $type;
    }else{
      $fields{type} = 'CAT5';
    }
    $fields{prefix} = 'R';
  }elsif($fields{rack} eq 'IBM') {
    $fields{prefix} = '';
  }elsif($fields{rack} eq 'CATV') {
    $fields{type} = 'CATV';
    $fields{prefix} = 'C';
  }
  
  if ($modpanel == 1) {

    if ($startpanel > 9){
      $alphapanel = 'A';
      for (11 .. $startpanel){
	$alphapanel++;
      }
    } else {
      $alphapanel = $startpanel;
    }

    warn __FILE__, ':', __LINE__, ' :>'.
      "\nModifying panel $startpanel\n\n" if ($debug >= 2);
    $cableRef = CMU::Netdb::list_cables($dbh, $user, 
					"cable.from_building=\"" . $fields{from_building}
					. "\" AND cable.from_closet=\"" . 
					$fields{from_closet} . 
					"\" AND cable.from_rack=\"$fields{from_rack}\" " . 
					"AND cable.from_panel=\"$alphapanel\" " .
					"AND cable.prefix=\"".$fields{prefix}."\"" );
    if (!ref $cableRef) {
      print "Error getting cable list: $cableRef -- ".$errmeanings{$cableRef};
      print CMU::WebInt::stdftr($q);
      $dbh->disconnect();
      
      return;
    }
    
    for (1..$#$cableRef) {
      $oldcables->{$cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.from_x'}] . $cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.from_y'}]} = [$cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.label_to'}], $cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.to_room_number'}], $cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.id'}],$cableRef->[$_]->[$CMU::WebInt::cables::cable_pos{'cable.version'}]];
    }
    
    
    if ($fields{rack} eq 'IBM') {
      @cables_to_create = @{$omap{'IBM'}};
    } elsif ($fields{rack} eq 'CATV') {
      @cables_to_create = @{$omap{'CATV'}};
    } else {
      my ($last, @rest) = reverse sort keys %$oldcables;
      
      if ($last > 24 ) {
	@cables_to_create = @{$omap{'48 (Cat 5/6)'}};
      } else { 
	@cables_to_create = @{$omap{'24 (Cat 5/6)'}};
      }
    }
    
  } else {
    if ($psize eq "Default") {
      if ($fields{rack} eq 'IBM') {
	@cables_to_create = @{$omap{'IBM'}};
      } elsif($fields{rack} eq 'CATV') {
	@cables_to_create = @{$omap{'CATV'}};
      } elsif ($fields{rack} eq 'CAT5/6' || $fields{rack} eq 'TELCO') {
	@cables_to_create = @{$omap{'24 (Cat 5/6)'}};
      }
    } else {
      @cables_to_create = @{$omap{$psize}} if (defined $omap{$psize});
    }
  }
  
  my ($xy, $panelNum, $doit);
  my ($stTotal, $stError) = (0, 0);
  my @logmsg= ();
  for $panelNum ($startpanel..($startpanel + $npanels - 1)) {
    if ($panelNum > 9) {
      my $newpn = "A";
      for (11..$panelNum) {
	$newpn++;
      }
      $panelNum = $newpn;
    }
    
    foreach $xy (@cables_to_create) {
      $doit = 1;
      my $ob = $fields{prefix} . $fields{from_building} . $fields{from_wing} . $fields{from_floor} .'-'. $fields{from_closet} . $fields{from_rack} . $panelNum;
      my $label_to = CMU::WebInt::gParam($q, "label_to_$panelNum$xy");
      $fields{from_panel} = $panelNum;
      ($fields{from_x},$fields{from_y}) = split //, $xy;
      if ($label_to =~ /^[CRW*\$M]?([^-]{5,})-([^-][^-])([^-][^-])([^-])$/) {
	# Typical format of $1 is: 11233
	# Where 1 == building, 2 == wing, 3 == floor
	# BUT, because building can be > 2 chars now, we're going to
	# pull off the floor and wing, then assume the rest is the building
	$fields{to_wing} = substr($1, -3, 1);
	$fields{to_floor} = substr($1, -2, 2);
	$fields{to_building} = substr($1, 0, length($1)-3);

	# End Run 
	$fields{to_floor_plan_x} = $2;
	$fields{to_floor_plan_y} = $3;
	$fields{to_outlet_number} = $4;
	$fields{to_room_number} = CMU::WebInt::gParam($q, "to_room_number_$panelNum$xy");
	$fields{destination} = "OUTLET";
	if($fields{rack} eq 'IBM') {
	  $fields{type} = 'TYPE2';
	}
	$fields{to_closet} = "";
	$fields{to_rack} = "";
	$fields{to_panel} = "";
	$fields{to_x} = "";
	$fields{to_y} = "";
	
	# Verify End Run doesn't already exist on another cable
	# Add to database
	
	$label_to = $fields{prefix} . $fields{to_building} . $fields{to_wing} . $fields{to_floor} .'-'. $fields{to_floor_plan_x} . $fields{to_floor_plan_y} . $fields{to_outlet_number};
	my $cableRef = CMU::Netdb::list_cables($dbh, "netreg", "label_to = \"$label_to\"");
	if (!ref $cableRef) {
	  print "Error getting cable list: $cableRef -- ".$errmeanings{$cableRef};
	  print CMU::WebInt::stdftr($q);
	  $dbh->disconnect();
	  &CMU::WebInt::admin_mail('outlet_act.pm:oact_telco_mod_closet_4', 'WARNING',
				   "Possible Corruption, Partial failure while adding a rack/panel: $ob", {});
	  return;
	}
	
	if ($#$cableRef != 0) {
	  # Error, other end existed.
	  # Add cable w/ to blank, and warn user.
	  $fields{to_building} = "";
	  $fields{to_wing} = "";
	  $fields{to_floor} = "";
	  $fields{to_floor_plan_x} = "";
	  $fields{to_floor_plan_y} = "";
	  $fields{to_outlet_number} = "";
	  $fields{to_room_number} = "";
	  $stError++;
	  $doit = 0;
	  push(@logmsg, "Error: To location $label_to already exists on another cable.  Leaving blank.\n");
	}	  
	
      } elsif ($label_to =~ /^[CRW*\$M]?([^-]{5,})-([^-])([^-])([^-])-([^-])([^-])$/) {
	# Closet to Closet
	# See note above about dealing with building/wing/floor
	$fields{to_building} = substr($1, 0, length($1)-3);
	$fields{to_wing} = substr($1, -3, 1);
	$fields{to_floor} = substr($1, -2, 2);

	$fields{to_closet} = $2;
	$fields{to_rack} = $3;
	$fields{to_panel} = $4;
	$fields{to_x} = $5;
	$fields{to_y} = $6;
	$fields{destination} = "CLOSET";
	if ($fields{rack} eq 'IBM') {
	  $fields{type} = 'TYPE1';
	}
	$fields{to_floor_plan_x} = "";
	$fields{to_floor_plan_y} = "";
	$fields{to_outlet_number} = "";
	$fields{to_room_number} = "";
	
	# Verify to end already exists in DB as a from w/o a to.
	# Add both entries to DB
	
	$label_to = $fields{prefix} . $fields{to_building} . $fields{to_wing} . $fields{to_floor} .'-'. $fields{to_closet} . $fields{to_rack} . $fields{to_panel} . '-' . $fields{to_x} . $fields{to_y};
	my $cableRef = CMU::Netdb::list_cables($dbh, "netreg", "label_from = \"$label_to\" AND label_to = \"\"");
	if (!ref $cableRef) {
	  print "Error getting cable list: $cableRef -- ".$errmeanings{$cableRef};
	  print CMU::WebInt::stdftr($q);
	  $dbh->disconnect();
	  &CMU::WebInt::admin_mail('outlet_act.pm:oact_telco_mod_closet_4', 'WARNING',
				   "Possible Corruption, Partial failure while adding a rack/panel: $ob", {});
	  return;
	}
	
	if ($#$cableRef != 1) { 
	  # Other end either does not exist or is duplicated
	  # Add cable with to blank and warn user
	  $fields{to_building} = "";
	  $fields{to_wing} = "";
	  $fields{to_floor} = "";
	  $fields{to_closet} = "";
	  $fields{to_rack} = "";
	  $fields{to_panel} = "";
	  $fields{to_x} = "";
	  $fields{to_y} = "";
	  $doit =  0;
	  $stError++;
	  push(@logmsg, "Error: $label_to either doesn't exist, or is already in use, leaving to fields of $ob-$xy blank.\n"); 
	} else {
	  my ($res, $ref) = 
	    CMU::Netdb::modify_cable($dbh, $user, 
				     $cableRef->[1]->[$CMU::WebInt::cables::cable_pos{'cable.id'}],
				     $cableRef->[1]->[$CMU::WebInt::cables::cable_pos{'cable.version'}],
				     { "to_building" => $fields{from_building},
				       "to_wing" => $fields{from_wing},
				       "to_floor" => $fields{from_floor},
				       "to_closet" => $fields{from_closet},
				       "to_rack" => $fields{from_rack},
				       "to_panel" => $fields{from_panel},
				       "to_x" => $fields{from_x},
				       "to_y" => $fields{from_y},
				       "destination" => "CLOSET",
				     });
	  if ($res < 1) {
	    $stError++;
	    $doit = 0;
	    push(@logmsg, "Error couldn't modify other end of closet to closet connection, not setting to fields: Error: $res [".join(',', @$ref)."]\n");
	    $fields{to_building} = "";
	    $fields{to_wing} = "";
	    $fields{to_floor} = "";
	    $fields{to_closet} = "";
	    $fields{to_rack} = "";
	    $fields{to_panel} = "";
	    $fields{to_x} = "";
	    $fields{to_y} = "";
	  }	       
	}
      } else {
	# Error, unknown to format, probably blank.
	if ($label_to ne "") {
	  $stError++;
	  push(@logmsg, "Error: unknown format for to label for $ob-$xy/$label_to, leaving blank.\n");
	}
	$doit = 0;
	$fields{to_building} = "";
	$fields{to_wing} = "";
	$fields{to_floor} = "";
	$fields{to_floor_plan_x} = "";
	$fields{to_floor_plan_y} = "";
	$fields{to_outlet_number} = "";
	$fields{to_room_number} = "";
	$fields{to_closet} = "";
	$fields{to_rack} = "";
	$fields{to_panel} = "";
	$fields{to_x} = "";
	$fields{to_y} = "";
	
      }
      
      
      if ($modpanel == 1) {
	if ($doit == 1) {
	  if ($oldcables->{$xy}[0] ne "") {
	    $stError++;
	    push(@logmsg, "Cable $ob-$xy's to fields have already been set, not updating.\n");
	  } else {
	    my ($res, $ref) = CMU::Netdb::modify_cable($dbh, $user, $oldcables->{$xy}[2], $oldcables->{$xy}[3], \%fields);
	    if ($res < 1) {
	      $stError++;
	      push(@logmsg, "Error $res modifying $ob-$xy/$label_to: [".join(',', @$ref)."]\n");
	    } else {
	      $stTotal++;
	    }
	  }
	  
	}
      } else { 
	my ($res, $ref) = CMU::Netdb::add_cable($dbh, $user, \%fields);
	if ($res < 1) {
	  $stError++;
	  push(@logmsg, "Error $res adding $ob-$xy/$label_to: [".join(',', @$ref)."]\n");
	} else {
	  $stTotal++;
	}
      }
    }
  }
  
  print "<hr>";
  
  print "Added $npanels panels, $stTotal cables. $stError errors.\n<br>";
  if ($#logmsg > -1) {
    print "Errors:<br><ul>\n";
    foreach(@logmsg) {
      print "<li>$_\n";
    }
    print "</ul>\n";
  }
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
  
}



sub oact_aq_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_aq_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Activation Queues", $errors);
  &CMU::WebInt::title("List of Activation Queues");
  
  $url = $ENV{SCRIPT_NAME};
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=oact_aq_add_form\">Add Activation Queue</a></b>]\n".CMU::WebInt::pageHelpLink(''));
  
  $res = oact_aq_print_queue($user, $dbh, $q, 
			     " 1 ",
			     $ENV{SCRIPT_NAME}, '', 'start');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# oact_aq_print_queue
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the subnet WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub oact_aq_print_queue {
  my ($user, $dbh, $q, $where, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : 
    CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'activation_queue', $where);

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
  $ruRef = CMU::Netdb::list_activation_queue
    ($dbh, $user, " $where ".CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_activation_queue: ".$errmeanings{$ruRef};
    return 0;
  }
  
  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
			      ['activation_queue.name'],
			      [], '', 'oact_aq_list', 'op=oact_aq_view&id=',
			      \%oact_aq_pos, 
			      \%CMU::Netdb::structure::activation_q_printable,
			      'activation_queue.name', 'activation_queue.id', '', []);
  return 1;
}

sub oact_aq_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res, $msg);
  
  $id = CMU::WebInt::gParam($q, 'id');
  $msg = $errors->{'msg'};
  $msg = "Activation Queue not specified!" if ($id eq '');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_aq_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Activation Queues", $errors);
  &CMU::WebInt::title("Activation Queue Information");
  
  $url = $ENV{SCRIPT_NAME};
  
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $sref = CMU::Netdb::list_activation_queue($dbh, $user, " activation_queue.id='$id' ");
  my @sdata = @{$sref->[1]};
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  my $version = $sdata[$oact_aq_pos{'activation_queue.version'}];
  print CMU::WebInt::subHeading("Information for: ".$sdata[$oact_aq_pos{'activation_queue.name'}], CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=$url?op=oact_aq_view&id=$id>Refresh</a></b>]
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=oact_aq_delete&id=$id&version=$version")."\">Delete Queue</a></b>]\n");
 
  # name
  print "<table border=0><form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=oact_aq_update>
<input type=hidden name=version value=\"$version\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $CMU::Netdb::structure::activation_q_printable{'activation_queue.name'}, 1, 'activation_queue.name').
  "</tr>";
  
  print "<tr><td>".CMU::WebInt::printVerbose('activation_queue.name', $verbose).
    $q->textfield(-name => 'name', -value => $sdata[$oact_aq_pos{'activation_queue.name'}], -size => length($sdata[$oact_aq_pos{'activation_queue.name'}])+5).
      "</td><td></tr>\n";
  
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n";
  
  print "</table></form>\n";
  
  print CMU::WebInt::subHeading("Buildings in this Queue", CMU::WebInt::pageHelpLink('building'));
  my $ssref = CMU::Netdb::list_buildings($dbh, $user, "building.activation_queue='$id'");
  
  if (!ref $ssref) {
    print "ERROR with list_buildings: ".$errmeanings{$ssref};
    print "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($ssref eq $CMU::Netdb::errcodes{EDB});
    return 0;
  }
  
  CMU::WebInt::generic_tprint($url, $ssref, 
			      ['building.name'], 
			      [\&oact_aq_cb_del_build],
			      $id, '', 'op=build_view&id=', 
			      \%CMU::WebInt::buildings::building_pos,
			      \%CMU::Netdb::structure::building_printable, 'building.name', 
			      'building.id', '', []);
  
  my $bref = CMU::Netdb::list_buildings_ref($dbh, $user, '');
  if (ref $bref) {
    my @bs = sort {$$bref{$a} cmp $$bref{$b}} keys %$bref;
    
    print "<br>".&CMU::WebInt::subHeading("Add Building to Queue");
    print "<table border=1><tr><td><form method=get>
<input type=hidden name=op value=oact_aq_add_build>
<input type=hidden name=id value=$id>";
    print $q->popup_menu(-name => 'b',
			 -values => \@bs,
			 -labels => $bref);
    print "<input type=submit value=\"Add Building\"></form></td></tr></table>\n";
  }
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# outlet activation, activation queue, callback, delete, building :)
sub oact_aq_cb_del_build {
  my ($url, $row, $edata) = @_;
  warn __FILE__, ':', __LINE__, ' :>'.
    "oact_aq_cb_del_build row: $row\n" if ($debug >= 2);
  return "Delete" if (!ref $row);
  my @rrow = @{$row};
  return "<a href=\"$url?op=oact_aq_del_build&id=$edata&b=".$rrow[$CMU::WebInt::buildings::building_pos{'building.id'}]."\">Delete</a>\n";
}

sub oact_aq_del_build {
  my ($q) = @_;
  my ($dbh, $res, $version, $id, %error, $url, $errfields);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'id'));
  my $b = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'b'));
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'activation_queue', $id);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('activation_queue', 'WRITE', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  my $bref = CMU::Netdb::list_buildings($dbh, $user, "building.id = '$b'");
  if (!ref $bref || !defined $bref->[1]) {
    my %errors;
    $errors{type} = 'ERR';
    $errors{code} = $bref;
    $errors{loc} = 'oact_aq_del_build';
    $errors{msg} = 'Error in list_buildings';
    $errors{fields} = 'b';
    oact_aq_view($q, \%errors);
    return;
  }
  
  my %fields = ('activation_queue' => 0);
  
  ($res, $errfields) = CMU::Netdb::modify_building($dbh, $user, 
						   $bref->[1]->[$CMU::WebInt::buildings::building_pos{'building.id'}],
						   $bref->[1]->[$CMU::WebInt::buildings::building_pos{'building.version'}], \%fields);
  
  if ($res != 1) {
    $error{msg} = "Error deleting activation queue from building: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'oact_aq_del_build';
    $error{code} = $res;
    $error{fields} = join(',', @$errfields);
  }else{
    $error{msg} = "Building removed from activation queue."
  }
  $dbh->disconnect();
  oact_aq_view($q, \%error);
}

sub oact_aq_add_build {
  my ($q) = @_;
  my ($dbh, $res, $version, $id, %error, $url, $errfields);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'id'));
  my $b = CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'b'));
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'activation_queue', $id);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('activation_queue', 'WRITE', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  my $bref = CMU::Netdb::list_buildings($dbh, $user, "building.building = '$b'");
  if (!ref $bref || !defined $bref->[1]) {
    my %errors;
    $errors{type} = 'ERR';
    $errors{code} = $bref;
    $errors{loc} = 'oact_aq_add_build';
    $errors{msg} = 'Error in list_buildings';
    $errors{fields} = 'b';
    oact_aq_view($q, \%errors);
    return;
  }
  
  my %fields = ('activation_queue' => $id);
  
  ($res, $errfields) = CMU::Netdb::modify_building($dbh, $user, 
						   $bref->[1]->[$CMU::WebInt::buildings::building_pos{'building.id'}],
						   $bref->[1]->[$CMU::WebInt::buildings::building_pos{'building.version'}], \%fields);
  
  if ($res != 1) {
    $error{msg} = "Error adding building to activation queue: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'oact_aq_add_build';
    $error{code} = $res;
    $error{fields} = join(',', @$errfields);
  }else{
    $error{msg} = "Building added to activation queue."
  }
  $dbh->disconnect();
  oact_aq_view($q, \%error);
}

sub oact_aq_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'activation_queue', $id);
  
  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Activation Queue", $errors);
    &CMU::WebInt::title("Update Activation Queue");
    CMU::WebInt::accessDenied('activation_queue', 'WRITE', $id, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  %fields = ('name' => CMU::WebInt::gParam($q, 'name'));
  
  my ($res, $errfields) = CMU::Netdb::modify_activation_queue($dbh, $user, $id, $version, \%fields);
  
  if ($res > 0) {
    $nerrors{'msg'} = "Updated activation queue.";
    $dbh->disconnect(); 
    &oact_aq_view($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{type} = 'ERR';
    $nerrors{loc} = 'oact_aq_update';
    $nerrors{code} = $res;
    $nerrors{fields} = join(',', @$errfields);
    $dbh->disconnect();
    &oact_aq_view($q, \%nerrors);
  }
  $dbh->disconnect();
}

sub oact_aq_delete {
  my ($q) = @_;
  my ($url, $msg, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('oact_aq_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Activation Queues", {});
  &CMU::WebInt::title('Delete Activation Queue');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'activation_queue', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('activation_queue', 'WRITE', $id, 1, $ul, 
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  my $sref = CMU::Netdb::list_activation_queue($dbh, $user, "activation_queue.id='$id'");
  if (!defined $sref->[1]) {
    print "<hr>Activation Queue not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following activation queue.\n";
  
  my @print_fields = ('activation_queue.name');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::activation_q_printable{$f}."</th>
<td>";
    print $sdata[$oact_aq_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=oact_aq_delete_conf&id=$id&version=$version")."\">
Yes, delete this activation queue";
  print "<br><a href=\"$url?op=oact_aq_list\">No, return to the activation queue list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub oact_aq_delete_conf {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'activation_queue', $id);
  
  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete activation_queue $id\n";
    $dbh->disconnect();
    oact_aq_view($q, \%errors);
    return;
  }
  
  my $fields;
  ($res, $fields) = CMU::Netdb::delete_activation_queue($dbh, $user, $id, $version);
  
  $dbh->disconnect;
  if ($res == 1) {
    oact_aq_list($q, {'msg' => "The activation queue was deleted."});
  }else{
    $errors{msg} = "Error while deleting activation queue: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{type} = 'ERR';
    $errors{loc} = 'oact_aq_delete_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    oact_aq_view($q, \%errors);
  }
  $dbh->disconnect();
}

sub oact_aq_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'activation_queue', 0);
  
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  CMU::WebInt::setHelpFile('oact_aq_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Activation Queue", $errors);
  &CMU::WebInt::title("Add an Activation Queue");
  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('activation_queue', 'ADD', 0, 1, $userlevel,
			      $user);
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
<input type=hidden name=op value=oact_aq_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $CMU::Netdb::structure::activation_q_printable{'activation_queue.name'}, 1, 'activation_queue.name')."</tr>".
  "<tr><td>".CMU::WebInt::printVerbose('activation_queue.name', $verbose).
    $q->textfield(-name => 'name')."</td><td>"."</td></tr>\n";
  
  print "</table>\n";
  print "<input type=submit value=\"Add Activation Queue\">\n";
  
  print &CMU::WebInt::stdftr($q);
  $dbh->disconnect();
  
}

sub oact_aq_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  %fields = ('name' => CMU::WebInt::gParam($q, 'name'));
  
  my ($res, $errfields) = CMU::Netdb::add_activation_queue($dbh, $user, \%fields);
  
  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added activation queue $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect();		# we use this for the insertid ..
    oact_aq_view($q, \%nerrors);
  }else{
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'oact_aq_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    oact_aq_add_form($q, \%nerrors);
  }
}

1;
