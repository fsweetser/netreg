# DNS::LBPool
# Parse and LB Pools
#
# Copyright 2001 Carnegie Mellon University
#
# All Rights Reserved
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted,
# provided that the above copyright notice appear in all copies and that
# both that copyright notice and this permission notice appear in
# supporting documentation, and that the name of CMU not be
# used in advertising or publicity pertaining to distribution of the
# software without specific, written prior permission.
#
# CMU DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
# ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
# CMU BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
# ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
# ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
# SOFTWARE.
# 
# $Id: LBPool.pm,v 1.21 2008/04/16 17:43:36 vitroth Exp $
#
# $Log: LBPool.pm,v $
# Revision 1.21  2008/04/16 17:43:36  vitroth
# Added support for multiple keys for multiple reverse zones.
#
# Revision 1.20  2008/03/27 19:42:40  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.19.14.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.19.12.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.19  2004/07/21 19:11:18  vitroth
# Adding reverse dns records for LB pool machine NEVER worked.
# Now it does.
#
# Reverse records will be added to match the forward A record.
# i.e. if foo.cmu.edu is a lb pool, and foo1.cmu.edu is a member,
# then the reverse lookup of foo1.cmu.edu's IP address will give
# foo.cmu.edu
#
# Revision 1.18  2003/08/08 15:24:20  kevinm
# * UpdateOnFailureOnly support
#
# Revision 1.17  2003/08/01 05:34:08  kevinm
# * Changed for SNMP to work; reduced logging
#
# Revision 1.16  2003/06/24 18:05:39  kevinm
# * Broken code in identifying if any backups exist
#
# Revision 1.15  2003/06/24 15:54:43  kevinm
# * BackupOnly support
#
# Revision 1.14  2002/09/08 04:47:03  kevinm
# * WARN should be WARNING
#
# Revision 1.13  2002/08/12 13:17:29  kevinm
# * A bit of memory management cleanup
#
# Revision 1.12  2002/07/10 12:22:06  kevinm
# * More Error logging
#
# Revision 1.11  2002/05/21 15:41:05  kevinm
# * Trailing dots..
#
# Revision 1.10  2002/05/10 15:05:41  kevinm
# * Fixes for the LBPool (call Set_DefZone to get the right zone updated)
#
# Revision 1.9  2002/04/29 21:29:53  kevinm
# * Changes to make KMemsrv actually work.
#
# Revision 1.8  2002/04/29 20:17:24  kevinm
# * lbnamed.stat for sitter process
#
# Revision 1.7  2002/04/15 21:37:02  kevinm
# * To solve the Solaris bug, add all A records for machines that are up
#
# Revision 1.6  2002/04/08 03:55:10  kevinm
# * Reverse DNS updates
#
# Revision 1.5  2002/04/08 01:53:23  kevinm
# * Fix LB stuff. This now all works AFAIK
#
# Revision 1.4  2002/04/05 04:11:51  kevinm
# * Lots of fixes for getting LB stuff in order.
#
# Revision 1.3  2002/03/31 04:13:29  kevinm
# * Completely reworked LBPool to do most of the DNS updating, etc.
#
# Revision 1.2  2001/11/29 06:26:01  kevinm
# Added copyright
#
#

package DNS::LBPool;

require 5.005_03;
use vars qw($VERSION @ISA @EXPORT);
use strict;
use Carp;

use Data::Dumper;
use DNS::ZoneParse;
use DNS::KMemLB;
use DNS::SNMPLB;
use DNS::RandomLB;

use CMU::Errors;

require Exporter;
@ISA = qw(Exporter);
$VERSION = '0.36C';

my $STATDIR = '/var/run/lbnamed';

@EXPORT = qw/new AddPool AddMember DelMember SetVar GetVar SetFactors Run 
  Dump Record_Error/;

my ($ALARM_MAJOR,
    $ALARM_MINOR) = ('', '');

# ModuleMap needs to be updated with the string-based "Collector Type"
# as a reference to the ::new function that will instantiate a 
# collector of that type.

my %ModuleMap = ('kmemsrv' => \&DNS::KMemLB::new,
		 'snmp' => \&DNS::SNMPLB::new,
		 'random' => \&DNS::RandomLB::new);

sub new {
  my $self = {};
  bless $self;
  $self->{__Pools} = {};
  
  # Used by SetVar/GetVar in 'global' scope
  $self->{__Variables} = {};
  
  # Instantiate the ZoneParses that will be used for updating DNS
  $self->{NZone} = new DNS::ZoneParse();
  $self->{DZone} = new DNS::ZoneParse();

  $self->{Errors} = new CMU::Errors;
  $self->{Errors}->SetVar('Log_Syslog_Facility', 'daemon');
  $self->{Errors}->SetVar('Log_Syslog_LockSock', 'unix');
  $self->{Errors}->SetVar('Log_Syslog', 'on');
  $self->_err("Error log startup");
  $self->SetVar('Debug', 0, 'global');
  return $self;
}

sub DESTROY {
  my ($self) = @_;
  delete $self->{__Pools};
  delete $self->{__Variables};
  delete $self->{NZone};
  delete $self->{DZone};
  delete $self->{Errors};
}

# Function: AddPool
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub AddPool {
  my ($self, $PoolName, $CollType) = @_;
  
  return $self->_err("Pool name $PoolName already defined")
    if (defined $self->{$PoolName});
  
  return $self->_err("Pool named _global not allowed.")
    if ($PoolName eq '_global');
  
  $self->{__Pools}->{$PoolName} = {};

  my $Pool = $self->{__Pools}->{$PoolName};

  my $CollNew;
  if (ref $CollType) {
    # This is a reference to the ::new function we can use to start 
    # the collection interface
    $CollNew = $CollType;
  }else{
    return $self->_err("Collector Type $CollType unknown")
      unless (defined $ModuleMap{$CollType});
    $CollNew = $ModuleMap{$CollType};
  }
  
  my $Ret = eval {
    $CollNew->($PoolName);
  };
  
  return $self->_err("Unable to instantiate Collection Type $CollType")
    if (!defined $Ret);

  $Pool->{Collector} = $Ret;

  $Ret = eval {
    $Pool->{Collector}->SetName($PoolName);
  };
  
  return $self->_err("Unable to set name of new collector to: $PoolName\n")
    if (!defined $Ret);

  $self->SetVar('ActiveDNS', '', 'pool', $PoolName);

  return 1;
}
  
# Function: AddMember
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub AddMember {
  my ($self, $PoolN, $Name, $BaseProb, $ConnParams) = @_;
  
  return $self->_err("Pool $PoolN does not exist")
    if (!defined $self->{__Pools}->{$PoolN});
  my $Pool = $self->{__Pools}->{$PoolN};
  
  return $self->_err("Member $Name already defined")
    if (defined $Pool->{Members}->{$Name});

  $Pool->{Members}->{$Name} = {};
  my $Member = $Pool->{Members}->{$Name};
  
  $BaseProb = '1' if ($BaseProb eq '');
  $Member->{Weight} = $BaseProb;

  # Call the underlying collector to get the member loaded
  # Wrap in eval {} so that we trap die() (or for example,
  #  a broken collector that doesn't implement AddMember
  my $Ret = eval {
    $Pool->{Collector}->AddMember($Name, $BaseProb, $ConnParams);
  };

  return $self->_err("Unable to add member ($Name) to collector")
    if (!defined $Ret);
  return $self->_err("Error adding member ($Name) to collector: $Ret")
    if ($Ret != 1);

  return 1;
}

# Function: DelMember
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub DelMember {
  my ($self, $PoolN, $Member) = @_;
  
  return $self->_err("Pool $PoolN does not exist")
    if (!defined $self->{__Pools}->{$PoolN});
  my $Pool = $self->{__Pools}->{$PoolN};

  return $self->_err("Member $Member does not exist")
    unless (defined $Pool->{Members}->{$Member});
  
  my $Ret = eval {
    $Pool->{Collector}->DelMember($Member);
  };

  return $self->_err("Unable to remove member $Member from pool")
    unless ($Ret == 1);
  
  delete $Pool->{Members}->{$Member};
  return 1;
}

# Function: SetVar
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub SetVar {
  my ($self, $VarKey, $Value, $Scope, $PoolN) = @_;

  $Value = '' if (!defined $Value);
  $Scope = 'global' if (!defined $Scope || $Scope eq '');

  if ($Scope eq 'global') {
    $self->{__Variables}->{$VarKey} = $Value;
    return 1;

  }elsif($Scope eq 'pool') {
    return $self->_err("Pool must be specified in scope 'pool'")
      if (!defined $PoolN || $PoolN eq '');
    return $self->_err("Unknown pool ($PoolN)")
      if (!defined $self->{__Pools}->{$PoolN});

    my $Pool = $self->{__Pools}->{$PoolN};
    $Pool->{Variables}->{$VarKey} = $Value;
    return 1;    

  }elsif($Scope eq 'collector') {
    return $self->_err("Pool must be specified in scope 'collector'")
      if (!defined $PoolN || $PoolN eq '');
    return $self->_err("Unknown pool ($PoolN)")
      if (!defined $self->{__Pools}->{$PoolN});

    my $Pool = $self->{__Pools}->{$PoolN};
  
    # Eval{} in case the collector doesn't implement SetVar
    # or is otherwise broken
    my $Ret = eval {
      $Pool->{Collector}->SetVar($VarKey, $Value);
    };

    return $self->_err("Error setting variable in collector: $VarKey -> $Value ($Ret)")
      if (!defined $Ret || $Ret != 1);
    
    return 1;
  }elsif($Scope eq 'errors') {
    return $self->{Errors}->SetVar($VarKey, $Value);
  }

  return $self->_err("Unknown scope ($Scope)/expect 'global', 'pool', ".
		     "or 'collector'");
}

# Function: GetVar
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub GetVar {
  my ($self, $VarKey, $Scope, $PoolN) = @_;
  
  my ($Ret, $ResTxt) = ('', '');

  $Scope = 'global' if (!defined $Scope || $Scope eq '');
  if ($Scope eq 'global') {
    $Ret = $self->{__Variables}->{$VarKey};
    goto GetVar_Out;

  }elsif($Scope eq 'pool') {
    $ResTxt = "Pool must be specified in scope 'pool'"
      if (!defined $PoolN || $PoolN eq '');
    $ResTxt = "Unknown pool ($PoolN)"
      if (!defined $self->{__Pools}->{$PoolN});
    
    goto GetVar_Out if ($ResTxt ne '');

    my $Pool = $self->{__Pools}->{$PoolN};
    $Ret = $Pool->{Variables}->{$VarKey};

    goto GetVar_Out;    
  }elsif($Scope eq 'collector') {
    $ResTxt = "Pool must be specified in scope 'collector'"
      if (!defined $PoolN || $PoolN eq '');
    $ResTxt = "Unknown pool ($PoolN)"
      if (!defined $self->{__Pools}->{$PoolN});

    goto GetVar_Out if ($ResTxt ne '');
    
    my $Pool = $self->{__Pools}->{$PoolN};

    # Eval{} in case the collector doesn't implement SetVar
    # or is otherwise broken
    my $RetEval = eval {
      $Pool->{Collector}->GetVar($VarKey);
    };

    $ResTxt = "Error getting variable from collector"
      if (!defined $RetEval);
    
    $Ret = $RetEval;
    goto GetVar_Out;
  }elsif($Scope eq 'errors') {
    my $Ret = $self->{Errors}->GetVar($VarKey);
    goto GetVar_Out;
  }
  
  $ResTxt = "Unknown scope ($Scope): Expect 'global', 'pool', or 'collector'";
  
 GetVar_Out:
  if ($ResTxt ne '') {
    $self->SetVar('_last_getvar_error', $ResTxt, 'global');
    $self->_err($ResTxt);
    return undef;
  }
  
  return $Ret;
}

# Function: SetFactors
# Perldoc:
# Authored: DONE/kevinm
# Reviewed:
sub SetFactors {
  my ($self, $PoolN, $rFactors) = @_;

  return $self->_err("Pool $PoolN does not exist")
    if (!defined $self->{__Pools}->{$PoolN});
  my $Pool = $self->{__Pools}->{$PoolN};

  my $Ret = eval {
    $Pool->{Collector}->SetFactors($rFactors);
  };

  return $self->_err("Error calling SetFactors of collector ($Ret)")
    if (!defined $Ret || $Ret != 1);
  
  return $Ret;  
}

# Function: Run
# Perldoc:
# Authored: 
# Reviewed:
sub Run {
  my ($self) = @_;

  # We don't want to spin quickly. The exact application of timers
  # is thus:
  #  - collectors are expected to keep some record of time, and
  #    return if they have been collected from recently
  #  - _RunUpdate will return if it has been too recent since
  #    the last collection
  #  - We record the amount of time it takes to complete this
  #    process. If it's less than a second, we'll sleep for
  #    a second to prevent spins.
  # Additionally, we set a 5 seconds alarm to regain control
  # if a pool is being cranky with us

  my $Start = time();
  print STDERR "$Start: lbnamed.stat being written\n";
  open(FILE, ">$STATDIR/lbnamed.stat");
  print FILE "LBPool::Run awoken at $Start (".localtime($Start).")\n";
  close(FILE);

  $SIG{ALRM} = \&_Alarm_Wakeup;
  $ALARM_MAJOR = $self;

  # Run through all of pools and let them perform updates, etc.
  foreach my $PN (keys %{$self->{__Pools}}) {
    my $CurTime = time();
    print STDERR "$CurTime: Running $PN\n";
    $ALARM_MINOR = $PN;
    alarm(5);
    my $Ret = eval {
      $self->{__Pools}->{$PN}->{Collector}->Run();
    };
    alarm(0);
    $self->_err("Error running: $Ret") if ($Ret != 1);
  }
  
  # Now run through all the pools and do the DNS updates
  foreach my $PN (keys %{$self->{__Pools}}) {
    my $CurTime = time();

    $ALARM_MINOR = $PN;
    alarm(5);
    my $Ret = $self->_RunUpdate($PN, $self->{NZone}, $self->{DZone});
    if ($Ret != 1 && $Ret != 2) {
      $self->_err($Ret);
    }
    alarm(0);
  }

  # Give the error queue a chance to flush any pending messages
  $self->{Errors}->Run();

  my $End = time();

  if ($End <= $Start) {
    # If it's really less-than, we have a bit of a problem. ^)
    sleep(2);
  }
  return 1;
}

# Function: Dump
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub Dump {
  my ($self) = @_;

  print "**Dumping all..";
  print Dumper($self);
  
  return 1;
}

# Function: Record_Error
# Perldoc:
# Authored: DONE/kevinm
# Reviewed:
sub Record_Error {
  my ($self, $msg) = @_;
  $self->_err($msg);
}

# Function: Delete
# Perldoc:
# Authored: DONE/kevinm
# Reviewed:
sub Delete {
  my ($self, $PoolN) = @_;

  return $self->_err("Pool $PoolN does not exist")
    if (!defined $self->{__Pools}->{$PoolN});
  my $Pool = $self->{__Pools}->{$PoolN};

  foreach my $M (keys %{$Pool->{members}}) {
    $self->DelMember($PoolN, $M);
  }
  delete $Pool->{Collector};
  delete $self->{__Pools}->{$PoolN};
}


### *************** Internal Functions ***********************

sub _Alarm_Wakeup {
  my $self = $ALARM_MAJOR;
  my $Pool = $ALARM_MINOR;
  
  print STDERR time().": alarm wakeup -- $Pool!\n"; 
  $self->{Errors}->Record_Error('WARNING', "Alarm timeout ($Pool)");
}

## Update the DNS records for a specific pool ($PoolN)
## $NZone and $DZone are references to DNS::ZoneParse objects;
##  they will be used for zone additions (Nzone) and deletions (DZone)
sub _RunUpdate {
  my ($self, $PoolN, $NZone, $DZone) = @_;

  return "Pool $PoolN does not exist"
    if (!defined $self->{__Pools}->{$PoolN});
  my $Pool = $self->{__Pools}->{$PoolN};

  my $Debug = $self->GetVar('Debug');

  my $LastUpdate = $self->GetVar('_LastUpdate', 'pool', $PoolN);
  my $UpdInterval = $self->GetVar('UpdInterval', 'pool', $PoolN);
  if (!defined $UpdInterval || $UpdInterval eq '') {
    # By default we just set an interval of 5 seconds
    $self->SetVar('UpdInterval', 5, 'pool', $PoolN);
    $UpdInterval = 5;
  }

  my $Now = time();
  $LastUpdate = 0 if (!defined $LastUpdate || $LastUpdate eq '');

  print "_RunUpdate timing: LastUpdate $LastUpdate; UpdInterval $UpdInterval; ".
    "Now $Now\n" if ($Debug >= 55);

  if ($LastUpdate + $UpdInterval > $Now) {
    # Don't want to run now.
    return 2;
  }

  $self->SetVar('_LastUpdate', $Now, 'pool', $PoolN);
  
  my $rMach = _Pool_GetIndices($Pool);
  return $rMach if (!ref $rMach);

  my %Machines = %$rMach;
  # Keep a log
  open(FILE, ">$STATDIR/$PoolN");
  print FILE "Update_Time: ".time()." [".localtime(time())."]\n";
  foreach my $M (keys %Machines) {
    print FILE "Machine $M : $Machines{$M}";
    print FILE " [IGNORE]" if ($Machines{$M} < 1);
    print FILE "\n";
  }

  my $AnyNonBackup = 0; 
  foreach my $M (keys %Machines) {
    if ($Machines{$M} < 1) {
      delete $Machines{$M};
      next;
    }
    $AnyNonBackup = 1 
      if ($self->GetVar("BackupOnly_$M", 'collector', $PoolN) eq 'No');
  }

  # Remove BackupOnly machines if any non-BackupOnly machine still exists
  # in the list
  if ($AnyNonBackup == 1) {
    foreach my $M (keys %Machines) {
      next unless ($self->GetVar("BackupOnly_$M", 'collector', $PoolN) eq 'Yes');
      delete $Machines{$M}; 
      print FILE "BackupOnly $M : REMOVED\n";
    }
  }

  my ($min, $max) = _Get_MinMax(\%Machines);
  $max = 1 if ($max == 0);

  my @NewPoolDNS = ();
  my @OldPoolDNS = ();
  {
    my $ADNS = $self->GetVar('ActiveDNS', 'pool', $PoolN);
    if (!defined $ADNS) {
      print FILE "Error: Could not get Active DNS set.\n";
      close(FILE);
      return $self->GetVar('_last_getvar_error');
    }
    @OldPoolDNS = split(/\,/, $ADNS);
  }
  print FILE "Old_DNS: ".join(',', @OldPoolDNS)."\n";

  my $UOFO = $self->GetVar('UpdateOnFailureOnly', 'pool', $PoolN);
  if ($UOFO eq 'Yes' && $#OldPoolDNS > -1 && 
      defined $Machines{$OldPoolDNS[0]} && 
      $Machines{$OldPoolDNS[0]} > 0) {
    # No update if the current DNS entry is still valid
    print FILE "UpdateOnFailureOnly: $OldPoolDNS[0] still valid, ".
      "$Machines{$OldPoolDNS[0]}\n";
    return 1;
  }

  my $DNSType = $self->GetVar('DNSType', 'pool', $PoolN);
  my $DNSName = $self->GetVar('DNSName', 'pool', $PoolN);

  ## Actually go through and figure out what machines are going to
  ## be part of this pool 
  my @KM = keys %Machines;
  my $Step;
  if ($#KM >= 0) { 
    $Step = 1/($#KM+1);
  }else{
    $Step = 1;
  }
  my $Iteration = 0;
  if ($DNSType ne 'CNAME' && $self->GetVar('OverrideANAME_Method') ne 'yes') {
    foreach my $M (keys %Machines) {
      push(@NewPoolDNS, $M) if ($Machines{$M} > 0);
    }
  }else{ 
    foreach my $M (sort {$Machines{$a} <=> $Machines{$b}} keys %Machines) {
      my $Prob = 1-($Step*$Iteration++);
      print "Machine $M: $Machines{$M} ($Prob) [$max, $min]\n" if ($Debug >= 7);
      push(@NewPoolDNS, $M)
        if (rand() <= $Prob);
    }
  }
  print FILE "New_DNS: ".join(',', @NewPoolDNS)."\n";

  print "New Pool: ".join(',', @NewPoolDNS)."\n" if ($Debug >= 7);
  
  if (!defined $DNSType || $DNSType eq '') {
    print FILE "Error: Could not get DNS Type.\n";
    close(FILE);
    return "Error getting DNS Type: ".
      $self->GetVar('_last_getvar_error');
  }
  
  if (!defined $DNSName || $DNSName eq '') {
    print FILE "Error: Could not DNS Name.\n";
    close(FILE);
    return "Error getting DNS Name ($PoolN): ".
      $self->GetVar('_last_getvar_error');
  }    

  # You can only have one CNAME in an RR, so we choose one of 
  # the NewPoolDNS entries at random
  if ($DNSType eq 'CNAME') {
    @NewPoolDNS = ($NewPoolDNS[int(rand($#NewPoolDNS+1))]);
  }
  print FILE "New_DNS_Actual: ".join(',', @NewPoolDNS)."\n"; 

  close(FILE);

  my $SendUpdate = 1;
  if (join(',', sort @OldPoolDNS) eq join(',', sort @NewPoolDNS)) {
    $SendUpdate = 0;
  }
  ## If the new pool is a superset of the old pool, don't worry
  ## about updating. This will save us a few updates.
  #my $SendUpdate = 0;
  #$SendUpdate = 1 if ($#OldPoolDNS == -1);
  #foreach my $D (@OldPoolDNS) {
  #  $SendUpdate = 1
  #    unless (grep(/^$D$/, @NewPoolDNS));
  #}

  print "Send update? $SendUpdate\n" if ($Debug >= 10);
  return 1 unless ($SendUpdate);

  ## Call NSUpdate
  $NZone->Clear_Zone();
  $DZone->Clear_Zone();
  
  ## Set the default zone so we update the right thing
  my ($h, $z) = split(/\./, $DNSName, 2);
  $NZone->Set_DefZone($z);
  
  ## DZone is the list of deletions. So we delete all
  ## existing entries of this RR name and type
  $DZone->Add_RR("$DNSName.", 1, 'IN', $DNSType, '')
    if ($DNSType eq 'A');

  ## Check the number of NewPoolDNS entries. If less than
  ## one, ABORT. Assume something is wrong, and leave DNs alone so that
  ## things aren't completely broken.
  if ($#NewPoolDNS < 0) {
    return "No entries in \@NewPoolDNS; NOT updating DNS (assuming error)";
  }

  my $Interval = int($self->GetVar('UpdInterval', 'pool', $PoolN)/2);
  $Interval = 3 if ($Interval eq '' || $Interval < 1);

  foreach my $N (@NewPoolDNS) {
    my $rdata = '';
    if ($DNSType eq 'CNAME') {
      $rdata = $N;
    }elsif($DNSType eq 'A') {
      # Lookup the IP address from the collector
      my $AIP = $self->GetVar("IP_$N", 'collector', $PoolN);
      return $self->GetVar('_last_getvar_error')
	if (!defined $AIP);
      $rdata = $AIP;
    }else{
      return "Unknown DNS Type: $DNSType";
    }

    $NZone->Add_RR("$DNSName.", $Interval, 'IN', $DNSType, $rdata);
    if (!defined $self->{_dns_reverse}->{$N}) {
      $self->_DNS_Reverse($N, $rdata, $PoolN, $DNSName);
    }
  }
  
  my $Ret = $self->SetVar('ActiveDNS', join(',', @NewPoolDNS),
			  'pool', $PoolN);
  return $Ret if ($Ret != 1);

  # Get the update key ID and name
  my $KeyName = $self->GetVar('KeyName', 'pool', $PoolN);
  my $Key = $self->GetVar('Key', 'pool', $PoolN);
  if (!defined $KeyName || $KeyName eq '') {
    return "Error retrieving KeyName: ".
      $self->GetVar('_last_getvar_error');
  }
  
  if (!defined $Key || $Key eq '') {
    return "Error retrieving Key: ".
      $self->GetVar('_last_getvar_error');
  }

  if ($Debug >= 30) {
    print "Not updating: debug >= 30\n";
    print "Indices: ";
    map {
      print "  $_: $Machines{$_}\n";
    } keys %Machines;
    print "New: ".join(', ', @NewPoolDNS)."\n";
    print "Old: ".join(', ', @OldPoolDNS)."\n";

    return 1;
  }
 
  my ($res, $txt) = $NZone->NSUpdate($DZone->Get_Zone(),
				     $KeyName, $Key);

  if ($res < 1) {
    # Error updating DNS records
    return "Error updating DNS Records: $res $txt\n";
  }
  
  return 1;
}

## Register a reverse address
sub _DNS_Reverse {
  my ($self, $N, $rdata, $PoolN, $DNSName) = @_;
  
  my $KeyA = $self->GetVar('UpdReverse', 'pool', $PoolN);
  $self->{_dns_reverse}->{$N} = 1;

  warn "_DNS_Reverse:\nmachine=$N\nrdata=$rdata\nDNS record=$DNSName\nPool=$PoolN\nkey='$KeyA'\n" 
    if ($self->GetVar('Debug'));

  return 1 if ($KeyA eq '');

  my $zone = new DNS::ZoneParse();
  # IP Address
  my ($a, $b, $c, $d) = split(/\./, $rdata);
  my $Name = "$d.$c.$b.$a.IN-ADDR.ARPA.";
  my $Zone = $Name;
  $Zone =~ s/^\d*\.(.*)$/\1/;
  my ($KeyName, $Key);
  # If multiple keys were passed, find the matching key
  # This assumes keys will have the zone name as the initial component of the key
  # Which is what NetReg does...  key/lbnamed on the zone becomes a key named '$ZONE.lbnamed'
  foreach (split(/\s+/, $KeyA)) {
    ($KeyName, $Key) = split(/\:/, $_);
    last if ($KeyName =~ /^$Zone/);
  }

  $zone->Set_Debug(20)  if ($self->GetVar('Debug') >= 20);
  $zone->Set_DefZone($Zone);

  warn "Adding RR ($Name, 300, 'IN', 'PTR', $DNSName)\n" if ($self->GetVar('Debug'));
  $zone->Add_RR($Name, 300, 'IN', 'PTR', $DNSName);
  warn "Calling NSUpdate with key '$KeyName:$Key'\n" if ($self->GetVar('Debug') >= 20);
  $zone->NSUpdate({}, $KeyName, $Key);

  undef $zone;
}


## Wrapper around a call to the collector's GetIndices
sub _Pool_GetIndices {
  my ($Pool) = @_;
  
  my $Ret = eval {
    $Pool->{Collector}->GetIndices();
  };

  return "Error calling GetIndices of collector"
    if (!defined $Ret);

  return $Ret;
}

## Go through the indices we have retrieved
##  from the collector, and return the minimum/maximum
sub _Get_MinMax {
  my ($rMach) = @_;
  my ($min, $max) = (-1, -1);
      foreach my $M (keys %$rMach) {
    $min = $rMach->{$M}
      if ($rMach->{$M} < $min || $min == -1);
    $max = $rMach->{$M}
      if ($rMach->{$M} > $max || $max == -1);
  }
  return ($min, $max);
}

## Default reporting of errors at level ERR
sub _err {
  my ($self, $msg) = @_;
  $self->{Errors}->Record_Error('ERR', $msg);
  return $msg;
}

1;

__END__

This module is a wrapper around lower-level communications modules.

The idea is that the lbnamed.pl process creates new pools in this
module; we'll take care of talking to the modules that handle the
exact data collection. We'll also manage the attributes, etc.

Global variable space:

__Pools: ref to array ( PoolName => { [PoolContents]
				    })

__Variables: hash of Key: Value ('global' scope)

NZone: DNS::ZoneParse instance, used for adding entries
DZone: DNS::ZoneParse instance, used for deleting entries

[PoolContents]: ref to array of 
  ('Collector' => reference to collector handle
   'Members' => ( 
		 MemberName => ref to [MemberInfo]
		)
   'Variables' => reference to key:value (for SetVar scope 'ppol')
   'NZone' => DNS::ZoneParse instance 
   'DZone' => DNS::ZoneParse instance
 

[MemberInfo]: 


=head1 NAME

DNS::LBPool - DNS load balancer pool management

=head1 SYNOPSIS

  use DNS::LBPool;

=head1 DESCRIPTION

C<DNS::LBPool> provides an interface for creating and managing 
load balanced pools. A load-balancing nameserver creates pools
using this module. C<DNS::LBPool> then instantiates lower-level
communications modules and manages updating the DNS servers.

=head1 CONSTRUCTOR

=over 4

=item new ( [ARGS] )

Creates a new C<DNS::LBPool>.

=back

=head1 METHODS

=over 4

=item AddMember($PoolName, $MemberName, $BaseWeight, $ConnParams)
  
Adds the member C<$MemberName> to the pool C<$PoolName>. The basic weight
of this machine is set to C<$BaseProb>. The MemberName is expected to have
meaning to the underlying collector. Typically this would be a hostname or IP
address. The pool must exist. The basic weight is used to weight this 
member with respect to all other members. Therefore, if all members have the
same basic weight, the weight is irrelevant. If the weight is not specified,
it defaults to '1'. $ConnParams is a reference to an associative array
of connection-related information. This is entirely collector-specific.
Returns 1 on success, otherwise an error message is returned.

=item DelMember($PoolName, $Member)

Deletes the specified member $Member from the pool $PoolName. This causes
a deletion from the underlying collection mechanism. Returns '1' on success,
otherwise returns an error message.

=item SetVar($VarKey, $VarValue, $Scope, $Pool)

LBPool maintains an internal variable table. This can be used to store/retrieve
pool-specific information. The value of $VarKey is the name of the variable,
and is set to the value $VarValue. If $VarValue is NOT specified, the variable
$VarKey is set to ''. $Scope can be one of 'global', 'pool', 'collector', or 'errors'. If
type 'global' is specified, the variable is set in the global LBPool context. If
type 'pool' is specified, $Pool must also be specified, and the variable is set
in LBPool's pool-specific variable store. If 'collector', the variable is passed
down to the underlying collector agent ($Pool must be defined in this case). 
If 'errors', the variable is set in the error reporting module. 
If
$Scope is not specified, 'global' scope is assumed. Note that while the namespace
for variables is separate from module-private information, collectors and LBPool
may use the variable space for public information. $Pool should be the name of a pool
when defined. Returns 1 on success, otherwise return and error message.

=item GetVar($VarKey, $Scope, $Pool)

GetVar retrieves the value of a variable as set by SetVar. The same rules apply
for $Scope and $Pool. Returns the variable value on success. The return value
is undefined on failure. On failure you can GetVar('_last_getvar_error', 'global')
to query the failure condition. If the variable does not exist, '' (empty
string) is returned.

=item SetFactors($PoolName, $rFactors)

baz

=item AddPool($Name, $CollType)

Constructs a new pool with name C<$Name> (which must be unique to this
LBPool instance, and collector type C<$CollType>. $CollType can be the
name of one of the built-in collection types, or it can be a reference
to the ::new function of a module that implements the collection interface,
in which case LBPool will call the ::new function to instantiate the collector.
Returns '1' on success, otherwise returns an error message.

=item DelPool( )

baz baz baz

=item Run()

Runs an iteration of the pool updater; checks for fresh data about the 
current status of all members of the pool, recalculates UsabilityIndices, 
and updates DNS.

=item Dump()

Runs Data::Dumper on essentially every variable element under our control,
and recursively dumps all collectors.

=back

=head1 POOL-SPECIFIC VARIABLES

The following variables can/should be set by the process using C<DNS::LBPool>.

=over 4

=item * DNSType

Can be either 'CNAME', or 'A', indicating the type of DNS record to be added
for this pool.

=item * DNSName

Specifies the Resource Record name that the pool entry will be added as. For 
example, 'CYRUS.ANDREW.CMU.EDU'.

=item * KeyName

DNS Updates are expected to be done by TSIG key. This specifies the key name
of the key to use while updating this pool record.

=item * Key

Specifies the actual shared key for use in updating the pool record.

=item * UpdInterval

Specifies the interval between updates of the DNS records for this zone 
(in seconds).

=back

=head1 COLLECTOR-SPECIFIC VARIABLES

The following variables MUST be implemented by lower-level collectors.
Collectors may implement many other variables.

=over 4

=item * UpdInterval

Specifies the interval between updates of the underlying factors.

=back

=head1 ERROR-SPECIFIC VARIABLES

The following variables can be sent to the error reporting
module.

=over 4

=item * Log_Email

If set to 'on', enables logging of errors via email. You MUST specify
the other Log_Email parameters.

=item * Log_Email_Address

Specifies the email address to send email error reports to. Must be 
specified if Log_Email is enabled.

=item * Log_Email_Level

Specifies the minimum criticality level for messages sent via email.

=item * Log_Email_Interval

Specifies the interval (in seconds) between email reports.

=item * Log_Syslog

If set to 'on', enables logging of errors to the syslog facility.
Errors are logged under facility local4, unless the Log_Syslog_Facility
variable is set. Note that you need to toggle the value of Log_Syslog
in order to change the facility - you need to toggle it off, ensure
a single iteration of the Error->Run() method, and then toggle it back
on. (Typically Error->Run() would be called on each iteration of
another module).

=item * Log_Syslog_Facility

Can be set to change the syslog facility from the standard 'local4'. See
Log_Syslog.

=item * Log_Stderr

If set to 'on', enables logging of errors to standard error.

=back

=head1 SEE ALSO

C<DNS::RandomLB> defines the basic collector implementation.

=head1 AUTHOR

Kevin Miller; Carnegie Mellon University.

=head1 COPYRIGHT

Copyright (c) 2002 Carnegie Mellon University. All rights reserved.
See the copyright statement of CMU NetReg/NetMon for more details
(http://www.net.cmu.edu/netreg).

=cut
