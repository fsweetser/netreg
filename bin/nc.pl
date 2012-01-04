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

use strict;

use lib '/home/netreg/lib';

use Data::Dumper;
use CGI qw/:standard/;
my $q = new CGI;
use CMU::WebInt;
use CMU::Netdb;
use CMU::Netdb::reports;
use CMU::WebInt::helper;
use CMU::WebInt::interface;
use POSIX qw/ctime/;

my ($LOGOUT_URL, $LOGOUT_TEXT, $SYSTEM_MAIN_URL, $COOKIE_DESTROY, $vres);

($vres, $LOGOUT_URL) = CMU::Netdb::config::get_multi_conf_var('webint',
							      'LOGOUT_URL');
($vres, $LOGOUT_TEXT) = CMU::Netdb::config::get_multi_conf_var('webint',
							       'LOGOUT_TEXT');
($vres, $SYSTEM_MAIN_URL) = CMU::Netdb::config::get_multi_conf_var
  ('webint', 'SYSTEM_MAIN_URL');
($vres, $COOKIE_DESTROY) = CMU::Netdb::config::get_multi_conf_var
  ('webint', 'COOKIE_DESTROY');

my @SquishCookies;
my @CD;
if (ref $COOKIE_DESTROY eq 'ARRAY') {
  @CD = @$COOKIE_DESTROY;
}else{
  @CD = [$COOKIE_DESTROY];
}
  

foreach my $CName (@CD) {
  my ($Name, $Domain) = ('', '');
  if ($CName =~ /\@/) {
    ($Name, $Domain) = split('@', $CName, 2);
  }else{
    $Name = $CName;
  }
  
  if ($Domain ne '') {
    push(@SquishCookies, $q->cookie(-name => $Name, -value => '', -path => '/',
				    -domain => $Domain, -expires => 'now', -secure => 1));
  }else{
    push(@SquishCookies, $q->cookie(-name => $Name, -value => '', -path => '/',
				    -expires => 'now', -secure => 1));
  }
}

print $q->header(-cookie => \@SquishCookies,
		 -title => 'NetReg Logout');

if ($LOGOUT_URL ne '') {		   
  print $q->start_html(-title => 'NetReg Logout',
		       -BGCOLOR => 'white',
		       -head=>meta({-http_equiv => 'Refresh',
				  -content => "60;url=$LOGOUT_URL"}));
}else{
  print $q->start_html(-title => 'NetReg Logout',
		       -BGCOLOR => 'white');
}
print "<img src=/img/netreg.jpg><br>\n";

&title("Network Registration Signoff");

my $now = ctime(time());
chomp($now);

print "<hr><br>\n";

my $dbh = db_connect();
my $lsref = list_scheduled($dbh, 'netreg', '');
if (ref $lsref) {
  shift(@$lsref);

  print "<table width=610><tr><td>";
  print CMU::WebInt::subHeading("Logoff");
  print "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  print "<ul>\n";
  print "<li>You have been signed off from the NetReg system as of: $now.\n";

  if ($LOGOUT_URL ne '' &&
      $LOGOUT_TEXT ne '') {
    print "<li>$LOGOUT_TEXT\n";
  }
  print "<li>If you would like to continue using NetReg, ".
    "<a href=\"$SYSTEM_MAIN_URL\">click here</a>.\n";
  print "</ul></font>\n";

  print subHeading("System Updates").
"<i>Note: In most cases, DNS and DHCP propagation is complete within 15 minutes following 
the \"Next Update\" time. 
\n</i><br>\n";
  print "<table border=1><tr bgcolor=$CMU::WebInt::interface::TACOLOR><th><font face=\"Arial,Helvetica,Geneva,Charter\">System</th>
<th><font face=\"Arial,Helvetica,Geneva,Charter\">Last Update</th>
<th><font face=\"Arial,Helvetica,Geneva,Charter\">Next Update</th></tr>\n";

  foreach(@$lsref) {
    if ($_->[4] eq 'Create DNS Zones') {
      print "<tr><td><b><font face=\"Arial,Helvetica,Geneva,Charter\">DNS</b></td>
<td>".$_->[2]."</td><td>".$_->[3]."</td></tr>\n";
    }elsif($_->[4] eq 'Create DHCP Configuration') {
      print "<tr><td><b><font face=\"Arial,Helvetica,Geneva,Charter\">DHCP</b></td>
<td>".$_->[2]."</td><td>".$_->[3]."</td></tr>\n";
    }elsif($_->[4] eq 'Enable/Disable Ports') {
      print "<tr><td><b><font face=\"Arial,Helvetica,Geneva,Charter\">Outlet Enabling</b></td>
<td>".$_->[2]."</td><td>".$_->[3]."</td></tr>\n";
    }
  }
  print "</table>\n";
}

print stdftr($q);

