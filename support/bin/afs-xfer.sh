#! /bin/sh
#
# Copies files into AFS
# Author: Kevin Miller
#
# $Id: afs-xfer.sh,v 1.13 2003/03/12 15:58:12 kevinm Exp $
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

AFSRWDIR=/afs/.andrew

## END Vars ##

if [ ! -f $AFSRWDIR/common/etc/passwd ]; then
    # assume AFS is currently down
    exit 0
fi

/usr/local/bin/kauth -n $NRUSER -f $NRHOME/etc/.srvtab -l 15 >& /dev/null

## /etc/hosts
MRHOME=$NRHOME/etc/misc-reports
HOSTLOC=/afs/.andrew/common/etc
/bin/cp $MRHOME/hosts $HOSTLOC/hosts.new
if [ -f $HOSTLOC/hosts.new ]; then
    mv $HOSTLOC/hosts.new $HOSTLOC/hosts
fi

## bootptab
BPLOC=/afs/.andrew/data/db/net/bootp
/bin/cp $MRHOME/bootptab $BPLOC/bootptab.new
if [ -f $BPLOC/bootptab.new ]; then
    mv $BPLOC/bootptab.new $BPLOC/bootptab
fi
/bin/cp $MRHOME/bootptab-dynamic $BPLOC/bootptab-dynamic.new
if [ -f $BPLOC/bootptab-dynamic.new ]; then
    mv $BPLOC/bootptab-dynamic.new $BPLOC/bootptab-dynamic
fi

## other reports
OUTLETLOC=/afs/.andrew/data/db/net/netdb/outlets
for f in building-list all-switches all-hubs; do
/bin/cp $MRHOME/$f $OUTLETLOC/$f.new
if [ -f $OUTLETLOC/$f.new ]; then
    mv $OUTLETLOC/$f.new $OUTLETLOC/$f
fi
done

## DNS Zones
ZXHOME=$NRHOME/etc/zone-xfer
ZONELOC=/afs/.andrew/data/db/net/netdb/dns
for f in `cd $ZXHOME; ls *.zone`; do
/bin/cp $ZXHOME/$f $ZONELOC/$f.new
if [ -f $ZONELOC/$f.new ]; then
    mv $ZONELOC/$f.new $ZONELOC/$f
fi
done

## DNS Configs
ZCHOME=$NRHOME/etc/zone-config
ZONELOC=/afs/.andrew/data/db/net/netdb/config
for f in `cd $ZCHOME; ls`; do
/bin/cp $ZCHOME/$f $ZONELOC/$f.new
if [ -f $ZONELOC/$f.new ]; then
    mv $ZONELOC/$f.new $ZONELOC/$f
fi
done

## DHCP Configuration
DXHOME=$NRHOME/etc/dhcp-xfer
DHCPLOC=/afs/.andrew/data/db/net/netdb/dhcp
for f in `cd $DXHOME; ls`; do
/bin/cp $DXHOME/$f $DHCPLOC/$f.new
if [ -f $DHCPLOC/$f.new ]; then
    mv $DHCPLOC/$f.new $DHCPLOC/$f
fi
done

## CS Hosts report
MRHOME=$NRHOME/etc/misc-reports
HOSTLOC=/afs/.andrew/data/db/net/netdb/reports/scs
/bin/cp $MRHOME/cs/*.csv $HOSTLOC

## Group loader needs to run with creds
/home/netreg/bin/grloader.pl

## Release db.net.011 volume
echo "release-vol db.net.011"|/usr/local/bin/adm -host admsrv.andrew.cmu.edu > /dev/null

/usr/local/bin/unlog
