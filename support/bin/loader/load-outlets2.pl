#! /usr/bin/perl
##
## load-outlets.pl
## Loads pre-connect data.
##
## $Id: load-outlets2.pl,v 1.2 2008/03/27 19:42:45 vitroth Exp $
##
## $Log: load-outlets2.pl,v $
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
## Revision 1.3  2000/08/14 05:22:12  kevinm
## *** empty log message ***
##
## Revision 1.2  2000/07/31 15:39:37  kevinm
## *** empty log message ***
##
## Revision 1.1  2000/07/14 06:20:17  kevinm
## Loads registered outlets from CINDI dumps
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
  my ($fromto, $from, $to, $user, $dept, $status, %outlets, $speed);
    
#  $CMU::Netdb::primitives::debug = 2;
#  $CMU::Netdb::auth::debug = 2;

  open(LOGFILE, ">$logfile") || die "Cannot open log file $logfile";

  open(FILE, $file) || die "Cannot open infile $file";
  while(<FILE>) {
    next if (/^\s+$/ || /^\#/);
    ($fromto, $user, $dept, $status, $speed) = split(/\|/, $_);
    print "USER: $user\n";
    ($from, $to) = split(/\//, $fromto);
    foreach(qw/R \$/) {
      $to = $_.$to if ($from =~ /^$_/);
    }
    # grr. stupid *
    $to = '*'.$to if ($from =~ /^\*/);

    my $type = 1;
    $type = 1 if ($speed eq '10-BASE-T');
    $type = 2 if ($speed eq 'SWITCH-10');
    $type = 3 if ($speed eq '100-BASE-T');
    $type = 4 if ($speed eq 'SWITCH-100');
    $type = 5 if ($speed eq 'SWITCH-1000');
    $type = 6 if ($speed eq 'NETBAR');
    # WARNING - hardcoded values from outlet_type
#    if ($device =~ /SW.NET/i || $device =~ /NB.NET/i) {
#      $type = 2;
#    }elsif($device =~ /HB.NET/i) {
#      $type = 1;
#    }else{
#      print LOGFILE "FIND_TYPE: unknown: $device: assuming switched-10\n";
#      $type = 2;
    #    }
    if (defined $outlets{"$from/$to"}) {
      my @row = @{$outlets{"$from/$to"}};
      push(@row, [$from, $to, $user, $type, $status]);
      $outlets{"$from/$to"} = \@row;
    }else{
      $outlets{"$from/$to"} = [[$from, $to, $user, $type, $status]];
    }
  }
  close(FILE);
  
  my ($recordCindi, $recordOffline, $cable, @o);
  foreach my $ko (keys %outlets) {
    @o = @{$outlets{$ko}};
    print "Cable FROM: $o[0]->[0] TO: $o[0]->[1]\n";
    my $cr = list_cables($dbh, 'netreg', "cable.label_from = '$o[0]->[0]' AND ".
			 "cable.label_to = '$o[0]->[1]'");
    if (!ref $cr || !defined $cr->[1]) {
      $cr = list_cables($dbh, 'netreg', "cable.label_from = '$o[0]->[0]' AND destination = 'OUTLET' AND label_to = ''");
      if (ref $cr && defined $cr->[1]) {
	my %nfields = ('label_to' => $o[0]->[1]);
	$cable = $cr->[1]->[$CMU::WebInt::cable::cable_pos{'cable.id'}];
	my $a = modify_cable($dbh, 'netreg', $cable, 
			     $cr->[1]->[$CMU::WebInt::cable::cable_pos{'cable.version'}], \%nfields);
	if ($a) {
	  print LOGFILE "MOD_CABLE: OKAY: Changed cable $cable (Added TO) ($o[0]->[0]/$o[0]->[1])\n";
	}else{
	  print LOGFILE "MOD_CABLE: ERROR: Couldn't change cable $cable (Adding TO) ($o[0]->[0]/$o[0]->[1])\n";
	  print LOGFILE "ADD_OUTLET: ERROR: list_cables ($o[0]->[0], $o[0]->[1])\n";
	  next;
	}
      }else{
	print LOGFILE "ADD_OUTLET: ERROR: list_cables ($o[0]->[0], $o[0]->[1])\n";
	next;
      }
    }else{
      $cable = $cr->[1]->[$CMU::WebInt::cable::cable_pos{'cable.id'}];
    }

    my %fields = ('type' => $o[0]->[3],
		  'device' => '',
		  'port' => 0,
		  'cable' => $cable,
		  'attributes' => '',
		  'flags' => 'activated',
		  'status' => 'enable',
		  'account' => '',
		  'dept' => 'dept:compserv',
		  'comment' => 'added by load-outlets');

    # set permissions
    ($recordCindi, $recordOffline) = (1, 1);
    foreach my $p (@o) {
      $recordCindi = 0 if ($p->[2] ne 'cindi' && $p->[2] ne 'dc0m');
      $recordOffline = 0 if ($p->[4] ne 'O');
    }
    my %perms = ();
    foreach my $p (@o) {
      print "Perm added for $p->[2]\n";
      $perms{$p->[2]} = ['READ,WRITE', 1]
	unless ( (($p->[2] eq 'cindi' || $p->[2] eq 'dc0m') && !$recordCindi)
		 || ($p->[4] eq 'O' && !$recordOffline));
    }
      
    my ($res, $wref);
    $res = 1 unless $usedb;
    ($res, $wref) = add_outlet($dbh, 'netreg', 9, \%fields, \%perms) if $usedb;
    if ($res != 1) {
      print LOGFILE "ADD_OUTLET: ERROR: $cable: ".$errmeanings{$res};
      print LOGFILE " (".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $errcodes{EDB});
      print LOGFILE " [".join(',', @$wref)."] ";
      print LOGFILE "\n";
    }else{
      print LOGFILE "ADD_OUTLET: OKAY: $cable\n";
    }
  }
  close(FILE);
  close(LOGFILE);
  print "\nAll done.\n";
  $dbh->disconnect();
}
    
  

  


