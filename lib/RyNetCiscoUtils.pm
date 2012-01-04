# -*-Perl-*-
#
# Perl5 CISCO utility subroutines
#
# $Id: RyNetCiscoUtils.pm,v 1.2 2008/03/27 19:42:33 vitroth Exp $
#
###########################################################################

package RyNetCiscoUtils;
require 5.000;

use SNMP 1.8;
use strict;

###########################################################################

# Exports:

# &RyNetCiscoUtils::LoadPortMap("core-rtr-0.rtr.net.cmu.edu");
# &RyNetCiscoUtils::SetLInfoPortLabel
# &RyNetCiscoUtils::SetGJPortLabel
# &RyNetCiscoUtils::SetWGPortLabel
# &RyNetCiscoUtils::DumpLInfoLabels
# &RyNetCiscoUtils::DumpGJLabels
# &RyNetCiscoUtils::DumpWGLabels
# &RyNetCiscoUtils::DumpDeviceLabels

###########################################################################

# Load the map of SNMP iftable row number to module/port map.
# IE: "2/12" -> "23"

# This is only good for things like a Cisco 2900.

# Not routers.

sub FetchPortMap {
  my($Host, $Comm) = @_;
  $Comm = "public" if (!defined $Comm || $Comm eq '');
  my($Head) = ".1.3.6.1.4.1.9.5.1.4.1.1.11";
  my($Mod, $Port);
  my($SNMPInt);
  my(%PortMap);
  my %walk=();
  my($oid);
  my(@oidparts);

  %walk=RyNetUtils::snmp_walk($Host,$Comm,$Head);
  
  foreach $oid (keys %walk){
    chomp($walk{$oid});
    @oidparts=split /\./, $oid;
    $Mod = $oidparts[14]; $Port=$oidparts[15];
    if($Port == 0){ $Port=1 };
    $SNMPInt = $walk{$oid};

    # Put everything into one struct.  Easy to determine,
    # as IfTable indicies do not have a "/", and mod/port
    # combos do.
    $PortMap{$SNMPInt} = "$Mod/$Port";
    $PortMap{"$Mod/$Port"} = $SNMPInt;
  }

  %PortMap;
};

###########################################################################

sub FetchCDPTable {
  my($Host, $Comm) = @_;
  $Comm = "public" if (!defined $Comm || $Comm eq '');
  my($Int, $Name);
  my(%CDPTable);
  my %walk=();
  my($oid); 
  my(@oidparts);
  
  %walk=RyNetUtils::snmp_walk($Host, $Comm, ".1.3.6.1.4.1.9.9.23.1.2.1.1.6");
  foreach $oid (keys %walk) {
    chomp($walk{$oid});
    @oidparts = split /\./, $oid;
    $Int = $oidparts[15]; $Name = $walk{$oid};
    $CDPTable{$Int} = $Name;
  }

  %CDPTable;
};

## This table contains CDP Entries.  These functions allow you to pull
## out the appropriate info from the entry.  These will need to be
## updated as they change the CDP format.

# [7513]backbone3
# hostnameAABBCCDDEEFF
# hostnameAABBCCDDEEFF.
# hostname
# 009697769(core0.sw.cmu.net)

sub CDPHost {
  my($Entry) = @_;
  my($Host);

  if ($Entry =~ m/\[\d+\]/) {
    # [7513]backbone3
    $Host = $Entry;
    $Host =~ s/\[\d+\]//;
  } elsif ($Entry =~ m/(.+)([a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9])$/) {
    # hostnameAABBCCDDEEFF
    $Host = $1;
  } elsif ($Entry =~ m/(.+)([a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9])\.$/) {
    # hostnameAABBCCDDEEFF.
    $Host = $1;
  } elsif ($Entry =~ m/\(([^\)]+)\)/) {
    # 009697769(core0.sw.cmu.net)
    $Host = $1
  } else {
    $Host = $Entry;
  }

  $Host =~ s/\.$//; # Remove trailing dot
  $Host=lc($Host);

  # Now cleanup hostname
  if (($Host =~ m/\.net\.cmu\.edu$/) ||
      ($Host =~ m/\.cmu\.net$/)) {
    # Good
  } elsif ($Host =~ m/\.net\.cmu$/) {
    $Host .= ".edu";
  } elsif ($Host =~ m/\.net$/) {
    $Host .= ".cmu.edu";
  } else {
    $Host .= ".cmu.net";
  }

  return($Host);
}

sub CDPMAC {
  my($Entry) = @_;

  return("");
}

###########################################################################

# Label a port.  Cisco has three different MIBs with labels:

# grandjunction MIB [ old non-cisco mib] : OID._port_ = str
# localinfo MIB [ cisco mib ]            : OID._port_ = str
# workgroup MIB [ cisco mib ]            : OID._mod_._port_ = str

sub SetLInfoPortLabel {
  my($Host, $Comm, $Port, $Name) = @_;
  my($OID) = ".1.3.6.1.4.1.9.2.2.1.1.28.$Port";

  &RyNetUtils::SNMPSetString($Host, $Comm, $OID, $Name);
}

sub SetGJPortLabel {
  my($Host, $Comm, $Port, $Name) = @_;
  my($OID) = ".1.3.6.1.4.1.437.1.1.3.3.1.1.3.$Port";
  &RyNetUtils::SNMPSetString($Host, $Comm, $OID, $Name);
}

sub SetWGPortLabel {
  my($Host, $Comm, $ModPort, $Name) = @_;
  my($OID) = ".1.3.6.1.4.1.9.5.1.4.1.1.4.$ModPort";
  &RyNetUtils::SNMPSetString($Host, $Comm, $OID, $Name);
}

###########################################################################
sub FetchVLANTable {
  my($Host, $Comm) = @_;
  $Comm = "public" if (!defined $Comm || $Comm eq '');
  my ($Port, $Descr);
  my %walk=();
  my ($oid); 
  my ($throw);

  my (@VLANTable);
  my ($Head) = ".1.3.6.1.2.1.2.2.1.2";
  
  %walk=RyNetUtils::snmp_walk($Host, $Comm, $Head);

  foreach $oid (sort keys %walk){
    if($walk{$oid} =~ m/VLAN/){  
      ($throw, $Port)=split /\ /,$walk{$oid};   
        push(@VLANTable, $Port) if ($Port ne '' && $Port <= 1000);   
    }
  }

  # get the other table of vlan information
  $Head = ".1.3.6.1.4.1.9.9.46.1.3.1.1.2.1";
  
  %walk = RyNetUtils::snmp_walk($Host, $Comm, $Head);
  
  foreach $oid (sort keys %walk) {
    if ($oid =~ /\Q$Head\E\.(\d*)$/) {
      push(@VLANTable, $1) 
        if ($1 ne '' && $1 <= 1000 && !grep(/^$1$/, @VLANTable));
    }
  }

  @VLANTable;
} 
  
###########################################################################

# XXXXX Really ugly.  Should clean up everything in here. XXXXX

sub DumpLInfoLabels {
  my($Host, $Comm) = @_;
  $Comm = "public" if (!defined $Comm || $Comm eq '');
  my %walk=();
  my $oid;
 
  %walk=RyNetUtils::snmp_walk($Host, $Comm, ".1.3.6.1.4.1.9.2.2.1.1.28");
  foreach $oid (sort keys %walk){
    print("$oid -> $walk{$oid}");
  }
}

sub DumpGJLabels {
  my($Host, $Comm) = @_;
  $Comm = "public" if (!defined $Comm || $Comm eq '');
  my %walk=();
  my $oid;
 
  %walk=RyNetUtils::snmp_walk($Host, $Comm, ".1.3.6.1.4.1.437.1.1.3.3.1.1.3");
  foreach $oid (sort keys %walk){
    print("$oid -> $walk{$oid}");
  }
}

sub DumpWGLabels {
  my($Host, $Comm) = @_;
  $Comm = "public" if (!defined $Comm || $Comm eq '');
  my %walk=();
  my $oid;
 
  %walk=RyNetUtils::snmp_walk($Host, $Comm, ".1.3.6.1.4.1.9.5.1.4.1.1.4");
  foreach $oid (sort keys %walk){
    print("$oid -> $walk{$oid}");
  }
}

sub DumpDeviceLabels {
  my($Host) = @_;
  &RyNetCiscoUtils::DumpLInfoLabels($Host);
  &RyNetCiscoUtils::DumpGJLabels($Host);
  &RyNetCiscoUtils::DumpWGLabels($Host);
}

###########################################################################
#by alison, 1-24-2001

#sub snmp_walk {
  #my ($server, $comm, $rootoid) = @_;
  #my %walk=();
  #my $sess = new SNMP::Session ( DestHost => $server, 
                                 #Community => $comm,
                                 #UseNumeric => 1, 
                                 #UseLongNames => 1
                               #);
#
  #my @orig=split /\./, $rootoid;  # original oid for comparison
#
  #my $var = new SNMP::Varbind(["$rootoid"]); 
  #my $val = $sess->getnext($var);
  #my $name = $var->[$SNMP::Varbind::tag_f].".".$var->[$SNMP::Varbind::iid_f];
  #$name .= ".$var->[$SNMP::Varbind::iid_f]" if $var->[$SNMP::Varbind::iid_f];
  #my @current=split /\./, $name;
#
  #while (!$sess->{ErrorStr} && $orig[$#orig] eq $current[$#orig]){
    #my $value=$var->[$SNMP::Varbind::val_f];
#
    #$walk{"$name"} = $value;
    #$val = $sess->getnext($var);
    #$name=$var->[$SNMP::Varbind::tag_f];
    #$name.=".$var->[$SNMP::Varbind::iid_f]" if $var->[$SNMP::Varbind::iid_f];
    #@current=split /\./, $name;
  #}  #while
#
  #print(STDERR "$sess->{ErrorStr}\n") if $sess->{ErrorStr};
  #return(%walk);
#}
#
# Success!
1;
