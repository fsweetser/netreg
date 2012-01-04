#! /usr/bin/perl

## Update these files
my @Files = qw/
  afs-xfer.sh
  domain-reports.sh
  dump-db.sh

  /;

$Config_Block =<<CONFIG_BLOCK;

## Warning! The contents of this file between BEGIN-CONFIG-BLOCK and
## END-CONFIG-BLOCK are updated from vars-update.pl

## NRHOME should be set to the NetReg home directory
NRHOME=/home/netreg

## NRUSER should be set to the default NetReg user
NRUSER=netreg

MYSQL_PATH=/usr/local/bin
MYSQL=$MYSQL_PATH/mysql
MYSQLDUMP=$MYSQL_PATH/mysqldump

CONFIG_BLOCK


foreach my $File (@Files) {
  unless (-e $File) {
    warn "Cannot open $File!\n";
    next;
  }

  open(OLD, $File)
    || warn "Cannot read $File!";
  open(NEW, ">$File.new")
    || (warn "Cannot write $File.new!" && next);
  
  my $Print = 1;
  while(my $Line = <OLD>) {
    $Print = 1 if ($Line =~ /-END-CONFIG-BLOCK-/);
    print NEW $Line if ($Print);

    if ($Line =~ /-BEGIN-CONFIG-BLOCK-/) {
      print NEW $Config_Block;
      $Print = 0;
    }
  }
  close(OLD);
  close(NEW);
  rename("$File.new", $File) 
    || warn "Cannot rename $File.new to $File!";
  chmod 0755, $File;
  print "Updated $File\n";
}
  
    

