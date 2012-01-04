#! /usr/bin/perl

# Transform a dump of SQL such as:
# select id, abbreviation, base_address, (base_address |(~network_mask&4294967295)) from subnet;
# into a form for bulk-update.pl
#
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
# $Id: set-base-broadcast.pl,v 1.4 2008/03/27 19:42:44 vitroth Exp $
#
# $Log: set-base-broadcast.pl,v $
# Revision 1.4  2008/03/27 19:42:44  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.3.22.1  2007/10/11 20:59:47  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.3.20.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.3  2002/01/30 20:38:50  kevinm
# Fixed vars_l
#
# Revision 1.2  2001/07/20 22:06:37  kevinm
# *** empty log message ***
#
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}
use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb::helper;

open FILE, $ARGV[0];
open OUT, ">$ARGV[1]";
print OUT "seperator,\\|\n";
while(my $l = <FILE>) {
  my @a = split /\|/, $l;
  my ($bip, $Xip) = (long2dot($a[2]), long2dot($a[3]));
  my ($xbip, $xXip) = ($bip, $Xip);

  $xbip =~ s/\./\-/g;
  $xXip =~ s/\./\-/g;
  $a[1] = uc $a[1];
  
  print OUT "add|machine|user=netreg|host_name=BASE-$xbip-$a[1].NET.CMU.EDU|ip_address=$bip|ip_address_subnet=$a[0]|mode=base|dept=dept:nginfra|perm=dc0m READ,WRITE 1\n";
  print OUT "add|machine|user=netreg|host_name=BROADCAST-$xXip-$a[1].NET.CMU.EDU|ip_address=$Xip|ip_address_subnet=$a[0]|mode=broadcast|dept=dept:nginfra|perm=dc0m READ,WRITE 1\n";
}
close OUT;
close FILE;
  

