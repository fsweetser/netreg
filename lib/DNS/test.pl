#! /usr/bin/perl

use lib '/home/netreg/lib';
use DNS::ZoneParse;

my $dns = new DNS::ZoneParse();

my $zonefile = $ARGV[0];
my $zone = $zonefile;
my @a = split(/\//, $zone);
$zone = $a[-1];
$zone =~ s/\.zone$//;

$dns->Debug(2);
$dns->Prepare($zonefile, $zone, 86400);

sleep (2);
print "***************** NEW ZONE FILE *************************\n";
print $dns->PrintZone();

