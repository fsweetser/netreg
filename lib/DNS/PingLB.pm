# -*- perl -*-
#
# DNS::PingLB
# Random load balance engine
#
# Copyright 2002-2006 Carnegie Mellon University 
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
# 
# $Id: PingLB.pm,v 1.1 2006/06/29 15:31:19 vitroth Exp $
#
#
#
#

# NOTE:
#  This is an example implementation of the collection engine. It is
#  interfaced from DNS::LBPool.  It is untested and not guaranteed to 
#  actually be useful.  A real collection agent would connect
#  via some method to the host, or otherwise get a real-time update
#  of the status of the machines in the pool.
#

package DNS::PingLB;

use strict;
use vars qw/@ISA @EXPORT/;

require Exporter;
@ISA = qw/Exporter/;

@EXPORT = qw/AddMember DelMember SetVar GetVar SetFactors Run GetIndices
  PrintStats PrintSumStats/;

my $MAX_DOWNHOLD = 64;
my $debug = 20;

# Function: new
# Perldoc: 
# Authored: DONE/kevinm
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

# Function: AddMember
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub AddMember {
  my ($self, $MemberName, $BasicWeight) = @_;

  return "Member already exists ($MemberName)"
    if (defined $self->{machines}->{$MemberName});
  
  $self->{machines}->{$MemberName} = {};
  my $Member = $self->{machines}->{$MemberName};
  $Member->{BasicWeight} = $BasicWeight;

  # Here you can set other initial variables for this member entry

  return 1;
}

# Function: DelMember
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub DelMember {
  my ($self, $MName);

  return "Member ($MName) doesn't exist"
    if (!defined $self->{machines}->{$MName});
  
  delete $self->{machines}->{$MName};
  
  return 1;
}

# Function: SetVar
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub SetVar {
  my ($self, $Key, $Value) = @_;
  $self->{vars}->{$Key} = $Value;
  return 1;
}

# Function: GetVar
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub GetVar {
  my ($self, $Key) = @_;
  return $self->{vars}->{$Key};
}

# Function: SetFactors
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed:
sub SetFactors {
  my ($self, $rFactors) = @_;

  $self->{factors} = $rFactors;
  return 1;
}

# Function: Run
# Perldoc: DONE/kevinm
# Authored: DONE/kevinm
# Reviewed: 
sub Run {
  my ($self) = @_;

  # Here, you would go fetch updates for all the members
  # as necessary.
  my $LastUpd = $self->GetVar('LastUpdate');
  my $UpdInterval = $self->GetVar('UpdInterval');
  my $Now = time();
  
  return 2 if ($LastUpd + $UpdInterval > $Now);

  # We don't have anything to do, but might as well change all
  # the UsabilityIndex (es) to something new (& random).
  $self->_calc_UI();
}

# Function: GetIndices
# Perldoc:
# Authored: DONE/kevinm
# Reviewed:
sub GetIndices {
  my ($self) = @_;

  $self->_calc_UI();
  my %M;
  foreach (keys %{$self->{machines}}) {
    $M{$_} = $self->{machines}->{$_}->{UsabilityIndex};
  }
  return \%M;
}

# Function: PrintStats
# Perldoc:
# Authored: DONE/kevinm
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
# Authored: DONE/kevinm
# Reviewed:
sub PrintSumStats {
  my ($self) = @_;
  return $self->PrintStats();
}

##

sub _calc_UI {
  my ($self) = @_;
  my $p = Net::Ping->new("icmp", 1);
  foreach my $M (keys %{$self->{machines}}) {
    my $status = $p->ping($M) || 0;
    $self->{machines}->{$M}->{UsabilityIndex} = $status;
  }
}

1;

__END__

=head1 NAME

DNS::PingLB - Reference implementation of collector agent for C<DNS::LBPool>

=head1 SYNOPSIS

  use DNS::LBPool;
  my $pool = new DNS::LBPool;
  $pool->AddPool('Random1', 'PingLB');

=head1 CONSTRUCTOR

=over 4

=item new ($Name)

Creates a new C<DNS::PingLB>. Should be instantiated via LBPool only. $Name specifies
the name of this pool.

=back

=head1 METHODS

=over 4

=item AddMember($MemberName, $BasicWeight)

Adds a new member to this pool. The member is of name $MemberName, and has a basic
weight of $BasicWeight. $MemberName will most likely be a hostname or IP address,
however the collector could elect to use some other method of member separation.

=item DelMember($MemberName)

Deletes a member from the pool. Called from LBPool only. Collectors MUST ensure
that GetIndices, on the next iteration, will NOT include deleted members.

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

SetFactors should be called via LBPool to set the various
weights. PingLB does not use any factors, as the indexes it returns
are based on ping results.

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
C<DNS::PingLB> for required variables. PingLB does not use any additional
variables.

=head1 AUTHOR

David Nolan; Network Development; Carnegie Mellon University.

=head1 COPYRIGHT

Copyright (c) 2002-2006 Carnegie Mellon University. All rights reserved.
See the copyright statement of CMU NetReg for more details
  (http://www.net.cmu.edu/netreg).

=cut


