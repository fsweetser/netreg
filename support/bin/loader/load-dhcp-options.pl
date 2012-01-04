#! /usr/bin/perl
##
## load-dhcp-options.pl
## Loads subnet DHCP options from the subnet table.
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
## $Id: load-dhcp-options.pl,v 1.2 2008/03/27 19:42:44 vitroth Exp $
##
## $Log: load-dhcp-options.pl,v $
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
## Revision 1.2  2001/07/20 22:22:26  kevinm
## Copyright info
##
## Revision 1.1  2000/07/31 15:39:36  kevinm
## *** empty log message ***
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

$| = 1;
my $FW_FILE = "/afs/andrew/data/db/net/zone/CMU.EDU.zone";
my $RV_FILE = "/afs/andrew/data/db/net/zone/2.128.IN-ADDR.ARPA.zone";

my @extras = qw/ARTSNET.ORG BIODS.COM CARNEGIETECH.ORG
  CARNEGIETECHSCHOOLS.COM CARNEGIETECHSCHOOLS.ORG CMU.NET CMU.ORG EIOLCA.NET
  ENVIROLINK.ORG INTERSTREAM.COM NCOVR.ORG OVFORUM.ORG PAAR.ORG PAPA.ORG
  PARCHIVE.ORG PINBALL.ORG TALKBANK.ORG TECHSCHOOLS.COM TECHSCHOOLS.ORG
  TMA-PGH.ORG WRCT.ORG HUB.CMU.NET RTR.CMU.NET/;

if ($ARGV[0] eq '') {
  print "$0 [logfile]\n";
  exit;
}

a($ARGV[0]);

sub a {
  my ($logfile) = @_;
  my ($line, %fields, $dbh, $s, %fields, $res, $ref);
  $dbh = lw_db_connect();
  
  open(LOGFILE, ">$logfile") || die "Cannot open log file $logfile";

  ## Routed Subnets
  my $slr = list_subnets($dbh, 'netreg', 'subnet.share = 0');
  if (!ref $slr || !defined $slr->[0]) {
    print LOGFILE "Unable to load subnets.\n";
    exit 1;
  }

  shift(@$slr);
  foreach $s (@$slr) {
    %fields = ('type' => 'subnet',
	       'tid' => $s->[0]);
    
    # Router
    $fields{number} = 3;
    $fields{value} = long2dot($s->[3]+1);
    ($res, $ref) = add_dhcp_option($dbh, 'netreg', \%fields);
    if ($res < 1) {
      print LOGFILE "ADD_ROUTER: ERROR: ($s->[1]:$s->[0]) $errmeanings{$res} ".join(',', @$ref)."\n";
      next;
    }else{
      print LOGFILE "ADD_ROUTER: OKAY: ($s->[1]:$s->[0])\n";
    }
    
    # Broadcast
    $fields{number} = 28;
    $fields{value} = calc_bcast(long2dot($s->[3]), long2dot($s->[4]));
    ($res, $ref) = add_dhcp_option($dbh, 'netreg', \%fields);
    if ($res < 1) {
      print LOGFILE "ADD_BCAST: ERROR: ($s->[1]:$s->[0]) $errmeanings{$res} ".join(',', @$ref)."\n";
      next;
    }else{
      print LOGFILE "ADD_BCAST: OKAY: ($s->[1]:$s->[0])\n";
    }
    
    # Subnet Mask
    $fields{number} = 1;
    $fields{value} = long2dot($s->[4]);
    ($res, $ref) = add_dhcp_option($dbh, 'netreg', \%fields);
    if ($res < 1) {
      print LOGFILE "ADD_SMASK: ERROR: ($s->[1]:$s->[0]) $errmeanings{$res} ".join(',', @$ref)."\n";
      next;
    }else{
      print LOGFILE "ADD_SMASK: OKAY: ($s->[1]:$s->[0])\n";
    }
  }

  ## Old Backbone/Campus Ethernet
  my $slr = list_subnets($dbh, 'netreg', 'subnet.share = 1');
  if (!ref $slr || !defined $slr->[0]) {
    print LOGFILE "Unable to load subnets.\n";
    exit 1;
  }

  shift(@$slr);
  foreach $s (@$slr) {
    %fields = ('type' => 'subnet',
	       'tid' => $s->[0]);
    
    # Router
    $fields{number} = 3;
    $fields{value} = '128.2.1.2';
    ($res, $ref) = add_dhcp_option($dbh, 'netreg', \%fields);
    if ($res < 1) {
      print LOGFILE "ADD_ROUTER_2: ERROR: ($s->[1]:$s->[0]) $errmeanings{$res} ".join(',', @$ref)."\n";
      next;
    }else{
      print LOGFILE "ADD_ROUTER_2: OKAY: ($s->[1]:$s->[0])\n";
    }
    
    # Broadcast
    $fields{number} = 28;
    $fields{value} = '128.2.255.255';
    ($res, $ref) = add_dhcp_option($dbh, 'netreg', \%fields);
    if ($res < 1) {
      print LOGFILE "ADD_BCAST_2: ERROR: ($s->[1]:$s->[0]) $errmeanings{$res} ".join(',', @$ref)."\n";
      next;
    }else{
      print LOGFILE "ADD_BCAST_2: OKAY: ($s->[1]:$s->[0])\n";
    }
    
    # Subnet Mask
    $fields{number} = 1;
    $fields{value} = '255.255.0.0';
    ($res, $ref) = add_dhcp_option($dbh, 'netreg', \%fields);
    if ($res < 1) {
      print LOGFILE "ADD_SMASK_2: ERROR: ($s->[1]:$s->[0]) $errmeanings{$res} ".join(',', @$ref)."\n";
      next;
    }else{
      print LOGFILE "ADD_SMASK_2: OKAY: ($s->[1]:$s->[0])\n";
    }
  }
    
  close(LOGFILE);
}

