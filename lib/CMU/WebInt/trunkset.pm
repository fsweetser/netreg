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
# $ID$
# $Log: trunkset.pm,v $
# Revision 1.14  2008/03/27 19:42:38  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.13.8.2  2008/02/06 20:17:46  vitroth
# Added quick access popup menu links on the list view pages
#
# Revision 1.13.8.1  2007/10/11 20:59:43  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.13.6.1  2007/09/20 18:43:06  kevinm
# Committing all local changes to CVS repository
#
#
# Revision 1.13  2006/08/03 01:37:56  vitroth
# In all cases where a version is used in an input field the value needs
# to be quoted since it may contain spaces (mysql 4.1)
#
# Revision 1.7  2005/08/14 19:57:10  kcmiller
# * Syncing to mainline
#
# Revision 1.12.6.1  2005/08/14 19:56:49  kevinm
# * Make accessDenied more informative
#
# Revision 1.12  2005/06/29 22:04:31  fes
# Back out changes that missed the branch and hit HEAD
#
# Revision 1.10  2005/02/10 15:32:05  vitroth
# Handle error result from list_trunkset_presence correctly.
# Error pointed out by Brian Dowling.
#
# Revision 1.9  2005/01/07 17:25:14  vitroth
# Call get_add_level on the trunkset, not on the presence table.
#
# Revision 1.8  2004/11/03 18:48:59  vitroth
# Typo on trunkset deletion page.
#
# Revision 1.7  2004/08/02 14:48:12  vitroth
# Added vlan number to vlan list on trunkset page.
#
# Revision 1.6  2004/07/12 12:09:30  vitroth
# Various changes to make the UI better with respect to lists of devices
# (outlets, trunkset memberships, activations).  The device list is now
# sorted in all locations.
#
# Revision 1.5  2004/05/24 19:15:46  kevinm
# * Eliminate warnings about multiply defined variables
#
# Revision 1.4  2004/05/12 02:12:39  ktrivedi
# trunkset_xxx_presence_ts_xxx_{field,presence} used.
#
# Revision 1.3  2004/05/11 02:12:37  ktrivedi
# trunkset_cb_add_presence handles machine_info
#
# Revision 1.2  2004/03/25 20:14:25  kevinm
# * Merging netdb-layer2-branch2
#
# Revision 1.1.4.4  2004/03/19 06:11:50  ktrivedi
# Bug in permission for 'Add Trunk Set' ($ul < 9) instead of ($ul >= 9)
#
# Revision 1.1.4.3  2004/03/14 21:49:23  ktrivedi
# cosmetic changes and bug fixes
#
# Revision 1.1.4.2  2004/03/01 03:34:39  ktrivedi
# popup_menu in primary_vlan
#
# Revision 1.1.4.1  2004/02/25 19:33:52  kevinm
# * Merging layer2 changes
#
# Revision 1.1.2.6  2003/12/31 19:43:33  ktrivedi
# Num(Dev) > 10, then 'click here' link
#
# Revision 1.1.2.5  2003/12/31 05:15:09  ktrivedi
# Bug fix for Building presence in TS (calling list_buildingID_ref instead
# list_buildings_ref)
#
# Revision 1.1.2.4  2003/12/08 22:01:28  ktrivedi
# Added primary_vlan on 'Add-Vlan' page.
#
# Revision 1.1.2.3  2003/12/08 21:50:32  ktrivedi
# Added update function
#
# Revision 1.1.2.2  2003/11/30 02:34:06  ktrivedi
# Now, properly adding vlan and device in trunkset_presence. Supporting functions.
#
# Revision 1.1.2.1  2003/11/27 06:58:54  ktrivedi
# TrunkSet Mgmt.
#
#

package CMU::WebInt::trunkset;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %ts_pos %ts_p %ts_vlan_pos %ts_building_pos %ts_device_pos 
	     %ts_vlan_tsv_pos %ts_building_tsb_pos %ts_device_tsd_pos %ts_mem_p $debug %vlan_pos 
	     %errmeanings);

use CMU::WebInt;
use CMU::Netdb;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw/trunkset_main trunkset_mgmt trunkset_view trunkset_add_membership
	     trunkset_del_membership/;

$debug = 0;
%ts_pos 	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunk_set_fields)};
%ts_building_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunkset_building_presence_fields)};
%ts_device_pos   = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunkset_machine_presence_fields)};
%ts_vlan_pos 	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunkset_vlan_presence_fields)};

%ts_p   	= %CMU::Netdb::structure::trunk_set_printable;
%ts_building_tsb_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunkset_building_presence_ts_building_fields)};
%ts_vlan_tsv_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunkset_vlan_presence_ts_vlan_fields)};
%ts_device_tsd_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunkset_machine_presence_ts_machine_fields)};

%ts_mem_p 	= %CMU::Netdb::structure::trunkset_members_printable;

%errmeanings 	= %CMU::Netdb::errors::errmeanings;
%vlan_pos 	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::vlan_fields)};

# trunkset_main
# Arguments:
#	- CGI handle
#	- Errors hash reference
# Returns:
#	- none
# Check user privileges and if succeded, calls trunkset_print.
sub trunkset_main {
    my ($q, $errors) = @_;
    my ($dbh, $res, $url, $sort);
    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    CMU::WebInt::setHelpFile('trunkset_main');
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", $errors);
    &CMU::WebInt::title("List of Trunk Sets");

    $url = $ENV{SCRIPT_NAME};
    my $ul = CMU::Netdb::get_read_level($dbh, $user, 'trunk_set', 0);
    if ($ul == 0) {
	print &CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", $errors);
	&CMU::WebInt::title("Read Error");
	CMU::WebInt::accessDenied('trunk_set', 'READ', 0, 1, 0, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect;
	return;
    }

    print CMU::WebInt::smallRight("[<b><a href=\"$url?op=trunkset_mgmt\">Add Trunk Set</a></b>] ".
	  CMU::WebInt::pageHelpLink('')) if ($ul >= 9);

    print CMU::WebInt::errorDialog($url, $errors);

    my $tst = CMU::Netdb::list_trunkset_ref($dbh, $user, '', 'trunk_set.name');
    if (ref $tst) {
        my @tsk = sort { $$tst{$a} cmp $$tst{$b} } keys %$tst;
        unshift(@tsk, '--select--');
        print "<form method=get>\n<input type=hidden name=op value=trunkset_info>\n";
        print CMU::WebInt::smallRight($q->popup_menu(-name => 'tid',
                                                     -accesskey => 't',
                                                     -values => \@tsk,
                                                     -labels => $tst) 
                                      . "\n<input type=submit value=\"View Trunkset\"></form>\n");

    } else {
        &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
                                 'Error loading trunksets (list_trunkset_ref).', {});
    }


    $sort = CMU::WebInt::gParam($q, 'sort');
    $sort = 'trunk_set.name' if ($sort eq '');
  
    $res = trunkset_print($user, $dbh, $q,
			      " trunk_set.id != 0 ".
			      CMU::Netdb::verify_orderby($sort), '',
			      $ENV{SCRIPT_NAME}, "op=trunkset_main&sort=$sort", 'start');
  
    print "ERROR: ".$errmeanings{$res} if ($res <= 0);

    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
}

# trunkset_print 
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the vlan WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
# List all existing trunk-set in database.
sub trunkset_print {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'trunk_set', $cwhere);
  
  return $ctRow if (!ref $ctRow);

  $defitems = $CMU::WebInt::config::DEF_ITEMS_PER_PAGE;

  print &CMU::WebInt::pager_Top($start, $$ctRow[0], $defitems,
		   $CMU::WebInt::config::DEF_MAX_PAGES, 
		   $url, $oData, $skey);
  $where = "1" if ($where eq '');
  $ruRef = CMU::Netdb::list_trunkset($dbh, $user, " $where ".
				    CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_trunkset: ".$errmeanings{$ruRef};
    return 0;
  }

  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['trunk_set.name', 'trunk_set.abbreviation'],
		 [], '',
		 'trunkset_main', 'op=trunkset_info&tid=',
		 \%ts_pos, 
		 \%ts_p,
		'trunk_set.name', 'trunk_set.id', 'sort', 
		['trunk_set.name', 'trunk_set.abbreviation']);
  
  return 1;
}

# trunkset_mgmt
# Arguments:
#	- database handle
#	- Error hash reference
# Returns:
#	- none
# Performs adding of new trunkset(Name and Abbreviation). 
sub trunkset_mgmt {
    my ($q, $errors) = @_;
    my ($dbh, $res, $url, $sort, $vlref, $userlevel, $defvlan, @vlarr, %errors);

    $dbh = CMU::WebInt::db_connect();
    my ($user,$p, $r) = CMU::WebInt::getUserInfo();
    $userlevel = CMU::Netdb::get_write_level($dbh,$user,'trunk_set',0);

    $url = $ENV{SCRIPT_NAME};
    %errors = %{$errors} if defined ($errors);
    
    CMU::WebInt::setHelpFile('trunkset_mgmt');
    print CMU::WebInt::stdhdr($q,$dbh, $user, "Trunk Set Admin", $errors);
    &CMU::WebInt::title("Add Trunk Set");

    print CMU::WebInt::errorDialog($url,$errors);

    if ($userlevel < 1) {
	CMU::WebInt::accessDenied('trunk_set', 'WRITE', 0, 1, $userlevel, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    my $verbose = CMU::WebInt::gParam($q,'bmvm');
    $verbose = 1 if ($verbose ne '0');

    print "<hr>Enter the name of the trunk set, its abbreviation, a description of the set, ".
	"and the native vlan for the trunk set.  After you succesfully add the trunk set ".
	"you will be able to add vlan, building, and device information to the trunk set. ".
	"<br>";

    $vlref = CMU::Netdb::list_vlans_ref($dbh, $user, '', 'vlan.name');
    @vlarr = sort {$vlref->{$a} cmp $vlref->{$b}} keys %$vlref;
    unshift @vlarr , 0;
    $vlref->{0} = "No Primary VLAN";
    $defvlan = 0;

    my $prVal = "<form method=get>".
		"<input type=hidden name=op value=trunkset_add>
		 <table border=0>";

    ### trunk-set name, abbr, description
    $prVal .= 	"<tr>".CMU::WebInt::printPossError(defined $errors{name},
						  $ts_p{'trunk_set.name'},1,"trunk_set.name").
		CMU::WebInt::printPossError(defined $errors{abbreviation},
					    $ts_p{'trunk_set.abbreviation'},1,"trunk_set.abbreviation").
		"</tr>";
    $prVal .= 	"<tr><td>".CMU::WebInt::printVerbose('trunk_set.name',$verbose).
		$q->textfield(-name => 'name', -accesskey => 't'). "</td>".
		"<td>".CMU::WebInt::printVerbose('trunk_set.abbreviation',$verbose).
		$q->textfield(-name => 'abbreviation', -accesskey => 'a')."</td></tr>\n";

    $prVal .=   "<tr>".CMU::WebInt::printPossError(defined $errors->{'description'}, 
		$ts_p{'trunk_set.description'},1, 'trunk_set.description').
		CMU::WebInt::printPossError(defined $errors->{'primary_vlan'},
		$ts_p{'trunk_set.primary_vlan'},1,'trunk_set.primary_vlan')."</tr>";
    $prVal .= 	"<tr><td>".CMU::WebInt::printVerbose('trunk_set.description', $verbose).
		$q->textfield(-name => 'description', -accesskey => 'e')."</td><td>".
		$q->popup_menu(-name => 'primary_vlan', -values => \@vlarr, -default => $defvlan, -labels => $vlref)."</td></tr>\n";
    $prVal .=	"</table>\n";

    print $prVal;
    
    print "<tr><td><input type=submit value=\"Add Trunk Set\"></td></tr>\n";

    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
}

# trunkset_add
# Arguments:
#	- CGI handle
#	- Errors hash reference
# Returns:
#	- none
# Calls Netdb::add_trunkset and add new trunk_set. If
# successfull it will jump to trunkset_view.
sub trunkset_add {
    my ($q, $errors) = @_;
    my ($dbh, %fields, %nerrors, $userlevel, $addret);

    $dbh = CMU::WebInt::db_connect();
    my ($user,$p,$r) = CMU::WebInt::getUserInfo();
    $userlevel = CMU::Netdb::get_write_level($dbh,$user,'trunk_set',0);

    if ($userlevel < 1) {
	print &CMU::WebInt::stdhdr($q,$dbh,$user,"Trunk Set",$errors);
	&CMU::WebInt::title("Add Trunk Set");
	CMU::WebInt::accessDenied('trunk_set', 'WRITE', 0, 1, 
				  $userlevel, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    foreach (qw/name abbreviation description primary_vlan/) {
	$fields{$_} = CMU::WebInt::gParam($q,$_);
    }

    my ($res, $errfields) = CMU::Netdb::add_trunkset($dbh,$user,\%fields);

    if ($res > 0) {
	my %warns = %$errfields;
	$nerrors{'msg'} = "Added Trunk Set.";
	$q->param('tid',$warns{insertID});
	$dbh->disconnect();
	&CMU::WebInt::trunkset_view($q,\%nerrors);
    } else {
	if ($res <= 0) {
	    map {$nerrors{$_} = 1} @$errfields if ($res <= 0);
	    $nerrors{'msg'} .= $errmeanings{$res};
	    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
	    $nerrors{'msg'} .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." )" 
	      if ($res == $CMU::Netdb::errcodes{EDB});
	    $nerrors{type} = 'ERR';
	    $nerrors{loc} = 'trunkset_add';
	    $nerrors{code} = $res;
	    $nerrors{fields} = join(',', @$errfields);
	}
	$dbh->disconnect();
	&CMU::WebInt::trunkset_add_form($q,\%nerrors);
    }
}

# trunkset_view
# Arguments:
#	- CGI handle
#	- Errors hash reference
# Returns:
#	- none
# Shows trunk_set.name and trunk_set.abbreviation. It
# also shows members of this trunk_set i.e. vlan, building
# and device.
sub trunkset_view {
    my ($q, $errors) = @_;
    my ($dbh, $tid, $url, $res, $userlevel, $pvlan, $vlref, @vlarr);

    $tid = CMU::WebInt::gParam($q, 'tid');
    $$errors{msg} = "Trunk Set ID not specified!" if ($tid eq '');

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    CMU::WebInt::setHelpFile('trunkset_info');
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", $errors);
    &CMU::WebInt::title("Trunk Set Information");

    $url = $ENV{SCRIPT_NAME};
    $userlevel = CMU::Netdb::get_read_level($dbh, $user, 'trunk_set', 0);
    if ($userlevel == 0) {
	CMU::WebInt::accessDenied('trunk_set', 'READ', 0, 1, 0, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    my $verbose = CMU::WebInt::gParam($q, 'bmvm');
    $verbose = 1 if ($verbose ne '0');

    print "<hr>";
    print CMU::WebInt::errorDialog($url, $errors);
  
    ## basic trunk-set information (name, abbreviation)
    my $sref = CMU::Netdb::list_trunkset($dbh, $user, "trunk_set.id='$tid'");
    if (!ref $sref) {
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }
    if ($#$sref == 0) {
	print "The specified Trunk Set ID does not exist.<br><br>\n";
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }
    my @sdata = @{$sref->[1]};

    print CMU::WebInt::subHeading("Information for: ".$sdata[$ts_pos{'trunk_set.name'}], 
				    CMU::WebInt::pageHelpLink(''));
    print CMU::WebInt::smallRight("[<b><a href=$url?op=trunkset_info&tid=$tid>Refresh</a></b>] 
	[<b><a href=$url?op=prot_s3&table=trunk_set&tidType=1&tid=$tid>View/Update Protections</a></b>] 
	[<b><a href=$url?op=trunkset_del&tid=$tid>Delete Trunk Set</a></b>]");

    ## name,abbreviation
    print "<table border=0><form method=get>
	<input type=hidden name=tid value=$tid>
	<input type=hidden name=op value=trunkset_update>
        <input type=hidden name=version value=\"".$sdata[$ts_pos{'trunk_set.version'}]."\">
	<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $ts_p{'trunk_set.name'}, 1, 'trunk_set.name').
	CMU::WebInt::printPossError(defined $errors->{'abbreviation'}, $ts_p{'trunk_set.abbreviation'},1,
		'trunk_set.abbreviation')."</tr>";

    print "<tr><td>".CMU::WebInt::printVerbose('trunk_set.name', $verbose).
    $q->textfield(-name => 'uname', -accesskey => 't', -value => $sdata[$ts_pos{'trunk_set.name'}])."</td>".
    "<td>".CMU::WebInt::printVerbose('trunk_set.abbreviation',$verbose).
    $q->textfield(-name => 'abbr', -accesskey => 'a', -value => $sdata[$ts_pos{'trunk_set.abbreviation'}]).
		    "</td></tr>\n";
    ## description, primary_vlan
    $vlref = CMU::Netdb::list_vlans_ref($dbh, $user, '', 'vlan.name');
    @vlarr = sort {$vlref->{$a} cmp $vlref->{$b}} keys %$vlref;
    if ($sdata[$ts_pos{'trunk_set.primary_vlan'}] == 0) {
	unshift @vlarr, 0;
	$vlref->{0} = "Unspecified Primary VLAN";
	$pvlan = 0;
    } else {
	$pvlan = $sdata[$ts_pos{'trunk_set.primary_vlan'}];
    }
    print "<tr>".CMU::WebInt::printPossError(defined $errors->{'description'}, $ts_p{'trunk_set.description'},1, 'trunk_set.description').CMU::WebInt::printPossError(defined $errors->{'primary_vlan'}, $ts_p{'trunk_set.primary_vlan'},1,'trunk_set.primary_vlan')."</tr>";
    print "<tr><td>".CMU::WebInt::printVerbose('trunk_set.description', $verbose).
	$q->textfield(-name => 'description', -accesskey => 'e', -value => $sdata[$ts_pos{'trunk_set.description'}]).
	"</td><td>".$q->popup_menu(-name => 'primary_vlan', -values => \@vlarr, -default => $pvlan, -labels => $vlref)."</td></tr>\n";

    ## Last update
    if (0) {
	print "<tr>".CMU::WebInt::printPossError(0, $ts_p{'trunk_set.version'}).
	  "</tr><tr><td>";
	$sdata[$ts_pos{'trunk_set.version'}] =~ /(....)(..)(..)(..)(..)(..)/;
	my $LU = "$1-$2-$3 $4:$5:$6\n";
	print "$LU</td></tr>\n";
    }
  
    ## Update button
    print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n";
    print "</table></form>\n";

    ## Device Presence
    print CMU::WebInt::subHeading("Device in Trunk Set", CMU::WebInt::pageHelpLink('device_presence'));
    my $ViewAllDev = (CMU::WebInt::gParam($q,'VAD') eq '1' ? 1 : 0);
    my $pref = CMU::Netdb::list_trunkset_presences($dbh,$user, 'machine',
					"trunkset_machine_presence.trunk_set='$sdata[$ts_pos{'trunk_set.id'}]' ORDER BY machine.host_name ASC");

    if (!ref $pref) {
        print errorDialog($url, { 'msg' => "Error fetching devices in this trunkset", 'code' => $pref, 'type' => 'ERR' });
    } elsif ($#$pref > 10 && !($ViewAllDev || (CMU::WebInt::gParam($q,'op') eq 'ts_del_member1'))) {
        print "More than 10 Devices in this Trunk Set. <a href=\"$url?op=trunkset_view&tid=$tid&VAD=1\">Click here</a> to view all devices.<br><br>\n";
    } else {
	CMU::WebInt::generic_smTable($url, $pref, ['machine.host_name'],
				    \%ts_device_tsd_pos,
				    \%CMU::Netdb::structure::trunkset_machine_presence_ts_machine_printable,
				    "mid=$tid",'trunkset_machine_presence','ts_del_member1',
				    '','', 'trunkset_machine_presence.device', "op=mach_view&id=");
	my $devAdd = "<form method=get>
	    <input type=hidden name=op value=device_add_pres>
	    <input type=hidden name=tid value=$tid>
	    ";
	$devAdd .= "<input accesskey=d type=text name=device>&nbsp;"; 
	$devAdd .= "
	    <input type=submit value=\"Add Device\"></form>
	    ";
	print $devAdd;
    }

    ## VLAN Presence
    print CMU::WebInt::subHeading("VLANs in Trunk Set", CMU::WebInt::pageHelpLink('vlan_presence'));
    $pref = CMU::Netdb::list_trunkset_presences($dbh, $user, 'vlan',
						"trunkset_vlan_presence.trunk_set='$sdata[$ts_pos{'trunk_set.id'}]'");
    my $blref = CMU::Netdb::list_vlans_ref($dbh, $user, '', 'vlan.name');
    $$blref{'##q--'} = $q;
    $$blref{'##back--'} = 'build';
    $$blref{'##build--'} = $sdata[$ts_pos{'trunk_set.id'}];
    $$blref{'##id--'} = $tid;
    CMU::WebInt::generic_smTable($url, $pref, ['vlan.name','vlan.number'],
  		    \%CMU::WebInt::trunkset::ts_vlan_tsv_pos,
		    \%CMU::Netdb::structure::trunkset_vlan_presence_ts_vlan_printable, 
		    "vid=$tid", 'trunkset_vlan_presence', 'ts_del_member1',
		    \&CMU::WebInt::vlans::vlans_cb_add_presence,
		    $blref,'trunkset_vlan_presence.vlan', "op=vlan_info&vid=");

    ## Building Presence 
    my ($vres, $en) = CMU::Netdb::config::get_multi_conf_var
			('webint','ENABLE_BUILDINGS');
    if ($en == 1) {
	print CMU::WebInt::subHeading("Buildings in Trunk Set", CMU::WebInt::pageHelpLink('trunkset_presence'));
	$pref = CMU::Netdb::list_trunkset_presences($dbh, $user, 'building',
						    "trunkset_building_presence.trunk_set='$sdata[$ts_pos{'trunk_set.id'}]'");

	my $bref = CMU::Netdb::list_buildingID_ref($dbh, $user, '');

	$$bref{'##id--'} = $tid;
	$$bref{'##q--'} = $q;
	CMU::WebInt::generic_smTable($url, $pref, ['building.name'],
				 \%ts_building_tsb_pos,
				 \%CMU::Netdb::structure::trunkset_building_presence_ts_building_printable, 
				 "bid=$tid", 'trunkset_building_presence', 'ts_del_member1',
				 \&CMU::WebInt::vlans::vlans_cb_add_presence,
				 $bref, 'trunkset_building_presence.buildings', "op=build_view&id=");
    }
  
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
}

# trunkset_update
# Arguments:
#	- CGI handle
# Returns:
#	- none
# This function updates existing trunkset parameters.
sub trunkset_update {
    my ($q) = @_;
    my ($dbh, $version, $id, $user, $p, $r, $userlevel, %fields, %error);

    $dbh = CMU::WebInt::db_connect();
    ($user, $p, $r) = CMU::WebInt::getUserInfo();
    $version = CMU::WebInt::gParam($q, 'version');
    $id = CMU::WebInt::gParam($q,'tid');

    $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'trunk_set', $id);
    if ($userlevel < 9) {
	print CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", {});
	&CMU::WebInt::title("Update Error");
	CMU::WebInt::accessDenied('trunk_set', 'WRITE', $id, 
				  9, $userlevel, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    %fields = ('name' => CMU::WebInt::gParam($q, 'uname'),
		'abbreviation' => CMU::WebInt::gParam($q, 'abbr'),
		'description' => CMU::WebInt::gParam($q, 'description'),
		'primary_vlan' => CMU::WebInt::gParam($q, 'primary_vlan')
	    );
    my ($res, $field) = CMU::Netdb::modify_trunkset($dbh, $user, $id, $version, \%fields);
    if ($res >= 1) {
	$error{msg} = "Trunk Set information has been updated.";
    } else {
	$error{msg} = "Error updating Trunk Set information: ".$errmeanings{$res};
	$error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
	    if ($res eq $CMU::Netdb::errcodes{EDB});
	$error{type} = 'ERR';
	$error{loc}  = 'trunkset_upd';
	$error{code} = $res;
	$error{fields} = join(',', @$field);
	$error{$field} = 1;
    }

    $dbh->disconnect();
    CMU::WebInt::trunkset_view($q, \%error);
}

# trunkset_add_membership
# Arguments:
#	- CGI handle
# Returns:
#	- none
# This is generic function to add members in trunk_set. Based
# on CGI param, it will decide type of member (vlan, building,
# or device) and after checking write_level on id, adds that
# member in trunkset. After adding member, view will be changed
# by calling trunkset_view.
sub trunkset_add_membership {
    my ($q, $errors) = @_;
    my (%fields, %error, $res, $dbh, $ref, $userlevel);
    my ($type, $mid);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();

    %fields = ('trunk_set' => CMU::WebInt::gParam($q,'tid'));
    $type = CMU::WebInt::gParam($q,'type');
    $mid  = CMU::WebInt::gParam($q,'vid') if ($type eq 'vlan');
    $mid  = CMU::WebInt::gParam($q,'id') if ($type eq 'building');
    $mid  = CMU::WebInt::gParam($q,'id') if ($type eq 'machine');

    $fields{vlan} = $mid if($type eq 'vlan');
    $fields{buildings} = $mid if($type eq 'building');
    $fields{device} = $mid if ($type eq 'machine');
    $fields{type} = $type;

    $userlevel = CMU::Netdb::get_add_level($dbh,$user,'trunk_set',$fields{trunkset});
    if ($userlevel < 9) {
	print &CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", $errors);
	&CMU::WebInt::title("Add Error");
	CMU::WebInt::accessDenied('trunk_set', 'ADD', $fields{trunkset},
				  9, $userlevel, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
   }

    ($res,$ref) = CMU::Netdb::add_trunkset_presence($dbh,$user,\%fields);
    if ($res != 1) {
	$error{msg} = "Error adding trunkset presence : ".$errmeanings{$res};
	$error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
	  if ($res eq $CMU::Netdb::errcodes{EDB});
	$error{msg} .= " [".join(',', @$ref)."] ";
	$error{type} = 'ERR';
	$error{loc} = 'trunkset_add_membership';
	$error{code} = $res;
	$error{fields} = join(',', @$ref);
    } else {
	$error{msg} = "Trunk Set field added to the $type.";
    }
  
    $dbh->disconnect();

    if ($type eq 'vlan') {
        &CMU::WebInt::vlans_view($q, \%error) ;
    } elsif ($type eq 'machine') {
	&CMU::WebInt::mach_view($q, \%error) ;
    } else {
	&CMU::WebInt::build_view($q, \%error) ;
    }
}

# trunkset_del_membership
# Arguments:
#	- CGI handle
# Returns:
#	- none
# This is generic function to delete members in trunk_set. Based
# on CGI param, it will decide type of member (vlan, building,
# or device) and after checking write_level on id, deletes that
# member in trunkset. After deleting member, view will be changed
# by calling trunkset_view
sub trunkset_del_membership {
    my ($q, $errors) = @_;
    my ($dbh, $res, $userlevel, $version, $id, $tid, $url, $errfields, $type, %error);
    my (@devs, $devref, $oref);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    $version = CMU::WebInt::gParam($q, 'v');
    $id = CMU::WebInt::gParam($q,'id');
    if (CMU::WebInt::gParam($q,'vid') ne '') {
	$type = 'vlan' ;
	$tid = CMU::WebInt::gParam($q,'vid');
    }
    if (CMU::WebInt::gParam($q,'bid') ne '') {
	$type = 'building' ;
	$tid = CMU::WebInt::gParam($q,'bid');
    }
    if (CMU::WebInt::gParam($q,'mid') ne '') {
	$type = 'machine' ;
	$tid = CMU::WebInt::gParam($q,'mid');
    }

    $userlevel = CMU::Netdb::get_write_level($dbh, $user, "trunkset_".$type."_presence", $tid);
    if ($userlevel < 9) {
	print &CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", $errors);
	&CMU::WebInt::title("Delete Error");
	CMU::WebInt::accessDenied("trunkset_".$type."_presence", 'WRITE',
				  $tid, 9, $userlevel, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    ($res, $errfields) = CMU::Netdb::delete_trunkset_presence($dbh, $user, $type,$id, $version);
    if ($res != 1) {
	$error{msg} = "Error deleting Trunk Set presence from $type: ".$errmeanings{$res};
	$error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
	if ($res eq $CMU::Netdb::errcodes{EDB});
	    $error{type} = 'ERR';
	$error{loc} = 'trunkset_del_membership';
	$error{code} = $res;
	$error{fields} = join(',', @$errfields);
    } else {
	$error{msg} = "Trunk Set presence deleted from the $type.";
    }
    
    $dbh->disconnect();

    if ($type eq 'building') {
	$q->param('id', CMU::WebInt::gParam($q, 'bid'));
	CMU::WebInt::build_view($q, \%error);
    } elsif ($type eq 'vlan') {
	$q->param('id', CMU::WebInt::gParam($q, 'vid'));
	CMU::WebInt::vlans_view($q, \%error);
    } elsif ($type eq 'machine') {
	$q->param('id', CMU::WebInt::gParam($q,'mid'));
	CMU::WebInt::mach_view($q,\%error);
    } else {
	$q->param('tid',$tid );
	CMU::WebInt::trunkset_view($q, \%error);
    }
}

# trunkset_del
# Arguments:
# 	- CGI handle
# Returns:
#	- none
# Function gets trunk_set.id from database for given name
# and ask for confirmation.
sub trunkset_del {
    my ($q) = @_;
    my ($dbh, $where, $tid, $url, $res, $userlevel);

    $tid = CMU::WebInt::gParam($q,'tid');

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    CMU::WebInt::setHelpFile('ts_del_member');
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Trunkset Admin", {});
    &CMU::WebInt::title("Delete Trunk Set");

    $url = $ENV{SCRIPT_NAME};
    $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'trunk_set',0);
    if ($userlevel == 0) {
	CMU::WebInt::accessDenied('trunk_set', 'WRITE', 0,
				  1, $userlevel, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    my $sref = CMU::Netdb::list_trunkset( $dbh, $user, "trunk_set.id='$tid'");
    my @sdata = @{$sref->[1]};

    print CMU::WebInt::subHeading("Confirm Deletion of: ".$sdata[$ts_pos{'trunk_set.name'}]);
    print "Please confirm that you wish to delete the following Trunk Set."; 
    print "<br>Clicking \"Delete Trunk Set\" below will cause this trunk set and all associated ".
	    " information to be deleted.\n";
    print "<table border=0>
	<tr><td bgcolor=lightyellow>Name</td><td>$sdata[$ts_pos{'trunk_set.name'}]</td></tr>
	<tr><td bgcolor=lightyellow>Abbreviation</td><td>$sdata[$ts_pos{'trunk_set.abbreviation'}]</td></tr>
	</table>
	<form method=get>
	<input type=hidden name=op value=trunkset_del_conf>
	<input type=hidden name=tid value=$tid>
        <input type=hidden name=version value=\"".$sdata[$ts_pos{'trunk_set.version'}]."\">
	<input type=submit value=\"Delete Trunk Set\">
	</form>
    ";

    $dbh->disconnect();
    print &CMU::WebInt::stdftr($q);
}

# trunkset_del_confirm
# Arguments:
#	- CGI handle
# Returns:
#	- none
# It deletes trunk_set from database, for given id. 'id' of the
# trunk_set is passed as CGI param. After successful deletion
# calls trunkset_main, to show all listed trunk_sets.
sub trunkset_del_confirm {
    my ($q) = @_;
    my ($dbh, $tid, $version, $userlevel, %errors);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    $tid = CMU::WebInt::gParam($q,'tid');
    $version = CMU::WebInt::gParam($q, 'version');
    $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'trunk_set',0);
    if ($userlevel == 0) {
	CMU::WebInt::accessDenied('trunk_set', 'WRITE', 0, 1, 0, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }

    my ($res, $ref) = CMU::Netdb::delete_trunkset($dbh, $user, $tid, $version);
    if ($res != 1) {
	$errors{msg} = "Error deleting Trunk Set: ".$errmeanings{$res}." [".
	join(',', @$ref)."] ";

	$errors{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
	    if ($res eq $CMU::Netdb::errcodes{EDB});
	$errors{type} = 'ERR';
	$errors{loc} = 'trunkset_del_conf';
	$errors{code} = $res;
	$errors{fields} = join(',', @$ref);
    } else {
	$errors{msg} = "Trunk Set deleted.";
    }

    $dbh->disconnect();
    CMU::WebInt::trunkset_main($q, \%errors);
}

# trunkset_del_membership1
# Arguments:
#	- CGI handle
# Returns:
#	- none
# This will delete vlan/machine from Trunk Set and will return trunkset_view
# It is different from trunkset_del_membership, as after deleting 
# appropriate element in trunkset_XXX_presence, it will get back to 
# trunkset_view instead of  XXX_view
sub trunkset_del_membership1 {
    my ($q) = @_;
    my ($dbh, $res, $version, $id, $tid, %error, $url, $errfields, $type);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();

    $version = CMU::WebInt::gParam($q, 'v');
    $id = CMU::WebInt::gParam($q, 'id');

    $tid = CMU::WebInt::gParam($q, 'vid');
    $tid = CMU::WebInt::gParam($q, 'bid') if ($tid eq '');
    $tid = CMU::WebInt::gParam($q, 'mid') if ($tid eq '');

    $type = 'vlan' if (CMU::WebInt::gParam($q,'vid')  ne '');
    $type = 'building' if (CMU::WebInt::gParam($q,'bid') ne '');
    $type = 'machine' if (CMU::WebInt::gParam($q, 'mid') ne '');

    my $ul = CMU::Netdb::get_write_level($dbh, $user, $type, $tid);
    if ($ul < 9) {
	print CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin ",{});
	&CMU::WebInt::title("Delete Error");
	CMU::WebInt::accessDenied($type, 'WRITE', $tid, 9, $ul, $user);
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect;
	return;
    }

    ($res, $errfields) = CMU::Netdb::delete_trunkset_presence($dbh, $user, $type, $id, $version);
    if ($res != 1) {
	$error{msg} = "Error deleting trunkset presence from $type: ".$errmeanings{$res}.
			" [".join(',',@$errfields)."] ";
	$error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
	  if ($res eq $CMU::Netdb::errcodes{EDB});
	$error{type} = 'ERR';
	$error{loc} = 'trunkset_del_membership1';
	$error{code} = $res;
	$error{fields} = join(',', @$errfields);
	}else{
	$error{msg} = "$type delete from Trunk Set.";
    }
    $dbh->disconnect();

    $q->param('tid', $tid) ;
    CMU::WebInt::trunkset_view($q,\%error);
}

# trunkset_add_membership1
# Arguments:
#	- CGI handle
# Returns:
#	- none
# This will add vlan/machine from Trunk Set and will return trunkset_view
# It is different from trunkset_add_membership, as after adding
# appropriate element in trunkset_XXX_presence, it will get back to 
# trunkset_view instead of  XXX_view
sub trunkset_add_membership1 {
    my ($q, $errors) = @_;
    my (%fields, $res, %error, $dbh, $ref, $userlevel, $vl_userlevel, $rid, $type);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();

    $rid = CMU::WebInt::gParam($q, 'vid');
    $rid = CMU::WebInt::gParam($q, 'bid') if ($rid eq '');

    $type = 'vlan' if (CMU::WebInt::gParam($q, 'vid') ne '');
    $type = 'building' if (CMU::WebInt::gParam($q, 'bid') ne '');

  
    %fields = ('trunk_set' => CMU::WebInt::gParam($q, 'id'),
	     'type' => $type);
    $fields{vlan} = $rid if ($type eq 'vlan');
    $fields{buildings} = $rid if ($type eq 'building');

    $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'trunk_set' , $fields{trunk_set});
    $vl_userlevel = CMU::Netdb::get_add_level($dbh, $user, 'vlan' , $fields{vlan});
    if ($userlevel < 9 || $vl_userlevel < 1) {
	print &CMU::WebInt::stdhdr($q, $dbh, $user, "Trunk Set Admin", $errors);
	&CMU::WebInt::title("Add Error");
	if ($userlevel < 9) {
		CMU::WebInt::accessDenied('trunk_set', 'ADD', $fields{trunk_set},
					  9, $userlevel, $user);
	}else{
		CMU::WebInt::accessDenied('vlan', 'ADD', $fields{vlan},
					  1, $vl_userlevel, $user);
	}

	CMU::WebInt::accessDenied();
	print CMU::WebInt::stdftr($q);
	$dbh->disconnect();
	return;
    }
  
    ($res, $ref) = CMU::Netdb::add_trunkset_presence($dbh, $user, \%fields);
    if ($res != 1) {
	$error{msg} = "Error adding Trunk Set presence to $type: ".$errmeanings{$res};
	$error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
	  if ($res eq $CMU::Netdb::errcodes{EDB});
	$error{msg} .= " [".join(',', @$ref)."] ";
	$error{type} = 'ERR';
	$error{loc} = 'trunkset_add_membership1';
	$error{code} = $res;
	$error{fields} = join(',', @$ref);
    }else{
	$error{msg} = "$type added to the Trunk Set.";
    }
    $dbh->disconnect();

    $q->param('tid', CMU::WebInt::gParam($q,'id'));
    CMU::WebInt::trunkset_view($q, \%error);
}

# trunkset_cb_add_presence
# Arguments:
#	- Reference to Hash, contains id -> name
# Returns:
#	- CGI elements, contain popup_menu, and call_back
#	  functions.
# This function shows, popup_menu and button, and call_back
# function when button is pressed. Depending on which module
# calls this function i.e., vlan,building,device or trunkset
# it will create name= and value= elements.
sub trunkset_cb_add_presence {
    my($bref) = @_;
    my $q 	= $$bref{'##q--'}; delete $$bref{'##q--'};
    my $vid 	= $$bref{'##vid--'}; delete $$bref{'##vid--'};
    my $bid 	= $$bref{'##bid--'}; delete $$bref{'##bid--'};
    my $did	= $$bref{'##mid--'}; delete $$bref{'##mid--'};
    my $tid 	= $$bref{'##tid--'}; delete $$bref{'##tid--'};
    my $type	= $$bref{'##type--'}; delete $$bref{'##type--'};
    my $trset	= $$bref{'##trset--'}; delete $$bref{'##trset--'};

    my $mid = ($type eq 'vlan'?$vid:($type eq 'building'?$bid:$did)); 

    my @bs = sort {$bref->{$a} cmp $bref->{$b}} keys %$bref;


    my $res = "<tr><td><form method=get>
	<input type=hidden name=op value=ts_add_member>
	<input type=hidden name=type value=$type>";
    if ($type eq 'vlan') {
	$res .= "<input type=hidden name=vid value=$mid>";
    } elsif ($type eq 'machine') {
	$res .= "<input type=hidden name=id value=$mid>";
    } else {
	$res .= "<input type=hidden name=id value=$mid>";
    }
    $res .= $q->popup_menu(-name => 'tid',
			   -values => \@bs,
			   -labels => $bref);
    $res .= "<input type=submit value=\"Add Trunk Set\"></form></td></tr>";
    return $res;
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 8
# perl-indent-level: 4
# cperl-indent-level: 4
# End:

