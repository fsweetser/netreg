#!/usr/bin/perl

# Copyright (c) 2000-2006 Carnegie Mellon University. All rights reserved.   
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

use strict;

use lib '../bin';
BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use DBI;


my $debug = 0;


my @SchemaChanges = (
		     #Modify groups.id and and memberships.gid to be signed, for mysql 4.1+
		     "alter table groups modify id int(10) auto_increment",
		     "alter table memberships modify gid int(10)",


		     #####
		     # user type changes for usermaint interface
		     #####
		     "CREATE TABLE user_type (
					     id int(10) unsigned NOT NULL auto_increment,
					     version timestamp(14) NOT NULL,
					     name varchar(64) NOT NULL default '',
					     expire_days_mach tinyint(4) not null default '7',
					     expire_days_outlet tinyint(4) not null default '7',
					     flags set('send_email_mach','send_email_outlet','disable_acct') default null,
					     PRIMARY KEY  (id),
					     UNIQUE KEY (name)
					    ) TYPE=InnoDB",

		     # Add user_type to protections table
		     "alter table protections modify column tname
		     enum('users','groups','building','cable',
			  'outlet','outlet_type','machine','network','subnet','subnet_share','subnet_presence',
			  'subnet_domain','dhcp_option_type','dhcp_option','dns_resource_type','dns_resource',
			  'dns_zone','_sys_scheduled','activation_queue','service','service_membership',
			  'service_type','attribute','attribute_spec','outlet_subnet_membership',
			  'outlet_vlan_membership','vlan','vlan_presence','vlan_subnet_presence','trunk_set',
			  'trunkset_building_presence','trunkset_machine_presence','trunkset_vlan_presence',
			  'credentials','subnet_registration_modes','user_type') default 'users'",


		     # add user type to credential 
		     "ALTER TABLE credentials ADD COLUMN type tinyint(4) NOT NULL default '1'",


		     # Add expires column to outlet table
		     "ALTER TABLE outlet ADD COLUMN expires date not null default '0000-00-00'",

		     # Add default user types
		     "INSERT INTO user_type VALUES
		     (1,20060314133240,'General',14,14,'send_email_mach,send_email_outlet'),
		     (2,20060314133240,'Internal',90,90,'send_email_mach,send_email_outlet,disable_acct'),
		     (3,20060220134454,'Guest',0,0,null)",

		     # Add initial usermaint protections
		     "INSERT INTO protections (identity, tname, tid, rights, rlevel) VALUES
		     (-1,'user_type',0,'READ,WRITE,ADD', 9),
		     (0,'user_type',0,'READ', 1),
		     (-1,'user_type',1,'ADD', 9),
		     (-1,'user_type',2,'ADD', 9),
		     (-1,'user_type',3,'ADD', 9)",


		     # Global user type changes
		     "UPDATE credentials SET type=2 where authid = 'netreg'",

		     #####
		     # end user type changes
		     #####



		     # support for large dhcp options, requires mysql >= 4.0.15 (IIRC)
		     "alter table dhcp_option drop index index_nodup",
		     "alter table dhcp_option modify value text",
		     "alter table dhcp_option add unique key index_nodup (type_id, type, tid, value(255))",

		     # support for per-user default groups
		     "alter table users add default_group INT UNSIGNED NOT NULL",

		     # dynamics now get ip_address_zone set to null, must allow null.
		     "alter table machine modify ip_address_zone int(10) unsigned default 0",
		    );



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

print "Running database schema updates\n";

foreach (@SchemaChanges) {
  print "$_\n";
  $dbh->do($_);
}

$dbh->disconnect();

exit 0;

