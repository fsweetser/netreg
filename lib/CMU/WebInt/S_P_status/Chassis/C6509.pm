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


# $chassis = {
#	      'chassis_type' => "Chassis ID from chassis table in vars.pm",
#	      'Parent' => "The parent device that this is mounted in",
#	      'chassis_num' => "number of this chassis",
#	      'blade_cnt' => "The number of blades in this chassis";
#	      'blades'[] => "array of blades in the device";
#	     };


package CMU::WebInt::S_P_status::Chassis::C6509;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars qw($blade $chassis);
# use child classes
#use CMU::WebInt::S_P_status::Chassis;

# require superclass
require CMU::WebInt::S_P_status::Chassis;


use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Chassis);

sub new {
  my $type = shift;
  my (%params) = @_;
  my $self = {};

  bless($self, $type);
  $self->init(%params) if (defined $params{'parent'});
  return($self);
}


sub init {
  my $self = shift;
  my (%params) = @_;
  my ($i);

  $self->{'vars'}{'chassis_type'} = "C6509";

  $self->{'parent'} = $params{'parent'};
  $self->{'dev_conf'} = $params{'dev_conf'};
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
#      warn __FILE__ . ":" . __LINE__ . ": Constructing a blade of type $self->{'blades'}[$i]\n";
      $self->{'blades'}[$i] = eval ($self->{'blades'}[$i]) if (defined $self->{'blades'}[$i]);
      warn __FILE__ . ":" . __LINE__ . ": Blade creation failed: $@" if ($@);
    }
    $self->{'blades'}[$i]->init( 'parent' => $self,'blade_num' => $i, 'dev_conf' => $self->{'dev_conf'}{children}{container}[$i]{children}{module}[1])
      if defined $self->{'blades'}[$i];

  }

  
}

sub get_blade_construct {
  my ($self) = shift;
  my %params = @_;

  my $blade_num = $params{blade_num};
  my $dev_conf = $params{dev_conf};

  my $new_blade = $dev_conf->{children}{container}[$blade_num];
  my $type;
  
#  warn __FILE__ . ":" . __LINE__ . ": Building a dynamic blade.\n";

#  warn __FILE__ . ":" . __LINE__ . ": $new_blade->{'entPhysicalName'}\n";
  return(undef) if ($new_blade->{'entPhysicalName'} !~ /physical slot $blade_num/i);

#  print "<pre>\n";
#  print "" . Data::Dumper->Dump([$new_blade],[qw(bladeinfo)]) . "\n";
#  print "</pre>\n";

  return("new CMU::WebInt::S_P_status::Blade::B6509_blank")
    if (! defined $new_blade->{children}{module});


  $type = $new_blade->{children}{module}[1]{'entPhysicalModelName'};
  $type =~ s/-/_/g;
#  warn __FILE__ . ":" . __LINE__ . ": type = $type\n";
#  warn __FILE__ . ":" . __LINE__ . ": Checking on B6509_$type\nin " . join (", ", sort keys %$blade) . "\n";
  return("new CMU::WebInt::S_P_status::Blade::B6509_unknown") if (! defined $blade->{"B6509_$type"});
  return("new CMU::WebInt::S_P_status::Blade::B6509_$type");
}


1;
