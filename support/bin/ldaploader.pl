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
# $Id: ldaploader.pl,v 1.7 2008/03/27 19:42:42 vitroth Exp $
#

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
use Net::LDAP;

$| = 1;

my $debug = 0;
my @GROUPS = qw/pts,adv:advisors,netreg:advisors pts,ac:csg.repair,netreg:cmg/;
my $DBUSER = 'netreg';

loadGroups(\@GROUPS);

sub loadGroups {
  my ($grRef) = @_;
  my (@groups, $lgr, $dbh, $res, $ref, @addmembers, $gid);
  @groups = @$grRef;
  $dbh = lw_db_connect();
  if (!$dbh) {
    &netdb_mail('ldaploader.pl', 'Error connecting to db.');
    exit -1;
  }  

  $res = CMU::Netdb::list_attribute($dbh, $DBUSER, 'attribute_spec.name = "LDAP Source Group" and attribute_spec.scope = "groups"');

  if (ref $res) {
    my $attrmap = CMU::Netdb::makemap(shift @$res);

    foreach my $attr (@$res) {
      my $gid = $attr->[$attrmap->{'attribute.owner_tid'}];
      my $gres = CMU::Netdb::list_groups($dbh, $DBUSER, "groups.id = $gid");
      my $ldap = $attr->[$attrmap->{'attribute.data'}];
      if (ref $gres) {
	my $gmap = CMU::Netdb::makemap(shift @$gres);
	if (@$gres) {
	  my $name = $gres->[0][$gmap->{'groups.name'}];
	  push @groups, "ldap,$ldap,$name";
	  print "Adding group from database attribute: ldap,$ldap,$name\n" if ($debug);
	}
      }
    }
  }

  $res = CMU::Netdb::list_attribute($dbh, $DBUSER, 'attribute_spec.name = "PTS Source Group" and attribute_spec.scope = "groups"');

  if (ref $res) {
    my $attrmap = CMU::Netdb::makemap(shift @$res);

    foreach my $attr (@$res) {
      my $gid = $attr->[$attrmap->{'attribute.owner_tid'}];
      my $gres = CMU::Netdb::list_groups($dbh, $DBUSER, "groups.id = $gid");
      my $pts = $attr->[$attrmap->{'attribute.data'}];
      if (ref $gres) {
	my $gmap = CMU::Netdb::makemap(shift @$gres);
	if (@$gres) {
	  my $name = $gres->[0][$gmap->{'groups.name'}];
	  push @groups, "pts,$pts,$name";
	  print "Adding group from database attribute: pts,$pts,$name\n" if ($debug);
	}
      }
    }
  }





  foreach my $gr (@groups) {
    my ($gtype,$sourcegroup,$netreggr)=split(/,/,$gr);
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
      my $gmap = CMU::Netdb::makemap($lgr->[0]);
      $gid = $lgr->[1]->[$gmap->{'groups.id'}];
    }
      
    # group now exists. yay.
    # get a list of the members
    my $lmgr = list_members_of_group($dbh, $DBUSER, $gid, '');
    if (!ref $lmgr) {
      netdb_mail($0, "Error listing members of group: $netreggr ($lmgr)");
      next;
    }
    my $memmap = CMU::Netdb::makemap($lmgr->[0]);
    shift(@$lmgr);
    my %dbmembers = map { $_->[$memmap->{'users.id'}], $_->[$memmap->{'credentials.authid'}] } @$lmgr;
    my %delmembers = map { $_->[$memmap->{'users.id'}], $_->[$memmap->{'credentials.authid'}] } @$lmgr;
    my %cred2user = map { $_->[$memmap->{'credentials.authid'}], $_->[$memmap->{'users.id'}] } @$lmgr;

    @addmembers = ();
    # now compare to the LDAP group listing
    if ($gtype eq "pts") { 
      my $server = "netreg-ldap.andrew.cmu.edu";
      my $base = "ou=PTS,dc=andrew,dc=cmu,dc=edu";
      my $filter = "(ptsName=%s)";
      my $ldap = Net::LDAP->new($server);

      if (!$ldap) {
	netdb_mail($0, "Error connecting to ldap server\n");
	next;
      } else {
	my $f = sprintf($filter,$sourcegroup);
	my $mesg = $ldap->search(
				 base => $base,
				 filter => $f,
				 attrs => ["ptsMember"],
				);
	my $entry;
	if ($mesg->code) {
	  netdb_mail($0, "Error search LDAP PTS groups: ".$mesg->error."\n");
	  next;
	} else {
	  foreach $entry ($mesg->all_entries) {
	    foreach my $user ($entry->get_value("ptsMember")) {
	      $user .= '@andrew.cmu.edu' unless ($user =~ /\@/);
	      if (exists $cred2user{$user} && exists $dbmembers{$cred2user{$user}}) {
		delete $delmembers{$cred2user{$user}};
 		print STDERR "Found $user in group '$netreggr' ($sourcegroup)\n" if ($debug >= 1);
	      } else {
		push(@addmembers, $user);
		print STDERR "Would add $user to group '$netreggr' ($sourcegroup)\n" if ($debug >= 1);
	      }
	    }
	  }
	}
      }
    } elsif ($gtype eq "ldap") {
      require Net::LDAP::Groups;
      my $groups = Net::LDAP::Groups->new();
      $groups->config(recurse => 1);

#HARDCODED
      my $users = $groups->group_all_members_indirect($sourcegroup,"cmuAndrewID");

      if (!$users) {
	netdb_mail($0, "Error searching LDAP group: $sourcegroup\n");
	next;
      } else {
	foreach my $user (@$users) {
	  $user .= '@andrew.cmu.edu' unless ($user =~ /\@/);
	  if (exists $cred2user{$user} && exists $dbmembers{$cred2user{$user}}) {
		delete $delmembers{$cred2user{$user}};
		print STDERR "Found $user in group '$netreggr' ($sourcegroup)\n" if ($debug >= 1);
	  } else {
	    push(@addmembers, $user);
		print STDERR "Would add $user to group '$netreggr' ($sourcegroup)\n" if ($debug >= 1);
	  }
	}
      }
    } else {
      netdb_mail($0, "Unknown group type: $gtype");
      next;
    }
    # everyone in @delmembers should be nuked, everyone in @addmembers added

    # remove users
    {
      foreach my $id (keys %delmembers) {
	my $rm = $delmembers{$id};
	if ($debug < 2) {
	  ($res, $ref) = delete_user_from_group($dbh, $DBUSER, $rm, $gid);
		print STDERR "Deleting $rm from group '$netreggr'\n" if ($debug >= 1);
	  if ($res < 1) {
	    netdb_mail($0, "Error removing user $rm from group $gid.\n");
	    next;
	  }
	} else {
		print STDERR "Would remove $rm from group '$netreggr'\n";
	}
      }
    }

    # add users
    {
      my $am;
      foreach $am (@addmembers) {
	if ($debug < 2) {
	  ($res, $ref) = add_user_to_group($dbh, $DBUSER, $am, $gid);
		print STDERR "Adding $am to group '$netreggr'\n" if ($debug >= 1);
	  if ($res < 1) {
	    netdb_mail($0, "Error adding user $am to group $gid.\n");
	    next;
	  }
	} else {
		print STDERR "Would add $am to group '$netreggr'\n";
	}
      }
    }


    # all done with this group
  }
  $dbh->disconnect();
}


