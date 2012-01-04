#! /usr/bin/perl
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
##
## $Id: grloader.pl,v 1.8 2008/03/27 19:42:41 vitroth Exp $
##
## $Log: grloader.pl,v $
## Revision 1.8  2008/03/27 19:42:41  vitroth
## Merging changes from duke merge branch to head, with some minor type corrections
## and some minor feature additions (quick jump links on list pages, and better
## handling of partial range allocations in the subnet map)
##
## Revision 1.7.8.1  2007/10/11 20:59:46  vitroth
## Massive merge of all Duke changes with latest CMU changes, and
## conflict resolution therein.   Should be ready to commit to the cvs HEAD.
##
## Revision 1.7  2005/08/11 13:28:05  fk03
## Cleaned up error in handling deletes
## send only one error mail for each run.
##
## Revision 1.6  2005/08/09 16:40:54  fk03
## Fixed error message to show "real" user causing error in delete.
##
## Revision 1.5  2004/07/06 13:48:57  vitroth
## Updates to match credentials changes.
##
## Revision 1.4  2004/04/01 02:11:18  kevinm
## * exit with code 0 to make previous_run time update
##
## Revision 1.3  2002/09/30 17:27:14  kevinm
## * I hate grloader; I think it's now working though. Need to get it
##   added to the scheduler.
##
## Revision 1.2  2002/04/05 17:41:51  kevinm
## * Fixes to the group loader
##
##

use strict;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::auth;
use CMU::Netdb::errors;
use CMU::Netdb::helper;

$| = 1;

my $DBUSER    = 'netreg';
my $prefix   = 'local:';
my $afs_path  = '/afs/andrew/data/db/netreg-groups';
my $user_file = 'users';

loadGroups();

exit(0);

sub loadGroups {
  my (@groups, $wgr, $lgr);
  my ($dbh, $res, $ref, @dbmembers, @addmembers, $gid);
  my ($errmsgs) = [];
  
  $dbh = lw_db_connect();
  if (!$dbh) {
    &CMU::Netdb::netdb_mail('grloader.pl', 'Error connecting to db.');
    print "group_loader.pl: Error connectiong to db.\n";
    exit -1;
  }
  
  # open directory and traverse it.
  opendir(G_DIR, $afs_path) || die "Can't open directory $afs_path\n"; 
  @groups = grep !/^\./ , readdir G_DIR;
  
  foreach my $gr (@groups) {
    # does the group exist in netreg?
    print "Checking group $gr\n";
    $wgr = $prefix.$gr;
    $lgr = CMU::Netdb::list_groups($dbh, $DBUSER, "groups.name = '$wgr'");
    if (!ref $lgr) {
	push(@$errmsgs,"Error calling list_groups; ".
			     "Name: $wgr ($lgr)");
      next;
    }
    
    if (!defined $lgr->[1]) {
      # Find the title
      my $title = 'AFS Local: $gr';
      if (-e "$afs_path/$gr/title") {
	open(FILE, "$afs_path/$gr/title");
	while(<FILE>) {
	  next if ($_ =~ /^\#/);
	  chomp($_);
	  $title = "AFS Local: $_";
	  close(FILE);
	}
      }
      
      # need to add this group
      ($res, $ref) = CMU::Netdb::add_group
	($dbh, $DBUSER,
	 {'name' => $wgr,
	  'description' => $title});

      if ($res < 1) {
	push(@$errmsgs,"Error adding local group $wgr: ".
			       "$res [".join(',', @$ref)."]");
	next;
      }
      $gid = $ref->{'insertID'};
    }else{
      my $gmap = CMU::Netdb::makemap($lgr->[0]);
      $gid = $lgr->[1]->[0];
    }

    print "GROUP: $gid\n";
    
    # Open 'users' file and read list of members
    # get a list of the members
    
    my $lmgr = CMU::Netdb::list_members_of_group($dbh, $DBUSER, $gid, '');
    if (!ref $lmgr) {
	push(@$errmsgs, "Error listing members of group: $gid".
			     "($lmgr)");
      print STDERR "Error listing members of group: $gid\n";
      next;
    }
    
    my $memmap = CMU::Netdb::makemap($lmgr->[0]);
    shift(@$lmgr);
    my %dbmembers = map { $_->[$memmap->{'users.id'}], lc($_->[$memmap->{'credentials.authid'}]) } @$lmgr;
    my %cred2user = map { lc($_->[$memmap->{'credentials.authid'}]), $_->[$memmap->{'users.id'}] } @$lmgr;

    @addmembers = ();
    
    open(R_USER, "$afs_path/$gr/$user_file") 
      || die "Can't open user file: $afs_path/$gr/$user_file\n";
    while(my $line = <R_USER>) {
      next if ($line =~ /\#/);
      chomp($line);
      my $user = $line;
      $user .= '@andrew.cmu.edu' unless ($user =~ /\@/);
      if (exists $cred2user{lc($user)} && exists $dbmembers{$cred2user{lc($user)}}) {
	delete $dbmembers{$cred2user{lc($user)}};
	next;
      }

      print "Adding $user to $gid ($DBUSER)\n";
      ($res, $ref) = 
	CMU::Netdb::add_user_to_group($dbh, $DBUSER, $user, $gid);
      if ($res < 1) {
        print "Error adding $user to $gid. Error codes: $res; ($CMU::Netdb::errors::errmeanings{$res}) ".
	  " field: [".join(',', @$ref)."]\n";
	if ($res != -3) {
	  push(@$errmsgs, "Error adding user $user to group $gid");
	} else {
	  print "Not logging error\n";
	}
	next;
      }
    }
    close(R_USER);
    
    foreach my $rm (values %dbmembers) {
      print "Deleting $rm from NetReg\n";
      ($res, $ref) = CMU::Netdb::delete_user_from_group
	($dbh, $DBUSER, $rm, $gid);
      if ($res < 1) {
	push(@$errmsgs, "Error deleting user $rm from group $gid");
	print "Error $res ($CMU::Netdb::errors::errmeanings{$res}) deleting user $rm from group $gid\n";
#	CMU::Netdb::netdb_mail($0, "Error deleting user $rm from group $gid");
	next;
      }
    }
  }
  $dbh->disconnect();
  closedir G_DIR;
  if (scalar @$errmsgs) {
    print "Sending error mail using netdb_mail\n";
    CMU::Netdb::netdb_mail($0, join("\n", @$errmsgs));
  }
}
