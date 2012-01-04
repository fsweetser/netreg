#! /usr/bin/perl
#
# Copies the services.sif file to the load balance servers / other servers
# that need parts of the services.sif file
#
# Copyright 2002 Carnegie Mellon University
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
# $Id: service-xfer.pl,v 1.7 2008/03/27 19:42:44 vitroth Exp $
#
# $Log: service-xfer.pl,v $
# Revision 1.7  2008/03/27 19:42:44  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.6.10.1  2007/10/11 20:59:47  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.6.8.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.2  2007/06/05 20:50:14  kcmiller
# *** empty log message ***
#
# Revision 1.6  2005/08/04 02:04:17  vitroth
# Fixed a race condition where dns.pl could be run while service-dump.pl was
# regenerating services.sif.  dns.pl will now use the services.sif file from
# from the xfer directory instead of from the gen directory.  i.e. it uses
# SERVICE_COPY instead of SERVICE_FILE from the config file.
#
# Also removed a hard coded email address from dns.pl and replaced it with
# DNS_LOG_EMAIL
#
# Revision 1.5  2004/07/26 21:25:23  vitroth
# Added support for rsync'ing to alternate path on remote machine, and using
# a username other then ftp.  This is set via attributes on the machine
# in the service group, 'Services File Xfer Path' and 'Services File Xfer User'
#
# Revision 1.4  2004/03/19 18:53:56  kevinm
# * Send an error message when transfers fail
#
# Revision 1.3  2004/02/20 03:17:52  kevinm
# * External config file updates
#
# Revision 1.2  2002/07/16 00:14:37  vitroth
# Added support for sending services file to any member machine which has
# the "Services File Xfer" attribute.  Also fixed a minor bug in the die
# message. (This is service-xfer.pl not dns-xfer.pl)
#
# Revision 1.1  2002/04/05 17:40:59  kevinm
# * Transfers services.sif file to machines that need it
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
use CMU::Netdb::helper;

my ($SFILE, $SCOPY, $vres);

($vres, $SFILE) = CMU::Netdb::config::get_multi_conf_var('netdb','SERVICE_FILE');
($vres, $SCOPY) = CMU::Netdb::config::get_multi_conf_var('netdb','SERVICE_COPY');

my $DEBUG = 0;

my $MYHOST = `/bin/hostname`;
chomp($MYHOST);

if ($ARGV[0] eq '-debug') {
  print "** Don't copy anything when running in -debug\n";
  exit 1;
}

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
`/bin/cp $SFILE $SCOPY.new`;
`/bin/mv $SCOPY.new $SCOPY`;

my @Hosts = CMU::Netdb::unique(load_services($SCOPY));
my %users;
my %paths;

my $DIR = $SCOPY;
$DIR =~ s/\/[^\/]+$//;

foreach my $host (@Hosts) {
  my $user = $RSYNC_REM_USER;
  my $path = $DIR;
  $user = $users{$host} if (exists $users{$host});
  $path = $paths{$host} if (exists $paths{$host});
  print "Syncing to: $host\n";
  my $com = $RSYNC_PATH." ".$RSYNC_OPTIONS." ".
    " $SCOPY $user\@$host:$path";
  # Silence the output
  $com .= ' > /dev/null';
  
  print "Command: $com\n";
  unless ($DEBUG) {
    my $res = system($com); 
    $res = $res >> 8;
    print "Result: $res\n";
    if ($res != 0) {
      die_msg("Error transferring services file to $host, result: $res");
    }
  }
}

sub die_msg {
  my ($msg) = @_;
  CMU::Netdb::netdb_mail('service-xfer.pl', $msg, 'service-xfer.pl died');
  die $msg;
}
 
sub load_services {
  my ($File) = @_;

  my @Hosts = ();
  my $machine;
  open(FILE, $File) || die("Cannot open services file: $File\n");
  while(my $line = <FILE>) {
    chomp $line;
    if ($line =~ /member\s+type\s+\"machine\"\s+name\s+\"([^\"]+)\"\s+\{/) {
      $machine = $1;
    }
    if ($line =~ /LB_Server\s*=\s*([^\;]+)/) {
      push(@Hosts, $1);
    }
    if ($line =~ /Services File Xfer\s*=\s*yes/) {
      push(@Hosts, $machine);
    }
    if ($line =~ /Services File Xfer Path\s*=\s*(\S*);/) {
      $paths{$machine} = $1;
    }
    if ($line =~ /Services File Xfer User\s*=\s*(\S*);/) {
      $users{$machine} = $1;
    }

  }
  return @Hosts;
}
      
