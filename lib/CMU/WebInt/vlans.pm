#   -*- perl -*-
#
# CMU::WebInt::vlans
# This module provides the vlan management interfaces.
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
# $Id: vlans.pm,v 1.14 2008/03/27 19:42:39 vitroth Exp $
#
#

package CMU::WebInt::vlans;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings $debug %vlan_p %vlan_pos
             %vlan_pres_pos %vlan_subnet_pres_pos);
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

@EXPORT = qw(vlans_main vlans_view vlan_add_form);

%vlan_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::vlan_fields)};
%vlan_pres_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::vlan_presence_fields)};
%vlan_subnet_pres_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::vlan_subnet_presence_subnetvlan_fields)};
%vlan_p = %CMU::Netdb::structure::vlan_printable;
%errmeanings = %CMU::Netdb::errors::errmeanings;
$debug = 0;

sub vlans_main {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('vlan_main');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "VLAN Admin", $errors);
  &CMU::WebInt::title("List of VLANs");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'vlan', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('vlan', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=vlan_add_form\">Add VLAN</a></b>] ".CMU::WebInt::pageHelpLink(''))
      if ($ul >= 9);

  print CMU::WebInt::errorDialog($url, $errors);

  my $vln = CMU::Netdb::list_vlans_ref($dbh, $user, '', 'vlan.name');
  if (ref $vln) {
    my @vlk = sort { $$vln{$a} cmp $$vln{$b} } keys %$vln;
    unshift(@vlk, '--select--');
    print "<form method=get>\n<input type=hidden name=op value=vlan_info>\n";
    print CMU::WebInt::smallRight($q->popup_menu(-name => 'vid',
						 -accesskey => 'v',
						 -values => \@vlk,
						 -labels => $vln) 
				  . "\n<input type=submit value=\"View Vlan\"></form>\n");

  } else {
    &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
			     'Error loading vlans (list_vlans_ref).', {});
  }


  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'vlan.name' if ($sort eq '');
  
  $res = vlans_print_vlan($user, $dbh, $q,
			      " vlan.id != 0 ".
                              CMU::Netdb::verify_orderby($sort), '',
			      $ENV{SCRIPT_NAME}, "op=vlan_main&sort=$sort", 'start');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# vlans_print_vlan
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the vlan WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub vlans_print_vlan {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'vlan', $cwhere);
  
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
  $ruRef = CMU::Netdb::list_vlans($dbh, $user, " $where ".
				    CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_vlans: ".$errmeanings{$ruRef};
    return 0;
  }

  my %vlan_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::vlan_fields)};

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['vlan.name', 'vlan.abbreviation', 'vlan.number'],
		 [], '',
		 'vlan_main', 'op=vlan_info&vid=',
		 \%vlan_pos, 
		 \%CMU::Netdb::structure::vlan_printable,
			      'vlan.name', 'vlan.id', 'sort', 
			      ['vlan.name', 'vlan.abbreviation', 'vlan.number']);
  
  return 1;
}

########################################################################
## vlans_view
##  -- Prints info about a vlan

sub vlans_view {
  my ($q, $errors) = @_;
  my ($dbh, $vid, $url, $res);

  $vid = CMU::WebInt::gParam($q, 'vid');
  $$errors{msg} = "VLAN ID not specified!" if ($vid eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('vlan_info');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "VLAN Admin", $errors);
  &CMU::WebInt::title("VLAN Information");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'vlan', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('vlan', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # basic vlan information (name, abbreviation,description) 
  my $sref = CMU::Netdb::list_vlans($dbh, $user, "vlan.id='$vid'");
  if (!ref $sref) {
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  if ($#$sref == 0) {
    print "The specified vlan ID does not exist.<br><br>\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  my @sdata = @{$sref->[1]};
  
  print CMU::WebInt::subHeading("Information for: ".$sdata[$vlan_pos{'vlan.name'}], CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=$url?op=vlan_info&vid=$vid>Refresh</a></b>] 
 [<b><a href=$url?op=prot_s3&table=vlan&tidType=1&tid=$vid>View/Update Protections</a></b>] 
 [<b><a href=$url?op=vlan_delete&vid=$vid>Delete VLAN</a></b>]");

  # name, abbreviation
  print "<table border=0><form method=get>
<input type=hidden name=vid value=$vid>
<input type=hidden name=op value=vlan_update>
<input type=hidden name=version value=\"".$sdata[$vlan_pos{'vlan.version'}]."\">
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $vlan_p{'vlan.name'}, 1, 'vlan.name').
  CMU::WebInt::printPossError(defined $errors->{'abbreviation'}, $vlan_p{'vlan.abbreviation'}, 1, 'vlan.abbreviation').
    "</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('vlan.name', $verbose).
  $q->textfield(-name => 'sname', -accesskey => 'v', -value => $sdata[$vlan_pos{'vlan.name'}]).
    "</td><td>".CMU::WebInt::printVerbose('vlan.abbreviation', $verbose).
      $q->textfield(-name => 'abbr', -accesskey => 'a',
		    -value => $sdata[$vlan_pos{'vlan.abbreviation'}])."</td></tr>\n";

  # number,description
  print "<tr>".
CMU::WebInt::printPossError(defined $errors->{'number'}, $vlan_p{'vlan.number'}, 1, 'vlan.number').
CMU::WebInt::printPossError(defined $errors->{'description'}, $vlan_p{'vlan.description'},1, 'vlan.description').
"</tr>";
  print "<tr><td>".CMU::WebInt::printVerbose('vlan.number', $verbose).
  $q->textfield(-name=> 'number', -accesskey => 'n',
		-value=>$sdata[$vlan_pos{'vlan.number'}])."</td><td>".
  CMU::WebInt::printVerbose('vlan.description', $verbose).
  $q->textfield(-name=> 'description', -accesskey => 'e',
	        -value=> $sdata[$vlan_pos{'vlan.description'}])."</td></tr>\n";

  # Last update
  if (0) {
      print "<tr>".CMU::WebInt::printPossError(0, $vlan_p{'vlan.version'}).
	  "</tr><tr><td>";
      $sdata[$vlan_pos{'vlan.version'}] =~ /(....)(..)(..)(..)(..)(..)/;
      my $LU = "$1-$2-$3 $4:$5:$6\n";
      
      print "$LU</td></tr>\n";
  }

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n";
  
  print "</table></form>\n";

  ## vlan_presence in trunk-set
  my ($confres, $ETS) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_TRUNK_SET');
  my ($bref, $pref);
  if ($confres == 1 && $ETS == 1) {
    print CMU::WebInt::subHeading("Trunk Set Membership",CMU::WebInt::pageHelpLink(''));
    $pref = CMU::Netdb::list_trunkset_presences($dbh,$user,'vlan',"vlan='$vid'");
    $bref = CMU::Netdb::list_trunkset_ref($dbh,$user, '','trunk_set.name');
    $$bref{'##q--'}	= $q;
    $$bref{'##vid--'}	= $vid;
    $$bref{'##type--'} 	= 'vlan';
    CMU::WebInt::generic_smTable($url,$pref,['trunk_set.name'],
				 \%CMU::WebInt::trunkset::ts_vlan_tsv_pos,
				 \%CMU::Netdb::structure::trunkset_vlan_presence_ts_vlan_printable,
				 "vid=$vid",'trunkset_vlan_presence','ts_del_member',
				 \&CMU::WebInt::trunkset::trunkset_cb_add_presence,
				 $bref,'trunkset_vlan_presence.trunk_set',"op=trunkset_info&tid=");
  }

  ## vlan_presence in subnets
  print CMU::WebInt::subHeading("Subnets in this VLAN",CMU::WebInt::pageHelpLink(''));
  $pref = CMU::Netdb::list_subnet_presences($dbh, $user, "vlan_subnet_presence.vlan='$vid'");
  $bref = CMU::Netdb::list_subnets_ref($dbh, $user,'','subnet.name');

  $$bref{'##q--'} 	= $q;
  $$bref{'##vid--'} 	= $vid;
  $$bref{'##back--'} 	= 'vlan';
  CMU::WebInt::generic_smTable($url,$pref,['subnet.name'],
				\%vlan_subnet_pres_pos,
				\%CMU::Netdb::structure::vlan_subnet_presence_subnetvlan_printable,
				"vid=$vid",'vlan_subnet_presence','sub_del_pres',
				\&CMU::WebInt::subnets::subnets_cb_add_presence,
				$bref, 'vlan_subnet_presence.subnet', "op=sub_info&sid=");

  ## Service Groups
  if(0) {
      my $servicequery = "service_membership.member_type = 'vlan' AND ".
	"service_membership.member_tid = '$vid'";

      my ($lsmr, $rMemRow, $rMemSum, $rMemData) =
	CMU::Netdb::list_service_members($dbh, 'netreg', $servicequery);

      if ($lsmr < 0) {
	print "Unable to list Service Groups ($lsmr).\n";
	&CMU::WebInt::admin_mail('vlans.pm:vlan_view', 'WARNING',
				 'Unable to list Service Groups ($lsmr).',
				 { 'id' => $vid});
      }else {
	print "<br>" . CMU::WebInt::subHeading("Service Groups","");
	print CMU::WebInt::printVerbose('vlan_view.service_groups');

	my @data = map {
	  ["<a href=\"$url?op=svc_info&sid=".$rMemRow->{$_}->{'service.id'}."\">".
	   $rMemRow->{$_}->{'service.name'}."</a>", $rMemRow->{$_}->{'service_membership.id'},
	   $rMemRow->{$_}->{'service_membership.version'}];
	} keys %$rMemRow;
	unshift(@data, ['service.name']);
	my $gsrr = CMU::Netdb::get_services_ref($dbh, $user, '', 'service.name');
	my %printable = (%CMU::Netdb::structure::vlans_printable, %CMU::Netdb::structure::service_printable);
	$$gsrr{'##q--'} = $q;
	$$gsrr{'##mid--'} = $vid;
	CMU::WebInt::generic_smTable($url, \@data, ['service.name'],
				     {'service.name' => 0,
				      'service_membership.id' => 1,
				      'service_membership.version' => 2},
				     \%printable,
				     "vid=$vid&back=vlan", 'service_membership', 'svc_del_member',
				     \&CMU::WebInt::vlans::cb_vlan_add_service,
				     $gsrr);
      }
  }
  print "<br>";
  CMU::WebInt::attr_display($dbh, $user, 'vlan', $vid);;
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


sub cb_vlan_add_service {
  my ($sref) = @_;
  my $q = $$sref{'##q--'}; delete $$sref{'##q--'};
  my $id = $$sref{'##mid--'}; delete $$sref{'##mid--'};
  my $res = "<tr><td><form method=get>
<input type=hidden name=op value=svc_add_member>
<input type=hidden name=vlan value=$id>
<input type=hidden name=id value=$id>
<input type=hidden name=back value=vlan>\n";
  my @ss = sort {$sref->{$a} cmp $sref->{$b}} keys %$sref;
  $res .= $q->popup_menu(-name=>'sid',
                         -values=>\@ss,
                         -labels=> $sref);
  $res .= "</td><td>\n<input type=submit value=\"Add to Service Group\"></form></td></tr>\n";

}

sub vlans_cb_add_presence {
  my ($bref) = @_;
  my $q = $$bref{'##q--'}; delete $$bref{'##q--'};
  my $vid = $$bref{'##vid--'}; delete $$bref{'##vid--'};
  my $back = $$bref{'##back--'}; delete $$bref{'##back--'};
  my $build = $$bref{'##build--'}; delete $$bref{'##build--'};
  my $id = $$bref{'##id--'}; delete $$bref{'##id--'};

  my @bs = sort {$bref->{$a} cmp $bref->{$b}} keys %$bref;

  if ($back ne 'build') {
    my $res = "<tr><td><form method=get>
<input type=hidden name=op value=ts_add_member1>
<input type=hidden name=id value=$id>
"; 
    
    $res .= $q->popup_menu(-name => 'bid',
			   -values => \@bs,
			   -labels => $bref);
    $res .= "
<input type=submit value=\"Add Building\"></form></td></tr>
";
    return $res;
  }else{
    my $res = "<tr><td><form method=get>
<input type=hidden name=op value=ts_add_member1>
<input type=hidden name=tid value=$build>
<input type=hidden name=back value=trunkset>
<input type=hidden name=id value=$id>
"; 
    
    $res .= $q->popup_menu(-name => 'vid',
			   -values => \@bs,
			   -labels => $bref);
    $res .= "
<input type=submit value=\"Add VLAN\"></form></td></tr>
";
    return $res;
  }
}

sub vlans_delete {
  my ($q) = @_;
  my ($dbh, $where, $vid, $url, $res);

  $vid = CMU::WebInt::gParam($q, 'vid');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('vlan_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "VLAN Admin", {});
  &CMU::WebInt::title("Delete VLAN");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'vlan', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('vlan', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  
  $where = " vlan.id=$vid ";

  # basic vlan information (name, abbreviation, number)
  my $sref = CMU::Netdb::list_vlans($dbh, $user, "vlan.id='$vid'");
  my @sdata = @{$sref->[1]};
  
  print CMU::WebInt::subHeading("Confirm Deletion of: ".$sdata[$vlan_pos{'vlan.name'}]);
  print "Please confirm that you wish to delete the following VLAN.";
  print "<br>Clicking \"Delete VLAN\" below will cause this VLAN and all ".
    "associated information to be deleted.\n";
  
  print "<table border=0>
<tr><td bgcolor=lightyellow>Name</td><td>$sdata[$vlan_pos{'vlan.name'}]</td></tr>
<tr><td bgcolor=lightyellow>Abbreviation</td><td>$sdata[$vlan_pos{'vlan.abbreviation'}]</td></tr>
<tr><td bgcolor=lightyellow>Number</td><td>$sdata[$vlan_pos{'vlan.number'}]</td></tr>
</table>
<form method=get>
<input type=hidden name=op value=vlan_del_conf>
<input type=hidden name=vid value=$vid>
<input type=hidden name=version value=\"".$sdata[$vlan_pos{'vlan.version'}]."\">
<input type=submit value=\"Delete VLAN\">
</form>
";
  $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);


}

sub vlans_deleteConfirm {
  my ($q) = @_;
  my ($dbh, $id, $version);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::WebInt::gParam($q, 'vid');
  $version = CMU::WebInt::gParam($q, 'version');
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'vlan', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('vlan', 'WRITE', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my ($res, $ref) = CMU::Netdb::delete_vlan($dbh, $user, $id, $version);
  my %errors;
  if ($res != 1) {
    $errors{msg} = "Error deleting VLAN: ".$errmeanings{$res}." [".
      join(',', @$ref)."] ";

    $errors{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $errors{type} = 'ERR';
    $errors{loc} = 'vlan_del_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$ref);
  }else{
    $errors{msg} = "VLAN deleted.";
  }
  
  $dbh->disconnect();
  CMU::WebInt::vlans_main($q, \%errors);
}

sub vlans_update {
  my ($q) = @_;
  my ($dbh, $version, $id, %fields, %error);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'version');
  $id = CMU::WebInt::gParam($q, 'vid');
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'vlan', $id);
  if ($ul < 9) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "VLAN Update",{});
    &CMU::WebInt::title("Update Error");
    CMU::WebInt::accessDenied('vlan', 'WRITE', $id, 9, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  %fields = ('name' => CMU::WebInt::gParam($q, 'sname'),
	     'abbreviation' => CMU::WebInt::gParam($q, 'abbr'),
	     'number' => CMU::WebInt::gParam($q, 'number')
  );
  
  my ($res, $field) = CMU::Netdb::modify_vlan($dbh, $user, $id, $version, \%fields);
  if ($res >= 1) {
    $error{msg} = "VLAN information has been updated.";
  }else{
    $error{msg} = "Error updating VLAN information: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'vlan_upd';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
    $error{$field} = 1;
  }
  $dbh->disconnect();
  CMU::WebInt::vlans_view($q, \%error);
}

#####################################################################
## Add/delete building from a vlan
##

sub vlans_del_presence {
  my ($q) = @_;
  my ($dbh, $res, $version, $id, $vid, %error, $url, $errfields);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'v');
  $id = CMU::WebInt::gParam($q, 'id');
  $vid = CMU::WebInt::gParam($q, 'vid');
  
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'vlan', $vid);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('vlan', 'WRITE', $vid, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $type = 'vlan';
  
  #($res, $errfields) = CMU::Netdb::delete_vlan_presence($dbh, $user, $id, $version);
  ($res, $errfields) = CMU::Netdb::delete_trunkset_presence($dbh, $user, $type, $id, $version);
  if ($res != 1) {
    $error{msg} = "Error deleting trunkset presence from vlan: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'vlan_del_presence';
    $error{code} = $res;
    $error{fields} = join(',', @$errfields);
  }else{
    $error{msg} = "Trunk Set presence deleted from the vlan.";
  }
  $dbh->disconnect();
#  if (CMU::WebInt::gParam($q, 'bid') ne '') {
#    $q->param('id', CMU::WebInt::gParam($q, 'bid'));
#    CMU::WebInt::build_view($q, \%error);
#  }else{
#    CMU::WebInt::vlans_view($q, \%error);
#  }

  $q->param('tid', $vid);
  CMU::WebInt::trunkset_view($q,\%error);
}
    
sub vlans_add_presence {
  my ($q) = @_;
  my (%fields, $res, %error, $dbh, $ref, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  %fields = ('vlan' => CMU::WebInt::gParam($q, 'vid'),
	     'trunk_set' => CMU::WebInt::gParam($q, 'id'),
	     'type' => 'vlan');

  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'vlan', $fields{vlan});
  if ($userlevel == 0) {
    CMU::WebInt::accessDenied('vlan', 'WRITE', $fields{'vlan'}, 1, $userlevel,
			      $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  
  #($res, $ref) = CMU::Netdb::add_vlan_presence($dbh, $user, \%fields);
  ($res, $ref) = CMU::Netdb::add_trunkset_presence($dbh, $user, \%fields);
  if ($res != 1) {
    $error{msg} = "Error adding building presence to vlan: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{msg} .= " [".join(',', @$ref)."] ";
    $error{type} = 'ERR';
    $error{loc} = 'vlan_add_presence';
    $error{code} = $res;
    $error{fields} = join(',', @$ref);
  }else{
    $error{msg} = "Building $fields{building} added to the vlan.";
  }
  $dbh->disconnect();

#  if (CMU::WebInt::gParam($q, 'back') eq 'build') {
#    CMU::WebInt::build_view($q, \%error);
#  }else{
#    CMU::WebInt::vlans_view($q, \%error);
#  }

  $q->param('tid', CMU::WebInt::gParam($q,'id'));
  CMU::WebInt::trunkset_view($q, \%error);
}

sub vlan_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'vlan', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('vlan_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "VLAN Admin", $errors);
  &CMU::WebInt::title("Add a VLAN");

  print CMU::WebInt::errorDialog($url, $errors);

  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('vlan', 'ADD', 0, 1, $userlevel, $user);
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
<input type=hidden name=op value=vlan_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $vlan_p{'vlan.name'}, 1, 'vlan.name').
  CMU::WebInt::printPossError(defined $errors{abbreviation}, $vlan_p{'vlan.abbreviation'}, 1, 'vlan.abbreviation')."</tr>
<tr><td>".CMU::WebInt::printVerbose('vlan.name', $verbose).
  $q->textfield(-name => 'name', -accesskey => 'v')."</td><td>".CMU::WebInt::printVerbose('vlan.abbreviation', $verbose).
  $q->textfield(-name => 'abbreviation',  -accesskey => 'a')."</td></tr>\n";

  # number,description 
  print "
<tr>".CMU::WebInt::printPossError(defined $errors{number}, $vlan_p{'vlan.number'}, 1, '	vlan.number').
      CMU::WebInt::printPossError(defined $errors{description}, $vlan_p{'vlan.description'}, 1, 'vlan.description').
		   "</tr><tr><td>".CMU::WebInt::printVerbose('vlan.number', $verbose).
		     $q->textfield(-name => 'number', -accesskey => 'n').
		     "</td><td>&nbsp;".CMU::WebInt::printVerbose('vlan.description', $verbose).
		     $q->textfield(-name => 'description' , -accesskey => 'e').
		     "</td><td>&nbsp;</td></tr>\n";

  print "</table>\n";
  print "<input type=submit value=\"Add VLAN\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub vlan_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'vlan', 0);
  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "VLANSs", $errors);
    &CMU::WebInt::title("Add VLAN");
    CMU::WebInt::accessDenied('vlan', 'ADD', 0, 1, $userlevel, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  
  foreach (qw/name abbreviation number description/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }

  my ($res, $errfields) = CMU::Netdb::add_vlan($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added VLAN.";
    $q->param('vid', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    &CMU::WebInt::vlans_view($q, \%nerrors);
  }else{
    if ($res <= 0) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." )" 
	if ($res == $CMU::Netdb::errcodes{EDB});
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'vlans_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    &CMU::WebInt::vlan_add_form($q, \%nerrors);
  }
}

1;
