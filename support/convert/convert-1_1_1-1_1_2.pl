#!/usr/bin/perl

## Converts the DNS server software entries into service group
## members

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

if ($#ARGV == -1) {
 USAGE:
  print "Usage: $0 [-all] [-dns-sg] [-dhcp-ot] [-sys-s] [-ddns-auth]\n";
  print "\t-all: Do all updates\n".
    "\t-dns-sg: Do the DNS Server Group updates\n".
      "\t-dhcp-ot: Do the DHCP Option Type updates\n".
	"\t-sys-s: Do the _sys_scheduled update\n".
	  "\t-ddns-auth: Do DDNS Auth updates\n\n";
  
  print " ** More descriptive text is presented with each option, and you \n";
  print "    have the option of stopping them before proceeding.\n";
  exit 1;
}

my %Run = ('dns-sg' => 0,
	   'dhcp-ot' => 0,
	   'sys-s' => 0,
	   'ddns-auth' => 0);

my %Cmd = ('dns-sg' => \&convert_dns_server,
	   'dhcp-ot' => \&convert_dhcp_options,
	   'sys-s' => \&convert_sys_scheduled,
	   'ddns-auth' => \&convert_ddns_auth);

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
sub convert_ddns_auth {
  print "Converting DDNS Auth\n\n";
  print "This is a very small change, just changing the type of column\n ".
    "dns_zone.ddns_auth to 'text'.\n";
  
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $Res = $dbh->do("ALTER TABLE dns_zone CHANGE COLUMN ddns_auth ddns_auth ".
		     "text");
  print "Result from changing dns_zone.ddns_auth column: $Res\n";
}

sub convert_sys_scheduled {
  print "Converting _sys_scheduled\n\n";
  print "This is a very small change, just adding the 'blocked_until' column.\n";
  
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);
  
  my $Res = $dbh->do("ALTER TABLE _sys_scheduled ADD COLUMN blocked_until datetime NOT NULL DEFAULT 0");
  print "Result from adding blocked_until column: $Res\n";
}

sub convert_dhcp_options {
  print "Converting DHCP Options\n\n";
  print "We are going to: 
  * Change the dhcp_option table to reference dhcp_option_type.id instead of
    dhcp_option_type.number
  * Extend the dhcp_option.type field to include services
  * Change the indices of dhcp_option_type to remove uniqueness restriction
    of dhcp_option_type.number
  * Add the dhcp_option_type.builtin column
  * Change the dhcp_option_type.format structure
  * Update the values of dhcp_option_type.format to reflect the new validation
  * Guess the values of dhcp_option_type.builtin (probably very accurate)
  * Delete old-style options of the form 'option option-XXX', where XXX was a 
    number
\n";
  
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);
  
  # Get the full list of number -> ID
  my %NumToID;
  my $dhtN = $dbh->selectall_arrayref("SELECT number, id FROM dhcp_option_type");
  if (!ref $dhtN) {
    print STDERR "Error selecting number/id from dhcp_option_type!\n";
    exit 5;
  }

  map { $NumToID{$_->[0]} = $_->[1]; } @$dhtN;
  
  # Convert the dhcp_option fields
  my $Res = $dbh->do("ALTER TABLE dhcp_option ADD COLUMN type_id INT UNSIGNED NOT NULL");
  print "Result of ALTER TABLE: $Res\n";
  
  # Get all the IDs we need to update
  my %Upd;
  my $NUp = $dbh->selectall_arrayref("SELECT number FROM dhcp_option");
  if (!ref $NUp) {
    print STDERR "Error selecting numbers from dhcp_option!";
    exit 6;
  }

  map { $Upd{$_->[0]} = 1; } @$NUp;
  
  foreach (keys %Upd) {
    my $Res = $dbh->do("UPDATE dhcp_option SET type_id = $NumToID{$_} WHERE number = $_");
    print "Updating $_: result code: $Res\n";
  }

  # Extend the dhcp_option.type field
  $Res = $dbh->do("ALTER TABLE dhcp_option CHANGE type type ".
		  "enum('global', 'share', 'subnet', 'machine', 'service')".
		  " NOT NULL");

  # Muck with dhcp_option_type: remove the unique index on number, add
  # the builtin column, change the 'format' spec
  $Res = $dbh->do("ALTER TABLE dhcp_option_type DROP INDEX index_number");
  print "Result of dropping index_number: $Res\n";
  
  $Res = $dbh->do("ALTER TABLE dhcp_option_type ADD INDEX ".
		  "index_number (number)");
  print "Result of adding (non-unique) index_number: $Res\n";
  
  $Res = $dbh->do("ALTER TABLE dhcp_option_type ADD COLUMN builtin ".
		  "ENUM('Y', 'N') DEFAULT 'N' NOT NULL");
  print "Result of adding builtin column: $Res\n";

  $Res = $dbh->do("ALTER TABLE dhcp_option_type CHANGE COLUMN format ".
		  "format varchar(255) NOT NULL");
  print "Result of changing format spec: $Res\n";

  
  # Go through and change all the format specs
  my %format_conversion = ('B' => 'UNSIGNED INTEGER 8',
			   'BA' => 'ARRAY OF UNSIGNED INTEGER 8',
			   'e' => 'e',
			   'f' => 'BOOLEAN',
			   'I' => 'IP-ADDRESS',
			   'i' => 'IP-ADDRESS',
			   'IA' => 'ARRAY OF IP-ADDRESS',
			   'IIA' => 'ARRAY OF { IP-ADDRESS , IP-ADDRESS }',
			   'l' => 'INTEGER 32',
			   'L' => 'UNSIGNED INTEGER 32',
			   'S' => 'UNSIGNED INTEGER 16',
			   'SA' => 'ARRAY OF UNSIGNED INTEGER 16',
			   't' => 'TEXT',
			   'X' => 'STRING');

  foreach (keys %format_conversion) {
    $Res = $dbh->do("UPDATE dhcp_option_type SET format = ".
		    "'$format_conversion{$_}' WHERE format = ".
		    "binary '$_'");
    print "Format conversion of $_: $Res\n";
  }
  
  # Cleanup the value of 'builtin'
  $dbh->do("UPDATE dhcp_option_type SET builtin = 'Y' WHERE ".
	   " name NOT LIKE 'option option%' AND (number < 90 OR number > 1023)");

  # Delete the 'option option' ones
  $dbh->do("DELETE FROM dhcp_option_type WHERE name LIKE 'option option%'");

  # Change indices
  $dbh->do("ALTER TABLE dhcp_option DROP INDEX index_nodup");
  print "Result of dhcp_option index drop: $Res\n";

  $Res = $dbh->do("ALTER TABLE dhcp_option ADD UNIQUE index_nodup (type_id,type,tid,value)");
  print "Result of index add: $Res\n";
  
  print "*********************** Note *********************************************\n";
  print "You need to execute the following on the database once conversion is done:\n ".
    "ALTER TABLE dhcp_option DROP COLUMN number\n";

}

sub add_server_groups {
  print "\n\nAdding service groups. This is required if you are converting 
the DNS server software groups. This should be completely safe. We're also
going to change the attribute and attribute_spec definitions slightly, to 
add users/groups as possible types. This should also be safe.\n";

  print "Proceed [default: no]?";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my %services = ('DNS View Definition' => 
		  [ 
		   ['Server Version', 'enum(bind4,bind8,bind9)', 'service', 
		    1, 'The version of the server software that this view applies to.'],
		   
		   ['DNS Parameter', 'ustring', 'service',
		    0, 'general format for defining a parameter (free form text)']
		  ],
		  
		  'DNS Server Group' =>
		  [
		   ['Service View Name', 'string64', 'service_membership',
		    1, 'The name of a view specification in this server group. '.
		    '_default_ is the global space.'],

		   ['Server Version', 'enum(bind4,bind8,bind9)', 'service_membership',
		    1, 'The version of the server software that this view applies to.'],
		   
		   ['Service View Order', 'int', 'service_membership',
		    1, 'A cardinal ordering of this view in the configuration. '.
		    'Numerical order is assumed, 1 at top. If more than one '.
		    'have the same value, the ordering is of those is not guaranteed.'],
		   
		   ['Zone In View', 'string64', 'service_membership',
		    0, 'Specify the view that this zone should be in. '.
		    'No specified views will cause it to be put in the default view.'],

		   ['Zone Parameter', 'ustring', 'service_membership',
		    0, 'A general zone option or other parameter. '.
		    'Semicolon will be appended.'],

		   ['Server Type', 'enum(master,slave,none)', 'service_membership',
		    1, 'Should zones be setup as master or secondary for this machine.']
		  ],
		  
		  'DHCP Class' => 
		  [
		   ['Match Statement', 'ustring', 'service', 1,
		    'A statement to match clients to this class.']
		  ]);
  
  foreach my $S (keys %services) {
    my $sinfo = $dbh->selectall_arrayref
      ("SELECT id FROM service_type WHERE name = '$S'");
    my $SID;
    if (ref $sinfo && defined $sinfo->[0] && defined $sinfo->[0]->[0]) {
      $SID = $sinfo->[0]->[0];
      print "service_type $S exists: $SID\n";
    }else{
      my $res = $dbh->prepare("INSERT INTO service_type (name) VALUES ".
			      "('$S')");
      $res->execute();
      
      $SID = $dbh->{'mysql_insertid'};
      print "Added service_type $S: $SID\n";
    }
    foreach my $AttrSpec (@{$services{$S}}) {
      my ($name, $format, $scope, $ntimes, $desc) = @$AttrSpec;
      my $ainfo = $dbh->selectall_arrayref
	("SELECT id FROM attribute_spec WHERE name = '$name' AND ".
	 "scope = '$scope' AND type = '$SID'");
      next 
	if (ref $ainfo && defined $ainfo->[0] && defined $ainfo->[0]->[0]);

      # Insert the attribute
      my $res = $dbh->prepare
	("INSERT INTO attribute_spec (name, format, scope, type, ntimes, ".
	 "description) VALUES ('$name', '$format', '$scope', $SID, ".
	 "$ntimes, '$desc')");
      $res->execute();
      my $AID = $dbh->{'mysql_insertid'};
      print "Added attribute $name ($AID)\n";
    }
    # Add protections for the service
    my ($res, $ref) = CMU::Netdb::auth::add_group_to_protections
      ($dbh, 'netreg', 'netreg:admins', 'service_type', $SID, 
       'ADD', 9, '');
  }
  

  $dbh->do("ALTER TABLE attribute_spec CHANGE COLUMN scope ".
	   "scope enum('service_membership','service','users','groups') ".
	   "NOT NULL default 'service_membership'");

  $dbh->do("ALTER TABLE attribute CHANGE COLUMN owner_table ".
	   "owner_table enum('service_membership','service','users','groups') ".
	   "NOT NULL default 'service_membership'");
}


sub convert_dns_server {
  &add_server_groups();
  

  print "\n\nConversion from DNS server software groups to DNS Server Group.\n\n";
  print "We are going to:
  * Change the service_membership table (remove 'machine', 
    add 'member_type' and 'member_tid')
  * Convert all of your DNS Server setups to the new service group format
    - Add service version information
    - Add DNS Zones to the service
   
\n";

  print "Proceed [default: no]?";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);
  
  ## Change the table structure
  $dbh->do("ALTER TABLE service_membership ADD COLUMN member_type ".
	   "enum('activation_queue','building','cable',".
	   "'dns_server_software','dns_zone','groups','machine',".
	   "'outlet','outlet_type','service','subnet','subnet_share',".
	   "'users') NOT NULL default 'activation_queue'");
  
  $dbh->do("ALTER TABLE service_membership ADD COLUMN member_tid ".
	   "int unsigned not null");

  $dbh->do("UPDATE service_membership SET member_type = 'machine', ".
	   "member_tid = machine");
  
  $dbh->do("ALTER TABLE service_membership DROP INDEX index_memberships");

  $dbh->do("ALTER TABLE service_membership DROP COLUMN machine");

  $dbh->do("ALTER TABLE service_membership ADD UNIQUE index_members ".
	   "(member_type,member_tid,service)");
  

  my $ServerGroupType = 0;
  
  ## Figure out the ID of service group "DNS Server Group"
  
  my $sres = CMU::Netdb::list_service_types_ref
    ($dbh, $DBUSER, "service_type.name = 'DNS Server Group'",
     'service_type.name');
  
  if (!ref $sres) {
    print "Couldn't determine the ID of the DNS Server Group!\n";
    exit 1;
  }else{
    my @a = keys %$sres;
    if ($#a == -1) {
      print "Couldn't determine the ID of the DNS Server Group!\n";
      exit 1;
    }
    $ServerGroupType = $a[0];
    print "Keys: ".join(',', @a)."\n";
  }
  
  print "ServerGroupType of DNS Server Group is: $ServerGroupType\n";
  
  ## Determine the attribute spec ID for Nameserver Version
  my $NSVersionID = -1;
  {
    my $sres = CMU::Netdb::list_attribute_spec_ref
      ($dbh, $DBUSER, "attribute_spec.scope = 'service_membership' ".
       " AND attribute_spec.type = $ServerGroupType AND ".
       " attribute_spec.name = 'Server Version'", 
       'attribute_spec.name');
    
    if (!ref $sres) {
      print "Couldn't determine the ID for the Nameserver Version attribute spec.\n";
    }else{
      my @a = keys %$sres;
      $NSVersionID = $a[0];
      print "NSVersionID: $NSVersionID\n";
    }
  }
  
  ## Determine the attribute spec ID for Zone Server Type
  my $ZoneTypeID = -1;
  {
    my $sres = CMU::Netdb::list_attribute_spec_ref
      ($dbh, $DBUSER, "attribute_spec.scope = 'service_membership' ".
       " AND attribute_spec.type = $ServerGroupType AND ".
       " attribute_spec.name = 'Server Type'", 
       'attribute_spec.name');
    if (!ref $sres) {
      print "Couldn't determine the ID for the Zone Type attribute spec.\n";
    }else{
      my @a = keys %$sres;
      $ZoneTypeID = $a[0];
      print "ZoneTypeID: $ZoneTypeID\n";
    }
  }
  
  my %ConfigTypes = ();
  my $configs = CMU::Netdb::list_dns_configs($dbh, $DBUSER,"");
  my $ConfigsMap = CMU::Netdb::makemap($configs->[0]);
  
  my %ConfigToServerGroup;
  my %ConfigNameToID;
  # Go through all the config names and see if they already 
  # exist as services. If not, add one.
  for my $i (1..@{$configs}-1) { 
  GroupStart:
    my $Name = $configs->[$i][$ConfigsMap->{"dns_config.name"}];
    $Name =~ s/\s+/\-/g;
    my $ConfigID = $configs->[$i][$ConfigsMap->{"dns_config.id"}];
    $ConfigNameToID{$Name} = $ConfigID;
    
    my $sref = CMU::Netdb::list_services
      ($dbh, $DBUSER, 
       "service.type = '$ServerGroupType' AND ".
       "service.name = '${Name}.dns'");
    
    if (ref $sref && $#$sref > 0) {
      my %pos = %{CMU::Netdb::makemap($sref->[0])};
      $ConfigToServerGroup{$Name} = $sref->[1]->[$pos{'service.id'}];
      my ($res, $ref) = CMU::Netdb::auth::add_group_to_protections
	($dbh, 'netreg', 'netreg:admins', 'service', $sref->[1]->[$pos{'service.id'}],
	 'ADD', 9, '');
      if ($res < 1) {
	print "Error adding protection entry for service group $Name\n";
      }
    }else{
      print "Adding $Name server group..\n";
      my %fields = ('name' => "${Name}.dns",
		    'type' => $ServerGroupType,
		    'description' => "$Name DNS Server Group");
      my ($res, $ref) = CMU::Netdb::add_service($dbh, $DBUSER, \%fields);
      if ($res != 1) {
	print "Error adding $Name. Exiting ($res).\n";
	exit 2;
      }else{
	$ConfigToServerGroup{$Name} = $dbh->{'mysql_insertid'};
	goto GroupStart;
      }
    }
  }
  
  ## Now figure out what hosts to add to these service groups
  my $servers = CMU::Netdb::list_dns_config_server_machines($dbh,$DBUSER,
							    "dns_server.control='internal' ORDER by machine.host_name, dns_server.software");
  my $ServerMap = CMU::Netdb::makemap($servers->[0]);
  
  my %BoundTop;
  my $DHCPbits;
  for my $i (1..@{$servers}-1) { 
    
    my $Hostname = lc($servers->[$i][$ServerMap->{"machine.host_name"}]);
    my $MachID = $servers->[$i][$ServerMap->{"machine.id"}];
    
    my $Level = $servers->[$i][$ServerMap->{"dns_config.name"}];
    $Level =~ s/\s+/\-/g;
    my $Software = $servers->[$i][$ServerMap->{"dns_server.software"}];
    my $ZoneType = $servers->[$i][$ServerMap->{"dns_config_server.type"}];
    
    ## Add $MachID to the service group
    my %fields = ('member_type' => 'machine',
		  'member_tid' => $MachID,
		  'service' => $ConfigToServerGroup{$Level});
    my ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $DBUSER,
							 \%fields);
    if ($res != 1) {
      print "Error adding $Hostname to group $Level!\n";
    }else{
      print "Added $Hostname to group $Level.\n";
    }
    
    ## Get ID of member
    my ($res, $rMemRow) = CMU::Netdb::list_service_members
      ($dbh, $DBUSER, "service_membership.member_type = 'machine' AND ".
       "service_membership.member_tid = $MachID AND ".
       " service_membership.service = $ConfigToServerGroup{$Level} ");
    
    my $SMemID;
    if ($res < 0) {
      print "Error finding ID for member $Hostname\n";
      exit 3;
    }else{
      my @a = keys %$rMemRow;
      $SMemID = $a[0];
    }
    
    ## Now add attributes of the hosts:
    ##  - Version of nameserver
    ##  - Master/secondary
    
    ## Okay, I'm lazy and hardcoding this
    my %softTypes = (1 => 'bind4', 2 => 'bind8', 3 => 'bind9');
    %fields = ('spec' => $NSVersionID,
	       'owner_table' => 'service_membership',
	       'owner_tid' => $SMemID,
	       'data' => $softTypes{$Software});
    my ($res, $ref) = CMU::Netdb::add_attribute
      ($dbh, $DBUSER, \%fields);
    
    if ($res != 1) {
      if ($res == -45) {
	print "Nameserver version attribute already exists for $Hostname\n";
      }else{
	print "Error adding Nameserver Version attribute to $Hostname: $res ($NSVersionID, $SMemID)\n";
      }
    }else{
      print "Added Nameserver Version attribute to $Hostname\n";
    }
    
    # Add the master/slave designation
    %fields = ('spec' => $ZoneTypeID,
	       'owner_table' => 'service_membership',
	       'owner_tid' => $SMemID,
	       'data' => $ZoneType);
    my ($res, $ref) = CMU::Netdb::add_attribute
      ($dbh, $DBUSER, \%fields);
    
    if ($res != 1) {
      if ($res == -45) {
	print "Zone Type attribute already exists for $Hostname\n";
      }else{
	print "Error adding Zone Type attribute to $Hostname: $res\n";
      }
    }else{
      print "Added Zone Type attribute to $Hostname\n";
    }
  }
  
  ## Now add all the zones to the appropriate server groups, and 
  ## the attributes of the zone
  
  foreach my $Level (keys %ConfigToServerGroup) {
    print "Adding zones to $Level ($ConfigNameToID{$Level})\n";
    my $zones = CMU::Netdb::list_dns_config_zone_dns_zones
      ($dbh,$DBUSER,
       "dns_config_zone.config = $ConfigNameToID{$Level} ORDER BY dns_zone.name");
    if (!ref $zones) {
      print "Unable to list zones for service group $Level!\n";
      next;
    }
    my $ZoneMap = CMU::Netdb::makemap($zones->[0]);
    
    for my $k (1..@{$zones}-1) {
      my $ZoneID = $zones->[$k][$ZoneMap->{"dns_zone.id"}];
      my $z = $zones->[$k][$ZoneMap->{"dns_zone.name"}];
      ## Add this zone
      my %fields = ('member_type' => 'dns_zone',
		    'member_tid' => $ZoneID,
		    'service' => $ConfigToServerGroup{$Level});
      my ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $DBUSER,
							   \%fields);
      if ($res != 1) {
	print "Error adding Zone (ID $ZoneID) to group $Level!\n";
      }else{
	print "Added Zone (ID $ZoneID) to group $Level.\n";
      }
      
    }
  }
}



