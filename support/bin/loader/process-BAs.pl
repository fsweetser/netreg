#! /usr/bin/perl
#
# $Id: process-BAs.pl,v 1.2 2008/03/27 19:42:45 vitroth Exp $
#
# $Log: process-BAs.pl,v $
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
# Revision 1.1  2000/08/10 14:43:47  kevinm
# *** empty log message ***
#
#

my ($adminfile, $mapfile, $outfile) = @ARGV;

if ($adminfile eq '' || $mapfile eq '' || $outfile eq '') {
  print "$0 [adminfile] [mapfile] [outfile]\n";
  exit;
}

my %map;
open(MAP, $mapfile) || die "Cannot open mapfile $mapfile.";
while(<MAP>) {
  my @a = split(/\|/, $_);
  $map{$a[0]} = $a[1];
}
close(MAP);

my %deptMap;
open(OUT, ">$outfile") || die "Cannot open outfile $outfile.";    
open(FILE, $adminfile) || die "Cannot open admin file $adminfile";
while(<FILE>) {
  my @b = split(/\s+/, $_);
  my $userid = shift(@b);
  shift(@b); shift(@b);
  my $dept = join(' ', @b);
  if (defined $map{$dept}) {
    if (!defined $deptMap{"$userid|$map{$dept}"}) {
      print OUT "$userid|$map{$dept}\n";
      $deptMap{"$userid|$map{$dept}"} = 1;
    }
  }else{
    print "$dept\n";
  }
}
close(FILE);
close(OUT);
