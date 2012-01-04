#!/bin/sh
#
# Runs the various domain dumps for CS (and possibly others)
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
#

# -BEGIN-CONFIG-BLOCK-

## Warning! The contents of this file between BEGIN-CONFIG-BLOCK and
## END-CONFIG-BLOCK are updated from vars-update.pl

## NRHOME should be set to the NetReg home directory
NRHOME=/home/netreg

## NRUSER should be set to the default NetReg user
NRUSER=netreg

MYSQL_PATH=/usr/local/bin
MYSQL=/mysql
MYSQLDUMP=/mysqldump

# -END-CONFIG-BLOCK-

echo $NRHOME

LOC=/home/netreg/bin

$LOC/domain-report.pl CAT.CMU.EDU cs/cat_cmu_edu
$LOC/domain-report.pl CS.CMU.EDU cs/cs_cmu_edu
$LOC/domain-report.pl DISTANCE.CMU.EDU cs/distance_cmu_edu
$LOC/domain-report.pl DISTANCE-EDUCATION.CMU.EDU cs/distance_education_cmu_edu
$LOC/domain-report.pl ECOM.CMU.EDU cs/ecom_cmu_edu
$LOC/domain-report.pl EDRC.CMU.EDU cs/edrc_cmu_edu
$LOC/domain-report.pl ETC.CMU.EDU cs/etc_cmu_edu
$LOC/domain-report.pl HCII.CMU.EDU cs/hcii_cmu_edu
$LOC/domain-report.pl ICES.CMU.EDU cs/ices_cmu_edu
$LOC/domain-report.pl ISRI.CMU.EDU cs/isri_cmu_edu
$LOC/domain-report.pl ITC.CMU.EDU cs/itc_cmu_edu
$LOC/domain-report.pl RI.CMU.EDU cs/ri_cmu_edu
$LOC/domain-report.pl SCS.CMU.EDU cs/scs_cmu_edu

exit 0
