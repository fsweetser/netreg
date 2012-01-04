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
# $Id: auth.pl,v 1.3 2008/03/27 19:42:35 vitroth Exp $
#
# $Log: auth.pl,v $
# Revision 1.3  2008/03/27 19:42:35  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.2.14.1  2007/10/11 20:59:40  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.2.12.1  2007/09/20 18:43:04  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.2  2004/06/24 02:38:10  kevinm
# * Pulling from cred tree
#
# Revision 1.1.2.3  2004/06/17 21:41:40  kevinm
# * More auth checking..
#
# Revision 1.1.2.2  2004/06/17 19:09:44  kevinm
# * Additional auth tests
#
# Revision 1.1.2.1  2004/06/17 01:38:07  kevinm
# * Additional auth checking
#
#
#

use Test::More tests => 43;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

use strict;

use lib '/usr/ng/lib/perl5';
use lib '../../..';

use CMU::Netdb::t::framework;
use CMU::Netdb::auth;
use CMU::Netdb::config;

## BEGIN TESTING

# Verify that things are in place
reload_db("db-auth-1");
my $dbh = test_db_connect();
my ($sth, $Ret, $t0, $t1, $Data, $WarnOK);
my %errcodes = %CMU::Netdb::errors::errcodes;

# test get_add_level
$t0 = [gettimeofday];
$Ret = CMU::Netdb::auth::get_add_level($dbh, 'netreg', 'machine', 0);
$t1 = [gettimeofday];

is($Ret, 9, "get_add_level(netreg/machine/0, dT=".tv_interval($t0, $t1).")");

$t0 = [gettimeofday];
$Ret = CMU::Netdb::auth::get_add_level($dbh, 'testuser5', 'machine', 0);
$t1 = [gettimeofday];

is($Ret, 0, "get_add_level(testuser5/machine/0, dT=".
   tv_interval($t0, $t1).")");

# FIXME



# test get_read_level
$t0 = [gettimeofday];
$Ret = CMU::Netdb::auth::get_read_level($dbh, 'netreg', 'machine', 0);
$t1 = [gettimeofday];

is($Ret, 9, "get_read_level(netreg/machine/0, dT=".tv_interval($t0, $t1).")");

$t0 = [gettimeofday];
$Ret = CMU::Netdb::auth::get_read_level($dbh, 'testuser5', 'machine', 0);
$t1 = [gettimeofday];

is($Ret, 0, "get_read_level(testuser5/machine/0, dT=".
   tv_interval($t0, $t1).")");

$t0 = [gettimeofday];
$Ret = CMU::Netdb::auth::get_read_level($dbh, 'kevinm', 'machine', 900);
$t1 = [gettimeofday];

is($Ret, 0, "get_read_level(testuser5/machine/900, dT=".
   tv_interval($t0, $t1).")");

$t0 = [gettimeofday];
$Ret = CMU::Netdb::auth::get_read_level($dbh, 'wcw', 'outlet', '12989');
$t1 = [gettimeofday];

is($Ret, 0, "get_read_level(wcw/outlet/12989, dT=".
   tv_interval($t0, $t1).")");

# test get_write_level
# FIXME

# test list_users
# FIXME

# test list_groups
# FIXME

# test list_memberships_of_user
# FIXME

# test list_groups_administered_by_user
# FIXME

# test list_members_of_group
# FIXME

# test list_protections
# FIXME

# test add_user
# FIXME

# test add_credentials
# FIXME

# test add_group
# FIXME

# test add_user_to_group
# FIXME

# test add_user_to_protections
# FIXME

# test add_group_to_protections
# FIXME

# test modify_user
# FIXME

# test modify_credentials
# FIXME

# test modify_group
# FIXME

# test modify_user_protection
# FIXME

# test modify_group_protection
# FIXME

# test delete_user_from_group
# test:
#  - invalid user
#  - user, no secondary (valid group)
#  - user, secondary (valid group)
#  - invalid group, valid user
#  - user is not a member of the group
#  - user with no access

# user #4 - credential dufg1 - member of group netreg:dufg1
# user #5 - credential dufg2, dufg2.1 - member of group netreg:dufg2
# user #6 - credential dufg3 - member of netreg:dufg2

# group netreg:dufg1 - id 200
# group netreg:dufg2 - id 201

# invalid user
($Ret, $Data) = CMU::Netdb::auth::delete_user_from_group
  ($dbh, 'netreg', 'nouser', '200');
is($Ret, $errcodes{'EUSER'}, 'delete_user_from_group (invalid user)');

# user with no secondary
($Ret, $Data) = CMU::Netdb::auth::delete_user_from_group
  ($dbh, 'netreg', 'dufg1', '200');
is($Ret, 1, 'delete_user_from_group (valid with no secondary)');

# user with secondary
($Ret, $Data) = CMU::Netdb::auth::delete_user_from_group
  ($dbh, 'netreg', 'dufg2.1', '201');
is($Ret, 1, 'delete_user_from_group (valid with secondary)');

# invalid group
# FIXME - I don't think delete_user_from_group should return 1
# and log this message when the group is invalid. But I'm not
# going to change the existing behavior right now.
$WarnOK = 0;
$SIG{__WARN__} = sub {
  $WarnOK = 1 if ($_[0] =~ /is already not a member of group/);
};
($Ret, $Data) = CMU::Netdb::auth::delete_user_from_group
  ($dbh, 'netreg', 'dufg3', '999');
ok($Ret == 1 && $WarnOK == 1, 'delete_user_from_group (invalid group)');

# user not a member of group
$WarnOK = 0;

($Ret, $Data) = CMU::Netdb::auth::delete_user_from_group
  ($dbh, 'netreg', 'dufg3', '1');
ok($Ret == 1 && $WarnOK == 1,
   'delete_user_from_group (not a member of group)');

$SIG{__WARN__} = '';

# user does not have appropriate access to delete
($Ret, $Data) = CMU::Netdb::auth::delete_user_from_group
  ($dbh, 'dufg1', 'dufg3', '201');
is($Ret, $errcodes{EPERM}, 'delete_user_from_group (no access)');

# test delete_user
# FIXME

# test delete_credentials
# FIXME

# test delete_group
# FIXME

# test delete_user_from_protections
# FIXME

# test delete_protection_tid
# FIXME

# test delete_group_from_protections
# FIXME

# test get_departments
# FIXME

# test get_user_admin_status
# test:
#  X suspended user
#  X user in a netreg:* group (netreg:admins and other)
#  X user not in a netreg group
#  X verify environment (CMU::Netdb::auth::useradm, CMU::Netdb::auth::useradmStatus)

$CMU::Netdb::auth::useradm = 'guas_test1';
$CMU::Netdb::auth::useradmStatus = -1000;
is(CMU::Netdb::auth::get_user_admin_status($dbh, 'guas_test1'), -1000,
   'get_user_admin_status (environment setup)');

is(CMU::Netdb::auth::get_user_admin_status($dbh, 'guas_nouser'), 0,
   'get_user_admin_status (invalid user)');

is($CMU::Netdb::auth::useradm, 'guas_nouser', 'get_user_admin_status (environment 2)');
is($CMU::Netdb::auth::useradmStatus, '0', 'get_user_admin_status (environment 3)');

is(CMU::Netdb::auth::get_user_admin_status($dbh, 'netreg'), 1,
   'get_user_admin_status (netreg)');

is(CMU::Netdb::auth::get_user_admin_status($dbh, 'guas_real1'), 1,
   'get_user_admin_status (real user in netreg:fullread)');

is(CMU::Netdb::auth::get_user_admin_status($dbh, 'guas_real2'), -1,
   'get_user_admin_status (suspended user)');

is(CMU::Netdb::auth::get_user_admin_status($dbh, 'guas_real3'), 0,
   'get_user_admin_status (user in non-netreg group)');

is(CMU::Netdb::auth::get_user_admin_status($dbh, 'guas_real4'), 0,
   'get_user_admin_status (user in no group)');

# test clear_user_admin_status
CMU::Netdb::auth::clear_user_admin_status();
is($CMU::Netdb::auth::useradm, '', 'clear_user_admin_status (useradm)');
is($CMU::Netdb::auth::useradmStatus, 0, 'clear_user_admin_status (useradmStatus)');

# test get_user_deptadmin_status
# test:
#  X user doesn't exist
#  X user in a netreg: group
#  X user in a dept: group
#  X user not in any group

$CMU::Netdb::auth::userdeptadm = 'gudas_test1';
$CMU::Netdb::auth::userdeptadmStatus = -1000;
is(CMU::Netdb::auth::get_user_deptadmin_status($dbh, 'gudas_test1'), -1000,
   'get_user_deptadmin_status (environment setup)');

is(CMU::Netdb::auth::get_user_deptadmin_status($dbh, 'gudas_nouser'), 0,
   'get_user_deptadmin_status (invalid user)');

is($CMU::Netdb::auth::userdeptadm, 'gudas_nouser', 'get_user_deptadmin_status (env 2)');
is($CMU::Netdb::auth::userdeptadmStatus, '0', 'get_user_deptadmin_status (env 3)');

is(CMU::Netdb::auth::get_user_deptadmin_status($dbh, 'netreg'), 0,
   'get_user_deptadmin_status (netreg)');

is(CMU::Netdb::auth::get_user_deptadmin_status($dbh, 'guas_real3'), 1,
   'get_user_deptadmin_status (dept admin)');

is(CMU::Netdb::auth::get_user_deptadmin_status($dbh, 'guas_real4'), 0,
   'get_user_deptadmin_status (user in no group)');

# test clear_user_deptadmin_status
CMU::Netdb::auth::clear_user_deptadmin_status();
is($CMU::Netdb::auth::userdeptadm, '', 'clear_user_deptadmin_status (userdeptadm)');
is($CMU::Netdb::auth::userdeptadmStatus, 0,
   'clear_user_deptadmin_status (userdeptadmStatus)');

# test get_user_group_admin_status
# test:
#  X user in a netreg: group
#  X user in a dept: group with no access
#  X user in a dept: group with level 5 read
#  - user in a dept: group with level 5 write
#  X user not in any group
$CMU::Netdb::auth::usergroupadm = 'gugas_test1';
$CMU::Netdb::auth::usergroupadmStatus = -1000;
is(CMU::Netdb::auth::get_user_group_admin_status($dbh, 'gugas_test1'), -1000,
   'get_user_group_admin_status (environment setup)');

is(CMU::Netdb::auth::get_user_group_admin_status($dbh, 'gugas_nouser'), 0,
   'get_user_group_admin_status (invalid user)');

is($CMU::Netdb::auth::usergroupadm, 'gugas_nouser', 'get_user_group_admin_status (env 2)');
is($CMU::Netdb::auth::usergroupadmStatus, '0', 'get_user_group_admin_status (env 3)');

is(CMU::Netdb::auth::get_user_group_admin_status($dbh, 'netreg'), 1,
   'get_user_group_admin_status (netreg)');

# in a group that has L5 READ
is(CMU::Netdb::auth::get_user_group_admin_status($dbh, 'guas_real3'), 1,
   'get_user_group_admin_status (group member with access)');

# no group
is(CMU::Netdb::auth::get_user_group_admin_status($dbh, 'guas_real4'), 0,
   'get_user_group_admin_status (user in no group)');

# in a group with no access
is(CMU::Netdb::auth::get_user_group_admin_status($dbh, 'gugas_real1'), 0,
   'get_user_group_admin_status (group member/non-group admin)');

# in a group with l5 write directly
is(CMU::Netdb::auth::get_user_group_admin_status($dbh, 'gugas_real2'), 1,
   'get_user_group_admin_status (group member with individual l5 write)');

# test clear_user_group_admin_status
CMU::Netdb::auth::clear_user_group_admin_status();
is($CMU::Netdb::auth::usergroupadm, '', 'clear_user_group_admin_status (usergroupadm)');
is($CMU::Netdb::auth::usergroupadmStatus, 0,
   'clear_user_group_admin_status (usergroupadmStatus)');

# test get_user_netreg_admin
# FIXME

# test auth_prot_op
# FIXME

# test apply_prot_profile
# FIXME
