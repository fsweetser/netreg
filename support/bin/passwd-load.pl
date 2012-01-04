#! /usr/bin/perl
#
# Load users into NetReg via passwd file
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
# $Log: passwd-load.pl,v $
# Revision 1.9  2008/03/27 19:42:43  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.8.14.1  2007/10/11 20:59:46  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.8.12.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.6  2004/07/07 13:45:53  vitroth
# Fixed passwd load script to be case insensitive, and to
# wrap a transaction around a user & credential insertion, so the
# user can be rolled back if the credential insertion fails.
#
# Also added better debugging, and logging of interesting failures
# to the errors bboard.
#
# Revision 1.5  2004/06/24 02:05:40  kevinm
# * Credentials/machine type pulled to head
#
# Revision 1.4.8.1  2004/06/21 15:53:46  vitroth
# Merging credentials & machine type permissions branches.
# Inital merge complete, no testing done yet.
# Still need to update convert script and schema.
#
# Revision 1.4.6.1  2004/06/17 01:08:26  kevinm
# * Changes to deal with credentials
#
# Revision 1.4  2002/08/11 16:26:43  kevinm
# * Extended error reporting
#
# Revision 1.3  2002/01/30 21:12:00  kevinm
# Fixed vars_l
#
# Revision 1.2  2001/08/08 16:30:51  kevinm
# Getting it into mainline
#
#

use lib "/usr/ng/lib/perl5";
use DBI;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;
use CMU::Netdb::auth;
use CMU::Netdb::helper;

use Data::Dumper;

use strict;


my $console = 0;
my $mail_log = "";

if ($ARGV[0] && $ARGV[0] eq '-console') {
  $console = 1;
} 

my $logfile = "/home/netreg/logs/user_sync-$$.log"; # eww. should fix. -kevinm
my $date = localtime; 

my $dbh;
unless ($console) {
  open(LOGFILE,">>$logfile") || die "unable to open $logfile for append";
}

writelog(0,"$date: user_sync started") ;

$dbh = lw_db_connect();
if (!$dbh) {
  &admin_mail('user_sync.pl', 'Unable to connect to database: '.$!);
  die "Unable to connect to database.\n";
}

getLock($dbh, 'USERSYNC_LOCK', 'user_sync.pl', 60);


my %l_users;

open(FILE, "/afs/andrew/common/etc/passwd");
while(<FILE>) {
  my ($uname, $pwd, $uid, $gid, $name, $hdir) = split(/\:/, $_);
  next unless ($hdir =~ /\/afs\/andrew/);

  # kevinm - hacks for now
  next if ($uname eq 'netreg');
  $uname .= '@ANDREW.CMU.EDU';

  $l_users{lc($uname)} = $name;
}
close(FILE);

writelog(0,"Loaded ".scalar(keys(%l_users))." users from passwd file.\n");

  
#get the list of all users currently in the db
my $ref = CMU::Netdb::auth::list_users($dbh,'netreg', ''); # bleh
my %upos = %{CMU::Netdb::makemap($ref->[0])};
my @user_list = @{$ref};


#throw all those users into a hash key=user.name value=user.comment
my %db_users;

foreach my $user (@user_list) {
  my ($name, $desc) = ($user->[$upos{'credentials.authid'}],
		       $user->[$upos{'credentials.description'}]);
  # kevinm - hack for now. eventually this entire script should be replaced
  # by something that does ldap, like the good old days.
  next unless ($name =~ /\@andrew\.cmu\.edu$/i);
  $db_users{lc($name)} = $desc;
}

writelog(0,"Loaded ".scalar(keys(%db_users))." users from database.\n");

#this compares the two hashes to see what is missing from where.  When finished, %l_users
#contains all the users we have to add to the db, while %e_users contains people who are in
#the db but not in the LDAP (which shouldn't happen) and will be logged somehow.

# %c_users are users that we need to change
my %c_users;
my %e_users;
foreach my $key (keys %db_users) {
  if (defined $l_users{$key}) {
    if ($l_users{$key} ne $db_users{$key}) {
      $c_users{$key} = $l_users{$key};
    }
    delete $l_users{$key};
  } else {
    $e_users{$key} = $db_users{$key};
  }
}

writelog(0,"Found ".scalar(keys(%l_users))." users from passwd not in the db.\n");

#for each user in the LDAP hash that is left after removing those already in the db (above),
#we call the add_user with the user.name and user.comment and throw it into the db
my %user_info;
foreach my $key (keys %l_users) {
  # start a transaction
  my ($xtres, $xtref) = CMU::Netdb::xaction_begin($dbh);
  my $in_transaction = 0;
  if ($xtres <= 0) {
    writelog(1,"- error beginning transaction: $xtres\n");
  } else {
    $in_transaction = 1;
  }
  # Add a user record
  my ($res, $ret) = CMU::Netdb::add_user($dbh, 'netreg', {'flags' => '',
							  'comment' => ''});
  if ($res != 1) {
    writelog(1,"- error adding new user: $res [".join(', ',@$ret)."]\n");
    CMU::Netdb::xaction_rollback($dbh) if ($in_transaction);
    next;
  }

  my $II = $ret->{'insertID'};
  if ($II eq '') {
    writelog(1,"- error getting insert ID from new user: $res $II");
    CMU::Netdb::xaction_rollback($dbh) if ($in_transaction);
    next;
  }

  my %fields = ('user' => $II,
		'authid' => $key,
		'description' => $l_users{$key});
  my %$fcopy = %fields;

  ($res, $ret) = CMU::Netdb::add_credentials($dbh, 'netreg', \%fields);

  if ($res != 1) {
    writelog(1,"- error adding credential $key to user $II: $res [".join(', ',@$ret)."]: \n".
      Data::Dumper->Dump([$fcopy],['fields'])."\n");
    CMU::Netdb::xaction_rollback($dbh) if ($in_transaction);
    next;
  }
  writelog(0,"- user added:  name=$key, description=".$l_users{$key}."\n");
  CMU::Netdb::xaction_commit($dbh);
}

# changes
foreach my $key (keys %c_users) {
  # Get the current credential information
  my $cinfo = CMU::Netdb::list_credentials($dbh, 'netreg',
					   "authid = '$key'");
  if (!ref $cinfo || scalar(@$cinfo) != 2) {
    writelog(1,"- error listing credential $key (changing): \n".
	     Data::Dumper->Dump([$cinfo],['result'])."\n");
    next;
  }

  my %cpos = %{CMU::Netdb::makemap($cinfo->[0])};
  my %fields = map { my $a = $_;
		     $a =~ s/^credentials\.//;
		     ($a, $cinfo->[1]->[$cpos{$_}]); } keys %cpos;
  my $ID = $cinfo->[1]->[$cpos{'credentials.id'}];
  my $V = $cinfo->[1]->[$cpos{'credentials.version'}];

  # Change the name
  $fields{'description'} = $c_users{$key};

  my %$fcopy = %fields;
  my ($res, $ref) = CMU::Netdb::modify_credentials($dbh, 'netreg', $ID, $V,
						   \%fields);
  if ($res != 1) {
    writelog(1,"- error updating credentials for $key to $c_users{$key}: \n".
	     Data::Dumper->Dump([$fcopy],['fields'])."\n");
    next;
  }
  writelog(0,"- success updating credentials for $key to $c_users{$key}\n");
}

writelog(0,"- ERROR: ".scalar(keys(%e_users))." users missing from passwd file.\n");


if (!$console) {
  close LOGFILE;
  if ($mail_log) {
    netdb_mail("passwd-load.pl", $mail_log, "Error in passwd-load.pl");
  }
}

killLock($dbh, 'USERSYNC_LOCK');
$dbh->disconnect;



sub writelog {
  my ($level, $mesg) = @_;

  if ($console) {
    warn $mesg;
  } else {
    if ($level > 0) {
      $mail_log .= $mesg;
    }
    print LOGFILE $mesg
  }
}
