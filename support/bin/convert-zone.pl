#! /usr/bin/perl

use strict;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;
use Getopt::Long;
use CMU::Netdb;
use Sys::Hostname;

use vars qw/ %Fields $res /;

my %Fields = ('name' => '',
	      'soa_host' => hostname(),
	      'soa_email' => '',
	      'soa_refresh' => 3600,
	      'soa_retry' => 900,
	      'soa_expire' => 2419200,
	      'soa_minimum' => 21600,
	      'type' => 'fw-toplevel',
	      'soa_default' => 21600);


$res = GetOptions("zone=s" => \$Fields{name},
		  "host=s" => \$Fields{soa_host},
		  "email=s" => \$Fields{soa_email},
		  "refresh=i" => \$Fields{soa_refresh},
		  "retry=i" => \$Fields{soa_retry},
		  "expire=i" => \$Fields{soa_expire},
		  "minimum=i" => \$Fields{soa_minimum},
		  "default=i" => \$Fields{soa_default},
		  "type=s" => \$Fields{type});

usage() unless ($res && $Fields{name} && $Fields{soa_email} && ($Fields{type} eq 'fw-toplevel' || $Fields{type} eq 'rv-toplevel'));


print Data::Dumper->Dump([\%Fields], ['Fields']);


main();

sub main {

  my $dbh = CMU::Netdb::lw_db_connect();

  # Load the zone data out of NetReg
  my $ZD = CMU::Netdb::list_dns_zones($dbh, 'netreg',
				      "dns_zone.name = '$Fields{name}'");





  if (!ref $ZD) {
    print "Error listing DNS zones: $ZD\n";
    return;
  }elsif(!defined $ZD->[1]) {
    print "DNS Zone not found ($Fields{name}).";
    return;
  }
  my %zone_pos = %{CMU::Netdb::makemap($ZD->[0])};
  my $id = $ZD->[1]->[$zone_pos{"dns_zone.id"}];
  my $ver = $ZD->[1]->[$zone_pos{"dns_zone.version"}];

  
  my ($res, $ref) = CMU::Netdb::modify_dns_zone($dbh, 'netreg', $id, $ver,
						\%Fields);
  if ($res != 1) {
    print "Error updating dns zone ($id/$ver): ".join(',', @$ref)."\n";
    return;
  }
  print "Zone Updated\n";
}

sub usage {
  print <<EOF;
Usage: $0 --zone <ZONE> --email <SOA Email String> [--host hostname]
                   [--refresh N] [--retry N] [--expire N] [--minimum N]
                   [--default N] [--type (fw-toplevel|rv-toplevel)]
EOF
  exit;
}
