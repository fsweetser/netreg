#! /usr/local/bin/perl5
#
# Pulls new zone files out of AFS. Can also be called with argument 'restart' to restart
# the nameserver

my $DIR = '/afs/.andrew/data/db/net/netdb/config';
my $XFER_DIR = '/home/netreg/etc/zone-xfer';
my $CONF_DIR = '/home/bind9/etc';
my $CP_TO = $CONF_DIR.'/named.conf';
my $RESTART = '/home/bind9/sbin/rndc reload';
my $CHECKCONF = '/home/bind9/sbin/named-checkconf';
my $WARN_EMAIL = 'your.email.address@example.org';

if ($ARGV[0] eq 'restart') {
  `$RESTART`;
  exit 1;
}

my $hn = `/bin/hostname`;
chomp($hn);
$hn = lc($hn);

## Find the file that we'll make our new configuration
if (-r "$XFER_DIR/named.conf.$hn") { # Local Disk
  $cp = "$XFER_DIR/named.conf.$hn";
}elsif (-r "$DIR/named.conf.$hn") { # AFS
  $cp = "$DIR/named.conf.$hn";
}elsif (-r "$DIR/named.conf") { # AFS Generic
  $cp = "$DIR/named.conf";
}else{
  die "Cannot copy any named.conf file!";
}

## Copy this file to perform checks on it
my $cres = mysystem("/bin/cp $cp $CONF_DIR/named.conf.candidate");
if ($cres != 0) {
  die "Cannot copy $cp to $CONF_DIR/named.conf.candidate!";
}else{
  $cp = $CONF_DIR."/named.conf.candidate";
}

# Adjust paths in the file
my $pres = mysystem("/bin/sed -e 's-/usr/domain-/home/bind9-' < $cp > $cp.new");
$pres = mysystem("/bin/mv $cp.new $cp");


## Figure out if any of the zones listed do not exist, and copy them as well
my $TriggerRestart = 0;

open(FILE, $cp);
while(my $line = <FILE>) {
  if ($line =~ /file\s+\"([^\"]+)\"/ && !(-e "$DB_DIR/$1") && (-e "$XFER_DIR/$1")) {
    `/bin/cp $XFER_DIR/$1 $DB_DIR/$1`;
    print "Copying $1\n";
    $TriggerRestart = 1;
  }
}
close(FILE);
  
my $rc = mysystem("diff $cp $CP_TO");
if ($rc != 0) {
  # Verify that the file checks out
  if (mysystem("$CHECKCONF $cp") != 0) {
    my $hn = `hostname`;
    chomp($hn);
    mysystem("$CHECKCONF $cp | mail -s '$hn failed update-conf' $WARN_EMAIL"); 
    die "Error checking configuration with $CHECKCONF"
  }
  if (mysystem("/bin/cp $CP_TO $CP_TO.last") != 0) {
    die "Error copying $CP_TO to $CP_TO.last!";
  }
  if (mysystem("/bin/cp $cp $CP_TO") != 0) {
    die "Error copying $cp to $CP_TO (ns update)!";
  }
  $TriggerRestart = 1;
}

if ($TriggerRestart) {
  # sleep some amount of time so that all the servers don't restart 
  # simultaneously
  my $SleepTime = rand(10)*3;
    
  warn "Restarting the server after sleeping $SleepTime seconds...";
  sleep($SleepTime);

  `$RESTART`;
}

sub mysystem {
  my ($com) = @_;
  my $res = system($com);
  return $res >> 8;
}
