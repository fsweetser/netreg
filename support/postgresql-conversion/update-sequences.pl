#!/usr/bin/perl -w

use strict;
use Data::Dumper;

unless (defined($ARGV[0]) and $ARGV[0] ne "") {
    die "Usage: $0 <directory>\n";
}
my $d = $ARGV[0];

opendir(DIR, $d) or die "Cannot opendir $d: $!\n";
my @files = readdir DIR;
closedir DIR;
    
foreach my $f ( @files ){
    next unless $f =~ /\.sql$/;
    # print "Opening $d/$f\n";
    open(F, "$d/$f") or die "Cannot open $d/$f: $!\n";

    my $table;
    my $curval;
    while(<F>){
	if(/CREATE TABLE (.*) /){
	    $table = $1;
	}elsif(/AUTO_INCREMENT=(\d+)/){
	    $curval = $1;
	}
    }
    if(defined($table)){
	$table =~ s/[\'\"\`]//g;
	if(defined($curval)){
	    print STDERR "Setting $table to $curval\n";
	    print "ALTER SEQUENCE ", $table, "_id_seq RESTART WITH ", $curval+1, ";\n";
	}else{
	    print STDERR "Skipping $table\n";
	}
    }
}

