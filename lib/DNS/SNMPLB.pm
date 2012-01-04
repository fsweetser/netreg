# -*- perl -*-
#
# DNS::SNMPLB

#
# Copyright 2002 Carnegie Mellon University 
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
# $Id: SNMPLB.pm,v 1.8 2007/04/11 18:51:02 vitroth Exp $
#
# $Log: SNMPLB.pm,v $
# Revision 1.8  2007/04/11 18:51:02  vitroth
# add tracking of current tcp connection counts to snmp based LB weighting
#
# Revision 1.7  2007/03/27 20:55:17  vitroth
# too much debugging, not enough if ($debug)
# again
#
# Revision 1.6  2007/03/27 20:53:46  vitroth
# too much debugging, not enough if ($debug)
#
# Revision 1.5  2007/03/27 20:50:33  vitroth
# added a workaround for a behavior change (bug?) in SNMP.pm
#
# Revision 1.4  2003/10/30 18:11:37  kevinm
# * Don't hammer the unreachable hosts
#
# Revision 1.3  2003/08/01 05:34:08  kevinm
# * Changed for SNMP to work; reduced logging
#
# Revision 1.2  2002/04/08 05:10:36  kevinm
# * Don't set a UI < 1 if we have a good UI value
#
# Revision 1.1  2002/04/05 17:59:29  kevinm
# * Initial checking of SNMP collector for load balancing
#
#
#
#

package DNS::SNMPLB;

use strict;
use vars qw/@ISA @EXPORT/;
use SNMP;
use Data::Dumper;

require Exporter;
@ISA = qw/Exporter/;

@EXPORT = qw/AddMember DelMember SetVar GetVar SetFactors Run GetIndices
  PrintStats PrintSumStats SetName/;

my $SNMP_PORT = '161';
my $DEF_RETR = 2;
my $DEF_TIMEOUT = 10000;
my $MAX_DOWNHOLD = 64;
my $debug = 20;

my %SNMP_Dictionary = ('1MinLoad' => '.1.3.6.1.4.1.2021.10.1.3.1',
		       '5SecLoad' => '.1.3.6.1.4.1.2021.10.1.3.2',
		       '5MinLoad' => '.1.3.6.1.4.1.2021.10.1.3.3',
		       'tcpCurrEstab' => '.1.3.6.1.2.1.6.9.0');


# Function: new
# Perldoc: 
# Authored:
# Reviewed:
sub new {
  my ($name) = @_;
  my $self = {};
  bless $self;
  $self->{machines} = {};
  $self->{factors} = {};
  $self->{name} = $name;
  $self->{vars} = {};
  $self->SetVar('UpdInterval', 3);

  return $self;
}

sub SetName {
  my ($self, $name) = @_;
  $self->{name} = $name;
  return 1;
}

# Function: AddMember
# Perldoc: 
# Authored:
# Reviewed:
sub AddMember {
  my ($self, $MemberName, $BasicWeight, $ConnParams) = @_;

  return "Member already exists ($MemberName)"
    if (defined $self->{machines}->{$MemberName});
  
  $self->{machines}->{$MemberName} = {};
  my $Member = $self->{machines}->{$MemberName};
  $Member->{BasicWeight} = $BasicWeight;
  
  $self->_set_Max_Weight();

  # Initialize other per-member variables
  $Member->{Status} = 'DOWN';   # CONNECTED, CONN_PEND, or DOWN
  $Member->{LastQueryStart} = 0;    # Last time we started a query
  $Member->{LastUpdate} = 0;        # Last time we received an update
  $Member->{DownHold} = 1;

  $Member->{ReadComm} = $ConnParams->{'ReadComm'};
  $Member->{ReadComm} = 'public' 
    if ($Member->{ReadComm} eq '');
  
  $Member->{Port} = $ConnParams->{'Port'};
  $Member->{Port} = $SNMP_PORT
    if ($Member->{Port} eq '');

  $Member->{Retries} = $ConnParams->{'Retries'};
  $Member->{Retries} = $DEF_RETR
    if ($Member->{Retries} eq '');
  
  $Member->{Timeout} = $ConnParams->{'Timeout'};
  $Member->{Timeout} = $DEF_TIMEOUT
    if ($Member->{Timeout} eq '');  

  $Member->{Status} = 'DOWN';
  my $Ret = $self->_Connect($MemberName);

  $Member->{_FactorValues} = {};

  return $Ret if ($Ret != 1);

  return 1;
}

# Function: DelMember
# Perldoc: 
# Authored:
# Reviewed:
sub DelMember {
  my ($self, $MName);

  return "Member ($MName) doesn't exist"
    if (!defined $self->{machines}->{$MName});
  
  delete $self->{machines}->{$MName};
  
  return 1;
}

# Function: SetVar
# Perldoc: 
# Authored: DONE/kevinm
# Reviewed:
sub SetVar {
  my ($self, $Key, $Value) = @_;
  $self->{vars}->{$Key} = $Value;
  return 1;
}

# Function: GetVar
# Perldoc: 
# Authored: DONE/kevinm
# Reviewed:
sub GetVar {
  my ($self, $Key) = @_;
  return $self->{vars}->{$Key};
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
      if (!defined $SNMP_Dictionary{$F}) {
	return "Factor $F is not in the dictionary!";
      }
    }
  }

  return 1;
}

# Function: Run
# Perldoc: 
# Authored: DONE/kevinm
# Reviewed: 
sub Run {
  my ($self) = @_;
  
  $self->_Process_Timeouts();
  $self->_Begin_Request();
  $self->_Begin_Reconnect();
  $self->_SNMP_Handle();
  
}

# Function: GetIndices
# Perldoc:
# Authored:
# Reviewed:
sub GetIndices {
  my ($self) = @_;

  $self->_calc_UI();
  my %M;
  foreach (keys %{$self->{machines}}) {
    next if ($self->{machines}->{$_}->{Status} ne 'CONNECTED');
    $M{$_} = $self->{machines}->{$_}->{UsabilityIndex};
  }
  return \%M;
}

# Function: PrintStats
# Perldoc:
# Authored:
# Reviewed:
sub PrintStats {
  my ($self) = @_;
  
  foreach my $M (keys %{$self->{machines}}) {
    print "Member $M: UI ".$self->{machines}->{$M}->{'UsabilityIndex'}."\n";
  }
  return 1;
}

# Function: PrintSumStats
# Perldoc:
# Authored:
# Reviewed:
sub PrintSumStats {
  my ($self) = @_;
  return $self->PrintStats();
}

##

sub _calc_UI {
  my ($self) = @_;

  foreach my $M (keys %{$self->{machines}}) {
    my $Member = $self->{machines}->{$M};
    if ($Member->{Status} ne 'CONNECTED') {
      $Member->{UsabilityIndex} = 0;
      next;
    }
    # Machine is connected. Calculate usability index
    my $val;
    foreach my $F (keys %{$self->{factors}}) {
      my $G = $SNMP_Dictionary{$F};
      print "$F/$G\n" if ($debug >= 25);
      $val += $self->{factors}->{$F} * 
	$Member->{_FactorValues}->{$G};
      print "Calc: $M/$F (fetched: $Member->{_FactorValues}->{$G}, weight: $self->{factors}->{$F}, result: $val)\n" if ($debug >= 20);
    }
    $Member->{PreWeightUI} = $val;
    $self->_set_MaxMin_UI();
    my $UI_step = ($self->GetVar('Max_UI') - 
		   $self->GetVar('Min_UI'))/1000;
    $Member->{UsabilityIndex} = int($val - ($self->GetVar('Max_Wt') -
					    $Member->{BasicWeight}) * $UI_step);
    $Member->{UsabilityIndex} = 2 if ($val > 0 && $Member->{UsabilityIndex} < 1);
  }
}

sub _set_MaxMin_UI {
  my ($self) = @_;
  my ($max, $min) = (-1, -1);
  foreach my $M (keys %{$self->{machines}}) {
    my $MRec = $self->{machines}->{$M};
    if ($MRec->{Status} eq 'CONNECTED') {
      $max = $MRec->{PreWeightUI} if ($max == -1 || $MRec->{PreWeightUI} > $max);
      $min = $MRec->{PreWeightUI} if ($min == -1 || $MRec->{PreWeightUI} < $min);
    }
  }
  $self->SetVar('Max_UI', $max);
  $self->SetVar('Min_UI', $min);
}

## Find the maximum weight of all CONNECTED machines
sub _set_Max_Weight {
  my ($self) = @_;
  my $max = 0;
  foreach my $M (keys %{$self->{machines}}) {
    my $MRec = $self->{machines}->{$M};
    if ($MRec->{Status} eq 'CONNECTED') {
      $max = $MRec->{BasicWeight} if ($MRec->{BasicWeight} > $max);
    }
  }
  $self->SetVar('Max_Wt', $max);
}
  
sub _Connect {
  my ($self, $MemberName) = @_;

  return "Unknown member $MemberName"
    if (!defined $self->{machines}->{$MemberName});
  
  my $Member = $self->{machines}->{$MemberName};
 
  my $SS = new SNMP::Session(DestHost => $MemberName,
                             Community => $Member->{ReadComm},
                             RemotePort => $Member->{Port},
                             Timeout => $Member->{Timeout},
                             Retries => $Member->{Retries},
			     UseLongNames => 1,
			     UseNumeric => 1
                            );
  my $Now = time();

  $Member->{LastQueryStart} = $Now;
  $Member->{LastUpdate} = $Now;
  
  if (!$SS) {
    # If the hostname doesn't exist, or something similar.
    $self->_Status_Transition($MemberName, 'DOWN')
      if ($Member->{Status} ne 'DOWN');
    return "Unable to connect to $MemberName";
  }
  $Member->{SNMP_Session} = $SS;

  $self->_Status_Transition($MemberName, 'CONN_PEND');
  return 1;
}

## Fire off SNMP requests for CONN_PEND or CONNECTED hosts
sub _Begin_Request {
  my ($self) = @_;
  
  print "_Begin_Request!\n" if ($debug >= 20);
  foreach my $M (keys %{$self->{machines}}) {
    my $Member = $self->{machines}->{$M};
    if ($Member->{Status} eq 'CONNECTED' ||
	$Member->{Status} eq 'CONN_PEND') {
      
      my $UpdInterval = $self->GetVar('UpdInterval');
      my $LQS = $Member->{LastQueryStart};
      my $LU = $Member->{LastUpdate};
      next unless ( ($LU >= $LQS ||
		     $LU == 0) 
		    && $LQS + $UpdInterval < time());

      my @Vars = map { [$SNMP_Dictionary{$_}] } keys %{$self->{factors}};

      my $VarList = new SNMP::VarList(@Vars);
      print Data::Dumper->Dump([\@Vars, $VarList], ['SNMP Vars', 'VarList']) if ($debug >= 30);
      
      $Member->{SNMP_Session}->get($VarList,
				   [ \&_Process_SNMP_Vars, $self, $M, \@Vars ]);
      $Member->{LastQueryStart} = time();
    }
  }
}

# Give SNMP some time to deal with asychronous data reception
sub _SNMP_Handle {
  my ($self) = @_;

  SNMP::MainLoop(1, sub { SNMP::finish() });
  return 1;
}


## Callback for handling SNMP "get" responses
sub _Process_SNMP_Vars {
  my ($self, $MemberName, $VarsAsPassed, $VarList) = @_;
  
  print Data::Dumper->Dump([$VarList, $VarsAsPassed], ['VarList', 'VarsAsPassed']) if ($debug >= 30);

  if (!defined $VarList) {
    # Timeout. Fire off another attempt to "get" if we're supposedly connected
    return unless ($self->{machines}->{$MemberName}->{Status} eq 'CONNETED');

    my @Vars = map { [$SNMP_Dictionary{$_}, 0] } keys %{$self->{factors}};
    
    my $VarList = new SNMP::VarList(@Vars);
    
    $self->{machines}->{$MemberName}->{SNMP_Session}->get
      ($VarList, [ \&_Process_SNMP_Vars, $self, $MemberName ]);
  }else{
    # We got a response. excellent.
    my $Member = $self->{machines}->{$MemberName};
    if ($Member->{Status} eq 'CONN_PEND') {
      # We didn't know if the host was actually responsive,
      # but it appears that it is. So let's go.
      $self->_Status_Transition($MemberName, 'CONNECTED');
    }
    $Member->{LastUpdate} = time();
    
    # Handle all the variables
    foreach my $Var (@$VarList) {
      my ($Key, $a, $Value) = @$Var;

      # fix for zero load results in zero score, which is considered a failure
      $Value = 0.01 if ($Value == 0);
      # fix for broken SNMP.pm returning broken varbind list?
      my $orig = shift @$VarsAsPassed;
      if (!$Key && !$a) {
	$Key = $orig->[0];
	print "Process_SNMP_Vars: $MemberName, $Key, $Value\n" if ($debug >= 25);
	$Member->{_FactorValues}->{$Key} = $Value;
      } else {
	print "Process_SNMP_Vars: $MemberName, $Key.$a ($orig->[0]), $Value\n" if ($debug >= 25);
	$Member->{_FactorValues}->{$Key.".$a"} = $Value;
      }
    }
  }
}

## Find all the hosts that are unresponsive
sub _Process_Timeouts {
  my ($self) = @_;
  
  foreach my $M (keys %{$self->{machines}}) {
    my $Member = $self->{machines}->{$M};
    print "Process_Timeouts: $M status $Member->{Status}\n"
      if ($debug >= 20);
    
    if ($Member->{Status} eq 'CONNECTED' ||
	$Member->{Status} eq 'CONN_PEND') {
      my $LQS = $Member->{LastQueryStart};
      my $LU = $Member->{LastUpdate};
      my $UI = $self->GetVar('UpdInterval');
      my $Now = time();
      if ($LU < $LQS && $LQS + 2*$UI < $Now) {
	$self->_Status_Transition($M, 'DOWN');
      }	
    }
  }
  return 1;
}

## Try to reconnect to hosts that are down
## We call _Connect, which puts them in CONN_PEND.
## If the host doesn't respond, we move them back to DOWN,
## and after DownHold (which gets doubled for each iteration,
##   they'll get back here and we send off another _Connect)
sub _Begin_Reconnect {
  my ($self) = @_;

  print "Begin_Reconnect\n" if ($debug >= 20);
  foreach my $M (keys %{$self->{machines}}) {
    my $Member = $self->{machines}->{$M};
    next unless ($Member->{Status} eq 'DOWN');
    
    # Only try again if LastUpdate + DownHold is sufficient
    my $Now = time();
    my $DH = $Member->{DownHold};
    my $LUpdate = $Member->{LastUpdate};
    next if ($LUpdate + $DH > $Now);

    $self->_Connect($M);
  }
  return 1;
}

# This defines all the changes needed for a state change 
sub _Status_Transition {
  my ($self, $MemberName, $NewState) = @_;
  
  return "Unknown Member ($MemberName) "
    unless (defined $self->{machines}->{$MemberName});

  my $Member = $self->{machines}->{$MemberName};

  print "Status Transition: $MemberName from $Member->{Status} to $NewState\n" if ($debug >= 10);
  
  my $Now = time();

  if ($Member->{Status} eq 'DOWN') {
    return 1 if ($NewState eq 'DOWN');
    if ($NewState eq 'CONN_PEND') {
      $Member->{LastUpdate} = $Now;
      $Member->{LastQueryStart} = 0;
      $Member->{Status} = $NewState;
      return 1;
    }
    return 0;
  }elsif($Member->{Status} eq 'CONN_PEND') {
    return 1 if ($NewState eq 'CONN_PEND');
    if ($NewState eq 'DOWN') {
      $Member->{LastUpdate} = $Now;
      if ($Member->{DownHold} eq '') {
	$Member->{DownHold} = 1;
      }else{
	$Member->{DownHold} = ($Member->{DownHold}*2);
	$Member->{DownHold} = $MAX_DOWNHOLD
	  if ($Member->{DownHold} > $MAX_DOWNHOLD);
      }
      $Member->{Status} = $NewState;
      return 1;
    }elsif($NewState eq 'CONNECTED') {
      $Member->{LastUpdate} = $Now;
      $Member->{LastQueryStart} = 0;
      $Member->{Status} = $NewState;
      return 1;
    }    
  }elsif($Member->{Status} eq 'CONNECTED') {
    return 1 if ($NewState eq 'CONNECTED');
    if ($NewState eq 'DOWN') {
      $Member->{DownHold} = 2;
      $Member->{LastUpdate} = $Now;
      $Member->{LastQueryStart} = 0;
      $Member->{Status} = $NewState;
      return 1;
    }
    return 0;
  }
  return "Unknown member status $Member->{Status}\n";
}

1;

__END__

=head1 NAME

DNS::SNMPLB - Implementation of an SNMP collector for LBPool

=head1 SYNOPSIS

  use DNS::LBPool;
  my $pool = new DNS::LBPool;
  $pool->AddPool('Random1', 'SNMPLB');

=head1 CONSTRUCTOR

=over 4

=item new ($Name)

Creates a new C<DNS::SNMPLB>. Should be instantiated via LBPool only. $Name specifies
the name of this pool.

=back

=head1 METHODS

=over 4

=item AddMember($MemberName, $BasicWeight)

Adds a new member to this pool. The member is of name $MemberName, and has a basic
weight of $BasicWeight. $MemberName must be a hostname.

=item DelMember($MemberName)

Deletes a member from the pool. Called from LBPool only.

=item SetVar($VarName, $VarValue);

Sets a variable in the collector. Certain variables have special meaning (see
C<DNS::LBPool> and/or collector-implementation-specific manuals.) Again, 
this is not supposed to be called directly, but via the LBPool SetVar 
interface. $VarName specifies the variable to set, and $VarValue is the value to set
the variable to.

=item GetVar($VarName)

Gets the value of the variable $VarName in the collector. Called via the LBPool GetVar
interface.

=item SetFactors($rFactors)

SetFactors should be called via LBPool to set the various weights. RandomLB does not
use any factors, as the indexes it returns are random. The factors would be used,
however, to control the various multipliers of certain parameters (for example, 
to provide a comparison for 1-minute load average versus 5 minute). $rFactors is
a reference to an associative array of { factor => value }

=item Run()

The Run method is called periodically by LBPool to provide an interface for going
and collecting new information from hosts, updating UsabilitiyIndex (es), and any
periodic housekeeping that needs to be done. Collectors MUST implement a timing
check (using the 'UpdInterval' variable), to ensure they do not perform work
every time the Run method is called. Collectors should take reasonable measures
to ensure that any operations that may take a long time to complete, or are not
bounded by a timer, are executed asynchronously.

=item GetIndices()

Returns a reference to an associative array of hostname to UsabilityIndex. Note that
a hostname MUST be returned. In most cases this will be the same as the member name,
but the Indices will be directly used to update DNS tables. Again, GetIndices
is called from LBPool.

=item PrintStats()

PrintStats is an optional method for implementation. When implemented, it should
print complete statistics about the current state of each member, and the pool
as a whole. Information might include the current UI, base weights, the values
of various factors involved, etc.

=item PrintSumStats()

PrintSumStats is an optional method for implementation. When implemented, it should
print a summary of the current pool status: such as the members and the current UIs.

=back

=head1 VARIABLES

See 
C<DNS::RandomLB> for required variables. RandomLB does not use any additional
variables.

=head1 AUTHOR

Kevin Miller; Carnegie Mellon University.

=head1 COPYRIGHT

Copyright (c) 2002 Carnegie Mellon University. All rights reserved.
See the copyright statement of CMU NetReg/NetMon for more details
  (http://www.net.cmu.edu/netreg).

=cut


