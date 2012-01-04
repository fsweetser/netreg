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
# $Id: helper.pl,v 1.5 2008/03/27 19:42:36 vitroth Exp $
#
# $Log: helper.pl,v $
# Revision 1.5  2008/03/27 19:42:36  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.4.14.1  2007/10/11 20:59:41  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.4.12.1  2007/09/20 18:43:05  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.4  2004/06/24 02:05:35  kevinm
# * Credentials/machine type pulled to head
#
# Revision 1.3.6.1  2004/06/21 15:53:42  vitroth
# Merging credentials & machine type permissions branches.
# Inital merge complete, no testing done yet.
# Still need to update convert script and schema.
#
# Revision 1.3.2.1  2004/05/28 17:43:01  kevinm
# * CIDR2mask function
#
# Revision 1.3  2004/05/17 15:29:28  kevinm
# * Fixes to deal with different netmon location
#
# Revision 1.2  2004/05/10 21:45:37  kevinm
# *** empty log message ***
#
# Revision 1.1  2004/05/03 20:51:31  kevinm
# * First checkin of test framework
#
#
#

use Test::More tests => 36;

use lib '/usr/ng/lib/perl5';
use lib '../../..';

use CMU::Netdb::t::framework;
use CMU::Netdb::helper;
use CMU::Netdb::config;

# test remove_dept_tag_hash2


# test long2dot
is(long2dot(0), '0.0.0.0', 'long2dot 0');
is(long2dot(2147680001), '128.2.255.1', 'long2dot 128.2.255.1');
is(long2dot(4294967295), '255.255.255.255', 'long2dot 255.255.255.255');

# test dot2long
is(dot2long('0.0.0.0'), 0, 'dot2long 0.0.0.0');
is(dot2long('128.2.255.1'), 2147680001, 'dot2long 128.2.255.1');
is(dot2long('255.255.255.255'), 4294967295, 'dot2long 255.255.255.255');

# test mask2CIDR
is(mask2CIDR('0.0.0.0'), 0, 'mask2CIDR /0');
is(mask2CIDR('255.255.255.0'), 24, 'mask2CIDR /24');
is(mask2CIDR('255.255.255.255'), 32, 'mask2CIDR /32');

is(mask2CIDR(dot2long('0.0.0.0')), 0, 'mask2CIDR /0 (long)');
is(mask2CIDR(dot2long('255.255.0.0')), 16, 'mask2CIDR /16 (long)');
is(mask2CIDR(dot2long('255.255.255.255')), 32, 'mask2CIDR /32 (long)');

# test CIDR2mask
is(CIDR2mask(0), '0.0.0.0', 'CIDR2mask /0');
is(CIDR2mask(8), '255.0.0.0', 'CIDR2mask /8');
is(CIDR2mask(23), '255.255.254.0', 'CIDR2mask /23');
is(CIDR2mask(25), '255.255.255.128', 'CIDR2mask /25');
is(CIDR2mask(32), '255.255.255.255', 'CIDR2mask /32');

# test exec_cleanse
is(exec_cleanse("; evil 'string'"), ' evil ', "exec_cleanse (bad)");
is(exec_cleanse('/usr/bin/foobar ju33@dom.example.com'),
   '/usr/bin/foobar ju33@dom.example.com', 'exec_cleanse (good)');

# test cleanse
is(cleanse("*EXPR: foobar"), 'foobar', 'cleanse (EXPR)');
is(cleanse("testing
with 'bad' data & stuff"), 'testingwith bad data  stuff',
   'cleanse (bad chars)');

my $OKText = '$This# `~ [is] a %test% (of) v@arious **;+=-_ chars / to '.
  '\ "check",. <|> {cleanse}?!';

is(cleanse($OKText), $OKText, 'cleanse (clean data)');

# test splitHostname
{
  my ($H, $D) = ('', '');
  ($H, $D) = splitHostname('bar');
  ok(defined $H && defined $D &&
     $H eq 'bar' && $D eq '', "splitHostname (single label)");

  ($H, $D) = splitHostname('bar.');
  ok(defined $H && defined $D &&
     $H eq 'bar' && $D eq '', "splitHostname (single label, enddot)");

  ($H, $D) = splitHostname('foo.bar');
  ok(defined $H && defined $D &&
     $H eq 'foo' && $D eq 'bar', "splitHostname (2 label)");

  ($H, $D) = splitHostname('foo.bar.');
  ok(defined $H && defined $D &&
     $H eq 'foo' && $D eq 'bar.', "splitHostname (2 label, enddot)");

  ($H, $D) = splitHostname('foo.bar.baz');
  ok(defined $H && defined $D &&
     $H eq 'foo' && $D eq 'bar.baz', "splitHostname (3 label)");

  ($H, $D) = splitHostname('foo.bar.baz.');
  ok(defined $H && defined $D &&
     $H eq 'foo' && $D eq 'bar.baz.', "splitHostname (3 label, enddot)");
}

# test calc_bcast
is(calc_bcast('0.0.0.0', '0.0.0.0'), '255.255.255.255',
   "calc_bcast (0.0.0.0/0)");

is(calc_bcast('128.2.0.0', '255.255.255.0'), '128.2.0.255',
   "calc_bcast (128.2.0.0/24)");

is(calc_bcast('128.2.0.10', '255.255.255.252'), '128.2.0.11',
   "calc_bcast (128.2.0.10/30)");

is(calc_bcast('128.2.0.4', '255.255.255.254'), '128.2.0.5',
   "calc_bcast (128.2.0.4/31)");

# test netdb_mail
SKIP: {
  ($res, $val) = get_multi_conf_var('test-netdb', 'email');
  skip "No configured email address", 1 
    unless ($res eq 1 && defined $val && $val ne '');

  netdb_mail('test-helper.pl', "Testing helper.pl", 'Helper.pm test',
	     '', $val);
  pass("netdb_mail");
}

# test ArpaDate
my $AD = ArpaDate();
ok($AD =~ /^\w{3}, [\ \d]{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} [\-\+]\d{4}$/,
   "ArpaDate format");

# test makemap
my $MMT = ['foo', 'bar', 'baz', 'blam'];
my %MMT_Res = ('blam' => 3,
	       'bar' => 1,
	       'baz' => 2,
	       'foo' => 0);
is_deeply(makemap($MMT), \%MMT_Res, "makemap");

# test lw_db_connect

# test report_db_connect

# test pruneLocks

# test getLock

# test killLock

# test get_sys_key

# test replace_sys_key

# test delete_sys_key

# test unique
my @UT = ('foo', 'bar', 'baz', 'foo', 'blam', 'tag', 'foo', 'baz');
my @UTR = ('foo', 'bar', 'baz', 'blam', 'tag');
my @UTRR = unique(@UT);
is_deeply(\@UTR, \@UTRR, "unique");

# test xaction_begin

# test xaction_commit

# test xaction_rollback

# test netdb_debug
