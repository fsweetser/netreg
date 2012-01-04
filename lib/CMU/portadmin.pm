#   -*- perl -*-
#
# CMU::portadmin
# This module provides routines for checking and updating the port status
# of hubs and switches.
#
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
# $Id: portadmin.pm,v 1.41 2008/03/27 19:42:33 vitroth Exp $
#
# $Log: portadmin.pm,v $
# Revision 1.41  2008/03/27 19:42:33  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.40.8.1  2007/10/11 20:59:38  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.40.6.1  2007/09/20 18:43:03  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.40  2006/08/04 17:54:37  fk03
# Got in a hurry and missed some debugging statement that made this way
# too chatty
#
# Revision 1.39  2006/08/03 15:57:54  fk03
# Added handling of 6509s
#
# Revision 1.38  2006/03/27 17:33:26  fk03
# Changes for 4948 switches.
#
# Revision 1.37  2005/07/13 17:25:24  fk03
# Altered to handle building up trunks on cisco switches.
#
# Revision 1.36  2005/01/07 17:24:19  vitroth
# Missing paren.  oops.
#
# Revision 1.35  2005/01/04 13:35:39  vitroth
# Added OID for 2800, removed call to netdb_mail_wrapper.
#
# Revision 1.34  2005/01/03 21:06:06  vitroth
# Add log entry about what password file experienced a problem.
#
# Revision 1.33  2004/12/06 20:53:47  vitroth
# Major overhaul of portadmin code.  Better logging, more features,
# better debugging, etc.  Portadmin can now set port speed, duplex,
# spanning-tree portfast, and port-security mode.
#
# Revision 1.32  2004/09/13 20:14:04  ktrivedi
# separate telnet/ssh login/enable.
#
# Revision 1.31  2004/08/20 20:08:36  vitroth
# *another* 2950 variant...
#
# Revision 1.30  2004/08/02 14:00:07  vitroth
# Another 2950 OID
#
# Revision 1.29  2004/07/25 05:36:45  vitroth
# Oops, helps to call the logging helper function correctly.
#
# Revision 1.28  2004/07/25 05:33:27  vitroth
# Added some debugging/logging of unrecognized switches.
# Added more caching of successful community strings.
# Added more switch OIDs, for older switches.
#
# Revision 1.27  2004/07/22 06:35:15  ktrivedi
# added OID for 2950-48 SI
#
# Revision 1.26  2004/07/14 18:45:34  ktrivedi
# updated checkVlan so that eventhough trunk is not set up, if
# vlan exist then we can set up 'that' vlan on switch.
#
# Revision 1.25  2004/05/12 02:00:49  ktrivedi
# return proper errorcode to prevent fludding on error bboard
#
# Revision 1.24  2004/04/23 01:00:28  ktrivedi
# remove debugs
#
# Revision 1.23  2004/03/28 21:30:19  ktrivedi
# using CMU::NetConf
# spanning-tree portfast off when shutingdown the port
#
# Revision 1.22  2004/03/25 21:16:13  ktrivedi
# new portadmin, with cached snmp and ManageIOS module
#
# Revision 1.21  2004/02/11 20:29:52  vitroth
# expect doesn't do case insensitive matching, so we need to downcase
# the hostname passed in...
#
# Revision 1.20  2003/12/17 20:32:43  vitroth
# turn off strict host key checking when ssh'ing to switches
# since we have no way to maintain a list of ssh keys at present.
#
# Revision 1.19  2003/11/14 14:11:38  vitroth
# grr... 2950's in icarnegie are providing a different objID than
# the one i tested on.  these are 48 port switches, the one i tested on
# was a 24 port switch.  sigh
#
# Revision 1.18  2003/10/07 13:18:30  vitroth
# Another RH6->RH8 bizarro change.  Apparently sysObjectID *was* defined
# as .1.3.6.1.2.1.1.2, which meant we needed to fetch sysObjectID.0.
#
# But now its defined as .1.3.6.1.2.1.1.2.0
#
# Changed the portadmin code to use the the raw OID, to avoid future problems.
#
# Revision 1.17  2003/10/01 15:48:18  vitroth
# No really, I meant use ssh.  (doh!)
#
# Revision 1.16  2003/10/01 15:46:50  vitroth
# Now that the other bug is fixed, go back to using ssh.
#
# Revision 1.15  2003/10/01 13:48:37  vitroth
# wrong object id for 2950
#
# Revision 1.14  2003/09/30 19:37:56  vitroth
# 2950 tweaking
#
# Revision 1.13  2003/09/30 15:43:59  vitroth
# Added 2950 support
#
# Revision 1.12  2002/04/03 18:39:46  vitroth
# Added support for Cisco 5002 switches
#
# Revision 1.11  2002/03/14 21:55:33  vitroth
# Moved an SNMP query to before the expect connection starts, to
# speed up the actual transaction
#
# Revision 1.10  2002/03/14 21:17:20  vitroth
# Bug fixes for putting primary vlan in allowed list.  Also don't mark as
# error any vlan changes which turn out to be on unsupported devices.
#
# Revision 1.9  2002/03/12 20:35:56  vitroth
# Increased 'write mem' timeouts to 90 seconds for slow devices.
#
# Revision 1.8  2002/03/10 20:19:38  vitroth
# Added fixes for using non-public RO strings in critical operations
# (identifying a device, and mapping interfaces)
#
# Revision 1.7  2002/03/10 17:04:27  vitroth
# Lots of changes to support associating outlets with vlans, and to support
# VoIP associations.
#
# Revision 1.6  2002/01/10 03:43:34  kevinm
# Updated copyright.
#
# Revision 1.5  2001/07/20 22:22:21  kevinm
# Copyright info
#
# Revision 1.4  2001/06/13 14:42:05  kevinm
# Updated to use a second method for activating ports. It may need to be
# changed more to deal with checking the status correctly, though. A completely
# correct solution would be to look at .iso.org.dod.internet.mgmt.mib-2.system.2.0
# and then pick the method of activation based on that value.
#
# Revision 1.3  2000/12/19 23:09:51  vitroth
# If device appears to be set correctly and we fail to update it, pretend
# we succeeded.  Some devices seem to return an error when being set to
# the current state.
#
# Revision 1.2  2000/08/14 19:34:29  vitroth
# Bug fix
#
# Revision 1.1  2000/08/11 15:39:25  vitroth
# Initial checkin of portadmin script and module
#
#
#

package CMU::portadmin;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug $HUB_READ $SW_READ %errcodes);

use CMU::NetConf::ManageIOS;
use CMU::NetConf::Manage3500;
use CMU::NetConf::Manage3750;
use CMU::NetConf::Manage6000;
use CMU::WebInt;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(%errcodes);

my $HUB_READ = "public";
my $SW_READ = "public";
my $debug = 0;
my $devPassCa = {};
my (%typemap, %errmeaning, %errnum, %baddevs);

%typemap = ("1.3.6.1.4.1.9.1.287" => "3524-PWR-XL",
	    "1.3.6.1.4.1.9.1.278" => "3548-XL",
	    "1.3.6.1.4.1.9.1.248" => "3524-XL",
	    "1.3.6.1.4.1.9.1.246" => "3508G-XL",
	    "1.3.6.1.4.1.9.5.7" => "5000",
	    "1.3.6.1.4.1.9.5.18" => "1900",
	    "1.3.6.1.4.1.9.5.20" => "2820",
	    "1.3.6.1.4.1.9.5.29" => "5002",
	    "1.3.6.1.4.1.9.5.42" => "2948",
	    "1.3.6.1.4.1.9.5.44" => "6509",
	    "1.3.6.1.4.1.9.1.283" => "6509IOS",
	    "1.3.6.1.4.1.9.1.184" => "2900",
	    "1.3.6.1.4.1.9.1.359" => "2950",
	    "1.3.6.1.4.1.9.1.428" => "2950",
	    "1.3.6.1.4.1.9.1.429" => "2950",
	    "1.3.6.1.4.1.9.1.480" => "2950",
	    "1.3.6.1.4.1.9.1.516" => "3750",
	    "1.3.6.1.4.1.9.1.560" => "2950",
	    "1.3.6.1.4.1.437.1.1.3.3.3" => "2800",
	    "1.3.6.1.4.1.9.1.627" => "4948",
	    "1.3.6.1.4.1.9.1.659" => "4948",
	   );

%errcodes = ("EEXPECT" => -1,
		"EWRITE" => -2,
		"ELOGIN" => -3,
		"EENABLE" => -4,
		"EIFMAP" => -5,
		"EIDENT" => -6,
		"ECONN" => -7,
		"EDEVTYPE" => -8,
		"EINVALID" => -9,
		"ENOVLAN" => -11,
		"EINVALIDINPUT" => -12,
		"ENOPRIMARYVLAN" => -13,
		);

%errmeaning = ( 'EEXPECT' => "Error getting expected output from EXPECT ",
		'EWRITE'  => "Error writing configuration to switch ",
		'ELOGIN'  => "Error while login to device ",
		'EENABLE' => "Error while running enable on switch ",
		'EIFMAP'  => "Error getting interface map via snmp on switch ",
		'EIDENT'  => "Error getting identity of device i.e. Unspecified Device ",
		'ECONN'   => "Error establishing expect connection to switch ",
		'EDEVTYPE' => "Device Driver Not Implemented ",
		'EINVALID' => "Invalid Input ",
		'ENOVLAN' => "Device does not support VLAN or does not have VLAN configuration ",
		'EINVALIDINPUT' => "Error input to expect. Device refused to accept input ",
		'ENOPRIMARYVLAN' => "Error in setting trunk, i.e. no primary vlan defined ",
	);

%errnum = ( '-1' => 'EEXPECT',
	    '-2' => 'EWRITE',
	    '-3' => 'ELOGIN',
	    '-4' => 'EENABLE',
	    '-5' => 'EIFMAP',
	    '-6' => 'EIDENT',
	    '-7' => 'ECONN',
	    '-8' => 'EDEVTYPE',
	    '-9' => 'EINVALID',
	    '-11' => 'ENOVLAN',
	    '-12' => 'EINVALIDINPUT',
	    '-13' => 'ENOPRIMARYVLAN',
	   );

# ## this returns a port => link, admin, type, macs for hubs
# sub get_HubPorts {
#   my ($hn, $ip, $wm) = @_;
#   my $shost = "$HUB_READ\@$ip:161";
#   my %portinfo;
#   my (%links, %admin, %macs, %macCount);
#   my @portMacAddr = SNMP_util::snmpwalk($shost, "1.3.6.1.4.1.45.1.3.2.6.1.1.1.4.1");
#   my @locMacAddr = SNMP_util::snmpwalk($shost, "1.3.6.1.4.1.45.1.3.2.5.1.1.3.1");
#   if ($wm) {
#     foreach(@portMacAddr,@locMacAddr) {
#       my @pmA = &translate_hub_walk($_);
#       if (!defined $macCount{$pmA[0]} || $macCount{$pmA[0]} == 0) {
# 	$macs{$pmA[0]} .= $pmA[1];
# 	$macCount{$pmA[0]}++;
#       }elsif($macCount{$pmA[0]} == 1) {
# 	$macCount{$pmA[0]}++;
#       }
#     }
#   }
#   foreach(SNMP_util::snmpwalk($shost, "1.3.6.1.4.1.45.1.3.2.3.1.1.3.1")) {
#     split(/\:/);
#     $links{$_[0]} = $_[1];
#   }
#   foreach(SNMP_util::snmpwalk($shost, "1.3.6.1.4.1.45.1.3.2.3.1.1.4.1")) {
#     split(/\:/);
#     $admin{$_[0]} = $_[1];
#   }
#   foreach(keys %admin) {
#     $portinfo{$_} = [$links{$_}, $admin{$_}, $macs{$_}];
#   }
#   return \%portinfo;
# }
#
# #given IP, port, return MACs on that
# sub getHubMACs {
#   my ($ip, $port) = @_;
#   my $shost = "$HUB_READ\@$ip:161";
#   my @portMacAddr = SNMP_util::snmpwalk($shost, "1.3.6.1.4.1.45.1.3.2.6.1.1.1.4.1.$port");
#   my @locMacAddr = SNMP_util::snmpwalk($shost, "1.3.6.1.4.1.45.1.3.2.5.1.1.3.1.$port");
#   my $res;
#   foreach(@portMacAddr,@locMacAddr) {
#     my @pmA = &translate_hub_walk($_);
#     $res .= $pmA[1];
#   }
#   return $res;
# }

sub setHubPort {
  my ($ip, $port, $status) = @_;
  my $oid = "1.3.6.1.4.1.45.1.3.2.3.1.1.4.1.$port";
  &wlog("SET_HUB_PORT", "Setting $ip:$port to $status");
  my @passwords;
  open(PWFILE, "/home/netreg/etc/.portadmin.passwords") ||
    die("Can't open portadmin password file /home/netreg/etc/.portadmin.passwords");
  my $l;
  while($l = <PWFILE>) {
    chop($l);
    push(@passwords, $l);
  }
  close(PWFILE);
  my $shost = "$HUB_READ\@$ip:161";
  my ($cstat) = SNMP_util::snmpget($shost, $oid);
  my $fakeit = 0;
  if ($status == $cstat) {
    &wlog("SET_HUB_PORT_PASS", "Port is already set as requested");
    $fakeit = 1;
  }
  # We know the status is something different. Cycle through the passwords
  # and set the port status
  my $pass;
  my $pcnt = 0;
  foreach $pass (@passwords) {
    my $seth = "$pass\@$ip:161";
    $pcnt++;
    my ($res) = SNMP_util::snmpset($seth, $oid, 'int', $status);
    if ($res == $status) {
      &wlog("SET_HUB_PORT_PASS", "Used password #$pcnt");
      return 1;
    }
  }
  if ($fakeit) {
    &wlog("SET_HUB_PORT_PASS", "Unable to set port, but port was already set correctly");
    return 1;
  } else {
    &wlog("SET_HUB_PORT_PASS", "Unable to set port; bad password?");
    return 0;
  }
}  

# # takes x.128.2.y.z: XXXXXX and returns x, 00aabbccddee
# sub translate_hub_walk {
#   my ($a) = @_;
#   my @b = split(/\:/, $a);
#   my @c = split(/\./, $b[0]);
#   return ($c[0], unpack("H*", $b[1]));
# }

# ## this returns a port => link, admin, type, macs for hubs
# sub get_SwitchPorts {
#   my ($hn, $ip, $wm) = @_;
#   my $shost = "$SW_READ\@$ip:161";
#   my %portinfo;
#   my (%links, %admin, %macs, %macCount, $adminoid, $linkoid);
#   if (exists $baddevs{$ip}) {
#     &wlog("GET_SW_PORTS", "Skipping $ip, previous failure exists\n");
#     return undef;
#   }
#   my $swtype = identify_device($ip);
#   if ($swtype =~ /^35.*-XL$/ || $swtype eq "2950" || $swtype eq "6509" || $swtype =~ /^500.$/) {
#     $adminoid = "ifAdminStatus";
#     $linkoid = "ifOperStatus";
#   } else {
#     $adminoid = "1.3.6.1.4.1.437.1.1.3.3.1.1.10";
#     $linkoid = "1.3.6.1.4.1.437.1.1.3.3.1.1.9";
#   }
#   if ($wm) {
#     my @portMacAddr = SNMP_util::snmpwalk($shost, "1.3.6.1.2.1.17.4.3.1.2");
#     foreach(@portMacAddr) {
#       my @pmA = &translate_sw_walk($_);
#       if (!defined $macCount{$pmA[0]} || $macCount{$pmA[0]} == 0) {
# 	$macs{$pmA[0]} .= $pmA[1];
# 	$macCount{$pmA[0]}++;
#       }elsif($macCount{$pmA[0]} == 1) {
# 	$macCount{$pmA[0]}++;
#       }
#     }
#   }
#   # Link Status
#   foreach(SNMP_util::snmpwalk($shost, $linkoid)) {
#     split(/\:/);
#     $links{$_[0]} = $_[1];
#   }
#   # Admin
#   foreach(SNMP_util::snmpwalk($shost, $adminoid)) {
#     split(/\:/);
#     $admin{$_[0]} = $_[1];
#   }
#   foreach(keys %admin) {
#     $portinfo{$_} = [$links{$_}, $admin{$_}, $macs{$_}];
#   }
#   return \%portinfo;
# }

sub setSwitchPort {
  my ($ip, $port, $status) = @_;
  if (exists $baddevs{$ip}) {
    &wlog("SET_SW_PORT", "Skipping $ip, previous failure exists\n");
    return 0;
  }
  my $swtype = identify_device($ip);
  my $oid;
  if ($swtype =~ /^35.*-XL$/ || $swtype eq "2950" || $swtype eq "3750" || $swtype eq "6509" || $swtype =~ /^500.$/) {
    $oid = "ifAdminStatus.$port";
  } else {
    $oid = "1.3.6.1.4.1.437.1.1.3.3.1.1.10.$port";
  }
  &wlog("SET_SW_PORT", "Setting $ip:$port to $status");
  my @passwords;
  open(PWFILE, "/home/netreg/etc/.portadmin.passwords") ||
    die("Can't open portadmin passwords");
  my $l;
  while($l = <PWFILE>) {
    chop($l);
    push(@passwords, $l);
  }
  close(PWFILE);
  my $shost = "$SW_READ\@$ip:161";
  if (defined $devPassCa->{$ip}->{SNMP_RO}) {
    $shost = "$devPassCa->{$ip}->{SNMP_RO}\@$ip:161";
  }
  my ($cstat) = SNMP_util::snmpget($shost, $oid);
  my $fakeit = 0;
  if ($status == $cstat) {
    &wlog("SET_SW_PORT_PASS", "Port is already set as requested");
    $fakeit=1;
  }
  # We know the status is something different. Cycle through the passwords
  # and set the port status
  my $pass;
  my $pcnt = 0;
  foreach $pass (@passwords) {
    my $seth = "$pass\@$ip:161";
    $pcnt++;
    my ($res) = SNMP_util::snmpset($seth, $oid, 'int', $status);
    if ($res == $status) {
      &wlog("SET_SW_PORT_PASS", "Used password #$pcnt");
      return 1;
    }
  }
  # still haven't set it.
  if ($fakeit) {
    &wlog("SET_SW_PORT_PASS", "Unable to set port, but port was already set correctly");
    return 1;
  } else {
    &wlog("SET_SW_PORT_PASS", "Unable to set port; bad password?");
    $baddevs{$ip} = 1;
    return 0;
  }
}

# # takes 00.aa.bb.cc.dd.ee:26 and translates to 26, 00aabbccddee
# sub translate_sw_walk {
#   my ($a) = @_;
#   my @b = split(/\:/, $a);
#   my $c = sprintf("%02x%02x%02x%02x%02x%02x", split(/\./, $b[0]));
#   return($b[1], $c);
# }

# #given IP, port, return MACs on that
# sub getSwitchMACs {
#   my ($ip, $port) = @_;
#   my $shost = "$SW_READ\@$ip:161";
#   my @portMacAddr = SNMP_util::snmpwalk($shost, "1.3.6.1.2.1.17.4.3.1.2");
#   my $res;
#   foreach(@portMacAddr) {
#     my @pmA = &translate_sw_walk($_);
#     next if ($pmA[0] != $port);
#     $res .= $pmA[1];
#   }
#   return $res;
# }


# return the device type, based on sysObjectID
sub identify_device {
  my ($dev) = @_;

  if (exists $baddevs{$dev}) {
    &wlog("IDENTIFY_DEVICE", "Skipping $dev, previous failure exists\n");
    return undef;
  }

#  warn __FILE__ . ":" . __LINE__ . ": \n" . Data::Dumper->Dump([$devPassCa->{$dev}],[qw(passcache)]) . "\n"; 
  # Try from the cache.
  if (defined $devPassCa->{$dev}->{SNMP_RO}) {
      my $shost = "$devPassCa->{$dev}->{SNMP_RO}\@$dev:161";
      my ($id) = SNMP_util::snmpget($shost, "1.3.6.1.2.1.1.2.0");
	
      wlog("IDENTIFY_DEVICE", "snmpget returned $id") if ($debug >= 2);
      return $typemap{$id} if exists($typemap{$id});
  }

  # cache is stale, then try password file.
  my @passwords;
  open(PWFILE, "/home/netreg/etc/.portadmin.passwords.RO") ||
    die("Can't open portadmin passwords (/home/netreg/etc/.portadmin.passwords.RO)");
  my $l;
  while($l = <PWFILE>) {
    chop($l);
    push(@passwords, $l);
  }
  close(PWFILE);
  foreach (@passwords) {
    my $shost = "$_\@$dev:161";
    my ($id) = SNMP_util::snmpget($shost, "1.3.6.1.2.1.1.2.0");
    
    if ($id) {
      wlog("IDENTIFY_DEVICE", "snmpget returned $id") if ($debug >= 2);
      if (exists $typemap{$id}) {
        wlog("IDENTIFY_DEVICE", "Identified $id as $typemap{$id}") if ($debug >= 2);
	$devPassCa->{$dev}->{SNMP_RO} = $_;
	return $typemap{$id} ;
      } else {
	wlog("IDENTIFY_DEVICE", "WARNING\nUnknown Device $dev ($id).  Please update CMU::portadmin module\nWARNING\n");
      }
    } else {
      wlog("IDENTIFY_DEVICE", "No response to password $_\n") if ($debug >= 2);
    }
  }
  wlog("IDENTIFY_DEVICE", "WARNING\nNo response at all from $dev\nWARNING\n");
  return undef;
}

# generate a hash of if->ifdescr, and vice versa, mappings
sub map_ifdescr_to_int {
  my ($dev) = @_;
  my $ifmap = undef;
  my $currPass = undef;
  if (exists $baddevs{$dev}) {
    &wlog("MAP_IFDESCR_TO_INT", "Skipping $dev, previous failure exists\n");
    return undef;
  }

  # Try from the cache.
  if (defined $devPassCa->{$dev}->{SNMP_RO}) {
    my $shost = "$devPassCa->{$dev}->{SNMP_RO}\@$dev:161";
    foreach (SNMP_util::snmpwalk($shost, "ifDescr")) {
	split(/\:/);
	$ifmap->{ifdescr}{$_[0]} = $_[1];
	$ifmap->{ifnum}{$_[1]} = $_[0];
    }
  }

  return $ifmap if (defined $ifmap);

  # cache is stale, then try password file.
  my @passwords;
  open(PWFILE, "/home/netreg/etc/.portadmin.passwords.RO") ||
    die("Can't open portadmin passwords");
  my $l;
  while($l = <PWFILE>) {
    chop($l);
    push(@passwords, $l);
  }
  close(PWFILE);
  foreach (@passwords) {
    my $shost = "$_\@$dev:161";
    my @retVal = SNMP_util::snmpwalk($shost, "ifDescr");
    if (defined @retVal && $#retVal >= 0) {
	$devPassCa->{$dev}->{SNMP_RO} = $_;
	#foreach (SNMP_util::snmpwalk($shost, "ifDescr")) {
	foreach (@retVal) {
	    split(/\:/);
	    $ifmap->{ifdescr}{$_[0]} = $_[1];
	    $ifmap->{ifnum}{$_[1]} = $_[0];
	}
    }
  }
  return $ifmap;
  
}

# generate a hash of if->ifname, and vice versa, mappings
# uses .iso.org.dod.internet.mgmt.mib-2.ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifName
sub map_ifname_to_int {
  my ($dev) = @_;
  my $ifmap = undef;
  if (exists $baddevs{$dev}) {
    &wlog("MAP_IFNAME_TO_INT", "Skipping $dev, previous failure exists\n");
    return undef;
  }

  # Try from the cache.
  if (defined $devPassCa->{$dev}->{SNMP_RO}) {
    my $shost = "$devPassCa->{$dev}->{SNMP_RO}\@$dev:161";
    foreach (SNMP_util::snmpwalk($shost, "1.3.6.1.2.1.31.1.1.1.1")) {
	split(/\:/);
	$ifmap->{ifname}{$_[0]} = $_[1];
	$ifmap->{ifnum}{$_[1]} = $_[0];
    }
    return $ifmap if (defined $ifmap);
  }

  # cache is stale, then try password file.
  my @passwords;
  open(PWFILE, "/home/netreg/etc/.portadmin.passwords.RO") ||
    die("Can't open portadmin passwords");
  my $l;
  while($l = <PWFILE>) {
    chop($l);
    push(@passwords, $l);
  }
  close(PWFILE);
  foreach (@passwords) {
    my $shost = "$_\@$dev:161";
    my @retVal = SNMP_util::snmpwalk($shost, "1.3.6.1.2.1.31.1.1.1.1");
    if (defined @retVal && $#retVal >= 0) {
	$devPassCa->{$dev}->{SNMP_RO} = $_;
	foreach (SNMP_util::snmpwalk($shost, "1.3.6.1.2.1.31.1.1.1.1")) {
	    split(/\:/);
	    $ifmap->{ifname}{$_[0]} = $_[1];
	    $ifmap->{ifnum}{$_[1]} = $_[0];
	}
    }
  }
  return $ifmap;
  
}

# args: device name, port number, primary vlan number
# The access/native vlan will be set to the number given, all other vlan
# configuration will be left unchanged.
# sub set_primary_vlan {
#   my ($dev, $port, $vlan) = @_;

#   my ($type, $ifmap, $if, $shortdev, $devHandle, $res, $ref, $retVal);

#   $type = identify_device($dev);
#   return netdb_mail_wrapper($errcodes{EIDENT}, $errmeaning{EIDENT}, "NR-VLAN {EIDENT} $dev\/$port vlan-$vlan")
# 	  if (!$type);
  
#   $ifmap = map_ifname_to_int($dev);
#   return netdb_mail_wrapper($errcodes{EIFMAP}, $errmeaning{EIFMAP}, "NR-VLAN {EIFMAP} $dev\/$port vlan-$vlan")
#       if (!exists $ifmap->{'ifname'}{$port});
  
#   $if = $ifmap->{'ifname'}{$port};
#   $shortdev =~ s/^([^\.]*\.[^\.]*)\..*$/\1/;

#   # Getting devHandle by initiating specific device driver instance.
#   ($res, $devHandle) = getExpectHandle($dev, $port, $type);
#   return netdb_mail_wrapper($res,$errmeaning{$errnum{$res}},"NR-VLAN {ECONN} $dev\/$port vlan-$vlan",
# 			    $devHandle->{'err'}) 
#       if ($res != 1);

#   ($res, $ref) = $devHandle->enable();
#   return netdb_mail_wrapper($errcodes{EENABLE},$errmeaning{EENABLE},"NR-VLAN {EENABLE} $dev\/$port vlan-$vlan") 
#       if ($res < 1);

#   my ($con, $mpp, $err, $ms, $bm, $am);
#   $con = $devHandle->{'connection'};

#   $res = checkTrunk($devHandle, $vlan);
#   return netdb_mail_wrapper($errcodes{ENOVLAN}, $errmeaning{ENOVLAN}, "NR-VLAN {ENOVLAN} ".$dev."/".$port." vlan-$vlan",
# 	      "Trying to Set VLAN $vlan on $dev/$port with NO TRUNKING ENABLE")
#       if ($res != 1);

#   # New-code _START_
#   my %int_config = ('change_interface' => [{ 'truncated-if' => $if,
# 					    'access-vlan' => $vlan,
# 					   }
# 					  ]
# 		    );
#   $retVal = $devHandle->change_config(\%int_config);
#   return netdb_mail_wrapper($retVal->{'change_interface'}->{'ret'}, $errmeaning{$errnum{$retVal->{'change_interface'}->{'ret'}}},
# 			    "NR-VLAN {$errnum{$retVal->{'change_interface'}->{'ret'}}}".$dev."/".$port." vlan-$vlan",
# 			    $retVal->{'change_interface'}->{'err'})
#       if ($retVal->{'change_interface'}->{'ret'} < 1);
#   # New-code _END_
  
#   return 1;
# }

sub checkTrunk {
    my ($devHandle, $thisVlan) = @_;
    my ($con, $mpp, $err, $ms, $bm, $am, $res, $ref);

    ($res, $ref) = $devHandle->run_command("sh interface vlan 1");

    if ($res != 1) {
      wlog("checkTrunk", $errmeaning{EEXPECT});
      return $errcodes{EEXPECT};
    }
    return $errcodes{ENOVLAN} if ($ref->{'data'} =~ /line protocol is up/);

    ($res, $ref) = $devHandle->get_running_config();
    return $errcodes{ENOCONFIG} if ($res < 1);

    my $runConfig = $ref->{'data'};
    return 1 
	if ($runConfig =~ /switchport mode trunk/ || $runConfig =~ /switchport trunk native vlan/);

    ($res, $ref) = $devHandle->run_command("sh interface vlan $thisVlan");
    return 1
	if ($ref->{'data'} =~ /line protocol is up/);

    return $errcodes{ENOVLAN};
}


# args: device name, port (snmp interface # for now), array of vlan numbers, 
#       voice vlan # (blank for no voice vlan), trunktype
# sub set_trunk_vlans {
#   my ($dev, $port, $vlans, $voicevlan, $primaryvlan, $trunktype, $thisVlan) = @_;

#   my ($type, $ifmap, $if, $shortdev, $devHandle, $vlword, $res, $ref, $retVal);

#   $type = identify_device($dev);
#   return netdb_mail_wrapper($errcodes{EIDENT}, $errmeaning{EIDENT}, "NR-VLAN {EIDENT} $dev\/$port vlan-$vlan")
# 	  if (!$type);
  
#   $ifmap = map_ifname_to_int($dev);
#   return netdb_mail_wrapper($errcodes{EIFMAP}, $errmeaning{EIFMAP}, "NR-VLAN {EIFMAP} $dev\/$port vlan-$vlan")
#       if (!exists $ifmap->{'ifname'}{$port});
  
#   $if = $ifmap->{'ifname'}{$port};
#   $shortdev =~ s/^([^\.]*\.[^\.]*)\..*$/\1/;

#   my $msg = "This condition should never occur. User is trying to set trunk without first setting ".
# 	    "primary vlan\non Device-$dev/$port with vlan-@$vlans";
#   return  netdb_mail_wrapper($errcodes{ENOPRIMARYVLAN}, $errmeaning{ENOPRIMARYVLAN},
# 			    "NR-VLAN {ENOPRIMARYVLAN} $dev\/$port vlan-@$vlans",$msg,
# 			    $CMU::Netdb::config::NR_VLAN_ADMIN) 
#       if ($primaryvlan eq '');
  
#   push @$vlans, $voicevlan if ($voicevlan);
#   push @$vlans, $primaryvlan if ($primaryvlan);
#   $vlword = join(',',@$vlans);
  
#   # Getting devHandle by initiating specific device driver instance.
#   ($res, $devHandle) = getExpectHandle($dev, $port, $type);
#   return netdb_mail_wrapper($res, $errmeaning{$errnum{$res}}, "NR-VLAN {ECONN} $dev\/$port - $vlword",
# 			    $devHandle->{'err'})
#       if ($res != 1);
  
#   ($res, $ref) = $devHandle->enable();
#   return netdb_mail_wrapper($errcodes{EENABLE}, $errmeaning{EENABLE}, "NR-VLAN {EENABLE} $dev\/$port vlan-$vlword")
# 	  if ($res < 1);

#   my ($con, $mpp, $err, $ms, $bm, $am, $updateTrunk);
#   $con = $devHandle->{'connection'};


#   goto ADD_VLAN if ($#$vlans > 1 && $voicevlan eq '' && $thisVlan != $primaryvlan);

#   # New-code _START_
#   my %int_config = ( 'change_interface' => [{ 'truncated-if' => $if,
# 					      'access-vlan' => $primaryvlan,
# 					      'native-vlan' => $primaryvlan,
# 					      'switchport-mode' => 'trunk',
# 					      'vlan-encapsulation' => $trunktype,
# 					      'spanning-tree-portfast' => '1',
# 					      'allowed-vlan' => $vlword,
# 					      'voice-vlan' => $voicevlan,
# 					     }
# 					   ],
# 		    );
#   $retVal = $devHandle->change_config(\%int_config);
#   return netdb_mail_wrapper($retVal->{'change_interface'}->{'ret'}, $errmeaning{$errnum{$retVal->{'change_interface'}->{'ret'}}},
# 			    "NR-VLAN {$errnum{$retVal->{'change_interface'}->{'ret'}}}".$dev."/".$port." vlan-$vlan",
# 			    $retVal->{'change_interface'}->{'err'})
#       if ($retVal->{'change_interface'}->{'ret'} < 1);

#   # New-code _END_
 
#   goto WRITE_MEM;

# ADD_VLAN:
  
#   # New-code _START_
#   my %int_config = ( 'change_interface' => [{ 'truncated-if' => $if,
# 					     'allowed-vlan' => $vlword,
# 					    }
# 					   ],
# 		    );
#   $retVal = $devHandle->change_config(\%int_config);
#   return netdb_mail_wrapper($retVal->{'change_interface'}->{'ret'}, $errmeaning{$errnum{$retVal->{'change_interface'}->{'ret'}}},
# 			    "NR-VLAN {$errnum{$retVal->{'change_interface'}->{'ret'}}}".$dev."/".$port." vlan-$vlan",
# 			    $retVal->{'change_interface'}->{'err'})
#       if ($retVal->{'change_interface'}->{'ret'} < 1);
#   # New-code _END_


# WRITE_MEM:

#   return 1;
# }

# # args: device name and port number
# # removes all trunked vlans from port
# sub remove_trunk_vlans {
#   my ($dev, $port, $thisVlan, $voicevlan, $thisVlanType, $delvlans, $shutdown) = @_;

#   my ($type, $ifmap, $if, $shortdev, $devHandle, $res, $ref, $retVal);

#   $type = identify_device($dev);
#   return netdb_mail_wrapper($errcodes{EIDENT}, $errmeaning{EIDENT}, "NR-VLAN {EIDENT} $dev\/$port vlan-$vlan")
# 	  if (!$type);
  
#   $ifmap = map_ifname_to_int($dev);
#   return netdb_mail_wrapper($errcodes{EIFMAP}, $errmeaning{EIFMAP}, "NR-VLAN {EIFMAP} $dev\/$port vlan-$vlan")
#       if (!exists $ifmap->{'ifname'}{$port});
  
#   $if = $ifmap->{'ifname'}{$port};
#   $shortdev =~ s/^([^\.]*\.[^\.]*)\..*$/\1/;

#   # Getting devHandle by initiating specific device driver instance.
#   ($res, $devHandle) = getExpectHandle($dev, $port, $type);
#   return netdb_mail_wrapper($res, $errmeaning{$errnum{$res}}, "NR-VLAN {ECONN} $dev\/$port ",
# 			    $devHandle->{'err'})
#       if ($res != 1);
  
#   ($res, $ref) = $devHandle->enable();
#   return $errcodes{EENABLE} if ($res < 1);

#   my ($con, $mpp, $err, $ms, $bm, $am, $updateTrunk);

#   if (defined $shutdown && $shutdown == 1) {
#     my %int_config = ('change_interface' => [{'truncated-if' => $if,
# 					      'access-vlan' => '',
# 					      'native-vlan' => '',
# 					      'allowed-vlan' => '',
# 					      'switchport-mode' => '',
# 					      'inline-power' => '',
# 					      'voice-vlan' => '',
# 					      'spanning-tree-portfast' => '',
# 					     }
# 					    ],
# 		     );
	
#     $retVal = $devHandle->change_config(\%int_config);
#     return netdb_mail_wrapper($retVal->{'change_interface'}->{'ret'}, $errmeaning{$errnum{$retVal->{'change_interface'}->{'ret'}}},
# 			      "NR-VLAN {$errnum{$retVal->{'change_interface'}->{'ret'}}}".$dev."/".$port." vlan-$vlan",
# 			      $retVal->{'change_interface'}->{'err'})
#       if ($retVal->{'change_interface'}->{'ret'} < 1);

#     return 1;
#   }

#   goto REMOVE_VLAN if ( $#$delvlans >= 0 || ($voicevlan && $thisVlan != $voicevlan));

#   # New-code _START_
#   my %int_config = ('change_interface' => [{'truncated-if' => $if,
# 					    'native-vlan' => '',
# 					    'allowed-vlan' => '',
# 					    'switchport-mode' => '',
# 					    'inline-power' => '',
# 					    'voice-vlan' => '',
# 					    }
# 					  ],
# 		    );
#   $retVal = $devHandle->change_config(\%int_config);
#   return netdb_mail_wrapper($retVal->{'change_interface'}->{'ret'}, $errmeaning{$errnum{$retVal->{'change_interface'}->{'ret'}}},
# 			    "NR-VLAN {$errnum{$retVal->{'change_interface'}->{'ret'}}}".$dev."/".$port." vlan-$vlan",
# 			    $retVal->{'change_interface'}->{'err'})
#       if ($retVal->{'change_interface'}->{'ret'} < 1);
#   # New-code _END_

#   goto WRITE_MEM;

# REMOVE_VLAN:

#   # New-code _START_
#   my %int_config = ( 'change_interface' => [{'truncated-if' => $if,
# 					     'voice-vlan' => '',
# 					     'allowed-vlan-remove' => $thisVlan,
# 					     'inline-power' => '',
# 					    }
# 					   ],
# 		    );
#   $retVal = $devHandle->change_config(\%int_config);
#   return netdb_mail_wrapper($retVal->{'change_interface'}->{'ret'}, $errmeaning{$errnum{$retVal->{'change_interface'}->{'ret'}}},
# 			    "NR-VLAN {$errnum{$retVal->{'change_interface'}->{'ret'}}}".$dev."/".$port." vlan-$vlan",
# 			    $retVal->{'change_interface'}->{'err'})
#       if ($retVal->{'change_interface'}->{'ret'} < 1);

#   # New-code _END_
  

# WRITE_MEM:
#   return 1;
# }

sub getExpectHandle {
    my ($dev, $port, $type) = @_;
      my (@passwd, @login_telnet_Arr, @enable_telnet_Arr);
      my (@login_ssh_Arr, @enable_ssh_Arr, $AuthInfo);
      my ($devHandle, $res, $ref);

      # login_telnet
      open(P_READ, $CMU::WebInt::config::PORTADMIN_LOGIN_TELNET_PASSWD)
	or die "Unable to open $CMU::WebInt::config::PORTADMIN_LOGIN_TELNET_PASSWD";
      @passwd = <P_READ>;
      close(P_READ);
      foreach my $pele (@passwd) {
	  chomp($pele);
	  push(@login_telnet_Arr, {'password' => $pele});
      }
      @passwd = ();

      # login_ssh
      open(P_READ, $CMU::WebInt::config::PORTADMIN_LOGIN_SSH_PASSWD)
	or die "Unable to open $CMU::WebInt::config::PORTADMIN_LOGIN_SSH_PASSWD";
      @passwd = <P_READ>;
      close(P_READ);
      foreach my $pele (@passwd) {
	  chomp($pele);
	  push(@login_ssh_Arr, {'password' => $pele});
      }
      @passwd = ();

      # enable_telnet
      open(E_READ,$CMU::WebInt::config::PORTADMIN_ENABLE_TELNET_PASSWD)
	or die "Unable to open $CMU::WebInt::config::PORTADMIN_ENABLE_TELNET_PASSWD";
      @passwd = <E_READ>;
      close(E_READ);
      foreach my $pele (@passwd) {
	  chomp($pele);
	  push(@enable_telnet_Arr,{'password' => $pele});
      }
      @passwd = ();

      # enable_ssh
      open(E_READ,$CMU::WebInt::config::PORTADMIN_ENABLE_SSH_PASSWD)
	or die "Unable to open $CMU::WebInt::config::PORTADMIN_ENABLE_SSH_PASSWD";
      @passwd = <E_READ>;
      close(E_READ);
      foreach my $pele (@passwd) {
	  chomp($pele);
	  push(@enable_ssh_Arr,{'password' => $pele});
      }
      @passwd = ();


      $AuthInfo->{'login'}->{'telnet'}  = \@login_telnet_Arr;
      $AuthInfo->{'enable'}->{'telnet'} = \@enable_telnet_Arr;
      $AuthInfo->{'login'}->{'ssh'} 	= \@login_ssh_Arr;
      $AuthInfo->{'enable'}->{'ssh'} 	= \@enable_ssh_Arr;

#    warn __FILE__ . ":" . __LINE__ . ": device type is $type\n";

      if ($type =~ /^35.*-XL$/ || $type eq "2900" || $type eq "4948") {
	  $devHandle = new CMU::NetConf::Manage3500();
      } elsif ($type eq "2950" || $type eq "3750") {
	  $devHandle = new CMU::NetConf::Manage3750();
      } elsif ($type eq "6509IOS") {
	  $devHandle = new CMU::NetConf::Manage6000();
      } elsif ($type =~ /6509/) {
	  return $errcodes{EDEVTYPE};
      } else {
	  return $errcodes{EDEVTYPE};
      }

      ($res, $ref) = $devHandle->connect($dev, {ssh_opt => '-a -x -o UserKnownHostsFile=/dev/null'}, $AuthInfo);
      return ($errcodes{ECONN},$ref) if ($res < 1);

      return (1, $devHandle);
}

sub netdb_mail_wrapper {
    my ($errNum, $errMsg, $mailSub, $extra, $cc) = @_;
    $errMsg .= "\n$extra";
    CMU::Netdb::netdb_mail("", $errMsg, $mailSub, $cc);
    return $errNum;
}

sub wlog {
  my ($op, $status) = @_;
  if (defined(&main::wlog)) {
    main::wlog("$op:$status");
  } else {
    open(LOGFILE, ">/home/netreg/logs/portadmin.log.$$") ||
      die("Can't open /home/netreg/logs/portadmin.log.$$");
    flock(LOGFILE, LOCK_EX);
    my $t = time();
    print LOGFILE "$t:$op:$status\n";
    warn "$op:$status\n" if ($debug);
    close(LOGFILE);
    flock(LOGFILE, LOCK_UN);
  }
}

1;
