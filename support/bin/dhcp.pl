#!/usr/bin/perl
#
# Generate DHCP Configuration File for ISC-DHCP server
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
# Thanks to Frank Sweetser for significant contributions to this script.
# $Id: dhcp.pl,v 1.71 2008/03/27 19:42:41 vitroth Exp $
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
use Data::Dumper;

$| = 1;

print "Using libdir: $vars_l::NRLIB\n";

my $DBUSER = 'netreg';

my ($SERVICES, $GENPATH, $XFERPATH, $SVCNAME, $LEASE_TIME, $DNS_SERVERS, $TPATH,
    $DHCP_NSKEY);
my ($vres);

($vres, $SERVICES) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'SERVICE_COPY');
($vres, $GENPATH) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'DHCP_GENPATH');
($vres, $XFERPATH) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'DHCP_XFERPATH');
($vres, $SVCNAME) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'DHCP_SERVICE');
($vres, $LEASE_TIME) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'DHCP_DEF_LEASETIME');
($vres, $TPATH) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'DHCP_TEMPLATE_PATH');
my ($vres, $DHCP_NSKEY) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'DHCP_NSKEY');

my $debug = 0;
if ($ARGV[0] eq '-debug') {
  print "*** Debug mode enabled.\n";
  $debug = $ARGV[1] || '1';
  $GENPATH = '/tmp/dhcp';
  $XFERPATH = '/tmp/dhcp-xfer';
  $SERVICES = '/tmp/services.sif';
}

# Declaring the sections we want and mapping a function to generate each
# section.

# Known dependencies:
#  'zones' after 'dynhosts' and 'subnets'
#  'classes' after 'dynhosts'

my %OutputSections = ('hdr' => {'order' => 1,
				'fun' => \&output_hdr},
		      'failover' => {'order' => 2,
				     'fun' => \&output_failover},

		      'omapi' => {'order' => 3,
				  'fun' => \&output_omapi},

		      'zones' => {'order' => 10,
				  'fun' => \&output_zones},

		      'options_declarations' => 
		      {'order' => 4,
		       'fun' => \&output_options_decls},

		      'global_options' => {'order' => 5,
					   'fun' => \&output_global_options},

		      'classes' => {'order' => 9,
				    'fun' => \&output_classes},

		      'subnets' => {'order' => 6,
				    'fun' => \&output_subnets},

		      'dynhosts' => {'order' => 7,
				     'fun' => \&output_dynhosts},

		      'stathosts' => {'order' => 8,
				      'fun' => \&output_stathosts},
		     );

my $rServices = load_services($SERVICES);
my $ConfTemplate = load_template($TPATH);
my $dbh = CMU::Netdb::report_db_connect();
if (!$dbh) {
  die_msg("Database handle could not be established: $dbh");
}

print Dumper($rServices) if ($debug >= 5);

my %DHCPData;

# Generate options declarations
$DHCPData{'options_declarations'} = 
  gen_options_declarations($dbh, $rServices);

# Generate failover/omapi/global options linked to server name
$DHCPData{'servers'} = gen_server_specific($dbh, $rServices);

# Generate subnets
$DHCPData{'subnets'} = gen_subnets($dbh, $rServices, \%DHCPData);

$DHCPData{'shares'} = gen_subnet_shares($dbh);

# pools, static/dynamic machines
$DHCPData{'hosts'} = gen_host_data($dbh, \%DHCPData);

gen_roaming_acls($dbh, $rServices, \%DHCPData);

# Generate zones
$DHCPData{'zones'} = gen_zones($dbh, $rServices);
$DHCPData{'zone_parents'} = gen_zone_map($dbh);

gen_pool_access_fixup($dbh, $rServices, \%DHCPData);
gen_unique_acl_statements($dbh, $rServices, \%DHCPData);

$DHCPData{'classes'} = gen_classes($dbh, $rServices, \%DHCPData);

print "DHCPData at the end of processing all data, before output:\n" if ($debug >= 5);
print Dumper(\%DHCPData) if ($debug >= 5);

write_files(\%DHCPData, $rServices);

print Dumper(\%DHCPData) if ($debug >= 2);
exit (0);

sub write_files {
  my ($rDD, $rServ) = @_;

  foreach my $Server (sort { $rDD->{'servers'}{$a}{priority} <=> $rDD->{'servers'}{$b}{priority}}  keys %{$rDD->{'servers'}}) {
    my $LCServer = lc($Server);
    my $Template = load_template($TPATH, $Server);

    foreach my $Var (sort {  $OutputSections{$a}->{'order'} <=>
			     $OutputSections{$b}->{'order'} }
		     keys %OutputSections) {
      my $Rep = $OutputSections{$Var}->{'fun'}->($rDD, $Server, $rServ);
      $Template =~ s/\%$Var\%/$Rep/g;
    }

    print "Generating configuration for: $LCServer\n";
    open(FILE, ">$GENPATH/dhcpd.conf.$LCServer") 
      or die_msg("Cannot open $GENPATH/dhcpd.conf.$LCServer");
    print FILE $Template;
    close(FILE);

    dhcpxfer($rDD, $Server);

  }
}

## die_msg
## Die while sending mail
sub die_msg {
  my ($msg) = @_;
  CMU::Netdb::netdb_mail('dhcp.pl', $msg, 'dhcp.pl died');
  die $msg;
}

# Load all of the dhcp option types from the database. This returns
# a structure with the option name, number, and format.
sub load_dhcp_option_types {
  my ($dbh) = @_;

  my $types = CMU::Netdb::list_dhcp_option_types($dbh, $DBUSER,"");
  if (!ref $types) {
    die_msg("list_dhcp_option_types returned: ".$types);
  }

  my %pos = %{CMU::Netdb::makemap($types->[0])};

  my %OptionType;
  my ($IDPos, $NumPos, $NamePos, $FormPos) = ($pos{'dhcp_option_type.id'},
					      $pos{'dhcp_option_type.number'},
					      $pos{'dhcp_option_type.name'},
					      $pos{'dhcp_option_type.format'});

  map { $OptionType{$_->[$IDPos]} = [$_->[$NamePos], 
				     $_->[$NumPos],
				     $_->[$FormPos]] 
      } @$types;

  return \%OptionType;
}

# Figure out what subnets are in a subnet share.
sub gen_subnet_shares {
  my ($dbh) = @_;

  my %ShareInfo;

  my $rShares = CMU::Netdb::list_subnet_shares($dbh, $DBUSER, '');
  unless (ref $rShares) {
    die_msg("list_subnet_shares returned: ".$rShares);
  }

  my %pos = %{CMU::Netdb::makemap($rShares->[0])};

  shift(@$rShares);

  foreach my $row (@$rShares) {
    my $id = $row->[$pos{'subnet_share.id'}];
    foreach my $Field (qw/name abbreviation/) {
      $ShareInfo{$id}->{$Field} = $row->[$pos{"subnet_share.$Field"}];
    }
  }

  my $shared = CMU::Netdb::list_subnets($dbh, $DBUSER, "subnet.share != 0");
  if (!ref $shared) {
    die_msg("list_subnets (share != 0) returned: ".$shared);
  }

  my %SharedColumns = %{CMU::Netdb::makemap($shared->[0])};

  shift(@$shared);

  foreach my $row (@$shared) {
    my $ShareID = $row->[$SharedColumns{'subnet.share'}];
    my $SubnetName = $row->[$SharedColumns{'subnet.name'}];
    $ShareInfo{$ShareID}->{'members'}->{$SubnetName} = {};
  }

  return \%ShareInfo;
}

# Generate host data, attached to subnets
#  - dynamic host information (X)
#  - static host information (X)
#  - pool data (X)
sub gen_host_data {
  my ($dbh, $rOD) = @_;

  my %HostInfo;

  # Pool data
  my $pools = CMU::Netdb::list_machines_subnets($dbh, $DBUSER,
						"machine.mode=\"pool\" ".
						"ORDER BY machine.ip_address");
  if (!ref $pools) {
    die_msg("list_machines_subnets (mode = pool) returned: ".$pools);
  }

  my %MachinesColumns = %{CMU::Netdb::makemap($pools->[0])};
  shift(@$pools);

  my ($StartIP, $EndIP, $LastSubnet) = ('', '', '');

  foreach my $row (@$pools) {
    my $IP = $row->[$MachinesColumns{'machine.ip_address'}];
    my $Subnet = $row->[$MachinesColumns{'subnet.name'}];
    my $IPZone = $row->[$MachinesColumns{'machine.ip_address_zone'}];

    if ($StartIP eq '') {
      $StartIP = $IP;
      $EndIP = $IP;
      $LastSubnet = $Subnet;

      $rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'zones_used'}->{$IPZone} = 1;
    }elsif($EndIP+1 == $IP and $LastSubnet eq $Subnet) {
      $EndIP = $IP;
      $rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'zones_used'}->{$IPZone} = 1;
    }else{
      push(@{$rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'ranges'}},
	   {'start' => $StartIP,
	    'end' => $EndIP,
	    });
      $rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'allow'} = [];
      $rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'deny'} = [];

      $StartIP = $IP;
      $EndIP = $IP;
      $LastSubnet = $Subnet;
      $rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'zones_used'}->{$IPZone} = 1;
    }
  }

  # Last defined pool
  push(@{$rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'ranges'}},
       {'start' => $StartIP,
	'end' => $EndIP,
       });
  $rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'allow'} = [];
  $rOD->{'subnets'}->{$LastSubnet}->{'pool'}->{'main'}->{'deny'} = [];

  my $machines = CMU::Netdb::list_dhcp_machine_options
          ($dbh, $DBUSER, "(machine.mode IN ('static', 'dynamic', 'reserved')".
	   " AND machine.mac_address != '') ");

  if (!ref $machines) {
    die_msg("list_dhcp_machine_options returned: ".
	    $machines);
  }
  my %MachinesColumns = %{CMU::Netdb::makemap($machines->[0])};

  shift(@$machines);
  foreach my $row (@$machines) {
    my $ID = $row->[$MachinesColumns{'machine.id'}];

    unless (defined $HostInfo{$ID}) {
      my %Info = ();
      foreach my $field (qw/mode flags mac_address ip_address host_name
			    ip_address_subnet id host_name_zone
			    ip_address_zone/) {
	$Info{$field} = $row->[$MachinesColumns{"machine.$field"}];
      }

      $HostInfo{$ID} = \%Info;
    }

    if ($row->[$MachinesColumns{'dhcp_option.id'}] ne '') {
      my $OName = $row->[$MachinesColumns{'dhcp_option_type.name'}];
      my $OValue = $row->[$MachinesColumns{'dhcp_option.value'}];
      $HostInfo{$ID}->{'options'}->{$OName} = {'value' => $OValue};
    }
  }

  return \%HostInfo;
}

# Cleanup acls; remove duplicate classes
sub gen_unique_acl_statements {
  my ($dbh, $rServ, $rOD) = @_;

  foreach my $Subnet (keys %{$rOD->{'subnets'}}) {
    foreach my $Pool (keys %{$rOD->{'subnets'}->{$Subnet}->{'pool'}}) {
      my $PInfo = $rOD->{'subnets'}->{$Subnet}->{'pool'}->{$Pool};

      my @NewAllow = ();
      my @NewDeny = ();
      my %Cl = {};
      foreach my $X (@{$PInfo->{'allow'}}) {
        next if ($X->{'type'} eq 'class' && defined $Cl{$X->{'class'}});
        $Cl{$X->{'class'}} = 1;
        push(@NewAllow, $X);
      }

      %Cl = {};
      foreach my $X (@{$PInfo->{'deny'}}) {
        next if ($X->{'type'} eq 'class' && defined $Cl{$X->{'class'}});
        $Cl{$X->{'class'}} = 1;
        push(@NewDeny, $X);
      }
      $PInfo->{'allow'} = \@NewAllow;
      $PInfo->{'deny'} = \@NewDeny;
    }
  }
} 

# Fixup the access lists to the pools. Specifically add:
#  - "deny dynamic bootp clients" (X)
#  - deny registered members from quickreg pools (X)
#  - deny unknown clients from restricted pools (X)
#  - permit registered clients on restricted pools (X)
sub gen_pool_access_fixup {
  my ($dbh, $rServ, $rOD) = @_;

  foreach my $Subnet (keys %{$rOD->{'subnets'}}) {
    foreach my $Pool (keys %{$rOD->{'subnets'}->{$Subnet}->{'pool'}}) {
      my $PInfo = $rOD->{'subnets'}->{$Subnet}->{'pool'}->{$Pool};
      my $Abbrev = $rOD->{'subnets'}->{$Subnet}->{'abbreviation'};

      push(@{$PInfo->{'deny'}}, {'type' => 'bootp_clients'});
      if ($rOD->{'subnets'}->{$Subnet}->{'dynamic_mode'} eq 'restrict') {
#        push(@{$PInfo->{'deny'}}, {'type' => 'unknown'});
        push(@{$PInfo->{'allow'}}, {'type' => 'class',
				    'class' => $Abbrev.'_dynamic_reg'});
      }elsif($rOD->{'subnets'}->{$Subnet}->{'dynamic_mode'} eq 'disallow') {
	push(@{$PInfo->{'deny'}}, {'type' => 'unknown'});
      }else{
	push(@{$PInfo->{'deny'}}, {'type' => 'class',
				   'class' => $Abbrev.'_dynamic_deny'});
      }
    }
  }

  # QuickReg fixup: Go through the shares and set them up so that the
  # registered clients will not get a QuickReg address
  foreach my $Share (keys %{$rOD->{'shares'}}) {
    my $PreReg = '';
    my @DenyACLs;
    foreach my $Subnet (keys %{$rOD->{'shares'}->{$Share}->{'members'}}) {

      if ($rOD->{'subnets'}->{$Subnet}->{'flags'} =~ /prereg_subnet/) {
	$PreReg = $Subnet;
      }
      if(defined $rOD->{'subnets'}->{$Subnet}->{'pool'}->{'main'} &&
	 $rOD->{'subnets'}->{$Subnet}->{'dynamic_mode'} eq 'restrict') {
        foreach my $statement (@{$rOD->{'subnets'}->{$Subnet}->{'pool'}->{'main'}->{'allow'}}) {
          if ($statement->{'type'} eq 'class') {
            push(@DenyACLs, $statement->{'class'});
          }
        }
        foreach my $statement (@{$rOD->{'subnets'}->{$Subnet}->{'pool'}->{'main'}->{'deny'}}) {
	  if ($statement->{'type'} eq 'class') {
	    push(@DenyACLs, $statement->{'class'});
          }
        }
      }
    }
    next if ($PreReg eq '');

    # all the open pools off the share will get restrictions against the
    # defined, restricted pools
    foreach my $Subnet (keys %{$rOD->{'shares'}->{$Share}->{'members'}}) {
      if (defined $rOD->{'subnets'}->{$Subnet}->{'pool'}->{'main'} &&
	  $rOD->{'subnets'}->{$Subnet}->{'dynamic_mode'} eq 'permit') {
        push(@{$rOD->{'subnets'}->{$Subnet}->{'pool'}->{'main'}->{'deny'}},
	     map { {'type' => 'class',
		      'class' => $_} } @DenyACLs);
      }
    }
  }
}

# Class ACL format
#  dhcp.pl generated: _SubnetAbbrev_{static|dynamic}_{reg|roam|deny}
#  normal: freeform
sub gen_classes {
  my ($dbh, $rServ, $rOD) = @_;

  my %ClassInfo;
  # Pull classes from the service config
  if (defined $rServ->{'service'}->{'DHCP Class'}) {
    foreach my $Class (keys %{$rServ->{'service'}->{'DHCP Class'}}) {
      my $CInfo = $rServ->{'service'}->{'DHCP Class'}->{$Class};
      $ClassInfo{$Class}->{'match'} = $CInfo->{'attr'}->{'Match Statement'};
      $ClassInfo{$Class}->{'options'} = $CInfo->{'dhcp_option'};

      if (defined $CInfo->{'member'} && 
	  defined $CInfo->{'member'}->{'subnet'}) {
	foreach my $Subnet (keys %{$CInfo->{'member'}->{'subnet'}}) {
	  $rOD->{'subnets'}->{$Subnet}->{'classes'}->{$Class} = 1;
	}
      }
    }
  }

  # Generate class statements for all defined classes in pool statements
  my %ClassRefs;
  foreach my $Subnet (keys %{$rOD->{'subnets'}}) {
    foreach my $Pool (keys %{$rOD->{'subnets'}->{$Subnet}->{'pool'}}) {
      foreach my $ref (@{$rOD->{'subnets'}->{$Subnet}->{'pool'}->{$Pool}->{'allow'}}) {
	next if ($ref->{'type'} ne 'class');
	$ClassRefs{$ref->{'class'}} = 1;
      }
      foreach my $ref (@{$rOD->{'subnets'}->{$Subnet}->{'pool'}->{$Pool}->{'deny'}}) {
	next if ($ref->{'type'} ne 'class');
	$ClassRefs{$ref->{'class'}} = 1;
      }
    }

    # Also generate basic registration classes if not done already
    my $Abbrev = $rOD->{'subnets'}->{$Subnet}->{'abbreviation'};
    my $BaseClass = "${Abbrev}_dynamic_reg";

    $ClassRefs{$BaseClass} = 1;
  }

  foreach my $Class (keys %ClassRefs) {
    next if (defined $ClassInfo{$Class});
    $ClassInfo{$Class}->{'match'} = 'hardware';
  }
  return \%ClassInfo;
}

sub gen_roaming_acls {
  my ($dbh, $rServ, $rOD) = @_;

  return unless (defined $rServ->{'service'}->{'DHCP Roaming Group'});
  foreach my $DRG (keys %{$rServ->{'service'}->{'DHCP Roaming Group'}}) {
    my $RGInfo = $rServ->{'service'}->{'DHCP Roaming Group'}->{$DRG};
    next unless (defined $RGInfo->{'member'} &&
		 defined $RGInfo->{'member'}->{'subnet'});

    my @Allow;
    my @Deny;

    # Construct the source allow list
    foreach my $Subnet (keys %{$RGInfo->{'member'}->{'subnet'}}) {
      my $SInfo = $RGInfo->{'member'}->{'subnet'}->{$Subnet};
      next unless (defined $SInfo->{'attr'}->{'source-selection'});

      my @PAllow = ('static_reg', 'dynamic_reg', 'static_roam',
		    'dynamic_roam');
      my @PDeny = ('static_deny', 'dynamic_deny');
      if ($SInfo->{'attr'}->{'source-selection'} ne 'both') {
	my $SS = $SInfo->{'attr'}->{'source-selection'};
	@PAllow = grep(/^${SS}_/, @PAllow);
        @PDeny = grep(/^${SS}/, @PDeny);
      }

      if (defined $SInfo->{'attr'}->{'source-filter'}) {
	my $SF = $SInfo->{'attr'}->{'source-filter'};
	if ($SF eq 'roaming-flag-required') {
	  @PAllow = grep(/_roam$/, @PAllow);
	}elsif($SF eq 'all') {
          @PAllow = grep(!/_roam$/, @PAllow);
        }
      }

      my $SubnetAbbrev = $rOD->{'subnets'}->{$Subnet}->{'abbreviation'};
      push(@Allow, map { $SubnetAbbrev.'_'.$_ } @PAllow);
      push(@Deny, map { $SubnetAbbrev.'_'.$_ } @PDeny);
    }

    # Attach allow list to every destination subnet
    foreach my $Subnet (keys %{$RGInfo->{'member'}->{'subnet'}}) {
      my $SInfo = $RGInfo->{'member'}->{'subnet'}->{$Subnet};
      next unless (defined $SInfo->{'attr'}->{'destination-selection'} &&
		   $SInfo->{'attr'}->{'destination-selection'} eq 'yes');

      if (!defined $rOD->{'subnets'}->{$Subnet}->{'pool'}) {
	if ($debug >= 1) {
	  warn "Subnet $Subnet defined as destination in group $DRG ".
	    "but no pools on subnet.";
	}
	next;
      }

      foreach my $Pool (keys %{$rOD->{'subnets'}->{$Subnet}->{'pool'}}) {
	my $PInfo = $rOD->{'subnets'}->{$Subnet}->{'pool'}->{$Pool};

	push(@{$PInfo->{'allow'}}, 
	     map { {'type' => 'class', 'class' => $_} } @Allow);
        push(@{$PInfo->{'deny'}},
	     map { {'type' => 'class', 'class' => $_} } @Deny);
      }
    }
  }
}

# Determine subnet-specific data, including:
#  - subnet information (X)
#    - dynamic mode
#  - DHCP options (X)
#  - which servers the subnet appears in (X)
sub gen_subnets {
  my ($dbh, $rServices, $rOD) = @_;

  my $DSI = $rOD->{'servers'};

  my $options = CMU::Netdb::list_dhcp_subnet_options
    ($dbh, $DBUSER,
     "NOT FIND_IN_SET('no_dhcp', subnet.flags)");
  if (!ref $options) {
    die_msg("list_dhcp_subnet_options failed: ".$options);
  }

  my %SubnetInfo;

  my %ColMap = %{CMU::Netdb::makemap($options->[0])};
  shift(@$options);
  foreach my $Opt (@$options) {
    my $Name = $Opt->[$ColMap{'subnet.name'}];
    if (!defined $SubnetInfo{$Name}) {
      $SubnetInfo{$Name}->{'base'} = CMU::Netdb::long2dot
	($Opt->[$ColMap{'subnet.base_address'}]);
      $SubnetInfo{$Name}->{'mask'} = CMU::Netdb::long2dot
	($Opt->[$ColMap{'subnet.network_mask'}]);
      $SubnetInfo{$Name}->{'dynamic_mode'} = $Opt->[$ColMap{'subnet.dynamic'}];
      $SubnetInfo{$Name}->{'flags'} = $Opt->[$ColMap{'subnet.flags'}];
      $SubnetInfo{$Name}->{'abbreviation'} = 
	$Opt->[$ColMap{'subnet.abbreviation'}];

      $SubnetInfo{$Name}->{'expire_static'} = 
	$Opt->[$ColMap{'subnet.expire_static'}];
      $SubnetInfo{$Name}->{'expire_dynamic'} =
	$Opt->[$ColMap{'subnet.expire_dynamic'}];
      $SubnetInfo{$Name}->{'id'} = $Opt->[$ColMap{'subnet.id'}];
      $SubnetInfo{$Name}->{'subnet_share'} = $Opt->[$ColMap{'subnet.share'}];
    }

    my $OptName = $Opt->[$ColMap{'dhcp_option_type.name'}];
    my $OptVal = $Opt->[$ColMap{'dhcp_option.value'}];

    $SubnetInfo{$Name}->{'options'}->{$OptName} = {'value' => $OptVal};
  }

  # get/set subnet default options
  my $rSubnetDefaultOpts = get_subnet_default_opts($dbh);

  my $SubnetCount = 0;
  foreach my $Subnet (keys %SubnetInfo) {
    $SubnetCount++;
    foreach my $Opt (keys %$rSubnetDefaultOpts) {
      next if (defined $SubnetInfo{$Subnet}->{'options'}->{$Opt});
      my $Val = $rSubnetDefaultOpts->{$Opt};

      # Shuffle DNS Servers (from subnet default only)
      if ($Opt eq 'option domain-name-servers') {
	my @Servers = split(/\,/, $Val);
	my $NDNS = $#Servers + 1;
	my @dns = ();
	for my $z (1..$NDNS) {
	  push(@dns, $Servers[($SubnetCount + $z - 1) % $NDNS]);
	}
	$Val = join(',', @dns);
      }

      $SubnetInfo{$Subnet}->{'options'}->{$Opt} = {'value' => $Val};
    }
  }

  # expand server defaults to join this subnet to specific servers
  foreach my $Subnet (keys %SubnetInfo) {
    my $IsRef = 0;

    # See if the subnet is referenced anywhere
    foreach my $Server (keys %$DSI) {
      if (defined ($DSI->{$Server}->{'subnet'}->{$Subnet})) {
	$IsRef = 1;
	last;
      }
    }

    unless ($IsRef) {
      # It's not referenced, so add it to the defaults
      foreach my $Server (keys %$DSI) {
	if (defined ($DSI->{$Server}->{'subnet_default'})) {
	  $DSI->{$Server}->{'subnet'}->{$Subnet} =
	    $DSI->{$Server}->{'subnet_default'};
	}
      }
    }
  }

  return \%SubnetInfo;
}

# Get the subnet default information. These are options that will appear
# in the subnet scope in the absence of a more specific option on the
# individual subnet.
sub get_subnet_default_opts {
  my ($dbh) = @_;

  my $ref = CMU::Netdb::list_default_dhcp_options($dbh, $DBUSER, 'subnet');
  if (!ref $ref) {
    die_msg("list_default_dhcp_options returned: ".$ref);
  }

  my %Options;
  foreach my $Opt (@$ref) {
    my ($Name, $Val) = @$Opt;
    $Options{$Name} = $Val;
  }
  return \%Options;
}

# Generate server-specific information, including:
#  - header (server-identifier) (X)
#  - failover declarations (X)
#  - OMAPI declarations (X)
#  - global options (X)
#  - every subnet in the server's config (X)
#    * static/dynamic/failover?
#  - classes associated with server pool
sub gen_server_specific {
  my ($dbh, $rServ, $rSubnetInfo) = @_;

  my %DhcpServerInfo;

  # Load the global DHCP options
  my $rGlobalOpts = get_global_opts($dbh);

  foreach my $Pool (keys %{$rServ->{'service'}->{'DHCP Server Pool'}}) {
    my $PInfo = $rServ->{'service'}->{'DHCP Server Pool'}->{$Pool};
    my $IsDefault = 0;
    my $Priority = 255;
    my ($OMAPIPort, $OMAPIKey) = ('', '');
    if (defined $PInfo->{'attr'}) {
      $IsDefault = ($PInfo->{'attr'}->{'Default DHCP Service Pool'} 
		    eq 'Yes' ? 1 : 0);
      $OMAPIPort = $PInfo->{'attr'}->{'OMAPI Port'};
      $OMAPIKey = $PInfo->{'attr'}->{'OMAPI Key'};
      $Priority = $PInfo->{'attr'}->{'Configuration Priority'} if (exists $PInfo->{'attr'}->{'Configuration Priority'});
    }

    # Find the failover primary and secondary for this peer group
    my ($FPri, $FSec) = ('', '');
    foreach my $Server (keys %{$PInfo->{'member'}->{'machine'}}) {
      my $SInfo = $PInfo->{'member'}->{'machine'}->{$Server};
      if (defined $SInfo->{'attr'}) {
	if (defined $SInfo->{'attr'}->{'Dynamic Failover'}) {
	  my $FR = $SInfo->{'attr'}->{'Dynamic Failover'};
 	  if ($FR eq 'master') {
	    if (!$FPri) {
	      $FPri = $Server;
	    } else {
	      die_msg("Multiple Master Servers defined: $FPri and $Server");
	    }
	  } elsif ($FR eq 'secondary') {
	    if (!$FSec) {
	      $FSec = $Server;
	    } else {
	      die_msg("Multiple Secondary Servers defined: $FSec and $Server");
	    }
	  }
	}
      }
    }

    foreach my $Server (keys %{$PInfo->{'member'}->{'machine'}}) {
      my $SInfo = $PInfo->{'member'}->{'machine'}->{$Server};
      $DhcpServerInfo{$Server}->{'identifier'} = $Server;
      my $FailoverRole = 'neither';
      my $ServerType = 'static';

      # If the priority for this pool is lower then the current priority on
      # the member servers, lower the priority on the server.
      $DhcpServerInfo{$Server}->{'priority'} = $Priority
	if (!defined $DhcpServerInfo{$Server}->{'priority'}
	    || $Priority < $DhcpServerInfo{$Server}->{'priority'});

    # Find the failover primary and secondary for this peer group
      if (defined $SInfo->{'attr'}) {
	if (defined $SInfo->{'attr'}->{'Dynamic Failover'}) {
	  $FailoverRole = $SInfo->{'attr'}->{'Dynamic Failover'};
	}
	if (defined $SInfo->{'attr'}->{'File Type'}) {
	  $ServerType = $SInfo->{'attr'}->{'File Type'};
	}
	if (defined $SInfo->{'attr'}->{'Configure All Zones'}) {
	  $DhcpServerInfo{$Server}->{'config_all_zones'} =
	    $SInfo->{'attr'}->{'Configure All Zones'};
	}
      }

      # Set OMAPI Info
      if ($OMAPIPort ne '' && $OMAPIKey ne '') {
	if (defined $DhcpServerInfo{$Server}->{'omapi'} && $debug >= 1) {
	  warn "Duplicate OMAPI information for $Server";
	}
	$DhcpServerInfo{$Server}->{'omapi'} = {'port' => $OMAPIPort,
					       'key' => $OMAPIKey};
      }

      # Set the options
      foreach my $Opt (keys %$rGlobalOpts) {
	next if (defined $DhcpServerInfo{$Server}->{'goptions'}->{$Opt});
	$DhcpServerInfo{$Server}->{'goptions'}->{$Opt} = $rGlobalOpts->{$Opt};
      }

      if (defined $PInfo->{'dhcp_option'}) {
	foreach my $Opt (keys %{$PInfo->{'dhcp_option'}}) {
	  if (defined $DhcpServerInfo{$Server}->{'goptions'} && $debug >= 1) {
	    warn "Duplicate global option $Opt for $Server";
	  }

	  $DhcpServerInfo{$Server}->{'goptions'}->{$Opt} =
	    $PInfo->{'dhcp_option'}->{$Opt};
	}
      }

      # If this SG is defined as default, note this on the server so that
      # it gets all the uncommitted subnets later.
      if ($IsDefault) {
	if (defined $DhcpServerInfo{$Server}->{'subnet_default'} && $debug) {
	  warn "Duplicate default subnet information in $Pool/$Server";
	}

	$DhcpServerInfo{$Server}->{'subnet_default'}->{'failover'} =
	  $FailoverRole;
	$DhcpServerInfo{$Server}->{'subnet_default'}->{'failover_name'} =
	  $Pool;
	if ($FailoverRole eq 'master') {
	  $DhcpServerInfo{$Server}->{'subnet_default'}->{'failover_peer'} =
	    $FSec;
	}elsif($FailoverRole eq 'secondary') {
	  $DhcpServerInfo{$Server}->{'subnet_default'}->{'failover_peer'} =
	    $FPri;
	}
	$DhcpServerInfo{$Server}->{'subnet_default'}->{'type'} = $ServerType;
      }

      # For each subnet directly attached to the service group, add it
      # to this server's output list.
      if (defined $PInfo->{'member'}->{'subnet'}) {
	foreach my $Subnet (keys %{$PInfo->{'member'}->{'subnet'}}) {
	  $DhcpServerInfo{$Server}->{'subnet'}->{$Subnet}->{'failover'} =
	    $FailoverRole;
	  $DhcpServerInfo{$Server}->{'subnet'}->{$Subnet}->{'failover_name'} =
	    $Pool;
	  if ($FailoverRole eq 'master') {
	    $DhcpServerInfo{$Server}->{'subnet'}->{$Subnet}->{'failover_peer'}
	      = $FSec;
	  }elsif($FailoverRole eq 'secondary') {
	    $DhcpServerInfo{$Server}->{'subnet'}->{$Subnet}->{'failover_peer'}
	      = $FPri;
	  }
	  $DhcpServerInfo{$Server}->{'subnet'}->{$Subnet}->{'type'} =
	    $ServerType;
	}
      }

      # Check all the services associated with this group. If any are
      # recognized (currently just DHCP classes, add them to each server)
      if (defined $PInfo->{'member'}->{'service'}) {
	foreach my $Svc (keys %{$PInfo->{'member'}->{'service'}}) {

	  ## Type-specific checking
	  if (defined $rServ->{'service'}->{'DHCP Class'}->{$Svc}) {
	    $DhcpServerInfo{$Server}->{'classes'}->{$Svc} = 1;
	  }
	}
      }
    }
  }
  return \%DhcpServerInfo;
}

# Get the global options in the system. Global options will be 
# added to the global scope of each DHCP server, but overridden by 
# options on the service group containing the server.
sub get_global_opts {
  my ($dbh) = @_;

  my $rOptionType = load_dhcp_option_types($dbh);

  my $options = CMU::Netdb::list_dhcp_options
    ($dbh, $DBUSER, 'dhcp_option.type = "global"');

  if (!ref $options) {
    die_msg("list_dhcp_options/1 returned: ".$options);
  }

  my %OptionsColumns = %{CMU::Netdb::makemap($options->[0])};
  my ($NumPos, $ValPos) = ($OptionsColumns{'dhcp_option.type_id'},
			   $OptionsColumns{'dhcp_option.value'});

  shift(@$options);

  my %GlobalOptions;
  foreach my $R (@$options) {
    $GlobalOptions{$rOptionType->{$R->[$NumPos]}->[0]}->{'value'} = 
      $R->[$ValPos];
  }
  return \%GlobalOptions;
}

# Determine the zone/key statements required
sub gen_zones {
  my ($dbh, $rServ) = @_;

  my %ZoneInfo;
  foreach my $Zone (keys %{$rServ->{'dns_zone'}}) {
    if ($rServ->{'dns_zone'}->{$Zone}->{'ddns_auth'} =~ /key\/dhcp:(\S+)/) {
      my $Key = $1;
      my $KeyName = "$Zone.dhcp";
      my $Master = '';
      # Find the master
      my $DSG = $rServ->{'service'}->{'DNS Server Group'};
      FIND_MASTER: foreach my $SG (keys %$DSG) {
	  next unless (defined $DSG->{$SG}->{'member'}->{'dns_zone'});

	  foreach my $TZone (keys %{$DSG->{$SG}->{'member'}->{'dns_zone'}}) {
	    if (lc($Zone) eq lc($TZone)) {
	      next unless (defined $DSG->{$SG}->{'member'}->{'machine'});

	      foreach my $Mach (keys %{$DSG->{$SG}->{'member'}->{'machine'}}) {
		my $MInfo = $DSG->{$SG}->{'member'}->{'machine'}->{$Mach};
		if (defined $MInfo->{'attr'}) {
		  if ($MInfo->{'attr'}->{'Server Type'} eq 'master') {
		    $Master = $Mach;
		    last FIND_MASTER;
		  }
		}
	      }
	    }
	  }
	}
      if ($debug >= 2 && $Master eq '') {
	warn "No master nameserver found for zone: $Zone";
      }
      next if ($Master eq ''); # No master found, can't update!

      if (!defined $rServ->{'machine'}->{$Master}) {
	die_msg("Unable to find machine: $Master for $Zone");
      }
      my $MasterIP = CMU::Netdb::helper::long2dot
	($rServ->{'machine'}->{$Master}->{'ip_address'});
      $ZoneInfo{'keys'}->{$KeyName} = {'value' => $Key};
      $ZoneInfo{'zones'}->{"$Zone."} = {'key' => $KeyName,
					'master' => $MasterIP};
    }elsif($debug >= 2) {
      warn "No DDNS update key found for zone: $Zone";
    }
  }
  return \%ZoneInfo;
}

sub gen_zone_map {
  my ($dbh) = @_;

  my $zoneinfo = CMU::Netdb::list_dns_zones($dbh, $DBUSER, '');
  if (!ref $zoneinfo) {
    die_msg("Error retrieving zone data from list_dns_zones: ".$zoneinfo);
  }

  my %ColMap = %{CMU::Netdb::makemap($zoneinfo->[0])};
  shift(@$zoneinfo);

  my %IDMap;
  foreach my $row (@$zoneinfo) {
    my $id = $row->[$ColMap{'dns_zone.id'}];
    my $name = $row->[$ColMap{'dns_zone.name'}];
    $IDMap{$id} = $name;
  }

  my %ParentMap;
  foreach my $row (@$zoneinfo) {
    my $id = $row->[$ColMap{'dns_zone.id'}];
    my $parent = $row->[$ColMap{'dns_zone.parent'}];
    $ParentMap{$id} = $IDMap{$parent};
  }

  return \%ParentMap;
}

# Generate the basic options declarations. No need to restrict these to
# particular servers, since they don't take much space (normally) and just
# define the format for options.
sub gen_options_declarations {
  my ($dbh, $rServices) = @_;

  my $nbTypes = CMU::Netdb::list_dhcp_option_types
    ($dbh, $DBUSER, "dhcp_option_type.builtin != 'Y'");
  if (!ref $nbTypes) {
    die_msg("Error: loading non-builtin options: not a ref \n");
    $dbh->disconnect();
    exit -2;
  }
  my %pos = %{CMU::Netdb::makemap($nbTypes->[0])};
  shift(@$nbTypes);

  my %OptionSpaces;
  my %OD;

  foreach my $T (sort { $a->[$pos{'dhcp_option_type.name'}] cmp
			  $b->[$pos{'dhcp_option_type.name'}] }
		 @$nbTypes) {
    my $OName = $T->[$pos{'dhcp_option_type.name'}];
    $OName =~ s/^option\s+//;

    my ($prefix, $suffix) = CMU::Netdb::splitHostname($OName);

    if ($suffix ne '' && !defined $OptionSpaces{$prefix}) {
      $OD{1} .= "option space $prefix;\n";
      $OptionSpaces{$prefix} = 1;
    }
    $OD{2} .= "option $OName code ".
      $T->[$pos{'dhcp_option_type.number'}]." = ".
	format_printable($T->[$pos{'dhcp_option_type.format'}]).
	  ";\n";
  }
  return $OD{1}.$OD{2}."\n";
}

# Load the services file. It's loaded into a generic structure that is
# used throughout the script to access particular components of the file.
sub load_services {
  my ($File) = @_;

  my %svcs;
  my $cur;
  my $entity;
  my $stype;
  my $mtype;
  my $mname;

  open(SIF, "<$File") or die_msg("Can't open $File: $!\n");

  while(<SIF>) {
    chomp;
    next if /^\s*$/;
    next if /^\#/;

    if (/^(sif-header|dns_zone|machine|subnet)\s+\"?([^\"]*)\"?\s*{/) {
      $entity = $1;
      $cur = $2 || "attr"; # for sif-header
      $svcs{$entity}{$cur} = {};
    ENTITY: while(<SIF>) {
	last ENTITY if /^};$/;
	if (/^\s+(\S+)\s+([^;]*);$/){
	  $svcs{$entity}{$cur}{$1} = $2;
	}
      }
      # services are different then everything else :P
    } elsif(/^service\s+\"([^\"]+)\"\s+type\s+\"([^\"]+)\"\s+{/) {
      $cur = $1;
      $stype = $2;
      $svcs{'service'}{$stype}{$cur} = {};
    SVC: while(<SIF>) {
	last SVC if /^};$/;
	if(/\s+member\s+type\s+\"([^\"]+)\"\s+name\s+\"([^\"]+)\"\s+{/){
	  $mtype = $1;
	  $mname = $2;
	  $svcs{'service'}{$stype}{$cur}{'member'}{$mtype}{$mname} = {};
	MEMB: while(<SIF>){
	    last MEMB if /\s+};/;
	    if(/\s+attr\s+([^=]+)\s+=\s+([^;]*);/){
	      $svcs{'service'}{$stype}{$cur}{'member'}{$mtype}{$mname}{'attr'}{$1} = $2;
	    }
	  }
	}elsif(/\s+resource\s+(\S+)\s+{/) {
	  $mtype = $1;
	  my %resInfo;
	RESOURCE: while(<SIF>) {
	    last RESOURCE if /\s+};/;
  	    if (/\s+(\S+)\s+([^;]+);$/) {
	      $resInfo{$1} = $2;
	    }
	  }
	  push(@{$svcs{'service'}{$stype}{$cur}{'resource'}{$mtype}},
	       \%resInfo);
	}elsif(/\s+dhcp_option\s+\"([^\"]+)\"\s+{/) {
	  $mtype = $1;
	DHOPTION: while(<SIF>) {
	    last DHOPTION if /\s+};/;
 	    if (/\s+(\S+)\s+([^;]+);$/) {
	      $svcs{'service'}{$stype}{$cur}{'dhcp_option'}{$mtype}{$1} = $2;
	    }
	  }
	}elsif(/\s+attr\s+([^=]+)\s+=\s+([^;]*);/){
	  $svcs{'service'}{$stype}{$cur}{'attr'}{$1} = $2;
	}elsif (/^\s+(\S+)\s+([^;]*);$/){
	  $svcs{'service'}{$stype}{$cur}{$1} = $2;
	}
      }
    }
  }
  return \%svcs;
}

sub load_template {
  my ($File) = @_;

  unless (-r $File) {
    my $T = '
%hdr%

if (substring (option dhcp-client-identifier, 1, 3) = "RAS") {
       ignore booting;
}

# DHCP Failover Configuration
%failover%

# OMAPI Configuration
%omapi%

# DNS Zones and Keys
%zones%

# Option Declarations
%options_declarations%

# Global Options
%global_options%

# Class Declarations
%classes%

# Subnet Declarations
%subnets%

# Dynamic Hosts
%dynhosts%

# Static Hosts
%stathosts%
';
    return $T;
  }

  open(FILE, $File) or die_msg("Could not open template file: $File: $!");
  my @T = <FILE>;
  return join('', @T);
}

sub format_printable {
  my ($in) = @_;
  return lc($in);
}


### Output functions #
sub output_hdr {
  my ($rDD, $Server) = @_;
  $Server = lc($Server);
  return "server-identifier $Server;\n";
}

sub output_failover {
  my ($rDD, $Server, $rServ) = @_;

  my %FailoverInfo;
  my $Out = '';

  my $ServSInfo = $rDD->{'servers'}->{$Server}->{'subnet'};
  foreach my $Subnet (keys %{$ServSInfo}) {
    if ($ServSInfo->{$Subnet}->{'failover'} eq 'master' or
	$ServSInfo->{$Subnet}->{'failover'} eq 'secondary') {
      my $FPeer = $ServSInfo->{$Subnet}->{'failover_name'};
      if (defined $FailoverInfo{$FPeer}) {
	if ($FailoverInfo{$FPeer}->{'type'} ne
	    $ServSInfo->{$Subnet}->{'failover'}) {
	  die_msg("Incompatible failover mode for $Server/$Subnet/$FPeer");
	}
      }else{
	$FailoverInfo{$FPeer} = 
	  {'type' => $ServSInfo->{$Subnet}->{'failover'},
	   'peer' => $ServSInfo->{$Subnet}->{'failover_peer'},
	  };
      }
    }
  }

  foreach my $Peer (keys %FailoverInfo) {
    my $Type = $FailoverInfo{$Peer}->{'type'};
    $Out .= "failover peer \"$Peer\" {\n";
    $Out .= "\t".($Type eq 'master' ? 'primary' : 'secondary').";\n";
    $Out .= "\taddress ".get_machine_ip($Server, $rServ).";\n";
    $Out .= "\tport ".($Type eq 'master' ? '519' : '520').";\n";
    $Out .= "\tpeer address ".
      get_machine_ip($FailoverInfo{$Peer}->{'peer'}, $rServ).";\n";
    $Out .= "\tpeer port ".($Type eq 'master' ? '520' : '519').";\n";

    $Out .= "\tmax-response-delay 30;\n";
    $Out .= "\tmax-unacked-updates 10;\n";
    $Out .= "\tload balance max seconds 3;\n";

    if ($Type eq 'master') {
      $Out .= "\tmclt 3600;\n";
      $Out .= "\tsplit 128;\n";
    }
    $Out .= "}\n";
  }

  return $Out;
}

sub output_omapi {
  my ($rDD, $Server) = @_;

  return '' unless (defined $rDD->{'servers'}->{$Server}->{'omapi'});
  my $Key = $rDD->{'servers'}->{$Server}->{'omapi'}->{'key'};
  my $Port = $rDD->{'servers'}->{$Server}->{'omapi'}->{'port'};
  return "key defomapi {
\talgorithm hmac-md5;
\tsecret $Key;
};\n
omapi-key defomapi;
omapi-port $Port;\n";

}

# If the server is enabled for "all zones", then we don't restrict the
# zones going in. Otherwise, we get the authoritative zone of every machine
# added to the configuration for the server. Those that exist as zones here
# will then be added. Also, we'll need to add zones for any dynamic pools
# defined in the configuration. 

# To do this, we'll have the zone IDs for the host_name_zone, but we'll
# need a mapping of dns_zone.id -> [NAME of the authoritative zone]
sub output_zones {
  my ($rDD, $Server) = @_;

  my ($ZoneData, $KeyData);

  my $CfgAllZones = ($rDD->{'servers'}->{$Server}->{'config_all_zones'} 
		     eq 'Yes' ? 1 : 0);
  my %ReqKeys;

  foreach my $Zone (sort {$a cmp $b} keys %{$rDD->{'zones'}->{'zones'}}) {
    next unless ($CfgAllZones or
		 defined $rDD->{'servers'}->{$Server}->{'zones'}->{$Zone});
    $ZoneData .= "zone $Zone {
\tprimary ".$rDD->{'zones'}->{'zones'}->{$Zone}->{'master'}.";
\tkey ".$rDD->{'zones'}->{'zones'}->{$Zone}->{'key'}.";\n}\n";
    $ReqKeys{$rDD->{'zones'}->{'zones'}->{$Zone}->{'key'}} = 1;
  }

  foreach my $Key (sort {$a cmp $b} keys %{$rDD->{'zones'}->{'keys'}}) {
    next unless (defined $ReqKeys{$Key});

    $KeyData .= "key $Key {
\talgorithm HMAC-MD5.SIG-ALG.REG.INT;
\tsecret ".$rDD->{'zones'}->{'keys'}->{$Key}->{'value'}.";\n};\n";
  }

  return $KeyData.$ZoneData;
}

sub output_options_decls {
  my ($rDD, $Server) = @_;

  return $rDD->{'options_declarations'};
}

sub output_global_options {
  my ($rDD, $Server) = @_;

  return output_opt_generic($rDD->{'servers'}->{$Server}->{'goptions'}, 0);
}

sub output_classes {
  my ($rDD, $Server) = @_;

  my $Out;
  foreach my $Class (sort {$a cmp $b} 
		     keys %{$rDD->{'servers'}->{$Server}->{'classes'}}) {
    if (!defined $rDD->{'classes'}->{$Class} or 
	!defined $rDD->{'classes'}->{$Class}->{'match'}) {
      die_msg("No match information for class $Class");
    }

    $Out .= "class \"$Class\" {
\tmatch ".$rDD->{'classes'}->{$Class}->{'match'}.";\n";

    if (defined $rDD->{'classes'}->{$Class}->{'options'}) {
      $Out .= output_opt_generic($rDD->{'classes'}->{$Class}->{'options'}, 1);
    }
    $Out .= "}\n";
  }
  return $Out;
}

sub output_subnets {
  my ($rDD, $Server) = @_;

  # Subnets that are IN a share
  my %SharedSubnets;

  # Subnets not in a share
  my %Subnets;

  foreach my $Subnet (sort {$a cmp $b} 
		      keys %{$rDD->{'servers'}->{$Server}->{'subnet'}}) {
    my $SInfo = $rDD->{'subnets'}->{$Subnet};
    my $ServSInfo = $rDD->{'servers'}->{$Server}->{'subnet'}->{$Subnet};

    my ($Out, $Dynamic, $FailoverPeer) = ('', 0, '');

    $Dynamic = 1 if ($ServSInfo->{'type'} eq 'dynamic');

    if ($ServSInfo->{'failover'} eq 'master' or
	$ServSInfo->{'failover'} eq 'secondary') {
      $FailoverPeer = $ServSInfo->{'failover_name'};
    }

    $Out .= "# $Subnet
subnet ".$SInfo->{'base'}." netmask ".$SInfo->{'mask'}." {\n";

    # Classes
    if (defined $SInfo->{'classes'}) {
      foreach my $Class (keys %{$SInfo->{'classes'}}) {
	if (!defined $rDD->{'classes'}->{$Class}) {
	  warn "Class $Class referenced on $Subnet but not found!";
	  next;
	}
	$Out .= "\tclass \"$Class\" {\n";
	
	# Only print the match if the class is not also defined in the
	# global scope.
	unless (defined $rDD->{'servers'}->{$Server}->{'classes'}->{$Class}) {
	  $Out .= "\t\tmatch ".$rDD->{'classes'}->{$Class}->{'match'}.";\n";
	}
	
	if (defined $rDD->{'classes'}->{$Class}->{'options'}) {
	  $Out .= output_opt_generic($rDD->{'classes'}->{$Class}->{'options'},
				     2);
	}
	$Out .= "\t}\n";
      }
    }

    unless ($SInfo->{'expire_static'} eq '0') {
      $Out .= "\tdefault-lease-time ".$SInfo->{'expire_static'}.";\n";
      $Out .= "\tmax-lease-time ".$SInfo->{'expire_static'}.";\n";
    }

    if (defined $SInfo->{'options'}) {
      $Out .= output_opt_generic($SInfo->{'options'}, 1);
    }

    if ($Dynamic && defined $SInfo->{'pool'}->{'main'}) {
      # Generate pool information
      $Out .= "\tpool {\n";

      if ($FailoverPeer ne '') {
	$Out .= "\t\tfailover peer \"".$FailoverPeer."\";\n";
      }

      unless ($SInfo->{'expire_dynamic'} eq '0') {
	$Out .= "\t\tmax-lease-time ".$SInfo->{'expire_dynamic'}.";\n";
	$Out .= "\t\tdefault-lease-time ".$SInfo->{'expire_dynamic'}.";\n";
      }

      # Output pool IP ranges
      $Out .= join("\n", 
		   map { "\t\trange ".
			   CMU::Netdb::long2dot($_->{'start'})." ".
			   CMU::Netdb::long2dot($_->{'end'}).";"
			   } @{$SInfo->{'pool'}->{'main'}->{'ranges'}})."\n";

      # Output pool access information
      $Out .= output_poolacl_generic($SInfo->{'pool'}->{'main'});

      $Out .= "\t}\n"; # Closing the pool

      # Note the zone use
      foreach my $ZID (keys %{$SInfo->{'pool'}->{'main'}->{'zones_used'}}) {
	my $ZName = $rDD->{'zone_parents'}->{$ZID};
	die_msg("Unknown zone (zones_used) ($ZID)") if ($ZName eq '');
	$rDD->{'servers'}->{$Server}->{'zones'}->{$ZName.'.'} = 1;
      }
    }
    $Out .= "}\n"; # Closing the subnet

    if ($SInfo->{'subnet_share'} eq '0') {
      $Subnets{$Subnet} = $Out;
    }else{
      $SharedSubnets{$Subnet} = $Out;
    }
  }

  my $SOut;
  foreach my $Share (sort {$rDD->{'shares'}->{$a}->{'abbreviation'} cmp
			     $rDD->{'shares'}->{$b}->{'abbreviation'} }
			       keys %{$rDD->{'shares'}}) {
    my $IsNeeded = 0;
    my @Members = keys %{$rDD->{'shares'}->{$Share}->{'members'}};

    # First see if it's needed (if any subnets are attached to the server).
    foreach my $M (@Members) {
      $IsNeeded = 1 if (defined $SharedSubnets{$M});
    }

    next unless ($IsNeeded);

    my $ShareName = $rDD->{'shares'}->{$Share}->{'name'};
    my $ShareAbbrev = $rDD->{'shares'}->{$Share}->{'abbreviation'};

    $SOut .= "# ".$rDD->{'shares'}->{$Share}->{'name'}."\n";
    $SOut .= "shared-network shared-$ShareAbbrev {\n";

    # Now, if any aren't defined, we'll whine
    foreach my $M (@Members) {
      unless (defined $SharedSubnets{$M}) {
	die_msg("Subnet \"$M\" not attached to server \"$Server\" but is ".
		"needed by share \"".$rDD->{'shares'}->{$Share}->{'name'}.
		"\"");
      }
      $SOut .= join("\n", map { "\t$_" } split(/\n/, $SharedSubnets{$M}))."\n";
    }
    $SOut .= "}\n";
  }

  foreach my $Subnet (sort {$a cmp $b} keys %Subnets) {
    $SOut .= $Subnets{$Subnet};
  }

  return $SOut;
}

# Add dynamic hosts for every required class. The required classes
# are all those required by every subnet defined for the server. We'll
# need to determine the subnet of every required class.
#
# In the end, for our single pass through all the machines, we'll
# need to have a hash from the subnet ID to a list of the classes that
# need to be defined with hosts from this subnet.
sub output_dynhosts {
  my ($rDD, $Server) = @_;

  my %SubnetAbbrev;
  my %SubnetID;
  # Create a [subnet abbrev] -> [subnet name] map
  foreach my $Subnet (keys %{$rDD->{'subnets'}}) {
    $SubnetAbbrev{$rDD->{'subnets'}->{$Subnet}->{'abbreviation'}} = 
      $rDD->{'subnets'}->{$Subnet}->{'id'};
    $SubnetID{$rDD->{'subnets'}->{$Subnet}->{'id'}} = $Subnet;
  }

  my %Classes;

  # Create a list of all classes referenced on subnets for this server
  foreach my $Subnet (keys %{$rDD->{'servers'}->{$Server}->{'subnet'}}) {
    # Skip if this subnet isn't dynamic for this server
    next if ($rDD->{'servers'}->{$Server}->{'subnet'}->{$Subnet}->{'type'}
	     ne 'dynamic');

    my $Abbrev = $rDD->{'subnets'}->{$Subnet}->{'abbreviation'};
    $Classes{"${Abbrev}_dynamic_reg"} = 1;

    next unless (defined $rDD->{'subnets'}->{$Subnet}->{'pool'}->{'main'});

    foreach my $Reg (@{$rDD->{'subnets'}->{$Subnet}->{'pool'}->{'main'}->{'deny'}}) {
      if ($Reg->{'type'} eq 'class') {
       $Classes{$Reg->{'class'}} = 1;
     }
    }
    foreach my $Reg (@{$rDD->{'subnets'}->{$Subnet}->{'pool'}->{'main'}->{'allow'}}) {
      if ($Reg->{'type'} eq 'class') {
	$Classes{$Reg->{'class'}} = 1;
      }
    }
  }

  foreach my $C (keys %Classes) {
    $rDD->{'servers'}->{$Server}->{'classes'}->{$C} = $Classes{$C};
  }

  my %Subnets;
  my $Out = '';
  # For each class, determine the subnet it's on.
  foreach my $Class (keys %Classes) {
    $Class =~ /(.+)\_(.+)\_(.+)$/;
    my ($Abbrev, $Type, $Mode) = ($1, $2, $3);
    $Subnets{$SubnetAbbrev{$Abbrev}}->{'classes'}->{$Class} = {};
  }

  foreach my $Mach (values %{$rDD->{'hosts'}}) {
    next unless (defined $Subnets{$Mach->{'ip_address_subnet'}});
    my @MClasses;
    if ($Mach->{'mode'} eq 'static' or
	($Mach->{'mode'} eq 'reserved' && $Mach->{'mac_address'} ne '')) {
      if ($Mach->{'flags'} =~ /suspend/) {
	@MClasses = qw/static_deny/;
      }elsif($Mach->{'flags'} =~ /roaming/) {
	@MClasses = qw/static_reg static_roam/;
      }else{
	@MClasses = qw/static_reg/;
      }
    }elsif($Mach->{'mode'} eq 'dynamic') {
      if ($Mach->{'flags'} =~ /suspend/) {
	@MClasses = qw/dynamic_deny/;
      }elsif($Mach->{'flags'} =~ /roaming/) {
	@MClasses = qw/dynamic_reg dynamic_roam/;
      }else{
	@MClasses = qw/dynamic_reg/;
      }
    }
 
    my $Abbrev = $rDD->{'subnets'}->{$SubnetID{$Mach->{'ip_address_subnet'}}}->{'abbreviation'};

    @MClasses = map { $Abbrev.'_'.$_ } @MClasses;
    my $SClass = $Subnets{$Mach->{'ip_address_subnet'}}->{'classes'};
    foreach my $Class (@MClasses) {
      next unless (defined $SClass->{$Class});
      my $MAC = $Mach->{'mac_address'};
      $MAC =~ s/(\w{2})/$1:/g;
      $MAC =~ s/:$//;
      $Out .= '# NetReg Machine ID'.$Mach->{'id'}."\n";
      $Out .= 'subclass "'.$Class.'" 1:'.$MAC." {\n";
      if ($Mach->{'host_name'} ne '') {
	my ($Host, $Domain) = CMU::Netdb::splitHostname($Mach->{'host_name'});
	$Out .= "\tddns-hostname \"$Host\";\n";
	$Out .= "\toption domain-name \"$Domain\";\n";
      }
      if (defined $Mach->{'options'}) {
	$Out .= output_opt_generic($Mach->{'options'}, 1);
      }
      $Out .= "}\n";
    }

    # Register zone use
    if ($#MClasses != -1 && $Mach->{'host_name'} ne '') {
      die_msg("No host_name_zone for ".$Mach->{'id'}."!")
	if ($Mach->{'host_name_zone'} eq '');

      my $Zone = $rDD->{'zone_parents'}->{$Mach->{'host_name_zone'}};
      die_msg("Unknown zone (host_name_zone) (".
	      $Mach->{'host_name_zone'}.")") if ($Zone eq '');
      $rDD->{'servers'}->{$Server}->{'zones'}->{$Zone.'.'} = 1;
    }
  }
  return $Out;
}

sub output_stathosts {
  my ($rDD, $Server) = @_;

  # Determine all the IDs of subnets printed for this server
  my %Subnets;

  foreach my $Subnet (keys %{$rDD->{'servers'}->{$Server}->{'subnet'}}) {
    $Subnets{$rDD->{'subnets'}->{$Subnet}->{'id'}} = $Subnet
  }

  my $Out = '';
  foreach my $Mach (values %{$rDD->{'hosts'}}) {
    next unless (defined $Subnets{$Mach->{'ip_address_subnet'}});
    next if ($Mach->{'flags'} =~ /suspend/);
    next unless ($Mach->{'mode'} eq 'static' or 
		 ($Mach->{'mode'} eq 'reserved' &&
		  $Mach->{'host_name'} ne '' &&
		  $Mach->{'mac_address'} ne '' &&
		  $Mach->{'ip_address'} ne '0'));
    my $MAC = $Mach->{'mac_address'};
    $MAC =~ s/(\w{2})/$1:/g;
    $MAC =~ s/:$//;
    $Out .= '# NetReg Machine ID'.$Mach->{'id'}."\n";
    $Out .= 'host '.lc($Mach->{'host_name'})." {
\thardware ethernet $MAC;
\tfixed-address ".CMU::Netdb::long2dot($Mach->{'ip_address'}).";
\toption domain-name \"".lc(domainof($Mach->{'host_name'}))."\";\n";

    if (defined $Mach->{'options'}) {
      $Out .= output_opt_generic($Mach->{'options'}, 1);
    }
    $Out .= "}\n";
  }
  return $Out;
}

# Print options from the generic format
sub output_opt_generic {
  my ($OptTop, $level) = @_;

  my $Padding = "\t"x$level;
  my $output; 
  foreach (keys %$OptTop) {
    $output .= "$Padding$_ $OptTop->{$_}->{value}";
    $output .= ';' if ($OptTop->{$_}->{value} !~ /[};]$/);
    $output .= "\n";
  }
  return $output; 
}

sub output_poolacl_generic {
  my ($Pool) = @_;

  my $Out = '';
  foreach my $Type (qw/deny allow/) {
    foreach my $Rec (@{$Pool->{$Type}}) {
      my $Desc = '';
      if ($Rec->{'type'} eq 'bootp_clients') {
	$Desc = 'dynamic bootp clients';
      }elsif($Rec->{'type'} eq 'class') {
	$Desc = 'members of "'.$Rec->{'class'}.'"';
      }elsif($Rec->{'type'} eq 'unknown') {
	$Desc = 'unknown clients';
      }elsif($Rec->{'type'} eq 'known') {
	$Desc = 'known clients';
      }else{
	die_msg("Unknown pool ACL ($Type, ".$Rec->{'type'}.")");
      }
      $Out .= "\t\t$Type $Desc;\n";
    }
  }
  return $Out;
}

sub get_machine_ip {
  my ($hostname, $rServ) = @_;

  unless (defined $rServ->{'machine'}->{$hostname}) {
    die_msg("get_machine_ip($hostname) couldn't find hostname");
  }
  return CMU::Netdb::long2dot
    ($rServ->{'machine'}->{$hostname}->{'ip_address'});
}

sub domainof {
  my ($hostname) = @_;
  my ($h, $d) = CMU::Netdb::splitHostname($hostname);
  return $d;
}

sub dhcpxfer {
  my ($rDD, $Server) = @_;

  $Server = lc($Server);
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
  my $com = $RSYNC_PATH." ".$RSYNC_OPTIONS." ".
    "$XFERPATH/dhcpd.conf.$Server $RSYNC_REM_USER\@$Server:$XFERPATH";
  print "Copying...\n";
  my $res = system("/bin/cp $GENPATH/dhcpd.conf.$Server ".
		   "$XFERPATH/dhcpd.conf.$Server");
  $res = $res >> 8;
  if ($res != 0) {
    die_msg("Error copying $GENPATH/dhcpd.conf.$Server to $XFERPATH!");
  }

  # Silence the output
  $com .= ' > /dev/null';

  print "Command: $com\n";
  unless ($debug) {
    my $res = system($com);
    $res = $res >> 8;
    print "Result: $res\n";
    if ($res != 0) {
      CMU::Netdb::netdb_mail('dhcp.pl', 
			     "Error transferring DHCP configuration to ".
			     "$Server, result: $res", 'dhcp.pl error');
    }
  }
}
