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


package CMU::WebInt::S_P_status::Port::P3750;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes

# require superclass
require CMU::WebInt::S_P_status::Port;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Port);

sub new {
  my $type = shift;
  my $self = {};
  my (%params) = @_;

  bless($self, $type);
  return($self);
}


sub init {
  my $self = shift;
  my (%params) = @_;

  $self->{'parent'} = $params{'parent'};
  $self->{'vals'}{display_width} = "plug";
  $self->{'vars'}{'read_comm'} = $params{'read_comm'} if (defined $params{'read_comm'});
  $self->{'dev_conf'} = $params{'dev_conf'};
  $self->{'dev_conf'} = $self->get_dev_conf(port => $params{port_num}, name => $params{'name'}, read_comm => $self->{'vars'}{'read_comm'})
    if (! defined $self->{'dev_conf'});
  $self->{'vars'}{'name'} = $params{'name'} if (defined $params{'name'});
  $self->{'vars'}{'port_type'} = "P3750";
  $self->{'vars'}{'snmp_port_num'} = (defined $self->{'dev_conf'}{'entPhysicalAlias'} ? $self->{'dev_conf'}{'entPhysicalAlias'} : $params{'port_num'});
  $self->{'vals'}{'Port'} = $self->{'dev_conf'}{'entPhysicalName'};
  $self->{'vars'}{'oids'} = { %{$port->{$self->{'vars'}{'port_type'}}{'oids'}}};
  $self->{'vars'}{'netreg'} = [ @{$port->{$self->{'vars'}{'port_type'}}{'netreg'}} ];
  $self->{'vars'}{'name'} = $self->{'parent'}->s_p_name() if (! defined $self->{'vars'}{'name'});
  $self->{'vals'}{'Device'} = $self->{'vars'}{'name'};
  $self->{'vals'}{'PortStatus'} = 'up';
  $self->{'vals'}{'Loc'} = defined $params{'label'} ? $params{'label'} : $params{'port_num'};
  $self->{'vars'}{'chassisport'} =   $self->{'dev_conf'}{'chassisport'};
  $self->{'vars'}{'portIfIndex'} =   $self->{'dev_conf'}{'portIfIndex'};

}


sub bad_snmp_num_chk {
  my $self = shift;

  return() if ((defined $self->{'vals'}) &&
	       ( defined $self->{'vals'}{'PortStatus'}) &&
	       (($self->{'vals'}{'PortStatus'} eq 'misconf')) ||
	       (($self->{'vals'}{'PortStatus'} eq 'error')));
  
  if (! defined $self->{'vals'}{'Port'}) {
    $self->{'vals'}{'PortStatus'} = 'error';
    $self->{'vals'}{'Port'} = "<div style=\"color:red;\">Probable bad port number<br />in netreg</div>";
  }
  return;
}


sub speed_chk {
  my $self = shift;

  return() if ((defined $self->{'vals'}) &&
	       ( defined $self->{'vals'}{'PortStatus'}) &&
	       (($self->{'vals'}{'PortStatus'} eq 'misconf')) ||
	       (($self->{'vals'}{'PortStatus'} eq 'error')));


  return if (($self->{'vals'}{'Speed/NetReg'} eq 'Unconf'));

  if ((defined $self->{'vals'}{'Speed/NetReg'}) &&
      ($self->{'vals'}{'Speed/NetReg'} ne $self->{'vals'}{'Speed/Configured'})) {
    $self->{'vals'}{'PortStatus'} = 'misconf';
    $self->{'vals'}{'Speed/NetReg'} = "<div style=\"color:red;\">$self->{'vals'}{'Speed/NetReg'}</div>";
  }
  
#  warn __FILE__ . ":" . __LINE__ . ": Port $self->{'vars'}{'snmp_port_num'} failed speed_chk\n" if ($self->{'vals'}{'PortStatus'} eq 'misconf');
  return;

}

sub duplex_chk {
  my $self = shift;

  return() if ((defined $self->{'vals'}) &&
	       ( defined $self->{'vals'}{'PortStatus'}) &&
	       (($self->{'vals'}{'PortStatus'} eq 'misconf')) ||
	       (($self->{'vals'}{'PortStatus'} eq 'error')));

  return if (($self->{'vals'}{'Duplex/NetReg'} eq 'Unconf'));

  if ((defined $self->{'vals'}{'Duplex/NetReg'}) &&
      ($self->{'vals'}{'Duplex/NetReg'} ne $self->{'vals'}{'Duplex/Configured'})) {
    $self->{'vals'}{'PortStatus'} = 'misconf';
    $self->{'vals'}{'Duplex/NetReg'} = "<div style=\"color:red;\">$self->{'vals'}{'Duplex/NetReg'}</div>";
  }
  
#  warn __FILE__ . ":" . __LINE__ . ": Port $self->{'vars'}{'snmp_port_num'} failed duplex_chk\n" if ($self->{'vals'}{'PortStatus'} eq 'misconf');

  return;
}

sub status_chk {
  my $self = shift;

  if ((defined $self->{'vals'}) &&
      ( defined $self->{'vals'}{'PortStatus'}) &&
      (($self->{'vals'}{'PortStatus'} eq 'misconf')) ||
      (($self->{'vals'}{'PortStatus'} eq 'error'))) {
    return;
  } elsif (($self->{'vals'}{'Status/NetReg'} eq 'Unconf') && ( $self->{'vals'}{'Status/Admin'} eq 'down')) {
    $self->{'vals'}{'PortStatus'} = 'partitioned';
  } elsif (($self->{'vals'}{'Status/Admin'} eq 'up') && 
	   ($self->{'vals'}{'Status/Oper'} eq 'down')) {
    $self->{'vals'}{'PortStatus'} = 'nolink';
  }
#  warn __FILE__ . ":" . __LINE__ . ": Port $self->{'vars'}{'snmp_port_num'} failed status_chk\n" if ($self->{'vals'}{'PortStatus'} eq 'misconf');
  return;
  
}

sub portfast_chk {
  my $self = shift;

  return() if ((defined $self->{'vals'}) &&
	       ( defined $self->{'vals'}{'PortStatus'}) &&
	       (($self->{'vals'}{'PortStatus'} eq 'misconf')) ||
	       (($self->{'vals'}{'PortStatus'} eq 'error')));

  return if (($self->{'vals'}{'PortFast/NetReg'} eq 'Unconf'));

  if ((defined $self->{'vals'}{'PortFast/NetReg'}) &&
      ($self->{'vals'}{'PortFast/NetReg'} ne $self->{'vals'}{'PortFast/Curr'})) {
      $self->{'vals'}{'PortStatus'} = 'misconf';
      $self->{'vals'}{'PortFast/NetReg'} = "<div style=\"color:red;\">$self->{'vals'}{'PortFast/NetReg'}</div>";
    }
  
#  warn __FILE__ . ":" . __LINE__ . ": Port $self->{'vars'}{'snmp_port_num'} failed portfast_chk >>$self->{'vals'}{'PortFast/NetReg'}<< >>$self->{'vals'}{'PortFast/Curr'}<<\n" if ($self->{'vals'}{'PortStatus'} eq 'misconf');

  return;
}

sub vlan_chk {
  my $self = shift;
  my ($nname, $nnum, $cname, $cnum);
  my (@nr, @cf, $nr, $cf);

#  warn __FILE__ . ":" . __LINE__ . ": vlan_chk on " . Data::Dumper->Dump([$self->{'vals'}],[qw(vals)]) . "\n"; 
  return() if ((defined $self->{'vals'}) &&
	       ( defined $self->{'vals'}{'PortStatus'}) &&
	       (($self->{'vals'}{'PortStatus'} eq 'misconf') ||
		(($self->{'vals'}{'PortStatus'} eq 'error'))));
  
  
  return() if ($self->{'vals'}{'Vlan/NetReg'} eq 'Unconf');

  @nr = split(/\n/, $self->{'vals'}{'Vlan/NetReg'});
  @cf = split(/\n/, $self->{'vals'}{'Vlan/Curr'});

#  warn __FILE__ . ":" . __LINE__ . ": Arrays are\n" . Data::Dumper->Dump([\@nr, \@cf],[qw(nr cf)]) . "\n"; 

  if ((scalar @nr) != (scalar @cf)) {
    $self->{'vals'}{'PortStatus'} = 'misconf';
#    warn __FILE__ . ":" . __LINE__ . ": Array sizes don't match\n";
    $self->{'vals'}{'Vlan/NetReg'} = "<div style=\"color:red;\">$self->{'vals'}{'Vlan/NetReg'}</div>";
    return;
  }
  
  foreach (@nr) {
    ($nname, $nnum) = split(/\//, $_);
    if ($nnum =~ /(^\d+)/) {
      $nnum = $1;
    } else {
      $nnum = 0;
    }
    $nr->{$nnum} = $nname;
  }

  foreach (@cf) {
    ($cname, $cnum) = split(/\//, $_);
    if ($cnum =~ /(^\d+)/) {
      $cnum = $1;
    } else {
      $cnum = 0;
    }
    $cf->{$cnum} = $cname;
  }
#  warn __FILE__ . ":" . __LINE__ . ": hashes are\n" . Data::Dumper->Dump([$nr, $cf],[qw(nr cf)]) . "\n"; 

  # Since both hashes have the same number of elements,
  #  one way check is all that is needed
  foreach (keys %$nr) {
    if (! defined $cf->{$_}) {
#      warn __FILE__ . ":" . __LINE__ . ": Couldn't find $_ ($nr->{$_})\n";
      $self->{'vals'}{'PortStatus'} = 'misconf';
      $self->{'vals'}{'Vlan/NetReg'} = "<div style=\"color:red;\">$self->{'vals'}{'Vlan/NetReg'}</div>";
      return;
    }
  }
  warn __FILE__ . ":" . __LINE__ . ": Port $self->{'vars'}{'snmp_port_num'} failed vlan_chk\n" if ($self->{'vals'}{'PortStatus'} eq 'misconf');
  return;
}



sub get_dev_conf {
  my $self = shift;
  my %params = @_;
  my (@snmp, @type, $cfgobj, $conf);
  my ($tmp, $ifId, $chassisport);

  return(undef) if (
		    (! defined $params{'name'}) ||
		    (! defined $params{'port'}) ||
		    (! defined $params{'read_comm'}));


  @snmp = $self->SNMP_cache(community => $params{'read_comm'},
			    host => $params{'name'},
			    base => '.1.3.6.1.4.1.9.5.1.4.1.1.11',
			    walk => 1);
  
  foreach (@snmp) {
    ($chassisport, $ifId) = split(/:/, $_);
    $tmp->{$ifId} = $chassisport;
  }
  $conf->{chassisport} = $tmp->{$params{'port'}};
  $conf->{portIfIndex} = $params{'port'};
  
  @snmp = $self->SNMP_cache(community => $params{'read_comm'},
			    host => $params{'name'},
			    base => ".1.3.6.1.2.1.31.1.1.1.1.$params{'port'}",
			    walk => 0);

  $conf->{'entPhysicalName'} = $snmp[0];

  return($conf);
}

sub old_display {
  my $self = shift;
  my (%params) = @_;
  my ($var) = "";

  my ($parent) = $self->{'parent'};
 
  $self->{'parent'} = 'PARENT';
  $var .= "<pre>" . Data::Dumper->Dump([$self],[qw(self)]) . "\n</pre>";
 
  $self->{'parent'} = $parent;

  return($var);
}
1;


