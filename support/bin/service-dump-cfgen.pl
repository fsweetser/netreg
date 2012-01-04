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
# $Id: service-dump-cfgen.pl,v 1.4 2006/10/10 11:52:05 vitroth Exp $
# 
# $Log: service-dump-cfgen.pl,v $
# Revision 1.4  2006/10/10 11:52:05  vitroth
# minor updates for debugging & better formatting
#
# Revision 1.3  2006/08/07 11:57:45  vitroth
# Brought service-dump-cfgen.pl from WPI branch to HEAD.
#
# Revision 1.2.2.1  2005/07/08 21:15:03  fes
# Add misc new files
#
# Revision 1.1  2005/06/29 17:53:28  fes
# First pass of uploading the WPI changes into the ipranges branch.
# Highlights include:
#   - ip ranges support
#   - machine to outlet mapping (this just uses a horrible hack table
#     rather than the upcoming outlet code for now, but it should readily
#     transferable to the new outlet code when it is done)
#   - Changes to work with MySQL 4.1
#   - Various WPI policy related changes
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
use Config::General;

use strict;

use Data::Dumper;

my $USER = 'netreg';
my $DEBUG = 0;

my ($SPATH, $XFERPATH, $NRHOME, $vres);
($vres, $NRHOME) = CMU::Netdb::config::get_multi_conf_var('netdb', 'NRHOME');
($vres, $SPATH) = CMU::Netdb::config::get_multi_conf_var('netdb', 
							 'SERVICE_PATH');
($vres, $XFERPATH) = CMU::Netdb::config::get_multi_conf_var('netdb', 
							    'SERVICE_XFER_PATH');


if ($ARGV[0] eq '-debug') {
  $SPATH = '/tmp';
  $DEBUG = 1;
  print "** Debug Mode Enabled **\n";
}

## ASSUME: We're running inside scheduled, so locking is done for us.

my $dbh = CMU::Netdb::lw_db_connect();
# check for errors?
if (!$dbh) {
  &CMU::Netdb::netdb_mail('service-dump.pl', 'Database handle is NULL!', 'service-dump.pl error');
  exit -1;
}

my %svhash;
my $conf = new Config::General(
			       -ConfigHash => \%svhash,
			       -StoreDelimiter => ' = ',
			       );

my %FileContents;
$FileContents{members} = {};

## Get all services
my @services = @{sdump_Get_Services($dbh, $USER)};
foreach(@services) {
  print "service: $_\n";
  sdump_Dump_Service($dbh, $USER, $_, \%FileContents);
}
my $now = time();
my $formatted = localtime($now);
$svhash{'sif-header'} = {
			 'originator' => 'NetReg',
			 'file-type' => 'Full',
			 'timestamp' => $now,
			 'time-formatted' => $formatted
			 };

$conf->save_file($SPATH."/services.cfg");

#system($NRHOME.'/bin/service-xfer.pl') unless ($DEBUG);

unless ($DEBUG) {
  system("/bin/cp $SPATH/services.cfg $XFERPATH/services.cfg.NEW");
  rename "$XFERPATH/services.cfg.NEW", "$XFERPATH/services.cfg";
}

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

  $svhash{'service'}{$SInfo{'service_name'}} = {
    'type' => $SInfo{'service_type_name'},
    'description' => $SInfo{'service_desc'},
    'version' => $SInfo{'version'}
  };

  foreach my $k (keys %{$SInfo{attributes}}) {
      foreach my $v (@{$SInfo{attributes}->{$k}}) {
	  $svhash{'service'}{$SInfo{'service_name'}}{'attr'}{$k} = $v;
      }
  }
  
  ## Record this service group in the type list
  push(@{$rFileContents->{types}->{$SInfo{service_type_name}}},
       $SInfo{service_name});

  ## Add all of the member records
  my %SMTF = %CMU::Netdb::structure::service_member_type_fields;
  foreach my $Table (keys %{$SInfo{memberSum}}) {
    print "Dumping all members of type $Table\n";
    foreach my $ID (@{$SInfo{memberSum}->{$Table}}) {
      push(@{$rFileContents->{type_members}->{$SInfo{service_type_name}}},
	   "$Table:$ID");
      next if (defined $FileContents{members}->{"$Table:$ID"});
      my $name = $SInfo{memberData}->{"$Table:$ID"}->{$SMTF{$Table}};
      
      foreach my $Key (sort keys %{$SInfo{memberData}->{"$Table:$ID"}}) {
	my $prKey = $Key;
	$prKey =~ s/^$Table\.//;
	$svhash{$Table}{$name}{$prKey} = $SInfo{'memberData'}->{"$Table:$ID"}->{$Key};
      }
    }
  }
      
  ## Now add member records to the service itself
  foreach my $Table (keys %{$SInfo{memberSum}}) {
    foreach my $ID (@{$SInfo{memberSum}->{$Table}}) {

      my $mname = $SInfo{'memberData'}->{"$Table:$ID"}->{$SMTF{$Table}};
      $svhash{'service'}{$SInfo{'service_name'}}{'member'}{$Table}{$mname}{'ismember'} = 1;

      foreach my $Key (keys %{$SInfo{member_attr}->{"$Table:$ID"}}) {
	foreach my $v (@{$SInfo{member_attr}->{"$Table:$ID"}->{$Key}}) {
	  my ($lkey, $lval) = ($Key, $v->[0]);
	  $lval =~ s/=/\\=/;
	  $lkey =~ s/=/\\=/;
	  
	  $svhash{'service'}{$SInfo{'service_name'}}{'member'}{$Table}{$mname}{'attr'}{$lkey} = $lval;
	}
      }
    }
  }

  ## Add DNS resource records
  my %res_pos = %{$SInfo{dnsResPos}};
  foreach my $dr (@{$SInfo{dnsResources}}) {
    my ($type, $name, $rn) = ($dr->[$res_pos{'dns_resource.type'}],
			      $dr->[$res_pos{'dns_resource.name'}],
			      $dr->[$res_pos{'dns_resource.rname'}]);



    foreach(qw/name rname text0 text1/) {
      $svhash{'service'}{$SInfo{'service_name'}}{'resource'}{$type}{$_} =
	  $dr->[$res_pos{"dns_resource.$_"}]
	  unless ($dr->[$res_pos{"dns_resource.$_"}] eq '');
    }
    foreach(qw/ttl rmetric0 rmetric1 rport/) {
      $svhash{'service'}{$SInfo{'service_name'}}{'resource'}{$type}{$_} =
	  $dr->[$res_pos{"dns_resource.$_"}]
	  unless ($dr->[$res_pos{"dns_resource.$_"}] eq '' ||
		  $dr->[$res_pos{"dns_resource.$_"}] eq '0');
    }
  }

  ## Add DHCP Options
  my %dhcp_pos = %{$SInfo{dhcpOptPos}};
  foreach my $do (@{$SInfo{dhcpOptions}}) {
    my ($name, $format, $number, $value) = 
      ($do->[$dhcp_pos{'dhcp_option_type.name'}],
       $do->[$dhcp_pos{'dhcp_option_type.format'}],
       $do->[$dhcp_pos{'dhcp_option_type.number'}],
       $do->[$dhcp_pos{'dhcp_option.value'}]);

    $svhash{'service'}{$SInfo{'service_name'}}{'dhcp_option'}{$name} = {
      'format' => $format,
      'number' => $number,
      'value' => $value
	};
  }
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

sub die_msg {
  my ($msg) = @_;
  CMU::Netdb::netdb_mail('service-dump.pl', $msg, 'service-dump died');
  die $msg;
}
 
