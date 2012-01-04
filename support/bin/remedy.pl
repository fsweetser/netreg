#!/usr/bin/perl
#
# This report dumps the building table and the tech queue info
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
# $Id: remedy.pl,v 1.3 2008/03/27 19:42:43 vitroth Exp $
# 
# $Log: remedy.pl,v $
# Revision 1.3  2008/03/27 19:42:43  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.2.22.1  2007/10/11 20:59:46  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.2.20.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.2  2002/01/30 20:54:13  kevinm
# Fixed vars_l
#
# 

use strict;
use Fcntl ':flock';

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;

my ($user, $dbh, $db_result);
my ($i, $debug);
my ($bldgfile, $techfile);
my ($tbl, $atr);

$CMU::Netdb::auth::debug = 0;
$debug = 0;
$bldgfile = "/home/netreg/etc/misc-reports/remedy/bldgs.csv";
#$bldgfile = "bldgs.csv";
$techfile = "/home/netreg/etc/misc-reports/remedy/techs.csv";
#$techfile = "techs.csv";

$user="netreg";
open (BLDGDMPFILE, "> $bldgfile") || die "Can't open $bldgfile for write\n";
open (TECHDMPFILE, "> $techfile") || die "Can't open $techfile for write\n";


$dbh = CMU::Netdb::report_db_connect();

$db_result = CMU::Netdb::list_buildings($dbh, $user, "( 1 = 1)");

die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get building list\n" if not ref $db_result;

$i = 0;
foreach (@{$db_result->[0]}){
#  map column headers from reply
  print STDERR "$_ \n" if $debug >= 5;
  ($tbl, $atr) = split (/\./, $_);
  print BLDGDMPFILE "$atr" . "|";
#  $id = $i if ($_ eq 'machine.id');
  $i++
}
print BLDGDMPFILE "\n";;

if ( $debug >= 5){
  $dbh->disconnect();
  exit;
}
  
for $i ( 1 .. $#$db_result ) {
# Loop through the values returned.
# items referenced as follows...
#  @{$db_result->[$i]}[$id],

  print STDERR join( '|', @{$db_result->[$i]}, "\n") if ($debug >= 4);
  print BLDGDMPFILE join( '|', @{$db_result->[$i]}, "\n");

}


$db_result = CMU::Netdb::list_activation_queue($dbh, $user, "( 1 = 1)");

die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get tech list\n" if not ref $db_result;

$i = 0;
foreach (@{$db_result->[0]}){
#  map column headers from reply
  print STDERR "$_ \n" if $debug >= 5;
  ($tbl, $atr) = split (/\./, $_);
  print TECHDMPFILE "$atr" . "|";
#  $id = $i if ($_ eq 'machine.id');
  $i++
}
print TECHDMPFILE "\n";;

if ( $debug >= 5){
  $dbh->disconnect();
  exit;
}
  
for $i ( 1 .. $#$db_result ) {
# Loop through the values returned.
# items referenced as follows...
#  @{$db_result->[$i]}[$id],

  print STDERR join( '|', @{$db_result->[$i]}, "\n") if ($debug >= 4);
  print TECHDMPFILE join( '|', @{$db_result->[$i]}, "\n");

}

$dbh->disconnect();

close (BLDGDMPFILE);
close (TECHDMPFILE);

system('/home/netreg/bin/remedy-xfer.sh');
