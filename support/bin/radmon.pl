#!/usr/local/bin/perl5
#
# 
#
# 
# 
# 
# 
#
#
# 
# 
# 

use strict;
use Fcntl ':flock';
use lib '/home/netreg/lib';
use CMU::RadWeb;

my ($dbuser, $dbh, $data, $dapos);
my ($i, $debug, $quota, $qupos);
my ($pperiod, $ttimes);
my ($access, $acpos, $achash, $key, $expire);

$debug = 0;
$dbuser="radweb";

$dbh = CMU::RadWeb::WebReg_db_connect();

$quota = CMU::RadWeb::Quota_list($dbh, $dbuser, "Quotas.PoolID = 1");

if (! ref $quota){
  print STDERR "internal error $data ( $CMU::Netdb::errors::errmeanings{$data} ) while attempting to get list\n";
  exit(-1);
}

$qupos = CMU::RadWeb::GetHeaderPos($quota);

$access = CMU::RadWeb::SpecAccess_list($dbh, $dbuser);
if (! ref $access){
  print STDERR "internal error $data ( $CMU::Netdb::errors::errmeanings{$data} ) while attempting to get list\n";
  exit(-1);
}
$acpos = CMU::RadWeb::GetHeaderPos($access);

shift @$access;

map {
  $achash->
    {$_->[$acpos->{'SpecAccess.UserName'}]}{$_->[$acpos->{'SpecAccess.AccessType'}]}{Expire} = Time::ParseDate::parsedate($_->[$acpos->{'SpecAccess.Expires'}]);
  $achash->
    {$_->[$acpos->{'SpecAccess.UserName'}]}{$_->[$acpos->{'SpecAccess.AccessType'}]}{RecNum} = $_->[$acpos->{'SpecAccess.RecNum'}];
  $achash->{$_->[$acpos->{'SpecAccess.UserName'}]}{$_->[$acpos->{'SpecAccess.AccessType'}]}{Version} = $_->[$acpos->{'SpecAccess.Version'}];
} (@$access);

map {
  foreach $key (sort keys %{$achash->{$_}}){
    print STDERR "$_ at $key expires $achash->{$_}{$key}{Expire}\n";
  
    print STDERR "Calling SpecAccess_delete with dbuser = $dbuser " .
      "RecNum = $achash->{$_}{$key}{RecNum} Version = $achash->{$_}{$key}{Version}\n" .
	"Expires at $achash->{$_}{$key}{Expire} is currently " . time() . "\n"
	  if ($achash->{$_}{$key}{Expire} <= time());

    CMU::RadWeb::SpecAccess_delete($dbh, $dbuser,
				   $achash->{$_}{$key}{RecNum},
				   $achash->{$_}{$key}{Version}) if ($achash->{$_}{$key}{Expire} <= time());
    

  }
} (sort keys %$achash);

if ($quota->[1][$qupos->{'Quotas.Status'}] eq "Disabled"){
  print STDERR "Quota disabled\n" ;
  dbh->disconnect();
  exit (0);
}

($pperiod,$ttimes) = CMU::RadWeb::PrimePeriod($dbh, $dbuser, 1, time());

$expire = (($quota->[1][$qupos->{'Quotas.Status'}] eq "Active") ?
	   CMU::RadWeb::TimeStamp(time() + (60 * 60 * 24 * 7) - (15 * 60)) :
	   CMU::RadWeb::TimeStamp($pperiod->{end}));

$data = CMU::RadWeb::User_list($dbh, $dbuser, 1, $pperiod->{start}, time(), "PT");


if (! ref $data){
  print STDERR "internal error $data ( $CMU::Netdb::errors::errmeanings{$data} ) while attempting to get list\n";
  exit(-1);
}

$dapos = CMU::RadWeb::GetHeaderPos($data);

foreach $i (1 .. $#$data)  {
#  print STDERR "\n\nCumPrimeTime = " . time2sec($data->[$i][$dapos->{'Internal.cum_prime_time'}]) . "\nQuota = " .
#    time2sec($quota->[1][$qupos->{'Quotas.Quota'}]) . "\nGrace period = " .
#      time2sec($quota->[1][$qupos->{"Quotas.Grace"}]) . "\nWarning = " .
#	time2sec($quota->[1][$qupos->{"Quotas.Warn"}]) . "\n";

#  Check for Exempt status
  next if (defined $achash->{$data->[$i][$dapos->{'radacct.UserName'}]}{UNLIMIT});

#  Check for overquota persons, flattening them if newly over, continuing if already flagged
  if (time2sec($data->[$i][$dapos->{'Internal.cum_prime_time'}]) >=
      (time2sec($quota->[1][$qupos->{"Quotas.Quota"}]) + time2sec($quota->[1][$qupos->{"Quotas.Grace"}]))){
    if (! defined $achash->{$data->[$i][$dapos->{'radacct.UserName'}]}{'OVER-QUOTA'}){
#      print STDERR "\"Over-Quota\"ing $data->[$i][$dapos->{'radacct.UserName'}]\n";
#  Silently delete any warning level that they have
      CMU::RadWeb::SpecAccess_delete($dbh, $dbuser,$achash->{$data->[$i][$dapos->{'radacct.UserName'}]}{WARNED}{RecNum},
				     $achash->{$data->[$i][$dapos->{'radacct.UserName'}]}{WARNED}{Version}, "NOMAIL")
	if (defined $achash->{$data->[$i][$dapos->{'radacct.UserName'}]}{WARNED});
      
# Insert the OverQuota line, sending mail
#      print STDERR "Calling CMU::RadWeb::SpecAccess_add(\$dbh, $dbuser, \\$data = " .
#	"{ UserName => \"$data->[$i][$dapos->{'radacct.UserName'}]\", " .
#	  "AccessType => \"OVER-QUOTA\", " . 
#	    "Pool => 1, " .
#	      "Expires => " . CMU::RadWeb::TimeStamp(time() + (60 * 60 * 24 * 7) - (15 * 60)) . ", " .
#		"Comment => \"User has exceeded prime time quota for this usage period\" });\n";
      CMU::RadWeb::SpecAccess_add($dbh, $dbuser, { UserName => "$data->[$i][$dapos->{'radacct.UserName'}]",
						   AccessType => "OVER-QUOTA",
						   Pool => 1,
						   Expires => $expire,
						   Comment => "User has exceeded prime time quota for this usage period. " .
						   CMU::RadWeb::TimeStamp(time())
						 });
    }
    next;
  }
  
  
#  Check to see if they are to be warned (if we got here they haven't accumulated enough time for a shutdown
  if (time2sec($data->[$i][$dapos->{'Internal.cum_prime_time'}]) >= time2sec($quota->[1][$qupos->{"Quotas.Warn"}])){

#  check it they were already warned
    if (!defined $achash->{$data->[$i][$dapos->{'radacct.UserName'}]}{'WARNED'}){
# Post the warning message, sending mail
#      print STDERR "$data->[$i][$dapos->{'radacct.UserName'}] being warned\n";
#      print STDERR "Calling CMU::RadWeb::SpecAccess_add(\$dbh, $dbuser, \$data = " .
#	"{ UserName => \"$data->[$i][$dapos->{'radacct.UserName'}]\", " . 
#	  "AccessType => \"WARNED\", " .
#	    "Pool => 1, " . 
#	      "Expires => " . CMU::RadWeb::TimeStamp($pperiod->{end}) . ", " .
#		"Comment => \"User has exceeded prime time warning level for this usage period\"});\n";
      CMU::RadWeb::SpecAccess_add($dbh, $dbuser, { UserName => "$data->[$i][$dapos->{'radacct.UserName'}]",
						   AccessType => "WARNED",
						   Pool => 1,
						   Expires => CMU::RadWeb::TimeStamp($pperiod->{end}),
						   Comment => "User has exceeded prime time warning level for this usage period. " .
						   CMU::RadWeb::TimeStamp(time())
						 });
    }
#    else {
#      print STDERR "$data->[$i][$dapos->{'radacct.UserName'}] already warned\n";
#    }
    next;
  }
  
# if we get here, they are below the warning level.  Since these are sorted, all the rest are too.
  last;
} ;

$dbh->disconnect();


sub time2sec{
  my ($time) = @_;

  my ($hr, $min, $sec) = split(':', $time);
  return (($hr * 3600) + ($min * 60) + $sec);
}
