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
# $id$
# $Log: convert-1_1_7-1_1_8.pl,v $
# Revision 1.9  2008/03/27 19:42:45  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.8.14.1  2007/10/11 20:59:48  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.8.12.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.2  2005/08/14 03:34:38  kcmiller
# * Syncing to mainline
#
# Revision 1.8  2005/06/29 22:04:32  fes
# Back out changes that missed the branch and hit HEAD
#
# Revision 1.6  2005/03/21 17:13:55  vitroth
# Added better error reporting.
# Rewrote some portions to be easier to maintain.
# Changed order of conversions so they work.
# Disabled trunkset device population.
# Changed behavior of the vlan status conversion to only do insertions
# that the API will allow.
#
# Revision 1.5  2005/03/18 20:07:21  vitroth
# fixed broken sql statements.
#
# Revision 1.4  2005/03/17 23:35:02  vitroth
# Added vlan table, changelog tables, attribute_spec changes and
# some additional attribute types.
#
# Revision 1.3  2004/06/24 02:05:42  kevinm
# * Credentials/machine type pulled to head
#
# Revision 1.2.4.2  2004/06/21 20:06:40  vitroth
# credentials and registration modes changes fully merged.
# one small bug in credentials (dangling comma) fixed.
# one small bug in vlan code (column with no title on subnet
# info page) fixed.
# conversion script completed
#
# Revision 1.2.4.1  2004/06/21 15:53:47  vitroth
# Merging credentials & machine type permissions branches.
# Inital merge complete, no testing done yet.
# Still need to update convert script and schema.
#
# Revision 1.2.2.2  2004/06/21 15:22:01  kevinm
# * LocalRealm warnings and conversion
#
# Revision 1.2.2.1  2004/06/17 01:08:10  kevinm
# * credential changes
#
# Revision 1.2  2004/03/25 20:14:51  kevinm
# * Merging netdb-layer2-branch2
#
# Revision 1.1.4.1  2004/02/25 19:38:09  kevinm
# * Merigng config/layer2
#
# Revision 1.1.2.1  2003/11/18 07:14:04  ktrivedi
# conversion script. VLAN protections need to be done.
#
#

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

my %Desc = ('vlan-schema' => "This command will create 5 new tables.  Namely
trunk_set, trunkset_building_presence, trunkset_machine_presence,
trunkset_vlan_presence, vlan_subnet_presence and vlan.  It will also
update the protections table.",
	    'vlan-subnet-mapping'  => "This command will create mapping between vlan and subnet.",
	    'vlan-trunkset-add' => "This command will populate trunk_set table from subnet.",
	    'vlan-trunkset-mapping' => "This command will populate trunkset_vlan_presence table from vlan,subnet.",
	    'vlan-building-trunkset-mapping' => "This command will populate trunkset_building_presence table from trunk_set,
building,subnet_pres",
	    'vlan-device-trunkset' => "This command will populate trunkset_machine_presence table from trunk_set,
subnet, machine, such that outlet will have correct machines information.",
	    'vlan-outlet' => "This command will populate outlet_vlan_membership by getting subnets from ,
outlet_subnet_membership and from subnet getting associated vlans.",
	    'vlan-prot'  => "This command will copy subnet-vlan protections.",
	    'credential-change' => 'User/credentials changes.  This command will create the credentials table and
populate it with the data from the users table.',
	    'subnet-registration-modes-schema' => 'This command will create one new table, subnet_registration_modes,
and updated the protections table.  Must be run before the subnet-modes 
conversion routine.',
	    'subnet-registration-modes'  => "This command will convert the existing configuration
of the subnets in the database to the new format, by adding many entries to
the subnet_registration_modes table.",
	    'subnet-schema-delete'  => "This command will remove some columns from the subnets table.
Those columns have been replaced with the new subnet_registration_modes table.
Run the subnet-modes conversion routine first, or you will lose all the
existing information about whether statics & dynamics are allowed on
your subnets.",
	    'changelog-schema' => "This command will create the tables necessary to do the extensive
change logging that NetReg now performs.",
	    'attribute-schema-update' => "This command will modify the attribute schema to allow attributes on more types of records.",
	    'attribute-type-add' => "This command will insert some new attribute types, some of which are for 
device configuration manipulation, and others for web interface customization.",
	   );
my %Run = ( 'vlan-schema-create' => 0,
	    'vlan-subnet-mapping' => 0,
	    'vlan-trunkset-add' => 0,
	    'vlan-trunkset-mapping' => 0,
	    'vlan-building-trunkset-mapping' => 0,
	    'vlan-device-trunkset' => 0,
	    'vlan-outlet' => 0,
	    'vlan-prot' => 0,
	    'credential-change' => 0,
	    'subnet-registration-modes-schema' => 0,
	    'subnet-registration-modes' => 0,
	    'subnet-schema-delete' => 0,
	    'changelog-schema' => 0,
	    'attribute-schema-update' => 0,
	    'attribute-type-add' => 0,
	  );

my @Order = qw(changelog-schema
	       credential-change
	       vlan-schema-create
	       vlan-subnet-mapping
	       vlan-trunkset-add
	       vlan-trunkset-mapping
	       vlan-building-trunkset-mapping
	       vlan-device-trunkset
	       vlan-outlet
	       vlan-prot
	       subnet-registration-modes-schema
	       subnet-registration-modes
	       subnet-schema-delete
	       attribute-schema-update
	       attribute-type-add);
my %Cmd = ('vlan-schema-create' => \&create_vlan_table,
	   'vlan-subnet-mapping' => \&create_vlan_subnet_mapping,
	   'vlan-trunkset-add' => \&create_trunkset,
	   'vlan-trunkset-mapping' => \&create_vlan_trunkset_mapping,
	   'vlan-building-trunkset-mapping' => \&create_building_trunkset_mapping,
	   'vlan-device-trunkset' => \&create_machine_trunkset_mapping,
	   'vlan-outlet' => \&create_outlet_vlan_mapping,
	   'vlan-prot' => \&create_vlans_prot,
	   'credential-change' => \&change_credentials,
	   'subnet-registration-modes-schema' => \&create_srm_table,
	   'subnet-schema-delete' => \&delete_subnet_columns,
	   'changelog-schema' => \&create_changelog_tables,
	   'subnet-registration-modes' => \&convert_subnets,
	   'attribute-schema-update' => \&alter_attribute_schema,
	   'attribute-type-add' => \&add_attribute_types);

my %subnet_pos 	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_fields)};
my %subnet_pres = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::subnet_presence_fields)};
my %vlan_pos 	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::vlan_fields)};
my %ts_pos 	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::trunk_set_fields)};
my %mach_pos	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::machine_fields)};
my %bldg_pos	= %{CMU::Netdb::makemap(\@CMU::Netdb::structure::building_fields)};
my %outlet_sub  = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::outlet_subnet_membership_fields)};

my $debug = 0;
          
my @RunKeys = keys %Run;
if ($#RunKeys == -1) {
  print "There are no conversion operations in this conversion script.\n";
  exit 0;
}
 
if ($#ARGV == -1) {
 USAGE:
  print "Usage: $0 [-all]\n";
  print "\t-all: Do all updates\n";
  foreach my $E (sort keys %Desc) {
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

foreach (@Order) {
  if ($Run{$_}) {
    $Cmd{$_}->();  
  }
}  
 
exit 0;

sub create_vlan_table {
  print "Creating table schema\n\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Creates trunk_set table\n";
  print "  * Creates vlan table\n";
  print "  * Creates trunkset_building_presence table\n";
  print "  * Creates trunkset_machine_presence table\n";
  print "  * Creates trunkset_vlan_presence table\n";
  print "  * Creates vlan_subnet_presence table\n";
  print "  * Creates outlet_vlan_membership table\n";
  print "  * Updates protections table (expand tname)\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $query = <<END_SELECT;
CREATE TABLE trunk_set (
  id int(10) unsigned NOT NULL auto_increment,
  version timestamp(14) NOT NULL,
  name char(255) NOT NULL default '',
  abbreviation char(127) NOT NULL default '',
  description char(255) NOT NULL default '',
  primary_vlan int(10) NOT NULL default '0',
  PRIMARY KEY (id),
  UNIQUE KEY index_name (name)
) TYPE=MyISAM;
END_SELECT
  my $res = $dbh->do($query);
  print "Created trunk_set table. Status: $res\n";

  $query = <<END_SELECT;
CREATE TABLE vlan (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  name char(64) NOT NULL default '',
  abbreviation char(16) NOT NULL default '',
  number int(4) NOT NULL default '0',
  description char(255) NOT NULL default '',
  PRIMARY KEY (id),
  UNIQUE KEY index_name (name)
) TYPE=MyISAM;
END_SELECT
  my $res = $dbh->do($query);
  print "Created vlan table. Status: $res\n";

    $query = <<END_SELECT;
CREATE TABLE trunkset_building_presence (
    id int(10) unsigned NOT NULL auto_increment,
    version timestamp(14) NOT NULL,
    trunk_set int(10) NOT NULL default '0',
    buildings int(10) NOT NULL default '0',
    PRIMARY KEY (id),
    UNIQUE KEY index_nodup (trunk_set,buildings),
    KEY index_trunkset (trunk_set),
    KEY index_building (buildings)
) TYPE=MyISAM;
END_SELECT
    $res = $dbh->do($query);
    print "Create trunkset_building_presence table. Status: $res\n";
    
    $query = <<END_SELECT;
CREATE TABLE trunkset_vlan_presence(
    id int(10) unsigned NOT NULL auto_increment,
    version timestamp(14) NOT NULL,
    trunk_set int(10) NOT NULL default '0',
    vlan int(10) NOT NULL default '0',
    PRIMARY KEY (id),
    UNIQUE KEY index_nodup (trunk_set,vlan),
    KEY index_trunkset (trunk_set),
    KEY index_vlan (vlan)
) TYPE=MyISAM;
END_SELECT
    $res = $dbh->do($query);
    print "Create trunkset_vlan_presence table. Status: $res\n";

    $query = <<END_SELECT;
CREATE TABLE trunkset_machine_presence (
  id int(10) unsigned NOT NULL auto_increment,
  version timestamp(14) NOT NULL,
  device int(10) NOT NULL default '0',
  trunk_set int(10) NOT NULL default '0',
  last_update datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY (id),
  UNIQUE KEY index_nodup (trunk_set,device),
  KEY index_trunkset (trunk_set),
  KEY index_vlan (device)
) TYPE=MyISAM;
END_SELECT
    $res = $dbh->do($query);
    print "Create trunkset_machine_presence table. Status: $res\n";

    $query = <<END_SELECT;
CREATE TABLE vlan_subnet_presence(
  id int(10) unsigned NOT NULL auto_increment,
  version timestamp(14) NOT NULL,
  subnet int(10) NOT NULL default '0',
  subnet_share int(10) NOT NULL default '0',
  vlan int(10) NOT NULL default '0',
  PRIMARY KEY (id),
  UNIQUE KEY index_nodup (subnet,vlan),
  KEY index_trunkset (subnet),
  KEY index_vlan (vlan)
) TYPE=MyISAM;
END_SELECT
    $res = $dbh->do($query);
    print "Create vlan_subnet_presence table. Status: $res\n";

    $query = <<END_SELECT;
CREATE TABLE outlet_vlan_membership (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  outlet int(10) unsigned NOT NULL default '0',
  vlan int(10) unsigned NOT NULL default '0',
  type enum('primary','voice','other') NOT NULL default 'primary',
  trunk_type enum('802.1Q','ISL','none') NOT NULL default '802.1Q',
  status enum('request','active','delete','error','errordelete') NOT NULL default 'request',
  PRIMARY KEY  (id),
  UNIQUE KEY index_membership (outlet,vlan),
  KEY index_type (outlet,vlan,type,trunk_type)
) TYPE=MyISAM;
END_SELECT
    $res = $dbh->do($query);
    print "Create outlet_vlan_membership table. Status: $res\n";

    &alter_protections();

    print "Adding protections for trunksetXXX , vlan_subnet_presence\n";
    my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet',0);
    foreach my $table ("trunk_set", "trunkset_building_presence", "trunkset_vlan_presence",
			"trunkset_machine_presence", "vlan_subnet_presence") { 
	foreach  my $protection (@{$protections}) {
	    my ($type, $name, $rights, $level) = @{$protection};
	    if( $type eq 'user') {
		CMU::Netdb::add_user_to_protections($dbh,'netreg', $name, $table, 0, $rights, $level);
	    } elsif ($type eq 'group') {
		CMU::Netdb::add_group_to_protections($dbh,'netreg', $name, $table, 0, $rights, $level);
	    }
	    print " Added for $table:	$type/$name/$rights/$level \n";
	}
    }

    print "Adding protections for outlet_vlan_membership\n";
    $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'outlet_subnet_membership', 0);
    foreach my $protection (@{$protections}) {
	my ($type, $name, $rights, $level) = @{$protection};
	if( $type eq 'user') {
	    CMU::Netdb::add_user_to_protections($dbh,'netreg', $name, 'outlet_vlan_membership', 0, $rights, $level);
	} elsif ($type eq 'group') {
	    CMU::Netdb::add_group_to_protections($dbh,'netreg', $name,'outlet_vlan_membership' , 0, $rights, $level);
	}
	print "Adding for outlet_vlan_membership:  $type/$name/$rights/$level \n";
    }
}

sub create_vlan_subnet_mapping {
    print "Adding vlan information from subnet table to vlan_subnet_presence\n";
    print "This populates vlan_subnet_presence table. Each entry will be created\n";
    print "based on reference from subnet{vlan} table\n\n";
    
    print "Proceed [default:no] ";
    my $ans = <STDIN>;
    return unless ($ans =~ /y/i);
   
    my $sub_ref  = CMU::Netdb::list_subnets($dbh, 'netreg', "subnet.vlan != '' ORDER BY subnet.vlan");
    if(!ref $sub_ref) {
	print "create_vlan_subnet_mapping::Error retreving subnets information from db\n";
	return;
    }
    
    my $vlan_ref = CMU::Netdb::list_vlans($dbh, 'netreg', "1");
    my (%vlans);
    map { $vlans{$_->[$vlan_pos{'vlan.number'}]} = $_->[$vlan_pos{'vlan.id'}] } @{$vlan_ref};

    shift(@{$sub_ref});
    foreach my $subnet (@{$sub_ref}) {
	my $sid   = $subnet->[$subnet_pos{'subnet.id'}];
	my $sname = $subnet->[$subnet_pos{'subnet.name'}];
	my $sabbr = $subnet->[$subnet_pos{'subnet.abbreviation'}];
	my $ssid  = $subnet->[$subnet_pos{'subnet.share'}];
	my $vnum  = $subnet->[$subnet_pos{'subnet.vlan'}];
	if ($vlans{$vnum} eq '') {
	    my %vlanfields = ( 'name' => $sname,
			       'abbreviation' => $sabbr,
			       'number' => $vnum);
	    my ($res, $errfields) = CMU::Netdb::add_vlan($dbh, 'netreg',\%vlanfields);
	    if ($res <= 0) {
		print "***Error adding vlan ($sname/$vnum): $res (".join(' ',@$errfields).")\n";
		next;
	    }
	    my %warns = %$errfields;
	    $vlans{$vnum} = $warns{insertID};
	}
	
	my %fields;
	$fields{subnet} = $sid;
	$fields{vlan} = $vlans{$vnum};
	$fields{subnet_share} = $ssid;
	my ($res, $ref) = CMU::Netdb::add_subnet_presence($dbh,'netreg',\%fields);
	if ($res != 1) {
	    print "***Error adding <subnet, vlan,subnet_share> = <$sid, $vlans{$vnum}, $ssid>: $res (".join(' ',@$ref).")\n";
	    return;
	} else {
	    print "Successfully added to vlan_subnet_presence <subnet, vlan,subnet_share> = <$sid, $vlans{$vnum}, $ssid>\n ";
	}
    }
}

## create_trunkset
## This function create trunk_set from existing subnet/subnet_share
## information. 
## 1) First iteration is, all subnet without share.
## 2) Second iteration is, list all subnet_share and then subnet with share
##    and create new name for trunk_set from that.
sub create_trunkset {
    print "Adding TrunkSet from Subnet | Subnet Share\n";
    print "This populates trunk_set table. Trunkset will be\n";
    print "created for each subnet share or subnet without share\n\n";

    print "Proceed [default:no] ";
    my $ans = <STDIN>;
    return unless ($ans =~ /y/i);

    my $sub_ref = CMU::Netdb::list_subnets($dbh, 'netreg', "");
    if(!ref $sub_ref) {
	print "create_trunkset::Error retrieving subnets information from db\n";
	return;
    }
    shift(@$sub_ref);
    
    my $subshare_ref = CMU::Netdb::list_subnet_shares($dbh,'netreg',"");
    shift(@$subshare_ref);

    # Iterating subnet without share, share = 0
    foreach my $ind_sub (@$sub_ref) {
	my $sid		= $ind_sub->[$subnet_pos{'subnet.id'}];
	my $share_id  	= $ind_sub->[$subnet_pos{'subnet.share'}];
	my $sname	= $ind_sub->[$subnet_pos{'subnet.name'}];
	my $sabbr	= $ind_sub->[$subnet_pos{'subnet.abbreviation'}];

	if ($share_id ==  0) {
	    my %fields;
	    $fields{name} = $sname;
	    $fields{abbreviation} = $sabbr;
	    my ($res,$warns) = CMU::Netdb::add_trunkset($dbh,'netreg', \%fields);
	    if ($res > 0) {
		print "$sname got added with id:$warns->{insertID}\n";
		if (0) {
		    # protections for subnet to trunk_set
		    my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet', $sid);
		    my $rowid = $warns->{insertID};
		    foreach my $protection (@{$protections}) {
			my ($type, $name, $rights, $level) = @{$protection};
			if ($type eq 'user') {
			    CMU::Netdb::add_user_to_protections($dbh, 'netreg', $name, 'trunk_set', $rowid, $rights, $level);
			} elsif ($type eq 'group') {
			    CMU::Netdb::add_group_to_protections($dbh, 'netreg', $name, 'trunk_set', $rowid, $rights, $level);
			}
		    }
		}
	    } else {
		print "***Error  $sname could NOT be added: $res (".join(' ',@$warns).")";
		return;
	    }
	} 
    }

    # Iterating subnet_share
    foreach my $ind_subshare (@$subshare_ref) {
	
	my $ssid = $ind_subshare->[0];
	my $ssname = $ind_subshare->[1];

	my $subnetss = "";
	my $sid = "";
	# and then subnet with share , share != 0
	foreach my $ind_sub (@$sub_ref) {
	    my $sub_ssid = $ind_sub->[$subnet_pos{'subnet.share'}];
	    if ($ssid eq $sub_ssid) {
		$subnetss .= $ind_sub->[$subnet_pos{'subnet.name'}]."::" ;
		$sid = $ind_sub->[$subnet_pos{'subnet.id'}];
	    }
	}

	my @narr = split(/::/,$subnetss);
	my $append = " ( + QuickReg)" if ($narr[1] =~ /quick/i);
	my $ts_name = $narr[0].$append;

	my %fields;
	$fields{name} = $ts_name;
	$fields{abbreviation} = $narr[0];
	my ($res,$warns) = CMU::Netdb::add_trunkset($dbh,'netreg', \%fields);
	if ($res > 0) {
	    print "$ts_name got added with id:$warns->{insertID}\n";
	    if (0) {
		# protections for subnet to trunk_set
		my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet', $sid);
		my $rowid = $warns->{insertID};
		foreach my $protection (@{$protections}) {
		    my ($type, $name, $rights, $level) = @{$protection};
		    if ($type eq 'user') {
			CMU::Netdb::add_user_to_protections($dbh, 'netreg', $name, 'trunk_set', $rowid, $rights, $level);
		    } elsif ($type eq 'group') {
			CMU::Netdb::add_group_to_protections($dbh, 'netreg', $name, 'trunk_set', $rowid, $rights, $level);
		    }
		}
	    }

	} else {
	    print "***Error TrunkSet: $ts_name could NOT be added: $res (".join(' ',@$warns).")";
	    my %nerrors;
	    map {$nerrors{$_} = 1} @$warns;
	}

	$subnetss = "";
    }
}

## create_vlan_trunkset_mapping
## This function populates trunkset_vlan_presence, by getting vlan number
## from subnet table. (Exist), and mapping that vlan number to vlan.name
## As we already created trunk_set above from subnet table, we now have
## relationship between subnet.name to trunk_set.name,
## Logic is dirty, as subnet.name to trunk_set.name is not a one to one.
sub create_vlan_trunkset_mapping {
    print "Adding VLAN in trunkset_vlan_presence from VLAN<-->TrunkSet\n";
    print "This function populates trunkset_vlan_presence. Each entry \n";
    print "will be created for each vlan--trunk_set tuple\n\n";

    print "Proceed [default:no] ";
    my $ans = <STDIN>;
    return unless ($ans =~ /y/i);
    
    # trunkset info
    my $ts_ref  = CMU::Netdb::list_trunkset($dbh, 'netreg', "1");
    if (!ref $ts_ref) {
	print "***create_vlan_trunkset_mapping::Error retriving trunkset information from db\n";
	return;
    }
    my %ts_name_id;
    map { $ts_name_id{$_->[$ts_pos{'trunk_set.name'}]} = $_->[$ts_pos{'trunk_set.id'}]} @{$ts_ref};

    # subnet.vlan info
    my $sub_ref = CMU::Netdb::list_subnets($dbh, 'netreg', "vlan != 0");
    if (!ref $sub_ref) {
	print "***create_vlan_trunkset_mapping::Error retriving subnets information from db\n";
	return;
    }
    
    my %subnet_vlan_name;
    map { $subnet_vlan_name{$_->[$subnet_pos{'subnet.name'}]} = $_->[$subnet_pos{'subnet.vlan'}] } @{$sub_ref};
    
    foreach my $sub_name (keys %subnet_vlan_name) {
	my $ts_id;
	foreach my $ts_key (keys %ts_name_id){
	    my @subname_p 	= split(/\(/,$sub_name);
	    my @ts_p		= split(/\(/,$ts_key);
	    $ts_p[1] =~ s/\)//;
	    $subname_p[1] =~ s/\)//;

	    if ($ts_key =~ /^$subname_p[0]/){
		$ts_id = $ts_name_id{$ts_key};
	    }
	}

	my $vlan_num = $subnet_vlan_name{$sub_name};
	my $vlan_ref = CMU::Netdb::list_vlans_ref($dbh, 'netreg', "vlan.number = \"$vlan_num\"",'vlan.number');
	print "***create_vlan_trunkset_mapping::Could not find entry for $vlan_num" if (!ref $vlan_ref);
	next if (!ref $vlan_ref);
	my %vlan_h = %$vlan_ref;

	if ($debug == 0) {
	    next if ($ts_id eq "");
	}
	
	## Iterating vlans 
	foreach my $vlan_id (keys %vlan_h) {
	    my %fields;
	    $fields{trunk_set} = $ts_id;
	    $fields{vlan} = $vlan_id;
	    $fields{type} = 'vlan';

	    if ($debug) {
		print "vlan: $vlan_id	tsid:$ts_id	subnet:$sub_name\n";
	    } else {
		my ($res, $ref) = CMU::Netdb::add_trunkset_presence($dbh, 'netreg',\%fields);
		if ($res != 1) {
		    print "***Error creating <vlan,trunk_set> = <$vlan_id, $ts_id>: $res (".join(' ',@$ref).")\n";
		    return;
		} else {
		    print "<vlan,trunk_set> = <$vlan_id, $ts_id> got created\n";
		}
	    }
	}
    }
}

## create_building_trunkset_mapping
## Populating trunkset_building_presence table. After filling data in trunk_set from
## subnet, we take subnet <--> building association. and add that building to trunk_set
## based on made up name of trunk_set.
sub create_building_trunkset_mapping {
    print "Adding Building in trunkset_building_presence from Subnet_presence<-->TrunkSet\n";
    print "This function populates trunkset_building_presence. Each entry\n";
    print "will be created for each subnet_presence{building}<-->subnet{trunkset}\n\n";

    print "Proceed [default:no] ";
    my $ans = <STDIN>;
    return unless ($ans =~ /y/i);
    
    my $ts_ref  = CMU::Netdb::list_trunkset($dbh, 'netreg', "1");
    if (!ref $ts_ref) {
	print "***create_vlan_trunkset_mapping::Error retriving trunkset information from db\n";
	return;
    }
    my %ts_name_id;
    map { $ts_name_id{$_->[$ts_pos{'trunk_set.name'}]} = $_->[$ts_pos{'trunk_set.id'}]} @{$ts_ref};

    my $sub_pres = CMU::Netdb::list_subnet_building_presences($dbh, 'netreg',"");
    if (!ref $sub_pres) {
	print "***create_building_trunkset_mapping::Error retriving subnet_presence information\n";
	return;
    }
    shift(@$sub_pres);

    foreach my $ind_sub (@$sub_pres) {
	## subnet info
	my $sub_id 	= $ind_sub->[$subnet_pres{'subnet_presence.subnet'}];
	my $sub_ref 	= CMU::Netdb::list_subnets_ref($dbh, 'netreg', "subnet.id = \"$sub_id\"", 'subnet.name');
	my %sub_h 	= %$sub_ref;
	my $sub_name 	= $sub_h{$sub_id};
	    
	my @subname_p 	= split(/\(/,$sub_name);
	
	## building info
	my $bldg_num = $ind_sub->[$subnet_pres{'subnet_presence.building'}];
	my $bldg_ref = CMU::Netdb::list_buildings($dbh, 'netreg', "building.building = \"$bldg_num\"");
	my $ts_id;

	## Iterating trunkset
	foreach my $ts_key (keys %ts_name_id){
	    my @subname_p 	= split(/\(/,$sub_name);
	    my @ts_p		= split(/\(/,$ts_key);
	    $ts_p[1] =~ s/\)//;
	    $subname_p[1] =~ s/\)//;
	    
	    if ($ts_key =~ /^$subname_p[0]/ && 
		($ts_p[1] eq "" || $subname_p[1] eq "" || $ts_p[1] =~ /$subname_p[1]/) ) {
		$ts_id   = $ts_name_id{$ts_key};
	    }
	}

	if ($debug) {
	    print "<subnet_id:$sub_id  bldg_num:$bldg_num	".
		"bldg_id:$bldg_ref->[1]->[$bldg_pos{'building.id'}]  tsid:$ts_id  subnet:$sub_name\n" ;
	} else {
	    my %fields;
	    $fields{trunk_set} = $ts_id;
	    $fields{buildings} = $bldg_ref->[1]->[$bldg_pos{'building.id'}];
	    $fields{type} = 'building';

	    my ($res, $ref) = CMU::Netdb::add_trunkset_presence($dbh, 'netreg', \%fields);
	    if ($res != 1) {
		print "***Error creating <buildling, trunk_set> = <$bldg_ref->[1]->[$bldg_pos{'building.id'}], $ts_id>: $res (".join(' ',@$ref).")\n";
		return;
	    } else {
		print "<building,trunk_set> = <$bldg_ref->[1]->[$bldg_pos{'building.id'}], $ts_id>  got created\n";
	    }
	}
    }
}


## create_machine_trunkset_mapping
## Populating trunkset_machine_presence table, by getting device info, Each device has subnet
## associates with it, so get subnet from there and then fill out appropriate trunk_set info.
sub create_machine_trunkset_mapping {
    print "Adding Machine/Device in trunkset_machine_presence. All the devices with\n";
    print "sw.cmu.net, sw.net.cmu.edu, sw.cmu.local,net.cmu.local, gw.cmu.net, bh.net.cmu.edu\n";
    print "This function populates trunkset_machine_presence by taking each above type\n";
    print "devices from machine table, decideing subnet for those machine and matching subnet\n";
    print "to trunk_set , will generate <trunkset_id, machine_id> tuple\n\n";
    print "\n   *** NOTE ***\nSince this conversion routine is CMU Specific, it is DISABLED.\n";
    print "If you want to enable it, edit the conversion script to provide a useful list of\n";
    print "hostname matching clauses and remove the line marked 'REMOVE ME'\n";
    print "FIXME: A future version of this routine should prompt for a list of hostname patterns.\n";
    
    sleep 5;
    
    return; # REMOVE ME TO ENABLE THIS CONVERSION ROUTINE
    print "Proceed [default:no] ";
    my $ans = <STDIN>;
    return unless ($ans =~ /y/i);

    my @hostnamelist = qw(%.sw.cmu.net
			  %.hb.cmu.net
			  %.sw.net.cmu.edu
			  %.hb.net.cmu.edu
			  %.sw.cmu.local
			  %.gw.cmu.net
			  %.gw.cmu.local
			 );
    my $where = 'machine.host_name like "'.join('" OR machine.host_name like "', @hostnamelist).'"';
    # device list
    my $sref = CMU::Netdb::list_machines($dbh, 'netreg', $where);

    shift (@{$sref});
    my %dev_id_name;
    map { $dev_id_name{$_->[$mach_pos{'machine.id'}]} = $_->[$mach_pos{'machine.ip_address_subnet'}]} @{$sref};

    # trunkset list 
    my $ts_ref  = CMU::Netdb::list_trunkset($dbh, 'netreg', "1");
    if (!ref $ts_ref) {
	print "***create_machine_trunkset_mapping::Error retriving trunkset information from db\n";
	return;
    }
    my %ts_name_id;
    map { $ts_name_id{$_->[$ts_pos{'trunk_set.name'}]} = $_->[$ts_pos{'trunk_set.id'}]} @{$ts_ref};

    # Iterating device list
    foreach my $did (keys %dev_id_name) {
	my $sbnref = CMU::Netdb::list_subnets_ref($dbh, 'netreg', "subnet.id = $dev_id_name{$did}",
						    'subnet.name');
	my $sub_name = $$sbnref{$dev_id_name{$did}};
	my $ts_id;
	foreach my $ts_key (keys %ts_name_id){
	    my @subname_p 	= split(/\(/,$sub_name);
	    my @ts_p		= split(/\(/,$ts_key);
	    $ts_p[1] =~ s/\)//;
	    $subname_p[1] =~ s/\)//;
	    
	    if ($ts_key =~ /^$subname_p[0]/ && 
		($ts_p[1] eq "" || $subname_p[1] eq "" || $ts_p[1] =~ /$subname_p[1]/) ) {
		$ts_id   = $ts_name_id{$ts_key};
	    } elsif ($sub_name eq "Wireless - Private") {
		$ts_id 	= $ts_name_id{"Wireless Network ( + private)"};
	    } elsif ($sub_name eq "311 South Craig Quickreg") {
		$ts_id 	= $ts_name_id{"311 S. Craig/4609 Winthrop ( + QuickReg)"};
	    }
	}

	if ($debug) {
	    print "ts_id:$ts_id	device:$did  subnet:$sub_name\n" ;
	} else {
	    #my $tsref = CMU::Netdb::list_trunkset_ref($dbh, 'netreg', "trunk_set.name = \"$sName\"", 'trunk_set.id');
	    #my @ts_arr = map { $tsref->{$_} } %$tsref;
	    my %fields = ('type' => 'machine',
			  'trunk_set' => $ts_id,
			  'device' => $did);
	    my ($res, $ref) = CMU::Netdb::add_trunkset_presence($dbh, 'netreg',\%fields);
	    if ($res != 1) {
		print "***Error creating <machine, trunk_set> = <$did, $ts_id: $res (".join(' ',@$ref).")\n";
	    } else {
		print "<machine,trunk_set> = <$did, $ts_id> got created\n";
	    }
	}
    }
}

## create_outlet_vlan_mapping
## Nothing much here.
sub create_outlet_vlan_mapping {
    print "Adding outlet-->vlan association in outlet_vlan_membership.All the associated subnets with\n";
    print "with some outlet, will be retrived from outlet_subnet_membership and then number of vlans\n";
    print "associated with each subnet will be added for that outlet.\n\n";
    print "***NOTE:: Need to comment out status check in add_outlet_vlan_membership, so that outlet with\n";
    print "status other then \'active\' and \'request\' will be added ***\n\n";

    print "Proceed [default:no] ";
    my $ans = <STDIN>;
    return unless ($ans =~ /y/i);

    my $outlet_ref = CMU::Netdb::list_outlet_subnet_memberships($dbh, 'netreg',"");
    shift(@$outlet_ref);

    foreach my $ind_outlet (@$outlet_ref) {
	my $outlet_id 	= $ind_outlet->[$outlet_sub{'outlet_subnet_membership.outlet'}];
	my $subnet_id 	= $ind_outlet->[$outlet_sub{'outlet_subnet_membership.subnet'}];
	my $type   	= $ind_outlet->[$outlet_sub{'outlet_subnet_membership.type'}];
	my $trunk_type	= $ind_outlet->[$outlet_sub{'outlet_subnet_membership.trunk_type'}];
	my $status	= $ind_outlet->[$outlet_sub{'outlet_subnet_membership.status'}];

	my $subvlan_ref = CMU::Netdb::get_subnet_vlan_presence($dbh, 'netreg', "vlan_subnet_presence.subnet = \'$subnet_id\'",
								'vlan_subnet_presence.vlan');
	my %subvlan_h   = %$subvlan_ref;
	my $vlan_id = $subvlan_h{$subnet_id};

	my %fields = ( 'outlet' => $outlet_id,
		       'vlan' => $vlan_id,
		       'type' => $type,
		       'trunk_type' => $trunk_type,
		       'status' => $status);
	$fields{status} = 'request' unless ($fields{status} eq 'active');
	
	if ($debug) {
	    print "outlet:$outlet_id, vlan:$vlan_id, subnet_id:$subnet_id  type=$type, ".
		"trunktype:$trunk_type status:$status\n";
	} else {
	    next if ($vlan_id eq '');
	    my ($res ,$ref) = CMU::Netdb::add_outlet_vlan_membership($dbh,'netreg',\%fields);
	    if ($res != 1) {
		print "***Error adding <outlet_id,vlan_id> = <$outlet_id, $vlan_id>: $res (".join(' ',@$ref).")\n";
		return;
	    } else {
		print "<outlet_id, vlan_id> = <$outlet_id, $vlan_id> got created\n";
	    }
	}
    }
}

sub create_vlans_prot {
  print "Adding VLANS from data in subnet table.\n";
  print "This populates the VLAN table based on information about VLANS\n";
  print "currently present in your VLAN table.\n";

  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet', 0);
  foreach my $protection (@{$protections}) {
    my ($type, $name, $rights, $level) = @{$protection};
    print "  $type/$name/$rights/$level\n";
    if ($type eq 'user') {
        CMU::Netdb::add_user_to_protections($dbh, 'netreg', $name, 'vlan', 0, $rights, $level);
    } elsif ($type eq 'group') {
        CMU::Netdb::add_group_to_protections($dbh, 'netreg', $name, 'vlan', 0, $rights, $level);
    }
  }


  my $subnets = CMU::Netdb::list_subnets($dbh, 'netreg', "subnet.vlan != '' ORDER BY subnet.vlan");
  my %map = %{ CMU::Netdb::makemap( shift(@{$subnets}) ) };

  foreach my $subnet (@{$subnets}) {
    my $sid  = $subnet->[$map{"subnet.id"}];
    my $name = $subnet->[$map{"subnet.name"}];
    my $abbr = $subnet->[$map{"subnet.abbreviation"}];
    my $vlan = $subnet->[$map{"subnet.vlan"}];

    my $vlans = CMU::Netdb::list_vlans($dbh, 'netreg', "vlan.number = '$vlan'");

    my $rowid;
    if ($#$vlans < 1) {
	print "***Error should not come here... $name \n";
    } else {
	my %vlanmap = %{ CMU::Netdb::makemap( shift(@{$vlans}) ) };
	$rowid = $vlans->[0]->[$vlanmap{"vlan.id"}];
    }

    next if ($rowid eq '');
    my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet', $sid);
    foreach my $protection (@{$protections}) {
      my ($type, $name, $rights, $level) = @{$protection};
      print "rowid($rowid) --> $vlan  $type/$name/$rights/$level\n";
      if ($type eq 'user') {
	CMU::Netdb::add_user_to_protections($dbh, 'netreg', $name, 'vlan', $rowid, $rights, $level);
      } elsif ($type eq 'group') {
	CMU::Netdb::add_group_to_protections($dbh, 'netreg', $name, 'vlan', $rowid, $rights, $level);
      }
    }
  }
}

sub change_credentials {
  print "Converting users to credential table.\n";
  print "*** Note: You need to update netreg-webint.conf if you are using \n".
	"the LocalRealm variable. Specifically, remove the LocalRealm setting.\n";
  print "\n";

  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $Query = "CREATE TABLE credentials (
version		TIMESTAMP(14),
id		INT	UNSIGNED NOT NULL AUTO_INCREMENT,
authid		VARCHAR(255)	NOT NULL,
user		INT	UNSIGNED NOT NULL,
description     VARCHAR(255)    NOT NULL,
PRIMARY KEY	index_id	(id),
KEY		index_user	(user),
UNIQUE          index_authid    (authid),
FOREIGN KEY	(user) 		REFERENCES	users(id) ON UPDATE CASCADE  ON DELETE RESTRICT
) Type=MyISAM;";
  $dbh->do($Query);

  $Query = "INSERT INTO credentials (authid, user, description) ".
"SELECT U.name, U.id, U.description FROM users AS U;";
  $dbh->do($Query);

  $dbh->do("ALTER TABLE users DROP INDEX `index_name`");
  $dbh->do("ALTER TABLE users DROP INDEX `name`");
  $dbh->do("ALTER TABLE users DROP INDEX `id`");

  $dbh->do("ALTER TABLE users DROP COLUMN name");
  $dbh->do("ALTER TABLE users DROP COLUMN description");

  &alter_protections;
  $dbh->do("INSERT INTO protections (identity, tname, tid, rights, rlevel) ".
	   "VALUES (0, 'credentials', 0, 'READ', 1), ".
	   "(-1, 'credentials', 0, 'READ,WRITE,ADD', 9)");

  print "If you used LocalRealm, enter the realm and the users will be \n".
        "converted to [userid]@[LocalRealm] syntax.\n\n";
  print "LocalRealm: ";
  my $realm = <STDIN>;
  chomp($realm);
 
  if ($realm ne '') {
    # Andrew specific
    $dbh->do("UPDATE credentials SET authid = CONCAT(authid, '\@$realm')");
    $dbh->do("UPDATE credentials SET authid = 'netreg' ".
	     "WHERE authid = 'netreg\@$realm'");
  }

}


sub create_srm_table {
  print "Creating subnet_registration_modes table\n\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Creates subnet_registration_modes table\n";
  print "  * Updates protections table (expand tname)\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $query = <<END_SELECT;
CREATE TABLE subnet_registration_modes (
  id int(10) unsigned NOT NULL auto_increment,
  version timestamp(14) NOT NULL,
  subnet int(10) NOT NULL default '0',
  mode enum('static','dynamic','reserved','broadcast','pool','base','secondary') NOT NULL,
  mac_address enum('required','none') NOT NULL default 'required',
  quota int(10) unsigned,
  PRIMARY KEY (id),
  UNIQUE KEY (subnet, mode, mac_address, quota),
  KEY index_subnet_mode (subnet,mode)
) TYPE=MyISAM;
END_SELECT
    my $res = $dbh->do($query);
    print "Created subnet_registration_modes table. Status: $res\n";

  &alter_protections;
  print "Adding protections for subnet_registration_modes.\n";
  my $protections = CMU::Netdb::list_protections($dbh, 'netreg', 'subnet', 0);
  foreach  my $protection (@{$protections}) {
    my ($type, $name, $rights, $level) = @{$protection};
    if( $type eq 'user') {
      CMU::Netdb::add_user_to_protections($dbh,'netreg', $name, 
					  'subnet_registration_modes', 
					  0, $rights, $level);
    } elsif ($type eq 'group') {
      CMU::Netdb::add_group_to_protections($dbh,'netreg', $name, 
					   'subnet_registration_modes', 
					   0, $rights, $level);
    }
    print " Added for subnet_registration_modes:	$type/$name/$rights/$level \n";
  }
}


sub convert_subnets {
    print "Adding subnet registration modes entries:\n";
    print "This populates the subnet_registration_modes table with entries\n";
    print "to match your existing configuration.\n";

    print "Proceed [default:no] ";
    my $ans = <STDIN>;
    return unless ($ans =~ /y/i);
   
    my $sub_ref  = $dbh->selectall_arrayref("SELECT subnet.id, subnet.name, subnet.flags, subnet.quota_dynamic, subnet.quota_static, subnet.default_mode, subnet.dynamic FROM subnet ORDER BY subnet.id");
    if(!ref $sub_ref) {
      print "convert_subnets::Error retreving subnets information from db\n";
      return;
    }
    

    foreach my $subnet (@{$sub_ref}) {
      my $sid   = $subnet->[0];
      my $sname   = $subnet->[1];
      my $sflags = $subnet->[2];
      my $squota_dynamic  = $subnet->[3];
      my $squota_static  = $subnet->[4];
      my $sdefmode = $subnet->[5];
      my $sdyn = $subnet->[6];

      my %modes_to_add = ('static-required' => ['admin_default_add'],
			  'reserved-required' => ['admin_default_add'],
			  'reserved-none' => ['admin_default_add'],
			  'broadcast-none' => ['admin_default_add'],
			  'base-none' => ['admin_default_add']);
      my %users_to_add;
      my %groups_to_add;
      my %added;

      print "\nProcessing subnet $sid ($sname).\n\n";

      my $protections = 
	CMU::Netdb::list_protections($dbh, 'netreg', 
				     'subnet',  $sid, 
				     "FIND_IN_SET('ADD', P.rights)");
      if (!ref $protections) {
	die "Unable to list protections on subnet $sid\n";
      }
	
      foreach my $prot (@$protections) {
	if ($prot->[0] eq 'group' && $prot->[1] eq 'netreg:admins') {
	  # Do nothing for statics, its added elsewhere already.
	  # For dynamic, just make sure the entry will be created
	  if ($sdyn ne 'disallow') {
	    if ($squota_dynamic == 0 || $prot->[3] >= 9) {
	      push @{$modes_to_add{'dynamic-required'}},  'admin_default_add';
	    } else {
	      push @{$modes_to_add{"dynamic-required-$squota_dynamic"}} ,  'admin_default_add';
	    }
	  }

	} elsif ($prot->[0] eq 'group' && $prot->[1] eq 'system:anyuser') {
	  if (!(($sflags =~ /no_static/) && ($prot->[3] < 9))) {
	    if ($squota_static == 0) {
	      push @{$modes_to_add{'static-required'}}, 'all_users_add';
	    } else {
	      push @{$modes_to_add{"static-required-$squota_static"}} , 'all_users_add';
	    }
	  }
	  if ($sdyn ne 'disallow') {
	    if ($squota_dynamic == 0) {
	      push @{$modes_to_add{'dynamic-required'}}, 'all_users_add';
	    } else {
	      push @{$modes_to_add{"dynamic-required-$squota_dynamic"}} , 'all_users_add';
	    }
	  }
	} elsif ($prot->[0] eq 'group') {
	  if (!(($sflags =~ /no_static/) && ($prot->[3] < 9))) {
	    if ($squota_static == 0 || $prot->[3] >= 9) {
	      push @{$groups_to_add{"static-required"}}, [$prot->[1],$prot->[3]];
	    } else {
	      push @{$groups_to_add{"static-required-$squota_static"}} ,  [$prot->[1],$prot->[3]];
	    }
	  }
	  if ($sdyn ne 'disallow') {
	    if ($squota_dynamic == 0 || $prot->[3] >= 9) {
	      push @{$groups_to_add{'dynamic-required'}},  [$prot->[1],$prot->[3]];
	    } else {
	      push @{$groups_to_add{"dynamic-required-$squota_dynamic"}} ,  [$prot->[1],$prot->[3]];
	    }
	  }
	} else {
	  if (!(($sflags =~ /no_static/) && ($prot->[3] < 9))) {
	    if ($squota_static == 0 || $prot->[3] >= 9) {
	      push @{$users_to_add{"static-required"}},  [$prot->[1],$prot->[3]];
	    } else {
	      push @{$users_to_add{"static-required-$squota_static"}} ,  [$prot->[1],$prot->[3]];
	    }
	  }
	  if ($sdyn ne 'disallow') {
	    if ($squota_dynamic == 0 || $prot->[3] >= 9) {
	      push @{$users_to_add{'dynamic-required'}}, [$prot->[1],$prot->[3]];
	    } else {
	      push @{$users_to_add{"dynamic-required-$squota_dynamic"}} ,  [$prot->[1],$prot->[3]];
	    }
	  }
	}
      }


      foreach my $key (keys %modes_to_add) {
	my ($mode,$mac,$quota) = split /-/, $key, 3;

	print "Creating subnet_registration_modes entry: ($sid, $mode, $mac, $quota) ($key)\n";
	print "Using protections profiles: ".join(', ',@{$modes_to_add{$key}})."\n";
	my ($res, $reason) = 
	  CMU::Netdb::add_subnet_registration_mode($dbh, 'netreg',
						   {'subnet' => $sid,
						    'mode' => $mode,
						    'mac_address' => $mac,
						    'quota' => $quota},
						   $modes_to_add{$key});

	if ($res <= 0) {
	  die "Error adding subnet registration mode: $sid/$mode/$mac/$quota: $res (".join(' ',@$reason).")";
	}

	$added{$key} = $reason->{insertID};
      }


#      print Data::Dumper->Dump([\%groups_to_add], ['groups_to_add']);
      foreach my $key (keys %groups_to_add) {
	if (!exists $added{$key}) {
	  my ($mode,$mac,$quota) = split /-/, $key, 3;

	  print "Creating subnet_registration_modes entry: ($sid, $mode, $mac, $quota)\n";
	  my ($res, $reason) = 
	    CMU::Netdb::add_subnet_registration_mode($dbh, 'netreg',
						     {'subnet' => $sid,
						      'mode' => $mode,
						      'mac_address' => $mac,
						      'quota' => $quota});
	  die "Error adding subnet registration mode: $sid/$mode/$mac/$quota: $res (".join(' ',@$reason).")" if ($res <= 0);
	
	  $added{$key} = $reason->{insertID};
	}

	foreach my $entry (@{$groups_to_add{$key}}) {
	  my $group = $entry->[0];
	  my $level = $entry->[1];
	  print "Adding group $group/ADD/$level to entry $added{$key} ($sname-$key)\n";
	  my ($res, $reason) = CMU::Netdb::add_group_to_protections
	    ($dbh, 'netreg', $group, 'subnet_registration_modes', $added{$key},
	     'ADD', $level);
	  die "Error adding protection to subnet_registration_mode: $res (".join(' ',@$reason).")\n" if ($res <= 0);
	}
      }

#      print Data::Dumper->Dump([\%users_to_add], ['groups_to_add']);
      foreach my $key (keys %users_to_add) {
	if (!exists $added{$key}) {
	  my ($mode,$mac,$quota) = split /-/, $key, 3;

	  print "Creating subnet_registration_modes entry: ($sid, $mode, $mac, $quota)\n";
	  my ($res, $reason) = 
	    CMU::Netdb::add_subnet_registration_mode($dbh, 'netreg',
						     {'subnet' => $sid,
						      'mode' => $mode,
						      'mac_address' => $mac,
						      'quota' => $quota});
	  die "Error adding subnet registration mode: $sid/$mode/$mac/$quota: $res (".join(' ',@$reason).")" if ($res <= 0);
	
	  $added{$key} = $reason->{insertID};
	}

	foreach my $entry (@{$users_to_add{$key}}) {
	  my $user = $entry->[0];
	  my $level = $entry->[1];
	  print "Adding user $user/ADD/$level to entry $added{$key} ($sname-$key)\n";
	  my ($res, $reason) = CMU::Netdb::add_user_to_protections
	    ($dbh, 'netreg', $user, 'subnet_registration_modes', $added{$key},
	     'ADD', $level);
	  die "Error adding protection to subnet_registration_mode: $res (".join(' ',@$reason).")\n" if ($res <= 0);
	}
      }
    }
}

sub delete_subnet_columns {
  print "Removing obsolete columsn from subnet table\n\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Removes the quota_dynamic and quota_static field from the 
    subnet table.\n";
  print "  * Removes the no_static and allow_secondaries options from the 
    subnet.flags column.\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  print "Dropping columns/flags from subnet table.\n";
  my $query = "ALTER TABLE subnet DROP quota_static, DROP quota_dynamic, MODIFY
flags set('no_dhcp','delegated','prereg_subnet')";
  my $res = $dbh->do($query);
  print "Done.  Status: $res\n";
}

sub alter_attribute_schema {
  print "Altering attribute and attribute_spec tables.\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Updates attribute table (expand owner_table)\n";
  print "  * Updates attribute_spec table (expand scope)\n";

  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $query = "ALTER TABLE attribute MODIFY owner_table enum('service_membership','service','users','groups','vlan','outlet','subnet') default NULL;";
  my $res = $dbh->do($query);
  print "Altered attribute table. Status: $res\n";

  $query = "ALTER TABLE attribute_spec MODIFY scope enum('service_membership','service','users','groups','vlan','outlet','subnet') default NULL;";
  my $res = $dbh->do($query);
  print "Altered attribute_spec table. Status: $res\n";

}

sub add_attribute_types {
  print "Inserting additional attribute types.\n";
  print "The following attribute types will be added:\n";
  print "  * port-duplex\n";
  print "  * port-speed\n";
  print "  * Port Security Mode\n";
  print "  * Port-Fast Mode\n";
  print "  * Extra Menu Item\n";
  print "  * background-color\n";
  print "Access permissions for the attributes will NOT be setup automatically.\n";
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $query = <<END_SELECT;
INSERT INTO attribute_spec (name, format, scope, type, ntimes, description) VALUES
('background-color','ustring','users',0,1,'Color to use for web page backgrounds'),
('port-speed','enum(auto,forced-10,forced-100)','outlet',0,1,'Set the speed of a switch port'),
('port-duplex','enum(auto,forced-half,forced-full)','outlet',0,1,'Set the duplex of a switch port'),
('Port Security Mode','enum(enabled,disabled)','vlan',0,1,'Enable/Disable port security mode on outlets in this vlan, by default.'),
('Port Security Mode','enum(enabled,disabled)','outlet',0,1,'Enable/Disable port security mode on the outlet'),
('Port-Fast Mode','enum(enabled,disabled)','outlet',0,1,'Enable/Disable spanning tree port-fast mode on the outlet'),
('Extra Menu Item','ustring','subnet',0,0,'Extra HTML to output in the machine information page, in the machine operations menu.');
END_SELECT

  my $res = $dbh->do($query);
  print "Added attribute types.  Status: $res\n";

}

sub create_changelog_tables {
  print "Creating table schema\n\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Creates _sys_changelog table\n";
  print "  * Creates _sys_changerec_row table\n";
  print "  * Creates _sys_changerec_col table\n";
 
  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $query = <<END_SELECT;
CREATE TABLE _sys_changelog (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  user int(10) unsigned NOT NULL default '0',
  name char(16) NOT NULL default '',
  time datetime default NULL,
  info char(255) NOT NULL default '',
  PRIMARY KEY  (id),
  KEY index_user (user),
  KEY index_username (name),
  KEY index_time (time)
) TYPE=MyISAM;
END_SELECT
  my $res = $dbh->do($query);
  print "Created _sys_changelog table. Status: $res\n";


  $query = <<END_SELECT;
CREATE TABLE _sys_changerec_col (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  changerec_row int(10) unsigned NOT NULL default '0',
  name varchar(255) NOT NULL default '',
  data text,
  previous text,
  PRIMARY KEY  (id),
  KEY index_record (changerec_row,name)
) TYPE=MyISAM;
END_SELECT
  my $res = $dbh->do($query);
  print "Created _sys_changerec_col table. Status: $res\n";


  $query = <<END_SELECT;
CREATE TABLE _sys_changerec_row (
  version timestamp(14) NOT NULL,
  id int(10) unsigned NOT NULL auto_increment,
  changelog int(10) unsigned NOT NULL default '0',
  tname char(255) NOT NULL default '',
  row int(10) unsigned NOT NULL default '0',
  type enum('INSERT','UPDATE','DELETE') NOT NULL default 'INSERT',
  PRIMARY KEY  (id),
  KEY index_changelog (changelog),
  KEY index_record (tname,row)
) TYPE=MyISAM;
END_SELECT
  my $res = $dbh->do($query);
  print "Created _sys_changerec_col table. Status: $res\n";

}



# Only one block to do this, so the user doesn't shoot themselves in the foot.
sub alter_protections {
  print "Altering protections table to include subnet_registration_modes.\n";
  my $query = "ALTER TABLE protections MODIFY tname enum('users','groups','building','cable','outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence','subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource','dns_zone','_sys_scheduled','activation_queue','service','service_membership','service_type','attribute','attribute_spec','outlet_subnet_membership','outlet_vlan_membership','vlan','vlan_presence','vlan_subnet_presence','trunk_set','trunkset_building_presence','trunkset_machine_presence','trunkset_vlan_presence','credentials','subnet_registration_modes') NOT NULL default 'users'";
  my $res = $dbh->do($query);
  print "  Altering Protections. Status: $res\n";
}

$dbh->disconnect();
