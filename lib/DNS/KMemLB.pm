# -*- perl -*-
#
# DNS::KMemLB
# Load balance engine for KMemSrv
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
# Kevin Miller <kcm@cmu.edu>
# 
# $Id: KMemLB.pm,v 1.9 2008/03/27 19:42:40 vitroth Exp $
#
# $Log: KMemLB.pm,v $
# Revision 1.9  2008/03/27 19:42:40  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.8.22.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.8.20.1  2007/09/20 18:43:06  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.8  2003/08/01 05:34:08  kevinm
# * Changed for SNMP to work; reduced logging
#
# Revision 1.7  2002/05/09 02:17:00  kevinm
# * Timers to keep things processing when hosts are down
#
# Revision 1.6  2002/04/29 21:29:53  kevinm
# * Changes to make KMemsrv actually work.
#
# Revision 1.5  2002/04/08 05:08:21  kevinm
# * Don't let UIs fall below 0 if it's a good value
#
# Revision 1.4  2002/04/08 01:53:23  kevinm
# * Fix LB stuff. This now all works AFAIK
#
# Revision 1.3  2002/04/05 04:11:51  kevinm
# * Lots of fixes for getting LB stuff in order.
#
# Revision 1.2  2001/12/12 19:10:49  kevinm
# Removing stale stuff, adding KMemLB functions
#
# Revision 1.1  2001/11/29 03:54:22  kevinm
# Initial checking of code to deal with kmemsrv. Should be mostly working.
#
#
#

package DNS::KMemLB;

use strict;
use vars qw/@ISA @EXPORT/;
use IO::Socket;
use IO::Select;

require Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/AddMember DelMember SetFactors GetIndex PrintStats 
  PrintSumStats GetIndices SetVar GetVar/;

my $KMEM_PORT = 'kmemsrv.log(904)';
my $MAX_DOWNHOLD = 64;
my $debug = 20;

sub new {
  my ($Name) = @_;
  my $self = {};
  bless $self;
  $self->{machines} = {};
  $self->{factors} = {};
  $self->{name} = $Name;
  $self->{vars} = {};
  $self->{param} = {Max_UI => 0,
		    Min_UI => 0,
		    Max_Wt => 0};
  return $self;
}

sub SetName {
  my ($self, $name) = @_;
  $self->{name} = $name;
  return 1;
}

##
sub SetVar {
  my ($self, $k, $v) = @_;
  $self->{vars}->{$k} = $v;
  return 1;
}

sub GetVar {
  my ($self, $k) = @_;
  return $self->{vars}->{$k};
}

## Add a machine to this pool
sub AddMember {
  my ($self, $mName, $weight) = @_;

  $weight = 1 if ($weight eq '');
  $self->{machines}->{$mName} = {status => 'DOWN',
				 s_Interval => $MAX_DOWNHOLD, # Nsecs between updates
				 s_BootTime => 0,
				 UsabilityIndex => 0,
				 ConnectTime => 0,
				 LastUpdate => 0,
				 NUpdates => 0,
				 DownHold => 0,
				 Reader => 0,
				 NConnects => 0,
				 RecvBuf => '',
				 Weight => $weight,
				 PreWeightUI => 0
				};
  my $M = $self->{machines}->{$mName};
  $M->{_factors} = {};
  my $Rem = _connect($mName, $KMEM_PORT);
  if ($Rem == -1) {
    $M->{LastUpdate} = time();
    $M->{DownHold} = 2;
    return 2;
  }else{
    $M->{Reader} = $Rem;
    $self->_connect_set($M);
  }
  return 1;
}

## Delete a machine from the pool
sub DelMember {
  my ($self, $mName) = @_;
  if (defined $self->{machines}->{$mName}) {
    _disconnect($self->{machines}->{$mName}->{Reader});
    delete $self->{machines}->{$mName};
  }
  _set_Max_Weight($self);
}

# Function: SetFactors
# Perldoc: 
# Authored: DONE/kevinm
# Reviewed:
sub SetFactors {
  my ($self, $rFactors) = @_;

  $self->{factors} = {};
  foreach my $F (keys %$rFactors) {
    if ($rFactors->{$F} != 0) {
      $self->{factors}->{$F} = $rFactors->{$F};
    }
  }

  return 1;
}

## Get the usability index of an individual machine
sub GetIndex {
  my ($self, $mname) = @_;
  if (!defined $self->{machines}->{$mname}) {
    return -1;
  }
  _runReader($self);
  _runRecvBuf($self);
  _runTimers($self);
  return $self->{machines}->{$mname}->{UsabilityIndex};
}

## Get the usability indices of all the machines in the pool
sub GetIndices {
  my ($self) = @_;
 
  _runReader($self);
  _runRecvBuf($self);
  _runTimers($self);
  my %M;
  foreach(keys %{$self->{machines}}) {
    $M{$_} = $self->{machines}->{$_}->{UsabilityIndex};
  }
  return \%M;
}

## Get some general statistics
sub PrintStats {
  my ($self, $FH) = @_;

  print $FH "Pool $self->{name}. Max UI: $self->{param}->{Max_UI}; ".
    "Min UI: $self->{param}->{Min_UI}; Max Weight: $self->{param}->{Max_Wt}\n";

  foreach(keys %{$self->{machines}}) {
    $self->MachineStats($_, $FH);
    print $FH "\n\n";
  }
}

sub Run { return 1; }

sub PrintSumStats {
  my ($self, $FH) = @_;

  print $FH 
"Machine Name           Status     UI   5Sec  1Min  5Min  Users  Procs
=======================================================================\n";

  my ($mname, $status, $ui, $n5sec, $n1min, $n5min, $users, $procs);
  format MACH =
@<<<<<<<<<<<<<<<<<<<<  @<<<<<<<< @>>>> @>>>> @>>>> @>>>> @>>>>> @>>>>>
$mname, $status, $ui, $n5sec, $n1min, $n5min, $users, $procs
.

  select((select($FH),$~ = 'MACH')[0]);
  foreach (sort {$a cmp $b} keys %{$self->{machines}}) {
    $mname = $_;
    my $M = $self->{machines}->{$_};
    $status = $M->{status};
    $ui = $M->{UsabilityIndex};
    $n5sec = $M->{factors}->{'5SecLoad'};
    $n1min = $M->{factors}->{'1MinLoad'};
    $n5min = $M->{factors}->{'5MinLoad'};
    $users = $M->{factors}->{'NumUsers'};
    $procs = $M->{factors}->{'NumProcs'};
    write($FH);
  }
}

## Get statistics about an individual machine
sub MachineStats {
  my ($self, $mName, $RH) = @_;

  return -1 if (!defined $self->{machines}->{$mName});
  my $M = $self->{machines}->{$mName};
  if ($M->{status} eq 'DOWN') {
    my ($hn, $status, $nconnect, $waittime, $lastcon);
    format RH_DOWN =                               
Host: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<     Status: @>>>>>>>>>>
$hn, $status
  Num. Connections: @>>>>
$nconnect
  Last Connect Attempt: @<<<<<<<<<<<<<<<<<<< Wait Time: @>>>>s
$lastcon, $waittime
.
    $hn = $mName;
    $status = $M->{status};
    $nconnect = $M->{NConnects};
    $lastcon = _niceDate($M->{LastUpdate});
    $waittime = $M->{DownHold};
    select((select($RH), $~ = 'RH_DOWN')[0]);
    write $RH;
  }elsif($M->{status} eq 'CONNECTED') {
    my ($hn, $status, $nconnect, $uptime, $ctime, $lupdate, $n5sec, $n1min);
    my ($n5min, $nproc, $nuser, $nupdate, $usabIndex, $wt, $preUsab);
    format RH =                               
Host: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  Status: @>>>>>>>>> Weight: @<<<<
$hn, $status, $wt
  Num connections/updates: (@>>>>/@>>>>>) System Uptime: @<<<<<<<<<<<<<<
$nconnect, $nupdate, $uptime
  Connected: @<<<<<<<<<<<<<<<<< Last Update: @<<<<<<<<<<<<<<<<<<<
$ctime, $lupdate
  Load: (@>>>>>/@>>>>>/@>>>>>) (5 Sec/1 Min/5 Min)
$n5sec, $n1min, $n5min
  Processes: @<<<<<<<<   Users: @<<<<<  UI Pre/Post Weight: @>>>>>>/@<<<<<
$nproc, $nuser, $preUsab, $usabIndex
.
    $hn = $mName;
    $status = $M->{status};
    $wt = $M->{Weight};
    $nconnect = $M->{NConnects};
    $uptime = _uptime($M->{s_BootTime});
    $ctime = _uptime($M->{ConnectTime});
    $nupdate = $M->{NUpdates};
    $lupdate = _niceDate($M->{LastUpdate});
    $n5sec = $M->{factors}->{'5SecLoad'};
    $n1min = $M->{factors}->{'1MinLoad'};
    $n5min = $M->{factors}->{'5MinLoad'};
    $nproc = $M->{factors}->{'NumProcs'};
    $nuser = $M->{factors}->{'NumUsers'};
    $preUsab = $M->{PreWeightUI};
    $usabIndex = $M->{UsabilityIndex};    
    select((select($RH), $~ = 'RH')[0]);
    write $RH;    
  }else{
    print $RH "Unknown status: $M->{status}!\n";
  }
}    

## Run through all the CONNECTED machines and see if they have
## data waiting for us.
sub _runReader {
  my ($self) = @_;
  
  my %Readers;
  my $ReadSet = new IO::Select();
  foreach my $M (keys %{$self->{machines}}) {
    my $MRec = $self->{machines}->{$M};
    if ($MRec->{status} eq 'CONNECTED') {
      $ReadSet->add($MRec->{Reader});
      $Readers{$MRec->{Reader}} = $MRec;
    }
  }
  my ($RH_Set) = IO::Select->select($ReadSet, undef, undef, 0);
  foreach my $RH (@$RH_Set) {
    ## Only read once, because otherwise we're going to deadlock waiting
    ## for data.
    my $buf = '';
    my $nread = sysread($RH, $buf, 1024);
    $Readers{$RH}->{RecvBuf} .= $buf;
  }
}

## Run through all the CONNECTED machines and process any entries
## in their receive buffer (which is filled via _runReader)
sub _runRecvBuf {
  my ($self) = @_;
 MACH: foreach my $M (keys %{$self->{machines}}) {
    my $MRec = $self->{machines}->{$M};
    if ($MRec->{status} eq 'CONNECTED' && $MRec->{RecvBuf} ne '') {
      my @lines = split(/\n/, $MRec->{RecvBuf});

      if ($MRec->{RecvBuf} =~ /\n$/s) {
	$MRec->{RecvBuf} = '';
      }else{
	$MRec->{RecvBuf} = pop(@lines);
      }
      
      ## In reality we just need to process the last line
      while ($#lines > -1) {
	if (_process_KMem_Line($self, $M, pop(@lines))) {
	  $self->_update_usability($M);
	  next MACH;
	}
      }
    }
  }
}

## Process an individual line of output from the kmemsrv on a machine
sub _process_KMem_Line {
  my ($self, $M, $Line) = @_;
  my $MRec = $self->{machines}->{$M};

  my @elem = split(/\|/, $Line);
  if ($elem[0] ne '^*') {
    return "_process_KMem_Line: $M: Invalid magic sequence.";
  }
  $MRec->{s_Interval} = $elem[1];
  $MRec->{s_BootTime} = $elem[3];
  $MRec->{factors}->{'5SecLoad'} = $elem[5];
  $MRec->{factors}->{'1MinLoad'} = $elem[6];
  $MRec->{factors}->{'5MinLoad'} = $elem[7];
  $MRec->{factors}->{'NumProcs'} = $elem[8];
  $MRec->{factors}->{'NumUsers'} = $elem[10];
  $MRec->{LastUpdate} = time();
  $MRec->{NUpdates}++;

  return 1;
}

## Update the Usability Index by applying our multiplication factors.
sub _update_usability {
  my ($self, $M) = @_;
  my $MRec = $self->{machines}->{$M};
  my $Factors = $self->{factors};
  
  my $val = 0;
  foreach my $F (keys %$Factors) {
    $val += $Factors->{$F}*$MRec->{factors}->{$F};
  }

  $MRec->{PreWeightUI} = $val;
  _set_MaxMin_UI($self);
  my $UI_step = ($self->{param}->{Max_UI}-$self->{param}->{Min_UI}) / 1000;
  $MRec->{UsabilityIndex} = int($val-( ($self->{param}->{Max_Wt}-$MRec->{Weight})*$UI_step));
  $MRec->{UsabilityIndex} = 2 if ($val > 0 && $MRec->{UsabilityIndex} < 0); 
}

## Run through all the machines. For DOWN machines, see if we should try
## reconnecting. For CONNECTED machines, see if we haven't heard from them
## in a rather long time.
sub _runTimers {
  my ($self) = @_;

  my $Time = time();
  foreach my $M (keys %{$self->{machines}}) {
    # Many DOWN machines will cause a long delay as we try to
    # reconnect to all of them. Go ahead and return, we'll get
    # back to them.
    if ($Time + 5 < time()) {
      return;
    } 
  
    my $MRec = $self->{machines}->{$M};
    if (!ref $MRec) { print STDERR "Not a reference in runTimers!\n"; }
     else { # print "status of $M (runTimers): $MRec->{status}\n"; FIXME print when debug level high 
	}
    if ($MRec->{status} eq 'DOWN') {
      if ($Time >= $MRec->{LastUpdate} + $MRec->{DownHold}) {
  	print STDERR "_runTimers ($M): Trying to reconnect\n";
	my $Rem = _connect($M, $KMEM_PORT);
	$MRec->{LastUpdate} = $Time;
	if ($Rem == -1) {
	  $MRec->{DownHold} = $MRec->{DownHold}*2;
	  $MRec->{DownHold} = $MAX_DOWNHOLD 
            if ($MRec->{DownHold} > $MAX_DOWNHOLD);
	  $MRec->{DownHold} = 2 if ($MRec->{DownHold} <= 0);
	}else{
	  $MRec->{Reader} = $Rem;
	  $self->_connect_set($MRec);
	}
      }
    }elsif($MRec->{status} eq 'CONNECTED') {
#      print STDERR "Checking CONN > DOWN ($MRec->{LastUpdate}, $Time, $MRec->{s_Interval}) for $M\n";
      if ($Time >= $MRec->{LastUpdate} + (1.5*$MRec->{s_Interval})) {
	# We've waited too long for an update
	print STDERR "_runTimers ($M): Setting status to DOWN\n";
	$MRec->{status} = 'DOWN';
	$MRec->{LastUpdate} = $Time;
	_disconnect($MRec->{Reader});
	$MRec->{Reader} = 0;
        $MRec->{UsabilityIndex} = 0;
	_set_Max_Weight($self);
      }
    }else{
      # Send mail?
      print STDERR "_runTimers: machine $M status is: $MRec->{status}\n";
    }
  }
}
 
## Attempt to connect to a host.
sub _connect {
  my ($HostName, $Port) = @_;
  my $Rem = IO::Socket::INET->new(Proto => 'tcp',
				  PeerAddr => $HostName,
				  PeerPort => $Port,
				  Timeout => 2);
  if (!$Rem) {
    return -1;
  }
  return $Rem;
}

## Once a host is connected, setup the record with the basic information.
sub _connect_set {
  my ($self, $MRec) = @_;
  $MRec->{NConnects}++;
  $MRec->{NUpdates} = 0;
  $MRec->{status} = 'CONNECTED';
  $MRec->{s_Interval} = $MAX_DOWNHOLD;
  $MRec->{s_BootTime} = 0;
  $MRec->{UsabilityIndex} = 0;
  $MRec->{ConnectTime} = time();
  $MRec->{LastUpdate} = time();
  $MRec->{DownHold} = 0;
  $MRec->{RecvBuf} = '';
  _set_Max_Weight($self);
}

sub _disconnect {
  my ($RH) = @_;
  close($RH);
}

sub _uptime {
  my ($begin) = @_;
  my $diff = time()-$begin;
  $diff = int($diff/60); # Ignore seconds
  my $min = $diff % 60;
  $diff = int($diff/60); # Now we have hours
  my $hours = $diff % 24;
  $diff = int($diff/24); # Now we have days
  my $days = $diff % 31;
  my $mo = int($diff/31);
  my $Txt = '';
  $Txt .= "${mo}mo " if ($mo != 0);
  $Txt .= "${days}d " if ($days != 0);
  $Txt .= "${hours}h " if ($hours != 0);
  $Txt .= "${min}m" if ($hours != 0);
  $Txt = "<1m" if ($Txt eq '');
  return $Txt;
}

sub _niceDate {
  return localtime($_[0]);
}

## Find the maximum weight of all CONNECTED machines
sub _set_Max_Weight {
  my ($self) = @_;
  my $max = 0;
  foreach my $M (keys %{$self->{machines}}) {
    my $MRec = $self->{machines}->{$M};
    if ($MRec->{status} eq 'CONNECTED') {
      $max = $MRec->{Weight} if ($MRec->{Weight} > $max);
    }
  }
  $self->{param}->{Max_Wt} = $max;
}
  
sub _set_MaxMin_UI {
  my ($self) = @_;
  my ($max, $min) = (-1, -1);
  foreach my $M (keys %{$self->{machines}}) {
    my $MRec = $self->{machines}->{$M};
    if ($MRec->{status} eq 'CONNECTED') {
      $max = $MRec->{PreWeightUI} if ($max == -1 || $MRec->{PreWeightUI} > $max);
      $min = $MRec->{PreWeightUI} if ($min == -1 || $MRec->{PreWeightUI} < $min);
    }
  }
  $self->{param}->{Max_UI} = $max;
  $self->{param}->{Min_UI} = $min;
}  

## 
 
1;
