#! /usr/bin/perl
##
## load-extra-cable-info.pl
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
## $Id: load-extra-cable-info.pl,v 1.2 2008/03/27 19:42:44 vitroth Exp $
##
## $Log: load-extra-cable-info.pl,v $
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
## Revision 1.1  2000/08/13 16:15:28  kevinm
## * for adding device/port and room number information
##
##
##
##
##

use strict;

use lib '/home/netreg-dev/lib';

use CMU::Netdb;
use CMU::Netdb::buildings_cables;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;

$| = 1;

if ($ARGV[0] eq '') {
  print "$0 [infile] [logfile]\n";
  exit;
}

open(LOGFILE, ">$ARGV[1]") || die "Cannot open log file $ARGV[1]";
a($ARGV[0], $ARGV[1]);

my %typecache;
#open(LOGFILE, ">$ARGV[1]") || die "Cannot open log file $ARGV[1]";

sub a {
  my ($file, $logfile) = @_;
  my $dbh = lw_db_connect();
  
  open(FILE, $file) || die "Cannot open infile $file";
  while(<FILE>) {
    next if (/^\s+$/ || /^\#/);
    chop($_);
    my @parsed = split(/\|/, $_);
    my ($from, $to, $room, $type, $device, $port) = 
      ($parsed[2], $parsed[3], $parsed[29], $parsed[30], $parsed[31], 
       $parsed[32]);

    next if ($type eq '' && $device eq '');
    if ($type eq 'P') {
      if ($device eq '' || $port eq '') {
	print LOGFILE "ERROR: permanent-connection doesn't have device/port: fr=$from;to=$to;ty=$type;dv=$device;po=$port\n";
	next;
      }
      my $id = getCable($dbh, $from, $to);
      next if ($id == -1);
      my $lor = list_outlets($dbh, 'netreg', "outlet.cable = $id");
      if (!ref $lor) {
	print LOGFILE "ERROR: list_outlets returned not ref: $lor: fr=$from;to=$to;ty=$type;dv=$device;po=$port\n";
	next;
      }
      shift(@$lor);
      my ($oid, $version);
      my %fields;
      if (defined $lor->[0] && defined $lor->[0]->[0]) {
	$oid = $lor->[0]->[0];
	$version = $lor->[0]->[10];
	%fields = ('flags' => 'activated,permanent',
		   'device' => $device,
		   'port' => $port,
		   'attributes' => '');
	my ($res, $ref) = modify_outlet($dbh, 'netreg', $oid,
					$version, \%fields, 9);
	if ($res < 1) {
	  print LOGFILE "ERROR: marking outlet permanent: res=$res;oid=$oid;fr=$from;to=$to;ty=$type;dv=$device;po=$port\n"; 
	}else{
	  print LOGFILE "OKAY: market outlet permanent: oid=$oid\n";
	}
      }else{
	my $query = "INSERT INTO outlet (type, cable, device, port, ".
	  "attributes, flags, status) VALUES (2, $id, '$device', $port, ".
	    "'', 'permanent', 'partitioned')";
	$dbh->do($query);
	my $newID = $dbh->{'mysql_insertid'};
	if ($newID < 1) {
	  print LOGFILE "ERROR: adding permanent outlet: res=$newID;fr=$from;to=$to;ty=$type;dv=$device;po=$port\n";
	}else{
	  print LOGFILE "OKAY: added permanent outlet: res=$newID;fr=$from;to=$to;ty=$type;dv=$device;po=$port\n";
	}
      }
    }elsif($device ne '') {
      my $id = getCable($dbh, $from, $to);
      next if ($id == -1);
      my $lor = list_outlets($dbh, 'netreg', "outlet.cable = $id");
      if (!ref $lor) {
	print LOGFILE "ERROR: list_outlets returned not ref: $lor: fr=$from;to=$to;ty=$type;dv=$device;po=$port\n";
	next;
      }
      shift(@$lor);
      my ($oid, $version);
      my %fields;
      if (defined $lor->[0] && defined $lor->[0]->[0]) {
	$oid = $lor->[0]->[0];
	$version = $lor->[0]->[10];
	%fields = ('flags' => 'activated',
		   'device' => $device,
		   'port' => $port,
		   'attributes' => '');
	my ($res, $ref) = modify_outlet($dbh, 'netreg', $oid,
					$version, \%fields, 9);
	if ($res < 1) {
	  print LOGFILE "ERROR: marking outlet activated: res=$res;oid=$oid;fr=$from;to=$to;ty=$type;dv=$device;po=$port\n"; 
	}else{
	  print LOGFILE "OKAY: market outlet activated: oid=$oid\n";
	}
      }else{
	print LOGFILE "ERROR: Couldn't find active outlet for: fr=$from;to=$to;ty=$type;dv=$device;po=$port\n";  
      }
    }      
  }
  close(FILE);
  close(LOGFILE);
}

sub getCable {
  my ($dbh, $from, $to) = @_;
  my $cr = list_cables($dbh, 'netreg', 
		       "cable.label_from = '$from' AND ".
		       "cable.label_to = '$to'");
  if (!ref $cr) {
    print LOGFILE "ERROR: Can't get cable (no ref) for fr=$from;to=$to;er=$cr\n";
    return -1;
  }
  shift(@$cr);
  if (!defined $$cr[0] || !defined $cr->[0]->[0]) {
     print LOGFILE "ERROR: Can't find cable for fr=$from;to=$to\n";
    return -1;
  }
  return $cr->[0]->[0];
}
