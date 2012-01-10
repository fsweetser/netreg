#!/usr/bin/perl

# vi: set sw=2 ts=2:

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

# dns bind named.conf generator
# major rewrite 2010-01-21 by Gabriel Somlo
# based on orignal code by Kevin Miller (with minor patches by Dave Nolan)

use strict;
use Fcntl ':flock';

BEGIN {
	my @LPath = split(/\//, __FILE__);
	push(@INC, join('/', @LPath[0..$#LPath-1]));
	push(@INC, '/home/netreg/bin');
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::config;
use Data::Dumper;

my $DBUSER = "netreg";
my $debug = 0;

my ($SERVICES, $CONFDIR, $vres);

($vres, $SERVICES) =
	CMU::Netdb::config::get_multi_conf_var('netdb', 'SERVICE_COPY');
($vres, $CONFDIR) =
	CMU::Netdb::config::get_multi_conf_var('netdb', 'DNS_CONFPATH');

if ($ARGV[0] eq '-debug') {
	print "** Debug Mode Enabled**\n";
	$debug = 1;
	$SERVICES = '/tmp/services.sif';
	$CONFDIR = '/tmp/zones';
}

# Before we begin, delete all named.conf's from the confdir
unlink <$CONFDIR/named.conf*>;
unlink <$CONFDIR/dhcpd.conf.nsaux>;

# buffer warning messages to be emailed when script completes
my $WarningBuffer = '';

## Load the config from the services file
my ($rDNSSrvGrp, $rDNSSvrView, $rDNSZoneAuth, $rMachines, $rZones) =
	load_services($SERVICES);

# insure ddns/dhcp configs are created for only one master server for each zone
my %KeyLoaded;

print Data::Dumper->Dump([$rDNSSrvGrp], ['$rDNSSrvGrp']) if ($debug);
print Data::Dumper->Dump([$rDNSSvrView], ['$rDNSSvrView']) if ($debug);
print Data::Dumper->Dump([$rDNSZoneAuth], ['$rDNSZoneAuth']) if ($debug);
print Data::Dumper->Dump([$rMachines], ['$rMachines']) if ($debug);
print Data::Dumper->Dump([$rZones], ['$rZones']) if ($debug);

write_config($rDNSSrvGrp, $rDNSSvrView, $rDNSZoneAuth, $rMachines, $rZones);

if ($WarningBuffer ne '') {
	&CMU::Netdb::netdb_mail('dns-config.pl', $WarningBuffer,	
													'Warnings from dns-config.pl !');
}

exit(0);
## ****************************************************************************

sub write_config {
	my ($rDNSSrvGrp, $rDNSSvrView, $rDNSZoneAuth, $rMachines, $rZones) = @_;
	# rDNSSrvGrp is the list of service groups of type "DNS Server Group"
	# rDNSSvrView is the list of service groups of type "DNS View Definition"
	# rDNSZoneAuth is the list of service groups of type "DDNS_Zone_Auth"
	#		- machine members can to dynamically update zone members' master server
	#	  (global hash %KeyLoaded enforces limit of one ddns master per zone)
	# rMachines -- any machines that are members of any service groups
	#		- only used to resolve hostname -> ip addresses !
	# rZones -- any zones that are members of any service groups
	#		- only used for ddns_auth field, passed along to generate_ddns_keyacl()

	my $DHCP_DDNS;	# dynamic DNS config bits for the dhcp server(s)

	# build hash keyed by hosts for which we plan to generate a named.conf file
	# values are the list of server groups in which the host has a valid
	#  "Server Type" attribute (master, slave, forward, or stub) and
	#  a defined "Server Version".
	my %HGroups;
	foreach my $SG (keys %$rDNSSrvGrp) {
		foreach my $HN (keys %{$rDNSSrvGrp->{$SG}{'machines'}}) {
			if (defined $rDNSSrvGrp->{$SG}{'machines'}{$HN}{'version'} &&
					$rDNSSrvGrp->{$SG}{'machines'}{$HN}{'version'} ne '' &&
					defined $rDNSSrvGrp->{$SG}{'machines'}{$HN}{'type'} &&
					$rDNSSrvGrp->{$SG}{'machines'}{$HN}{'type'} ne 'none') {

				push(@{$HGroups{$HN}}, $SG);
			}
		}
	}

	print Data::Dumper->Dump([\%HGroups], ['\%HGroups']) if ($debug);

	# now generate a named.conf for each of the hosts:
	HOST_GEN_CONF:
	foreach my $HN (keys %HGroups) {

		print "\n\nWorking on $HN\n" if ($debug);

		my $ServerVersion = '';
		my $MaxOrder = 0;
		my %ViewOrder;
		my %GlobalOptions;	# global options from params of '_default_'/'global'
		my %ViewOptions;	# per-view options (non-default views only)
		my %ViewAddedBy;	# viewgroup/servergroup that created $VName
		my %SpecZonesOnly;	# true if 'Import Unspecified Zones' was explicitly
												#  set to 'no' on the view group which supplied $VName

		# iterate over all service groups containing $HN,
		#  verify server version consistency and
		#  collect any applicable views
		foreach my $SG (@{$HGroups{$HN}}) {

			# set $ServerVersion for $HN for the first time (if not already set)
			if ($ServerVersion eq '') {
				$ServerVersion = $rDNSSrvGrp->{$SG}{'machines'}{$HN}{'version'};
			}
			# complain loudly and skip $HN altogether if
			#  mismatched server versions across groups:
			if ($ServerVersion ne $rDNSSrvGrp->{$SG}{'machines'}{$HN}{'version'}) {
				warn_msg("Mismatched 'Server Version' for $HN in group $SG: ".
									"got $rDNSSrvGrp->{$SG}{'machines'}{$HN}{'version'}, ".
									"expected $ServerVersion; Skipping conf. gen. for $HN");
				next HOST_GEN_CONF;
			}

			print "Server $HN in $SG is $rDNSSrvGrp->{$SG}{'machines'}{$HN}{'type'}/".
						"$rDNSSrvGrp->{$SG}{'machines'}{$HN}{'version'}\n" if ($debug);

			# iterate over view groups in current $SG,
			#  and select the ones to be used for $HN's named.conf
			foreach my $VG (keys %{$rDNSSrvGrp->{$SG}{'views'}}) {

				# host and view versions must match;
				# view must have a 'name' attribute set in $SG
				next if ($rDNSSvrView->{$VG}{'version'} ne $ServerVersion ||
									$rDNSSrvGrp->{$SG}{'views'}{$VG}{'name'} eq '');

				my $VName = $rDNSSrvGrp->{$SG}{'views'}{$VG}{'name'};
				my $VOrder = $rDNSSrvGrp->{$SG}{'views'}{$VG}{'order'};	# undef == 0

				print "Adding view $VG named $VName ".
							"in group $SG, order $VOrder/$MaxOrder\n" if ($debug);

				if ($VName eq '_default_' || $VName eq 'global') {

					# '_default_' and 'global' are equivalent, and multiple view groups
					#  with those names may cumulatively contribute parameters to the
					#  global options sections of $HN's named.conf
					# also, ignore $VOrder, as 'global' must be last in named.conf
					map { $GlobalOptions{$_} = 1; } @{$rDNSSvrView->{$VG}{'params'}};

				} else {

					# only one non-default $VG may supply $VName per $HN (across all $SGs)
					if (defined $ViewAddedBy{$VName}) {
						warn_msg("View $VName already provided by view/service group ".
											"$ViewAddedBy{$VName}; Skipping $VG/$SG on host $HN");
						next;
					}
					$ViewAddedBy{$VName} = "$VG/$SG";
					# 'Import Unspecified Zones' explicitly disallowed on this view ?
					$SpecZonesOnly{$VName} = 1 if ($rDNSSvrView->{$VG}{'import'} eq 'no');
					# and use $VOrder to determine relative position $VName in named.conf
					$ViewOrder{$VName} = $VOrder;
					$MaxOrder = $VOrder if ($VOrder > $MaxOrder);
					# collect view attributes from view group
					map {
						$ViewOptions{$VName}->{$_} = 1;
					} @{$rDNSSvrView->{$VG}{'params'}};

				} # if ($VName eq '_default_' || 'global')

			} # foreach $VG (keys %{$rDNSSrvGrp->{$SG}{'views'}})

		} # foreach $SG (@{$HGroups{$HN}})

		# 'global' view goes last, using only global options and no restrictions;
		# undefined 'Import Unspecified Zones' will default to yes
		$ViewOrder{'global'} = $MaxOrder + 1;

		# server version set, consistent across groups, but not bind9
		if ($ServerVersion ne 'bind9') {
			warn_msg("Skipping config generation for $HN ".
								"(server version $ServerVersion != bind9)");
			next;
		}

		print "Generating config for $HN:\n" if ($debug);

		open(FILE, ">$CONFDIR/named.conf.$HN") ||
			die_msg("Cannot open $CONFDIR/named.conf.$HN for writing");

		# print out global named.conf options section:
		if (keys %GlobalOptions > 0) {
			print FILE "options {\n".
									join("\n", map { "\t$_;" } keys %GlobalOptions).
									"\n};\n\n";
		}

		## include local, host-specific configuration
		print FILE "include \"/usr/domain/etc/base.conf\";\n\n";

		print Data::Dumper->Dump([\%ViewOrder], ['$%ViewOrder']) if ($debug);
		print Data::Dumper->Dump([\%ViewAddedBy], ['$%ViewAddedBy']) if ($debug);

		# during the course of processing zones, we might generate keys and acls for
		# the zone master's config file, which need to get in before any views;
		# we buffer all zone/view related config bits, to be printed after any such
		# keys and ACLs have made it into named.conf
		my $BUFFER;

		# generate views in the appropriate order
		foreach my $VName
								(sort {$ViewOrder{$a} <=> $ViewOrder{$b}} keys %ViewOrder) {

			print "View $VName provided by $ViewAddedBy{$VName}\n" if ($debug);

			# opening 'view' block statement, and view-specific options:
			$BUFFER .= "view \"$VName\" {\n".
									join("\n",  map { "\t$_;" } keys %{$ViewOptions{$VName}}).
									"\n\n";

			# keep track of which $SG added each key zone to the current view
			my %ZoneAddedBy;

			# process zones from all of $HN's $SGs, and add them to $VName if
			#   $SpecZonesOnly{$VName} and the zone's 'Zone In View' attributes align
			foreach my $SG (@{$HGroups{$HN}}) {

				# $HN's ServerType attribute on its $SG membership
				my $ServerType = $rDNSSrvGrp->{$SG}{'machines'}{$HN}{'type'};

				# Find masters' and slaves' IP addresses (might include ourselves, $HN)
				my $Masters = '';
				my $Slaves = '';
				while (my ($Mach, $MInfo) = each %{$rDNSSrvGrp->{$SG}{'machines'}}) {
					if ($MInfo->{'type'} eq 'master') {
						$Masters.=CMU::Netdb::long2dot($rMachines->{$Mach}{ip_address}).';';
					} elsif ($MInfo->{'type'} eq 'slave') {
						$Slaves.=CMU::Netdb::long2dot($rMachines->{$Mach}{ip_address}).';';
					}
				}

				foreach my $Zone (sort keys %{$rDNSSrvGrp->{$SG}{'zones'}}) {

					# any ZoneInView attributes on this zone's $SG membership ?
					if (defined $rDNSSrvGrp->{$SG}{'zones'}{$Zone}{'views'}) {
						# yes, skip unless $VName is among those attributes
						next unless grep(/^$VName$/,
															@{$rDNSSrvGrp->{$SG}{'zones'}{$Zone}{'views'}});
					} else {
						# no, unspecified zone;
						# skip if 'Import Unspecified Zones' turned off on $VName
						next if ($SpecZonesOnly{$VName});
					}

					# have we already added this zone to this view ?
					# Unfortunately the current semantics of DNS Server Groups
					# (and the netreg u/i in general) are not equipped to prevent this
					# from happening. Allowing it through into the config file will
					# result in something that won't load into bind, so we refuse to do
					# it and complain loudly in hopes that someone will notice and fix
					# the config error in NetReg.
					if (defined $ZoneAddedBy{$Zone}) {
						warn_msg("Attempt to add zone $Zone to view $VName via ".
											"service group $SG on host $HN failed (already ".
											"added from group $ZoneAddedBy{$Zone})");
						next;
					}
					$ZoneAddedBy{$Zone} = $SG;

					## Print the actual zone
					$BUFFER .= "\tzone \"$Zone\" {\n\t\ttype $ServerType;\n";

					if ($ServerType ne 'forward' && $ServerType ne 'stub') {
						$BUFFER .= "\t\tfile \"$Zone.zone\";\n";
					}

					if ($ServerType eq 'master') {
						# we're the master for $Zone (ServerType for $HN in $SG is 'master')
						#  we need to add any keys and acls to allow dynamic updates:
						#
						#  NOTE1: if multiple masters are configured for a ddns zone, only
						#  the first one we process gets the keys and gets added to dhcp
						#  by generate_ddns_keyacl().
						#
						#  NOTE2: the update script on the managed DNS servers expects
						#  master zones to have the 'type', 'file', and 'allow-update'
						#  lines in contiguous squence in this order. I.e., if 'type' and
						#  'file' are not immediately followed by 'allow-update', the
						#  script assumes this is *not* a ddns-managed zone and will
						#  potentially overwrite its zonefile.
						print "Host $HN is master for zone $Zone ".
									"in svcgroup $SG (current view = $VName)\n" if ($debug);

						my ($GlobalDDNS, $ZoneDDNS, $ZoneDHCP) =
							generate_ddns_keyacl($Zone,
								CMU::Netdb::long2dot($rMachines->{$HN}{ip_address}),	# $HN's IP
								$rZones->{$Zone}{'ddns_auth'},
								get_authorized_updaters($Zone, $rDNSZoneAuth, $rMachines));

						# This needs to go directly into the file, because we want it
						# to come before the views are actually printed.
						print FILE "$GlobalDDNS";

						# this gets buffered along with the other zone-specific bits
						$BUFFER .= $ZoneDDNS;

						# buffer dynamic update config bits for the dhcp server(s)
						$DHCP_DDNS .= $ZoneDHCP;

					} elsif ($ServerType eq 'forward' || $ServerType eq 'stub') {

						# NOTE: while stub zones are often considered more similar to
						# slave zones (they 'slave' only the SOA record), we're using
						# them to replace forward zones on the caching servers.
						# While the target of a forward is expected to return a full
						# answer (thus forcing us to have either a very detailed list
						# of all forwarded (sub)zones on the cache, or make the authorities
						# recurse on behalf of the caches), having a stub to the top-level
						# zones on the cache allows it to both bypass root *and* perform
						# recursion itself, without explicit a-priori configuration
						# regarding delegations from the toplevel zone on the authority.
						# Stub zones facilitate this by insuring the toplevel NS record
						# is always in cache, allowing the DNS lookup algorithm to
						# opportunistically start somewhere *below* the root (i.e. at the
						# top-level server).

						# we're forwarding this zone: figure out where
						my $ForwardTo = 'master';
						if (defined $rDNSSrvGrp->{$SG}{'forward_to'} &&
								$rDNSSrvGrp->{$SG}{'forward_to'} ne '') {
							$ForwardTo = $rDNSSrvGrp->{$SG}{'forward_to'};
						}

						my $keyword = ($ServerType eq 'stub') ? 'masters' : 'forwarders';

						if ($ForwardTo eq 'master') {
							$BUFFER .= "\t\t$keyword {$Masters};\n";
						} elsif ($ForwardTo eq 'slave') {
							$BUFFER .= "\t\t$keyword {$Slaves};\n";
						} elsif ($ForwardTo eq 'both') {
							$BUFFER .= "\t\t$keyword {$Masters$Slaves};\n";
						}

					} elsif ($ServerType eq 'slave') {

						# we're slaving this zone, point at master(s)
						$BUFFER .= "\t\tmasters {$Masters};\n";

					} # if ($ServerType eq 'master' / 'forward' / 'slave' / 'stub')

					# Print the (indented) zone parameters, if any
					map {
						$BUFFER .= "\t\t$_;\n";
					} @{$rDNSSrvGrp->{$SG}{'zones'}{$Zone}{'params'}};

					$BUFFER .= "\t};\n\n";

				} # foreach my $Zone (sort keys %{$rDNSSrvGrp->{$SG}{'zones'}})

			} # foreach my $SG (@{$HGroups{$HN}})

			# closing view block statement (bind-9 only)
			$BUFFER .= "\n};\n\n";

		} # foreach my $VName (sort {...} keys %ViewOrder)

		print FILE $BUFFER;

		close(FILE);

	} # foreach my $HN (keys %HGroups) 

	## Write the DHCP bits
	open(FILE, ">$CONFDIR/dhcpd.conf.nsaux") ||
		die_msg("Cannot open $CONFDIR/dhcpd.conf.nsaux for writing");
	print FILE $DHCP_DDNS;
	close(FILE);
}

sub warn_msg {
	my ($msg) = @_;
	$WarningBuffer .= "$msg\n";
	warn $msg;
}

sub die_msg {
	my ($msg) = @_;
	&CMU::Netdb::netdb_mail('dns-config.pl', $msg, 'dns-config died!');
	die $msg;
}

# grab all IPs of machines tied to $ZoneName by a DDNS_Zone_Auth service group
# these are machines allowed to ddns-update the zone's master server
sub get_authorized_updaters {
	my ($ZoneName, $rDNSZoneAuth, $rMachines) = @_;

	my @Machines;
	foreach my $SG (keys %$rDNSZoneAuth) {
		next unless (grep(/^$ZoneName$/i, keys %{$rDNSZoneAuth->{$SG}{zones}}));
		foreach my $M (keys %{$rDNSZoneAuth->{$SG}{machines}}) {
			push(@Machines, CMU::Netdb::long2dot($rMachines->{$M}{ip_address}));
		}
	}
	return join(';', @Machines);
}

# For DDNS master servers, generate:
#  - extra per-zone config bits that go into the global file,
#    before any views ($GlobalDDNS, containing e.g. keys and acls);
#  - allow-update statement that goes into the current zone config
#    within the current view ($ZoneDDNS)
#  - if applicable 'auto-dnssec maintain' statement asking the master
#    to use DNSSec on the zone, and automatically manage the process
#  - corresponding configuration bits for any dhcp servers allowed to
#    perform ddns updates on this zone ($ZoneDHCP)
# NOTE: Global %KeyLoaded hash insures that only one one master gets
#    configured to receive dynamic updates for each zone
#    (thus enforcing the one-ddns-master-per-zone convention)
sub generate_ddns_keyacl {
	my ($Zone, $MasterIP, $DDNS_Auth, $AllowUpdateIPs) = @_;

	# return values:
	my ($GlobalDDNS, $ZoneDDNS, $ZoneDHCP) = ('', '', '');

	# turn the $DDNS_Auth string ("key1:value1 key2:value2 ...")
	#  into a hash with lowercased keys
	my %AuthInfo;
	map {
		my ($k, $v) = split(/:/);
		$AuthInfo{lc($k)} = $v;
	} split(' ', $DDNS_Auth);

	my @allow_update;
	while (my ($k, $kval) = each %AuthInfo) {
		my ($kword, $ktype) = split(/\//, $k);

		next unless ($kword eq 'key');

		# "key:foo" and "key/key:foo" are hereby declared equivalent :)
		$ktype = 'key' unless (defined $ktype);

		if (defined $KeyLoaded{$Zone.$ktype}) {
			warn_msg("$Zone.$ktype already added to $KeyLoaded{$Zone.$ktype}; ".
								"ignoring duplicate master $MasterIP");
		} else {
			$KeyLoaded{$Zone.$ktype} = $MasterIP;

			push(@allow_update, "key $Zone.$ktype");

			$GlobalDDNS .= "key $Zone.$ktype {\n\t".
											"algorithm hmac-md5;\n\t".
											"secret \"$kval\";\n};\n\n";
			if ($ktype eq 'dhcp') {
				$ZoneDHCP .= "key $Zone.dhcp {\n\t".
											"algorithm HMAC-MD5.SIG-ALG.REG.INT;\n\t".
											"secret $kval;\n};\n\n".
											"zone $Zone. {\n\t".
											"primary $MasterIP;\n\t".
											"key $Zone.dhcp;\n}\n\n";
			}
		}
	} # while (my ($k, $kval) = each %AuthInfo)

	# IPs allowed to dynamically update the zone:
	if ($AllowUpdateIPs ne '') {
		# obtained via DDNS_Zone_Auth service group memberships
		$AllowUpdateIPs .= ';';	# just need to append a ';' here
	}
	if (defined $AuthInfo{'ip'} && $AuthInfo{'ip'} ne '') {
		# obtained via the ddns_auth string on the zone's netreg record
		$AllowUpdateIPs .= $AuthInfo{'ip'} . ';';	# append to AllowUpdateIPs
	}

	if ($AllowUpdateIPs ne '') {
		if (defined $KeyLoaded{$Zone.'acl'}) {
			warn_msg("$Zone.acl already added to $KeyLoaded{$Zone.'acl'}; ".
								"ignoring duplicate master $MasterIP");
		} else {
			$KeyLoaded{$Zone.'acl'} = $MasterIP;

			push(@allow_update, "$Zone.acl");
			$GlobalDDNS .= "acl $Zone.acl { $AllowUpdateIPs };\n\n"
		}
	}

	if (@allow_update > 0) {
		$ZoneDDNS .= "\t\tallow-update {\n\t\t\t".
								join(";\n\t\t\t", @allow_update).
								";\n\t\t};\n";
	}

	# is this a zone the master should manage for DNSSec ?
	if ($AuthInfo{'dnssec'} eq 'ena') {
		$ZoneDDNS .= "\t\tauto-dnssec maintain;\n";
	}

	return ($GlobalDDNS, $ZoneDDNS, $ZoneDHCP);
}


# Load the services.sif file. 
# This function untouched during rewrite -- GLS, 2010/01/20
sub load_services {
  my ($File) = @_;

  # These are the returned structures
  my %DNSSrvGrp;
  my %ServerView;
  my %ServerAuth;
  my %Machines;
  my %Zones;

  open(FILE, $File) || die_msg("Cannot open services file: $File\n");
  my ($depth, $loc, $SName, $SType,$MType,$MName) = (0,0,'','','','');

  while(my $line = <FILE>) {
    if ($depth == 0) {

      ## Look for service definitions
      if ($line =~ /service\s+\"([^\"]+)\"\s+type\s+\"([^\"]+)\"\s*\{/) {
	($SName, $SType) = ($1, $2);
	$depth++;
	if ($SType eq 'DNS Server Group') {
	  $loc = 1;
	  $DNSSrvGrp{$SName} = {};
	  print "Defined Group $SName\n";
	}elsif($SType eq 'DNS View Definition') {
	  $loc = 2;
	  $ServerView{$SName} = {};
	}elsif($SType eq 'DDNS_Zone_Auth') {
	  $loc = 20;
	  $ServerAuth{$SName} = {};
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
	}elsif($loc == 2 && $AKey eq 'Import Unspecified Zones') {
	  $ServerView{$SName}->{'import'} = $AVal;
        }elsif($loc == 1 && $AKey eq 'Forward To') {
	  $DNSSrvGrp{$SName}->{'forward_to'} = $AVal;
	}
	## Look for members of a service
      }elsif($line =~ /member\s*type\s*\"([^\"]*)\"\s*name\s*\"([^\"]*)\"/) {
	($MType, $MName) = ($1, $2);
	if ($MType eq '' || $MName eq '') {
	  warn_msg( "In service $SName, Type or Name of member is blank: ($MType), ($MName).");
	}
	  
	$depth++;
	
	if ($loc == 1 && $MType eq 'dns_zone') {
	  $DNSSrvGrp{$SName}->{'zones'}{$MName} = {};
	  $loc = 5;
	}elsif($loc == 1 && $MType eq 'service') {
	  $DNSSrvGrp{$SName}->{'views'}{$MName} = {};
	  $loc = 6;
	}elsif($loc == 1 && $MType eq 'machine') {
	  $MName = lc($MName);
	  $DNSSrvGrp{$SName}->{'machines'}{$MName} = {};
	  $loc = 7;
	}elsif($loc == 20 && $MType eq 'machine') {
	  $MName = lc($MName);
	  $ServerAuth{$SName}->{'machines'}{$MName} = {};
	}elsif($loc == 20 && $MType eq 'dns_zone') {
	  $ServerAuth{$SName}->{'zones'}{$MName} = {};
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
      }elsif($line =~ /\{/) {
	$depth++;
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
	  push(@{$DNSSrvGrp{$SName}->{'zones'}{$MName}{'params'}},
	       $AVal);
	}elsif($loc == 5 && $AKey eq 'Zone In View') {
	  print "pushing view $SName $MName $AVal\n";
	  push(@{$DNSSrvGrp{$SName}->{'zones'}{$MName}{'views'}},
	       $AVal);
	}elsif($loc == 6 && $AKey eq 'Service View Name') {
	  $DNSSrvGrp{$SName}->{'views'}{$MName}{'name'} = $AVal;
	}elsif($loc == 6 && $AKey eq 'Service View Order') {
	  $DNSSrvGrp{$SName}->{'views'}{$MName}{'order'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Type') {
	  $DNSSrvGrp{$SName}->{'machines'}{$MName}{'type'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Version') {
	  $DNSSrvGrp{$SName}->{'machines'}{$MName}{'version'} = $AVal;
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

  return (\%DNSSrvGrp, \%ServerView, \%ServerAuth, \%Machines, \%Zones);
}
