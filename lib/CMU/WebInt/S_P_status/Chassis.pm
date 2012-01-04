#   -*- perl -*- 
# 
# CMU::WebInt::switch_panel_templates
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
# 

# In this package, every class/subclass must provide the following methods. All numberings are 1's based to match SNMP variables.
#  new - Create new object and sub objects as appropriate/possible
#  display - Show the contents of the object, this must support HTML-Table and HTML-Visual, the default will be HTML-Table
#  init - Initialize object with default values for the device represented, init may use SNMP to determine the type of object that it is.
#  update - Get values from the object either via SNMP or ssh/telnet.  SNMP is the prefered method
#  installed_in - Returns a pointer to the object that the object is installed in.  installed_in for S_P_status objects returns UNDEF.
#  child_count - Returns the number of child objects in this object (chassis in S_P_status, blades in chassis, ports in blade etc)
#  get_child - returns a child object, takes child number, returns UNDEF for ports
#  s_p_name - returns the name of the S_P_status.


package CMU::WebInt::S_P_status::Chassis;
use strict;
use warnings;
use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
require CMU::WebInt::S_P_status;

# require superclass


# Use subclasses
use CMU::WebInt::S_P_status::vars qw($chassis);
use CMU::WebInt::S_P_status::Chassis::C2950_24;
use CMU::WebInt::S_P_status::Chassis::C2950_48;
use CMU::WebInt::S_P_status::Chassis::C3500_48;
use CMU::WebInt::S_P_status::Chassis::C3500_24;
use CMU::WebInt::S_P_status::Chassis::C3750;
use CMU::WebInt::S_P_status::Chassis::C6509;

@ISA = qw(Exporter);

sub new {
  my ($type) = shift;
  my ($self) = {};

  $self->{'vars'}{'device_type'} = 'Runtime';
  $self->{'vars'}{'blade'} = [];
  $self->{'vars'}{'blade_cnt'} = [];
  $self = bless($self,$type);
  return($self);
}  

sub init {
  my $self = shift;
  my (%params) = @_;
  my ($i);

  $self->{'parent'} = $params{'parent'};
  if (defined $params{'dev_conf'}) {
    $self->{'dev_conf'} = $params{'dev_conf'};
  } else {
    $self->{'dev_conf'} = $self->get_config(name => $self->s_p_name(),
					    read_comm => $self->get_read_comm()
					   );
    
  }
  $self->{'vars'}{'chassis_num'} = $params{'chassis_num'};
  $self->{'vars'}{'blade_cnt'} = $chassis->{$self->{'vars'}{'chassis_type'}}{'Blade_cnt'};
  $self->{'vars'}{'vender_desc'} = $params{'vender_desc'};
  
  foreach $i (1 .. $self->{'vars'}{'blade_cnt'}) {
    if ((defined $chassis->{$self->{'vars'}{'chassis_type'}}{'Blade_construct'}) &&
	($chassis->{$self->{'vars'}{'chassis_type'}}{'Blade_construct'}  !~ /^runtime$/i)){
      $self->{'blades'}[$i] = eval $chassis->{$self->{'vars'}{'chassis_type'}}{'Blade_construct'};
      warn __FILE__ . ":" . __LINE__ . ": Blade creation failed: $@" if ($@);
    } else {
      $self->{'blades'}[$i] = $self->get_blade_construct(blade_num => $i, dev_conf => $self->{'dev_conf'});
      $self->{'blades'}[$i] = eval ($self->{'blades'}[$i]) if (defined $self->{'blades'}[$i]);
      warn __FILE__ . ":" . __LINE__ . ": Blade creation failed: $@" if ($@);
    }
    $self->{'blades'}[$i]->init( 'parent' => $self,'blade_num' => $i, 'dev_conf' => $self->{'dev_conf'})
      if defined $self->{'blades'}[$i];
  }
}

sub get_blade_construct {
  my ($self) = shift;
  my %params = @_;

  return(undef);
}
  


sub display {
  my ($self) = shift;
  my %params = @_;
  
  my ($form) = (defined $params{'form'}) ? $params{'form'} : "HTML-table";
  my ($val) = "";
  my ($i, $blade) ;

  $form = "HTML-table" if ((! defined $form) || (($form ne 'XML') && ($form ne 'HTML-display')));


  if ($form eq "HTML-table") {
    foreach $i (1 .. $self->{'vars'}{'blade_cnt'}) {
      $blade = "";
      $blade .= $self->{'blades'}[$i]->display('form' => $form) if (defined $self->{'blades'}[$i]);
      $val .= $blade;
    }
  } elsif ($form eq 'HTML-display') {
    $val .= "<table class=\"state\" border=\"3\">\n";
    $val .= "<caption>$self->{'vars'}{'vender_desc'}</caption>\n";
    if (! defined $self->{'vars'}{'blade_cnt'}) {
      warn __FILE__ . ":" . __LINE__ . ": blade_cnt undefined for me as \n" . 
	$self->dump() . "\n"; 
    } else {
      
      foreach $i (1 .. $self->{'vars'}{'blade_cnt'}) {
	$val .= "<tr><td>" . $self->{'blades'}[$i]->display('form' => $form) . "</td></tr>" if (defined $self->{'blades'}[$i]);
      }
    }
    $val .= "</table>\n";
  }
  return($val);
}


sub s_p_name {
  my $self = shift;

  if (defined $self->{'vars'}{'name'}) {
    return ($self->{'vars'}{'name'});
  } else {
    return($self->{'parent'}->s_p_name());
  }
}

sub get_read_comm {
  my $self = shift;

  return($self->{'vars'}{'read_comm'}) if(defined $self->{'vars'}{'read_comm'} && ($self->{'vars'}{'read_comm'} ne ""));

  return($self->{'parent'}->get_read_comm());
}

sub get_dbh {
  my $self = shift;

  return($self->{'vars'}{'dbh'}) if(defined $self->{'vars'}{'dbh'} && ($self->{'vars'}{'dbh'} ne ""));

  return($self->{'parent'}->get_dbh());
}

sub get_nmdbh {
  my $self = shift;

  return($self->{'vars'}{'nmdbh'}) if(defined $self->{'vars'}{'nmdbh'} && ($self->{'vars'}{'nmdbh'} ne ""));

  return($self->{'parent'}->get_nmdbh());
}

sub SNMP_init {
  my $self = shift;
  
  foreach (@{$self->{'blades'}}) {
    $_->SNMP_init() if (defined $_);
  }
}

sub netreg_init {
  my $self = shift;
  
  foreach (@{$self->{'blades'}}) {
    $_->netreg_init() if (defined $_);
  }
}

sub g_context {
  my $self = shift;

  if (defined $self->{'vars'}{'g_context'}) {
    return($self->{'vars'}{'g_context'})
  } else {
    return($self->{'parent'}->g_context());
  }
}

sub vlan_config{
  my $self = shift;
  my (%params) = @_;
  my ($vlan, $port, $bits);

  return($self->{'vars'}{'vlan_info'}) if ((defined $self->{'vars'}{'vlan_info'}) && (! defined $params{'name'}));
  return($self->{'parent'}->vlan_config(%params));
}

sub table_headers {
  my $self = shift;
  my (%params) = @_;

  if (defined $self->{'vars'}{'table_headers'}) {
    return($self->{'vars'}{'table_headers'});
  } else {
    return($self->{'parent'}->table_headers(%params));
  }
}

sub dump {
  my $self = shift;
  my (@call) = caller(0);
  my ($retstr);

  my ($parent) = $self->{'parent'};
  $self->{'parent'} = 'PARENT' if (defined $self->{'parent'});
  $retstr = $call[1] . ":" . $call[2] . ": I am \n" . Data::Dumper->Dump([$self],[qw(self)]) . "\n"; 
  $self->{'parent'} = $parent if (defined $parent);
  return($retstr);
}

sub SNMP_cache{
  my $self = shift;
  my (%params) = @_;
  
  return($self->{'parent'}->SNMP_cache(%params));
}
	 
sub ifName2SNMPid {
  my $self = shift;
  my (%params) = @_;
  
  return($self->{'parent'}->ifName2SNMPid(%params));
}


1;
