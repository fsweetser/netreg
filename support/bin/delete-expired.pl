#!/usr/bin/perl
#
# Delete all expired machines
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
# $Id: delete-expired.pl,v 1.9 2008/03/27 19:42:41 vitroth Exp $
#
# $Log: delete-expired.pl,v $
# Revision 1.9  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.8.8.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.8  2007/03/29 20:37:46  vitroth
# Use the correct state name when deactivating outlets.
#
# Revision 1.7  2006/10/06 19:55:37  jcarr
# Changing to the 'state' model for port expires
#
# Revision 1.6  2006/08/28 14:56:28  jcarr
# Added more functionality
#
# Revision 1.5  2006/08/22 20:23:24  jcarr
# UserMaint code
#
# Revision 1.4  2002/09/29 20:56:45  kevinm
# * Don't send mail unless machines were deleted.
#
# Revision 1.3  2002/02/19 16:25:18  kevinm
# Changed deletion to happen on the day set in NetReg.
#
# Revision 1.2  2002/01/30 20:53:14  kevinm
# Fixed vars_l
#
# Revision 1.1  2001/12/10 23:16:42  kevinm
# Delete expired machines from the db
#
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

my $debug = 0;
if ($ARGV[0] eq '-debug') {
  print "** Debug mode enabled.\n";
  $debug = 1;
}else{
  sleep 1;
}

delete_expired();
delete_expired_outlets();

exit(0);

sub delete_expired_outlets {
  my $DeleteLog = '';
  my ($NOk, $NErr) = (0,0);
  my $dbh = CMU::Netdb::helper::lw_db_connect() 
    || die "Cannot make connection to database server!";

  # List all machines in the subnet
  my $ruRef = CMU::Netdb::list_outlets($dbh, 'netreg', 
					" outlet.expires <= now() AND outlet.expires != 0");
  if (!ref $ruRef) {
    print "Error in list_outlets: ".$CMU::Netdb::errors::errmeanings{$ruRef}."\n";
    exit(2);
  }

  my %MachMap = %{CMU::Netdb::helper::makemap($ruRef->[0])};
  shift(@$ruRef);

  foreach my $m (@$ruRef) {
    print "Would deact: $m->[$MachMap{'outlet.id'}]/$m->[$MachMap{'outlet.cable'}]/$m->[$MachMap{'outlet.port'}]/".$m->[$MachMap{'outlet.status'}]."\n";
    
    if ($debug == 1) {
      print "Would deact: $m->[$MachMap{'outlet.id'}]/$m->[$MachMap{'outlet.cable'}]/$m->[$MachMap{'outlet.port'}]/".$m->[$MachMap{'outlet.status'}]."\n";
    } else {
      # correct way to expire outlets... 
      my $action = "OUTLET_WAIT_PARTITION";

      if (index($m->[$MachMap{'outlet.flags'}], 'permanent') >= 0) { 
        $action = "OUTLET_PERM_WAIT_PARTITION";
      }

      my ($rex, $ref) = CMU::Netdb::buildings_cables::modify_outlet_state_by_name($dbh, 'netreg', $m->[$MachMap{'outlet.id'}], $m->[$MachMap{'outlet.version'}], $action);
      if ($rex < 1) {
        warn "deactivating outlet $m->[$MachMap{'outlet.id'}], $m->[$MachMap{'outlet.version'}] failed: $rex (".join(',',@$ref).")";
        return 0;
      }
      
      # change the expire time to 0000-00-00 so we don't keep deactivating the outlet
      my $ul = "9";
      
      my $fields = {
        'expires' => '0000-00-00'
      };
      my ($res, $fields) = CMU::Netdb::modify_outlet ($dbh, 'netreg', $m->[$MachMap{'outlet.id'}], $m->[$MachMap{'outlet.version'}], $fields, $ul);
      
      if ($res < 1) {
        $DeleteLog .= "ERROR Deact $m->[$MachMap{'outlet.id'}]/$m->[$MachMap{'outlet.cable'}]/$m->[$MachMap{'outlet.port'}]/".$m->[$MachMap{'outlet.status'}]."\n";
	    $DeleteLog .=  "\t\tErr: ".$CMU::Netdb::errors::errmeanings{$res}." :: ".join(", ", @$fields)."\n";
    	$NErr++;
      } else {
	    $DeleteLog .= "Deact $m->[$MachMap{'outlet.id'}]/$m->[$MachMap{'outlet.cable'}]/$m->[$MachMap{'outlet.port'}]/".$m->[$MachMap{'outlet.status'}]."\n";
	    $NOk++;
      }
    }
  }
  $dbh->disconnect();
  if ($debug != 1 && $DeleteLog ne '') {
    CMU::Netdb::netdb_mail('delete-expired.pl', $DeleteLog, 'Expired Outlet Deactivations');
  }
} 


sub delete_expired {
  my $DeleteLog = '';
  my ($NOk, $NErr) = (0,0);
  my $dbh = CMU::Netdb::helper::lw_db_connect() 
    || die "Cannot make connection to database server!";

  # List all machines in the subnet
  my $ruRef = CMU::Netdb::list_machines($dbh, 'netreg', 
					" machine.expires <= now() AND machine.expires != 0");
  if (!ref $ruRef) {
    print "Error in list_machines: ".$CMU::Netdb::errors::errmeanings{$ruRef}."\n";
    exit(2);
  }

  my %MachMap = %{CMU::Netdb::helper::makemap($ruRef->[0])};
  shift(@$ruRef);

  foreach my $m (@$ruRef) {
    if ($debug == 1) {
      print "Would delete: $m->[$MachMap{'machine.id'}]/$m->[$MachMap{'machine.host_name'}]/$m->[$MachMap{'machine.mac_address'}]/".CMU::Netdb::helper::long2dot($m->[$MachMap{'machine.ip_address'}])."\n";
    }else{
      my ($res, $fields) = CMU::Netdb::delete_machine
	($dbh, 'netreg', 
	 $m->[$MachMap{'machine.id'}], 
	 $m->[$MachMap{'machine.version'}]);
      
      if ($res < 1) {
	# Error
	$DeleteLog .= "ERROR Deleting $m->[$MachMap{'machine.id'}]/$m->[$MachMap{'machine.host_name'}]/$m->[$MachMap{'machine.mac_address'}]/".CMU::Netdb::helper::long2dot($m->[$MachMap{'machine.ip_address'}])."\n";
	$DeleteLog .=  "\t\tErr: ".$CMU::Netdb::errors::errmeanings{$res}." :: ".join(", ", @$fields)."\n";
	$NErr++;
      }else{
	$DeleteLog .= "DELETED $m->[$MachMap{'machine.id'}]/$m->[$MachMap{'machine.host_name'}]/$m->[$MachMap{'machine.mac_address'}]/".CMU::Netdb::helper::long2dot($m->[$MachMap{'machine.ip_address'}])."\n";
	$NOk++;
      }
    }
  }
  $dbh->disconnect();
  if ($debug != 1 && $DeleteLog ne '') {
    CMU::Netdb::netdb_mail('delete-expired.pl', $DeleteLog, 'Expired Machine Deletions');
  }
}

sub usage {
  print "$0 <subnet #> [-yes|-ask]\n\tSubnet number, from netreg\n\t-yes to actually delete\n\t-ask to ask about each one";
  exit(1);
}
