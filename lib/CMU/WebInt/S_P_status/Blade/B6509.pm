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


package CMU::WebInt::S_P_status::Blade::B6509;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade);

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
  my ($i, $j);

  $self->{'vars'}{'blade_type'} = "B6509" if (! defined $self->{'vars'}{'blade_type'});
  $self->{'dev_conf'} = $params{'dev_conf'};
  $self->{'parent'} = $params{'parent'};
  $self->{'vars'}{'blade_num'} = $params{'blade_num'};
  $self->{'vars'}{'port_cnt'} = $blade->{$self->{'vars'}{'blade_type'}}{'Port_cnt'};
  
  foreach $j ('container', 'port') {
    if (exists $self->{'dev_conf'}{'children'}{$j}) {
      foreach $i (@{$self->{'dev_conf'}{'children'}{$j}}) {
	if (defined $i){
	  next if (($i->{'entPhysicalName'} =~ /^Switching/) ||
		   ($i->{'entPhysicalName'} =~ /^MSFC/));
#	  warn __FILE__ . ":" . __LINE__ . ": making P6509 as \n" . Data::Dumper->Dump([$i],[qw(dev_conf)]) . "\n"; 
	  if ((defined $blade->{$self->{'vars'}{'blade_type'}}) &&
	      (defined $blade->{$self->{'vars'}{'blade_type'}}{'Port_construct'})){
	    $self->{'ports'}[$i->{'entPhysicalParentRelPos'}] = eval $blade->{$self->{'vars'}{'blade_type'}}{'Port_construct'};
	    if ($@) {
	      warn __FILE__ . ":" . __LINE__ . ": Constructor failed\n$@\n";
	      next;
	    }
	  } else {
	    $self->{'ports'}[$i->{'entPhysicalParentRelPos'}] = eval $blade->{'B6509_unknown'}{'Port_construct'};
	  }
	  if (! defined $i->{'chassisport'}) {
	    warn __FILE__ . ":" . __LINE__ . ": No Chassis ID for\n " . Data::Dumper->Dump([$i],[qw(dev_conf)]) . "\n";
	    next;
	  }
	  $self->{'ports'}[$i->{'entPhysicalParentRelPos'}]->init( 'parent' => $self,
								   'port_num' => $i->{'portIfIndex'},
								   'dev_conf' => $i
								 );
	  
	}
      }
    }
    
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
    $layout = $blade->{$self->{'vars'}{'blade_type'}}{Layout};
    $val .= "<table class=\"state\" border=\"2\">\n";
    $self->{'vars'}{'blade_type'} =~ /B6509_(.*)/;
    $val .= "<caption><h3>$1 ($self->{'vars'}{'blade_num'})</h3></caption>\n";
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


package CMU::WebInt::S_P_status::Blade::B6509_WS_X6408A_GBIC;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade::B6509);

sub init {
  my $self = shift;
  my (%params) = @_;

  $self->{'vars'}{'blade_type'} = "B6509_WS_X6408A_GBIC";
  $self->SUPER::init(%params);
}
  
package CMU::WebInt::S_P_status::Blade::B6509_WS_X6408_GBIC;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade::B6509);

sub init {
  my $self = shift;
  my (%params) = @_;

  $self->{'vars'}{'blade_type'} = "B6509_WS_X6408_GBIC";
  $self->SUPER::init(%params);
}
  
package CMU::WebInt::S_P_status::Blade::B6509_WS_X6748_GE_TX;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade::B6509);

sub init {
  my $self = shift;
  my (%params) = @_;

  $self->{'vars'}{'blade_type'} = "B6509_WS_X6748_GE_TX";
  $self->SUPER::init(%params);
}
  
package CMU::WebInt::S_P_status::Blade::B6509_WS_X6248_RJ_45;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade::B6509);

sub init {
  my $self = shift;
  my (%params) = @_;

  $self->{'vars'}{'blade_type'} = "B6509_WS_X6248_RJ_45";
  $self->SUPER::init(%params);
}
  
package CMU::WebInt::S_P_status::Blade::B6509_WS_SUP720_3B;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade::B6509);

sub init {
  my $self = shift;
  my (%params) = @_;
  my ($i, $pn);

#  warn __FILE__ . ":" . __LINE__ . ": Initing SUP720 with \n" . Data::Dumper->Dump([$params{dev_conf}],[qw(dev_conf)]) . "\n"; 
  $self->{'vars'}{'blade_type'} = "B6509_WS_SUP720_3B";

  $self->{'dev_conf'} = $params{'dev_conf'};
  $self->{'parent'} = $params{'parent'};
  $self->{'vars'}{'blade_num'} = $params{'blade_num'};
  $self->{'vars'}{'port_cnt'} = $blade->{$self->{'vars'}{'blade_type'}}{'Port_cnt'};

  foreach $i (@{$self->{'dev_conf'}{'children'}{'container'}}) {
    if ((defined $i->{'entPhysicalDescr'}) &&($i->{'entPhysicalDescr'} eq 'Gigabit Port Container' )) {
#      warn __FILE__ . ":" . __LINE__ . ": Processing \n" . Data::Dumper->Dump([$i, $self->{'vars'}, $self->{'vals'}],[qw(dev_conf vars vals)]) . "\n"; 
      $i->{'chassisport'} =~ /(\d+)$/;
      $pn = $1;
      $self->{'ports'}[$pn] = eval $blade->{$self->{'vars'}{'blade_type'}}{'Port_construct'};
      $self->{'ports'}[$pn]->init( 'parent' => $self, 'port_num' => $pn, 'dev_conf' => $i);
#      warn __FILE__ . ":" . __LINE__ . ": New port is \n" . $self->{'ports'}[$pn]->dump();
    }
  }


#  foreach $i (1 .. $self->{'vars'}{'port_cnt'} ) {
#    $self->{'ports'}[$i] = eval $blade->{$self->{'vars'}{'blade_type'}}{'Port_construct'};
#    $self->{'dev_conf'}{'children'}[$i]{'chassisport'} =~ /(\d+)$/;
#    $self->{'ports'}[$i]->init( 'parent' => $self, 'port_num' => $i, 'dev_conf' => $self->{'dev_conf'}{'children'}[$i]);
#  }




#  warn __FILE__ . ":" . __LINE__ . ": sup720 entity is \n" . Data::Dumper->Dump([$params{dev_conf}],[qw(dev_conf)]) . "\n"; 
}
  


package CMU::WebInt::S_P_status::Blade::B6509_blank;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade::B6509);

sub init {
  my $self = shift;
  my (%params) = @_;

  $self->{'vars'}{'blade_type'} = "B6509_blank";
  $self->{'vars'}{'blade_num'} = $params{'blade_num'}
}
  
sub display {
  my $self = shift;
  my (%params) = @_;

  my ($form) = (defined $params{'form'}) ? $params{'form'} : "HTML-table";
  my ($val) = "";
  my ($i, $layout, $row, $col);

  $form = "HTML-table" if ((! defined $form) || (($form ne 'XML') && ($form ne 'HTML-display')));


  if ($form eq "HTML-display") {
    $layout = $blade->{$self->{'vars'}{'blade_type'}}{Layout};
    $val .= "<table class=\"state\" border=\"2\">\n";
    $val .= "<tr>";
    $val .= "<td width=\"1000px\" align=\"center\" height=\"60px\"> <H2>Empty Slot ($self->{'vars'}{'blade_num'})</H2></td>\n";
    $val .= "</tr>";
    $val .= "</table>\n";
  }
  
  return($val);
}

package CMU::WebInt::S_P_status::Blade::B6509_unknown;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars;
# use child classes


# require superclass
require CMU::WebInt::S_P_status::Blade;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter CMU::WebInt::S_P_status::Blade::B6509);

sub init {
  my $self = shift;
  my (%params) = @_;

#  warn __FILE__ . ":" . __LINE__ . ": initing unknown with \n" . Data::Dumper->Dump([$params{dev_conf}],[qw(dev_conf)]) . "\n"; 
  $self->{'vars'}{'blade_type'} = "B6509_unknown";
  $self->{'vars'}{'blade_num'} = $params{'blade_num'};
  $self->{'vars'}{'real_type'} = $params{'dev_conf'}{'entPhysicalModelName'};
}
  
sub display {
  my $self = shift;
  my (%params) = @_;

  my ($form) = (defined $params{'form'}) ? $params{'form'} : "HTML-table";
  my ($val) = "";
  my ($i, $layout, $row, $col);

  $form = "HTML-table" if ((! defined $form) || (($form ne 'XML') && ($form ne 'HTML-display')));


  if ($form eq "HTML-display") {
#    warn __FILE__ . ":" . __LINE__ . ": Displaying unknown blade\n" . $self->dump();
    $layout = $blade->{$self->{'vars'}{'blade_type'}}{Layout};
    $val .= "<table class=\"state\" border=\"2\">\n";
    $val .= "<tr>";
    $val .= "<td width=\"1000px\" align=\"center\" height=\"60px\"> <H2>Cannot draw a $self->{'vars'}{'real_type'} ($self->{'vars'}{'blade_num'})</H2></td>\n";
    $val .= "</tr>";
    $val .= "</table>\n";
  }
  
  return($val);
}


1;
