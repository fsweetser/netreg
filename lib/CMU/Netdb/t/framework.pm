#
# Copyright (c) 2003-2004 Carnegie Mellon University. All rights reserved.
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
#
# $Id: framework.pm,v 1.8 2008/03/27 19:42:36 vitroth Exp $
#
# $Log: framework.pm,v $
# Revision 1.8  2008/03/27 19:42:36  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.7.14.1  2007/10/11 20:59:41  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.7.12.1  2007/09/20 18:43:05  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.7  2004/06/24 02:05:35  kevinm
# * Credentials/machine type pulled to head
#
# Revision 1.6.6.1  2004/06/21 15:53:42  vitroth
# Merging credentials & machine type permissions branches.
# Inital merge complete, no testing done yet.
# Still need to update convert script and schema.
#
# Revision 1.6.2.1  2004/06/17 19:10:12  kevinm
# * Credentials updates to tests
#
# Revision 1.6  2004/05/25 14:19:06  kevinm
# * More tests, more debugging
#
# Revision 1.5  2004/05/23 04:08:06  kevinm
# * Run "ANALYZE TABLE" on all tables after load
#
# Revision 1.4  2004/05/21 17:26:39  kevinm
# * Provide hints on setting up database passwords and access
#
# Revision 1.3  2004/05/17 15:26:35  kevinm
# *** empty log message ***
#
# Revision 1.2  2004/05/17 14:58:07  kevinm
# * Moved location of NetReg schema
#
# Revision 1.1  2004/05/10 21:45:37  kevinm
# *** empty log message ***
#
#
#
package CMU::Netdb::t::framework;

use strict;

use vars qw/@ISA @EXPORT @EXPORT_OK/;

require Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/reload_db test_db_connect optimize_db dump_db/;

use CMU::Netdb;
use CMU::Netdb::config;

# Taint mode protection
delete @ENV{qw/IFS CDPATH ENV BASH_ENV/};

# Prime the config
my ($res, $val) = get_multi_conf_var('test-netdb', 'netdb-conf');
if ($res != 1 or $val eq '') {
  diag("test-netdb configuration needs to have netdb-conf specified");
  die;
}

$ENV{'NETREG_netdb_CONF'} = $val;

($res, $val) = get_multi_conf_var('test-netdb', 'path');
if ($res != 1 or $val eq '') {
  diag("test-netdb configuration needs a PATH setting");
  die;
}

if ($val =~ /([\w\:\d\.\-\/]+)/) {
  $ENV{PATH} = $1;
}

sub get_db_param {
  my $BaseSchema = get_multi_conf_var('test-netdb', 'netdb-schema');
  $BaseSchema = '../../../../doc/db/NETREG-COMPLETE.sql'
    unless ($BaseSchema ne '' && -r $BaseSchema);

  die "Can not find DB schema: $BaseSchema" unless (-r $BaseSchema);

  my $TestDB = get_multi_conf_var('test-netdb', 'test-db');

  die "Could not find test-db information" unless (ref $TestDB);

  die "Could not find connect string information"
    unless (defined $TestDB->{'connect_string'});

  my ($dbi, $type, $db, $host) = split(/\:/, $TestDB->{'connect_string'});

  die "Unsupported db type: $type" unless ($type eq 'mysql');

  my $Pass;

  if (defined $TestDB->{'password_file'}) {
    open(FILE, $TestDB->{'password_file'})
      || die_s("Cannot open DB password file (".
	       $TestDB->{'password_file'}.")!",
	       $TestDB, $host, $db);
    $Pass = <FILE>;
    close(FILE);
  }else{
    $Pass = $TestDB->{'password'};
  }
  return {'db' => $db,
	  'host' => $host,
	  'user' => $TestDB->{'username'},
	  'pass' => $Pass,
	  'schema' => $BaseSchema};
}

sub dump_db {
  my ($dumpfile) = @_;

  $| = 1;
  my $rDB = get_db_param();

  print "Dumping $dumpfile...";
  dump_db_data($dumpfile, $rDB->{'db'}, $rDB->{'host'}, $rDB->{'user'},
	       $rDB->{'pass'});
  print "done\n";
}

sub reload_db {
  my ($loadfile) = @_;

  die "DB Load file not found: $loadfile" unless (-r $loadfile);
  $| = 1;

  my $rDB = get_db_param();

  print "Loading $loadfile...";
  load_schema($rDB->{'schema'}, $rDB->{'db'}, $rDB->{'host'},
	      $rDB->{'user'}, $rDB->{'pass'});
  load_db_data($loadfile, $rDB->{'db'}, $rDB->{'host'}, $rDB->{'user'},
	       $rDB->{'pass'});
  print "done\n";

  optimize_db(test_db_connect());
}

sub optimize_db {
  my ($dbh) = @_;

  print "Optimizing database...";
  my $sth = $dbh->prepare("SHOW TABLES");
  $sth->execute();
  my @Tables = sort {$a cmp $b } map { $_->[0] } @{$sth->fetchall_arrayref()};
  foreach my $T (@Tables) {
    $dbh->do("ANALYZE TABLE $T");
  }
  $dbh->disconnect();
  print "done\n";
}

sub load_schema {
  my ($Schema, $db, $host, $user, $pass) = @_;

  open(FILE, $Schema) or die "Error opening schema ($Schema): $!";
  my @S = <FILE>;
  close(FILE);
  my $S = join('', @S);

  $S =~ s/DROP DATABASE IF EXISTS netdb/DROP DATABASE IF EXISTS `$db`/s;
  $S =~ s/CREATE DATABASE netdb/CREATE DATABASE `$db`/s;
  $S =~ s/CONNECT netdb/CONNECT $db/s;

  $pass = untaint($pass);
  $user = untaint($user);
  $host = untaint($host);

  my $cmd = "|mysql -u '$user' -p'$pass' --host='$host'";
  open(MYSQL, $cmd) or die "Unable to spawn cmd: $cmd: $!";
  print MYSQL $S;
  close(MYSQL);

}

sub load_db_data {
  my ($File, $db, $host, $user, $pass) = @_;

  $user = untaint($user);
  $pass = untaint($pass);
  $host = untaint($host);
  $db = untaint($db);

  die "DB data file doesn't exist: $File" unless (-r $File);
  $File = untaint($File);

  my $ret;
  my $DeleteFile = 0;

  if ($File =~ /\.gz$/) {
    my $Short = $File;
    $Short =~ s/.+\/([^\/]+)/$1/;
    $Short =~ s/\.gz$//;

    $ret = system("zcat $File > /tmp/netdbtest-$$-$Short");
    if ($ret >> 8 != 0) {
      die "DB data load ($File) failed, zcat returned: $ret";
    }
    $File = "/tmp/netdbtest-$$-$Short";
    $DeleteFile = 1;
  }

  $ret = system("mysql -u '$user' -p'$pass' --host='$host' '$db' < $File");
  if ($ret >> 8 != 0) {
    die "DB data load ($File) failed, mysql returned: $ret";
  }

  unlink($File) if ($DeleteFile);
}

sub dump_db_data {
  my ($File, $db, $host, $user, $pass) = @_;

  my $ret;

  $user = untaint($user);
  $pass = untaint($pass);
  $host = untaint($host);
  $db = untaint($db);
  $File = untaint($File);

  my $Short = $File;
  $Short =~ s/.+\/([^\/]+)/$1/;
  $Short =~ s/\.gz$//;

  open(FILE, ">$Short") or die "DB data dump failed, cannot open $Short: $!";
  print FILE "SET FOREIGN_KEY_CHECKS=0;\n";
  close(FILE);

  $ret = system("mysqldump -u '$user' -p'$pass' --host='$host' '$db' -n -t ".
		">> $Short");
  if ($ret >> 8 != 0) {
    die "DB data dump ($File) failed, mysqldump returned: $ret";
  }

  if ($File =~ /\.gz$/) {
    $ret = system("gzip -f $Short");
    if ($ret >> 8 != 0) {
      die "DB data dump ($File) failed, gzip returned: $ret";
    }
    $Short .= '.gz';
  }

  rename($Short, $File) or die "DB data dump ($File) failed, rename returned: $!";
}

sub test_db_connect {
  my $TestDB = get_multi_conf_var('test-netdb', 'test-db');

  die "Could not find test-db information" unless (ref $TestDB);

  my $dbh = __generic_db_connect($TestDB);
  die "Could not establish DB connection" unless (defined $dbh);
  return $dbh;
}

# Die, but help setup the database foo
sub die_s {
  my ($msg, $dbinfo, $host, $db) = @_;

  print STDERR "***********************************************************\n";
  print STDERR "Connection failed; if you haven't setup the password file
or access for this host, you can run the following to do so:\n";
  my $pwd = '';
  if (defined $dbinfo->{'password_file'}) {
    $pwd = genRandomPassword();
    $pwd =~ s/\!/A/;
    print STDERR "perl -e 'print \"$pwd\"' > ".$dbinfo->{'password_file'}."\n";
  }elsif(defined $dbinfo->{'password'}) {
    $pwd = $dbinfo->{'password'};
  }else{
    print STDERR "Your db configuration doesn't have a password or
password_file specified; not sure how you intend to make this work.
Please see the sample configuration.\n";
    print STDERR "***********************************************************\n";
    die $msg;
  }

  my $user = $dbinfo->{'username'};
  if ($user eq '') {
    print STDERR "Your db configuration doesn't have a username specified.
I'm not sure how you intend to make this work. Please see the sample
configuration.\n";
    print STDERR "***********************************************************\n";
    die $msg;
  }

  my $dbhost = 'localhost';
  if ($host ne 'localhost') {
    $dbhost = `hostname`;
    chomp($dbhost);
  }

  print STDERR "Connect to the database:\nmysql -u root -p --host=$host\n";
  print STDERR "Send the following command:\n";
  print STDERR "grant select,insert,update,delete,create,drop on `$db`.* to ".
    "`$user`@`$dbhost` identified by '$pwd';\n";
  print STDERR "***********************************************************\n";
  die $msg;
}

sub genRandomPassword {
  my $buf = '';
  my $chrStore = 0;
  my $iter = 0;
  while(length($buf) < 18) {
    $chrStore += rand(256) + ($iter++ % 18);
    $chrStore = $chrStore % 256;
    if (chr($chrStore) =~ /[A-Za-z0-9\-\.\,\!\@\#\$\%\^\&\*\(\)\[\]]/) {
      $buf .= chr($chrStore);
    }
  }
  return $buf;
}

sub __generic_db_connect {
  my ($DBInfo) = @_;

  my $pass;

  if (defined $DBInfo->{'password_file'}) {
    open(FILE, $DBInfo->{'password_file'})
      || die "Cannot open DB password file (".$DBInfo->{'password_file'}.")!";
    $pass = <FILE>;
    close(FILE);
  }else{
    $pass = $DBInfo->{'password'};
  }

  my $dbh = DBI->connect($DBInfo->{'connect_string'},
			 $DBInfo->{'username'},
			 $pass);
  return $dbh;
}

sub untaint {
  my ($in) = @_;
  $in =~ /(.+)/;
  return $1;
}
