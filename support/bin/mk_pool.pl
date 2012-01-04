#!/usr/bin/perl
#
# This code takes a subnet and an optional max entry count and
# attempts to make pool entries in that subnet.  It will either
# make entry_count entries or fill out the subnet, which ever
# comes first.  Needless to say, if it is not given a max entry
# count, it WILL take over a subnet.
# 
#
#
# 
# 
# 

use strict;
use Fcntl ':flock';
use lib '/home/netreg/lib';
use CMU::Netdb;
use Getopt::Std;


my ($user, $dbh, $db_result);
my ($i, $debug);
my ($target_sn, $target_mask , $id, $mask, $total, $avail);
my ($hname, $hdomain, $ipstr, @ipstr, $snet);
my(%perms, %vals, %opts, $cnt, $ret, $ref, $ver);
my ($ntag, $htag);

getopts('d:n:s:', \%opts);

$debug = 0;
$CMU::Netdb::auth::debug = 0;
$CMU::Netdb::machines_subnets::debug = 0;

undef $cnt;
undef $hdomain;
undef $snet;
$ntag = "";
$htag = 21;

$cnt = $opts{n} if defined $opts{n};
$hdomain = $opts{d} if defined $opts{d};
$snet = $opts{s} if defined $opts{s};
$snet =~ s/\%//g;
$snet =~ s/\"//g;
$snet =~ s/\'//g;

&usage if ((! defined $hdomain) or (! defined $snet));

$user="netreg";

$dbh = CMU::Netdb::lw_db_connect();

$db_result = CMU::Netdb::list_subnets($dbh, $user, "( subnet.abbreviation like \"$snet\"  )  ");

die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get subnet info for target subnet $ARGV[1]\n" if not ref $db_result;

$i = 0;

foreach (@{$db_result->[0]}){
#  map column headers from reply
  $id = $i if ($_ eq 'subnet.id');
  $mask = $i if ($_ eq 'subnet.network_mask');
#  print STDERR $_ . "\n";
  $i++
}
die "No target subnet found \n" if $#$db_result != 1;
#print STDERR join( '|', @{$db_result->[1]}, "\n");
#for $i ( 1 .. $#$db_result ) {
# Loop through the values returned.
# items referenced as follows...
#  @{$db_result->[$i]}[$id],
#  print STDERR join( '|', @{$db_result->[$i]}, "\n");
#}

$target_sn = @{$db_result->[1]}[$id];
$target_mask = @{$db_result->[1]}[$mask];

$total = (0xFFFFFFFF ^ $target_mask) + 1;
print "total = $total \n" if ($debug >= 1);

$db_result = CMU::Netdb::list_machines($dbh, $user, "( (machine.ip_address != 0 ) and (machine.ip_address_subnet = $target_sn)) ");
die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get host count\n" if not ref $db_result;

$avail = $total - $#$db_result ;
print "avail = $avail \n" if ($debug >= 1);;
if ((! defined $cnt) || ($cnt > $avail)){
  $cnt = $avail;
}

print STDERR "$cnt available hosts\n";

while (((! defined $cnt) or ($cnt > 0)) and ($avail >= 1)){
 again:
  undef %perms;
  undef %vals;

# /* initialize the permissions */
  $perms{dc0m}->[0] = 'READ,WRITE';
  $perms{dc0m}->[1] = 1;

# /* initialize the device */
  $vals{host_name} = "TOBERES" . $ntag . "." . $hdomain;
  $vals{mode} = 'static';
  $vals{mac_address} = '424F475553' . $htag;
  $vals{ip_address_subnet} = $target_sn;
  $vals{dept} = 'dept:nginfra';

  print "\nvalues passed to add_machine\n" if ($debug >= 1);
  foreach $i (sort keys %vals){
    print "\tvals{$i} = $vals{$i}\n" if ($debug >= 1);
  }
  ($ret, $ref) = CMU::Netdb::add_machine($dbh, $user, 9, \%vals, \%perms);
  if ($ret == -17){
    last;
  } elsif ($ret == -6){
    $ntag += 1;
    $htag += 1;
    $ret = 0;
    $ref = 0;
    goto again;
  } elsif ($ret < 0){
    print "\nvalues passed to add_machine\n";
    foreach $i (sort keys %vals){
      print "\tvals{$i} = $vals{$i}\n";
    }
    die "error $ret ( $CMU::Netdb::errmeanings{$ret} ) while attempting to add host\n";
  }
  
  print "\nvalues returned by add_machine\n" if ($debug >= 1);
  foreach $i (sort keys %$ref){
    print "\tref{$i} = $$ref{$i}\n" if ($debug >= 1);
  }
  
  undef %vals;
  $ipstr = $$ref{IP};
  print "ipstr = $ipstr\n" if ($debug >= 1);
  @ipstr = split /\./, $ipstr;
  print "\@ipstr = " . join '|', @ipstr, "\n" if ($debug >= 1);
  $vals{host_name} = "DYN-A84-" . $ipstr[2] . "-" . $ipstr[3] . "." . $hdomain;
  $vals{mode} = 'pool';
  $vals{mac_address} = ''; 
 
  $db_result = CMU::Netdb::list_machines($dbh, $user, "( machine.id = $$ref{insertID} )");
  
  die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get just inserted host\n" if not ref $db_result;
  
  $i = 0;
  foreach (@{$db_result->[0]}){
#  map column headers from reply
    $ver = $i if ($_ eq 'machine.version');
    $i++
  }
  
  die "HELP, I cannot find the entry I just made!!!\n" if $#$db_result != 1;
  
  for $i ( 1 .. $#$db_result ) {
# Loop through the values returned.
# items referenced as follows...
#  @{$db_result->[$i]}[$id],
    
#  print join( '|', @{$db_result->[$i]}, "\n");
    
  }
  
  print "\nvalues passed to modify_machine\n" if ($debug >= 1);
  foreach $i (sort keys %vals){
    print "\tvals{$i} = $vals{$i}\n" if ($debug >= 1);
  }
  
  ($ret, $ref) = CMU::Netdb::modify_machine($dbh,
					    $user,
					    $$ref{insertID},
					    @{$db_result->[1]}[$ver],
					    9,
					    \%vals);
  if ($ret < 0){
    die "error $ret ( $CMU::Netdb::errmeanings{$ret} ) while attempting to add host\n";
  }
  print STDERR "added $vals{host_name} to pool\n";
  $cnt -= 1 if defined $cnt;
  
}


$dbh->disconnect();

sub usage {
  die "usage: mk_pool [-n count] -s subnet_abbrev -d subdomain\n";
}
