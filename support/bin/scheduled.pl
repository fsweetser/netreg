#! /usr/bin/perl
##
## scheduled.pl
## A script to run scheduled NetReg operations.
##
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
## $Id: scheduled.pl,v 1.32 2008/03/27 19:42:43 vitroth Exp $
##
## $Log: scheduled.pl,v $
## Revision 1.32  2008/03/27 19:42:43  vitroth
## Merging changes from duke merge branch to head, with some minor type corrections
## and some minor feature additions (quick jump links on list pages, and better
## handling of partial range allocations in the subnet map)
##
## Revision 1.31.8.1  2007/10/11 20:59:47  vitroth
## Massive merge of all Duke changes with latest CMU changes, and
## conflict resolution therein.   Should be ready to commit to the cvs HEAD.
##
## Revision 1.31.6.1  2007/09/20 18:43:08  kevinm
## Committing all local changes to CVS repository
##
## Revision 1.30  2005/02/23 22:52:18  vitroth
## Moved the removal of the db lock row into an END statement, to make
## it go away if some subroutine encounters an error.
##
## Revision 1.29  2005/01/04 14:02:34  vitroth
## Removed entry for separate portadmin vlan update run.
##
## Revision 1.28  2004/07/22 15:40:17  vitroth
## Do vlan updates in the background.
##
## Revision 1.27  2003/10/01 15:45:36  vitroth
## Split port activate/deactivate and vlan changing into separate scheduled
## jobs.
##
## Revision 1.26  2002/09/30 17:28:12  kevinm
## * Added grloader
##
## Revision 1.25  2002/08/11 16:26:11  kevinm
## * Write dns update logs to logs dir
##
## Revision 1.24  2002/06/24 17:49:44  kevinm
## * pruneLocks
##
## Revision 1.23  2002/05/28 22:27:57  vitroth
## Using ldap based group loader now.
##
## Revision 1.22  2002/05/10 17:14:25  kevinm
## * Added authbridge-xfer
##
## Revision 1.21  2002/03/04 01:34:42  kevinm
## Added blcoked stuff
##
## Revision 1.20  2002/01/30 20:20:05  kevinm
## Fixed BEGIN line for vars_l
##
## Revision 1.19  2001/12/10 23:17:04  kevinm
## Added delete-expired
##
## Revision 1.18  2001/11/29 06:56:41  kevinm
## Made DNS fork and changed the user loading stuff
##
## Revision 1.17  2001/11/09 20:35:48  kevinm
## Stupid bug with comma
##
## Revision 1.16  2001/11/09 20:27:13  kevinm
## Addition of service-dump
##
## Revision 1.15  2001/08/06 21:35:44  kevinm
## Added DNS config file generation
##
## Revision 1.14  2001/08/01 15:23:21  vitroth
## Added remedy script.
##
## Revision 1.13  2001/07/25 18:11:01  vitroth
## Minor changes for CS reports.
##
## Revision 1.12  2001/07/20 22:22:26  kevinm
## Copyright info
##
## Revision 1.11  2001/03/13 20:22:02  vitroth
## more consistency stuff
##
## Revision 1.10  2001/03/13 20:18:31  vitroth
## Added consistency checker.
##
## Revision 1.9  2001/01/22 21:54:57  vitroth
## script now chdirs to /tmp
##
## Revision 1.8  2000/09/29 17:06:23  vitroth
## Added CS hosts report.
##
## Revision 1.7  2000/09/20 19:31:47  vitroth
## Production scripts should use /home/netreg not /home/netreg-dev
##
## Revision 1.6  2000/08/29 17:01:22  kevinm
## *** empty log message ***
##
## Revision 1.5  2000/08/22 12:57:55  kevinm
## * added keys
##
## Revision 1.4  2000/08/16 03:24:23  kevinm
## * added user_sync to the scheduled runs
##
## Revision 1.3  2000/08/15 03:17:07  kevinm
## * updates from today's loading.
## * portadmin updated to use getLock, etc. in CMU/Netdb
##
## Revision 1.2  2000/08/14 05:22:13  kevinm
## *** empty log message ***
##
## Revision 1.1  2000/07/31 15:39:37  kevinm
## *** empty log message ***
##
##
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
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;
use CMU::Netdb::reports;

$| = 1;

my $NRHOME = CMU::Netdb::config::get_multi_conf_var('netdb',
                                                          'NRHOME');

my %tasks = (1 => "$NRHOME/bin/dns.pl > $NRHOME/logs/dns.$$",
	     2 => "$NRHOME/bin/dhcp.pl",
	     3 => "$NRHOME/bin/misc-reports.pl",
	     4 => "$NRHOME/bin/portadmin.pl",
	     5 => "$NRHOME/bin/passwd-load.pl",
	     6 => "$NRHOME/bin/afs-xfer.sh",
	     7 => "$NRHOME/bin/ldaploader.pl",
	     8 => "$NRHOME/bin/domain-reports.sh",
	     9 => "$NRHOME/bin/checker.pl -m",
	     10 => "$NRHOME/bin/remedy.pl",
	     11 => "$NRHOME/bin/dns-config.pl",
	     12 => "$NRHOME/bin/service-dump.pl",
	     13 => "$NRHOME/bin/delete-expired.pl",
	     14 => "$NRHOME/bin/authbridge-xfer.pl",
	     15 => "$NRHOME/bin/grloader.pl",
	     16 => "$NRHOME/bin/service-dump-cfgen.pl",
	     17 => "$NRHOME/bin/radius.pl",
	    );

my @fork = qw/1 4 5/;
	     
my %sch_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::sys_scheduled_fields)};

my $dbh = CMU::Netdb::lw_db_connect();

my $debug = 0;

chdir("/tmp");
print STDERR "Scheduled began: ".`date`;
CMU::Netdb::pruneLocks($dbh);
getLock($dbh, 'SCHEDULED_LOCK', 'scheduled.pl', 20);
runOperations($dbh);

END {
  killLock($dbh, 'SCHEDULED_LOCK');
  my ($err, $val) = get_sys_key($dbh, 'SCHEDULED_LOCK');
  if ($err == 1) {
    print STDERR "Scheduled lock removal failure: $err/$val\n";
  }
  print STDERR "Scheduled end: ".`date`;

  $dbh->disconnect();
}

## **********************************************************************
## **********************************************************************

sub runOperations {
  my ($dbh) = @_;
  my ($sopr, $exit, %fields, $res, $ref);

  $sopr = list_scheduled($dbh, 'netreg', 'next_run <= now() AND blocked_until < now()');
  return if (!ref $sopr);
  shift(@$sopr);

  my $rec;
  foreach $rec (@$sopr) {
    next if (!defined $tasks{$rec->[$sch_pos{'_sys_scheduled.id'}]});
    print STDERR "Running op: $rec->[$sch_pos{'_sys_scheduled.name'}] ($tasks{$rec->[$sch_pos{'_sys_scheduled.id'}]})\n" if ($debug >= 2);
    if (grep(/^$rec->[$sch_pos{'_sys_scheduled.id'}]$/, @fork)) {
      spawn($tasks{$rec->[$sch_pos{'_sys_scheduled.id'}]});
    }else{
      system('/bin/sh', '-c', $tasks{$rec->[$sch_pos{'_sys_scheduled.id'}]});
      $exit = $? >> 8;
      print STDERR "Return value: $exit\n" if ($debug >= 2);
    }
    
    # also useful for resetting the array...
    %fields = ('next_run' => makeDate(time()+(60*$rec->[$sch_pos{'_sys_scheduled.def_interval'}])));
    $fields{'previous_run'} = makeDate(time()) if ($exit == 0);
    $fields{'blocked_until'} = 0;

    ($res, $ref) = modify_scheduled($dbh, 'netreg', 
				    $rec->[$sch_pos{'_sys_scheduled.id'}],
				    $rec->[$sch_pos{'_sys_scheduled.version'}], 
				    \%fields);
    if ($res < 1) {
      print STDERR "ERROR modifying scheduled: $res: ".join(',', @$ref)."\n";
      netdb_mail('scheduled.pl', 'Error modifying scheduled: '.$res." [ ".join(',', @$ref)."]");
    }
      
  }
}

# s  mi hr md m yr wd yd  isdst
# 46,14,10,25,6,100,2,206,1 (around 10:15am)
sub makeDate {
  my ($timeIn) = @_;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timeIn);

  $year = $year+1900;
  $mon++;
  return "$year-$mon-$mday $hour:$min:$sec";
}
  
sub spawn {
  my ($command) = @_;

  print STDERR "spawning $command\n";
  my $pid = fork();
  if ($pid ne '0') {
    # PARENT
    return;
  }
  # CHILD
  exec('/bin/sh', '-c', $command);
  exit;
}
  
