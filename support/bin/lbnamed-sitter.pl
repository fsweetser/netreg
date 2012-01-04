#!/usr/bin/perl

use strict;
use Mon::Client;
use Sys::Hostname;


my $Test = "/var/run/lbnamed/lbnamed.stat";
my $TestLB = "/var/run/lbnamed/linux.andrew.cmu.edu";
my $Script = "/home/netreg/bin/lbnamed.pl";
my $host = 'netsage-montrap.andrew.cmu.edu';
my $localhost = hostname;
my $group = 'dynamic-dns';
$localhost =~ tr/a-z/A-Z/;

$host = 'netsage-montrap.andrew.cmu.edu';

if ($localhost =~ /QATAR\.CMU\.EDU/) {
  $host = 'netsage-montrap.qatar.cmu.edu';
  $TestLB = '/var/run/lbnamed/ldap.qatar.cmu.edu';
  $group = 'dynamic-dns-qatar';
}

my $c = new Mon::Client (host => $host, port => 2583);
my $error = undef;

my $LastRestart = 0;
verify_lastupdate($Test);
verify_lastupdate($TestLB);

if (!$c) {
  die "Cannot connect to MON to send trap!";
}

if ($error) {
  print $c, "\n";
  $c->send_trap( group => $group,
		 service => "lbnamed",
		 retval => 1,
		 opstatus => "fail",
		 summary => "lbnamed dead, restarting",
		 detail => "$error->[0] not updated since " . scalar localtime($error->[1]) . "\n",
	       );
} else {
  $c->send_trap( group => $group,
		 service => "lbnamed",
		 retval => 0,
		 opstatus => "ok",
		 summary => "",
		 detail => ""
	       );
}

sub verify_lastupdate {
  my ($File) = @_;
  my @FileStat = stat($File);
  my $Now = time();
  
  if ($FileStat[9] + 30 < $Now &&
      $LastRestart + 30 < $Now) {
    $ENV{PATH} = "/bin:/usr/bin";
    system("/bin/ps auxww | grep lbname | grep -v sitter | cut -b10-14  | xargs kill");
    launch_lbnamed();
    $LastRestart = $Now;

    $error = [$File,$FileStat[9]];
  }
} 

sub launch_lbnamed {
  if (fork()) {
    # Parent
    return;
  }else{
    exec($Script);
    exit 0;   
  }
} 
