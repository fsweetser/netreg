#!/usr/bin/perl
#
# This code is used to re-ip one subnet into another.
#
# It can either pack the hosts into the bottom of the destination subnet
# or do a 1 to 1 transfer, preserving the offset into the subnet.  It can also
# reposition the hosts by a specific offset to free space at the start of the 
# target subnet and provide a predictable translation into the new subnet.
# This program can also take a file of random IP addresses and move them into
# the first available spaces in a target subnet.  The file should have one IP 
# address per line, lines starting with a hash are ignored.
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
# $Id: re_ip.pl,v 1.9 2008/03/27 19:42:43 vitroth Exp $
#
# $Log: re_ip.pl,v $
# Revision 1.9  2008/03/27 19:42:43  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.8.22.1  2007/10/11 20:59:46  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.8.20.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.8  2003/05/28 16:51:27  fk03
# Removed -w flag from the perl command line as netdb is too dirty to use it.
#
# Revision 1.7  2003/05/28 16:49:45  fk03
# Added -D flag to allow for re-domaining of hosts being re-IPed.
#
# Revision 1.6  2003/04/02 18:49:43  fk03
# Altered program behavior to allow for "pre-registering" hosts onto a
# new subnet so that a maping of "where things will end up" can be made
# in advance of the move.  This is done with the -p and -c options.
#
# Revision 1.5  2002/01/30 20:40:26  kevinm
# Fixed vars_l
#
# Revision 1.4  2001/07/20 22:05:47  kevinm
# *** empty log message ***
#
# 

use strict;
use Fcntl ':flock';

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;
use Getopt::Std;


my ($user, $dbh, $db_result, $dbrpos, %opts, $str, $scan, $debug, $old_ip, $new_ip);
my ($cnt, $i, $target_sn, %target_attr, $res, $ret, $target_mask, %target_perm);
my ($one2one, $src_base, $target_base, $delta, $test_only);
my ($dyn, $in_str, $db_qry, $dbqpos, $offset, $infile, $tgt_arg, $dynqry, $inline);
my ($pre, $comp, $domain);

sub usage {

  my ($dbhandle) = @_;

  if (defined $dbhandle){
    $dbh->disconnect();    
  }
  print STDERR "usage: re_ip.pl [options] [source_sn_abbrev] target_sn_abbrev\n";
  print STDERR "options are\n";
  print STDERR "\t-t - test only, do not actually do the move\n";
  print STDERR "\t-o - do a one to one mapping of the subnet (cannot be used with -F)\n";
  print STDERR "\t-O n - offset the new addresses by n (requires -o)\n";
  print STDERR "\t-F filename - read a set of ip addresses from filename\n\t\t(one IP per line) to use instead of source_sn_abbrev\n\t\t(cannot be used with -o)\n";
  print STDERR "\t-d - move dynamic registrations also\n";
  print STDERR "\t-r - move reserve addresses also\n";
  print STDERR "\t-p - Pre-register all hosts into the new space instead of changing them.\n\t\tNew regrestrations will have the same hostname with\n\t\t\"new-\" prepended\n";
  print STDERR "\t-c - Complete the re-ip started by -p option.  Deletes old records if \n\t\tthe hardware address is defined in the new space, and \n\t\tre-names the new host to the old name.\n";
  print STDERR "\t-T seconds - set TTLs on IP and name to seconds, prevents all \n\t\tother updates\n";
  print STDERR "\t-D DOMAIN.NAME.TGT - set all hosts that are re-iped to be in the\n\t\tnamed domain. No effect when used with -p.";
  print STDERR "\t-v - verbose\n";
  print STDERR "\t-V - more verbose (combine with -v for extreme verbosity)\n";
  

}

sub test_move {
  my ($t_base, $t_mask, $t_snet, $s_base, $src_info, $direct, $res, $dyn, $comp, $domain) = @_;
  my ($target_size, $retval, $s_mask, $delta, $srcpos);
  my ($i, %tgt_ip_lst, %tgt_hw_lst, $tgt_ip, $err_txt);

  $srcpos = GetHeaderPos($src_info);
  $retval = 0;
  $target_size = ($t_mask ^ 0xFFFFFFFF) - 1;

  warn __FILE__ . ":" . __LINE__ . ": t_base = " .
    ((defined $t_base) ? $t_base . "(" . CMU::Netdb::long2dot($t_base) . ")" : "UNDEFINED") . ", s_base = " .
      ((defined $s_base) ? $s_base . "(" . CMU::Netdb::long2dot($s_base) . ")"  : "UNDEFINED") . ", offset = " . 
	((defined $offset) ? $offset : "UNDEFINED") . "\n" if ($debug);
  $delta = ($t_base - $s_base) + $offset if ($one2one == 1);

  warn __FILE__ . ":" . __LINE__ . ": base = $t_base, mask = $t_mask, target_size = $target_size, src_size = $#$src_info, target_subnet = $t_snet, one2one = $direct\n" if $debug >= 2;
#   Check to see if the target subnet is big enough.
  warn __FILE__ . ":" . __LINE__ . ": Checking sizes\n" if $debug >= 1;
  if ($#$src_info > $target_size){
    warn __FILE__ . ":" . __LINE__ . ": >>> Target subnet too small for number of hosts being transfered\n";
    $retval++;
  }

# check to see if the domain is valid on the target subnet
  if (defined $domain) {
    
    $db_qry = CMU::Netdb::list_subnet_domains($dbh, $user, "((subnet_domain.subnet = \"$t_snet\") and (subnet_domain.domain like \"$domain\"))");
    if (not ref $db_qry) {
      warn __FILE__ . ":" . __LINE__ . ": error $db_qry ( $CMU::Netdb::errmeanings{$db_qry} ) while attempting to check for $domain on  $t_snet\n";
      &usage($dbh);
      die("\n");
    }
    if ($#$db_qry == 0) {
      warn __FILE__ . ":" . __LINE__ . ": >>> Target domain not allowed in target subnet\n";
      $retval++;
    }
  }

# check to see it the target net has enough free space;
  $db_qry = CMU::Netdb::list_machines_subnets($dbh, $user, "( subnet.id = $t_snet ) order by machine.ip_address");
  
  if (not ref $db_qry) {
    warn __FILE__ . ":" . __LINE__ . ": error $db_qry ( $CMU::Netdb::errmeanings{$db_qry} ) while attempting to get subnet hosts from subnet $t_snet\n";
    &usage($dbh);
    die("\n");
  }
  

  if ((! $comp) && ($target_size < ($#$src_info + $#$db_qry))){
    my ($srccnt, $tgtspc);
    $srccnt = $#$src_info - 1;
    $tgtspc = $target_size -  $#$db_qry;
    warn __FILE__ . ":" . __LINE__ . ": >>> Not enough free space in target subnet. Need $srccnt slots, have $tgtspc slots \n";
    $retval++;
  }
  
# check for collisions in transfer (this is UGLY)
# while we are at it, check to see if there are hosts out of range for target

# play  find that column
  $dbqpos = GetHeaderPos($db_qry);
  
# map in all the current addresses in the target range
  for $i ( 1 .. $#$db_qry ) {
# Loop through the values returned.
# items referenced as follows...
#  $db_qry->[$i][$id],
#      print STDERR join( '|', @{$db_qry->[$i]}, "\n");
    if ($db_qry->[$i][$dbqpos->{'machine.ip_address'}] != 0){
      $tgt_ip_lst{$db_qry->[$i][$dbqpos->{'machine.ip_address'}]} = @{$db_qry->[$i]}[$dbqpos->{'machine.mac_address'}];
      $err_txt = CMU::Netdb::long2dot(@{$db_qry->[$i]}[$dbqpos->{'machine.ip_address'}]);
      warn __FILE__ . ":" . __LINE__ . ": Adding @{$db_qry->[$i]}[$dbqpos->{'machine.mac_address'}] to tgt_ip_lst on index $err_txt\n" if $debug >= 3;
    }
    if (length($db_qry->[$i][$dbqpos->{'machine.mac_address'}]) != 0){
      $tgt_hw_lst{$db_qry->[$i][$dbqpos->{'machine.mac_address'}]} = $db_qry->[$i][$dbqpos->{'machine.ip_address'}];
      $err_txt = CMU::Netdb::long2dot($db_qry->[$i][$dbqpos->{'machine.ip_address'}]);
      warn __FILE__ . ":" . __LINE__ . ": Adding $err_txt to tgt_hw_lst on index @{$db_qry->[$i]}[$dbqpos->{'machine.mac_address'}]\n" if $debug >= 3;
    }
  }
  
  if (($direct == 1) && (! $comp)){
    warn __FILE__ . ":" . __LINE__ . ": Checking for insert IP collisions\n" if $debug >= 1;
    $i = 0;
    
    warn __FILE__ . ":" . __LINE__ . ": " . Data::Dumper->Dump([\%tgt_ip_lst],['%tgt_ip_lst']) . "\n";
# loop through the list of effected hosts
    for $i ( 1 .. $#$src_info ) {
      
      $tgt_ip = $src_info->[$i][$srcpos->{'machine.ip_address'}] + $delta;
      $err_txt = CMU::Netdb::long2dot($src_info->[$i][$srcpos->{'machine.ip_address'}]);
      if ($tgt_ip > ($t_base + $target_size + 1)){
	warn __FILE__ . ":" . __LINE__ . ": >>> Host $err_txt will land out of range at " . CMU::Netdb::long2dot($tgt_ip) . "\n";
	$retval++;
      }
      next if !defined $tgt_ip_lst{$tgt_ip};
      $err_txt = CMU::Netdb::long2dot($tgt_ip);
      warn __FILE__ . ":" . __LINE__ . ": tgt_ip = $tgt_ip ($err_txt)\n" if $debug >= 3;
      if ($tgt_ip_lst{$tgt_ip} != $src_info->[$i][$srcpos->{'machine.mac_address'}]){
	$err_txt = CMU::Netdb::long2dot($src_info->[$i][$srcpos->{'machine.ip_address'}]);
	warn __FILE__ . ":" . __LINE__ . ": >>> Address collision for $err_txt ($tgt_ip_lst{$tgt_ip} != @{$src_info->[$i]}[$srcpos->{'machine.mac_address'}])\n";
	$retval++;
      }
    }
    
  }
  
# check for pre-reged hosts
  warn __FILE__ . ":" . __LINE__ . ": Checking for \"pre-registered\" hosts\n" if $debug >= 1;
  for $i ( 1 .. $#$src_info ) {
    warn __FILE__ . ":" . __LINE__ . ": Checking hardware address \"$src_info->[$i][$srcpos->{'machine.mac_address'}]\"\n" if ($debug >= 3);
    
    if ((!$comp) && ($src_info->[$i][$srcpos->{'machine.mac_address'}] ne "") &&  defined $tgt_hw_lst{$src_info->[$i][$srcpos->{'machine.mac_address'}]}){
      warn __FILE__ . ":" . __LINE__ . ": >>> Hardware address $src_info->[$i][$srcpos->{'machine.mac_address'}] is preregistered in target subnet.\n\>>>> Error will be present in output for this host\n";
    }
    
    if (($comp) && ($src_info->[$i][$srcpos->{'machine.mac_address'}] ne "") &&  ! defined $tgt_hw_lst{$src_info->[$i][$srcpos->{'machine.mac_address'}]}){
      warn __FILE__ . ":" . __LINE__ . ": >>> Hardware address $src_info->[$i][$srcpos->{'machine.mac_address'}] is NOT preregistered in target subnet.\n\>>>> Host information will be lost <<<<\n";
      warn __FILE__ . ":" . __LINE__ . ": comp = $comp," .
	"src_info->[$i][$srcpos->{'machine.mac_address'}] = " .
	  "$src_info->[$i][$srcpos->{'machine.mac_address'}], " . 
	    "tgt_hw_lst{$src_info->[$i][$srcpos->{'machine.mac_address'}]} = " .
	      "$tgt_hw_lst{$src_info->[$i][$srcpos->{'machine.mac_address'}]}\n";
      $retval++;
    }
    
  }
  return($retval);
}
  

$debug = 0;
CMU::Netdb::netdb_debug({helper => 0});
CMU::Netdb::netdb_debug(0);
CMU::Netdb::netdb_debug({primitives => 0});

my $id = getopts('hdrotvpcVO:F:T:D:', \%opts);

if (defined $opts{h}){
  usage();
  die("\n");
}

$pre = (defined $opts{p}) ? 1 : 0;
$comp = (defined $opts{c}) ? 1 : 0;
$one2one = 0;
$test_only = 0;
$dyn = "";
$res =  "";
$offset = 0;
$tgt_arg = 1;
$one2one = 1 if defined $opts{o};
$test_only = 1 if defined $opts{t};
$dyn = "or machine.mode = \"dynamic\"" if defined  $opts{d};
$res = "or machine.mode = \"reserved\"" if defined $opts{r};
$debug++ if defined $opts{v};
$debug = $debug + 2 if defined $opts{V};
$infile = $opts{F} if defined $opts{F};
$tgt_arg = 0 if defined $opts{F};
$offset = $opts{O} if defined $opts{O};
$domain = $opts{D} if defined $opts{D};
if ((defined $opts{F}) && (defined $opts{o})){
  warn __FILE__ . ":" . __LINE__ . ": Cannot use -o and -F\n";
  &usage($dbh);
  die ("\n");
}
if ((defined $opts{O}) && (!defined $opts{o})){
  warn __FILE__ . ":" . __LINE__ . ": -O used without -o\n";
  &usage($dbh);
  die ("\n");
}
if ((defined $opts{T}) and (
			    (defined $opts{d}) ||
			    (defined $opts{o}) ||
			    (defined $opts{O}) ||
			    (defined $opts{p}) ||
			    (defined $opts{c}) ||
			    (defined $opts{F}))){
  warn __FILE__ . ":" . __LINE__ . ": -T cannot be used with any of d,o,O,F,p,c.\n";
  &usage($dbh);
  die("\n");
}
if ($pre && $comp) {
  warn __FILE__ . ":" . __LINE__ . ": Cannot do preregister and complete move in same pass\n";
  usage($dbh);
  die("\n");
}

warn __FILE__ . ":" . __LINE__ . ": " . (join("|", @ARGV, "id", $id)) .  "\n" if ($debug >= 2);

$user="netreg";

warn __FILE__ . ":" . __LINE__ . ": Connecting to database..\n" if $debug >= 1;
$dbh = CMU::Netdb::lw_db_connect();
warn __FILE__ . ":" . __LINE__ . ": connected\n" if $debug >= 1;

#                       Get subnet info for target subnet
warn __FILE__ . ":" . __LINE__ . ": Getting information on target subnet...\n" if $debug >= 1;
$db_result = CMU::Netdb::list_subnets($dbh, $user, "( subnet.abbreviation like \"$ARGV[$tgt_arg]\"  )  ");
     
if (not ref $db_result){
  warn __FILE__ . ":" . __LINE__ . ": \nerror $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get subnet info for target subnet $ARGV[$tgt_arg]\n";
  &usage($dbh);
  die("\n");
}
warn __FILE__ . ":" . __LINE__ . ": done\n" if $debug >= 1;

$i = 0;
$dbrpos = GetHeaderPos($db_result);
#foreach (@{$db_result->[0]}){
#  map column headers from reply
#  $id = $i if ($_ eq 'subnet.id');
#  $base = $i if ($_ eq 'subnet.base_address');
#  $mask = $i if ($_ eq 'subnet.network_mask');
#  print STDERR $_ . "\n";
#  $i++
#}
if ($#$db_result != 1){
  warn __FILE__ . ":" . __LINE__ . ": No target subnet found \n";
  &usage($dbh);
  die("\n");
}
#print STDERR join( '|', @{$db_result->[1]}, "\n");

#for $i ( 1 .. $#$db_result ) {
# Loop through the values returned.
# items referenced as follows...
#  @{$db_result->[$i]}[$id],
#  print STDERR join( '|', @{$db_result->[$i]}, "\n");
#}

$target_sn = $db_result->[1][$dbrpos->{'subnet.id'}];
$target_base = $db_result->[1][$dbrpos->{'subnet.base_address'}];
$target_mask = $db_result->[1][$dbrpos->{'subnet.network_mask'}];
warn __FILE__ . ":" . __LINE__ . ": target_sn = $target_sn\n" if ($debug >= 2);

if ( not defined $infile ){
#                        get subnet number for source subnet
  warn __FILE__ . ":" . __LINE__ . ": Getting information on source subnet...\n" if $debug >= 1;
  $db_result = CMU::Netdb::list_subnets($dbh, $user, "( subnet.abbreviation like \"$ARGV[0]\"  ) ");
  
  if ((not ref $db_result) && ($#$db_result != 1)){
    warn __FILE__ . ":" . __LINE__ . ": \nerror $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get subnet info for source subnet $ARGV[0]\n";
    &usage($dbh);
    die("\n");
  }
  warn __FILE__ . ":" . __LINE__ . ": done\n" if $debug >= 1;
  
#print STDERR join( '|', @{$db_result->[1]}, "\n");
  $src_base = $db_result->[1][$dbrpos->{'subnet.base_address'}];
  
  $delta = ($target_base - $src_base) + $offset if ($one2one == 1);
#$str = CMU::Netdb::long2dot($delta);
#print STDERR "delta = $delta ( $str )\n";
  
# get machine list from source subnet
  warn __FILE__ . ":" . __LINE__ . ": Getting host list for subnet $ARGV[0]...\n" if $debug >= 1;
  $db_result = CMU::Netdb::list_machines_subnets($dbh, $user, "(( subnet.abbreviation like \"$ARGV[0]\" ) and ((machine.mode = \"static\" $dyn $res))) order by machine.ip_address");
  if (not ref $db_result){
    warn __FILE__ . ":" . __LINE__ . ": \nerror $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get subnet hosts from subnet $ARGV[0]\n";
    &usage($dbh);
    die("\n");
  }
  
} else {
  if (open (INFILE, $infile) == 0){
    warn __FILE__ . ":" . __LINE__ . ": File $infile cannot be opened for read\n";
    &usage($dbh);
    die("\n");
  }
  while ($inline = <INFILE>){
    chomp $inline;
    next if $inline =~ /^#.*/;
    $inline =~ s/\s//g;
    $inline =~ s/\t//g;
    $inline =~ s/\r//g;
    if ($inline !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/){
      warn __FILE__ . ":" . __LINE__ . ": Bad input line in file\n$inline\n";
      &usage($dbh);
      die("\n");
    }
    if (defined $dynqry){
      $dynqry = $dynqry . " or (machine.ip_address = INET_ATON(\"$inline\"))";
    } else {
      $dynqry = "(machine.ip_address = INET_ATON(\"$inline\"))";
    }
  }
  warn __FILE__ . ":" . __LINE__ . ": Using host query ($dynqry)\n" if ($debug >= 2);
  $db_result = CMU::Netdb::list_machines_subnets($dbh, $user, "($dynqry) order by machine.ip_address");
  if (not ref $db_result){
    warn __FILE__ . ":" . __LINE__ . ": \nerror $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get subnet hosts from host query ($dynqry)\n";
    &usage($dbh);
    die("\n");
  }
  
  
}


warn __FILE__ . ":" . __LINE__ . ": done\n" if $debug >= 1;

if (test_move($target_base, $target_mask, $target_sn, $src_base, $db_result, $one2one, $res, $dyn, $comp, $domain ) && ! $test_only){
  print STDERR ("Errors possible in transfer, continue anyway [y/n] >>>==> ");
  $in_str = <STDIN>;
  chomp $in_str;
  if ($in_str !~ /y/){
    $dbh->disconnect();
    print STDERR "Aborting\n";
    exit;
  }
}
if ($test_only == 1) {
    $dbh->disconnect();
    warn __FILE__ . ":" . __LINE__ . ": Exiting due to test only flag\n";
    exit;
}

$i = 0;

$dbrpos = GetHeaderPos($db_result);

warn __FILE__ . ":" . __LINE__ . ": Processing host list\n" if $debug >= 1;
for $i ( 1 .. $#$db_result ) {
# Loop through the values returned.
# items referenced as follows...
#  $db_result->[$i][$id],
  undef %target_attr;
  map_info($dbh, $user, \%target_attr, \%target_perm, $db_result->[$i], $dbrpos) if ($pre);
  if ((! $pre) && (defined $domain) ) {
    my ($hn, @dn) = split(/\./,$db_result->[$i][$dbrpos->{'machine.host_name'}], 2);
    $target_attr{host_name} = "$hn.$domain";
  }
  $target_attr{ip_address_subnet} = $target_sn;
  $target_attr{ip_address} = "";
  $target_attr{host_name_ttl} = 0;
  $target_attr{ip_address_ttl} = 0;
  
  warn __FILE__ . ":" . __LINE__ . ": " . Data::Dumper->Dump([\%target_attr, \%target_perm], ['%target_attr', '%target_perm']) . "\n" if ($debug >= 4);

  if ($one2one == 1){
    $target_attr{ip_address} = ($db_result->[$i][$dbrpos->{'machine.ip_address'}] + $delta);
    $target_attr{ip_address} = CMU::Netdb::long2dot($target_attr{ip_address});
  }
  $old_ip = CMU::Netdb::long2dot($db_result->[$i][$dbrpos->{'machine.ip_address'}]) ;

#  print STDERR join( '|', "doing >>>==> ", @{$db_result->[$i]}, "\n");

  if ($pre == 1) {
    my (%ttls);
    undef %ttls;
    $ttls{host_name_ttl} = 300;
    $ttls{ip_address_ttl} = 300;
    
    warn __FILE__ . ":" . __LINE__ . ": calling add_machine($dbh, $user, 9, \%target_attr, \%target_perm) \n" .
      Data::Dumper->Dump([\%target_attr, \%target_perm], ['%target_attr', '%target_perm']) . "\n" if ($debug >= 2);
    
    ($res, $ret) = CMU::Netdb::modify_machine($dbh, $user, $db_result->[$i][$dbrpos->{'machine.id'}], $db_result->[$i][$dbrpos->{'machine.version'}], 9, \%ttls);
      
    warn __FILE__ . ":" . __LINE__ . ": error $res ( $CMU::Netdb::errmeanings{$res} " . join (', ',@$ret) . ") while attempting to update TTLs \n"if ($res < 1);

    ($res, $ret) = CMU::Netdb::add_machine($dbh, $user, 9, \%target_attr, \%target_perm);
  } else {
    if ($comp) {
      my ($deldata, $delpos);
      warn __FILE__ . ":" . __LINE__ . ": Calling list_machines_subnets(\$dbh, $user, \"((machine.mac_address = \"$db_result->[$i][$dbrpos->{'machine.mac_address'}]\") and (machine.host_name like \"new-" . join("", split(/\./,$db_result->[$i][$dbrpos->{'machine.host_name'}])) . ".net.cmu.edu\"))\")\n" if ($debug >= 2);
      $deldata = CMU::Netdb::list_machines_subnets($dbh, $user, "((machine.mac_address = \"$db_result->[$i][$dbrpos->{'machine.mac_address'}]\") and (machine.host_name like \"new-" . join("", split(/\./,$db_result->[$i][$dbrpos->{'machine.host_name'}])) . ".net.cmu.edu\"))");
      if (! ref $deldata) {
	warn __FILE__ . ":" . __LINE__ . ": Error searching for pre-registration in target network, skipping\n" .
	  "error $deldata ( $CMU::Netdb::errmeanings{$deldata})\n " .
	    Data::Dumper->Dump([$db_result->[$i]], ['MachineInfo']);
	next;
      }
      $delpos = GetHeaderPos($deldata);
      # CHECK FOR NO LINES RETURNED!!!!
      if ($#$deldata == 0) {
	warn __FILE__ . ":" . __LINE__ . ": Could not find pre-registration for host " . CMU::Netdb::long2dot($db_result->[$i][$dbrpos->{'machine.ip_address'}]) . " not re-IPing\n";
	next;
      }
      $target_attr{ip_address} = CMU::Netdb::long2dot($deldata->[1][$delpos->{'machine.ip_address'}] || 0);
      
      warn __FILE__ . ":" . __LINE__ . ": Lookup of old host returned \n" . Data::Dumper->Dump([$deldata],['deldata']) . "\n" if ($debug >= 3);
      my ($delval, $delmsg) = CMU::Netdb::delete_machine($dbh, $user, $deldata->[1][$delpos->{'machine.id'}],$deldata->[1][$delpos->{'machine.version'}]);
      if ($delval != 1) {
	warn __FILE__ . ":" . __LINE__ . ": Error deleting existing host at " .
	  CMU::Netdb::long2dot($deldata->[1][$delpos->{'machine.ip_address'}]) .
	    "\n error $delval ( $CMU::Netdb::errmeanings{$delval} [" . join(', ', @$delmsg) . "] )\n" . Data::Dumper->Dump([\$delval], ['$delval']) . "\n";
	next;
      }
    }
    warn __FILE__ . ":" . __LINE__ . ": calling modify_machine($dbh, $user, $db_result->[$i][$dbrpos->{'machine.id'}], $db_result->[$i][$dbrpos->{'machine.version'}], 9, \%target_attr) \n" .
      Data::Dumper->Dump([\%target_attr], ['%target_attr']) . "\n" if ($debug >= 2);
    ($res, $ret) = CMU::Netdb::modify_machine($dbh, $user, $db_result->[$i][$dbrpos->{'machine.id'}], $db_result->[$i][$dbrpos->{'machine.version'}], 9, \%target_attr);
  }
  
  $new_ip = CMU::Netdb::long2dot($target_attr{ip_address});
  
  warn __FILE__ . ":" . __LINE__ . ": " . Data::Dumper->Dump([\%target_attr], ['%target_attr']) . "\n" if ($debug >=3);

  if ($res < 1)  {
    warn __FILE__ . ":" . __LINE__ . ": error $res ( $CMU::Netdb::errmeanings{$res} " . join (', ',@$ret) . ") while attempting to " . ($pre ? "add\n" : "update \n");
    warn __FILE__ . ":" . __LINE__ . ": " . join( '|', @{$db_result->[$i]}, "\n");
    warn __FILE__ . ":" . __LINE__ . ": target_attr{ip_address_subnet} =  $target_attr{ip_address_subnet}\n";
    $str = CMU::Netdb::long2dot($target_attr{ip_address});
    warn __FILE__ . ":" . __LINE__ . ": target_attr{ip_address} = $target_attr{ip_address} ( $str )\n";
    warn __FILE__ . ":" . __LINE__ . ": " . Data::Dumper->Dump([\%target_attr], ['%target_attr']) . "\n";

    undef $res;
    undef $ret;
  } 
  print STDERR "$old_ip -> $new_ip\n";

#  $cnt += 1;
#  if ($cnt >= 3){
#    $dbh->disconnect();
#    exit(0);
#  }

}



$dbh->disconnect();
print STDERR "Done\n\n";

# Function: GetHeaderPos
#
# Arguments: 1
#    Pointer to array of arrays as returned by primitives::List
#
# Actions: 
#    Creates hash of positions of columns that are returned
#
# Return value: 
#    pointer to hash
#
# Side effects:
#    None
#
# Caveats:
#    Make sure to check if a value is defined before you use it.
# 

sub GetHeaderPos {
  my ($data) = @_;
  my ($i, %heads);

  $i = 0;
  %heads = ();

  foreach (@{$data->[0]}){
#  map column headers from reply
    warn __FILE__ . ":" . __LINE__ . ": $_ \n" if $debug >= 25;
    $heads{$_} = $i;
    $i++
  }
  return (\%heads);

}

sub map_info{
  my ($dbh, $usr, $attr, $perm, $info, $inpos) = @_;
  my ($tbl, $col, $perms, $perpos);

  $perms = CMU::Netdb::list_groups($dbh, $usr, "(groups.name like 'dept:ngtemp')");
  die "Could not find group information for group \"dept:ngtemp\"\n" if ((! ref $perms) || ($#$perms == 0));

  $perpos = GetHeaderPos($perms);

  


  foreach (keys %$inpos ) {
    ($tbl, $col) = split( /\./, $_);
    next if ($tbl ne "machine");
    warn __FILE__ . ":" . __LINE__ . ": Adding $col ($info->[$inpos->{$_}]) from $tbl\n" if ($debug >= 4);
    next if (($col eq "version") || ($col eq "id") || ($col eq "created"));
    next if ((! defined $info->[$inpos->{$_}]) || (length($info->[$inpos->{$_}]) == 0)) ;
    $attr->{$col} = $info->[$inpos->{$_}];
  }
  $attr->{'host_name'} = "NEW-" . $attr->{'host_name'};
  $attr->{'host_name'} =~ s/\.//g;
  $attr->{'host_name'} .= ".net.cmu.edu";
  
  $attr->{'dept'} = $perms->[1][$perpos->{'groups.name'}];
  $perm->{dc0m}[0] = 'READ,WRITE';
  $perm->{dc0m}[1] = 1;

}
