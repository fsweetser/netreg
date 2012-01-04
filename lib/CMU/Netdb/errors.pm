#
# CMU::Netdb::errors
# This module provides the common error codes, and their
# human readable translations
#
# Copyright 2001-2004 Carnegie Mellon University
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
# $Id: errors.pm,v 1.38 2008/03/27 19:42:35 vitroth Exp $
#
#

package CMU::Netdb::errors;
use strict;
use vars qw(@ISA @EXPORT %errcodes %errmeanings);

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(%errcodes %errmeanings);

%errcodes = ("ERROR" => 0,
	     "EINVALID" => -1,
	     "EPERM" => -2,
	     "EUSER" => -3,
	     "EGROUP" => -4,
	     "ENOENT" => -5,
	     "EEXISTS" => -6,
	     "ESTALE" => -7,
	     "EPARTIAL" => -8,
	     "EDB" => -9,
	     "EDATA" => -10,
	     "ETOOLONG" => -11,
	     "EINVCHAR" => -12,
	     "ESETMEM" => -13,
	     "ENONUM" => -14,
	     "EDOMAIN" => -15,
	     "ESUBNET" => -16,
	     "ENOIP" => -17,
	     "EBADIP" => -18,
	     "ENOIWANTTOBEBLANK" => -19,
	     "EHOST" => -20,
	     "EBLANKSET" => -21,
	     "EBLANK" => -22,
	     "EINUSE" => -23,
	     "EBROADCAST" => -24,
	     "ENORESTYPE" => -25,
	     "ENOOPTTYPE" => -26,
	     "ENOOUTTYPE" => -27,
	     "ENOCABLE" => -28,
	     "ERANGE" => -29,
	     "EUNKSTATE" => -30,
	     "EINVTRANS" => -31,
	     "EINCDNSRES" => -32,
	     "ESYSTEM" => -33,
	     "EMACHCASCADE" => -34,
	     "ENODYNAMIC" => -35,
	     "ENOTFOUND" => -36,
	     "ENOSTATIC" => -37,
	     "EQUOTA" => -38,
# specific error codes for static/dynamic quotas are deprecated
	     "ESTATICQUOTA" => -38,
	     "EDYNAMICQUOTA" => -39,
	     "ENODNSSOFT" => -40,
	     "ENODNSSERV" => -41,
	     "ENODNSCONF" => -42,
	     "ESERVICE" => -43,
             "ETOOSHORT" => -44,
	     "ENUMATTRS" => -45,
	     "EDOF2MTOKENS" => -46,
	     "ENOSECONDARY" => -47,
	     "ESECONDARY" => -48,
	     "ESECONDARYQUOTA" => -49,
	     "ECASCADEDEPTH" => -50,
	     "ECASCADEFATAL" => -51,
	     "EUSERSUSPEND" => -52,
	     "ENOCONFVAR" => -53,
	     "ENONETSEGMENT" => -54,
	     "EDEVPORTEXIST" => -55,
	     "EDEVNETMISMATCH" => -56,
	     "EDEVTRUNKSETMISMATCH" => -57,
	     "EINVFIELD" => -58,
	     "EINVREF" => -59,
	     "ELEASEDIRREAD" => -60,
	     "EOPEN" => -61,
	     "ENOFILEFOUND" => -62,
	     "ELEASEQUERYSTRING" => -63,
	     "EMAXMAC" => -64
	    );

%errmeanings = (0 => "Unknown Error",
		-1 => "Insufficient or Invalid Data",
		-2 => "Not Authorized",
		-3 => "No Such User",
		-4 => "No Such Group",
		-5 => "No Such Entry",
		-6 => "Entry Already Exists",
		-7 => "Entry Changed, Retry",
		-8 => "Partial Failure in Multi-Step Process, Retry",
		-9 => "Database Error: ",
		-10 => "Data Format (General Error)",
		-11 => "Data Format: String too long",
		-12 => "Data Format: Invalid characters",
		-13 => "Data Format: Invalid set member",
		-14 => "Data Format: Non-numeric components",
		-15 => "Domain does not exist, or you do not have access to use this domain",
		-16 => "Subnet does not exist, or you do not have access to use this subnet",
		-17 => "No more IPs available in the subnet",
		-18 => "IP address/host name/mac address not allowed on the requested subnet",
		-19 => "Entry must be blank",
		-20 => "Host does not exist, or you do not have access to use this host",
		-21 => "Set may not be blank",
		-22 => "Entry may not be blank",
		-23 => "Entry still in use",
		-24 => "Error setting mode/address for broadcast/base address",
		-25 => "DNS Resource Type does not exist, or you do not have access to use this DNS Resource Type",
		-26 => "DHCP Option Type does not exist, or you do not have access to use this Option",
		-27 => "Outlet Type does not exist, or you do not have access to use this outlet type",
		-28 => "Cable does not exist, or you do not have access to use this cable",
		-29 => "Data Format: Out of range",
		-30 => "Unknown outlet state",
		-31 => "Invalid outlet state transition",
		-32 => "DNS Resource Fields inconsistent with DNS Resource Type",
		-33 => "General System Error",
		-34 => "Error while cascade updating/deleting machine records",
		-35 => "Subnet does not allow dynamic addresses",
		-36 => "No items matching search (and readable) found.",
		-37 => "Subnet does not allow new static addresses",
                -38 => "Your quota of registrations of this type on this subnet has been exceeded",
                -39 => "Your quota of dynamic registrations on this subnet has been exceeded",
		-40 => "DNS Server Software does not exist",
		-41 => "DNS Server does not exist",
		-42 => "DNS Server Configuration does not exist",
		-43 => "Machine is listed as being part of a service group. (e.g. DNS Server, DHCP Server, LB Pool)",
		-44 => "Data Format: String too short",
		-45 => "Maximum number of attributes of type exceeded.",
		-46 => "Invalid DHCP Option Format: Too many tokens",
		-47 => "Subnet does not allow secondary registrations",
		-48 => "Secondary IP Addresses still exists for this machine",
      		-49 => "Your quota of secondary registrations for this subnet has been exceeded",
		-50 => "Cascade deletion depth exceeded; possible loop",
		-51 => "Cascade deletion fatal error: dependent records exist",
		-52 => "User access to NetReg is suspended",
		-53 => "The specified configuration variable doesn't exist",
		-54 => "Network Segment does not exist.",
		-55 => "Trying to bind more then one outlet to same device and port",
		-56 => "Selected Device is not present in selected Network Segment",
		-57 => "Selected Device is not present in Trunk Set",
		-58 => "Non-table field on insert list",
		-59 => "Data Format: Not a valid reference",
		-60 => "Leases file directory not set/readable.",
		-61 => "Error opening file/directory.",
		-62 => "No relevant leases files found.",
		-63 => "Query string terminated with no result on stack.",
		-64 => "Too many dynamic registrations for this mac address",
	       );
1;	
