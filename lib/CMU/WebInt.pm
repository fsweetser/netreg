#   -*- perl -*-
#
# CMU::WebInt
# This module provides the web interface to the CMU::Netdb components.
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
# $Id: WebInt.pm,v 1.28 2008/04/24 13:53:15 vitroth Exp $
#
# $Log: WebInt.pm,v $
# Revision 1.28  2008/04/24 13:53:15  vitroth
# moved switch_panel_config loading into the block that tests if outlets are
# enabled.
#
# Revision 1.27  2008/03/27 19:42:33  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.26.8.1  2007/10/11 20:59:38  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.26.6.1  2007/09/20 18:43:03  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.26  2006/02/23 15:50:38  vitroth
# Disable switch/panel reports unless outlets are enabled.
#
# Revision 1.25  2005/06/29 22:04:25  fes
# Back out changes that missed the branch and hit HEAD
#
# Revision 1.23  2005/05/09 20:25:15  fk03
# Initial release of Switch/panel configuration report
#
# Revision 1.22  2004/03/25 20:14:20  kevinm
# * Merging netdb-layer2-branch2
#
# Revision 1.21.2.1  2004/02/25 19:27:22  kevinm
# * Merging config changes with layer2 changes
#
# Revision 1.21  2004/02/20 03:07:23  kevinm
# * External config file updates
#
# Revision 1.20.2.1  2003/11/29 06:28:54  ktrivedi
# NR-VLAN support
#
# Revision 1.20  2002/10/23 19:15:53  ebardsle
# VLAN support
#
# Revision 1.19  2002/08/26 01:04:14  kevinm
# * Get config.pm loaded before we try using it
#
# Revision 1.18  2002/08/22 20:23:51  kevinm
# * Completely disable modules that pertain to pieces of the system that have
#   been disabled.
#
# Revision 1.17  2002/07/18 03:47:48  kevinm
# * Added quickreg
#
# Revision 1.16  2002/02/27 18:26:47  kevinm
# Added scheduler file
#
# Revision 1.15  2002/01/10 03:43:34  kevinm
# Updated copyright.
#
# Revision 1.14  2002/01/03 20:54:46  kevinm
# Added configuration modules.
#
# Revision 1.13  2001/11/05 21:14:14  kevinm
# Addition of service stuff.
#
# Revision 1.12  2001/09/20 20:30:13  vitroth
# Updates for Perl5.6 Merging into Mainline.  All ready for deployment
# with any luck.
#
# Revision 1.11  2001/07/20 22:22:20  kevinm
# Copyright info
#
# Revision 1.10.2.1  2001/07/20 15:45:02  kevinm
# First round of changing stuff around for perl5.6
#
# Revision 1.10  2001/03/14 17:08:27  vitroth
# Cleaning up 'use' lines.
#
# Revision 1.9  2000/07/31 15:39:14  kevinm
# *** empty log message ***
#
# Revision 1.8  2000/07/19 17:35:48  kevinm
# Minor changes to add new files
#
# Revision 1.7  2000/06/30 03:02:05  kevinm
# Added new WebInt modules
#
# Revision 1.6  2000/06/28 21:58:09  kevinm
# Committing a bunch of changes.
#
# Revision 1.5  2000/06/23 06:14:41  kevinm
# *** empty log message ***
#
# Revision 1.4  2000/06/14 01:23:09  kevinm
# Just tweaking the top level files a bit...
#
# Revision 1.3  2000/06/08 22:34:58  kevinm
# More modules....
#
# Revision 1.2  2000/05/25 18:37:22  kevinm
# The WebInt auth stuff works now.
#
# Revision 1.1  2000/05/23 19:01:14  kevinm
# Initial checkin.
#
#
#

package CMU::WebInt;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK);
use CMU::Netdb;

BEGIN {
  require CMU::Netdb::config; import CMU::Netdb::config;
}

# our packages
use CMU::WebInt::auth;
BEGIN {
  my ($res, $EB) = CMU::Netdb::config::get_multi_conf_var('webint',
							  'ENABLE_BUILDINGS');
  if ($res == 1 && $EB == 1) {
    require CMU::WebInt::buildings; import CMU::WebInt::buildings;
  }
}


use CMU::WebInt::dhcp;
use CMU::WebInt::dns;
use CMU::WebInt::errors;
use CMU::WebInt::helper;
use CMU::WebInt::interface;
use CMU::WebInt::mach_dns;
use CMU::WebInt::machines;

BEGIN {
  my ($res, $EN) = CMU::Netdb::config::get_multi_conf_var('webint',
							  'ENABLE_NETWORKS');
  if ($res == 1 && $EN == 1) {
    require CMU::WebInt::networks; import CMU::WebInt::networks;
  }
}

BEGIN {
  my ($res, $ECO) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_CABLES_OUTLETS');
  my ($res2, $ETS) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_TRUNK_SET');

  if ($res == 1 && $ECO == 1) {
    if ($res2 == 1 && $ETS == 1) {
	require CMU::WebInt::trunkset; import CMU::WebInt::trunkset;
    }
    require CMU::WebInt::cables; import CMU::WebInt::cables;
    require CMU::WebInt::outlet_act; import CMU::WebInt::outlet_act;
    require CMU::WebInt::outlet_type; import CMU::WebInt::outlet_type;
    require CMU::WebInt::outlets; import CMU::WebInt::outlets;
    require CMU::WebInt::switch_panel_config; import CMU::WebInt::switch_panel_config;
  }
}

use CMU::WebInt::protections;

BEGIN {
  my ($res, $EQR) = CMU::Netdb::config::get_multi_conf_var('webint',
							   'ENABLE_QUICKREG');
  if ($res == 1 && $EQR == 1) {
    require CMU::WebInt::quickreg; import CMU::WebInt::quickreg;
  }
}

use CMU::WebInt::reports;
use CMU::WebInt::services;
use CMU::WebInt::scheduled;
use CMU::WebInt::subnets;
use CMU::WebInt::vars;
use CMU::WebInt::vlans;
use CMU::WebInt::zones;


{
  no strict;
  $VERSION = '0.01';
}

use Exporter;
@ISA = qw(Exporter);
