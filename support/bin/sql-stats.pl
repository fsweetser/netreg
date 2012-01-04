#! /usr/bin/perl
#
# Log data about the SQL server
#
# Copyright (c) 2002 Carnegie Mellon University. All rights reserved.
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
#
# $Id: sql-stats.pl,v 1.3 2008/03/27 19:42:44 vitroth Exp $
# 
# $Log: sql-stats.pl,v $
# Revision 1.3  2008/03/27 19:42:44  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.2.20.1  2007/10/11 20:59:47  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.2.18.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.2  2004/02/20 03:18:11  kevinm
# * External config file updates
#
# Revision 1.1  2002/04/23 16:04:06  kevinm
# * Basic script for automatically grabbing SQL stats, so that we can do interesting things with them
#
#
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::config;

my ($vres, $NRHOME) = CMU::Netdb::config::get_multi_conf_var('netdb','NRHOME');
my $PWDFILE = $NRHOME."/etc/.password-u=stat";
my $ADMIN = '/usr/local/bin/mysqladmin';
my $LOGFILE = $NRHOME."/etc/db-statlog";
my $INTERVAL = 30; # seconds

open(FILE, $PWDFILE) || die "Cannot open password file $PWDFILE";
my $Password = <FILE>;
close(FILE);

while(1) {
  my $Now = time();
  my $PrNow = localtime($Now);
  open(FILE, ">>$LOGFILE") || die "Cannot open logfile $LOGFILE";
  print FILE "--MARK Time: $Now [$PrNow]\n";
  close(FILE);

  `$ADMIN -u stat -p$Password status >> $LOGFILE`;
  
  sleep($INTERVAL);
}

