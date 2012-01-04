#! /usr/bin/perl

open(FILE, "proto.html");
my @a = <FILE>;
close(FILE);

foreach(@ARGV) {
  s/tags\///;
  open(FILE, ">$_.shtml");
  print FILE @a;
  close(FILE);
}
  
