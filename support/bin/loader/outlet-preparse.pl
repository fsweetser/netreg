#! /usr/bin/perl

open(FILE, $ARGV[0]);
open(OFILE, ">$ARGV[1]");

my %outlets;
while(<FILE>) {
  next if ($_ =~ /^\#/);
  my ($from, $to, $user) = split(/\|/, $_);
  if (defined $outlets{"$from/$to"}) {
    push(@$outlets{"$from/$to"}, $user);
  }else{
    $outlets{"$from/$to"} = [$user];
  }
}
close(FILE);
