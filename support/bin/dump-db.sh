#! /bin/sh
#
# dump-db: Periodically can be run to dump the database and tarball it up. 
# Useful for backups
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
# $Id: dump-db.sh,v 1.11 2008/03/27 19:42:41 vitroth Exp $
#
# $Log: dump-db.sh,v $
# Revision 1.11  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.10.20.1  2007/10/11 20:59:46  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.10.18.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.10  2004/02/17 22:20:19  kevinm
# * Don't archive the _sys_change* log tables
#
# Revision 1.9  2002/08/11 16:25:10  kevinm
# * Date change
#
# Revision 1.8  2002/05/06 19:18:51  kevinm
# * Use the canonical variables
#
# Revision 1.7  2002/03/07 05:28:43  kevinm
# * Various modifications
#
# Revision 1.6  2002/01/30 20:45:35  kevinm
# Fixed vars_l
#
# Revision 1.5  2001/07/20 22:02:24  kevinm
# *** empty log message ***
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
MYSQL=$MYSQL_PATH/mysql
MYSQLDUMP=$MYSQL_PATH/mysqldump

# -END-CONFIG-BLOCK-

### Edit the following variables if necessary
PWFILE=$NRHOME/etc/.password-maint
DATE=`/bin/date +%Y-%m-%d.%H%M`
DUMPDIR=/data/dumps
DIR=$DUMPDIR/netdb.$DATE
DBUSER=database
### END ###


mkdir $DIR
chown $DBUSER $DIR

$MYSQLDUMP -l --add-locks -u netreg-maint --host=localhost -p`/bin/cat $PWFILE` -T $DIR netdb
# Hack to not tar up the ever-growing log tables
rm $DIR/_sys_change*
/bin/tar zcf $DIR.tgz $DIR
/bin/rm -rf $DIR

/usr/bin/find $DUMPDIR -mtime +30 -exec rm {} \;
