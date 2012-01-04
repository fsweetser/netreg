#!/usr/bin/perl
#  -*- perl -*-
#
# Copyright (c) 2003-2004 Carnegie Mellon University. All rights reserved.
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
#
# $Id: vlanUpdate.pl,v 1.10 2008/03/27 19:42:44 vitroth Exp $
#
#

use strict;
use lib '/usr/ng/lib/perl5';

use CMU::Netdb;
use CMU::Netdb::helper;
use CMU::Netdb::structure;

use CMU::NetConf::Manage3750;

use Data::Dumper;
use Getopt::Long;

## Global CDP OIDs
my $cdpINFOOID = ".1.3.6.1.4.1.9.9.23.1.2.1.1";
my $cdpIPOID = ".1.3.6.1.4.1.9.9.23.1.2.1.1.4.";
my $cdpPORTOID = ".1.3.6.1.4.1.9.9.23.1.2.1.1.7.";
my $switchIntNameOID = ".1.3.6.1.2.1.2.2.1.2";
my $debug = 0;

my ($trunksetName, $help, $noDoAction, $stopAndWait, $result, $host);
my ($verbose, $force);

Getopt::Long::Configure('no_ignore_case');

$noDoAction = 0;
$stopAndWait = 0;
$help = 0;
$verbose = 0;
$force = 0;


$result = GetOptions("T|tsname=s", \$trunksetName,
		     "R|dryrun" , \$noDoAction,
		     "S|stop" , \$stopAndWait,
		     "H|host=s" , \$host,
		     "d|debug=i", \$debug,
		     "v|verbose", \$verbose,
		     "f|force", \$force,
		     "h|help", \$help);

warn __FILE__ . ":" . __LINE__ . ": options are \n" . Data::Dumper->Dump([$trunksetName,
									  $noDoAction,
									  $stopAndWait,
									  $host,
									  $debug,
									  $help
									 ],[qw(
									       tsname
									       dryrun
									       stop
									       host
									       debug
									       help
									      )]) . "\n" if ($debug >= 1); 

usage() if ($help);
usage() if ($trunksetName eq '');


my ($dbh, $dbuser, $data, $rMap, $rData, $query);
my ($tID, $trVLAN, $vlanNumToName, $cdpMap, @devName);

$noDoAction = 0 if (! defined $noDoAction);

$dbh = lw_db_connect();
$dbuser = 'netreg';

$query = " trunk_set.name = \"$trunksetName\" ";
warn __FILE__ . ":" . __LINE__ . ": list_trunkset query is >>>==>$query\n" if ($debug >= 10);
$data = CMU::Netdb::vlan_trunkset::list_trunkset
	    ($dbh, $dbuser, $query, 'trunk_set.name');
print Dumper($data) if ($debug >= 10);

## Handle error condition. if data is empty, or undef
die "Can't get information about trunkset $trunksetName\n"
    if (!defined $data || $#$data < 1);

## TrunkSet information
$rMap = CMU::Netdb::makemap($data->[0]);
shift(@$data);
$tID = $data->[0]->[$rMap->{'trunk_set.id'}];

## VLAN information
$query = "trunkset_vlan_presence.trunk_set = \"$tID\"";
warn __FILE__ . ":" . __LINE__ . ": list_trunkset_presences(vlan) query is >>>==>$query\n" if ($debug >= 10);
$trVLAN = CMU::Netdb::list_trunkset_presences
		($dbh, $dbuser, 'vlan', $query);
$rMap = CMU::Netdb::makemap($trVLAN->[0]);
shift(@$trVLAN);
map { $vlanNumToName->{$_->[$rMap->{'vlan.number'}]} = $_->[$rMap->{'vlan.abbreviation'}] } @$trVLAN;
print Dumper($vlanNumToName) if ($debug >= 10);

## Device information
$query = "trunkset_machine_presence.trunk_set = \"$tID\"" . ((defined $host) && ($host ne '') ? " and host_name like \"$host\"" : "");
warn __FILE__ . ":" . __LINE__ . ": list_trunkset_presences(machine) query is >>>==>$query\n" if ($debug >= 10);
my $trDev = CMU::Netdb::list_trunkset_presences
		($dbh, $dbuser, 'machine', $query);
$rMap = CMU::Netdb::makemap($trDev->[0]);
shift(@$trDev);
@devName = map { $_->[$rMap->{'machine.host_name'}] } @$trDev;
print Dumper(\@devName) if ($debug >= 10);


## Make sure you have filter here with .sw.cmu.local
## Config File Format
## telnetlogin1		foo
## telnetlogin2		foo
## sshlogin1		foo
## sshlogin2		foo
## telnetenable1		foo
## telnetenable2		foo
## sshenable1		foo
## sshenable2		foo
## snmpro			foo

my ($ConfigFile, $password, %AuthInfo, %ConnectOpt);
$ConfigFile 	= '/home/netreg/etc/.passwd_ios';
$password 	= getConfig($ConfigFile);

%AuthInfo = ('login' => { 'telnet' => [{'password' => $password->{telnetlogin1}},
					  {'password' => $password->{telnetlogin2}},
					 ],
			      'ssh' => [{'password' => $password->{sshlogin1}},
					{'password' => $password->{sshlogin2}},
				       ],
			   },
		'enable' => { 'telnet' => [{'password' => $password->{telnetenable1}},
					   {'password' => $password->{telnetenable2}},
					  ],
			      'ssh' => [{'password' => $password->{sshenable1}},
					{'password' => $password->{sshenable2}},
				       ],
			     }
	    );
%ConnectOpt = ('ssh_opt' => '-a -x -o UserKnownHostsFile=/dev/null');

foreach my $dev (@devName) {
    next if (($dev !~ /sw\.cmu\.local/i) && ($dev !~ /switch\.net\.cmu\.local/i));

    if ($verbose) {
      warn "Processing $dev\n";
    }

    if ($stopAndWait) {
	print "[$dev] Proceed ? ";
	my $a = <STDIN>;
	next unless ($a =~ /y/i);
    }

    
    my ($devConn, $data, $res, $ref) = (undef, undef, undef, undef);

    my $devConn = CMU::NetConf::ManageIOS::connect_new($dev, undef, $debug, \%AuthInfo);
    print "" . Data::Dumper->Dump([$devConn],[qw(devConn)]) . "\n" if ($debug >= 1); 

    if (! ref $devConn) {
      warn __FILE__ . ":" . __LINE__ . ": Error connecting to $dev\n$devConn\n";
      next;
    }

    ($res, $ref) = $devConn->enable();
    if ($res < 1) {
	print "Unable to enable $dev, [$res] ($ref->{'err'})\n";
	next;
    }

    ## B'coz of the stupid LONG names of the switch, ManageIOS got confused.
    my $origPrompt = $devConn->{prompt};
    $devConn->{prompt} = "#";
    ($res, $ref) = $devConn->run_command("show vlan brief\n");
    $devConn->{prompt} = $origPrompt;
    print Dumper($ref) if ($debug >= 10);

    # parsing show vlan output
    my @parseData = split(/\n/,$ref->{data});
    my @localVLAN;
    foreach my $vl (@parseData) {
	push(@localVLAN,$1) 
	    if ($vl =~ /^(\d+).*/);
    }

    # Taking diff. If vlan does NOT exisit on switch but
    # does exist on trunkset/netreg.
    my $pushVlan;
    foreach my $trV (keys %$vlanNumToName) {
	$pushVlan->{$trV} = $vlanNumToName->{$trV}
	    if ((!grep /^$trV$/, @localVLAN) || $force)
    }
    print Dumper($pushVlan) if ($debug >= 10);


    my $cdpInfo = getCDPInfo($password, $dev);
    if (!defined $cdpInfo) {
	print "Unable to get CDP Info for $dev\n";
	next;
    }
    print Dumper($cdpInfo) if ($debug >= 10);

    my @interfaceChange;
    foreach my $pid (keys %$cdpInfo) {
	my $pt = $cdpInfo->{$pid}->{PORT};
	my $interface;
	if ($pt =~ /(.*)Ethernet(.*)/) {
	    my $type = $1;
	    my $rest = $2;
	    $interface->{'truncated-if'} = "Fa".$rest
		if ($type =~ /Fast/i);
	    $interface->{'truncated-if'} = "Gi".$rest
		if ($type =~ /Gig/i);
	    $interface->{'allowed-vlan-add'} = join(',', keys %$pushVlan);
	    push(@interfaceChange, $interface);
	}

    }

    my %vlanChange;
    foreach my $l (keys %{$pushVlan}) {
      $vlanChange{$l}{name} = $pushVlan->{$l};
    }
    
    my %global_config = ('change_global' => [{'vlans' =>\%vlanChange}]);

    my %int_config = ('change_interface' => \@interfaceChange);
    print Dumper(\%int_config) if ($debug >= 10);
    
    # Adding vlan to host
    if (scalar keys %$pushVlan > 0){

      warn "\nWould send following commands to $dev\n" if ($noDoAction);

      $res = $devConn->change_config(\%global_config, undef, $noDoAction);
      
      if ($noDoAction) {
	warn " configure terminal\n";
	foreach (keys %{$res}) {
	  warn " " . join(" ", @{$res->{$_}{'err'}}) . "\n";
	}
	warn " end\n";
	warn " write memory\n";
      } else {
	
	## writing to memory. Do I need this ?
	($res, $ref) = $devConn->run_command("write mem\n");
	
      }
      
      # Adding vlan to interface
      $res = $devConn->change_config(\%int_config, undef, $noDoAction);
      
      if ($noDoAction) {
	warn " configure terminal\n";
	foreach (keys %{$res}) {
	  warn " " . join(" ", @{$res->{$_}{'err'}}) . "\n";
	}
	warn " end\n";
	warn " write memory\n";
      } else {
	
	## writing to memory. Do I need this ?
	($res, $ref) = $devConn->run_command("write mem\n");
	
      }
    } else {
      warn "No vlan additions needed on $dev\n";
    }
    warn "\n" if ($noDoAction);
    
    $devConn->disconnect();

    buildCDPMap($dev, $cdpInfo);   

}

# warn __FILE__ . ":" . __LINE__ . ": " . Data::Dumper->Dump([$cdpMap],[qw(cdpMap)]) . "\n"; 

my ($errmsg, @err_msg);

foreach my $cN (keys %$cdpMap) {
  if ((length($cN)) && (!grep /^$cN$/, @devName)) {
    $errmsg = "$cN (CDP Neighbor of ";
    foreach (keys %{$cdpMap->{$cN}}) {
      $errmsg .=  "$_ on port(s) " . join(', ', @{$cdpMap->{$cN}{$_}});
    }
    $errmsg .= ") not present in " . (((defined $host) && ($host ne '')) ? "host list" : "TrunkSet" );
    push(@err_msg, $errmsg);
  }
}

if (scalar @err_msg) {
  print "The following hosts and interconnecting interfaces were not updated for listed reasons\nThis is probably not an error but is presented for informational purposes\n";
  print "" . join("\n", @err_msg) . "\n\n";
}


sub usage {
    print "Bulk Switch Configurator\n\n";

    print "\t-T (--tsname) <TRUNKSET_NAME> Name of the TrunkSet.\n";
    print "\t-R (--dryrun) Just runs through everything, except it will NOT change anything on switch\n";
    print "\t-S (--stop) Stop And Wait. It will ask your input for every device before pushing out configs.\n";
    print "\t-H (--host) only update this single host.\n";
    print "\t-v (--verbose) print device name as processing of device starts\n";
    print "\t-f (--force) Force all vlans in the trunkset to be added to all devices and trunks\n";
    print "\t-h (--help) Help\n";

    exit 1;
}

sub getConfig {
    my ($file) = @_;

    die "Password file $file does NOT exist\n" if (! -f $file);
    my $CT = new Config::General($file);
    my %UserConfig = $CT->getall;
    return \%UserConfig;
}

sub getCDPInfo {
    my ($passInfo, $dev) = @_;
    my ($cdpInfo, %walkres);
    %walkres = RyNetUtils::snmp_walk($dev, $passInfo->{snmpro}, $cdpINFOOID);
    $cdpInfo = undef;
    foreach my $id (keys %walkres) {
	if ($id =~ /$cdpIPOID/) {
	    my $val = uc(unpack("H12", $walkres{$id}));
	    $id =~ s/$cdpIPOID//;
	    $id =~ s/(\d+)\.\d+$/$1/;
	    $val =~ s/(..)(..)(..)(..)/(hex $1).".".(hex $2).".".(hex $3).".".(hex $4)/e;
	    $cdpInfo->{$id}->{IP} = $val;
	} elsif ($id =~ /$cdpPORTOID/) {
	    my $val = $walkres{$id};
	    $id =~ s/$cdpPORTOID//;
	    $id =~ s/(\d+)\.\d+$/$1/;
	    $cdpInfo->{$id}->{PORT} = $val;
	}
    }

    %walkres = RyNetUtils::snmp_walk($dev, $passInfo->{snmpro}, $switchIntNameOID);
    foreach my $id (keys %walkres) {
	my $val = $walkres{$id};
	$id =~ s/$switchIntNameOID\.//;
	$cdpInfo->{$id}->{PORT} = $val
	    if(defined $cdpInfo->{$id});
    }

    return $cdpInfo;
}

sub buildCDPMap {
    my ($dev, $cdpInfo) = @_;
    my ($neighbor);

    foreach my $id (keys %$cdpInfo) {
	my @oct = split(/\./, $cdpInfo->{$id}{IP});
	my $ip_num = pack("C4", @oct);
	$neighbor = uc((gethostbyaddr($ip_num,2))[0]);
	if (! defined $cdpMap->{$neighbor}{$dev}) {
	  $cdpMap->{$neighbor}{$dev} = [];	  
	}
	push(@{$cdpMap->{$neighbor}{$dev}}, $cdpInfo->{$id}{PORT});
    }
}
