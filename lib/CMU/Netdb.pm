#   -*- perl -*-
#
# CMU::Netdb
# This module provides the primary API to the Netdb.  Functions which 
# will be used by applications directly.
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
#
# 
# $Id: Netdb.pm,v 1.14 2008/03/27 19:42:33 vitroth Exp $
#
# $Log: Netdb.pm,v $
# Revision 1.14  2008/03/27 19:42:33  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.13.20.1  2007/10/11 20:59:38  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.13.18.1  2007/09/20 18:43:03  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.13  2004/03/25 20:14:20  kevinm
# * Merging netdb-layer2-branch2
#
# Revision 1.12.2.1  2004/02/25 21:51:42  ktrivedi
# New module vlan_trunkset.pm
#
# Revision 1.12  2004/02/20 03:07:05  kevinm
# * External config file updates
#
# Revision 1.11  2002/08/16 17:14:29  kevinm
# * Final 1;
#
# Revision 1.10  2002/01/10 03:43:34  kevinm
# Updated copyright.
#
# Revision 1.9  2002/01/03 20:54:46  kevinm
# Added configuration modules.
#
# Revision 1.8  2001/11/05 21:14:14  kevinm
# Addition of service stuff.
#
# Revision 1.7  2001/07/20 22:22:20  kevinm
# Copyright info
#
# Revision 1.6  2001/03/14 17:08:27  vitroth
# Cleaning up 'use' lines.
#
# Revision 1.5  2000/06/14 01:23:09  kevinm
# Just tweaking the top level files a bit...
#
# Revision 1.4  2000/06/05 20:20:29  vitroth
# Added machines_subnets.pm and appropriate entries to Netdb.pm
#
# Revision 1.3  2000/06/05 19:44:06  vitroth
# Added the 'use' entry for buildings_cables.pm
#
# Revision 1.2  2000/05/19 19:38:56  vitroth
# Added entries for new modules.
#
# Revision 1.1  2000/04/04 21:38:22  vitroth
# Initial checkin on Netdb.pm
#
#

# First we define what package/module this is, and set some ground rules.

package CMU::Netdb;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug);
use DBI;
use CMU::Netdb::auth;
use CMU::Netdb::buildings_cables;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::primitives;
use CMU::Netdb::reports;
use CMU::Netdb::services;
use CMU::Netdb::structure;
use CMU::Netdb::validity;
use CMU::Netdb::vlan_trunkset;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw();

# Now we'll define some globals we'll be using in our package
$debug = 0;

BEGIN {
  # Load the configuration stuff early so that we can conditionally include
  # other modules.
  require CMU::Netdb::config; import CMU::Netdb::config;
}


1;


