#! /usr/bin/perl
#
# Outlet group information 'reloader'
# 
# $Id: reload-outlets.pl,v 1.2 2008/03/27 19:42:45 vitroth Exp $
#
# $Log: reload-outlets.pl,v $
# Revision 1.2  2008/03/27 19:42:45  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.1.22.1  2007/10/11 20:59:48  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.1.20.1  2007/09/20 18:43:08  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.1  2002/01/10 03:56:44  kevinm
# Moved to loader/
#
# Revision 1.1  2000/10/05 13:00:00  kevinm
# The script to reload the outlet information.
#
#
#

use strict;
use lib '/home/netreg/lib';

use CMU::Netdb;
use CMU::Netdb::auth;
use CMU::Netdb::helper;

my $DB_INFO = "/tmp/out.groups";
my $DEPT_MAPFILE = "/home/dataload/depts/dept.mapfile";
my $DEPT_GFILE = "/home/dataload/depts/dept.gfile";
my $DEPT_DB = "/tmp/out.mgroups";
my $ORIG_DUMP = "/home/dataload/outletload/active_outlets.out.3";


# first lets verify that we have some semblance of a match
# between the gfile (which was created pre-initial load) and the
# current state of the DB
open (FILE, $DEPT_GFILE) || die "E00: Cannot open $DEPT_GFILE: $!";
my %g_groups;
my $l;
while($l = <FILE>) {
  my @la = split(/\|/, $l);
  $g_groups{$la[1]} = $la[2];
}
close(FILE);

my $n_errors = 0;
open (FILE, $DEPT_DB) || die "E01: Cannot open $DEPT_DB: $!";
while($l = <FILE>) {
  chop($l);
  my @lb = split(/\|/, $l);
  if ($g_groups{$lb[0]} ne $lb[1] && defined $g_groups{$lb[0]}) {
    print "Group ID $lb[0] is now: $lb[1], was: $g_groups{$lb[0]}. Exiting.\n";
    $n_errors++;
  }
}
close(FILE);

if ($n_errors > 0) {
  print "Exiting, $n_errors errors.\n";
  exit 1;
}

print "Stage 1: Groups old/new verified.\n";

# Let's get the mapfile loaded
#
my %g_map;
open (FILE, $DEPT_MAPFILE) || die "E02: Cannot open $DEPT_MAPFILE: $!";
while($l = <FILE>) {
  chop($l);
  my @lc = split(/\|/, $l);
  $g_map{$lc[0]} = $lc[1];
}
close(FILE);

print "Stage 2: Group mapfile loaded.\n";

# Okay, now load the outlets that need to be re-grouped
my %o_fix;

open(FILE, $DB_INFO) || die "E03: Cannot open $DB_INFO: $!";
while($l = <FILE>) {
  chop($l);
  my @ld = split(/\|/, $l);
  $ld[2] =~ s/^(R|\*|\$)//;
  $o_fix{"$ld[1]/$ld[2]"} = $ld[0];
}

close(FILE);

# Now load the original group file and try to find all these
# outlets
my %o_orig;
my %o_o_prefix;
open(FILE, $ORIG_DUMP) || die "E04: Cannot open $ORIG_DUMP: $!";
while($l = <FILE>) {
  chop($l);
  my @le = split(/\|/, $l);
  $o_orig{$le[0]} = $le[2];
  my @lf = split(/\//, $le[0]);
  $o_o_prefix{$lf[0]} = $le[2];
}
close(FILE);

print "Stage 3: Current DB dump and original dump loaded.\n";

$n_errors = 0;
# Find see if we can come up with a valid group for all the
# outlets in o_fix
my %reload_data;
foreach my $k (keys %o_fix) {
  if (defined $o_orig{$k}) {
    if (defined $g_map{$o_orig{$k}}) {
      $reload_data{$o_fix{$k}} = $g_map{$o_orig{$k}};
      print "Reload: outlet #$o_fix{$k} = group $reload_data{$o_fix{$k}}\n";
    }else{
      print "Group name not found: $o_orig{$k} (outlet $o_fix{$k})\n";
      $n_errors++;
    }
  }else{
    my @lg = split(/\//, $k);
    if (defined $o_o_prefix{$lg[0]} &&
       defined $g_map{$o_o_prefix{$lg[0]}}) {
      $reload_data{$o_fix{$k}} = $g_map{$o_o_prefix{$lg[0]}};
      print "Reload CH2: outlet #$o_fix{$k} = group $reload_data{$o_fix{$k}}\n";
    }else{
      print "Not defined in original dump: $k (id #$o_fix{$k}!\n";
      $n_errors++;
    }
  }
}

if ($n_errors > 0) {
  print "Exiting: $n_errors errors in matching groups.\n";
  exit 2;
}

print "Proceeding with database updates.\n";

#exit 3;
my $dbh = lw_db_connect() || die "E05: Can't get DB handle\n";
foreach my $rd (keys %reload_data) {
  my $sql = "UPDATE protections SET identity = -1*$reload_data{$rd} WHERE ".
    "tname = 'outlet' AND tid = $rd AND identity < 0";
  print "UPD: $sql\n";
  $dbh->do($sql);
}


  
