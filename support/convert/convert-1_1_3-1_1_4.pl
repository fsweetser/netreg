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
#
# $Id: convert-1_1_3-1_1_4.pl,v 1.2 2008/03/27 19:42:45 vitroth Exp $
#

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
	   'schema-upd' => 0);

my %Cmd = (#'example-upd' => \&convert_example_upd,
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
sub convert_schema_upd {
  print "Converting table schema\n\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Deletes dns server tables (superseded by service groups)\n";
  print "  * Deletes protections entries for dns_server_*\n";
  print "  * Updates the protections.tname (remove dns server tables)\n";
  print "  * Remove service_membership.member_type (dns_server_software)\n";
  print "  * Add subnet flags (allow_secondaries, prereq_subnet)\n";
  print "  * Increase the length of dns_resource.text fields\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  # dns server tables
  my $Res;
  foreach my $Table (qw/dns_server dns_server_software dns_config 
		     dns_config_server dns_config_zone/) {
    $Res = $dbh->do("DROP TABLE $Table");
    print "Result from dropping table $Table: $Res\n";
    $Res = $dbh->do("DELETE FROM protections WHERE tname = '$Table'");
    print "Result from deleting protections entries: $Res\n";
  }

  # protections.tname

  $Res = $dbh->do("ALTER TABLE protections CHANGE COLUMN tname ".
" tname ENUM ('users', 'groups', 'building', 'cable', 'outlet',
'outlet_type', 'machine', 'network', 'subnet', 'subnet_share',
'subnet_presence', 'subnet_domain', 'dhcp_option_type',
'dhcp_option', 'dns_resource_type', 'dns_resource', 'dns_zone',
'_sys_scheduled', 'activation_queue', 'service', 'service_membership',
'service_type', 'attribute', 'attribute_spec', 'outlet_subnet_membership')
NOT NULL ");
  print "Result from changing protections.tname: $Res\n";

  # subnet flags
  $Res = $dbh->do("ALTER TABLE subnet CHANGE COLUMN flags ".
"flags SET ('no_dhcp', 'no_static', 'delegated', 'allow_secondaries', 
 'prereg_subnet') NOT NULL DEFAULT ''");
  print "Result from changing subnet.flags: $Res\n";

  # change dns_resource.text*
  $Res = $dbh->do("ALTER TABLE dns_resource CHANGE COLUMN text0 ".
" text0 VARCHAR(255)");
  print "Result from changing dns_resource.text0: $Res\n";
  
  $Res = $dbh->do("ALTER TABLE dns_resource CHANGE COLUMN text1 ".
" text1 VARCHAR(255)");
  print "Result from changing dns_resource.text1: $Res\n";

  # service_membership.member_type
  $Res = $dbh->do("ALTER TABLE service_membership CHANGE COLUMN ".
" member_type member_type ENUM ('activation_queue', 'building', 'cable',
'dns_zone', 'groups', 'machine', 'outlet', 'outlet_type', 'service',
'subnet', 'subnet_share', 'users') NOT NULL");
  print "Result from changing service_membership: $Res\n";
}


