#! /usr/bin/perl
#
# Copies the authbridge bootptab to the authbridge machines
#
# This is more intelligent than dns-xfer.sh in that it will figure out 
# which files go where
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
# $Id: authbridge-xfer.pl,v 1.7 2008/03/27 19:42:41 vitroth Exp $
#
# $Log: authbridge-xfer.pl,v $
# Revision 1.7  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.6.18.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.6.16.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.6  2004/03/19 18:54:57  kevinm
# * Warn when transfer fails
#
# Revision 1.5  2004/02/24 18:12:31  kevinm
# * exec bit, damit
#
# Revision 1.4  2004/02/24 18:11:43  kevinm
# * Just need to get it in the repository with exec bit set
#
# Revision 1.3  2004/02/20 03:17:52  kevinm
# * External config file updates
#
# Revision 1.2  2002/06/04 15:08:17  kevinm
# * Added vl64 to copy list
#
# Revision 1.1  2002/05/10 17:14:53  kevinm
# * transfer reports to the authbridge machine
#
#
#

use strict;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::config;

my $DEBUG = 0;

my $MYHOST = `/bin/hostname`;
chomp($MYHOST);

## Do XFERs
my ($RSYNC_RSH, $RSYNC_PATH, $RSYNC_OPTIONS, $RSYNC_REM_USER, $rres);

($rres, $RSYNC_RSH) = CMU::Netdb::config::get_multi_conf_var('netdb',
							     'RSYNC_RSH');
($rres, $RSYNC_PATH) = CMU::Netdb::config::get_multi_conf_var('netdb',
							      'RSYNC_PATH');
($rres, $RSYNC_OPTIONS) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'RSYNC_OPTIONS');
($rres, $RSYNC_REM_USER) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'RSYNC_REM_USER');


$ENV{RSYNC_RSH} = $RSYNC_RSH;

foreach my $ip (qw/128.2.4.18 128.2.4.20/) {
  my $com = $RSYNC_PATH." ".$RSYNC_OPTIONS." ".
    "/home/netreg/etc/misc-reports/bootptab-dynamic ".
      "$RSYNC_REM_USER\@$ip:/home/netreg/etc/misc-reports";
  # Silence the output
  $com .= ' > /dev/null';
  
  print "Command: $com\n";
  unless ($DEBUG) {
    my $res = system($com); 
    $res = $res >> 8;
    print "Result: $res\n";
    if ($res != 0) {
      die_msg("Error transferring authbridge report to $ip, result: $res");
    }
  }
}

sub die_msg {
  my ($msg) = @_;
  CMU::Netdb::netdb_mail('authbridge-xfer.pl', $msg, 'authbridge-xfer.pl died');
  die $msg;
}

