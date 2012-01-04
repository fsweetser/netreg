#!/usr/bin/perl
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
# $id$

use strict;

use lib '../bin';
BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::config;

CMU::Netdb::netdb_debug({helper => 0});
CMU::Netdb::netdb_debug(0);

my %Desc = ();
my %Run = ();
my %Cmd = ();
          
my @RunKeys = keys %Run;
if ($#RunKeys == -1) {
  print "There are no conversion operations in this conversion script.\n";
  exit 0;
}
 
if ($#ARGV == -1) {
 USAGE:
  print "Usage: $0 [-all]\n";
  print "\t-all: Do all updates\n";
  foreach my $E (keys %Desc) {
    print "\t-$E: $Desc{$E}\n";
  }
  
  print "\n ** More descriptive text is presented with each option, and you \n";
  print "    have the option of stopping them before proceeding.\n";
  exit 1;  
}

my $RunAny = 0;
foreach (@ARGV) {
  if ($_ eq '-all') {
    map { $Run{$_} = 1; } keys %Run;
    $RunAny = 1;
  }else{
    my $arg = $_;
    $arg =~ s/^\-//;
    if (!defined $Run{$arg}) {
      print STDERR "Unknown flag: -$arg\n";
      goto USAGE;
      exit;
    }
    $Run{$arg} = 1;
    $RunAny = 1;   
  }
}  
   
## Make a connection
exit 0 if (!$RunAny);

print "This conversion script requires access to modify table structures \n".
"in your database. Please provide your mysql root password for this.\n\n";

system('stty -echo');
print "Password: ";
my $in = <STDIN>;
system('stty echo');
chomp($in);

my $dbh = DBI->connect("DBI:mysql:netdb:localhost", "root", $in);
unless ($dbh) {
  print "Unable to get DB connection. Exiting!\n";
  exit(10);
}

foreach (sort keys %Run) {
  if ($Run{$_}) {
    $Cmd{$_}->();  
  }
}  
 
exit 0;

sub convert_schema_upd {
  print "Converting table schema\n\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Creates vlan table\n";
  print "  * Creates vlan_presence table\n";
  print "  * Updates protections table (expand tname)\n";
  print "  * Updates service_membership table (expand member_type)\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $query = <<END_SELECT;
  CREATE TABLE vlan (
    version timestamp(14) NOT NULL,   
    id int(10) unsigned NOT NULL auto_increment,
    name char(64) NOT NULL default '', 
    abbreviation char(16) NOT NULL default '',
    number char(8) NOT NULL default '',
    PRIMARY KEY  (id),
    UNIQUE KEY index_name (name),
    UNIQUE KEY index_number (number)
  ) TYPE=MyISAM
END_SELECT
  my $res = $dbh->do($query);
  print "Created vlan table. Status: $res\n";

  $query = <<END_SELECT;
  CREATE TABLE vlan_presence (
    version timestamp(14) NOT NULL,
    id int(10) unsigned NOT NULL auto_increment,
    vlan int(10) unsigned NOT NULL default '0',
    building char(8) NOT NULL default '',  
    PRIMARY KEY  (id),
    UNIQUE KEY index_nodup (vlan,building),
    KEY index_vlan (vlan),
    KEY index_building (building)
  ) TYPE=InnoDB
END_SELECT
  $dbh->do($query);
  print "Created vlan_presence table. Status: $res\n";

  print "Altering protections table to include vlan and vlan_membership entries.\n";
  $query = "ALTER TABLE protections CHANGE tname tname enum('users','groups','building','cable','outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence','subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource','dns_zone','_sys_scheduled','activation_queue','service','service_membership','service_type','attribute','attribute_spec','outlet_subnet_membership','vlan','vlan_presence') NOT NULL default 'users';";
  $res = $dbh->do($query);
  print "  Done. Status: $res\n";

  print "Altering servive_membership table to include vlans as services.\n";
  $query = "ALTER TABLE service_membership CHANGE member_type member_type enum('activation_queue','building','cable','dns_zone','groups','machine','outlet','outlet_type','service','subnet','subnet_share','users','vlan') NOT NULL default 'activation_queue';";
  $res = $dbh->do($query);
  print "  Done. Status: $res\n";

  foreach my $table ("", "_presence") {
    print "Copying protections from subnet$table to vlan$table\n";
    my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet'.$table, 0);
    foreach my $protection (@{$protections}) {
      my ($type, $name, $rights, $level) = @{$protection};
      print "  $type/$name/$rights/$level\n";
      if ($type eq 'user') {
        CMU::Netdb::add_user_to_protections($dbh, 'netreg', $name, 'vlan'.$table, 0, $rights, $level);
      } elsif ($type eq 'group') {
        CMU::Netdb::add_group_to_protections($dbh, 'netreg', $name, 'vlan'.$table, 0, $rights, $level);
      }
    }
  }
}

sub convert_vlans_add {
  print "Adding VLANS from data in subnet table.\n";
  print "This populates the VLAN table based on information about VLANS\n";
  print "currently present in your VLAN table.\n";

  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $subnets = CMU::Netdb::list_subnets($dbh, 'netreg', "subnet.vlan != '' ORDER BY subnet.vlan");
  my %map = %{ CMU::Netdb::makemap( shift(@{$subnets}) ) };

  foreach my $subnet (@{$subnets}) {
    my $sid  = $subnet->[$map{"subnet.id"}];
    my $name = $subnet->[$map{"subnet.name"}];
    my $abbr = $subnet->[$map{"subnet.abbreviation"}];
    my $vlan = $subnet->[$map{"subnet.vlan"}];

    print "Subnet: $name ($abbr, VLAN: $vlan)\n";

    my $vlans = CMU::Netdb::machines_subnets::list_vlans($dbh, 'netreg', "vlan.number = '$vlan'");

    my $rowid;
    if ($#$vlans < 1) {
      my ($res, $warns) = CMU::Netdb::machines_subnets::add_vlan($dbh, 'netreg', { 'name' => $name, 'abbreviation' => $abbr, number => $vlan });
      $rowid = $warns->{"insertID"};
    } else {
      my %vlanmap = %{ CMU::Netdb::makemap( shift(@{$vlans}) ) };
      $rowid = $vlans->[0]->[$vlanmap{"vlan.id"}];
    }

    my $presences = CMU::Netdb::list_subnet_presences($dbh, 'netreg', "subnet_presence.subnet = $sid");
    my %presmap = %{ CMU::Netdb::makemap( shift @{$presences} ) };
    foreach my $presence (@{$presences}) {
  #    print "Presnce: ".$presence->[$presmap{"subnet_presence.building"}]."\n";
      CMU::Netdb::add_vlan_presence($dbh, 'netreg', { vlan => $rowid, building => $presence->[$presmap{"subnet_presence.building"}] });
    }

    my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet', $sid);
    foreach my $protection (@{$protections}) {
      my ($type, $name, $rights, $level) = @{$protection};
      print "  $type/$name/$rights/$level\n";
      if ($type eq 'user') {
        CMU::Netdb::add_user_to_protections($dbh, 'netreg', $name, 'vlan', $rowid, $rights, $level);
      } elsif ($type eq 'group') {
        CMU::Netdb::add_group_to_protections($dbh, 'netreg', $name, 'vlan', $rowid, $rights, $level);
      }
    }
  }
}

$dbh->disconnect;
