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


package CMU::WebInt::S_P_status::Port;
use strict;
use warnings;

use CMU::WebInt::S_P_status::vars qw($port);
# use child classes
use CMU::WebInt::S_P_status::Port::P2900;
use CMU::WebInt::S_P_status::Port::P3750;
use CMU::WebInt::S_P_status::Port::P6509;
use Socket;

# require superclass

use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter UNIVERSAL);

sub new {
  my $type = shift;
  my $self = {};
  my (%params) = @_;

  bless($self, $type);
  $self->init(%params) if (defined $params{'parent'});
  return($self);
}


sub display {
  my $self = shift;
  my (%params) = @_;

  my ($form) = (defined $params{'form'}) ? $params{'form'} : "HTML-table";
  my ($val) = "";
  my ($i, $pname, $ColorHold, $target, $host_url, $OutHold, $table_headers);
  my ($g) = $self->g_context();
  
  $host_url = $g->url(-path=>1);
#  warn __FILE__ . ":" . __LINE__ . ":Displaying portID 9\n" . Data::Dumper->Dump([$self->{'vals'}],[qw(vals)]) . "\n" if ($self->{'vars'}{portIfIndex} == 9);

  foreach (@{$port->{$self->{'vars'}{'port_type'}}{'status_check'}}) {
    eval "\$self->$_()";
    warn __FILE__ . ":" . __LINE__ . ": $@\n" if $@;
  }
  $form = "HTML-table" if ((! defined $form) || (($form ne 'XML') && ($form ne 'HTML-display')));

  if ($form eq "HTML-table") {
    $table_headers = $self->table_headers();
    $val .= "<tr>\n";
    $ColorHold = $self->{'vals'}{$table_headers->[0]};
    $self->{'vals'}{$table_headers->[0]} = "<div class=\"$self->{'vals'}{'PortStatus'}\"><a NAME='$self->{'vals'}{$table_headers->[0]}'>$self->{'vals'}{$table_headers->[0]}</a></div>";
    
    $OutHold = $self->{'vals'}{'Connected to'};
    $self->{'vals'}{'Connected to'} = (( $self->{'vals'}{'Connected to'} eq 'Not') ?
					    $self->{'vals'}{'Connected to'} :
					    "<a href='$host_url?op=outlets_info&oid=$self->{'vars'}{'outletID'}'>$self->{'vals'}{'Connected to'}</a>");
    
    if ((defined $self->{'vals'}{'CDP_Neighbor'}) && (length($self->{'vals'}{'CDP_Neighbor'}) >= 1)) {
      $self->{'vals'}{'Connected to'} = (( $self->{'vals'}{'Connected to'} eq 'Not') ?
					      $self->{'vals'}{'CDP_Neighbor'} :
					      "$self->{'vals'}{'Connected to'}<br />$self->{'vals'}{'CDP_Neighbor'}");
    }
    foreach $i (@$table_headers) {
      $val .= "<td class=\"TD\">" . (defined $self->{'vals'}{$i} ? $self->{'vals'}{$i} : "&nbsp;" ) . "</td>\n";
    }
    $self->{'vals'}{'Connected to'} = $OutHold;
    $self->{'vals'}{$table_headers->[0]} = $ColorHold;
    $val .= "</tr>\n";
  } elsif ($form eq "HTML-display") {
    if (defined $self->{'dev_conf'}{'entPhysicalName'}) {
      if (length($self->{'dev_conf'}{'entPhysicalName'}) > 10) {
	$self->{'dev_conf'}{'entPhysicalName'} =~ /^(..)/;
	$pname = $1;
	$self->{'dev_conf'}{'entPhysicalName'} =~ /([\d\/]+)$/;
	$pname .= $1;
	$pname .=  (defined $self->{'vals'}{'PortType'} ? "<br />$self->{'vals'}{'PortType'}" : "<br />&nbsp;"); 
      } else {
	$pname = $self->{'dev_conf'}{'entPhysicalName'} . (defined $self->{'vals'}{'PortType'} ? "<br />$self->{'vals'}{'PortType'}" : "<br />&nbsp;");
      }
    } else {
      $pname = $self->ifName2SNMPid(snmp => $self->{'vars'}{'snmp_port_num'}) . (defined $self->{'vals'}{'PortType'} ? "<br />$self->{'vals'}{'PortType'}" : "<br />&nbsp;");       
    }

    $target = (defined $self->{'vars'}{'outletID'} ?
	       "href='$host_url?op=outlets_info&oid=$self->{'vars'}{'outletID'}'" :
	       "NAME='$pname'");
    $val .= "<div class=\"$self->{'vals'}{display_width}\">\n<div class=\"buttons\">\n<div class=\"$self->{'vals'}{'PortStatus'}\">";
    $val .= "<a $target>$pname</a>";
    $val .= "</div></div></div>\n";
  }
  
#  warn __FILE__ . ":" . __LINE__ . ": Port::display returning\n" . Data::Dumper->Dump([$val],[qw(val)]) . "\n"; 
  return($val);
}


sub init {
  my $self = shift;
  my (%params) = @_;

  if (defined $params{status}) {
    $self->{'vals'}{'PortStatus'} = "misconf";
  }
  $self->{'vals'}{display_width} = "plug";
  foreach (@$CMU::WebInt::S_P_status::vars::table_headers) {
    $self->{'vals'}{$_} = "";
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
  my (%params) = @_;

  return($self->{'vars'}{'read_comm'}) if(defined $self->{'vars'}{'read_comm'} && ($self->{'vars'}{'read_comm'} ne ""));

  return($self->{'parent'}->get_read_comm(%params));
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
  my ($oid, $macro, $vlans);
  my $oids = $self->{'vars'}{'oids'};
  my ($key, @vals, $name, $read_comm, $info);
  my ($walk);

#  warn __FILE__ . ":" . __LINE__ . ": Port level SNMP_init called\n" . $self->dump() . Carp::longmess() . "\n";
  
  $name = $self->s_p_name();
  $read_comm = $self->get_read_comm();
  
  $self->vlan_init();

 TheKeys:  foreach $key (keys %$oids) {
    $walk = 0;
    if (defined $oids->{$key}{'oid'}) {
      $oid = $oids->{$key}{'oid'};
    } else {
      $oid = $oids->{$key}{'woid'};
      $walk = 1;
    }
    $info = $oids->{$key}{'info'};

    while ($info =~ /(\%[^%]+\%)/) {
      $macro = $1;
      $macro =~ s/\%//g;
      if (! defined $self->{'vars'}{$macro}) {
	next TheKeys;
      } else {
      }
      $info =~ s/\%$macro\%/$self->{'vars'}{$macro}/g;
    }

    if ($walk) {
      @vals = $self->SNMP_cache(community => $read_comm,
				host => $name,
				base => $oid,
				specific => $info,
				walk => 1
			       );


      if (@vals) {
	if ((defined $oids->{$key}{xlate}) && ((ref $oids->{$key}{xlate}) eq 'HASH')) {
	  $self->{'vals'}{$key} = join("<br />", map { ((defined $_) &&
							(defined $oids->{$key}{xlate}) &&
							(defined $oids->{$key}{xlate}{(split(/:/, $_))[1]})) ?
							  $oids->{$key}{xlate}{(split(/:/, $_))[1]} :
							    (split(/:/, $_))[1] } @vals);
	  
	} elsif ((defined $oids->{$key}{xlate}) && (! ref $oids->{$key}{xlate})) {
	  my ($fun) =  $oids->{$key}{xlate};
	  $self->{'vals'}{$key} = $self->$fun(\@vals);
	  
	}
      }
    } else {
#      @vals = SNMP_util::snmpget("$read_comm\@$name", "$oid.$info");
      @vals = $self->SNMP_cache(community => $read_comm,
				host => $name,
				base => $oid,
				specific => $info
			       );
      if (@vals) {
	$self->{'vals'}{$key} = (((defined $vals[0]) && (defined $oids->{$key}{xlate}) && (defined $oids->{$key}{xlate}{$vals[0]})) ?
				 $oids->{$key}{xlate}{$vals[0]} :
				 $vals[0]);
      }
      
    }
    
#    warn __FILE__ . ":" . __LINE__ . ": Port:SNMP_init::get/walk returned \n" . Data::Dumper->Dump([\@vals, $self->{'vals'}{$key}],["vals", "self->{'vals'}{$key}"]) . "\n"; 
  }

  if (defined $self->{'vals'}{'Port'}) {
    $self->{'vals'}{'Port'} = $self->s_p_name() . "<br />$self->{'vals'}{'Port'} ($self->{'vars'}{'snmp_port_num'})";
  }
  if ((! defined $self->{'vals'}{'Vlan/Curr'}) || ($self->{'vals'}{'Vlan/Curr'} eq "")) {
    $vlans = $self->vlan_config(name => $self->{'vals'}{'Device'});
    $self->{'vals'}{'Vlan/Curr'} = join("<br />\n", @{$vlans->{$self->{'vars'}{'snmp_port_num'}}{'trunk'}}) if ((defined $vlans) &&
														(defined $vlans->{$self->{'vars'}{'snmp_port_num'}}{'trunk'}));
  }

#  warn __FILE__ . ":" . __LINE__ . ": Port level SNMP_init done\n" . $self->dump();

}

sub vlan_init {
  my $self = shift;
  my (@vals, $name, $read_comm, $vlnum, $vlname);
  
  return if ((! defined $self->{'vars'}{'oids'}{'Vlan/Curr'}) || (defined $self->{'vars'}{'oids'}{'Vlan/Curr'}{'xlate'}));
  
  $name = $self->s_p_name();
  $read_comm = $self->get_read_comm(name => $name);
  
  $self->{'vars'}{'oids'}{'Vlan/Curr'} = { %{$self->{'vars'}{'oids'}{'Vlan/Curr'}}};
  
#  @vals = SNMP_util::snmpwalk("$read_comm\@$name", ".1.3.6.1.4.1.9.9.46.1.3.1.1.4");
  @vals = $self->SNMP_cache(community => $read_comm,
			     host => $name,
			     base => '.1.3.6.1.4.1.9.9.46.1.3.1.1.4',
			     walk => 1
			    );
  
  foreach (@vals) {
    ($vlnum, $vlname) = split(/:/, $_);
    $vlnum = (split(/\./, $vlnum))[1] if ($vlnum =~ /\./);
    $self->{'vars'}{'oids'}{'Vlan/Curr'}{'xlate'}{$vlnum} = "$vlname/$vlnum";
  }
  
}


sub netreg_init {
  my $self = shift;
  my $query = "";

#  warn __FILE__ . ":" . __LINE__ . ": netreg_init entered\n";

  my ($name) = $self->s_p_name();
  my ($port) = $self->{'vars'}{'snmp_port_num'};

  my ($outlet, $err, $oupos);
  my ($cable, $capos);
  my ($attr, $atpos, $vlan, $vlpos, $vlh);

  my ($dbh) = $self->get_dbh();
  if (! ref $dbh) {
    warn __FILE__ . ":" . __LINE__ . ": Could not get database handle\n";
    return;
  }
  
  foreach (@{$self->{'vars'}{'netreg'}}) {
    $self->{'vals'}{$_} = "Unconf";
  }
  
  return if (! defined $port);
  
#  warn __FILE__ . ":" . __LINE__ . ": Searching database for port $port\n";
  ($outlet, $err) = CMU::Netdb::list_outlets_devport($dbh, 'netreg', "(machine.host_name like \"$name\" and outlet.port = $port)");
  $oupos = CMU::Netdb::makemap(shift @$outlet);
  
  if ((scalar @$outlet) == 0) {
    $self->{'vals'}{'Connected to'} = "Not";
    return ;
  }
#  warn __FILE__ . ":" . __LINE__ . ": list_outlet_devport returns " . Data::Dumper->Dump([$oupos],[qw(oupos)]) . "\n"; 
  
  ($cable, $err) = CMU::Netdb::list_outlets_cables($dbh, 'netreg', "(outlet.id = $outlet->[0][$oupos->{'outlet.id'}])");
  $capos = CMU::Netdb::makemap(shift @$cable);
  
  $self->{'vars'}{'outletID'} = $cable->[0][$capos->{'outlet.id'}];
  $self->{'vals'}{'Connected to'} = "$cable->[0][$capos->{'cable.label_from'}]<br />$cable->[0][$capos->{'cable.label_to'}]";
  $self->{'vals'}{'Status/NetReg'} = $outlet->[0][$oupos->{'outlet.status'}];
  
  
# Get any attributes on the outlet
  ($attr, $err) = CMU::Netdb::list_attribute($dbh, 'netreg', "attribute.owner_table = 'outlet' and owner_tid = $outlet->[0][$oupos->{'outlet.id'}]");
  $atpos = CMU::Netdb::makemap(shift(@$attr));
  if ((scalar @$attr) != 0) {
    
    foreach (@$attr) {
      $self->{'vals'}{'PortSecurity/NetReg'} = $_->[$atpos->{'attribute.data'}] 
	if ($_->[$atpos->{'attribute_spec.name'}] eq "Port Security Mode");
      $self->{'vals'}{'PortFast/NetReg'} = $_->[$atpos->{'attribute.data'}] 
	if ($_->[$atpos->{'attribute_spec.name'}] eq "Port-Fast Mode");
      $self->{'vals'}{'Speed/NetReg'} = $_->[$atpos->{'attribute.data'}] 
	if ($_->[$atpos->{'attribute_spec.name'}] eq "port-speed");
      $self->{'vals'}{'Duplex/NetReg'} = $_->[$atpos->{'attribute.data'}] 
	if ($_->[$atpos->{'attribute_spec.name'}] eq "port-duplex");
    }
  }
  
# Get the vlan info 
  $vlan = CMU::Netdb::list_outlet_vlan_memberships($dbh, 'netreg',
						   "outlet_vlan_membership.outlet = '$outlet->[0][$oupos->{'outlet.id'}]'");
  $vlpos = CMU::Netdb::makemap(shift(@$vlan));

  if ((scalar @$vlan) != 0) {
    map {$vlh->{$_->[$vlpos->{'vlan.number'}]} = "$_->[$vlpos->{'vlan.abbreviation'}]/$_->[$vlpos->{'vlan.number'}]" } @{$vlan};
    
#    warn __FILE__ . ":" . __LINE__ . ": vlan map is \n" . Data::Dumper->Dump([$vlh],[qw(vlh)]) . "\n"; 

    $self->{'vals'}{'Vlan/NetReg'} = join("<br />\n",
					  map {"$vlh->{$_}"} sort { $a <=> $b } keys %{$vlh}) ;
  }
  
  
  
}

sub port_label {
  my $self = shift;

  return($self->{'vals'}{'Loc'});
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


sub ip2hostname {
  my $self = shift;
  my ($vals) = @_;
  my ($g) = $self->g_context();
  my ($url) = $g->url(-path=>1);
  my $ret;

  $ret = [ map { (scalar gethostbyaddr((split(/:/,$_))[1], AF_INET)) || (join('.',unpack("C4",(split(/:/,$_))[1] )))  } @$vals ];
  
  $ret = [ map {
    if ($_ =~ /^\d+\.\d+\.\d+\.\d+$/) {
      "<a href=\"$url?op=sw_panel_config&device=$_\">$_</a>";
    } else {
      $_ =~ /^([^\.]+\.[^\.]+)\..*/ ;
      "<a href=\"$url?op=sw_panel_config&device=$_\">$1</a>";
    }
  } @$ret ];
	   

#  warn __FILE__ . ":" . __LINE__ . ": ip2hostname returning " . join("<br />", @$ret) . "\n";
  return(join("<br />", @$ret));
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
