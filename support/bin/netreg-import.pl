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
use CMU::Helper;
use Config::General;
use Getopt::Long;

use strict;

use Data::Dumper;

my $dbuser = 'netreg';
my $debug = 5;
my $configfile;
my $datafile;

# Flush output to make stdout/stderr not overlap
$| = 1;

my $result = GetOptions ("config=s" => \$configfile,
			 "data=s" => \$datafile,
			 "debug=i" => \$debug);

if (!$result || !$configfile || !$datafile) {
  usage();
  exit 0;
}



my $conf = new Config::General(-ConfigFile => $configfile);

my $inconf = new Config::General(
				 -ConfigFile => $datafile,
				 -BackslashEscape => 1,
				);
my %config = $conf->getall;
my %input = $inconf->getall;
my %imported;
$imported{group}{'system:anyuser'}{id} = 0;
$imported{group}{'system:anyuser'}{newname} = 'system:anyuser';

#print Data::Dumper->Dump([\%config], ['config']);
#exit;


my $dbh = CMU::Netdb::lw_db_connect();




# Data reconciliation notes:
# groups:  (must be done first, in two passes so groups exist before setting perms)
#   name -> prefix in config
# zones:
#   sort by length, so foo.edu is created before bar.foo.edu
#   conflicts, different types -> toplevel overrides permissable
#   conflicts, same type -> configurable behavior from config, no default
#   keys -> generate new ddns keys
# vlans:
#   conflicts -> configurable behavior in config
#   name -> prefix in config
# global/subnet dhcp options;
#   compare to local globals, override per subnet on create as needed
# subnets:
#   conflicts -> configurable behavior by IP range in config?  may need to split up existing subnets
#   name -> prefix in config
# machines:
#   conflicts -> configurable behavior from config.  regexp of allowed overrides?
# service groups

foreach (@{$input{global_settings}{dhcp_option}}) {
  compare_dhcp_option($_);
}

foreach (keys %{$input{group}}) {
  import_group($_);
}

foreach (keys %{$input{group}}) {
  import_group_protections($_);
}

foreach (sort { length($a) <=> length($b) } keys %{$input{dns_zone}}) {
  import_dns_zone($_);
}

foreach (keys %{$input{vlan}}) {
  import_vlan($_);
}

foreach (keys %{$input{subnet}}) {
  import_subnet($_);
}

foreach (keys %{$input{machine}}) {
  import_machine($_);
}

foreach (keys %{$input{dns_zone}}) {
  import_dns_zone_resources($_);
}

foreach (keys %{$input{service}}) {
  import_service($_);
}

foreach (keys %{$input{service}}) {
  import_service_members($_);
}

fix_default_dhcp_service_pool();

# todo
#
# not handling subnet shares at present
#



sub compare_dhcp_option {
  my $option = shift;
  my $type = $option->{'dhcp_option_type.name'};
  my $context = $option->{'dhcp_option.type'};
  my $short_type;
  ($short_type = $type) =~ s/^option //;

  # If this is a global option and we've already loaded a subnet option, skip it.
  return if ($context eq 'global'
	     && exists $imported{dhcp_option}{$type});

  return unless ($config{global_settings}{dhcp_option}{$short_type} eq 'import');

  my $ref = CMU::Netdb::list_dhcp_options($dbh, $dbuser, "dhcp_option_type.name = '$type' AND dhcp_option.type = '$context' AND dhcp_option.tid = 0");

#  print Data::Dumper->Dump([$ref], ['ref']);

  if (!ref $ref) {
    die "Unable to list DHCP options for $type/$context.\n";
  } elsif ($#$ref == 0) {
    print "[There is no existing DHCP option for '$type'/'$context']\n" if ($debug >= 4);
    $imported{dhcp_option}{$type} = $option;
  } else {
    my $map = CMU::Netdb::makemap($ref->[0]);
    if ($ref->[1][$map->{'dhcp_option.value'}] eq $option->{'dhcp_option.value'}) {
      print "Identical option found for $type/$context. Ignoring\n"
    } elsif ($ref->[1][$map->{'dhcp_option.value'}] eq '"'.$option->{'dhcp_option.value'}.'"'){
      print "Identical (quoted) option found for $type/$context. Ignoring\n"
    } else {
      $imported{dhcp_option}{$type} = $option;
    }
  }

}

sub import_dns_zone_resources {
  my $zone = shift;
  my $zid = $imported{dns_zone}{$zone}{id};

  if ($zid && exists $input{dns_zone}{$zone}{dns_resource}) {
    set_dns_resources('dns_zone', $zid,  $input{dns_zone}{$zone}{dns_resource});
  }

}


sub import_dns_zone {
  my $zone = shift;
  my (%fields, $res, $ref, $zid);

  if (exists $config{dns_zone}{$zone} 
      && exists $config{dns_zone}{$zone}{action}
      && $config{dns_zone}{$zone}{action} eq 'ignore') {
    print "IGNORING dns_zone $zone\n" if ($debug >= 5);
    return;
  }

  if (exists $config{dns_zone}{DEFAULT} && exists $config{dns_zone}{DEFAULT}{accept_pattern}) {
    my $accept = $config{dns_zone}{DEFAULT}{accept_pattern};
    print "Comparing $zone to accept pattern: $accept\n" if ($debug >= 6);
    if ($zone =~ m/$accept/i) {
      print "   $zone matched accept pattern\n" if ($debug >= 6);
    } else {
      print "IGNORING dns_zone $zone\n" if ($debug >= 5);
      return;
    }
  }

  if (exists $config{dns_zone}{DEFAULT} && exists $config{dns_zone}{DEFAULT}{reject_pattern}) {
    my $reject = $config{dns_zone}{DEFAULT}{reject_pattern};
    print "Comparing $zone to reject pattern: $reject\n" if ($debug >= 6);
    if ($zone =~ m/$reject/i) {
      print "REJECTING dns_zone $zone\n";
      return;
    } else {
      print "   $zone allowed by reject pattern\n" if ($debug >= 6);
    }
  }

  print "Importing dns_zone $zone\n";

  foreach my $param (grep(/^dns_zone\./, keys %{$input{dns_zone}{$zone}})) {
    my $short = $param;
    $short =~ s/^dns_zone\.//;
    $fields{$short} = $input{dns_zone}{$zone}{$param}
  }

  # Does dns_zone already exist?
  my $zlist = CMU::Netdb::list_dns_zones($dbh, $dbuser, "dns_zone.name = '$zone'");
  if (!ref $zlist) {
    die "Error calling list_dns_zones; Name: $zone ($zlist)";
  }

  if (!defined $zlist->[1]) {
    # If dns_zone doesn't exist, create


    ($res, $ref) = CMU::Netdb::add_dns_zone($dbh, $dbuser, \%fields);
    if ($res < 1) {
      die "Error adding dns_zone $zone: ".
			       "$res [".join(',', @$ref)."]";
    }
    $zid = $ref->{insertID};
    print "Added dns_zone $zone, id $zid.\n";
    $imported{dns_zone}{$zone}{id} = $zid;

  } else {
    # Dns_zone existed, options are override, lookup (for service group membership later), or keep-existing
    print "dns_zone $zone already exists!\n";


    if (exists $config{dns_zone}{$zone} 
	&& exists $config{dns_zone}{$zone}{action}) {
      if ($config{dns_zone}{$zone}{action} eq 'override') {
	# Override the existing zone
	print "OVERWRITING EXISTING dns_zone $zone\n";
	my $zmap = CMU::Netdb::makemap($zlist->[0]);
	$zid = $zlist->[1][$zmap->{'dns_zone.id'}];
	my $zver = $zlist->[1][$zmap->{'dns_zone.version'}];

	($res, $ref) = CMU::Netdb::modify_dns_zone($dbh, $dbuser, $zid, $zver, \%fields);
	if ($res < 1) {
	  die "Error modifying dns_zone $zone($zid): ".
	    "$res [".join(',', @$ref)."]";
	}

	$imported{dns_zone}{$zone}{id} = $zid;
      } elsif ($config{dns_zone}{$zone}{action} eq 'lookup') {
	# Save the zone ID for reference in service group memberships
	my $zmap = CMU::Netdb::makemap($zlist->[0]);
	$zid = $zlist->[1][$zmap->{'dns_zone.id'}];
	$imported{dns_zone}{$zone}{id} = $zid;
	print "KEEPING EXISTING dns_zone $zone (imported id of $zid)\n";
	return;

      } else {
	print "KEEPING EXISTING dns_zone $zone\n";
	return;
      }
    } else {
      print "KEEPING EXISTING dns_zone $zone\n";
      return;
    }


  }


  if (exists $input{dns_zone}{$zone}{attribute}) {
    set_attributes('dns_zone', $zid, $input{dns_zone}{$zone}{attribute});
  }

  if (exists $input{dns_zone}{$zone}{protection}) {
    #flush_protections('dns_zone', $zid);
    set_protections('dns_zone', $zid,  $input{dns_zone}{$zone}{protection});
  }



}


sub import_vlan {
  my $vlan = shift;
  my (%fields, $res, $ref, $vid, $prefix, $newvlan, $abbr_prefix);

  if (exists $config{vlan}{$vlan} 
      && exists $config{vlan}{$vlan}{action}
      && $config{vlan}{$vlan}{action} eq 'ignore') {
    print "IGNORING vlan $vlan\n" if ($debug >= 6);
    return;
  }

  $prefix = $config{vlan}{DEFAULT}{prefix} || "";
  $newvlan = $prefix . $input{vlan}{$vlan}{'vlan.name'};
  $abbr_prefix = $config{subnet}{DEFAULT}{abbr_prefix} || "";

  print "Importing vlan $vlan\n";


  # Does vlan already exist?
  my $zlist = CMU::Netdb::list_vlans($dbh, $dbuser, "vlan.name = '$newvlan'");
  if (!ref $zlist) {
    die "Error calling list_vlans; Name: $newvlan ($zlist)";
  }

  if (!defined $zlist->[1]) {
    # If vlan doesn't exist, create

    foreach my $param (grep(/^vlan\./, keys %{$input{vlan}{$vlan}})) {
      my $short = $param;
      $short =~ s/^vlan\.//;
      $fields{$short} = $input{vlan}{$vlan}{$param}
    }

    $fields{name} = $newvlan;
    $fields{abbreviation} = $abbr_prefix . $fields{abbreviation};
    $fields{abbreviation} = substr $fields{abbreviation}, 0, 16;

    ($res, $ref) = CMU::Netdb::add_vlan($dbh, $dbuser, \%fields);
    if ($res < 1) {
      die "Error adding vlan $newvlan: ".
			       "$res [".join(',', @$ref)."]";
    }
    $vid = $ref->{insertID};
    print "Added vlan $newvlan, id $vid.\n";
    $imported{vlan}{$vlan}{id} = $vid;
    $imported{vlan}{$vlan}{newname} = $newvlan

  } else {
    # FIXME
    # Vlan existed, options are abort/override/keep-existing
    # No such examples exist in CMU-Q -> CMU-P transition, can be ignored for now.
    print "vlan $newvlan already exists!\n";
    return;
  }


  if (exists $input{vlan}{$vlan}{attribute}) {
    set_attributes('vlan', $vid, $input{vlan}{$vlan}{attribute});
  }

  if (exists $input{vlan}{$vlan}{protection}) {
    #flush_protections('vlan', $vid);
    set_protections('vlan', $vid,  $input{vlan}{$vlan}{protection});
  }


}






sub import_group {
  my $group = shift;
  my $newgroup = $group;
  my (%fields, $res, $ref, $gid);

  if (exists $config{group}{$group} 
      && exists $config{group}{$group}{action}
      && $config{group}{$group}{action} eq 'ignore') {
    print "Ignoring group $group\n";
    return;
  }
  if (exists $config{group}{$group} && exists $config{group}{$group}{translate}) {
    my $pattern = $config{group}{$group}{translate}{pattern};
    my $replacement = $config{group}{$group}{translate}{replacement};
    $newgroup =~ s/$pattern/$replacement/;
  } elsif (exists $config{group}{DEFAULT} && exists $config{group}{DEFAULT}{translate}) {
    my $pattern = $config{group}{DEFAULT}{translate}{pattern};
    my $replacement = $config{group}{DEFAULT}{translate}{replacement};
    $newgroup =~ s/$pattern/$replacement/;
  }

  print "Importing group $group as $newgroup\n";


  foreach my $param (grep(/^groups\./, keys %{$input{group}{$group}})) {
    my $short = $param;
    $short =~ s/^groups\.//;
    $fields{$short} = $input{group}{$group}{$param}
  }

  $fields{name} = $newgroup;
  $imported{group}{$group}{newname} = $newgroup;

  # Does group already exist?
  my $lgr = CMU::Netdb::list_groups($dbh, $dbuser, "groups.name = '$newgroup'");
  if (!ref $lgr) {
    die "Error calling list_groups; Name: $newgroup ($lgr)";
  }

  if (!defined $lgr->[1]) {
    # If group doesn't exist, create
    ($res, $ref) = CMU::Netdb::add_group($dbh, $dbuser, \%fields);
    if ($res < 1) {
      die "Error adding group $newgroup: ".
			       "$res [".join(',', @$ref)."]";
    }
    $gid = $ref->{insertID};
    print "Added group $newgroup, id $gid.\n";
    $imported{group}{$group}{id} = $gid;

    # FIXME - might not be an array?!
    foreach my $user (@{$input{group}{$group}{member}}) {

      print "Adding $user to $newgroup($gid)\n";
      ($res, $ref) = 
	CMU::Netdb::add_user_to_group($dbh, $dbuser, $user, $gid);
      if ($res < 1) {
        print "Error adding $user to $newgroup($gid). Error codes: $res; ($CMU::Netdb::errors::errmeanings{$res}) ".
	  " field: [".join(',', @$ref)."]\n";
      }
    }
  } else {
    # FIXME
    # Group existed, options are override/keep-existing
    print "Group $newgroup already exists!\n";
    return;
  }


  if (exists $input{group}{$group}{attribute}) {
    set_attributes('groups', $gid, $input{group}{$group}{attribute});
  }

}


sub import_group_protections {
  my $group = shift;
  my $newgroup = $group;
  my (%fields, $res, $ref, $gid);

  if (exists $config{group}{$group} 
      && exists $config{group}{$group}{action}
      && $config{group}{$group}{action} eq 'ignore') {
    print "Ignoring group $group\n";
    return;
  }
  if (exists $config{group}{$group} && exists $config{group}{$group}{translate}) {
    my $pattern = $config{group}{$group}{translate}{pattern};
    my $replacement = $config{group}{$group}{translate}{replacement};
    $newgroup =~ s/$pattern/$replacement/;
  } elsif (exists $config{group}{DEFAULT} && exists $config{group}{DEFAULT}{translate}) {
    my $pattern = $config{group}{DEFAULT}{translate}{pattern};
    my $replacement = $config{group}{DEFAULT}{translate}{replacement};
    $newgroup =~ s/$pattern/$replacement/;
  }

  print "Importing group protections of $group as $newgroup\n";

  if ( ! $imported{group}{$group}{id}) { 
    print "Missing group id for $newgroup, skipping protections\n";
    return;
  }


  set_protections('groups', $imported{group}{$group}{id},  $input{group}{$group}{protection});

}


sub import_subnet {
  my $subnet = shift;
  my ($sid, $res, $ref, $prefix, $abbr_prefix, $base, $mask, $bcast, $newsubnet);
  if (exists $config{subnet}{$subnet} 
      && exists $config{subnet}{$subnet}{action}
      && $config{subnet}{$subnet}{action} eq 'ignore') {
    print "Ignoring subnet $subnet\n";
    return;
  }


  $base = $input{subnet}{$subnet}{'subnet.base_address'};
  $mask = $input{subnet}{$subnet}{'subnet.network_mask'};
  $bcast = ((0+$base) | ~(0+$mask)) & 0xffffffff ;
  $prefix = $config{subnet}{DEFAULT}{prefix} || "";
  $abbr_prefix = $config{subnet}{DEFAULT}{abbr_prefix} || "";
  $newsubnet = $prefix . $input{subnet}{$subnet}{'subnet.name'};
  print "Importing subnet $subnet as $newsubnet\n";
  print "Base: $base - ".CMU::Helper::long2dot($base)."\n" if ($debug >= 7);
  print "Mask: $mask - ".CMU::Helper::long2dot($mask)."\n" if ($debug >= 7);
  print "Broadcast: $bcast - ".CMU::Helper::long2dot($bcast)."\n" if ($debug >= 7);

  my %fields;
  foreach my $param (grep(/^subnet\./, keys %{$input{subnet}{$subnet}})) {
    my $short = $param;
    $short =~ s/^subnet\.//;
    $fields{$short} = $input{subnet}{$subnet}{$param}
  }

  $fields{name} = $newsubnet;
  $fields{abbreviation} = $abbr_prefix . $fields{abbreviation};
  $fields{abbreviation} = substr $fields{abbreviation}, 0, 16;


  my $query = "subnet.base_address < $bcast AND ".
    "((subnet.base_address | ~subnet.network_mask) & 0xffffffff) > $base";

  my $overlap = CMU::Netdb::list_subnets($dbh, $dbuser, $query);

  die "Error in list_subnets ($overlap)" if (!ref $overlap);

  if (scalar @$overlap > 1) {
    print " - Overlapping subnets found for $subnet\n";
    my $map = CMU::Netdb::makemap($overlap->[0]);
    shift @$overlap;

    if (scalar @$overlap == 1
	&& $overlap->[0][$map->{'subnet.base_address'}] == $base
	&& $overlap->[0][$map->{'subnet.network_mask'}] == $mask) {
      # Only one overlapping subnet, and its the identical range.  Overwrite?
      print "   - IDENTICAL RANGE -  ".$overlap->[0][$map->{'subnet.name'}]."\n";

      if ($config{subnet}{$subnet}{overlap_action} eq 'overwrite'
	  || $config{subnet}{DEFAULT}{overlap_action} eq 'overwrite') {
	# We're going to update the existing subnet to match our input
	$sid = $overlap->[0][$map->{'subnet.id'}];
	my $sver = $overlap->[0][$map->{'subnet.version'}];

	($res, $ref) = CMU::Netdb::modify_subnet($dbh, $dbuser, $sid, $sver, \%fields);
	if ($res < 1) {
	  die "Error modifying existing subnet $sid: ".
	    "$res [".join(',', @$ref)."]";
	}

	$imported{subnet}{$subnet}{id} = $sid;
	$imported{subnet}{$subnet}{newname} = $newsubnet;

      } else {
	warn "   - Skipping $subnet because of pre-existing matching subnet\n";
	return;
      }
    } else {
      # Multiple matching subnets for this range.  Manual reconciliation required
      foreach (@$overlap) {
	print " - ".$_->[$map->{'subnet.name'}]." / " .CMU::Netdb::long2dot($_->[$map->{'subnet.base_address'}])." / " .CMU::Netdb::long2dot($_->[$map->{'subnet.network_mask'}])."\n";
      }
      warn "   - Skipping $subnet because of pre-existing non-identical matching subnet\n";
      return;
    }
  } else {
    # No overlapping subnets, add new subnet

    ($res, $ref) = CMU::Netdb::add_subnet($dbh, $dbuser, \%fields);
    if ($res < 1) {
      die "Error adding subnet $newsubnet: ".
			       "$res [".join(',', @$ref)."]";
    }
    $sid = $ref->{insertID};
    print "ADDED SUBNET $newsubnet, id $sid.\n";
    $imported{subnet}{$subnet}{id} = $sid;
    $imported{subnet}{$subnet}{newname} = $newsubnet;
  }


  # If we reached here, we either added a subnet or modified the existing subnet, and the subnet id
  # is stored in $sid.

  # Flush all protections and add from imput
  flush_protections('subnet', $sid);
  set_protections('subnet', $sid,  $input{subnet}{$subnet}{protection}) if ($input{subnet}{$subnet}{protection});

  # Flush all dhcp options and add from input
  #  - use global/subnet options from input as necessary
  flush_dhcp_options('subnet', $sid);
  set_dhcp_options('subnet', $sid, $input{subnet}{$subnet}{dhcp_option}) if ($input{subnet}{$subnet}{dhcp_option});
  set_dhcp_options('subnet', $sid, $imported{dhcp_option}) if ($imported{dhcp_option});



  # Flush all registration modes and add modes & protections from input
  my $modes = CMU::Netdb::list_subnet_registration_modes($dbh, $dbuser, "subnet_registration_modes.subnet='$sid'");
  die "Error fetching subnet registration modes" if (!ref $modes);

  my %mpos = %{CMU::Netdb::makemap($modes->[0])};
  shift @$modes;

  foreach my $mrow (@$modes) {
    ($res, $ref) = CMU::Netdb::delete_subnet_registration_mode($dbh, $dbuser,
						   $mrow->[$mpos{'subnet_registration_modes.id'}],
						   $mrow->[$mpos{'subnet_registration_modes.version'}]);
    die "Error deleting subnet registration modes ($res):". join(', ', @$ref) if ($res <= 0);
  }

  # Make sure the input is an array
  $input{subnet}{$subnet}{subnet_registration_mode} 
    = [$input{subnet}{$subnet}{subnet_registration_mode}] 
      if (ref $input{subnet}{$subnet}{subnet_registration_mode} ne 'ARRAY');
  foreach my $mode (@{$input{subnet}{$subnet}{subnet_registration_mode}}) {
    my %fields;
    $fields{subnet} = $sid;
    $fields{mode} = $mode->{'subnet_registration_modes.mode'};
    $fields{quota} = $mode->{'subnet_registration_modes.quota'};
    $fields{mac_address} = $mode->{'subnet_registration_modes.mac_address'};
    ($res, $ref) = CMU::Netdb::add_subnet_registration_mode($dbh, $dbuser, \%fields);
    die "Error adding subnet registration modes ($res):". join(', ', @$ref) if ($res <= 0);

    set_protections('subnet_registration_modes', $ref->{insertID},
		    $mode->{protection}) if ($mode->{protection});

  }


  # Flush all dns zones and add from input
  my $zones = CMU::Netdb::list_subnet_domains($dbh, $dbuser, "subnet_domain.subnet='$sid'");
  die "Error fetching subnet domains" if (!ref $modes);

  my %zpos = %{CMU::Netdb::makemap($zones->[0])};
  shift @$zones;

  foreach my $zrow (@$zones) {
    ($res, $ref) = CMU::Netdb::delete_subnet_domain($dbh, $dbuser,
						    $zrow->[$zpos{'subnet_domain.id'}],
						    $zrow->[$zpos{'subnet_domain.version'}]);
    die "Error deleting subnet domains ($res):". join(', ', @$ref) if ($res <= 0);
  }


  # Make sure the input is an array
  #print Data::Dumper->Dump([$input{subnet}{$subnet}{dns_zone}], ['dns_zone']);
  if ($input{subnet}{$subnet}{dns_zone} && ref $input{subnet}{$subnet}{dns_zone} ne 'ARRAY') {
    $input{subnet}{$subnet}{dns_zone} = [$input{subnet}{$subnet}{dns_zone}];
  }
  #print Data::Dumper->Dump([$input{subnet}{$subnet}{dns_zone}], ['dns_zone']);
  foreach my $zone (@{$input{subnet}{$subnet}{dns_zone}}) {
    my %fields;
    $fields{subnet} = $sid;
    $fields{domain} = $zone;
    ($res, $ref) = CMU::Netdb::add_subnet_domain($dbh, $dbuser, \%fields);
    warn "Error adding subnet domain $sid/$zone ($res):". join(', ', @$ref) if ($res <= 0);
  }

  # Flush all vlans and add from input

  my $vlans = CMU::Netdb::list_subnet_presences($dbh, $dbuser, "subnet.id='sid'");
  die "Error fetching subnet vlans" if (!ref $modes);

  my %vpos = %{CMU::Netdb::makemap($vlans->[0])};
  shift @$vlans;

  foreach my $vrow (@$vlans) {
    ($res, $ref) = CMU::Netdb::delete_subnet_presence($dbh, $dbuser,
						      $vrow->[$vpos{'vlan_subnet_presence.id'}],
						      $vrow->[$vpos{'vlan_subnet_presence.version'}]);
    die "Error deleting subnet vlan presence ($res):". join(', ', @$ref) if ($res <= 0);
  }


  # Make sure the input is an array
  #print Data::Dumper->Dump([$input{subnet}{$subnet}{vlan}], ['vlan']);
  if ($input{subnet}{$subnet}{vlan} && ref $input{subnet}{$subnet}{vlan} ne 'ARRAY') {
    $input{subnet}{$subnet}{vlan} = [$input{subnet}{$subnet}{vlan}];
  }
  #print Data::Dumper->Dump([$input{subnet}{$subnet}{vlan}], ['vlan']);
  foreach my $vlan (@{$input{subnet}{$subnet}{vlan}}) {
    my %fields;


    $fields{subnet} = $sid;
    $fields{vlan} = $imported{vlan}{$vlan}{id} || warn "----- Did not import vlan $vlan for subnet $subnet.  Skipping!";
    ($res, $ref) = CMU::Netdb::add_subnet_presence($dbh, $dbuser, \%fields);
    warn "Error adding subnet domain $sid/$vlan($fields{vlan}) ($res):". join(', ', @$ref) if ($res <= 0);
  }
  


}



sub import_machine {
  my $machine = shift;

  my (%fields, $res, $ref, $mid, %perms);

  if (exists $config{machine}{$machine} 
      && exists $config{machine}{$machine}{action}
      && $config{machine}{$machine}{action} eq 'ignore') {
    print "Ignoring machine $machine\n";
    return;
  }

  print "Importing machine $machine\n";


  foreach my $param (grep(/^machine\./, keys %{$input{machine}{$machine}})) {
    my $short = $param;
    $short =~ s/^machine\.//;
    $fields{$short} = $input{machine}{$machine}{$param}
  }

  print Data::Dumper->Dump([\%fields, \%perms], ['fields', 'perms']);
  if ($fields{ip_address}) {
    $fields{ip_address_subnet} = find_subnet($fields{ip_address});
    $fields{ip_address_zone} = find_zone($fields{ip_address}) if ($fields{ip_address});
    $fields{ip_address} = CMU::Helper::long2dot($fields{ip_address}) if ($fields{ip_address});
  } else {
    $fields{ip_address} = undef;
    my $tmp = $imported{subnet}{$fields{ip_address_subnet}}{id};
    print "Setting ip_address_subnet to $tmp\n";
    $fields{ip_address_subnet} = $tmp;
  }

  if (exists $input{machine}{$machine}{protection}{group}) {
    foreach my $group (keys %{$input{machine}{$machine}{protection}{group}}) {
      if ($imported{group}{$group}{newname} =~ /^dept\:/) {
	$fields{dept} = $imported{group}{$group}{newname};
      } else {
	$perms{$imported{group}{$group}{newname}}[0] = $input{machine}{$machine}{protection}{group}{$group}{rights};
	$perms{$imported{group}{$group}{newname}}[1] = $input{machine}{$machine}{protection}{group}{$group}{rlevel};
      }
    }
  }

  if (exists $input{machine}{$machine}{protection}{user}) {
    foreach my $user (keys %{$input{machine}{$machine}{protection}{user}}) {
      $perms{$user}[0] = $input{machine}{$machine}{protection}{user}{$user}{rights};
      $perms{$user}[1] = $input{machine}{$machine}{protection}{user}{$user}{rlevel};
    }
  }

  # Does machine already exist?
  my $mref = CMU::Netdb::list_machines($dbh, $dbuser, "machine.host_name = '$machine'");
  if (!ref $mref) {
    die "Error calling list_machines; Name: $machine ($mref)";
  }

  if (!defined $mref->[1]) {
    # If machine doesn't exist, create
    #print Data::Dumper->Dump([\%fields, \%perms], ['fields', 'perms']);
    ($res, $ref) = CMU::Netdb::add_machine($dbh, $dbuser, 9, \%fields, \%perms);
    if ($res < 1) {
      die "Error adding machine $machine: ".
			       "$res [".join(',', @$ref)."]";
    }
    $mid = $ref->{insertID};
    print "Added machine $machine, id $mid.\n";
    $imported{machine}{$machine}{id} = $mid;

  } else {
    # Machine existed, options are override, lookup (for service group membership later), or keep-existing
    print "Machine $machine already exists!\n";

    if (exists $config{machine}{$machine} 
	&& exists $config{machine}{$machine}{action}) {
      if ($config{machine}{$machine}{action} eq 'override') {
	# Override the existing machine
	print "OVERWRITING EXISTING machine $machine\n";
	my $map = CMU::Netdb::makemap($mref->[0]);
	$mid = $mref->[1][$map->{'machine.id'}];
	my $mver = $mref->[1][$map->{'machine.version'}];
	print Data::Dumper->Dump([$mid, $mver, \%fields, \%perms], ['mid', 'mver', 'fields', 'perms']) if ($debug >= 5);
	($res, $ref) = CMU::Netdb::modify_machine($dbh, $dbuser, $mid, $mver, 9, \%fields);
	if ($res < 1) {
	  die "Error modifying machine $machine($mid): ".
	    "$res [".join(',', @$ref)."]";
	}

	#print Data::Dumper->Dump([$res, $ref], ['res', 'ref']);
	$imported{machine}{$machine}{id} = $mid;
      } elsif ($config{machine}{$machine}{action} eq 'lookup') {
	my $map = CMU::Netdb::makemap($mref->[0]);
	$mid = $mref->[1][$map->{'machine.id'}];
	$imported{machine}{$machine}{id} = $mid;
	print "KEEPING EXISTING machine $machine (imported id of $mid)\n";
	return;
      } else {
	print "KEEPING EXISTING machine $machine\n";
	return;
      }

    } else {
      print "KEEPING EXISTING machine $machine\n";
      return;
    }

  }


  if (exists $input{machine}{$machine}{attribute}) {
    set_attributes('machine', $mid, $input{machine}{$machine}{attribute});
  }

#  if (exists $input{machine}{$machine}{protection}) {
#    set_protections('machine', $mid,  $input{machine}{$machine}{protection});
#  }

  if (exists $input{machine}{$machine}{dns_resource}) {
    set_dns_resources('machine', $mid,  $input{machine}{$machine}{dns_resource});
  }

  # FIXME
  # ignoring per machine dhcp options for now.  none set in cmu-q netreg data

}




sub import_service {
  my $service = shift;
  my $newservice = $service;
  my (%fields, $res, $ref, $sid, $prefix);

  if (exists $config{service}{$service} 
      && exists $config{service}{$service}{action}
      && $config{service}{$service}{action} eq 'ignore') {
    print "Ignoring service $service\n";
    return;
  }

  $prefix = $config{service}{DEFAULT}{prefix} || "";
  $newservice = $prefix . $input{service}{$service}{'service.name'};

  print "Importing service $service as $newservice\n";


  foreach my $param (grep(/^service\./, keys %{$input{service}{$service}})) {
    my $short = $param;
    $short =~ s/^service\.//;
    $fields{$short} = $input{service}{$service}{$param}
  }

  $fields{name} = $newservice;
  $imported{service}{$service}{newname} = $newservice;

  my $typeid;
  my $tref = CMU::Netdb::list_service_types_ref($dbh, $dbuser, 
						"service_type.name = "
						. $dbh->quote($input{service}{$service}{type}),
						'service_type.name');
  die "Error trying to find service type ".$input{service}{$service}{type}
    if (!ref $tref);
  $typeid = (keys %$tref)[0];
  die "Unable to find service type ".$input{service}{$service}{type} if (!$typeid);
  $fields{type} = $typeid;

  # Does service already exist?
  my $lsr = CMU::Netdb::list_services($dbh, $dbuser, "service.name = '$newservice'");
  if (!ref $lsr) {
    die "Error calling list_service; Name: $newservice ($lsr)";
  }

  if (!defined $lsr->[1]) {
    # If service doesn't exist, create
    print Data::Dumper->Dump([\%fields], ['fields']) if ($debug >= 5);
    ($res, $ref) = CMU::Netdb::add_service($dbh, $dbuser, \%fields);
    if ($res < 1) {
      die "Error adding service $newservice: ".
			       "$res [".join(',', @$ref)."]";
    }
    $sid = $ref->{insertID};
    print "Added service $newservice, id $sid.\n";
    $imported{service}{$service}{id} = $sid;
    $imported{service}{$service}{typeid} = $typeid;
    $imported{service}{$service}{type} = $input{service}{$service}{type};



#       print "Adding $user to $newservice($sid)\n";
#       ($res, $ref) = 
# 	CMU::Netdb::add_user_to_service($dbh, $dbuser, $user, $sid);
#       if ($res < 1) {
#         print "Error adding $user to $newservice($sid). Error codes: $res; ($CMU::Netdb::errors::errmeanings{$res}) ".
# 	  " field: [".join(',', @$ref)."]\n";
#       }
#     }
  } else {
    # FIXME
    # Service existed, options are abort/override/keep-existing
    print "Service $newservice already exists!\n";
    return;
  }


  if (exists $input{service}{$service}{attribute}) {
    set_attributes('service', $sid, $input{service}{$service}{attribute}, $typeid);
  }

  if (exists $input{service}{$service}{protection}) {
    set_protections('service', $sid, $input{service}{$service}{protection});
  }

  if (exists $input{service}{$service}{dns_resource}) {
    set_dns_resources('service', $sid, $input{service}{$service}{dns_resource}, $newservice);
  }

  if (exists $input{service}{$service}{dhcp_option}) {
    set_dhcp_options('service', $sid, $input{service}{$service}{dhcp_option});
  }


}


sub import_service_members {
  my $service = shift;
  my $newservice = $service;
  my (%fields, $res, $ref, $sid, $prefix);

  if (exists $config{service}{$service} 
      && exists $config{service}{$service}{action}
      && $config{service}{$service}{action} eq 'ignore') {
    print "Ignoring service $service\n";
    return;
  }

  $prefix = $config{service}{DEFAULT}{prefix} || "";
  $newservice = $prefix . $input{service}{$service}{'service.name'};

  print "Importing service members for $newservice\n";

  $sid = $imported{service}{$service}{id};

  die "No service id for $newservice, cannot import members!" if (!$sid);

  foreach my $type (keys %{$input{service}{$service}{member}}) {
    foreach my $member (keys %{$input{service}{$service}{member}{$type}}) {
      die "Unable to find id for $type/$member, cannot import membership." if (!$imported{$type}{$member}{id});

      my %fields;
      $fields{service} = $sid;
      $fields{member_type} = $type;
      $fields{member_tid} = $imported{$type}{$member}{id};

      ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $dbuser, \%fields);

      if ($res < 1) {
        die "Error adding member $type/$member to $newservice($sid). Error codes: $res; ($CMU::Netdb::errors::errmeanings{$res}) ".
	  " field: [".join(',', @$ref)."]\n";
      }

      my $mid = $ref->{insertID};

      if (exists $input{service}{$service}{member}{$type}{$member}{attribute}) {
	set_attributes('service_membership', $mid, $input{service}{$service}{member}{$type}{$member}{attribute}, $imported{service}{$service}{typeid});
      }

      if ($imported{service}{$service}{type} eq 'DHCP Server Pool') {
	if ($type eq 'subnet') {
	  $imported{$type}{$member}{'DHCP Server Pool'} = $sid;
	}
      }

    }
  }

}



sub fix_default_dhcp_service_pool {
  my ($res, $ref);
  return if ( ! $imported{default_dhcp_service_pool});

  foreach my $subnet (keys %{$imported{subnet}}) {
    my %fields;
    next if ($imported{subnet}{$subnet}{'DHCP Server Pool'});
    next if (! $imported{subnet}{$subnet}{id});

    $fields{service} = $imported{default_dhcp_service_pool};
    $fields{member_type} = 'subnet';
    $fields{member_tid} = $imported{subnet}{$subnet}{id};

    print "fix_d_d_s_p: ".Data::Dumper->Dump([\%fields], ['fields']) if ($debug >= 5);

    ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $dbuser, \%fields);

    if ($res < 1) {
      die "Error adding member subnet/$fields{member_tid} to \"Default\" dhcp server pool ($fields{service}). Error codes: $res; ($CMU::Netdb::errors::errmeanings{$res}) ".
	" field: [".join(',', @$ref)."]\n";
    }

  }

}




sub flush_protections {
  my $type = shift;
  my $id = shift;

  print STDERR "Flushing protections for $type/$id\n" if ($debug >= 7);
  my $ref = CMU::Netdb::list_protections($dbh, $dbuser, $type, $id, '');

  if (!ref $ref) {
    die "Unable to list protections for $type/$id.\n";
  } elsif (!@$ref) {
    print STDERR "[There are no protections for $type/$id]\n" if ($debug >= 8);
  }

  foreach my $row (@$ref) {
    my ($res, $ref);
    if ($row->[0] eq 'user') { 
      ($res, $ref) = CMU::Netdb::delete_user_from_protections($dbh, $dbuser, $row->[1], $type, $id, $row->[3], '');
    } else {
      ($res, $ref) = CMU::Netdb::delete_group_from_protections($dbh, $dbuser, $row->[1], $type, $id, $row->[3], '');
    }
    die "Failure while deleting user $row->[1] from $type/$id: $res . (".join(', ', @$ref).")\n" if ($res <= 0);
  }

}


sub set_protections {
  my ($table, $row, $prots) = @_;

  #print STDERR "Setting protections for $table/$row:\n" . Data::Dumper->Dump([$prots], ['prots']);
  if (exists $prots->{group}) {
    foreach my $group (keys %{$prots->{group}}) {
      print "Adding $imported{group}{$group}{newname} / $prots->{group}{$group}{rights} / $prots->{group}{$group}{rlevel} to $table/$row\n" if ($debug >= 6);
      CMU::Netdb::add_group_to_protections($dbh, $dbuser, $imported{group}{$group}{newname}, $table, $row, 
					   $prots->{group}{$group}{rights}, $prots->{group}{$group}{rlevel});
    }
  }

  if (exists $prots->{user}) {
    foreach my $user (keys %{$prots->{user}}) {
      print "Adding $user / $prots->{user}{$user}{rights} / $prots->{user}{$user}{rlevel} to $table/$row\n" if ($debug >= 6);
      CMU::Netdb::add_user_to_protections($dbh, $dbuser, $user, $table, $row, 
					  $prots->{user}{$user}{rights}, $prots->{user}{$user}{rlevel});
    }
  }
}

sub flush_dhcp_options {
  my $type = shift;
  my $id = shift;

  print STDERR "Flushing dhcp options for $type/$id\n" if ($debug >= 6);
  my $where =  "dhcp_option.tid = '$id' AND dhcp_option.type = '$type'";
  my $ref = CMU::Netdb::list_dhcp_options($dbh, $dbuser, $where);

  if (!ref $ref) {
    die "Unable to list DHCP options for $type/$id.\n";
  } elsif ($#$ref == 0) {
    print STDERR "[There are no DHCP options for $type/$id]\n" if ($debug >= 7);
    return;
  }

  my %pos = %{CMU::Netdb::makemap($ref->[0])};
  shift @$ref;


  foreach my $row (@$ref) {
    my ($res, $ref) = CMU::Netdb::delete_dhcp_option($dbh, $dbuser, 
				   $row->[$pos{'dhcp_option.id'}], 
				   $row->[$pos{'dhcp_option.version'}]);
    die "Failure while deleting dhcp_option from $type/$id: $res . (".join(', ', @$ref).")\n" if ($res <= 0);
  }

}


sub set_dhcp_options {
  my ($table, $row, $options) = @_;
  my ($dummy);

  print Data::Dumper->Dump([$options], ['options']) if ($debug >= 6);

  if (ref $options eq 'HASH') {
    if (ref $options->{(keys %$options)[0]}) {
      $dummy = [values %$options];
      $options = $dummy;
    } else {
      $dummy = [$options];
      $options = $dummy
    }
  } elsif (ref $options ne 'ARRAY') {
    $dummy = [$options];
    $options = $dummy;
  }

  print Data::Dumper->Dump([$options], ['options']) if ($debug >= 5);

  foreach my $opt (@$options) {
#    print Data::Dumper->Dump([$opt], ['opt']);

    my %fields;
    my $typeid;
    my $otref = CMU::Netdb::get_dhcp_option_types($dbh, $dbuser, 
						  "dhcp_option_type.name = "
						  . $dbh->quote($opt->{'dhcp_option_type.name'}));
    die "Error trying to find dhcp option type ".$opt->{'dhcp_option_type.name'}
      if (!ref $otref);
    $typeid = (keys %$otref)[0];
    die "Unable to find dhcp option type ".$opt->{'dhcp_option_type.name'} if (!$typeid);

    foreach my $param (grep(/^dhcp_option\./, keys %$opt)) {
      my $short = $param;
      $short =~ s/^dhcp_option\.//;
      $fields{$short} = $opt->{$param};
    }

    $fields{type} = $table;
    $fields{tid} = $row;
    $fields{type_id} = $typeid;

    if ($imported{$table}{$row}{dhcp_option}{$typeid} == 1) {
      print "Skipping DHCP option ".$opt->{'dhcp_option_type.name'}." for $table/$row, already imported.\n";
      next;
    }
    my ($res, $ref) = CMU::Netdb::add_dhcp_option($dbh, $dbuser, \%fields);
    die "Failure while adding dhcp_option to $table/$row: $res . (".join(', ', @$ref).")\n". Data::Dumper->Dump([\%fields], ['fields']) if ($res <= 0);

    $imported{$table}{$row}{dhcp_option}{$typeid} = 1;

  }
}



sub set_attributes {
  my ($table, $row, $attributes, $context) = @_;
  my ($dummy);

#  print Data::Dumper->Dump([$attributes], ['attributes']);

  if (ref $attributes eq 'HASH') {
    if (ref $attributes->{(keys %$attributes)[0]}) {
      $dummy = [values %$attributes];
      $attributes = $dummy;
    } else {
      $dummy = [$attributes];
      $attributes = $dummy
    }
  } elsif (ref $attributes ne 'ARRAY') {
    $dummy = [$attributes];
    $attributes = $dummy;
  }

#  print Data::Dumper->Dump([$attributes], ['attributes']);

  foreach my $attr (@$attributes) {
    print Data::Dumper->Dump([$attr], ['attr']) if ($debug >= 5);

    if ($attr->{'attribute_spec.name'} eq 'Default DHCP Service Pool') {
      $imported{default_dhcp_service_pool} = $row;
      next;
    }
    my %fields;
    my $typeid;
    my $where = "attribute_spec.name = '".$attr->{'attribute_spec.name'}."' ";
    $where .= " AND attribute_spec.scope = ".$dbh->quote($table);
    if ($context) {
      $where .= " AND attribute_spec.type = ".$dbh->quote($context);
    }
    #print "Where is:\n$where\n";
    my $asref = CMU::Netdb::list_attribute_spec_ref($dbh, $dbuser, $where,
						    'attribute_spec.name');
    die "Error trying to find attribute spec ".$attr->{'attribute_spec.name'}
      if (!ref $asref);
    $typeid = (keys %$asref)[0];
    #print Data::Dumper->Dump([$asref], ['asref']);
    die "Unable to find attribute_spec ".$attr->{'attribute_spec.name'} if (!$typeid);

    $fields{owner_table} = $table;
    $fields{owner_tid} = $row;
    $fields{spec} = $typeid;
    $fields{data} = $attr->{'attribute.data'};

    print Data::Dumper->Dump([\%fields], ['fields']) if ($debug >= 5);
    my ($res, $ref) = CMU::Netdb::add_attribute($dbh, $dbuser, \%fields);
    die "Failure while adding attribute to $table/$row: $res . (".join(', ', @$ref).")\n" if ($res <= 0);

  }
}


sub set_dns_resources {
  my ($table, $row, $options, $rname) = @_;
  my ($dummy);

#  print Data::Dumper->Dump([$options], ['options']);

  if (ref $options eq 'HASH') {
    if (ref $options->{(keys %$options)[0]}) {
      $dummy = [values %$options];
      $options = $dummy;
    } else {
      $dummy = [$options];
      $options = $dummy
    }
  } elsif (ref $options ne 'ARRAY') {
    $dummy = [$options];
    $options = $dummy;
  }

#  print Data::Dumper->Dump([$options], ['options']);

  foreach my $opt (@$options) {
    print Data::Dumper->Dump([$opt], ['opt']) if ($debug >= 5);

    my %fields;
    foreach my $param (grep(/^dns_resource\./, keys %$opt)) {
      my $short = $param;
      $short =~ s/^dns_resource\.//;
      $fields{$short} = $opt->{$param};
    }

    $fields{owner_type} = $table;
    $fields{owner_tid} = $row;
    $fields{rname} = $rname if ($rname);

    my ($res, $ref) = CMU::Netdb::add_dns_resource($dbh, $dbuser, \%fields);
    die "Failure while adding dns_resource to $table/$row: $res . (".join(', ', @$ref).")\n" if ($res <= 0);
  }
}


sub usage {
  print "Usage: $0 --config configfile --data datafile [ --debug level ]";
}

sub find_subnet {
  my $ip = shift;

  my $query = "subnet.base_address = ($ip & subnet.network_mask)";

  my $slist = CMU::Netdb::list_subnets($dbh, $dbuser, $query);

  if (!ref $slist) {
    die "Error calling list_subnets with $query: ($slist)";
  }
  my $map = CMU::Netdb::makemap($slist->[0]);

  if (defined $slist->[1]) {
    return $slist->[1][$map->{'subnet.id'}];
  } else {
    die "Unable to find subnet for IP Address ".CMU::Helper::long2dot($ip).".\n";
  }
  
}

sub find_zone {
  my $ip = shift;

  my ($a, $b, $c, $d) = split(/\./, CMU::Helper::long2dot($ip));

  my $zone =  "$c.$b.$a.IN-ADDR.ARPA";

  my $zlist = CMU::Netdb::list_dns_zones($dbh, $dbuser, "dns_zone.name = '$zone'");
  if (!ref $zlist) {
    die "Error calling list_dns_zones for $zone: ($zlist)";
  }
  my $map = CMU::Netdb::makemap($zlist->[0]);

  if (defined $zlist->[1]) {
    return $zlist->[1][$map->{'dns_zone.id'}];
  } else {
    die "Unable to find zone $zone for foreign key lookup.\n"
  }


}




