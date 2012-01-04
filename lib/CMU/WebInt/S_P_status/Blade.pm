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


package CMU::WebInt::S_P_status::Blade;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars qw($blade);
# use child classes
use CMU::WebInt::S_P_status::Blade::B2950_24;
use CMU::WebInt::S_P_status::Blade::B2950_48;
use CMU::WebInt::S_P_status::Blade::B3500_24;
use CMU::WebInt::S_P_status::Blade::B3500_48;
use CMU::WebInt::S_P_status::Blade::B3750_12;
use CMU::WebInt::S_P_status::Blade::B3750_24TS;
use CMU::WebInt::S_P_status::Blade::B3750_48TS;
use CMU::WebInt::S_P_status::Blade::B3750_24T;
use CMU::WebInt::S_P_status::Blade::B6509;

# require superclass

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter UNIVERSAL);

sub new {
  my $self = {};
  my (%params) = @_;

  bless($self, "CMU::WebInt::S_P_status::Blade");
  $self->init();
  return($self);
}


sub display {
  my $self = shift;
  my (%params) = @_;

  my ($form) = (defined $params{'form'}) ? $params{'form'} : "HTML-table";
  my ($val) = "";
  my ($i, $layout, $row, $col);

  $form = "HTML-table" if ((! defined $form) || (($form ne 'XML') && ($form ne 'HTML-display')));


  if ($form eq "HTML-table") {
    foreach $i (1 .. $self->{'vars'}{'port_cnt'}) {
      $val .= $self->{'ports'}[$i]->display('form' => $form) if (defined $self->{'ports'}[$i]);
    }
  } elsif ($form eq "HTML-display") {
    $layout = $blade->{$self->{'vars'}{'blade_type'}}{Layout};
    $val .= "<table class=\"state\" border=\"2\">\n";
    foreach $row (@$layout) {
      $val .= "<tr>";
      foreach $col ( @$row) {
	$val .= "<td>" . $self->{'ports'}[$col]->display('form' => $form) . "</td>" if ((defined $col) && (defined $self->{'ports'}[$col]));
	$val .= "<td></td>" if (! defined $col);
      }
      $val .= "</tr>";
    }
    $val .= "</table>\n";
  }
  
  return($val);
}


sub init {
  my $self = shift;
  my (%params) = @_;
  my ($i, $pn);

  $self->{'dev_conf'} = $params{'dev_conf'};
  $self->{'parent'} = $params{'parent'};
  $self->{'vars'}{'blade_number'} = $params{'blade_num'};
  $self->{'vars'}{'port_cnt'} = $blade->{$self->{'vars'}{'blade_type'}}{'Port_cnt'};

  foreach $i (1 .. $self->{'vars'}{'port_cnt'} ) {
    $self->{'ports'}[$i] = eval $blade->{$self->{'vars'}{'blade_type'}}{'Port_construct'};
    if (defined $self->{'dev_conf'}{'children'}[$i]{'chassisport'}) {
      $self->{'dev_conf'}{'children'}[$i]{'chassisport'} =~ /(\d+)$/;
      $pn = $1;
    } else {
      $pn = $self->{'dev_conf'}{'children'}[$i]{'portIfIndex'};
    }
    $self->{'ports'}[$i]->init( 'parent' => $self, 'port_num' => $pn, 'dev_conf' => $self->{'dev_conf'}{'children'}[$i]);
  }

}


sub update {
  my $self = shift;
  my (%params) = @_;

}


sub installed_in {
  my $self = shift;
  my (%params) = @_;

}


sub child_count {
  my $self = shift;
  my (%params) = @_;

}


sub get_child {
  my $self = shift;
  my (%params) = @_;

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

  foreach (@{$self->{'ports'}}) {
    $_->SNMP_init() if (defined $_);
  }
}

sub netreg_init {
  my $self = shift;

  foreach (@{$self->{'ports'}}) {
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
  $retstr =  $call[1] . ":" . $call[2] . ": I am \n" . Data::Dumper->Dump([$self],[qw(self)]) . "\n"; 
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
