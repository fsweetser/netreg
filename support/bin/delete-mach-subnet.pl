#!/usr/bin/perl
#
# Delete all machines in a subnet
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
# $Id: delete-mach-subnet.pl,v 1.6 2008/03/27 19:42:41 vitroth Exp $
#
# $Log: delete-mach-subnet.pl,v $
# Revision 1.6  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.5.8.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.5  2006/05/16 21:49:41  fk03
# Deleted check on machine name that made no sense.
#
# Revision 1.4  2004/02/20 03:17:52  kevinm
# * External config file updates
#
# Revision 1.3  2002/10/24 15:24:24  kevinm
# * Minor change to usage(); add a newline
#
# Revision 1.2  2002/01/30 20:52:29  kevinm
# Fixed vars_l
#
# Revision 1.1  2001/08/17 15:06:06  kevinm
# New file
#
#

use strict;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}
use vars_l;

use lib $vars_l::NRLIB;
use CMU::Netdb;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::errors;
use CMU::Netdb::auth;

&usage unless (defined $ARGV[0]);

my $yes = 0;
$yes = 1 if (defined $ARGV[1] && $ARGV[1] eq '-yes');
$yes = 2 if (defined $ARGV[1] && $ARGV[1] eq '-ask');

unless($ARGV[0] =~ /\A\d+\Z/) {
  print STDERR "Invalid subnet ID format (should be numeric): $ARGV[0]\n";
  &usage;
}

&delete_from_subnet($ARGV[0], $yes);

sub delete_from_subnet {
  my ($sid, $Delete) = @_;

  my $dbh = CMU::Netdb::helper::lw_db_connect() || die "Cannot make connection to database server!";

  # List all machines in the subnet
  my $ruRef = list_machines($dbh, 'netreg', " machine.ip_address_subnet = '$ARGV[0]'");
  if (!ref $ruRef) {
    print "Error in list_machines: ".$CMU::Netdb::errors::errmeanings{$ruRef}."\n";
    exit(2);
  }

  my %MachMap = %{CMU::Netdb::helper::makemap($ruRef->[0])};
  shift(@$ruRef);

  foreach my $m (@$ruRef) {
    my $ldelete = $Delete;
    if ($ldelete == 2) {
      my $ownq = list_protections($dbh, 'netreg', 'machine', $m->[$MachMap{'machine.id'}], '');
      if (!ref $ownq) {
	print "Unable to get protections for machine/$m->[$MachMap{'machine.id'}]!\n";
	exit(3);
      }
      my @owners = map { if ($_->[0] eq 'user') { $_->[1] } else { () } } @$ownq;

      my $HN = $m->[$MachMap{'machine.host_name'}];


      print "Delete $HN/$m->[$MachMap{'machine.mac_address'}] (own: ".join(', ', @owners).") ?? ";
      my $resp = <STDIN>;
      if ($resp =~ /y/i) {
	$ldelete = 1;
      }
    }

    if ($ldelete == 1) {
      my ($res, $fields) = delete_machine($dbh, 'netreg', 
					  $m->[$MachMap{'machine.id'}], 
					  $m->[$MachMap{'machine.version'}]);
      if ($res < 1) {
	# Error
	print "ERROR Deleting $m->[$MachMap{'machine.id'}]/$m->[$MachMap{'machine.host_name'}]/$m->[$MachMap{'machine.mac_address'}]/".CMU::Netdb::helper::long2dot($m->[$MachMap{'machine.ip_address'}])."\n";
	print "\t\tErr: ".$CMU::Netdb::errors::errmeanings{$res}." :: ".join(", ", @$fields)."\n";
      }else{
	print "DELETED $m->[$MachMap{'machine.id'}]/$m->[$MachMap{'machine.host_name'}]/$m->[$MachMap{'machine.mac_address'}]/".CMU::Netdb::helper::long2dot($m->[$MachMap{'machine.ip_address'}])."\n";
      }
    }
    
    if ($Delete != 1 && $Delete != 2) {
      print "Would delete: $m->[$MachMap{'machine.id'}]/$m->[$MachMap{'machine.host_name'}]/$m->[$MachMap{'machine.mac_address'}]/".CMU::Netdb::helper::long2dot($m->[$MachMap{'machine.ip_address'}])."\n";
    }
  }
  $dbh->disconnect();
}

sub usage {
  print "$0 <subnet #> [-yes|-ask]\n\tSubnet number, from netreg\n\t-yes to actually delete\n\t-ask to ask about each one\n";
  exit(1);
}
