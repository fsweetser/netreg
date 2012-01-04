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
# $Id: structure.pl,v 1.4 2008/03/27 19:42:36 vitroth Exp $
#
# $Log: structure.pl,v $
# Revision 1.4  2008/03/27 19:42:36  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.3.20.1  2007/10/11 20:59:41  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.3.18.1  2007/09/20 18:43:05  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.3  2004/05/25 14:19:06  kevinm
# * More tests, more debugging
#
# Revision 1.2  2004/05/17 15:29:28  kevinm
# * Fixes to deal with different netmon location
#
# Revision 1.1  2004/05/17 14:29:27  kevinm
# * Initial checkin
#
# Revision 1.3  2004/05/10 21:46:36  kevinm
# * Committing without comments preventing prune checking
#
# Revision 1.2  2004/05/10 21:45:37  kevinm
# *** empty log message ***
#
# Revision 1.1  2004/05/03 20:51:31  kevinm
# * First checkin of test framework
#
#
#

use Test::More;

use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

use strict;

use lib '/usr/ng/lib/perl5';
use lib '../../..';

use CMU::Netdb::t::framework;
use CMU::Netdb::structure;
use CMU::Netdb::config;

# This is a generic format for validating an enum() in the database with
# a particular array from structure.pm.
# [db column name] => [array]
my %ColumnMaps = ('groups.flags' => 'groups_flags',
		  'dns_zone.type' => 'dns_zone_types',
		  'dns_resource.owner_type' => 'dns_resource_owner_types',
		  'attribute.owner_table' => 'attribute_owners',
		  'attribute_spec.scope' => 'attribute_spec_scope',
		  'dhcp_option.type' => 'dhcp_option_types',
		  'subnet.flags' => 'subnet_flags',
		  'subnet.dynamic' => 'subnet_dynamic',
		  'subnet.default_mode' => 'subnet_default_mode',
		  'machine.flags' => 'machine_flags',
		  'outlet.attributes' => 'outlet_attributes',
		  'outlet.flags' => 'outlet_flags',
		  'outlet.status' => 'outlet_status',
		  'outlet_subnet_membership.type' =>
		    'outlet_subnet_membership_type',
		  'outlet_subnet_membership.trunk_type' =>
		    'outlet_subnet_membership_trunk_type',
		  'outlet_subnet_membership.status' =>
		    'outlet_subnet_membership_status',
		  'outlet_vlan_membership.type' =>
		    'outlet_vlan_membership_type',
		  'outlet_vlan_membership.trunk_type' =>
		    'outlet_vlan_membership_trunk_type',
		  'outlet_vlan_membership.status' =>
		    'outlet_vlan_membership_status',
		  'cable.type' => 'cable_type',
		  'cable.rack' => 'cable_rack',
		  '_sys_changerec_row.type' => 'sys_changerec_row_type',


		  );
my %ColumnInfo;

my $SET_TESTS = 3 + scalar(keys %ColumnMaps) +
  scalar(keys %CMU::Netdb::structure::restricted_access_fields) +
  2*scalar(keys %CMU::Netdb::structure::cascades);

## BEGIN TESTING

# Verify that things are in place
reload_db("db-primitives-1");
my $dbh = test_db_connect();

# Read from the database to compare to the structure contents

my ($Ret, $Q, $sth);

$Q = "show tables;";
$sth = $dbh->prepare($Q);
$sth->execute();
my @Tables = sort {$a cmp $b } map { $_->[0] } @{$sth->fetchall_arrayref()};

plan tests => $SET_TESTS + scalar(@Tables);

ok(scalar(@Tables) > 0, 'table list');

my @VT = sort {$a cmp $b} @CMU::Netdb::structure::valid_tables;
is(scalar(@VT), scalar(@Tables), 'valid_table list size');

my $TableOK = 1;
for my $i (0..$#Tables) {
  $TableOK = $Tables[$i] unless ($Tables[$i] eq $VT[$i]);
}

unless($TableOK == 1) {
  fail("tables differ ($TableOK)");
}else{
  pass("valid_table matches database tables");
}

# Verify that the fields match all the tables.
TABLE:
foreach my $Table (@Tables) {
  my $FieldArray = "CMU::Netdb::structure::${Table}_fields";
  unless (defined @$FieldArray) {
    fail("$Table: no table fields structure");
    next TABLE;
  }
  my @SFields;
  eval '@SFields = @'.$FieldArray.';';

  my $FieldPrint = "CMU::Netdb::structure::${Table}_printable";
  unless (defined %$FieldPrint) {
    fail("$Table: no table printable structure");
    next TABLE;
  }
  my %SPrint;
  eval '%SPrint = %'.$FieldPrint.';';

  # Get the fields from the database
  $Q = "describe $Table;";
  $sth = $dbh->prepare($Q);
  $sth->execute();
  my $TInfo = $sth->fetchall_arrayref();
  my @Fields = map { $_->[0] } @{$TInfo};
  foreach my $Row (@$TInfo) {
    my $F = $Row->[0];
    unless (grep /^$Table.$F$/, @SFields) {
      fail("$Table: field $F not defined in _fields structure");
      next TABLE;
    }
    unless (defined $SPrint{"${Table}.$F"}) {
      fail("$Table: field $F not defined in _printable structure");
      next TABLE;
    }
    $ColumnInfo{"$Table.$F"} = {'format' => $Row->[1]};
  }
  if (scalar(@Fields) != scalar(@SFields)) {
    fail("$Table: ".scalar(@Fields)." fields in database, ".
	 scalar(@SFields)." fields in _fields struct");
    next TABLE;
  }
  my @FPK = keys %SPrint;
  if (scalar(@Fields) != scalar(@FPK)) {
    fail("$Table: ".scalar(@Fields)." fields in database, ".
	 scalar(@FPK)." fields in _printable struct");
    next TABLE;
  }

  pass("$Table: looks good");
}

# verify column maps
foreach my $Col (keys %ColumnMaps) {
  my $ARef = 'CMU::Netdb::structure::'.$ColumnMaps{$Col};
  unless (defined @$ARef) {
    fail("Column reference ($Col) array doesn't exist ($ARef)");
    next;
  }
  unless (defined $ColumnInfo{$Col}) {
    fail("Column reference ($Col) not found (table should be okay first)");
    next;
  }

  my @SCol;
  eval '@SCol = @'.$ARef.';';
  @SCol = sort { $a cmp $b } @SCol;
  my @ECol;
  my $format = $ColumnInfo{$Col}->{'format'};
  unless($format =~ /^(enum|set)\((.+)\)$/) {
    fail("Column reference ($Col) does not appear as enum/set in the database");
    next;
  }

  @ECol = sort { $a cmp $b }
    map { $_ =~ s/^\'//; $_ =~ s/\'$//; $_; } split(/\,/, $2);
  if (scalar(@ECol) != scalar(@SCol)) {
    fail("Column reference ($Col) database/structure array lengths differ");
    next;
  }

  for my $i (0..$#ECol) {
    if ($ECol[$i] ne $SCol[$i]) {
      fail("Column reference ($Col) inconsistency ($ECol[$i] != $SCol[$i])");
      next;
    }
  }

  pass("Column reference ($Col) looks good");
}

# verify that restricted access fields all exist
foreach my $Col (keys %CMU::Netdb::structure::restricted_access_fields) {
  ok(defined $ColumnInfo{$Col}, "restricted access field $Col defined");
}

# verify that cascade delete fields all exist, and verify the primary
# tables all exist
foreach my $Key (keys %CMU::Netdb::structure::cascades) {
  ok(defined $ColumnInfo{$Key},
     "cascade delete key field $Key defined");
  my $AllTablesOk = 1;
  foreach my $E (@{$CMU::Netdb::structure::cascades{$Key}}) {
    my $PT = $E->{'Primary'};
    $PT =~ s/\s*AS.+$//;
    $AllTablesOk = $PT unless (scalar(grep/^$PT$/, @Tables) == 1);
  }
  ok($AllTablesOk == 1, "cascade delete primary table ($Key/$AllTablesOk)");
}

# verify that multiref TableRef/TidRef are correct

