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


package CMU::WebInt::S_P_status;
use strict;
use warnings;

use UNIVERSAL;
use CMU::WebInt::S_P_status::vars qw($table_headers $typemap $device $chassis $blade $port);
use CMU::WebInt::S_P_status::Device;
use CMU::WebInt::S_P_status::Bldg;
use CMU::WebInt::S_P_status::Closet;
use CMU::WebInt::S_P_status::Rack;
use CMU::WebInt::S_P_status::Panel;
use CMU::WebInt::S_P_status::Chassis;
use CMU::WebInt::S_P_status::Blade;
use CMU::WebInt::S_P_status::Port;

use SNMP_util;
use SNMP;
use CGI; 
use DBI; 

#use Devel::DProf;

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter UNIVERSAL);

$SNMP_Session::suppress_warnings = 100;

sub new {
  my $type = shift;
  my %params = @_;
  my $self = {};
  my @mibs;
  $self = bless($self, $type);

  $self->{'vars'}{'init_state'} = $self->init(%params);

  return($self);
}



# This begins the display section, make adjustments here for HTML vs XML

sub display {
  my $self = shift;
  my %params = @_;
  
  $params{'form'} = "HTML-table" if (! defined $params{'form'});
  my ($form) = $params{'form'};
  my ($val) = "";
  my ($i, $head, $tail, $pre, $post);

  $form = "HTML-table" if ((! defined $form) || (($form ne 'XML') && ($form ne 'HTML-display')));

  if (($form eq "HTML-table") && ($self->{'vars'}{'init_state'} eq '1') ) {
    $head = "<table class=\"state\" border=\"2\">\n" . $self->make_table_header(form => $form) ;
    $tail = "</table>\n";
    $pre = "";
    $post = "";
  } elsif (($form eq 'HTML-display') && ($self->{'vars'}{'init_state'} eq '1')) {
    $head = "<div class=\"h_scroll\"><table class=\"state\" border=\"4\">\n";
    $pre = "<tr><td>";
    $post = "</td></tr>\n";
    $tail = "</td></tr></table></div>\n";
    $tail .= "<table border=\"2\">\n";
    $tail .= "<tr>\n";
    $tail .= "<td rowspan=\"2\">Key</td>\n";
    $tail .= "<td align=\"center\" >Unconfigured</td>\n";
    $tail .= "<td align=\"center\" >Up</td>\n";
    $tail .= "<td align=\"center\" >No Link</td>\n";
    $tail .= "<td align=\"center\" >Partitioned</td>\n";
    $tail .= "<td align=\"center\" >Error</td>\n";
    $tail .= "<td align=\"center\" >Misconfigured</td>\n";
    $tail .= "</tr>\n";
    $tail .= "<tr>\n";
    $tail .= "<td align=center>\n";
    $tail .= "<div class=\"plug\">\n";
    $tail .= "<div class=\"buttons\">\n";
    $tail .= "<div class=\"unconf\">\n";
    $tail .= "<a name=\"unconf\">&nbsp;</a>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</td>\n";
    $tail .= "<td align=center>\n";
    $tail .= "<div class=\"plug\">\n";
    $tail .= "<div class=\"buttons\">\n";
    $tail .= "<div class=\"up\">\n";
    $tail .= "<a name=\"up\">&nbsp;</a>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</td>\n";
    $tail .= "<td align=center>\n";
    $tail .= "<div class=\"plug\">\n";
    $tail .= "<div class=\"buttons\">\n";
    $tail .= "<div class=\"nolink\">\n";
    $tail .= "<a name=\"nolink\">&nbsp;</a>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</td>\n";
    $tail .= "<td align=center>\n";
    $tail .= "<div class=\"plug\">\n";
    $tail .= "<div class=\"buttons\">\n";
    $tail .= "<div class=\"partitioned\">\n";
    $tail .= "<a name=\"partitioned\">&nbsp;</a>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</td>\n";
    $tail .= "<td align=center>\n";
    $tail .= "<div class=\"plug\">\n";
    $tail .= "<div class=\"buttons\">\n";
    $tail .= "<div class=\"error\">\n";
    $tail .= "<a name=\"error\">&nbsp;</a>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</td>\n";
    $tail .= "<td align=center>\n";
    $tail .= "<div class=\"plug\">\n";
    $tail .= "<div class=\"buttons\">\n";
    $tail .= "<div class=\"misconf\">\n";
    $tail .= "<a name=\"misconfig\">&nbsp;</a>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</div>\n";
    $tail .= "</td>\n";
    $tail .= "</tr>\n";
    $tail .= "</table>\n";
    
  } elsif (($self->{'vars'}{'init_state'} ne '1') ) {
    if (($form eq "HTML-display")) {
      print "<h2>$self->{'vars'}{'init_state'}</h2>\n";
    };
    return;
  } else {
    
    warn __FILE__ . ":" . __LINE__ . ": Don't know how to display \"$form\"\n";
    return;
  }
  
  $val .= $head;
  if (! defined $self->{'device'}) {
    $val .= "<h1>Do not know how to query/display " .
      ((defined $self->{'vars'}{'device_type'}) ? "a $self->{'vars'}{'device_type'}" : "an unknown device") .
	"</h1>\n";
    $val .= "<pre>" . Data::Dumper->Dump([$self],[qw(self)]) . "\n</pre>"; 
  } else {
    $val .= $pre . $self->{'device'}->display('form' => $form) . $post if (defined $self->{'device'}) ;
  }
  $val .= $tail;
  return($val);
}

sub make_table_header {
  my $self = shift;
  my %params = @_;

  my $val = "";
  my ($tab, @parts, $top);
  my ($display, $i);
  my ($dipos);

  $tab = [ @{$self->{'vars'}{'table_headers'}} ];

  $display = [];

  $i = 0;
  foreach (@$tab) {
    @parts = split(/\//, $_, 2);
    $top = shift @parts;
    if (! defined $dipos->{$top}) {
      push(@$display, [ $top ]);
      $dipos->{$top} = $#$display;
      $display->[$dipos->{$top}] = [ $top ];
    }
    push(@{$display->[$dipos->{$top}]}, @parts);
  }
  
  $val .= "<tr class=\"TR\">";
  $val .= join ("\n", map { "<th class=\"TH\" style=\"text-align: center\" " . (($#$_ > 0) ? "colspan=\"$#$_\"" : "rowspan=\"2\"") . " >" . shift (@$_) . "</th>"} @$display);
  $val .= "</tr>\n";

  $val .= "<tr class=\"TR\">";
  foreach $i (@$display) {
    if ((scalar $i) > 0) {
      $val .= join("\n", map { "<th class=\"TH\">" . $_ . "</th>"} @$i);
    }
  }
  $val .= "</tr>\n";

  return($val);
  
}

sub init {
  my $self = shift;
  my %params = @_;
  my ($name);
  my ($bldg, $blpos, $err, $dbh);

#  Determine device type
  if ((defined $params{name}) && ($params{name} ne "0")) {
    $name = $params{name};
    $self->{'vars'}{'type'} = "device";
  } elsif (
	   (defined $params{bldg}) && ($params{bldg} ne "0") &&
	   (defined $params{clos}) && ($params{clos} ne "0") &&
	   (defined $params{rack}) && ($params{rack} ne "0") &&
	   (defined $params{pane}) && ($params{pane} ne "0") 
	  ) {

    $self->{'vars'}{'type'} = "panel";
    $self->{'vars'}{'bldg'} = $params{bldg};

    if ($self->{'vars'}{'bldg'} !~ /^[0-9]+$/) {
      $dbh = $self->get_dbh();
      ($bldg, $err) = CMU::Netdb::list_buildings($dbh, 'netreg', "building.abbreviation like '$self->{'vars'}{'bldg'}'");
      if ((! ref $bldg) || $#$bldg != 1 ) {
	return ("Error: Could not parse building name, please try again");
      } else {
	$blpos = CMU::Netdb::makemap(shift @$bldg);
	$self->{'vars'}{'bldg'} = $bldg->[0][$blpos->{'building.building'}];
      }
    }
    $self->{'vars'}{'clos'} = $params{clos};
    $self->{'vars'}{'rack'} = $params{rack};
    $self->{'vars'}{'pane'} = $params{pane};
    $name = "$self->{'vars'}{'bldg'} - $self->{'vars'}{'clos'}$self->{'vars'}{'rack'}$self->{'vars'}{'pane'}";
  } else {
    warn __FILE__ . ":" . __LINE__ . ": Processing unknown\n";
    $self->{'vars'}{'type'} = "unknown";
  }
# initialize global level parameters
  $self->{'vars'}{'g_context'} = $params{'g_context'};
  $self->{'vars'}{'name'} = $name;
  $self->{'vars'}{'parent'} = undef;
  $self->{'vars'}{'device_type'} = (defined $params{'device_type'}) ? $params{'device_type'} : $self->get_device_type();
  $self->{'vars'}{'table_headers'} = [ @$table_headers ];

# create correct type of device or building

  if ($self->{'vars'}{'type'} eq 'device') {
    shift(@{$self->{'vars'}{'table_headers'}});
    $self->{'vars'}{'read_comm'} = (defined $params{'read_comm'}) ? $params{'read_comm'} : $self->get_read_comm();
    if ((defined $device->{$self->{'vars'}{'device_type'}}) && (defined $device->{$self->{'vars'}{'device_type'}}{'Device_construct'})) {
      $self->{'device'} = eval $device->{$self->{'vars'}{'device_type'}}{'Device_construct'};
    } else {
      warn __FILE__ . ":" . __LINE__ . ": Cannot instantiate $self->{'vars'}{'name'} as a $self->{'vars'}{'device_type'}\n";
      return("Error: Do not know how to display a $self->{'vars'}{'device_type'}");
    }
    
  } elsif ($self->{'vars'}{'type'} eq 'panel') {
    $self->{'device'} = new CMU::WebInt::S_P_status::Device;
  } else {
    warn __FILE__ . ":" . __LINE__ . ": Cannot instanciate $self->{'vars'}{'name'}\n";
    return("Do not know how to display $self->{'vars'}{'name'}");
  }

  $self->{'device'}->init(type => $self->{'vars'}{'type'},
			  name => $self->{'vars'}{'name'},
			  device_type => $self->{'vars'}{'device_type'},
			  parent => $self,
			  bldg => $self->{'vars'}{'bldg'},
			  clos => $self->{'vars'}{'clos'},
			  rack => $self->{'vars'}{'rack'},
			  pane => $self->{'vars'}{'pane'}
			 );


# Do initializations requiring external information

  $self->SNMP_init();
  $self->netreg_init();
  return(1);
}

sub get_device_type {
  my $self = shift;
  my %params = @_;
  my ($data, $dapos, $err, $isIBM, $isCAT, $isCAT48);
  my ($read_comm, $name, $bldg, $blpos, @result);

  return($self->{'vars'}{'device_type'}) if ((defined $self->{'vars'}{'device_type'}) && (! defined $params{'name'}));

  if ((defined $self->{'vars'}{'type'}) && ($self->{'vars'}{'type'} eq 'panel') && ((! defined $params{'name'}) || ($params{'name'} =~ / - /))) {
  
    $isIBM = 0;
    $isCAT = 0;
    $isCAT48 = 0;
    
    if (! defined $self->{'vars'}{'data'}) {
      my ($dbh)  = $self->get_dbh();
      
      ($data, $err) = CMU::Netdb::list_cables_outlets($dbh, "netreg",
						      "(prefix != 'W' and " . 
						      "from_building = \"$self->{'vars'}{'bldg'}\" and " .
						      "from_closet = \"$self->{'vars'}{'clos'}\" and " .
						      "from_rack = \"$self->{'vars'}{'rack'}\" and " .
						      "from_panel = \"$self->{'vars'}{'pane'}\") order by rack"); 
      
      $dapos = CMU::Netdb::makemap(shift(@$data));
      $self->{'vars'}{'data'} = $data;
      $self->{'vars'}{'datamap'} = $dapos;
      
    } else {
      $data = $self->{'vars'}{'data'};
      $dapos = $self->{'vars'}{'datamap'};
    }

#    warn __FILE__ . ":" . __LINE__ . ": " . scalar (@$data) . "rows found\n";

    foreach (@$data) {
      if ((defined $_->[$dapos->{'cable.label_from'}]) &&
	  (defined $_->[$dapos->{'cable.label_to'}]) &&
	  ($_->[$dapos->{'cable.label_from'}] =~ /[0-9].$/) ) {
	$isCAT = 1;
	if ($_->[$dapos->{'cable.label_from'}] =~ /48$/) {
	  $isCAT48 = 1;
	}
      } elsif ((defined $_->[$dapos->{'cable.label_from'}]) &&
	       (defined $_->[$dapos->{'cable.label_to'}]) &&
	       ($_->[$dapos->{'cable.label_from'}] =~ /[A-H].$/) ) {
	$isIBM = 1;
      }
    }
    if ($isCAT && $isIBM) {
      return ("Mixed");
    } elsif ($isCAT48) {
      return "Cat5_48";
    } elsif ($isCAT) {
      return "Cat5";
    } elsif ($isIBM) {
      return "IBM";
    } else {
      return "EMPTY";
    }
    
  } else {
    
    if (defined $params{'name'}) {
      $read_comm = $self->get_read_comm(name => $params{'name'});
      $name = $params{'name'};
    } else {
      $read_comm = $self->get_read_comm();
      $name = $self->s_p_name();
    }
    if ((! defined $read_comm) || ($read_comm eq "")) {
      return("device not listed in NetMon with valid SNMP string.");
    }
#    my @result = SNMP_util::snmpget("$read_comm\@$name", ".1.3.6.1.2.1.1.2.0");
    @result = $self->SNMP_cache(community => $read_comm,
				host => $name,
				base => ".1.3.6.1.2.1.1",
				specific => '2.0'
			       );
#    warn __FILE__ . ":" . __LINE__ . ": Getting device type returned \n" . Data::Dumper->Dump([\@result],[qw(result)]) . "\n"; 
    if (! defined $result[0]) {
      return("device that does not respond to SNMP.");
    } else {
#      warn __FILE__ . ":" . __LINE__ . ": typemap decode of $result[0] = $typemap->{$result[0]}\n";
      if (! defined $typemap->{$result[0]}) {
	return "device not configured in \$CMU::Netdb::WebInt::S_P_status::vars::typemap.<br />$result[0]";
      }
      return($typemap->{$result[0]});
    }
  }
  
};

sub get_read_comm {
  my $self = shift;
  my %params = @_;
  my ($read_comm);

  return($self->{'vars'}{'read_comm'}) if(defined $self->{'vars'}{'read_comm'} && ($self->{'vars'}{'read_comm'} ne "") && (! defined $params{'name'}));
  
  my $nmdbh = $self->get_nmdbh();
  return undef unless ($nmdbh);
  my $name = (defined $params{'name'}) ? $params{'name'} : $self->s_p_name();
  my $query = "select read_comm from device where name like '$name'";
  
  $read_comm = $nmdbh->selectall_arrayref($query);

  return($read_comm->[0][0]) if (ref $read_comm);
  return(undef);

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
  my (%params) = @_;
  my ($data, $err, $dapos, $dbh);
    
  if (defined $self->{'vars'}{'name'} && (! defined $params{'id'}) && (! defined $params{'vpid'})) {
    return ($self->{'vars'}{'name'});
  } elsif (defined $params{'vpid'}) {
    $dbh = $self->get_dbh();
    ($data, $err) = CMU::Netdb::list_trunkset_presences($dbh, 'netreg', 'machine', "trunkset_machine_presence.id = $params{'vpid'}");
    return(undef) if (! ref $data);
    $dapos = CMU::Netdb::makemap(shift @$data);
    return(undef) if (! scalar @$data);
    return($data->[0][$dapos->{'machine.host_name'}]);
  } elsif (defined $params{'id'}) {
    $dbh = $self->get_dbh();
    ($data, $err) = CMU::Netdb::list_machines($dbh, "netreg", "(machine.id = $params{'id'})");
    $dapos = CMU::Netdb::makemap(shift(@$data));
    if ((scalar $data) == 0 ) {
      return(undef);
    }
    return($data->[0][$dapos->{'machine.host_name'}]);

  } else {
    return (undef);
  }
}



sub get_dbh {
  my $self = shift;

  return($self->{'vars'}{'dbh'}) if(defined $self->{'vars'}{'dbh'} && ($self->{'vars'}{'dbh'} ne ""));

  $self->{'vars'}{'dbh'} = CMU::WebInt::db_connect();
  return($self->{'vars'}{'dbh'});
}

sub get_nmdbh {
  my $self = shift;

  return($self->{'vars'}{'nmdbh'}) if(defined $self->{'vars'}{'nmdbh'} && ($self->{'vars'}{'nmdbh'} ne ""));

  return undef unless eval { require CMU::NetMon; };
  $self->{'vars'}{'nmdbh'} = CMU::NetMon::netmon_remote_db_connect();
  return($self->{'vars'}{'nmdbh'});

}

sub SNMP_init {
  my $self = shift;

  $self->{'device'}->SNMP_init();
}

sub netreg_init {
  my $self = shift;

  $self->{'device'}->netreg_init();
}

sub panel_data {
  my $self = shift;

  return($self->{'vars'}{'data'}, $self->{'vars'}{'datamap'}) if (defined $self->{'vars'}{'data'});
  return(undef, undef);
}


sub g_context {
  my $self = shift;

  if (defined $self->{'vars'}{'g_context'}) {
    return($self->{'vars'}{'g_context'})
  } else {
    return(undef);
  }
}


sub name {
  my $self = shift;

  return($self->{'vars'}{'name'});

}

sub table_headers {
  my $self = shift;
  return($self->{'vars'}{'table_headers'});
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

  my ($base) = $params{'base'};
  my ($specific) = $params{'specific'};
  my ($walk) = ((defined $params{'walk'}) ?  $params{'walk'}  : 0);
  my ($host) = ((defined $params{'host'}) ? $params{'host'} : $self->s_p_name());
  my ($community, @base_parts, $full);
  $self->{vars}{walked} = [] if (! defined $self->{'vars'}{'walked'});

  if ($host =~ /\@/) {
    ($community, $host) = split(/\@/,$host);
  }
  if (defined $params{'community'}) {
    $community = $params{'community'};
  }
  if (! defined $community) {
    $community = $self->get_read_comm(name => $host);
  }

  if (! defined $specific) {
    @base_parts = split(/\./, $base);
    $specific = pop(@base_parts);
    $specific = pop(@base_parts) . ".$specific" if ($specific eq "0");
    $base = join('.', @base_parts);
  }
  $self->{vars}{snmp_cache} = {} if (! defined $self->{vars}{snmp_cache});
  
  return($self->_read_cache(cache => $self->{vars}{snmp_cache},
			    base => $base,
			    specific => $specific,
			    walk => $walk,
			    host => $host,
			    community => $community,
			    walked_cache => $self->{'vars'}{'walked'}
			   )
	);
  
}



sub _read_cache {
  my $self = shift;
  my (%params) = @_;
  my ($retval) = [];
  my ($curr, $q);
  my (@parts, $OK, $isOK, $walked, $bad);
#  warn __FILE__ . ":" . __LINE__ . ": _read_cache called with \n" . Data::Dumper->Dump([\%params],[qw(params)]) . "\n"; 
  if (! defined $params{'curr_cache'}) {
    $params{'curr_cache'} = $params{'cache'};
  }

  if (! defined $params{'full'}) {
    $params{'full'} ="$params{'host'}$params{'base'}.$params{specific}";
  }

  $params{'canon'} = $params{'full'} if (!defined $params{'canon'});
  
  $walked = 0;
  $bad = 0;


  foreach (@{$params{'walked_cache'}}) {
#    warn __FILE__ . ":" . __LINE__ . ": Checking >>>==>$params{'full'}<==<<< against >>>==>$_<==<<<\n";
    $walked = 1 if ($params{'full'} =~ /$_/);
  }
#  warn __FILE__ . ":" . __LINE__ . ": Tree has been walked\n" if $walked;
  if (! $walked) {
#    warn __FILE__ . ":" . __LINE__ . ": Cache miss $params{'full'}\n";
# If they didn't pass in a community string, assume that they only want cached values.
    return()if (! defined $params{'community'});
    
    $self->_load_cache(
		       cache => $params{'cache'},
		       host => $params{'host'},
		       community => $params{'community'},
		       base => $params{'base'},
		       specific => $params{'specific'},
		       walked_cache => $params{'walked_cache'}
		      );
  } else {
#    warn __FILE__ . ":" . __LINE__ . ": Cache hit $params{'full'}\n";
  }
  @parts = split(/\./,$params{'full'});
  $OK = "\$params{cache}{\"" . join('"}{"', @parts) . "\"}";
#  warn __FILE__ . ":" . __LINE__ . ": evaling >>>==> $OK\n";
  if (! eval "exists $OK") {
#    warn __FILE__ . ":" . __LINE__ . ": Non-existant\n";
    eval "$OK\{u\} = 1";
    return();
  } else {
    if (eval "exists $OK\{u\}") {
#      warn __FILE__ . ":" . __LINE__ . ": Undefined-by-flag\n";
      return();
    }
  }
  
  if (($params{'walk'} == 1) && (! $walked)) {
    # This needs to build the array of return values for a walk.    
    $self->_load_cache(cache => $params{'cache'},
		       host => $params{'host'},
		       community => $params{'community'},
		       base => $params{'base'},
		       specific => $params{'specific'},
		       walked_cache => $params{'walked_cache'});
  }
  
  
  if ($params{'walk'} == 1) {
#    warn __FILE__ . ":" . __LINE__ . ": Returning " . Data::Dumper->Dump([dump_tree(eval $OK)],["dump_tree($OK)"]) . "\n"; 
    return(dump_tree(eval $OK));
  } else {
    if (ref eval $OK) {
      return();
    } else {
#      warn __FILE__ . ":" . __LINE__ . ": Returning " . eval( $OK ) . "\n";
      return(eval $OK);
    }
    
  }
  
}


sub _load_cache {
  my $self = shift;
  my (%params) = @_;
  my ($oid, $value, $datum, $statement, $frame, @call_stack);
  my ($snmp, @result);
#  warn __FILE__ . ":" . __LINE__ . ": _load_cache called with \n" . Data::Dumper->Dump([\%params],[qw(params)]) . "\n"; 

#  warn __FILE__ . ":" . __LINE__ . ": calling snmpwalk as \"$params{'community'}\@$params{'host'}\", $params{'base'}\n";
#  warn __FILE__ . ":" . __LINE__ . ": call_stack is \n";
#  $frame = 0;
#  while ((@call_stack = caller($frame++)) && ($frame < 30)) {
#    warn "$call_stack[1] : $call_stack[3] :  $call_stack[2]\n";
#  }
  
  unshift(@{$params{'walked_cache'}}, "$params{'host'}$params{'base'}");
# the following line uses SNMP_util, let's try to use SNMP directly
#  @result = SNMP_util::snmpwalk("$params{'community'}\@$params{'host'}", $params{'base'});
  $snmp = new SNMP::Session(DestHost => $params{'host'},
			    Community => $params{'community'},
			    Retries => 3,
			    UseEnums => 0,
			    UseNumeric => 1,
			    Version => 2,
			    UseLongNames => 1,
			    Timeout => 3000000
			   );
  
#  warn __FILE__ . ":" . __LINE__ . ": Asking $params{'host'} $params{'community'}  $params{'base'}\n";
  @result = $snmp->bulkwalk(0, 40, [[$params{'base'}]]);
  
  if ($snmp->{ErrorNum} == -24) {
#    warn __FILE__ . ":" . __LINE__ . ": SNMP returned error ($snmp->{'ErrorNum'}) $snmp->{'ErrorStr'}\n";
    @result = $self->snmp_v1_walk(%params);
  }

#  warn __FILE__ . ":" . __LINE__ . ": snmpwalk returned \n" . Data::Dumper->Dump([\@result, $snmp],[qw(result snmp)]) . "\n"; 


  if ((defined $result[0]) && (scalar(@{$result[0]}) > 0)) {
    foreach $datum (@{$result[0]}) {
#      ($oid, $value) = split(/:/, "$params{base}.$datum",2);
#      $value = "" if (!defined $value);
#      warn __FILE__ . ":" . __LINE__ . ": datum is \n" . Data::Dumper->Dump([$datum],[qw(datum)]) . "\n"; 
      $oid = "$datum->[0].$datum->[1]";
      $value = $datum->[2];
      $statement = "\$params{cache}" . join('"}{"',split(/\./,"{\"$params{'host'}$oid")) . "\"} = '$value'";
#    warn __FILE__ . ":" . __LINE__ . ": evaling \n$statement\n";
      eval $statement;
    }
#    warn __FILE__ . ":" . __LINE__ . ": Cache is now \n" . Data::Dumper->Dump([$params{cache}],[qw(params{cache})]) . "\n"; 

# Mark this node walked
    $statement = "\$params{cache}" . join('"}{"',split(/\./,"{\"$params{'host'}$params{'base'}")) . "\"}{w} = '1'"; 
#    warn __FILE__ . ":" . __LINE__ . ": evaling \n$statement\n" ;
    eval $statement;
  } else {
#    warn __FILE__ . ":" . __LINE__ . ": SNMP returned no values for \"$params{'community'}\@$params{'host'}\", $params{'base'}\n";
# Nothing came back, mark the node as undefined.
    $statement = "\$params{cache}" . join('"}{"',split(/\./,"{\"$params{'host'}$params{'base'}")) . "\"}{u} = '1'"; 
#    warn __FILE__ . ":" . __LINE__ . ": evaling \n$statement\n" ;
    eval $statement;
  } ;
  return();
}


sub dump_tree{
  my ($ptr) = @_;
  my ($key, @key_list);
  my (@ret) = ();

#  warn __FILE__ . ":" . __LINE__ . ": dump_tree called on \n" . Data::Dumper->Dump([$ptr],[qw(ptr)]) . "\n"; 

  if (! ref $ptr) {
#    warn __FILE__ . ":" . __LINE__ . ": dump_tree returning \n" . Data::Dumper->Dump([$ptr],[qw(ptr)]) . "\n"; 
    return(":$ptr");
  }

  if (ref($ptr) eq 'HASH') {
    @key_list = sort { $a <=> $b } grep { $_ =~ /^[0-9]+/} (keys %$ptr);
    warn __FILE__ . ":" . __LINE__ . ": dead branch \n" if (scalar(@key_list) == 0);
    return('DEAD_BRANCH') if (scalar(@key_list) == 0);
    foreach $key (@key_list) {
      push(@ret, map { ($_ =~ /^:/ ? "$key" . $_ :  "$key." . $_)  } ( grep { ! /DEAD_BRANCH/ } dump_tree($ptr->{$key})));
    }
  }
  
#  warn __FILE__ . ":" . __LINE__ . ": dump_tree returning \n" . Data::Dumper->Dump([\@ret],[qw(ret)]) . "\n"; 
  return(@ret);

}
  

sub snmp_v1_walk {
  my $self = shift;
  my %params = @_;
  my (@ret);
  my ($base) = $params{'base'};;
  my $data = new SNMP::Varbind;
  $ret[0] = [];
  my $snmp =  new SNMP::Session(DestHost => $params{'host'},
				Community => $params{'community'},
				Retries => 3,
				UseEnums => 0,
				UseNumeric => 1,
				Version => 1,
				UseLongNames => 1,
				Timeout => 3000000
			       );
  
  $data->[0] = $base;
  while ($snmp->getnext($data)) {
    last if ($data->[0] !~ /^$base/);
    push(@{$ret[0]}, [ @$data ]);
#    warn __FILE__ . ":" . __LINE__ . ": snmpgetnext returned \n" . Data::Dumper->Dump([$data],[qw(data)]) . "\n"; 
  }
  if ($snmp->{'ErrorNum'} == -24) {
    return();
  }
  return(@ret);
}
		 

1;
