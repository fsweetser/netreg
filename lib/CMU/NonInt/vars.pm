#   -*- perl -*-
#
# CMU::NonInt::vars
# This module defines some basic variables to be used
# 
# $Id: vars.pm,v 1.3 2008/03/27 19:42:36 vitroth Exp $
#
# $Log: vars.pm,v $
# Revision 1.3  2008/03/27 19:42:36  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.2.26.1  2007/10/11 20:59:41  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.2.24.1  2007/09/20 18:43:05  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.2  2001/06/28 22:45:47  vitroth
# Next phase complete
#
# Revision 1.1  2001/06/25 19:18:08  vitroth
# Initial checkin of netreg noninteractive interface.  Partially implemented.
#
#
#


package CMU::NonInt::vars;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %sections $REALM %realms
	    $DEF_ITEMS_PER_PAGE $DEF_MAX_PAGES
	    $MACHINES_PER_PAGE %opcodes %htext
	   );

require Exporter;
@ISA = qw(Exporter);

# operations
# per user, list machines, list outlets, list departments
# per machine, list all info, including owner/group
# per outlet, list all info, including owner/group

%opcodes = ('user_list_machines' => \&CMU::NonInt::mach::list_machines_by_user,
	    'user_list_outlets' => \&CMU::NonInt::outlet::list_outlets_by_user,
#	    'user_list_departments' => \&CMU::NonInt::auth::list_user_departments,
	    'mach_view' => \&CMU::NonInt::mach::mach_view,
	    'outlet_view' => \&CMU::NonInt::outlet::outlet_view,
	    );


1;
