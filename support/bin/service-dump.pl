#!/usr/bin/perl
#
# Copyright (c) 2000-2002 Carnegie Mellon University. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. The name "Carnegie Mellon University" must not be used to endorse or
#    promote products derived from this software without prior written
#    permission. For permission or any legal details, please contact:
#      Office of Technology Transfer
#      Carnegie Mellon University
#      5000 Forbes Avenue
#      Pittsburgh, PA 15213-3890
#      (412) 268-4387, fax: (412) 268-7395
#      tech-transfer@andrew.cmu.edu
#
# 4. Redistributions of any form whatsoever must retain the following
#    acknowledgment: "This product includes software developed by Computing
#    Services at Carnegie Mellon University (http://www.cmu.edu/computing/)."
#
# CARNEGIE MELLON UNIVERSITY DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
# SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS,
# IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY BE LIABLE FOR ANY SPECIAL,
# INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
# OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# Service Information File (SIF) Dumper
# $Id: service-dump.pl,v 1.9 2008/03/27 19:42:43 vitroth Exp $
# 
# $Log: service-dump.pl,v $
# Revision 1.9  2008/03/27 19:42:43  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.8.20.1  2007/10/11 20:59:47  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.8.18.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.8  2004/02/20 03:17:52  kevinm
# * External config file updates
#
# Revision 1.7  2002/04/05 17:42:13  kevinm
# * Run service-xfer
#
# Revision 1.6  2002/03/07 05:28:43  kevinm
# * Various modifications
#
# Revision 1.5  2002/02/21 03:16:50  kevinm
# Dump in new service file format
#
# Revision 1.4  2002/01/30 21:37:34  kevinm
# Fixed vars_l
#
# Revision 1.3  2001/12/17 20:58:21  kevinm
# Got it out of my sandbox
#
# Revision 1.2  2001/11/06 18:10:57  kevinm
# Prints out DNS resources now, as well.
#
# Revision 1.1  2001/11/06 16:51:33  kevinm
# Initial checking. service-dump will output a .sif file of all services configured.
#
#
#


use Fcntl ':flock';

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;
use CMU::Netdb::config;

use strict;

use Data::Dumper;

my $USER = 'netreg';
my $DEBUG = 0;

my ($SPATH, $NRHOME, $vres);
($vres, $NRHOME) = CMU::Netdb::config::get_multi_conf_var('netdb', 'NRHOME');
($vres, $SPATH) = CMU::Netdb::config::get_multi_conf_var('netdb', 
							 'SERVICE_PATH');

if ($ARGV[0] eq '-debug') {
  $SPATH = '/tmp';
  $DEBUG = 1;
  print "** Debug Mode Enabled **\n";
}

## ASSUME: We're running inside scheduled, so locking is done for us.

my $dbh = CMU::Netdb::lw_db_connect();
# check for errors?
#if (!$dbh) {
#  &CMU::Netdb::netdb_mail('service-dump.pl', 'Database handle is NULL!', 'service-dump.pl error');
#  exit -1;
#}

my %FileContents;
$FileContents{members} = {};

## Get all services
my @services = @{sdump_Get_Services($dbh, $USER)};
foreach(@services) {
  $FileContents{services} .= sdump_Dump_Service($dbh, $USER, $_, \%FileContents);
}
sdump_Print_File($SPATH, \%FileContents);

system($NRHOME.'/bin/service-xfer.pl') unless ($DEBUG);

$dbh->disconnect();

exit(0);

## ******************************************************************************
## ******************************************************************************

sub sdump_Dump_Service {
  my ($dbh, $user, $sid, $rFileContents) = @_;
  
  my %FileContents = %$rFileContents;

  my $res = CMU::Netdb::list_service_full_ref($dbh, $user, $sid);
  if (!ref $res) {
    die_msg("list_service_full ref of sid $sid returns: $res");
  }
  my %SInfo = %$res;

  print "Adding $SInfo{service_name}\n";
  my $STxt;
  $STxt .= "service \"$SInfo{service_name}\" type \"$SInfo{service_type_name}\" {".
    "\n\tdescription $SInfo{service_desc};\n\tversion $SInfo{version};\n\n";

  foreach my $k (keys %{$SInfo{attributes}}) {
    foreach my $v (@{$SInfo{attributes}->{$k}}) {
      $STxt .= "\tattr $k = $v;\n";
    }
  }
  
  ## Record this service group in the type list
  push(@{$rFileContents->{types}->{$SInfo{service_type_name}}},
       $SInfo{service_name});

  ## Add all of the member records
  my %SMTF = %CMU::Netdb::structure::service_member_type_fields;
  foreach my $Table (keys %{$SInfo{memberSum}}) {
    foreach my $ID (@{$SInfo{memberSum}->{$Table}}) {
      push(@{$rFileContents->{type_members}->{$SInfo{service_type_name}}},
	   "$Table:$ID");
      next if (defined $FileContents{members}->{"$Table:$ID"});

      my $Txt = "$Table \"".$SInfo{memberData}->{"$Table:$ID"}->{$SMTF{$Table}}."\" {\n";
      foreach my $Key (sort keys %{$SInfo{memberData}->{"$Table:$ID"}}) {
	my $prKey = $Key;
	$prKey =~ s/^$Table\.//;
	$Txt .= "\t$prKey ".
	  $SInfo{memberData}->{"$Table:$ID"}->{$Key}.";\n";
      }
      $Txt .= "};\n\n";
      
      $rFileContents->{members}->{"$Table:$ID"} = $Txt;
    }
  }
      
  ## Now add member records to the service itself
  foreach my $Table (keys %{$SInfo{memberSum}}) {
    foreach my $ID (@{$SInfo{memberSum}->{$Table}}) {
      $STxt .= "\tmember type \"$Table\" name \"".
	$SInfo{memberData}->{"$Table:$ID"}->{$SMTF{$Table}}."\" {\n";
      
      foreach my $Key (keys %{$SInfo{member_attr}->{"$Table:$ID"}}) {
	foreach my $v (@{$SInfo{member_attr}->{"$Table:$ID"}->{$Key}}) {
	  my ($lkey, $lval) = ($Key, $v->[0]);
	  $lval =~ s/=/\\=/;
	  $lkey =~ s/=/\\=/;
	  
	  $STxt .= "\t\tattr $lkey = $lval;\n";
	}
      }
      $STxt .= "\t};\n\n";
    }
  }

  ## Add DNS resource records
  my %res_pos = %{$SInfo{dnsResPos}};
  foreach my $dr (@{$SInfo{dnsResources}}) {
    my ($type, $name, $rn) = ($dr->[$res_pos{'dns_resource.type'}],
			      $dr->[$res_pos{'dns_resource.name'}],
			      $dr->[$res_pos{'dns_resource.rname'}]);
    $STxt .= "\tresource $type {\n";
    foreach(qw/name rname text0 text1/) {
      $STxt .= "\t\t$_ ".$dr->[$res_pos{"dns_resource.$_"}].";\n" 
	unless ($dr->[$res_pos{"dns_resource.$_"}] eq '');
    }
    foreach(qw/ttl rmetric0 rmetric1 rport/) {
      $STxt .= "\t\t$_ ".$dr->[$res_pos{"dns_resource.$_"}].";\n" 
	unless ($dr->[$res_pos{"dns_resource.$_"}] eq '' ||
		$dr->[$res_pos{"dns_resource.$_"}] eq '0');
    }
    $STxt .= "\t};\n";
  }

  ## Add DHCP Options
  my %dhcp_pos = %{$SInfo{dhcpOptPos}};
  foreach my $do (@{$SInfo{dhcpOptions}}) {
    my ($name, $format, $number, $value) = 
      ($do->[$dhcp_pos{'dhcp_option_type.name'}],
       $do->[$dhcp_pos{'dhcp_option_type.format'}],
       $do->[$dhcp_pos{'dhcp_option_type.number'}],
       $do->[$dhcp_pos{'dhcp_option.value'}]);
    $STxt .= "\tdhcp_option \"$name\" {\n".
      "\t\tformat $format;\n".
	"\t\tnumber $number;\n".
	  "\t\tvalue $value;\n".
	    "\t};\n\n";
  }

  $STxt .= "};\n\n";
  $rFileContents->{service_contents}->{$SInfo{service_name}} = $STxt;

  return $STxt;
}
  

sub sdump_Get_Services {
  my ($dbh, $user) = @_;
  
  my $res = CMU::Netdb::list_services($dbh, $user, '');
  my %serv_pos = %{CMU::Netdb::makemap($res->[0])};
  shift(@$res);
  my @Services;
  foreach my $serv (@$res) {
    push(@Services, $serv->[$serv_pos{'service.id'}]);
  }
  \@Services;
}

sub sdump_Print_File {
  my ($GenPath, $rFileContents) = @_;

  my %Contents = %$rFileContents;
  my $now = time();
  my $formatted = localtime($now);

  delete $rFileContents->{services};
  # Write out the full file
  open(FILE, ">$GenPath/services.sif") 
    || die_msg("Unable to open $GenPath/services.sif for writing!");
  print FILE "sif-header {\n\toriginator NetReg;\n".
    "\tfile-type Full;\n".
      "\ttimestamp $now;\n".
	"\ttime-formatted $formatted;\n};\n\n";
  
  foreach my $m (sort {$a cmp $b} keys %{$Contents{members}}) {
    print FILE $Contents{members}->{$m};
  }
  print FILE $Contents{services};
  close(FILE);
  
  # Now write out files for individual service types
  foreach my $Type (keys %{$Contents{types}}) {
    my $ntype = $Type;
    $ntype =~ s/\s+/_/g;
    open(FILE, ">$GenPath/services.$ntype.sif")
      || die_msg("Unable to open $GenPath/services.$ntype.sif for writing!");
    print FILE "sif-header {\n\toriginator NetReg;\n".
      "\tfile-type Partial/$ntype;\n".
	"\ttimestamp $now;\n".
	  "\ttime-formatted $formatted;\n};\n\n";
    
    my @Members = CMU::Netdb::unique(@{$Contents{type_members}->{$Type}});
    
    foreach my $M (@Members) {
      print FILE $Contents{members}->{$M};
    }
    
    my @SGs = @{$Contents{types}->{$Type}};
    foreach my $S (@SGs) {
      print FILE $Contents{service_contents}->{$S};
    }
    
    close(FILE);
  }
}

sub die_msg {
  my ($msg) = @_;
  CMU::Netdb::netdb_mail('service-dump.pl', $msg, 'service-dump died');
  die $msg;
}
 
