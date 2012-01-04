#! /bin/sh

# Dump the current database (referenced by t-test-netdb-conf:test-db)
# $Id: dump.sh,v 1.3 2008/03/27 19:42:36 vitroth Exp $
#
# Kevin Miller - 11 Jun 2004

# This is useful when there are database schema changes and you want to convert
# the various DB data files in this directory to the new schema. Run, for example:
#
# $ cd /path/to/OLD/CVS/TREE/lib/CMU/Netdb/t
# $ reload.sh db-primitives-1
# Loading db-primitives-1...done
# Optimizing database...done
# 
# This should be run in a CVS tree with the old schema. Then run the conversion
# script (e.g. support/convert/convert-OLDVER-NEWVER.pl). Then dump:
# $ cd /path/to/NEW/CVS/TREE/lib/CMU/Netdb/t
# $ dump.sh db-primitives-1
# Dumping db-primitives-1...done
#
# At this point you should be able to immediately reload the file:
# $ reload.sh db-primitives-1
#
# Note that "reload" ALWAYS uses the schema from the current tree 
# (doc/db/NETREG-COMPLETE.sql).
#
# Now you should be able to use the test framework in a CVS tree with the
# new schema (in doc/db/NETREG-COMPLETE.sql) and the data will load.

perl -I../../.. -I/usr/ng/lib/perl5 -MCMU::Netdb::t::framework -e "dump_db('$1')"
