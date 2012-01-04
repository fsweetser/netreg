#! /usr/bin/perl -Tw
#
# Copyright (c) 2003-2004 Carnegie Mellon University. All rights reserved.
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
#
# $Id: primitives.pl,v 1.14 2008/03/27 19:42:36 vitroth Exp $
#
#

use Test::More tests => 221;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

use strict;

use lib '/usr/ng/lib/perl5';
use lib '../../..';

use CMU::Netdb::t::framework;
use CMU::Netdb::primitives;
use CMU::Netdb::config;

## BEGIN TESTING

# Verify that things are in place
reload_db("db-primitives-1");
my $dbh = test_db_connect();
my ($sth, $WarnOK, $t0, $t1, $Ret);

# test can_read_all

is(can_read_all($dbh, 'testuser1', 'machine', 
		'(P.identity = 0 OR (U.id = P.identity)'.
		'OR (M.gid * -1 = P.identity))', 'CHECK_ALL'),
   0, "can_read_all (access:0,where:1,type:CHECK_ALL)");

is(can_read_all($dbh, 'testuser1', 'machine', '(P.identity = 2)', ''),
   0, "can_read_all (access:0,where:1,type:blank)");

# invalid fourth argument
$WarnOK = 0;
$SIG{__WARN__} = sub {
  $WarnOK = 1 if ($_[0] =~ /Must specify valid WHERE/);
};

$Ret = can_read_all($dbh, 'testuser1', 'machine', '', 'CHECK_ALL');
ok ($Ret == 0 && $WarnOK, "can_read_all (access:0,where:0,type:CHECK_ALL)");

# invalid third argument with blank fourth
$WarnOK = 0;

$Ret = can_read_all($dbh, 'testuser1', 'machine', '', '');
ok ($Ret == 0 && $WarnOK, 'can_read_all (access:0,where:0,type:blank)');

$SIG{__WARN__} = '';

# testuser2 doesn't exist
is(can_read_all($dbh, 'testuser2', 'machine', '(P.identity = 2)', ''),
   0, "can_read_all (user:invalid,access:0,where:1,type:blank)");

is(can_read_all($dbh, 'testuser2', 'machine', 
		'(P.identity = 0 OR (U.id = P.identity)'.
		'OR (M.gid * -1 = P.identity))', 'CHECK_ALL'),
   0, "can_read_all (user:invalid,access:0,where:1,type:CHECK_ALL)");

is(can_read_all($dbh, 'netreg', 'machine',
		'(P.identity = 0 OR (U.id = P.identity)'.
		'OR (M.gid * -1 = P.identity))', 'CHECK_ALL'),
   1, "can_read_all (access:1,where:1,type:CHECK_ALL)");

is(can_read_all($dbh, 'netreg', 'machine',
		'(P.identity = 1)', ''),
   0, "can_read_all (access:0,where:1,type:blank)");

is(can_read_all($dbh, 'testuser3', 'machine',
		'(P.identity = 3)', ''),
   1, "can_read_all (access:1,where:1,type:blank)");

is(can_read_all($dbh, 'testuser3', 'machine', 
		'(P.identity = 0 OR (U.id = P.identity)'.
		'OR (M.gid * -1 = P.identity))', 'CHECK_ALL'),
   1, "can_read_all (access:1,where:1,type:CHECK_ALL)");

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = can_read_all($dbh, 'testuser3', 'notable', '(P.identity = 3)', '');
ok($Ret == 0 && $WarnOK, "can_read_all (invalid table)");

$WarnOK = 0;
$Ret = can_read_all($dbh, 'testuser3', undef, '(P.identity = 3)', '');
ok($Ret == 0 && $WarnOK, "can_read_all (undef table)");

$WarnOK = 0;
$Ret = can_read_all($dbh, 'testuser3', '', '(P.identity = 3)', '');
ok($Ret == 0 && $WarnOK, "can_read_all (blank table)");

$WarnOK = 0;
$Ret = can_read_all($dbh, undef, 'machine', '(P.identity = 1)', '');
ok($WarnOK && $Ret == 0, 'can_read_all (undef user)');

$WarnOK = 0;
$Ret = can_read_all($dbh, 'netreg', undef, '(P.identity = 1)', '');
ok($WarnOK && $Ret == 0, 'can_read_all (undef table)');

$SIG{__WARN__} = '';

is(can_read_all($dbh, "foo'bar", 'machine', '(P.identity = 1)', ''),
   0, 'can_read_all (malformed user)');

# test prune_restricted_fields
# Assumes db-primitives-1; uses protections from there to check access

# Some tests that should pass
my ($T1, $E1, $F1);

$T1 = [['2', 'cannot see 2'],
       ['4', 'can see 4'],
       ['5', 'can see 5'],
       ['6', 'cannot see 6'],
      ];
$F1 = ['machine.id', 'machine.comment_lvl9'];
$E1 = [['2', undef],
       ['4', 'can see 4'],
       ['5', 'can see 5'],
       ['6', undef]
      ];

CMU::Netdb::primitives::prune_restricted_fields($dbh, 'testuser3', $T1, $F1);
is_deeply($T1, $E1, "prune_restricted_fields (testuser3)");

$T1 = [['2', 'can see 2'],
       ['4', 'can see 4'],
       ['5', 'can see 5'],
       ['6', 'can see 6'],
      ];
$E1 = [['2', 'can see 2'],
       ['4', 'can see 4'],
       ['5', 'can see 5'],
       ['6', 'can see 6']
      ];
CMU::Netdb::primitives::prune_restricted_fields($dbh, 'netreg', $T1, $F1);
is_deeply($T1, $E1, "prune_restricted_fields (netreg)");

## Test failed arguments
$F1 = ['machine.notid', 'machine.comment_lvl9'];
$T1 = [['2', 'cannot see 2']];

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1 
			 if ($_[0] =~ /No ID column found.+Unable to prune/);};
CMU::Netdb::primitives::prune_restricted_fields($dbh, 'netreg', $T1, $F1);
ok($WarnOK, "prune_restricted_fields (no ID column)");

$SIG{__WARN__} = '';

# test list

# tablefields fail
is(CMU::Netdb::primitives::list($dbh, 'netreg', 'machine', 'foobar', ''),
   $CMU::Netdb::errors::errcodes{'EINVREF'}, 'list (tablefields err/string)');

is(CMU::Netdb::primitives::list($dbh, 'netreg', 'machine', {'f' => 'b'}, ''),
   $CMU::Netdb::errors::errcodes{'EINVREF'}, 'list (tablefields err/ref)');

is(CMU::Netdb::primitives::list($dbh, 'netreg', 'machine', undef, ''),
   $CMU::Netdb::errors::errcodes{'EINVREF'}, 'list (tablefields err/undef)');

## Invalid SQL

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /list error.*query\:/s);};
$Ret = CMU::Netdb::primitives::list($dbh, 'netreg', 'machine', ['machine.id'],
				    'invalid_sql');
ok($Ret eq $CMU::Netdb::errors::errcodes{'EDB'} && $WarnOK,
   'list (query string error)');

$SIG{__WARN__} = '';

# empty where clause
$Ret = CMU::Netdb::primitives::list($dbh, 'netreg', 'network', ['network.id'],
				    '');
is_deeply($Ret, [], 'list (empty where clause)');

# Test multi-table joins
$Ret = CMU::Netdb::primitives::list($dbh, 'netreg', 'machine, subnet',
				    ['machine.id', 'subnet.name'],
				    'machine.id = 5 and '.
				    'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0]->[1] eq 'Administration Network',
   'list (multi-table join)');

# different table specification
$Ret = CMU::Netdb::primitives::list($dbh, 'netreg', 'machine ,subnet',
				    ['machine.id', 'subnet.name'],
				    'machine.id = 5 and '.
				    'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0]->[1] eq 'Administration Network',
   'list (multi-table join / tablename space)');

# Invalid table
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::list($dbh, 'testuser1', 'notable',
				    ['machine.id'], 'machine.id = 5');
ok($Ret eq $CMU::Netdb::errors::errcodes{'EINVCHAR'} && $WarnOK, 
   'list (invalid table)');

$SIG{__WARN__} = '';

# join / left join clauses
is_deeply(CMU::Netdb::primitives::list
	  ($dbh, 'netreg', 'cable LEFT JOIN outlet ON cable.id = outlet.cable',
	   ['cable.id'], 'cable.id = 1'),
	  [[]], 'list (left join table)');

# there was a bug accepting lower case "ON"
is_deeply(CMU::Netdb::primitives::list
	  ($dbh, 'netreg', 'dns_resource lEfT JoIn machine on '.
	   'dns_resource.rname_tid = machine.id', ['dns_resource.id'],
	   'machine.id = 1000'),
	  [[]], 'list (left join table, lowercase "on")');

# and a case where we needed to use AND, and quoted data
is_deeply(CMU::Netdb::primitives::list
          ($dbh, 'netreg', 'dns_resource lEfT JoIn machine on '.
           'dns_resource.rname_tid = machine.id AND dns_resource.type = "TXT"',
	   ['dns_resource.id'],
           'machine.id = 1000'),
          [[]], 'list (left join table, JOIN .. AND x = "foo")');

# Double left join with multiple match clauses
is_deeply(CMU::Netdb::primitives::list
          ($dbh, 'netreg', 'dns_resource lEfT JoIn machine on '.
           'dns_resource.rname_tid = machine.id AND '.
	   'dns_resource.type = "TXT REC"'.
	   ' LEFT JOIN subnet ON machine.ip_address_subnet = subnet.id ',
	   ['dns_resource.id'],
           'machine.id = 1000'),
          [[]], 'list (left join table, JOIN .. AND x = "foo" JOIN .. )');

# quoted data
is_deeply(CMU::Netdb::primitives::list
          ($dbh, 'netreg', 'dns_resource lEfT JoIn machine on '.
           'dns_resource.rname_tid = "1" ',
	   ['dns_resource.id'],
           'machine.id = 1000'),
          [[]], 'list (left join table, JOIN x = "foo")');

# multiple left joins
is_deeply(CMU::Netdb::primitives::list
	  ($dbh, 'netreg', 'outlet LEFT JOIN cable ON outlet.cable = cable.id'.
	   ' LEFT JOIN building ON cable.to_building = building.building',
	   ['cable.id'], 'cable.id = 1'),
	  [[]], 'list (double left join table)');

# multiple left joins with commas
is_deeply(CMU::Netdb::primitives::list
	  ($dbh, 'netreg', 
	   'outlet, cable LEFT JOIN trunkset_machine_presence '.
	   'ON outlet.device = trunkset_machine_presence.id LEFT JOIN machine'.
	   ' ON machine.id = trunkset_machine_presence.device, memberships',
	   ['cable.id'], 'cable.id = 1'),
	  [[]], 'list (double left join w/comma table)');

is_deeply(CMU::Netdb::primitives::list
	  ($dbh, 'netreg', 'cable JOIN outlet ON cable.id = outlet.cable',
	   ['cable.id'], 'cable.id = 1'), [[]], 'list (join table)');
	
# test:
#  X invalid table specification
#  X invalid column specification
#  X JOIN (not LEFT JOIN)

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'notable JOIN outlet ON cable.id = outlet.cable',
   ['cable.id'], 'cable.id = 1');
ok($WarnOK && $Ret eq $CMU::Netdb::errors::errcodes{'EINVCHAR'}, 
   'list (join invalid left table)');

$WarnOK = 0;

$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'cable JOIN notable ON cable.id = outlet.cable',
   ['cable.id'], 'cable.id = 1');
ok($WarnOK && $Ret eq $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'list (join invalid right table)');

$WarnOK = 0;

$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'cable JOIN outlet ON cable.nothing = outlet.cable',
   ['cable.id'], 'cable.id = 1');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'list (join invalid left col)');

$WarnOK = 0;

$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'cable JOIN outlet ON cable.id = outlet.nothing',
   ['cable.id'], 'cable.id = 1');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'list (join invalid right col)');

$WarnOK = 0;

$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'cable JOIN outlet ON notable.id = outlet.cable',
   ['cable.id'], 'cable.id = 1');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'list (join invalid left ON table)');

$WarnOK = 0;

$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'cable JOIN outlet ON cable.id = notable.cable',
   ['cable.id'], 'cable.id = 1');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'list (join invalid right ON table)');

$WarnOK = 0;

$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'cable JOIN outlet',
   ['cable.id'], 'cable.id = 1');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'list (join invalid format)');

$WarnOK = 0;
# badly quoted data
$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', 'dns_resource lEfT JoIn machine on '.
   'dns_resource.rname_tid = "1 2"3 "',
   ['dns_resource.id'],
   'machine.id = 1000');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'list (join invalid quoted data)');

$WarnOK = 0;
$Ret = CMU::Netdb::primitives::list
  ($dbh, 'netreg', undef, ['cable.id'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EBLANK'},
   'list (undef table)');

$SIG{__WARN__} = '';

# exercise different code path (user without full access)
$Ret = CMU::Netdb::primitives::list($dbh, 'testuser1', 'machine ,subnet',
				    ['machine.id', 'subnet.name'],
				    'machine.id = 5 and '.
				    'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0]->[1] eq 'Administration Network',
   'list (multi-table join 3)');

$Ret = CMU::Netdb::primitives::list($dbh, 'testuser1', 'machine, subnet',
				    ['machine.id', 'subnet.name'],
				    'machine.id = 5 and '.
				    'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0]->[1] eq 'Administration Network',
   'list (multi-table join 4)');

# no output
is_deeply(CMU::Netdb::primitives::list($dbh, 'netreg', 'machine',
				       ['machine.id'], 'machine.id = 9999999'),
	  [], 'list (nonexistent record)');


## Load db-primitives-2 to do list checking

reload_db('db-primitives-2.gz');
$WarnOK = 0;
for my $i (1..3) {
  # See if the protection table's indices are okay

  $t0 = [gettimeofday];
  my $L = CMU::Netdb::auth::get_read_level($dbh, 'testuser3',
					   'machine', '279');
  $t1 = [gettimeofday];
  my $runTime = tv_interval($t0, $t1);

  print "get_read_level: $runTime sec\n";
  # If it takes more than 0.5 sec, we're going to be under water.
  # Analyze and try again.
  if ($runTime < 0.01) {
    $WarnOK = 1;
    last;
  }
  optimize_db($dbh);
}

unless ($WarnOK) {
  die "get_read_level is taking longer than 0.5sec to complete; database \n".
    "is not usable";
}

# DB Primitives 2 Layout
# User #2 - testuser1 - member of group "Test 1" (id 10)
# User #3 - testuser2 - member of group "Test 1" (id 10)
# User #4 - testuser3 - member of group "Test 2" (id 11)
# User $5 - testuser4 - member of group "Test 3" (id 12)

# 10k machines regd to testuser3, dept:test1, subnet 233, 
#     FOO-$id.FOO.EXAMPLE.ORG
# 10k machines regd to testuser4, dept:test1, subnet 234,
#     BAR-$id.BAR.EXAMPLE.ORG
# 10k machines regd to dept:test2, subnet 235, BAZ-$i.BAZ.EXAMPLE.ORG
#     w/ system:anyuser R/W 1

## If this is changed, make sure the indexes in the tests are updated
my @MachFields = qw/machine.id machine.host_name machine.comment_lvl1
		    machine.comment_lvl5 machine.comment_lvl9/;

# Verify that we have 1...10000 of the machines
my %Counters = map { ($_, 1) } (1...10000);

# Die after 60 seconds for the next 4 tests
$SIG{ALRM} = sub { die "Timeout waiting for db query; the protections table ".
		     "indices are likely bad.";
		 };
alarm(60);

# Should have access as group member to each
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::list($dbh, 'testuser1', 'machine',
				    \@MachFields,
				    "machine.ip_address_subnet = 233");
$t1 = [gettimeofday];

if (ref $Ret) {
  if (scalar(@$Ret) != 10000) {
    fail("list (10k machines, group access) returned ".scalar(@$Ret)." rows");
  }else{
    # Verify the comment_lvl9 is mapped out, and that each machine is
    # represented
    my $Pass = 1;
    my %LCounter = %Counters;
    foreach my $row (@$Ret) {
      $Pass = 0 if (defined $row->[4]);
      $row->[1] =~ /FOO-(\d+).FOO/;
      delete $LCounter{$1};
    }
    unless ($Pass) {
      fail("list (10k machines, group access) comment_lvl9 not cleared");
    }else{
      my @LCK = keys %LCounter;
      unless (scalar(@LCK) == 0) {
	fail("list (10k machines, group access) output incomplete, missed ".
	     scalar(@LCK));
      }else{
	my $tdiff = tv_interval($t0, $t1);
	pass("list (10k machines, group access, dT=$tdiff sec)");
      }
    }
  }
}else{
  fail("list (10k machines, group access)");
}

# Should have access as owner to each
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::list($dbh, 'testuser4', 'machine',
				    \@MachFields,
				    "machine.ip_address_subnet = 234");
$t1 = [gettimeofday];

if (ref $Ret) {
  if (scalar(@$Ret) != 10000) {
    fail("list (10k machines, user access) returned ".scalar(@$Ret)." rows");
  }else{
    # Verify the comment_lvl9 and comment_lvl5 is mapped out
    my $Pass = 1;
    my %LCounter = %Counters;
    foreach my $row (@$Ret) {
      $Pass = 0 if (defined $row->[4] or defined $row->[3]);
      $row->[1] =~ /BAR-(\d+).BAR/;
      delete $LCounter{$1};
    }
    unless ($Pass) {
      fail("list (10k machines, user access) comment_lvl9/5 not cleared");
    }else{
      my @LCK = keys %LCounter;
      unless (scalar(@LCK) == 0) {
	fail("list (10k machines, user access) output incomplete, missed ".
	     scalar(@LCK));
      }else{
	my $tdiff = tv_interval($t0, $t1);
	pass("list (10k machines, user access, dT=$tdiff sec)");
      }
    }
  }
}else{
  fail("list (10k machines, user access)");
}

# system:anyuser on each record
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::list($dbh, 'testuser4', 'machine',
				    \@MachFields,
				    "machine.ip_address_subnet = 235");
$t1 = [gettimeofday];

if (ref $Ret) {
  if (scalar(@$Ret) != 10000) {
    fail("list (10k machines, group access) returned ".scalar(@$Ret)." rows");
  }else{
    # Verify the comment_lvl9 and comment_lvl5 is mapped out
    my $Pass = 1;
    my %LCounter = %Counters;
    foreach my $row (@$Ret) {
      $Pass = 0 if (defined $row->[4] or defined $row->[3]);
      $row->[1] =~ /BAZ-(\d+).BAZ/;
      delete $LCounter{$1};
    }
   unless ($Pass) {
      fail("list (10k machines, anyuser access) comments cleared");
    }else{
      my @LCK = keys %LCounter;
      unless (scalar(@LCK) == 0) {
	fail("list (10k machines, anyuser access) output incomplete, missed ".
	     scalar(@LCK));
      }else{
	my $tdiff = tv_interval($t0, $t1);
	pass("list (10k machines, anyuser access, dT=$tdiff sec)");
      }
    }
  }
}else{
  fail("list (10k machines, anyuser access)");
}

# Should have global table access
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::list($dbh, 'netreg', 'machine',
				    \@MachFields,
				    "machine.ip_address_subnet = 234");
$t1 = [gettimeofday];

if (ref $Ret) {
  if (scalar(@$Ret) != 10000) {
    fail("list (10k machines, netreg access) returned ".scalar(@$Ret)." rows");
  }else{
    # Verify the comments are NOT mapped out
    my $Pass = 1;
    my %LCounter = %Counters;
    foreach my $row (@$Ret) {
      $Pass = 0 unless (defined $row->[4] and defined $row->[3] and
			defined $row->[2]);
      $row->[1] =~ /BAR-(\d+).BAR/;
      delete $LCounter{$1};
    }
    unless ($Pass) {
      fail("list (10k machines, netreg access) comments cleared");
    }else{
      my @LCK = keys %LCounter;
      unless (scalar(@LCK) == 0) {
	fail("list (10k machines, netreg access) output incomplete, missed ".
	     scalar(@LCK));
      }else{
	my $tdiff = tv_interval($t0, $t1);
	pass("list (10k machines, netreg access, dT=$tdiff sec)");
      }
    }
  }
}else{
  fail("list (10k machines, netreg access)");
}

alarm(0);
$SIG{ALRM} = '';

# user is suspended
$WarnOK = 0;
$SIG{__WARN__} = sub { 
  $WarnOK = 1
    if ($_[0] =~ /Validation of credentials.authid_perm.*failed/s);
};
$Ret = CMU::Netdb::primitives::list($dbh, 'testuser5', 'machine',
				    \@MachFields,
				    'machine.ip_address_subnet = 234');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EUSERSUSPEND'},
   'list (suspended user)');
$SIG{__WARN__} = '';

# test count
# test 
$WarnOK = 0;
$SIG{__WARN__} = sub { 
  $WarnOK = 1
    if ($_[0] =~ /Validation of credentials.authid_perm.*failed/s);
};
$Ret = CMU::Netdb::primitives::count($dbh, 'testuser5', 'machine',
				     'machine.id = 5');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EUSERSUSPEND'},
   'count (suspended user)');
$SIG{__WARN__} = '';

# Test multi-table joins
$Ret = CMU::Netdb::primitives::count($dbh, 'netreg', 'machine, subnet',
				     'machine.id = 5 and '.
				     'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0] == 1, 'count (multi-table join)');

$Ret = CMU::Netdb::primitives::count($dbh, 'netreg', 'machine ,subnet',
				     'machine.id = 5 and '.
				     'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0] == 1, 'count (multi-table join 2)');

# Doesn't have full access to the table; exercise alternate path
$Ret = CMU::Netdb::primitives::count($dbh, 'testuser1', 'machine, subnet',
				     'machine.ip_address_subnet = 233 and '.
				     'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0] == 10000, 'count (multi-table join 3)');

$Ret = CMU::Netdb::primitives::count($dbh, 'testuser1', 'machine ,subnet',
				     'machine.ip_address_subnet = 233 and '.
				     'machine.ip_address_subnet = subnet.id');
ok(ref $Ret eq 'ARRAY' && $Ret->[0] == 10000, 'count (multi-table join 4)');

# No results
$Ret = CMU::Netdb::primitives::count($dbh, 'netreg', 'machine',
				     'machine.id = 9999999');
ok(ref $Ret eq 'ARRAY' && $Ret->[0] == 0, 'count (no results)');

# Invalid table
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::count($dbh, 'netreg', 'notable',
				     'table.id = 100');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'count (invalid table)');

$WarnOK = 0;
$Ret = CMU::Netdb::primitives::count($dbh, 'netreg', undef,
				     'table.id = 100');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EBLANK'},
   'count (table undef)');

$SIG{__WARN__} = '';

## Invalid SQL

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /count error\:/s);};
$Ret = CMU::Netdb::primitives::count($dbh, 'netreg', 'machine',
				    'invalid_sql');
ok($Ret eq $CMU::Netdb::errors::errcodes{'EDB'} && $WarnOK,
   'count (query string error)');

$SIG{__WARN__} = '';

# Should have access as group member to each
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::count($dbh, 'testuser1', 'machine',
				     "machine.ip_address_subnet = 233");
$t1 = [gettimeofday];

unless (ref $Ret eq 'ARRAY') {
  fail("count (10k machines, group access) returned: $Ret");
}else{
  if ($Ret->[0] != 10000) {
    fail("count (10k machines, group access) invalid: ".$Ret->[0]);
  }else{
    my $tdiff = tv_interval($t0, $t1);
    pass("count (10k machines, group access, dT=$tdiff sec)");
  }
}

# Should have access as owner to each
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::count($dbh, 'testuser4', 'machine',
				     "machine.ip_address_subnet = 234");
$t1 = [gettimeofday];
unless (ref $Ret eq 'ARRAY') {
  fail("count (10k machines, user access) returned: $Ret");
}else{
  if ($Ret->[0] != 10000) {
    fail("count (10k machines, user access) invalid: ".$Ret->[0]);
  }else{
    my $tdiff = tv_interval($t0, $t1);
    pass("count (10k machines, user access, dT=$tdiff sec)");
  }
}

# system:anyuser on each record
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::count($dbh, 'testuser4', 'machine',
				     "machine.ip_address_subnet = 235");
$t1 = [gettimeofday];
unless (ref $Ret eq 'ARRAY') {
  fail("count (10k machines, anyuser access) returned: $Ret");
}else{
  if ($Ret->[0] != 10000) {
    fail("count (10k machines, anyuser access) invalid: ".$Ret->[0]);
  }else{
    my $tdiff = tv_interval($t0, $t1);
    pass("count (10k machines, anyuser access, dT=$tdiff sec)");
  }
}

# Should have global table access
$t0 = [gettimeofday];
$Ret = CMU::Netdb::primitives::count($dbh, 'netreg', 'machine',
				     "machine.ip_address_subnet = 234");
$t1 = [gettimeofday];
unless (ref $Ret eq 'ARRAY') {
  fail("count (10k machines, netreg access) returned: $Ret");
}else{
  if ($Ret->[0] != 10000) {
    fail("count (10k machines, netreg access) invalid: ".$Ret->[0]);
  }else{
    my $tdiff = tv_interval($t0, $t1);
    pass("count (10k machines, netreg access, dT=$tdiff sec)");
  }
}

# test get
# test:
#  X invalid user specification
#  X suspended user
#  X invalid table specification (notable, ref)
#  X table fields not a ref
#  X table fields a non-array ref
#  X invalid sql in where clause
#  X normal
#    X no results
#    X results
#    X table with join spec
#    X empty where clause
#    X undef where clause
#    X user doesn't exist

# invalid user specification
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::get($dbh, {'f' => 'b'}, 'subnet',
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'get (invalid user: ref)');

$Ret = CMU::Netdb::primitives::get($dbh, undef, 'subnet',
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'get (invalid user: undef)');

# user is suspended
$WarnOK = 0;
$Ret = CMU::Netdb::primitives::get($dbh, 'testuser5', 'subnet',
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EUSERSUSPEND'},
   'get (invalid user: suspended)');

# invalid table specification
$WarnOK = 0;
$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', {'f' => 'b'},
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'get (invalid table: ref)');

$WarnOK = 0;
$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', '',
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EBLANK'},
   'get (invalid table: empty table)');

$WarnOK = 0;

$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', undef,
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EBLANK'},
   'get (invalid table: undef)');

$SIG{__WARN__} = sub { $WarnOK = 1
			  if ($_[0] =~ /Validation.*failed/s)};
$WarnOK = 0;
$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', 'notable',
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'get (invalid table: notable)');

$WarnOK = 0;
$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', 'subnet, notable',
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'get (invalid table: real table with notable)');

$WarnOK = 0;
$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1',
				   'subnet JOIN notable ON s.id = n.id',
				   ['subnet.id', 'subnet.name'], '');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'get (invalid table: real table JOIN notable)');

$SIG{__WARN__} = '';

# invalid field specifications
$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', 'subnet',
				   {'f' => 'b'}, '');
is($Ret, $CMU::Netdb::errors::errcodes{'EINVREF'},
   'get (invalid fieldlist: hash ref)');

$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', 'subnet',
				   'subnet.id', '');
is($Ret, $CMU::Netdb::errors::errcodes{'EINVREF'},
   'get (invalid fieldlist: scalar');

# bad SQL
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1 if ($_[0] =~ /execute failed/); };

$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', 'subnet',
				   ['subnet.id'], 'badsql');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EDB'},
   'get (invalid where: badsql)');

$SIG{__WARN__} = '';

# Normal queries
$Ret = CMU::Netdb::primitives::get($dbh, 'netreg', 'subnet',
				   ['subnet.id'], '');
is(scalar(@$Ret), 5, 'get (normal/netreg/subnet)');

$Ret = CMU::Netdb::primitives::get($dbh, 'testuser1', 'machine',
				   ['machine.id'], '');
is(scalar(@$Ret), 0, 'get (normal/testuser1/machine)');

$Ret = CMU::Netdb::primitives::get($dbh, 'netreg',
				   'subnet JOIN machine ON '.
				   'subnet.id = machine.ip_address_subnet',
				   ['subnet.id'], '');
is(scalar(@$Ret), 4, 'get (normal/netreg/subnet JOIN machine)');

$Ret = CMU::Netdb::primitives::get($dbh, 'netreg', 'subnet',
				   ['subnet.id'], undef);
is(scalar(@$Ret), 5, 'get (normal/netreg/subnet - undef where)');

$Ret = CMU::Netdb::primitives::get($dbh, 'nouser', 'subnet',
				   ['subnet.id'], '');
is(scalar(@$Ret), 0, 'get (normal/nouser/subnet)');

$Ret = CMU::Netdb::primitives::get($dbh, 'netreg', 'subnet',
				   ['subnet.id'], 'subnet.id = 188');
is(scalar(@$Ret), 1, 'get (normal/netreg/subnet)');


my ($Info, $Q, $ID);

# test add
# test:
#  X user is suspended
#  X as netreg
#  X user is authorized/not authorized
#  X with id/version on fields list
#  X EXPR
#  X quoting of single quotes
#  X verify changelog recording
#  X check db_insertid
#  X multiple tables specified
#  X fields with different table names
#  X bad db query with EXPR test

# basic test, user is authorized
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser4', 'network',
   {'network.id' => 0,
    'network.version' => '20040101010101',
    'network.name' => 'NetTest 1',
    'network.subnet' => '233',
   });
is($Ret, 1, 'add (basic test)');
$ID = $CMU::Netdb::primitives::db_insertid;
ok($ID != 0, 'add (basic test non 0 id)');

$Q = "SELECT name FROM network WHERE id = '$ID'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (basic test query prepare)');
}else{
  unless($sth->execute()) {
    fail("add (basic test query execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] ne 'NetTest 1') {
      fail("add (basic test query failed)");
    }else{
      pass("add (basic test query)");
    }
  }
}

# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'network' AND row = '$ID' AND type = 'INSERT' AND
      previous IS NULL AND
      ((crc.name = 'network.name' AND crc.data = 'NetTest 1') OR
       (crc.name = 'network.subnet' AND crc.data = '233'))";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (basic test changelog verification prepare)');
}else{
  unless($sth->execute()) {
    fail("add (basic test changelog verification execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 2) {
      fail("add (basic test changelog verification query)");
    }else{
      pass("add (basic test changelog verification query)");
    }
  }
}

# as netreg
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'netreg', 'network',
   {'network.name' => 'NetTest 2',
    'network.subnet' => '234'
   });
is($Ret, 1, 'add (netreg user)');
$ID = $CMU::Netdb::primitives::db_insertid;
ok($ID != 0, 'add (netreg test non 0 id)');
$Q = "SELECT name FROM network WHERE id = '$ID'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (netreg test query prepare)');
}else{
  unless($sth->execute()) {
    fail("add (netreg test query execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] ne 'NetTest 2') {
      fail("add (netreg test query failed)");
    }else{
      pass("add (netreg test query)");
    }
  }
}

# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'network' AND row = '$ID' AND type = 'INSERT' AND
      previous IS NULL AND
      ((crc.name = 'network.name' AND crc.data = 'NetTest 2') OR
       (crc.name = 'network.subnet' AND crc.data = '234'))";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (netreg test changelog verification prepare)');
}else{
  unless($sth->execute()) {
    fail("add (netreg test changelog verification execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 2) {
      fail("add (netreg test changelog verification query)");
    }else{
      pass("add (netreg test changelog verification query)");
    }
  }
}

# user is suspended
$WarnOK = 0;
$SIG{__WARN__} = sub { 
  $WarnOK = 1
    if ($_[0] =~ /Validation of credentials.authid_perm.*failed/s);
};
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser5', 'network',
   {'network.id' => 1,
    'network.version' => 20040101010101,
    'network.name' => 'NetTest 3',
    'network.subnet' => '234'
   });
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EUSERSUSPEND'},
   'add (suspended user)');
$SIG{__WARN__} = '';

# user doesn't have access
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser1', 'network',
   {'network.name' => 'NetTest 4',
    'network.subnet' => '234'
    });
is($Ret, $CMU::Netdb::errors::errcodes{'EPERM'}, 'add (unauthorized user)');

# EXPR
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser4', 'network',
   {'network.name' => '*EXPR: concat("NetTest 5 ", now())',
    'network.subnet' => '234'
   });
is($Ret, 1, 'add (expr)');
$ID = $CMU::Netdb::primitives::db_insertid;
ok($ID != 0, 'add (expr)');

$Q = "SELECT name FROM network WHERE id = '$ID'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (expr)');
}else{
  unless($sth->execute()) {
    fail('add (expr)');
  }else{
    my @rd = $sth->fetchrow_array();
    unless ($rd[0] =~ /NetTest 5 \d+\-\d+\-\d+ \d+\:\d+\:\d+/) {
      fail('add (expr)');
    }else{
      pass("add (expr)");
    }
  }
}

# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'network' AND row = '$ID' AND type = 'INSERT' AND
      previous IS NULL AND
      ((crc.name = 'network.name' AND 
        crc.data = 'concat(\"NetTest 5 \", now())') OR
       (crc.name = 'network.subnet' AND crc.data = '234'))";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (expr changelog verification prepare)');
}else{
  unless($sth->execute()) {
    fail("add (expr changelog verification execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 2) {
      fail("add (expr changelog verification query)");
    }else{
      pass("add (expr changelog verification query)");
    }
  }
}

# EXPR with bad data
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1 if ($_[0] =~ /primitives::add error/s); };

($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser4', 'network',
   {'network.name' => '*EXPR: badsql AND morebadsql',
    'network.subnet' => '234'
   });
ok($WarnOK = 1 && $Ret == $CMU::Netdb::errors::errcodes{'EDB'}, 
   'add (invalid EXPR)');
$SIG{__WARN__} = '';

# quoting single quotes
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser4', 'network',
   {'network.name' => "NetTest '6'",
    'network.subnet' => '234'
   });
is($Ret, 1, 'add (quotes)');
$ID = $CMU::Netdb::primitives::db_insertid;
ok($ID != 0, 'add (quotes)');

$Q = "SELECT name FROM network WHERE id = '$ID'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (quotes)');
}else{
  unless($sth->execute()) {
    fail('add (quotes)');
  }else{
    my @rd = $sth->fetchrow_array();
    unless ($rd[0] eq "NetTest '6'") {
      fail('add (quotes)');
    }else{
      pass("add (quotes)");
    }
  }
}

# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'network' AND row = '$ID' AND type = 'INSERT' AND
      previous IS NULL AND
      ((crc.name = 'network.name' AND crc.data = 'NetTest \\'6\\'') OR
       (crc.name = 'network.subnet' AND crc.data = '234'))";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (quotes changelog verification prepare)');
}else{
  unless($sth->execute()) {
    fail("add (quotes changelog verification execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 2) {
      fail("add (quotes changelog verification query)");
    }else{
      pass("add (quotes changelog verification query)");
    }
  }
}

# multiple tables
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser4', 'network, subnet',
   {'network.name' => 'NetTest 7',
    'network.subnet' => '233',
   });
is($Ret, 1, 'add (mtable test)');
$ID = $CMU::Netdb::primitives::db_insertid;
ok($ID != 0, 'add (mtable test non 0 id)');
$Q = "SELECT name FROM network WHERE id = '$ID'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (mtable test query prepare)');
}else{
  unless($sth->execute()) {
    fail("add (mtable test query execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] ne 'NetTest 7') {
      fail("add (mtable test query failed)");
    }else{
      pass("add (mtable test query)");
    }
  }
}

# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'network' AND row = '$ID' AND type = 'INSERT' AND
      previous IS NULL AND
      ((crc.name = 'network.name' AND crc.data = 'NetTest 7') OR
       (crc.name = 'network.subnet' AND crc.data = '233'))";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('add (mtable test changelog verification prepare)');
}else{
  unless($sth->execute()) {
    fail("add (mtable test changelog verification execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 2) {
      fail("add (mtable test changelog verification query)");
    }else{
      pass("add (mtable test changelog verification query)");
    }
  }
}

# fields with different table names
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser4', 'network',
   {'network.name' => 'NetTest 8',
    'network.subnet' => '233',
    'subnet.id' => 0,
   });
is($Ret, $CMU::Netdb::errors::errcodes{'EINVFIELD'}, 'add (mfields test)');

# invalid table name
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
($Ret, $Info) = CMU::Netdb::primitives::add
  ($dbh, 'testuser4', 'notable',
   {'network.name' => 'NetTest 9',
    'network.subnet' => '233'
   });
ok($WarnOK = 1 && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'add (invalid table)');
$SIG{__WARN__} = '';


# test modify
# test:
#  X invalid user specification
#  X suspended user
#  X invalid table name specification
#  X invalid id specification
#  X invalid version specification
#  X version mismatch
#    X verify changelog was not recorded
#  X not authorized
#  X fields list:
#    X normal
#    X with id/version columns
#    X with EXPRs
#  X verify changelog
#  X bad DB query (via bad EXPR field)
#    X verify changelog

# invalid user spec
$WarnOK = 0;
$SIG{__WARN__} = sub {
  $WarnOK = 1
    if ($_[0] =~ /Validation of credentials.authid_perm.*failed/s);
};
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, {'foo' => 'bar'}, 'network', '1', '1',
   {'network.id' => 1,
    'network.version' => 20040101010101,
    'network.name' => 'NetMod 1',
    'network.subnet' => '234'
   });
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'modify (invalid user spec)');

# suspended user
$WarnOK = 0;
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser5', 'network', '1', '1',
   {'network.id' => 1,
    'network.version' => 20040101010101,
    'network.name' => 'NetMod 2',
    'network.subnet' => '234'
   });
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EUSERSUSPEND'},
   'modify (suspended user)');

$SIG{__WARN__} =  sub {
  $WarnOK = 1
    if ($_[0] =~ /Validation of .*failed/s);
};

# invalid table name specs
$WarnOK = 0;
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', 'notable', '1', '1', {'network.name' => 'NetMod 3'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'modify (invalid table name)');

$WarnOK = 0;
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', {'f' => 'b'}, '1', '1', {'network.name' => 'NetMod 4'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'modify (table as ref)');

$WarnOK = 0;
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', 'network machine', '1', '1',
   {'network.name' => 'NetMod 5'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'modify (multiple tables w/ space)');

$WarnOK = 0;

# invalid ID spec
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', 'network', {'f' => 'b'}, '1',
   {'network.name' => 'NetMod 6'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'modify (invalid ID spec - ref)');

$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', 'network', 'foo', '1',
   {'network.name' => 'NetMod 7'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'modify (invalid ID spec - non-numeric)');

$WarnOK = 0;

# invalid version spec
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', 'network', '1', {'f' => 'b'},
   {'network.name' => 'NetMod 8'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'modify (invalid version - ref)');

$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', 'network', '1', 'foo',
   {'network.name' => 'NetMod 9'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'modify (invalid version - non-numeric)');

$SIG{__WARN__} = '';

# no access
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser4', 'network', '1', '20040101010101',
   {'network.name' => 'NetMod 10'});
is($Ret, $CMU::Netdb::errors::errcodes{'EPERM'},
   'modify (no access)');

# Force a new change log ID to make sure they are recorded separately
CMU::Netdb::primitives::changelog_id($dbh, 'testuser3', 1);

# version mismatch
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser3', 'machine', '3802', '20040510160547',
   {'machine.host_name_ttl' => '12345'});
is($Ret, $CMU::Netdb::errors::errcodes{'ESTALE'},
   'modify (mismatched version)');

# check for changelog entries -- none should exist
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'machine' AND row = '3802'";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('modify (version mismatch changelog prepare)');
}else{
  unless($sth->execute()) {
    fail("modify (version mismatch changelog execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 0) {
      fail("modify (version mismatch changelog query; $rd[0])");
    }else{
      pass("modify (version mismatch changelog query)");
    }
  }
}

# Force a new change log ID to make sure they are recorded separately
CMU::Netdb::primitives::changelog_id($dbh, 'testuser3', 1);

# should complete
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser3', 'machine', '3802', '20040510160546',
   {'machine.host_name_ttl' => '23456'});
is($Ret, 1, 'modify (ok)');

# check changelog entries
# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'machine' AND row = '3802' AND type = 'UPDATE' AND
      previous = '0' AND
      crc.name = 'machine.host_name_ttl' AND crc.data = '23456'";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('modify (correctness prepare)');
}else{
  unless($sth->execute()) {
    fail("modify (correctness execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("modify (correctness changelog query)");
    }else{
      pass("modify (correctness changelog query)");
    }
  }
}

# Get the version of that
my $NewVersion;
$Q = "SELECT version FROM machine WHERE id = 3802";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('modify (retrieve updated version/prepare)');
}else{
  unless ($sth->execute()) {
    fail('modify (retrieve updated version/execute)');
  }else{
    my @rd = $sth->fetchrow_array();
    $NewVersion = $rd[0];
    pass('modify (retrieve updated version)');
  }
}

# Try another modify -- this should return 1 even though the data is
# unchanged
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser3', 'machine', '3802', $NewVersion,
   {'machine.host_name_ttl' => '23456'});
is($Ret, 1, 'modify (no change required)');

# check changelog entries
# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'machine' AND row = '3802' AND type = 'UPDATE' AND
      previous = '0' AND
      crc.name = 'machine.host_name_ttl' AND crc.data = '23456'";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('modify (correctness re-run prepare)');
}else{
  unless($sth->execute()) {
    fail("modify (correctness re-run execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("modify (correctness re-run changelog query)");
    }else{
      pass("modify (correctness re-run changelog query)");
    }
  }
}

# Force a new change log ID to make sure they are recorded separately
CMU::Netdb::primitives::changelog_id($dbh, 'testuser3', 1);

# id/version should not exist
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser3', 'machine', '15982', '20040510161458',
   {'machine.host_name_ttl' => '23456',
    'machine.id' => '100000',
    'machine.version' => '20040510161459'});
is($Ret, 1, 'modify (id/version specified)');

# check changelog entries
# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'machine' AND row = '15982'";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('modify (id/version spec changelog prepare)');
}else{
  unless($sth->execute()) {
    fail("modify (id/version spec changelog execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("modify (id/version spec changelog query)");
    }else{
      pass("modify (id/version spec changelog query)");
    }
  }
}

# Force a new change log ID to make sure they are recorded separately
CMU::Netdb::primitives::changelog_id($dbh, 'testuser3', 1);

# EXPR in fields
($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser3', 'machine', '28160', '20040510162421',
   {'machine.host_name_ttl' => '*EXPR: host_name_ttl + 34567'});

is($Ret, 1, 'modify (expr)');

# check changelog entries
# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'machine' AND row = '28160' AND
      crc.name = 'machine.host_name_ttl' AND
      crc.data = 'host_name_ttl + 34567'";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('modify (expr changelog prepare)');
}else{
  unless($sth->execute()) {
    fail("modify (expr changelog execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("modify (expr changelog query: $rd[0])");
    }else{
      pass("modify (expr changelog query)");
    }
  }
}

# Force a new change log ID to make sure they are recorded separately
CMU::Netdb::primitives::changelog_id($dbh, 'testuser3', 1);

# bad DB info in EXPR
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1 if ($_[0] =~ /error in .+ SQL syntax/s); };

($Ret, $Info) = CMU::Netdb::primitives::modify
  ($dbh, 'testuser3', 'machine', '10333', '20040510161042',
   {'machine.host_name_ttl' => '*EXPR: AND badsql'});

ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EDB'},
   'modify (bad expr)');

$SIG{__WARN__} = '';

# check changelog entries
# verify changelog records of entry
$Q = "SELECT COUNT(*)
FROM _sys_changelog AS cl JOIN
     _sys_changerec_row AS crr ON crr.changelog = cl.id JOIN
     _sys_changerec_col AS crc ON crc.changerec_row = crr.id
WHERE tname = 'machine' AND row = '10333'";

$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('modify (bad expr changelog prepare)');
}else{
  unless($sth->execute()) {
    fail("modify (bad expr changelog execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 0) {
      fail("modify (bad expr changelog query: $rd[0])");
    }else{
      pass("modify (bad expr changelog query)");
    }
  }
}

# test delete
# test:
#  X invalid user specification
#  X suspended user
#  X invalid table name specification
#  X invalid ID specification
#  X invalid version specification
#  X cascade deletion prevents deletion
#  X no access to delete item
#  X incompatible version
#    X verify rollback happened and changelog 
#  X normal: cascade deletion deletes nothing
#    X verify changelog records
#  X normal: cascade deletion deletes other rows
#    X verify changelog records

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1 if ($_[0] =~ /Validation.+failed/s); };

# undefined user
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, undef, 'dns_zone', 24,
					       '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EINVCHAR'},
   'delete (user undef)');

$WarnOK = 0;

# suspended user
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'testuser5', 'dns_zone', 
					       24, '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EUSERSUSPEND'},
   'delete (user suspended)');

$WarnOK = 0;

# table name undef
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', undef, 24,
					       '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EBLANK'},
   'delete (table undef)');

$WarnOK = 0;

# table name blank
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', '', 24,
					       '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EBLANK'},
   'delete (table blank)');

$WarnOK = 0;

# table name invalid
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'notable', 24,
					       '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'delete (table invalid)');

$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 
					       'machine, subnet', 24,
					       '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'delete (multiple tables)');

# invalid ID
$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone', 
					       undef, '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'delete (undef id)');

$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone', 
					       'foobar', '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'delete (non-numeric id)');

$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone', 
					       {'f' => 'b'}, '20020102163330');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'delete (reference id)');

$WarnOK = 0;

# invalid version
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone', 
					       '24', undef);
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'delete (undef version)');

$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone', 
					       '24', {'f' => 'b'});
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'delete (reference version)');

$WarnOK = 0;

($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone', 
					       '24', 'foobar');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'delete (non-numeric version)');

$SIG{__WARN__} = '';

# cascade deletion should prevent this deletion, because
# a.del1.example.org exists
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone', 41,
					       '20020102151506');
is($Ret, $CMU::Netdb::errors::errcodes{'ECASCADEFATAL'},
   'delete (cascade deletion prevents removal)');

# no access to delete
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'testuser3', 'dns_zone',
					       42, '20020102151506');
is($Ret, $CMU::Netdb::errors::errcodes{'EPERM'},
   'delete (no access to delete)');

($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone',
					       40, '20020102151507');
is($Ret, $CMU::Netdb::errors::errcodes{'ENOENT'},
   'delete (incompatible version)');

$Q = "SELECT COUNT(*) FROM subnet_domain WHERE id IN (12,13)";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail("delete - invalid db verification / prepare");
}else{
  $Ret = $sth->execute();
  unless ($Ret) {
    fail("delete - invalid db verification / execute");
  }else{
    my ($cnt) = $sth->fetchrow_array();
    if ($cnt != 2) {
      fail("delete - invalid db verification / count");
    }else{
      pass("delete - invalid db verification");
    }
  }
}

$Q = "SELECT COUNT(*) FROM _sys_changerec_row WHERE type = 'DELETE'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail("delete - invalid changerec verification / prepare");
}else{
  $Ret = $sth->execute();
  unless ($Ret) {
    fail("delete - invalid changerec verification / execute");
  }else{
    my ($cnt) = $sth->fetchrow_array();
    if ($cnt != 0) {
      fail("delete - invalid changerec verification / count");
    }else{
      pass("delete - invalid changerec verification");
    }
  }
}

# cascade deletion deletes nothing
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone',
					       43, '20020102151506');
is($Ret, 1, 'delete (zone without cascade requirement)');

$Q = "SELECT COUNT(*) FROM _sys_changerec_row WHERE type = 'DELETE'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail("delete - delete (no cascade) verification / prepare");
}else{
  $Ret = $sth->execute();
  unless ($Ret) {
    fail("delete - delete (no cascade) verification / execute");
  }else{
    my ($cnt) = $sth->fetchrow_array();
    if ($cnt != 1) {
      fail("delete - delete (no cascade) verification / count");
    }else{
      pass("delete - delete (no cascade) verification");
    }
  }
}

$Q = "SELECT COUNT(*) FROM dns_zone WHERE id = 43";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail("delete - delete (no cascade) db / prepare");
}else{
  $Ret = $sth->execute();
  unless ($Ret) {
    fail("delete - delete (no cascade) db / execute");
  }else{
    my ($cnt) = $sth->fetchrow_array();
    if ($cnt != 0) {
      fail("delete - delete (no cascade) db / count");
    }else{
      pass("delete - delete (no cascade) db");
    }
  }
}

# cascade deletion deletes other rows
($Ret, $Info) = CMU::Netdb::primitives::delete($dbh, 'netreg', 'dns_zone',
					       42, '20020102151506');
is($Ret, 1, 'delete (zone with cascade requirement)');

$Q = "SELECT COUNT(*) FROM _sys_changerec_row WHERE type = 'DELETE'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail("delete - delete (cascade) verification / prepare");
}else{
  $Ret = $sth->execute();
  unless ($Ret) {
    fail("delete - delete (cascade) verification / execute");
  }else{
    my ($cnt) = $sth->fetchrow_array();
    if ($cnt != 3) {
      fail("delete - delete (cascade) verification / count");
    }else{
      pass("delete - delete (cascade) verification");
    }
  }
}

$Q = "SELECT COUNT(*) FROM dns_zone WHERE id = 42";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail("delete - delete (cascade dns_zone) db / prepare");
}else{
  $Ret = $sth->execute();
  unless ($Ret) {
    fail("delete - delete (cascade dns_zone) db / execute");
  }else{
    my ($cnt) = $sth->fetchrow_array();
    if ($cnt != 0) {
      fail("delete - delete (cascade dns_zone) db / count");
    }else{
      pass("delete - delete (cascade dns_zone) db");
    }
  }
}

$Q = "SELECT COUNT(*) FROM subnet_domain WHERE id = 13";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail("delete - delete (cascade subnet_domain) db / prepare");
}else{
  $Ret = $sth->execute();
  unless ($Ret) {
    fail("delete - delete (cascade subnet_domain) db / execute");
  }else{
    my ($cnt) = $sth->fetchrow_array();
    if ($cnt != 0) {
      fail("delete - delete (cascade subnet_domain) db / count");
    }else{
      pass("delete - delete (cascade subnet_domain) db");
    }
  }
}

# test delete_cascade_check
# test:
#  - invalid user specification
#  - invalid table specification (not a real table)
#  - invalid tid specification (not a real id)
#  - invalid cascade depth specification
#  - high cascade depth
#  - check that cascade depth is being incremented
#  - normal: no dependent fields
#  - normal: dependent fields

# FIXME

# test delete_cascade_xone
# if we try to delete dns zone id 300, CTABLE is dns_zone, id = 300,
# FK is just the name, and CR is the cascade struct (e.g. referencing
# machine.host_name_zone, machine.ip_address_zone)

# test: 
#  X delete, deleteOrUpdate, fatal outcomes
#    X finding rows, and not finding..
#    X with delete/deleteOrUpdate, validate returned data
#  X CR table info of "foo AS bar"
#  X broken Where clause in CR

# delete
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 15, 'dns_zone.id',
   {'Outcome' => 'delete',
    'Primary' => 'machine',
    'Where' => 'machine.host_name_zone = dns_zone.id'});
is($Ret, 1, 'delete_cascade_xone(delete return)');
is_deeply($Info,
	  [['machine','7','20020102224519'],
	   ['machine','8','20020102224546']],
	  'delete_cascade_xone(delete data)');

# deleteOrUpdate
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 15, 'dns_zone.id',
   {'Outcome' => 'deleteOrUpdate',
    'Primary' => 'machine',
    'Where' => 'machine.host_name_zone = dns_zone.id'});
is($Ret, 1, 'delete_cascade_xone(deleteOrUpdate return)');
is_deeply($Info,
          [['machine','7','20020102224519'],
           ['machine','8','20020102224546']],
          'delete_cascade_xone(deleteOrUpdate data)');

# fatal
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 15, 'dns_zone.id',
   {'Outcome' => 'fatal',
    'Primary' => 'machine',
    'Where' => 'machine.host_name_zone = dns_zone.id'});
is($Ret, $CMU::Netdb::errors::errcodes{'ECASCADEFATAL'}, 
   'delete_cascade_xone(fatal return)');
is_deeply($Info, ['machine','dns_zone.id'],
          'delete_cascade_xone(fatal data)');

# table alias
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 12, 'dns_zone.id',
   {'Outcome' => 'delete',
    'Primary' => 'dns_zone AS D2',
    'Where' => 'D2.parent = dns_zone.id AND D2.id != dns_zone.id'.
    ' ORDER BY dns_zone.id '
   });
is($Ret, 1, 'delete_cascade_xone(table alias return)');
is_deeply($Info, [['dns_zone', '14', '20020102151553'],
		  ['dns_zone', '15', '20020102151647']],
	  'delete_cascade_xone(table alias data)');

# table alias as fatal
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 12, 'dns_zone.id',
   {'Outcome' => 'fatal',
    'Primary' => 'dns_zone AS D2',
    'Where' => 'D2.parent = dns_zone.id AND D2.id != dns_zone.id'
   });
is($Ret, $CMU::Netdb::errors::errcodes{'ECASCADEFATAL'},
   'delete_cascade_xone(table alias/fatal return)');
is_deeply($Info, ['dns_zone AS D2','dns_zone.id'],
          'delete_cascade_xone(table alias/fatal data)');

# no results
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 15, 'dns_zone.id',
   {'Outcome' => 'fatal',
    'Primary' => 'machine',
    'Where' => 'machine.ip_address_zone = dns_zone.id'
   });
is($Ret, 1, 'delete_cascade_xone(no results return)');
is_deeply($Info, [], 'delete_cascade_xone(no results data)');

# no results -- delete
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 15, 'dns_zone.id',
   {'Outcome' => 'delete',
    'Primary' => 'machine',
    'Where' => 'machine.ip_address_zone = dns_zone.id'
   });
is($Ret, 1, 'delete_cascade_xone(no results/delete return)');
is_deeply($Info, [[]], 'delete_cascade_xone(no results/delete data)');

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Unknown column/s);};
# broken where clause
($Ret, $Info) = CMU::Netdb::primitives::delete_cascade_xone
  ($dbh, 'dns_zone', 15, 'dns_zone.id',
   {'Outcome' => 'fatal',
    'Primary' => 'machine',
    'Where' => 'machine.host_name_zone = dns_zone.id and badsql '});
is($Ret, $CMU::Netdb::errors::errcodes{'EDB'},
   'delete_cascade_xone(broken where-clause return)');
is($WarnOK, 1, 'delete_cascade_xone(broken where-clause warning)');

$SIG{__WARN__} = '';

# test delete_cascade_xmrone
# FIXME

# test delete_permission_check

# protections table
($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'netreg', 'protections', 0);
is($Ret, 1, "delete_permission_check (netreg, protections)");

($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'nouser', 'protections', 0);
is($Ret, 1, "delete_permission_check (nouser, protections)");

# full table access
($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'netreg', 'machine', 0);
is($Ret, 1, "delete_permission_check (netreg, machine/0)");

# single machine
($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'netreg', 'machine', 5);
is($Ret, 1, "delete_permission_check (netreg, machine/5)");

# invalid table
($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'netreg', 'notable', 0);
is($Ret, $CMU::Netdb::errors::errcodes{'EPERM'}, 
   "delete_permission_check (netreg, notable/0)");

# user based tests
($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'testuser3', 'machine', 0);
is($Ret, $CMU::Netdb::errors::errcodes{'EPERM'}, 
   "delete_permission_check (testuser3, machine/0)");

($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'testuser3', 'machine', 59);
is($Ret, 1, "delete_permission_check (testuser3, machine/59)");

($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'nouser', 'machine', 59);
is($Ret, $CMU::Netdb::errors::errcodes{'EPERM'},
   "delete_permission_check (nouser, machine/59)");

($Ret, $Info) = CMU::Netdb::primitives::delete_permission_check
  ($dbh, 'nouser', 'machine', 0);
is($Ret, $CMU::Netdb::errors::errcodes{'EPERM'},
   "delete_permission_check (nouser, machine/0)");

# test clear_changelog

$Ret = CMU::Netdb::primitives::clear_changelog("test-$$");
is($CMU::Netdb::primitives::changelog_id, 0, 'clear_changelog (id)');
is($CMU::Netdb::primitives::changelog_user, '', 'clear_changelog (user)');
ok(!defined $CMU::Netdb::primitives::db_insertid,
   'clear_changelog (db_insertid)');
is($CMU::Netdb::primitives::changelog_info, "test-$$",
   'clear_changelog (changelog_info)');

$Ret = CMU::Netdb::primitives::clear_changelog("bad'changelog");
is($CMU::Netdb::primitives::changelog_info, "badchangelog",
   'clear_changelog (cleanse required)');

# test changelog_start

$Ret = CMU::Netdb::primitives::clear_changelog("test-$$");
# actual user
$Ret = CMU::Netdb::primitives::changelog_start($dbh, 'testuser1');
ok($Ret != 0, "changelog_start (return value)");

# verify the record exists
$Q = "SELECT user, name, info FROM _sys_changelog WHERE ".
  " _sys_changelog.id = '$Ret'";
$sth = $dbh->prepare($Q);
unless($sth) {
  fail("changelog_start (query verification / prepare)");
}else{
  unless($sth->execute()) {
    fail("changelog_start (query verification / execute)");
  }else{
    my ($user, $name, $info) = $sth->fetchrow_array();
    ok($user == 2 && $name eq 'testuser1' && $info eq "test-$$",
       'changelog_start (query verification)');
  }
}

# test a bogus user
$Ret = CMU::Netdb::primitives::clear_changelog("test-bogus-$$");

is(CMU::Netdb::primitives::changelog_start($dbh, 'nouser'), 0,
   'changelog_start (invalid user)');

# test a bad construction of user name
$WarnOK = 0;
$SIG{__WARN__} = sub {$WarnOK = 1 if ($_[0] =~ /adding changelog/);};

$Ret = CMU::Netdb::primitives::changelog_start($dbh, "foo'bar");
# Want to make sure we DIDN'T get the db error
ok($WarnOK == 0 && $Ret == 0, 'changelog_start (bad username construction)');

$SIG{__WARN__} = '';

# test changelog_id
CMU::Netdb::primitives::clear_changelog();

# Test default behavior of creating new ID
$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1');

ok($Ret != 0 &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser1',
   'changelog_id(testuser1)');

my $ExCID = $Ret;

# test default behavior when user is netreg (and ID exists)
$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'netreg');
ok($Ret == $ExCID &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser1',
   'changelog_id(netreg, existing log)');

# test default behavior when user is not the same
$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'testuser3');
ok($Ret != 0 && $Ret != $ExCID &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser3',
   'changelog_id(testuser3, existing log)');

$ExCID = $Ret;

# force a change even with the same user
$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'testuser3', 1);
ok($Ret != 0 && $Ret != $ExCID &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser3',
   'changelog_id(testuser3, force new log)');

$ExCID = $Ret;

# verify a forced inheritance
$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'testuser3', 0);
ok($Ret == $ExCID &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser3',
   'changelog_id(testuser3, force inheritance)');

# try to force inheritance with new id
$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'testuser4', 0);
ok($Ret != 0 && $Ret != $ExCID &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser4',
   'changelog_id(testuser4, try to force inheritance)');

$ExCID = $Ret;

# force inheritance with netreg id
$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'netreg', 0);
ok($Ret == $ExCID &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser4',
   'changelog_id(netreg, try to force inheritance)');

# break things a bit and make sure it deals
$Ret = CMU::Netdb::primitives::changelog_start($dbh, 'nouser');

# Ret == 0 because nouser doesn't exist
$ExCID = $Ret;
$CMU::Netdb::primitives::changelog_id = $ExCID;
$CMU::Netdb::primitives::changelog_user = 'testuser1';

$Ret = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1', 0);
ok($Ret != 0 && $Ret != $ExCID &&
   $CMU::Netdb::primitives::changelog_id == $Ret &&
   $CMU::Netdb::primitives::changelog_user eq 'testuser1',
   'changelog_id(testuser1, error in setup)');

# test changelog_row
# test:
#  X invalid type
#  X invalid row
#  X invalid table name
#  X invalid log

# basic
# get a changelog id
CMU::Netdb::primitives::clear_changelog();
$ID = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1', 1);
ok($ID != 0, 'changelog_row (new changelog 1)');

$Ret = CMU::Netdb::primitives::changelog_row($dbh, $ID, 'network', '1000',
					     'INSERT');
ok($Ret > 0, 'changelog_row (basic/insert)');
$Q = "SELECT COUNT(*) from _sys_changerec_row WHERE ".
  "id = '$Ret' AND changelog = '$ID' AND tname = 'network' ".
  " AND row = '1000' AND type = 'INSERT'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('changelog_row (basic/insert prepare)');
}else{
  unless($sth->execute()) {
    fail("changelog_row (basic/insert execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("changelog_row (basic/insert verification)");
    }else{
      pass("changelog_row (basic/insert verification)");
    }
  }
}

# basic (type = delete)
CMU::Netdb::primitives::clear_changelog();
$ID = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1', 1);
ok($ID != 0, 'changelog_row (new changelog 2)');

$Ret = CMU::Netdb::primitives::changelog_row($dbh, $ID, 'network', '1001',
					     'DELETE');
ok($Ret > 0, 'changelog_row (basic/delete)');
$Q = "SELECT COUNT(*) from _sys_changerec_row WHERE ".
  "id = '$Ret' AND changelog = '$ID' AND tname = 'network' ".
  " AND row = '1001' AND type = 'DELETE'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('changelog_row (basic/delete prepare)');
}else{
  unless($sth->execute()) {
    fail("changelog_row (basic/delete execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("changelog_row (basic/delete verification)");
    }else{
      pass("changelog_row (basic/delete verification)");
    }
  }
}

# basic (type = update)
CMU::Netdb::primitives::clear_changelog();
$ID = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1', 1);
ok($ID != 0, 'changelog_row (new changelog 2)');

$Ret = CMU::Netdb::primitives::changelog_row($dbh, $ID, 'network', '1002',
					     'UPDATE');
ok($Ret > 0, 'changelog_row (basic/update)');
$Q = "SELECT COUNT(*) from _sys_changerec_row WHERE ".
  "id = '$Ret' AND changelog = '$ID' AND tname = 'network' ".
  " AND row = '1002' AND type = 'UPDATE'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('changelog_row (basic/update prepare)');
}else{
  unless($sth->execute()) {
    fail("changelog_row (basic/update execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("changelog_row (basic/update verification)");
    }else{
      pass("changelog_row (basic/update verification)");
    }
  }
}

# basic (invalid)
CMU::Netdb::primitives::clear_changelog();
$ID = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1', 1);
ok($ID != 0, 'changelog_row (new changelog 4)');

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::changelog_row($dbh, $ID, 'network', '1003',
					     'BOGUS_TYPE');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'changelog_row (invalid type)');

$SIG{__WARN__} = '';

# invalid row
CMU::Netdb::primitives::clear_changelog();
$ID = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1', 1);
ok($ID != 0, 'changelog_row (new changelog 5)');

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::changelog_row($dbh, $ID, 'network', 'norow',
					     'INSERT');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'changelog_row (invalid row)');
$SIG{__WARN__} = '';

# invalid table
CMU::Netdb::primitives::clear_changelog();
$ID = CMU::Netdb::primitives::changelog_id($dbh, 'testuser1', 1);
ok($ID != 0, 'changelog_row (new changelog 6)');

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::changelog_row($dbh, $ID, 'notable', '1005',
					     'INSERT');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ESETMEM'},
   'changelog_row (invalid table)');

$SIG{__WARN__} = '';

# invalid log
CMU::Netdb::primitives::clear_changelog();

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /Validation.*failed/s);};
$Ret = CMU::Netdb::primitives::changelog_row($dbh, 'nolog', 'network', '1006',
					     'INSERT');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'changelog_row (invalid log)');

$SIG{__WARN__} = '';

# test changelog_col
#  X invalid logrow
#  X invalid name
#  - invalid data
#  - invalid previous
#  - undef both data and previous
#  - verify database

# both data and previous as refs
$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1
			 if ($_[0] =~ /two references passed in/s);};
$Ret = CMU::Netdb::primitives::changelog_col($dbh, '0', 'foo', {}, {});
ok($Ret == 0 && $WarnOK == 1, 'changelog_col (two references)');

$WarnOK = 0;
$SIG{__WARN__} = sub { $WarnOK = 1 if ($_[0] =~ /Validation.*failed/s);};

# undef check
$Ret = CMU::Netdb::primitives::changelog_col($dbh, undef, 'foo', 
					     'foo1', 'foo2');
ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'ENONUM'},
   'changelog_col (undef logrow)');

$WarnOK = 0;

# undef name
$Ret = CMU::Netdb::primitives::changelog_col($dbh, '1', undef, 'foo1', 'foo2');

ok($WarnOK && $Ret == $CMU::Netdb::errors::errcodes{'EBLANK'},
   'changelog_col (undef name)');

$SIG{__WARN__} = '';

# undef data
$Ret = CMU::Netdb::primitives::changelog_col($dbh, '9901', 'ColTest1',
					     undef, 'col1');
is($Ret, 1, 'changelog_col (undef data)');

# verify what's in the databse
$Q = "SELECT COUNT(*) from _sys_changerec_col WHERE ".
  "changerec_row = '9901' AND name = 'ColTest1' AND ".
  " previous = 'col1'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('changelog_col (undef next prepare)');
}else{
  unless($sth->execute()) {
    fail("changelog_col (undef next execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("changelog_col (undef next verification: $rd[0])");
    }else{
      pass("changelog_col (undef next verification)");
    }
  }
}

# undef previous
$Ret = CMU::Netdb::primitives::changelog_col($dbh, '9902', 'ColTest2',
					     'col2', undef);
is($Ret, 1, 'changelog_col (undef previous)');

# verify what's in the databse
$Q = "SELECT COUNT(*) from _sys_changerec_col WHERE ".
  "changerec_row = '9902' AND name = 'ColTest2' AND ".
  " data = 'col2'";
$sth = $dbh->prepare($Q);
unless ($sth) {
  fail('changelog_col (undef previous prepare)');
}else{
  unless($sth->execute()) {
    fail("changelog_col (undef previous execute)");
  }else{
    my @rd = $sth->fetchrow_array();
    if ($rd[0] != 1) {
      fail("changelog_col (undef previous verification)");
    }else{
      pass("changelog_col (undef previous verification)");
    }
  }
}


# undef both: is Ret == 1 the right result?
$Ret = CMU::Netdb::primitives::changelog_col($dbh, '9903', 'ColTest3',
					     undef, undef);
is($Ret, 1, 'changelog_col (undef data/previous)');


