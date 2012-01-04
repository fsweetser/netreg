#!/usr/bin/perl
#
# This program sends mail to users.
#
# It uses the user/group fields to determine who to send messages to.
# A command line argument determines where to send the mail, to users,
#  admins, and/or an arbirary fixed mail address.
# It can take a query against the machine subnet join, a user list,
#  a group list or a list of machines as the list of what information to mail.
# It takes a generic mail message file name as an argument.
#  This file may have meta strings that will be filled in as a mail merge
#  These fields include 
#  %DATE% - Current ARPA format date (normally used in Date: header)
#  %USER% - The user(s) receiving this mail (may be group members, comma sep)
#  %AFFILIATION% - The dept: group for this machine
#  %NAME% - the name of the machine
#  %IP_ADDRESS% - the IP Address of the machine
#  %MAC% - The MAC address of the machine
#  %INFO% - List of information about machines listed 
#      "%NAME%, %IP_ADDRESS%, %MAC%, %USERS%, %AFFILIATION%, %MODIFIED%\n\t%URL%"
#  where 
#   %USERS% is the users associated with this machine, semicolon seperated
#   %URL% - A full URL to the machine edit screen
#   %MODIFIED% - last update of machine record
#  %SHORTINFO% - List of information about machines listed
#      "%NAME% - %IP_ADDRESS - %USERS%%"
# if multiple information is going in a single message, all macros produce
# comma seperated lists except %INFO% which produces newline seperated
# records.
# 

use strict;
use Fcntl ':flock';
use lib '/home/netreg/lib';
use CMU::Netdb;
use Getopt::Std;

my ($output, $send_user, $send_admin, $bcc_address, $bcc_only, $from_address, $message_file, $host_file, $s_type, $by_user, $where, $vals, $slow);
my ($mlist, $dbh, $i);
my ($letter, $debug);

$debug = 0;

CMU::Netdb::netdb_debug({helper => 0});;
CMU::Netdb::netdb_debug(0);
#CMU::Netdb::netdb_debug({machines_subnets => 5});

$dbh = CMU::Netdb::helper::report_db_connect();

($output, $send_user, $send_admin, $bcc_address, $bcc_only, $from_address, $message_file, $host_file, $s_type, $by_user, $where, $vals) = parse_args(@ARGV);

warn __FILE__ . ":" . __LINE__ . ": send_user = $send_user, send_admin =  $send_admin, bcc_address =  $bcc_address, bcc_only =  $bcc_only, from_address = $from_address, message_file =  $message_file, host_file =  $host_file, s_type = $s_type, by_user = >$by_user<, where = $where\n" if ($debug);
if ($debug) {
  foreach $i (sort keys %$vals){
    warn "\t$i = $vals->{$i}\n";
  }
}


$letter = read_msg($dbh, $message_file);

if (defined $where) {
  $mlist = get_by_where($dbh, $s_type, $by_user, $where);
} elsif (defined $host_file) {
  $mlist = get_by_file($dbh, $s_type, $by_user, $host_file);
} else {
  usage($dbh, 1);
}

die "error $mlist ( $CMU::Netdb::errmeanings{$mlist} ) while attempting to get host list\n" if not ref $mlist;


warn __FILE__ . ":" . __LINE__ . ": calling build_and_send( " . Data::Dumper->Dump([$dbh, $send_user, $send_admin, $bcc_address, $bcc_only, $from_address, $letter, $vals, $mlist, $output],[qw(dbh send_user send_admin bcc_address bcc_only from_address letter vals mlist output)]) . ");\n" if ($debug >= 2);
build_and_send($dbh, $send_user, $send_admin, $bcc_address, $bcc_only, $from_address, $letter, $vals, $mlist, $output);

$dbh->disconnect();

exit(0);


sub build_and_send {
  my ($dbh, $send_user, $send_admin, $bcc_address, $bcc_only, $from_address, $letter, $vals, $mlist, $output) = @_;
  my ($id, $usr, $grp, $mname, $ip, $mac, $create, $modify, $afid, $subnet);
  my ($rec, $dotted);
  my ($owner, $user, $group);
  my (%users, %groups);
  my ($info, $sinfo, $mdate);
  my (@u_mname, @u_ip, @u_mac, @u_affil, @u_info);
  my (%attr, $mems);
  my ($i, $j, $mem, $grpn, $gp_desc, $flags);

  warn __FILE__ . ":" . __LINE__ . ": entering build_and_send \n" if ($debug >= 1);
  $i = 0;
  # find fields in mlist
    foreach (@{$mlist->[0]}){
#      print "$_ \n";
      $id = $i if ($_ eq 'machine.id');
      $usr = $i if ($_ eq 'machine.users');
      $grp = $i if ($_ eq 'machine.affil');
      $mname = $i if ($_ eq 'machine.host_name');
      $ip = $i if ($_ eq 'machine.ip_address');
      $mac = $i if ($_ eq 'machine.mac_address');
      $create = $i if ($_ eq 'machine.created');
      $modify = $i if ($_ eq 'machine.version');
      $afid = $i if ($_ eq 'machine.affil_id');
      $subnet = $i if ($_ eq 'subnet.name');
      $flags = $i if ($_ eq 'groups.flags');
      $i++
    }

  # build user and group machine hashes

#  warn __FILE__ . ":" . __LINE__ . ":  mlist count = $#$mlist \n";
  foreach $rec ( 1 .. $#$mlist ) {
    $group = @{$mlist->[$rec]}[$grp];

    @{$mlist->[$rec]}[$modify] =~ /(....)(..)(..)(..)(..)(..)/;
    $mdate = "$1-$2-$3 $4:$5:$6";

    $dotted = CMU::Netdb::long2dot(@{$mlist->[$rec]}[$ip]);

    $mems = CMU::Netdb::list_groups($dbh, 'netreg', "groups.name like \"$group\"");
    $i = 0;
    foreach (@{$mems->[0]}){
#  map column headers from reply
      $mem = $i if $_ eq 'groups.description';
      $i++
    }

    $gp_desc = @{$mems->[1]}[$mem];


    $info = "@{$mlist->[$rec]}[$mname], $dotted, @{$mlist->[$rec]}[$mac], \n\t@{$mlist->[$rec]}[$usr], $gp_desc, $mdate\n\thttps://netreg.net.cmu.edu/bin/netreg.pl?op=mach_view&id=@{$mlist->[$rec]}[$id]\n";
#    warn __FILE__ . ":" . __LINE__ . ": $info";
    $sinfo = "@{$mlist->[$rec]}[$mname] - $dotted - @{$mlist->[$rec]}[$usr]";

    if ($mlist->[$rec][$flags] =~ /purge_mailusers/){
      foreach $owner (split /;/, @{$mlist->[$rec]}[$usr]){
	$users{$owner}{SHORTINFO} = "Machine Name - IP Address - Users\n"
	  if not defined $users{$owner}{SHORTINFO};
	
	$users{$owner}{INFO} = "Machine Name, IP_Address, Hardware Address,\n\tUsers, Affiliation, Last Modified Date,\n\tAccess URL\n\n"
	  if not defined $users{$owner}{INFO};

	$users{$owner}{NAME} = join ( ', ', $users{$owner}{NAME}, @{$mlist->[$rec]}[$mname])
	  if (defined $users{$owner}{NAME})  and ($users{$owner}{NAME} !~ @{$mlist->[$rec]}[$mname]) ;
	$users{$owner}{NAME} = @{$mlist->[$rec]}[$mname]
	  if not defined $users{$owner}{NAME};

	$users{$owner}{SUBNET} = join ( ', ', $users{$owner}{SUBNET}, '"'. @{$mlist->[$rec]}[$subnet]) . '"'
	  if defined $users{$owner}{SUBNET} and ($users{$owner}{SUBNET} !~ @{$mlist->[$rec]}[$subnet]);
	$users{$owner}{SUBNET} = '"' . @{$mlist->[$rec]}[$subnet] . '"'
	  if not defined $users{$owner}{SUBNET};

	$users{$owner}{IP_ADDRESS} = join (', ', $users{$owner}{IP_ADDRESS}, $dotted)
	  if (defined $users{$owner}{IP_ADDRESS} ) and ($users{$owner}{IP_ADDRESS} !~ $dotted );
	$users{$owner}{IP_ADDRESS} = $dotted
	  if not defined $users{$owner}{IP_ADDRESS};

	$users{$owner}{MAC} = join (', ', $users{$owner}{MAC}, @{$mlist->[$rec]}[$mac])
	  if (defined $users{$owner}{MAC}) and ($users{$owner}{MAC} !~ @{$mlist->[$rec]}[$mac] );
	$users{$owner}{MAC} = @{$mlist->[$rec]}[$mac]
	  if not defined $users{$owner}{MAC};

	if ($users{$owner}{AFFILIATION} !~ @{$mlist->[$rec]}[$grp]){
	  $users{$owner}{AFFILIATION} = join (', ', $users{$owner}{AFFILIATION}, @{$mlist->[$rec]}[$grp])
	    if (defined $users{$owner}{AFFILIATION}) and ( $users{$owner}{AFFILIATION} !~ @{$mlist->[$rec]}[$grp] );
	  $users{$owner}{AFFILIATION} = @{$mlist->[$rec]}[$grp]
	    if not defined $users{$owner}{AFFILIATION};
	}

	$users{$owner}{INFO} = join ("\n", $users{$owner}{INFO}, $info);
	$users{$owner}{SHORTINFO} = join("\n", $users{$owner}{SHORTINFO}, $sinfo);


	$users{$owner}{USER} = $owner;
	if ((defined $send_user) && (defined $send_admin )) {
	  $mems = CMU::Netdb::list_members_of_group($dbh, 'netreg', 
						    @{$mlist->[$rec]}[$afid]);


	  $i = 0;
	  foreach (@{$mems->[0]}){
	    #  map column headers from reply
	    #  $id = $i if ($_ eq 'machine.id');
	    $mem = $i if $_ eq 'credentials.authid';
	    $i++

	  }

	  for $i ( 1 .. $#$mems ) {
	    # Loop through the values returned.
	    # items referenced as follows...
	    #  @{$db_result->[$i]}[$id],
	    next if (@{$mems->[$i]}[$mem] eq "netreg");
	    warn __FILE__ . ":" . __LINE__ . ": <<=O=>> assigning @{$mems->[$i]}[$mem] to group\n" if ($debug >= 4);
	    $users{$owner}{USER} = join (',', $users{$owner}{USER}, @{$mems->[$i]}[$mem])
	      if (defined $users{$owner}{USER}) and ($users{$owner}{USER} !~ @{$mems->[$i]}[$mem] );
	    $users{$owner}{USER} = @{$mems->[$i]}[$mem]
	      if not defined $users{$owner}{USER};

	    #  warn __FILE__ . ":" . __LINE__ . ": " . join( '|', @{$db_result->[$i]}, "\n");


	  }

	}

      }
    }

    $groups{$group}{INFO} = "Machine Name, IP_Address, Hardware Address,\n\tUsers, Affiliation, Last Modified Date,\n\tAccess URL\n\n"
      if not defined $groups{$group}{INFO};

    $groups{$group}{SHORTINFO} = "Machine Name - IP_Address - Users\n"
      if not defined $groups{$group}{SHORTINFO};

    $groups{$group}{WARNING} = "" if !defined $groups{$group}{WARNING};
    $groups{$group}{WARNING} = "By your request, the individual users in this group HAVE NOT received notification of this pending change.\n\n "     if ($mlist->[$rec][$flags] !~ /purge_mailusers/);
    if (not defined $groups{$group}{GROUP}) {
#      warn __FILE__ . ":" . __LINE__ . ": looking up group $group\n";
      $mems = CMU::Netdb::list_members_of_group($dbh, 'netreg', 
						@{$mlist->[$rec]}[$afid]);


      $i = 0;
      foreach (@{$mems->[0]}){
#  map column headers from reply
#  $id = $i if ($_ eq 'machine.id');
	$mem = $i if $_ eq 'credentials.authid';
	$i++

      }

      for $i ( 1 .. $#$mems ) {
# Loop through the values returned.
# items referenced as follows...
#  @{$db_result->[$i]}[$id],
	next if (@{$mems->[$i]}[$mem] eq "netreg");
	warn __FILE__ . ":" . __LINE__ . ": <<=O=>> assigning @{$mems->[$i]}[$mem] to group\n" if ($debug >= 4);
	$groups{$group}{USER} = join (',', $groups{$group}{USER}, @{$mems->[$i]}[$mem])
	  if (defined $groups{$group}{USER}) and ($groups{$group}{USER} !~ @{$mems->[$i]}[$mem] );
	$groups{$group}{USER} = @{$mems->[$i]}[$mem]
	  if not defined $groups{$group}{USER};

#  warn __FILE__ . ":" . __LINE__ . ": " . join( '|', @{$db_result->[$i]}, "\n");


      }

      $groups{$group}{GROUP} = $gp_desc;
    };

    $groups{$group}{NAME} = join ( ', ', $groups{$group}{NAME}, @{$mlist->[$rec]}[$mname])
      if (defined $groups{$group}{NAME}) and ( $groups{$group}{NAME} !~ @{$mlist->[$rec]}[$mname] );
    $groups{$group}{NAME} = @{$mlist->[$rec]}[$mname]
      if not defined $groups{$group}{NAME};

    $groups{$group}{IP_ADDRESS} = join (', ', $groups{$group}{IP_ADDRESS}, $dotted)
      if (defined $groups{$group}{IP_ADDRESS}) and ($groups{$group}{IP_ADDRESS} !~ $dotted );
    $groups{$group}{IP_ADDRESS} = $dotted
      if not defined $groups{$group}{IP_ADDRESS};

    $groups{$group}{MAC} = join (', ', $groups{$group}{MAC}, @{$mlist->[$rec]}[$mac])
      if (defined $groups{$group}{MAC}) and ($groups{$group}{MAC} !~ @{$mlist->[$rec]}[$mac] );
    $groups{$group}{MAC} = @{$mlist->[$rec]}[$mac]
      if not defined $groups{$group}{MAC};

    $groups{$group}{AFFILIATION} = join (', ', $groups{$group}{AFFILIATION}, $group)
      if (defined $groups{$group}{AFFILIATION}) and ($groups{$group}{AFFILIATION} !~ $group  ) ;
    $groups{$group}{AFFILIATION} = $group
      if not defined $groups{$group}{AFFILIATION};

    $groups{$group}{INFO} = join ("\n", $groups{$group}{INFO}, $info);

    $groups{$group}{SHORTINFO} = join ("\n", $groups{$group}{SHORTINFO}, $sinfo);



  }

#  foreach $i ( keys %users ){
#    warn __FILE__ . ":" . __LINE__ . ": $i => { \n";
#    foreach $j (keys %{ $users{$i} } ){
#      warn "  $j => $users{$i}{$j}\n";
#    }
#    warn "}\n\n";
#  }
#  foreach $i ( keys %groups ){
#    warn __FILE__ . ":" . __LINE__ . ":  $i => { \n";
#    foreach $j (keys %{ $groups{$i} } ){
#      warn "   $j => $groups{$i}{$j}\n";
#    }
#    warn "}\n\n";
#  }


  mail_to($from_address, $bcc_address, $bcc_only, $letter, $vals, \%users, $output) if (defined $send_user);
  mail_to($from_address, $bcc_address, $bcc_only, $letter, $vals, \%groups, $output) if ((defined $send_admin) && (! defined $send_user));

}

sub mail_to {
  my ($from_address, $bcc_address, $bcc_only, $letter, $vals, $list_ref, $output) = @_;
  my (%list) = %$list_ref;
  my (%subs) = {};
  my ($usr, %user, $send, $member);
  my ($key, $val);
  my ($working, $cmd, $retry);
  my ($umacros);

  warn __FILE__ . ":" . __LINE__ . ": entering mail_to\n" if ($debug >= 1);
  $from_address = 'netreg@ANDREW.CMU.EDU' if not defined $from_address;
  $working = "";
# for each row in user and/or group hashes,
# assign the proper values into vals
  foreach $send (keys(%list)){
    sleep 1 if ($slow);
    %subs = {};
    %subs = %$vals;
    $working = $letter;

#    warn __FILE__ . ":" . __LINE__ . ": for $send\n";
    foreach $key ( keys %{ $list{$send} } ){
      $subs{$key} = $list{$send}{$key};
    }


# for each key in vals, do the substitution

    foreach $key (sort keys %subs){
#      warn __FILE__ . ":" . __LINE__ . ": $key => $subs{$key}\n";
      $working =~ s/%$key%/$subs{$key}/g;
    }
#    warn __FILE__ . ":" . __LINE__ . ": \n\n";

    if ($working =~ /(%\w+%)/){
      $umacros = $1;
      warn __FILE__ . ":" . __LINE__ . ": Undefined Macro \"$umacros\", aborting on following\n";
      warn __FILE__ . ":" . __LINE__ . ": $working \n\n";
      next;
    }

#    warn __FILE__ . ":" . __LINE__ . ":  $working\n";

# send the mail to correct users
  MAILER:
    $retry = 0;
    {
      $cmd = "| /usr/sbin/sendmail -f $from_address -- " . join ( " ", split(",", $subs{USER}), split(",", $bcc_address))
	if not defined $bcc_only;
      $cmd = "| /usr/sbin/sendmail -f $from_address -- " . join ( " ", split(",", $bcc_address))
	if defined $bcc_only;

      $cmd = ">> $output" if defined $output;

      print STDERR ": cmd = $cmd \n"
	if (($debug <= 3) or ($debug >= 5));
      print STDERR  "would send to " . join ( " ", split(",", $subs{USER}), split(",", $bcc_address)) . "\n"
	if ((($debug <= 3) or ($debug >= 5)) and (defined $output));
      open (MAIL, "$cmd") || die "Could not open mailer : $!\n";
      print MAIL "----------NEW LETTER--CUT HERE-------- \n\n" if defined $output;
      print MAIL $working;
      close MAIL;
      if ($?) {
	print STDERR "ERROR SENDING MAIL, $!\n";
	$retry += 1;
	sleep 1;
	redo MAILER if ($retry <= 10);
	warn __FILE__ . ":" . __LINE__ . ": RETRIES EXCEEDED, CANNOT SEND FOLLOWING...\n";
	warn __FILE__ . ":" . __LINE__ . ": \n$working\n";
      }
    }
  }


}


sub read_msg {
  my ($dbh, $f_name) = @_;
  my (@msg_txt, $msg);


  if (not (open(MSG, $f_name))) {
    warn __FILE__ . ":" . __LINE__ . ": Cannot open $f_name\n";
    usage($dbh, 4);
  }
  @msg_txt = <MSG>;
  close(MSG);
  $msg = join("", @msg_txt);
  return($msg);
}


sub parse_args {

  my (%opts) ;
  my ($output, $from_address, $send_user, $send_admin, $bcc_address, $bcc_only, $message_file, $host_file, $s_type, $by_user, $where, %vals);
  my ($pairs, $da_key, $da_val);

  getopts('huaBsb:m:f:F:w:U:MSD:o:d:',\%opts);

  $debug = $opts{'d'} if defined $opts{'d'};
  usage($dbh, 0) if (defined $opts{'h'});

  if ($debug) {
    warn "-u is $opts{'u'}\n" if defined $opts{'u'};
    warn "-a is $opts{'a'}\n" if defined $opts{'a'};
    warn "-b is $opts{'b'}\n" if defined $opts{'b'};
    warn "-B is $opts{'B'}\n" if defined $opts{'B'};
    warn "-m is $opts{'m'}\n" if defined $opts{'m'};
    warn "-f is $opts{'f'}\n" if defined $opts{'f'};
    warn "-F is $opts{'F'}\n" if defined $opts{'F'};
    warn "-w is $opts{'w'}\n" if defined $opts{'w'};
    warn "-U is $opts{'U'}\n" if defined $opts{'U'};
    warn "-M is $opts{'M'}\n" if defined $opts{'M'};
    warn "-s is $opts{'s'}\n" if defined $opts{'s'};
    warn "-S is $opts{'S'}\n" if defined $opts{'S'};
    warn "-D is $opts{'D'}\n" if defined $opts{'D'};
    warn "-o is $opts{'o'}\n" if defined $opts{'o'};
    warn "other args: @ARGV\n";
  }

  usage($dbh, 2) if ((defined $opts{'U'} && defined $opts{'M'}) ||
		  (defined $opts{'S'} && defined $opts{'M'}) ||
		  (defined $opts{'S'} && defined $opts{'U'}) ||
		  (defined $opts{'f'} && defined $opts{'w'}) ||
		  (defined $opts{'f'} && defined $opts{'U'}) ||
		  ((defined $opts{'w'} && !defined $opts{'U'} &&
		    !defined $opts{'M'} && !defined $opts{'S'})) );



  $send_user = $opts{'u'};
  $send_admin = $opts{'a'};
  $bcc_address = $opts{'b'};
  $from_address = $opts{'F'};
  $bcc_only = $opts{'B'};
  $message_file = $opts{'m'};
  $host_file = $opts{'f'};
  $by_user = "0";
  $by_user = $opts{'U'} if defined $opts{'U'};
  $s_type = "U" if defined $opts{'U'};
  $s_type = "M" if defined $opts{'M'};
  $s_type = "S" if defined $opts{'S'};
  $output = $opts{'o'};
  $slow = $opts{'s'};


  foreach $pairs (split(',',  $opts{'D'})){
#    warn __FILE__ . ":" . __LINE__ . ": processing $pairs \n";
    ($da_key, $da_val) = split( /=/, $pairs);
    $vals{$da_key} = $da_val;
  }
  $vals{DATE} = CMU::Netdb::ArpaDate();

  $where = join " ", $opts{'w'}, @ARGV if ((defined $ARGV[0]) && (defined $opts{'w'}));

  $where = $opts{'w'} if not defined $ARGV[0];



  $where = "( " . $where . " )" if (defined $where);

  warn __FILE__ . ":" . __LINE__ . ": by_user = $by_user \n" if ($debug >= 3);
  usage($dbh, 3) if ((! defined $by_user) && ($s_type eq "U"));

  return ($output, $send_user, $send_admin, $bcc_address, $bcc_only, $from_address, $message_file, $host_file, $s_type, $by_user, $where, \%vals);

}


sub usage {
  my ($dbh, $level) = @_;
  print "error $level\n\n";

  for ($level) {
    /0/ && do { print "\n"; last ; };
    /1/ && do { print "No host list defined, specify either -w or -f optione\n"; last ; };
    /2/ && do { print "Invalid option combination\n"; last ; };
    /3/ && do { print "User not specified but user query specified\n"; last ; };
    /4/ && do { print "Could not open message file\n"; last ; };
  }


  print " -u - Address mail to users\n";
  print " -a - Address mail to administrators\n";
  print " -s - Run slowly to avoid overloading mail servers.  One message per second max.\n";
  print " -B - send mail to BCC machine only\n";
  print " -b bcc-address{,bcc_address...} - Blind CC address\n";
  print " -m message_file - Generic message containing macros above\n";
  print "\n";
  print " -f list_file - File containing query to use \n\t(Cannot be used with -U or -w option)\n";
  print " -F Address - address you want to tell sendmail to use as the from address\n";
  print " -D MACRO=define[,MACRO=define]* - List of additional macros\n";
  print "     the argument for this should be quoted\n";
  print " -o output_file - write the mail to a single file instead of sending\n";
  print " -w where_clause - Clause for query (cannot be used with -f option)\n";
  print "\n";
  print " -U user_or_group - query using user or group protections\n";
  print "\tuser_or_group should be a comma separated list of user or group IDs\n";
  print " -M - query using machine information only\n";
  print " -S - query using machine_subnet query\n";
  print "The last three are mutually exclusive\n";

  $dbh->disconnect();

  if ($level == 0) {
    print "\n\n\n";
    print " Pre-defined macros are as follows\n";
    print '%DATE% - Current ARPA format date (normally used in Date: header)' . "\n";
    print '%USER% - The user(s) receiving this mail (may be group members, comma sep)' . "\n";
    print '%AFFILIATION% - The dept: group for this machine' . "\n";
    print '%SUBNET% - The subnet this machine is registered on' . "\n";
    print '%NAME% - the name of the machine' . "\n";
    print '%IP_ADDRESS% - the IP Address of the machine' . "\n";
    print '%MAC% - The MAC address of the machine' . "\n";
    print '%INFO% - List of information about machines listed ' . "\n";
    print '"%NAME%, %IP_ADDRESS%, %MAC%, %USERS%, %AFFILIATION%, %MODIFIED%\n\t%URL%"' . "\n";
    print "\t" . 'where ' . "\n";
    print "\t" . '%USERS% is the users associated with this machine, semicolon seperated' . "\n";
    print "\t" . '%URL% - A full URL to the machine edit screen' . "\n";
    print "\t" . '%MODIFIED% - last update of machine record' . "\n";
    print '%SHORTINFO% - List of information about machines listed' . "\n";
    print " \t" .'"%NAME% - %IP_ADDRESS - %USERS%%"' . "\n";
    print 'if multiple information is going in a single message, all macros produce' . "\n";
    print 'comma seperated lists except %INFO% which produces newline seperated' . "\n";
    print 'records.' . "\n\n";

  }

  die "\n\n usage: mail_em.pl [ -o /tmp/dumpfile ] -B|-u|-a [ -F from_address ] [-D MACRO=def] [-b email_address] -m message_file [-f list_file| -U|-M|-S -w \"(where clause)]\"\n"
}


sub get_by_file {
  my ($dbh, $s_type, $by_user, $host_file) = @_;
  my ($ret_data);
  my ($where, $how, $what, @what, $elem, $scan);

  $ret_data = 1;
  open(INFILE, $host_file) || die "Cannot open file \"$host_file\"\n$!\n";
 REREAD:
  $how = <INFILE>;
  chomp($how);
  goto REREAD if $how =~ /^#/;

  die "\"$how\" contains no positional macros\n" if $how !~ /%\d+%/;
  foreach $what (<INFILE>){
    chomp($what);
    next if $what =~ /^#/;
    $elem = $how;
    @what = split (/ /, $what);
    foreach $scan (1 .. ($#what + 1)){
      $elem =~ s/%$scan%/$what[$scan - 1]/g;
      warn __FILE__ . ":" . __LINE__ . ": Substituting \"$what[$scan - 1]\" for \"%$scan%\"\n" if ($debug >= 2);
    }
    die "\"$what\" contains fewer fields than the macro\n\"$how\"\n" if $elem =~ /%\d+%/;


    $where = $where . " or ( $elem )" if defined $where;
    $where = "( $elem )" if not defined $where;

  }
  $where = "( $where )";
  close INFILE;
  warn __FILE__ . ":" . __LINE__ . ": calling get_by_where with where clause...\n$where\n\n" if ($debug >= 1);
  $ret_data = get_by_where($dbh, $s_type, $by_user, $where);
  return ($ret_data);

}




sub get_by_where {
  my ($dbh, $s_type, $by_user, $where) = @_;
  my ($db_user, $db_result, $m_prot, $ret_list);
  my ($i,$j, $usr, $grp, $id, $afid);
  my (@ret_data, $grid, $k, $pu);
  my ($gpos);

  $db_user="netreg";

  if (($s_type eq 'M') || ($s_type eq 'S')){
#    warn __FILE__ . ":" . __LINE__ . ": calling list with ||$db_user||$where\n";
    $db_result = CMU::Netdb::list_machines_subnets($dbh, $db_user, $where);

    die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get host list\n" if not ref $db_result;

#    warn __FILE__ . ":" . __LINE__ . ": retrieved $#$db_result rows\n";

  } elsif ( $s_type eq "U") {

    foreach my $act (split /,/, $by_user) {
      my ($req, $type, $id, $hdr, $ret, $usr);
      # Punt if wildcards are embeded in the id
      next if ($act =~ /%|_/);
      # determine if user or group (quick and dirty check)
      if ($act =~ /:/) {
	warn __FILE__ . ":" . __LINE__ . ": Processing Group: $act\n" if ($debug >= 2);
	$type = 'GROUP';
	# snatch a user ID that is a member of that group. This is bogus, but must be done.
	my $userlist = CMU::Netdb::list_members_of_group($dbh, 'netreg', $act);

	my $uspos = GetHeaderPos($userlist);

	die "No members in group $act\n " if ($#$userlist == 0);
	$usr = $userlist->[1][$uspos->{'credentials.authid'}];
	warn __FILE__ . ":" . __LINE__ . ": Using user >$usr< to get group information\n" if ($debug);

	# get the numeric value for the group
	my $groups = CMU::Netdb::list_groups($dbh, 'netreg', "groups.name like \"$act\"");

	die "Group information not available for $act\n" if ($#$groups == 0);
	my $grpos = GetHeaderPos($groups);

	$id = $groups->[1][$grpos->{'groups.id'}];

      } else {
	warn __FILE__ . ":" . __LINE__ . ": Processing User: $act\n" if ($debug >= 2);
	$type = 'USER';
	$usr = $act;
	# get the numeric value for the user
	my $users = CMU::Netdb::list_users($dbh, 'netreg', "credentials.authid like \"$act\"");
	my $uspos = GetHeaderPos($users);

	$id = $users->[1][$uspos->{'users.id'}];
	if ($debug >= 5) {
	  foreach (sort keys %$uspos){
	    warn __FILE__ . ":" . __LINE__ . ":  $_ at offset $uspos->{$_}\n";
	  }
	}
      }

      # get the machine list for the user/group
      warn __FILE__ . ":" . __LINE__ . ": Calling list_machines_munged_protections(\$dbh, $usr, $type, $id, $where)\n";
      $db_result = CMU::Netdb::list_machines_munged_protections($dbh, $usr, $type, $id, $where);
      die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get host list\n" if not ref $db_result;

      warn __FILE__ . ":" . __LINE__ . ": $#$db_result rows returned for the query using $usr, $type, $id, $where\n" if ($debug >= 2);

      # if the return list is already populated, shift the header line off then shift the entire new list onto it
      if (!defined $ret_list) {
	$ret_list = [ @$db_result ];
      } else {
	shift @$db_result;
	while (scalar(@$db_result)) {
	  push(@$ret_list, shift(@$db_result));
	}
      }
    }
    $db_result = $ret_list;

    if ($debug >= 4) {
      foreach ( 1 .. $#$db_result) {
	warn __FILE__ . ":" . __LINE__ . ": " .  join( '|', @{$db_result->[$_]}) .  "\n";
      }
    }

    warn __FILE__ . ":" . __LINE__ . ": db_result count = $#$db_result\n" if ($debug);
    $db_result = Uniq_Machines($db_result);
    warn __FILE__ . ":" . __LINE__ . ": db_result count = $#$db_result\n" if ($debug);

    if ($debug >= 1) {
      warn __FILE__ . ":" . __LINE__ . ": dumping result list\n";
      foreach ( 0 .. $#$db_result) {
	warn join( '|', @{$db_result->[$_]}) . "\n";
      }
    }

    die "error $db_result ( $CMU::Netdb::errmeanings{$db_result} ) while attempting to get host list\n" if not ref $db_result;


  }

  $i = 0;
  @{$db_result->[0]} = (@{$db_result->[0]}, 'machine.users', 'machine.affil', 'machine.affil_id', 'groups.flags');
  foreach (@{$db_result->[0]}){
# map column headers from reply
    $id = $i if ($_ eq 'machine.id');
    $usr = $i if ($_ eq 'machine.users');
    $grp = $i if ($_ eq 'machine.affil');
    $afid = $i if ($_ eq 'machine.affil_id');
    $pu = $i if ($_ eq 'groups.flags');
    $i++
  }

#  warn __FILE__ . ":" . __LINE__ . ": id = $id\n";
#  warn __FILE__ . ":" . __LINE__ . ": usr = $usr\n";
#  warn __FILE__ . ":" . __LINE__ . ": grp = $grp\n";

  for $i ( 1 .. $#$db_result ) {
# Loop through the values returned.
# items referenced as follows...
#  @{$db_result->[$i]}[$id],
#      warn __FILE__ . ":" . __LINE__ . ": " .  join( '|', @{$db_result->[$i]}) . "\n";

    $m_prot = CMU::Netdb::list_protections($dbh, $db_user, 'machine', @{$db_result->[$i]}[$id], '1');
    for $j (0 .. $#$m_prot){
#      warn __FILE__ . ":" . __LINE__ . ": result[0] = @{$m_prot->[$j]}[0] \n";
      if (@{$m_prot->[$j]}[0] eq 'user'){
#	warn __FILE__ . ":" . __LINE__ . ": Adding user @{$m_prot->[$j]}[1] to @{$db_result->[$i]}[$usr] \n";

	if (defined (@{$db_result->[$i]}[$usr])){
	  @{$db_result->[$i]}[$usr] = join (';', @{$db_result->[$i]}[$usr],
					    @{$m_prot->[$j]}[1]);
	} else {
	  @{$db_result->[$i]}[$usr] = @{$m_prot->[$j]}[1];
	}

      } elsif ((@{$m_prot->[$j]}[0] eq 'group') &&
	       (@{$m_prot->[$j]}[1] =~ /dept:/)){


	@{$db_result->[$i]}[$grp] = @{$m_prot->[$j]}[1];
#	  warn __FILE__ . ":" . __LINE__ . ": Trying to call list_groups with where = \"(groups.name like \"@{$m_prot->[$j]}[1]\")\"\n";
	$grid = CMU::Netdb::list_groups($dbh, $db_user, "(groups.name like \"@{$m_prot->[$j]}[1]\")");
	$gpos = GetHeaderPos($grid);
	@{$db_result->[$i]}[$afid] = @{$grid->[1]}[$gpos->{'groups.id'}];
	@{$db_result->[$i]}[$pu] = @{$grid->[1]}[$gpos->{'groups.flags'}];
#	  warn __FILE__ . ":" . __LINE__ . ": Adding group @{$m_prot->[$j]}[1] (@{$grid->[1]}[0]) to @{$db_result->[$i]}[$grp] \n";

      }
    }

#    warn __FILE__ . ":" . __LINE__ . ": " .  join( '|', @{$db_result->[$i]}) . "\n";
  }


  return ($db_result);


}

sub Uniq_Machines{
  my ($list) = @_;
  my ($header, $hash);
  my ($key, $trash);

  $header = shift(@$list);

  map {
    $key = $_->[0];
    $hash->{$key} = $_;
  } ( @$list );
  $list = [];

  foreach (sort {$a <=> $b} keys %$hash) {
    push(@$list, $hash->{$_});
  }
  unshift (@$list, $header);
  return ($list);
}



# Function: GetHeaderPos
#
# Arguments: 1
#    Pointer to array of arrays as returned by primitives::List
#
# Actions: 
#    Creates hash of positions of columns that are returned
#
# Return value: 
#    pointer to hash
#
# Side effects:
#    None
#
# Caveats:
#    Make sure to check if a value is defined before you use it.
# 

sub GetHeaderPos {
  my ($data) = @_;
  my ($i, %heads);

  $i = 0;
  %heads = ();

  foreach (@{$data->[0]}){
#  map column headers from reply
    warn __FILE__ . ":" . __LINE__ . ": $_ \n" if $debug >= 25;
    $heads{$_} = $i;
    $i++
  }
  return (\%heads);

}

