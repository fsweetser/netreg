#!/usr/bin/perl
#
# Copies the DNS zones to the DNS servers
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
# $Id: dns-xfer.pl,v 1.11 2008/03/27 19:42:41 vitroth Exp $
#
# $Log: dns-xfer.pl,v $
# Revision 1.11  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.10.8.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.10  2006/05/10 12:05:19  vitroth
# Added some bulletproofing to protect against hanging ssh processes.
# dns-xfer.pl now sets a timeout, using either RSYNC_TIMEOUT from netreg-netdb.conf
# or a default of 30 seconds.  dns.pl now execs dns-xfer.pl, instead of using
# system, since its just going to exit immediately anyway.  This avoids leaving
# around a potentially large dns.pl process longer then necessary.
#
# Revision 1.9  2005/03/30 20:54:32  vitroth
# Added an 'file exists' check when building list of zones to rsync,
# since netreg CAN be configured to put a zone entry in named.conf
# without generating the matching zone file.  i.e. for zone files
# that aren't mastered by netreg, but netreg is mastering the named.conf.
# In particular, we're now using this to serve 127.IN-ADDR.ARPA, for
# which the static zone file comes with Bind.
#
# Revision 1.8  2004/08/16 11:51:32  vitroth
# Delete all zones/named.conf's before creating new ones, so we stop copying
# old data around.
#
# Revision 1.7  2004/04/26 15:14:24  kevinm
# * Don't die if a machine is offline.. but send mail
#
# Revision 1.6  2004/03/19 18:53:56  kevinm
# * Send an error message when transfers fail
#
# Revision 1.5  2004/03/19 18:52:24  kevinm
# * Send an error message when the rsync fails
#
# Revision 1.4  2004/02/20 03:17:52  kevinm
# * External config file updates
#
# Revision 1.3  2002/04/05 17:41:14  kevinm
# * Include Netdb::config (how did it work??)
#
# Revision 1.2  2002/01/30 21:02:11  kevinm
# Fixed vars_l
#
# Revision 1.1  2001/11/09 20:24:22  kevinm
# This is the first round of a replacement DNS zonefile/config file transfer
# script. It only transfers the individual zonefiles needed + config file. Any
# zonefiles with keys in them will be SSH'd out. The only reason I'm not
# SSH'ing all the configs out is that the older Bind8 machines don't have
# the SSH receiving setup.
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

my ($GEN, $CONF, $XFER, $vres);
($vres, $GEN) = CMU::Netdb::config::get_multi_conf_var('netdb', 'DNS_GENPATH');
($vres, $CONF) = CMU::Netdb::config::get_multi_conf_var('netdb', 'DNS_CONFPATH');
($vres, $XFER) = CMU::Netdb::config::get_multi_conf_var('netdb', 'DNS_XFERPATH');

my $DEBUG = 0;
my $MYHOST = `/bin/hostname`;
chomp($MYHOST);

if ($ARGV[0] eq '-debug') {
  $GEN = '/tmp/zones';
  $XFER = '/tmp/zones-xfer';
  $CONF = '/tmp/zones';
  $DEBUG = 1;
}

opendir(DIR, $CONF);
my @confs = grep { /^named\.conf\./ && -f "$CONF/$_" } readdir(DIR);
closedir(DIR);

my %XferFiles;
my %KeyZones;

foreach my $c (@confs) {
  $c =~ /named.conf.(.+)$/;
  my $host = $1;
  next if ($host =~ /$MYHOST/i);

  open(FILE, "$CONF/$c") || die_msg("Cannot open configuration file $CONF/$c");
  $XferFiles{$host} = [];
  my $master;
  while((my $line = <FILE>)) {
#    print "Read: $line\n";
    if ($line =~ /zone\s+\"([^\"]+)\"\s+\{/) {
      $master = $1;
    }elsif($line =~ /type master/) {
      push(@{$XferFiles{$host}}, "$master.zone") unless ($master eq '.');
    }elsif($line =~ /key/) {
      $KeyZones{$host} = 1;
    }
      
  }
  close(FILE);
}    

## Do XFERs
my ($RSYNC_RSH, $RSYNC_PATH, $RSYNC_OPTIONS, $RSYNC_REM_USER, $RSYNC_TIMEOUT, $rres);

($rres, $RSYNC_RSH) = CMU::Netdb::config::get_multi_conf_var('netdb',
							     'RSYNC_RSH');
($rres, $RSYNC_PATH) = CMU::Netdb::config::get_multi_conf_var('netdb',
							      'RSYNC_PATH');
($rres, $RSYNC_OPTIONS) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'RSYNC_OPTIONS');
($rres, $RSYNC_REM_USER) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'RSYNC_REM_USER');
($rres, $RSYNC_TIMEOUT) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'RSYNC_TIMEOUT');


$ENV{RSYNC_RSH} = $RSYNC_RSH;
$RSYNC_TIMEOUT = 30 if (!defined $RSYNC_TIMEOUT);

# Before we begin, remove all zone files and named files in the XFER directory
unlink <$XFER/*.zone>;
unlink <$XFER/named.conf*>;
unlink <$XFER/dhcpd.conf.nsaux>;

`/bin/cp $GEN/*.zone $XFER`;
`/bin/cp $CONF/* $XFER`;

foreach my $host (keys %XferFiles) {
  push(@{$XferFiles{$host}}, "named.conf.$host") if ($#{$XferFiles{$host}} != -1 || 
						     defined $KeyZones{$host});
  next if ($#{$XferFiles{$host}} == -1);
  print "Syncing to: $host\n";
  my @flist = map { "$XFER/$_" if (-f "$XFER/$_"); } @{$XferFiles{$host}};
  my $com = $RSYNC_PATH." ".$RSYNC_OPTIONS." ".
    join(" ", @flist)." $RSYNC_REM_USER\@$host:$XFER";
  # Silence the output
  $com .= ' > /dev/null';
  
  print "Command: $com\n";
  unless ($DEBUG) {
    my $res;
    eval {
      local $SIG{ALRM} = sub { die "Timeout Alarm" };
      alarm $RSYNC_TIMEOUT;
      $res = system($com); 
      alarm 0;
    };

    if ($@ && $@ =~ /Timeout Alarm/) {
      CMU::Netdb::netdb_mail('dns-xfer.pl', "Error transferring DNS conf/".
                             "zones to $host, timeout after $RSYNC_TIMEOUT seconds.",
                             'dns-xfer.pl error');
    } else {
      $res = $res >> 8;
      print "Result: $res\n";
      if ($res != 0) {
        CMU::Netdb::netdb_mail('dns-xfer.pl', "Error transferring DNS conf/".
 			       "zones to $host, result: $res",
			       'dns-xfer.pl error');
      }
    }
  }
}

sub die_msg {
  my ($msg) = @_;
  CMU::Netdb::netdb_mail('dns-xfer.pl', $msg, 'dns-xfer.pl died');
  die $msg;
}
 
