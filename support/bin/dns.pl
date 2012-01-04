#!/usr/bin/perl
#
# DNS Zone File Generation
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
#
# $Id: dns.pl,v 1.61 2008/03/29 16:09:48 vitroth Exp $
# 
# $Log: dns.pl,v $
# Revision 1.61  2008/03/29 16:09:48  vitroth
# fixed a bug where partial zone matches were firing in the -only mode.
# i.e. trying to update only test.net.cmu.edu would also update net.cmu.edu
#
# Revision 1.60  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.59.8.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.59.6.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.13  2007/06/05 20:48:28  kcmiller
# * Updating to what's currently running on netreg1
#
# Revision 1.55.2.2  2006/08/01 01:07:14  kevinm
# * Merged ANAME and DNS UPDATE/glue fixes
#
# Revision 1.55.2.1  2005/08/14 03:26:18  kevinm
# * Integration of the local dns.pl with the HEAD. Some functions were implemented
#   in both, including exclusive zone generation. This also implements zone canonicalization
#   (enabling one to make the whole zone lowercase, for example)
#
# Revision 1.10  2005/08/14 03:25:02  kcmiller
# * Syncing to mainline
#
# Revision 1.9  2004/12/15 02:49:17  kcmiller
# * canonicalization of zone master hash
#
# Revision 1.8  2004/12/14 14:09:40  kcmiller
# * Can't canonicalize before referring to name
#
# Revision 1.7  2004/12/14 04:10:16  kcmiller
# * canonicalization
#
# Revision 1.6  2004/12/10 18:54:19  kcmiller
# * Update DNS pool addresses
#
# Revision 1.5  2004/12/03 05:07:26  kcmiller
# * Adding RP type
#
# Revision 1.4  2004/12/03 04:33:02  kcmiller
# * HINFO needs to be wrapped in quotes
#
# Revision 1.3  2004/11/20 00:21:39  kcmiller
# * declare SUPDMAIL ..
#
# Revision 1.2  2004/11/20 00:20:09  kcmiller
# * Don't send mail back to andrew for all DNS updates
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.50  2004/08/16 11:51:32  vitroth
# Delete all zones/named.conf's before creating new ones, so we stop copying
# old data around.
#
# Revision 1.49  2004/07/13 18:39:27  vitroth
# dns.pl & related modules should send ddns updates to the servers that netreg
# say are authoritative, instead of resolving an SOA.  The SOA lookup is still
# done if netreg didn't have an entry.  And if the SOA lookup returns nothing
# the update should be aborted, instead of letting Net::DNS::Resolver pick
# a server to send it to, which doesn't work at all.  We were sending updates
# to web5.andrew.cmu.edu, because N:D:R was looking up an A record for the
# andrew.cmu.edu (presumably because its the default zone in resolv.conf) and
# sending to that.
#
# Revision 1.48  2004/02/21 11:25:54  kevinm
# * Variable typo (SERVICE->SERVICES)
#
# Revision 1.47  2004/02/20 03:17:52  kevinm
# * External config file updates
#
# Revision 1.46  2003/08/04 15:03:35  kevinm
# * Added LOC record type
#
# Revision 1.45  2003/07/09 21:55:34  kevinm
# * Can now handle reverse zones that aren't /24s as the rv-toplevel
#
# Revision 1.44  2002/11/01 16:21:28  kevinm
# * Use _DZ- in static zones as well
#
# Revision 1.43  2002/09/30 20:48:09  kevinm
# * Don't add glue unless the NS record is below the apex
#
# Revision 1.42  2002/08/04 02:16:27  cg2v
# More of the same
#
# Revision 1.41  2002/08/04 01:23:17  cg2v
# fix typo in SRV record generation
#
# Revision 1.40  2002/07/17 21:57:31  kevinm
# * Added AAAA Record type
#
# Revision 1.39  2002/04/09 22:03:44  kevinm
# * Added zone name in ddns success update messages
#
# Revision 1.38  2002/04/08 02:35:01  kevinm
# * Use no_dnsfwd / no_dnsrev in generating zones
#
# Revision 1.37  2002/03/29 20:50:01  kevinm
# * Don't CC: the .dns mail, send it there. sigh
#
# Revision 1.36  2002/03/29 20:36:47  kevinm
# * Send both forward and reverse posts to .dns
#
# Revision 1.35  2002/03/29 19:23:47  kevinm
# * Send errors to .dns
#
# Revision 1.34  2002/03/27 20:42:40  kevinm
# * Don't DNS Update pool addresses
#
# Revision 1.33  2002/03/25 22:54:06  kevinm
# * Got rid of dns server group dependencies
#
# Revision 1.32  2002/03/11 04:11:01  kevinm
# * Added AFSDB support
#
# Revision 1.31  2002/01/30 21:40:53  kevinm
# Fixed vars_l
#
# Revision 1.30  2002/01/10 22:27:19  kevinm
# Send mail about succesful DNS updates
#
# Revision 1.29  2001/11/29 06:55:45  kevinm
# Changed to using dns-xfer.pl from dns-xfer.sh
#
# Revision 1.28  2001/11/29 06:41:20  kevinm
# More changes.. return codes are better.
# Pushing this out
#
# Revision 1.27  2001/10/31 19:09:34  kevinm
# Fixed ANAME TTL and TXT records
#
# Revision 1.26  2001/10/31 07:22:00  kevinm
# This code should cause all zones to be loaded. There are some unresolved
# issues with TTL values on multiple A records (but the nameserver corrects
# for us), and we need to verify that ANAMEs have okay TXT records for them.
#
# Revision 1.25  2001/10/31 06:44:17  kevinm
# Fixes reverse records for DNS zones, also fixed CNAME/OTHER data erors
#
# Revision 1.24  2001/10/31 06:33:02  kevinm
# Fixed CNAME record addition
#
# Revision 1.23  2001/10/31 06:24:23  kevinm
# Fixes for DNS xfer
#
# Revision 1.21  2001/10/17 20:18:20  kevinm
# Fixes for sending mail
#
# Revision 1.20  2001/09/14 16:21:57  kevinm
# Minor change to printing A records for the zone.
#
# Revision 1.19  2001/09/14 06:00:46  kevinm
# Fixed ANAMEs
#
# Revision 1.18  2001/09/13 21:05:34  kevinm
# Don't put the IP address out more than once for ANAMEs
#
# Revision 1.17  2001/09/13 20:45:55  kevinm
# Added ANAME support
#
# Revision 1.16  2001/09/12 20:24:33  kevinm
# Fixed TTL == 0 problem
#
# Revision 1.15  2001/09/12 20:20:50  kevinm
# Problem with LastRecord utilization. It was only having one nameserver
# be the primary.
#
# Revision 1.14  2001/09/05 20:26:12  kevinm
# Fixed TTL writing issue
#
# Revision 1.13  2001/08/24 22:45:12  kevinm
# Today's round of fixes...
#
# Revision 1.12  2001/08/22 21:51:06  kevinm
# Fixed up a canonicalization problem
#
# Revision 1.11  2001/08/22 21:06:06  kevinm
# Fixed additional records.
#
# Revision 1.10  2001/08/22 20:58:23  kevinm
# This is dns2.pl -> dns.pl
#
#
#


use Fcntl ':flock';

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use Getopt::Long;
use CMU::Netdb;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;

use DNS::NetRegZone;

use strict;
use Data::Dumper;

my $USER = 'netreg';

my ($ZONEPATH, $SERVICES, $NRHOME, $EMAIL, $vres,
    $UPD_POOLADDR, $CANON_FUNC);

($vres, $ZONEPATH) = CMU::Netdb::config::get_multi_conf_var('netdb',
							    'DNS_GENPATH');
($vres, $SERVICES) = CMU::Netdb::config::get_multi_conf_var('netdb',
							    'SERVICE_COPY');
($vres, $NRHOME) = CMU::Netdb::config::get_multi_conf_var('netdb',
							  'NRHOME');
($vres, $UPD_POOLADDR) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'DNS_UPDATE_POOL_ADDR');
$UPD_POOLADDR = 0 unless ($vres == 1);

($vres, $CANON_FUNC) = CMU::Netdb::config::get_multi_conf_var('netdb',
							      'DNS_CANON_FUNC');
if ($vres == 1) {
    if ($CANON_FUNC eq 'lc') {
	$CANON_FUNC = sub { return lc($_[0]); };
    }else{
	$CANON_FUNC = sub { return uc($_[0]); };
    }
}else{
    $CANON_FUNC = sub { return uc($_[0]); };
}

($vres, $EMAIL) = CMU::Netdb::config::get_multi_conf_var('netdb',
                                                         'DNS_LOG_EMAIL');

my %nscache;
my $DEBUG;
my $ENABLE_DDNS = 1;
my $ENABLE_STATIC = 1;

my %options = (
	       'xfer' => 1,
	       'zone' => [],
	       'help' => 0,
	       'only' => '');

my $ores = GetOptions(\%options, "debug:i", "xfer!", "zone=s@", "help|h!",
			         "only=s");
die if (!$ores);
push(@{$options{'zone'}}, $options{'only'}) if ($options{'only'} ne '');

if ($options{'help'} == 1) {
    usage();
}

if (defined $options{'debug'}) {
  $SERVICES = '/tmp/services.sif';
  $ZONEPATH = '/tmp/zones';
  $options{'debug'} = 12 if ($options{'debug'} == 0);
  print "** Debug Mode Enabled **\n";
}else{
  $options{'debug'} = 0;
}

# Before we begin, delete all zonefiles in ZONEPATH
unlink <$ZONEPATH/*.zone> unless (scalar($options{'zone'}) > 0);

## ASSUME: We're running inside scheduled, so locking is done for us.

my $dbh = lw_db_connect();
# check for errors?
if (!$dbh) {
  &CMU::Netdb::netdb_mail('dns.pl', 'Database handle is NULL!', 'dns.pl error');
  exit -1;
}
 
my %ZoneMap;

# Get all zonefiles up-to-date
CMU::Netdb::update_zone_serials($dbh, $USER) unless ($options{'debug'} > 0);

print "Zone serials updated, selecting machine data\n";

my $machines = CMU::Netdb::list_machines_fw_zones($dbh, $USER, 
  "machine.mode!=\"base\" and machine.mode!=\"broadcast\" and ".
  "machine.mode!=\"dynamic\" AND NOT FIND_IN_SET('suspend', machine.flags) ".
  "AND machine.ip_address != 0 ORDER BY machine.host_name_zone");

if (!ref $machines) {
  &CMU::Netdb::netdb_mail('dns.pl', 'Error from list_machines: '.$machines, 'dns.pl error');
  exit -1;
}
my %MachMap = %{makemap($machines->[0])};
shift(@$machines);

my $revMachines = CMU::Netdb::list_machines_rv_zones($dbh, $USER,
  "machine.mode != \"base\" AND machine.mode != \"broadcast\" AND ".
  "machine.mode != \"dynamic\" AND NOT FIND_IN_SET('suspend', machine.flags) ".
  "AND machine.ip_address != 0 ORDER BY machine.host_name_zone");
if (!ref $revMachines) {
  &CMU::Netdb::netdb::mail('dns.pl', 'Error from list_machines_rv_zones: '.
			  $machines, 'dns.pl error');
  exit -2;
}
my %MachRevMap = %{makemap($revMachines->[0])};
shift (@$revMachines);

my $resources = CMU::Netdb::list_dns_resource_zones($dbh, $USER, '1 ORDER BY dns_resource.name');
if (!ref $resources) {
  &CMU::Netdb::netdb_mail('dns.pl', 'Error from list_dns_resources: '.$machines, 'dns.pl error');
  exit -1;
}
my %ResMap = %{makemap($resources->[0])};
shift(@$resources);

## Config will be:
## Associative array of Server Hostname (all lower-case) to:
##  - associative array of view name to view contents
##    _default_ will be the "global" view (ie, not in a view() statement)
##   View Contents is simply the contents of the view block
## Load the config from the services file
my %KeyLoaded;
my ($rServerGroup, $rServerView, $rMachines, $rZones) = 
  load_services($SERVICES);

print "Machine data selected, creating hashes\n";
# First create a hash of hostname to IP address, as well as for the TTL and the
# reverse zone info
my %hostIP;
my %IPhost;
#my %hostRevTTL;
my %rev;
my %fwd;
my %hostFwTTL;
my %hostID;
my %mode;
my @map_pos = ($MachMap{'machine.ip_address_zone'},
	       $MachMap{'machine.host_name'},
	       $MachMap{'dns_zone.parent'},
	       $MachMap{'machine.ip_address'},
	       $MachMap{'machine.ip_address_ttl'},
	       $MachMap{'machine.host_name_ttl'},
	       $MachMap{'machine.id'},
	       $MachMap{'machine.mode'},
	       $MachMap{'machine.flags'});
my $MachCount = 0;
map {
  my ($rz, $hn, $fz, $ip, $fwttl, $id, $mode, $flags) = 
    ($_->[$map_pos[0]], $_->[$map_pos[1]], $_->[$map_pos[2]],
     long2dot($_->[$map_pos[3]]), $_->[$map_pos[5]],
     $_->[$map_pos[6]], $_->[$map_pos[7]], $_->[$map_pos[8]]);

  push(@{$fwd{$fz}}, $hn) unless (defined $hostIP{$hn} ||
				  $flags =~ /no_dnsfwd/);
#  push(@{$rev{$rz}}, $ip) unless (defined $IPhost{$ip} ||
#				  $flags =~ /no_dnsrev/);

  push(@{$hostIP{$hn}}, $ip);
#  push(@{$IPhost{$ip}}, $hn);

  $hostFwTTL{"${hn}_$ip"} = $fwttl;
  print "ERR " if ($id eq '') ;
  $hostID{"${hn}_$ip"} = $id;
  $mode{"${hn}_$ip"} = $mode;

  $MachCount++;

} @$machines;

## Reverse zones
@map_pos = ($MachRevMap{'dns_zone.parent'},
	    $MachRevMap{'machine.ip_address'},
	    $MachRevMap{'machine.flags'},
	    $MachRevMap{'machine.host_name'});

map {
  my ($rz, $ip, $flags, $hn) =
    ($_->[$map_pos[0]], long2dot($_->[$map_pos[1]]),
     $_->[$map_pos[2]], $_->[$map_pos[3]]);

  push(@{$rev{$rz}}, $ip) unless (defined $IPhost{$ip} ||
				   $flags =~ /no_dnsrev/);
  push(@{$IPhost{$ip}}, $hn);

} @$revMachines;

# Find the zone masters
# We ignore the multiple-master case. Probably should come up with some
# better solution, but this is only for the SOA field
print Data::Dumper->Dump([$rServerGroup],['Service Groups']) if ($options{'debug'} > 12);

my %zoneMasters;
foreach my $view (keys %$rServerGroup) {
  my $Master;
  foreach my $mach (keys %{$rServerGroup->{$view}->{'machines'}}) {
    if ($rServerGroup->{$view}->{'machines'}->{$mach}->{'type'} eq 'master') {
      $Master = $mach;
    }
  }
  next if (!$Master);
  foreach my $zone (keys %{$rServerGroup->{$view}->{'zones'}}) {
    $zoneMasters{$CANON_FUNC->($zone)} = $Master;
  }
}

if ($options{'debug'} > 0) {
  print "Zone Master servers:\n";
  foreach (sort keys %zoneMasters) {
    print "$_\t$zoneMasters{$_}\n";
  }
}

exit if ($options{'debug'} > 100);

# check for errors
my %alreadyGlued = (); # used to figure out when/if we need to 

print "Creating zones for $MachCount hosts.\n";

&dns_create_fw();
&dns_create_rv();
$dbh->disconnect();
system($NRHOME.'/bin/dns-xfer.pl') unless ($options{'debug'} > 0 ||
					   $options{'xfer'} == 0);

### Done!
exit(1);

sub dns_create_fw {
  $CMU::Netdb::dns_dhcp::debug = 2;
  $CMU::Netdb::primitives::debug = 2;
  my $fzones = list_dns_zones($dbh, $USER,'dns_zone.type="fw-toplevel" ORDER BY dns_zone.name');
  
  if (!ref $fzones) {
    &CMU::Netdb::admin_mail('dns.pl', 'Error from list_dns_zones: '.$fzones);
    exit -1;
  }
  %ZoneMap = %{makemap($fzones->[0])};
  shift(@$fzones);
  
  foreach (@$fzones) {
    my @fz = @{$_};

    my $name = $fz[$ZoneMap{'dns_zone.name'}];
    next if (scalar(@{$options{'zone'}}) > 0 && 
	     ! grep(/^$name$/i, @{$options{'zone'}}));

    if ($fz[$ZoneMap{'dns_zone.ddns_auth'}] =~ /ddns\:ena/) {
      dns_create_ddns_fw(\@fz) if ($ENABLE_DDNS);
    }
    dns_create_static_fw(\@fz) if ($ENABLE_STATIC);
  }
}

sub dns_create_rv {
  $CMU::Netdb::dns_dhcp::debug = 2;
  $CMU::Netdb::primitives::debug = 2;

  my $zones = CMU::Netdb::list_dns_zones($dbh, $USER, "dns_zone.type=\"rv-toplevel\" ORDER BY dns_zone.id");
  if (!ref $zones) {
    &CMU::Netdb::admin_mail('dns.pl', 'Error from list_dns_zones: '.$zones);
    exit -1;
  }
  %ZoneMap = %{makemap($zones->[0])};
  shift(@$zones);
  
  foreach (@$zones) {
    my @z = @{$_};

    my $name = $z[$ZoneMap{'dns_zone.name'}];
    next if (scalar(@{$options{'zone'}}) > 0 && 
	     ! grep(/$name/i, @{$options{'zone'}}));

    if ($z[$ZoneMap{'dns_zone.ddns_auth'}] =~ /ddns\:ena/) {
      dns_create_ddns_rv(\@z) if ($ENABLE_DDNS);
    }
    dns_create_static_rv(\@z) if ($ENABLE_STATIC);
  }
}

sub dns_create_static_rv {
  my ($RZ) = @_;

  my $NR = new DNS::NetRegZone;
  $NR->Set_Debug($options{'debug'});
  $NR->Set_CanonFunc($CANON_FUNC);

  my @z = @{$RZ};
  my %alreadyGlued = ();
  my $txtRec = '';
  my ($id, $name, $ttl) = ($z[$ZoneMap{'dns_zone.id'}],
			   $z[$ZoneMap{'dns_zone.name'}],
			   $z[$ZoneMap{'dns_zone.soa_default'}]);
  
  my $soa_host = $zoneMasters{$name};
  $soa_host = $z[$ZoneMap{'dns_zone.soa_host'}] if ($soa_host eq '');

  ## Parse the DDNS Authorization field -- needs to be done for static
  ## zones as well so that we can set keys that will eventually
  ## be used for dynamics
  my $DAuth = $z[$ZoneMap{'dns_zone.ddns_auth'}];
  my @dkey = split(/\s+/, $DAuth);
  my %AuthInfo;
  foreach(@dkey) {
    my ($a, $b) = split(/\:/, $_);
    $AuthInfo{$a} = $b;
  }

  if ($AuthInfo{txtkey} eq '') {
    $AuthInfo{txtkey} = `hostname`;
    chomp($AuthInfo{txtkey});
  }
  
  my @oldkeys = split(/\,/, $AuthInfo{otxtkey});

  $NR->Prepare($AuthInfo{txtkey}, \@oldkeys);
  
  open(ZONEFILE, ">$ZONEPATH/$name.zone");
  print ZONEFILE "\$TTL $ttl\n
;
; Zone $name\n
;
@\t\t\tIN\tSOA\t$soa_host. $z[$ZoneMap{'dns_zone.soa_email'}]. ( $z[$ZoneMap{'dns_zone.soa_serial'}] $z[$ZoneMap{'dns_zone.soa_refresh'}] $z[$ZoneMap{'dns_zone.soa_retry'}] $z[$ZoneMap{'dns_zone.soa_expire'}] $z[$ZoneMap{'dns_zone.soa_minimum'}] )\n\n";
  
  # non machine records go here
  #
  #  my $res = list_dns_resources($dbh, $USER, "dns_resource.name='$name' or dns_resource.name_zone=$z[0] ORDER BY dns_resource.name_zone, dns_resource.type, dns_resource.name");
  
  # Glue all records that match
  my $LastRecord;		# we can do this because the resources are ordered by name
  my $MoreGlue = '';
  
  foreach my $res (@$resources) {
    my $ResID = $res->[$ResMap{'dns_resource.id'}];
    next unless ($res->[$ResMap{'dns_resource.owner_type'}] eq 'machine' ||
		 $res->[$ResMap{'dns_resource.owner_type'}] eq 'dns_zone');
    if ($res->[$ResMap{'dns_resource.name'}] eq $name ||
	$res->[$ResMap{'dns_resource.name_zone'}] eq $id) {
      my $type = $res->[$ResMap{'dns_resource.type'}];
      my $rname = $res->[$ResMap{'dns_resource.rname'}];
      my $zname = $res->[$ResMap{'dns_resource.name'}];
      $zname .= ".";
      my $Fzname = $zname;
      $zname =~ s/$name//;
      $zname =~ s/\.*$//;
      $zname = '@' if ($zname eq '');
      
      if ($zname eq $LastRecord) {
	print ZONEFILE "\t";
      }else{
	print ZONEFILE $CANON_FUNC->($zname);
      }
      $LastRecord = $zname;
     
      # check to see if default TTL is different from a specific record.
      # and if so include it.
      if($ttl != $res->[$ResMap{'dns_resource.ttl'}] && 
	 $res->[$ResMap{'dns_resource.ttl'}] != 0) {
	print ZONEFILE "\t$res->[$ResMap{'dns_resource.ttl'}]\tIN\t$type\t";
      } else {
	print ZONEFILE "\t\t\tIN\t$type\t";
      }
      
      my $RData = '';
      if ($type =~ /^(CNAME|NS)$/) {
	$RData = $CANON_FUNC->($rname.'.');
      } elsif ($type =~ /^(MX|AFSDB)$/) {
	$RData = "$res->[$ResMap{'dns_resource.rmetric0'}] $rname.";
      } elsif ($type =~ /^(TXT)$/) {
	$RData = "\"$res->[$ResMap{'dns_resource.text0'}]\"";
      } elsif ($type =~ /^(HINFO)$/) {
	$RData = "\"$res->[$ResMap{'dns_resource.text0'}]\" \"$res->[$ResMap{'dns_resource.text1'}]\"";
      } elsif ($type =~ /^(RP)$/) {
	  $RData = $CANON_FUNC->("$res->[$ResMap{'dns_resource.text0'}] $res->[$ResMap{'dns_resource.text1'}]");
      } elsif ($type =~ /^(SRV)$/) {
	$RData = "$res->[$ResMap{'dns_resource.rmetric0'}] ".
	  "$res->[$ResMap{'dns_resource.rmetric1'}] ".
	    "$res->[$ResMap{'dns_resource.rport'}] ".
	      "$rname.";
      } elsif ($type =~ /^(AAAA|LOC)$/) {
	$RData = $res->[$ResMap{'dns_resource.text0'}];
      }
      

      print ZONEFILE "\t$RData\n";

      $zname = '@' if ($type eq 'CNAME' || $type eq 'NS');
      $txtRec .= $CANON_FUNC->($zname);
      $txtRec .= "\tIN\tTXT\t".$NR->DDNS_Cons_TXT('NRDR', 'IN', $type, $RData, $ResID,
							$CANON_FUNC->($Fzname))."\n";

      ## additional glue
      ## no need for this glue.
      if ($type eq 'NS' && defined $alreadyGlued{$rname} ne '1' && 0) {
	$LastRecord = '';
	if (!defined $hostIP{$rname}) {
	  ## This is a big error, so email admins. 
	  ## FIXME: Should we abort?
	  &CMU::Netdb::netdb_mail('dns.pl', "Error gluing $rname!", 'dns.pl error');
	}else{
  	  $MoreGlue .= $CANON_FUNC->($rname).".\tIN\tA\t".$hostIP{$rname}->[0]."\n";
        }
	$alreadyGlued{$rname} = 1;
      }
    }
  }
  print ZONEFILE $MoreGlue;
  
  my %rmap = ();
  my $zoneIPPortion = $name;
  $zoneIPPortion =~ s/.in-addr.arpa//i;
  $zoneIPPortion = join('.', reverse(split(/\./, $zoneIPPortion)));

  foreach my $IP (@{$rev{$id}}) {
    my ($a, $b, $c, $d) = split(/\./, $IP);
    my $IPName = "$d.$c.$b.$a.in-addr.arpa";
    $IPName =~ s/$name//i;
    $IPName =~ s/\.*$//;

    foreach my $hn (@{$IPhost{$IP}}) {
      if (defined $rmap{$IPName}) {
	print ZONEFILE "; NOTE - DUPLICATE IP $a.$b.$c.$d for $hn!\n".
	  $CANON_FUNC->($IPName)."\t\t\tIN\tPTR\t$hn.\n";
	$txtRec .= $CANON_FUNC->($IPName)."\t\t\tIN\tTXT\t".
	  $NR->DDNS_Cons_TXT('NRMR', 'IN', 'PTR', "$hn.", 
			     $hostID{"${hn}_$IP"},
			     $CANON_FUNC->($IPName.".$name."))."\n";
	next;
      }
      $rmap{$IPName} = $hn;
    }
  }   ## $hostID{"${hn}_$ip"} = $id;
  foreach my $Rec (sort {$a <=> $b} keys %rmap) {
    my $RRec = join('.', reverse(split(/\./, $Rec)));
    print ZONEFILE $CANON_FUNC->($Rec)."\t\t\tIN\tPTR\t$rmap{$Rec}.\n";
    $txtRec .= "$Rec\t\t\tIN\tTXT\t".
      $NR->DDNS_Cons_TXT('NRMR', 'IN', 'PTR', $rmap{$Rec}.'.', 
			 $hostID{"$rmap{$Rec}_$zoneIPPortion.$RRec"}, 
			 $Rec.".$name.")."\n";
  }
  print ZONEFILE ";\n; NetReg TXT records\n$txtRec\n";
  
  close(ZONEFILE);
}
  
sub dns_create_ddns_rv {
  my ($RZ) = @_;
  
  my $NR = new DNS::NetRegZone;
  $NR->Set_CanonFunc($CANON_FUNC);

  my @z = @{$RZ};
  my %alreadyGlued = ();
  my $txtRec = '';
  my ($id, $name, $ttl) = ($z[$ZoneMap{'dns_zone.id'}],
			   $z[$ZoneMap{'dns_zone.name'}],
			   $z[$ZoneMap{'dns_zone.soa_default'}]);
  
  my $soa_host = $zoneMasters{$name};
  $soa_host = $z[$ZoneMap{'dns_zone.soa_host'}] if ($soa_host eq '');
  
  ## Parse the DDNS Authorization field
  my $DAuth = $z[$ZoneMap{'dns_zone.ddns_auth'}];
  my @dkey = split(/\s+/, $DAuth);
  my %AuthInfo;
  foreach(@dkey) {
    my ($a, $b) = split(/\:/, $_);
    $AuthInfo{$a} = $b;

  }

  if ($AuthInfo{txtkey} eq '') {
    $AuthInfo{txtkey} = `hostname`;
    chomp($AuthInfo{txtkey});
  }

  my @oldkeys = split(/\,/, $AuthInfo{otxtkey});
  
  ## Load the zone via dig
  $NR->Prepare($AuthInfo{txtkey}, \@oldkeys);
  $NR->Set_Zone_Dig($CANON_FUNC->($name), $soa_host, $ttl);
  
  ## Add DNS Resources  
  foreach my $res (@$resources) {
    my $ResID = $res->[$ResMap{'dns_resource.id'}];
    next unless ($res->[$ResMap{'dns_resource.owner_type'}] eq 'machine' ||
		 $res->[$ResMap{'dns_resource.owner_type'}] eq 'dns_zone');
    if ($res->[$ResMap{'dns_resource.name'}] eq $name ||
	$res->[$ResMap{'dns_resource.name_zone'}] eq $id) {
      my $type = $res->[$ResMap{'dns_resource.type'}];
      my $rname = $res->[$ResMap{'dns_resource.rname'}];
      my $zname = $res->[$ResMap{'dns_resource.name'}];
      $zname .= ".";
      my $Fzname = $zname;
      my $RData = '';
      if ($type =~ /^(CNAME|NS)$/) {
	$RData = $CANON_FUNC->($rname.'.');
      } elsif ($type =~ /^(MX|AFSDB)$/) {
	$RData = "$res->[$ResMap{'dns_resource.rmetric0'}] $rname.";
      } elsif ($type =~ /^(TXT)$/) {
	$RData = "\"$res->[$ResMap{'dns_resource.text0'}]\"";
      } elsif ($type =~ /^(HINFO)$/) {
	$RData = "\"$res->[$ResMap{'dns_resource.text0'}]\" \"$res->[$ResMap{'dns_resource.text1'}]\"";
      } elsif ($type =~ /^(RP)$/) {
	  $RData = $CANON_FUNC->("$res->[$ResMap{'dns_resource.text0'}] $res->[$ResMap{'dns_resource.text1'}]");
      } elsif ($type =~ /^(SRV)$/) {
        $RData = "$res->[$ResMap{'dns_resource.rmetric0'}] ".
          "$res->[$ResMap{'dns_resource.rmetric1'}] ".
            "$res->[$ResMap{'dns_resource.rport'}] ".
              "$rname.";
      } elsif ($type =~ /^(AAAA|LOC)$/) {
	$RData = $res->[$ResMap{'dns_resource.text0'}];
      } else {
	$RData = $rname;
      }
      
      my $ttlval = $res->[$ResMap{'dns_resource.ttl'}];
      $ttlval = $ttl if ($ttlval eq '' || $ttlval eq '0');

      $NR->CheckAndAdd($CANON_FUNC->($zname), $ttlval, 'IN', $type,
		       $RData, 'NRDR', $ResID);
    }
  }

  my %rmap = ();
  my $zoneIPPortion = $name;
  $zoneIPPortion =~ s/.in-addr.arpa//i;
  $zoneIPPortion = join('.', reverse(split(/\./, $zoneIPPortion)));

  foreach my $IP (@{$rev{$id}}) {
    my ($a, $b, $c, $d) = split(/\./, $IP);
    my $IPName = "$d.$c.$b.$a.in-addr.arpa";
    $IPName =~ s/$name//i;
    $IPName =~ s/\.*$//;

    foreach my $hn (@{$IPhost{$IP}}) {
      my $hTTL = $hostFwTTL{"${hn}_$IP"};
      $hTTL = $ttl if ($hTTL eq '' || $hTTL == 0);
      next if ($mode{"${hn}_$IP"} eq 'pool' && !$UPD_POOLADDR);
      
      $NR->CheckAndAdd($CANON_FUNC->($IPName.".$name."), $hTTL, 'IN', 'PTR', 
			$CANON_FUNC->("${hn}."), 
		       'NRMR', $hostID{"${hn}_$IP"});
    }
  }  
  
  $NR->MarkDeletions();
  my ($Res, $ResTxt);
  unless ($options{'debug'} > 0) {
    if (defined $AuthInfo{"key/netreg"}) {
      ($Res, $ResTxt) = $NR->DDNS_NSUpdate(uc($name).".netreg", $AuthInfo{"key/netreg"}, \%zoneMasters);
    }elsif(defined $AuthInfo{"key"}) {
      ($Res, $ResTxt) = $NR->DDNS_NSUpdate(uc($name).".key", $AuthInfo{"key"}, \%zoneMasters);
    }else{
      &CMU::Netdb::netdb_mail('dns.pl', "Error: Zone $name has no authentication keys for ".
			      "NSUpdate!", "NSUpdate: No zone auth key!");
      return -1;
    }
  }else{
    $Res = 1;
  }

  ## No response 
  if ($Res == -100) {
    &CMU::Netdb::netdb_mail('dns.pl', "Error: Zone $name had no condition-coded response ".
			    "from nsupdate!\n\n$ResTxt", "NSUpdate: No c-c response!");
  }elsif($Res < 0) {
    &CMU::Netdb::netdb_mail('dns.pl', "Error: Zone $name could not NSUpdate!\n\n$ResTxt", 
			    "NSUpdate: Error $Res in updating!");
  }else{
    if ($ResTxt !~ /^\s*$/) {
      &CMU::Netdb::netdb_mail('dns.pl', "Success in updating: \n\n$ResTxt",
			      "NS_U: Success [$name]", '', $EMAIL) if ($EMAIL);
    }
    ## We're all good.
  }
}

sub dns_create_ddns_fw {
  my ($FZ) = @_;

  my $NR = new DNS::NetRegZone;
  $NR->Set_Debug($options{'debug'});
  $NR->Set_CanonFunc($CANON_FUNC);

  my %alreadyGlued = ();
  my $txtRec = '';
  my @fz = @{$FZ};
  my ($id, $name, $ttl) = ($fz[$ZoneMap{'dns_zone.id'}],
			   $fz[$ZoneMap{'dns_zone.name'}],
			   $fz[$ZoneMap{'dns_zone.soa_default'}]);

  my $soa_host = $zoneMasters{$name};
  $soa_host = $fz[$ZoneMap{'dns_zone.soa_host'}] if ($soa_host eq '');

  ## Parse the DDNS Authorization field
  my $DAuth = $fz[$ZoneMap{'dns_zone.ddns_auth'}];
  my @dkey = split(/\s+/, $DAuth);
  my %AuthInfo;
  warn "Zone Auth field for $name is $DAuth" if ($options{'debug'});
  foreach(@dkey) {
    warn "Parsing individual key: '$_'" if ($options{'debug'});
    my ($a, $b) = split(/\:/, $_);
    $AuthInfo{$a} = $b;
  }

  if ($AuthInfo{txtkey} eq '') {
    warn "No txtkey for $name found!";
    $AuthInfo{txtkey} = `hostname`;
    chomp($AuthInfo{txtkey});
  }

  my @oldkeys = split(/\,/, $AuthInfo{otxtkey});

  ## Load the zone via dig
  $NR->Prepare($AuthInfo{txtkey}, \@oldkeys);
  $NR->Set_Zone_Dig($CANON_FUNC->($name), $soa_host, $ttl);
  
  ## Add DNS Resources
  foreach my $res (@$resources) {
    my $ResID = $res->[$ResMap{'dns_resource.id'}];
    next unless ($res->[$ResMap{'dns_resource.owner_type'}] eq 'machine' ||
		 $res->[$ResMap{'dns_resource.owner_type'}] eq 'dns_zone');
    if ($res->[$ResMap{'dns_resource.name'}] eq $name ||
	$res->[$ResMap{'dns_zone.parent'}] eq $id) {
      my $type = $res->[$ResMap{'dns_resource.type'}];
      my $rname = $res->[$ResMap{'dns_resource.rname'}];
      my $zname = $CANON_FUNC->($res->[$ResMap{'dns_resource.name'}]);
      my $Fzname = $zname;
      $zname .= ".";
     
      ### no data for this record is printed until AFTER this point
      if ($type eq 'ANAME') {
        # Verify we have an IP for the rname entry.  (No IP == Suspended host?)
	next unless (defined $hostIP{$rname});

	push(@{$fwd{$id}}, $Fzname) unless (defined $hostIP{$Fzname});

        # Copy the rname's IP to this name
 	push(@{$hostIP{$Fzname}}, @{$hostIP{$rname}});

        foreach my $ip (@{$hostIP{$rname}}) {
          $hostID{"${Fzname}_$ip"} = "AN-$ResID";
          $hostFwTTL{"${Fzname}_$ip"} = $res->[$ResMap{'dns_resource.ttl'}];
        }
	next;
      }

      if ($zname eq $name && $type eq 'CNAME') {
	# in this case, we MUST have an A record for this, even though it's
	# defined as a CNAME; to follow RFCs. We'll skip it if we don't have
	# the machine in netreg
	if (!defined $hostIP{$rname}) {
	  &CMU::Netdb::admin_mail('dns.pl', "CNAME -> A rec converstion failed for $rname");
	  next;
	}

	my $ttlval = $res->[$ResMap{'dns_resource.ttl'}];
	$ttlval = $ttl if ($ttlval eq '' || $ttlval eq '0');
	$NR->CheckAndAdd($CANON_FUNC->($zname), $ttlval, 'IN', 'A',
			 $hostIP{$rname}->[0], 'NRCA', $ResID);
	next;
      }


      # fr[3] - rtype (one of CNAME, MX, NS, SRV, TXT, HINFO, AFSDB, RP)
      # fr[4] - rname (CNAME, MX, NS, SRV, AFSDB)
      # fr[5] - rmetric0 (SRV, MX, AFSDB)
      # fr[6] - rmetric1 (SRV) 
      # fr[7] - rport (SRV)
      # fr[8] - text0 (HINFO, TXT, AAAA, LOC, RP)
      # fr[9] - text1 (HINFO, RP)
	
      my $RData;
      if($type =~ /^(CNAME|NS)$/) {
	$RData = $CANON_FUNC->($rname.'.');
      } elsif ($type =~ /^(MX|AFSDB)$/) {
	$RData = $CANON_FUNC->("$res->[$ResMap{'dns_resource.rmetric0'}] $rname.");
      } elsif ($type =~ /^(TXT)$/) {
	$RData = "\"$res->[$ResMap{'dns_resource.text0'}]\"";
      } elsif ($type =~ /^(HINFO)$/) {
	$RData = $CANON_FUNC->("\"$res->[$ResMap{'dns_resource.text0'}]\" \"$res->[$ResMap{'dns_resource.text1'}]\"");
      } elsif ($type =~ /^(RP)$/) {
	$RData = $CANON_FUNC->("$res->[$ResMap{'dns_resource.text0'}] $res->[$ResMap{'dns_resource.text1'}]");
      } elsif ($type =~ /^(SRV)$/) {
        $RData = "$res->[$ResMap{'dns_resource.rmetric0'}] ".
          "$res->[$ResMap{'dns_resource.rmetric1'}] ".
            "$res->[$ResMap{'dns_resource.rport'}] ".
              "$rname.";
      } elsif ($type =~ /^(AAAA|LOC)$/) {
	$RData = $res->[$ResMap{'dns_resource.text0'}];
      } else {
	$RData = $rname;
      }

      my $ttlval = $res->[$ResMap{'dns_resource.ttl'}];
      $ttlval = $ttl if ($ttlval eq '' || $ttlval eq '0');
      $NR->CheckAndAdd($CANON_FUNC->($zname), $ttlval, 'IN', $type,
		       $RData, 'NRDR', $ResID);
     	
      ## additional glue
      ## Nameserver: $rname (NOT CANONICALIZED)
      ## Resource: $Fzname (CANONICALIZED)
      ## Zone: $name (NOT CANONICALIZED)
      ## Add iff: - type is NS, 
      ##          - we haven't already added glue for this nameserver ($rname)
      ##          - if the nameserver ($rname) is beneath the resource name ($Fzname)
      ##          - name != $Fzname
      ## only glue records below this zone
      if ($type eq 'NS' && defined $alreadyGlued{$rname} ne '1' &&
         $rname =~ /$Fzname$/i && ($Fzname ne $CANON_FUNC->($name))) {
       if (!defined $hostIP{$rname}) {
         ## This is a big error, so email admins. 
         ## FIXME: Should we abort?
         &CMU::Netdb::netdb_mail('dns.pl', "Error glueing $rname, no IP known!", 'dns.pl error');
       }else{
         $NR->CheckAndAdd($CANON_FUNC->($rname).'.', $ttlval, 'IN', 'A', $hostIP{$rname}->[0], 'NRGR', $ResID);
        }
       $alreadyGlued{$rname} = 1;
      }
 
    }
  }		    
  
  # A records

  my $hn;
  my $txtKey;
  foreach my $host (@{$fwd{$id}}) {
    $hn = $host.".";
    my $ttlval = $hostFwTTL{"${host}_$hostIP{$host}->[0]"};
    $ttlval = $ttl if ($ttlval eq '' || $ttlval == 0);
    my $hostID = -1;
    @{$hostIP{$host}} = CMU::Netdb::helper::unique(@{$hostIP{$host}});

    if ($#{$hostIP{$host}} == 0) {
      $hostID = $hostID{"${host}_$hostIP{$host}->[0]"};
      next if ($mode{"${host}_$hostIP{$host}->[0]"} eq 'pool' && !$UPD_POOLADDR);

      $txtKey = ($hostID =~ /^AN/ ? 'NRDR' : 'NRMR');
      $NR->CheckAndAdd($CANON_FUNC->($hn), $ttlval, 'IN', 'A', $hostIP{$host}->[0], 
		       $txtKey, $hostID);
    }else{
      $hostID = $hostID{"${host}_$hostIP{$host}->[0]"};
      next if ($mode{"${host}_$hostIP{$host}->[0]"} eq 'pool' && !$UPD_POOLADDR);
      
      $txtKey = ($hostID =~ /^AN/ ? 'NRDR' : 'NRMR');
      $NR->CheckAndAdd($CANON_FUNC->($hn), $ttlval, 'IN', 'A', $hostIP{$host}->[0], 
		       $txtKey, $hostID);

      shift(@{$hostIP{$host}});
      map { 
	my $ip = $_;
	$ttlval = $hostFwTTL{"${host}_$ip"};
	$ttlval = $ttl if ($ttlval eq '' || $ttlval == 0);
	$hostID = $hostID{"${host}_$ip"};
	next if ($mode{"${host}_$ip"} eq 'pool' && !$UPD_POOLADDR);

	$NR->CheckAndAdd($CANON_FUNC->($hn), $ttlval, 'IN', 'A', $ip, 'NRMR', $hostID);
      } @{$hostIP{$host}};
      
    }
  }
  $NR->MarkDeletions();
  my ($Res, $ResTxt);
  unless ($options{'debug'} > 0) {
    if (defined $AuthInfo{"key/netreg"}) {
      ($Res, $ResTxt) = $NR->DDNS_NSUpdate(uc($name).".netreg", $AuthInfo{"key/netreg"}, \%zoneMasters);
    }elsif(defined $AuthInfo{"key"}) {
      ($Res, $ResTxt) = $NR->DDNS_NSUpdate(uc($name).".key", $AuthInfo{"key"}, \%zoneMasters);
    }else{
      &CMU::Netdb::netdb_mail('dns.pl', "Error: Zone $name has no authentication keys for ".
			      "NSUpdate!", "NSUpdate: No zone auth key!");
      return -1;
    }
  }else{
    $Res = 1;
  }

  ## No response 
  if ($Res == -100) {
    &CMU::Netdb::netdb_mail('dns.pl', "Error: Zone $name had no condition-coded response ".
			    "from nsupdate!\n\n$ResTxt", "NSUpdate: No c-c response!");
  }elsif($Res < 0) {
    &CMU::Netdb::netdb_mail('dns.pl', "Error: Zone $name could not NSUpdate!\n\n$ResTxt", 
			    "NSUpdate: Error $Res in updating!");
  }else{
    if ($ResTxt !~ /^\s*$/) {
      &CMU::Netdb::netdb_mail('dns.pl', "Success in updating: \n\n$ResTxt",
			      "NS_U: Success [$name]", '', $EMAIL) if ($EMAIL);
    }
    ## We're all good.
  }
}

sub dns_create_static_fw {
  my ($FZ) = @_;

  my $NR = new DNS::NetRegZone;
  $NR->Set_Debug($options{'debug'});
  $NR->Set_CanonFunc($CANON_FUNC);

  my %alreadyGlued = ();
  my $txtRec = '';
  my @fz = @{$FZ};
  my ($id, $name, $ttl) = ($fz[$ZoneMap{'dns_zone.id'}],
			   $fz[$ZoneMap{'dns_zone.name'}],
			   $fz[$ZoneMap{'dns_zone.soa_default'}]);
  my $soa_host = $zoneMasters{$name};
  $soa_host = $fz[$ZoneMap{'dns_zone.soa_host'}] if ($soa_host eq '');
  
  ## Parse the DDNS Authorization field -- needs to be done for static
  ## zones as well so that we can set keys that will eventually
  ## be used for dynamics
  my $DAuth = $fz[$ZoneMap{'dns_zone.ddns_auth'}];
  my @dkey = split(/\s+/, $DAuth);
  my %AuthInfo;
  foreach(@dkey) {
    my ($a, $b) = split(/\:/, $_);
    $AuthInfo{$a} = $b;
  }

  if ($AuthInfo{txtkey} eq '') {
    $AuthInfo{txtkey} = `hostname`;
    chomp($AuthInfo{txtkey});
  }

  my @oldkeys = split(/\,/, $AuthInfo{otxtkey});

  $NR->Prepare($AuthInfo{txtkey}, \@oldkeys);
  
  open(ZONEFILE, ">$ZONEPATH/$name.zone");
  print ZONEFILE "\$TTL $ttl\n
;
; Zone $name
;
@\t\t\tIN\tSOA\t$soa_host. $fz[$ZoneMap{'dns_zone.soa_email'}]. ( $fz[$ZoneMap{'dns_zone.soa_serial'}] $fz[$ZoneMap{'dns_zone.soa_refresh'}] $fz[$ZoneMap{'dns_zone.soa_retry'}] $fz[$ZoneMap{'dns_zone.soa_expire'}] $fz[$ZoneMap{'dns_zone.soa_minimum'}] )\n\n";
  
  my $MoreGlue = '';
  my $LastRecord;
  foreach my $res (@$resources) {
    my $ResID = $res->[$ResMap{'dns_resource.id'}];
    next unless ($res->[$ResMap{'dns_resource.owner_type'}] eq 'machine' ||
		 $res->[$ResMap{'dns_resource.owner_type'}] eq 'dns_zone');
    if ($res->[$ResMap{'dns_resource.name'}] eq $name ||
	$res->[$ResMap{'dns_zone.parent'}] eq $id) {
      
      my $type = $res->[$ResMap{'dns_resource.type'}];
      my $rname = $res->[$ResMap{'dns_resource.rname'}];
      my $zname = $res->[$ResMap{'dns_resource.name'}];
      my $Fzname = $zname;
      $zname .= ".";

      $zname =~ s/$name//;
      $zname =~ s/\.*$//;
      $zname = '@' if ($zname eq '' && $type ne 'CNAME');
     
	### no data for this record is printed until AFTER this point
      if ($type eq 'ANAME') {
	push(@{$fwd{$id}}, $Fzname) unless (defined $hostIP{$Fzname});
	unless (ref $hostIP{$rname} eq 'ARRAY') {
		&CMU::Netdb::netdb_mail('dns.pl', "ANAME processing, can't find IP for $rname !", "ANAME $rname error");
		next;
	}

        # Copy the rname's IP to this name
 	push(@{$hostIP{$Fzname}}, @{$hostIP{$rname}});

	foreach my $ip (@{$hostIP{$rname}}) {
          $hostID{"${Fzname}_$ip"} = "AN-$ResID";
          $hostFwTTL{"${Fzname}_$ip"} = $res->[$ResMap{'dns_resource.ttl'}];
        }
	next;
      }

      if ($zname eq '' && $type eq 'CNAME') {
	# in this case, we MUST have an A record for this, even though it's
	# defined as a CNAME; to follow RFCs. We'll skip it if we don't have
	# the machine in netreg
	if (!defined $hostIP{$rname}) {
	  &CMU::Netdb::netdb_mail('dns.pl', "CNAME -> A rec converstion failed for $rname", 'dns.pl error');
	  next;
	}

      # non standard TTLs
	if ($ttl != $res->[$ResMap{'dns_resource.ttl'}] && 
	    $res->[$ResMap{'dns_resource.ttl'}] != 0) {
	  print ZONEFILE "@\t$res->[$ResMap{'dns_resource.ttl'}]\tIN\tA\t$hostIP{$rname}->[0]\n";
	  $txtRec .= "@\tIN\tTXT\t".$NR->DDNS_Cons_TXT('NRCA', 'IN', 'A', 
						       $hostIP{$rname}->[0], $ResID,
						       $CANON_FUNC->($Fzname.'.'))."\n";
	}else{
	  print ZONEFILE "@\t\t\tIN\tA\t$hostIP{$rname}->[0]\n";
	  $txtRec .= "@\tIN\tTXT\t".$NR->DDNS_Cons_TXT('NRCA', 'IN', 'A', 
						       $hostIP{$rname}->[0], $ResID,
						       $CANON_FUNC->($Fzname.'.'))."\n";
	}
	next;
      }

      if ($zname eq $LastRecord) {
	print ZONEFILE "\t";
      }else{
	print ZONEFILE $CANON_FUNC->($zname);
      }
      $LastRecord = $zname;

      # check to see if default TTL is different from a specific record.
      # and if so include it.
      if ($ttl != $res->[$ResMap{'dns_resource.ttl'}] && 
	 $res->[$ResMap{'dns_resource.ttl'}] != 0) {
	print ZONEFILE "\t$res->[$ResMap{'dns_resource.ttl'}]\tIN\t$type\t";
      } else {
	print ZONEFILE "\t\t\tIN\t$type\t";
      }
      # fr[3] - rtype (one of CNAME, MX, NS, SRV, TXT, HINFO, AFSDB, RP)
      # fr[4] - rname (CNAME, MX, NS, SRV, AFSDB)
      # fr[5] - rmetric0 (SRV, MX, AFSDB)
      # fr[6] - rmetric1 (SRV) 
      # fr[7] - rport (SRV)
      # fr[8] - text0 (HINFO, TXT, RP)
      # fr[9] - text1 (HINFO, RP)
	
      my $RData;
      if($type =~ /^(CNAME|NS)$/) {
	$RData = $CANON_FUNC->($rname.'.');
      } elsif ($type =~ /^(MX|AFSDB)$/) {
	$RData = "$res->[$ResMap{'dns_resource.rmetric0'}] $rname.";
      } elsif ($type =~ /^(TXT)$/) {
	$RData = "\"$res->[$ResMap{'dns_resource.text0'}]\"";
      } elsif ($type =~ /^(HINFO)$/) {
	$RData = "\"$res->[$ResMap{'dns_resource.text0'}]\" \"$res->[$ResMap{'dns_resource.text1'}]\"";
      } elsif ($type =~ /^(RP)$/) {
        $RData = $CANON_FUNC->("$res->[$ResMap{'dns_resource.text0'}] $res->[$ResMap{'dns_resource.text1'}]");
      } elsif ($type =~ /^(SRV)$/) {
        $RData = "$res->[$ResMap{'dns_resource.rmetric0'}] ".
          "$res->[$ResMap{'dns_resource.rmetric1'}] ".
            "$res->[$ResMap{'dns_resource.rport'}] ".
              "$rname.";
      } elsif ($type =~ /^(AAAA|LOC)$/) {
	$RData = $res->[$ResMap{'dns_resource.text0'}];
      }
      
      print ZONEFILE "\t$RData\n";

      $zname = "_DZ-$zname" if ($type eq 'CNAME' || $type eq 'NS');
      $txtRec .= $CANON_FUNC->($zname);

      $txtRec .= "\tIN\tTXT\t".$NR->DDNS_Cons_TXT('NRDR', 'IN', $type, $RData, $ResID,
						  $CANON_FUNC->($Fzname.'.'))."\n";
      
      ## additional glue
      ## only glue records below this zone
      if ($type eq 'NS' && defined $alreadyGlued{$rname} ne '1' &&
	  $rname =~ /$Fzname$/i) {
	$LastRecord = '';
	if (!defined $hostIP{$rname}) {
	  ## This is a big error, so email admins.
	  ## FIXME: Should we abort?
	  &CMU::Netdb::netdb_mail('dns.pl', "Error glueing $rname!", 'dns.pl error');
	}else{
  	  $MoreGlue .= $CANON_FUNC->($rname).".\tIN\tA\t".$hostIP{$rname}->[0]."\n";
        }
	$alreadyGlued{$rname} = 1;
      }
    }
  }		    
  
  print ZONEFILE $MoreGlue;
  
  # A records

  my $hn;
  foreach my $host (@{$fwd{$id}}) {
    $hn = $host.".";
    $hn =~ s/$name//;
    $hn =~ s/\.*$//;
    $hn = '@' if ($hn eq '');
    $hn = $CANON_FUNC->($hn);
    my $ttlval = $hostFwTTL{"${host}_$hostIP{$host}->[0]"};
    my $hostID = -1;
    $ttlval = '' if ($ttlval eq $ttl || $ttlval == 0);
    @{$hostIP{$host}} = CMU::Netdb::helper::unique(@{$hostIP{$host}});

    if ($#{$hostIP{$host}} == 0) {
      $hostID = $hostID{"${host}_$hostIP{$host}->[0]"};
      print ZONEFILE "$hn\t\t$ttlval\tIN\tA\t$hostIP{$host}->[0]\n";
      $txtRec .= "$hn\tIN\tTXT\t".$NR->DDNS_Cons_TXT('NRMR', 'IN', 'A',
						     $hostIP{$host}->[0], $hostID,
						     $host.'.')."\n";
    }else{
      $hostID = $hostID{"${host}_$hostIP{$host}->[0]"};
      print ZONEFILE "$hn\t\t$ttlval\tIN\tA\t$hostIP{$host}->[0]\n";
      $txtRec .= "$hn\tIN\tTXT\t".$NR->DDNS_Cons_TXT('NRMR', 'IN', 'A',
						     $hostIP{$host}->[0], $hostID, $host.'.')."\n";
      shift(@{$hostIP{$host}});
      map { 
	my $ip = $_;
	$ttlval = $hostFwTTL{"${host}_$ip"};
	$hostID = $hostID{"${host}_$ip"};
	$ttlval = '' if ($ttlval eq $ttl || $ttlval == 0);
	print ZONEFILE "\t\t\t$ttlval\tIN\tA\t$ip\n";
	$txtRec .= "$hn\tIN\tTXT\t".$NR->DDNS_Cons_TXT('NRMR', 'IN', 'A',
						       $ip, $hostID, $host.'.')."\n";
	
      } @{$hostIP{$host}};
      
    }
  }
  print ZONEFILE ";\n; NetReg TXT records\n$txtRec\n";
  close(ZONEFILE);

}

# Load the services.sif file. 
sub load_services {
  my ($File) = @_;

  # These are the returned structures
  my %ServerGroup;
  my %ServerView;
  my %Machines;
  my %Zones;

  open(FILE, $File) || die("Cannot open services file: $File\n");
  my ($depth, $loc, $SName, $SType,$MType,$MName) = (0,0,'','','','');
  %KeyLoaded = ();

  while(my $line = <FILE>) {
    if ($depth == 0) {

      ## Look for service definitions
      if ($line =~ /service\s+\"([^\"]+)\"\s+type\s+\"([^\"]+)\"\s*\{/) {
	($SName, $SType) = ($1, $2);
	$depth++;
	if ($SType eq 'DNS Server Group') {
	  $loc = 1;
	  $ServerGroup{$SName} = {};
	  print "Defined Group $SName\n";
	}elsif($SType eq 'DNS View Definition') {
	  $loc = 2;
	  $ServerView{$SName} = {};
	}
	## Look for machine definitions
      }elsif($line =~ /machine\s+\"([^\"]+)\"\s*\{/) {
	$SName = $1;
	$depth++;
	$loc = 10;
	$SName = lc($SName);
	$Machines{$SName} = {};
	## Look for zone definitions
      }elsif($line =~ /dns_zone\s+\"([^\"]+)\"\s*\{/) {
	$SName = $1;
	$depth++;
	$loc = 15;
	$Zones{$SName} = {};
      }
    }elsif($depth == 1) {
      ## Look for attribute specifications
      if ($line =~ /attr\s*([^\=]+)\=\s*(.+)$/) {
	my ($AKey, $AVal) = ($1, $2);
	$AVal =~ s/\;$//;
	$AKey =~ s/\s*$//;
	
	if ($loc == 2 && $AKey eq 'Server Version') {
	  $ServerView{$SName}->{'version'} = $AVal;
	}elsif($loc == 2 && $AKey eq 'DNS Parameter') {
	  push(@{$ServerView{$SName}->{'params'}}, $AVal);
	}
	## Look for members of a service
      }elsif($line =~ /member\s*type\s*\"([^\"]+)\"\s*name\s*\"([^\"]+)\"/) {
	($MType, $MName) = ($1, $2);
	$depth++;
	
	if ($loc == 1 && $MType eq 'dns_zone') {
	  $ServerGroup{$SName}->{'zones'}->{$MName} = {};
	  $loc = 5;
	}elsif($loc == 1 && $MType eq 'service') {
	  $ServerGroup{$SName}->{'views'}->{$MName} = {};
	  $loc = 6;
	}elsif($loc == 1 && $MType eq 'machine') {
	  $MName = lc($MName);
	  $ServerGroup{$SName}->{'machines'}->{$MName} = {};
	  $loc = 7;
	}

      }elsif($loc == 10) {
	$line =~ s/\;$//;
	my @elem = split(/\s+/, $line);
	shift @elem while($elem[0] eq '');

	$Machines{$SName}->{$elem[0]} = $elem[1];
      }elsif($loc == 15) {
	$line =~ s/\;$//;
	my @elem = split(/\s+/, $line);
	shift @elem while($elem[0] eq '');
	my $Key = shift(@elem);
	my $Val = join(' ', @elem);

	$Zones{$SName}->{$Key} = $Val;
      }

      if ($line =~ /\}/ && $line !~ /\{/) {
	$depth--;
	$SName = '';
	$loc = 0;
      }
    }elsif($depth == 2) {
      if ($line =~ /attr\s*([^\=]+)\=\s*(.+)$/) {
	my ($AKey, $AVal) = ($1, $2);
	$AKey =~ s/\s*$//;
	$AVal =~ s/\;$//;
	$AVal =~ s/^\s+//;
	$AVal =~ s/\s+$//;

	if ($loc == 5 && $AKey eq 'Zone Parameter') {
	  push(@{$ServerGroup{$SName}->{'zones'}->{$MName}->{'params'}},
	       $AVal);
	}elsif($loc == 5 && $AKey eq 'Zone In View') {
	  print "pushing view $SName $MName $AVal\n";
	  push(@{$ServerGroup{$SName}->{'zones'}->{$MName}->{'views'}},
	       $AVal);
	}elsif($loc == 6 && $AKey eq 'Service View Name') {
	  $ServerGroup{$SName}->{'views'}->{$MName}->{'name'} = $AVal;
	}elsif($loc == 6 && $AKey eq 'Service View Order') {
	  $ServerGroup{$SName}->{'views'}->{$MName}->{'order'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Type') {
	  $ServerGroup{$SName}->{'machines'}->{$MName}->{'type'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Version') {
	  $ServerGroup{$SName}->{'machines'}->{$MName}->{'version'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Block Parameter') {
	  push(@{$ServerGroup{$SName}->{'server_blocks'}->{$MName}}, $AVal);
	}
      }

      if ($line =~ /\}/ && $line !~ /\{/) {
	$depth--;
	$loc = 1 if ($loc == 5 || $loc == 6 || $loc == 7);
	($MType, $MName) = ('', '');
      }
    }
  }
  close(FILE);

  return (\%ServerGroup, \%ServerView, \%Machines, \%Zones);
}

sub usage {
    print "dns.pl [-h] [options]\n";
    print "
\tOptions (defaults listed first when --no[x] applies)

\t--nodebug (--debug)         Changes output dir to /tmp/zone-gen, inc debug level
\t--xfer (--noxfer)           Run dns-xfer.pl to transfer zones/configs
\t--zone [zone]               Only generate [zone] (may be specified multiple times)
\t--only [zone]		      Only generate [zone] (specify once)
";
    exit(1);
}
 
