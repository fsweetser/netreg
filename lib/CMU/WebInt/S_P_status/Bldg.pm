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


package CMU::WebInt::S_P_status::Bldg;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes
#use CMU::WebInt::S_P_status::Chassis;
use CMU::WebInt::S_P_status::Closet;


# require superclass

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter UNIVERSAL);

sub new {
  my $type = shift;
  my $self = {};
  my (%params) = @_;

  bless($self, $type);
  return($self);
}


sub display {
  my $self = shift;
  my (%params) = @_;
  my ($val, $i, $head, $tail);
  $val = "";
  $head = "";
  $tail = "";


#  $val .= Data::Dumper->Dump([$self],[qw(self)]) . "\n"; 

  if ($self->{'vars'}{'closet_cnt'} > 1) {
    $head = "<table border=\"6\"><tr><th>Building $self->{'vars'}{'bldg'}</th></tr><td>\n";
    $tail = "</td></tr></table>\n";
  }
  $val .= $head;
  foreach $i (1 .. $self->{'vars'}{'closet_cnt'}) {
    $val .= $self->{'closets'}[$i]->display(%params);
  }
  $val .= $tail;
  return($val);
}


sub init {
  my $self = shift;
  my (%params) = @_;
  
#  warn __FILE__ . ":" . __LINE__ . ": Bldg::init called by " . join(" <:> ", caller(0)) . " with " . join ("\n", map { Data::Dumper->Dump([$params{$_}],["params{$_}"]) if ($_ ne 'parent') } (keys %params)) . "\n";

  $self->{'parent'} = $params{'parent'};
  
  if (($params{'clos'} =~ /^[0-9A-Z]$/)) {
    $self->{'vars'}{'closet_cnt'} = 1;
  } else {
    warn __FILE__ . ":" . __LINE__ . ": Multiple closet not supported\n\$params{'clos'} = $params{'clos'}\n";
    return
  }
  $self->{bldg_num} = $params{'bldg'};
  
  foreach ( 1 .. $self->{'vars'}{'closet_cnt'} ) {
    $self->{'closets'}[$_] = CMU::WebInt::S_P_status::Closet->new();
    $self->{'closets'}[$_]->init(
				 closet_num => $params{'clos'},
				 rack => $params{'rack'},
				 pane => $params{'pane'},
				 parent => $self
				);
  }
  
  
}


sub get_read_comm {
  my $self = shift;
  my (%params) = @_;

  return($self->{'vars'}{'read_comm'}) if(defined $self->{'vars'}{'read_comm'} && ($self->{'vars'}{'read_comm'} ne ""));

  return($self->{'parent'}->get_read_comm(%params));
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

sub panel_type {
  my $self = shift;
  my $panel_type;
  
  if (defined $self->{'vars'}{'panel_type'}) {
    $panel_type = $self->{'vars'}{'panel_type'};
  } else {
    $panel_type = $self->get_device_type();
  }
    
  if ($panel_type eq "Mixed") {
# FIXME This is where multiple closet support needs to be added
  }
  return($panel_type);
}

sub panel_data {
  my $self = shift;

  return($self->{'vars'}{'data'}, $self->{'vars'}{'datamap'}) if (defined $self->{'vars'}{'data'});
  return($self->{'parent'}->panel_data());
}


sub get_device_type {
  my $self = shift;
  my (%params) = @_;
  if ((defined $self->{'vars'}{'device_type'}) && (! defined $params{'name'})) {
    return($self->{'vars'}{'device_type'});
  } else {
    return($self->{'parent'}->get_device_type(%params));
  }
}

sub s_p_name {
  my $self = shift;
  my (%params) = @_;
    
  if (defined $self->{'vars'}{'name'} && (! defined $params{'id'}) && (! defined $params{'vpid'})) {
    return ($self->{'vars'}{'name'});
  } else {
    return($self->{'parent'}->s_p_name(%params));
  }
}

sub SNMP_init {
  my $self = shift;

  foreach (@{$self->{'closets'}}) {
    $_->SNMP_init() if (defined $_);
  }
}

sub netreg_init {
  my $self = shift;

  foreach (@{$self->{'closets'}}) {
    $_->netreg_init() if (defined $_);
  }
}

sub get_dbh {
  my $self = shift;

  return($self->{'vars'}{'dbh'}) if(defined $self->{'vars'}{'dbh'} && ($self->{'vars'}{'dbh'} ne ""));

  return($self->{'parent'}->get_dbh());
}

sub g_context {
  my $self = shift;

  if (defined $self->{'vars'}{'g_context'}) {
    return($self->{'vars'}{'g_context'})
  } else {
    return($self->{'parent'}->g_context());
  }
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

sub make_port {
  my $self = shift;
  my (%params) = @_;

  return ($self->{'parent'}->make_port(%params));
}

sub vlan_config{
  my $self = shift;
  my (%params) = @_;
  my ($vlan, $port, $bits);

  return($self->{'vars'}{'vlan_info'}) if ((defined $self->{'vars'}{'vlan_info'}) && (! defined $params{'name'}));
  return($self->{'parent'}->vlan_config(%params));
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
