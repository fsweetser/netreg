#!/usr/bin/perl
#
#

#BEGIN {
#  my @LPath = split(/\//, __FILE__);
#  push(@INC, join('/', @LPath[0..$#LPath-1]));
#}

#use vars_l;
#use lib $vars_l::NRLIB;
use lib "/usr/ng/lib/perl5";
use CMU::Netdb;
use Config::General;
use Getopt::Long;

use strict;

use Data::Dumper;

my $user = 'netreg';
my $DEBUG = 2;
my $configfile;

my $result = GetOptions ("config=s" => \$configfile,
			 "debug=i" => \$DEBUG);

if (!$result || !$configfile) {
  usage();
  exit 0;
}



my $conf = new Config::General(-ConfigFile => $configfile,
			      );
my %output;
my %exported;
my $outconf = new Config::General(
				  -ConfigHash => \%output,
				 );


my %config = $conf->getall;


my $dbh = CMU::Netdb::lw_db_connect();

# TODO/FIXME:
# Not adding subnet shares at present (not required for qatar)

foreach my $machine (keys %{$config{machine}}) {
  add_machines_to_output($machine);
}

foreach my $zone ( keys %{$config{dns_zone}} ) {
  add_zones_to_output($zone);
}

foreach my $subnet (keys %{$config{subnet}}) {
  add_subnets_to_output($subnet);
}

foreach my $group (keys %{$config{group}}) {
  add_groups_to_output($group);
}

foreach my $vlan (keys %{$config{vlan}}) {
  add_vlans_to_output($vlan);
}

foreach my $service (keys %{$config{service}}) {
  add_services_to_output($service);
}

# Add global and subnet default dhcp options
$output{global_settings}{dhcp_option} = fetch_dhcp_options('global',0);
push @{$output{global_settings}{dhcp_option}},  @{fetch_dhcp_options('subnet',0)};


print $outconf->save_string();


sub usage {
  print STDERR "Usage: $0 --config file [--debug N]\n";
}


sub add_zones_to_output {
  my $zone = shift;

  print STDERR "Processing zone $zone\n" if ($DEBUG >= 4);

  my $res = CMU::Netdb::list_dns_zones($dbh, $user, "name LIKE '$zone'");

  print STDERR Data::Dumper->Dump([$res], ['res']) if ($DEBUG >= 10);

  die "Error fetching dns_zone $zone ($res)\n" if (!ref $res);

  my %pos = %{CMU::Netdb::makemap($res->[0])};

  shift @$res;

  foreach my $row (@$res) {
    next if (exists $output{dns_zone}{$row->[$pos{'dns_zone.name'}]});
    foreach my $key (sort grep(!/\.(id|version|parent)/,keys %pos)) {
      if ($key eq 'dns_zone.ddns_auth' 
	  && exists $config{dns_zone}{$zone}{keys}
	  && $config{dns_zone}{$zone}{keys} =~ m/no/i) {

	$row->[$pos{$key}] =~ s/((^|\s)[\S]*key[\S]*):\S*(?=(\s|$))/\1:REDACTED /gi;
      }
      $output{dns_zone}{$row->[$pos{'dns_zone.name'}]}{$key} = $row->[$pos{$key}];
    }


    # DNS Resources
    $output{dns_zone}{$row->[$pos{'dns_zone.name'}]}{dns_resource} = fetch_dns_resources('dns_zone', $row->[$pos{'dns_zone.id'}]);

    # Protections
    $output{dns_zone}{$row->[$pos{'dns_zone.name'}]}{protection} = fetch_protections('dns_zone', $row->[$pos{'dns_zone.id'}]);

  }


  if ($config{dns_zone}{$zone}{machines} =~ m/yes/i) {
    add_machines_to_output("%.$zone");
  }

}

sub add_machines_to_output {
  my $machine = shift;
  my $is_sql = shift;
  print STDERR "Processing machine $machine\n" if ($DEBUG >= 5);
  my $where;
  if ($is_sql) {
    $where = $machine;
  } else {
    $where = "host_name LIKE '$machine'";
  }

  my $res = CMU::Netdb::list_machines($dbh, $user, $where);

  print STDERR Data::Dumper->Dump([$res], ['res']) if ($DEBUG >= 10);

  die "Error fetching machine $machine ($res)\n" if (!ref $res);

  my %pos = %{CMU::Netdb::makemap($res->[0])};

  shift @$res;

  foreach my $row (@$res) {
    next if (exists $output{machine}{$row->[$pos{'machine.host_name'}]});
    foreach my $key (sort grep(!/\.(id|version|ip_address_zone|ip_address_subnet|host_name_zone)/,keys %pos)) {
      $output{machine}{$row->[$pos{'machine.host_name'}]}{$key} = $row->[$pos{$key}];
    }

    $output{machine}{$row->[$pos{'machine.host_name'}]}{'machine.ip_address_subnet'} = $exported{subnet}{$row->[$pos{'machine.ip_address_subnet'}]};

    # DNS Resources
    $output{machine}{$row->[$pos{'machine.host_name'}]}{dns_resource} = fetch_dns_resources('machine', $row->[$pos{'machine.id'}]);

    # Protections
    $output{machine}{$row->[$pos{'machine.host_name'}]}{protection} = fetch_protections('machine', $row->[$pos{'machine.id'}]);

    # DHCP Options
    $output{machine}{$row->[$pos{'machine.host_name'}]}{dhcp_option} = fetch_dhcp_options('machine', $row->[$pos{'machine.id'}]);

    # Attributes
    $output{machine}{$row->[$pos{'machine.host_name'}]}{attribute} = fetch_attributes('machine', $row->[$pos{'machine.id'}]);


    # TODO:
    # TrunkSet?

  }



}


sub add_groups_to_output {
  my $group = shift;
  print STDERR "Processing group '$group'\n" if ($DEBUG >= 6);
  my $where;
  $where = "name like '$group'";

  my $res = CMU::Netdb::list_groups($dbh, $user, $where);

  print STDERR Data::Dumper->Dump([$res], ['res']) if ($DEBUG >= 10);

  die "Error fetching group $group ($res)\n" if (!ref $res);

  my %pos = %{CMU::Netdb::makemap($res->[0])};

  shift @$res;

  foreach my $row (@$res) {
    next if (exists $output{group}{$row->[$pos{'groups.name'}]});
    foreach my $key (sort grep(!/\.(id|version)/,keys %pos)) {
      $output{group}{$row->[$pos{'groups.name'}]}{$key} = $row->[$pos{$key}];
    }


    # Protections
    $output{group}{$row->[$pos{'groups.name'}]}{protection} = fetch_protections('groups', $row->[$pos{'groups.id'}]);

    # Attributes
    $output{group}{$row->[$pos{'groups.name'}]}{attribute} = fetch_attributes('groups', $row->[$pos{'groups.id'}]);

    # Memberships
    my $rGmem = CMU::Netdb::list_members_of_group($dbh, $user, $row->[$pos{'groups.id'}], '');

    if (!ref $rGmem) {
      die "error fetching members of group ".$row->[$pos{'groups.name'}];
    }

    my %gpos = %{CMU::Netdb::makemap($rGmem->[0])};
    shift @$rGmem;
    foreach my $mem (@$rGmem) {
      push @{$output{group}{$row->[$pos{'groups.name'}]}{member}}, $mem->[$gpos{'credentials.authid'}];
    }

  }



}


sub add_subnets_to_output {
  my $subnet = shift;

  print STDERR "Processing subnet $subnet\n" if ($DEBUG >= 4);

  my ($base, $mask, $where);
  if ($subnet =~ m/^(\d+\.\d+\.\d+\.\d+)\/(\d+)$/) {
    $base = $1;
    $mask = CIDR2mask($2);
    $where = "base_address = INET_ATON('$base') AND network_mask = INET_ATON('$mask')";
  } elsif ($subnet =~ m/^(\d+\.\d+\.\d+\.\d+)\/(\d+\.\d+\.\d+\.\d+)$/) {
    $base = $1;
    $mask = $2;
    $where = "base_address = INET_ATON('$base') AND network_mask = INET_ATON('$mask')";
  } elsif ($subnet =~ m/^\d+$/) {
    # Subnet id
    $where = "id = $1";
  } else {
    # Match against subnet name
    $where = "name LIKE '$subnet'";
  }

  print STDERR "Where clause is '$where'\n" if ($DEBUG >= 7);

  my $res = CMU::Netdb::list_subnets($dbh, $user, $where);

  print STDERR Data::Dumper->Dump([$res], ['res']) if ($DEBUG >= 10);

  die "Error fetching subnet $subnet ($res)\n" if (!ref $res);

  my %pos = %{CMU::Netdb::makemap($res->[0])};

  shift @$res;

  foreach my $row (@$res) {
    my $confname = $row->[$pos{'subnet.name'}];
    $confname =~ s/\s/_/g;
    next if (exists $output{subnet}{$confname});
    my $sid = $row->[$pos{'subnet.id'}];
    foreach my $key (sort grep(!/\.(id|version)/, keys %pos)) {
      $output{subnet}{$confname}{$key} = $row->[$pos{$key}];
    }

    $exported{subnet}{$sid} = $confname;

    # Registration Types & Quotas & Protections
    my $modes = CMU::Netdb::list_subnet_registration_modes($dbh, $user, "subnet_registration_modes.subnet='$sid'");

    die "Error fetching subnet registration modes" if (!ref $modes);

    my %mpos = %{CMU::Netdb::makemap($modes->[0])};
    shift @$modes;

    foreach my $mrow (@$modes) {
      my $entry = {};
      push @{$output{subnet}{$confname}{subnet_registration_mode}}, $entry;
      foreach my $key (sort grep(!/\.(id|version|subnet)/, keys %mpos)) {
	$entry->{$key} = $mrow->[$mpos{$key}];
      }

      # Protections
      $entry->{protection} = fetch_protections('subnet_registration_modes', $mrow->[$mpos{'subnet_registration_modes.id'}]);


    }

    if ($config{subnet}{$subnet}{machines} =~ m/yes/i) {
      add_machines_to_output("ip_address_subnet = ".$sid, 1);
    }

    # Protections
    $output{subnet}{$confname}{protection} = fetch_protections('subnet', $sid);

    # DHCP Options
    $output{subnet}{$confname}{dhcp_option} = fetch_dhcp_options('subnet', $sid);

    # Attributes
    $output{subnet}{$confname}{attribute} = fetch_attributes('subnet', $sid);

    # Dns Zones
    if ($config{subnet}{$subnet}{dns_zones} !~ m/no/i) {
      my $dref = CMU::Netdb::list_subnet_domains($dbh, $user,
						 "subnet='$sid'",
						 1);

      die "Error fetching subnet domains for $sid ($dref)\n" if (!ref $dref);

      print STDERR Data::Dumper->Dump([$dref], ['dref']) if ($DEBUG >= 10);

      my %dpos = %{CMU::Netdb::makemap($dref->[0])};
      shift @$dref;

      foreach my $drow (@$dref) {
	push @{$output{subnet}{$confname}{dns_zone}}, $drow->[$dpos{'subnet_domain.domain'}];

	add_zones_to_output($drow->[$dpos{'subnet_domain.domain'}]);
      }
    }

    # Vlans
    if ($config{subnet}{$subnet}{vlans} !~ m/no/i) {
      my $vref = CMU::Netdb::list_subnet_presences($dbh, $user, "vlan_subnet_presence.subnet='$sid'");

      die "Error fetching subnet vlans for $sid ($vref)\n" if (!ref $vref);

      print STDERR Data::Dumper->Dump([$vref], ['vref']) if ($DEBUG >= 10);

      my %vpos = %{CMU::Netdb::makemap($vref->[0])};
      shift @$vref;

      foreach my $vrow (@$vref) {
	my $vlconfname = $vrow->[$vpos{'vlan.name'}];
	$vlconfname =~ s/\s/_/g;
	push @{$output{subnet}{$confname}{vlan}}, $vlconfname;

	add_vlans_to_output($vrow->[$vpos{'vlan.name'}]);
      }
    }

  }

  
}


sub add_vlans_to_output {
  my $vlan = shift;

  print STDERR "Processing vlan $vlan\n" if ($DEBUG >= 4);

  my $res = CMU::Netdb::list_vlans($dbh, $user, "name LIKE '$vlan'");

  print STDERR Data::Dumper->Dump([$res], ['res']) if ($DEBUG >= 10);

  die "Error fetching vlan $vlan ($res)\n" if (!ref $res);

  my %pos = %{CMU::Netdb::makemap($res->[0])};

  shift @$res;

  foreach my $row (@$res) {
    my $confname = $row->[$pos{'vlan.name'}];
    $confname =~ s/\s/_/g;
    next if (exists $output{vlan}{$confname});
    foreach my $key (sort grep(!/\.(id|version)/,keys %pos)) {
      $output{vlan}{$confname}{$key} = $row->[$pos{$key}];
    }


    # Protections
    $output{vlan}{$confname}{protection} = fetch_protections('vlan', $row->[$pos{'vlan.id'}]);

    # Attributes
    $output{vlan}{$confname}{attribute} = fetch_attributes('vlan', $row->[$pos{'vlan.id'}]);

    # TODO:
    # Trunk Sets

  }


}





sub add_services_to_output {
  my $service = shift;
  print STDERR "Processing service '$service'\n" if ($DEBUG >= 6);
  my $where;
  $where = "name like '$service'";

  my $typeref = CMU::Netdb::list_service_types_ref($dbh, $user, '', 'service_type.name');

  my $res = CMU::Netdb::list_services($dbh, $user, $where);

  print STDERR Data::Dumper->Dump([$res], ['res']) if ($DEBUG >= 10);

  die "Error fetching service $service ($res)\n" if (!ref $res);

  my %pos = %{CMU::Netdb::makemap($res->[0])};

  shift @$res;

  foreach my $row (@$res) {
    next if (exists $output{service}{$row->[$pos{'service.name'}]});
    foreach my $key (sort grep(!/\.(id|version|type)/,keys %pos)) {
      $output{service}{$row->[$pos{'service.name'}]}{$key} = $row->[$pos{$key}];
    }

    $output{service}{$row->[$pos{'service.name'}]}{type} = $typeref->{$row->[$pos{'service.type'}]};

    my $sid = $row->[$pos{'service.id'}];
    # Protections
    $output{service}{$row->[$pos{'service.name'}]}{protection} = fetch_protections('service', $sid);

    # Attributes
    $output{service}{$row->[$pos{'service.name'}]}{attribute} = fetch_attributes('service', $sid);

    # Memberships
    my ($sres, $rMemRow, $rMemSum, $rMemData) =
      CMU::Netdb::list_service_members($dbh, $user, "service_membership.service = $sid");

    if ($sres < 0) {
      die "error fetching members of service ".$row->[$pos{'service.name'}]. " ($sres)";
    }

#    foreach my $mem (@$rGmem) {
#      push @{$output{service}{$row->[$pos{'service.name'}]}{member}}, $mem->[$gpos{'credentials.authid'}];
#    }

    my %member_map;
    foreach (keys %$rMemRow) {
      $member_map{$rMemRow->{$_}{'service_membership.member_type'}}{$rMemRow->{$_}{'service_membership.member_tid'}}	= $_;
    }

    #print Data::Dumper->Dump([$rMemRow, $rMemSum, $rMemData], ['row', 'sum', 'data']);

    foreach my $type (keys %$rMemSum) {
      foreach my $mem (@{$rMemSum->{$type}}) {
	my $member_name;
	$member_name = $rMemData->{$type .':'.$mem}{$type.'.host_name'};
	$member_name ||= $rMemData->{$type .':'.$mem}{$type.'.name'};
	$member_name =~ s/\s/_/g;
	$output{service}{$row->[$pos{'service.name'}]}{member}{$type}{$member_name} = {};
	$output{service}{$row->[$pos{'service.name'}]}{member}{$type}{$member_name}{attribute} =
	  fetch_attributes('service_membership', $member_map{$type}{$mem});
      }
    }
	

    # DNS Resources
    $output{service}{$row->[$pos{'service.name'}]}{dns_resource} = fetch_dns_resources('service', $sid);

    # DHCP Options
    $output{service}{$row->[$pos{'service.name'}]}{dhcp_option} = fetch_dhcp_options('service', $sid);

  }



}










sub fetch_dns_resources {
  my $type = shift;
  my $id = shift;

  print STDERR "Fetching dns resources for $type/$id\n" if ($DEBUG >= 6);
  my $DNSquery = "dns_resource.owner_type = '$type' AND dns_resource.owner_tid = '$id'";
  my $ldrr = CMU::Netdb::list_dns_resources($dbh, $user, $DNSquery);

  my $block = [];

  if (!ref $ldrr) {
    die "Unable to list DNS resources for $type/$id.\n";
  } elsif ($#$ldrr == 0) {
    print STDERR "[There are no DNS resources for $type/$id]\n" if ($DEBUG >= 7);
    return $block;
  }

  my %pos = %{CMU::Netdb::makemap($ldrr->[0])};
  shift @$ldrr;


  foreach my $row (@$ldrr) {
    my $entry = {};
    push @$block, $entry;
    foreach my $key (sort grep(!/(^machine\.)|\.(id|version|owner_tid|owner_type|rname_tid)/, keys %pos)) {
      $entry->{$key} = $row->[$pos{$key}];
    }
  }

  return $block;
}


sub fetch_dhcp_options {
  my $type = shift;
  my $id = shift;

  print STDERR "Fetching dhcp options for $type/$id\n" if ($DEBUG >= 6);
  my $where =  "dhcp_option.tid = '$id' AND dhcp_option.type = '$type'";
  my $ref = CMU::Netdb::list_dhcp_options($dbh, $user, $where);

  my $block = [];

  if (!ref $ref) {
    die "Unable to list DHCP options for $type/$id.\n";
  } elsif ($#$ref == 0) {
    print STDERR "[There are no DHCP options for $type/$id]\n" if ($DEBUG >= 7);
    return $block;
  }

  my %pos = %{CMU::Netdb::makemap($ref->[0])};
  shift @$ref;


  foreach my $row (@$ref) {
    my $entry = {};
    push @$block, $entry;
    foreach my $key (sort grep(!/(^dhcp_option_type.(?!name))|\.(id|version)/, keys %pos)) {
      $entry->{$key} = $row->[$pos{$key}];
      $entry->{$key} =~ s/^"/""/;
      $entry->{$key} =~ s/"$/""/;
    }
  }

  return $block;
}


sub fetch_attributes {
  my $type = shift;
  my $id = shift;

  print STDERR "Fetching attributes for $type/$id\n" if ($DEBUG >= 6);
  my $where =  "attribute.owner_tid = '$id' AND attribute.owner_table = '$type'";
  my $ref = CMU::Netdb::list_attribute($dbh, $user, $where);

  my $block = [];

  if (!ref $ref) {
    die "Unable to list attributes for $type/$id.\n";
  } elsif ($#$ref == 0) {
    print STDERR "[There are no attributes for $type/$id]\n" if ($DEBUG >= 7);
    return $block;
  }

  my %pos = %{CMU::Netdb::makemap($ref->[0])};
  shift @$ref;


  foreach my $row (@$ref) {
    my $entry = {};
    push @$block, $entry;
    foreach my $key (sort grep(/(attribute_spec\.name)|(attribute\.data)/, keys %pos)) {
      $entry->{$key} = $row->[$pos{$key}];
    }
  }

  return $block;
}




sub fetch_protections {
  my $type = shift;
  my $id = shift;

  print STDERR "Fetching protections for $type/$id\n" if ($DEBUG >= 7);
  my $ref = CMU::Netdb::list_protections($dbh, $user, $type, $id, '');

  my $block = {};

  if (!ref $ref) {
    die "Unable to list protections for $type/$id.\n";
  } elsif (!@$ref) {
    print STDERR "[There are no protections for $type/$id]\n" if ($DEBUG >= 8);
    return $block;
  }

  foreach my $row (@$ref) {
    $block->{$row->[0]}{$row->[1]}{rights} = $row->[2];
    $block->{$row->[0]}{$row->[1]}{rlevel} = $row->[3];

    add_groups_to_output($row->[1]) if ($row->[0] eq 'group');

  }

  return $block;
}



# given an IP address as a long int, returns the 
# dotted-quad equivalent
sub long2dot {
  return join('.', unpack('C4', pack('N', $_[0])));
}

# given an IP address as a dotted-quad, returns the
# long int equivalent
sub dot2long {
  return unpack('N', pack('C4', split(/\./, $_[0])));
}


# given a netmask in the form a.b.c.d (or one integer), calculates
# the CIDR nbits netmask (e.g. /24)
sub mask2CIDR {
  my ($addr) = @_;
 
  $addr = dot2long($addr) if ($addr =~ /\./);
  my $CIDR = 32;
  while($addr % 2 != 1 && $CIDR > 1) {
    $addr = $addr >> 1;
    $CIDR--;
  }
  return $CIDR;
}

sub CIDR2mask {
  my ($cidr) = @_;

  return long2dot( ((2**$cidr)-1) << (32-$cidr));
} 



