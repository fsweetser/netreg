#!/usr/bin/perl
#
# netreg-nonint.pl
#
# This is the script that will be used by programs accessing netreg
# remotely.  I.e. not user access, non-interactive access.
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
# $Id: netreg-nonint.pl,v 1.6 2008/03/27 19:42:08 vitroth Exp $
#
# $Log: netreg-nonint.pl,v $
# Revision 1.6  2008/03/27 19:42:08  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.5.22.1  2007/10/04 22:00:00  vitroth
# commit duke changes in /bin (trivial changes)
#
# Revision 1.5.20.1  2007/09/20 18:42:58  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:39  kcmiller
#
#
# Revision 1.5  2002/08/11 16:21:54  kevinm
# * Removed non-useful path
#
# Revision 1.4  2002/01/30 21:48:48  kevinm
# Fixed copyright
#
# Revision 1.3  2001/11/29 06:53:46  kevinm
# Added deptadmin clear
#
# Revision 1.2  2001/07/20 22:22:19  kevinm
# Copyright info
#
# Revision 1.1  2001/06/25 19:18:08  vitroth
# Initial checkin of netreg noninteractive interface.  Partially implemented.
#
#
#

use strict;

use lib '/home/netreg/lib';

use CMU::NonInt;
use CMU::Netdb;
use CGI::Carp qw(fatalsToBrowser);
use CGI;# qw(-debug);

my $q = new CGI;

my $op = $q->param('op');
CMU::Netdb::auth::clear_user_admin_status();
CMU::Netdb::auth::clear_user_group_admin_status();
CMU::Netdb::auth::clear_user_deptadmin_status();

if ($op eq '' || !defined $CMU::NonInt::vars::opcodes{$op}) {
  die "No operation specified, $op";
} else {
  $CMU::NonInt::vars::opcodes{$op}->($q);
};


