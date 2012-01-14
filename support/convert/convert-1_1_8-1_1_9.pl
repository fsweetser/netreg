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

use CMU::Netdb;
use CMU::Netdb::config;

CMU::Netdb::netdb_debug({helper => 0});
CMU::Netdb::netdb_debug(0);

my %Desc = (	    'attribute-schema-update' => "This command will modify the attribute schema to allow attributes on more types of records.",
	   );
my %Run = ( 	    'attribute-schema-update' => 0,
	  );

my @Order = qw(attribute-schema-update);
my %Cmd = ('attribute-schema-update' => \&alter_attribute_schema);

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
 
$dbh->disconnect();

exit 0;

sub alter_attribute_schema {
  print "Altering attribute and attribute_spec tables.\n";
  print "This modifies the following parts of your DB schema:\n";
  print "  * Updates attribute table (expand owner_table)\n";
  print "  * Updates attribute_spec table (expand scope)\n";

  print "Proceed [default:no]? ";
  my $a = <STDIN>;
  return unless ($a =~ /y/i);

  my $query = "ALTER TABLE attribute MODIFY owner_table enum('service_membership','service','users','groups','vlan','outlet','subnet','machine') default NULL;";
  my $res = $dbh->do($query);
  print "Altered attribute table. Status: $res\n";

  $query = "ALTER TABLE attribute_spec MODIFY scope enum('service_membership','service','users','groups','vlan','outlet','subnet','machine') default NULL;";
  my $res = $dbh->do($query);
  print "Altered attribute_spec table. Status: $res\n";

}


