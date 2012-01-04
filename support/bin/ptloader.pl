#! /usr/bin/perl
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
##
## $Id: ptloader.pl,v 1.7 2008/03/27 19:42:43 vitroth Exp $
##
## $Log: ptloader.pl,v $
## Revision 1.7  2008/03/27 19:42:43  vitroth
## Merging changes from duke merge branch to head, with some minor type corrections
## and some minor feature additions (quick jump links on list pages, and better
## handling of partial range allocations in the subnet map)
##
## Revision 1.6.22.1  2007/10/11 20:59:46  vitroth
## Massive merge of all Duke changes with latest CMU changes, and
## conflict resolution therein.   Should be ready to commit to the cvs HEAD.
##
## Revision 1.6.20.1  2007/09/20 18:43:08  kevinm
## Committing all local changes to CVS repository
##
## Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
##
##
## Revision 1.6  2002/01/30 20:43:56  kevinm
## Fixed vars_l
##
## Revision 1.5  2000/09/22 15:11:19  kevinm
## Added a check for the db handle
##
## Revision 1.4  2000/09/20 20:36:16  neplokh
## forgot my in front of some temp variables
##
## Revision 1.3  2000/09/20 20:33:33  neplokh
## added support for pts -> netreg group mapping
## with different group names
##
## Revision 1.2  2000/09/20 19:31:46  vitroth
## Production scripts should use /home/netreg not /home/netreg-dev
##
## Revision 1.1  2000/08/03 15:49:28  kevinm
## Loads PTS groups
##
##
##
##
##

use strict;

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::auth;
use CMU::Netdb::errors;
use CMU::Netdb::helper;

$| = 1;

my @GROUPS = qw/adv:advisors,netreg:advisors/;
my $DBUSER = 'netreg';

loadGroups(\@GROUPS);

sub loadGroups {
  my ($grRef) = @_;
  my (@groups, $lgr, $dbh, $res, $ref, @dbmembers, @addmembers, $gid);
  @groups = @$grRef;
  $dbh = lw_db_connect();
  if (!$dbh) {
    &netdb_mail('ptloader.pl', 'Error connecting to db.');
    exit -1;
  }  
  foreach my $gr (@groups) {
    my ($ptsgr,$netreggr)=split(/,/,$gr);
    # does the group exist in netreg?
    $lgr = list_groups($dbh, $DBUSER, "groups.name = '$netreggr'");
    if (!ref $lgr) {
      netdb_mail($0, "Error calling list_groups; Name: $netreggr ($lgr)");
      next;
    }

    if (!defined $lgr->[1]) {
      # need to add this group
      ($res, $ref) = add_group($dbh, $DBUSER,
			       {'name' => $netreggr,
				'description' => 'none'});
      if ($res < 1) {
	netdb_mail($0, "Error adding group $netreggr: $res [".join(',', @$ref)."]");
	next;
      }
      $gid = $ref->{'insertID'};
    }else{
      $gid = $lgr->[1]->[0];
    }
      
    # group now exists. yay.
    # get a list of the members
    my $lmgr = list_members_of_group($dbh, $DBUSER, $gid, '');
    if (!ref $lmgr) {
      netdb_mail($0, "Error listing members of group: $netreggr ($lmgr)");
      next;
    }
    shift(@$lmgr);
    @dbmembers = map { $_->[1] } @$lmgr;
    
    @addmembers = ();
    # now compare to the PTS group listing
    { 
      my $ptl;
      open(PTS, "/usr/local/bin/pts mem $ptsgr|") || netdb_mail($0, "Unable to run pts mem $ptsgr");
      
      while($ptl = <PTS>) {
	next if ($ptl =~ /libprot/);
	next if ($ptl =~ /Members of/);
	$ptl =~ s/\s//g;
	if (grep /^$ptl$/, @dbmembers) {
	  @dbmembers = grep !/^$ptl$/, @dbmembers;
	  next;
	}
	push(@addmembers, $ptl);
      }
      close(PTS);
    }
    
    # everyone in @dbmembers should be nuked, everyone in @addmembers added
    
    # add users
    {
      my $am;
      foreach $am (@addmembers) {
	($res, $ref) = add_user_to_group($dbh, $DBUSER, $am, $gid);
	if ($res < 1) {
	  netdb_mail($0, "Error adding user $am to group $gid.\n");
	  next;
	}
      }
    }

    # remove users
    {
      my $rm;
      foreach $rm (@dbmembers) {
	($res, $ref) = delete_user_from_group($dbh, $DBUSER, $rm, $gid);
	if ($res < 1) {
	  netdb_mail($0, "Error removing user $rm from group $gid.\n");
	  next;
	}
      }
    }

    # all done with this group
  }
  $dbh->disconnect();
}

    
  

  


