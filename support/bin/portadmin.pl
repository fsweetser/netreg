#!/usr/bin/perl
#
# Script for automating hub/switch updates.
#
#
# Copyright (c) 2000-2004 Carnegie Mellon University. All rights reserved.
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
# $Id: portadmin.pl,v 1.44 2008/03/27 19:42:43 vitroth Exp $
#

use strict;
use vars qw($result $debug $audit $destructive $singledev $nolock $clearlock $noop @errors @successes);
use warnings;
use lib '/usr/ng/lib/perl5';
use Data::Dumper;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}


use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;
use CMU::Netdb::helper;
use CMU::portadmin;
use BER;
use SNMP_Session;
use SNMP_util;
use Getopt::Long;
use Fcntl ':flock';		# import LOCK_* constants

#$CMU::Netdb::primitives::debug = 0;
$SNMP_Session::default_timeout = 1.0;
$SNMP_Session::default_retries = 1;
$SNMP_Session::default_backoff = 1.0;


sub main {
  my ($dbh, $pass, $sth, $rows, $world, $query, $devcount, $portcount);
  my $now = time();

  $dbh = lw_db_connect();

  if (!$dbh) {
    &wlog("main","Unable to connect to database.");
    die "Unable to connect to database.\n";
  }

  # If processing a single device, don't mess with the locks at all
  $nolock = 1 if (defined $singledev);
  
  # If we were told to clear an existing lock, blow it away and move on.
  killLock($dbh, 'PORTADMIN_LOCK') if ($clearlock);

  # Get a lock (unless we were told not to, or are processing a single device)
  getLock($dbh, 'PORTADMIN_LOCK', 'portadmin.pl', 60) unless ($nolock || $singledev);


  # Ok, now we're going to start pulling in data and building our view of the $world.
  # i.e. what state do we believe everything is in, and what changes do we believe we need to make
  # Our world view will be stored in $world, in this form:

  #     $world->{$devicename}{$portname} = { "meta" => { "outletid" => "OID",
  #                                                      "outletversion" => timestamp,
  #                                                      "vlandata" => [
  #                                                                      {
  #                                                                         "type" => "normal|permanent",
  #                                                                         "ovm-id" => outlet_vlan_membership.id,
  #                                                                         "ovm-version" => outlet_vlan_membership.version,
  #                                                                         "vlanid" => outlet_vlan_membership.vlan,
  #                                                                         "outlet" => outlet_vlan_membership.outlet,
  #                                                                         "trunktype" => outlet_vlan_membership.type,
  #                                                                         "action" => outlet_vlan_membership.status,
  #                                                                         "vlanno" => vlan.number,
  #                                                    },
  #                                          "current" => { "status" => "enabled|partitioned",
  # 						  	      "primaryvlan" => "vlan-number",
  # 							      "speed" => "auto|10|100",
  # 							      "duplex" => "auto|half|full",
  # 							      "port-security" => "enabled|disabled",
  # 							      "port-fast" => "enabled|disabled" },
  # 					       "new" => { ... },
  # 				             }


  # first, perform query to get all entries requiring activations
  $query = "outlet.attributes='' AND FIND_IN_SET('activated',outlet.flags) AND NOT FIND_IN_SET('suspend',outlet.flags) AND outlet.status='partitioned' AND outlet.device!=''";
  $query .= " AND machine.host_name = ".$dbh->quote($singledev) if ($singledev);

  $rows = CMU::Netdb::list_outlets_devport($dbh, "netreg", $query);

  if (!ref $rows) {
    &wlog("error: $rows");
    killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
    exit;
  }

  if ($#$rows == 0) {
    &wlog("No ports requiring activation.") if ($debug);
  } else {
    &wlog("Processsing activations.") if ($debug);
    my $map = CMU::Netdb::makemap($rows->[0]);
    shift @$rows;
    foreach (@$rows) {
      my $dev = $_->[$map->{'machine.host_name'}];
      my $port = $_->[$map->{'outlet.port'}];
      $world->{$dev}{$port}{meta}{outletid} = $_->[$map->{'outlet.id'}];
      $world->{$dev}{$port}{meta}{outletversion} = $_->[$map->{'outlet.version'}];
      $world->{$dev}{$port}{meta}{type} = "normal";
      $world->{$dev}{$port}{current}{status} = 'partitioned';
      $world->{$dev}{$port}{new}{status} = 'enabled';
    }
  }

  # perform query to get all entries requiring deactivations
  $query = "outlet.attributes='deactivate' AND NOT FIND_IN_SET('activated',outlet.flags) AND NOT FIND_IN_SET('permanent',outlet.flags) AND outlet.status='enabled' AND outlet.device!=''";
  $query .= " AND machine.host_name = ".$dbh->quote($singledev) if ($singledev);

  $rows = CMU::Netdb::list_outlets_devport($dbh, "netreg", $query);
  if (!ref $rows) {
    &wlog("error: $rows");
    killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
    exit;
  }
  if ($#$rows == 0) {
    &wlog("No ports requiring deactivation.") if ($debug);
  } else {
    &wlog("Processing deactivations.") if ($debug);
    my $map = CMU::Netdb::makemap($rows->[0]);
    shift @$rows;
    foreach (@$rows) {
      my $dev = $_->[$map->{'machine.host_name'}];
      my $port = $_->[$map->{'outlet.port'}];
      $world->{$dev}{$port}{meta}{outletid} = $_->[$map->{'outlet.id'}];
      $world->{$dev}{$port}{meta}{outletversion} = $_->[$map->{'outlet.version'}];
      $world->{$dev}{$port}{meta}{type} = "normal";
      $world->{$dev}{$port}{current}{status} = 'enabled';
      $world->{$dev}{$port}{new}{status} = 'partitioned';
    }
  }

  # perform query to get all entries requiring "permanent" activations
  $query = "outlet.attributes='' AND FIND_IN_SET('permanent',outlet.flags) AND FIND_IN_SET('activated',outlet.flags) AND NOT FIND_IN_SET('suspend',outlet.flags) AND outlet.status='partitioned' AND outlet.device!=''";
  $query .= " AND machine.host_name = ".$dbh->quote($singledev) if ($singledev);

  $rows = CMU::Netdb::list_outlets_devport($dbh, "netreg", $query);

  if (!ref $rows) {
    &wlog("error: $rows");
    killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
    exit;
  }
  if ($#$rows == 0) {
    &wlog("No ports requiring \"permanent\" activation.") if ($debug);
  } else {
    &wlog("Processing \"permanent\" activations.") if ($debug);
    my $map = CMU::Netdb::makemap($rows->[0]);
    shift @$rows;
    foreach (@$rows) {
      my $dev = $_->[$map->{'machine.host_name'}];
      my $port = $_->[$map->{'outlet.port'}];
      $world->{$dev}{$port}{meta}{outletid} = $_->[$map->{'outlet.id'}];
      $world->{$dev}{$port}{meta}{outletversion} = $_->[$map->{'outlet.version'}];
      $world->{$dev}{$port}{meta}{type} = "permanent";
      $world->{$dev}{$port}{current}{status} = 'partitioned';
      $world->{$dev}{$port}{new}{status} = 'enabled';
    }

  }
	
  # perform query to get all entries requiring "permanent" deactivations
  $query = "outlet.attributes='' AND NOT FIND_IN_SET('activated',outlet.flags) AND FIND_IN_SET('permanent',outlet.flags) AND outlet.status='enabled' AND outlet.device!=''";
  $query .= " AND machine.host_name = ".$dbh->quote($singledev) if ($singledev);

  $rows = CMU::Netdb::list_outlets_devport($dbh, "netreg", $query);

  if (!ref $rows) {
    &wlog("error: $rows");
    killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
    exit;
  }
  if ($#$rows == 0) {
    &wlog("No ports requiring \"permanent\" deactivation.") if ($debug);
  } else {
    &wlog("Processing \"permanent\" deactivations.") if ($debug);
    my $map = CMU::Netdb::makemap($rows->[0]);
    shift @$rows;
    foreach (@$rows) {
      my $dev = $_->[$map->{'machine.host_name'}];
      my $port = $_->[$map->{'outlet.port'}];
      $world->{$dev}{$port}{meta}{outletid} = $_->[$map->{'outlet.id'}];
      $world->{$dev}{$port}{meta}{outletversion} = $_->[$map->{'outlet.version'}];
      $world->{$dev}{$port}{meta}{type} = "permanent";
      $world->{$dev}{$port}{current}{status} = 'enabled';
      $world->{$dev}{$port}{new}{status} = 'partitioned';
    }

  }

  # query to get all entries requiring VLAN updates
  # fix me, we don't do voice at this time.
  foreach $query (
		  "outlet_vlan_membership.status IN ('request', 'delete') AND FIND_IN_SET('activated', outlet.flags) AND outlet.attributes = '' AND outlet.device != 0 AND NOT ISNULL(outlet.device) AND outlet_vlan_membership.type in ('primary', 'other') order by outlet_vlan_membership.status",
		  "outlet_vlan_membership.status IN ('error', 'errordelete') AND TO_DAYS(NOW()) - TO_DAYS(outlet_vlan_membership.version) <= 2 AND FIND_IN_SET('activated',outlet.flags) AND outlet.attributes = '' AND outlet.device != 0 AND NOT ISNULL(outlet.device)"
		 ) {
    $rows = CMU::Netdb::list_outlet_vlan_memberships($dbh, "netreg", $query); 
    
    if (!ref $rows) {
      &wlog("error: $rows");
      killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
      exit;
    }
    if ($#$rows == 0) {
      &wlog("No ports requiring vlan updates.") if ($debug);
    } else {
      &wlog("Processing vlan updates.") if ($debug);
      my $map = CMU::Netdb::makemap($rows->[0]);
      shift @$rows;
      foreach (@$rows) {
	&wlog(__FILE__ . ':' . __LINE__ . ":  Processing " . join('|', @$_) . " \n") if ($debug);
	my $oref = CMU::Netdb::list_outlets_devport($dbh, "netreg", "outlet.id = ".$_->[$map->{'outlet.id'}]);
	if (!ref $oref) {
	  &wlog("error: $oref");
	  killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
	  exit;
	}
	if ($#$oref == 0) {
	  &wlog(__FILE__ . ':' . __LINE__ . " error: Unable to fetch device info for outlet ".$_->[$map->{'outlet.id'}]);
	  killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
	  exit;
	}
	my $omap = CMU::Netdb::makemap($oref->[0]);
	my $dev = $oref->[1][$omap->{'machine.host_name'}];
	next if ($singledev && lc($dev) ne lc($singledev));
	my $port = $oref->[1][$omap->{'outlet.port'}];
	$world->{$dev}{$port}{meta}{outletid} = $_->[$map->{'outlet.id'}];
	$world->{$dev}{$port}{meta}{outletversion} = $_->[$map->{'outlet.version'}];
	my $vdata = {};
	$world->{$dev}{$port}{meta}{vlandata} = [] if (! defined $world->{$dev}{$port}{meta}{vlandata});
	$vdata->{'outlet'} = $_->[$map->{'outlet_vlan_membership.outlet'}];
	$vdata->{'type'} = $_->[$map->{'outlet_vlan_membership.type'}];
	$vdata->{'trunktype'} = $_->[$map->{'outlet_vlan_membership.trunk_type'}];
	$vdata->{'action'} = $_->[$map->{'outlet_vlan_membership.status'}];
	$vdata->{'vlanid'} = $_->[$map->{'outlet_vlan_membership.vlan'}];
	$vdata->{'vlanno'} = $_->[$map->{'vlan.number'}];
	$vdata->{'ovm-id'} = $_->[$map->{'outlet_vlan_membership.id'}];
	$vdata->{'ovm-version'} = $_->[$map->{'outlet_vlan_membership.version'}];
	push(@{$world->{$dev}{$port}{meta}{vlandata}}, $vdata);
	
	&wlog(__FILE__ . ':' . __LINE__ . ": Processing request for $_->[$map->{'outlet_vlan_membership.type'}] vlan\n"); 
	if ($_->[$map->{'outlet_vlan_membership.type'}] eq 'primary') {
	  &wlog(__FILE__ . ':' . __LINE__ . ":  Processing primary vlan info " . Data::Dumper->Dump([$_],[qw(data)]) . "\n"); 
	  if ($_->[$map->{'outlet_vlan_membership.status'}] eq 'request') {
	    $world->{$dev}{$port}{new}{primaryvlan} = $_->[$map->{'vlan.number'}];
	    $world->{$dev}{$port}{new}{status} = 'enabled';
	  } else {
	    $world->{$dev}{$port}{new}{noprimaryvlan} = $_->[$map->{'vlan.number'}];
	    $world->{$dev}{$port}{new}{status} = 'disabled';
	  }
	} else {
	  &wlog(__FILE__ . ':' . __LINE__ . ":  Setting up trunk\n");
	  # FIXME
	  # Trunks need certain attributes set and cleared.  They are set up or cleared here
	  # and may be over-ridden later in the attribute code.
	  if ($_->[$map->{'outlet_vlan_membership.status'}] eq 'request') {
	    # Adding a vlan, set up all the settings for a trunk
	    $world->{$dev}{$port}{new}{'port-security'} = 'disabled';
	    $world->{$dev}{$port}{new}{'nonegotiate'} = 'disable';
	    $world->{$dev}{$port}{new}{'vlan-encapsulation'} = 'dot1q';
	    $world->{$dev}{$port}{new}{'switchport-mode'} = 'trunk';
	    $world->{$dev}{$port}{new}{'cdp'} = 'enabled';
	    $world->{$dev}{$port}{new}{'port-fast'} = 'disabled';
	    $world->{$dev}{$port}{new}{'spanning-tree-rootguard'} = 'enabled';
	    $world->{$dev}{$port}{new}{'igmp-max-groups'} = 'disabled';
	    $world->{$dev}{$port}{new}{'keepalive'} = 'enabled';
	    $world->{$dev}{$port}{new}{'native-vlan'} = '$world->{$dev}{$port}{database}{primaryvlan}';
	    $world->{$dev}{$port}{new}{'access-vlan'} = '$world->{$dev}{$port}{database}{primaryvlan}';
	    $world->{$dev}{$port}{new}{'allowed-vlan'} = "reset";
	    $world->{$dev}{$port}{new}{'ip-address'} = 'disabled';
	  } else {
	    # Removing a vlan, check to see if this is still a trunk
	    warn __FILE__ . ":" . __LINE__ . ": Deleting a vlan\n";
	    my $tlist =  CMU::Netdb::list_outlet_vlan_memberships($dbh, "netreg",
								  "((outlet.id = $_->[$map->{'outlet.id'}]) and " . 
								  "(outlet_vlan_membership.type != 'primary') and " .
								  "(outlet_vlan_membership.status IN ('request', 'active')))");
	    &wlog(__FILE__ . ':' . __LINE__ . ": " . Data::Dumper->Dump([$tlist],[qw(tlist)]) . "\n"); 
	    my $tlmap = CMU::Netdb::makemap(shift(@$tlist));
	    if ((scalar @$tlist) == 0) {
	      warn __FILE__ . ":" . __LINE__ . ": Tearing down trunkset\n" if ($debug);
	      # There are no more vlans assigned, tear down the trunk
	      $world->{$dev}{$port}{new}{'switchport-mode'} = "access";
	      $world->{$dev}{$port}{new}{'nonegotiate'} = "enabled";
	      $world->{$dev}{$port}{new}{'port-security'} = "enabled";
	      $world->{$dev}{$port}{new}{'ip-address'} = "disabled";
	      $world->{$dev}{$port}{new}{'keepalive'} = "disabled";
	      $world->{$dev}{$port}{new}{'cdp'} = "disabled";
	      $world->{$dev}{$port}{new}{'port-fast'} = "disabled";
	      $world->{$dev}{$port}{new}{'spanning-tree-rootguard'} = "enabled";
	      $world->{$dev}{$port}{new}{'igmp-max-groups'} = "50";
	      $world->{$dev}{$port}{new}{'native-vlan'} = '';
	      $world->{$dev}{$port}{new}{'access-vlan'} = '$world->{$dev}{$port}{database}{primaryvlan}';
	      $world->{$dev}{$port}{new}{'allowed-vlan'} = "";
	    } 
	    # set the allowed vlans to be those
	    $world->{$dev}{$port}{new}{'allowed-vlan'} = "reset";
	  }
	}
      }
    }
  }


  # Find all attributes that are newer then the last time their device was updated
  $query = "attribute.version > trunkset_machine_presence.last_update";
  $query .= " AND machine.host_name = ".$dbh->quote($singledev) if ($singledev);

  $rows = CMU::Netdb::list_outlets_attributes_devport($dbh, "netreg", $query);

  if (!ref $rows) {
    &wlog("error: $rows");
    killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
    exit;
  }
  if ($#$rows == 0) {
    &wlog("No ports requiring attribute updates.") if ($debug);
  } else {
    &wlog("Processing attribute updates.") if ($debug);
    my $map = CMU::Netdb::makemap($rows->[0]);
    shift @$rows;
    foreach (@$rows) {
      my $dev = $_->[$map->{'machine.host_name'}];
      my $port = $_->[$map->{'outlet.port'}];
      $world->{$dev}{$port}{meta}{outletid} = $_->[$map->{'outlet.id'}];
      $world->{$dev}{$port}{meta}{outletversion} = $_->[$map->{'outlet.version'}];

      if ($_->[$map->{'attribute_spec.name'}] eq 'port-speed') {
	print "Setting speed to ".$_->[$map->{'attribute.data'}]."\n" if ($debug >= 4);
	$world->{$dev}{$port}{new}{speed} = $_->[$map->{'attribute.data'}];
      }
      if ($_->[$map->{'attribute_spec.name'}] eq 'CDP') {
	print "Setting CDP to ".$_->[$map->{'attribute.data'}]."\n" if ($debug >= 4);
	$world->{$dev}{$port}{new}{cdp} = $_->[$map->{'attribute.data'}];
      }
      if ($_->[$map->{'attribute_spec.name'}] eq 'port-duplex') {
	print "Setting duplex to ".$_->[$map->{'attribute.data'}]."\n" if ($debug >= 4);
	$world->{$dev}{$port}{new}{duplex} = $_->[$map->{'attribute.data'}];
      }
      if ($_->[$map->{'attribute_spec.name'}] eq 'Trunk Mode') {
	print "Setting Trunk Mode to ".$_->[$map->{'attribute.data'}]."\n" if ($debug >= 4);
	$world->{$dev}{$port}{new}{'switchport-mode'} = $_->[$map->{'attribute.data'}];
      }
      if ($_->[$map->{'attribute_spec.name'}] eq 'Port Security Mode') {
	print "Setting port-security to ".$_->[$map->{'attribute.data'}]."\n" if ($debug >= 4);
	$world->{$dev}{$port}{new}{'port-security'} = $_->[$map->{'attribute.data'}];
      }
      if ($_->[$map->{'attribute_spec.name'}] eq 'Port-Fast Mode') {
	print "Setting port-fast to ".$_->[$map->{'attribute.data'}]."\n" if ($debug >= 4);
	$world->{$dev}{$port}{new}{'port-fast'} = $_->[$map->{'attribute.data'}];
      }
      if ($_->[$map->{'attribute_spec.name'}] eq 'port-label') {
	print "Setting description to ".$_->[$map->{'attribute.data'}]."\n" if ($debug >= 4);
	$world->{$dev}{$port}{new}{'description'} = $_->[$map->{'attribute.data'}];
# Since 'none' is the default, delete the attribute so as to not confuse people.
	CMU::Netdb::delete_attribute($dbh, 'netreg', $_->[$map->{'attribute.id'}], $_->[$map->{'attribute.version'}])
	    if ($_->[$map->{'attribute.data'}] eq 'none');
      }
    }
  }

  $devcount = 0;
  foreach my $dev (keys %$world) {
    $devcount++;
    foreach my $port (keys %{$world->{$dev}}) {
      $portcount++;
      fetch_fulldata($dbh, $world->{$dev}{$port});
    }
  }


  wlog("Complete view of work to be done: ".Data::Dumper->Dump([$world],['world'])) if ($debug >= 2);
  wlog("$portcount ports to be updated, on $devcount devices.") if ($debug);

  if ($debug >= 5) {
    killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);
    exit;
  }

  foreach my $dev (keys %$world) {
    # Identify the device type via the hostname
    # If unknown device, don't do anything
    # If hub, call appropriate old-style hub code
    # If switch, identify the device type via snmp
    # If not ManageIOS capable, call old style switch code
    # Otherwise, built config block for ManageIOS and update via ManageIOS

    if ($dev =~ /UNKNOWN-DEVICE/) {
      # Skipping all outlets on UNKNOWN-DEVICE*
      my $msg = "Outlets exist with $dev as their device.  Total count is ".scalar(keys(%{$world->{$dev}}));
      wlog($msg) if ($debug);
      push @errors, $msg;
    } elsif ($dev =~ /\.HB\./) {
      # Update via old-style hub code
      my $error = 0;
      foreach my $port (keys %{$world->{$dev}}) {
	my $id = $world->{$dev}{$port}{meta}{outletid};
	my $version = $world->{$dev}{$port}{meta}{outletversion};

	# Are we enabling/disabling the port?
	if ($world->{$dev}{$port}{new}{status}) {
	  my $state = $world->{$dev}{$port}{new}{status} eq "enabled" ? 1 : 0;

	  # Make sure we're not in NO-OP mode.
	  if (!$noop) {
	    if ($state == 1) {
	      &wlog("Activating $dev/$port") if ($debug);
	    } else {
	      &wlog("Deactivating $dev/$port") if ($debug);
	    }

	    if (CMU::portadmin::setHubPort($dev,$port, $state)) {
	      # We set the port successfully via SNMP.  Update the outlet in the database.
	      my ($res, $ret);
	      if ($state == 1) {
		($res, $ret) = 
		  CMU::Netdb::modify_outlet($dbh, "netreg", $id, $version, {"status" => "enabled"}, 9);
		push @successes, "$dev / $port (OID $id): Activated (SNMP)";
	      } else {
		($res, $ret) = 
		  CMU::Netdb::modify_outlet($dbh, "netreg", $id, $version, {"status" => "partitioned"}, 9);
		push @successes, "$dev / $port (OID $id): Deactivated (SNMP)";
	      }

	      if ($res < 1) {
		my $msg = "$dev / $port (OID: $id): Activation/Deactivation successful, but an error occured while updating the database: " . $CMU::Netdb::errors::errmeanings{$res};
		$msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $errcodes{EDB});
		$msg .= " [".join(',', @$ret)."]";
		&wlog($msg);
		push @errors, $msg;
		$error++;
	      }

	    } else {
	      push @errors, "$dev / $port (OID: $id): Unable to update to state $world->{$dev}{$port}{new}{status}.  Skipping additional updates for ports on this device.";
	      $error++;
	      last;
	    }
	  } else {
	    # In NO-OP mode, just report what would be done.
	    if ($state == 1) {
	      print "Would activate Hub/Port: $dev/$port\n";
	    } else {
	      print "Would deactivate Hub/Port: $dev/$port\n";
	    }
	  }

	} else {
	  # No other settings are relevant for hubs.
	  # FIXME: Should we just ignore other settings, or log an error?
	  # For primary-vlan changes, pretend me made the change
	  if ($world->{$dev}{$port}{meta}{vlandata}) {
	    my ($vl);
	    foreach $vl (@{$world->{$dev}{$port}{meta}{vlandata}}) {
	      my ($res, $ret);
	      my $id = $vl->{'ovm-id'};
	      my $ver = $vl->{'ovm-version'};
	      my %fields = ("outlet" => $vl->{'outlet'},
			    "vlan" => $vl->{vlanid},
			    "type" => $vl->{type},
			    "trunk_type" => "none",
			    "status" => 'active');
	      if (($vl->{action} eq 'request') || ($vl->{action} eq 'error')) {
		&wlog(__FILE__ . ':' . __LINE__ . ":  updating  outlet_vlan_membership with\n" . Data::Dumper->Dump([\%fields],[qw(fields)]) . "\n") if ($debug >= 2); 
		my ($res, $ret) = CMU::Netdb::modify_outlet_vlan_membership($dbh,'netreg',$id,$ver,\%fields);
	      } else {
		&wlog(__FILE__ . ':' . __LINE__ . ":  Deleting vlan registration $id, $version\n") if ($debug >= 2); 
		my ($res, $ret) = CMU::Netdb::delete_outlet_vlan_membership($dbh,'netreg',$id,$ver);
	      }
	      push @successes, "$dev / $port (OID $id): Device doesn't support vlans, ignoring vlan request.";
	      if ($res < 1) {
		my $msg = "$dev / $port (OID: $id): Primary vlan change ignored, and an error occured while updating the database: " . $CMU::Netdb::errors::errmeanings{$res};
		$msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $errcodes{EDB});
		$msg .= " [".join(',', @$ret)."]";
		&wlog($msg);
		push @errors, $msg;
		$error++;
	      }
	    }
	  }
	}
      }

      # If we encountered no errors, and we're not in NO-OP mode, log that
      # we've processed all changes as of when we loaded the data.
      if (!$error && !$noop) {
	update_timestamp($dbh, $dev, $now);
      }

#    } elsif ($dev =~ /\.SW\./) { privileges
    } elsif (($dev =~ /\.SW\./) || ($dev =~ /\-SWITCH\./)) {

      # First, we must identify the device type.
      wlog("Identifying device type of $dev") if ($debug);
      my $devtype = CMU::portadmin::identify_device($dev);

      next if ((! defined $devtype) || ($devtype eq ""));
      warn __FILE__ . ":" . __LINE__ . ": devtype is $devtype\n" if ($debug >= 3);

      if ((defined $devtype) &&
	  ($devtype =~ /^(3508|3524|3548|2900|2950|3750|4948|6509IOS)/)) {
	# These are devices that NetConf can handle, and that support vlans.
	my ($res, $ref, $devHandle);
	($res, $devHandle) = CMU::portadmin::getExpectHandle($dev, "", $devtype);

	if ($res != 1) {
	  # Unable to get expect handle, error.
	  chomp($devHandle->{err});
	  wlog("Unable to connect to $dev.  $devHandle->{err}");
	  push @errors, "$dev: Unable to connect.  $devHandle->{err}";
	  next;
	}
##FIXME - Debugging
#	$devHandle->set_debug($debug);
	($res, $ref) = $devHandle->enable();

	if ($res != 1) {
	  wlog("Unable to enable on $dev.");
	  push @errors, "$dev: Unable to enable.";
	  next;
	}

	my $ifmap = CMU::portadmin::map_ifname_to_int($dev);
	my $error = 0;
	foreach my $port (keys %{$world->{$dev}}) {
	  # Now we build the NetConf config block and update the config.

	  my $id = $world->{$dev}{$port}{meta}{outletid};
	  my $version = $world->{$dev}{$port}{meta}{outletversion};
	  my $if = $ifmap->{'ifname'}{$port};
	  my %config;

	  if (!$if) {
	    wlog("Unable to map snmp interface $port to port on $dev.");
	    push @errors, "$dev: Unable to map snmp interface $port to port.";
	    $error++;
	    next;
	  }

	  $config{'truncated-if'} = $if;

	  if ((defined $world->{$dev}{$port}{new}{'description'}) && ($world->{$dev}{$port}{new}{'description'} ne 'none')) {
	    $config{description} = "$world->{$dev}{$port}{new}{'description'}";
	  } elsif ((defined $world->{$dev}{$port}{new}{'description'}) && ($world->{$dev}{$port}{new}{'description'} eq 'none')) {
	    $config{description} = "$world->{$dev}{$port}{meta}{labelfrom}/$world->{$dev}{$port}{meta}{labelto}";
	  } elsif ((defined $world->{$dev}{$port}{new}{status})) {
	    $config{description} = "$world->{$dev}{$port}{meta}{labelfrom}/$world->{$dev}{$port}{meta}{labelto}";
	  }


	  # Are we enabling/disabling the port?
	  if (defined $world->{$dev}{$port}{new}{status}) {
	    if ($world->{$dev}{$port}{new}{status} eq 'enabled') {
	      $config{shutdown} = "";
	    } else {
	      $config{shutdown} = "yes";
	    }
	  }

	  # Changing the port speed?
	  if (defined $world->{$dev}{$port}{new}{speed}) {
	    if ($world->{$dev}{$port}{new}{speed} eq 'auto') {
	      $config{speed} = "auto";
	    } elsif ($world->{$dev}{$port}{new}{speed} eq 'forced-10') {
	      $config{speed} = "10";
	    } elsif ($world->{$dev}{$port}{new}{speed} eq 'forced-100') {
	      $config{speed} = "100";
	    } else {
	      wlog("Unknown speed $world->{$dev}{$port}{new}{speed} for $dev / $port (OID $id)");
	      push @errors, "$dev / $port (OID $id): Unknown speed $world->{$dev}{$port}{new}{speed}.";
	      $error++;
	    }
	  }

	  # Changing the port duplex?
	  if (defined $world->{$dev}{$port}{new}{duplex}) {
	    if ($world->{$dev}{$port}{new}{duplex} eq 'auto') {
	      $config{duplex} = "auto";
	    } elsif ($world->{$dev}{$port}{new}{duplex} eq 'forced-half') {
	      $config{duplex} = "half";
	    } elsif ($world->{$dev}{$port}{new}{duplex} eq 'forced-full') {
	      $config{duplex} = "full";
	    } else {
	      wlog("Unknown duplex $world->{$dev}{$port}{new}{duplex} for $dev / $port (OID $id)");
	      push @errors, "$dev / $port (OID $id): Unknown duplex $world->{$dev}{$port}{new}{duplex}";
	      $error++;
	    }
	  }

	  # Enabling/Disabling port-security?
	  # FIXME: The maximum and aging-time parameters should be configurable somehow.
	  if (defined $world->{$dev}{$port}{new}{'port-security'}) {
	    if ($world->{$dev}{$port}{new}{'port-security'} eq 'enabled') {
	      $config{'port-security'} = 'yes';
	      $config{'port-security-maximum'} = '32';
	      $config{'port-security-aging-time'} = '1';
	      $config{'port-security-aging-type'} = 'inactivity';
	    } else {
	      $config{'port-security'} = '';
	      $config{'port-security-maximum'} = '';
	      $config{'port-security-aging-time'} = '';
	      $config{'port-security-aging-type'} = '';
	    }
	  }

	  # Enabling/Disabling port-fast?
	  if (defined $world->{$dev}{$port}{new}{'port-fast'}) {
	    if ($world->{$dev}{$port}{new}{'port-fast'} eq 'enabled') {
	      $config{'spanning-tree-portfast'} = "yes";
	    } else {
	      $config{'spanning-tree-portfast'} = "";
	    }
	  }

	  # Setting the primary vlan?
	  if (defined $world->{$dev}{$port}{new}{primaryvlan}) {
	    $world->{$dev}{$port}{new}{'primaryvlan'} = eval ($world->{$dev}{$port}{new}{'primaryvlan'})
	      if ($world->{$dev}{$port}{new}{'primaryvlan'} =~ /\$/);
	    my $res = CMU::portadmin::checkTrunk($devHandle, $world->{$dev}{$port}{new}{primaryvlan});
	    if ($res == 1) {
	      $config{'access-vlan'} = $world->{$dev}{$port}{new}{primaryvlan};
	    } else {
	      wlog("Unable to set vlan $world->{$dev}{$port}{new}{primaryvlan} on $dev/$port: Vlan not configured");
	      push @errors, "$dev / $port (OID $id): Unable to set vlan $world->{$dev}{$port}{new}{primaryvlan}: Vlan not configured";
	      $error++;
	    }
	  }

	  # Setting the acccess vlan in a trunk?
	  if (defined $world->{$dev}{$port}{new}{'access-vlan'}) {
	    $world->{$dev}{$port}{new}{'access-vlan'} = eval ($world->{$dev}{$port}{new}{'access-vlan'})
	      if ($world->{$dev}{$port}{new}{'access-vlan'} =~ /\$/);
	    my $res = CMU::portadmin::checkTrunk($devHandle, $world->{$dev}{$port}{new}{'access-vlan'});
	    if ($res == 1) {
	      $config{'access-vlan'} = $world->{$dev}{$port}{new}{'access-vlan'};
	    } else {
	      wlog("Unable to set vlan $world->{$dev}{$port}{new}{primaryvlan} on $dev/$port: Vlan not configured");
	      push @errors, "$dev / $port (OID $id): Unable to set vlan $world->{$dev}{$port}{new}{'access-vlan'}: Vlan not configured";
	      $error++;
	    }
	  }

	  # Setting CDP?
	  if (defined $world->{$dev}{$port}{new}{'cdp'}) {
	    if ($world->{$dev}{$port}{new}{'cdp'} eq 'enabled') {
	      $config{'cdp'} = "yes";
	    } else {
	      $config{'cdp'} = "";
	    }
	  }

	  # Setting nonegotiate?
	  if (defined $world->{$dev}{$port}{new}{'nonegotiate'}) {
	    if ($world->{$dev}{$port}{new}{'nonegotiate'} eq 'enabled') {
	      $config{'nonegotiate'} = "yes";
	    } else {
	      $config{'nonegotiate'} = "";
	    }
	  }

	  # Setting switchport mode?
	  if (defined $world->{$dev}{$port}{new}{'switchport-mode'}) {
	    if ($world->{$dev}{$port}{new}{'switchport-mode'} eq 'disabled') {
	      $config{'switchport-mode'} = "";
	    } else {
	      $config{'switchport-mode'} = "$world->{$dev}{$port}{new}{'switchport-mode'}";
	    }
	  }
	  
      # Setting encapsulation?
      if (defined $world->{$dev}{$port}{new}{'vlan-encapsulation'}) {
        if ($world->{$dev}{$port}{new}{'vlan-encapsulation'} eq 'disabled') {
          $config{'vlan-encapsulation'} = "";
        } else {
          $config{'vlan-encapsulation'} = "$world->{$dev}{$port}{new}{'vlan-encapsulation'}";
        }
      }


	  # Enabling/disabling rootguard?
	  if (defined $world->{$dev}{$port}{new}{'spanning-tree-rootguard'}) {
	    if ($world->{$dev}{$port}{new}{'spanning-tree-rootguard'} eq 'enabled') {
	      $config{'spanning-tree-rootguard'} = "yes";
	    } else {
	      $config{'spanning-tree-rootguard'} = "";
	    }
	  }

	  # Enabling/disabling igmp max groups?
	  if (defined $world->{$dev}{$port}{new}{'igmp-max-groups'}) {
	    if ($world->{$dev}{$port}{new}{'igmp-max-groups'} eq 'disabled') {
	      $config{'igmp-max-groups'} = "";
	    } else {
	      $config{'igmp-max-groups'} = "$world->{$dev}{$port}{new}{'igmp-max-groups'}";
	    }
	  }

	  # Enabling/disabling keepalive?
	  if (defined $world->{$dev}{$port}{new}{'keepalive'}) {
	    if ($world->{$dev}{$port}{new}{'keepalive'} eq 'enabled') {
	      $config{'keepalive'} = "yes";
	    } else {
	      $config{'keepalive'} = "";
	    }
	  }

	  # Setting the native vlan?
	  if (defined $world->{$dev}{$port}{new}{'native-vlan'}) {
	    if ($world->{$dev}{$port}{new}{'native-vlan'} =~ /\$/) {
	      $world->{$dev}{$port}{new}{'native-vlan'} = eval ($world->{$dev}{$port}{new}{'native-vlan'});
	    }
	    warn __FILE__ . ":" . __LINE__ . ": setting native-vlan to $world->{$dev}{$port}{new}{'native-vlan'}\n";
	    if ($world->{$dev}{$port}{new}{'native-vlan'} eq "") {
	      $config{'native-vlan'} = "";
	    } else {
	      my $res = CMU::portadmin::checkTrunk($devHandle, $world->{$dev}{$port}{new}{'native-vlan'});
	      if ($res == 1) {
		$config{'native-vlan'} = $world->{$dev}{$port}{new}{'native-vlan'};
	      } else {
		wlog("Unable to set vlan $world->{$dev}{$port}{new}{'native-vlan'} on $dev/$port: Vlan not configured");
		push @errors, "$dev / $port (OID $id): Unable to set vlan $world->{$dev}{$port}{new}{'native-vlan'}: Vlan not configured";
		$error++;
	      }
	    }
	  }

	  # Setting allowed vlans?
	  if (defined $world->{$dev}{$port}{new}{'allowed-vlan'}) {
	    if ($world->{$dev}{$port}{new}{'allowed-vlan'} eq "") {
	      $config{'allowed-vlan'} = ""; 
	    } else {
	      if ((scalar(@{$world->{$dev}{$port}{database}{'vlans'}})) > 1) {
		foreach (@{$world->{$dev}{$port}{database}{'vlans'}}) {
		  my $res = CMU::portadmin::checkTrunk($devHandle, $_);
		  if ($res == 1) {
		    $config{'allowed-vlan'} = $_ .
		      (defined $config{'allowed-vlan'} ? ",$config{'allowed-vlan'}" : "");
		  } else {
		    wlog("Unable to set vlan $_ on $dev/$port: Vlan not configured");
		    push @errors, "$dev / $port (OID $id): Unable to set vlan $_: Vlan not configured";
		    $error++;
		  }
		}
	      } else {
		$config{'allowed-vlan'} = ""; 
	      }
	    }
	  }

	  # Deleting allowed vlans?
	  if (defined $world->{$dev}{$port}{new}{'allowed-vlan-delete'}) {
	    foreach (split(/,/, $world->{$dev}{$port}{new}{'allowed-vlan-delete'})) {
	      $config{'allowed-vlan-remove'} = $_ .
		(defined $config{'allowed-vlan-remove'} ? ",$config{'allowed-vlan-remove'}" : "");
	    }
	  }

	  # Enabling/disabling IP Address?
	  if (defined $world->{$dev}{$port}{new}{'ip-address'}) {
	    if ($world->{$dev}{$port}{new}{'ip-address'} eq 'disabled') {
	      $config{'ip-address'} = "";
	    } else {
	      $config{'ip-address'} = "$world->{$dev}{$port}{new}{'ip-address'}";
	    }
	  }


	  wlog("Built config block for $dev/$port: \n".Data::Dumper->Dump([\%config, $world],['config', 'world']))
	    if ($debug);

	  warn __FILE__ . ":" . __LINE__ . ": Current Information is \n" . Data::Dumper->Dump([$devHandle->get_config({get_snmp => {},
														      get_interface => {}})],[qw(config)]) . "\n" if ($debug >= 5); 
	  if (!$noop) {
	    $res = $devHandle->change_config({'change_interface' => [\%config]});

#	    warn __FILE__ . ":" . __LINE__ . ": change_config returned \n" .
#	      Data::Dumper->Dump([$res],[qw(res)]) . "\n"; 
	    if ($res->{'change_interface'}{ret} < 1) {
	      my $msg = "$dev / $port (OID $id): Error updating via NetConf: ".$res->{'change_interface'}{err};
	      $msg .= "\nNetConf config block was:\n".Data::Dumper->Dump([\%config],['$config']);
	      wlog($msg);
	      push @errors, $msg;
	      $error++;
	      # FIXME we should mark the errors on vlan updates here...
	    } else {
	      # For activation/deactivation requests, we go ahead and mark it complete.
	      if ($world->{$dev}{$port}{new}{status}) {
		my ($res, $ret);
		if ($world->{$dev}{$port}{new}{status} eq 'enabled') {
		  ($res, $ret) = CMU::Netdb::modify_outlet($dbh, "netreg", $id, $version, {"status" => "enabled"}, 9);
		  push @successes, "$dev / $port (OID $id): Activated (NetConf)";
		} else {
		  ($res, $ret) = CMU::Netdb::modify_outlet($dbh, "netreg", $id, $version, {"status" => "partitioned"}, 9);
		  push @successes, "$dev / $port (OID $id): Deactivated (NetConf)";
		}
		if ($res < 1) {
		  my $msg = "$dev / $port (OID: $id): Activation/Deactivation successful, but an error occured while updating the database: " . $CMU::Netdb::errors::errmeanings{$res};
		  $msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $errcodes{EDB});
		  $msg .= " [".join(',', @$ret)."]";
		  &wlog($msg);
		  push @errors, $msg;
		  $error++;
		}
	      }

	      # For vlan changes, mark them complete.
	      if ($world->{$dev}{$port}{meta}{vlandata}) {
		my ($vl);
		foreach $vl (@{$world->{$dev}{$port}{meta}{vlandata}}) {
		  &wlog(__FILE__ . ':' . __LINE__ . ": Marking database for \n" . Data::Dumper->Dump([$vl],[qw(vl)]) . "\n") if ($debug); 
		  my ($res, $ret);
		  my $id = $vl->{'ovm-id'};
		  my $ver = $vl->{'ovm-version'};
		  my %fields = ("outlet" => $vl->{'outlet'},
				"vlan" => $vl->{vlanid},
				"type" => $vl->{type},
				"trunk_type" => $vl->{'trunktype'},
				"status" => 'active');
		  if (($vl->{action} eq 'request') || ($vl->{action} eq 'error')) {
		    &wlog(__FILE__ . ':' . __LINE__ . ":  updating  outlet_vlan_membership with\nid = $id\nversion = $ver\n" . Data::Dumper->Dump([\%fields],[qw(fields)]) . "\n") if ($debug >= 2); 
		    
		    ($res, $ret) = CMU::Netdb::modify_outlet_vlan_membership($dbh,'netreg',$id,$ver,\%fields);
		    push @successes, "$dev / $port (OID $id): $vl->{type} vlan set to $vl->{vlanno}\n";
		  } else {
		    ($res, $ret) = CMU::Netdb::delete_outlet_vlan_membership($dbh,'netreg',$id,$ver);
		    push @successes, "$dev / $port (OID $id): $vl->{type} vlan removed";
		  }
		  if ($res < 1) {
		    warn __FILE__ . ":" . __LINE__ . ": update failed\n" . Data::Dumper->Dump([$res, $ret],[qw(res ret)]) . "\n"; 
		    my $msg = "$dev / $port (OID: $id): Primary vlan change successful, but an error occured while updating the database: " . $CMU::Netdb::errors::errmeanings{$res};
		    $msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $errcodes{EDB});
		    $msg .= " [".join(',', @$ret)."]";
		    &wlog($msg);
		    push @errors, $msg;
		    $error++;
		  }
		}
	      }

	      # For other attributes, log that we completed the updates
	      if ($world->{$dev}{$port}{new}{speed}
		  || $world->{$dev}{$port}{new}{duplex}
		  || $world->{$dev}{$port}{new}{'port-security'}
		  || $world->{$dev}{$port}{new}{'description'}
		  || $world->{$dev}{$port}{new}{'port-fast'}) {
		my $msg = "$dev / $port (OID: $id): Updated port settings:";
		foreach (qw/speed duplex port-security port-fast description/) {
		  if ($world->{$dev}{$port}{new}{$_}) {
		    $msg .= " $_ = $world->{$dev}{$port}{new}{$_}.";
		  }
		}
		push @successes, $msg;
	      }
	    }
	  }
	}

	# If we encountered no errors, and we're not in NO-OP mode, log that
	# we've processed all changes as of when we loaded the data.
	if (!$error && !$noop) {
	  update_timestamp($dbh, $dev, $now);
	}

	$devHandle->run_command("copy running-config tftp://128.2.4.8/sw/netreg-confs/$dev\n\n");
	$devHandle->disconnect();

      } elsif ($devtype =~ /^(1900|2800|2820|2948|5000|5002|6509)/) {
	# These are devices that must be handled the old way, via snmp.
	# No Vlan support.

	my $error = 0;
	foreach my $port (keys %{$world->{$dev}}) {
	  my $id = $world->{$dev}{$port}{meta}{outletid};
	  my $version = $world->{$dev}{$port}{meta}{outletversion};

	  # Are we enabling/disabling the port?
	  if ($world->{$dev}{$port}{new}{status}) {
	    my $state = $world->{$dev}{$port}{new}{status} eq "enabled" ? 1 : 0;

	    # Make sure we're not in NO-OP mode.
	    if (!$noop) {
	      if ($state == 1) {
		&wlog("Activating $dev/$port") if ($debug);
	      } else {
		&wlog("Deactivating $dev/$port") if ($debug);
	      }

	      if (CMU::portadmin::setSwitchPort($dev,$port, $state)) {
		# We set the port successfully via SNMP.  Update the outlet in the database.
		my ($res, $ret);
		if ($state == 1) {
		  ($res, $ret) = CMU::Netdb::modify_outlet($dbh, "netreg", $id, $version, {"status" => "enabled"}, 9);
		  push @successes, "$dev / $port (OID $id): Activated (SNMP)";
		} else {
		  ($res, $ret) = CMU::Netdb::modify_outlet($dbh, "netreg", $id, $version, {"status" => "partitioned"}, 9);
		  push @successes, "$dev / $port (OID $id): Deactivated (SNMP)";
		}
		if ($res < 1) {
		  my $msg = "$dev / $port (OID: $id): Activation/Deactivation successful, but an error occured while updating the database: " . $CMU::Netdb::errors::errmeanings{$res};
		  $msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $errcodes{EDB});
		  $msg .= " [".join(',', @$ret)."]";
		  &wlog($msg);
		  push @errors, $msg;
		  $error++;
		}

	      } else {
		push @errors, "$dev / $port (OID $id): Unable to update to state $world->{$dev}{$port}{new}{status}.  Skipping additional updates for ports on this device.";
		$error++;
		last;
	      }
	    } else {
	      # In NO-OP mode, just report what would be done.
	      if ($state == 1) {
		print "Would activate Switch/Port: $dev/$port\n";
	      } else { 
		print "Would deactivate Switch/Port: $dev/$port\n";
	      }
	    }
	  } else {
	    # This switch type doesn't support vlans, and isn't supported by ManageIOS,
	    # so no other settings are relevant.
	    # FIXME: Should we just ignore the settings, or log an error?
	    # For primary-vlan changes, pretend me made the change
	    if ($world->{$dev}{$port}{new}{primaryvlan}) {
	      my ($res, $ret);
	      my $id = $world->{$dev}{$port}{meta}{'ovm-id'};
	      my $ver = $world->{$dev}{$port}{meta}{'ovm-version'};
	      my %fields = ("outlet" => $world->{$dev}{$port}{meta}{outletid},
			    "vlan" => $world->{$dev}{$port}{meta}{vlanid},
			    "type" => "primary",
			    "trunk_type" => "none",
			    "status" => 'active');
	      &wlog(__FILE__ . ':' . __LINE__ . ":  updating  outlet_vlan_membership with\n" . Data::Dumper->Dump([\%fields],[qw(fields)]) . "\n") if ($debug >= 2); 
	      ($res, $ret) = CMU::Netdb::modify_outlet_vlan_membership($dbh,'netreg',$id,$ver,\%fields);
	      push @successes, "$dev / $port (OID $id): Device doesn't support vlans, ignoring vlan request.";
	      if ($res < 1) {
		my $msg = "$dev / $port (OID: $id): Primary vlan change ignored, and an error occured while updating the database: " . $CMU::Netdb::errors::errmeanings{$res};
		$msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $errcodes{EDB});
		$msg .= " [".join(',', @$ret)."]";
		&wlog($msg);
		push @errors, $msg;
		$error++;
	      }
	    }

	  }
	}

	# If we encountered no errors, and we're not in NO-OP mode, log that
	# we've processed all changes as of when we loaded the data.
	if (!$error && !$noop) {
	  update_timestamp($dbh, $dev, $now);
	}

      } elsif ($devtype) {
	wlog("Unknown device type $devtype for $dev.  portadmin.pl needs to be updated to know how to handle this device.");
	push @errors, "$dev: Unknown device type $devtype.  portadmin.pl needs to be updated to know how to handle this device.";
      } else {
	wlog("Unable to contact device $dev via SNMP.  Please fix this device");
	push @errors, "$dev: Unable to contact device via SNMP.  Please fix this device, or remove this outlet registration.";
      }

    } else {
      # Unknown device type
      wlog("Unable to determine, by hostname, the device type for $dev.");
      push @errors, "$dev: Unable to determine, by hostname, the device type.";
    }
  }

  killLock($dbh, 'PORTADMIN_LOCK') unless ($nolock);

  $dbh->disconnect();

  if (@errors) {
    my $msg = "\nErrors encountered while updating devices:\n";
    $msg .= join("\n",@errors);
    if (@successes) {
      $msg .= "\n\nThe following updates were processed successfully:\n";
      $msg .= join("\n",@successes);
    }
    CMU::Netdb::netdb_mail("portadmin",$msg,"Portadmin: ".scalar(@errors)." errors encountered while updating devices", "", "") if ($debug < 2);
    wlog($msg);
  } elsif (@successes) {
    my $msg .= "\nThe following updates were processed successfully:\n";
    $msg .= join("\n",@successes);
    wlog($msg) if ($debug);
  }

}


sub update_timestamp {
  my ($dbh, $dev, $now) = @_;
  my ($res, $ret);

  $res = CMU::Netdb::list_trunkset_presences($dbh, "netreg", "machine", "machine.host_name = '$dev'");
  if (!ref $res || $#$res == 0) {
    my $msg = "All changes to $dev completed successfully, but an error occured while updating the database: $CMU::Netdb::errors::errmeanings{$res} ";
    $msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($res == $errcodes{EDB});
    &wlog($msg);
    push @errors, $msg;
    return;
  }

  my $map = CMU::Netdb::makemap($res->[0]);
  shift @$res;

  foreach (@$res) {
    my $id = $_->[$map->{'trunkset_machine_presence.id'}];
    my $ver = $_->[$map->{'trunkset_machine_presence.version'}];

    warn "Updating timestamp for $dev ($id / $ver)" if ($debug);
    my @date = localtime($now);
    my $datestring = 
      sprintf('%4.4d%2.2d%2.2d%2.2d%2.2d%2.2d', ($date[5] + 1900), ($date[4] +1), $date[3], $date[2], $date[1], $date[0]);

    push @successes, "$dev: Updated timestamp";
    my ($result, $return) = CMU::Netdb::modify_trunkset_machine_presence($dbh, 'netreg', $id, $ver, {'last_update' => $datestring});
    if ($result < 1) {
      my $msg = "All changes to $dev completed successfully, but an error occured while updating the database:" . $CMU::Netdb::errors::errmeanings{$result};
      $msg .= " [DB: ".$CMU::Netdb::primitives::db_errstr." ]" if ($result == $errcodes{EDB});
      $msg .= " [".join(',', @$return)."]";
      &wlog($msg);
      push @errors, $msg;
    }
  }
}


sub fetch_fulldata {
  my ($dbh, $outlet) = @_;

  if ($debug >= 2) {
    print "Fetching data for ".Data::Dumper->Dump([$outlet],['outlet']);
  }

  my $id = $outlet->{meta}{outletid};
  my $oref = CMU::Netdb::list_outlets_devport($dbh, "netreg", "outlet.id = $id");
  my $cref = CMU::Netdb::list_outlets_cables($dbh, "netreg", "outlet.id = $id");
  my $vlref = CMU::Netdb::list_outlet_vlan_memberships($dbh, "netreg", "outlet.id = $id");
  my $attrs = CMU::Netdb::list_attribute($dbh, "netreg", "attribute.owner_table = 'outlet' AND attribute.owner_tid = $id");

  if (!ref $oref || !ref $cref || !ref $vlref || !ref $attrs) {
    wlog("Error while fetching full data for outlet $id.");
    exit;
  }

  my $omap = CMU::Netdb::makemap($oref->[0]);
  my $cmap = CMU::Netdb::makemap($cref->[0]);
  my $vlmap = CMU::Netdb::makemap($vlref->[0]);
  my $attrmap = CMU::Netdb::makemap($attrs->[0]);

  if ($#$oref == 0) {
    wlog("Error: outlet $id not found");
    exit;
  } else {
    $outlet->{database}{status} = $oref->[1][$omap->{'outlet.status'}];
  }

  if ($#$cref == 0) {
    wlog("Error: outlet $id not found");
    exit;
  } else {
    $outlet->{meta}{labelfrom} = $cref->[1][$cmap->{'cable.label_from'}];
    $outlet->{meta}{labelto} = $cref->[1][$cmap->{'cable.label_to'}];
  }


  if ($#$vlref == 0) {
    wlog("No vlans found for outlet $id");
  } else {
    shift @$vlref;
    $outlet->{database}{vlans} = [];
    foreach (@$vlref) {
      if ($_->[$vlmap->{'outlet_vlan_membership.type'}] eq 'primary') {
	$outlet->{database}{primaryvlan} = $_->[$vlmap->{'vlan.number'}];
      }
      push(@{$outlet->{database}{vlans}},$_->[$vlmap->{'vlan.number'}])
	if (($_->[$vlmap->{'outlet_vlan_membership.status'}] eq 'active') ||
	    ($_->[$vlmap->{'outlet_vlan_membership.status'}] eq 'request'));
    }
  }

  if ($#$attrs == 0) {
    wlog("No attributes found for outlet $id") if ($debug);
  } else {
    shift @$attrs;
    foreach (@$attrs) {
      if ($_->[$attrmap->{'attribute_spec.name'}] eq 'port-speed') {
	$outlet->{database}{speed} = $_->[$attrmap->{'attribute.data'}];
      }
      if ($_->[$attrmap->{'attribute_spec.name'}] eq 'port-duplex') {
	$outlet->{database}{duplex} = $_->[$attrmap->{'attribute.data'}];
      }
      if ($_->[$attrmap->{'attribute_spec.name'}] eq 'Port Security Mode') {
	$outlet->{database}{'port-security'} = $_->[$attrmap->{'attribute.data'}];
      }
      if ($_->[$attrmap->{'attribute_spec.name'}] eq 'Port-Fast Mode') {
	$outlet->{database}{'port-fast'} = $_->[$attrmap->{'attribute.data'}];
      }
    }
  }
}


sub wlog {
  my ($msg) = @_;
  if (!$debug) {
    open(LOGFILE, ">/home/netreg/logs/portadmin.log.$$") ||
      warn "Can't open /home/netreg/logs/portadmin.log.$$";
    flock(LOGFILE, LOCK_EX);
    my $t = localtime(time);
    print LOGFILE "$t:$msg\n";
    flock(LOGFILE, LOCK_UN);
    close(LOGFILE);
  } else {
    print "$msg\n";
  }
}


sub usage {
  print "Usage: $0 [--clear-lock] [--no-lock] [--noop] [--single-device HOSTNAME] [--debug int]\n";
  exit;
}


$result = GetOptions("debug=i" => \$debug,
		     "audit" => \$audit,  # Not implemented yet
		     "destructive" => \$destructive, # Not implemented yet
		     "single-device=s" => \$singledev,
		     "no-lock" => \$nolock,
		     "clear-lock" => \$clearlock,
		     "noop" => \$noop);

usage() unless ($result);
$debug = 0 if (! defined $debug);
$audit = 0 if (! defined $audit);
$destructive = 0 if (!defined $destructive);
$nolock = 0 if (! defined $nolock);
$clearlock = 0 if (! defined $clearlock);
$noop = 0 if (! defined $noop);

warn __FILE__ . ":" . __LINE__ . ": \n" . 
  "parameters are: \n" . 
  "\tdebug = $debug \n" .
  "\taudit = $audit \n" .
  "\tdestructive = $destructive \n" .
  "\tnolock = $nolock \n" .
  "\tclearlock = $clearlock \n" .
  "\tnoop = $noop \n" .
  "\tsingledev = " . (defined $singledev ? "$singledev\n" : "undef\n") .
  "snmp variables\n\tdefault_timeout = $SNMP_Session::default_timeout\n" . 
  "\tdefault_retries = $SNMP_Session::default_retries\n" . 
  "\tdefault_backoff = $SNMP_Session::default_backoff\n" if ($debug >= 3);


&main();
