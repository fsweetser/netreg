#!/usr/bin/perl

use strict;

use lib '/home/netreg/lib';

use CMU::Netdb;
use CMU::Netdb::config;

use Data::Dumper;

my $Zone = $ARGV[0];
my $Stage = $ARGV[1];
 
my @NewNS = qw/ac-ddns1.net.cmu.edu ac-ddns2.net.cmu.edu
  ddns-a100.net.cmu.edu/;
my $Master = 'ddns-master.net.cmu.edu';

my ($res, $XFERPATH) = CMU::Netdb::config::get_multi_conf_var('netdb', 'DNS_XFERPATH');

## Should be the ID of the new service group for zones (ie DDNS.dns)
my $NewSG = 24;

my $USER = 'netreg';
my $FORCE = 0;

sub usage {
  print <<USAGE;
Usage: $0 [zone] [stage] [force]
    zone: name of zone that we're converting
    force: -f
    stage: What stage of the process we're in:
      These steps follow section 6.1.3 of the manual:
       -0: Create zone (XX-toplevel)
       -1: Lock zone file, parent zone file, named.conf.*
       -2: Updates NS records, ddns_auth, and DNS service group
       -3: forces DNS zone regeneration
       -4: [null] (Wait for the nameserver configs to xfer to ddns)
       -5: [null] (copy the zonefiles to the master nameserver)
       -6: adds ddns:ena to ddns_auth
       -7: once again, forces DNS zone regeneration
       -8: [null] (verify the zone files are being served from DDNS)
       -9: Unlocks all files

       -a1: Adds key/FOO where FOO is the third argument
USAGE
}

my %FRefs = ('-0' => \&zero,  
	     '-1' => \&one,   # DONE
	     '-2' => \&two,   # InProg
	     '-3' => \&three, # DONE
	     '-4' => \&null,
	     '-5' => \&null, 
	     '-6' => \&six,   # open
	     '-7' => \&three, # DONE
	     '-8' => \&null,
	     '-9' => \&nine,
	     '-a1' => \&a_one); # DONE

if (!defined $FRefs{$Stage} || $Zone eq '') {
  &usage();
  exit 1;
}

$FORCE = 1 if ($ARGV[2] eq '-f');

$FRefs{$Stage}->($Zone);

exit 0;

sub zero {
  my ($Z) = @_;

  # Create the zone
  my $Type = 'fw-toplevel';
  $Type = 'rv-toplevel' if ($Z =~ /in-addr.arpa/i);

  my $dbh = CMU::Netdb::lw_db_connect();

  my %Fields = ('name' => $Z,
		'soa_host' => 'ddns-master.net.cmu.edu',
		'soa_email' => 'host-master.andrew.cmu.edu',
		'soa_refresh' => 3600,
		'soa_retry' => 900,
		'soa_expire' => 2419200,
		'soa_minimum' => 21600,
		'type' => $Type,
		'soa_default' => 21600);
		
  my ($res, $fields) = CMU::Netdb::add_dns_zone($dbh, 'netreg', \%Fields);
  print "Adding zone $Z result: $res\n";
}

### ************ Step One **************
### Add ddns:ena
###
sub one {
  my ($Z) = @_;
  # List all the files in the zone-xfer directory
  opendir(DIR, $XFERPATH)
    || die "Cannot list files in $XFERPATH";
  my @Files = readdir(DIR);
  close(DIR);
  
  # Lock all the named.confs
  file_lock($XFERPATH,
	    grep(/^named.conf./, @Files));
  
  # Unlock the named.confs of the new servers, and the master
  foreach my $N (@NewNS) {
    file_unlock($XFERPATH,
		grep(/^named.conf.$N/i, @Files));
  }

  file_unlock($XFERPATH,
	      grep(/^named.conf.$Master/i, @Files));

  # Lock the zone file
  file_lock($XFERPATH,
	    grep(/^$Z/i, @Files));
  
  # Lock the parent zone file
  my ($h, $z) = split(/\./, $Z, 2);
  file_lock($XFERPATH,
	    grep(/^$z/i, @Files));
}

### ************ Step Two **************
### Most of the work: 
###  - remove old NSs, add new ones
###  - remove from old SG, add to DDNS SG
###  - add ddns auth information
sub two {
  my ($Z) = @_;
  
  my $dbh = CMU::Netdb::lw_db_connect();
  # Load the zone data out of NetReg
  my $ZD = CMU::Netdb::list_dns_zones($dbh, $USER,
				      "dns_zone.name = '$Z'");
  if (!ref $ZD) {
    print "Error listing DNS zones: $ZD\n";
    return;
  }elsif(!defined $ZD->[1]) {
    print "DNS Zone not found ($Z).";
    return;
  }
  my %zone_pos = %{CMU::Netdb::makemap($ZD->[0])};
  
  my %AuthFields = ();
  map { 
    my ($k, $v) = split(/\:/, $_, 2);
    $AuthFields{$k} = $v;
  } split(/\s+/, $ZD->[1]->[$zone_pos{'dns_zone.ddns_auth'}]);

  # Check (and conditionally update) ddns_auth
  if (defined $AuthFields{'ddns'} || 
      defined $AuthFields{'key'} ||
      defined $AuthFields{'txtkey'}) {
    print "ddns_auth field already contains ddns/key/txtkey fields";
    return unless ($FORCE);
  }
  
  # Update the zone data
  $AuthFields{key} = makekey();
  $AuthFields{txtkey} = makekey();
  
  my %fields;
  map { 
    $_ =~ s/^dns_zone\.//;
    $fields{$_} = $ZD->[1]->[$zone_pos{"dns_zone.$_"}];
  } keys %zone_pos;

  $fields{ddns_auth} = join(' ', map { "$_:$AuthFields{$_}" }
                            keys %AuthFields);
    
  $fields{type} = 'fw-toplevel' if ($fields{type} =~ /^fw-/);
  $fields{type} = 'rv-toplevel' if ($fields{type} =~ /^rv-/);

  $fields{soa_host} = 'ddns-master.net.cmu.edu' if (!$fields{soa_host});
  $fields{soa_email} = 'host-master.andrew.cmu.edu' if (!$fields{soa_email});

  my ($id, $version) = ($fields{id}, $fields{version});
  
  delete $fields{id};
  delete $fields{version};

  # Go for the update
  print Dumper(\%fields);
  {
    my ($res, $ref) = CMU::Netdb::modify_dns_zone($dbh, $USER, $id, $version,
						  \%fields);
    if ($res != 1) {
      print "Error updating dns zone ($id/$version): ".join(',', @$ref)."\n";
      return;
    }
    print "Zone Updated\n";
  }
  
  # Load the dns resource. Delete the ones that don't match @NewNS,
  # and add the NewNS ones

  my $Query = "dns_resource.owner_type = 'dns_zone' AND ".
    "dns_resource.owner_tid = '$id'";
  my $ldrr = CMU::Netdb::list_dns_resources($dbh, $USER, $Query);
  if (!ref $ldrr) {
    print "list_dns_resources returned $ldrr\n";
    return;
  }

  my %res_pos = %{CMU::Netdb::makemap($ldrr->[0])};
  unshift(@$ldrr);
  
  my %newns;
  map { $newns{$_} = 1; } @NewNS;
  
  foreach my $LR (@$ldrr) {
    next unless ($LR->[$res_pos{'dns_resource.type'}] eq 'NS');
    if (defined $newns{$LR->[$res_pos{'dns_resource.rname'}]}) {
      delete $newns{$LR->[$res_pos{'dns_resource.rname'}]};
      next;
    }else{
      # Delete this record
      if (dns_res_del($dbh, $LR->[$res_pos{'dns_resource.id'}],
		      $LR->[$res_pos{'dns_resource.version'}]) != 1) {
	return;
      }
	
      next;
    }
  }

  # All remaining newns's, add them..
  map { return if (dns_res_add($dbh, $Z, $id, $_) != 1); } keys %newns;
  
  # Delete from DNS service group and add to the new DDNS one
  my $SQuery = "service_membership.member_type = 'dns_zone' AND ".
    "service_membership.member_tid = '$id'";
  
  my ($lsmr, $rMemRow, $rMemSum, $rMemData) =
    CMU::Netdb::list_service_members($dbh, $USER, $SQuery);

  if ($lsmr < 0) {
    print "Unable to list service groups ($lsmr).\n";
    return;
  }

  my $AddSG = 1;
  foreach my $id (keys %$rMemRow) {
    next unless ($rMemRow->{$id}->{'service.name'} =~ /\.dns$/);
    if ($rMemRow->{$id}->{'service.id'} == $NewSG) {
      $AddSG = 0;
      next;
    }

    # Delete this service member
    my ($smid, $smver) = ($rMemRow->{$id}->{'service_membership.id'},
			  $rMemRow->{$id}->{'service_membership.version'});
    my ($res, $fields) = CMU::Netdb::delete_service_membership($dbh, $USER, $smid, $smver);
    print "Result of deleting service_membership $smid/$smver: \n\t".
      "$res -- ".join(',', @$fields)."\n";
  }

  ## Add the new service membership
  if ($AddSG) {
    my %MFields = ('service' => $NewSG,
		   'member_type' => 'dns_zone',
		   'member_tid' => $id);
    
    my ($res, $ref) = CMU::Netdb::add_service_membership($dbh, $USER, \%MFields);
    if ($res != 1) {
      print "Error adding zone ($id) to new service group ($NewSG): ".join(',', @$ref)."\n";
      return;
    }
  }
    
  print Dumper($lsmr, $rMemRow, $rMemSum, $rMemData);
}

### ************ Step Three **************
### Force a DNS Update
###
sub three {
  # DNS Update force
  my $dbh = CMU::Netdb::lw_db_connect();
  $dbh->do("UPDATE _sys_scheduled SET next_run = now() WHERE id IN (1,2,11)");
}

### ************ Step Six **************
### Add ddns:ena
###
sub six {
  my ($Z) = @_;
   my $dbh = CMU::Netdb::lw_db_connect();
  # Load the zone data out of NetReg
   my $ZD = CMU::Netdb::list_dns_zones($dbh, $USER,
                                      "dns_zone.name = '$Z'");
   if (!ref $ZD) {
    print "Error listing DNS zones: $ZD\n";
    return;
  }elsif(!defined $ZD->[1]) {
    print "DNS Zone not found.";
    return;
  }
   my %zone_pos = %{CMU::Netdb::makemap($ZD->[0])};

  my %AuthFields = ();
  map {
    my ($k, $v) = split(/\:/, $_, 2);
    $AuthFields{$k} = $v;
  } split(/\s+/, $ZD->[1]->[$zone_pos{'dns_zone.ddns_auth'}]);

  # Check (and conditionally update) ddns_auth
  if (defined $AuthFields{'ddns'} ||
      ! defined $AuthFields{'key'} ||
      ! defined $AuthFields{'txtkey'}) {
    print "ddns_auth field already contains ddns OR doesn't have /key/txtkey fields\n";
    return;
  }

  # Update the zone data

  my %fields;
  map {
    $_ =~ s/^dns_zone\.//;
    $fields{$_} = $ZD->[1]->[$zone_pos{"dns_zone.$_"}];
  } keys %zone_pos;

  my ($id, $version) = ($fields{id}, $fields{version});

  delete $fields{id};
  delete $fields{version};

  $AuthFields{ddns} = "ena";
  $fields{ddns_auth} = join(' ', map { "$_:$AuthFields{$_}" }
			    keys %AuthFields);
  
  # Go for the update
  print Dumper(\%fields);
  {
    my ($res, $ref) = CMU::Netdb::modify_dns_zone($dbh, $USER, $id, $version,
						  \%fields);
    if ($res != 1) {
      print "Error updating dns zone ($id/$version): ".join(',', @$ref)."\n";
      return;
    }
    print "Zone Updated\n";
  }
}

sub null {
  print "Not doing anything at this step.. but you should probably \n".
    "do something.\n";
}

### ************ Step Nine **************
### Unlock all the files
###
sub nine {
  my ($Z) = @_;
  # List all the files in the zone-xfer directory
    opendir(DIR, $XFERPATH)
    || die "Cannot list files in $XFERPATH";
  my @Files = readdir(DIR);
  close(DIR);

  # Unlock all the named.confs
    file_unlock($XFERPATH,
            grep(/^named.conf./, @Files));

  # Unlock the zone file
    file_unlock($XFERPATH,
            grep(/^$Z/i, @Files));

  # Unlock the parent zone file
  my ($h, $z) = split(/\./, $Z, 2);
    file_unlock($XFERPATH,
            grep(/^$z/i, @Files));

}

sub a_one {
  add_extra_key($_[0], $ARGV[2]);
}

sub add_extra_key {
  my ($Z, $keyname) = @_;
  my $dbh = CMU::Netdb::lw_db_connect();
  # Load the zone data out of NetReg
  my $ZD = CMU::Netdb::list_dns_zones($dbh, $USER,
                                      "dns_zone.name = '$Z'");
  if (!ref $ZD) {
    print "Error listing DNS zones: $ZD\n";
    return;
  }elsif(!defined $ZD->[1]) {
    print "DNS Zone not found.";
    return;
  }
  my %zone_pos = %{CMU::Netdb::makemap($ZD->[0])};
  
  my %AuthFields = ();
  map {
    my ($k, $v) = split(/\:/, $_, 2);
    $AuthFields{$k} = $v;
  } split(/\s+/, $ZD->[1]->[$zone_pos{'dns_zone.ddns_auth'}]);


  # Update the zone data

  my %fields;
  map {
    $_ =~ s/^dns_zone\.//;
    $fields{$_} = $ZD->[1]->[$zone_pos{"dns_zone.$_"}];
  } keys %zone_pos;

  my ($id, $version) = ($fields{id}, $fields{version});

  delete $fields{id};
  delete $fields{version};

  $AuthFields{"key/$keyname"} = makekey();
  $fields{ddns_auth} = join(' ', map { "$_:$AuthFields{$_}" }
			    keys %AuthFields);
  
  # Go for the update
  print Dumper(\%fields);
  {
    my ($res, $ref) = CMU::Netdb::modify_dns_zone($dbh, $USER, $id, $version,
						  \%fields);
    if ($res != 1) {
      print "Error updating dns zone ($id/$version): ".join(',', @$ref)."\n";
      return;
    }
    print "Zone Updated\n";
  }
}

sub dns_res_del {
  my ($dbh, $id, $version) = @_;

  my ($res, $ref) = CMU::Netdb::delete_dns_resource($dbh, $USER,
						    $id, $version);
  if ($res != 1) {
    print "Error deleting dns resource $id/$version: ".join(',', @$ref)."\n";
    return 0;
  }
  print "Deleted dns resource $id/$version.\n";
  return 1;  
}

## Add an NS resource with name $ResourceName to zone
## with $ZoneName
sub dns_res_add {
  my ($dbh, $ZoneName, $ZoneID, $ResourceName) = @_;

  my %fields = ('type' => 'NS',
		'name' => $ZoneName,
		'ttl' => 86400,
		'rname' => $ResourceName,
		'rmetric0' => 0,
		'rmetric1' => 0,
		'rport' => 0,
		'text0' => '',
		'text1' => '',
		'owner_type' => 'dns_zone',
		'owner_tid' => $ZoneID);
  my ($res, $ref) = CMU::Netdb::add_dns_resource($dbh, $USER, \%fields);
  if ($res != 1) {
    print "Error ($res) adding dns resource to $ZoneName: $ResourceName: ".
      join(',', @$ref)."\n";
    return 0;
  }
  print "Adding DNS Resource $ResourceName to $ZoneName\n";
  return 1;
}

sub file_lock {
  my ($dir, @Files) = @_;
  my $U = get_id('user', 'root');
  my $G = get_id('group', 'wheel');

  print "Locking as root($U)/wheel($G):\n";
  map { print "\t- $dir/$_\n" } @Files;
  
  chown($U, $G, map { "$dir/$_" } @Files);
}

sub file_unlock {
  my ($dir, @Files) = @_;
  my $U = get_id('user', 'netreg');
  my $G = get_id('group', 'netreg');
  
  print "Unlocking as netreg($U)/netreg($G):\n";
  map { print "\t- $dir/$_\n" } @Files;
  
  chown($U, $G, map { "$dir/$_" } @Files);
}

sub get_id {
  my ($type, $name) = @_;
  if ($type eq 'user') {
    my ($login, $p, $u) = getpwnam($name);
    return $u;
  }elsif($type eq 'group') {
    my ($n, $p, $g) = getgrnam($name);
    return $g;
  }else{
    return -1;
  }
}

sub makekey {
  chdir("/tmp");
  my $file = `/usr/ng/sbin/dnssec-keygen -a HMAC-MD5 -b 164 -n ENTITY move-ddns`;
  chomp($file);
  unless (-e "$file.private") {
    print "ERROR: File $file.private doesn't exist!\n";
  }
  
  my $RetKey;
  open(FILE, "$file.private");
  while(<FILE>) {
    if ($_ =~ /Key\:\s+(\S+)/) {
      $RetKey = $1;
    }
  }
  close(FILE);
  unlink("$file.private");
  unlink("$file.key");

  until($RetKey =~ /^[A-Za-z0-9]+$/) {
    $RetKey =~ s/[^A-Za-z0-9]/random_char()/e;
  }
  while(length($RetKey) % 4 != 0) {
    $RetKey = substr($RetKey, 1);
  }
  print "## Using key: $RetKey\n";
  return $RetKey;
}

sub random_char {
  my $chrStore = 0;
  my $iter = 0;
  until (chr($chrStore) =~ /[A-Za-z0-9]/) {
    $chrStore += rand(256) + ($iter++ % 18);
    $chrStore = $chrStore % 256;
  }
  return $chrStore;
}

