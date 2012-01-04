#! /usr/bin/perl
##
## load-outlets.pl
## Loads pre-connect data.
##
## $Id: load-outlets.pl,v 1.2 2008/03/27 19:42:45 vitroth Exp $
##
## $Log: load-outlets.pl,v $
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
## Revision 1.2  2000/07/31 15:39:36  kevinm
## *** empty log message ***
##
## Revision 1.1  2000/06/30 02:58:16  kevinm
## Initial checkin. Some files to automate loading procedures.
##
##
##
##

use strict;

use lib '/home/netreg/lib';

use CMU::Netdb;
use CMU::Netdb::buildings_cables;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;
use CMU::WebInt::helper;
use CMU::WebInt::outlets;
use CMU::WebInt;

$| = 1;

if ($ARGV[0] eq '' || $ARGV[1] eq '') {
  print "$0 -usedb [infile] [logfile]\n\t-usedb: Actually update the db.\n";
  exit;
}

# /afs/andrew/data/db/net/utils/connected-ports
if ($ARGV[0] eq '-usedb') {
  a($ARGV[1], $ARGV[2], 1);
}else{
  a($ARGV[0], $ARGV[1], 0);
}

sub a {
  my ($file, $logfile, $usedb) = @_;
  my $dbh = db_connect();
  
#  $CMU::Netdb::primitives::debug = 2;
#  $CMU::Netdb::auth::debug = 2;

  open(LOGFILE, ">$logfile") || die "Cannot open log file $logfile";

  open(FILE, $file) || die "Cannot open infile $file";
  while(<FILE>) {
    next if (/^\s+$/ || /^\#/);
    my ($device, $port, $to, $from) = split(/\s+/);
    my $type;
    # WARNING - hardcoded values from outlet_type
    if ($device =~ /SW.NET/i || $device =~ /NB.NET/i) {
      $type = 2;
    }elsif($device =~ /HB.NET/i) {
      $type = 1;
    }else{
      print LOGFILE "FIND_TYPE: unknown: $device: assuming switched-10\n";
      $type = 2;
    }
    my $cr = list_cables($dbh, 'netreg', "cable.label_from = '$from' AND ".
			 "cable.label_to = '$to'");
    if (!ref $cr || !defined $cr->[1]) {
      print LOGFILE "ADD_OUTLET: ERROR: list_cables ($from, $to, $device, $port)\n";
      next;
    }
    my $cable = $cr->[1]->[$CMU::WebInt::cable::cable_pos{'cable.id'}];

    my %fields = ('type' => $type,
		  'device' => $device,
		  'port' => $port,
		  'cable' => $cable,
		  'attributes' => '',
		  'flags' => 'permanent',
		  'status' => 'partitioned',
		  'account' => '',
		  'comment' => 'added by load-outlets');

    my ($res, $wref);
    $res = 1 unless $usedb;
    ($res, $wref) = add_outlet($dbh, 'netreg', 9, \%fields) if $usedb;
    if ($res != 1) {
      print LOGFILE "ADD_OUTLET: ERROR: $device/$port/$cable: ".$errmeanings{$res};
      print LOGFILE " (".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $errcodes{EDB});
      print LOGFILE "\n";
    }else{
      print LOGFILE "ADD_OUTLET: OKAY: $device/$port/$cable\n";
    }
  }
  close(FILE);
  close(LOGFILE);
  print "\nAll done.\n";
  $dbh->disconnect();
}
    
  

  


