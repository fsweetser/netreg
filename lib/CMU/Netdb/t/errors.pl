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
# $Id: errors.pl,v 1.2 2008/03/27 19:42:36 vitroth Exp $
#
# $Log: errors.pl,v $
# Revision 1.2  2008/03/27 19:42:36  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.1.20.1  2007/10/11 20:59:41  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.1.18.1  2007/09/20 18:43:04  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.1  2004/05/20 18:02:06  kevinm
# * Check the errors module
#
#
#

use Test::More tests => 2;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

use strict;

use lib '/usr/ng/lib/perl5';
use lib '../../..';

use CMU::Netdb::t::framework;
use CMU::Netdb::errors;
use CMU::Netdb::config;

## BEGIN TESTING

# Pretty simple verification
my $OK = 1;
my %ValID;
foreach my $Code (keys %CMU::Netdb::errors::errcodes) {
  my $ID = $CMU::Netdb::errors::errcodes{$Code};
  $OK = "Undefined meaning: $Code"
    unless (defined $CMU::Netdb::errors::errmeanings{$ID});
  $ValID{$ID} = $Code;
}
is($OK, 1, "all codes have defined meanings");

$OK = 1;
foreach my $ID (keys %CMU::Netdb::errors::errmeanings) {
  $OK = "Undefined code: $ID"
    unless (defined $ValID{$ID});
}
is($OK, 1, "all meanings correspond to defined codes");



