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


package CMU::WebInt::S_P_status::Device;
use strict;
use warnings;
use vars qw (@ISA @EXPORT @EXPORT_OK);

require Exporter;
require CMU::WebInt::S_P_status;

# require superclass


# Use subclasses
use CMU::WebInt::S_P_status::vars qw($device $cfgobjs $typemap);
use CMU::WebInt::S_P_status::Device::D3750;
use CMU::WebInt::S_P_status::Device::D3500_48;
use CMU::WebInt::S_P_status::Device::D3500_24;
use CMU::WebInt::S_P_status::Device::D2950_48;
use CMU::WebInt::S_P_status::Device::D2950_24;
use CMU::WebInt::S_P_status::Device::D6509;


@ISA = qw(Exporter);


sub new {
  my ($type) = shift;
  my ($self) = {};

  $self->{'vars'}{'device_type'} = 'Runtime';
  $self = bless($self,$type);
  return($self);
}  



sub init {
  my $self = shift;
  my (%params) = @_;
  my ($chassis);

  my ($name, $bldg, $clos, $rack, $pane, $type);
  my ($c_type);
  $name = $params{'name'};
  $type = $params{'type'};


  $self->{'vars'}{'type'} = $type;
  $self->{'vars'}{'name'} = $name;
  $self->{'vars'}{'device_type'} = $params{'device_type'};
  $self->{'parent'} = $params{'parent'};
  
#  warn __FILE__ . ":" . __LINE__ . ": Processing device as $self->{'vars'}{'device_type'}\n";
  if ($self->{'vars'}{'type'} eq "device") {

# get the vlan configuration regardless of device type
    $self->{'vars'}{'vlan_info'} = $self->vlan_config();
    $self->{'dev_conf'} = $self->get_config(name => $self->s_p_name(),
					    read_comm => $self->get_read_comm()
					   );
    
    if ((defined $self->{'vars'}{'device_type'}) &&
	($self->{'vars'}{'device_type'} ne 'Runtime') &&
	(defined $device->{$self->{'vars'}{'device_type'}}) &&
	($device->{$self->{'vars'}{'device_type'}} ne 'Runtime') &&
	(defined $device->{$self->{'vars'}{'device_type'}}{'Chassis_cnt'}) &&
	($device->{$self->{'vars'}{'device_type'}}{'Chassis_cnt'} ne 'Runtime') &&
	(defined $device->{$self->{'vars'}{'device_type'}}{'Chassis_type'}) &&
	($device->{$self->{'vars'}{'device_type'}}{'Chassis_type'} ne 'Runtime')
       ) {
      $self->{'vars'}{'chassis_cnt'} = $device->{$self->{'vars'}{'device_type'}}{'Chassis_cnt'};
      foreach $chassis (1 .. $self->{'vars'}{'chassis_cnt'}) {
#	warn __FILE__ . ":" . __LINE__ . ": Constructor is $device->{$self->{'vars'}{'device_type'}}{'Chassis_construct'}\n";
	$self->{'chassis'}[$chassis] = eval $device->{$self->{'vars'}{'device_type'}}{'Chassis_construct'};
	$self->{'chassis'}[$chassis]->init('parent' => $self,
					   'dev_conf' => $self->{'dev_conf'},
					   'vender_desc' => $self->{'vars'}{'device_type'},
					   'chassis_num' => $chassis);
      }
    } elsif (
	     ((defined $device->{$self->{'vars'}{'device_type'}}{'Chassis_cnt'}) &&
	      ($device->{$self->{'vars'}{'device_type'}}{'Chassis_cnt'} eq 'Runtime')) ||
	     ((defined $device->{$self->{'vars'}{'device_type'}}{'Chassis_type'}) &&
	      ($device->{$self->{'vars'}{'device_type'}}{'Chassis_type'} eq 'Runtime'))
	    ){
# Runtime definition of device
#      warn __FILE__ . ":" . __LINE__ . ": " . Data::Dumper->Dump([$self],[qw(self)]) . "\n"; 

      foreach $chassis (@{$self->{'dev_conf'}{'children'}}) {
	next if (! defined $chassis);
#	warn __FILE__ . ":" . __LINE__ . ": processing chassis\n" . Data::Dumper->Dump([$chassis],[qw(chassis)]) . "\n"; 
	$c_type = $typemap->{"$chassis->{'entPhysicalVendorType'}"};
	if (! defined $c_type) {
	  warn __FILE__ . ":" . __LINE__ . ": Don't know how to make a .$chassis->{'entPhysicalVendorType'}\n";
	  $self->{'chassis'}[$chassis->{'entPhysicalParentRelPos'}] = "<h2>Could Not translate .$chassis->{'entPhysicalVendorType'} to a device type</h2>";
	  next;
	} elsif (! defined $device->{$c_type}) {
	  warn __FILE__ . ":" . __LINE__ . ": Don't know how to make a $c_type\n";
	  $self->{'chassis'}[$chassis->{'entPhysicalParentRelPos'}] = "<h2>Do not know how to display a $c_type</h2>";
	  next;
	}
	$self->{'chassis'}[$chassis->{'entPhysicalParentRelPos'}] = eval $device->{$c_type}{'Chassis_construct'};
	$self->{'chassis'}[$chassis->{'entPhysicalParentRelPos'}]->init(chassis_num => $chassis->{'entPhysicalName'},
									dev_conf => $chassis,
									vender_desc => $c_type,
									parent => $self
								       ) 
	  if ((defined $self->{'chassis'}[$chassis->{'entPhysicalParentRelPos'}]) && 
	      (ref $self->{'chassis'}[$chassis->{'entPhysicalParentRelPos'}]));
      }

    } else {
      return;
    }
  } elsif ( $self->{'vars'}{'type'} eq "panel") {
    $self->{'bldgs'} = [];
# FIXME This is where multiple buildings would be handled....
    $self->{'vars'}{'bldg_cnt'} = 1;
    foreach (1 .. $self->{'vars'}{'bldg_cnt'}) {
      $self->{'bldgs'}[$_] = CMU::WebInt::S_P_status::Bldg->new();
      $self->{'bldgs'}[$_]->init(
				 parent => $self,
				 bldg => $params{'bldg'},
				 clos => $params{'clos'},
				 rack => $params{'rack'},
				 pane => $params{'pane'}
				);
    }
    
  }
}

sub display {
  my $self = shift;
  my (%params) = @_;
  my ($i, $val);
  $val = "";
  

  foreach $i (@{$self->{'chassis'}}, @{$self->{'bldgs'}}) {
    if (defined $i) {
      if (ref $i) {
	$val .= $i->display(%params);
      } else {
	$val .= "$i\n";
      }
    }
  }
  return($val);
}



sub SNMP_init {
  my $self = shift;

  foreach (@{$self->{'chassis'}}, @{$self->{'bldgs'}}) {
    $_->SNMP_init() if ((defined $_) && (ref $_));
  }
}

sub netreg_init {
  my $self = shift;

  foreach (@{$self->{'chassis'}}, @{$self->{'bldgs'}}) {
    $_->netreg_init() if ((defined $_) && (ref $_));
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

sub g_context {
  my $self = shift;

  if (defined $self->{'vars'}{'g_context'}) {
    return($self->{'vars'}{'g_context'})
  } else {
    return($self->{'parent'}->g_context());
  }
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

sub panel_data {
  my $self = shift;

  return($self->{'vars'}{'data'}, $self->{'vars'}{'datamap'}) if (defined $self->{'vars'}{'data'});
  return($self->{'parent'}->panel_data());
}

sub get_config {
  my $self = shift;
  my (%params) = @_;

  if ((defined $self->{'dev_conf'}) && (! defined $params{'name'})) {
    return($self->{'dev_conf'});
  } 


  my ($Device_config_oid) = '.1.3.6.1.2.1.47.1.1.1.1';
  my ($portCrossIndex_oid) = '.1.3.6.1.4.1.9.5.1.4.1.1.3';
  my ($portIfIndex_oid) = '.1.3.6.1.4.1.9.5.1.4.1.1.11';
  my (@snmp, @type, $cfgobj, $conf);
  my ($tmp) = {};
  my ($tmp2) = {};
  my ($vlaninfo);
  $conf = {};

# This gets the entity mib information
  @snmp = $self->SNMP_cache(community => $params{'read_comm'},
			    host => $params{'name'},
			    base => $Device_config_oid,
			    walk => 1
			   );
  
#  print "<pre>SNMP returned\n" . Data::Dumper->Dump([\@snmp],[qw(snmp)]) . "\n</pre>"; 

# group the items from the mib table into a hash by id number
  foreach $cfgobj (sort { $a <=> $b} keys %$cfgobjs) {
    @type = grep { /^$cfgobj\./ } @snmp;

    foreach (@type) {
      $_ =~ /[0-9]+\.([0-9]+):(.*)$/;
      $conf->{$1}{$cfgobjs->{$cfgobj}{id}} = (defined $cfgobjs->{$cfgobj}{transl}{$2} ? $cfgobjs->{$cfgobj}{transl}{$2} : $2);
    }
  }


  foreach (keys %$conf) {
    $conf->{$_}{'entPhysicalIndex'} = $_ if (! defined $conf->{$_}{'entPhysicalIndex'});
  }

  @snmp = $self->SNMP_cache(community => $params{'read_comm'},
			    host => $params{'name'},
			    base => $portCrossIndex_oid,
			    walk => 1
			   );


  map { $_ =~ /^([0-9+]\.[0-9]+)\:([0-9]+)$/ ; $tmp->{$1} = $2 } @snmp;

  @snmp = $self->SNMP_cache(community => $params{'read_comm'},
			    host => $params{'name'},
			    base => $portIfIndex_oid,
			    walk => 1
			   );


  map { $_ =~ /^([0-9+]\.[0-9]+)\:([0-9]+)$/ ; $tmp2->{$1} = $2 } @snmp;
  $tmp2 = { reverse %$tmp2 };


# Fix a few things that Cisco messed up in the entity mib
#  This is usually 2 items at the same relpos.
  foreach (keys %$conf) {
    if (($conf->{$_}{'entPhysicalClass'} =~ /^backplane$/) &&
	($conf->{$_}{'entPhysicalParentRelPos'} == 1) &&
	($conf->{$_}{'entPhysicalContainedIn'} == 1)
       ) {
      $conf->{$_}{'entPhysicalParentRelPos'} = 0;
    }
  }
  
#  print "<pre>";
#  foreach (sort {$a <=> $b} keys %$conf) {
#    print "" . Data::Dumper->Dump([$conf->{$_}],["conf->{$_}"]) . "\n"; 
#  }
#  print "</pre>";

# Build up the device using the parentrelpos to make a tree representing the
#  device
  foreach (keys %$conf ) {
    if ((defined $conf->{$_}{'entPhysicalAlias'}) &&
	($conf->{$_}{'entPhysicalAlias'} ne '') &&
	(defined $tmp2->{$conf->{$_}{'entPhysicalAlias'}})) {
      $conf->{$_}{'portIfIndex'} = $tmp->{$tmp2->{$conf->{$_}{'entPhysicalAlias'}}};
      $conf->{$_}{'chassisport'} = $tmp2->{$conf->{$_}{'entPhysicalAlias'}};
    } else {
      my ($physname);
      if ($conf->{$_}{'entPhysicalName'} =~ /^Gigabit Port Container ([\d\/]+)$/) {
	$physname = "Gi$1";
      } else {
	$physname = (split(/ /, $conf->{$_}{'entPhysicalName'}))[0];
      }
#      print "<pre> physname is $physname for >>$conf->{$_}{'entPhysicalName'}<<\n</pre";
      if (defined $self->ifName2SNMPid(name => $physname) ) {
	$conf->{$_}{'portIfIndex'} = $self->ifName2SNMPid(name => $physname);
	$conf->{$_}{'chassisport'} = $tmp2->{$conf->{$_}{'portIfIndex'}};
      } 
    }
    next if (( $conf->{$_}{'entPhysicalContainedIn'} == -1) || ( $conf->{$_}{'entPhysicalParentRelPos'} == -1));
#    warn __FILE__ . ":" . __LINE__ . ": Parts are \n\t \$_ = $_\n\t\$conf->{$_}{'entPhysicalParentRelPos'} = $conf->{$_}{'entPhysicalParentRelPos'}\n\t\$conf->{$_}{'entPhysicalContainedIn'} = $conf->{$_}{'entPhysicalContainedIn'}\n\n";
    if (defined $conf->{$conf->{$_}{'entPhysicalContainedIn'}}{children}[$conf->{$_}{'entPhysicalParentRelPos'}]) {
      warn __FILE__ . ":" . __LINE__ . ": get_config: Overwriting \n" .
	Data::Dumper->Dump([$conf->{$conf->{$_}{'entPhysicalContainedIn'}}{children}[$conf->{$_}{'entPhysicalParentRelPos'}]],[qw(lost_child)]) .
	    "With\n" .
	      Data::Dumper->Dump([$conf->{$_}],[qw(new_child)]) . "\n"; 
    }
    $conf->{$conf->{$_}{'entPhysicalContainedIn'}}{children}[$conf->{$_}{'entPhysicalParentRelPos'}] = $conf->{$_};
  }

#  print "<pre> Full hierarchy is\n" . Data::Dumper->Dump([$conf->{1}],[qw(conf->{1})]) . "</pre>\n"; 
  
  return($conf->{1});
}

sub vlan_config{
  my $self = shift;
  my (%params) = @_;
  my ($vlan, $port, $bits, $xlate, $i, $j);

  return($self->{'vars'}{'vlan_info'}) if ((defined $self->{'vars'}{'vlan_info'}) && (! defined $params{'name'}));

  my ($name) = (defined $params{'name'} ? $params{'name'} : $self->s_p_name());
  my ($read_comm) = (defined $params{'read_comm'} ? $params{'read_comm'} : $self->get_read_comm(name => $params{'name'}));

# get the trunk/port definitions
#  my (@SNMP_result) = SNMP_util::snmpwalk("$read_comm\@$name", ".1.3.6.1.4.1.9.9.46.1.6.1.1.4");
  my (@SNMP_result) = $self->SNMP_cache(community => $read_comm,
					host => $name,
					base => '.1.3.6.1.4.1.9.9.46.1.6.1.1.4',
					walk => 1
				       );

  foreach (@SNMP_result) {
    ($port, $bits) = split(/:/,$_,2);
    $bits = [ split(//,unpack("B*",$bits)) ];
    $vlan->{$port}{trunk} = [ grep {$bits->[$_]} (0 .. 1023) ];
  }

# get the default vlan
#  @SNMP_result = SNMP_util::snmpwalk("$read_comm\@$name", ".1.3.6.1.4.1.9.9.46.1.6.1.1.5");
  @SNMP_result = $self->SNMP_cache(
				   community => $read_comm,
				   host => $name,
				   base => ".1.3.6.1.4.1.9.9.46.1.6.1.1.5",
				   walk => 1
				  );

  if (! defined $SNMP_result[0]) {
    return(undef);
  }

  foreach (@SNMP_result) {
    ($port, $bits) = split(/:/,$_,2);
    $vlan->{$port}{native} = $bits;
  }

# get/apply the vlan name translation table
# FIXME If we start using multiple translational bridging, this will break...
#  @SNMP_result = SNMP_util::snmpwalk("$read_comm\@$name", ".1.3.6.1.4.1.9.9.46.1.3.1.1.4.1");
  @SNMP_result = $self->SNMP_cache(
				   community => $read_comm,
				   host => $name,
				   base => ".1.3.6.1.4.1.9.9.46.1.3.1.1.4.1",
				   walk => 1
				  );
  
  foreach (@SNMP_result) {
    $xlate->{(split(/:/,$_))[0]} = (split(/:/,$_))[1];
  }
  foreach $i (keys %$vlan) {
    $vlan->{$i}{'trunk'} = [ map { "$xlate->{$_}/$_" } @{$vlan->{$i}{'trunk'}} ];
    $vlan->{$i}{'native'} = "$xlate->{$vlan->{$i}{'native'}}/$vlan->{$i}{'native'}"
  }
  

#  warn __FILE__ . ":" . __LINE__ . ": vlan_info is " . Data::Dumper->Dump([$vlan],[qw(vlan)]) . "\n"; 
  return($vlan);
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

  if (! defined $self->{'vars'}{subdevices}{$params{'name'}}) {

  }
  $self->{'vars'}{subdevices}{$params{'name'}}->get_port(%params);

  return(undef);
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
  my ($name, $reread, $snmp, $long);
  $name = $params{name};
  $reread = $params{reread};
  $snmp = $params{snmp};
  $long = $params{long};
  my ($n2s, $SnmpData, $oids, $oid);
  my ($idx, $val);

#  warn __FILE__ . ":" . __LINE__ . ": ifName2SNMPid called with \n" . Data::Dumper->Dump([\%params],[qw(params)]) . "\n"; 
  $oids = { long => '.1.3.6.1.2.1.2.2.1.2',
	    short => '.1.3.6.1.2.1.31.1.1.1.1' };

  if ((! defined $self->{'vars'}{name2snmp}) ||
     $reread) {
    foreach $oid (keys %$oids) {
      $SnmpData = [$self->SNMP_cache(
				    base => $oids->{$oid},
				    walk => 1
				   )];
      foreach (@$SnmpData) {
	($idx,$val) = split(/:/,$_,2);
	$self->{'vars'}{name2snmp}{$val} = $idx;
	$self->{'vars'}{snmp2name}{$oid}{$idx} = $val;
      }
      
    }
  }
  return($self->{'vars'}{name2snmp}{$name}) if(defined $name);
  if(defined $snmp) {
    return($self->{'vars'}{snmp2name}{long}{$snmp}) if ($long);
    return($self->{'vars'}{snmp2name}{short}{$snmp});
  }
  return(undef);
}

1;
