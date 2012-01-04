#!/usr/bin/perl
#
# lbnamed implements nsupdate functions for real-time control of A/CNAME
# records.
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
# $Id: lbnamed.pl,v 1.14 2008/03/27 19:42:42 vitroth Exp $
#
# $Log: lbnamed.pl,v $
# Revision 1.14  2008/03/27 19:42:42  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.13.8.1  2007/10/11 20:59:46  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.13  2007/03/27 20:41:55  vitroth
# debugging changes
#
# Revision 1.12  2004/02/21 11:25:30  kevinm
# * External config change
#
# Revision 1.11  2003/08/08 15:24:01  kevinm
# * UpdateOnFailureOnly support
#
# Revision 1.10  2003/07/01 20:53:48  kevinm
# * ignore semi-colons on the backuponly line
#
# Revision 1.9  2003/06/24 15:54:27  kevinm
# * Added BackupOnly support for only failing to certain machines when all
#   non-backup servers are dead
#
# Revision 1.8  2002/08/12 13:17:55  kevinm
# * A bit of memory management cleanup
#
# Revision 1.7  2002/08/04 20:19:27  kevinm
# * Manually chmod /var/run/lbnamed
#
# Revision 1.6  2002/07/18 21:41:50  kevinm
# * More debugging files.
#
# Revision 1.5  2002/04/24 17:55:29  kevinm
# * Various bug fixes
#
# Revision 1.4  2002/04/08 03:54:53  kevinm
# * Fixes; reverse dns update
#
# Revision 1.3  2002/04/05 17:42:02  kevinm
# * Load balancing nameserver is coming right along
#
# Revision 1.2  2002/02/21 03:17:45  kevinm
# Patches to deal with new services file format
#
# Revision 1.1  2002/01/30 20:22:03  kevinm
# First pass of the lbnamed server. Works in general, not in production yet.
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
use DNS::LBPool;
use DNS::ZoneParse;
use Data::Dumper;
use Digest::MD5  qw(md5 md5_hex md5_base64);

$| = 1;
my ($vres, $CONF) = CMU::Netdb::config::get_multi_conf_var('netdb', 
							   'SERVICE_COPY');

my $debug = 0;
my %PoolXsum = ();

## The interval on which we recheck the services file
my $RECHECK_INTERVAL = 30;

## Load_services will return an array of service pointers that
## we need to handle

if ($ARGV[0] eq '-debug') {
  $debug = 25;
  $CONF = $ARGV[1] if ($ARGV[1] ne '');
}

# Make sure our directory exists and is writable
unless (-d "/var/run/lbnamed") {
  mkdir("/var/run/lbnamed", '0755');
  `chmod 755 /var/run/lbnamed`;
}

my $LBPool = new DNS::LBPool;

$LBPool->SetVar('Debug', $debug, 'global') if ($debug);

&do_loop($LBPool);

exit(1);

sub do_loop {
  my ($LBPool) = @_;

  my $LastCheck = 0;

  while(1) {
    if ($LastCheck + $RECHECK_INTERVAL < time()) {
      &load_services($CONF);
      $LastCheck = time();
    }
    
    # LBPool implements a sleep to avoid spinning too fast.
    $LBPool->Run();
  }
}

## --**--**--**--**--**--**--**--**--**--**--**--**--**--**--**--**

## Load the services.sif file and extract the LBNAMED relevant bits
## Arguments:
##  - File: Path to the services.sif file
## Returns:
##  - Array of LBPool handlers

sub load_services {
  my ($File) = @_;

  open(FILE, $File) || die("Cannot open services file: $File\n");
  my ($depth, $loc) = (0, 0);

  ## Variables used in the process
  my ($hn, $ServiceName, $MemberName, $ResType) = ('', '', '', '');
  my %Pools;
  
  while(my $line = <FILE>) {
    if ($depth == 0) {
      if ($line =~ /machine\s+\"([^\"]+)\"\s*\{/) {
        $hn = lc($1);
	$loc = 1;
	$depth++;
      }elsif($line =~ /service\s+\"([^\"]+)\"\s+type\s+\"LB_Pool\"\s+\{/) {
	$loc = 2;
	$ServiceName = $1;
	$Pools{$ServiceName} = {};
	## Reset all variables related to the service group stuff.
	$depth++;
      }
    }elsif($depth == 1) {
      ## inside machine {} block
      if ($loc == 1 && $line =~ /ip_address\s+([^\;]+)\;/ && $hn ne '') {
	$Pools{_machines}->{$hn} = CMU::Netdb::long2dot($1);
        $hn = '';
      }elsif($loc == 2) {
	
	## Inside a service {} block
	if ($line =~ /member\s+type\s+\"machine\"\s+name\s+\"([^\"]+)\"\s*\{/) {
	  ## Adding a new member to this service group
	  $MemberName = lc($1);
	  $Pools{$ServiceName}->{members}->{$MemberName} = {};
	  $depth++;
	  $loc = 3;
	}elsif($line =~ /attr\s+([^\=]+)\s*=\s*([^\;]+)\;/) {
	  my ($AttrName, $AttrVal) = ($1, $2);
	  $AttrName =~ s/^\s*//;
	  $AttrName =~ s/\s*$//;

	  push(@{$Pools{$ServiceName}->{attribute}->{$AttrName}}, $AttrVal);
	}elsif($line =~ /resource (\S+)/) {
	  $ResType = $1;
	  $Pools{$ServiceName}->{resources}->{$ResType} = [];
	  $depth++;
	  $loc = 4;
	}
	
      }
      if ($line =~ /\}/) {
        $depth--;
        $loc = 0;
	$ServiceName = '';
      }
    }elsif($depth == 2) {

      if ($loc == 3) {
	## Inside a service { member HOST_NAME { } } block
	if ($line =~ /attr Weighting\s*=\s*(\d+)/) {
	  $Pools{$ServiceName}->{members}->{$MemberName}->{weight} = $1;
	}elsif($line =~ /attr BackupOnly\s*=\s*(\S+)\;/) {
	  $Pools{$ServiceName}->{members}->{$MemberName}->{backup} = $1;
        }
      }elsif($loc == 4) {
	## Inside a service { resource TYPE { } } block
	if ($line =~ /name ([^\;]+)/) {
	  push(@{$Pools{$ServiceName}->{resources}->{$ResType}},
	       $1);
	}
      }
      
      if ($line =~ /\}/) {
	$depth--;
	$loc = 2 if ($loc == 3);
	$MemberName = '';
	$ResType = '';
      }
    }
  }

  close(FILE);

  my $LocalHostname = lc(`hostname`);
  chop($LocalHostname);

  my $rPool = \%Pools;

  ## Okay, now we have constructed the %Pools structure with all the
  ## necessary information.
  foreach my $Pool (keys %Pools) {
    next if ($Pool eq '_machines');

    ## Don't construct this pool locally unless we are defined
    ## as one of the LB servers
    if (!defined $Pools{$Pool}->{attribute}->{LB_Server} ||
	!grep(/^$LocalHostname$/i,
	      @{$Pools{$Pool}->{attribute}->{LB_Server}})) {
      if (defined $PoolXsum{$Pool}) {
	$LBPool->Delete($Pool);
      }
      next;
    }

    ## Figure out if this pool already exists and is the same
    my $XS = md5_base64(Dumper($Pools{$Pool}));

    next if ($XS eq $PoolXsum{$Pool});
    if ($PoolXsum{$Pool} ne '') {
      $LBPool->Delete($Pool);
    }
    # Record this..
    open(FILE, ">/var/run/lbnamed/_pool.$Pool");
    print FILE Dumper($Pools{$Pool});
    close(FILE);

    ## Figure out what kind of collector this pool uses.
    ## Default to SNMP.
    my $CollType = 'SNMP';
    if (defined $Pools{$Pool}->{attribute}->{Collection_Type} && 
	ref $Pools{$Pool}->{attribute}->{Collection_Type}) {
      $CollType = $Pools{$Pool}->{attribute}->{Collection_Type}->[0];
    }

    ## Construct the pool
    my $Ret = $LBPool->AddPool($Pool, $CollType);
    if ($Ret != 1) {
      print "Unable to construct pool $Pool: $Ret";
      next;
    }
    
    ## Add members to the pool
    foreach my $Member (keys %{$Pools{$Pool}->{members}}) {
      # FIXME: Send along connection parameters
      $LBPool->AddMember($Pool, $Member,
			 $Pools{$Pool}->{members}->{$Member}->{weight}, {});
      if ($Pools{$Pool}->{members}->{$Member}->{backup} ne 'Yes') {
        $Pools{$Pool}->{members}->{$Member}->{backup} = 'No';
      }
      # Set the backup status
      $LBPool->SetVar("BackupOnly_$Member", 
                      $Pools{$Pool}->{members}->{$Member}->{backup},
                      'collector', $Pool);
      # Set the IP address of this member
      $LBPool->SetVar("IP_$Member", $Pools{_machines}->{$Member}, 'collector', $Pool);
    }

    ## Add the DNS resource information
    ## We don't support multiple resources now (ie CNAME and ANAME, etc.)
    if (defined $Pools{$Pool}->{resources}->{ANAME} &&
	defined $Pools{$Pool}->{resources}->{ANAME}->[0]) {
      $LBPool->SetVar('DNSType', 'A', 'pool', $Pool);
      $LBPool->SetVar('DNSName',
		      $Pools{$Pool}->{resources}->{ANAME}->[0],
		      'pool', $Pool);

    }elsif(defined $Pools{$Pool}->{resources}->{CNAME} &&
	   defined $Pools{$Pool}->{resources}->{CNAME}->[0]) {
      $LBPool->SetVar('DNSType', 'CNAME', 'pool', $Pool);
      $LBPool->SetVar('DNSName',
		      $Pools{$Pool}->{resources}->{CNAME}->[0],
		      'pool', $Pool);
    }

    ## Set the DNS update key
    if (defined $Pools{$Pool}->{attribute}->{DDNS_Key} &&
	defined $Pools{$Pool}->{attribute}->{DDNS_Key}->[0]) {
      my $FullKey = $Pools{$Pool}->{attribute}->{DDNS_Key}->[0];

      my ($KeyName, $Key) = split(/\:/, $FullKey, 2);
      $LBPool->SetVar('KeyName',  $KeyName, 'pool', $Pool);
      $LBPool->SetVar('Key', $Key, 'pool', $Pool);
    }

    ## Set the DNS update interval
    if (defined $Pools{$Pool}->{attribute}->{DNS_Update_Interval} &&
	defined $Pools{$Pool}->{attribute}->{DNS_Update_Interval}->[0]) {
      
      $LBPool->SetVar('UpdInterval', 
		      $Pools{$Pool}->{attribute}->{DNS_Update_Interval}->[0],
		      'pool', $Pool);
    }else{
      # If the update interval isn't set, default to 8 seconds
      $LBPool->SetVar('UpdInterval', 8, 'pool', $Pool);
    }

    ## Set the parameter for optionally updating there reverses
    if (defined $Pools{$Pool}->{attribute}->{DNS_Update_Reverse} &&
        defined $Pools{$Pool}->{attribute}->{DNS_Update_Reverse}->[0]) {

      $LBPool->SetVar('UpdReverse',
                      $Pools{$Pool}->{attribute}->{DNS_Update_Reverse}->[0],
                      'pool', $Pool);
    }

    ## Set the UpdateOnFailureOnly flag
    $LBPool->SetVar('UpdateOnFailureOnly',
		    $Pools{$Pool}->{attribute}->{UpdateOnFailureOnly}->[0],
		    'pool', $Pool);

    ## Set the multiplication factors for the pool
    my %Factors;
    foreach my $Attr (keys %{$Pools{$Pool}->{attribute}}) {
      my ($Name, $Val) = ('', '');
      if ($Attr eq 'Generic_Weight') {
	($Name, $Val) = split(/\s*\:\s*/, 
			     $Pools{$Pool}->{attribute}->{$Attr}->[0]);
      }elsif ($Attr =~ /_weight$/i) {
	$Name = $Attr;
        $Name =~ s/_weight$//i;
	$Val = $Pools{$Pool}->{attribute}->{$Attr}->[0];
      }else{
	next;
      }
      # Perl doesn't like hash variables to begin with a nu
      $Factors{$Name} = $Val;
    }
    $LBPool->SetFactors($Pool, \%Factors);
    $PoolXsum{$Pool} = $XS;

  }

  undef %Pools;
  return 1;
}
