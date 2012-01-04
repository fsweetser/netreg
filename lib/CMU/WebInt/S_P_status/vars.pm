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

package CMU::WebInt::S_P_status::vars;
use strict;
use warnings;

use vars qw (@ISA @EXPORT @EXPORT_OK
	     $table_headers
	     $typemap
	     $device
	     $chassis
	     $blade
	     $port
	     $panel
	     $mibfiles
	     $cfgobjs
	     $service_groups
	    );

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	     $table_headers
	     $typemap
	     $device
	     $chassis
	     $blade
	     $port
	     $panel
	     $mibfiles
	     $cfgobjs
	     $service_groups
	    );


$service_groups = [
		   qw(
		      BorderRoutersSW.netsage
		      CoreRoutersSW.netsage
		      A100RouterSW.netsage
		      routers-sw.netsage
		      switches-pod-c-machine-rooms.netsage
		      switches-pod-c-aggregators.netsage
		      switches-pod-b-aggregators.netsage
		      switches-layer2-aggregators.netsage
		      switches-pod-a-aggregators.netsage
		      switches-pod-a-machine-rooms.netsage
		      switches-pod-b-machine-rooms.netsage
		     )
		  ];
		  
$cfgobjs = {
	    1 => { id => 'entPhysicalIndex',
		 },
	    2 => { id => 'entPhysicalDescr',
		 },
	    3 => { id => 'entPhysicalVendorType',
		   transl => $typemap,
		 },
	    4 => { id => 'entPhysicalContainedIn',
		 },
	    5 => { id => 'entPhysicalClass',
		   transl => {
			      1 => "other",
			      2 => "unknown",
			      3 => "chassis",
			      4 => "backplane",
			      5 => "container",
			      6 => "powerSupply",
			      7 => "fan",
			      8 => "sensor",
			      9 => "module",
			      10 => "port",
			      11 => "stack"
			     }
		 },
	    6 => { id => 'entPhysicalParentRelPos',
		 },
	    7 => { id => 'entPhysicalName',
		 },
	    8 => { id => 'entPhysicalHardwareRev',
		 },
	    9 => { id => 'entPhysicalFirmwareRev',
		 },
	    10 => { id => 'entPhysicalSoftwareRev',
		  },
	    11 => { id => 'entPhysicalSerialNum',
		  },
	    12 => { id => 'entPhysicalMfgName',
		  },
	    13 => { id => 'entPhysicalModelName',
		  },
	    14 => { id => 'entPhysicalAlias',
		  },
	    15 => { id => 'entPhysicalAssetID',
		  },
	    16 => { id => 'entPhysicalIsFRU',
		    transl => {
			       1 => "true",
			       2 => "false"
			      }
		  },
	   };

$typemap = {
	    ".1.3.6.1.4.1.9.1.45" => "7500",
	    ".1.3.6.1.4.1.9.1.122" => "3620",  # new
	    ".1.3.6.1.4.1.9.1.162" => "5300",  # new
	    ".1.3.6.1.4.1.9.1.171" => "2900", # new
	    ".1.3.6.1.4.1.9.1.183" => "2900",
	    ".1.3.6.1.4.1.9.1.184" => "2900",
	    ".1.3.6.1.4.1.9.1.217" => "2900",
	    ".1.3.6.1.4.1.9.1.246" => "3508G-XL",
	    ".1.3.6.1.4.1.9.1.248" => "WS-C3524-XL",
	    ".1.3.6.1.4.1.9.1.258" => "6509-SUP",
	    ".1.3.6.1.4.1.9.1.278" => "WS-C3548-XL-EN",
	    ".1.3.6.1.4.1.9.1.283" => "6509",
	    ".1.3.6.1.4.1.9.1.287" => "WS-C3524-PWR-XL",
	    ".1.3.6.1.4.1.9.1.359" => "WS-C2950T-24",
	    ".1.3.6.1.4.1.9.1.428" => "WS-C2950G-24-EI",
	    ".1.3.6.1.4.1.9.1.429" => "WS-C2950G-48-EI",
	    ".1.3.6.1.4.1.9.1.480" => "WS-C2950SX-24-SI",
	    ".1.3.6.1.4.1.9.1.516" => "3750",
	    ".1.3.6.1.4.1.9.1.525" => "1200",  # new
	    ".1.3.6.1.4.1.9.1.539" => "1700",  # new
	    ".1.3.6.1.4.1.9.1.560" => "WS-C2950SX-48-SI",
	    ".1.3.6.1.4.1.9.5.7" => "5000",
	    ".1.3.6.1.4.1.9.5.18" => "1900",
	    ".1.3.6.1.4.1.9.5.20" => "2820",
	    ".1.3.6.1.4.1.9.5.28" => "1900",
	    ".1.3.6.1.4.1.9.5.29" => "5002",
	    ".1.3.6.1.4.1.9.5.42" => "2948",
	    ".1.3.6.1.4.1.9.5.44" => "6509",
	    ".1.3.6.1.4.1.45.3.12.1" => "BAY-2813", # new
	    ".1.3.6.1.4.1.343.5.1.6" => "Intel-510T",  # new
	    ".1.3.6.1.4.1.437.1.1.3.3.3" => "2800",
	    ".1.3.6.1.4.1.762.2" => "WavePOINT-II V3.83",  # new
	    ".1.3.6.1.4.1.1751.1.4.1" => "AP-1000",  # new
	    ".1.3.6.1.4.1.1751.1.4.2" => "WavePOINT-II V3.95",  # new
	    ".1.3.6.1.4.1.1751.1.4.5" => "AP-500 V3.95",
	    ".1.3.6.1.4.1.11898.2.4.6" => "AP-2000 v2.4.5",  # new
	    ".1.3.6.1.4.1.11898.2.4.12" => "AP-4000",  # new
# Cisco Identity mib objects of interest
	    ".1.3.6.1.4.1.9.12.3.1.10.150" => "cevPortBaseTEther",
	    ".1.3.6.1.4.1.9.12.3.1.10.1" => "cevPortUnknown",
	    ".1.3.6.1.4.1.9.12.3.1.3.372" => "WS-C3750G-24TS",
	    ".1.3.6.1.4.1.9.12.3.1.3.373" => "WS-C3750G-24T",
	    ".1.3.6.1.4.1.9.12.3.1.3.394" => "WS-C3750G-12S",
	    ".1.3.6.1.4.1.9.12.3.1.3.460" => "WS-C3750G-48TS",
	    "" => "",
	   };


$table_headers = [
		  "Loc",
		  "Port",
		  "Connected to",
		  "Speed/NetReg",
		  "Speed/Conf",
		  "Speed/Curr",
		  "Duplex/NetReg",
		  "Duplex/Conf",
		  "Duplex/Curr",
		  "PortFast/NetReg",
		  "PortFast/Curr",
		  "Status/NetReg",
		  "Status/Admin",
		  "Status/Oper",
		  "Vlan/NetReg",
		  "Vlan/Curr",
		 ];

$device = {
	   'WS-C3750G-12S' => {
			       'Chassis_cnt' => 1,
			       'Chassis_type' => 'C3750G-12S',
			       'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C3750G_12S"
			      },
	   'WS-C3750G-24T' => {
			       'Chassis_cnt' => 1,
			       'Chassis_type' => 'C3750G-24T',
			       'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C3750G_24T"
			      },
	   'WS-C3750G-24TS' => {
				'Chassis_cnt' => 1,
				'Chassis_type' => 'C3750G-24TS',
				'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C3750G_24ST"
			       },
	   'WS-C3750G-48TS' => {
				'Chassis_cnt' => 1,
				'Chassis_type' => 'C3750G-48TS',
				'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C3750G_48ST"
			       },
	   'WS-C2950T-24' => {
			      'Chassis_cnt' => 1,
			      'Chassis_type' => 'C2950-24',
			      'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C2950_24",
			      'Device_construct' => "new CMU::WebInt::S_P_status::Device::D2950_24",
			     },
	   'WS-C2950SX-24-SI' => {
				  'Chassis_cnt' => 1,
				  'Chassis_type' => 'C2950-24',
				  'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C2950_24",
				  'Device_construct' => "new CMU::WebInt::S_P_status::Device::D2950_24"
				 },
	   'WS-C2950G-24-EI'  => {
				  'Chassis_cnt' => 1,
				  'Chassis_type' => 'C2950-24',
				  'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C2950_24",
				  'Device_construct' => "new CMU::WebInt::S_P_status::Device::D2950_24"
				 },
	   'WS-C2950G-48-EI' => {
				 'Chassis_cnt' => 1,
				 'Chassis_type' => 'C2950-48',
				 'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C2950_48",
				 'Device_construct' => "new CMU::WebInt::S_P_status::Device::D2950_48"
				},
	   'WS-C2950SX-48-SI' => {
				  'Chassis_cnt' => 1,
				  'Chassis_type' => 'C2950-48',
				  'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C2950_48",
				  'Device_construct' => "new CMU::WebInt::S_P_status::Device::D2950_48"
				 },
	   'WS-C3548-XL-EN' =>  {
				 'Chassis_cnt' => 1,
				 'Chassis_type' => 'C3500-48',
				 'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C3500_48",
				 'Device_construct' => "new CMU::WebInt::S_P_status::Device::D3500_48"
				},
	   'WS-C3524-XL' =>  {
			      'Chassis_cnt' => 1,
			      'Chassis_type' => 'C3500-24',
			      'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C3500_24",
			      'Device_construct' => "new CMU::WebInt::S_P_status::Device::D3500_24"
			     },
	   'WS-C3524-PWR-XL' =>  {
				  'Chassis_cnt' => 1,
				  'Chassis_type' => 'C3500-24',
				  'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C3500_24",
				  'Device_construct' => "new CMU::WebInt::S_P_status::Device::D3500_24"
				 },
	   
	   '6509' => {
		      'Chassis_cnt' => 1,
		      'Chassis_type' => 'C6509',
		      'Chassis_construct' => "new CMU::WebInt::S_P_status::Chassis::C6509",
		      'Port_type' => "P6509",
		      'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
		      'Device_construct' => "new CMU::WebInt::S_P_status::Device::D6509"
		     },
	   
	   '3750' => {
		      'Chassis_cnt' => 'Runtime',
		      'Chassis_type' => 'Runtime',
		      'Chassis_construct' => "Runtime",
		      'Port_type' => "P3750",
		      'Port_construct' => "new CMU::WebInt::S_P_status::Port::P3750",
		      'Device_construct' => "new CMU::WebInt::S_P_status::Device::D3750"
		     }
	  };




$chassis = {
	    'C3750G-12S' => {
			     'Blade_cnt' => 1,
			     'Blade_type' => ['B3750-12'],
			     'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B3750_12"
			    },
	    'C3750G-24T' => {
			     'Blade_cnt' => 1,
			     'Blade_type' => ['B3750-24T'],
			     'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B3750_24T"
			    },
	    'C3750G-24TS' => {
			      'Blade_cnt' => 1,
			      'Blade_type' => ['B3750-24TS'],
			      'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B3750_24TS"
			     },
	    'C3750G-48TS' => {
			      'Blade_cnt' => 1,
			      'Blade_type' => ['B3750-48TS'],
			      'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B3750_48TS"
			     },
	    'C2950-24' => {
			   'Blade_cnt' => 1,
			   'Blade_type' => ['B2900-24'],
			   'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B2950_24"
			  },
	    'C2950-48' => {
			   'Blade_cnt' => 1,
			   'Blade_type' => ['B2900-48'],
			   'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B2950_48"
			  },
	    'C3500-48' => {
			   'Blade_cnt' => 1,
			   'Blade_type' => ['B3500-48'],
			   'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B3500_48"
			  },
	    'C3500-24' => {
			   'Blade_cnt' => 1,
			   'Blade_type' => ['B3500-24'],
			   'Blade_construct' => "new CMU::WebInt::S_P_status::Blade::B3500_24"
			  },
	    'C6509' => {
			'Blade_cnt' => 9,
			'Blade_type' => 'B6509',
			'Blade_construct' => "Runtime"
		       }
	   };


$blade = {
	  'B3750_12' => {
			 'Port_cnt' => 12,
			 'Port_type' => "P3750",
			 'Port_construct' => "new CMU::WebInt::S_P_status::Port::P3750",
			 'Layout' => [[ 1,2,3,4,undef,undef,5,6,7,8,undef,undef,9,10,11,12]]
			},
	  'B3750_24TS' => {
			   'Port_cnt' => 28,
			   'Port_type' => "P3750",
			   'Port_construct' => "new CMU::WebInt::S_P_status::Port::P3750",
			   'Layout' => [
					[1,3,5,7, 9,11, undef,undef,13,15,17,19,21,23],
					[2,4,6,8,10,12, undef,undef,14,16,18,20,22,24,undef,undef,undef,undef,undef,undef,25,26,27,28]
				       ],
			  },
	  'B3750_48TS' => {
			   'Port_cnt' => 52,
			   'Port_type' => "P3750",
			   'Port_construct' => "new CMU::WebInt::S_P_status::Port::P3750",
			   'Layout' => [
					[1,3,5,7, 9,11,13,15,undef,undef,17,19,21,23,25,27,29,31,undef,undef,33,35,37,39,41,43,45,47,undef,undef,undef,undef,49,51],
					[2,4,6,8,10,12,14,16,undef,undef,18,20,22,24,26,28,30,32,undef,undef,34,36,38,40,42,44,46,48,undef,undef,undef,undef,50,51]
				       ],
			  },
	  'B3750_24T' => {
			  'Port_cnt' => 24,
			  'Port_type' => "P3750",
			  'Port_construct' => "new CMU::WebInt::S_P_status::Port::P3750",
			  'Layout' => [
				       [1,3,5,7, 9,11, undef,undef,13,15,17,19,21,23],
				       [2,4,6,8,10,12, undef,undef,14,16,18,20,22,24]
				      ],
			 },
	  'B2900-24' => {
			 'Port_cnt' => 26,
			 'Port_type' => "P2900",
			 'Port_construct' => "new CMU::WebInt::S_P_status::Port::P2900",
			 'Layout' => [[ 1,2,3,4,5,6,7,8,undef,undef,9,10,11,12,13,14,15,16,undef,undef,17,18,19,20,21,22,23,24,undef,undef,undef,undef,25,26]]
			},
	  'B2900-48' => {
			 'Port_cnt' => 50,
			 'Port_type' => "P2900",
			 'Port_construct' => "new CMU::WebInt::S_P_status::Port::P2900",
			 'Layout' => [
				      [ 1,3,5,7, 9,11,13,15,undef,undef,17,19,21,23,25,27,29,31,undef,undef,33,35,37,39,41,43,45,47],
				      [ 2,4,6,8,10,12,14,16,undef,undef,18,20,22,24,26,28,30,32,undef,undef,34,36,38,40,42,44,46,48,undef,undef,undef,undef,49,50]
				     ]
			},
	  'B3500-48' => {
			 'Port_cnt' => 50,
			 'Port_type' => "P2900",
			 'Port_construct' => "new CMU::WebInt::S_P_status::Port::P2900",
			 'Layout' => [
				      [ 1,3,5,7, 9,11,13,15,undef,17,19,21,23,25,27,29,31,undef,33,35,37,39,41,43,45,47],
				      [ 2,4,6,8,10,12,14,16,undef,18,20,22,24,26,28,30,32,undef,34,36,38,40,42,44,46,48,undef,undef,49,50]
				     ]
			},
	  'B3500-24' => {
			 'Port_cnt' => 26,
			 'Port_type' => "P2900",
			 'Port_construct' => "new CMU::WebInt::S_P_status::Port::P2900",
			 'Layout' => [[ 1,2,3,4,5,6,7,8,undef,9,10,11,12,13,14,15,16,undef,17,18,19,20,21,22,23,24,undef,undef,25,26]]
			},
	  'B6509' => {
		      'Port_cnt' => 4,
		      'Port_type' => "P6509",
		      'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
		      'Layout' => [[ 1,undef,undef,2,undef,undef,3,undef,undef,4]]
		     },
	  'B6509_WS_SUP720_3B' => {
				   'Port_cnt' => 2,
				   'Port_type' => "P6509",
				   'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
				   'Layout' => [[undef,undef,undef,1,2]]
				  },
	  'B6509_WS_X6248_RJ_45' => {
				     'Port_cnt' => 48,
				     'Port_type' => "P6509",
				     'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
				     'Layout' => [
						  [ 1,3,5,7, 9,11,undef,13,15,17,19,21,23,undef,25,27,29,31,33,35,undef,37,39,41,43,45,47],
						  [ 2,4,6,8,10,12,undef,14,16,18,20,22,24,undef,26,28,30,32,34,36,undef,38,40,42,44,46,48]
						 ]
				    },
	  'B6509_WS_X6408_GBIC' => {
				     'Port_cnt' => 8,
				     'Port_type' => "P6509",
				     'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
				     'Layout' => [[ 1,2,3,4,5,6,7,8]]
				    },
	  'B6509_WS_X6408A_GBIC' => {
				     'Port_cnt' => 8,
				     'Port_type' => "P6509",
				     'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
				     'Layout' => [[ 1,2,3,4,5,6,7,8]]
				    },
	  'B6509_WS_X6748_GE_TX' => {
				     'Port_cnt' => 48,
				     'Port_type' => "P6509",
				     'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
				     'Layout' => [
						  [ 1,3,5,7, 9,11,undef,13,15,17,19,21,23,undef,25,27,29,31,33,35,undef,37,39,41,43,45,47],
						  [ 2,4,6,8,10,12,undef,14,16,18,20,22,24,undef,26,28,30,32,34,36,undef,38,40,42,44,46,48]
						 ]
				    },
	  'B6509_blank' => {
			    'Port_cnt' => 0,
			    'Port_type' => "P6509",
			    'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
			    'Layout' => [[]]
			   },
	  'B6509_unknown' => {
			    'Port_cnt' => 0,
			    'Port_type' => "P6509",
			    'Port_construct' => "new CMU::WebInt::S_P_status::Port::P6509",
			    'Layout' => [[]]
			   },
	  
	  
	 };

$port = {

	 'P2900' => {
		     'netreg' => [
				  'Connected to',
				  'Duplex/NetReg',
				  'Vlan/NetReg',
				  'Status/NetReg',
				  'Speed/NetReg',
				  'PortFast/NetReg'
				 ],
		     'oids' => {
				'Port'               => { oid => ".1.3.6.1.2.1.2.2.1",
							  info => "2.%snmp_port_num%"},
				'CDP_Neighbor'  => {
						    woid => ".1.3.6.1.4.1.9.9.23.1.2",
						    info => "1.1.4.%snmp_port_num%",
						    xlate => "ip2hostname"
						   },
				
				'Speed/Conf'   => { oid => ".1.3.6.1.4.1.9.9.87.1.4.1.1",
						    info => "33.0.%snmp_port_num%",
						    xlate => {
							      1 => "auto",
							      10000000 => "10",
							      100000000 => "10",
							      1000000000 => "1000",
							      155520000 => "155.5"
							     }
						  },
				'Speed/Curr'      => { oid => ".1.3.6.1.2.1.2.2.1",
						       info => "5.%snmp_port_num%",
						       xlate => {
								 10000000 => "10",
								 100000000 => "100",
								 1000000000 => "1000",
								 155520000 => "155.5"
								}
						     },
				'Duplex/Conf'  => { oid => ".1.3.6.1.4.1.9.9.87.1.4.1.1",
						    info => "31.0.%snmp_port_num%",
						    xlate => {
							      1 => "full",
							      2 => "half",
							      3 => "auto"
							     }
						  },
				'Duplex/Curr'     => { oid => ".1.3.6.1.4.1.9.9.87.1.4.1.1",
						       info => "32.0.%snmp_port_num%",
						       xlate => {
								 1 => "full",
								 2 => "half"
								}
						     },
				'Status/Admin'       => { oid => ".1.3.6.1.2.1.2.2.1",
							  info => "7.%snmp_port_num%",
							  xlate => {
								    1 => "up",
								    2 => "down",
								    3 => "testing"
								   }
							},
				'Status/Oper'        => { oid => ".1.3.6.1.2.1.2.2.1",
							  info => "8.%snmp_port_num%",
							  xlate => {
								    1 => "up",
								    2 => "down",
								    3 => "testing"
								   }
							},
				'PortFast/Curr'   => { oid => ".1.3.6.1.4.1.9.9.87.1.4.1.1",
						       info => "36.0.%snmp_port_num%",
						       xlate => {
								 1 => "enabled",
								 2 => "disabled"
								}
						     },
				'Vlan/Curr'        => { oid => ".1.3.6.1.4.1.9.9.68.1.2",
							info => "2.1.2.%snmp_port_num%" }
			       },
		     status_check => [
				      'speed_chk',
				      'duplex_chk',
				      'status_chk',
				      'portfast_chk',
				      'vlan_chk'
				     ]
		    },
	 'P3750' => {
		     'netreg' => [
				  'Connected to',
				  'Duplex/NetReg',
				  'Vlan/NetReg',
				  'Status/NetReg',
				  'Speed/NetReg',
				  'PortFast/NetReg'
				 ],
		     'oids' => {
				'CDP_Neighbor'  => {
						    woid => ".1.3.6.1.4.1.9.9.23.1.2",
						    info => "1.1.4.%snmp_port_num%",
						    xlate => "ip2hostname"
						   },
				
				'PortType'     => { oid => ".1.3.6.1.4.1.9.5.1.4.1.1",
						    info => "5.%chassisport%",
						    xlate => {
							      1 => 'other',
							      2 => 'cddi',
							      3 => 'fddi',
							      4 => 'tppmd',
							      5 => 'mlt3',
							      6 => 'sddi',
							      7 => 'smf',
							      8 => 'e10BaseT',
							      9 => 'e10BaseF',
							      10 => 'scf',
							      11 => '100-TX',
							      12 => '100-T4',
							      13 => '100-F',
							      14 => 'atmOc3mmf',
							      15 => 'atmOc3smf',
							      16 => 'atmOc3utp',
							      17 => '100-Fsm',
							      18 => '10a100-TX',
							      19 => 'mii',
							      20 => 'vlanRouter',
							      21 => 'remoteRouter',
							      22 => 'tokenring',
							      23 => 'atmOc12mmf',
							      24 => 'atmOc12smf',
							      25 => 'atmDs3',
							      26 => 'tokenringMmf',
							      27 => '1G-LX',
							      28 => '1G-SX',
							      29 => '1G-CX',
							      30 => 'networkAnalysis',
							      31 => '1G-XX',
							      32 => '1G-LH',
							      33 => '1G-T',
							      34 => '1G-USG',
							      35 => '1G-ZX',
							      36 => 'depi2',
							      37 => 't1',
							      38 => 'e1',
							      39 => 'fxs',
							      40 => 'fxo',
							      41 => 'transcoding',
							      42 => 'conferencing',
							      43 => 'atmOc12mm',
							      44 => 'atmOc12smi',
							      45 => 'atmOc12sml',
							      46 => 'posOc12mm',
							      47 => 'posOc12smi',
							      48 => 'posOc12sml',
							      49 => 'posOc48mm',
							      50 => 'posOc48smi',
							      51 => 'posOc48sml',
							      52 => 'posOc3mm',
							      53 => 'posOc3smi',
							      54 => 'posOc3sml',
							      55 => 'intrusionDetect',
							      56 => '10G-CPX',
							      57 => '10G-LX4',
							      59 => '10G-EX4',
							      60 => '10G-XX',
							      61 => '10.0.0-T',
							      62 => 'dptOc48mm',
							      63 => 'dptOc48smi',
							      64 => 'dptOc48sml',
							      65 => '10G-LR',
							      66 => 'chOc12smi',
							      67 => 'chOc12mm',
							      68 => 'chOc48ss',
							      69 => 'chOc48smi',
							      70 => '10G-SX4',
							      71 => '10G-ER',
							      72 => 'contentEngine',
							      73 => 'ssl',
							      74 => 'firewall',
							      75 => 'vpnIpSec',
							      76 => 'ct3',
							      77 => '1G-Cwdm1470',
							      78 => '1G-Cwdm1490',
							      79 => '1G-Cwdm1510',
							      80 => '1G-Cwdm1530',
							      81 => '1G-Cwdm1550',
							      82 => '1G-Cwdm1570',
							      83 => '1G-Cwdm1590',
							      84 => '1G-Cwdm1610',
							      85 => '1G-BT',
							      86 => '1G-Unapproved',
							      87 => 'chOc3smi',
							      88 => 'mcr',
							      89 => 'coe',
							      90 => 'mwa',
							      91 => 'psd',
							      92 => '100-LX',
							      93 => '10G-SR',
							      94 => '10G-CX4',
							      1000 => '1G-Unknown',
							      1001 => '10G-Unknown',
							      1002 => '10G-Unapproved',
							      1003 => '1G-WdmRxOnly',
							      1004 => '1G-Dwdm3033',
							      1005 => '1G-Dwdm3112',
							      1006 => '1G-Dwdm3190',
							      1007 => '1G-Dwdm3268',
							      1008 => '1G-Dwdm3425',
							      1009 => '1G-Dwdm3504',
							      1010 => '1G-Dwdm3582',
							      1011 => '1G-Dwdm3661',
							      1012 => '1G-Dwdm3819',
							      1013 => '1G-Dwdm3898',
							      1014 => '1G-Dwdm3977',
							      1015 => '1G-Dwdm4056',
							      1016 => '1G-Dwdm4214',
							      1017 => '1G-Dwdm4294',
							      1018 => '1G-Dwdm4373',
							      1019 => '1G-Dwdm4453',
							      1020 => '1G-Dwdm4612',
							      1021 => '1G-Dwdm4692',
							      1022 => '1G-Dwdm4772',
							      1023 => '1G-Dwdm4851',
							      1024 => '1G-Dwdm5012',
							      1025 => '1G-Dwdm5092',
							      1026 => '1G-Dwdm5172',
							      1027 => '1G-Dwdm5252',
							      1028 => '1G-Dwdm5413',
							      1029 => '1G-Dwdm5494',
							      1030 => '1G-Dwdm5575',
							      1031 => '1G-Dwdm5655',
							      1032 => '1G-Dwdm5817',
							      1033 => '1G-Dwdm5898',
							      1034 => '1G-Dwdm5979',
							      1035 => '1G-Dwdm6061',
							      1036 => '10G-WdmRxOnly',
							      1037 => '10G-Dwdm3033',
							      1038 => '10G-Dwdm3112',
							      1039 => '10G-Dwdm3190',
							      1040 => '10G-Dwdm3268',
							      1041 => '10G-Dwdm3425',
							      1042 => '10G-Dwdm3504',
							      1043 => '10G-Dwdm3582',
							      1044 => '10G-Dwdm3661',
							      1045 => '10G-Dwdm3819',
							      1046 => '10G-Dwdm3898',
							      1047 => '10G-Dwdm3977',
							      1048 => '10G-Dwdm4056',
							      1049 => '10G-Dwdm4214',
							      1050 => '10G-Dwdm4294',
							      1051 => '10G-Dwdm4373',
							      1052 => '10G-Dwdm4453',
							      1053 => '10G-Dwdm4612',
							      1054 => '10G-Dwdm4692',
							      1055 => '10G-Dwdm4772',
							      1056 => '10G-Dwdm4851',
							      1057 => '10G-Dwdm5012',
							      1058 => '10G-Dwdm5092',
							      1059 => '10G-Dwdm5172',
							      1060 => '10G-Dwdm5252',
							      1061 => '10G-Dwdm5413',
							      1062 => '10G-Dwdm5494',
							      1063 => '10G-Dwdm5575',
							      1064 => '10G-Dwdm5655',
							      1065 => '10G-Dwdm5817',
							      1066 => '10G-Dwdm5898',
							      1067 => '10G-Dwdm5979',
							      1068 => '10G-Dwdm6061'
							     }
						  },

				'Port'         => { oid => ".1.3.6.1.2.1.2.2.1",
						    info => '2.%snmp_port_num%'},
				'Speed/Conf'   => { oid => '.1.3.6.1.4.1.9.5.1.4.1.1',
						    info => '9.%chassisport%',
						    xlate => {
							      1 => "auto",
							      10000000 => "10",
							      100000000 => "10",
							      1000000000 => "1000",
							      155520000 => "155.5"
							     }
						  },
				'Speed/Curr'   => { oid => '.1.3.6.1.2.1.2.2.1',
						    info => '5.%snmp_port_num%',
						    xlate => {
							      10000000 => "10",
							      100000000 => "100",
							      1000000000 => "1000",
							      155520000 => "155.5"
							     }
						  },
				'Duplex/Conf'  => { oid => '.1.3.6.1.4.1.9.5.1.4.1.1',
						    info => '10.%chassisport%',
						    xlate => {
							      1 => "N/A",
							      2 => "N/A",
							      3 => "N/A",
							      4 => "N/A"
							     }
						  },
				'Duplex/Curr'  => { oid => '.1.3.6.1.4.1.9.5.1.4.1.1',
						    info => '10.%chassisport%',
						    xlate => {
							      1 => "half",
							      2 => "full",
							      3 => "disagree",
							      4 => "auto"
							     }
						  },
				'Status/Admin' => { oid => ".1.3.6.1.2.1.2.2.1",
						    info => "7.%snmp_port_num%",
						    xlate => {
							      1 => "up",
							      2 => "down",
							      3 => "testing"
							     }
						  },
				'Status/Oper'  => { oid => ".1.3.6.1.2.1.2.2.1",
						    info => "8.%snmp_port_num%",
						    xlate => {
							      1 => "up",
							      2 => "down",
							      3 => "testing"
							     }
						  },
				'PortFast/Curr' => { oid => ".1.3.6.1.4.1.9.5.1.4.1.1",
						     info => "12.%chassisport%",
						     xlate => {
							       1 => "enabled",
							       2 => "disabled"
							      }
						   },
				'Vlan/Curr'    => { oid => ".1.3.6.1.4.1.9.9.68.1.2",
						    info => "2.1.2.%snmp_port_num%" }
			       },
		     status_check => [
				      'bad_snmp_num_chk',
				      'speed_chk',
				      'status_chk',
				      'duplex_chk',
				      'vlan_chk',
				      'portfast_chk',
				     ]
		    },
	 'P6509' => {
		     'netreg' => [
				  'Connected to',
				  'Duplex/NetReg',
				  'Vlan/NetReg',
				  'Status/NetReg',
				  'Speed/NetReg',
				  'PortFast/NetReg'
				 ],
		     'oids' => {
				'CDP_Neighbor'  => {
						    woid => ".1.3.6.1.4.1.9.9.23.1.2",
						    info => "1.1.4.%snmp_port_num%",
						    xlate => "ip2hostname"
						   },
				
				'PortType'     => { oid => ".1.3.6.1.4.1.9.5.1.4.1.1",
						    info => "5.%chassisport%",
						    xlate => {
							      1 => 'other',
							      2 => 'cddi',
							      3 => 'fddi',
							      4 => 'tppmd',
							      5 => 'mlt3',
							      6 => 'sddi',
							      7 => 'smf',
							      8 => 'e10BaseT',
							      9 => 'e10BaseF',
							      10 => 'scf',
							      11 => '100-TX',
							      12 => '100-T4',
							      13 => '100-F',
							      14 => 'atmOc3mmf',
							      15 => 'atmOc3smf',
							      16 => 'atmOc3utp',
							      17 => '100-Fsm',
							      18 => '10a100-TX',
							      19 => 'mii',
							      20 => 'vlanRouter',
							      21 => 'remoteRouter',
							      22 => 'tokenring',
							      23 => 'atmOc12mmf',
							      24 => 'atmOc12smf',
							      25 => 'atmDs3',
							      26 => 'tokenringMmf',
							      27 => '1G-LX',
							      28 => '1G-SX',
							      29 => '1G-CX',
							      30 => 'networkAnalysis',
							      31 => '1G-XX',
							      32 => '1G-LH',
							      33 => '1G-T',
							      34 => '1G-USG',
							      35 => '1G-ZX',
							      36 => 'depi2',
							      37 => 't1',
							      38 => 'e1',
							      39 => 'fxs',
							      40 => 'fxo',
							      41 => 'transcoding',
							      42 => 'conferencing',
							      43 => 'atmOc12mm',
							      44 => 'atmOc12smi',
							      45 => 'atmOc12sml',
							      46 => 'posOc12mm',
							      47 => 'posOc12smi',
							      48 => 'posOc12sml',
							      49 => 'posOc48mm',
							      50 => 'posOc48smi',
							      51 => 'posOc48sml',
							      52 => 'posOc3mm',
							      53 => 'posOc3smi',
							      54 => 'posOc3sml',
							      55 => 'intrusionDetect',
							      56 => '10G-CPX',
							      57 => '10G-LX4',
							      59 => '10G-EX4',
							      60 => '10G-XX',
							      61 => '10.0.0-T',
							      62 => 'dptOc48mm',
							      63 => 'dptOc48smi',
							      64 => 'dptOc48sml',
							      65 => '10G-LR',
							      66 => 'chOc12smi',
							      67 => 'chOc12mm',
							      68 => 'chOc48ss',
							      69 => 'chOc48smi',
							      70 => '10G-SX4',
							      71 => '10G-ER',
							      72 => 'contentEngine',
							      73 => 'ssl',
							      74 => 'firewall',
							      75 => 'vpnIpSec',
							      76 => 'ct3',
							      77 => '1G-Cwdm1470',
							      78 => '1G-Cwdm1490',
							      79 => '1G-Cwdm1510',
							      80 => '1G-Cwdm1530',
							      81 => '1G-Cwdm1550',
							      82 => '1G-Cwdm1570',
							      83 => '1G-Cwdm1590',
							      84 => '1G-Cwdm1610',
							      85 => '1G-BT',
							      86 => '1G-Unapproved',
							      87 => 'chOc3smi',
							      88 => 'mcr',
							      89 => 'coe',
							      90 => 'mwa',
							      91 => 'psd',
							      92 => '100-LX',
							      93 => '10G-SR',
							      94 => '10G-CX4',
							      1000 => '1G-Unknown',
							      1001 => '10G-Unknown',
							      1002 => '10G-Unapproved',
							      1003 => '1G-WdmRxOnly',
							      1004 => '1G-Dwdm3033',
							      1005 => '1G-Dwdm3112',
							      1006 => '1G-Dwdm3190',
							      1007 => '1G-Dwdm3268',
							      1008 => '1G-Dwdm3425',
							      1009 => '1G-Dwdm3504',
							      1010 => '1G-Dwdm3582',
							      1011 => '1G-Dwdm3661',
							      1012 => '1G-Dwdm3819',
							      1013 => '1G-Dwdm3898',
							      1014 => '1G-Dwdm3977',
							      1015 => '1G-Dwdm4056',
							      1016 => '1G-Dwdm4214',
							      1017 => '1G-Dwdm4294',
							      1018 => '1G-Dwdm4373',
							      1019 => '1G-Dwdm4453',
							      1020 => '1G-Dwdm4612',
							      1021 => '1G-Dwdm4692',
							      1022 => '1G-Dwdm4772',
							      1023 => '1G-Dwdm4851',
							      1024 => '1G-Dwdm5012',
							      1025 => '1G-Dwdm5092',
							      1026 => '1G-Dwdm5172',
							      1027 => '1G-Dwdm5252',
							      1028 => '1G-Dwdm5413',
							      1029 => '1G-Dwdm5494',
							      1030 => '1G-Dwdm5575',
							      1031 => '1G-Dwdm5655',
							      1032 => '1G-Dwdm5817',
							      1033 => '1G-Dwdm5898',
							      1034 => '1G-Dwdm5979',
							      1035 => '1G-Dwdm6061',
							      1036 => '10G-WdmRxOnly',
							      1037 => '10G-Dwdm3033',
							      1038 => '10G-Dwdm3112',
							      1039 => '10G-Dwdm3190',
							      1040 => '10G-Dwdm3268',
							      1041 => '10G-Dwdm3425',
							      1042 => '10G-Dwdm3504',
							      1043 => '10G-Dwdm3582',
							      1044 => '10G-Dwdm3661',
							      1045 => '10G-Dwdm3819',
							      1046 => '10G-Dwdm3898',
							      1047 => '10G-Dwdm3977',
							      1048 => '10G-Dwdm4056',
							      1049 => '10G-Dwdm4214',
							      1050 => '10G-Dwdm4294',
							      1051 => '10G-Dwdm4373',
							      1052 => '10G-Dwdm4453',
							      1053 => '10G-Dwdm4612',
							      1054 => '10G-Dwdm4692',
							      1055 => '10G-Dwdm4772',
							      1056 => '10G-Dwdm4851',
							      1057 => '10G-Dwdm5012',
							      1058 => '10G-Dwdm5092',
							      1059 => '10G-Dwdm5172',
							      1060 => '10G-Dwdm5252',
							      1061 => '10G-Dwdm5413',
							      1062 => '10G-Dwdm5494',
							      1063 => '10G-Dwdm5575',
							      1064 => '10G-Dwdm5655',
							      1065 => '10G-Dwdm5817',
							      1066 => '10G-Dwdm5898',
							      1067 => '10G-Dwdm5979',
							      1068 => '10G-Dwdm6061'
							     }
						  },

				'Port'         => { oid => ".1.3.6.1.2.1.2.2.1",
						    info => '2.%snmp_port_num%'},
				'Speed/Conf'   => { oid => '.1.3.6.1.4.1.9.5.1.4.1.1',
						    info => '9.%chassisport%',
						    xlate => {
							      1 => "auto",
							      10000000 => "10",
							      100000000 => "10",
							      1000000000 => "1000",
							      10000000000 => "10G",
							      155520000 => "155.5"
							     }
						  },
				'Speed/Curr'   => { oid => '.1.3.6.1.2.1.2.2.1',
						    info => '5.%snmp_port_num%',
						    xlate => {
							      10000000 => "10",
							      100000000 => "100",
							      1000000000 => "1000",
							      10000000000 => "10G",
							      155520000 => "155.5"
							     }
						  },
				'Duplex/Conf'  => { oid => '.1.3.6.1.4.1.9.5.1.4.1.1',
						    info => '10.%chassisport%',
						    xlate => {
							      1 => "half",
							      2 => "full",
							      3 => "disagree",
							      4 => "auto"
							     }
						  },
				'Duplex/Curr'  => { oid => '.1.3.6.1.4.1.9.5.1.4.1.1',
						    info => '10.%chassisport%',
						    xlate => {
							      1 => "half",
							      2 => "full",
							      3 => "disagree",
							      4 => "auto"
							     }
						  },
				'Status/Admin' => { oid => ".1.3.6.1.2.1.2.2.1",
						    info => "7.%snmp_port_num%",
						    xlate => {
							      1 => "up",
							      2 => "down",
							      3 => "testing"
							     }
						  },
				'Status/Oper'  => { oid => ".1.3.6.1.2.1.2.2.1",
						    info => "8.%snmp_port_num%",
						    xlate => {
							      1 => "up",
							      2 => "down",
							      3 => "testing"
							     }
						  },
				'PortFast/Curr' => {
						    oid => ".1.3.6.1.4.1.9.5.1.19.1.1",
						    info => "12.%chassisport%",
						    xlate => {
							      1 => "enabled",
							      2 => "disabled"
							     }
						   },
				'Vlan/Curr'    => { oid => ".1.3.6.1.4.1.9.9.68.1.2",
						    info => "2.1.2.%snmp_port_num%" }
			       },

		     status_check => [
				      'bad_snmp_num_chk',
				      'speed_chk',
				      'status_chk',
				      'duplex_chk',
				      'vlan_chk',
				      'portfast_chk',
				     ]
		    }

	};


$panel = {
	  IBM => {
		  Port_cnt => 64,
		  Layout => [
			     [ 1, 2, 3, 4, 5, 6, 7, 8],
			     [ 9,10,11,12,13,14,15,16],
			     [17,18,19,20,21,22,23,24],
			     [25,26,27,28,29,30,31,32],
			     [33,34,35,36,37,38,39,40],
			     [41,42,43,44,45,46,47,48],
			     [49,50,51,52,53,54,55,56],
			     [57,58,59,60,61,62,63,64]
			    ]
		 },
	  Cat5 => {
		   Port_cnt => 24,
		   Layout => [[1,2,3,4,5,6,undef,undef,7,8,9,10,11,12,undef,undef,13,14,15,16,17,18,undef,undef,19,20,21,22,23,24]]
		  },
	  Cat5_48 => {
		   Port_cnt => 48,
		   Layout => [[ 1, 2, 3, 4,undef,undef, 5, 6, 7, 8,undef,undef, 9,10,11,12,13,undef,undef,undef,undef,14,15,16,undef,undef,17,18,19,20,undef,undef,21,22,23,24],
			      [24,26,27,28,undef,undef,29,30,31,32,undef,undef,33,34,35,36,37,undef,undef,undef,undef,38,39,40,undef,undef,41,42,43,44,undef,undef,45,46,47,48]]
		  }
	 };

1;
