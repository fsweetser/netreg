#! /usr/bin/perl
##
## load-cnames.pl
## A script that will perform a number of database loading operations
## on CINDI dumps
##
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
## $Id: load-cnames.pl,v 1.2 2008/03/27 19:42:44 vitroth Exp $
##
## $Log: load-cnames.pl,v $
## Revision 1.2  2008/03/27 19:42:44  vitroth
## Merging changes from duke merge branch to head, with some minor type corrections
## and some minor feature additions (quick jump links on list pages, and better
## handling of partial range allocations in the subnet map)
##
## Revision 1.1.22.1  2007/10/11 20:59:47  vitroth
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
## Revision 1.3  2001/07/20 22:22:26  kevinm
## Copyright info
##
## Revision 1.2  2000/07/31 15:39:36  kevinm
## *** empty log message ***
##
## Revision 1.1  2000/07/10 14:47:26  kevinm
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

if ($ARGV[0] eq '' || $ARGV[1] eq '') {
  print "$0 -usedb [infile] [logfile]\n\t-usedb: Actually update the db.\n";
  exit;
}

if ($ARGV[0] eq '-usedb') {
  a($ARGV[1], 1, $ARGV[2]);
}else{
  a($ARGV[0], 0, $ARGV[1]);
}

sub a {
  my ($file, $usedb, $logfile) = @_;
  my $dbh = db_connect();
  
  $CMU::Netdb::primitives::debug = 2;
  $CMU::Netdb::validity::debug = 2;
  $CMU::Netdb::auth::debug = 2;
  $CMU::Netdb::machines_subnets::debug = 2;
  $CMU::Netdb::dns_dhcp::debug = 2;
  open(LOGFILE, ">$logfile") || die "Cannot open log file $logfile";

  open(FILE, $file) || die "Cannot open infile $file";
  while(<FILE>) {
    next if (/^\s+$/ || /^\#/);
    my @c = split(/\s+/);
    my ($cname, $canon) = ($c[0], $c[1]);
    my $mid = list_machines($dbh, 'netreg', "machine.host_name = '$canon'");
    if (!ref $mid || !defined $mid->[1]->[0]) {
      print LOGFILE "ADD_RESOURCE: ERROR: $cname => $canon: Host doesn't exist (1).\n";
      next;
    }
    my %fields = ('name' => $cname,
		  'rname' => $canon,
		  'type' => 'CNAME',
		  'owner_tid' => $mid->[1]->[0],
		  'owner_type' => 'machine',
		  'ttl' => 0);
    my ($res, $ref) = add_dns_resource($dbh, 'netreg', \%fields);
    if ($res != 1) {
      print LOGFILE "ADD_RESOURCE: ERROR: $cname => $canon: ".$errmeanings{$res}."\n";;
    }else{
      print LOGFILE "ADD_RESOURCE: OKAY: $cname => $canon\n";
    }
  }
  close(FILE);
  close(LOGFILE);
}

