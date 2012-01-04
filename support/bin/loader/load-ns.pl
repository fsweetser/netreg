#! /usr/bin/perl
##
## load-ns.pl
## A script that will perform a number of database loading operations
## on CINDI dumps
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
##
## $Id: load-ns.pl,v 1.2 2008/03/27 19:42:45 vitroth Exp $
##
## $Log: load-ns.pl,v $
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
## Revision 1.5  2001/07/20 22:22:26  kevinm
## Copyright info
##
## Revision 1.4  2000/08/14 05:22:12  kevinm
## *** empty log message ***
##
## Revision 1.3  2000/07/31 15:39:36  kevinm
## *** empty log message ***
##
## Revision 1.2  2000/07/14 06:21:02  kevinm
## Set the default TTL
##
## Revision 1.1  2000/07/10 14:47:27  kevinm
## Updated loading scripts. cnames/mx/ns works now
##

##
##
##

use strict;

use lib '/home/netreg/lib';

use CMU::Netdb;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;
use CMU::WebInt::helper;
use CMU::WebInt;

$| = 1;
my $FW_FILE = "/afs/andrew/data/db/net/zone/CMU.EDU.zone";
my $RV_FILE = "/afs/andrew/data/db/net/zone/2.128.IN-ADDR.ARPA.zone";

my @extras = qw/CARNEGIETECH.ORG CARNEGIETECHSCHOOLS.COM 
  CARNEGIETECHSCHOOLS.ORG CMU.NET CMU.ORG HUB.CMU.NET RTR.CMU.NET TALKBANK.ORG 
  TECHSCHOOLS.COM TECHSCHOOLS.ORG TMA-PGH.ORG WRCT.ORG/;

if ($ARGV[0] eq '') {
  print "$0 [logfile]\n";
  exit;
}

a($ARGV[0]);

sub a {
  my ($logfile) = @_;
  my ($line, $dns);
  my $dbh = db_connect();
  
  $CMU::Netdb::primitives::debug = 2;
  $CMU::Netdb::validity::debug = 2;
  $CMU::Netdb::auth::debug = 2;
  $CMU::Netdb::machines_subnets::debug = 2;
  $CMU::Netdb::dns_dhcp::debug = 2;
  open(LOGFILE, ">$logfile") || die "Cannot open log file $logfile";

  # REVERSE
  open(FILE, $RV_FILE) || die "Cannot open infile $RV_FILE";
  my ($top, $curr) = ('', '');
  my @c;
  while($line = <FILE>) {
    next if ($line =~ /^\s+$/ || /^\#/);
    next if ($line =~ /^\$ORIGIN/);
    $line =~ s/^\s+//;
    @c = split(/\s+/, $line);
    if ($line =~ /IN SOA/) {
      $top = $c[0];
      $top =~ s/\.$//;
      print STDERR "top: $top\n";
      next;
    }
    print STDERR "top: $top\n";
    print STDERR "join: ".join(',', @c)."\n";
    if ($c[2] eq 'NS') {
      $curr = $c[0];
      $dns = $c[3];
    }elsif($c[1] eq 'NS') {
      $dns = $c[2];
    }else{
      next;
    }
    $dns =~ s/\.$//;
    my $dnsr = list_dns_zones($dbh, 'kevinm', "dns_zone.name = '$curr.$top'");
    if (!ref $dnsr || !defined $dnsr->[1]) {
      print LOGFILE "ADD_RESOURCE: ERROR: Can't find zone ($curr.$top)\n";
      next;
    }

    my $name;
    $name = $curr.".".$top if ($curr ne '');
    $name = $top if ($curr eq '');
    my %fields = ('name' => $name,
		  'rname' => $dns,
		  'type' => 'NS',
		  'ttl' => 86400,
		  'owner_type' => 'dns_zone',
		  'owner_tid' => $dnsr->[1]->[0]);
    my ($res, $ref) = add_dns_resource($dbh, 'kevinm', \%fields);
    if ($res != 1) {
      print LOGFILE "ADD_RESOURCE: ERROR: $curr.$top NS $dns: ".$errmeanings{$res}."\n";;
    }else{
      print LOGFILE "ADD_RESOURCE: OKAY: $curr.$top NS $dns\n";
    }
  }
  close(FILE);

  # FORWARD
  open(FILE, $FW_FILE) || die "Cannot open infile $FW_FILE";
  ($top, $curr) = ('', '');
  while($line = <FILE>) {
    next if ($line =~ /^\s+$/ || /^\#/);
    next if ($line =~ /^\$ORIGIN/);
    $line =~ s/^\s+//;
    @c = split(/\s+/, $line);
    if ($line =~ /IN SOA/) {
      $top = $c[0];
      $top =~ s/\.$//;
      next;
    }
    if ($c[2] eq 'NS') {
      $curr = $c[0];
      $dns = $c[3];
    }elsif($c[1] eq 'NS') {
      $dns = $c[2];
    }else{
      next;
    }
    $dns =~ s/\.$//;

    my $dnsr = list_dns_zones($dbh, 'kevinm', "dns_zone.name = '$curr.$top'");
    if (!ref $dnsr || !defined $dnsr->[1]) {
      print LOGFILE "ADD_RESOURCE: ERROR: Can't find zone ($curr.$top)\n";
      next;
    }
    my $name;
    $name = $curr.".".$top if ($curr ne '');
    $name = $top if ($curr eq '');
    $name =~ s/^\.//;
    my %fields = ('name' => $name,
		  'rname' => $dns,
		  'type' => 'NS',
		  'ttl' => 86400,
		  'owner_type' => 'dns_zone',
		  'owner_tid' => $dnsr->[1]->[0]);
    my ($res, $ref) = add_dns_resource($dbh, 'kevinm', \%fields);
    if ($res != 1) {
      print LOGFILE "ADD_RESOURCE: ERROR: $curr.$top NS $dns: ".$errmeanings{$res}."\n";;
    }else{
      print LOGFILE "ADD_RESOURCE: OKAY: $curr.$top NS $dns\n";
    }
  }
  close(FILE);
  
  # Extra forward zones

  foreach $dns (@extras) {
    my $dnsr = list_dns_zones($dbh, 'kevinm', "dns_zone.name = '$dns'");
    if (!ref $dnsr || !defined $dnsr->[1]) {
      print LOGFILE "ADD_RESOURCE: ERROR: Can't find zone ($dns)\n";
      next;
    }
    foreach my $ns (qw/LANCASTER.NET.CMU.EDU NETSERVER.NET.CMU.EDU 
		    LANCELOT.NET.CMU.EDU/) {
      
      my %fields = ('name' => $dns,
		    'rname' => $ns,
		    'type' => 'NS',
		    'ttl' => 86400,
		    'owner_type' => 'dns_zone',
		    'owner_tid' => $dnsr->[1]->[0]);
      my ($res, $ref) = add_dns_resource($dbh, 'kevinm', \%fields);
      if ($res != 1) {
	print LOGFILE "ADD_RESOURCE: ERROR: $dns NS $ns: ".$errmeanings{$res}."\n";;
      }else{
	print LOGFILE "ADD_RESOURCE: OKAY: $dns NS $ns\n";
      }
    }
  }

  close(LOGFILE);
}

