#! /usr/local/bin/perl5
#
# Copyright (c) 2000-2008 Carnegie Mellon University. All rights reserved.
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
# $Id: ldapgroup-create-group-from-netreg.pl,v 1.1 2008/05/15 20:08:12 vitroth Exp $
#

use strict;

use lib "/usr/ng/lib/perl5";

use Getopt::Long;
use CMU::Netdb;
#use Net::LDAP;
use Net::LDAP::Groups;
use Data::Dumper;
$| = 1;

my $debug = 1;
my @GROUPS;
my $subgroup;
my $convert = 0;
my $DBUSER = 'netreg';


my $result = GetOptions("group=s" => \@GROUPS,
			"subgroup=s" => \$subgroup,
			"convert" => \$convert,
		        "debug=i" => \$debug);

usage() if (!$result);

loadGroups(\@GROUPS, $subgroup);

sub loadGroups {
  my ($grRef, $subgroup) = @_;
  my (@groups, $lgr, $dbh, $res, $ref, @addmembers, $gid);
  @groups = @$grRef;
  $dbh = CMU::Netdb::lw_db_connect();
  if (!$dbh) {
    &netdb_mail('ldaploader.pl', 'Error connecting to db.');
    exit -1;
  }  


  foreach my $gr (@groups) {
    my $ldapgroup;

    if ($gr =~ /dept:/) {
      $ldapgroup = "cmu:pgh:ComputingServices:Net:NetReg:$gr";
    } elsif ($gr =~ /^ldap:(.*)$/) {
      $ldapgroup = "cmu:pgh:ComputingServices:Net:NetReg:group:$1";
    } else {
      $ldapgroup = "cmu:pgh:ComputingServices:Net:NetReg:group:$gr";
    }
      
    # does the group exist in netreg?
    $lgr = CMU::Netdb::list_groups($dbh, $DBUSER, "groups.name = '$gr'");
    if (!ref $lgr) {
      netdb_mail($0, "Error calling list_groups; Name: $gr ($lgr)");
      next;
    }

    if (!defined $lgr->[1]) {
      # skip
      next;
    } else {
      my $gmap = CMU::Netdb::makemap($lgr->[0]);
      $gid = $lgr->[1]->[$gmap->{'groups.id'}];
    }

    # get a list of the members
    my $lmgr = CMU::Netdb::list_members_of_group($dbh, $DBUSER, $gid, '');
    if (!ref $lmgr) {
      netdb_mail($0, "Error listing members of group: $gr ($lmgr)");
      next;
    }
    my $memmap = CMU::Netdb::makemap($lmgr->[0]);
    shift(@$lmgr);
    my %members = map { $_->[$memmap->{'credentials.authid'}], 1 } @$lmgr;

    print "Found ".scalar(keys %members)." users in $gr.\n";

    my $groups = Net::LDAP::Groups->new();
    $groups->config(recurse => 1);

    if ($subgroup) {
      # Fetch the members of $subgroup and don't put them in $ldapgroup, instead put the subgroup as a member
      print "Looking up members of '$subgroup'\n";

      my $submembers = $groups->group_all_members_indirect($subgroup, 'cmuAndrewID');
      my $err = $groups->error;
      print Data::Dumper->Dump([$submembers], ['submembers']);
      if ($err ne "OK" && !@$submembers) {
	die "Unable to load members of '$subgroup': $err\n";
      }

      foreach my $u (@$submembers) {
	if (exists($members{"$u\@andrew.cmu.edu"})) {
	  print "Pruning $u from $gr, member of $subgroup.\n";
	  delete $members{"$u\@andrew.cmu.edu"};
	}
      }
    }

    # Does the ldap group already exist?  We'll get an error if it does.

    print "Creating $ldapgroup\n" if ($debug);
    $res = $groups->create($ldapgroup);

    if (!$res) {
      my $err = $groups->error();
      warn "Error creating ldap group $ldapgroup: ".$err;
      next unless ($err =~ /Already exists/);
    }

    $res = $groups->onlymember("cn=$ldapgroup,ou=group,dc=cmu,dc=edu", $ldapgroup);

    my $first = 1;
    my $errcnt = 0;
    foreach my $u (sort keys %members) {
      my $user = $u;
      $user =~ s/\@andrew\.cmu\.edu//;
      print "Adding $user to $ldapgroup\n" if ($debug);
      if ($first) {
	$res = $groups->onlymember("cmuAndrewId==$user",$ldapgroup);
	$first = 0;
      } else {
	$res = $groups->addmember("cmuAndrewId==$user",$ldapgroup);
      }

      if (!$res) {
	warn "Error adding $user to $ldapgroup: $groups->error";
	$errcnt++;
      }
    }

    if ($subgroup) {
      print "Adding $subgroup to $ldapgroup\n" if ($debug);
      if ($first) {
	$res = $groups->onlymember("cn=$subgroup,ou=group,dc=cmu,dc=edu", $ldapgroup);
	$first = 0;
      } else {
	$res = $groups->addmember("cn=$subgroup,ou=group,dc=cmu,dc=edu", $ldapgroup);
      }
      if (!$res) {
	warn "Error adding $subgroup to $ldapgroup: $groups->error";
	$errcnt++;
      }
    }

    if ($first) {
      # No members were added, but our own identity was probably added, so we want to clear that.
    }

    # all done with this group in ldap, should we set the attribute in the database?
    if ($convert) {
      if ($errcnt) {
	print "Errors occured while creating group, NOT converting $gr to ldap ownership.\n"
      } else {
	my $spec = CMU::Netdb::list_attribute_spec_ref($dbh, $DBUSER, "attribute_spec.name = 'LDAP Source Group' AND attribute_spec.scope = 'groups'", 'attribute_spec.name');
	#print Data::Dumper->Dump([$spec], ['spec']);
	if (ref $spec && scalar(keys(%$spec))) {
	  my $specid;
	  foreach (keys %$spec) {
	    $specid = $_ if ($spec->{$_} eq 'LDAP Source Group');
	  }
	  if ($specid) {
	    print "Adding 'LDAP Source Group' attribute (set to $ldapgroup) to $gr.\n";
	    my ($res, $fields) = 	CMU::Netdb::set_attribute($dbh, $DBUSER, {'spec' => $specid,
										  'data' => $ldapgroup,
										  'owner_table' => 'groups',
										  'owner_tid' => $gid});
	    if ($res <= 0) {
	      print "Error setting attribute on $gr: $CMU::Netdb::errmeanings{$res}\n";
	    }
	  } else {
	    print "Error finding attribute spec for 'LDAP Source Group'";
	  }
	} else {
	  print "Error finding attribute spec for 'LDAP Source Group': $spec";
	}
      }
    }
  }
  $dbh->disconnect();
}



sub usage {
print <<END_USAGE;
Usage: 
$0 [--subgroup sub:group:name] [--convert] [--debug N] --group group:name [--group group:name ...]
       group      -  Name of netreg group to create in ldap (i.e. dept:foo)
       subgroup   -  Name of existing group in ldap to add as subgroup of this group.
                     Members of the subgroup will be removed from the new ldap group.
       convert    -  Set the attribute on the netreg group that causes group syncing to
                     start occurring.
       debug      -  Enable debugging output
END_USAGE

exit;
}
