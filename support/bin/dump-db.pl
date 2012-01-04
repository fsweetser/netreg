#! /usr/bin/perl

# dump-db: Periodically can be run to dump the database and tarball it up. 
# Useful for backups
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
# $Id: dump-db.pl,v 1.4 2008/03/27 19:42:41 vitroth Exp $
#
# $Log: dump-db.pl,v $
# Revision 1.4  2008/03/27 19:42:41  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.3.14.1  2007/10/11 20:59:46  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.3.12.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.3  2004/07/09 15:14:46  vitroth
# While not dumping the data from _sys_change* tables is good, we do need
# to dump the schema.  Doh.
#
# Revision 1.2  2004/07/06 22:16:31  vitroth
# Use @archive_tables array to avoid dumping changelog tables.
#
# Revision 1.1  2004/06/11 15:39:47  kevinm
# * Better dumper; writes a reload.sh to make the reloads easy
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::config;

use Data::Dumper;

$| = 1;

my $rDB = db_connect();

rundump($rDB);

sub db_connect {
  my $TestDB = get_multi_conf_var('netdb', 'DB-MAINT');
  die "Could not load maint information" unless (ref $TestDB);

  die "Could not find connect string information"
    unless (defined $TestDB->{'connect_string'});

  my ($dbi, $type, $db, $host) = split(/\:/, $TestDB->{'connect_string'});

  die "Unsupported db type: $type" unless ($type eq 'mysql');

  my $Pass;

  if (defined $TestDB->{'password_file'}) {
    open(FILE, $TestDB->{'password_file'})
      || die("Cannot open DB password file (".
	       $TestDB->{'password_file'}.")!",
	       $TestDB, $host, $db);
    $Pass = <FILE>;
    close(FILE);
  }else{
    $Pass = $TestDB->{'password'};
  }

  #Chomp'ing to make sure no newline crep in:
  chomp($Pass);

  return {'db' => $db,
	  'host' => $host,
	  'user' => $TestDB->{'username'},
	  'pass' => $Pass,
	  'schema' => $BaseSchema};
}

sub rundump {
  my ($rDB) = @_;

  my $dbUser = $rDB->{'user'};
  my $dbHost = $rDB->{'host'};
  my $pwd = $rDB->{'pass'};
  my $dbDatabase = $rDB->{'db'};

  my $DumpDB = get_multi_conf_var('netdb', 'DUMP-DB');
  die "Could not get DUMP-DB information" unless (ref $DumpDB);

  my $dumpCmd = $DumpDB->{'dump_command'};
  my $dbUnixUser = $DumpDB->{'unix_file_owner'};
  my $dumpDir = $DumpDB->{'dump_dir'};
  my $archiveDir = $DumpDB->{'archive_dir'};
  my $cleanTime = $DumpDB->{'clean_time'};

  if ($dumpCmd eq '' || $dbUser eq '' || $dbHost eq '' || $pwd eq '' ||
      $dumpDir eq '' || $dbDatabase eq '' || $dbUnixUser eq '' ||
      $archiveDir eq '' || $cleanTime eq '') {
    die "missing parameter ($dumpCmd, $dbUser, $dbHost, SECRET, $dumpDir, ".
      "$dbDatabase, $dbUnixUser, $archiveDir, $cleanTime)";
  }

  my $dTime = `/bin/date +%Y-%m-%d.%H%M`;
  chomp($dTime);

  my $sDir = "$dumpDir/$dbDatabase.$dTime";
  print "Making directory $sDir\n";
  system("mkdir $sDir") && die "Cannot mkdir $sDir";

  system("chown $dbUnixUser $sDir") && die "Cannot chown $dumpDir";

  my $tableList = join(' ', @CMU::Netdb::structure::archive_tables);

  my $Cmd = "$dumpCmd -u $dbUser --host=$dbHost -p$pwd ".
    "-T $sDir $dbDatabase $tableList";
  print "Running $Cmd\n";
  system($Cmd) && die "mysqldump failed";

  # Dump again with no data to get the schema for the non-archived tables
  $Cmd = "$dumpCmd -u $dbUser --host=$dbHost -p$pwd ".
    "-T $sDir -d $dbDatabase";
  print "Running $Cmd\n";
  system($Cmd) && die "mysqldump failed";

  print "Writing reconstruct script\n";
  reconstruct("$sDir", $dbDatabase);

  chdir($dumpDir);
  print "Tarring $dbDatabase.$dTime\n";
  system("tar zcf $dbDatabase.$dTime.tgz $dbDatabase.$dTime") 
    && die "tar of $sDir failed";

  if ($archiveDir ne $dumpDir) {
    system("mv -f $sDir.tgz $archiveDir") &&
      die "move $sDir.tgz to archive failed";
  }

  print "Cleaning up old dumps\n";
  system("rm -rf $sDir");
  rmdir($sDir);

  $cleanTime = '+'.$cleanTime;
  system("find $dumpDir -mtime $cleanTime ".' -exec rm {} \;');
}

# Puts the individual table description files back into order
sub reconstruct {
  my ($Dir, $dbName) = @_;

  my $rLoadOrder = {};

  my $filename = uc($dbName).'-COMPLETE.sql';

  opendir(DIR, $Dir) or die "Cannot opendir $Dir";
  my @Files = readdir(DIR);
  close(DIR);

  my @ExtraLoad = ();
  my %datafiles;
  foreach my $F (@Files) {
    $datafiles{$F} = 1 if ($F =~ /\.txt$/);
    next unless ($F =~ /(.+)\.sql$/);
    push(@ExtraLoad, $1) unless (defined $rLoadOrder->{$1});
  }

  my @Final = sort { $rLoadOrder->{$a} <=> $rLoadOrder->{$b} } keys %$rLoadOrder;
  push(@Final, @ExtraLoad);

  open(COMP, ">$Dir/$filename") or die "Cannot open $Dir/$filename for writing";

  print COMP "DROP DATABASE IF EXISTS $dbName;\nCREATE DATABASE $dbName;\nUSE $dbName;\n";
  print COMP "SET FOREIGN_KEY_CHECKS=0;\n";

  foreach my $F (@Final) {
    open(FILE, "$Dir/$F.sql") or die "Cannot open $Dir/$F.sql";
    while(<FILE>) { print COMP $_; }
    # Load data infile
    if (exists $datafiles{"$F.txt"}) {
      print COMP "\nLOAD DATA INFILE 'PWDIR/$F.txt' INTO TABLE $F ".
	'FIELDS TERMINATED BY \'|\';'."\n";
    }
    close(FILE);
  }

  close(COMP);

  # script to actually do the reload
  open(COMP, ">$Dir/reload.sh") or die "Cannot open reload.sh";
  print COMP "#! /bin/sh\n\n";
  print COMP 'PASS=$1'."\n\n";
  print COMP "sed -e \"s,PWDIR,\$PWD,\" $filename > $filename.local\n";
  print COMP "mysql -u root -p\$PASS < $filename.local\n\n";
  close(COMP);

  system("chmod +x $Dir/reload.sh");

}
