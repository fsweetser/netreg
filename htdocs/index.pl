#! /usr/bin/perl

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
# $Id: index.pl,v 1.43 2008/03/27 19:42:16 vitroth Exp $
#
# $Id: index.pl,v 1.43 2008/03/27 19:42:16 vitroth Exp $
# Revision 1.42  2007/08/17 20:49:10  vitroth
# modified text for FirstConnect
#
# $Log: index.pl,v $
# Revision 1.43  2008/03/27 19:42:16  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.42.4.1  2007/10/04 21:49:53  vitroth
# merging documentation changes (CMU->Generic) from duke
#
# Revision 1.42.2.1  2007/09/20 18:42:59  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.41  2006/03/28 22:08:23  vitroth
# Updated version number on front page
#
# Revision 1.40  2005/06/29 22:04:25  fes
# Back out changes that missed the branch and hit HEAD
#
# Revision 1.38  2005/03/01 17:53:09  vitroth
# use standard path to perl, since that works now in the cmu environment
#
# Revision 1.37  2004/08/23 21:16:36  vitroth
# added security block to both page variants
#
# Revision 1.36  2004/07/07 21:00:04  vitroth
# New security link.
#
# Revision 1.35  2004/02/20 03:16:00  kevinm
# * External config file updates
#
# Revision 1.34  2003/08/13 17:33:52  kevinm
# * Made the RPC warning more prominent
#
# Revision 1.33  2003/08/12 19:04:51  kevinm
# * Added link to vulnerabilities
#
# Revision 1.32  2003/02/26 06:33:05  kevinm
# * Bumping version
#
# Revision 1.31  2002/12/06 17:45:17  kevinm
# * Certificationes should be Certificates.
#
# Revision 1.30  2002/10/23 19:58:26  kevinm
# * Swapped the quickreg_out and main_out sections
#
# Revision 1.29  2002/10/14 17:38:25  kevinm
# * 800x600 woohoo
#
# Revision 1.28  2002/09/29 16:57:04  kevinm
# * QuickReg enabler wrapper
#
# Revision 1.27  2002/09/17 18:27:21  kevinm
# * Wrong release number
#
# Revision 1.26  2002/08/20 18:52:48  vitroth
# modified the certificates link to the new location
# (was right in one piece of the code, but not in both)
#
# Revision 1.25  2002/08/08 13:36:17  kevinm
# * dialog change
#
# Revision 1.24  2002/08/08 02:03:14  kevinm
# * PreReg hooks on the main page
#
# Revision 1.23  2002/08/07 14:40:24  kevinm
# * Certifications -> Certificates
#
# Revision 1.22  2002/07/13 16:30:03  kevinm
# * Remove DSL
#
# Revision 1.21  2002/07/13 16:29:11  kevinm
# * Remove KWEB
#
# Revision 1.20  2002/06/25 19:12:00  ebardsle
# New linkage.
#
# Revision 1.19  2002/05/15 13:46:46  kevinm
# * Removed outlet stuff
#
# Revision 1.18  2002/05/07 19:06:40  vitroth
# Changed links to guidelines pages.
#
# Revision 1.17  2002/01/10 03:41:11  kevinm
# Added copyright information
#
#
#
use strict;

use lib '/home/netreg/lib';
use CMU::WebInt;
use CMU::Netdb;
use CMU::WebInt::config;

use CGI;
my $q = new CGI;

my $url = $q->server_name();
my $port = $q->server_port();
if ($port ne "80" && $port ne "443") {
  $url = "https://$url:8443";
} else {
  $url = "https://$url";
}

my $SECURITY_WARNING = <<END_WARN;
<center>
<table border=1 bgcolor=black><tr><td bgcolor=#ffff00>
<font size=+1>
<center>
If you are here to register a computer, you must follow the instructions on the <a href="http://www.cmu.edu/computing/firstconnect">FirstConnect</a> website. <a href="http://www.cmu.edu/computing/firstconnect">FirstConnect</a> will help you secure your computer and avoid loss of network access.</a>
 
</center></font></td></tr></table>
</center>
END_WARN

my $enter = $q->param('enter');
if ($enter eq 'y') {
  &main_out();
  exit 0;
}elsif($enter eq 'n') {
  &quickreg_out();
  exit 0;
}

# Check if they are coming in via a quickreg subnet
my $dbh = eval { CMU::WebInt::db_connect(1); };
unless (defined $dbh) {
  &main_out();
  exit 0;
}

my ($vres, $eqr) = CMU::Netdb::config::get_multi_conf_var('netdb', 
							  'ENABLE_QUICKREG');

if ($eqr == 1) {
  my ($sid, $info) = CMU::WebInt::quickreg::qreg_findsubnet($q, $dbh, 'netreg');
  if ($sid > 0) {
    &quickreg_out();
    exit 0;
  }
}

&main_out();
exit 0;

sub quickreg_out {
  print $q->header(-title => 'Network Registration');
  print $q->start_html('Carnegie Mellon Network Registration');
  print <<"END_HTML_PREREG";

<body bgcolor=white>
<img src="/img/netreg.jpg">
<table width=620><tr><td>
<table width=100%><tr><td>
<font size=+2><B>Register Your Machine</b></font></td>
</tr></table>
<hr>
<font face="Arial,Helvetica,Geneva,Charter">
Your machine is not registered on the subnet that it is currently connected.
Using this system, your registration will be completed quickly and you will
have full network connectivity in approximately 30 minutes.<br><br>
<table border=1><tr><td bgcolor=lightgreen>
<font size=+1>You must install the 
<a href="http://www.cmu.edu/certificates" target=_new>
Carnegie Mellon Root Certificate</a>
into your browser before proceeding.</font></td></tr></table>
<br>
$SECURITY_WARNING
<br><br>Please follow these steps to complete registration:
<ul>
 <li> Install the certificates using the link above.
 <li> Click "Continue". On the main NetReg entry page, read and understand
      the guidelines for network utilization.
 <li> Click "Enter" on the next page.
 <li> If your computer's ethernet address is located, you will be presented
      with further QuickReg instructions.
 <li> If your address is not located, or your machine is already registered
      on this subnet, you will be presented with a list of your registered
      machines. If you have registered this machine in the last 30 minutes,
      please wait 30 minutes, reboot, and try accessing the network again.
 <li> If you registered more than 2 hours ago and have rebooted your 
      computer recently, please contact the Computing Services Help Center
      for more assistance (Cyert Hall A-Level, x8-HELP, or 
      advisor\@andrew.cmu.edu).
</ul>
<hr>
<center><b><font size=+2>
<a href="https://netreg.net.cmu.edu/index.pl?enter=y">
Continue</a></font></b></center>
<hr>
<i><font size=-1>Carnegie Mellon Network Development --
<a href="mailto:advisor\@andrew.cmu.edu">Webmaster</a></font></i>
</td></tr></table>

</body></html>
END_HTML_PREREG

}

sub main_out {
  my $cookie = $q->cookie(-name => 'KWEB',
			  -value => '',
			  -path => '/',
			  -expires => 'now');
  print $q->header(-cookie => $cookie,
		   -title => 'Network Registration');
  print $q->start_html('Carnegie Mellon Network Registration');
  
  print <<"END_HTML";

<body bgcolor=white>
<img src="/img/netreg.jpg">
<table width=620><tr><td>
<table width=100%><tr><td>
<font size=+2><B>Welcome to the Network Registration System</b></font></td>
<td align=right><i><font size=-1>Release 1.1.9</font></i>
</td></tr></table>
<hr>
<font face="Arial,Helvetica,Geneva,Charter">
$SECURITY_WARNING
<p>
Users with Carnegie Mellon Andrew IDs can use this system to register machines to be connected to the campus network and activate network outlets.<br>
<br>All machines
must be registered through this system prior to use on the campus network.
<a target=_blank href="/help/pages/about-netreg.shtml">About Network Registration</a>.

<br><br>

<table>

<tr><td bgcolor=lightgreen colspan=2><b><font face="Arial,Helvetica,Geneva,Charter">What You'll Need</font></b></td></tr>

<tr>
<td valign=top colspan=2><font face="Arial,Helvetica,Geneva,Charter" size=-1>
To use this system, you will need to have the 
<a target=export href="http://www.cmu.edu/certificates">CMU Root Certificates</a> installed in your browser. Your browser must also have Javascript and Cookies enabled.
<br><br>
</td></tr>

<tr valign=top>
<td colspan=2 bgcolor=red><b><font face="Arial,Helvetica,Geneva,Charter">Important</font></b></td></tr>
<td colspan=2 valign=top><font face="Arial,Helvetica,Geneva,Charter\" size=-1>By using this system, you agree to abide by the 
policies and guidelines concerning the use of computer, 
network, and telecommunications resources. These policies and guidelines govern the use of such resources. Please read the 
<A target=_blank HREF="http://www.cmu.edu/computing/documentation/index_policies.html">Carnegie Mellon Computing Policies and Guidelines</A>.

<br><br>If you <a href="http://www.cmu.edu/computing/documentation/index_policies.html">do not agree to abide by these guidelines</a>, you may not use this system.

<br><br>
By clicking "Enter", you indicate that you have read, understand, and agree to the policies and guidelines.<br><br>
<center><a href="$url/bin/netreg.pl?op=login"><img border=0 alt="Enter NetReg" src=/img/enter.gif></a></center>

</td></tr>

</table>
<hr>
<i><font size=-1>Carnegie Mellon Network Development -- 
<a href="mailto:advisor\@andrew.cmu.edu">Webmaster</a></font></i>
</td></tr></table>

</body>

</html>
END_HTML
}
