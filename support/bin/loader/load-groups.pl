#! /usr/bin/perl
##
## $Id: load-groups.pl,v 1.2 2008/03/27 19:42:44 vitroth Exp $
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
## $Log: load-groups.pl,v $
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
## Revision 1.1  2000/06/30 02:58:16  kevinm
## Initial checkin. Some files to automate loading procedures.
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

if ($ARGV[0] eq '' || $ARGV[1] eq '' || $ARGV[2] eq '') {
  print "$0 [infile] [mapfile] [gfile]\n\n";
  exit;
}

a($ARGV[0], $ARGV[1], $ARGV[2]);


## FORMAT of Gfile:
#0000000000000|1|netreg:admins||Network Development

## FORMAT of MAP FILE
#SENIOR, INDUSTRIAL MANAGEMENT|1|
#SENIOR, SOMETHING ELSE|1|
#BUSINESS ADMINISTRATION|2|

sub a {
  my ($file, $mapfile, $gfile) = @_;

  $CMU::Netdb::primitives::debug = 2;
  $CMU::Netdb::auth::debug = 2;
#  $CMU::Netdb::machines_subnets::debug = 2;

  my %smap;
  open(MFILE, $mapfile);
  while(<MFILE>) {
    chop;
    my @a = split(/\|/);
    $smap{$a[0]} = $a[1];
  }
  close(MFILE);
  my $gkey = 2;
  open(GFILE, $gfile);
  while(<GFILE>) {
    chop;
    my @a = split(/\|/);
    $gkey = $a[1]+1 if ($a[1] >= $gkey);
  }
  close(GFILE);

  open(FILE, "$file") || die "Cannot open dept file for read: $file ($!)\n";
  while(<FILE>) {
    chop();
    my $dept = $_;
    print "Dept: $dept\nNew (0) or Existing #? ";
    my $resp = <STDIN>;
    chop($resp);
    my $name;
    my $comm;
    last if ($resp eq '');
    if ($resp == 0) {
      print "Enter group name: ";
      $name = <STDIN>;
      chop($name);
      $comm = $dept;
      $smap{$dept} = $gkey;
      open(GFILE, ">>$gfile") || die "Cannot open group file for writing: $gfile ($!)\n";
      print GFILE "00000000000000|$gkey|$name||$comm\n";
      close(GFILE);
      $gkey++;
    }else{
      $smap{$dept} = $resp;
    }
  }
  close(FILE);
  open(MFILE, ">$mapfile") || die "Cannot open map file for writing: $mapfile ($!)\n";
  foreach(sort keys %smap) {
    print MFILE "$_|$smap{$_}|\n";
  }
  close(MFILE);
}
    
  

  


