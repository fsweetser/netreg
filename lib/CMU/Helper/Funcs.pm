#!/usr/local/bin/perl5 
#
# CMU::Pstatus
#  Handles operations with NetReg
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

package CMU::Helper::Funcs;

use strict;
use vars qw (@ISA @EXPORT $debug);

use Data::Dumper;

{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     makemap
	     long2dot
	     dot2long
	     mask2CIDR
	     CIDR2mask
	     ArpaDate
	     makeHash
	     hier_sort
	   );

$debug = 0;

# arguments: 
#  - a reference to the array
# returns:
#  - a reference to the data structure
sub makemap {
  my ($rArr) = @_;
  my $i = 0;
  my %rRef;
  map { $rRef{$_} = $i++ } @$rArr;
  return \%rRef;
}  

# given an IP address as a long int, returns the 
# dotted-quad equivalent
sub long2dot {
  return join('.', unpack('C4', pack('N', $_[0])));
}

# given an IP address as a dotted-quad, returns the
# long int equivalent
sub dot2long {
  return unpack('N', pack('C4', split(/\./, $_[0])));
}

# given a netmask in the form a.b.c.d (or one integer), calculates
# the CIDR nbits netmask (e.g. /24)
sub mask2CIDR {
  my ($addr) = @_;
 
  $addr = CMU::Netdb::dot2long($addr) if ($addr =~ /\./);
  my $CIDR = 32;
  while($addr % 2 != 1 && $CIDR > 0) {
    $addr = $addr >> 1;
    $CIDR--;
  }
  return $CIDR;
}

sub CIDR2mask {
  my ($cidr) = @_;

  return CMU::Netdb::long2dot( ((2**$cidr)-1) << (32-$cidr));
} 

sub ArpaDate {
  my($date, @l, @g, $zone, $zoneflg);

  # Fetch date, time
  #
  $date = ctime(time);
  @l = localtime(time);
  @g = gmtime(time);

  # Time zone
  #
  $zone = $l[2] - $g[2];
  $zoneflg = '+';
  $zone += 24 if ($zone < -12);
  $zone -= 24 if ($zone > 12);
  if ($zone < 0) {
    $zoneflg = '-';
    $zone = -$zone;
  }

  # Create date string
  #
  $date = substr($date,0,3).",". #  Day
    substr($date,7,3).          # Date
      substr($date,3,4).        # Month
        substr($date,19,5).     # Year
          substr($date,10,9).   # Time
            " $zoneflg".        # Zone direction
              sprintf("%02d",$zone). # Zone offset
                "00";

  return $date;
}

sub makeHash {
  my ($map, $datum) = @_;
  my ($res) = {};

  foreach (keys %$map) {
    $res->{$_} = $datum->[$map->{$_}];
  }

  return($res);
}

# Comparison routine will be used from other packages, so using the 
# package-global $a and $b won't work...  adding the '($$)' prototype
# causes the values to be sorted to be passed as arguments.

sub hier_sort ($$) {
  my ($a, $b) = @_;
  my ($l, @L, @R, $r);

  warn __FILE__ .':'. __LINE__ . ':> ' .
    "comparing $a and $b\n" if ($debug);
  @L = split(/\./, $a);
  @R = split(/\./, $b);
  $l = '';
  $r = '';

  while (@L && @R) {
    $l = pop(@L);
    $r = pop(@R);
    my $tmp = ($l <=> $r || $l cmp $r);
    if ($tmp) {
      warn __FILE__ .':'. __LINE__ . ':> ' .
        "result $tmp\n" if ($debug >= 2);
      return $tmp;
    }
  }
  if ((! @L) && @R) {
    warn __FILE__ .':'. __LINE__ . ":> result -1\n" if ($debug >= 3);
    return(-1);
  } elsif (@L && (! @R)) {
    warn __FILE__ .':'. __LINE__ . ":> result 1\n" if ($debug >= 3);
    return(1)
  } else {
    warn __FILE__ .':'. __LINE__ . ":> result 0\n" if ($debug >= 3);
    return(0);
  }

}

1;
