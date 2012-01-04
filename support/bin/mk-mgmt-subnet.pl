#!/usr/bin/perl

# mk-mgmt-subnets.pl
# script to create matching subnets in private IP space

# Copyright (c) 2004 Carnegie Mellon University. All rights reserved.
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
# $Id: mk-mgmt-subnet.pl,v 1.3 2008/03/27 19:42:43 vitroth Exp $
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use strict;
use Getopt::Long;
use CMU::Netdb;
use Data::Dumper;

use vars qw/$debug $result @subnets @base @mask $dbh @urls/;

$debug = 0;

# take subnet names on command line
$result = GetOptions("subnet=s" => \@subnets,
		     "base=s" => \@base,
		     "mask=s" => \@mask,
		     "debug=i", => \$debug,
		    );

&usage() if (!$result);

&usage() if (!@subnets);

$dbh = CMU::Netdb::lw_db_connect() or die "Unable to connect to database";

# Foreach subnet name


foreach my $subnet (@subnets) {
  my ($where, $res, $ref, $smap, $sub_id, $sub_abbr, $sub_base, $sub_mask, $vmap, 
      $sub_vlanid, $sub_vlan, $sub_vlname, $sub_vlabbr, $sub_ts, $sub_tsname, $tsmap,
      $base_a, $base_b, $base_c, $base_d,
      $mask_a, $mask_b, $mask_c, $mask_d,
      $new_name, $new_abbr, $new_base, $new_mask, $new_mask, $new_vlan,
      $rtr_base, $rtr_lastoctet,
      $fields, $new_subid, $new_vlanid, $rvzone, %dhcp_options,
     );

  $new_base = shift @base;
  $new_mask = shift @mask;
  #  search for subnet


  $where = "subnet.name = '$subnet'";
  $res = CMU::Netdb::list_subnets($dbh, 'netreg', $where);
  if (scalar(@$res) == 1) {
    warn "Name '$subnet' didn't match any existing subnets.  Skipping.\n";
    next;
  }
  $smap = CMU::Netdb::makemap($res->[0]);
  $sub_id = $res->[1][$smap->{'subnet.id'}];
  $sub_abbr = $res->[1][$smap->{'subnet.abbreviation'}];
  $sub_base = $res->[1][$smap->{'subnet.base_address'}];
  $sub_mask = $res->[1][$smap->{'subnet.network_mask'}];
  ($base_a, $base_b, $base_c, $base_d) = split /\./, CMU::Netdb::long2dot($sub_base);
  ($mask_a, $mask_b, $mask_c, $mask_d) = split /\./, CMU::Netdb::long2dot($sub_mask);
  warn "Mapped '$subnet' to subnet $sub_id ($sub_abbr / ".CMU::Netdb::long2dot($sub_base).' / '.CMU::Netdb::long2dot($sub_mask).")\n";

  # search for vlan

  $res = CMU::Netdb::list_subnet_presences($dbh, 'netreg', $where);
  $vmap = CMU::Netdb::makemap($res->[0]);
  if (scalar(@$res) != 2) {
    warn "*** Number of vlan presences is not exactly one, can't do this automatically.\n";
    next;
  }
  $sub_vlan = $res->[1][$vmap->{'vlan.number'}];
  $sub_vlanid = $res->[1][$vmap->{'vlan.id'}];
  $sub_vlname = $res->[1][$vmap->{'vlan.name'}];
  $sub_vlabbr = $res->[1][$vmap->{'vlan.abbreviation'}];

  warn "Mapped '$subnet' to vlan '$sub_vlname' ($sub_vlan / $sub_vlabbr)\n";

  # search for trunkset
  $where = "trunkset_vlan_presence.vlan = $sub_vlanid";
  $res = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'vlan', $where);
  $tsmap = CMU::Netdb::makemap($res->[0]);
  if (scalar(@$res) != 2) {
    warn "*** Number of trunkset presences is not exactly one, can't do this automatically.\n";
    next;
  }
  $sub_ts = $res->[1][$tsmap->{'trunk_set.id'}];
  $sub_tsname = $res->[1][$tsmap->{'trunk_set.name'}];

  warn "Mapped '$subnet' to trunkset '$sub_tsname' ($sub_ts)\n";


  # ok, start building the new data


  ($new_name = $subnet) =~ s/^(.*[^)\s])\s*(\(.*\))?$/$1/;
  $new_name .= " (mgmt)";
  $new_abbr = lc($sub_abbr) . "-mgmt";
  $new_base = "172.18.$base_c.$base_d" if (!$new_base);
  if (!$new_mask) {
    if ($mask_c <= 240) {
      # If the base network is 4K or larger, allocate 1K for devices
      $new_mask = "255.255.252.0";
    } else {
      # Otherwise allocate 1 class C, or less if the base network was smaller then a class c
      $new_mask = "255.255.255.$mask_d";
    }
  }
  $new_vlan = ($sub_vlan % 100) + 800;

  warn "Will create '$new_name' ($new_abbr / $new_base / $new_mask) with vlan '$new_name' / $new_vlan.\n";

  # build the list of dhcp option now, so they can be output now before db changes begin
  ($rtr_base = $new_base) =~ s/^(\d+\.\d+\.\d+)\.\d+$/\1/;
  ($rtr_lastoctet = $new_base) =~ s/^\d+\.\d+\.\d+\.(\d+)$/\1/;
  $rtr_lastoctet++;

  %dhcp_options = ( 'option routers' => "$rtr_base.$rtr_lastoctet",
		    'option subnet-mask' => $new_mask,
		    'option broadcast-address' => CMU::Netdb::long2dot(CMU::Netdb::dot2long($new_base) |
								       ~CMU::Netdb::dot2long($new_mask)),
		    'option bootfile-name' => '"network-confg"',
		    'option domain-name-servers' => "128.2.1.10,128.2.1.11",
		  );

  foreach my $opt (sort(keys %dhcp_options)) {
    warn "Will add dhcp option '$opt' = '$dhcp_options{$opt}'\n";
  }


  if ($debug >= 4) {
    warn "Debug mode is $debug, doing nothing.\n";
    next;
  }

  $where = "trunk_set.id = $sub_ts AND vlan.number = $new_vlan";
  $res = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'vlan', $where);
  if (scalar(@$res) != 1) {
    warn "*** Vlan $new_vlan already exists on trunkset '$sub_tsname'.  Skipping subnet '$subnet'.\n";
    next;
  }


  # create matching 172.18.x.y subnet
  $fields = { 'name' => $new_name,
	      'abbreviation' => $new_abbr,
	      'base_address' => $new_base,
	      'network_mask' => $new_mask,
	      'dynamic' => 'permit',
	      'default_mode' => 'static',
	    };


  ($res, $ref) = CMU::Netdb::add_subnet($dbh, 'netreg', $fields);

  if ($res <= 0) {
    warn "*** Error adding subnet, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
    warn "*** Skipping subnet '$subnet' due to error.\n";
    next;
  }

  $new_subid = $ref->{'insertID'};
  warn "Added subnet $new_subid.\n";
  # Add datacomm to the protections
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				 'subnet', $new_subid, '', {});




  # create the vlan
  $fields = { 'name' => $new_name,
	      'abbreviation' => $new_abbr,
	      'number' => $new_vlan,
	    };

  ($res, $ref) = CMU::Netdb::add_vlan($dbh, 'netreg', $fields);

  if ($res <= 0) {
    warn "*** Error adding vlan, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
    warn "*** Aborting subnet '$subnet' due to error.\n";
    next;
  }
  $new_vlanid = $ref->{'insertID'};
  warn "Added vlan $new_vlanid.\n";
  # Add datacomm to protections
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				 'vlan', $new_vlanid, '', {});


  # Add the vlan to the subnet
  $fields = { 'subnet' => $new_subid,
	      'vlan' => $new_vlanid
	    };

  ($res, $ref) = CMU::Netdb::add_subnet_presence($dbh, 'netreg', $fields);
  if ($res <= 0) {
    warn "*** Error adding subnet presence, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
    warn "*** Aborting subnet '$subnet' due to error.\n";
    next;
  }
  warn "Added subnet presence $ref->{'insertID'}\n";


  # Add the vlan to the trunkset
  $fields = { 'type' => 'vlan',
	      'vlan' => $new_vlanid,
	      'trunk_set' => $sub_ts,
	    };

  ($res, $ref) = CMU::Netdb::add_trunkset_presence($dbh, 'netreg', $fields);
  if ($res <= 0) {
    warn "*** Error adding trunkset presence, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
    warn "*** Aborting subnet '$subnet' due to error.\n";
    next;
  }
  warn "Added trunkset presence $ref->{'insertID'}\n";

  # For sanitys sake, make sure datacomm has access to the trunkset
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				   'trunk_set', $sub_ts, '', {});



  # Everything is now created with the appropriate permissions, now we need
  # to twiddle some extra bits on the zone.

  # add sw.cmu.local, gw.cmu.local, and net.cmu.loca domains to subnet
  $fields = { 'subnet' => $new_subid };

  foreach my $domain (qw/SW.CMU.LOCAL GW.CMU.LOCAL NET.CMU.LOCAL PI.CMU.LOCAL/) {
    $fields->{domain} = $domain;
    ($res, $ref) = CMU::Netdb::add_subnet_domain($dbh, 'netreg', $fields);
    if ($res <= 0) {
      warn "*** Error adding domain $domain to subnet, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
      warn "*** Continuing anyway\n"
    } else {
      warn "Added $domain to '$new_name'\n";
    }
  }


  # set permissions on static registrations

  $where = "subnet_registration_modes.subnet = $new_subid AND subnet_registration_modes.mode = 'static' AND subnet_registration_modes.mac_address = 'required' AND ISNULL(subnet_registration_modes.quota)";

  $res = CMU::Netdb::list_subnet_registration_modes($dbh, 'netreg', $where);
  if (scalar(@$res) < 2) {
    warn "*** No static mode listed on the subnet, not setting mode permissions.\n";
  } else {
    my $modemap = CMU::Netdb::makemap($res->[0]);
    my $mode_id = $res->[1][$modemap->{'subnet_registration_modes.id'}];
    CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				   'subnet_registration_modes', $mode_id, '', {});
  }


  # search for matching reverse zone
  $rvzone = "$base_c.18.172.IN-ADDR.ARPA";
  $where = "dns_zone.name = '$rvzone'";
  $res = CMU::Netdb::list_dns_zones($dbh, 'netreg', $where);
  if (scalar(@$res) > 1) {
    warn "Reverse zone already exists, not creating.\n";
  } else {
    # create if not existing as rv-permissible
    warn "Creating $rvzone zone.\n";

    $fields = { 'name' => $rvzone,
		'type' => 'rv-permissible'
	      };

    ($res, $ref) = CMU::Netdb::add_dns_zone($dbh, 'netreg', $fields);

    if ($res <= 0) {
      warn "*** Error adding reverse zone $rvzone, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
      warn "*** Continuing anyway\n"
    } else {
      my $new_rvzone = $ref->{'insertID'};
      warn "Added reverse zone $new_rvzone\n";
      CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				     'dns_zone', $new_rvzone, '', {});
    }
  }


  # set default dhcp options
  ## Load all the Option Types
  my $otl = CMU::Netdb::get_dhcp_option_types($dbh, 'netreg', '');
  if (!ref $otl) {
    warn "*** Unable to load option types, aborting.\n";
  } else {

    my %OTNameToNum;
    map { $OTNameToNum{$otl->{$_}} = $_ } keys %$otl;

    foreach my $option (sort keys %dhcp_options) {

      $fields = { 'type' => 'subnet',
		  'type_id' => $OTNameToNum{$option},
		  'value' => $dhcp_options{$option},
		  'tid' => $new_subid,
		};

      ($res, $ref) = CMU::Netdb::add_dhcp_option($dbh, 'netreg', $fields);
      if ($res <= 0) {
	warn "*** Error adding option '$option' = '$dhcp_options{$option}', result $res:\n".Data::Dumper->Dump([$ref],['reason']);
	warn "*** Continuing anyway\n";
      } else {
	warn "Added option '$option' = '$dhcp_options{$option}'\n";
      }
    }
  }

  # Add pool addresses
  warn "Adding 24 pool addresses.\n";
  ($res, $ref) = CMU::Netdb::register_ips($dbh, 'netreg', $new_subid, 24, 'pool', 
					  'Highest First', 'inst-%ip.net.cmu.local', 
					  'dept:nginfra', '');
  if ($res <= 0) {
    warn "*** Error adding pool addresses, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
  }

}








sub usage {

  print <<END_USAGE;
Usage: mk-mgmt-subnet.pl --subnet <User subnet name> [--subnet ... ] 
                         [--debug n]
Argument Details:
     subnet: Name of a subnet in Netreg for which you want to create
             the matching management subnet.  May be specified 
             multiple times.
      debug: debug level, higher numbers are more verbose
END_USAGE

  exit;

}
