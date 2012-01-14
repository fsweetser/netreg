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

use strict;
use warnings;
use Carp;
use DBI;
use English;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

my $user_home = '\/home\/';
my $passwd = "/etc/passwd";
use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;
use CMU::Netdb::auth;
use CMU::Netdb::helper;

use Data::Dumper;

my $console = 0;
my $mail_log = "";

if ($ARGV[0] && $ARGV[0] eq '-console') {
  $console = 1;
} 

my $logfile = "$NRHOME/logs/passwd-load-$$.log";
my $date = localtime; 

my $dbh;
my $LOG;
unless ($console) {
  open $LOG, '>>', $logfile 
	or croak "unable to open $logfile for append";
}

writelog(0,"$date: user_sync started") ;

$dbh = lw_db_connect();
if (!$dbh) {
  &admin_mail('user_sync.pl', 'Unable to connect to database: '.$!);
  die "Unable to connect to database.\n";
}

getLock($dbh, 'USERSYNC_LOCK', 'user_sync.pl', 60);


# p_users is the hash of users from passwd file
my %p_users;

open my $PASS_FILE, '<', $passwd 
	or croak "Can't open '$passwd': $OS_ERROR";
while(<$PASS_FILE>) {
  my ($uname, $pwd, $uid, $gid, $name, $hdir) = split(/\:/, $_);
  next unless ($hdir =~ /$user_home/);

  # kevinm - hacks for now
  next if ($uname eq 'netreg');

  $p_users{lc($uname)} = $name;
}
close($PASS_FILE);

writelog(0,"Loaded ".scalar(keys(%p_users))." users from passwd file.\n");

  
#get the list of all users currently in the db
my $lu_ref = CMU::Netdb::auth::list_users($dbh,'netreg', ''); # bleh
my %upos = %{CMU::Netdb::makemap($lu_ref->[0])};
my @user_list = @{$lu_ref};


#throw all those users into a hash key=user.name value=user.comment
my %db_users;

foreach my $user (@user_list) {
  my ($name, $desc) = ($user->[$upos{'credentials.authid'}],
		       $user->[$upos{'credentials.description'}]);
  $db_users{lc($name)} = $desc;
}

writelog(0,"Loaded ".scalar(keys(%db_users))." users from database.\n");

#this compares the two hashes to see what is missing from where.  When finished, %c_users
#contains all the users we have to add to the db, while %e_users contains people who are in
#the db but not in the passwd file and will be logged somehow.

# %c_users are users that we need to change
my %c_users;
# %e_users are the users that are in the database, but not in the passwd file
my %e_users;
foreach my $db_name (keys %db_users) {
  if (defined $p_users{$db_name}) {
    if ($p_users{$db_name} ne $db_users{$db_name}) {
      $c_users{$db_name} = $p_users{$db_name};
    }
    delete $p_users{$db_name};
  } else {
    $e_users{$db_name} = $db_users{$db_name};
  }
}

writelog(0,"Found ".scalar(keys(%p_users))." users from passwd not in the db.\n");

#for each user in the passwd hash that is left after removing those already in the db (above),
#we call the add_user with the user.name and user.comment and throw it into the db
foreach my $passwd_name (keys %p_users) {
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
		'authid' => $passwd_name,
		'description' => $p_users{$passwd_name});
  my $fcopy = \%fields;

  ($res, $ret) = CMU::Netdb::add_credentials($dbh, 'netreg', \%fields);

  if ($res != 1) {
    writelog(1,"- error adding credential $passwd_name to user $II: $res [".join(', ',@$ret)."]: \n".
      Data::Dumper->Dump([$fcopy],['fields'])."\n");
    CMU::Netdb::xaction_rollback($dbh) if ($in_transaction);
    next;
  }
  writelog(0,"- user added:  name=$passwd_name, description=".$p_users{$passwd_name}."\n");
  CMU::Netdb::xaction_commit($dbh);
}

# changes
foreach my $cred_name (keys %c_users) {
  # Get the current credential information
  my $cinfo = CMU::Netdb::list_credentials($dbh, 'netreg',
					   "authid = '$cred_name'");
  if (!ref $cinfo || scalar(@$cinfo) != 2) {
    writelog(1,"- error listing credential $cred_name (changing): \n".
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
  $fields{'description'} = $c_users{$cred_name};

  my $fcopy = \%fields;
  my ($res, $mc_ref) = CMU::Netdb::modify_credentials($dbh, 'netreg', $ID, $V,
						   \%fields);
  if ($res != 1) {
    writelog(1,"- error updating credentials for $cred_name to $c_users{$cred_name}: \n".
	     Data::Dumper->Dump([$fcopy],['fields'])."\n");
    next;
  }
  writelog(0,"- success updating credentials for $cred_name to $c_users{$cred_name}\n");
}

writelog(0,"- ERROR: ".scalar(keys(%e_users))." users missing from passwd file.\n");


if (!$console) {
  close $LOG;
  if ($mail_log) {
    netdb_mail("passwd-load.pl", $mail_log, "Error in passwd-load.pl");
  }
}

killLock($dbh, 'USERSYNC_LOCK');
$dbh->disconnect;

sub writelog {
  my ($level, $mesg) = @_;

  if ($console) {
    print "$mesg\n";
  } else {
    if ($level > 0) {
      $mail_log .= $mesg;
    }
    print $LOG $mesg
  }
}
