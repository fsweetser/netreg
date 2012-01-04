#! /usr/bin/perl
##
## load-dhcp-options-hosts.pl
##
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
## $Id: load-dhcp-options-hosts.pl,v 1.2 2008/03/27 19:42:44 vitroth Exp $
##
## $Log: load-dhcp-options-hosts.pl,v $
## Revision 1.2  2008/03/27 19:42:44  vitroth
## Merging changes from duke merge branch to head, with some minor type corrections
## and some minor feature additions (quick jump links on list pages, and better
## handling of partial range allocations in the subnet map)
##
## Revision 1.1.22.1  2007/10/11 20:59:47  vitroth
## Massive merge of all Duke changes with latest CMU changes, and
## conflict resolution therein.   Should be ready to commit to the cvs HEAD.
##
## Revision 1.1.20.1  2007/09/20 18:43:08  kevinm
## Committing all local changes to CVS repository
##
## Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
##
##
## Revision 1.1  2002/01/10 02:50:19  kevinm
## Rearranged the load-* scripts
##
## Revision 1.3  2001/07/20 22:22:26  kevinm
## Copyright info
##
## Revision 1.2  2000/08/14 05:22:12  kevinm
## *** empty log message ***
##
## Revision 1.1  2000/08/10 14:43:46  kevinm
## *** empty log message ***
##
##
##
##

use strict;

use lib '/home/netreg-dev/lib';

use CMU::Netdb;
use CMU::Netdb::machines_subnets;
use CMU::Netdb::dns_dhcp;
use CMU::Netdb::errors;
use CMU::Netdb::helper;

$| = 1;

if ($ARGV[0] eq '') {
  print "$0 [infile] [logfile]\n";
  exit;
}
a($ARGV[0], $ARGV[1]);

my %typecache;

sub a {
  my ($file, $logfile) = @_;
  my $dbh = lw_db_connect();
  
  open(LOGFILE, ">$logfile") || die "Cannot open log file $logfile";

  open(FILE, $file) || die "Cannot open infile $file";
  while(<FILE>) {
    next if (/^\s+$/ || /^\#/);
    my @parsed = split(/\s*\,\s*/, $_);
    my $host = shift(@parsed);
    
    my %fields = ('type' => 'machine');
    my $mr = list_machines($dbh, 'netreg', "machine.host_name = '$host'");
    if (!ref $mr || !defined $mr->[1]) {
      print LOGFILE "ADD_OPTION: ERROR: Can't find machine $host!\n";
      next;
    }
    $fields{tid} = $mr->[1]->[0];

    foreach(@parsed) {
      my @c = split(/\s+/, $_);
      if ($#c == 0) {
	print LOGFILE "ADD_OPTION: ERROR: $host/(".join(',', @c).")\n";
	@c = ();
	last;
      }
      my $optname = shift(@c);
      $optname .= " ".shift(@c) if ($optname eq 'option');
      my $val = shift(@c);
      print STDERR "Adding option $optname => $val\n";
      
      if (defined $typecache{$optname}) {
	$fields{number} = $typecache{$optname};
      }else{
	my $dotr = list_dhcp_option_types($dbh, 'netreg', "dhcp_option_type.name = '$optname'");
	if (!ref $dotr || !defined $dotr->[1]) {
	  print LOGFILE "ADD_OPTION: ERROR: Can't find option ID: $host $optname $val\n";
	  @c = ();
	  last;
	}
	$typecache{$optname} = $dotr->[1]->[2];
	$fields{number} = $typecache{$optname};
      }
      $fields{value} = $val;
      my ($res, $ref) = add_dhcp_option($dbh, 'netreg', \%fields);
     
      if ($res != 1) {
	print LOGFILE "ADD_OPTION: ERROR: $host:$optname:$val: ".$errmeanings{$res}."\n";;
      }else{
	print LOGFILE "ADD_RESOURCE: OKAY: $host:$optname:$val\n";
      }
    }
  }
  close(FILE);
  close(LOGFILE);
}

