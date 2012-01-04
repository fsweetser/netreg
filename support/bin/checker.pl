#!/usr/bin/perl
#
#
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
# $Id: checker.pl,v 1.5 2008/03/27 19:42:41 vitroth Exp $
#
# $Log: checker.pl,v $
# Revision 1.5  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.4.22.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.4.20.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.4  2002/01/30 20:52:50  kevinm
# Fixed vars_l
#
# Revision 1.3  2001/07/20 21:59:49  kevinm
# *** empty log message ***
#
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}
use vars_l;

use lib $vars_l::NRLIB;
use strict;
use vars qw($dbh $opt_f $opt_m $opt_L $opt_v $opt_q $flags);
use CMU::Netdb;
use CMU::Netdb::helper;
use CMU::Netdb::consistency;
use Getopt::Std;

getopts('fLmqv');
if (@ARGV && $ARGV[0] =~ /^-/) {
  print STDERR "Usage: $0 [-f] [-L] [-m] [-q] [-v]\n";
  print STDERR "-f        Automatically repair anything that's fixable\n";
  print STDERR "-L        Inhibit logging to /home/netreg/logs/consistency.log\n";
  print STDERR "-m        Send mail if problems are found\n";
  print STDERR "-q        Display no output\n";
  print STDERR "-v        Display more progress\n";
  exit(0);
}
$flags->{dofix}=1 if ($opt_f);
$flags->{domail}=1 if ($opt_m);
$flags->{nolog}=1 if ($opt_L);
$flags->{quiet}=1 if ($opt_q);
$flags->{verbose}=1 if ($opt_v);
$dbh=lw_db_connect;
if (@ARGV) {
  $flags->{nolog}=1;
  $flags->{verbose}=1;
  consis_query($dbh, $flags, $ARGV[0]);
} else {
  run_all_queries($dbh, $flags);
}
$dbh->disconnect;
