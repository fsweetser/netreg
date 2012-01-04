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
# $Id: convert-1_1_5-1_1_6.pl,v 1.3 2008/03/27 19:42:45 vitroth Exp $
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
	    'schema-upd' => 'Schema updates',
	    'dhcp-upd' => 'DHCP Option Type / Global Option updates');

if ($#ARGV == -1) {
 USAGE:
  print "Usage: $0 [-all] [-dhcp-upd] [-schema-upd]\n";
  print "\t-all: Do all updates\n";
  foreach my $E (keys %Desc) {
    print "\t-$E: $Desc{$E}\n";
  }
  
  print "\n ** More descriptive text is presented with each option, and you \n";
  print "    have the option of stopping them before proceeding.\n";
  exit 1;
}

my %Run = (#'example-upd' => 0,
	   'schema-upd' => 0,
           'dhcp-upd' => 0);

my %Cmd = (#'example-upd' => \&convert_example_upd,
	   'schema-upd' => \&convert_schema_upd,
           'dhcp-upd' => \&convert_dhcp_upd);

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
  print "  * Updates building table (expand abbreviation field)\n";
  print "  * Updates cable table (expand label, building fields)\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $Res;
  # update building table
  $Res = $dbh->do("ALTER TABLE building CHANGE COLUMN abbreviation ".
		  " abbreviation CHAR(16) NOT NULL");
  print "Result from changing building.abbreviation: $Res\n";

  $Res = $dbh->do("ALTER TABLE building CHANGE COLUMN building ".
		  " building CHAR(8) NOT NULL");
  print "Result from changing building.building: $Res\n";
  
  $Res = $dbh->do("ALTER TABLE cable CHANGE COLUMN label_from ".
		  " label_from CHAR(24) NOT NULL");
  print "Result from changing cable.label_from: $Res\n";

  $Res = $dbh->do("ALTER TABLE cable CHANGE COLUMN label_to ".
                  " label_to CHAR(24) NOT NULL");
  print "Result from changing cable.label_to: $Res\n";

  $Res = $dbh->do("ALTER TABLE cable CHANGE COLUMN from_building ".
                  " from_building CHAR(8) NOT NULL");
  print "Result from changing cable.from_building: $Res\n";

  $Res = $dbh->do("ALTER TABLE cable CHANGE COLUMN to_building ".
                  " to_building CHAR(8) DEFAULT NULL");
  print "Result from changing cable.to_building: $Res\n";
  
  # subnet_presence
  $Res = $dbh->do("ALTER TABLE subnet_presence CHANGE COLUMN building ".
                  " building CHAR(8) NOT NULL");
  print "Result from changing subnet_presence.building: $Res\n";

  # subnet
  $Res = $dbh->do("ALTER TABLE subnet CHANGE COLUMN abbreviation ".
                  " abbreviation CHAR(16) NOT NULL");
  print "Result from changing subnet.abbreviation: $Res\n";

  # subnet_share
  $Res = $dbh->do("ALTER TABLE subnet_share CHANGE COLUMN abbreviation ".
                  " abbreviation CHAR(16) NOT NULL");
  print "Result from changing subnet_share.building: $Res\n";

  # machine.mode
  $Res = $dbh->do("ALTER TABLE machine CHANGE COLUMN mode ".
		  " mode enum('static','dynamic','reserved','broadcast', ".
		  " 'pool','base','secondary') NOT NULL default 'static'");
  print "Result from updating machine.mode: $Res\n";

  # Old cleanup
  $Res = $dbh->do("ALTER TABLE dhcp_option DROP COLUMN number");
  print "Result from dropping dhcp_option.number (okay if failure): $Res\n";
		  

}

sub convert_dhcp_upd {
  print "Converting DHCP Options\n\n";
  print "This adds some new DHCP option types and global DHCP options.\n";
  print "The DHCP output script has been modified to pull all options\n";
  print "from the database.\n\n";
  print "This WILL FAIL unless the libraries are up to date.\n";
  
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my %fields;
  # add dhcp option types
  # need to add: authoritative, get-lease-hostnames, ignore
  %fields = ('name' => 'authoritative',
	     'number' => '1',
	     'format' => 'RAW',
	     'builtin' => 'Y');
  my ($res, $errf) = CMU::Netdb::add_dhcp_option_type($dbh, 'netreg', \%fields);
  print "Result from adding 'authoritative' global option: $res\n";
  if ($res <= 0) {
    print " Err fields: ".join(',', @$errf)."\n";
  }

  %fields = ('name' => 'get-lease-hostnames',
	     'number' => '1',
	     'format' => 'BOOLEAN',
	     'builtin' => 'Y');
  ($res, $errf) = CMU::Netdb::add_dhcp_option_type($dbh, 'netreg', \%fields);
  print "Result from adding 'get-lease-hostnames' global option: $res\n";
  if ($res <= 0) {
    print " Err fields: ",join(',', @$errf)."\n";
  }
  
  %fields = ('name' => 'ignore',
             'number' => '1',
             'format' => 'RAW',
             'builtin' => 'Y');
  ($res, $errf) = CMU::Netdb::add_dhcp_option_type($dbh, 'netreg', \%fields);
  print "Result from adding 'ignore' global option: $res\n";
  if ($res <= 0) {
    print " Err fields: ",join(',', @$errf)."\n";
  }

  %fields = ('name' => 'max-lease-time',
             'number' => '1',
             'format' => 'INTEGER',
             'builtin' => 'Y');
  ($res, $errf) = CMU::Netdb::add_dhcp_option_type($dbh, 'netreg', \%fields);
  print "Result from adding 'max-lease-time' global option: $res\n";
  if ($res <= 0) {
    print " Err fields: ",join(',', @$errf)."\n";
  }

  %fields = ('name' => 'default-lease-time',
             'number' => '1',
             'format' => 'INTEGER',
             'builtin' => 'Y');
  ($res, $errf) = CMU::Netdb::add_dhcp_option_type($dbh, 'netreg', \%fields);
  print "Result from adding 'default-lease-time' global option: $res\n";
  if ($res <= 0) {
    print " Err fields: ",join(',', @$errf)."\n";
  }

  # add dhcp global options
  # add: authoritative "", get-lease-hostnames on, ignore client-updates
  #      max-lease-time 86400, default-lease-time 86400
  #      use-host-decl-names on
  
  my $tid = find_dhcp_ot('authoritative');
  if ($tid <= 0) {
    print "Error locating option type for: 'authoritative'\n";
  }else{
    print STDERR "TID:: $tid\n";
    %fields = ('type_id' => $tid,
	       'value' => '',
	       'type' => 'global',
	       'tid' => '0');
    
    ($res, $errf) = CMU::Netdb::add_dhcp_option($dbh, 'netreg', \%fields);
    print "Result from adding global option 'authoritative': $res\n";
    print "  Err fields: ".join(',', @$errf)."\n" if ($res <= 0);
  }

  $tid = find_dhcp_ot('get-lease-hostnames');
  if ($tid <= 0) {
    print "Error locating option type for: 'get-lease-hostnames'\n";
  }else{
    %fields = ('type_id' => $tid,
               'value' => 'on',
               'type' => 'global',
               'tid' => '0');

    ($res, $errf) = CMU::Netdb::add_dhcp_option($dbh, 'netreg', \%fields);
    print "Result from adding global option 'get-lease-hostnames on': $res\n";
    print "  Err fields: ".join(',', @$errf)."\n" if ($res <= 0);
  }

  $tid = find_dhcp_ot('ignore');
  if ($tid <= 0) {
    print "Error locating option type for: 'ignore'\n";
  }else{
    %fields = ('type_id' => $tid,
               'value' => 'client-updates',
               'type' => 'global',
               'tid' => '0');

    ($res, $errf) = CMU::Netdb::add_dhcp_option($dbh, 'netreg', \%fields);
    print "Result from adding global option 'ignore client-updates': $res\n";
    print "  Err fields: ".join(',', @$errf)."\n" if ($res <= 0);
  }

  $tid = find_dhcp_ot('max-lease-time');
  if ($tid <= 0) {
    print "Error locating option type for: 'max-lease-time'\n";
  }else{
    %fields = ('type_id' => $tid,
               'value' => '86400',
               'type' => 'global',
               'tid' => '0');

    ($res, $errf) = CMU::Netdb::add_dhcp_option($dbh, 'netreg', \%fields);
    print "Result from adding global option 'max-lease-time 86400': $res\n";
    print "  Err fields: ".join(',', @$errf)."\n" if ($res <= 0);
  }

  $tid = find_dhcp_ot('default-lease-time');
  if ($tid <= 0) {
    print "Error locating option type for: 'default-lease-time'\n";
  }else{
    %fields = ('type_id' => $tid,
               'value' => '86400',
               'type' => 'global',
               'tid' => '0');

    ($res, $errf) = CMU::Netdb::add_dhcp_option($dbh, 'netreg', \%fields);
    print "Result from adding global option 'default-lease-time 86400': $res\n";
    print "  Err fields: ".join(',', @$errf)."\n" if ($res <= 0);
  }
}

sub find_dhcp_ot {
  my ($name) = @_;
  
  my $ref = CMU::Netdb::list_dhcp_option_types($dbh, 'netreg', "dhcp_option_type.name='$name'");
  return -1 if (!ref $ref);

  return -1 if ($#$ref != 1);
  my %pos = %{CMU::Netdb::makemap($ref->[0])};

  return $ref->[1]->[$pos{'dhcp_option_type.id'}];
}
