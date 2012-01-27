#   -*- perl -*-
#
# CMU::Netdb::helper
# 
# Copyright 2001 Carnegie Mellon University 
#
# All Rights Reserved
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted,
# provided that the above copyright notice appear in all copies and that
# both that copyright notice and this permission notice appear in
# supporting documentation, and that the name of CMU not be
# used in advertising or publicity pertaining to distribution of the
# software without specific, written prior permission.
# 
# CMU DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
# ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
# CMU BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
# ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
# ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
# SOFTWARE.
#
#


package CMU::Netdb::helper;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug);
use DBI;
use POSIX qw(ctime);
use CMU::Netdb::errors;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(lw_db_connect long2dot dot2long cleanse splitHostname 
	     calc_bcast ArpaDate makemap netdb_mail report_db_connect
	     getLock killLock get_sys_key delete_sys_key replace_sys_key
	     remove_dept_tag_hash2 unique pruneLocks mask2CIDR exec_cleanse
	     xaction_begin xaction_commit xaction_rollback netdb_debug
	     CIDR2mask get_db_variable lock_tables);

$debug = 0;

#
# Arguments: 
#   $array_ref - ptr to 2D array of with 3 columns
#
# Returns: 
#   ptr to 2 level hash
#
#  Removed the 'dept:' tags from the 1st column of the input array, then
#  converts the array into a 2 level hash, using the 1st column as the 
#  top level index and the 2nd column as the 2nd level index.
#
#   Note this should have probably be generalized to 2 to sub functions.
#   but I use this function in several calls to general_query.

sub remove_dept_tag_hash2 {
  my ($array_ref) = @_;
  
  my (%hash_val);

  if ( ! ref $array_ref) {
    print "Error ", $array_ref, " is not a reference\n";
    return;
  }
  else {
    my ($row);
    foreach $row (0..$#$array_ref) {
     if ($$array_ref[$row][0] =~ /^dept:(.*)/) { $$array_ref[$row][0] = $1; }
     $hash_val{$$array_ref[$row][0]}{$$array_ref[$row][1]} = $$array_ref[$row][2];
    }
  }

  return \%hash_val;

}


# given an IP address as a long int, returns the 
# dotted-quad equivalent
sub long2dot {
    if($_[0] =~ /^\d+$/){
	return join('.', unpack('C4', pack('N', $_[0])));
    }
    return $_[0];
}

# given an IP address as a dotted-quad, returns the
# long int equivalent
sub dot2long {
  # return unpack('N', pack('C4', split(/\./, $_[0])));
    return @_[0];
}

# given a netmask in the form a.b.c.d (or one integer), calculates
# the CIDR nbits netmask (e.g. /24)
sub mask2CIDR {
  my ($addr) = @_;
 
  $addr = CMU::Netdb::dot2long($addr) if ($addr =~ /\./);
  my $CIDR = 32;
  while($addr % 2 != 1 && $CIDR > 0) {
    $addr = $addr >> 1;
    $CIDR--;
  }
  return $CIDR;
}

sub CIDR2mask {
  my ($cidr) = @_;

  return CMU::Netdb::long2dot( ((2**$cidr)-1) << (32-$cidr));
} 

sub cleanse {
  my ($input) = @_;

  return undef unless (defined $input);
#  $input =~ s/\\*\"/\\\"/g;
  $input =~ tr/\n\'\&//d;
  $input =~ s/^\*EXPR\: //;

  return $input;
}

sub exec_cleanse {
  my ($input) = @_;
  if ($input =~ /([\w\d\.\-\_\/\s\@\+]+)/) {
    return $1;
  }
  return '';
}

sub splitHostname {
  my ($in) = @_;
  return ($in, '') unless ($in =~ /\./);
  return split(/\./, $in, 2);
}

# calculates the broadcast given an IP in the subnet
# and the netmask
# input format is dotted quad, output format is also dotted quad
sub calc_bcast {
  my ($nn, $nm) = @_;

  return CMU::Netdb::long2dot(&CMU::Netdb::dot2long($nn) |
		   ~CMU::Netdb::dot2long($nm));
}

sub netdb_mail {
  my ($file, $msg, $subject, $cc, $to) = @_;

  my ($Name, $Sender, $SenderN);

  my ($nrRes, $aaTo) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'ADMIN_ADDRESS');
  my ($mRes, $mailer) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'MAILER');

  # Deal with taint
  $mailer = exec_cleanse($mailer);

  $to = $aaTo if ($to eq '');
  $to = exec_cleanse($to);
  $cc = exec_cleanse($cc);

  ($nrRes, $Name) = CMU::Netdb::config::get_multi_conf_var('netdb', 'ADMIN_NAME');
  ($nrRes, $Sender) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'SENDER_ADDRESS');
  ($nrRes, $SenderN) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'SENDER_NAME');

  my $now = time();
  my $arpadate = &CMU::Netdb::ArpaDate();
  warn __FILE__, ':', __LINE__, ' :>'.
    "Sending mail ($subject)...\n" if ($debug >= 2);
  if ($cc eq "") {
    open(MAIL, "|$mailer $to") 
      || warn "Cannot open sendmail.\n";
  } else {
    open(MAIL, "|$mailer $to $cc") 
      || warn "Cannot open sendmail.\n";
  }
  print MAIL "X-Mailer: Netreg NetDB\n";
  print MAIL "From: $SenderN <$Sender>\n";
  print MAIL "To: $Name <$to>\n";
  print MAIL "CC: $cc\n" if ($cc ne "");
  print MAIL "Date: $arpadate\n";
  if ($subject eq "") {
    print MAIL "Subject: NetDB Error Report\n\n";
  } else {
    print MAIL "Subject: $subject\n\n";
  }


  print MAIL "================== NetDB error report =====================\n";
  print MAIL "Date: ".localtime($now)." [$now]\n";
  print MAIL "File: $file\n";
  print MAIL "Host: ".`hostname`." (PID: $$)\n";
  print MAIL "\nMessage:\n";
  print MAIL $msg;
  print MAIL "\n=========================================================\n";
  close(MAIL);
}

sub ArpaDate {
  my($date, @l, @g, $zone, $zoneflg);

  # Fetch date, time
  #
  $date = ctime(time);
  @l = localtime(time);
  @g = gmtime(time);

  # Time zone
  #
  $zone = $l[2] - $g[2];
  $zoneflg = '+';
  $zone += 24 if ($zone < -12);
  $zone -= 24 if ($zone > 12);
  if ($zone < 0) {
    $zoneflg = '-';
    $zone = -$zone;
  }

  # Create date string
  #
  $date = substr($date,0,3).",". #  Day
    substr($date,7,3).          # Date
      substr($date,3,4).        # Month
        substr($date,19,5).     # Year
          substr($date,10,9).   # Time
            " $zoneflg".        # Zone direction
              sprintf("%02d",$zone). # Zone offset
                "00";

  return $date;
}

# arguments: 
#  - a reference to the array
# returns:
#  - a reference to the data structure
sub makemap {
  my ($rArr) = @_;
  my $i = 0;
  my %rRef;
  map { $rRef{$_} = $i++ } @$rArr;
  return \%rRef;
}  

sub lw_db_connect {
  return _db_connect("DB-MAINT");
}

sub report_db_connect {
  return _db_connect("DB-REPORT");
}

sub _db_connect {
  my ($type) = @_;
  my ($dbh, $pass, $sth, @superusers, $q, @row);

  my ($vres, $DB) = CMU::Netdb::config::get_multi_conf_var('netdb', $type);
  die "Error connecting to netreg database: $type connect info not found".
    "($vres)" if ($vres != 1);

  if (defined $DB->{'password_file'}) {
    open(FILE, $DB->{'password_file'})
        || die "Cannot open password file (".$DB->{'password_file'}.")!";
    $pass = <FILE>;
    close(FILE);
    chomp $pass;
  }else{
    $pass = $DB->{'password'};
  }

  warn __FILE__, ':', __LINE__, ' :>'.
      "connection: ".$DB->{'connect_string'}." / ".$DB->{'username'}."\n"
      if ($debug >= 1);
  
  $dbh = DBI->connect($DB->{'connect_string'},
                      $DB->{'username'},
                      $pass);
  if (!$dbh) {
    die "Unable to get database connection:  $DBI::errstr\n";
  }
  return $dbh;
}

sub pruneLocks {
  my ($dbh) = @_;

  return unless (-r "/proc/uptime");
  open(UP, "/proc/uptime");
  my ($time) = split(/\s+/, <UP>);
  # 1 Hour
  return unless ($time < 3600);
  my $now = time();
  my $RebootTime = $now - $time;
  
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  my @locks = ("_sys_info");
  my ($lockres, $lockref) = CMU::Netdb::lock_tables($dbh, \@locks);
  unless($lockres == 1){
    CMU::Netdb::xaction_rollback($dbh);
    return ($errcodes{"EDB"}, $lockref);
  }
  my $query = "SELECT sys_key, sys_value FROM _sys_info ".
    " WHERE sys_key like '%_LOCK' ";
  my $Keys = $dbh->selectall_arrayref($query);
  foreach my $Entry (@$Keys) {
    my ($key, $val) = @$Entry;
    if ($val < $RebootTime) {
      CMU::Netdb::killLock($dbh, $key);
    }
  }

  CMU::Netdb::xaction_commit($dbh, $xref);
}
  

## obtain a lock to perform our operations
# arguments: database handle, SCHEDULED_LOCK, scheduled.pl, 20
sub getLock {
  my ($dbh, $name, $file, $timeout) = @_;
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  my @locks = ("_sys_info");
  my ($lockres, $lockref) = CMU::Netdb::lock_tables($dbh, \@locks);
  unless($lockres == 1){
    CMU::Netdb::xaction_rollback($dbh);
    return ($errcodes{"EDB"}, $lockref);
  }

  
  my ($res, $val) = CMU::Netdb::get_sys_key($dbh, $name);
  if ($res > 0) {
    CMU::Netdb::xaction_commit($dbh, $xref);
    if ($timeout ne '') {
      my $diff = time()-$val;
      if ($diff > (60*$timeout)) {
	CMU::Netdb::netdb_mail($file, "$name held for >$timeout minutes");
      }
    }
    die "Error getting lock $name";
  }
  
  CMU::Netdb::replace_sys_key($dbh, $name, time());
  CMU::Netdb::xaction_commit($dbh, $xref);
}
  
sub killLock {
  my ($dbh, $name) = @_;
  CMU::Netdb::delete_sys_key($dbh, $name);
}

sub get_sys_key {
  my ($dbh, $key) = @_;
  my $query;
  
  return ($CMU::Netdb::errors::errcodes{ERROR}, ['sys_key']) if ($key eq '');
  $query = "SELECT sys_value FROM _sys_info WHERE sys_key = '$key'";
  my $sth = $dbh->prepare($query);
  $sth->execute;
  
  my @row = $sth->fetchrow_array;
  $sth->finish;
  if (@row && defined $row[0]) {
    return (1, $row[0]);
  }else{
    return ($CMU::Netdb::errors::errcodes{ERROR}, ['notfound']);
  }
}

sub replace_sys_key {
  my ($dbh, $key, $value) = @_;
  my $query;
  return ($CMU::Netdb::errors::errcodes{ERROR}, ['sys_key']) if ($key eq '');
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }

  $query = "REPLACE INTO _sys_info (sys_key, sys_value) VALUES ('$key', '$value')";
  
  my $sth = $dbh->prepare($query);
  $sth->execute;
  $sth->finish;
  CMU::Netdb::xaction_commit($dbh, $xref);
  return 0; # FIXME more error checking?
}

sub delete_sys_key {
  my ($dbh, $key) = @_;
  my $query;
  return ($CMU::Netdb::errors::errcodes{ERROR}, ['sys_key']) if ($key eq '');
  $query = "DELETE FROM _sys_info WHERE sys_key = '$key'";
  my ($xres, $xref) = CMU::Netdb::xaction_begin($dbh);
  if ($xres == 1){
    $xref = shift @{$xref};
  }else{
    return ($xres, $xref);
  }
  $dbh->do($query); # FIXME error checking?
  CMU::Netdb::xaction_commit($dbh, $xref);
  return 0;
}

sub get_db_variable {
  my ($dbh, $user, $var) = @_;
  my $query;
  
  print STDERR "db_variable is '$var'\n";
  return ($CMU::Netdb::errors::errcodes{EBLANK}, ['db_variable']) if ($var eq '');
  return ($CMU::Netdb::errors::errcodes{ERROR}, ['db_variable']) if ($var ne 'hostname');
  $query = "SHOW variables LIKE '$var'";
  my $sth = $dbh->prepare($query);
  $sth->execute;
  
  my @row = $sth->fetchrow_array;
  $sth->finish;
  if (@row && defined $row[1]) {
    return (1, $row[1]);
  }else{
    return ($CMU::Netdb::errors::errcodes{ERROR}, ['notfound']);
  }
}

sub unique {
  my %saw;
  return grep(!$saw{$_}++, @_);
}

# Conditionally begin a transaction.  Since Postgres doesn't support
# nested transactions, in order to minimalize the amount of
# modifications required we check if we're already in a transaction,
# and only start one if we're not already in one.  We then return a 1
# or 0 as the second return value, indicating whether or not this
# transaction is the "top level" one.  This gets passed to the commit
# function to ensure we don't accidentally commit a transaction
# halfway through.
#
# See DBD::Pg docs for explanation of ping values.

sub xaction_begin {
  my ($dbh) = @_;

  my $ping = $dbh->ping;
  warn __FILE__, ':', __LINE__, ' :>'.
    " XACTION_BEGIN Ping State $ping\n" if ($debug >= 1);
  warn join('|', caller) if ($debug >= 1);


  if($ping == 1 or $ping == 2){
      warn "Calling begin_work";
      if($dbh->begin_work()){
	  return (1, [$ping]);
      } else {
	  return ($errcodes{"EDB"}, ['begin_work']);
      }
  }else{
      return (1, [$ping]);
  }
}

# The second parameter (ping) should be the ping value returned by the
# xaction_begin function called in the same context (ie, the same
# function).  This is used to determine whether we should actually
# commit, or if there may still be more work to be done, in which case
# we no-nop.
#
# If the commit fails, rollback WILL BE CALLED AUTOMATICALLY
# Returns two-element array:
#   1 on success (commit succeeded)
#   2 on failure of the commit but success of the rollback
# <=0 indicates failure of commit + failure of the rollback
sub xaction_commit {
  my ($dbh, $ping) = @_;
  warn __FILE__, ':', __LINE__, ' :>'.
    " XACTION_COMMIT Ping State $ping\n" if ($debug >= 1);
  warn join('|', caller) if ($debug >= 1);

  if($ping == 1 or $ping == 2){
      warn "Calling commit";
      unless ($dbh->commit()) {
	  my $str = $dbh->errstr;
	  my ($r, $d) = CMU::Netdb::xaction_rollback($dbh);
	  push(@$d, "commit: $str");

	  if ($r <= 0) {
	      return ($r, $d);
	  }else{
	      return (2, $d);
	  }
      }
  } else {
      return (1, []);
  }
}

# The actual rollback will be called only if we're really in a
# transaction.  Calls from outside a transaction (ie, a lower context
# function has already called rollback on us) will just quietly no-op.
#
# returns two element array, <= 0 is failure, 1 is success
sub xaction_rollback {
  my ($dbh) = @_;

  my $ping = $dbh->ping;
  warn __FILE__, ':', __LINE__, ' :>'.
    " XACTION_ROLLBACK Ping State $ping\n" if ($debug >= 1);
  warn join('|', caller) if ($debug >= 1);

  if($ping == 3 or $ping == 4){
      warn "Calling rollback";
      my $Ret = $dbh->rollback;

      unless (defined($Ret) && $Ret) {
	  my $str = $DBI::errstr || '';
	  return ($errcodes{"EDB"}, ["rollback: $str"]);
      }
      return (1, []);
  }
  return (1, []);
}

# netdb_debug
#
# Arguments:
#  an integer to set all debug levels to or a ref to a hash of 
#  module names and debug levels as in:
#   { auth => 2, reports => 4 };
#
# Returns:
#   void;
#
# Sets the debug levels in the various modules to sane values.
#
#
sub netdb_debug{
  my ($opt) = @_;
  my ($isa) = ref($opt);
  my ($debug_var);
  
  my ($modules) = {
		   auth => \$CMU::Netdb::auth::debug,
		   buildings_cables => \$CMU::Netdb::buildings_cables::debug,
		   config => \$CMU::Netdb::config::debug,
		   consistency => \$CMU::Netdb::consistency::debug,
		   dns_dhcp => \$CMU::Netdb::dns_dhcp::debug,
		   errors => \$CMU::Netdb::errors::debug,
		   helper => \$CMU::Netdb::helper::debug,
		   machines_subnets => \$CMU::Netdb::machines_subnets::debug,
		   primitives => \$CMU::Netdb::primitives::debug,
		   reports => \$CMU::Netdb::reports::debug,
		   services => \$CMU::Netdb::services::debug,
		   structure => \$CMU::Netdb::structure::debug,
		   validity => \$CMU::Netdb::validity::debug,
		   vars => \$CMU::Netdb::vars::debug
		  };
		  
  if (length($isa) == 0){
    if ($opt !~ /^[0-9]+$/){
      warn __FILE__, ':', __LINE__, ' :> '.
	"netdb_debug: invalid call value: $opt\n";
      return;
    }
    foreach $debug_var (keys %$modules){
      warn __FILE__, ':', __LINE__, ' :>'.
	"setting $debug_var to $opt\n" if (($debug >= 2) && ($debug_var ne 'helper') && ($opt != 0));
      ${$modules->{$debug_var}} = $opt if (defined ${$modules->{$debug_var}});
    }
  } elsif ($isa eq "HASH"){
    foreach $debug_var (keys %$opt){
      if (! defined $modules->{$debug_var}){
	warn __FILE__, ':', __LINE__, ' :> '.
	  "netdb_debug: invalid call value: $debug_var\n";
	return;
      }
      if ($opt->{$debug_var} !~ /^[0-9]+$/){
	warn __FILE__, ':', __LINE__, ' :> '.
	  "netdb_debug: invalid call value: $debug_var -> $opt->{$debug_var} \n";
	return;
      }
      warn __FILE__, ':', __LINE__, ' :> '.
	"setting $debug_var to $opt->{$debug_var}\n" if ($debug >= 2);
      ${$modules->{$debug_var}} = $opt->{$debug_var} if (defined ${$modules->{$debug_var}});
    }
  } else {
    warn __FILE__, ':', __LINE__, ' :> '.
      "netdb_debug: usage: argument not integer or hashref\n";
    return;
  }
}    

# Acquires an ACCESS EXCLUSIVE lock on all requested tables.

sub lock_tables {
    my ($dbh, $tables) = @_;

    # sort to ensure we always lock tables in the same order, preventing deadlocks
    foreach my $table ( sort @{$tables} ){
       warn "LOCK TABLE " . $table . " IN ACCESS EXCLUSIVE MODE" if $debug;
       unless($dbh->do("LOCK TABLE " . $table . " IN ACCESS EXCLUSIVE MODE")){
           warn "Error locking $table: " . $dbh->errstr;
           return ($errcodes{"EDB"}, ['lock_tables:' . $dbh->errstr]);
       }
    }
    return (1, []);
}


1;

