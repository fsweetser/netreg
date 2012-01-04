#!/usr/local/bin/perl

# mk-rv-zone.pl
# script to create reverse zones in netreg, and populate the NS records, etc.

# Copyright (c) 2004 Carnegie Mellon University. All rights reserved.
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
# $Id: mk-rv-zone.pl,v 1.1 2006/02/16 19:02:10 vitroth Exp $
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use strict;
use Getopt::Long;
use CMU::Netdb;
use Data::Dumper;

use vars qw/$debug $result $type @zones @nameservers $service $dbh @urls $prot/;

$debug = 3;
$type = 'rv-permissible';
# take subnet names on command line
$result = GetOptions("zone=s" => \@zones,
		     "nameserver=s" => \@nameservers,
		     "service=s" => \$service,
		     "type=s" => \$type,
                     "prot-profile=s" => \$prot,
		     "debug=i", => \$debug,
		    );

&usage() if (!$result);

&usage() if (!@zones);

$dbh = CMU::Netdb::lw_db_connect() or die "Unable to connect to database";



foreach my $rvzone (@zones) {

  warn "Creating $rvzone zone.\n";

  my $fields = { 'name' => $rvzone,
		 'type' => $type, 
	       };

if ($type eq 'rv-toplevel') {
$fields->{'soa_host'} = 'netreg.net.cmu.edu';
$fields->{'soa_email'} = 'host-master.andrew.cmu.edu';
$fields->{'soa_refresh'} = 900;
$fields->{'soa_retry'} = 450;
$fields->{'soa_expire'} = 3600000;
$fields->{'soa_minimum'} = 86400;
$fields->{'soa_default'} = 86400;
}
  my ($res, $ref) = CMU::Netdb::add_dns_zone($dbh, 'netreg', $fields);

  if ($res <= 0) {
    warn "*** Error adding reverse zone $rvzone, result $res:\n".Data::Dumper->Dump([$ref],['reason']);
    warn "*** Continuing anyway\n"
  } else {
    my $new_rvzone = $ref->{'insertID'};
    warn "Added reverse zone $new_rvzone\n";

    if ($prot) {
       my ($ARes, $AErrf) = CMU::Netdb::apply_prot_profile($dbh, 'netreg', $prot, 'dns_zone', $new_rvzone, '', {});
    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
        "$Pr failure adding protections entries for ".
          "dns_zone/$new_rvzone}: ".join(',', @$AErrf)."\n";
    }

    }
    foreach my $ns (@nameservers) {
      my $res_fields = { 'type' => 'NS',
			 'owner_type' => 'dns_zone',
			 'owner_tid' => $new_rvzone,
			 'ttl' => 86400,
			 'name' => $rvzone,
			 'rname' => $ns,
		       };

      ($res, $ref) = CMU::Netdb::add_dns_resource($dbh, 'netreg', $res_fields);
      if ($res <= 0) {
	warn "*** Error adding nameserver $ns to $rvzone\n  Error: $res Fields: ". join(',', @$ref);
      }
    }

    if ($service) {
      my $svc_fields = { 'service' => $service,
			 'member_tid' => $new_rvzone,
			 'member_type' => 'dns_zone',
		       };
      ($res, $ref) = CMU::Netdb::add_service_membership($dbh, 'netreg', $svc_fields);
      if ($res <= 0) {
	warn "*** Error adding zone $rvzone to service $service\n  Error: $res Fields: ". join(',', @$ref);
      }
    }
  }
}









sub usage {

  print <<END_USAGE;
Usage: mk-rv-zone.pl --zone <Zone name> [--nameserver ... ]
                     [--service <Service Group ID>]
                         [--debug n]
Argument Details:
      debug: debug level, higher numbers are more verbose
END_USAGE

  exit;

}
