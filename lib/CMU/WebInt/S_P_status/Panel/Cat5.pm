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


package CMU::WebInt::S_P_status::Panel::Cat5;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Panel;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Panel);

sub new {
  my $type = shift;
  my $self = {};
  my (%params) = @_;

  $self->{'vars'}{'panel_type'} = "Cat5";
  bless($self, $type);
  return($self);
}


sub init {
  my $self = shift;
  my (%params) = @_;
  my ($i, $port_type, $port, $read_comm);
  my ($devtype, $chastype, $bladetype, $name, $status);

#  warn __FILE__ . ":" . __LINE__ . ": Cat5::init called by " . join(" <:> ", caller(0)) . " with " . join ("\n", map { Data::Dumper->Dump([$params{$_}],["params{$_}"]) if ($_ ne 'parent') } (keys %params)) . "\n";

  $status = undef;
  $self->{'parent'} = $params{'parent'};
  $self->{'vars'}{'panel_num'} = $params{'pane'};
  $self->{'vars'}{'port_cnt'} = $panel->{$self->{'vars'}{'panel_type'}}{'Port_cnt'};
  
  $self->{'ports'}[0] = undef;
  foreach $i (1 .. $self->{'vars'}{'port_cnt'} ) {
#    warn __FILE__ . ":" . __LINE__ . ": Processing port $i\n";
    $name = $self->dev_from_port(port => sprintf("%02d", $i));
    if (! defined $name) {
#      warn __FILE__ . ":" . __LINE__ . ": No name\n";
      $self->{'ports'}[$i] = undef;
      next;
    }
    $port = $self->snmp_port_num(port => sprintf("%02d", $i));
    $read_comm = $self->get_read_comm("name" => $name);

    $devtype = $self->get_device_type(name => $name);
    if (defined $device->{$devtype}) {
      if ((defined $device->{$devtype}) && (defined $device->{$devtype}{'Port_type'})) {
	$self->{'ports'}[$i] = eval $device->{$devtype}{'Port_construct'};
      } else {
	$chastype = $device->{$devtype}{'Chassis_type'};
	if ((defined $chassis->{$chastype}) && (defined $chassis->{$chastype}{'Port_type'})) {
	  $self->{'ports'}[$i] = eval $chassis->{$chastype}{'Port_construct'};
	} else {
	  $bladetype = $chassis->{$chastype}{'Blade_type'}[0];
	  if ((defined $blade->{$bladetype}) && (defined $blade->{$bladetype}{'Port_type'})) {
	    $port_type = $blade->{$bladetype}{'Port_type'};
	    $self->{'ports'}[$i] = eval $blade->{$bladetype}{'Port_construct'};
	  } else {
	    warn __FILE__ . ":" . __LINE__ . ": No port definition available for $name\n";
	    $self->{'ports'}[$i] = self->new_port('port_num' => $port, 'name' => $name, 'read_comm' => $read_comm, 'label' => $i, 'status' => $status);
	    $status = 'misconf';
	  }
	}
      }
      
      
    }
    # FIXME - Here lies problems for devices with multiple blade types defined
#    warn __FILE__ . ":" . __LINE__ . ": " .
#      "\$name =  $name, " . 
#	"\$devtype = $devtype, " .
#	  "\$chastype = $chastype, " .
#	    "\$bladetype = $bladetype, " . 
#	      "\$port_type = $port_type, " .
#		"\$port = $port\n" .
#		  "\n";
   
    

    $self->{'ports'}[$i]->init( 'parent' => $self,
				'port_num' => $port,
				'name' => $name,
				'read_comm' => $read_comm,
				'label' => $i,
				'status' => $status)
      if (defined  $self->{'ports'}[$i]);
  }
  

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
    $layout = $panel->{$self->{'vars'}{'panel_type'}}{Layout};
    $val .= "<table class=\"state\" border=\"2\">\n";
    foreach $row (@$layout) {
      $val .= "<tr>";
      foreach $col ( @$row) {
	if (defined $col) {
	  $val .= "<th>$col</th>";
	} else {
	  $val .= "<th></th>";
	}
      }
      $val .= "</tr><tr>";
      foreach $col ( @$row) {
	if (defined $col) {
	  if (defined $self->{'ports'}[$col]) {
	    $val .= "<td>" . $self->{'ports'}[$col]->display('form' => $form) . "</td>" 
	  } else {
	    $val .= "<td><div class=\"plug\">&nbsp;</div></td>";
	  }
	} else {
	  $val .= "<td></td>";
	}
      }
      $val .= "</tr>";
    }
    $val .= "</table>\n";
  }
  
  return($val);
}

1;
