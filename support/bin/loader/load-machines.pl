#! /usr/bin/perl
##
## load-machines.pl
## A script that will perform a number of database loading operations
## on CINDI dumps
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
##
## $Id: load-machines.pl,v 1.2 2008/03/27 19:42:44 vitroth Exp $
##
## $Log: load-machines.pl,v $
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
## Revision 1.9  2001/07/20 22:22:26  kevinm
## Copyright info
##
## Revision 1.8  2000/08/14 05:22:12  kevinm
## *** empty log message ***
##
## Revision 1.7  2000/07/31 15:39:36  kevinm
## *** empty log message ***
##
## Revision 1.6  2000/07/21 14:45:37  kevinm
## *** empty log message ***
##
## Revision 1.5  2000/07/10 14:47:26  kevinm
## Updated loading scripts. cnames/mx/ns works now
##
## Revision 1.4  2000/07/06 20:07:49  kevinm
## *** empty log message ***
##
## Revision 1.3  2000/06/18 23:41:32  kevinm
## This works for most cases. Probably still need to change the behavior of
## dealing with same hostname, etc. given new semantics.
##
## Revision 1.2  2000/06/16 14:16:06  kevinm
## It now works for a large majority of cases. Still need to figure out what to
## do with machines that we don't have the subnets loaded for (CS machines, mostly)
## and duplicates now get pretty silly hostnames
##  (ie BDC-LAPTOP-128-2-35-50.PC.CC.CMU.EDU)
##
## Revision 1.1  2000/06/15 16:34:08  kevinm
## *** empty log message ***
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
use CMU::WebInt::helper;
use CMU::WebInt;

$| = 1;
my $GFILE = "/home/dataload/depts/dept.gfile";
my $GMAPFILE = "/home/dataload/depts/dept.mapfile";
my $UNK_GROUP = 'dept:unknown';
my %groups;
loadGroups();

if ($ARGV[0] eq '' || $ARGV[1] eq '') {
  print "$0 -usedb [infile] [logfile]\n\t-usedb: Actually update the db.\n";
  exit;
}

if ($ARGV[0] eq '-usedb') {
  a($ARGV[1], 1, $ARGV[2]);
}else{
  a($ARGV[0], 0, $ARGV[1]);
}

sub loadGroups {
  my %g;
  open(FILE, $GFILE) || die "Cannot open group file $GFILE\n";
  my @a;
  my $line;
  while($line = <FILE>) {
    @a = split(/\|/, $line);
    $g{$a[1]} = $a[2];
    print STDERR "$a[1] =1> $g{$a[1]}\n";
  }
  close(FILE);
  open(FILE, $GMAPFILE) || die "Cannot open group map file $GMAPFILE\n";
  while($line = <FILE>) {
    @a = split(/\|/, $line);
    $groups{$a[0]} = $g{$a[1]};
    print STDERR "$a[0] =2> $groups{$a[0]}\n";
  }
  close(FILE);
}

sub a {
  my ($file, $usedb, $logfile) = @_;
  my $dbh = lw_db_connect();
  
#  $CMU::Netdb::primitives::debug = 2;
#  $CMU::Netdb::auth::debug = 2;
#  $CMU::Netdb::machines_subnets::debug = 2;
  open(LOGFILE, ">$logfile") || die "Cannot open log file $logfile";
  open(RJ, ">rejects") || die "Cannot open rejects!";

  # First pass: extend dns_zone to have the domains we need
  print "Getting list of zones...";
  my %zref = %{list_zone_ref($dbh, 'netreg', '')};
  print "done\nMaking inverse map...";
  my %zones;
  map { $zones{uc($zref{$_})} = $_ } keys %zref;
#  map { print "Zone Loaded: $_\n" } keys %zones;
  print "done\nFirst pass...scanning for subnets that need to be added...";
  my %addz;

  open(FILE, $file) || die "Cannot open infile $file";
  while(<FILE>) {
    next if (/^\s+$/ || /^\#/);
    my @c = split(/\|/);
    next if ($c[5] eq 'W'); # withdrawn
    my $domain = $c[0];
    $domain =~ s/^[^\.]+\.//;
    if ($domain eq '') {
      print "Domain is NULL: $c[0] $c[1] $c[2]\n";
    }else{
      $addz{$domain} = 1 unless (defined $zones{$domain});
    }
  }
  close(FILE);
  print "done\nAdding zones...\n";

  my %fields = ('soa_host' => '',
		'soa_email' => '',
		'soa_serial' => 0,
		'soa_refresh' => 0,
		'soa_retry' => 0,
		'soa_expire' => 0,
		'soa_minimum' => 0,
		'last_update' => 0,
		'type' => 'fw-permissible');

  foreach my $dd (keys %addz) {
    $fields{'name'} = $dd;
    my $res;
    $res = 1 unless $usedb;
#    ($res) = add_dns_zone($dbh, 'netreg', \%fields) if $usedb;
    print LOGFILE "ZONE_ADD: ERROR: Need to add $fields{name}!";

    if ($res == 1) {
      print LOGFILE "ZONE_ADD: OKAY: $dd\n";
      print "Added $dd.\n";
    }else{
      print LOGFILE "ZONE_ADD: ERROR: $dd: ".$errmeanings{$res};
      print "Error adding $dd: ".$errmeanings{$res};
      print $CMU::Netdb::primitives::db_errstr if ($res eq $errcodes{EDB});
      print LOGFILE " (".$CMU::Netdb::primitives::db_errstr." )" if ($res eq $errcodes{EDB});
      print LOGFILE "\n";
      print "\n";
    }
  }

  ##
  ## SECOND PASS
  ##
  print "Second pass...adding allowed domains for subnets.\n";
  my %domains;
  my %machines;
  my %dups;
  open(FILE, $file) || die "Cannot open $file";
  my $line = -1;
  while(<FILE>) {
    $line++;
    next if (/^\s+$/ || /^\#/);
    my @c = split(/\|/);
    next if ($c[5] eq 'W'); #withdrawn
    my @s = split(/\./, $c[0]);
    my $host = shift(@s);
    my $domain = join('.', @s);
    my %subnets;
    my @ks;
    next if ($c[2] eq '..' || $c[2] eq '128.2..');
    %subnets = %{list_subnets_ref($dbh, 'netreg', 
				  ' subnet.base_address = ('.dot2long($c[2]).
				  ' & subnet.network_mask)', 'subnet.name')};
    my @ks = keys %subnets;
#    print "subnet $c[0]: $ks[0]\n";
    
    if ($#ks < 0) {
      print "\nError! No subnet found for $c[2]!\n";
      print LOGFILE "SUBNET_LOCATE: ERROR: $c[2]: No subnet found.\n";
      next;
    }elsif($#ks > 0) {
      print "\nError! More than one subnet found for $c[2]! (".join(',', @ks).")\n";
      print LOGFILE "SUBNET_LOCATE: ERROR: $c[2]: More than one subnet (".join(',', @ks).")\n";
      next;
    }

    $machines{$line} = $ks[0];
    
    unless (defined $domains{$ks[0]}) {
      my $gds = get_domains_for_subnet($dbh, 'netreg',
						 "subnet_domain.subnet = $ks[0]");
      $domains{$ks[0]} = $gds;
      print STDERR "$ks[0] defining!\n";
      if (!ref $domains{$ks[0]}) {
	print "Error! Listing domains for subnet $ks[0]: ".$errmeanings{$domains{$ks[0]}}."\n";
	print LOGFILE "SUBNET_LIST: ERROR: $ks[0]: Error listing domains: ".$errmeanings{$domains{$ks[0]}};
	
	print $CMU::Netdb::primitives::db_errstr if ($domains{$ks[0]} eq $errcodes{EDB});
	print LOGFILE " (".$CMU::Netdb::primitives::db_errstr.")" if ($domains{$ks[0]} eq $errcodes{EDB});
	print LOGFILE "\n";
	
	print "\n";
	next;
      }
    }	
    # figure out if we already know 
    my $is = 0;
    map { $is = 1 if (uc($_) eq uc($domain)) } @{$domains{$ks[0]}};
    unless ($is) {
      print "Adding domain $domain for subnet $ks[0] ($host.$domain)...";
      %fields = ('subnet' => $ks[0],
		 'domain' => $domain);
      my $res;
      $res = 1 unless $usedb;
#      ($res) = add_subnet_domain($dbh, 'netreg', \%fields) if $usedb;
      print LOGFILE "DOMAIN_ADD: Need to add subnet $ks[0] => domain $domain\n";
      if ($res != 1) {
	print "\nError! Adding domain: ".$errmeanings{$res};
	print LOGFILE "DOMAIN_ADD: ERROR: $domain => $ks[0]: ".$errmeanings{$res};
	print $CMU::Netdb::primitives::db_errstr if ($res eq $errcodes{EDB});
	print LOGFILE " ( ".$CMU::Netdb::primitives::db_errstr." ) " if ($res eq $errcodes{EDB});
	print LOGFILE "\n";
	print "\n";
      }else{
	print LOGFILE "DOMAIN_ADD: OKAY: $domain => $ks[0]\n";
	print "done.\n";
      }
#      delete $domains{$ks[0]}; # I LOVE PAIN!
    }
#    print ".";
  }
  close(FILE);

  ## 
  ## THIRD PASS
  ## 

  print "\nThird pass...adding machines.\n";
  $CMU::Netdb::primitives::debug = 2;
  $CMU::Netdb::auth::debug = 2;
  $CMU::Netdb::machines_subnets::debug = 2;

  my %perms;
  my $line = -1;
  open(FILE, $file) || die "Cannot open $file";
  open(WRITE, ">$file.reload");
  my $pline;
  while($pline = <FILE>) {
    $line++;
    chop($pline);
    if ($pline =~ /^\s+$/ || $pline =~ /^\#/) {
      print LOGFILE "SKIP: $pline\n";
      next;
    }
    my @c = split(/\|/, $pline);
    print STDERR "*** >$c[5]< *** \n";
    if ($c[5] eq 'W' || $c[5] eq 'H') {
      print LOGFILE "ADD_MACHINE: SAFE_REJECT: Status: $c[5] for $fields{host_name}/$fields{ip_address}/$fields{mac_address}\n";
      next;
    }

     %fields = ('mode' => 'static',
	       'flags' => '',
	       'comment' => '',
	       'account' => '',
	       'host_name_ttl' => 0,
	       'ip_address_ttl' => 0);
    print WRITE "$pline\n";
    my $savegroup;
    $fields{'host_name'} = $c[0];
    if (defined $groups{$c[4]}) {
      $savegroup = $groups{$c[4]};
    }else{
      $savegroup = $UNK_GROUP;
      print LOGFILE "ADD_MACHINE: ERROR: UNK_GROUP: $c[4]\n";
    }
    $fields{'dept'} = $savegroup;
    $fields{'mac_address'} = $c[1];
    $fields{'ip_address'} = $c[2];
    my $saveIP = $c[2];
    $saveIP = '..' if ($saveIP eq '128.2..');
    $fields{'ip_address'} = $saveIP;
    $fields{'ip_address_subnet'} = $machines{$line};
    $fields{'ip_address_subnet'} = 188 if (!defined $machines{$line} && $fields{mode} eq 'reserved');

    if (grep(/^$c[5]$/, qw/C I O P R S/) == 0) {
      print LOGFILE "ADD_MACHINE: ERROR: REJECT Status code unknown (is: $c[5])";
      next;
    }
    
    if ($c[5] eq 'S') {
      if ($fields{mac_address} ne '') {
	$fields{mode} = 'reserved';
	$fields{host_name} = "STOLEN-$fields{mac_address}.NET.CMU.EDU";
	$fields{flags} = 'stolen';
	$fields{ip_address} = '';
	$fields{ip_address_subnet} = '188';
      }else{
	print LOGFILE "ADD_MACHINE: REJECT: No MAC adress for stolen host ".
	  "$fields{'host_name'}/$fields{ip_address} (line $line)";
	next;
      }
    }

    if ($fields{mac_address} eq '' && $fields{ip_address} eq '..' && 
	$fields{host_name} eq '') {
      print LOGFILE "ADD_MACHINE: SAFE_REJECT: Triple-null, line $line\n";
    }elsif($fields{'mac_address'} ne '' && $fields{ip_address} ne '..' &&
	   $fields{'host_name'} ne '..') {
      # have all three
      $fields{'mode'} = 'static';
    }else{
      if ($fields{mac_address} ne '') {
	if ($fields{host_name} ne '') {
	  # have mac, hostname
	  if ($c[5] eq 'O') {
	    print LOGFILE "ADD_MACHINE: SAFE_REJECT: MAC/Hostname for offline machine: $fields{host}/$fields{mac_address}\n";
	    next;
	  }
	  $fields{'mode'} = 'reserved';
	}else{
	  if ($fields{ip_address} ne '..') {
	    # have mac, ip
	    $fields{host_name} = 'CMU-$fields{mac_address}.CC.CMU.EDU';
	    $fields{'mode'} = 'reserved';
	    $fields{'mode'} = 'static' 
	      if ($c[5] eq 'C' || $c[5] eq 'I' || $c[5] eq 'P');
	  }else{
	    # have only mac
	    if ($c[5] ne 'C') {
	      print LOGFILE "ADD_MACHINE: REJECT: Only have MAC address ($fields{mac_address} and status: $c[5] (line $line)\n";
	      next;
	    }
	    $fields{'mode'} = 'dynamic';
	  }
	}
      }else{
	if ($fields{host_name} ne '') {
	  if ($fields{ip_address} ne '..') {
	    # have hostname and ip
	    $fields{'mode'} = 'reserved';
	    $fields{'mode'} = 'broadcast' if ($fields{'host_name'} =~ /BCAST-\d+-255/);
	    $fields{'mode'} = 'base' if ($fields{'host_name'} =~ /BCAST2-\d+-0/);
	  }else{
	    # have only hostname
	    if ($c[5] eq 'O' || $c[5] eq 'P' || $c[5] eq 'I') {
	      print LOGFILE "ADD_MACHINE: REJECT: Only have host_name ($fields{host_name} and status: $c[5] (line $line)\n";
	    }else{
	      $fields{'mode'} = 'reserved';
	    }
	  }
	}else{
	  # must have the IP since we don't have host and mac
	  unless ($c[5] eq 'C') {
	    print LOGFILE "ADD_MACHINE: SAFE_REJECT: Only have IP, status NOT connected ($fields{ip_address}, $c[5]), line $line\n";
	    next;
	  }
	  $fields{mode} = 'reserved';
	  $fields{host_name} = 'CMU-$ip_address.cc.cmu.edu';
	}
      }
    }
    $fields{'ip_address_subnet'} = 188 if (!defined $machines{$line} && $fields{mode} eq 'reserved'); # FIXME fixed to the 127*

    %perms = ($c[3] => ['READ,WRITE',1]);

    if ($fields{'mode'} ne 'dynamic' && $fields{'mode'} ne 'reserved' 
	&& $fields{'ip_address_subnet'} eq '') {
      print LOGFILE "ADD_MACHINE: ERROR: $fields{'host_name'}/$fields{ip_address}/$fields{mac_address} (line $line)/$fields{mode}: No IP address subnet. Stop.\n";
      next;
    }

    $fields{ip_address} = '' if ($fields{ip_address} eq '..');

    my ($res, $wref);
    $res = 1 unless $usedb;
    ($res, $wref) = add_machine($dbh, 'netreg', 9, \%fields, \%perms) if $usedb;
    if ($res != 1) {
      print "Error adding $c[0] ($c[1] $c[2]): ".$errmeanings{$res};
      print "Warns: \n";
      map { print "$_\n" } @{$wref};
      print $CMU::Netdb::primitives::db_errstr if ($res eq $errcodes{EDB});
      print "\n";
      if ($res == $errcodes{EEXISTS}) {
	my $msg = "ADD_MACHINE: ERROR_2: $fields{host_name}/$fields{ip_address}/$fields{mac_address}/$fields{mode}: Error adding: ".$errmeanings{$res};
	$msg .=  " (".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $errcodes{EDB});
	$msg .= " [".join(',', @$wref)."]";
	$msg .= "\n";
	my ($h, $d) = splitHostname($fields{host_name});
	if (grep(/mac_address/, @$wref) && $res eq $errcodes{EEXISTS}) {
	  $h .= "-$fields{ip_address}-res";
	  $fields{host_name} = $h.".".$d;
	  $fields{ip_address_subnet} = $machines{$line};
	  $fields{mode} = 'reserved';
	  $fields{mac_address} = '';
	}else{
	  $h .= "-$fields{ip_address}-$fields{mac_address}";
	  $h =~ s/\-$//;
	  $fields{host_name} = $h.".".$d;
	  $fields{ip_address_subnet} = $machines{$line};
	  print STDERR "Assigning subnet $machines{$line} $saveIP\n";
	}
	$fields{dept} = $savegroup;
	$fields{ip_address} = $saveIP;
	my ($res2, $wref2) = add_machine($dbh, 'netreg', 9, \%fields, \%perms);
	if ($res2 != 1) {
	  print LOGFILE $msg;
	  print LOGFILE "ADD_MACHINE: ERROR: $fields{host_name}/$fields{ip_address}/$fields{mac_address}/$fields{mode}/$fields{dept}: Error adding: ".$errmeanings{$res2};
	  print LOGFILE " (".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $errcodes{EDB});
	  print LOGFILE " [".join(',', @$wref2)."] \n";
	  print LOGFILE "\n";
	  print RJ $pline."\n";
	}else{
	  print LOGFILE "ADD_MACHINE: OKAY_2: $fields{host_name}/$fields{ip_address}/$fields{mac_address}/$fields{mode} added.\n";
	  print "Added $c[0] ip $c[2] mac $c[1].\n";
	  print "Warns: \n";
	  map { print "$_: $$wref2{$_}\n" } keys %{$wref2};
	}
      }else{
	print LOGFILE "ADD_MACHINE: ERROR: $fields{host_name}/$fields{ip_address}/$fields{mac_address}/$fields{mode}: Error adding: ".$errmeanings{$res};
	print LOGFILE " (".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $errcodes{EDB});
	print LOGFILE " [".join(',', @$wref)."] \n";
	print RJ $pline."\n";
      }
    }else{
      print LOGFILE "ADD_MACHINE: OKAY: $fields{host_name}/$fields{ip_address}/$fields{mac_address}/$fields{mode} added.\n";
      print "Added $c[0] ip $c[2] mac $c[1].\n";
      print "Warns: \n";
      map { print "$_: $$wref{$_}\n" } keys %{$wref};
    }
  }
  close(FILE);
  close(LOGFILE);
  close(WRITE);
  close(RJ);
  print "\nAll done.\n";
}
    
  

  


