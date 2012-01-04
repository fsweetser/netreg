#! /usr/bin/perl

##
## $Id: pre-parse.pl,v 1.2 2008/03/27 19:42:45 vitroth Exp $
##
## $Log: pre-parse.pl,v $
## Revision 1.2  2008/03/27 19:42:45  vitroth
## Merging changes from duke merge branch to head, with some minor type corrections
## and some minor feature additions (quick jump links on list pages, and better
## handling of partial range allocations in the subnet map)
##
## Revision 1.1.22.1  2007/10/11 20:59:48  vitroth
## Massive merge of all Duke changes with latest CMU changes, and
## conflict resolution therein.   Should be ready to commit to the cvs HEAD.
##
## Revision 1.1.20.1  2007/09/20 18:43:08  kevinm
## Committing all local changes to CVS repository
##
## Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
##
##
## Revision 1.1  2002/01/10 02:50:19  kevinm
## Rearranged the load-* scripts
##
## Revision 1.4  2000/08/14 05:22:13  kevinm
## *** empty log message ***
##
## Revision 1.3  2000/07/31 15:39:37  kevinm
## *** empty log message ***
##
## Revision 1.2  2000/07/10 14:47:27  kevinm
## Updated loading scripts. cnames/mx/ns works now
##
##

use strict;

my $line;

my @zones = ('ECE.CMU.EDU', 'CIT.CMU.EDU', 'ECOM.CMU.EDU', 'EDRC.CMU.EDU',
	     'ETC.CMU.EDU', 'HCII.CMU.EDU', 'ICES.CMU.EDU', 'ISRI.CMU.EDU',
	     'ITC.CMU.EDU', 'RI.CMU.EDU', 'SCS.CMU.EDU', 'CS.CMU.EDU');

my @ignoreMachines;

open(FILE, "/home/dataload/hostload/ignore-list");
while($line = <FILE>) {
  chop($line);
  push(@ignoreMachines, $line);
}
close(FILE);

# Pre-parses host dumps to remove CS/ECE machines & subnets
open(FILE, $ARGV[0]);
open(WF, ">$ARGV[1]");
while($line = <FILE>) {
  my @a = split(/\|/, $line);
  my $host = $a[0];
  if (grep($_ eq $host, @ignoreMachines)) {
    print "Skipping $host..\n";
    next;
  }
  my @ip = split(/\./, $a[2]);
  if ( $a[2] eq '..' || $a[2] eq '128.2..' ||
       ($ip[2] == 102) || ($ip[2] == 44) ||
       ($ip[2] >= 128 && $ip[2] <= 132) ||
       ($ip[2] >= 178 && $ip[2] <= 222) ||
       ($ip[2] == 226) || ($ip[2] == 235) ||
       ($ip[2] == 236) || ($ip[2] == 242) ||
       ($ip[2] == 250) ||
       ($ip[2] >= 252 && $ip[2] <= 254) ) {
    my $f = 0;
    foreach my $z (@zones) {
      if ($host =~ /$z\Z/) {
	print "Skipping $host..\n";
	$f = 1;
	last;
      }
    }
    $f = 1 if ($host =~ /BCAST-$ip[2]-255.NET.CMU.EDU/);
    $f = 1 if ($host =~ /BCAST-$ip[2]-0.NET.CMU.EDU/);
    next if ($f == 1);
  }
  print WF $line;
}
close(FILE);
close(WF);
							 
