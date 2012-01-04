#!/usr/bin/perl -w

#############################################################################
# 5/22/2000
# Vincent Furia <vmf@andrew.cmu.edu>
# Carnegie Mellon Network Developement
#
# This program is designed to grab users from the CMU LDAP server and ensure 
# their existence in the the netdb database.  Logs any users that are created 
# in this manner and checks for "lost" user id's (ones that have disappeared 
# from the LDAP server)
#
#
# Copyright (c) 2000-2002 Carnegie Mellon University. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. The name "Carnegie Mellon University" must not be used to endorse or
#    promote products derived from this software without prior written
#    permission. For permission or any legal details, please contact:
#      Office of Technology Transfer
#      Carnegie Mellon University
#      5000 Forbes Avenue
#      Pittsburgh, PA 15213-3890
#      (412) 268-4387, fax: (412) 268-7395
#      tech-transfer@andrew.cmu.edu
#
# 4. Redistributions of any form whatsoever must retain the following
#    acknowledgment: "This product includes software developed by Computing
#    Services at Carnegie Mellon University (http://www.cmu.edu/computing/)."
#
# CARNEGIE MELLON UNIVERSITY DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
# SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS,
# IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY BE LIABLE FOR ANY SPECIAL,
# INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
# OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
#
# $Log: user_sync.pl,v $
# Revision 1.10  2008/03/27 19:42:44  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.9.14.1  2007/10/11 20:59:47  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.9.12.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.7  2002/01/30 20:55:45  kevinm
# Fixed vars_l
#
# Revision 1.6  2001/10/08 14:20:00  kevinm
# Not verified to work, committing so that I don't lose it.
#
# Revision 1.5  2001/07/20 22:22:26  kevinm
# Copyright info
#
# Revision 1.4  2000/08/16 03:24:23  kevinm
# * added user_sync to the scheduled runs
#
# Revision 1.3  2000/08/14 05:22:13  kevinm
# *** empty log message ***
#
# Revision 1.2  2000/07/10 14:47:27  kevinm
# Updated loading scripts. cnames/mx/ns works now
#
# Revision 1.1  2000/06/20 17:52:07  kevinm
# Moved over from lib
#
# Revision 1.3  2000/06/08 22:34:49  kevinm
# minor changes
#
# Revision 1.2  2000/05/30 18:23:48  kevinm
# Made a number of changes to use the perl-ldap libraries. This should now
# be functional (and use the netdb stuff).
#
#
##############################################################################

#use strict;
BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use $vars_l::NRLIB;
use lib "/usr/ng/lib/perl5";

use DBI;
use CMU::Netdb;
use CMU::Netdb::auth;
use CMU::Netdb::helper;


# Note: This script is a proof of concept for loading users into NetReg from an
# LDAP directory. To use, uncomment the following line and scan for localized
# configuration settings.
#use Net::LDAP;

my $console = 0;
if ($ARGV[0] && $ARGV[0] eq '-console') {
  $console = 1;
} 

my $logfile = "/home/netreg/logs/user_sync-$$.log"; # eww. should fix. -kevinm
my $date = localtime; 

my $dbh;
if (!$console) {
  open(LOGFILE,">>$logfile") || die "unable to open $logfile for append";
  print LOGFILE "$date: user_sync started";

  $dbh = lw_db_connect();
  if (!$dbh) {
    &admin_mail('user_sync.pl', 'Unable to connect to database.');
    die "Unable to connect to database.\n";
  }

  getLock($dbh, 'USERSYNC_LOCK', 'user_sync.pl', 60);
}

###############################################################################
##Needed to connect to (and search) the LDAP server
my $server = "netreg-ldap.andrew.cmu.edu";
my $srch = "(uid=*)";
my @params = ("uid","cn");              

print "Connecting to LDAP server: $server...\n";
my $ldap = Net::LDAP->new($server);
if (!$ldap) {
  killLock($dbh, 'USERSYNC_LOCK') if (!$console);
  die "$@";
}
print "Connected.\nProceeding with search (search: $srch)\n";
my @attrs = ('cn', 'uid');
my $mesg = LDAPsearch($ldap, $srch, \@attrs); # base is default

print "Search completed. Processing DNs...\n";
my %l_users;
my $href = $mesg->as_struct;
my @arrayofDNs = keys %$href;
foreach(@arrayofDNs) {
  my $valref = $$href{$_};
  my ($cn, $uid) = (@$valref{'cn'}, @$valref{'uid'});
  my ($k, $v) = (@$uid, @$cn);

  print "$k: $v\n";
  $l_users{$k} = $v;
}

print "Found $#arrayofDNs users\n";
$ldap->unbind;

exit(0) if ($console);

#get the list of all users currently in the db
my $ref = CMU::Netdb::auth::list_users($dbh,'netreg', ''); # bleh
my @user_list = @{$ref};

#throw all those users into a hash key=user.name value=user.comment
my %db_users;
my $i = 0;

while($user_list[$i]) {
  my @user = @{$user_list[$i]};
  $db_users{$user[1]} = $user[3];

  $i++;
}

#this compares the two hashes to see what is missing from where.  When finished, %l_users
#contains all the users we have to add to the db, while %e_users contains people who are in
#the db but not in the LDAP (which shouldn't happen) and will be logged somehow.
my %e_users; 
foreach my $key (keys %db_users) {
  if ($l_users{$key}) {
    delete $l_users{$key};
  } else {
    $e_users{$key} = $db_users{$key};
  }
}

#for each user in the LDAP hash that is left after removing those already in the db (above),
#we call the add_user with the user.name and user.comment and throw it into the db
my %user_info;
foreach $key (keys %l_users) {
  $user_info{"name"} = $key;
  $user_info{"description"} = $l_users{"$key"};
  $i = CMU::Netdb::add_user($dbh,'netreg',\%user_info) || warn "error in add_user";
  print LOGFILE "- user added:  name=$key, comment=$l_users{\"$key\"}\n";
}

#print errors to logfile...
foreach $key (keys %e_users) {
  print LOGFILE "- ERROR: user missing from LDAP server...  name=$key, comment=$e_users{\"$key\"}\n";
}

close LOGFILE;
killLock($dbh, 'USERSYNC_LOCK');
$dbh->disconnect;

sub LDAPsearch {
  my ($ldap, $searchString, $attrs, $base) = @_;

#  $base = "ou=Andrew, o=Carnegie Mellon University" if (!$base);
  $base = "dc=andrew,dc=cmu,dc=edu" if (!$base);
  
  $attrs = ['cn', 'uid'] if (!$attrs);
  my $result = $ldap->search(base => $base,
			     scope => "sub",
			     filter => $searchString,
			     attrs => $attrs);
}
	
