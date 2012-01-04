#! /usr/bin/perl
#
# startup.pl: Pre-load useful modules into Apache
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
# $Id: startup.pl,v 1.6 2008/03/27 19:42:33 vitroth Exp $
#
# $Log: startup.pl,v $
# Revision 1.6  2008/03/27 19:42:33  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.5.14.1  2007/10/11 20:59:38  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.5.12.1  2007/09/20 18:43:03  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.3  2002/01/10 03:41:44  kevinm
# Updated copyright.
#
# Revision 1.2  2001/07/20 22:08:31  kevinm
# *** empty log message ***
#
#
use strict;

use lib "/usr/ng/lib/perl5";
use lib "/home/netreg/lib";

$ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/ or die "GATEWAY_INTERFACE not perl!";

use Apache::Registry();

use CGI (); 
#CGI->compile(':all');
use CGI::Carp ();
use DBI;
use DBD::mysql;
use CMU::Netdb;
use CMU::WebInt;

1;
