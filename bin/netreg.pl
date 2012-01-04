#! /usr/bin/perl
##
## netreg.pl
##
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
##
##
## $Id: netreg.pl,v 1.18 2008/03/27 22:57:47 vitroth Exp $
##
use strict;

use lib '/home/netreg/lib';

use CMU::WebInt;
use CMU::Netdb;
use CGI::Carp qw(fatalsToBrowser);

use CGI;

my $debug = 0;

# running under FCGI
if (eval "require FCGI") {  
  # Well known FastCGI bug workaround
  my $ignore;
  while (($ignore) = each %ENV) {
  }

  my $req = FCGI::Request();
  my $is_fcgi = $req->IsFastCGI();
  if ($is_fcgi) { 
    warn "FastCGI? yes." if ($debug >= 2);

    while ($req->Accept() >= 0) {
      eval {
	CGI->_reset_globals();
	my $q = new CGI;
	my $authuser = $q->cookie('authuser');
	$ENV{'authuser'} = $authuser;
      
	#  warn Data::Dumper->Dump([\%ENV, $authuser], ['ENV', 'authuser']);

	my $op = $q->param('op');
	CMU::Netdb::primitives::clear_changelog("WebInt:$ENV{REMOTE_ADDR}");
	CMU::Netdb::auth::clear_user_admin_status();
	CMU::Netdb::auth::clear_user_group_admin_status();
	CMU::Netdb::auth::clear_user_deptadmin_status();
	if ($op eq '' || !defined $CMU::WebInt::vars::opcodes{$op}) {
	  CMU::WebInt::machines::mach_list($q);
	} else {
	  $CMU::WebInt::vars::opcodes{$op}->($q);
	}
      }
    }
    exit;

  } else {
    warn "FastCGI? no." if ($debug >= 2);
    # Fall through to non-FCGI case
  }
} 

#running without FCGI
my $q = new CGI;
my $authuser = $q->cookie('authuser');
$ENV{'authuser'} = $authuser;

my $op = $q->param('op');
CMU::Netdb::primitives::clear_changelog("WebInt:$ENV{REMOTE_ADDR}");
CMU::Netdb::auth::clear_user_admin_status();
CMU::Netdb::auth::clear_user_group_admin_status();
CMU::Netdb::auth::clear_user_deptadmin_status();
if ($op eq '' || !defined $CMU::WebInt::vars::opcodes{$op}) {
  CMU::WebInt::machines::mach_list($q);
} else {
  $CMU::WebInt::vars::opcodes{$op}->($q);
}


