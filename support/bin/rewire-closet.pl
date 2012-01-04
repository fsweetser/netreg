#!/usr/bin/perl

# rewire-closet.pl
# script to use when replacing all the devices in an closet

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
# $Id: rewire-closet.pl,v 1.6 2008/03/27 19:42:43 vitroth Exp $
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
use vars qw/$building $closet $rack $panel $defaultvlan $clustervlan $count $limit
            $abvlan $wlvlan $outlets $result $debug $dbh $where %ocmap $skip/;

$debug = 0;
$abvlan = 277;
$wlvlan = 351;

$result = GetOptions("building=s" => \$building,
		     "closet=s" => \$closet,
		     "rack=s" => \$rack,
		     "panel=s" => \$panel,
		     "defaultvlan=s" => \$defaultvlan,
		     "clustervlan=s" => \$clustervlan,
		     "debug=i" => \$debug,
		     "skip=i" => \$skip,
		     "limit=i" => \$limit);

&usage() if (!$result);

&usage() if (!defined $building || !defined $defaultvlan);

warn "Debug level is $debug\n" if ($debug);

$dbh = CMU::Netdb::lw_db_connect() or die "Unable to connect to database";

$count = 0;
$where = 'cable.from_building = '.$dbh->quote($building);
$where .= ' AND cable.from_closet = '.$dbh->quote($closet) if (defined $closet);
$where .= ' AND cable.from_rack = '.$dbh->quote($rack) if (defined $rack);
$where .= ' AND cable.from_panel = '.$dbh->quote($panel) if (defined $panel);
$where .= " AND outlet.version < DATE_SUB(now(), INTERVAL $skip DAY)" if ($skip);
$outlets = CMU::Netdb::list_outlets_cables($dbh, 'netreg', $where);

die "error $outlets ( $CMU::Netdb::errmeanings{$outlets} ) while attempting to get outlets.\n" if (not ref $outlets);

%ocmap = %{CMU::Netdb::makemap($outlets->[0])};

shift @$outlets;

warn "Found ".scalar(@$outlets)." outlets matching '$where'\n" if ($debug);

foreach my $outlet (@$outlets) {
  warn "Processing outlet:\n".Data::Dumper->Dump([$outlet],['outlet']) 
    if ($debug >= 3);
  my %fields;
  my $id = $outlet->[$ocmap{'outlet.id'}];
  my $version = $outlet->[$ocmap{'outlet.version'}];
  $fields{comment_lvl1} = $outlet->[$ocmap{'outlet.comment_lvl1'}];
  $fields{attributes} = 'change';
  $fields{status} = 'partitioned';
  $fields{flags} = $outlet->[$ocmap{'outlet.flags'}];

  my %psfields;
  my $setvlan = 0;
  $psfields{'outlet'} = $id;
  $psfields{'type'} = 'primary';
  $psfields{'trunk_type'} = 'none';
  $psfields{'status'} = 'request';

  if ($outlet->[$ocmap{'outlet.type'}] == 5) {
    $fields{type} = 5;
  } else {
    $fields{type} = 4;
  }
  if ($outlet->[$ocmap{'outlet.device'}]) {
    my $devs = CMU::Netdb::list_trunkset_device_presence($dbh,'netreg', "trunkset_machine_presence.id = '$outlet->[$ocmap{'outlet.device'}]'");
    warn Data::Dumper->Dump([$devs],['devs']);
    die "error $devs ( $CMU::Netdb::errmeanings{$devs} ) while attempting to get devs.\n" if (not ref $devs);
    my $mid = (keys(%$devs))[0];
    my $machine = $devs->{$mid};
    if (uc($machine) =~ /-AB[-\.]/) {
      warn "Updating Authbridge Outlet $id\n";
      $fields{'##primaryvlan--'} = $abvlan;
      $fields{'##oldvlan--'} = 'dummy';
      $psfields{'vlan'} = $abvlan;
      $setvlan = 1;
    } elsif (uc($machine) =~ /-WL[-\.]/) {
      warn "Updating Wirless Outlet $id\n";
      $fields{'##primaryvlan--'} = $wlvlan;
      $fields{'##oldvlan--'} = 'dummy';
      $psfields{'vlan'} = $wlvlan;
      $setvlan = 1;
    } elsif (uc($machine) =~ /-CLUSTER[-\.]/) {
      die "Found cluster switch $machine, but no cluster vlan setting provided.\nCompleted $count outlets\n" unless ($clustervlan);
      warn "Updating Cluster Outlet $id\n";
      $fields{'##primaryvlan--'} = $clustervlan;
      $fields{'##oldvlan--'} = 'dummy';
      $psfields{'vlan'} = $clustervlan;
      $setvlan = 1;
    } else {
      warn "Updating Regular Outlet $id\n";
      my $vlans = CMU::Netdb::list_outlet_vlan_memberships($dbh, 'netreg', "outlet.id = $id");

      die "error $vlans ( $CMU::Netdb::errmeanings{$vlans} ) while attempting to get vlans.\n" if (not ref $vlans);

      if (scalar(@$vlans) <= 1) {
	$fields{'##primaryvlan--'} = $defaultvlan;
	$fields{'##oldvlan--'} = 'dummy';
	$psfields{'vlan'} = $defaultvlan;
	$setvlan = 1;
      }
    }
  } else {
    $fields{'##primaryvlan--'} = $defaultvlan;
    $fields{'##oldvlan--'} = 'dummy';
    $psfields{'vlan'} = $defaultvlan;
    $setvlan = 1;
  }

  warn "Calling modify_outlet with:\n".Data::Dumper->Dump([$id, $version, \%fields],['id','version','fields']) if ($debug >= 2);

  my ($res, $ref);

#  $CMU::Netdb::buildings_cables::debug = 3;
  ($res, $ref) = CMU::Netdb::modify_outlet($dbh, 'netreg', 
					   $outlet->[$ocmap{'outlet.id'}],
					   $outlet->[$ocmap{'outlet.version'}],
					   \%fields,
					   9);

  if ($res < 0){
    die "error $res ( $CMU::Netdb::errmeanings{$res}, [".join(', ',@$ref)."] ) while attempting to modify outlet\nCompleted $count outlets\n";
  }

#   if ($setvlan) {
#     warn "Calling add_outlet_vlan_membership with:\n".Data::Dumper->Dump([\%psfields],['psfields']) if ($debug >= 2);

#     ($res, $ref) = CMU::Netdb::add_outlet_vlan_membership($dbh, 'netreg', \%psfields);
#     if ($res < 0){
#       die "error $res ( $CMU::Netdb::errmeanings{$res}, [".join(', ',@$ref)."] ) while attempting to modify outlet vlan membership\n";
#     }
#   }


  $count++;

  if (defined $limit && $count >= $limit) {
    print "Updated $count outlets\n";
    exit;
  }
}

print "Updated $count outlets\n";
exit;

sub usage {

  print <<END_USAGE;
Usage: rewire-closet.pl --building <number> [--closet <number>] 
          [--rack <number>] [--panel <number>] --defaultvlan <vlanid> 
          [--debug <number] [--skip <number of days>]
          [--limit number] [--clustervlan <vlanid>]
Argument Details:
   building: building number, as used in outlet labels
     closet: closet number/letter
       rack: rack number/letter
      panel: panel number/letter
defaultvlan: netreg row ID of the vlan to assign outlets to, if no 
             vlan is already assigned
clustervlan: netreg row ID of the vlan to assign outlets to, if the old
             switch has CLUSTER in its name
      debug: debug level, higher numbers are more verbose
       skip: skip outlets that have been updated in the last N days
      limit: limit the number of outlets processed to N
END_USAGE

  exit;

}

