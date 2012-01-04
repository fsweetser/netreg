#! /usr/bin/perl

use strict;
use lib "/usr/ng/lib/perl5";
use SOAP::Transport::HTTP;

my $debug = 2;

# FCGI module available?
if (eval "require FCGI") {
  # Well known FastCGI bug workaround
  my $ignore;
  while (($ignore) = each %ENV) {
  }

  # Are we running under FastCGI?
  my $req = FCGI::Request();
  my $is_fcgi = $req->IsFastCGI();
  if ($is_fcgi) {
    warn "FastCGI? yes." if ($debug >= 2);

    while ($req->Accept() >= 0) {
      SOAP::Transport::HTTP::CGI
	  -> dispatch_to("CMU::Netdb::SOAPAccess")
	    -> handle
	      ;
    }
    exit;
  } else {
    warn "FastCGI? no." if ($debug >= 2);
    # Fall through to non-FCGI case
  }

}

# running without FCGI

SOAP::Transport::HTTP::CGI
  -> dispatch_to("CMU::Netdb::SOAPAccess")
  -> handle
  ;


