#   -*- perl -*-
#
# CMU::WebInt::services
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
# $Id: services.pm,v 1.42 2008/03/27 19:42:38 vitroth Exp $
#
# Revision 1.41  2007/08/31 15:15:49  fk03
# Sorted attribute list shown on add attribute page.
#
# Revision 1.40  2007/07/31 20:11:24  vitroth
# Added UI bits for attributes on groups.  (Underlying code already existed)
#
# Revision 1.39  2007/07/05 16:08:44  vitroth
# minor ui tweak
#
# Revision 1.38  2007/06/23 12:10:09  vitroth
# Added history link
#
# $Log: services.pm,v $
# Revision 1.42  2008/03/27 19:42:38  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.41.4.3  2008/02/06 20:17:46  vitroth
# Added quick access popup menu links on the list view pages
#
# Revision 1.41.4.2  2007/10/23 17:01:38  vitroth
# various small typos
#
# Revision 1.41.4.1  2007/10/11 20:59:43  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.41.2.1  2007/09/20 18:43:06  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.37  2006/08/03 01:37:56  vitroth
# In all cases where a version is used in an input field the value needs
# to be quoted since it may contain spaces (mysql 4.1)
#
# Revision 1.36  2006/05/08 21:26:12  vitroth
# Ported the necessary changes for mysql 4.1 & 5.0 from WPI branch
# to cvs HEAD.  Not yet heavily tested, but appears to run on mysql 4.0
# still at least.
#
# Revision 1.35  2006/01/20 16:08:49  vitroth
# Minor html change for prettier content...
#
# Revision 1.34  2006/01/20 15:56:36  vitroth
# Also don't say 'No attributes' for level 1 users, since we're just hiding them.
#
# Revision 1.33  2006/01/20 15:50:50  vitroth
# Hide attributes from users with only level 1 access
#
# Revision 1.32  2005/09/15 15:20:33  fk03
# Added code to handle attributes on machines.
#
# $Log: services.pm,v $
# Revision 1.42  2008/03/27 19:42:38  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.41.4.3  2008/02/06 20:17:46  vitroth
# Added quick access popup menu links on the list view pages
#
# Revision 1.41.4.2  2007/10/23 17:01:38  vitroth
# various small typos
#
# Revision 1.41.4.1  2007/10/11 20:59:43  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.41.2.1  2007/09/20 18:43:06  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.6  2007/06/05 20:52:45  kcmiller
# * updating to netreg1
#
# Revision 1.5  2005/08/14 19:48:54  kcmiller
# * Syncing to mainline
#
# Revision 1.31.6.1  2005/08/14 19:48:32  kevinm
# * Make accessDenied more informative
#
# Revision 1.31  2005/06/29 22:04:30  fes
# Back out changes that missed the branch and hit HEAD
#
# Revision 1.29  2005/03/30 20:48:07  vitroth
# Fixed a typo in permissions checking of attributes on users.
#
# Revision 1.28  2005/02/04 14:58:02  vitroth
# Allow anyone who can write to a user to set attributes on the user.
#
# Revision 1.27  2004/12/06 20:48:09  vitroth
# Fixed a problem with permissions with adding new attributes to service members.
#
# Revision 1.26  2004/11/08 12:34:35  vitroth
# Added support to both the API and Web UI for attributes on outlets,
# subnets and vlans.
#
# Added generic attribute type add/view interface at top level.
#
# Added set_attribute API, which allows attributes with ntimes == 1
# to be set by applications in a single call.  (i.e. an attribute which
# can only exist once on a object can be set via set_attribute, without
# the application needing to know if its already set.)
#
# Added custom UI for port-speed and port-duplex attributes on outlets.
# If those attributes exist, we present them to the user as if they
# are additional columns on the outlet table.  Since WebInt is merely
# an application using the API, albeit the *primary* application, this doesn't
# violate the model that nothing internal to the API may refer to specific
# attribute types.
#
# Revision 1.25  2004/08/17 21:07:49  vitroth
# Fixed a bug where service names & descriptions could never be updated.
#
# Added support for using SQL wild cards when adding service members, for
# machines only.
#
# Added trunk_set's as a member type.  Not useful until the dumper does something
# extra to include trunk set data.
#
# Revision 1.24  2004/08/06 12:30:29  vitroth
# Make the service name & desc fields a bit bigger so
# they're easier to read.
#
# Revision 1.23  2004/07/27 13:00:27  vitroth
# Bug fixes related to adding/deleting attributes from users.
#
# Revision 1.22  2004/06/24 02:05:37  kevinm
# * Credentials/machine type pulled to head
#
# Revision 1.21.8.1  2004/06/21 15:53:44  vitroth
# Merging credentials & machine type permissions branches.
# Inital merge complete, no testing done yet.
# Still need to update convert script and schema.
#
# Revision 1.21.4.1  2004/06/16 03:41:00  kevinm
# * New subnet mapping
# * User -> credential change
#
# Revision 1.21  2004/02/20 03:14:25  kevinm
# * External config file updates
#
# Revision 1.20  2002/10/23 19:16:15  ebardsle
# VLAN support
#
# Revision 1.19  2002/10/03 22:34:22  kevinm
# * Replacing "print STDERR" with "warn" everywhere
#
# Revision 1.18  2002/08/20 14:48:12  kevinm
# * Added $errors to stdhdr everywhere
#
# Revision 1.17  2002/08/20 14:12:35  kevinm
# * Added __FILE__ and __LINE__ to STDERR everywhere
#
# Revision 1.16  2002/07/30 04:39:05  kevinm
# * Removed old DNS server/config bits
#
# Revision 1.15  2002/07/29 21:49:39  ebardsle
# Included HTML 4.01 ACCESSKEY and LABEL tags.
#
# Revision 1.14  2002/06/12 17:40:06  kevinm
# * Changed permissions on deleting member from service
#
# Revision 1.13  2002/05/29 19:29:40  kevinm
# * Fix an Internal Server Error when not authorized to delete a service member
#
# Revision 1.12  2002/03/11 04:40:53  kevinm
# * Fixed AFSDB printing
#
# Revision 1.11  2002/03/11 04:09:53  kevinm
# * Added AFSDB support
#
# Revision 1.10  2002/03/04 02:18:14  kevinm
# * Duplicate ORDER BY in service caused some db issues
#
# Revision 1.9  2002/03/04 02:13:48  kevinm
# * DHCP Option Type protections link
# * Service /type sorting
#
# Revision 1.8  2002/03/04 00:35:02  kevinm
# * Validation for parameters to ORDER BY and LIMIT
# * New DHCP Option Type stuff
#
# Revision 1.7  2002/02/21 03:02:44  kevinm
# Server member changes
#
# Revision 1.6  2002/02/04 20:05:02  kevinm
# Re-fixed broken gParam
#
# Revision 1.5  2002/02/04 20:04:28  kevinm
# Fixed naked gParam call
#
# Revision 1.4  2002/01/03 20:56:32  kevinm
# * Changed variables from interface/vars to config
# * Changed service_attribute to attribute
# * Initial parts of user attributes added (sorting changed from numeric to table name)
# * Added option for disabling outlet/cable/telecom portions in config
# *
#
# Revision 1.3  2001/11/07 18:13:57  kevinm
# Removed high debugging levels.
#
# Revision 1.2  2001/11/06 18:10:32  kevinm
# Fixed a minor bug after adding a DNS resource
#
# Revision 1.1  2001/11/05 21:37:55  kevinm
# Service stuff checking in..
#
#
#

package CMU::WebInt::services;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings %machine_pos
	     $debug %service_pos %service_type_pos %attr_pos);

use CMU::WebInt;
use CMU::Netdb;

require CMU::WebInt::auth; # for users_pos below
use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.03';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(svc_main svc_print_service svc_cb_type svc_add_form
	     svc_add svc_type_list svc_type_print cb_svc_type_del
	     svc_type_view attr_spec_view attr_spec_add_form attr_spec_add
	     attr_add svc_type_add_form svc_type_add svc_type_del
	     svc_type_confirm_del svc_view svc_cb_add_member svc_delete
	     svc_delete_conf svc_update svc_del_member svc_add_member
	     attr_add_form attr_spec_upd attr_spec_del 
	     attr_spec_del_conf svc_cb_attr_del attr_del
	     attr_display attr_cb_attr_del attr_spec_list attr_cb_data
	    );


%errmeanings = %CMU::Netdb::errors::errmeanings;
%machine_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::machine_fields)};

%service_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::service_fields)};
%service_type_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::service_type_fields)};
%attr_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::attribute_fields)};

$debug = 0;
my ($gmcvres, $TACOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 
								 'TACOLOR');

sub svc_main {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('service');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Services", $errors);
  $url = $ENV{SCRIPT_NAME};

  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'service', 0);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('service', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

#  $sort = CMU::WebInt::gParam($q, 'sort');
#  $sort = 'service.name' if ($sort eq '');


  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=svc_add_form\">Add Service</a></b>] [<b><a href=\"$url?op=svc_type_list\">List Service Types</a></b>] ".CMU::WebInt::pageHelpLink(''));

  print CMU::WebInt::errorDialog($url, $errors);

  my $svc = CMU::Netdb::list_services_ref($dbh, $user, '', 'service.name');
  if (ref $svc) {
    my @svk = sort { $$svc{$a} cmp $$svc{$b} } keys %$svc;
    unshift(@svk, '--select--');
    print "<form method=get>\n<input type=hidden name=op value=svc_info>\n";
    print CMU::WebInt::smallRight($q->popup_menu(-name => 'sid',
						 -accesskey => 's',
						 -values => \@svk,
						 -labels => $svc) 
				  . "\n<input type=submit value=\"View Service\"></form>\n");

  }else{
    &CMU::WebInt::admin_mail('machines.pm:mach_search', 'WARNING',
			     'Error loading services (list_services_ref).', {});
  }


  $res = svc_print_service($user, $dbh, $q, 
			   '', '',
			   $ENV{SCRIPT_NAME}, "op=svc_main", 'start');

  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# svc_print_service
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the subnet WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub svc_print_service {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);
  
  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'service', $cwhere);
  
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
  $ruRef = CMU::Netdb::list_services($dbh, $user, " $where ORDER BY service.type, service.name ".
				     CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_services: ".$errmeanings{$ruRef};
    return 0;
  }

  my $sref = CMU::Netdb::list_service_types_ref($dbh, $user, "", 'service_type.name');

  warn __FILE__, ':', __LINE__, ' :>'.
    "No ref\n" if (!ref $sref);
  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['service.name'],
		 [\&CMU::WebInt::services::svc_cb_type], $sref,
		 'svc_main', 'op=svc_info&sid=',
		 \%service_pos, 
		 \%CMU::Netdb::structure::service_printable,
		 'service.name', 'service.id', 'sort', ['service.name', 'service.type']);
  
  return 1;
}

sub svc_cb_type {
  my ($url, $row, $edata) = @_;
  return $CMU::Netdb::structure::service_type_printable{'service_type.name'} if (!ref $row);
  return $edata->{$row->[$service_pos{'service.type'}]} if (ref $edata);
}

sub svc_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'service', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('svc_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Group Admin", $errors);
  &CMU::WebInt::title("Add a Service Group");

  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('service', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));

  
  # name, description
  print "
<form method=get>
<input type=hidden name=op value=svc_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, 
				  $CMU::Netdb::structure::service_printable{'service.name'}, 
				  1, 'service.name')
  .
    CMU::WebInt::printPossError(defined $errors{description}, 
				$CMU::Netdb::structure::service_printable{'service.description'},
				1, 'service.description')
      ."</tr>\n<tr>".
	"<td>".CMU::WebInt::printVerbose('service.name', $verbose).
	  $q->textfield(-name => 'name', -accesskey => 's', -size => 35)."</td>\n".
	    "<td>".CMU::WebInt::printVerbose('service.description', $verbose).
  $q->textfield(-name => 'description', -accesskey => 's', -size => 35)."</td></tr>\n";

  # service_type
  print "<tr>".CMU::WebInt::printPossError(defined $errors->{'type'}, $CMU::Netdb::structure::service_type_printable{'service_type.name'}, 1, 'service_type.name'). "</tr>\n";
  my $stref = CMU::Netdb::list_service_types_ref($dbh, $user, '', 'name');
  my @st = sort {$stref->{$a} cmp $stref->{$b}} keys %$stref;
  print "<tr><td>".CMU::WebInt::printVerbose('service_type.name', $verbose).
    $q->popup_menu(-name => 'type', -accesskey => 's',
		   -values =>\@st,
		   -labels => $stref)
      . "</td></tr>\n";

  print "</table>\n";
  print "<input type=submit value=\"Add Service Group\">\n";

  print &CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub svc_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();


  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'description' => CMU::WebInt::gParam($q, 'description'),
	     'type' => CMU::WebInt::gParam($q, 'type'),
	    );

  
  my ($res, $errfields) = CMU::Netdb::add_service($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added Service Group $fields{name}.";
    $q->param('id', $warns{insertID});
    $q->param('sid', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    svc_view($q, \%nerrors);
  }else{
    $nerrors{'msg'} = "Error adding Service Group: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'svc_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    &svc_add_form($q, \%nerrors);
  }
}

sub svc_type_list {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('svc_type_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Group Types", $errors);
  &CMU::WebInt::title("List of Service Group Types");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'service_type', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('service_type', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=svc_type_add_form>Add Service Type</a></b>] ".CMU::WebInt::pageHelpLink(''));

#  my $stref = CMU::Netdb::list_service_types($dbh, $user, "1 ORDER BY service_type.name");

 # CMU::WebInt::generic_smTable($url, $stref, ['service_type.name'], 
#			       CMU::Netdb::makemap($stref->[0]),
#			       \%CMU::Netdb::structure::service_type_printable,
#			       '', 'service_type', 'svc_type_del',
#			       '', '');

  $res = svc_type_print($user, $dbh, $q,  
			" 1 ", '',
			$ENV{SCRIPT_NAME}, "", 'start', 'svc_type_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub svc_type_print {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $maxPages, $vres);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'service_type', $cwhere);
  
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
  $ruRef = CMU::Netdb::list_service_types($dbh, $user, " $where ORDER BY service_type.name ".
					  CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with CMU::Netdb::list_service_types: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
			      ['service_type.name'], [\&cb_svc_type_del], '',
			      'svc_type_list', 'op=svc_type_info&id=',
			      CMU::Netdb::makemap($ruRef->[0]),
			      \%CMU::Netdb::structure::service_type_printable,
			      'service_type.name', 'service_type.id', 'sort',
			     ['service_type.name']);
  return 1;
}


sub cb_svc_type_del {
  my ($url, $row, $edata) = @_;
  return "Delete" if (!ref $row);
  my @rrow = @$row;
  my %pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::service_type_fields)};
  return "<a href=\"".CMU::WebInt::encURL("$url?op=svc_type_del&id=".$rrow[$pos{'service_type.id'}]."&version=".$rrow[$pos{'service_type.version'}])."\">Delete</a>";
}

sub svc_type_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('svc_info');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Types", $errors);
  &CMU::WebInt::title('Service Type Information');
  $id = CMU::WebInt::gParam($q, 'id');

  $$errors{msg} = "Service Type ID not specified!" if ($id eq '');

  $url = $ENV{SCRIPT_NAME};
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'service_type', $id);
  
  if ($wl < 1) {
    CMU::WebInt::accessDenied('service_type', 'WRITE', $id, 1, $wl, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<hr>".CMU::WebInt::errorDialog($url, $errors);
  
  my $sref = CMU::Netdb::list_service_types($dbh, $user, "service_type.id='$id'");
  if (!ref $sref) {
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  my %stype_pos = %{CMU::Netdb::makemap($sref->[0])};
  my %stype_pr = %CMU::Netdb::structure::service_type_printable;
  my @sdata = @{$sref->[1]};
  print &CMU::WebInt::subHeading("Basic Information");
  print &CMU::WebInt::smallRight("[<b><a href=\"$url?op=svc_type_info&id=$id\">Refresh</a></b>] [<b><a href=\"$url?op=prot_s3&table=service_type&tidType=1&tid=$id\">View/Update Protections</a></b>]");

  my $version = $sdata[$stype_pos{'service_type.version'}];
  
  # start the madness..
  print "<form method=get><table border=0>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=svc_type_upd>
<input type=hidden name=version value=\"$version\">";

  # name
  my ($name) = $sdata[$stype_pos{'service_type.name'}];
  $q->delete('name');
  $q->param('name', $name);

  print "<tr>".CMU::WebInt::printPossError(defined $errors->{'name'},  
					   $stype_pr{'service_type.name'}, 2, 'name').
					     "</tr>";
  
  print "<tr><td colspan=2>".CMU::WebInt::printVerbose('service_type.name', 1);
  print $q->textfield(-name => 'name',  -accesskey => 's');
  print "</td></tr>\n";

  # last updated
  print "<tr>".CMU::WebInt::printPossError(0, $stype_pr{'service_type.version'}).
    "</tr><tr><td>";
      $sdata[$stype_pos{'service_type.version'}] =~ /(....)(..)(..)(..)(..)(..)/;
  my $updDate = "$1-$2-$3 $4:$5:$6\n";
	print $updDate."</td></tr>\n";
    
  print "<tr><td colspan=2>".($wl >= 1 ? $q->submit(-value=>'Update') : '')."</td></tr>\n";
  print "</table></form>\n";

  print &CMU::WebInt::subHeading("Attributes");
  my $attrs = CMU::Netdb::list_attribute_spec($dbh, $user, "attribute_spec.type = $id AND ".
					      " (attribute_spec.scope = 'service_membership' ".
					      " OR attribute_spec.scope = 'service')");
  if (!ref $attrs) {
    print "ERROR: Attribute spec list failed: ".$errmeanings{$attrs};
  }else{
    CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $attrs, ['attribute_spec.name', 'attribute_spec.format',
							    'attribute_spec.scope', 'attribute_spec.ntimes',
							    'attribute_spec.description'], 
				[], '', '', 'op=attr_spec_view&id=', CMU::Netdb::makemap($attrs->[0]),
				\%CMU::Netdb::structure::attribute_spec_printable, 'attribute_spec.name',
				'attribute_spec.id', '', []);
  }
  print "<br>";
  
  print &CMU::WebInt::subHeading("Add Attribute Specification");
  print &attr_spec_add_form($q, $id, $errors, 'service');

  print CMU::WebInt::stdftr($q);
}

sub attr_spec_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);

  my $SAC = 'attribute_spec';
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('attr_spec_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Attribute Specification", 
			    $errors);
  &CMU::WebInt::title('Attribute Specification');
  $id = CMU::WebInt::gParam($q, 'id');

  $$errors{msg} = "Attribute Specification ID not specified!" if ($id eq '');

  $url = $ENV{SCRIPT_NAME};

  ## Access is based on whether they can write to the service table that this is
  ## attached to
  my $sref = CMU::Netdb::list_attribute_spec($dbh, $user, "$SAC.id='$id'");
  if (!ref $sref) {
    print "ERROR: Reading list_$SAC: ".$errmeanings{$sref};
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my %stype_pos = %{CMU::Netdb::makemap($sref->[0])};
  my %stype_pr = %CMU::Netdb::structure::attribute_spec_printable;
  my @sdata = @{$sref->[1]};
  
  my $wl = 0;
  my $wlRow;
  my $wlTable;

  if ($sdata[$stype_pos{"$SAC.scope"}] eq 'service_membership' ||
      $sdata[$stype_pos{"$SAC.scope"}] eq 'service') {

      $wlTable = 'service_type';
      $wlRow = $sdata[$stype_pos{"$SAC.type"}];

      $wl = CMU::Netdb::get_write_level($dbh, $user, $wlTable, $wlRow);
  }elsif($sdata[$stype_pos{"$SAC.scope"}] =~ /^(users|groups|outlet|vlan|subnet)$/) {
    # Must have write access to the entire table to mess around with attribute specs

      $wlTable = $sdata[$stype_pos{"$SAC.scope"}];
      $wlRow = 0;

      $wl = CMU::Netdb::get_write_level($dbh, $user, $wlTable, $wlRow);
  } else {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Unknown attribute scope ".$sdata[$stype_pos{"$SAC.scope"}]."\n";
  }

  if ($wl < 1) {
    CMU::WebInt::accessDenied($wlTable, 'WRITE', $wlRow, 1, $wl, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<hr>".CMU::WebInt::errorDialog($url, $errors);

  print &CMU::WebInt::subHeading("Basic Information");
  my $version = $sdata[$stype_pos{"$SAC.version"}];
  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=prot_s3&table=attribute_spec&tidType=1&tid=$id\">View/Update Protections</a></b>] [<a href=\"".CMU::WebInt::encURL("$url?op=attr_spec_del&id=$id&version=$version")."\"><b>Delete Attribute Spec</b></a>]");

  print "<form method=get><input type=hidden name=op value=attr_spec_upd><input type=hidden name=id value=$id>
<input type=hidden name=version value=\"$version\">
<input type=hidden name=type value=".$sdata[$stype_pos{"$SAC.type"}].">
<table border=0>";
  
  # Name, Description
  my $namelen = length($sdata[$stype_pos{'attribute_spec.name'}]);
  my $desclen = length($sdata[$stype_pos{'attribute_spec.description'}]);
  $namelen = ($namelen > 50) ? 60 : $namelen + 10;
  $desclen = ($desclen > 50) ? 60 : $desclen + 10;
  print "<tr>".CMU::WebInt::printPossError(defined $$errors{name}, $stype_pr{"$SAC.name"}).
    CMU::WebInt::printPossError(defined $$errors{description}, $stype_pr{"$SAC.description"}).
      "</tr><tr><td>".CMU::WebInt::printVerbose("$SAC.name").$q->textfield(-name => 'name', -size => $namelen, -default => $sdata[$stype_pos{"$SAC.name"}]).
	"</td><td>".CMU::WebInt::printVerbose("$SAC.description").$q->textfield(-name => 'description', -size => $desclen, -default => $sdata[$stype_pos{"$SAC.description"}])."</td></tr>\n";

  # Scope, Format
  my $formatlen = length($sdata[$stype_pos{'attribute_spec.format'}]);
  $formatlen = ($formatlen > 50) ? 60 : $formatlen + 10;

  print "<tr>".CMU::WebInt::printPossError(defined $$errors{scope}, $stype_pr{"$SAC.scope"}).
    CMU::WebInt::printPossError(defined $$errors{format}, $stype_pr{"$SAC.format"}).
      "</tr><tr><td>".CMU::WebInt::printVerbose("$SAC.scope").$q->popup_menu(-name => 'scope', -default => $sdata[$stype_pos{"$SAC.scope"}],
									     -values => \@CMU::Netdb::structure::attribute_spec_scope,
									     -labels => \%CMU::Netdb::structure::attr_spec_scope_pr);
  print "</td><td>".CMU::WebInt::printVerbose("$SAC.format").$q->textfield(-name => 'format', -size => $formatlen, -default => $sdata[$stype_pos{"$SAC.format"}]).
    "</td></tr>\n";
									       

  # Ntimes, Version
  $sdata[$stype_pos{"$SAC.version"}] =~ /(....)(..)(..)(..)(..)(..)/;
  my $updDate = "$1-$2-$3 $4:$5:$6\n";

  print "<tr>".CMU::WebInt::printPossError(defined $$errors{ntimes}, $stype_pr{"$SAC.ntimes"}).
    CMU::WebInt::printPossError(0, $stype_pr{"$SAC.version"})."</tr><tr><td>".
      CMU::WebInt::printVerbose("$SAC.ntimes").$q->textfield(-name => 'ntimes', -default => $sdata[$stype_pos{"$SAC.ntimes"}]).
	"</td><td>$updDate</td></tr>\n";

  print "</table><input type=submit value=\"Update Spec\"></form>\n";

  print CMU::WebInt::stdftr($q);
}

sub attr_spec_add_form {
  my ($q, $type, $errors, $context) = @_;
  my %attr_s_pr = %CMU::Netdb::structure::attribute_spec_printable;
  $context = '' if (!defined $context);

  # Name, description
  my $res = "<form method=get><table border=0>".
    "<tr>".CMU::WebInt::printPossError(0, 
				       $attr_s_pr{'attribute_spec.name'}).
      CMU::WebInt::printPossError(0, $attr_s_pr{'attribute_spec.description'}).
	"</tr><tr><td>".CMU::WebInt::printVerbose('attribute_spec.name').
	  $q->textfield(-accesskey => 'a', -name => 'attr.name', -size => '25')."</td><td>".
	    CMU::WebInt::printVerbose('attribute_spec.description').
	      $q->textfield(-name => 'description', -accesskey => 'd', -size => '25')."</td></tr>\n";

  # Scope, NTimes
  my @scopes = @CMU::Netdb::structure::attribute_spec_scope;
  if ($context eq 'service') {
    @scopes = grep(/^(service|service_membership)$/, @CMU::Netdb::structure::attribute_spec_scope);
  } elsif ($context eq 'other') {
    @scopes = grep(!/^(service|service_membership)$/, @CMU::Netdb::structure::attribute_spec_scope) 
  }
  $res .= "<tr>".CMU::WebInt::printPossError(0, $attr_s_pr{'attribute_spec.scope'}).
      CMU::WebInt::printPossError(0, $attr_s_pr{'attribute_spec.ntimes'}).
	"</tr><tr><td>".CMU::WebInt::printVerbose('attribute_spec.scope').
	    $q->popup_menu(-name => 'scope',  -accesskey => 's',
			   -values => \@scopes,
			   -labels => \%CMU::Netdb::structure::attr_spec_scope_pr)
	      ."</td><td>".CMU::WebInt::printVerbose('attribute_spec.ntimes').
		$q->textfield(-name => 'ntimes',  -accesskey => 'm', -size => '25')."</td></tr>\n";

  # Format
  $res .= "<tr>".CMU::WebInt::printPossError(0, $attr_s_pr{'attribute_spec.format'}, 
					     2)
    ."</tr><td colspan=2>".CMU::WebInt::printVerbose('attribute_spec.format').
      $q->textfield(-name => 'format', -accesskey => 'd', -size => 50)."</td></tr>\n";
  
  # Service Type
  $res .= "</table><input type=submit value=\"Add Attribute Specification\">
          <input type=hidden name=type value=$type>\n".
	    "<input type=hidden name=op value=attr_spec_add>".
	      "<input type=hidden name=id value=$type></form>\n";
  
  return $res;
}			

sub attr_spec_add_form_full {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'attribute_spec', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('attr_spec_add_form_full');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Attribute Type Admin", $errors);
  print &CMU::WebInt::subHeading("Add Attribute Specification");

  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('attribute_spec', 'ADD', 0, 1, $userlevel,
			      $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  print attr_spec_add_form($q, 0, $errors, 'other');

  print &CMU::WebInt::stdftr($q);
  $dbh->disconnect();

}


sub attr_spec_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'attribute_spec', 0);
  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Attribute Specification",
			       $errors);
    &CMU::WebInt::title("Add Attribute Specification");
    CMU::WebInt::accessDenied('attribute_spec', 'ADD', 0, 1, $userlevel,
			      $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  foreach (qw/scope ntimes description format type/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  $fields{name} = CMU::WebInt::gParam($q, 'attr.name');
  
  my ($res, $errfields) = CMU::Netdb::add_attribute_spec($dbh, $user, \%fields);

  my $scope = CMU::WebInt::gParam($q, 'scope');

  warn __FILE__, ':', __LINE__, ' :>'.
    "ATTR SPEC ADD scope = $scope [$res]\n" if ($debug >= 2);
  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added $scope attribute specification.";
    $q->param('sid', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    if ($scope eq 'service' || $scope eq 'service_membership') {
      &CMU::WebInt::svc_type_view($q, \%nerrors);
    }else{
      &CMU::WebInt::attr_spec_list($q, \%nerrors);
    }

  }else{
    if ($res <= 0) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." )" 
	if ($res == $CMU::Netdb::errcodes{EDB});
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'attr_spec_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();

    if ($scope eq 'service' || $scope eq 'service_membership') {
      &CMU::WebInt::svc_type_view($q, \%nerrors);
    }elsif($scope eq 'users' || $scope eq 'groups') {
      CMU::WebInt::authmain($q, \%nerrors);
    }else{
      ## FIXME: Generic error page?
      &CMU::WebInt::svc_type_view($q, \%nerrors);
    }
  }
}

sub attr_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'attribute', 0);
  if ($userlevel < 1) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "Attribute",
			       $errors);
    &CMU::WebInt::title("Add Attribute");
    CMU::WebInt::accessDenied('attribute', 'ADD', 0, 1, $userlevel, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  foreach (qw/spec data owner_table owner_tid/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }

  my ($res, $errfields) = CMU::Netdb::add_attribute($dbh, $user, \%fields);

  my $OT = CMU::WebInt::gParam($q, 'owner_table');

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added attribute.";

    $dbh->disconnect(); # we use this for the insertid ..
    if ($OT eq 'service_membership' || $OT eq 'service') {
      &CMU::WebInt::svc_view($q, \%nerrors);
    }elsif($OT eq 'users') {
      $q->param('u', CMU::WebInt::gParam($q, 'owner_tid'));
      CMU::WebInt::auth_userinfo($q, \%nerrors);
    }elsif($OT eq 'groups') {
      $q->param('g', CMU::WebInt::gParam($q, 'owner_tid'));
      CMU::WebInt::auth_groupinfo($q, \%nerrors);
    }elsif($OT eq 'vlan') {
      $q->param('vid', CMU::WebInt::gParam($q, 'owner_tid'));
      &CMU::WebInt::vlans_view($q, \%nerrors);
    }elsif($OT eq 'outlet') {
      $q->param('oid', CMU::WebInt::gParam($q, 'owner_tid'));
      &CMU::WebInt::outlets_info($q, \%nerrors);
    }elsif($OT eq 'subnet') {
      $q->param('sid', CMU::WebInt::gParam($q, 'owner_tid'));
      &CMU::WebInt::subnets_view($q, \%nerrors);
    }elsif($OT eq 'machine') {
      $q->param('id', CMU::WebInt::gParam($q, 'owner_tid'));
      &CMU::WebInt::mach_view($q, \%nerrors);
    }else{
      # FIXME generic error?
      &CMU::WebInt::svc_view($q, \%nerrors);
    }

  }else{
    if ($res <= 0) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database Error: ".$CMU::Netdb::primitives::db_errstr." )"
        if ($res == $CMU::Netdb::errcodes{EDB});
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'attr_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();

    &CMU::WebInt::attr_add_form($q, \%nerrors);
  }
}

sub svc_type_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'service_type', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('svc_type_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Group Admin",
			    $errors);
  &CMU::WebInt::title("Add a Service Group Type");

  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('service_type', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  
  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));

  
  # name
  print "
<form method=get>
<input type=hidden name=op value=svc_type_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $CMU::Netdb::structure::service_type_printable{'service_type.name'}, 1, 'service_type.name')."</tr>
<tr><td>".CMU::WebInt::printVerbose('service_type.name', $verbose).
  $q->textfield(-name => 'name', -accesskey => 's')."</td></tr>\n";

  print "</table>\n";
  print "<input type=submit value=\"Add Service Group Type\">\n";

  print &CMU::WebInt::stdftr($q);


}

sub svc_type_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  %fields = ('name' => CMU::WebInt::gParam($q, 'name'));

  my ($res, $errfields) = CMU::Netdb::add_service_type($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added Service Group Type $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    svc_type_list($q, \%nerrors);
  }else{
    $nerrors{'msg'} = "Error adding Service Group Type: ";
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{type} = 'ERR';
      $nerrors{loc} = 'svc_type_add';
      $nerrors{code} = $res;
      $nerrors{fields} = join(',', @$errfields);
    }
    $dbh->disconnect();
    &svc_type_add_form($q, \%nerrors);
  }

}

sub svc_type_del {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('svc_type_del');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Group Admin", {});

  print &CMU::WebInt::subHeading("Delete Service Group Type", CMU::WebInt::pageHelpLink(''));
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'service_type', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('service_type', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic infromation
  my $sref = CMU::Netdb::list_service_types($dbh, $user, "service_type.id='$id' and service_type.version='$version'");
  if (!defined $sref->[1]) {
    print "Service Group Type not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  my $pos = CMU::Netdb::makemap($sref->[0]);
  print "<br><br>Please confirm that you wish to delete the following Service Group Type.\n";
  
  my @print_fields = ('service_type.name');
  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$CMU::Netdb::structure::service_type_printable{$f}."</th>
<td>";
    print $sdata[$pos->{$f}];
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=svc_type_del_conf&id=$id&version=$version")."\">
Yes, delete this Service Group Type";
  print "<br><a href=\"$url?op=svc_type_list\">No, return to the Service Group Type admin page</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub svc_type_confirm_del {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'service_type', $id);

  if ($ul < 1) {
    $errors{msg} = "Access denied while attempting to delete Service Group Type $id\n";
    $dbh->disconnect();
    svc_type_view($q, \%errors);
    return;
  }

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_service_type($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    svc_type_list($q, {'msg' => "The Service Group Type was deleted."});
  }else{
    $errors{msg} = "Error while deleting Service Group Type: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")" 
      if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{type} = 'ERR';
    $errors{loc} = 'svc_type_del_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    svc_type_list($q, \%errors);
  }

}

###
# service_view
# -- Prints info about a service

sub svc_view {
  my ($q, $errors) = @_;
  my ($dbh, $sid, $url, $res);

  $sid = CMU::WebInt::gParam($q, 'sid');
  $$errors{msg} = "Service ID not specified!" if ($sid eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('svc_info');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Admin", $errors);
  &CMU::WebInt::title("Service Information");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'service', $sid);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'service', $sid);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('service', 'READ', $sid, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  my $sref = CMU::Netdb::list_service_full_ref($dbh, $user, $sid);

  if (!ref $sref) {
    print "ERROR: No data retrieved from list_service_full_ref ($sid, $sref)!\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my %service = %$sref;
  print CMU::WebInt::subHeading("Information for: ".$service{service_name}, CMU::WebInt::pageHelpLink(''));
  my $pr = "[<b><a href=$url?op=svc_info&sid=$sid>Refresh</a></b>] 
  [<b><a href=$url?op=prot_s3&table=service&tidType=1&tid=$sid>View/Update&nbsp;Protections</a></b>] \n";
  $pr .= "[<a href=$url?op=history&tname=service&row=$sid><b>Show&nbsp;History</b></a>] \n"
    if (CMU::Netdb::get_user_admin_status($dbh, $user) == 1);
  $pr .= "[<b><a href=$url?op=svc_delete&sid=$sid>Delete Service</a></b>]";


  print CMU::WebInt::smallRight($pr);

  print "<form method=get>
<input type=hidden name=sid value=$sid>
<input type=hidden name=op value=svc_update>
<input type=hidden name=version value=\"".$service{'version'}."\">
<input type=hidden name=type value=$service{service_type}>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $CMU::Netdb::structure::service_printable{'service.name'}, 1, 'service.name').
  CMU::WebInt::printPossError(defined $errors->{'description'}, $CMU::Netdb::structure::service_printable{'service.description'}, 1, 'service.description')."</tr>";

  my $namelen = length($service{service_name});
  my $desclen = length($service{service_desc});
  $namelen = ($namelen > 50) ? 60 : $namelen + 10;
  $desclen = ($desclen > 50) ? 60 : $desclen + 10;
  $q->delete('name');
  $q->delete('description');
  print "<tr><td>".CMU::WebInt::printVerbose('service.name', $verbose).
    $q->textfield(-name => 'name', -accesskey => 's', -size => $namelen, -value => $service{service_name}).
      "</td><td>".CMU::WebInt::printVerbose('service.description', $verbose).
	$q->textfield(-name => 'description', -accesskey => 's', -size => $desclen,
		      -value => $service{service_desc})."</td></tr>\n";
  
  print CMU::WebInt::printPossError(defined $errors->{'service_type'}, $CMU::Netdb::structure::service_type_printable{'service_type.name'}, 1, 'service_type.name'). "</tr>\n";
  print "<tr><td>".CMU::WebInt::printVerbose('service_type.name', $verbose);
  my $stref = CMU::Netdb::list_service_types_ref($dbh, $user, '', 'service_type.name');
  print $stref->{$service{service_type}} . "</td></tr>\n";

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n" 
    if ($wl >= 1);
      
  print "</table></form>\n";

  # members
  my %mem_id_ref;
  my %SMTF = %CMU::Netdb::structure::service_member_type_fields;

  foreach my $ID (keys %{$service{memberRow}} ) {
    my $tname = $service{memberRow}->{$ID}->{'service_membership.member_type'};
    my $tid = $service{memberRow}->{$ID}->{'service_membership.member_tid'};
    $mem_id_ref{$tname}->{$tid} = $ID;
    warn __FILE__, ':', __LINE__, ' :>'.
      "$tname $tid == $ID\n" if ($debug >= 2);
  }
  
  my $ViewAllMembers = (CMU::WebInt::gParam($q, 'VAM') eq '1' ? 1 : 0);
  foreach my $Table (keys %{$service{memberSum}}) {
    print CMU::WebInt::subHeading("Members: $Table", 
				  CMU::WebInt::pageHelpLink('service_membership'));
    print "<br>";
    if ($#{$service{memberSum}->{$Table}} > 10 && !$ViewAllMembers) {
      print "More than 10 members of service/type $Table. <a href=\"$url?op=svc_info&sid=$sid&VAM=1\">Click here</a> to view all members.<br><br>\n";
      next;
    }
    foreach my $ID (@{$service{memberSum}->{$Table}}) {
      my $tid = $mem_id_ref{$Table}->{$ID};
      
      print "<table border=0 cellspacing=0 width=100%>";
      my $Vers = $service{memberRow}->{$tid}->{"service_membership.version"};
      my $SMURL = service_mem_view_url($Table, $ID);
      my $prHeading = $service{memberData}->{"$Table:$ID"}->{$SMTF{$Table}};
      $prHeading = "<a href=\"$url?$SMURL\" target=_blank>$prHeading</a>" if ($SMURL ne '');
      print CMU::WebInt::smallHeading
	($prHeading,
	 "[<a href=\"$url?op=attr_add_form".
	 "&t=service_membership&id=$tid\">".
	 "Add Attribute</a>] [<a href=\"$url?op=".
	 "svc_del_member&tname=$Table&mid=$ID&".
	 "back=service&v=$Vers&id=$tid&sid=$sid\">Remove</a>]");
      
      print "<tr><td colspan=2>";
      my @attr = keys %{$service{member_attr}->{"$Table:$ID"}};
      if ($#attr == -1) {
	print "<ul><li>No attributes.</ul>\n" if ($ul > 1);
      }else{
	print "<ul>";
	foreach my $att (sort {$a cmp $b} @attr) {
	  foreach my $da (sort {$a->[0] cmp $b->[0]} 
			  @{$service{member_attr}->{"$Table:$ID"}->{$att}}) {
	    print "<li>$att: $da->[0] [<a href=\"$url?op=attr_del&".
	      "id=$da->[1]&version=$da->[2]&sid=$sid\">Delete</a>]\n";
	  }
	}
      }
      print "</td></tr></table>\n";
    }
  }

  print "<br>\n";
  print CMU::WebInt::subHeading("<u>A</u>dd Member");
  print &CMU::WebInt::services::svc_cb_add_member($sid, $q);
  
  # attributes
 # only display attributes if real level > 1
  if ($ul > 1) {
  print CMU::WebInt::subHeading("Service Group Attributes", 
				CMU::WebInt::pageHelpLink('service_membership')).CMU::WebInt::smallRight("[<b><a href=\"$url?op=attr_add_form&t=service&id=$sid\">Add Attribute</a></b>]");
  
  
  my $attrs = CMU::Netdb::list_attribute($dbh, $user,
						 "attribute.owner_table = 'service' ".
						 "AND attribute.owner_tid = $sid ");
  if (!ref $attrs) {
    print "ERROR retrieving attributes from list_attribute: ".$errmeanings{$attrs};
  }else{
    my %prfields;
    map { 
      $prfields{$_} = $CMU::Netdb::structure::attribute_printable{$_};
    } keys %CMU::Netdb::structure::attribute_printable;
    map {
      $prfields{$_} = $CMU::Netdb::structure::attribute_spec_printable{$_};
     } keys %CMU::Netdb::structure::attribute_spec_printable;
    
    CMU::WebInt::generic_tprint($url, $attrs, ['attribute_spec.name', 
					      'attribute.data'],
				[\&CMU::WebInt::svc_cb_attr_del], $sid,
				'', '', CMU::Netdb::makemap($attrs->[0]), 
				\%prfields, '', '', '', []);
  }
  print "<br>";
}

  # dns resources

  print CMU::WebInt::subHeading("DNS Resources", "<a href=\"$url?op=mach_dns_res_add&owner_tid=$sid&owner_type=service&host=$service{service_name}\">Add DNS Resource</a>\n");
  print CMU::WebInt::printVerbose('svc_view.dns_resources');
  
  my $ldrr = CMU::Netdb::list_dns_resources($dbh, 'netreg', "dns_resource.owner_type = 'service' AND dns_resource.owner_tid = '$sid'");
  if (!ref $ldrr) {
    print "Unable to list DNS resources.\n";
    &CMU::WebInt::admin_mail('services.pm:svc_view', 'WARNING',
			     'Unable to list DNS resources.', 
			     { 'id' => $sid});
  }

  if($#$ldrr == 0) {
    print "[There are no DNS resources for this service.]\n";
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
	print "<td>${FS}Name: $$Res[$pos{'dns_resource.name'}]</td>\n".
	  "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
      }elsif($Type eq 'NS') {
	print "<td><B>NS</B></TD>\n";
	print "<td>${FS}Nameserver: $$Res[$pos{'dns_resource.rname'}]<br>".
	  "Host/domain: $$Res[$pos{'dns_resource.name'}]</td>\n";
	print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
      }elsif($Type eq 'MX') {
	print "<td><B>MX</B></TD>\n";
	print "<td>${FS}Mail exchanger: $$Res[$pos{'dns_resource.rname'}]<br>".
	  "Host/domain: $$Res[$pos{'dns_resource.name'}]</td>\n";
	print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]<BR>\n".
	  "Metric: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
      }elsif($Type eq 'TXT') {
	print "<td><b>TXT</b></td>\n";
	print "<td>${FS}Text Information: $$Res[$pos{'dns_resource.text0'}]</td>\n";
	print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td><BR>\n";
      }elsif($Type eq 'HINFO') {
	print "<td><b>HINFO</b></td>\n";
	print "<td>${FS}Field 0: $$Res[$pos{'dns_resource.text0'}]<br>".
	  "Field 1: $$Res[$pos{'dns_resource.text1'}]</td>\n";
	print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
      }elsif($Type eq 'RP') {
        print "<td><b>RP</b></td>\n";
        my $t0 = $$Res[$pos{'dns_resource.text0'}];
        $t0 =~ s/\./\@/;
        my $t1 = $$Res[$pos{'dns_resource.text1'}];
        print "<td>${FS}Contact: $t0</td><td>Text Info Record: $t1</td>\n";
      }elsif($Type eq 'SRV') {
	print "<td><b>SRV</b></td>\n";
	print "<td>${FS}Resource/Port: $$Res[$pos{'dns_resource.name'}] / $$Res[$pos{'dns_resource.rport'}]<br>".
	  "Metric 0: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
	print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]<br>".
	  "Metric 1: $$Res[$pos{'dns_resource.rmetric1'}]</td>\n";
      }elsif($Type eq 'AFSDB') {
	print "<td><b>AFSDB</b></td>\n";
	print "<td>${FS}DB Server: $$Res[$pos{'dns_resource.rname'}]</td>";
	print "<td>Type: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
      }else{
	print "<td><b>$Type</b></td><td colspan=2>[no format information]</td>\n";
      }
      print "<td><a href=\"".CMU::WebInt::encURL("$url?op=mach_dns_res_del&id=$$Res[$pos{'dns_resource.id'}]&version=$$Res[$pos{'dns_resource.version'}]&owner_type=service&owner_tid=$sid")."\">Delete</a></td>\n" if ($wl >= 1);
      print "</tr>\n";
    }
    print "</table>\n";
  }

  print "<br><br>\n";

  ## And DHCP Options
  
  my $ldor = CMU::Netdb::list_dhcp_options
    ($dbh, 'netreg', " dhcp_option.tid = '$sid' AND ".
     "dhcp_option.type = 'service'");

  if (!ref $ldor) {
    print "Unable to list DHCP Options.\n";
    &CMU::WebInt::admin_mail('services.pm:mach_view', 'WARNING',
                'Unable to list DHCP options.',
			     {'sid' => $sid });
  }else{

    print CMU::WebInt::subHeading
      ("DHCP Options", 
       "<a href=\"$url?op=mach_dhcp_add&type=service&tid=$sid&printable=".
       "$service{service_name}\">".
       "Add DHCP Option</a>\n");
    
    print CMU::WebInt::printVerbose('service.dhcp_options');
    
    if($#$ldor == 0) {
      print "<br>[There are no DHCP options for this service group.]\n";
    }else{
      CMU::WebInt::generic_tprint
	($url, $ldor,
	 ['dhcp_option_type.name', 'dhcp_option.value'],
	 [\&CMU::WebInt::machines::mach_cb_dhcp_opt_del],
	 "service&tid=$sid", '', '', \%CMU::WebInt::dhcp::dhcp_o_c_pos,
	 \%CMU::Netdb::structure::dhcp_option_printable,
	 '', '', '', []);
    }
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


sub svc_cb_add_member {
  my ($cdata, $q) = @_;
  return "<form method=get>
<input type=hidden name=op value=svc_add_member>
<input type=hidden name=sid value=$cdata>
<b>Add: </b>
<input accesskey=a type=text name=newMember>&nbsp;".
$q->popup_menu(-name => 'member_type',
	       -values => \@CMU::Netdb::structure::service_member_types).
"<input type=submit value=\"Add Member\"></form>
";
}


sub svc_delete {
  my ($q) = @_;
  my ($dbh, $where, $sid, $url, $res);

  $sid = CMU::WebInt::gParam($q, 'sid');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('svc_delete');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Admin", {});
  &CMU::WebInt::title("Delete Service");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'service', $sid);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('service', 'WRITE', $sid, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  # basic service information (name, description)
  my $sref = CMU::Netdb::list_services($dbh, $user, "service.id='$sid'");
  my @sdata = @{$sref->[1]};
  
  print CMU::WebInt::subHeading("Confirm Deletion of: ".$sdata[$service_pos{'service.name'}]);
  print "Please confirm that you wish to delete the following service.";
  print "<br>This will delete <b>all attributes</b>!\n";
  print "<br>Clicking \"Delete Service\" below will cause this service and all ".
    "associated information to be deleted.\n";
  
  print "<table border=0>
<tr><td bgcolor=lightyellow>Name</td><td>$sdata[$service_pos{'service.name'}]</td></tr>
<tr><td bgcolor=lightyellow>Description</td><td>$sdata[$service_pos{'service.description'}]</td></tr>
</table>
<form method=get>
<input type=hidden name=op value=svc_del_conf>
<input type=hidden name=sid value=$sid>
<input type=hidden name=version value=\"".$sdata[$service_pos{'service.version'}]."\">
<input type=submit value=\"Delete Service\">
</form>
";
  $dbh->disconnect();
  print &CMU::WebInt::stdftr($q);

}

sub svc_delete_conf {
  my ($q) = @_;
  my ($dbh, $id, $version);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $id = CMU::WebInt::gParam($q, 'sid');
  $version = CMU::WebInt::gParam($q, 'version');
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'service', $id);
  if ($ul == 0) {
    CMU::WebInt::accessDenied('service', 'WRITE', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my ($res, $ref) = CMU::Netdb::delete_service($dbh, $user, $id, $version);
  my %errors;
  if ($res != 1) {
    $errors{msg} = "Error deleting service: ".$errmeanings{$res};
    $errors{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $errors{type} = 'ERR';
    $errors{loc} = 'service_del_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$ref);
  }else{
    $errors{msg} = "Service deleted.";
  }
  
  $dbh->disconnect();
  CMU::WebInt::svc_main($q, \%errors);
}

sub svc_update {
  my ($q) = @_;
  my ($dbh, $version, $id, %fields, %error);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'version');
  $id = CMU::WebInt::gParam($q, 'sid');
  my $ul = CMU::Netdb::get_write_level($dbh, $user, 'service', $id);
  if ($ul == 0) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Update", {});
    &CMU::WebInt::title("Update Error");
    CMU::WebInt::accessDenied('service', 'WRITE', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  %fields = ('name' => CMU::WebInt::gParam($q, 'name'),
	     'description' => CMU::WebInt::gParam($q, 'description'),
	     'type' => CMU::WebInt::gParam($q, 'type'),
	     );
  
  my ($res, $field) = CMU::Netdb::modify_service($dbh, $user, $id, $version, \%fields);
  if ($res >= 1) {
    $error{msg} = "Service information has been updated.";
  }else{
    $error{msg} = "Error updating service information: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    map { if ($_ eq 'type') { $error{"service_type"} = 1; } else { $error{$_} = 1 }
	} @$field if ($res <= 0);
    $error{type} = 'ERR';
    $error{loc} = 'svc_update';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
    $error{$field} = 1;
  }
  $dbh->disconnect();
  CMU::WebInt::svc_view($q, \%error);
}


sub svc_del_member {
  my ($q) = @_;
  my ($dbh, $res, $version, $id, $url, %error, $field);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'v');
  $id = CMU::WebInt::gParam($q, 'id');

  ($res, $field) = CMU::Netdb::delete_service_membership($dbh, $user, $id, $version);
  if ($res != 1) {
    $error{msg} = "Error deleting member from service: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{type} = 'ERR';
    $error{loc} = 'svc_del_member';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
  }else{
    $error{msg} = "Member deleted from the service.";
  }
  $dbh->disconnect();
  if (CMU::WebInt::gParam($q, 'back') eq 'machine') {
    $q->param('id', CMU::WebInt::gParam($q, 'mid'));
    CMU::WebInt::mach_view($q, \%error);
  } elsif(CMU::WebInt::gParam($q, 'back') eq 'subnet') {
    CMU::WebInt::subnets_view($q, \%error);
  } elsif(CMU::WebInt::gParam($q, 'back') eq 'vlan') {
    CMU::WebInt::vlans_view($q, \%error);
  } elsif(CMU::WebInt::gParam($q, 'back') eq 'zone') {
    $q->param('id', CMU::WebInt::gParam($q, 'sid'));
    CMU::WebInt::zone_view($q, \%error);
  } else {
    CMU::WebInt::svc_view($q, \%error);
  }
}
    
sub svc_add_member {
  my ($q) = @_;
  my (%fields, $res, %error, $dbh, $ref);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  %fields = ('service' => CMU::WebInt::gParam($q, 'sid'));
  
  my $Back = CMU::WebInt::gParam($q, 'back');
  if ($Back eq 'machine') {
    $fields{'member_tid'} = CMU::WebInt::gParam($q, 'machine');
    $fields{'member_type'} = 'machine';
    ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $user, \%fields);
  } elsif($Back eq 'subnet') {
    $fields{'member_tid'} = CMU::WebInt::gParam($q, 'subnet');
    $fields{'member_type'} = 'subnet';
    ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $user, \%fields);
  } elsif($Back eq 'vlan') {
    $fields{'member_tid'} = CMU::WebInt::gParam($q, 'vlan');
    $fields{'member_type'} = 'vlan';
    ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $user, \%fields);
  } elsif($Back eq 'zone') {
    $fields{'member_tid'} = CMU::WebInt::gParam($q, 'zone');
    $fields{'member_type'} = 'dns_zone';
    ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $user, \%fields);
  } else {
    $fields{'member_type'} = CMU::WebInt::gParam($q, 'member_type');
    my @members;
    ($res, @members) = svc_add_member_locate($dbh, $user, $q);
    if ($res < 1) {
      $ref = [$fields{'member_type'}];
    }else{
      $error{msg} = "Adding ".scalar(@members)." entries to service:<br>";
      foreach my $m (@members) {
	$fields{'member_tid'} = $m;
	($res, $ref) = CMU::Netdb::add_service_membership($dbh, $user, \%fields);
	if ($res != 1) {
	  $error{msg} .= "Error adding machine $m to service: ".$errmeanings{$res}." (".join(',', @$ref).") ";
	  $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
	    if ($res eq $CMU::Netdb::errcodes{EDB});
	  $error{msg} .= "[".join(',', @$ref)."]<br>";
	  $error{type} = 'ERR';
	  $error{loc} = 'service_add_member';
	  $error{code} = $res;
	  $error{fields} = join(',', @$ref);
	}else{
	  $error{msg} .= "Member ($fields{'member_type'}) $m added to the service.<br>";
	}
      }
    }
  }

  if (!$error{msg}) {
    if ($res != 1) {
      $error{msg} = "Error adding member to service: ".$errmeanings{$res};
      $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")" 
	if ($res eq $CMU::Netdb::errcodes{EDB});
      $error{msg} .= "[".join(',', @$ref)."]";
      $error{type} = 'ERR';
      $error{loc} = 'service_add_member';
      $error{code} = $res;
      $error{fields} = join(',', @$ref);
    }else{
      $error{msg} = "Member added to the service.";
    }
  }
  $dbh->disconnect();
  if ($Back eq 'machine') {
    $q->param('id', CMU::WebInt::gParam($q, 'mid'));
    CMU::WebInt::mach_view($q, \%error);
  } elsif($Back eq 'subnet') {
    $q->param('sid', CMU::WebInt::gParam($q, 'subnet'));
    CMU::WebInt::subnets_view($q, \%error);
  } elsif($Back eq 'vlan') {
    $q->param('vid', CMU::WebInt::gParam($q, 'vlan'));
    CMU::WebInt::vlans_view($q, \%error);
  } elsif($Back eq 'zone') {
    CMU::WebInt::zone_view($q, \%error);
  } else {
    CMU::WebInt::svc_view($q, \%error);
  }
}

## Routines to find a specific member given a generic string
## from the form
sub svc_add_member_locate {
  my ($dbh, $user, $q) = @_;

  my $Table = CMU::WebInt::gParam($q, 'member_type');
  my $Data = CMU::WebInt::gParam($q, 'newMember');

  if ($Table eq 'activation_queue') {

  }elsif($Table eq 'building') {
    my $ref = CMU::Netdb::list_buildings($dbh, $user, "building.name = '$Data'");
    if (!(ref $ref) || ($#$ref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      return (1, $ref->[1]->[$pos{'building.id'}]);
    }
  }elsif($Table eq 'cable') {

  }elsif($Table eq 'dns_zone') {
    my $ref = CMU::Netdb::list_dns_zones($dbh, $user, "dns_zone.name = '$Data'");
    if (!(ref $ref) || ($#$ref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      return (1, $ref->[1]->[$pos{'dns_zone.id'}]);
    }
  }elsif($Table eq 'groups') {
    my $ref = CMU::Netdb::list_groups($dbh, $user, "groups.name = '$Data'");
    if (!(ref $ref) || ($#$ref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      return (1, $ref->[1]->[$pos{'groups.id'}]);
    }
  }elsif($Table eq 'machine') {
    my $ref;
    warn "Data is $Data\n";
    if ($Data =~ /\%/) {
      $ref = CMU::Netdb::list_machines($dbh, $user, "host_name LIKE '$Data'");
    } else {
      $ref = CMU::Netdb::list_machines($dbh, $user, "host_name = '$Data'");
    }
    warn __FILE__, ':', __LINE__, ' :>'.
      "TABLE MACHINE REFCOUNT $#$ref\n" if ($debug >= 2);
    if (!(ref $ref) || ($#$ref < 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      shift @$ref;
      return (1, map { $_->[$pos{'machine.id'}] } @$ref);
    }
  }elsif($Table eq 'outlet_type') {

  }elsif($Table eq 'service') {
    my $ref = CMU::Netdb::list_services($dbh, $user, "service.name = '$Data'");
    if (!(ref $ref) || ($#$ref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      return (1, $ref->[1]->[$pos{'service.id'}]);
    }
  }elsif($Table eq 'subnet') {
    my $ref = CMU::Netdb::list_subnets($dbh, $user, "subnet.name = '$Data'");
    if (!(ref $ref) || ($#$ref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      return (1, $ref->[1]->[$pos{'subnet.id'}]);
    }
  }elsif($Table eq 'subnet_share') {

  }elsif($Table eq 'trunk_set') {
    my $ref = CMU::Netdb::list_trunkset($dbh, $user, "trunk_set.name = '$Data'");
    if (!(ref $ref) || ($#$ref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      return (1, $ref->[1]->[$pos{'trunk_set.id'}]);
    }
  }elsif($Table eq 'vlan') {
    my $ref = CMU::Netdb::list_vlans($dbh, $user, "vlan.name = '$Data'");
    if (!(ref $ref) || ($#$ref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($ref->[0])};
      return (1, $ref->[1]->[$pos{'vlan.id'}]);
    }
  }elsif($Table eq 'users') {
    my $uref = CMU::Netdb::list_users($dbh, $user, 
				      "credentials.authid = '".lc($Data).'"');
    if (!(ref $uref) || ($#$uref != 1)) {
      return ($CMU::Netdb::errcodes{ENOENT});
    }else{
      my %pos = %{CMU::Netdb::makemap($uref->[0])};
      return (1, $uref->[1]->[$pos{'users.id'}]);
    }    
  }else{
    return (-1, 0);
  }


}


# Displays a generic table of attributes on a resource
# where clause can limit what attributes to display
# display_empty_table controls whether the table (and add link) will be displayed
# if no attributes currently exist.
sub attr_display {
  my ($dbh, $user, $context, $id, $where, $display_empty_table) = @_;
  my $url = $ENV{SCRIPT_NAME};

  $display_empty_table = 1 if (!defined $display_empty_table);
  if (!$where) {
    $where = "attribute.owner_table = '$context' AND attribute.owner_tid = $id ";
  } else {
    $where = "attribute.owner_table = '$context' AND attribute.owner_tid = $id AND $where";
  }

  # If no attributes exist for this scope, skip the UI.
  my $spec = CMU::Netdb::list_attribute_spec_ref($dbh, $user, "attribute_spec.scope = '$context'",
						 "attribute_spec.name");
  return if (!ref $spec || scalar(keys(%$spec)) == 0);

  my $attrs = CMU::Netdb::list_attribute($dbh, $user, $where);
  if (!ref $attrs) {
    print "ERROR retrieving attributes from list_attribute: ".$errmeanings{$attrs};
  }elsif ($#$attrs == 0 && !$display_empty_table) {
    return;
  } else {
    print CMU::WebInt::subHeading("Attributes", 
				  CMU::WebInt::pageHelpLink('attributes')).
				      CMU::WebInt::smallRight("[<b><a href=\"$url?op=attr_add_form&t=$context&id=$id\">Add Attribute</a></b>]");

    my %prfields;
    map { 
      $prfields{$_} = $CMU::Netdb::structure::attribute_printable{$_};
    } keys %CMU::Netdb::structure::attribute_printable;
    map {
      $prfields{$_} = $CMU::Netdb::structure::attribute_spec_printable{$_};
    } keys %CMU::Netdb::structure::attribute_spec_printable;

    CMU::WebInt::generic_tprint($url, $attrs, ['attribute_spec.name', 'attribute_spec.description'],
				[\&CMU::WebInt::attr_cb_data, \&CMU::WebInt::attr_cb_attr_del], [$context, $id],
				'', '', CMU::Netdb::makemap($attrs->[0]), 
				\%prfields, '', '', '', []);
  }
}

sub attr_cb_data {
  my ($url, $row, $edata) = @_;
  return $CMU::Netdb::structure::attribute_printable{'attribute.data'} if (!ref $row);
  my $data = $row->[$attr_pos{'attribute.data'}];
  $data =~ s/\</\&lt\;/g;
  $data =~ s/\>/\&gt\;/g;
  return $data;
}

sub attr_cb_attr_del {
  my ($url, $row, $edata) = @_;
  return "Operations" if (!ref $row);
  my $id = $row->[$attr_pos{'attribute.id'}];
  my $version = $row->[$attr_pos{'attribute.version'}];
  my ($context, $owner) = @$edata;
  my $back = $context."_view";
  $back = 'auth_userinfo' if ($context eq 'users');
  $back = 'auth_grp_info' if ($context eq 'groups');
  $back = 'vlans_view' if ($context eq 'vlan');
  $back = 'subnets_view' if ($context eq 'subnet');
  return "<a href=\"".CMU::WebInt::encURL("$url?op=attr_del&back=$back&owner_tid=$owner&id=$id&version=$version")."\">Delete</a>";
}

sub attr_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  my ($t, $id) = (CMU::WebInt::gParam($q, 't'),
		  CMU::WebInt::gParam($q, 'id'));

  my $ul = CMU::Netdb::get_add_level($dbh, $user, 'attribute', 0);
  if ($ul >= 1) {
    if ($t eq 'service_membership') {
      my ($mach, $rMemRow, $rMemSum, $rMemData) = 
	CMU::Netdb::list_service_members($dbh, $user, "service_membership.id = '$id'");

      if ($mach < 1) {
	$userlevel = 0;
      } else {
	$userlevel = CMU::Netdb::get_add_level($dbh, $user, 'service', 
					       $rMemRow->{$id}->{'service.id'});
      }
    } elsif ($t eq 'outlet' || $t eq 'users' || $t eq 'machine' || $t eq 'groups') {
      # For outlets and users, only require write access to the row.
      $userlevel = CMU::Netdb::get_write_level($dbh, $user, $t, $id);
    } else {
      $userlevel = CMU::Netdb::get_add_level($dbh, $user, $t, $id);
    }
  }else{
    $userlevel = 0;
  }

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('attr_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Service Admin", $errors);
  &CMU::WebInt::title("Add an Attribute");

  print CMU::WebInt::errorDialog($url, $errors);

  if ($userlevel < 1) {
    CMU::WebInt::accessDenied($t, 'ADD', $id, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  ## Get information about this service/service_membership
  my $ServiceInfo;
  my $ServiceID;
  {
    if ($t eq 'service_membership') {
      my ($mach, $rMemRow, $rMemSum, $rMemData) = 
	CMU::Netdb::list_service_members($dbh, $user, "service_membership.id = '$id'");
      if ($mach < 0) {
	print "ERROR in list_service_members while looking up service/mach info: ".
	  $errmeanings{$mach};
	$dbh->disconnect();
	print CMU::WebInt::stdftr($q);
	return;
      }
      if ($mach < 1) {
	print "ERROR: Service membership specified does not exist!";
	$dbh->disconnect();
	print CMU::WebInt::stdftr($q);
	return;
      }
      $ServiceInfo = service_mem_printable($id, $rMemRow, $rMemSum, $rMemData);
      $ServiceID = $rMemRow->{$id}->{'service.id'};
    }elsif($t eq 'service') {
      my $serv = CMU::Netdb::get_services_ref($dbh, $user, " service.id = \'$id\' ", 
					      'service.name');
      if (!ref $serv) {
	print "ERROR in get_services_ref while looking up service info: ".$errmeanings{$serv};
	$dbh->disconnect();
	print CMU::WebInt::stdftr($q);
	return;
      }
      if (!defined $serv->{$id}) {
	print "ERROR: Service specified does not exist!";
	$dbh->disconnect();
	print CMU::WebInt::stdftr($q);
	return;
      }
      $ServiceInfo = "Service \'$serv->{$id}\'";
      $ServiceID = $id;
    }elsif($t eq 'users') {
      my $user = CMU::Netdb::list_users($dbh, $user, "users.id = '$id'");
      if (!ref $user) {
	print "ERROR in list_users while looking up user info ($id): ".
	  $errmeanings{$user};
	$dbh->disconnect();
	return;
      }
      my %pos = %{CMU::Netdb::makemap($user->[0])};

      $ServiceInfo = "User $user->[1]->[$pos{'users.description'}]";
      $ServiceID = -1; # There aren't sub-classifications among users for attr types
    }elsif($t eq 'groups') {
      my $group = CMU::Netdb::list_groups($dbh, $user, "groups.id = '$id'");
      if (!ref $group) {
	print "ERROR in list_groups while looking up group info: ".
	  $errmeanings{$group};
	$dbh->disconnect();
	return;
      }
      my %pos = %{CMU::Netdb::makemap($group->[0])};
      $ServiceInfo = "Group $group->[1]->[$pos{'groups.description'}]";
      $ServiceID = -1; # There aren't sub-classifications among groups for attr types
    }elsif($t eq 'vlan') {
      my $vlan = CMU::Netdb::list_vlans($dbh, $user, "vlan.id = '$id'");
      if (!ref $vlan) {
	print "ERROR in list_vlans while looking up vlan info ($id): ".
	  $errmeanings{$vlan};
	$dbh->disconnect();
	return;
      }
      my %pos = %{CMU::Netdb::makemap($vlan->[0])};

      $ServiceInfo = "Vlan $vlan->[1]->[$pos{'vlan.name'}]";
      $ServiceID = -1; # There aren't sub-classifications among vlans for attr types
    }elsif($t eq 'outlet') {
      my $outlet = CMU::Netdb::list_outlets_cables($dbh, $user, "outlet.id = '$id'");
      if (!ref $outlet) {
	print "ERROR in list_outlets while looking up outlet info ($id): ".
	  $errmeanings{$outlet};
	$dbh->disconnect();
	return;
      }
      my %pos = %{CMU::Netdb::makemap($outlet->[0])};

      $ServiceInfo = "Outlet $outlet->[1]->[$pos{'cable.label_from'}]/$outlet->[1]->[$pos{'cable.label_to'}]";
      $ServiceID = -1; # There aren't sub-classifications among outlets for attr types
    }elsif ($t eq 'subnet') {
      my $subnet = CMU::Netdb::list_subnets($dbh, $user, "subnet.id = '$id'");
      if (!ref $subnet) {
	print "ERROR in list_subnets while looking up subnet info ($id): ".
	  $errmeanings{$subnet};
	$dbh->disconnect();
	return;
      }
      my %pos = %{CMU::Netdb::makemap($subnet->[0])};

      $ServiceInfo = "Subnet $subnet->[1]->[$pos{'subnet.name'}]";
      $ServiceID = -1; # There aren't sub-classifications among subnets for attr types

    }elsif ($t eq 'machine') {
      my $mach = CMU::Netdb::list_machines($dbh, $user, "machine.id = '$id'");
      if (!ref $mach) {
        print "ERROR in list_machines while looking up subnet info ($id): ".
          $errmeanings{$mach};
        $dbh->disconnect();
        return;
      }
      my %pos = %{CMU::Netdb::makemap($mach->[0])};

      $ServiceInfo = "Machine $mach->[1]->[$pos{'machine.host_name'}]";
      $ServiceID = -1; # There aren't sub-classifications among subnets for attr types



    } else {
      print "Attribute scope is unknown!\n";
      $dbh->disconnect();
      print CMU::WebInt::stdftr($q);
      return;
    }
  }    

  ## Get the ID of the service type from the service
  my $TypeID = -1;
  if ($ServiceID != -1) {
    my $type = CMU::Netdb::get_services_ref($dbh, $user, " service.id = \'$ServiceID\' ",
					    'service.type');
    if (!ref $type) {
      print "ERROR in get_services_ref while looking up service type: ".$errmeanings{$type};
      $dbh->disconnect();
      print CMU::WebInt::stdftr($q);
      return;
    }
    if (!defined $type->{$ServiceID}) {
      print "ERROR: Service ($ServiceID) derived does not exist!";
      $dbh->disconnect();
      print CMU::WebInt::stdftr($q);
      return;
    }
    $TypeID = $type->{$ServiceID};
  }

  print CMU::WebInt::subHeading("Attribute Information", CMU::WebInt::pageHelpLink(''));
  
  print "<font face=\"Arial,Helvetica,Geneva,Charter\">Adding attribute for ".
    "<b>$ServiceInfo</b></font><br><br>\n";

  my $where = "attribute_spec.scope = '$t' ";
  $where .= " AND attribute_spec.type = '$TypeID'" if ($TypeID != -1);
  
  my $attrs = CMU::Netdb::list_attribute_spec_ref
    ($dbh, $user, $where, 'attribute_spec.name');

  if (!ref $attrs) {
    print "ERROR getting valid attributes! ".$errmeanings{$attrs};
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  if ($t eq 'outlet') {
    # Filter out attribute types that have custom UI on the outlet page.
    foreach (keys %$attrs) {
      delete $attrs->{$_} if ($attrs->{$_} =~ /^(port-speed|port-duplex)$/);
    }
  }

  my @att = sort { $attrs->{$a} cmp $attrs->{$b} } keys %$attrs;


  # Attribute
  print "
<form method=get>
<input type=hidden name=op value=attr_add>
<input type=hidden name=t value=$t>
<input type=hidden name=id value=$id>
<input type=hidden name=sid value=$ServiceID>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{spec}, 
				  $CMU::Netdb::structure::attribute_spec_printable{'attribute_spec.name'}, 1, 'attribute.spec');
  if (defined $errors{data}) {
    print CMU::WebInt::printPossError(0, $CMU::Netdb::structure::attribute_spec_printable{'attribute_spec.format'}, 1, 'attribute_spec.format');
  }

  print "</tr><tr><td>".
    CMU::WebInt::printVerbose('attribute.spec').
      $q->popup_menu(-name => 'spec', -accesskey => 'a',
		     -values => \@att,
		     -labels => $attrs)."</td>";
  if (defined $errors{data}) {
    my $specID = CMU::WebInt::gParam($q, 'spec');
    my $format = CMU::Netdb::list_attribute_spec_ref($dbh, $user,
							 " attribute_spec.id = \'$specID\' ",
							 'attribute_spec.format');
    if (ref $format && defined $format->{$specID}) {
      print "<td>".CMU::WebInt::printVerbose('attribute_spec.format').
	"<font face=\"Arial,Helvetica,Geneva,Charter\">Format: <b>".
	$format->{$specID}."</font></b></td>";
    }else{
      print "<td>*error*\n</td>";
    }
  }

  # Data
  my $cols = 1;
  $cols = 2 if (defined $errors{data});
  print "<tr>".CMU::WebInt::printPossError(0, 
					   $CMU::Netdb::structure::attribute_printable{'attribute.data'}, $cols);
  print "</tr><tr><td colspan=$cols>".CMU::WebInt::printVerbose('attribute.data').
    $q->textfield(-name => 'data', -accesskey => 'a', -size => 50)."</td></tr>\n";
  
  print "</table>\n";
  print "<input type=submit value=\"Add Attribute\">
<input type=hidden name=owner_table value=$t>
<input type=hidden name=owner_tid value=$id>
\n";

  print &CMU::WebInt::stdftr($q);

}

sub attr_spec_upd {
  my ($q) = @_;
  my ($dbh, $version, $id, %fields, %error);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $version = CMU::WebInt::gParam($q, 'version');
  $id = CMU::WebInt::gParam($q, 'id');

  foreach (qw/name description scope format ntimes type/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
    $q->delete($_);
  }

  my ($res, $field) = CMU::Netdb::modify_attribute_spec($dbh, $user, $id, $version, \%fields);
  if ($res >= 1) {
    $error{msg} = "Attribute spec information has been updated.";
  }else{
    $error{msg} = "Error updating attribute spec information: ".$errmeanings{$res};
    $error{msg} .= "(".$CMU::Netdb::primitives::db_errstr.")"
      if ($res eq $CMU::Netdb::errcodes{EDB});
    $error{msg} .= " -- Fields: ".join(',',@$field);
    $error{type} = 'ERR';
    $error{loc} = 'attr_spec_upd';
    $error{code} = $res;
    $error{fields} = join(',', @$field);
    $error{$field} = 1;
  }
  $dbh->disconnect();
  CMU::WebInt::attr_spec_view($q, \%error);
}


sub attr_spec_del {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);

  if (CMU::WebInt::gParam($q, 'confirm') eq 'yes') {
    return attr_spec_del_conf($q, $errors);
  }

  my $SAC = 'attribute_spec';
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('attr_spec_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Attribute Specification",
			    $errors);
  &CMU::WebInt::title('Attribute Specification');
  $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');

  $$errors{msg} = "Attribute Specification ID not specified!" if ($id eq '');
  
  $url = $ENV{SCRIPT_NAME};

  ## Access is based on whether they can write to the service table that this is
  ## attached to
  my $sref = CMU::Netdb::list_attribute_spec($dbh, $user, "$SAC.id='$id'");
  if (!ref $sref) {
    print "ERROR: Reading list_$SAC: ".$errmeanings{$sref};
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my %stype_pos = %{CMU::Netdb::makemap($sref->[0])};
  my %stype_pr = %CMU::Netdb::structure::attribute_spec_printable;
  my @sdata = @{$sref->[1]};

  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'service_type', $sdata[$stype_pos{"$SAC.type"}]);

  if ($wl < 1) {
    CMU::WebInt::accessDenied('service_type', 'WRITE',
			      $sdata[$stype_pos{"$SAC.type"}], 1, $wl, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<hr>".CMU::WebInt::errorDialog($url, $errors);
  
  print "You must confirm deletion of this attribute specification. This will also ".
    "<b>delete all instances</b> of this attribute spec.<br><br>
<table border=0><tr><th>Name:</th><td>".$sdata[$stype_pos{"$SAC.name"}]."</td></tr>
<tr><th>Description:</th><td>".$sdata[$stype_pos{"$SAC.description"}]."</td></tr>
</table>
<br>
<a href=\"".CMU::WebInt::encURL("$url?op=attr_spec_del&confirm=yes&scope=".$sdata[$stype_pos{"$SAC.scope"}]
."&type=".$sdata[$stype_pos{"$SAC.type"}]
."&id=$id&version=$version")."\">Yes, delete this attribute specification.</a><br>
<a href=\"$url?op=attr_spec_view&id=$id\">No, go back to the attribute specification information.</a>
";
  print CMU::WebInt::stdftr($q);

}

sub attr_spec_del_conf {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, $scope, $type, %errors) = @_;

  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  $scope = CMU::WebInt::gParam($q, 'scope');
  $type = CMU::WebInt::gParam($q, 'type');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_attribute_spec($dbh, $user, $id, $version);

  $dbh->disconnect;
  if ($res == 1) {
    $errors{msg} = "The service attribute specification was deleted.";
    $errors{type} = 'OK';
    if ($scope =~ /^(service|service_membership)$/) {
      $q->param('id',$type);
      CMU::WebInt::svc_type_view($q, \%errors);
    } else {
      CMU::WebInt::attr_spec_list($q, \%errors);
    }
  }else{
    $errors{msg} = "Error while deleting attribute specification: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"                                                                                  if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{type} = 'ERR';
    $errors{loc} = 'attr_spec_del_conf';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    CMU::WebInt::attr_spec_view($q, \%errors);
  }
}

sub svc_cb_attr_del {
  my ($url, $row, $edata) = @_;
  return "Operations" if (!ref $row);
  my $id = $row->[$attr_pos{'attribute.id'}];
  my $version = $row->[$attr_pos{'attribute.version'}];
  return "<a href=\"".CMU::WebInt::encURL("$url?op=attr_del&sid=$edata&id=$id&version=$version")."\">Delete</a>";
}

sub attr_del {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $id, $version, %errors) = @_;
  
  $id = CMU::WebInt::gParam($q, 'id');
  $version = CMU::WebInt::gParam($q, 'version');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};

  my $fields;
  ($res, $fields) = CMU::Netdb::delete_attribute($dbh, $user, $id, $version);

  $dbh->disconnect;
  my $back = CMU::WebInt::gParam($q, 'back');
  my $owner = CMU::WebInt::gParam($q, 'owner_tid');
  if ($res == 1) {
    $errors{msg} = "The attribute was deleted.";
    if ($back eq 'auth_userinfo') {
      $q->param('uid', $owner);
      $q->param('u', $owner);
      CMU::WebInt::auth_userinfo($q, \%errors);
    } elsif ($back eq 'auth_grp_info') {
      $q->param('g', $owner);
      CMU::WebInt::auth_groupinfo($q, \%errors);
    } elsif ($back eq 'vlans_view') {
      $q->param('vid', $owner);
      CMU::WebInt::vlans_view($q, \%errors);
    } elsif ($back eq 'subnets_view') {
      $q->param('sid', $owner);
      CMU::WebInt::subnets_view($q, \%errors);
    } elsif ($back eq 'outlet_view') {
      $q->param('oid', $owner);
      CMU::WebInt::outlets_info($q, \%errors);
    } elsif ($back eq 'machine_view') {
      $q->param('id', $owner);
      CMU::WebInt::mach_view($q, \%errors);
    }else{
      CMU::WebInt::svc_view($q, \%errors);
    }
  }else{
    $errors{msg} = "Error while deleting attribute: ".$errmeanings{$res};
    $errors{msg} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"                                                                                  if ($CMU::Netdb::errcodes{EDB} == $res);
    $errors{msg} .= " [Fields: ".join(', ', @$fields)."] ";
    $errors{type} = 'ERR';
    $errors{loc} = 'attr_del';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
    if ($back eq 'auth_userinfo') {
      $q->param('uid', $owner);
      $q->param('u', $owner);
      CMU::WebInt::auth_userinfo($q, \%errors);
    } elsif ($back eq 'vlans_view') {
      $q->param('vid', $owner);
      CMU::WebInt::vlans_view($q, \%errors);
    } elsif ($back eq 'subnets_view') {
      $q->param('sid', $owner);
      CMU::WebInt::subnets_view($q, \%errors);
    } elsif ($back eq 'outlet') {
      CMU::WebInt::outlet_info($q, \%errors);
    } elsif ($back eq 'machine') {
      CMU::WebInt::mach_info($q, \%errors);
    } else {
      CMU::WebInt::svc_view($q, \%errors);
    }
      
  }
}

## Given the table and ID (row in table), return 
## the op code and parameters to view the member table information
sub service_mem_view_url {
  my ($Table, $Id) = @_;

  if ($Table eq 'activation_queue') {
    return "op=oact_aq_view&id=$Id";
  }elsif($Table eq 'building') {
    return "op=build_view&id=$Id";
  }elsif($Table eq 'cable') {
    return "op=cable&id=$Id";
  }elsif($Table eq 'dns_zone') {
    return "op=zone_info&id=$Id";
  }elsif($Table eq 'groups') {
    return "op=auth_grp_info&g=$Id";
  }elsif($Table eq 'machine') {
    return "op=mach_view&id=$Id";
  }elsif($Table eq 'outlet') {

  }elsif($Table eq 'outlet_type') {

  }elsif($Table eq 'service') {
    return "op=svc_info&sid=$Id";
  }elsif($Table eq 'subnet') {
    return "op=sub_info&sid=$Id";
  }elsif($Table eq 'subnet_share') {
    return "op=viewshare&id=$Id";
  }elsif($Table eq 'trunk_set') {
    return "op=trunkset_info&tid=$Id";
  }elsif($Table eq 'vlan') {
    return "op=vlan_info&vid=$Id";
  }elsif($Table eq 'users') {
    return "op=auth_user_info&u=$Id";
  }

  return '';
}
  
sub service_mem_printable {
  my ($id, $rMemRow, $rMemSum, $rMemData) = @_;

  return "Service Membership ID $id" if (!defined $rMemRow->{$id});
  my $Table = $rMemRow->{$id}->{'service_membership.member_type'};
  
  my $DataKey = $Table.':'.$rMemRow->{$id}->{'service_membership.member_tid'};
  
  my $Txt;
  if ($Table eq 'activation_queue') {
    $Txt .= "Activation Queue \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'building') {
    $Txt .= "Building \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'cable') {
    $Txt .= "Cable ".$rMemData->{$DataKey}->{"$Table.label_from"}."/".
      $rMemData->{$DataKey}->{"$Table.label_to"};
  }elsif($Table eq 'dns_zone') {
    $Txt .= "Zone \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'groups') {
    $Txt .= "Group \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'machine') {
    $Txt .= "Machine \'".$rMemData->{$DataKey}->{"$Table.host_name"}."\'";
  }elsif($Table eq 'outlet') {
    $Txt .= "Outlet On \'".$rMemData->{$DataKey}->{"$Table.device"}.":".
      $rMemData->{$DataKey}->{"$Table.port"};
  }elsif($Table eq 'outlet_type') {
    $Txt .= "Outlet Type \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'service') {
    $Txt .= "Service \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'subnet') {
    $Txt .= "Subnet \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'subnet_share') {
    $Txt .= "Subnet Share \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'vlan') {
    $Txt .= "VLAN \'".$rMemData->{$DataKey}->{"$Table.name"}."\'";
  }elsif($Table eq 'users') {
    $Txt .= "User \'".$rMemData->{$DataKey}->{"$Table.description"}."\'";
  }else{
    $Txt .= "$Table ID ".$rMemData->{$DataKey}->{"$Table.id"};
  }
  
  $Txt .= " in Service \'".$rMemRow->{$id}->{'service.name'}."\'";
  return $Txt;
}


sub attr_spec_list {
  my ($q, $errors) = @_;
  my ($dbh, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('attr_spec');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Attribute Types", $errors);
  &CMU::WebInt::title("Attribute Types");

  $url = $ENV{SCRIPT_NAME};

  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::subHeading("Attribute Types", CMU::WebInt::pageHelpLink(''));

  print CMU::WebInt::smallRight("[<b><a href=$url?op=attr_spec_add_form_full>Add Attribute Type</a></b>] \n");

  my $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'attribute_spec.name' if ($sort eq '');
  
  my $res = attr_spec_print($user, $dbh, $q,  
			    " attribute_spec.scope NOT IN ('service_membership', 'service') "
			    . CMU::Netdb::verify_orderby($sort), '',
			    $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'attr_spec_list');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print &CMU::WebInt::stdftr($q);
  
}

# attr_spec_print
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the WHERE clause
#   - parameters to count WHERE
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
#   - lmach
sub attr_spec_print {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = (CMU::WebInt::gParam($q, $skey) eq '') ? 0 : CMU::WebInt::gParam($q, $skey);

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'attribute_spec', $cwhere);

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
  $ruRef = CMU::Netdb::list_attribute_spec
    ($dbh, $user, " $where ".CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with CMU::Netdb::list_attribute_spec: ".$errmeanings{$ruRef};
    return 0;
  }

  my %attr_pos = %{CMU::Netdb::makemap($ruRef->[0])};

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
			      ['attribute_spec.name', 'attribute_spec.scope', 'attribute_spec.format'], 
			      [], '', 'attr_spec_list', 'op=attr_spec_view&id=',
			      \%attr_pos, \%CMU::Netdb::structure::attribute_spec_printable,
			      'attribute_spec.name', 'attribute_spec.id', 'sort',
			      ['attribute_spec.name', 'attribute_spec.scope', '']);
  return 1;
}



1;
