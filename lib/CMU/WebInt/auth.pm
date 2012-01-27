#   -*- perl -*-
#
# CMU::WebInt::auth
# This module provides the authorization screens.
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

package CMU::WebInt::auth;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings %users_pos %groups_pos
	     %uc_printable $debug %attr_pos);
use CMU::WebInt;
use CMU::Netdb;

use CMU::Netdb::UserMaint;

use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.03';
}

use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(auth_add_to_group auth_remove_from_group auth_groupinfo 
	     auth_userinfo auth_user_list auth_search_users auth_search_groups 
	     authmain auth_enviro_test auth_Print_Users auth_delete_group 
	     auth_update_user auth_Print_Groups auth_listgroups auth_add_group 
	     auth_add_user auth_delete_user auth_update_group auth_user_prefs
	     auth_user_cred cred_change_type user_type_mod user_type_perm_mod);

%errmeanings = %CMU::Netdb::errors::errmeanings;

my @UF = (@CMU::Netdb::structure::users_fields,
	  @CMU::Netdb::structure::credentials_fields);
%users_pos = %{CMU::Netdb::makemap(\@UF)};
%uc_printable = (%CMU::Netdb::structure::users_printable,
		 %CMU::Netdb::structure::credentials_printable);
%groups_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::groups_fields)};
%attr_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::attribute_fields)};

$debug = 0;

sub auth_user_list {
  my ($q) = @_;
  my ($dbh);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Users & Groups", {});
  &CMU::WebInt::title("List Users");
  my $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 1 if ($sort eq '');
  my %smap = (1 => 'credentials.authid',
	      2 => 'credentials.description');

  print CMU::WebInt::smallRight(CMU::WebInt::pageHelpLink(''));
  print "<font color=red>Error executing auth_Print_Users.</font><br>\n"
    if (&CMU::WebInt::auth_Print_Users($user, $dbh, $q, " TRUE ".
				       CMU::Netdb::verify_orderby($smap{$sort}),
				       $ENV{SCRIPT_NAME}, 
				       "op=auth_user_list&sort=$sort", 
				       'start') != 1);
  
  print CMU::WebInt::stdftr($q);
}

sub auth_user_cred {
  my ($q, $errors) = @_;
  
  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo('Real');

  my ($vres, $rSuperUsers) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'SuperUsers');
  $rSuperUsers = [$rSuperUsers] if ($vres == 1 && !(ref $rSuperUsers eq 'ARRAY'));

  my $UserAllowed = scalar grep /^$user$/i, @$rSuperUsers;
  if ($vres != 1 || $UserAllowed != 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Access Denied", $errors);
    CMU::WebInt::interface::accessDenied();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my ($author, $BGCOLOR);
  ($vres, $author) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'USER_MAIL');
  ($vres, $BGCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'BGCOLOR');

  if (CMU::WebInt::gParam($q, 'username') ne '') {
    my $newuser = CMU::WebInt::gParam($q, 'username');
    my $realm = CMU::WebInt::gParam($q, 'uidrealm');
    my $reason = CMU::WebInt::gParam($q, 'reason');
    $realm = '--none--' if (!$realm);

    if (($realm ne undef) and ($realm ne '--none--')) {
        $newuser = $newuser . '@' . $realm;
    }

    $reason = 'NO REASON PROVIDED!' if ($reason eq '');
    ## Send Mail
#    CMU::WebInt::admin_mail('auth.pm:auth_user_cred', 'NOTICE',
#			    'SWITCH-USER',
#			    {'user' => $newuser,
#			     'reason' => $reason});
    
    my ($swres, $SWUSERTIME) = CMU::Netdb::config::get_multi_conf_var('webint', 'Switch_User_Timeout');
    if (!defined($SWUSERTIME) || $swres == 0) {
	$SWUSERTIME = 5;
    }

    my $cookie = $q->cookie(-name => 'authuser',
			    -value => $newuser,
			    -expires => '+'.$SWUSERTIME.'m',
			    -path => '/',
#			    -domain => $ENV{SERVER_NAME},
			    -secure => 1);
    print $q->header(-cookie => $cookie);
    print $q->start_html(-title => 'Switching User',
			 -author => $author,
			 -BGCOLOR => $BGCOLOR);
    print "<meta HTTP-EQUIV=Refresh Content=\"1; URL=$ENV{SCRIPT_NAME}\">\n";
    print "<body>Setting user identity.</body></html>\n";
    return;
  }elsif(CMU::WebInt::gParam($q, 'CLEAR') eq '1') {
    my $cookie = $q->cookie(-name => 'authuser',
			    -value => '',
			    -expires => 'now',
			    -path => '/',
#			    -domain => $ENV{SERVER_NAME},
			    -secure => 1);
    print $q->header(-cookie => $cookie);
    print $q->start_html(-title => 'Switching User',
			     -author => $author,
                         -BGCOLOR => $BGCOLOR,);

    print "<meta HTTP-EQUIV=Refresh Content=\"1; URL=$ENV{SCRIPT_NAME}\">\n";
    print "<body>Resetting user identity.</body></html>\n";
    return;
  }
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Switch User Credentials",
			    $errors);
  &CMU::WebInt::title("Switch Credentials");
  
  print "<br><br>This interface enables you to access NetReg as though you 
were another user. All actions taken while having this identity will
occur as if the identity performed them.<br><br>\n";
  print "<hr>".CMU::WebInt::subHeading("Acquire Identity");
  print "<form method=get><input type=hidden name=op value=auth_user_cred>\n";
  print "Enter the username as NetReg would otherwise see it (including ".
    "trailing realm if appropriate). Identity acquisition expires in five ".
      "minutes.<br>\n";
  print "Username: " . $q->textfield(-name=>'username');

  CMU::WebInt::drawUserRealmPopup($q,"uidrealm","r");

  print "<br><br>".
    "Please describe your reason for acquiring this identity:<br>\n";
  print "<input type=text name=reason size=50>\n";
  print "<br><input type=submit value=\"Switch User\">\n";
  
  print CMU::WebInt::stdftr($q);
}  
  
sub auth_listgroups {
  my ($q, $errors) = @_;
  my ($dbh);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "List Groups", $errors);
  my $url = $ENV{SCRIPT_NAME};
  &CMU::WebInt::title("List Groups");
  print "<hr>\n";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight(CMU::WebInt::pageHelpLink(''));
  print "<font color=red>Error executing auth_Print_Groups.</font><br>\n"
    if (&CMU::WebInt::auth_Print_Groups($user, $dbh, $q, "", $ENV{SCRIPT_NAME}, 'op=auth_grp_list', 'start') != 1);
  
  print CMU::WebInt::stdftr($q);
}

sub auth_add_user_form {
  my ($q, $errors) = @_;
  my ($dbh, $url);

  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();
  my $al = CMU::Netdb::get_add_level($dbh, $user, 'users', 0);
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Add User", $errors);
  &CMU::WebInt::title("Add User");
  my $msg = $$errors{msg} if (ref $errors && defined $$errors{msg});
  
  if ($al < 1) {
    print "<br>";
    &CMU::WebInt::accessDenied('users', 'ADD', 0, 1, $al, $user);
    $dbh->disconnect;
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  print &CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));

  print "<form method=get><input type=hidden name=op value=auth_user_add>
<input type=hidden name=m value=add>";
  print "<table border=0>";

  print "<tr>".CMU::WebInt::printPossError(defined $$errors{comment}, $CMU::Netdb::structure::users_printable{'users.comment'}, 1, 'users.comment').
	    CMU::WebInt::printPossError(defined $$errors{flags}, $CMU::Netdb::structure::users_printable{'users.flags'}, 1, 'users.flags')."</tr>\n";
  
  print "<tr><td>".$q->textfield(-name => 'comment')."</td><td>".
    CMU::WebInt::printVerbose('users.flags', $verbose).
    $q->checkbox_group(-name => 'flags',
		       -values => \@CMU::Netdb::structure::users_flags).
			 "<tr><td>".
			   "<input type=submit value=\"Add User\"></td></tr></form></td></tr>\n"."</table>\n";

  print &CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub auth_add_user {
  my ($q) = @_;
  my ($dbh, $url, $m, %newu, $ret, $ref);

  $m = CMU::WebInt::gParam($q, 'm');
  if ($m ne 'add') {
    auth_add_user_form($q);
    return;
  }
  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();

  # add the user
  foreach (qw/comment/) {
    $newu{$_} = CMU::WebInt::gParam($q, $_);
  }
  $newu{'flags'} = join(',', CMU::WebInt::gParam($q, 'flags'));

  ($ret, $ref) = CMU::Netdb::add_user($dbh, $user, \%newu);
  my (%errors, $msg);
  if ($ret != 1) {
    $msg = "Error adding user: ".$errmeanings{$ret};
    $msg .= " (DB: ".$CMU::Netdb::primitives::db_errstr." ) " if ($ret == $CMU::Netdb::errcodes{EDB});
    $msg .= " [".join(',', @$ref)."] ";
    $errors{'msg'} = $msg;
    $errors{'code'} = $ret;
    $errors{'fields'} = join(',', @$ref);
    $errors{'type'} = 'ERR';
    $errors{'loc'} = 'auth_user_add';
    $dbh->disconnect;
    auth_add_user_form($q, \%errors);
  }else{
    $msg = "User was successfully added to the database.\n";
    $dbh->disconnect;
    $q->param('u', $$ref{insertID});
    &CMU::WebInt::auth_userinfo($q, \%errors);
  }
}

sub auth_add_group_form {
  my ($q, $errors) = @_;
  my ($dbh, $url);

  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();
  my $al = CMU::Netdb::get_add_level($dbh, $user, 'groups', 0);
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Add Group", $errors);
  &CMU::WebInt::title("Add Group");
  
  if ($al < 1) {
    print "<br>";
    &CMU::WebInt::accessDenied('groups', 'ADD', 0, 1, $al, $user);
    $dbh->disconnect;
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  print &CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));

  print "<form method=get><input type=hidden name=op value=auth_grp_add>
<input type=hidden name=m value=add>";
  print "<table border=0>";
  print "<tr>".CMU::WebInt::printPossError(defined $$errors{name}, $CMU::Netdb::structure::groups_printable{'groups.name'}, 1, 'groups.name').
    CMU::WebInt::printPossError(defined $$errors{description}, $CMU::Netdb::structure::groups_printable{'groups.description'}, 1, 'groups.description')."</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('groups.name', $verbose);
  print $q->textfield(-name => 'name');
  print "</td><td>".CMU::WebInt::printVerbose('groups.description', $verbose);
  print $q->textfield(-name => 'description');
  print "</td></tr>\n<tr>".CMU::WebInt::printPossError(defined $$errors{comment_lvl9}, $CMU::Netdb::structure::groups_printable{'groups.comment_lvl9'}, 1, 'groups.comment_lvl9').
    CMU::WebInt::printPossError(defined $$errors{flags}, $CMU::Netdb::structure::groups_printable{'groups.flags'}, 'groups.flags')."</tr>\n";

  print "<tr><td>".
    CMU::WebInt::printVerbose('groups.comment_lvl9', $verbose).
    $q->textfield(-name => 'comment_lvl9')."</td><td>".
    CMU::WebInt::printVerbose('groups.flags', $verbose).
    $q->checkbox_group(-name => 'flags',
		       -values => \@CMU::Netdb::structure::groups_flags);
  print "<tr><td>".
    "<input type=submit value=\"Add Group\"></td></tr></form></td></tr>\n";
  print "</table>\n";	
  print &CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub auth_add_group {
  my ($q) = @_;
  my ($dbh, $url, $m, $msg, %newu, $ret, $ref);

  $m = CMU::WebInt::gParam($q, 'm');
  if ($m ne 'add') {
    auth_add_group_form($q);
    return;
  }
  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();

  # add the user
  foreach (qw/name description comment_lvl9/) {
    $newu{$_} = CMU::WebInt::gParam($q, $_);
  }
  $newu{'flags'} = join(',', CMU::WebInt::gParam($q, 'flags'));

  ($ret, $ref) = CMU::Netdb::add_group($dbh, $user, \%newu);
  my %errors;
  if ($ret != 1) {
    $msg = "Error adding user: ".$errmeanings{$ret};
    $msg .= " (DB: ".$CMU::Netdb::primitives::db_errstr." ) " if ($ret == $CMU::Netdb::errcodes{EDB});
    $msg .= " [".join(',', @$ref)."] ";
    $errors{'msg'} = $msg;
    $errors{type} = 'ERR';
    $errors{code} = $ret;
    $errors{loc} = 'auth_grp_add';
    $errors{fields} = join(',', @$ref);
    $dbh->disconnect;
    auth_add_group_form($q, \%errors);
  }else{
    $msg = "Group was successfully added to the database.\n";
    $dbh->disconnect;
    $q->param('g', $$ref{insertID});
    &CMU::WebInt::auth_groupinfo($q, \%errors);
  }
}

sub auth_groupinfo {
  my ($q, $errors) = @_;
  my ($dbh, $g, $rGinfo, $rGmem, $i, $url, $out, @ginfo);
  
  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  $g = CMU::WebInt::gParam($q, 'g');
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "View Group Info", $errors);
 
  my $gName = CMU::WebInt::gParam($q, 'gName');
  if ($gName eq 'system:anyuser') {
    &CMU::WebInt::title("Group Information: Error");
    print "<br>The <b>system:anyuser</b> group is a special group of all valid ".
      "NetReg users. Enumeration of all users is not available.\n";
    print &CMU::WebInt::stdftr($q); 
    $dbh->disconnect;
    return;
  }
  if ((!defined $g || $g eq '') && $gName ne '') {
    my $gi = CMU::Netdb::list_groups($dbh, 'netreg', "name = '$gName'");
    $g = ${$gi->[1]}[$groups_pos{'groups.id'}] if (defined $gi && defined $gi->[1]);

  } 

  my ($rl, $wl) = (CMU::Netdb::get_read_level($dbh, $user, 'groups', $g), 
		   CMU::Netdb::get_write_level($dbh, $user, 'groups', $g));

  if ($rl < 1) {
    &CMU::WebInt::title("Access Denied");
    &CMU::WebInt::accessDenied('groups', 'READ', $g, 1, $rl, $user); 
    print &CMU::WebInt::stdftr($q); 
    $dbh->disconnect;
    return;
  }

  $rGinfo = CMU::Netdb::list_groups($dbh, $user, " groups.id = '$g' ");
  if (!ref $rGinfo || !defined $rGinfo->[1]) {
    &CMU::WebInt::title("Group Information: Error");
    print "<br>Error in list_groups: ".$errmeanings{$rGinfo}."<br>\n";
    print " [DB: ".$CMU::Netdb::primitives::db_errstr." ] <br>" if ($rGinfo == $CMU::Netdb::errcodes{EDB});
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  @ginfo = @{$rGinfo->[1]};

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  &CMU::WebInt::title("Group Information for: ".$ginfo[$groups_pos{'groups.description'}]);
  print "<hr>\n";
  print CMU::WebInt::errorDialog($url, $errors);

  if ($wl >= 1) {
    print "<form method=get action=$url>
<input type=hidden name=version value=\"".$ginfo[$groups_pos{'groups.version'}]."\">
<input type=hidden name=id value=\"".$ginfo[$groups_pos{'groups.id'}]."\">
<input type=hidden name=op value=auth_grp_upd>
<input type=hidden name=g value=$g>
<input type=hidden name=sop value=auth_grp_info>";
  }

  print &CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  if ($wl >= 9) {
    print CMU::WebInt::smallRight("[<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_grp_info&g=$g")."\">Refresh</a></b>] [<a href=$url?op=prot_s3&table=groups&tidType=1&tid=$g><b>View/Update Protections</b></a>] [<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_grp_del&id=$g&version=".$ginfo[$groups_pos{'groups.version'}])."\">Delete this Group</a></b>]\n");
  } else {
    print CMU::WebInt::smallRight("[<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_grp_info&g=$g")."\">Refresh</a></b>]\n");
  }
  print "<table border=0>\n";
  print "<tr>".CMU::WebInt::printPossError(defined $$errors{name}, $CMU::Netdb::structure::groups_printable{'groups.name'}, 1, 'groups.name').
    CMU::WebInt::printPossError(defined $$errors{description}, $CMU::Netdb::structure::groups_printable{'groups.description'}, 1, 'groups.description')."</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('groups.name', $verbose);
  if ($wl >= 9) {
    print $q->textfield(-name => 'name',
			-value => $ginfo[$groups_pos{'groups.name'}])
  }elsif ($wl >= 1) {
    print "<input type=hidden name=name value=". $ginfo[$groups_pos{'groups.name'}] . ">\n";
    print $ginfo[$groups_pos{'groups.name'}];
  } else {
    print $ginfo[$groups_pos{'groups.name'}];
  }
  print "</td><td>".CMU::WebInt::printVerbose('groups.description', $verbose);
  if ($wl >= 1) {
    print $q->textfield(-name => 'description',
			-value => $ginfo[$groups_pos{'groups.description'}]);
  }else{ 
    print $ginfo[$groups_pos{'groups.description'}];
  }

  print "</td></tr>\n";

  if ($rl >= 5) {
    print "<tr>". 
      CMU::WebInt::printPossError(defined $$errors{comment_lvl5}, 
		     $CMU::Netdb::structure::groups_printable{'groups.comment_lvl5'}, 1, 'comment_lvl5') . "</tr>\n";

    print "<tr><td>".CMU::WebInt::printVerbose('groups.comment_lvl5', $verbose).
      ($wl >= 5 
       ? $q->textfield(-name => 'comment_lvl5',
		       -value => $ginfo[$groups_pos{'groups.comment_lvl5'}]) 
       : $ginfo[$groups_pos{'groups.comment_lvl5'}]).
	 "</td></tr>\n";
  }

  if ($rl >= 9) {
    print "<tr>".
      CMU::WebInt::printPossError(defined $$errors{comment_lvl9}, 
		     $CMU::Netdb::structure::groups_printable{'groups.comment_lvl9'}, 1, 'comment_lvl9')
	. CMU::WebInt::printPossError(defined $$errors{flags}, 
			 $CMU::Netdb::structure::groups_printable{'groups.flags'},
			 1, 'groups.flags')."</tr>\n";
    my @sflags = split(/\,/, $ginfo[$groups_pos{'groups.flags'}]);
    
    print "<tr><td>".CMU::WebInt::printVerbose('groups.comment_lvl9', $verbose).
      ($wl >= 9 
       ? $q->textfield(-name => 'comment_lvl9',
		       -value => $ginfo[$groups_pos{'groups.comment_lvl9'}]) 
       : $ginfo[$groups_pos{'groups.comment_lvl9'}]).
	 "</td><td>".CMU::WebInt::printVerbose('groups.flags', $verbose).
	   ($wl >= 9 
	    ? $q->checkbox_group(-name => 'flags',
				 -values => \@CMU::Netdb::structure::groups_flags,
				 -defaults => \@sflags) 
	    : $ginfo[$groups_pos{'groups.flags'}])."</td></tr>\n";
  }
  print "<tr><td><input type=submit value=\"Update Group\"></td></tr></form></td></tr>\n" if ($wl >= 1);
  print "</table>\n";
  
  if ($rl >= 5) {
    print &CMU::WebInt::subHeading("Group Members", CMU::WebInt::pageHelpLink(''));
    $rGmem = CMU::Netdb::list_members_of_group($dbh, $user, $g, 
					       ' TRUE ORDER BY credentials.authid');
    my %lmgPos = %{CMU::Netdb::makemap($rGmem->[0])};
    if (!ref $rGmem) {
      print "error in list_members_of_group: ".$errmeanings{$rGmem}."<br>\n";
    }else{
      CMU::WebInt::generic_tprint($url, $rGmem, ['credentials.authid',
						 'credentials.description'], 
		     [\&auth_cb_UserRemove], "sop=auth_grp_info&g=$g", '', 'op=auth_user_info&u=',
		     \%lmgPos, \%uc_printable,
		     'credentials.authid', 'users.id', '', []);
    }
  }
  if ($wl >= 5) {
    # Add User
    print "<br>".&CMU::WebInt::subHeading("Add User to Group", CMU::WebInt::pageHelpLink(''));
    print "<table border=1>
<tr><td><form action=$url method=get><input type=hidden name=op value=auth_ug_add><br>\n
<input type=hidden name=g value=\"$g\"><input type=hidden name=src value=auth_grp_info>
UserID: <input type=text name=u>"; CMU::WebInt::drawUserRealmPopup($q,"uidrealm","r");
print "<input type=submit value=\"Add User\"></td></tr>
</table>\n";
  }

  # attributes
  print "<br>";
  CMU::WebInt::attr_display($dbh, $user, 'groups', $g);;

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub auth_add_to_group {
  my ($q) = @_;
  my ($dbh, $uidrealm, $u, $g, $msg, $res, $ref, $src);
  
  $u = CMU::WebInt::gParam($q, 'u');
  $uidrealm = CMU::WebInt::gParam($q, 'uidrealm');
  $u = "$u\@$uidrealm" if (($uidrealm ne undef) && ($uidrealm ne '--none--'));

  $g = CMU::WebInt::gParam($q, 'g');
  $src = CMU::WebInt::gParam($q, 'src');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();
  ($res, $ref) = CMU::Netdb::add_user_to_group($dbh, $user, $u, $g);
  my %errors;
  if ($res != 1) {
    $errors{msg} = "Error adding user $u to group $g: ".$errmeanings{$res};
    $errors{msg} .= " (DB: ".$CMU::Netdb::primitives::db_errstr." ) \n" if ($res == $CMU::Netdb::errcodes{EDB});
    $errors{msg} .= " [".join(',', @$ref)."] ";
    $errors{fields} = join(',', @$ref);
    $errors{loc} = 'auth_ug_add';
    $errors{code} = $res;
    $errors{type} = 'ERR';
  }else{
    $errors{msg} = "User $u successfully added to group $g.";
  }
  if ($src eq 'auth_grp_info') {
    CMU::WebInt::auth_groupinfo($q, \%errors);
  }else{
    auth_oops($q, $msg);
  }
  print $dbh->disconnect;
}

sub auth_remove_from_group {
  my ($q) = @_;
  my ($dbh, $u, $g, $msg, $res, $ref, $sop);
  
  $u = CMU::WebInt::gParam($q, 'u');
  $g = CMU::WebInt::gParam($q, 'g');
  $sop = CMU::WebInt::gParam($q, 'sop');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();
  ($res, $ref) = CMU::Netdb::delete_user_from_group($dbh, $user, $u, $g);
  my %errors = ('msg' => $msg,
		'code' => $res,
		'loc' => 'auth_ug_add');
  if ($res != 1) {
    $msg = "Error removing user $u from group $g: ".$errmeanings{$res};
    $msg .= " (DB: ".$CMU::Netdb::primitives::db_errstr." ) \n" if ($res == $CMU::Netdb::errcodes{EDB});
    $msg .= " [".join(',', @$ref)."] ";
    $errors{msg} = $msg;
    $errors{type} = 'ERR';
    $errors{fields} = join(',', @$ref);
  }else{
    $errors{msg} = "User $u removed from group $g.";
  }

  if ($sop eq 'auth_grp_info') {
    CMU::WebInt::auth_groupinfo($q, \%errors);
  }elsif($sop eq 'auth_user_info') {
    CMU::WebInt::auth_userinfo($q, \%errors);
  }else{
    auth_oops($q, $msg);
  }
  $dbh->disconnect;
}  

  
sub auth_userprefs {
  my ($q, $errors) = @_;
  my ($dbh, $i, @tarr, $rUmem, $u, $rUinfo, $url);
  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "User Preferences", $errors);
  $u = CMU::WebInt::gParam($q, 'u');

  my ($rl, $wl) = (CMU::Netdb::get_read_level($dbh, $user, 'users', $u), 
		   CMU::Netdb::get_write_level($dbh, $user, 'users', $u));

  if ($rl < 1) {
    &CMU::WebInt::title("Access Denied");
    &CMU::WebInt::accessDenied('users', 'READ', $u, 1, $rl, $user); 
    &CMU::WebInt::stdftr($q); 
    $dbh->disconnect;
    return;
  }

  $rUinfo = CMU::Netdb::list_users($dbh, $user, " users.id = \'$u\' ");
  if (!ref $rUinfo) {
    &CMU::WebInt::title("User Information: Error");
    print "error in CMU::Netdb::list_users: ".$errmeanings{$rUinfo}."<br>\n";
    print " [DB: ".$CMU::Netdb::primitives::db_errstr." ] <br>" if ($rUinfo == $CMU::Netdb::errcodes{EDB});
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
 } elsif ( !defined $rUinfo->[1]) {
    &CMU::WebInt::title("User Information: Error");
    print "<p>$u: No such user\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  
  &CMU::WebInt::title("User Preferences for: ".$tarr[$users_pos{'users.description'}]);

  # Get a list of all valid attributes
  my $where = "attribute_spec.scope = 'users'";
  
  my $attsr = CMU::Netdb::list_attribute_spec_ref($dbh, $user, $where,
						  "attribute_spec.name");
  
  my $attForm = CMU::Netdb::list_attribute_spec_ref($dbh, $user, $where,
						    "attribute_spec.format");

  if (!ref $attsr || !ref $attForm) {
    print "No attributes found.\n";
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  ## General form info
  print "<form method=get><input type=hidden name=op value=auth_userpref_update>";

  ## Get all the attributes of this user
  my %Attributes;
  my $attrs = CMU::Netdb::list_attribute($dbh, $user,
					 "attribute.owner_table = 'users' ".
					 "AND attribute.owner_tid = $u ");
  if (!ref $attrs) {
    print "ERROR retrieving attributes from list_attribute: ".$errmeanings{$attrs};
  }else{
    my %pos = %{CMU::Netdb::makemap($attrs->[0])};
    shift(@$attrs);

    foreach my $Rec (@$attrs) {
      $Attributes{$Rec->[$pos{'attribute_spec.name'}]} = 
	$Rec->[$pos{'attribute.data'}];
    }
  }
  
  ## Machine_Sort_Field
  my $SField = -1;
  foreach (keys %$attsr) {
    if ($attsr->{$_} eq 'Machine_Sort_Field') {
      $SField = $_;
    }
  }
  
  print &subHeading("Machine Sort Field");
  print "The field selected here will always be used initially to sort ".
    "lists of machines. You can always sort by a different field during ".
      "normal usage.\n";
}

sub user_type_mod {
  my ($q, $errors) = @_;

  my $url = $ENV{SCRIPT_NAME};

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo('Real');


  my $rl = CMU::Netdb::get_read_level($dbh, $user, 'user_type', 0);

  if ($rl < 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Access Denied", $errors);
    CMU::WebInt::interface::accessDenied();
    print CMU::WebInt::stdftr($q);
    return;
  }

  print CMU::WebInt::stdhdr($q, $dbh, $user, "User Types", $errors);
  &CMU::WebInt::title("User Types Configuration");

  print "<hr>\n";
  print CMU::WebInt::errorDialog($url, $errors);

  print "<p>This changes the user types configuration.</p>";

  my $result = CMU::Netdb::UserMaint::list_user_types($dbh, $user);
  if (!ref $result) {
    print "Error getting user_types! :: $result";
  } else {
    my $lmgPos = CMU::Netdb::makemap(@$result[0]);

    CMU::WebInt::generic_tprint($url, $result, ['user_type.name', 'user_type.expire_days_mach', 'user_type.expire_days_outlet'],
                     [\&ut_cb_m_m, \&ut_cb_o_m, \&ut_cb_disable_acct, \&ut_cb_operations], [$lmgPos, $dbh, $user], '', '',
                     $lmgPos, \%CMU::Netdb::structure::user_type_printable, '', '', '', [], \&ut_cb_addrow , [$url, $dbh, $user]);
         }

  print CMU::WebInt::stdftr($q);
}

sub user_type_del {
  my ($q, $errors) = @_;

  my $url = $ENV{SCRIPT_NAME};

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo('Real');

  my $al = CMU::Netdb::get_add_level($dbh, $user, 'user_type', 0);

  if ($al < 9) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Access Denied", $errors);
    CMU::WebInt::interface::accessDenied();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my ($res, $err) = CMU::Netdb::UserMaint::delete_user_type($dbh, $user, CMU::WebInt::gParam($q, 'id'), CMU::WebInt::gParam($q, 'version'));

  if ($res < 0) {
    CMU::WebInt::user_type_mod($q, {'msg' => "$CMU::Netdb::errors::errmeanings{$res}: [".join(', ', @$err)."]",
                                    'type'=>'ERR',
                                    'code'=>$res});
  } else {
    CMU::WebInt::user_type_mod($q, {'msg'=>"Deleted!"});
  }

  return;
}

sub ut_add {
  my ($q, $errors) = @_;

  my $url = $ENV{SCRIPT_NAME};

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo('Real');

  my $al = CMU::Netdb::get_add_level($dbh, $user, 'user_type', 0);

  if ($al < 9) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Access Denied", $errors);
    CMU::WebInt::interface::accessDenied();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $name = CMU::WebInt::gParam($q, 'name');
  my $m_d_e = CMU::WebInt::gParam($q, 'm_d_e');
  my $o_d_e = CMU::WebInt::gParam($q, 'o_d_e');
  my $m_m = CMU::WebInt::gParam($q, 'm_m');
  my $o_m = CMU::WebInt::gParam($q, 'o_m');
  my $disable = CMU::WebInt::gParam($q, 'disable');

  my $e = "";

  if (!($name =~ /^[a-zA-Z]+$/)) {
    $e .= " - User Type name may only contain alpha characters<br />";
  }

  if (!($m_d_e =~ /^\d+$/) || !($o_d_e =~ /^\d+$/)) {
    $e .= " - Days must be a numeric value<br />";
  }

  if ((($m_m ne "") && ($m_m ne "on")) || (($o_m ne "") && ($o_m ne "on")) || (($disable ne "") && ($disable ne "on"))) {
    $e .= " - Incorrect checkbox state<br />";
  }

  if ($e ne "") {
    CMU::WebInt::user_type_mod($q, {'msg'=>"Invalid data: <br />$e", 'type'=>'ERR', 'code'=>'0'});
    return;
  }

  if ($m_m eq "") { $m_m = 0; } else { $m_m = 1; }
  if ($o_m eq "") { $o_m = 0; } else { $o_m = 1; }
  if ($disable eq "") { $disable = 0; } else { $disable = 1; }

  my $data = {
    'name' => $name,
    'm_d_e' => $m_d_e,
    'o_d_e' => $o_d_e,
    'm_m' => $m_m,
    'o_m' => $o_m,
    'disable' => $disable,
  };

  my ($res, $err) = CMU::Netdb::UserMaint::add_user_type($dbh, $user, $data);

  if ($res < 0) {
    CMU::WebInt::user_type_mod($q, {'msg'=>$errmeanings{$res}, 'type'=>'ERR', 'code'=>$res});
  } else {
    CMU::WebInt::user_type_mod($q, {'msg'=>'Complete!'});
  }

  return;
}

sub ut_modify {
  my ($q, $errors) = @_;

  my $url = $ENV{SCRIPT_NAME};

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo('Real');

  my $rl = CMU::Netdb::get_read_level($dbh, $user, 'user_type', 0);
  if ($rl < 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Access Denied", $errors);
    CMU::WebInt::interface::accessDenied();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  my $name = CMU::WebInt::gParam($q, 'name');
  my $m_d_e = CMU::WebInt::gParam($q, 'm_d_e');
  my $o_d_e = CMU::WebInt::gParam($q, 'o_d_e');
  my $m_m = CMU::WebInt::gParam($q, 'm_m');
  my $o_m = CMU::WebInt::gParam($q, 'o_m');
  my $disable = CMU::WebInt::gParam($q, 'disable');

  my $e = "";

  if (!($name =~ /^[a-zA-Z]+$/)) {
    $e .= " - User Type name may only contain alpha characters<br \>";
  }

  if (!($m_d_e =~ /^\d+$/) || !($o_d_e =~ /^\d+$/)) {
    $e .= " - Days must be a numeric value<br \>";
  }

  if ((($m_m ne "") && ($m_m ne "on")) || (($o_m ne "") && ($o_m ne "on")) || (($disable ne "") && ($disable ne "on"))) {
    $e .= " - Incorrect checkbox state<br \>";
  }

  if ($e ne "") {
    CMU::WebInt::user_type_mod($q, {'msg'=>"Invalid data: <br \>$e", 'type'=>'ERR', 'code'=>'0'});
    return;
  }

  if ($m_m eq "") { $m_m = 0; } else { $m_m = 1; }
  if ($o_m eq "") { $o_m = 0; } else { $o_m = 1; }
  if ($disable eq "") { $disable = 0; } else { $disable = 1; }

  my $data = {
    'name' => $name,
    'm_d_e' => $m_d_e,
    'o_d_e' => $o_d_e,
    'm_m' => $m_m,
    'o_m' => $o_m,
    'disable' => $disable,
  };

  my ($res, $err) = CMU::Netdb::UserMaint::modify_user_type($dbh, $user, $id, $version, $data);

  if ($res < 0) {
    CMU::WebInt::user_type_mod($q, {'msg'=>$errmeanings{$res}, 'type'=>'ERR', 'code'=>$res});
  } else {
    CMU::WebInt::user_type_mod($q, {'msg'=>'Complete!'});
  }

  return;
}

sub user_type_change {
  my ($q, $errors) = @_;

  my $url = $ENV{SCRIPT_NAME};

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo('Real');

  my $id = CMU::WebInt::gParam($q, 'u');

  $id = CMU::Netdb::valid('user_type.id', $id, $user, 0, $dbh);
  if (CMU::Netdb::getError($id) != 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Access Denied", $errors);
    CMU::WebInt::interface::accessDenied();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $rl = CMU::Netdb::get_read_level($dbh, $user, 'user_type', $id);

  if ($rl < 1) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Access Denied", $errors);
    CMU::WebInt::interface::accessDenied();
    print CMU::WebInt::stdftr($q);
    return;
  }


  my $user_types = CMU::Netdb::UserMaint::list_user_types($dbh, $user, "user_type.id = '$id'");

  if (!ref $user_types) {
    warn "$user_types is not a reference to an array like it should be.";
    my $err = -9;
    CMU::WebInt::user_type_mod($q, {'msg'=>$errmeanings{$err}, 'type'=>'ERR', 'code'=>$err});
    return;
  }

  my $ut_map = CMU::Netdb::makemap(shift @$user_types);

  # if there's only one entry, nothing was returned, so there's no type by the name of $type.
  if (scalar @$user_types < 1) {
    warn "user_type doesn't exist or doesn't have enough permissions: $id";
    my $err = -2;
    CMU::WebInt::user_type_mod($q, {'msg'=>$errmeanings{$err}, 'type'=>'ERR', 'code'=>$err});
    return;
}

  print CMU::WebInt::stdhdr($q, $dbh, $user, "Modify User Type", $errors);

  my $ut_id = $user_types->[0][$ut_map->{'user_type.id'}];

  print CMU::WebInt::subHeading("Information for: " . $user_types->[0][$ut_map->{'user_type.name'}], CMU::WebInt::pageHelpLink(''));

  my $html = "<form method=get action=$url><input type=hidden name=id value=$id /><input type=hidden name=version value=\"". $user_types->[0][$ut_map->{'user_type.version'}] ."\" /><input type=hidden name=op value=ut_modify />";
  $html .= "<table><tr><td>".$CMU::Netdb::structure::user_type_printable{'user_type.name'}."</td>";
  $html .= "<td><input type=text name=name value=\"".$user_types->[0][$ut_map->{'user_type.name'}] . "\" /></td></tr>";
  $html .= "<tr><td>".$CMU::Netdb::structure::user_type_printable{'user_type.expire_days_mach'}."</td>";
  $html .= "<td><input type=text name=m_d_e value=\"". $user_types->[0][$ut_map->{'user_type.expire_days_mach'}]. "\" /></td></tr>";
  $html .= "<tr><td>".$CMU::Netdb::structure::user_type_printable{'user_type.expire_days_outlet'}."</td>";
  $html .= "<td><input type=text name=o_d_e value=\"". $user_types->[0][$ut_map->{'user_type.expire_days_outlet'}] ."\" /></td></tr>";
  $html .= "<tr><td>Send Email for Machines</td><td><input type=checkbox name=m_m value=\"on\" ";

  if (index($user_types->[0][$ut_map->{'user_type.flags'}], 'send_email_mach') >= 0) { $html .= "checked"; }
  $html .= " /></td></tr><tr><td>Send Email for Outlets</td><td><input type=checkbox name=o_m value=\"on\" ";
  if (index($user_types->[0][$ut_map->{'user_type.flags'}], 'send_email_outlet') >= 0) { $html .= "checked"; }
  $html .= " /></td></tr>";
  $html .= "<tr><td>Disable Account</td><td><input type=checkbox name=disable value=\"on\" ";
  if (index($user_types->[0][$ut_map->{'user_type.flags'}], 'disable_acct') >= 0) { $html .= "checked"; }
  $html .= " /></td></tr>";
  $html .= "<tr><td><input type=submit name=submit value=\"Change\" /></td></tr></table>";
  print $html;

  print CMU::WebInt::stdftr($q);
}

sub cred_change_type {
  my ($q, $errors) = @_;
  my ($dbh, $i, @tarr, $rUmem, $u, $c, $rUinfo, $url);

  my ($cupdate) = (1); # can update
  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Change Type", $errors);
  $u = CMU::WebInt::gParam($q, 'u');
  $c = CMU::WebInt::gParam($q, 'c');

  if (!($u =~ /^\d+$/) || !($c =~ /^\d+$/)) {
    warn "possible sql injection? u=$u, c=$c";

    print "Temporary Error Occured";

    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;

    return 1;
  }

  my ($rl, $wl) = (CMU::Netdb::get_read_level($dbh, $user, 'users', $u),
                   CMU::Netdb::get_write_level($dbh, $user, 'users', $u));

  if ($rl < 1) {
    &CMU::WebInt::title("Access Denied");
    &CMU::WebInt::accessDenied();
    &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }


  my $users = CMU::Netdb::auth::list_credentials($dbh, $user, "credentials.id = $c");
  if (!ref $users) {
    warn "failure: $users";

    &CMU::WebInt::title("Database Error");
    &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $usersmap = CMU::Netdb::makemap(shift @$users);

  my $credid = $users->[0][$usersmap->{'credentials.id'}];
  my $credver = $users->[0][$usersmap->{'credentials.version'}];
  my $credusr = $users->[0][$usersmap->{'credentials.user'}];
  my $credauthid = $users->[0][$usersmap->{'credentials.authid'}];
  my $credtype = $users->[0][$usersmap->{'credentials.type'}];

  my $types = CMU::Netdb::UserMaint::list_user_types($dbh, $user);
  my $types_map = CMU::Netdb::helper::makemap(shift @$types);

  my %list_o_types;
  foreach my $t (@$types) {
    $list_o_types{$t->[$types_map->{'user_type.name'}]} = $t->[$types_map->{'user_type.id'}];
  }

  my %rev_types = reverse %list_o_types;

  my $curtype = $rev_types{$credtype};

  if ($curtype eq '') { $curtype = "none"; }

  my @t = keys %rev_types;

  $q->param('op','cred_change_type_doit');

  print $q->start_form(-method=>'GET', -action=>$url), $q->hidden(-name=>'op', -default=>['cred_change_type_doit']);
  print $q->hidden(-name=>'v', -default=>[$credver]), $q->hidden(-name=>'c', -default=>[$credid]), $q->hidden(-name=>'u', -default=>[$credusr]);
  print $q->hidden(-name=>'authid', -default=>[$credauthid]);
  print "<p>Current user type for <b>$credauthid</b> is <b>$curtype</b></p>";
  print "<p>Pick a new user type: ", $q->popup_menu(-name => 'type',-values => \@t,-default => $curtype,-labels => \%rev_types);
  print "</p>", $q->submit(-name=>'submit', -value=>'Change'), $q->end_form;

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub cred_change_type_doit {
  my ($q, $errors) = @_;

  my ($cupdate) = (1); # can update
  my $dbh = CMU::WebInt::db_connect();
  my $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $v = CMU::WebInt::gParam($q, 'v');
  my $c = CMU::WebInt::gParam($q, 'c');
  my $u = CMU::WebInt::gParam($q, 'u');
  my $type = CMU::WebInt::gParam($q, 'type');
  my $authid = CMU::WebInt::gParam($q, 'authid');

  my ($rl, $wl) = (CMU::Netdb::get_read_level($dbh, $user, 'users', $u),
                   CMU::Netdb::get_write_level($dbh, $user, 'users', $u));

  if (($rl < 1) || ($wl < 1)) {
    &CMU::WebInt::title("Access Denied");
    &CMU::WebInt::accessDenied();
    &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $users = CMU::Netdb::auth::list_credentials($dbh, $user, "credentials.id = $c");
  if (!ref $users) {
    warn "failure: $users";

    &CMU::WebInt::title("Database Error");
    &CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $types = CMU::Netdb::UserMaint::list_user_types($dbh, $user);
  my $types_map = CMU::Netdb::helper::makemap(shift @$types);

  my %list_o_types;
  foreach my $t (@$types) {
    $list_o_types{$t->[$types_map->{'user_type.id'}]} = $t->[$types_map->{'user_type.name'}];
  }

  if ($list_o_types{$type} eq undef) {
    CMU::WebInt::auth_userinfo($q, {'msg'=>"Failure modifying credential type: bad user type", 'type'=>'ERR', 'code'=>'0'});
    return;
  }

  my %fields = (
    'credentials.type' => $type,
    'credentials.authid' => $authid
  );

  my $result = CMU::Netdb::primitives::modify($dbh, $user, 'credentials', $c, $v, \%fields);

  if ($result ne 1) {
    CMU::WebInt::auth_userinfo($q, {'msg'=>"Failure modifying credential type ($result)", 'type'=>'ERR', 'code'=>$result});
    return;
  }

  CMU::WebInt::auth_userinfo($q, {'msg'=>'Changed user type'});
}

sub auth_userinfo {
  my ($q, $errors) = @_;
  my ($dbh, $i, @tarr, $rUmem, $u, $rUinfo, $url);
  
  my ($cupdate) = (1); # can update
  $dbh = CMU::WebInt::db_connect();
  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "View User Info", $errors);
  $u = CMU::WebInt::gParam($q, 'u');
  
  my ($rl, $wl) = (CMU::Netdb::get_read_level($dbh, $user, 'users', $u), 
		   CMU::Netdb::get_write_level($dbh, $user, 'users', $u));

  if ($rl < 1) {
    &CMU::WebInt::title("Access Denied");
    &CMU::WebInt::accessDenied('users', 'READ', $u, 1, $rl, $user); 
    &CMU::WebInt::stdftr($q); 
    $dbh->disconnect;
    return;
  }

  $rUinfo = CMU::Netdb::list_users($dbh, $user, " users.id = \'$u\' ");
  if (!ref $rUinfo) {
    &CMU::WebInt::title("User Information: Error");
    print "<p>$u :\n";
    print "error in CMU::Netdb::list_users: ".$errmeanings{$rUinfo}."<br>\n";
    print " [DB: ".$CMU::Netdb::primitives::db_errstr." ] <br>" if ($rUinfo == $CMU::Netdb::errcodes{EDB});
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  } elsif ( !defined $rUinfo->[1]) {
    &CMU::WebInt::title("User Information: Error");
    print "<p>$u: No such user\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  my %rUPos = %{CMU::Netdb::makemap($rUinfo->[0])};

  @tarr = @{$rUinfo->[1]};
  &CMU::WebInt::title("User Information for User #".$tarr[$rUPos{'users.id'}]);
  print "<hr>\n";
  print CMU::WebInt::errorDialog($url, $errors);

  if ($wl >= 1) {
    print "<form method=get action=$url>
<input type=hidden name=version value=\"".$tarr[$users_pos{'users.version'}]."\">
<input type=hidden name=id value=\"".$tarr[$users_pos{'users.id'}]."\">
<input type=hidden name=op value=auth_user_upd>
<input type=hidden name=u value=$u>
<input type=hidden name=sop value=userinfo>";
  }

  print &CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_user_info&u=$u")."\">Refresh</a></b>]
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_user_del&id=$u&version=".$tarr[$users_pos{'users.version'}])."\">Delete this User</a></b>]\n");

  # basic info
  print "<table border=0>";
  # comment

  print "<tr>".CMU::WebInt::printPossError
    (defined $$errors{comment},
     $CMU::Netdb::structure::users_printable{'users.comment'}, 1,
     'users.comment');

  print CMU::WebInt::printPossError(defined $$errors{flags},
				    $CMU::Netdb::structure::users_printable{'users.flags'},
				    1, 'users.flags')."</tr>\n";

  my @sflags = split(/\,/, $tarr[$users_pos{'users.flags'}]);

  print "<tr><td>".CMU::WebInt::printVerbose('users.comment', $verbose).
    ($wl >= 1 ? $q->textfield(-name => 'comment',
			      -value => $tarr[$users_pos{'users.comment'}]) : $tarr[$users_pos{'users.comment'}]);

  print "</td><td>".CMU::WebInt::printVerbose('users.flags', $verbose).
    ($wl >= 1 ? $q->checkbox_group(-name => 'flags',
				   -values => \@CMU::Netdb::structure::users_flags,
				   -defaults => \@sflags) : $tarr[$users_pos{'users.flags'}])."</td></tr>\n";
  print "<tr><td>".
    "<input type=submit value=\"Update User\"></td></tr></form></td></tr>\n" if ($wl >= 1);
  print "</table>\n";

  # Credentials
  print "<br>";
  print CMU::WebInt::subHeading("Credentials",
				CMU::WebInt::pageHelpLink('credentials'));

  print 'The following credentials are associated with this user account. '.
    ' When a user authenticates with a listed credential, they will have '.
      'access to this user account.<br><br>';

  # If there are no credentials, we'll get a NULL here because of a LEFT JOIN
  if (!defined $rUinfo->[1]->[$rUPos{'credentials.authid'}]) {
    delete $rUinfo->[1];
  }

  my $lmgPos = CMU::Netdb::makemap(@$rUinfo[0]);

  CMU::WebInt::generic_tprint($url, $rUinfo, ['credentials.authid', 'credentials.description'],
                     [\&auth_cb_authid, \&auth_cb_operations], [$lmgPos, $dbh, $user], '', '',
                     $lmgPos, \%uc_printable, 'credentials.authid', 'users.id', '', [], \&auth_cb_addrow, [$url, $u, $dbh, $user]);

  if (defined $rUinfo->[1]) {
    # group membership
    print "<br>";
    print &CMU::WebInt::subHeading("Group Membership", CMU::WebInt::pageHelpLink(''));
    $rUmem = CMU::Netdb::list_memberships_of_user
      ($dbh, $user, $tarr[$rUPos{'credentials.authid'}]);

    if (!ref $rUmem) {
      print "error in CMU::Netdb::list_memberships_of_user: ".$errmeanings{$rUmem}."<br>\n";
    }else{
      CMU::WebInt::generic_tprint($url, $rUmem, ['groups.name', 'groups.description'],
				  [], '', '', 'op=auth_grp_info&g=',
				  \%groups_pos,
				  \%CMU::Netdb::structure::groups_printable,
				  'groups.name', 'groups.id', '', []);
    }
  }

  # attributes
  print "<br>";
  CMU::WebInt::attr_display($dbh, $user, 'users', $u);;
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub cred_cb_add_form {
  my ($uid) = @_;
  my $res = "<tr>
<form method=get>
<input type=hidden name=op value=cred_add>
<input type=hidden name=u value=$uid>

<td><input type=text name=authid></td>
<td><input type=text name=description></td>
<td><input type=submit value=\"Add Credential\"></td>
</form>
</tr>";
  return $res;
}

sub cred_add {
  my ($q, $errors) = @_;

  $errors = {} unless (ref $errors eq 'HASH');
  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  my %fields = ('user' => CMU::WebInt::gParam($q, 'u'),
		'authid' => CMU::WebInt::gParam($q, 'authid'),
		'description' => CMU::WebInt::gParam($q, 'description'),
        'type' => CMU::WebInt::gParam($q, 'type')
	);

  my ($res, $ref) = CMU::Netdb::add_credentials($dbh, $user, \%fields);
  if ($res != 1) {
    $errors->{msg} = "Error adding credential $fields{authid}:  ".
      $errmeanings{$res};
    $errors->{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $errors->{msg} .= " [".join(',', @$ref)."] "
      if (ref $ref eq 'ARRAY');
    $errors->{type} = 'ERR';
    $errors->{loc} = 'cred_add';
    $errors->{code} = $res;
    $errors->{fields} = join(',', @$ref);
  }else{
    $errors->{msg} = "Credential added to this user.";
  }
  $dbh->disconnect();
  auth_userinfo($q, $errors);
}

sub cred_del {
  my ($q, $errors) = @_;

  $errors = {} unless (ref $errors eq 'HASH');
  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  my $ID = CMU::WebInt::gParam($q, 'id');
  my $Ver = CMU::WebInt::gParam($q, 'v');

  my ($res, $ref) = CMU::Netdb::delete_credentials($dbh, $user, $ID, $Ver);
  if ($res != 1) {
    $errors->{msg} = "Error deleting credential: ".$errmeanings{$res};
    $errors->{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $errors->{msg} .= " [".join(',', @$ref)."] "
      if (ref $ref eq 'ARRAY');
    $errors->{type} = 'ERR';
    $errors->{loc} = 'cred_del';
    $errors->{code} = $res;
    $errors->{fields} = join(',', @$ref);
  }else{
    $errors->{msg} = "Credential deleted from this user.";
  }
  $dbh->disconnect();
  auth_userinfo($q, $errors);
}

# this is a callback to be used by auth_group_table_print
# when the 2nd argument is not a reference, we return our table heading
# arguments:
#  - url to fetch this page
#  - reference to the row
#  - user data (supplied by the register function)
# returns:
#  - data to be printed in a cell, or whatever.
sub auth_cb_GroupRemove {
  my ($url, $rRow, $ud) = @_;
  return "Remove From Group" if (!ref $rRow);
  
  return "<a href=\"".CMU::WebInt::encURL("$url?op=auth_ug_del&g=".$$rRow[$groups_pos{'groups.id'}].
    "&$ud")."\">Remove</a>";
}

sub auth_cb_UserRemove {
  my ($url, $rRow, $ud) = @_;
  return "Remove from Group" if (!ref $rRow);
  return "<a href=\"".CMU::WebInt::encURL("$url?op=auth_ug_del&u=".$$rRow[$users_pos{'credentials.authid'}].
    "&$ud")."\">Remove</a>";
}

sub auth_update_user {
  my ($q) = @_;
  my ($dbh, $url , %updRef, $r, $msg, $sop, $ref);
  $dbh = CMU::WebInt::db_connect();

  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();
  $updRef{'comment'} = CMU::WebInt::gParam($q, 'comment');

  $updRef{'flags'} = join(',', CMU::WebInt::gParam($q, 'flags'));
  ($r, $ref) = CMU::Netdb::modify_user($dbh, $user, CMU::WebInt::gParam($q, 'id'), CMU::WebInt::gParam($q, 'version'), 
		      \%updRef);
  $msg = ($r > 0 ? "User was updated successfully." :
	     "Error updating user: ".$errmeanings{$r});
  $sop = CMU::WebInt::gParam($q, 'sop');
  $dbh->disconnect;
  my %errors;
  if ($sop eq 'userinfo') {
    $errors{msg} = $msg;
    $errors{code} = $r;
    $errors{fields} = join(',', @$ref);
    $errors{loc} = 'auth_user_upd';
    $errors{type} = 'ERR' if ($r < 1);
    CMU::WebInt::auth_userinfo($q, \%errors);
  }else{
    auth_oops($msg);
  }
}

sub auth_update_group {
  my ($q) = @_;
  my ($dbh, $url, %updRef, $r, $msg, $sop, $ref);
  $dbh = CMU::WebInt::db_connect();

  $url = $ENV{SCRIPT_NAME};
  my ($user, $p, $realm) = CMU::WebInt::getUserInfo();
  foreach(qw/name comment_lvl9 comment_lvl5 description/) {
    $updRef{$_} = CMU::WebInt::gParam($q, $_);
  }
  $updRef{'flags'} = join(',', CMU::WebInt::gParam($q, 'flags'));

  print STDERR __FILE__, ':', __LINE__, ' :>'.
    "going to modify_group...\n" if ($debug >= 2);
  ($r, $ref) = CMU::Netdb::modify_group($dbh, $user, CMU::WebInt::gParam($q, 'id'), CMU::WebInt::gParam($q, 'version'), 
			    \%updRef);
  $msg = ($r > 0 ? "Group was updated successfully." :
	  "Error updating group: ".$errmeanings{$r});
  $sop = CMU::WebInt::gParam($q, 'sop');
  $dbh->disconnect;
  my %errors;
  if ($sop eq 'auth_grp_info') {
    $errors{msg} = $msg;
    $errors{code} = $r;
    $errors{fields} = '';
    $errors{fields} = join(',', @$ref) if (ref $ref);
    $errors{loc} = 'auth_grp_upd';
    $errors{type} = 'ERR' if ($r < 1);
    CMU::WebInt::auth_groupinfo($q, \%errors);
  }else{
    auth_oops($msg);
  }
}

## used by a bunch of functions that direct the user back to the page
## they came from, and they don't know where to direct the user to
sub auth_oops {
  my ($q, $msg) = @_;
  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "oops", {});
  print "You shouldn't be seeing this. <br>$msg<br>\n";
  print CMU::WebInt::stdftr($q);
}

sub auth_delete_group {
  my ($q) = @_;
  my ($url, $msg, $dbh, $ul, $res) = @_;

  if (CMU::WebInt::gParam($q, 'conf') eq '1') {
    &auth_delgroup_conf($q);
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Groups", {});
  &CMU::WebInt::title('Delete Group');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'groups', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('groups', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic group infromation
  my $sref = CMU::Netdb::list_groups($dbh, $user, "groups.id='$id'");
  if (!defined $sref->[1]) {
    print "Group not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following group.\n";
  
  my @print_fields = qw/groups.name groups.description/;
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::groups_printable{$f}."</th>
<td>";
    print $sdata[$groups_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=auth_grp_del&conf=1&id=$id&version=$version")."\">
Yes, delete this group</a>\n";
  print "<br><a href=\"".CMU::WebInt::encURL("$url?op=auth_grp_list")."\">No, return to the group list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

# this is only called from auth_delete_group in the case where the user
# has confirmed they want to delete the group
sub auth_delgroup_conf {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'groups', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete group $id\n";
    $dbh->disconnect();
    $q->param('g', CMU::WebInt::gParam($q, 'id'));
    CMU::WebInt::auth_groupinfo($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_group($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    CMU::WebInt::auth_listgroups($q, {'msg' => "The group was deleted."});
  }else{
    $errors{msg} = "Error while deleting group: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{type} = 'ERR';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    $errors{loc} = 'auth_grp_del';
    $q->param('g', CMU::WebInt::gParam($q, 'id'));
    CMU::WebInt::auth_groupinfo($q, \%errors);
  }
}

sub auth_delete_user {
  my ($q) = @_;
  my ($url, $msg, $dbh, $ul, $res) = @_;

  if (CMU::WebInt::gParam($q, 'conf') eq '1') {
    &auth_deluser_conf($q);
    return;
  }

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Users", {});
  &CMU::WebInt::title('Delete User');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');

  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'users', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('users', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic group infromation
  my $sref = CMU::Netdb::list_users($dbh, $user, "users.id='$id'");
  if (!defined $sref->[1]) {
    print "User not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following user.\n";

  my @print_fields = qw/users.id/;
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::users_printable{$f}."</th>
<td>";
    print $sdata[$users_pos{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=auth_user_del&conf=1&id=$id&version=$version")."\">
Yes, delete this user</a>\n";
  print "<br><a href=\"".CMU::WebInt::encURL("$url?op=auth_user_list")."\">No, return to the user list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

# this is only called from auth_delete_user in the case where the user
# has confirmed they want to delete the user
sub auth_deluser_conf {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;

  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'users', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete user $id\n";
    $dbh->disconnect();
    $q->param('g', CMU::WebInt::gParam($q, 'id'));
    CMU::WebInt::auth_userinfo($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_user($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    CMU::WebInt::auth_user_list($q, {'msg' => "The user was deleted."});
  }else{
    $errors{msg} = "Error while deleting user: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{type} = 'ERR';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    $errors{loc} = 'auth_grp_del';
    $q->param('u', CMU::WebInt::gParam($q, 'id'));
    CMU::WebInt::auth_userinfo($q, \%errors);
  }
}

sub auth_search_groups {
  my ($q, $errors) = @_;
  my ($dbh);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Search Groups", $errors);
  print CMU::WebInt::errorDialog($ENV{SCRIPT_NAME}, $errors);

  print "<font color=red>Error executing auth_Search_Groups_Int.</font><br>\n"
    if (&auth_Search_Groups_Int($user, $dbh, $q) != 1);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub auth_search_users {
  my ($q) = @_;
  my ($dbh);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Search Users", {});
  print "<font color=red>Error executing auth_Search_Users_Int.</font><br>\n"
    if (&auth_Search_Users_Int($user, $dbh, $q) != 1);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub authmain {
  my ($q, $errors) = @_;
  my ($dbh);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('auth_main');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Users & Groups", $errors);
  my $url = $ENV{SCRIPT_NAME};
  my $useradminStatus = CMU::Netdb::get_user_admin_status($dbh, $user);
  my $usergroupadminStatus = CMU::Netdb::get_user_group_admin_status($dbh, $user);

  if ($useradminStatus > 0) {
    &CMU::WebInt::title("User and Group Administration");
    print CMU::WebInt::errorDialog($url, $errors);
    print "<br>".CMU::WebInt::subHeading("Users", CMU::WebInt::pageHelpLink('users'));
    my $SU = '';

    my ($vres, $rSuperUsers) = CMU::Netdb::config::get_multi_conf_var
      ('webint', 'SuperUsers');

    $rSuperUsers = [$rSuperUsers] if ($vres == 1 && !(ref $rSuperUsers eq 'ARRAY'));

    my $UserAllowed = scalar grep /^$user$/i, @$rSuperUsers;
    if ($vres == 1 && $UserAllowed == 1) {
      $SU = "[<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_user_cred").
	"\">Switch User</a></b>] ";
    }
    print CMU::WebInt::smallRight($SU."[<b><a href=\"".CMU::WebInt::encURL("$url?op=user_type_mod").
                                  "\">User Types</a></b>] [<b><a href=\""
                                  .CMU::WebInt::encURL("$url?op=auth_user_list").
				  "\">List Users</a></b>]".
				  "[<b><a href=\"".
				  CMU::WebInt::encURL("$url?op=auth_user_add")."\">Add User</a></b>]");

    print "<form action=$url method=get>
<input type=hidden name=op value=auth_user_search>
<table><tr><th>
Search <u>U</u>sers</th></tr><td>
<input type=text name=a accesskey=u>";

CMU::WebInt::drawUserRealmPopup($q,"uidrealm","r");

print " <input type=submit value=\"Search\"></td></tr></table></form>";

    ## USER ATTRIBUTES removed, now that a general attributes interface exists

    print CMU::WebInt::subHeading("Groups", CMU::WebInt::pageHelpLink('groups'));
    print CMU::WebInt::smallRight("[<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_grp_list")."\">List Groups</a></b>]
 [<b><a href=\"".CMU::WebInt::encURL("$url?op=auth_grp_add")."\">Add Group</a></b>]");
    
    print "<form action=$url method=get>
<input type=hidden name=op value=auth_grp_search>
<table><tr><th>
Search <u>G</u>roups</th></tr><td>
<input type=text name=a accesskey=g>
<input type=submit value=\"Search\">
</td></tr></table>
</form>
";
    ## GROUP ATTRBITUES removed, now that a general attributes interface exists

    ## ATTRIBUTE ADD FORM removed, now that a general attributes interface exists

  } elsif ($usergroupadminStatus) {
    &CMU::WebInt::title("Group/Department Administration");
    print CMU::WebInt::errorDialog($url, $errors);
    my $admingroups = CMU::Netdb::list_groups_administered_by_user($dbh, $user, $user);
    if (!ref $admingroups) {
      print CMU::WebInt::subHeading("Groups You Control", CMU::WebInt::pageHelpLink('groups'));
      print "error in list_groups_administered_by_user:".$errmeanings{$admingroups}."<br>\n";
    } else {
      if ($#$admingroups != 0) {
	print CMU::WebInt::subHeading("Groups You Control", CMU::WebInt::pageHelpLink('groups'));
	CMU::WebInt::generic_tprint($url, $admingroups, ['groups.name', 'groups.description'],
		       [], '', '', 'op=auth_grp_info&g=',
		       \%groups_pos,
		       \%CMU::Netdb::structure::groups_printable,
		       'groups.name', 'groups.id', '', []);
      }
    }
    print "<br>\n";
    my $groups = CMU::Netdb::list_memberships_of_user($dbh, $user, $user);
    if (!ref $groups) {
      print CMU::WebInt::subHeading("Groups You Are In", CMU::WebInt::pageHelpLink('groups'));
      print "error in CMU::Netdb::list_memberships_of_user:".$errmeanings{$groups}."<br>\n";
    } else {
      if ($#$groups != 0) {
	print CMU::WebInt::subHeading("Groups You Are In", CMU::WebInt::pageHelpLink('groups'));
	CMU::WebInt::generic_tprint($url, $groups, ['groups.name', 'groups.description'],
		       [], '', '', 'op=auth_grp_info&g=',
		       \%groups_pos,
		       \%CMU::Netdb::structure::groups_printable,
		       'groups.name', 'groups.id', '', []);
      }
    }
    print "<br>\n";
  }
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# This just prints out all the environmental variables
sub auth_enviro_test {
  my ($q);

  $q = new CGI;
  print $q->header().$q->start_html(-title => "Test");
  
  foreach(keys %ENV) {
    print "<b>$_</b>: $ENV{$_}<br>\n";
  }
  
  print $q->end_html();
}

sub auth_Search_Groups_Int {
  my ($user, $dbh, $q) = @_;
  my ($a, $start, $url);

  $start = CMU::WebInt::gParam($q, 's_start');
  $a = CMU::WebInt::gParam($q, 'a');
  $start = 0 if ($start eq '');
  
  $url = $ENV{SCRIPT_NAME};

  # search form
  
  print "<table border=1><tr><th>Search Groups</th></tr>\n".
    "<tr><td>Enter part of the groupid or name.<br>".
      "<form action=$url method=get>".
	"<input type=hidden name=op value=auth_grp_search>".
	"<input type=text name=a value=\"$a\"><input type=submit value=\"Search\">".
	  "</form></td></tr></table>\n";
  return 1 if ($a eq '');
  
  # execute a search
  print "<B>Items matching your query:</b><br>\n";
  CMU::WebInt::auth_Print_Groups($user, $dbh, $q, " (groups.name like \"%$a%\" OR ".
		   "groups.description like \"%$a%\") ", $ENV{SCRIPT_NAME}, "op=auth_grp_search&a=$a", 's_start');
    
  return 1;
}

sub auth_Search_Users_Int {
  my ($user, $dbh, $q) = @_;
  my ($a, $start, $url, $uidrealm);

  $start = CMU::WebInt::gParam($q, 's_start');
  $a = CMU::WebInt::gParam($q, 'a');
 $uidrealm = CMU::WebInt::gParam($q, 'uidrealm');

  $start = 0 if ($start eq '');

  $url = $ENV{SCRIPT_NAME};

  # search form
  print "<table border=1><tr><th>Search Users</th></tr>\n".
    "<tr><td>Enter part of the userid or name.<br>".
      "<form action=$url method=get>".
	"<input type=hidden name=op value=auth_user_search>".
        "<input type=text name=a value=\"$a\">";

        CMU::WebInt::drawUserRealmPopup($q,"uidrealm","r",$uidrealm);

        print " <input type=submit value=\"Search\">".
	  "</form></td></tr></table>\n";
  return 1 if ($a eq '');

  # add to $a $uidrealm
  if (($uidrealm ne '--none--') and ($uidrealm ne undef)) {
          $a = $a . '%@' . $uidrealm;
  }


  # execute a search
  print "<B>Items matching your query:</b><br>\n";
  CMU::WebInt::auth_Print_Users
      ($user, $dbh, $q, " (credentials.authid like \"%$a%\" OR ".
       "credentials.description like \"%$a%\") ", 
       $ENV{SCRIPT_NAME}, "op=auth_user_search&a=$a", 's_start');

  return 1;
}

# auth_Print_Users
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the user WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub auth_Print_Users {
  my ($user, $dbh, $q, $where, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $maxPages, $vres);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'credentials', $where);
  
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
  $ruRef = CMU::Netdb::list_users($dbh, $user, " $where ".
				  CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with CMU::Netdb::list_users: ".$errmeanings{$ruRef};
    return 0;
  }

  CMU::WebInt::generic_tprint($url, $ruRef, 
			      ['credentials.authid', 'credentials.description'],
		 [], '', 'auth_user_list', 'op=auth_user_info&u=',
		 \%users_pos, \%uc_printable,
		 'credentials.authid', 'users.id', 'sort', []);

  return 1;
  
}

# auth_Print_Groups
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the user WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub auth_Print_Groups {
  my ($user, $dbh, $q, $where, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $in, $maxPages, $vres);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'groups', $where);
  
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
  $ruRef = CMU::Netdb::list_groups($dbh, $user, " $where ORDER BY groups.name ".
				   CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_groups: ".$errmeanings{$ruRef};
    return 0;
  }
  $oData =~ s/op\=/sop\=/; # make it the secondary target opcode
  CMU::WebInt::generic_tprint($url, $ruRef, ['groups.name', 'groups.description'],
		 [], '', '', 'op=auth_grp_info&g=',
		 \%groups_pos,
		 \%CMU::Netdb::structure::groups_printable,
		 'groups.name', 'groups.id', '', []);

  return 1;
}

sub auth_cb_authid {
  my ($url, $row, $a) = @_;
  my ($map, $dbh, $dbuser) = @$a;

  return "Type" if (!ref $row);


  my $types = CMU::Netdb::UserMaint::list_user_types($dbh, $dbuser);
  my $types_map = CMU::Netdb::helper::makemap(shift @$types);

  my %list_o_types;
  foreach my $t (@$types) {
    $list_o_types{$t->[$types_map->{'user_type.id'}]} = $t->[$types_map->{'user_type.name'}];
  }

  my $type = $list_o_types{$row->[$map->{'credentials.type'}]};

  if ($type eq '') {
    $type = "-- INVALID --";
  }

  return "<a href=\"$url?op=cred_change_type&u=$row->[$map->{'users.id'}]&c=$row->[$map->{'credentials.id'}]\">$type</a>\n";
}

sub auth_cb_operations {
  my ($url, $row, $a) = @_;

  my ($map, $dbh) = @$a;

  return "Operations" if (!ref $row);

  my $id = $row->[$map->{'users.id'}];
  my $ver = $row->[$map->{'credentials.version'}];
  my $cid = $row->[$map->{'credentials.id'}];

  return "<a href=\"$url?op=cred_del&u=$id&ig=nore&v=$ver&id=$cid\">Delete</a>\n";
}

sub auth_cb_addrow {
  my ($url, $u, $dbh, $dbuser) = @{$_[0]};

  my $html = "<form method=get action=$url><input type=hidden name=op value=cred_add /><input type=hidden name=u  value=$u />";
  $html .= "<tr><td><input type=text name=authid /></td><td><input type=text name=description /></td><td>";
  $html .= "<select name=\"type\">";
  my $types = CMU::Netdb::UserMaint::list_user_types($dbh, $dbuser);
  my $types_map = CMU::Netdb::helper::makemap(shift @$types);
  
  my %list_o_types;  
  foreach my $t (@$types) {
    $list_o_types{$t->[$types_map->{'user_type.id'}]} = $t->[$types_map->{'user_type.name'}];
  }
    
  foreach my $x (keys %list_o_types) {
    $html .= "<option value=$x>" . $list_o_types{$x};
  }
  $html .= "</select></td><td><input type=submit name=submit value=\"Add Credential\" /></td></tr>";

  return $html;
}
  
sub ut_cb_m_m {
  my ($url, $row, $a) = @_;
  my ($map, $dbh) = @$a;

  return "Mail Machine" if (!ref $row);

  my $m_m = $row->[$map->{'user_type.flags'}];
  if (index($m_m,'send_email_mach') >= 0) { return "True"; } else { return "False"; }
}
  
sub ut_cb_o_m {
  my ($url, $row, $a) = @_;
  my ($map, $dbh) = @$a;

  return "Mail Outlet" if (!ref $row);

  my $m_m = $row->[$map->{'user_type.flags'}];
  if (index($m_m,'send_email_outlet') >= 0) { return "True"; } else { return "False"; }
}

sub ut_cb_disable_acct {
  my ($url, $row, $a) = @_;
  my ($map, $dbh) = @$a;

  return "Disable Instead" if (!ref $row);

  my $m_m = $row->[$map->{'user_type.flags'}];
  if (index($m_m,'disable_acct') >= 0) { return "True"; } else { return "False"; }
}

sub ut_cb_addrow {
  my ($url, $u, $dbh) = @{$_[0]};

  my $html = "<form method=get action=$url><input type=hidden name=op value=ut_add /><tr>";
  $html .= "<td><input type=text name=name /></td>";
  $html .= "<td><input type=text name=m_d_e /></td>";
  $html .= "<td><input type=text name=o_d_e /></td>";
  $html .= "<td><input type=checkbox name=m_m /></td>";
  $html .= "<td><input type=checkbox name=o_m /></td>";
  $html .= "<td><input type=checkbox name=disable /></td>";
  $html .= "<td><input type=submit name=submit value=\"Add User Type\" /></td></tr>";

  return $html;
}

sub ut_cb_operations {
  my ($url, $row, $a) = @_;

  my ($map, $dbh) = @$a;

  return "Operations" if (!ref $row);

  my $id = $row->[$map->{'user_type.id'}];
  my $version = $row->[$map->{'user_type.version'}];

  return "<a href=\"$url?op=prot_s3&table=user_type&tidType=1&tid=$id\">Perm</a> <a href=\"$url?op=user_type_change&u=$id\">Modify</a> <a href=\"$url?op=user_type_del&id=$id&version=$version\">Delete</a>\n";
}

1;
