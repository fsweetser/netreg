#   -*- perl -*-
#
# CMU::WebInt::interface
# This module provides the basic interface parameters to be used
# through the netreg site.
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

package CMU::WebInt::interface;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %sections
	    $helpPage $debug $TACOLOR $HDCOLOR $PAGEWIDTH);
use CMU::WebInt;
use CMU::Netdb;

use CGI;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(shorthdr stdhdr stdftr pager_Top pager_Bottom title printPossError
	     tableHeading subHeading generic_tprint generic_smTable smallRight
	     generic_print_ref_table accessDenied permMatrix printVerbose
	     setHelpFile pageHelpLink inlineHelpLink errorDialog errhdr
	     smallHeading subHeadingAnchored);

%sections = %CMU::WebInt::vars::sections;

$helpPage = 'main';

$debug = 0;
my ($gmcvres);
($gmcvres, $HDCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'HDCOLOR');
die "interface / HDCOLOR" if ($gmcvres != 1);

($gmcvres, $TACOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'TACOLOR');
die "interface / TACOLOR" if ($gmcvres != 1);

($gmcvres, $PAGEWIDTH) = CMU::Netdb::config::get_multi_conf_var('webint', 'PAGEWIDTH');
$PAGEWIDTH=620 if ($gmcvres != 1);

# A note about tabindex html attributes.
# In an attempt to make the UI easier to use from the keyboard,
# we're adding tabindex attributes to HTML tags throughout the system.
# The values we're using are
# 32766: Top level menu items.  Accessed dead last via the keyboard
# 100: Third tier links.  next page links, individual help links, etc.
# 90: Second tier links.  page help/refresh links, foriegn object links, 'view advanced options', etc.
# 10: First tier links & objects.  form fields, submit buttons, etc.


# Function: stdhdr
# Arguments: 4:
#   * CGI handle
#   * Database handle
#   * UserID
#   * Title of the window
#   * Errors hash
# Actions: Presents the top bar, etc.
# Return Value:
#   Text to output
sub stdhdr {
  my ($q, $dbh, $user, $title, $errors) = @_;
  my ($result);
  my $url = $ENV{SCRIPT_NAME};
  
  if (ref $errors && defined $$errors{'msg'}) {

    my ($msg, $type, $code) = ($$errors{'msg'}, $$errors{'type'},
			       $$errors{'code'});
    my ($loc, $fields) = ($$errors{'loc'}, $$errors{'fields'});
    my $NR_ERRVAR = '';
    if ($type eq 'ERR') {
      $NR_ERRVAR = "ERR|${code}|${fields}|$loc|$msg";
    }else{
      $NR_ERRVAR = "OK|$msg";
    }
    $NR_ERRVAR =~ s/\s/\_/g;

    $result = $q->header(-netreg_error => $NR_ERRVAR);
  }else{
    $result = $q->header();
  }

  my ($vres, $user_mail, $bgcolor, $system_name, $mainURL);
  ($vres, $user_mail) = CMU::Netdb::config::get_multi_conf_var('webint', 
							       'USER_MAIL');
  ($vres, $bgcolor) = CMU::Netdb::config::get_multi_conf_var('webint', 'BGCOLOR');
  ($vres, $system_name) = CMU::Netdb::config::get_multi_conf_var('webint', 
								 'SYSTEM_NAME');
  ($vres, $mainURL) = CMU::Netdb::config::get_multi_conf_var('webint', 
							     'SYSTEM_MAIN_URL');
  my $users = CMU::Netdb::list_users($dbh, 'netreg', "credentials.authid = '$user'");
  if (ref $users && (@$users > 1)) {
    my $map = CMU::Netdb::makemap($users->[0]);
    my $uid = $users->[1][$map->{'users.id'}];
    my $attrs = CMU::Netdb::list_attribute($dbh, $user, "attribute_spec.name = 'background-color' AND attribute.owner_table = 'users' " 
					   . " AND attribute.owner_tid = $uid");
    if (ref $attrs && (@$attrs > 1)) {
      $map = CMU::Netdb::makemap($attrs->[0]);
      $bgcolor = $attrs->[1][$map->{'attribute.data'}];
    }
  }

  $result .= $q->start_html(-title => $title,
			    -author => $user_mail,
			    -BGCOLOR => $bgcolor);
  $result .= netreg_style();
  if ($ENV{'authuser'} ne '') {
    $result .= "<table border=0 width=630><tr bgcolor=orange width=630><td>".
      "<font face=\"Arial,Helvetica,Geneva,Charter\">".
	"Acting as: <b>$ENV{'authuser'}</b></font></td>".
	  "<td>[<b><a tabindex=\"32766\" href=\"$url?op=auth_user_cred&CLEAR=1\">".
	    "Exit</a></b>]</font></td></tr></table>";
  }

  my ($sidebarres, $sidebar) = CMU::Netdb::config::get_multi_conf_var('webint', 'SIDEBAR');
  $result .= "<table border=0><tr><td>" if ($sidebarres == 1);

  $result .= "<table border=0 width=$PAGEWIDTH><tr><td colspan='2' align='center'>";
  $result .= "<img alt=\"$system_name -- $mainURL\" src=/img/netreg.jpg /></td></tr>\n";
  my $userAdmin = CMU::Netdb::get_user_admin_status($dbh, $user);
  if ($userAdmin == -1) {
    my ($vres, $user_mail) = CMU::Netdb::config::get_multi_conf_var('webint',
							       'USER_MAIL');
    $result .= "<tr>".
      "<td>Your access to this system is currently suspended. If you believe ".
	"this to be an error, please contact $user_mail.\n";
    $result .= stdftr($q);
    print $result;
    exit;
  }
  if ($userAdmin == 0) {
    my $usergroupAdmin = CMU::Netdb::get_user_group_admin_status($dbh, $user);
    if (!$usergroupAdmin) {
      
      $result .= "<tr valign=top>".
	"<td valign=top><b>
<font face=\"Arial,Helvetica,Geneva,Charter\" size=+1>$title</font></td>
<td valign=top align=right>".
      &topbarNonAdm($title, $url)."</font></td></tr><tr><td width=$PAGEWIDTH colspan=2>";
    } else {
    $result .= &topbarGroupAdm($title, $url)."<tr><td width=$PAGEWIDTH colspan=2><hr />";
    }
  }else{
    $result .= &topbarAdm($title, $url)."<tr><td width=$PAGEWIDTH colspan=2><hr />";
  }
  return $result;
}

sub netreg_style {
  my ($vres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint',
								'THCOLOR');

  return "
<style><!--

.basetext { font-family: Verdana,Helvetica,Geneva,Charter;
            font-style: normal;
            font-size: 100%;
          }

.smtext   { font-family: Verdana,Helvetica,Geneva,Charter;
            font-style: normal;
            font-size: 80%;
          }

.lgtext   { font-family: Verdana,Helvetica,Geneva,Charter;
            font-style: normal;
            font-size: 110%;
          }

H3        { font-family: Verdana,Helvetica,Geneva,Charter;
            font-weight: bold;
            font-size: 125%
          }

TD        { font-family: Arial,Helvetica,Geneva,Charter;
            font-size: 85%;
          }

TH        { font-family: Arial,Helvetica,Geneva,Charter;
            font-weight: bold;
            font-size: 110%;
            background: $THCOLOR;
            text-align: left;
          }

TH.small  { font-size: 85%; }

TH.warn   { color: red; }

TH.warnsm { color: red; 
            font-size: 85%;
          }

//--></style>
";
}

sub errhdr {
  my ($q, $dbh, $user, $title) = @_;
  my ($result);
  my $url = $ENV{SCRIPT_NAME};

  my ($vres, $user_mail, $bgcolor, $system_name, $mainURL);
  ($vres, $user_mail) = CMU::Netdb::config::get_multi_conf_var('webint', 
							       'USER_MAIL');
  ($vres, $bgcolor) = CMU::Netdb::config::get_multi_conf_var('webint', 'BGCOLOR');
  ($vres, $system_name) = CMU::Netdb::config::get_multi_conf_var('webint', 
								 'SYSTEM_NAME');
  ($vres, $mainURL) = CMU::Netdb::config::get_multi_conf_var('webint', 
							     'SYSTEM_MAIN_URL');
  $result = $q->header();
  $result .= $q->start_html(-title => $title,
			   -author => $user_mail,
			   -BGCOLOR => $bgcolor);
  $result .= "<img alt=\"$system_name -- $mainURL\" src=/img/netreg.jpg><br />\n";
  my $userAdmin = CMU::Netdb::get_user_admin_status($dbh, $user);
  $result .= "<table border=0 width=$PAGEWIDTH><tr><td width=$PAGEWIDTH>";
  return $result;
}

sub topbarNonAdm {
  my ($title, $url) = @_;

  my ($vres, $logout) = CMU::Netdb::config::get_multi_conf_var('webint',
                                                               'LOGOUT_LINK');

  my $output = "<font face=\"arial,helvetica,geneva,charter\" size=-1>\n" .
    "[<b><a tabindex=\"32766\" href=".CMU::WebInt::encURL($url."?op=mach_list").">Main</a></b>]\n" .
    "[<b><a tabindex=\"32766\" href=/help/pages/about-netreg.shtml>Help</a></b>]\n";
  if ($vres > 0 && $logout ne '') {
      $output .= "[<b><a tabindex=\"32766\" href=\"$logout?u=".&CMU::WebInt::getUserInfo()."\">Signoff</a></b>]";
  } elsif ($vres <= 0) {
      $output .= "[<b><a tabindex=\"32766\" href=/nc.pl?u=".&CMU::WebInt::getUserInfo().">Signoff</a></b>]";
  }
  $output .= "</font>\n";
  return $output;
}

sub topbarDeptAdm {
  my ($title, $murl) = @_;
  
  my ($res, $vres, $eco, $edc, $esl, $logout);
  my $nurl = CMU::WebInt::encURL($murl);
  ($vres, $eco) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_CABLES_OUTLETS');

  #Adding "Enable Search leases" to this list
  ($vres, $esl) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_SEARCH_LEASES');

  ($vres, $logout) = CMU::Netdb::config::get_multi_conf_var('webint',
                                                               'LOGOUT_LINK');

  $res = <<END_HTML;
<tr valign=top><td valign=top>
<font face=\"Arial,Helvetica,Geneva,Charter\" size=+1>$title</font></td>
<td valign=top align=right>
<font face=\"arial,helvetica,geneva,charter\" size=-1>
[<b><a tabindex=\"32766\" href=$nurl?op=mach_list>Main</a></b>]
[<b><a tabindex=\"32766\" href=$nurl?op=mach_search>Search Machines</a></b>]
END_HTML

  #Check to set if Search Leases is toggled on
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=mach_find_lease>Search Leases</a></b>]" if ($esl == 1);
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=outlets_search>Search Outlets</a></b>]" if ($eco == 1);
  $res .= "[<b><a tabindex=\"32766\" href=/help/pages/about-netreg.shtml>Help</a></b>]";
  if ($vres > 0 && $logout ne '') {
      $res .= "[<b><a tabindex=\"32766\" href=\"$logout?u=".&CMU::WebInt::getUserInfo()."\">Signoff</a></b>]";
  } elsif ($vres <= 0) {
      $res .= "[<b><a tabindex=\"32766\" href=/nc.pl?u=".&CMU::WebInt::getUserInfo().">Signoff</a></b>]";
  }

  $res .= "<br></td></tr>";

  ($vres, $edc) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_DEPT_CONTROL');

  if ($edc == 1) {
    $res .= "<tr><td valign=top align=right colspan=2>\n" .
      "<font face=\"arial,helvetica,geneva,charter\" size=-1>\n" . 
	"[<b><a tabindex=\"32766\" href=$nurl?op=prot_deptadmin>Department Admin Control</a></b>]\n" .
	  "</font></td></tr>\n\n";
  } 
  return $res;
}

sub topbarGroupAdm {
  my ($title, $murl) = @_;
  
  my ($res, $vres, $eco, $edc, $esl, $logout);
  my $nurl = CMU::WebInt::encURL($murl);

  ($vres, $esl) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_SEARCH_LEASES');

  ($vres, $eco) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_CABLES_OUTLETS');

  ($vres, $logout) = CMU::Netdb::config::get_multi_conf_var('webint',
                                                            'LOGOUT_LINK');

  $res = <<END_HTML;
<tr valign=top><td valign=top>
<font face=\"Arial,Helvetica,Geneva,Charter\" size=+1>$title</font></td>
<td valign=top align=right>
<font face=\"arial,helvetica,geneva,charter\" size=-1>
[<b><a tabindex=\"32766\" href=$nurl?op=mach_list>Main</a></b>]
[<b><a tabindex=\"32766\" href=$nurl?op=mach_search>Search Machines</a></b>]
END_HTML
  #Displays Search Leases if toggled on in netreg-webint file
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=mach_find_lease>Search Leases</a></b>]" if ($esl == 1);
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=outlets_search>Search Outlets</a></b>]" if ($eco == 1);
  $res .= "[<b><a tabindex=\"32766\" href=/help/pages/about-netreg.shtml>Help</a></b>]";
  if ($vres > 0 && $logout ne '') {
      $res .= "[<b><a tabindex=\"32766\" href=\"$logout?u=".&CMU::WebInt::getUserInfo()."\">Signoff</a></b>]";
  } elsif ($vres <= 0) {
      $res .= "[<b><a tabindex=\"32766\" href=/nc.pl?u=".&CMU::WebInt::getUserInfo().">Signoff</a></b>]";
  }
  $res .= "<br></td></tr><tr><td valign=top align=right colspan=2>
<font face=\"arial,helvetica,geneva,charter\" size=-1>
 
[<b><a tabindex=\"32766\" href=$nurl?op=auth_main>Groups/Departments</a></b>]";

  ($vres, $edc) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_DEPT_CONTROL');

  my $lad;
  ($vres, $lad) = CMU::Netdb::config::get_multi_conf_var
      ('netdb', 'DHCP_Lease_Archive_Dir');
  if ($vres == 1 && $lad ne '') {
      $res .= "[<b><a href=$nurl?op=mach_find_lease>Find Leases</a></b>] ";
  }

  $res .= "
[<b><a tabindex=\"32766\" href=$nurl?op=prot_deptadmin>Department Admin Control</a></b>]
" if ($edc == 1);
  $res .= "</font></td></tr>\n\n";

  return $res;
}
 
sub topbarAdm {
  my ($sectionTitle, $murl) = @_;

  my ($vres, $eco, $eb, $edc, $en, $ets, $esl, $logout);

  ($vres, $eco) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_CABLES_OUTLETS');
  ($vres, $eb) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_BUILDINGS');
  ($vres, $edc) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_DEPT_CONTROL');
  ($vres, $en) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_NETWORKS');
  ($vres, $ets) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_TRUNK_SET');
  #Adding "Enable Search leases" to this list
  ($vres, $esl) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_SEARCH_LEASES');

  ($vres, $logout) = CMU::Netdb::config::get_multi_conf_var('webint',
                                                            'LOGOUT_LINK');

  my $res;
  my $nurl = CMU::WebInt::encURL($murl);
  $res = "<tr valign=top><td valign=top>\n" .
"<font face=\"Arial,Helvetica,Geneva,Charter\" size=+1>$sectionTitle</font></td>\n" . 
"<td valign=top align=right>\n" .
"<font face=\"arial,helvetica,geneva,charter\" size=-1>\n" .
"  [<b><a tabindex=\"32766\" href=$nurl?op=mach_list>Main</a></b>]\n" .
"  [<b><a tabindex=\"32766\" href=$nurl?op=mach_search>Search Machines</a></b>] ";
  #Making the Search leases togglable
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=mach_find_lease>Search Leases</a></b>] "
    if ($esl == 1);

  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=outlets_search>Search Outlets</a></b>] "
    if ($eco == 1);

  $res .= "\n" .
"  [<b><a tabindex=\"32766\" href=$nurl?op=rep_main>Reports</a></b>]\n" . 
"  [<b><a tabindex=\"32766\" href=/help/pages/about-netreg.shtml>Help</a></b>]\n";

  if ($vres > 0 && $logout ne '') {
      $res .= "[<b><a tabindex=\"32766\" href=\"$logout?u=".&CMU::WebInt::getUserInfo()."\">Signoff</a></b>]";
  } elsif ($vres <= 0) {
      $res .= "[<b><a tabindex=\"32766\" href=/nc.pl?u=".&CMU::WebInt::getUserInfo().">Signoff</a></b>]";
  }

  $res .= "<br />\n" .
"  </font></td></tr><tr><td valign=top align=right colspan=2> \n" .
"  <font face=\"arial,helvetica,geneva,charter\" size=-1> ";

  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=oact_list>Activations</a></b>] "
    if ($eco == 1);
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=attr_spec_list>Attributes</a></b>] ";
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=build_list>Buildings</a></b>] "
    if ($eb == 1);
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=cable_list>Cables</a></b>] "
    if ($eco == 1);
  $res .= "
 [<b><a tabindex=\"32766\" href=$nurl?op=prot_deptadmin>Dept Cntrl</a></b>] "
    if ($edc == 1);

  $res .= "
 [<b><a tabindex=\"32766\" href=$nurl?op=mach_dns_gdhcp_list>DHCP</a></b>]
 [<b><a tabindex=\"32766\" href=$nurl?op=dns_main>DNS</a></b>]
 <br />\n";
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=net_list>Networks</a></b>] "
    if ($en == 1);
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=outlet_t_list>Outlet Types</a></b>] "
    if ($eco == 1);
  $res .= "
 [<b><a tabindex=\"32766\" href=$nurl?op=prot_main>Protections</a></b>]
 [<b><a tabindex=\"32766\" href=$nurl?op=svc_main>Services</a></b>]
 [<b><a tabindex=\"32766\" href=$nurl?op=sch_main>Scheduler</a></b>]
 [<b><a tabindex=\"32766\" href=$nurl?op=sub_main>Subnets</a></b>]
<br />\n";

  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=telecom_main>Telecom</a></b>] "
    if ($eco == 1);
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=trunkset_main>Trunk Set</a></b>] "
    if ($ets == 1);
  $res .= "
[<b><a tabindex=\"32766\" href=$nurl?op=auth_main>Users/Groups</a></b>] ";
  ## Enabling VLAN...:
  $res .= "[<b><a tabindex=\"32766\" href=$nurl?op=vlan_main>Vlans</a></b>]";
 $res .= "
 [<b><a tabindex=\"32766\" href=$nurl?op=zone_list>Zones</a></b>]
  </font></td></tr>
  ";
return $res;
}

sub stdftr {
  my ($q) = @_;
  my ($result);

  my ($vres, $admin_grp, $user_mail);
  ($vres, $admin_grp) = CMU::Netdb::config::get_multi_conf_var('webint',
							       'ADMIN_GROUP');
  ($vres, $user_mail) = CMU::Netdb::config::get_multi_conf_var('webint',
							       'USER_MAIL');

  $result = "<br /><hr /></td></tr></table> ";
  my ($sidebarres, $sidebar) = CMU::Netdb::config::get_multi_conf_var('webint', 'SIDEBAR');
  $result .= "</td><td>$sidebar</td></tr></table>" if ($sidebarres == 1);
  $result .= "<i><font size=-1>$admin_grp -- ".
      "<a tabindex=\"32766\" href=\"mailto:$user_mail\">Webmaster</a></font></i>\n";

  $result .= $q->end_html();
  return $result;
}

# Pagination Routines
##
## $start: what record num you're starting with
## $total: total number of records
## $perpage: number of records per page
## $maxpages: max pages to supply links to
## $url: URL to refresh the list
## $extra: extra parameters (ie op=search)
## $var: variable that will become $start upon reload

sub pager_Top {
  my ($start, $total, $perpage, $maxpages, $url, $extra, $var) = @_;
  my ($res, $nv, $pstart, $i);

  $extra .= "&" if ($extra ne '');
  warn __FILE__, ':', __LINE__, ' :>'.
    "PAGER_TOP: $start $total $perpage $url $extra\n" if ($debug >= 2);
  return if ($start == 0 && $maxpages == 0 && $nv >= $total);
  $res = "<table border=0 width=$PAGEWIDTH><tr><td align=right>
[<a tabindex=\"100\" href=\"".CMU::WebInt::encURL("$url?$extra$var=0")."\">First Page</a>] &nbsp;\n";

  if ( $start != 0) {
    $nv = $start - $perpage;
    $nv = 0 if ($nv < 0);
    $res .= " [<a tabindex=\"100\" href=\"".CMU::WebInt::encURL("$url?$extra$var=$nv")."\">Previous Page</a>] \n";
  }
  $pstart = int($start/$perpage) - int($maxpages/2);
  $pstart = 0 if ($pstart < 0);
  # pstart will be the page number we start with
  $i = $pstart;
  while($i < ($pstart + $maxpages) && ( ($i)*$perpage) < $total) {
    $nv = $i*$perpage;
    $res .= "[<a tabindex=\"100\" href=\"".CMU::WebInt::encURL("$url?$extra$var=$nv")."\">$i</a>]\n";
    $i++;
  }
  $nv = $start+$perpage;
  if ($nv < $total) {
    $res .= "| [<a tabindex=\"100\" href=\"".CMU::WebInt::encURL("$url?$extra$var=$nv")."\">Next Page</a>]\n";
  }
  $res .= "&nbsp\n";
  if ($maxpages != 0) {
    $nv = $total-$perpage;
    $nv = 0 if ($nv < 0);
    $res .= " [<a tabindex=\"100\" href=\"".CMU::WebInt::encURL("$url?$extra$var=$nv")."\">Last Page</a>]\n";
  }
  $res .= "</td></tr></table>\n";
  return $res;
}

sub pager_Bottom {
  return "";
}

sub title {
  my ($t) = @_;
  print "<font size=+2 face=\"Arial,Helvetica,Geneva,Charter\"><B>$t</B></font>\n";
}

sub printPossError {
  my ($error, $msg, $cnt, $help, $extra) = @_;
  $cnt = 1 if ($cnt eq '');
  my $as = '';
  $as = "<a tabindex=\"100\" target=_blank href=\"".CMU::WebInt::encURL("/help/definitions/$help.shtml")."\">" if ($help ne '');
  my $af = '';
  $af = "</a>\n" if ($help ne '');
  if ($error) {
    if ($extra ne '') {
      return "<th colspan=$cnt class=warn><table border=0 cellspacing=0 width=100%><tr><th>$as".&tableHeading($msg)."$af</th><th alight=right>$extra</th></tr></table></th>";
    }else{
      return "<th class=warn colspan=$cnt>$as".&tableHeading($msg)."$af</th>\n";
    }
  } else {
    if ($extra ne '') {
      return "<th colspan=$cnt><table border=0 cellspacing=0 width=100%><tr><th>$as".&tableHeading($msg)."$af</th>".
	"<td align=right>$extra</td></tr></table></th>";
    }else{
      return "<th colspan=$cnt>$as".&tableHeading($msg)."$af</th>\n";
    }
  }
}

sub setHelpFile {
  my ($name) = @_;
  $helpPage = $name;
}

sub smallRight {
  my ($a) = @_;
  return "<table border=0 width=100%><tr><td align=right><font size=-1 face=\"Arial,Helvetica,Geneva,Charter\">$a</font></td></tr></table>\n";
}

sub subHeading {
  my ($a, $b) = @_;
  my $res;
  $res = "<table border=0 width=100% cellspacing=0><tr bgcolor=$HDCOLOR>
<td><font size=+1 face=\"Arial,Helvetica,Geneva,Charter\">$a</font></td>";
  $res .= "<td align=right><font size=-1 face=\"Arial,Helvetica,Geneva,Charter\">$b</font></td>" if (defined $b && $b ne '');
  $res .= "</tr></table>\n";
  return $res;
}

sub subHeadingAnchored {
  my ($a, $b, $c) = @_;
  my $res;
  $res = "<table border=0 width=100% cellspacing=0><tr bgcolor=$HDCOLOR>
<td><font size=+1 face=\"Arial,Helvetica,Geneva,Charter\">$a</font></td>";
  $res .= "<td align=right><font size=-1 face=\"Arial,Helvetica,Geneva,Charter\">$b</font></td>" if (defined $b && $b ne '');
  $res .= "</tr></table>\n";
  if (defined $c) {
    $res = "<A NAME=\"$c\">$res</A>";
  }
  return $res;
}


sub smallHeading {
  my ($a, $b) = @_;
  my $res;
  $res = "<tr>
<td>".tableHeading($a)."</td>";
  $res .= "<th class=small align=right>$b</th>" if ($b ne '');
  $res .= "</tr>\n";
  return $res;
}

sub tableHeading {
  my ($a) = @_;
  return "<font face=\"Arial,Helvetica,Geneva,Charter\"><b>$a</b></font>";
}

# generic_tprint
# A generic way to print out a list of "stuff" with all kinds of bells,
# whistles, and the like
# Arguments
#  - URL: url to the current file
#  - ruRef: reference to the data to output, as would be expected to be
#    returned
#  - dFields: reference to an array of all the fields that should be
#    displayed
#  - eCol: reference to an array of callback functions that will
#    customize extra columns of data
#  - uData: user data that will be passed to the callback functions
#  - listop: the opcode that will get back to this list (ie 'list')
#  - infoprefix: the prefix to specify how to get the info on a row
#    (ie 'op=subnetinfo&id=')
#  - posmap: the position map
#  - printmap: the printable map
#  - nameFieldCol: the column name of the name field (the one that should be linked)
#  - idFieldCol: the column name of the id field (what the infoprefix is followed by
#    in the link in the name field column
#  - sortparam: the parameter to use for sorting
#  - sortFields: reference to an array of the field used for sorting
##  - addRow: callback to a function that can print out the row to add
##            an entry (may be NULL)
##  - cData: data that will passed to the addRow function
sub generic_tprint {
  my ($url, $ruRef, $dFields, $eCol, $uData, $listop, $infoprefix, $posmap,
      $printmap, $nameFieldCol, $idFieldCol, $sortparam, $sortFields, $addRow, $cData) = @_;
  my ($i, @tarr, $out, $nameField, @pFields, $k, $keyField, $kout, $f, $missedKey);

  $sortFields = [] if (!ref $sortFields);
  $i = 0;
  @tarr = @{$ruRef};
  @pFields = map { $posmap->{$_} } @$dFields;
  $nameField = $posmap->{$nameFieldCol};
  $keyField = $posmap->{$idFieldCol};

  print "<table border=1 width=$PAGEWIDTH>\n";
  while($tarr[$i]) {
    print "<tr>\n" if ($i % 2 == 1);
    print "<tr bgcolor=$TACOLOR>\n" if ($i % 2 == 0);
    $missedKey = 0;

    $kout = (defined $keyField?${$tarr[$i]}[$keyField]:'');
    $k = 0;
    foreach $f (@pFields) {
      if ($i == 0) {
	$out = "<b><font size=+0>";
	$out .= "<a tabindex=\"100\" href=\"".CMU::WebInt::encURL("$url?op=$listop&$sortparam=$sortFields->[$k]")."\">" 
	  if ($listop ne '' && defined $sortFields->[$k] && $sortFields->[$k] ne '');
	$out .= $printmap->{$ { $tarr[$i]}[$f]};
        $out .= "</a>" if ($listop ne '' && defined $sortFields->[$k] && $sortFields->[$k] ne '');
	$out .= "</font></b>";
      }else{
        $out = $ {$tarr[$i]}[$f];
      } 
      if (($f == $nameField || $missedKey) && $i != 0 && $out ne '') {
	if ($infoprefix ne '') {
	  print "<td><a tabindex=\"100\" href=\"".
	    CMU::WebInt::encURL("$url?$infoprefix$kout")."\">$out</a></td>\n";
	} else {
          if ($i == 0) {
	    print "<th>$out</th>\n";
	  } else {
	    print "<td>$out</td>\n";
	  }
	}
	  
	$missedKey = 0;
      }else{
	$missedKey = 1 if ($f == $nameField);
	$out = '&nbsp;' if (!defined $out || $out eq '');
	if ($i ==0) {
	  print "<th>$out</th>\n";
	} else {
	  print "<td>$out</td>\n";
	}
      }
      $k++;
    }
    foreach $f (@{$eCol}) {
     if ($i == 0) {
	print "<th><b><font size=+0>";
	print "<a tabindex=\"100\" href=\"".
	  CMU::WebInt::encURL("$url?op=$listop&$sortparam=$sortFields->[$k]")."\">" 
	    if ($listop ne '' && defined $sortFields->[$k] && $sortFields->[$k] ne '');
	print $f->($url, 0, $uData)."</font></b>";
	print "</a>" if ($listop ne '' && defined $sortFields->[$k] && $sortFields->[$k] ne '');
	print "</th>\n";
      }else{
	print "<td>";
	my $lout = $f->($url, $tarr[$i], $uData);
	$lout = '&nbsp;' if ($lout eq '');
	print $lout;
	print "</td>";
      }
      $k++;
    }

    print "</tr>\n";
    $i++;
  }
  if (ref $addRow eq 'CODE') {
    print $addRow->($cData);
  }
  print "</table>\n";
}

## generic_smTable
## Arguments
##  - url to call
##  - rdata: data to print
##  - reference to a list of fields to print
##  - fieldmap_ref: an associative array mapping the field name to position in 
##                  array
##  - printable_ref: a reference to the printable versions of the field names
##  - extInfo: extra info to pass along to calls (ie 'sid=4')
##  - tName: table name
##  - delOp: opcode for deleting
##  - addRow: callback to a function that can print out the row to add
##            an entry (may be NULL)
##  - cData: data that will passed to the addRow function
##  - idFieldCol: see below
##  - infoprefix: for each row, generate clickable row using
##              $url+infoprefix+idFieldC

sub generic_smTable {
  my ($url, $rdata, $field_ref, $fieldmap_ref, $printable_ref, $extInfo,
      $tName, $delOp, $addRow, $cData, $idFieldCol, $infoprefix) = @_;
  my (@pFields, $keyField, $kout, $k, $m, $i);

  $extInfo = 'ig=nore' if ($extInfo eq '');
  map { push(@pFields, $fieldmap_ref->{$_}); } @{$field_ref};
  $keyField = $fieldmap_ref->{$idFieldCol} ;

  print "<table>\n";
  $i = 0;
  foreach $k (@{$rdata}) {
    $kout = (defined $keyField?$k->[$keyField]:'');
    print "<tr>" if ($i % 2 == 1);
    print "<tr bgcolor=$TACOLOR>" if ($i % 2 == 0);
    foreach $m (@pFields) {
      if ($i > 0) {
        if ($infoprefix ne '') {
	    print "<td><a tabindex=\"90\" href=\"".CMU::WebInt::encURL("$url?$infoprefix$kout")."\">$k->[$m]</a></td>\n";
	} else {
	    print "<td>$k->[$m]</td>\n";
        }

      }
      print "<td><font size=+1><b>".$printable_ref->{$k->[$m]}."</font></td>"
	if ($i == 0);
    }
    if ($delOp ne '') {
      print "<td><font size=+1><b>Operations</font></td>\n" if ($i == 0);
      print "<td><a tabindex=\"90\" href=\"".
		CMU::WebInt::encURL("$url?op=$delOp&$extInfo&v=".
      				    $k->[$fieldmap_ref->{"$tName.version"}]."&id=".
			 	    $k->[$fieldmap_ref->{"$tName.id"}]
				    )."\">Delete</td>" if ($i != 0);
    }
    print "</tr>\n";
    $i++;
  }
  if (ref $addRow) {
    print $addRow->($cData);
  }
  print "</table>\n";
}

## this really shouldn't be used for anything but as a very first step
## to make sure the functions are getting some reasonable data out
## of the DB.
sub generic_print_ref_table {
  my ($ref) = @_;
  my ($k, $m);
  return if (!ref $ref);
  print "<table>\n";

  foreach $k (@{$ref}) {
    print "<tr>";
    foreach $m (@{$k}) {
      print "<td>$m</td>\n";
    }
    print "</tr>\n";
  }
  print "</table>\n";
}

sub accessDenied {
    my ($table, $right, $row, $ulreq, $ulhad, $identity) = @_;
    print "<br><font size=+2 color=red><b>Access Denied</b></font><br>";
    print "You do not have the appopriate access to perform this operation.\n";

    if ($table ne '' || $right ne '' || $row ne '' ||
        $ulreq ne '' || $ulhad ne '' || $identity ne '') {
        print <<ADVERIFY;

<br><br>
<div class=\"adTitle\">Additional Details</div>
<table class=\"adVerify\">
  <tr><td class=\"adVerifyHeader\">Table</td>
      <td class=\"adVerifyCell\">$table</td></tr>

 <tr><td class=\"adVerifyHeader\">Right</td>
      <td class=\"adVerifyCell\">$right</td></tr>
 <tr><td class=\"adVerifyHeader\">Row</td>
      <td class=\"adVerifyCell\">$row</td></tr>
 <tr><td class=\"adVerifyHeader\">User Level Required</td>
      <td class=\"adVerifyCell\">$ulreq</td></tr>
 <tr><td class=\"adVerifyHeader\">User Level Determined</td>
      <td class=\"adVerifyCell\">$ulhad</td></tr>
 <tr><td class=\"adVerifyHeader\">Identity</td>
      <td class=\"adVerifyCell\">$identity</td></tr>
</table>
ADVERIFY
    }

}

## Prints the permission matrix
## Arguments:
##  - user (0) or group (1)
##  - printed ID ('kevinm' or 'net:admins')
##  - unique serial for this page
##  - read perm by default?
##  - write perm by default?

sub permMatrix {
  my ($type, $id, $serial, $read, $write) = @_;

  return "<tr><td>$id</td><td>
<input type=hidden name=IDtype$serial value=$type>
<input type=hidden name=ID$serial value=$id>
Read: <input type=checkbox name=read$serial ".($read ? " CHECKED " : "")." value=1>
 Write: <input type=checkbox name=write$serial ".($write ? " CHECKED " : "")." value=1>
</td></tr>";
}

sub printVerbose {
  my ($key, $verbose) = @_;
  return "<font size=-1 face=\"Arial,Helvetica,Geneva,Charter\">".
    $CMU::WebInt::vars::htext{$key}."</font><br />" if ($verbose ne '0');
}

sub pageHelpLink {
  my ($topic) = @_;
  my $res = "[<b><a tabindex=\"100\" target=_blank href=\"".CMU::WebInt::encURL("/help/pages/$helpPage.shtml");
  $res .= "#$topic" if ($topic ne '');
  $res .= "#$helpPage" if ($topic eq '');
  $res .= "\">Help</a></b>]";
  return $res;
}

sub inlineHelpLink {
  my ($topic) = @_;
  my $res = "<a tabindex=\"100\" target=_blank href=\"".CMU::WebInt::encURL("/help/pages/$helpPage.shtml")."\"";
  $res .= "#$topic" if ($topic ne '');
  $res .= "#$helpPage" if ($topic eq '');
  $res .= ">";
  return $res;
}

sub errorDialog {
  my ($url, $infoRef) = @_;
  my $res;
  my ($msg, $type, $code) = ($$infoRef{'msg'}, $$infoRef{'type'},
			     $$infoRef{'code'});
  my ($loc, $fields) = ($$infoRef{'loc'}, $$infoRef{'fields'});

  # We're going to set an environment variable so the result text
  # can be logged in the apache access log (or other custom log)
  if ($type eq 'ERR') {
    $res = "<table border=0 width=300 cellspacing=0 cellpadding=2>
<tr bgcolor=#f9aeae><td>
<font face=\"Arial,Helvetica,Charter,Geneva\" color=Red><b>Error</b></font></td>
<td align=right><font face=\"Arial,Helvetica,Charter,Geneva\" size=-1>
[<a tabindex=\"90\" target=_blank href=\"";
    $res .= CMU::WebInt::encURL("$url?op=err_lookup&errcode=$code&fields=$fields&location=$loc");
    $res .= "\">Explain this Error</a>]</font></td></tr>
  <tr bgcolor=#f9aeae><td colspan=2>$msg</td></tr></table><br />";
  }else{
    $res = "<table border=1 width=300 bgcolor=#96f986><tr><td>
<font face=\"Arial,Helvetica,Geneva,Charter\">$msg</font></td></tr></table><br />\n" if ($msg ne '');
  }
  
  return $res;
}

1;
