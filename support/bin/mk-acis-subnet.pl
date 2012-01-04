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
# $Id: mk-acis-subnet.pl,v 1.3 2008/03/27 19:42:42 vitroth Exp $
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

use vars qw/$debug $result @buildings @base @mask $dbh @urls $novlan/;

$debug = 0;

# take subnet names on command line
$result = GetOptions("building=s" => \@buildings,
		     "debug=i" => \$debug,
		     "novlan" => \$novlan
		    );

&usage() if (!$result);

&usage() if (!@buildings);

$dbh = CMU::Netdb::lw_db_connect() or die "Unable to connect to database";


foreach my $building (@buildings) {
  my ($where, $res, $ref, $bmap, $bid, $babbr, $bnum, $vmap, 
      $sub_vlanid, $sub_vlan, $sub_vlname, $sub_vlabbr, $sub_ts, $sub_tsname, $tsmap,
      $base_a, $base_b, $base_c, $base_d,
      $mask_a, $mask_b, $mask_c, $mask_d,
      $new_name, $new_abbr, $new_base, $new_mask, $new_mask, $new_vlan,
      $rtr_base, $rtr_lastoctet,
      $fields, $new_subid, $new_vlanid, $rvzone, %dhcp_options,
     );

  #  search for building


  $where = "building.name = '$building'";
  $res = CMU::Netdb::list_buildings($dbh, 'netreg', $where);
  if (scalar(@$res) == 1) {
    warn "Name '$building' didn't match any existing buildings.  Skipping.\n";
    next;
  }
  $bmap = CMU::Netdb::makemap($res->[0]);
  $bid = $res->[1][$bmap->{'building.id'}];
  $bnum = $res->[1][$bmap->{'building.building'}];
  $babbr = $res->[1][$bmap->{'building.abbreviation'}];
  warn "Mapped '$building' to building $bid ($babbr / $bnum)\n";


  unless ($novlan) {
    # search for trunkset
    $where = "trunkset_building_presence.buildings = $bid and trunk_set != 142";
    $res = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'building', $where);
    $tsmap = CMU::Netdb::makemap($res->[0]);
    if (scalar(@$res) != 2) {
      warn "*** Number of trunkset presences is not exactly one, can't do this automatically.\n";
      next;
    }
    $sub_ts = $res->[1][$tsmap->{'trunk_set.id'}];
    $sub_tsname = $res->[1][$tsmap->{'trunk_set.name'}];

    warn "Mapped '$building' to trunkset '$sub_tsname' ($sub_ts)\n";
  }

  # ok, start building the new data


  ($new_name = $building) =~ s/^(.*[^)\s])\s*(\(.*\))?$/$1/;
  $new_name .= " - ACIS Services";
  $new_abbr = "acis-" . lc($babbr);
  $new_base = "172.21.$bnum.0";
  $new_mask = "255.255.255.0";
  $new_vlan = ($bnum % 50) + 750;

  warn "Will create '$new_name' ($new_abbr / $new_base / $new_mask) with vlan '$new_name' / $new_vlan.\n";

  # build the list of dhcp option now, so they can be output now before db changes begin
  ($rtr_base = $new_base) =~ s/^(\d+\.\d+\.\d+)\.\d+$/\1/;
  ($rtr_lastoctet = $new_base) =~ s/^\d+\.\d+\.\d+\.(\d+)$/\1/;
  $rtr_lastoctet++;

  %dhcp_options = ( 'option routers' => "$rtr_base.$rtr_lastoctet",
		    'option subnet-mask' => $new_mask,
		    'option broadcast-address' => CMU::Netdb::long2dot(CMU::Netdb::dot2long($new_base) |
								       ~CMU::Netdb::dot2long($new_mask)),
		    'option domain-name-servers' => "128.2.1.10,128.2.1.11",
		  );

  foreach my $opt (sort(keys %dhcp_options)) {
    warn "Will add dhcp option '$opt' = '$dhcp_options{$opt}'\n";
  }


  if ($debug >= 4) {
    warn "Debug mode is $debug, doing nothing.\n";
    next;
  }

  unless ($novlan) {
    $where = "trunk_set.id = $sub_ts AND vlan.number = $new_vlan";
    $res = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'vlan', $where);
    if (scalar(@$res) != 1) {
      warn "*** Vlan $new_vlan already exists on trunkset '$sub_tsname'.  Skipping building '$building'.\n";
      next;
    }
  }


  # create matching 172.18.x.y subnet
  $fields = { 'name' => $new_name,
	      'abbreviation' => $new_abbr,
	      'base_address' => $new_base,
	      'network_mask' => $new_mask,
	      'dynamic' => 'restrict',
	      'default_mode' => 'static',
	    };


  ($res, $ref) = CMU::Netdb::add_subnet($dbh, 'netreg', $fields);

  if ($res <= 0) {
    warn "*** Error adding subnet, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
    warn "*** Skipping building '$building' due to error.\n";
    next;
  }

  $new_subid = $ref->{'insertID'};
  warn "Added subnet $new_subid.\n";
  # Add datacomm to the protections
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				 'subnet', $new_subid, '', {});
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				 'subnet', $new_subid, '', {'dept' => 'dept:acis'});
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				 'subnet', $new_subid, '', {'dept' => 'dept:busserv'});
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				 'subnet', $new_subid, '', {'dept' => 'dept:it'});




  unless ($novlan) {
    # create the vlan
    $fields = { 'name' => $new_name,
		'abbreviation' => $new_abbr,
		'number' => $new_vlan,
	      };

    ($res, $ref) = CMU::Netdb::add_vlan($dbh, 'netreg', $fields);

    if ($res <= 0) {
      warn "*** Error adding vlan, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
      warn "*** Aborting building '$building' due to error.\n";
      next;
    }
    $new_vlanid = $ref->{'insertID'};
    warn "Added vlan $new_vlanid.\n";
    # Add datacomm to protections
    CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				   'vlan', $new_vlanid, '', {});
    CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				   'vlan', $new_vlanid, '', {'dept' => 'dept:acis'});
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				 'vlan', $new_vlanid, '', {'dept' => 'dept:busserv'});
  CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				 'vlan', $new_vlanid, '', {'dept' => 'dept:it'});


    # Add the vlan to the subnet
    $fields = { 'subnet' => $new_subid,
		'vlan' => $new_vlanid
	      };

    ($res, $ref) = CMU::Netdb::add_subnet_presence($dbh, 'netreg', $fields);
    if ($res <= 0) {
      warn "*** Error adding subnet presence, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
      warn "*** Aborting building '$building' due to error.\n";
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
      warn "*** Aborting building '$building' due to error.\n";
      next;
    }
    warn "Added trunkset presence $ref->{'insertID'}\n";

    # For sanitys sake, make sure datacomm has access to the trunkset
    CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'datacomm_add',
				   'trunk_set', $sub_ts, '', {});
  }


  # Everything is now created with the appropriate permissions, now we need
  # to twiddle some extra bits on the zone.

  # add sw.cmu.local, gw.cmu.local, and net.cmu.loca domains to subnet
  $fields = { 'subnet' => $new_subid };

  foreach my $domain (qw/GW.CMU.LOCAL CARDS.AS.CMU.LOCAL/) {
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
    CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				   'subnet_registration_modes', $mode_id, '', {'dept' => 'dept:acis'});
    CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				   'subnet_registration_modes', $mode_id, '', {'dept' => 'dept:busserv'});
    CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'dept_add',
				   'subnet_registration_modes', $mode_id, '', {'dept' => 'dept:it'});
  }


  # search for matching reverse zone
  $rvzone = "$bnum.21.172.IN-ADDR.ARPA";
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
      CMU::Netdb::apply_prot_profile($dbh, 'netreg', 'all_users_add',
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
#  warn "Adding 24 pool addresses.\n";
#  ($res, $ref) = CMU::Netdb::register_ips($dbh, 'netreg', $new_subid, 24, 'pool', 
#					  'Highest First', 'inst-%ip.net.cmu.local', 
#					  'dept:nginfra', '');
#  if ($res <= 0) {
#    warn "*** Error adding pool addresses, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
#  }

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
