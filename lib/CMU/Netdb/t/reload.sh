#! /bin/sh

# Reload the current database (referenced by t-test-netdb-conf:test-db)
# $Id: reload.sh,v 1.3 2008/03/27 19:42:36 vitroth Exp $
#
# Kevin Miller - 11 Jun 2004

# See dump.sh for comments on how reload.sh and dump.sh are used

perl -I../../.. -I/usr/ng/lib/perl5 -MCMU::Netdb::t::framework -e "reload_db('$1')"
