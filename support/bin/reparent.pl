#! /usr/bin/perl
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
## $Id: reparent.pl,v 1.4 2008/03/27 19:42:43 vitroth Exp $
##
## $Log: reparent.pl,v $
## Revision 1.4  2008/03/27 19:42:43  vitroth
## Merging changes from duke merge branch to head, with some minor type corrections
## and some minor feature additions (quick jump links on list pages, and better
## handling of partial range allocations in the subnet map)
##
## Revision 1.3.22.1  2007/10/11 20:59:47  vitroth
## Massive merge of all Duke changes with latest CMU changes, and
## conflict resolution therein.   Should be ready to commit to the cvs HEAD.
##
## Revision 1.3.20.1  2007/09/20 18:43:08  kevinm
## Committing all local changes to CVS repository
##
## Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
##
##
## Revision 1.3  2002/01/30 20:38:10  kevinm
## Fixed vars_l
##
## Revision 1.2  2001/07/20 22:22:26  kevinm
## Copyright info
##
## Revision 1.1  2000/07/31 15:39:37  kevinm
## *** empty log message ***
##
## Revision 1.1  2000/07/21 14:46:19  kevinm
## Figured it'd be good to checkin some of this code. the b() function does
## a reparenting of dns_zones to the proper parent.
##
##
##
##

use strict;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}
use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;
use CMU::WebInt::helper;
use CMU::WebInt;

$| = 1;

b();

sub b {
  my ($id, $version, %fields, $dbh, $r);
  $dbh = db_connect();
  $r = list_dns_zones($dbh, 'netreg', '');
  
  die 'foo' if (!ref $r);

  foreach(@$r) {
    $id = $_->[0];
    $version = $_->[9];
    next if ($id eq 'dns_zone.id');
    %fields = (); # don't need to set parent because it will be done automatically on update
    my ($res, $ref) = CMU::Netdb::modify_dns_zone($dbh, 'netreg', $id, $version, \%fields);
    print "$_->[1]: $res";
    if ($res < 1) {
      print ": ".join(',', @$ref);
    }
    print "\n";
  }
  $dbh->disconnect();
}
  

sub a {
  my ($file, $usedb, $logfile) = @_;
  my $dbh = db_connect();

  my @b;
  foreach(1..6000) {
    push(@b, $_);
  }
  
  my $query = "SELECT * FROM machine WHERE id IN (".join(',', @b).")";
  my $sth = $dbh->prepare($query);
  $sth->execute();
  my @row;
  my $i = 0;
  while(@row = $sth->fetchrow_array()) {
    $i++;
    print ".";
  }
  print "\n$i hosts\n";
  $sth->finish();
  $dbh->disconnect();
}

1;
