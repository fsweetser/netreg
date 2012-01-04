#   -*- perl -*-
#
# CMU::NonInt::auth
#
# 
# $Id: auth.pm,v 1.2 2008/03/27 19:42:36 vitroth Exp $
# 
# $Log: auth.pm,v $
# Revision 1.2  2008/03/27 19:42:36  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.1.26.1  2007/10/11 20:59:41  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.1.24.1  2007/09/20 18:43:05  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.1  2001/06/25 19:18:08  vitroth
# Initial checkin of netreg noninteractive interface.  Partially implemented.
#
#
#



package CMU::NonInt::auth;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK);
use CMU::Netdb;
use CGI;
use DBI;



require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw();

1;
