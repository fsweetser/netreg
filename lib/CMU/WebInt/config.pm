#   -*- perl -*-
#
# CMU::WebInt::config
#  This module should be the ONLY one in WebInt that has site-specific content.
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
# $Id: config.pm,v 1.18 2008/03/27 19:42:37 vitroth Exp $
#
# $Log: config.pm,v $
# Revision 1.18  2008/03/27 19:42:37  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.17.14.1  2007/10/11 20:59:42  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.17.12.1  2007/09/20 18:43:05  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.17  2004/09/13 20:14:28  ktrivedi
# separate telnet/ssh login/enable
#
# Revision 1.16  2004/03/25 20:14:25  kevinm
# * Merging netdb-layer2-branch2
#
# Revision 1.15.2.1  2004/02/25 19:37:48  kevinm
# * Merging config/layer2
#
# Revision 1.15  2004/02/20 03:12:22  kevinm
# * External config file updates
#
# Revision 1.14  2003/11/13 20:26:23  kevinm
# * Comment update
#
# Revision 1.13.2.2  2003/12/31 05:18:56  ktrivedi
# Added variable for portadmin.pm
#
# Revision 1.13.2.1  2003/11/29 06:27:45  ktrivedi
# NR-VALN support
#
# Revision 1.13  2002/08/23 01:37:22  kevinm
# * Minor fix to the netreg db params
#
# Revision 1.12  2002/08/22 17:06:27  kevinm
# * Changes for netreg-install
#
# Revision 1.11  2002/08/20 18:15:18  kevinm
# * [Bug 1356] Enable/disable buildings, networks, and department control from
#   the config file
#
# Revision 1.10  2002/08/19 20:56:01  kevinm
# * More text for logout
#
# Revision 1.9  2002/08/19 20:09:56  kevinm
# * Rearranged a few vars, added more..
#
# Revision 1.8  2002/08/19 19:45:30  kevinm
# * Added LOGOUT_URL option
#
# Revision 1.7  2002/07/30 21:40:04  kevinm
# * Added quickreg module flag
#
# Revision 1.6  2002/07/18 16:07:31  kevinm
# * Added quickreg method of checking for MAC address registration
#
# Revision 1.5  2002/06/28 15:32:49  kevinm
# * SSL_CLIENT_EMAIL existing doesn't clear the realm
#
# Revision 1.4  2002/06/27 18:57:55  kevinm
# * SSL client cert support
#
# Revision 1.3  2002/06/18 17:31:25  ebardsle
# Ghetto WebISO support hack.
#
# Revision 1.2  2002/03/18 22:10:43  kevinm
# * Beginning to phase out old DNS config area; added parameter
#
# Revision 1.1  2002/01/03 20:55:08  kevinm
# Initial checking of general WebInt configuration file.
#
#

package CMU::WebInt::config;
use strict;
use vars qw/@ISA @EXPORT @EXPORT_OK 
	    $NetReg_Web_DB @SuperUsers $LocalRealm
            $DEF_ITEMS_PER_PAGE $DEF_MAX_PAGES $MACHINES_PER_PAGE
  $SYSTEM_NAME $SYSTEM_MAIN_URL $ADMIN_GROUP $USER_MAIL
  $THCOLOR $HDCOLOR $BGCOLOR $TACOLOR $ENABLE_CABLES_OUTLETS
  $DNS_CONFIG_OLD_METHOD $QUICKREG_METHOD $HAVE_OMAPI_MODULE
  $LOGOUT_URL @COOKIE_DESTROY $LOGOUT_TEXT
  $ENABLE_BUILDINGS $ENABLE_NETWORKS $ENABLE_DEPT_CONTROL
  $ENABLE_QUICKREG $ENABLE_TRUNK_SET $PORTADMIN_LOGIN_TELNET_PASSWD 
  $PORTADMIN_ENABLE_TELNET_PASSWD $PORTADMIN_LOGIN_SSH_PASSWD $PORTADMIN_ENABLE_SSH_PASSWD/;

require CMU::Netdb::config;
require Exporter;
@ISA = qw(Exporter);

# Do not allow any blank lines in here!
@EXPORT = qw/$NetReg_Web_DB @SuperUsers $LocalRealm
  $DEF_ITEMS_PER_PAGE $DEF_MAX_PAGES $MACHINES_PER_PAGE
  $SYSTEM_NAME $SYSTEM_MAIN_URL $ADMIN_GROUP $USER_MAIL
  $THCOLOR $HDCOLOR $BGCOLOR $TACOLOR $ENABLE_CABLES_OUTLETS
  $DNS_CONFIG_OLD_METHOD $QUICKREG_METHOD $HAVE_OMAPI_MODULE
  $LOGOUT_URL @COOKIE_DESTROY $LOGOUT_TEXT
  $ENABLE_BUILDINGS $ENABLE_NETWORKS $ENABLE_DEPT_CONTROL
  $ENABLE_QUICKREG $ENABLE_TRUNK_SET $PORTADMIN_LOGIN_TELNET_PASSWD $PORTADMIN_ENABLE_TELNET_PASSWD
  $PORTADMIN_LOGIN_SSH_PASSWD $PORTADMIN_ENABLE_SSH_PASSWD/;

# Do not allow any blank lines in here!
my @BASIC_VARS = qw/$LOGOUT_URL $LOGOUT_TEXT @SuperUsers $LocalRealm
  $USER_MAIL $SYSTEM_MAIN_URL $ADMIN_GROUP $ENABLE_QUICKREG/;

## ****** NOTE ********************************************************
## See doc/manual/index.html for a guide to configuring this file
## beyond the basic descriptions offered here.
## ********************************************************************

## ****** WARNING ***** WARNING ***** WARNING ***** WARNING ***********
## The structure of this file must be carefully maintained so that the 
## netreg-install.pl script can properly parse the contents and allow
## speedy configuration.
## * All configurable variables must be listed in @EXPORT.
## * Basic variables must be listed in @BASIC_VARS
## * Each variable must begin with a comment. The comment must have
##   a hash mark in the first text column, followed by --VARIABLE_NAME.
## * All text after the variable name, including additional comments,
##   will be included in the variable description in netreg-install.pl
## * The variable must immediately follow comments (no blank spaces)
##   and begin in the first text column. If the variable extends across
##   multiple lines, there should be no blank lines. A blank line
##   should separate all variables and comments.
## ********************************************************************

## ###################### File Header #################################
## --BEGIN HEADER--
## This file configures WebInt, the web interface for NetReg.
## --END HEADER--


############################ Web Settings #############################
# --LOGOUT_URL This is presented to the user on the logout screen as a link
# to follow to complete logging out (of a campus-wide web auth system, for
# example). Blank will supress logout text from being displayed.
$LOGOUT_URL = "https://webiso.andrew.cmu.edu/logout.cgi";

# --LOGOUT_TEXT This text is presented with LOGOUT_URL in nc.pl (the
# logout CGI)
$LOGOUT_TEXT = "<b><font size=+1>Notice:</font></b> If you are done using ".
  "authenticated web services, you should visit the ".
  "<a href=\"$LOGOUT_URL\">WebISO Logout</a> ".
  "page. Your browser may automatically refresh to this page in one minute.";

# --COOKIE_DESTROY is a list of cookies that are used to authenticate the
# user (your local web authentication system might use particular cookie
# names. These cookies are destroyed by the NetReg first page (index.pl)
# and the logout (nc.pl).
# ** You should include 'authuser' in this list, since it's a special
#    cookie used by administrators when acting as another user. **
# The format is CookieName@Domain. All paths are set to '/'
# If domain is not specified, no domain is passed to CGI.pm, which means
# it will use the local hostname.
@COOKIE_DESTROY = qw/authuser KWEB pubcookie_s_mysql3 pubcookie_s_netreg
  pubcookie_s__bin_ pubcookie_pre_s/;

############################ User Settings ############################
# --SuperUsers The SuperUsers will always be granted access to the system,
# even if the DB_OFFLINE key is set in the _sys_info table. Additionally,
# SuperUsers are the only ones allowed to assume another identity for
# purposes of interacting with the system (useful for testing, etc.)
@SuperUsers = qw/fk03 kevinm rjy vitroth ktrivedi/;

# --LocalRealm The REMOTE_USER environment variable will be fetched to 
# determine the users identity. In some environments, the REMOTE_USER
# variable is set to user@REALM, so the realm here is stripped in
# getUserInfo (and thus in the DB). Users that do NOT match the LocalRealm
# will not have the realm information stripped, so they would need
# a "user@realm" entry in the users table for access.
# Set this to '' if there is no REALM in use.
$LocalRealm = 'ANDREW.CMU.EDU';

# Kludge to work with both KWeb and WebISO on various machines.
# MOD_PUBCOOKIE is set in httpd.conf on WebISO machines.
# And further kludges to deal with client certs
if (defined $ENV{'MOD_PUBCOOKIE'} && !defined $ENV{'SSL_CLIENT_S_DN_CN'} &&
    !defined $ENV{'SSL_CLIENT_EMAIL'}) {
  $LocalRealm = '';
}

#######################################################################

############################ DB/Passwords #############################
# --NetReg_Web_DB This is the web interface's information used in
# making the connection to the backend database.
# The format here is Driver, Username, Password. Password may be
# specified as 'file=/path/to/file', and /path/to/file will be read
# to obtain the password. Note that this file should not contain 
# a newline, so you might want to update the contents as:
# perl -e 'print "mynewpassword"' > /path/to/file
# Remember to chown() the password to the user that the web server
# runs as.
# Otherwise, just put the password here.
# For the driver info, 'man DBI'
$NetReg_Web_DB = ['DBI:mysql:netdb:localhost', 'netreg-web', 
		  'file=/home/netreg/etc/.password'];

#######################################################################

########################### Paging Criteria ###########################
# --DEF_ITEMS_PER_PAGE On most screens NetReg will try to paginate the 
# displays - ie show you only a subset of the entire dataset (limited to 
# some number of rows). You can control the parameters of that paging here.
# DEF_ITEMS_PER_PAGE is the default number of items per page to display.
$DEF_ITEMS_PER_PAGE = 40;

# --DEF_MAX_PAGES We provide direct links to a number of the pages, 
# while any that exceed this number you can get to only by visiting a 
# page closer in sequence to the target page
$DEF_MAX_PAGES = 15;

# --MACHINES_PER_PAGE We limit the display of machines on the main 
# screen of NetReg, since there are also outlets on the page (if you
# enable the cable/outlet features. Both machines and outlets on the
# main page are limited to this number.
$MACHINES_PER_PAGE = 20;

#######################################################################

####################### User Interface Considerations #################
# --BGCOLOR The backgroudn color for all the pages.
$BGCOLOR = 'white';

# --THCOLOR The color for table headings.
$THCOLOR = 'lightyellow';

# --HDCOLOR The color for major subheadings.
$HDCOLOR = '#c6d4ff';

# --TACOLOR The color for alternating lines in lists.
$TACOLOR = '#c0f7de';

# Other colors: green: #a3ffa3 or #c0f7de; purple: #f6ccf9
#######################################################################

####################### NetReg Text Considerations ####################
# These variables affect the text that is presented to users at
# various locations. Most help text regarding individual values is
# in WebInt/vars.pm.
#

# --USER_MAIL This is the email address that users should send email if they
# have questions, etc. -- You probably don't want this to be the
# same email address that the system will send error reports 
# (in Netdb/config.pm)
$USER_MAIL = 'advisor@andrew.cmu.edu';

# --SYSTEM_NAME This should be the (friendly) name of your system.
$SYSTEM_NAME = 'Network Registration System';

# --SYSTEM_MAIN_URL The main URL for your system, as you would want 
# users to see
$SYSTEM_MAIN_URL = 'http://netreg.net.cmu.edu';

# --ADMIN_GROUP Administrative group - To identify the group responsible for 
# running the system
$ADMIN_GROUP = 'Carnegie Mellon Network Development';

# --ENABLE_CABLES_OUTLETS If you want to use the cable/outlet interface, 
# set this to '1'. '0' is recommended unless you are interested in 
# development/have read the manual
$ENABLE_CABLES_OUTLETS = '1';

# --ENABLE_BUILDINGS If you want to have the buildings section 
# (allowing users to find a subnet by building), set this to '1'.
$ENABLE_BUILDINGS = '1';

# --ENABLE_NETWORKS If you want to have 'networks' (just friendly names 
# for subnets) set this to '1'.
$ENABLE_NETWORKS = '1';

# --ENABLE_TRUNK_SET If you want to have 'trunk_set' (combining vlans
# in trunk-set and having multiple trunk-set/bldg) set this to '1'.
$ENABLE_TRUNK_SET = '1';

# --ENABLE_DEPT_CONTROL If you want to have the "Department Control" 
# section (allow members of dept: groups some control over zone and 
# subnet permissions, set this to '1'.
$ENABLE_DEPT_CONTROL = '1';

# --DNS_CONFIG_OLD_METHOD If you are not yet using the service group 
# DNS configuration method, set this to '1'. New NetReg users should
# leave this value as '0'.
$DNS_CONFIG_OLD_METHOD = '0';

#
#
$PORTADMIN_LOGIN_TELNET_PASSWD = "/home/netreg/etc/.sw_login_telnet_passwd";

#
#
$PORTADMIN_ENABLE_TELNET_PASSWD = "/home/netreg/etc/.sw_enable_telnet_passwd";

#
#
$PORTADMIN_LOGIN_SSH_PASSWD = "/home/netreg/etc/.sw_login_ssh_passwd";

#
#
$PORTADMIN_ENABLE_SSH_PASSWD = "/home/netreg/etc/.sw_enable_ssh_passwd";

#######################################################################

#################### QuickReg Configuration ###########################
# This affects the QuickRegistration feature.

# --ENABLE_QUICKREG QuickReg is a feature of NetReg that enables users
# to connect to the network, get a non-global IP address, and be directed
# into the registration system. The system detects that they are coming
# from this special "registration" IP space, finds their MAC address,
# and makes the registration process extremely simple.
$ENABLE_QUICKREG = 0;

# --QUICKREG_METHOD can be either 'no_regs' or 'machine_unreg'. If 
# no_regs, users get passed to the quickreg machine registration if
# they have NO machine registrations whatsoever. In 'machine_unreg', 
# they are passed if the machine they're connecting from is 
# unregistered. (In both cases they need to be on a subnet with the
# prereg_subnet flag defined.)
$QUICKREG_METHOD = 'machine_unreg';

# --HAVE_OMAPI_MODULE If you have the OMAPI::DHCP modules, set this
# to '1'. For now the modules can be obtained from
# http://www.net.cmu.edu/netreg/omapi.tar.gz
$HAVE_OMAPI_MODULE = 0;


######################################################################

1;

	     
