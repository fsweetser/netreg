#! /usr/bin/perl

require 5.005_03;

use strict;
use File::Path;
use File::Basename;
use File::Spec;
use Data::Dumper;
#use CPAN;

my $LOG_FILE = "netreg-install.log";
my $LOG_CONS = 1;
my $NR_USER = 'netreg';
my $NR_GRP = 'netreg';
my $NR_WHEEL = 'sudo';
my $CONFIG_MODE = '';
my $NRHOME = '/home/netreg';

my @REQ_PERL_MODULES = qw/DBI DBD::mysql Convert::BER Crypt::DES
  Data::Compare Digest::HMAC Digest::SHA1 IO::Stty IO::Tty Expect
  Net::DNS SNMP Net::SNMP Config::General/;
main();
exit(0);


## *********************************************************************


# Question to ask (like "Accept?")
# Default response (or blank)
# Accept no response? 1 if yes (default counts as response if available)
sub getUserInput {
  my ($question, $def, $req) = @_;

 GUI_START:
  print $question;
  if ($def ne '') {
    print " [$def]";
  }
  print ": ";
  my $inp = <STDIN>;
  chomp($inp);
  if ($inp =~ /^\s*$/) {
    if ($def eq '' && $req) {
      print "Response required!\n";
      goto GUI_START;
    }elsif($def ne '') {
      return $def;
    }else{
      return '';
    }
  }
  return $inp;
}
  
  
# Create a symlink and log it, etc.    
#  - source
#  - dest
#  - owner (ie root)
#  - group (ie wheel)
#  - perms (ie 755)
#  - force (true value to not check existence of source, etc.)
sub i_symlink {
  my ($src, $dst, $own, $grp, $perms, $force) = @_;

  if (!(-e $src) && !$force) {
    _log("symlink: Source file [$src] doesn't exist. Skipping!");
    return -1;
  }
  if ((-e $dst) && !$force) {
    _log("symlink: Dest file [$dst] already exists. Skipping!");
    return -1;
  }

  my @uInfo = getpwnam($own);
  if (!defined $uInfo[2]) {
    _log("symlink: User [$own] doesn't exist. Aborting!");
    exit(3);
  }
  my $realUID = $uInfo[2];
  
  my @gInfo = getgrnam($grp);
  if (!defined $gInfo[2]) {
    _log("symlink: Group [$grp] doesn't exist. Aborting!");
    exit(4);
  }
  my $realGID = $gInfo[2];
  
  if (symlink($src, $dst) != 1) {
    _log("symlink: Error linking $src to $dst. Skipping!");
    return -1 unless ($force);
  }
  
#  if (chown($realUID, $realGID, $dst) != 1) {
#    _log("symlink: Error chowning $dst to $realUID:$realGID. Skipping!");
#    return -1 unless ($force);
#  }

  if (chmod(oct($perms), $dst) != 1) {
    _log("symlink: Error chmoding $dst to $perms. Skipping!");
    return -1 unless ($force);
  }

  _log("symlink: $src -> $dst [$own:$grp $perms]");
  return 1;
}

# directory to create
# owner
# group
# permissions
# force
sub i_mkdir {
  my ($dir, $own, $grp, $perms, $force) = @_;
  
  if ((-e $dir) && !$force) {
    _log("symlink: Directory [$dir] already exists. Skipping!");
    return -1;
  }
  
  my @uInfo = getpwnam($own);
  if (!defined $uInfo[2]) {
    _log("symlink: User [$own] doesn't exist. Aborting!");
    exit(3);
  }
  my $realUID = $uInfo[2];
  
  my @gInfo = getgrnam($grp);
  if (!defined $gInfo[2]) {
    _log("symlink: Group [$grp] doesn't exist. Aborting!");
    exit(4);
  }
  my $realGID = $gInfo[2];
  
  unless (mkpath([$dir], 1, oct($perms))) {
    _log("symlink: Error creating directory $dir. Skipping!\n");
    return -1 unless ($force);
  }

  if (chown($realUID, $realGID, $dir) != 1) {
    _log("symlink: Error chowning $dir to $realUID:$realGID. Skipping!");
    return -1 unless ($force);
  }
  
  _log("mkdir: $dir [$own:$grp $perms]");
  return 1;
}

sub _log {
  my ($msg) = @_;
  if ($LOG_CONS) {
    print STDERR $msg."\n";
  }
  if ($LOG_FILE ne '') {
    open(LOG, ">>$LOG_FILE");
    print LOG $msg."\n";
    close(LOG);
  }
}

sub startup_checks {

  # Check that we can symlink
  my $sym_exists = eval { symlink('', ''); 1; };
  
  if (!$sym_exists) {
    _log("netreg-install assumes systype supports symlinks. Aborting.\n");
    exit(1);
  }

  return 1;
}


sub make_NR_etc {
  my ($dir, $force) = @_;
  i_mkdir("$dir/etc", 'root', $NR_WHEEL, '0755', $force);
  foreach my $sub (qw/dhcp-gen dhcp-xfer misc-reports service-gen
		   service-xfer zone-config zone-gen zone-xfer/) {
    i_mkdir("$dir/etc/$sub", $NR_USER, $NR_GRP, '0775', $force);
  }
}

sub make_NR_htdocs {
  my ($dir, $force) = @_;
  
  # Check for an apache user
  my $USER = '';
  my @uInfo = getpwnam('apache');
  $USER = 'apache' if (defined $uInfo[2]);
  
  if ($USER eq '') {
    @uInfo = getpwnam('nobody');
    $USER = 'nobody' if (defined $uInfo[2]);
  }

  # Lets see what we're gonna user
  if ($USER eq '') {
    print "We need to know what user the web server is running as.\n".
      "Most web servers run as 'nobody', but we couldn't find that \n".
	"user on your system.\n";
  }else{
    print "We need to know what user the web server is running as.\n".
      "Our best guess is that your server runs as : $USER\n";
  }
  my $uname = getUserInput("Web Server User: ", $USER, 1);
  
  i_mkdir("$dir/htdocs", 'root', $NR_WHEEL, '0755', $force);
  i_mkdir("$dir/htdocs/bin", 'root', $NR_WHEEL, '0755', $force);

  i_mkdir("$dir/htdocs/reports", $USER, $NR_WHEEL, '0775', $force);
  i_symlink("$dir/stable/netdb/htdocs/img",
	    "$dir/htdocs/img",
	    'root', $NR_WHEEL, '0755', $force);
  i_symlink("$dir/stable/netdb/htdocs/help", 
	    "$dir/htdocs/help",
	    'root', $NR_WHEEL, '0775', $force);
  i_symlink("$dir/stable/netdb/htdocs/index.pl",
	    "$dir/htdocs/index.pl",
	    'root', $NR_WHEEL, '0775', $force);
  i_symlink("$dir/stable/netdb/bin/nc.pl", 
	    "$dir/htdocs/bin/nc.pl",
	    'root', $NR_WHEEL, '0775', $force);
  i_symlink("$dir/stable/netdb/bin/netreg.pl",
	    "$dir/htdocs/bin/netreg.pl",
	    'root', $NR_WHEEL, '0775', $force);
  i_symlink("$dir/htdocs/bin/nc.pl",
	    "$dir/htdocs/nc.pl",
	    'root', $NR_WHEEL, '0775', $force);

  return $uname;
}

sub make_NR_tree {
  my ($dir, $force) = @_;
  
  i_mkdir("$dir/stable", 'root', $NR_WHEEL, '0755', $force);
  my $ns = `/bin/pwd`;
  chomp($ns);
  my $start = $ns;

  $start = dirname($start."/$0") unless ($0 =~ /^\//);
  $start = $0 if ($0 =~ /^\//);

  if (!(chdir($start.'/..'))) {
    _log("Unable to chdir $start/.. from $start, aborting!\n");
    exit(7);
  }
  my $cur = `/bin/pwd`;
  chomp($cur);
  chdir($ns);
  i_symlink($cur, "$dir/stable/netdb", 'root', $NR_WHEEL, '0755', $force);
}

sub make_NR_lib {
  my ($dir, $force) = @_;
  
  i_mkdir("$dir/lib", 'root', $NR_WHEEL, '0755', $force);
  i_symlink("$dir/stable/netdb/lib/CMU",
	    "$dir/lib/CMU", 'root', $NR_WHEEL, '0755', $force);
  i_symlink("$dir/stable/netdb/lib/DNS",
	    "$dir/lib/DNS", 'root', $NR_WHEEL, '0755', $force);
  i_symlink("$dir/stable/netdb/lib/startup.pl",
	    "$dir/lib/startup.pl", 'root', $NR_WHEEL, '0755', $force);
}
   
sub make_toplevel {
  my ($force) = @_;

  print "We run NetReg out of the /home/netreg directory.";
  print "\nWe are, of course, offering you the chance to change this, though.\n";
  my $dir = getUserInput("Homedir: ", "/home/netreg", 1);
  $NRHOME = $dir;
  i_mkdir($dir, 'root', $NR_WHEEL, '0755', $force);
  i_mkdir("$dir/logs", 'root', $NR_WHEEL, '0755', $force);
  make_NR_etc($dir, $force);
  make_NR_tree($dir, $force);
  make_NR_lib($dir, $force);
  my $webUName = make_NR_htdocs($dir, $force);
  i_symlink("$dir/stable/netdb/support/bin",
	    "$dir/bin", 'root', $NR_WHEEL, '0755', $force);
  return ($dir, $webUName);
}


# Generate a random password from our rand function
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

sub add_users {
  my @gInfo = getgrnam($NR_GRP);
  if (defined $gInfo[2] && $gInfo[2] ne '') {
    print "You appear to already have a '$NR_GRP' group. We are going to use ".
      "\nthis to setup directory permissions. If you want a different group ".
	"\nname, edit the NR_GRP variable in this install script.\n";
    my $co = getUserInput("Continue install (Y/N)?", "Y", 1);
    unless ($co =~ /Y/) {
      _log("Group exists, not continuing. Aborting!\n");
      exit(5);
    }
  }else{
    print "We are going to add a '$NR_GRP' group. We will use this to \n".
      "setup directory permissions. If you want a different group ".
	"\nname, edit the NR_GRP variable in this install script.\n";
    print "\nWe need a valid 'groupadd' command that accepts the group name ".
      "as an argument.\n";
    my $co = getUserInput("Group Add Command", "/usr/sbin/groupadd", 1);
    my $ret = system("$co $NR_GRP");
    $ret = $ret >> 8;
    if ($ret != 0) {
      print "The groupadd command returned a non-zero value, probably \n".
	"indicating failure. Please check for the correct command and \n".
	  "re-run this script (or add the $NR_GRP group yourself).\n";
      _log("Groupadd returned non-zero adding $NR_GRP, Aborting!\n");
      exit(5);
    }else{
      _log("Added group $NR_GRP\n");
    }
  }  
  
  my @uInfo = getpwnam($NR_USER);
  if (defined $uInfo[2] && $uInfo[2] ne '') {
    print "You appear to already have a '$NR_USER' user. We are going to use ".
      "\nthis to setup directory permissions. If you want a different user ".
        "\nname, edit the NR_USER variable in this install script.\n";
    my $co = getUserInput("Continue install (Y/N)?", "Y", 1);
    unless ($co =~ /Y/) {
      _log("User exists, not continuing. Aborting!\n");
      exit(5);
    }
  }else{
    print "We are going to add a '$NR_USER' user. We will use this to \n".
      "setup directory permissions. If you want a different user \n".
        "name, edit the NR_USER variable in this install script.\n";
    print "\nWe need a valid 'useradd' commands that accepts the -c \n".
      "flag for user comment, and -g to specify the primary group. \n";
    my $co = getUserInput("User Add Command", "/usr/sbin/useradd", 1);
    my $ret = system("$co -c \"Network Registration\" -g $NR_GRP $NR_USER");
    $ret = $ret >> 8;
    if ($ret != 0) {
      print "The useradd command returned a non-zero value, probably \n".
	"indicating failure. Please check for the correct command and\n".
	  "re-run this script (or add the $NR_USER user yourself.)\n";
      _log("Useradd returned non-zero adding $NR_USER, Aborting!\n");
      exit(6);
    }else{
      _log("Added user $NR_USER");
    }    
  }
  return 1;
}

sub writeFile {
  my ($fn, $usr, $grp, $perms, $data) = @_;
  
  my @uInfo = getpwnam($usr);
  if (!defined $uInfo[2]) {
    _log("symlink: User [$usr] doesn't exist. Aborting!");
    exit(3);
  }
  my $realUID = $uInfo[2];
  
  my @gInfo = getgrnam($grp);
  if (!defined $gInfo[2]) {
    _log("symlink: Group [$grp] doesn't exist. Aborting!");
    exit(4);
  }
  my $realGID = $gInfo[2];
  
  my $res = open(FILE, ">$fn");
  if (!$res) {
    _log("Unable to open file $fn for writing! Skipping!");
    return -1;
  }
  print FILE $data;
  close(FILE);

  if (chown($realUID, $realGID, $fn) != 1) {
    _log("writeFile: Error chowning $fn to $realUID:$realGID. Skipping!");
    return -1;
  }

  if (chmod($perms, $fn) != 1) {
    _log("writeFile: Error chmoding $fn to $perms! Skipping! ");
    return -1;
  }

  _log("writeFile: Wrote to $fn [user: $usr, group: $grp, perms: $perms]\n");

  return 1;
}

sub add_mysql {
  my ($path, $webUser) = @_;
  print "\n\n============== MySQL Passwords ==============\n";
  print "We're going to add three passwords (keys) to your MySQL installation.\n".
    "You will need to enter your mysql root password twice. These passwords \n".
      "are stored as: $path/etc/.password, .password-maint, and \n".
	".password-reports. \n\n";
  print "These passwords are randomly generated, and you do not need to\n".
    "know them. They will be used for authenticating the web front-end\n".
    "to the mysql database.\n\n";

  print "\nWe are now generating the passwords from random bits.\n";
  my $WebPass = genRandomPassword();
  my $MaintPass = genRandomPassword();
  my $RepPass = genRandomPassword();

  writeFile("$path/etc/.password", $webUser, $NR_WHEEL, '0400', $WebPass);
  writeFile("$path/etc/.password-maint", $NR_USER, 
	    $NR_GRP, '0440', $MaintPass);
  writeFile("$path/etc/.password-reports", $webUser, $NR_GRP, '0440', 
	    $RepPass);

  my $sql =
"GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES ON netdb.* to
'netreg-web'@'localhost' identified by '$WebPass';
GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES ON netdb.* to
'netreg-maint'@'localhost' identified by '$MaintPass';
GRANT SELECT,INSERT,LOCK TABLES ON netdb.* to
'netreg-reports'@'localhost' identified by '$RepPass'; ";

  my $mysql = find_mysql();

  my $com = getUserInput("MySQL binary: ", $mysql, 1);
  
  print "Please enter your MySQL root password as requested: \n";
  open(MYSQL, "|$com -u root -p mysql") || 
    _log("Cannot open MySQL command $com!\n");
  print MYSQL $sql;
  close(MYSQL);
  _log("add_mysql: Adding passwords for 'netreg-web', 'netreg-maint', 'netreg-reports'\n");
  
  print "You should now have three new MySQL users: netreg-web, \n".
    "netreg-maint, and netreg-reports. Please enter your MySQL \n".
      "root password once more, to reload the grant tables.\n";
  open(COM, "|${com}admin -u root -p reload") ||
    _log("Cannot open MySQL admin command ${com}admin\n");
  close(COM);
  _log("add_mysql: Reloading MySQL grant tables..\n");
}

sub find_mysql {
  my @locs = ('/usr/bin/mysql', '/usr/local/bin/mysql');

  foreach (@locs) {
    return $_ if (-e $_);
  }
  return '';
}

sub do_config {
  my @configfiles = @_;

  print
"You should now copy the following config files from doc/config
to /etc and edit the settings to match your system.  If you want to
keep these files elsewhere you can set the path to the config files
via environment variables:\n";
  print "   ".join("\n   ", @configfiles)."\n";
  return 1;
}

# returns: 
#  - result 
#  - FileHeader (text)
#  - rQVars (variables + description + default)
#  - File (file structure that will be passed back to _save_configfile)
sub _load_configfile {
  my ($FileName, $Mode) = @_;

  unless (-r $FileName) {
    print "You do not have appropriate access to read $FileName, \n".
      "or it does not exist. Unable to continue configuration..\n";
    return (-1);
  }
  
  # %File is the overall file structure object that will be passed
  # back to _save_configfile
  my %File;
  
  # QVars are the variables from the configuration file
  my %QVars;

  open(FILE, $FileName);
  my @Contents = <FILE>;
  close(FILE);
  $File{raw} = \@Contents;
  
  my $Location;
  my $LineNumber = 0;
  my ($Accum, $AccumTag, $Var) = ('', '', '');
  # Make a copy of the contents so we can dink with lines without
  # affecting the raw data
  my @EContents = @Contents;
  foreach my $Line (@EContents) {
    $LineNumber++;

    # Blank lines cause an immediate reset of the current location
    if ($Line =~ /^\s*$/) {
      # Check if we're inside an accumulator
      if ($AccumTag eq 'EXPORT') {
	$File{EXPORT} = $Accum;
      }elsif($AccumTag eq 'BASIC_VARS') {
	$File{BASIC_VARS} = $Accum;
      }elsif($AccumTag eq 'VAR') {
	# Remove trailing semicolon and any extra space
	$Accum =~ s/\s*\;\s*$//;
	$Accum =~ s/^\s*//; # Remove leading space
	if ($Accum =~ /^(\'|\")/ && 
	    $Accum =~ /($1)$/) {
	  my $Char = $1;
	  $Accum =~ s/^$Char//s;
	  $Accum =~ s/$Char$//;
	  $QVars{$Var}->{quote} = $Char;
	}
	$QVars{$Var}->{default} = $Accum;
	
      }elsif($AccumTag eq 'HEADER') {
	$File{HEADER} = $Accum;
      }
      $AccumTag = '';
      $Accum = '';
      $Location = '';
      $Var = '';
    }

  lf_lparse:
    if ($Location eq 'EXPORT') {
      $AccumTag = 'EXPORT' if ($AccumTag eq '');
      $Accum .= $Line;
    }elsif($Location eq 'BASIC_VARS') {
      $AccumTag = 'BASIC_VARS' if ($AccumTag eq '');
      $Accum .= $Line;
    }elsif($Location eq 'COMMENT') {
      unless ($Line =~ /^\s*\#/) {
	$Location = 'VAR';
	goto lf_lparse;
      }
      if ($AccumTag eq '') {
	$Line =~ /^\s*\# --(\S+)\s+(.+)/s;
	$Var = $1;
	if (defined $QVars{$Var}) {
	  print STDERR "Variable already defined (don't use the same ".
	    " variable name for arrays/hashes/scalars).\n";
	  return (-1);
	}
	$Accum = $2;
	$AccumTag = 'COMMENT';
      }elsif($AccumTag ne 'COMMENT') {
	print STDERR "Error in parse [line $LineNumber] (COM); expected AccumTag == COMMENT, ".
	"got: $AccumTag\n".
	  " -- While reading: $Line\n";
	return (-1);
      }else{
	$Line =~ /^\#\s*(.+)/s;
	$Accum .= $1;
      }
    }elsif($Location eq 'VAR') {
      if ($AccumTag eq 'COMMENT') {
	if ($Line =~ /^\s*(\$|\@|\%)$Var\s*\=\s*(.+)/) {
	  $QVars{$Var}->{description} = $Accum;
	  $QVars{$Var}->{line_number} = $LineNumber;
	  $QVars{$Var}->{actual_var} = $1.$Var;
	  $File{VarLine}->{$LineNumber} = $Var;
	  $AccumTag = 'VAR';
	  $Accum = $2;
	}else{
	  print STDERR "Error in parse [line $LineNumber] (VAR); expected variable $Var.\n ".
	    " -- While reading: $Line\n";
	}
      }elsif($AccumTag eq 'VAR') {
	$Accum .= $Line;
      }else{
	print STDERR "Error in parse [line $LineNumber] (VAR); expected AccumTag == COMMENT, ".
	  "got: $AccumTag\n".
	    "  -- While reading: $Line\n";
	return (-1);
      }
    }elsif($Location eq 'HEADER') {
      if ($AccumTag eq 'HEADER') {
	if ($Line =~ /--END HEADER--/) {
	  $Location = '';
	  $File{HEADER} = $Accum;
	  $Accum = '';
	  $AccumTag = '';
	}else{
	  $Line =~ s/^\s*\#+//;
	  $Accum .= $Line;
	}
      }elsif($AccumTag eq '') {
	$AccumTag = 'HEADER';
      }else{
	print STDERR "Error in parse [line $LineNumber]; expected AccumTag HEADER or empty.\n";
      }
    }else{
      if ($Line =~ /\@EXPORT\s*=\s*/) {
	$Location = 'EXPORT';
	goto lf_lparse;
      }elsif($Line =~ /\@BASIC_VARS\s*=\s*/) {
	$Location = 'BASIC_VARS';
	goto lf_lparse;
      }elsif($Line =~ /^\s*\#+ --BEGIN HEADER--/) {
	$Location = 'HEADER';
	goto lf_lparse;
      }elsif($Line =~ /^\s*\#+ --(\S+)/) {
	$Location = 'COMMENT';
	goto lf_lparse;
      }
    }
  }
  
  # Okay, the file has been read and parsed. We now need to figure out 
  # the format of basic_vars and export
  $File{EXPORT} =~ s/^\s*(my\s*)?\@EXPORT =/\@EXP_TEST =/;
  $File{BASIC_VARS} =~ s/^\s*(my\s*)?\@BASIC_VARS =/\@BASIC_VAR_TEST =/;
  
  my @EXP_TEST;
  my @BASIC_VAR_TEST;
  eval $File{EXPORT};
  if ($@ ne '') {
    print STDERR "Error parsing EXPORT: $@\n";
    return (-1);
  }
  
  eval $File{BASIC_VARS};
  if ($@ ne '') {
    print STDERR "Error parsing BASIC_VARS: $@\n";
    return (-1);
  }

#  print Dumper (\@EXP_TEST);
  @EXP_TEST = map { s/^(\$|\@|\%)//; $_; } @EXP_TEST;
  @BASIC_VAR_TEST = map { s/^(\$|\@|\%)//; $_; } @BASIC_VAR_TEST;
  foreach my $Var (keys %QVars) {
    delete $QVars{$Var} if ($Mode eq 'basic' && 
			    !(grep /^$Var$/, @BASIC_VAR_TEST));
    delete $QVars{$Var} unless (grep /^$Var$/, @EXP_TEST);
  }
  
  my @Order;
  if ($Mode eq 'basic') {
    @Order = @BASIC_VAR_TEST;
  }else{
    @Order = @EXP_TEST;
  }

#  print Dumper (\%File, \%QVars, \@EXP_TEST);
  $File{qvar} = \%QVars;
  return (1, $File{HEADER}, \%QVars, \@Order, \%File);
}

# _save_configfile
# Arguments:
#  - reference to file structure
#  - reference to variable changes
#  - new file name to write
sub _save_configfile {
  my ($rFile, $rChanges, $NewFileName) = @_;

  my $Res = open(FILE, ">$NewFileName");
  unless ($Res) {
    warn "Unable to open $NewFileName for writing!";
    return -1;
  }
  
  my $LineNumber = 0;
  my $Skip = 0;
  foreach my $Line (@{$rFile->{raw}}) {
    $LineNumber++;
    next if ($Skip-- > 0);

    # If we have a variable being replaced on this line,
    # then drop in the new variable contents here.
    if (defined $rFile->{VarLine}->{$LineNumber}) {
      my $Var = $rFile->{VarLine}->{$LineNumber};
      my @Default = split(/\n/, $rFile->{qvar}->{$Var}->{default});
      my $quote = $rFile->{qvar}->{$Var}->{quote};
      my $actual = $rFile->{qvar}->{$Var}->{actual_var};

      if (defined $rChanges->{$Var}) {
	my $Val = $rChanges->{$Var};
	$Val = '' if ($Val eq 'BLANK' || $Val eq "''" || $Val eq '""');

	print FILE $actual." = ".$quote.$Val."$quote;\n";
	$Skip = $#Default;
	next;
      }
    }
    
    print FILE $Line;
  }
  close(FILE);
  return 1;
}

sub _print_table {
  my ($title, $rInfo, $rOrder) = @_;

 pt_start:
  my $a = (70-length($title)) / 2;
  for (1..$a) {
    print ' ';
  }
  print "=== $title === \n\n";

  my $i = 1;
  my %IDMap;
  foreach my $elem (@$rOrder) {
    print "\t[$i] $elem\n";
    $IDMap{$i} = $elem;
    $i++;
  }
  print "\t[X] Exit (skip this step)\n\n";

  print "Enter selection: \n";
  my $In = <STDIN>;
  chomp($In);
  if ($In =~ /^x$/i) {
    return (0);
  }elsif ($In =~ /^\d+$/ && $In >= 1 && $In < $i) {
    return (1, $rInfo->{$IDMap{$In}});
  }else{
    print " ** Invalid selection ($In) ** \n";
    goto pt_start;
  }
  return (-1),
}

# NOT USED
#sub load_perlmods {
#  my @Modules = @REQ_PERL_MODULES;

#  foreach my $Module (@Modules) {
#    my $ModObj = CPAN::Shell->expand('Module', $Module);
#    if ($ModObj->uptodate) {
#      print "$Module up to date\n";
#    }else{
#      print "Installing $Module\n";
#      $ModObj->install;
#    }
    
#  }
  
#}

sub main {
  my $FORCE = 0;
  my $CONFIG_ONLY = 0;

  foreach(@ARGV) {
    if ($_ eq '-force') {
      $FORCE = 1;
    }elsif($_ eq '-config') {
      $CONFIG_ONLY = 1;
    }
  }
      
  print "\n\n ** CMU Network Registration System Installation **\n".
    "    Copyright 2000-2005 Carnegie Mellon University.  See COPYRIGHT.\n\n";

  goto CONFIG_RUN if ($CONFIG_ONLY);

  if (-e $LOG_FILE) {
    print "$LOG_FILE already exists.\n";
    my $ow = getUserInput("Overwrite logfile? (Yes/eXit)", "X", 1);
    if ($ow =~ /Y/i) {
      open(LOG, ">$LOG_FILE") ||
	die "Cannot open log file $LOG_FILE for output.";
      close(LOG);
    }else{
      print "Exiting installation.\n";
      exit(2);
    }
  }      

  if ($> != 0) {
    print "netreg-install is not being run as root. We recommend you run as ".
      "root to avoid any permissions problems. If you insist, though, we'll ".
	"do our best to run as the current user.\n";
    my $con = getUserInput("Continue? (Y/N)", "N", 1);
    if ($con =~ /Y/i) {
      print "Continuing to run as user $>\n";
    }else{
      exit(3);
    }
  }
  
  &startup_checks($FORCE);

  &add_users();
  my ($dir, $webUName) = &make_toplevel($FORCE);
  &add_mysql($dir, $webUName);
CONFIG_RUN:
  &do_config('netreg-netdb.conf', 'netreg-webint.conf', 'netreg-soap.conf');
}

