#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use DirHandle;
use Socket;
use Net::Netmask;

$| = 1;

my @spinny = ('\\', '-', '/', '|');

my %munge = (
	     'netdb/_sys_scheduled.txt'        => \&nullify_zero_dates,
	     'netdb/dns_zone.txt'              => \&nullify_zero_dates,
	     'netdb/machine.txt'               => \&munge_machine,
	     'netdb/subnet.txt'                => \&munge_subnet,
#	     'netdb/ip_range.txt'              => \&munge_ip_range,
	     'netmon/arp_archive.txt'          => \&munge_arp_archive,
	     'netmon/dhcp_leases.txt'          => \&munge_dhcp_leases,
	     'netmon/arp_capture_extra.txt'    => \&munge_arp_capture_extra,
	     'netmon/traps.txt'                => \&munge_traps,
	     'netmon/arp_capture.txt'          => \&munge_arp_capture,
	     'netmon/arp_lastseen.txt'         => \&munge_arp_lastseen,
	     'netmon/arp_tracking.txt'         => \&munge_arp_tracking,
	     'netmon/device_timings.txt'       => \&nullify_zero_dates,
	     'netmon/devmac_tracking.txt'      => \&nullify_zero_dates,
	     'netmon/dhcp_fingerprints.txt'    => \&munge_dhcp_fingerprints,
	     'netmon/interface_process.txt'    => \&nullify_zero_dates,
	     'netmon/ports_archive.txt'        => \&munge_ports_archive,
	     'netmon/ports_tracking.txt'       => \&munge_ports_tracking,
	     'netmon/routes_capture_extra.txt' => \&munge_routes_capture_extra,
	     'netmon/wifi_archive.txt'         => \&munge_wifi_archive,
	     'netmon/wifi_lastseen.txt'        => \&munge_wifi_lastseen,
	     'netmon/wifi_tracking.txt'        => \&munge_wifi_tracking,
	     'netmon/wifi_capture.txt'         => \&munge_wifi_capture,
	     'netmon/dhcp_leases_archive.txt'  => \&munge_dhcp_leases_archive,
	     'netmon/cam_tracking.txt'         => \&nullify_zero_dates,
	     'netmon/trap_varbinds_raw.txt'    => \&munge_trap_varbinds_raw,
	     'netmon/devmac_lastseen.txt'      => \&munge_devmac_lastseen,
	     'netmon/devmac_tracking.txt'      => \&munge_devmac_tracking,
	     'netmon/devmac_archive.txt'       => \&munge_devmac_archive,
	     'netmon/ndp_tracking.txt'         => \&munge_ndp_tracking,
);

if(defined($ARGV[0])){
    if($ARGV[0] =~ m/(.*)\/(.*\.txt)/) {
	clean_file($1, $2);
    } else {
	print "Error: file must be netdb/foo.txt or netmon/foo.txt\n";
	exit;
    }
} else {
    foreach my $dir ("netdb", "netmon"){
	opendir(DIR, $dir) or die "Can't open $dir: $!";
	my @files = readdir(DIR);
	closedir(DIR);

	foreach my $file (sort @files) {
	    next if $file =~ /^\./;
	    next unless $file =~ /\.txt$/;
	    clean_file($dir, $file);
	}
    }
}

sub clean_file {
    my ($dir, $file) = @_;

    my $oldf = $dir . "/" . $file;
    my $newf = $dir . "-clean/" . $file;

    my $newfh;
    my $oldfh;
    my $lineno = 0;
    my $spin = 0;

    print "Processing $oldf... ";
    print $spinny[3];

    mkdir $dir . "-clean";
    open($newfh, ">", $newf) or die "Cannot open " . $newf . ": " . $!;
    open($oldfh, "<", $oldf) or die "Cannot open " . $oldf . ": " . $!;
    if ( defined($munge{$oldf}) ){
	my $func = $munge{$oldf};
	while(my $line = <$oldfh>){
	    if ($line =~ /\\$/){
		chomp($line);
		$line .= '\n' . <$oldfh>;
	    }
	    $line =~ s/\r//g;
	    print $newfh $func->($line);
	    unless($lineno++ % 1000){
		print "\b", $spinny[$spin++ % 4];
	    }
	}
    }else{
	while(<$oldfh>){
	    $_ =~ s/\r//g;
	    print $newfh $_;
	    unless($lineno++ % 1000){
		print "\b", $spinny[$spin++ % 4];
	    }
	}
    }
    print "\bProcessed $lineno records.\n";
}

sub encode_bytea {
    my ($blob) = @_;

    return join('', map { $_ = '\\\\' . sprintf("%.3o", $_) } unpack("C*", $blob));
}

sub nullify_zero_dates {
    my ($line) = @_;

    $line =~ s/0000-00-00 00:00:00/\\N/g;
    $line =~ s/0000-00-00/\\N/g;
    return $line;
}

sub munge_machine {
   my ($line) = @_;

   my @a = split("\t", $line);
   $a[4] = inet_ntoa(pack("N", $a[4]));
   $a[15] = ($a[15] eq '0000-00-00' ?
	     "\\N" :
	     $a[15]);
   return join("\t", @a);
}

sub munge_subnet {
    my ($line) = @_;

    $line =~ s/0000-00-00 00:00:00/\\N/g;
    my @a = split("\t", $line);
    my $ip = inet_ntoa(pack("N", $a[4]));
    my $mask = inet_ntoa(pack("N", $a[5]));
    my $net = new Net::Netmask($ip, $mask);
    $a[4] = $ip . '/' . $net->bits;
    splice(@a, 5, 1);
    return join("\t", @a);
}

sub munge_ip_range {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[5] = inet_ntoa(pack("N", $a[5]));
    $a[6] = inet_ntoa(pack("N", $a[6]));
    return join("\t", @a);
}

sub munge_arp_archive {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[3] = inet_ntoa(pack("N", $a[3]));
    return join("\t", @a);
}

sub munge_dhcp_leases {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[6] = inet_ntoa(pack("N", $a[6]));
    return join("\t", @a);
}

sub munge_arp_capture_extra {
    my ($line) = @_;

    my @a = split("\t", $line);
    if ($a[1] eq '') {
	$a[1] = '\N';
    }
    $a[2] = inet_ntoa(pack("N", $a[2]));
    return join("\t", @a);
}

sub munge_traps {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[4] = inet_ntoa(pack("N", $a[4]));
    return join("\t", @a);
}

sub munge_arp_capture {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[3] = inet_ntoa(pack("N", $a[3]));
    return join("\t", @a);
}

sub munge_arp_lastseen {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[2] = inet_ntoa(pack("N", $a[2]));
    return join("\t", @a);
}

sub munge_arp_tracking {
    my ($line) = @_;

    $line =~ s/0000-00-00 00:00:00/\\N/g;
    my @a = split("\t", $line);
    $a[3] = inet_ntoa(pack("N", $a[3]));
    return join("\t", @a);
}

sub munge_dhcp_fingerprints {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[5] =~ s/[[:^print:]]//g;
    return join("\t", @a);
}

sub munge_ports_archive {
    my ($line) = @_;

    my @a = split("\t", $line);
    if ($a[5] eq '') {
	$a[5] = '\N';
    }
    return join("\t", @a);
}

sub munge_ports_tracking {
    my ($line) = @_;

    my @a = split("\t", $line);
    if ($a[8] eq '0000-00-00 00:00:00') {
	$a[8] = '\N';
    }
    if ($a[5] eq '') {
	$a[5] = '\N';
    }

    return join("\t", @a);
}

sub munge_routes_capture_extra {
    my ($line) = @_;

    my @a = split("\t", $line);
    my $ip = inet_ntoa(pack("N", $a[1]));
    my $mask = inet_ntoa(pack("N", $a[2]));
    my $net = new Net::Netmask($ip, $mask);
    $a[1] = $ip . '/' . $net->bits;
    splice(@a, 2, 1);
    return join("\t", @a);
}

sub munge_wifi_archive {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[3] = inet_ntoa(pack("N", $a[3]));
    return join("\t", @a);
}

sub munge_wifi_lastseen {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[2] = inet_ntoa(pack("N", $a[2]));
    return join("\t", @a);
}

sub munge_wifi_tracking {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[3] = inet_ntoa(pack("N", $a[3]));
    if ($a[11] eq '0000-00-00 00:00:00') {
	$a[11] = '\N';
    }
    return join("\t", @a);
}

sub munge_wifi_capture {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[3] = inet_ntoa(pack("N", $a[3]));
    return join("\t", @a);
}


sub munge_dhcp_leases_archive {
    my ($line) = @_;

    my @a = split("\t", $line);
    $a[6] = inet_ntoa(pack("N", $a[6]));
    return join("\t", @a);
}

sub munge_trap_varbinds_raw {
    my ($line) = @_;

    chomp $line;
    my @a = split("\t", $line, 8);

    if($a[5] eq ''){
	$a[5] = '\N';
    }
    $a[6] = encode_bytea($a[6]);
    $a[7] = encode_bytea($a[7]);
    return join("\t", @a) . "\n";
}

sub munge_devmac_lastseen {
    my ($line) = (@_);

    my @a = split("\t", $line);
    if ($a[1] eq '') {
        $a[1] = '\N';
    }
    return join("\t", @a);
}

sub munge_devmac_tracking {
    my ($line) = (@_);

    my @a = split("\t", $line);
    if ($a[2] eq '') {
        $a[2] = '\N';
    }
    if ($a[5] eq '0000-00-00 00:00:00') {
        $a[5] = '\N';
    }

    return join("\t", @a);
}

sub munge_devmac_archive {
    my ($line) = (@_);

    my @a = split("\t", $line);
    if ($a[2] eq '') {
        $a[2] = '\N';
    }

    return join("\t", @a);
}

sub munge_ndp_tracking {
    my ($line) = (@_);

    my @a = split("\t", $line);
    if ($a[8] eq '0000-00-00 00:00:00') {
        $a[8] = '\N';
    }


    return join("\t", @a);
}
