#   -*- perl -*-
#
# CMU::Helper
#   This module provides many general helper functins for use
#    with CMU Programming Projects
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
# $Id: Helper.pm,v 1.5 2007/05/21 16:04:55 fk03 Exp $
#

# First we define what package/module this is, and set some ground rules.

package CMU::Helper;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug);


use CMU::Helper::Pstatus qw(pstatus tftp_queue);
use CMU::Helper::SendMail qw(sendMail setDebug);
use CMU::Helper::Funcs qw(
			  makemap
			  long2dot
			  dot2long
			  mask2CIDR
			  CIDR2mask
			  ArpaDate
			  makeHash
			  hier_sort
			 );


require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw();

# Now we'll define some globals we'll be using in our package
$debug = 0;


1;


