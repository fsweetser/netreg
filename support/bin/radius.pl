#!/usr/bin/perl

use Fcntl ':flock';

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;
use CMU::Netdb::machines_subnets;
use strict;


my $rad_user_file = 'usersnew.dbm.src';
my $user = 'netreg';
my $res;
my %idx;

# connect to database:
my $dbh = CMU::Netdb::report_db_connect();
unless ($dbh) {
  CMU::Netdb::netdb_mail('radius.pl', 'Database handle is NULL!', 'radius.pl error');
  exit(-1);
}

# get service group:
$res = CMU::Netdb::list_services($dbh, $user, "name='radius.net.cmu.edu'");
%idx = %{CMU::Netdb::makemap(shift(@$res))};
$res = CMU::Netdb::list_service_full_ref($dbh, $user,
                                         $res->[0][$idx{'service.id'}]);
unless (ref($res)) {
  CMU::Netdb::netdb_mail('radius.pl', 'Could not find service group', 'radius.pl error');
  exit(-1);
}

# get list of radius servers from service group:
my @servers = map(lc($res->{'memberData'}{"machine:$_"}{'machine.host_name'}),
                  @{$res->{'memberSum'}{'machine'}});

# get list of subnets from service group:
my @subnets = map({
    'id' => $_,
  'name' => $res->{'memberData'}{"subnet:$_"}{'subnet.name'},
  'auth' => $res->{'member_attr'}{"subnet:$_"}{'RadiusAuthType'}[0][0],
'rad_ip' => $res->{'member_attr'}{"subnet:$_"}{'RadiusStaticIP'}[0][0],
 'uname' => $res->{'member_attr'}{"subnet:$_"}{'RadiusUserName'}[0][0],
                  }, @{$res->{'memberSum'}{'subnet'}});

# where to put the resulting users.dbm.src file:
my $GENPATH;
($res, $GENPATH) = CMU::Netdb::config::get_multi_conf_var('netdb', 'RADIUS_GENPATH');
$GENPATH='/tmp' if ($res != 1);
unless (open(FILE, ">$GENPATH/$rad_user_file")) {
  CMU::Netdb::netdb_mail('radius.pl', "Could not write $GENPATH/$rad_user_file", 'radius.pl error');
  exit(-1);

}
print FILE "# compile with: rlm_dbm_parser -c -i $rad_user_file -o users-new.dbm\n" .
"#================================================\n" .
"\n" .
"WirelessSandbox\n" .
"\tTunnel-Type = VLAN,\n" .
"\tTunnel-Medium-Type = IEEE-802,\n" .
"\tTunnel-Private-Group-Id = 73\n" .
"\n" .
"# *** Wireless APs and controllers have 'NAS-Port-Type = Wireless-802.11'\n" .
"# *** VPN servers (such as the ASA) have 'NAS-Port-Type = Virtual'\n" .
"\n" .
"DEFAULT\tNAS-Port-Type == Wireless-802.11, EAP-Message =* Any\n" .
"\tFall-Through = No,\n" .
"\tUser-Category = \"WirelessSandbox\"\n" .
"\tNAS-Port-Type == Wireless-802.11, Auth-Type = Accept\n" .
"\tFall-Through = No,\n" .
"\tUser-Category = \"WirelessSandbox\"\n" .
"\tAuth-Type := Reject\n" .
"\tFall-Through = No\n" .
"\n";

# add monitoring account, if one is configured:
my $MON_ACCT_FILE;
($res, $MON_ACCT_FILE) = CMU::Netdb::config::get_multi_conf_var('netdb', 'RADIUS_MON_ACCT');
if ($res == 1 && open(MON_ACCT, "<$MON_ACCT_FILE")) {
  my $mon_user_pass = <MON_ACCT>;
  chomp $mon_user_pass;
  my ($mon_user, $mon_pass) = split(':', $mon_user_pass);
  close(MON_ACCT);
  if ($mon_user && $mon_pass) {
    print FILE "# netstat user allows netmon to check radius servers\n";
    print FILE "$mon_user\tPassword == $mon_pass\n\t;\n\n";
  }
}

# iterate through list of subnets:
for my $subnet (@subnets) {
  my $id = $subnet->{'id'};
  my $name = $subnet->{'name'};
  my $auth = $subnet->{'auth'};
  my $rad_ip = $subnet->{'rad_ip'};
  my $uname = $subnet->{'uname'};


  # decide whether to pull dynamics in addition to statics:
  my $where = "ip_address_subnet=$id and not find_in_set('suspend',flags) and ";
  if ($rad_ip eq 'no') {
    $where .= "mode in ('static','dynamic')";
  } elsif ($rad_ip eq 'yes') {
    $where .= "mode='static'";
  } else {
    CMU::Netdb::netdb_mail('radius.pl', "Skipping subnet $id:$name:auth=$auth:rad_ip=$rad_ip due to bad rad_ip", 'radius.pl error');
    next;
  }

  # decide whether to pull dynamics in addition to statics:
  my $user_field;
  if ($uname eq 'hostname') {
    $user_field = 'machine.host_name';
  } elsif ($uname eq 'mac') {
    $user_field = 'machine.mac_address';
  } else {
    CMU::Netdb::netdb_mail('radius.pl', "Skipping subnet $id:$name:auth=$auth:rad_ip=$rad_ip due to bad uname", 'radius.pl error');
    next;
  }

  # get list of authorized machines:
  $res = list_machines($dbh, $user, $where);

  print FILE "#BEGIN Subnet $id: $name\n";
  %idx = %{CMU::Netdb::makemap(shift(@$res))};
  for my $m (@$res) {
    print FILE lc($m->[$idx{$user_field}]);
    if ($auth eq 'accept') {
      print FILE "\tAuth-Type = Accept";
    }
    print FILE "\n\t";
    if ($rad_ip eq 'yes') {
      print FILE 'Framed-IP-Address = ' .
            CMU::Netdb::long2dot($m->[$idx{'machine.ip_address'}]);
    } else {
      print FILE ';';
    }
    print FILE "\n";
  }

  print FILE "#END Subnet $id: Name = $name\n\n";
}

# done generating users.src.dbm file
close(FILE);
$dbh->disconnect();

# now transfer file to the servers:
my ($RSYNC_RSH, $RSYNC_PATH, $RSYNC_OPTIONS, $RSYNC_REM_USER, $XFERPATH);
($res, $RSYNC_RSH) = CMU::Netdb::config::get_multi_conf_var('netdb', 'RSYNC_RSH');
$ENV{RSYNC_RSH} = $RSYNC_RSH;
($res, $RSYNC_PATH) = CMU::Netdb::config::get_multi_conf_var('netdb', 'RSYNC_PATH');
($res, $RSYNC_OPTIONS) = CMU::Netdb::config::get_multi_conf_var('netdb', 'RSYNC_OPTIONS');
($res, $RSYNC_REM_USER) = CMU::Netdb::config::get_multi_conf_var('netdb', 'RSYNC_REM_USER');
($res, $XFERPATH) = CMU::Netdb::config::get_multi_conf_var('netdb', 'RADIUS_XFERPATH');
$XFERPATH='/tmp' if ($res != 1);

for my $server (@servers) {
  my $cmd = "$RSYNC_PATH $RSYNC_OPTIONS $GENPATH/$rad_user_file $RSYNC_REM_USER\@$server:$XFERPATH > /dev/null";
  $res = system($cmd);
  if ($res >> 8 != 0) {
    CMU::Netdb::netdb_mail('radius.pl', "Could not transfer $GENPATH/$rad_user_file to $server:$XFERPATH", 'radius.pl error');
    next;
  }
}

exit(0);
