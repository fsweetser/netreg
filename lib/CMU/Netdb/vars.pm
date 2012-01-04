#  -*- perl -*-
#
# CMU::Netdb::vars
# Define Queries and Query_Tables hashes.
#
# Copyright 2001 Carnegie Mellon University 
#
# All Rights Reserved
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted,
# provided that the above copyright notice appear in all copies and that
# both that copyright notice and this permission notice appear in
# supporting documentation, and that the name of CMU not be
# used in advertising or publicity pertaining to distribution of the
# software without specific, written prior permission.
# 
# CMU DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
# ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
# CMU BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
# ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
# ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
# SOFTWARE.
#
# $Id: vars.pm,v 1.5 2006/11/15 14:23:59 vitroth Exp $
#
# $Log: vars.pm,v $
# Revision 1.5  2006/11/15 14:23:59  vitroth
# Added expired machines/outlets per department report.
#
# Revision 1.4  2001/08/08 14:27:57  vitroth
# Somehow this file got modified to be the one from WebInt.  Probably
# my fault somehow... rolling back.
#
# Revision 1.2  2001/07/20 20:12:28  kevinm
# Bringing back to the mainline
#
# Revision 1.1.2.1  2001/07/20 20:11:02  kevinm
# Added copyright, NO changes for perl56-compat.
#
#
#

package CMU::Netdb::vars;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %Queries %Query_Tables
	   );

require Exporter;
@ISA = qw(Exporter);

%Queries = ( 
	    # used by WebInt::reports::rep_dept_mach
	    'count_machines_departments' => 
	    "select groups.name, mode, count(mode) as total
             from protections, groups, machine
             where   identity < 0  
                     AND tname='machine' 
                     AND groups.name LIKE 'dept:%' 
                     AND identity*-1 = groups.id 
                     AND tid=machine.id
             group by groups.name, mode",

	    # used by WebInt::report::rep_outlet_util and bin/outlet_machine_report.pl
	    'count_outlettypes_departments' => 
            "select groups.name,outlet_type.name as type,count(type) as total 
             from protections,groups,outlet,outlet_type 
             where   identity < 0  
                     AND tname='outlet' 
                     AND groups.name LIKE 'dept:%' 
                     AND identity*-1 = groups.id 
                     AND tid=outlet.id 
                     AND outlet.type = outlet_type.id 
                     group by groups.name, type",

	    # used by WebInt::reports::rep_expired_mach
	    'count_expired_machines_departments' => 
	    "select groups.name, 'expired', count(machine.id) as expired
             from protections, groups, machine
             where   identity < 0  
                     AND tname='machine' 
                     AND groups.name LIKE 'dept:%' 
                     AND identity*-1 = groups.id 
                     AND tid=machine.id
                     AND machine.expires
             group by groups.name",

	    # used by WebInt::report::rep_expired_outlet
	    'count_expired_outlets_departments' => 
            "select groups.name, 'expired', count(outlet.id) as expired
             from protections,groups,outlet
             where   identity < 0  
                     AND tname='outlet' 
                     AND groups.name LIKE 'dept:%' 
                     AND identity*-1 = groups.id 
                     AND tid=outlet.id 
                     AND outlet.expires
                     group by groups.name",


	    # used by bin/outlet_machine_report.pl
	    'count_wiredmachines_departments' => 
            "select groups.name, mode, count(mode) as total
             from protections, groups, machine, subnet
             where   identity < 0  
                     AND tname='machine' 
                     AND groups.name LIKE 'dept:%' 
                     AND abbreviation != 'wireless' AND abbreviation != 'ADSL'
                     AND identity*-1 = groups.id 
                     AND tid=machine.id 
                     AND machine.ip_address_subnet = subnet.id
             group by groups.name, mode",

	    # used by bin/outlet_machine_report.pl
	    'count_subnetabbrev-machines_departments' =>
             "select groups.name, mode, count(mode) as total
             from protections, groups, machine, subnet
             where   identity < 0  AND 
                     tname='machine' AND 
                     groups.name LIKE 'dept:%' AND 
                     abbreviation = ? AND
                     identity*-1 = groups.id AND 
                     tid=machine.id AND
                     machine.ip_address_subnet = subnet.id
             group by groups.name, mode",

	    # used by bin/outlet_machine_report.pl
	    'list_description_departments' => 
	    "select groups.name, groups.description 
             from groups
             where groups.name LIKE 'dept:%'"

           );

%Query_Tables = (
		 'count_machines_departments' => ['machine'],
		 'count_outlettypes_departments' => ['outlet'],
		 'count_wiredmachines_departments' => ['machine'],
		 'count_subnetabbrev-machines_departments' => ['machine']
		);
