#! /usr/bin/perl
#
# $Id: update-zones.pl,v 1.3 2008/03/27 19:42:46 vitroth Exp $
#

use strict;

my $GEN = '/home/netreg/etc/zone-xfer';
my $XFER = '/home/bind9/db';
my $DEBUG = 0;

if ($ARGV[0] eq '-debug') {
  $GEN = '/tmp/zones';
  $XFER = '/tmp/zones-xfer';
  $DEBUG = 1;
}

opendir(DIR, $GEN);
my @zones = grep { /\.zone$/ && -f "$GEN/$_" } readdir(DIR);
closedir(DIR);

my @CP_Files;
my $DNS_Restart = 0;

foreach my $Z (@zones) {
  next unless (-r "$GEN/$Z");
  # Doesn't exist in /home/bind9/db, definitely copy
  unless (-e "$XFER/$Z") {
    print "$Z doesn't exist in $XFER, copying..\n";
    `cp $GEN/$Z $XFER/$Z`;
    $DNS_Restart = 1;
    next;
  }

  next unless (-w "$XFER/$Z");
 
  my @OldFile = stat("$XFER/$Z");
  my @NewFile = stat("$GEN/$Z"); 
  if ($OldFile[9] < $NewFile[9]) {
    # File in $GEN is older
    print "Copying $Z..\n";
    `cp $GEN/$Z $XFER/$Z`;
    $DNS_Restart = 1;
  }
} 

if ($DNS_Restart) {
  print "Reloading nameserver..\n";
  system('/home/bind9/sbin/rndc reload');
}
