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

use strict;
use Fcntl ':flock';

use lib '../bin';
BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::config;

my $DBUSER = 'netreg';

## NOTE: When adding a new conversion routine, you should
## make a short key (like 'dns-conv'). Set the value of the
## key in %Desc to some short descriptive text.
## Set the key to value '0' in %Run (or 1 if you want it to ALWAYS run)
## Set the key to be a reference to the update function in %Cmd

my %Desc = (#'example-upd' => 'Do the example updates',
	    'afsdb-upd' => 'Add AFSDB DNS Resource type',
	    'schema-upd' => 'Schema updates');

if ($#ARGV == -1) {
 USAGE:
  print "Usage: $0 [-all] [-afsdb-upd] [-schema-upd]\n";
  print "\t-all: Do all updates\n";
  foreach my $E (keys %Desc) {
    print "\t-$E: $Desc{$E}\n";
  }
  
  print "\n ** More descriptive text is presented with each option, and you \n";
  print "    have the option of stopping them before proceeding.\n";
  exit 1;
}

my %Run = (#'example-upd' => 0,
	   'afsdb-upd' => 0,
	   'schema-upd' => 0);

my %Cmd = (#'example-upd' => \&convert_example_upd,
	   'afsdb-upd' => \&convert_afsdb_upd,
	   'schema-upd' => \&convert_schema_upd);

## NOTE: No more changes after this point, except for the convert
## routines.

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
if (!$dbh) {
  print STDERR "Unable to get database connection. Exiting.\n";
  exit 10;
}

foreach (keys %Run) {
  if ($Run{$_}) {
    $Cmd{$_}->();
  }
}

exit 0;

### ****************************************************************************
sub convert_afsdb_upd {
  print "Adding AFSDB DNS Resource Type\n\n";
  print "This simply adds the AFSDB Resource Type to your dns_resource_type\n".
        "table. You can skip this update and your system will work fine.\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $Res = $dbh->do("INSERT INTO dns_resource_type (name, format) VALUES ".
		     "('AFSDB', 'NM0')");
  print "Result from adding AFSDB: $Res\n";
} 

sub convert_schema_upd {
  print "Converting table schema\n\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Adds dhcp_option.number field\n";
  print "  * Adds machine flags: no_dnsfwd, no_dnsrev\n";
  print "  * Adds a key on machine.mac_address and machine.ip_address_subnet\n";
  print "  * Adds the outlet_subnet_membership table\n";
  print "  * Modify protections.tname\n";
  print "  * Modify service_membership.member_type\n";
  print "  * Modify subnet.vlan\n";

  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  #dhcp_option.number
  my $Res = $dbh->do("ALTER TABLE dhcp_option ADD COLUMN number INT UNSIGNED NOT NULL");
  print "Result from adding dhcp_option.number: $Res\n";

  #machine flags
  $Res = $dbh->do("ALTER TABLE machine CHANGE COLUMN flags flags set('abuse', 'suspend', 'stolen', 'no_dnsfwd', 'no_dnsrev') NOT NULL");
  print "Result from adding machine flags: $Res\n";

  #machine indices
  $Res = $dbh->do("ALTER TABLE machine ADD KEY index_mac_address (mac_address)");
  print "Result from adding first key: $Res\n";
  $Res = $dbh->do("ALTER TABLE machine ADD KEY index_subnet_mac (ip_address_subnet, mac_address)");
  print "Result from adding second key: $Res\n";

  # outlet_subnet_membership
  my $OSM =
"CREATE TABLE outlet_subnet_membership (version timestamp(14) NOT NULL, ".
"id int(10) unsigned NOT NULL auto_increment, ".
"outlet int(10) unsigned NOT NULL default '0', ".
"subnet int(10) unsigned NOT NULL default '0', ".
"type enum('primary','voice','other') NOT NULL default 'primary', ".
"trunk_type enum('802.1Q','ISL','none') NOT NULL default '802.1Q', ".
"status enum('request','active','delete','error','errordelete') NOT NULL default 'request', ".
"PRIMARY KEY  (id), ".
"UNIQUE KEY index_membership (outlet,subnet), ".
"KEY index_type (outlet,subnet,type,trunk_type) ".
") TYPE=MyISAM";

  $Res = $dbh->do($OSM);
  print "Result from adding outlet_subnet_membership: $Res\n";

  # protections.tname
  my $PTN = "ALTER TABLE protections CHANGE COLUMN tname tname enum('users','groups','building','cable','outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence','subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource','dns_zone','dns_server','dns_server_software','dns_config','dns_config_server','dns_config_zone','_sys_scheduled','activation_queue','service','service_membership','service_type','attribute','attribute_spec','outlet_subnet_membership') NOT NULL default 'users'";
  $Res = $dbh->do($PTN);
  print "Result from modifying protections.tname: $Res\n";

  # service_membership.member_type
  $Res = $dbh->do("ALTER TABLE service_membership CHANGE COLUMN member_type ".
		  "member_type enum('activation_queue','building','cable','dns_server_software','dns_zone','groups','machine','outlet','outlet_type','service','subnet','subnet_share','users') NOT NULL default 'activation_queue'");
  print "Result from modifying service_membership.member_type: $Res\n";

  # subnet.vlan
  $Res = $dbh->do("ALTER TABLE subnet CHANGE COLUMN vlan vlan char(8) NOT NULL");
  print "Result from modifying subnet.vlan: $Res\n";
  
}


