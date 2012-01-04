#! /usr/bin/perl

use CGI;
use strict;
my $q = new CGI;

my $port = $ENV{'SERVER_PORT'};
if ($port eq '80') {
	print $q->redirect("https://".$ENV{'SERVER_NAME'}.$ENV{'REQUEST_URI'});
	exit 1;
}
print $q->header().$q->start_html(-title => "Access Denied");

print "Access to the specified resource is denied.\n";

print $q->end_html();
 
