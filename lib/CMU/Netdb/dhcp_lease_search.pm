#   -*- perl -*-
#
# Copyright (c) 2004,2005 Duke University. All rights reserved.
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
# 3. The name "Duke University" must not be used to endorse or
#    promote products derived from this software without prior written
#    permission.
#
# 4. Redistributions of any form whatsoever must retain the following
#    acknowledgment: "This product includes software developed by 
#    Office of Information Technology at Duke University
#    (http://www.oit.duke.edu)."
#
# DUKE UNIVERSITY DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
# SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS,
# IN NO EVENT SHALL DUKE UNIVERSITY BE LIABLE FOR ANY SPECIAL,
# INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# USE OR INABILITY TO USE.
#
# $Id: dhcp_lease_search.pm,v 1.2 2008/03/27 19:42:34 vitroth Exp $
#
# $Log: dhcp_lease_search.pm,v $
# Revision 1.2  2008/03/27 19:42:34  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.1.6.1  2008/01/28 22:08:19  vitroth
# pulling new file from duke branch to merge branch
#
# Revision 1.1.4.1  2007/12/07 22:28:00  rchille
# 2nd round merge of all Duke changes with latest CMU changes
# Mainly updates and correction that were missing fromt he first pass
#
# Revision 1.2  2005/01/28 19:11:24  kcmiller
# * DHCP Lease Search
#
# Revision 1.1  2005/01/28 18:20:03  kcmiller
# * Initial checkin
#
#
#
package CMU::Netdb::dhcp_lease_search;

use strict;

use Data::Dumper;
use Time::Local;
use POSIX qw/strftime/;

use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK %errors/;

require Exporter;
$VERSION = '1.11';

@ISA = qw/Exporter/;

@EXPORT = qw//;

@EXPORT_OK = qw//;

%errors = (-60 => 'Leases file directory not set/readable.',
	   -61 => 'Error opening file/directory.',
	   -62 => 'No relevant leases files found.',
	   -63 => 'Query string terminated with no result on stack.',
	  );

sub new {
    my ($s, %options) = @_;
    my $self = {};
    bless $self;
    map { $self->{$_} = $options{$_}; } keys %options;

    my ($vres, $DHCP_CURRENT_LEASES);
    ($vres, $DHCP_CURRENT_LEASES) = CMU::Netdb::config::get_multi_conf_var('netdb', 'DHCP_CURRENT_LEASES');

    $self->{'currentLeasesFile'} = $DHCP_CURRENT_LEASES 
        unless (defined $self->{'currentLeasesFile'});

    return $self;
}

sub load_filelist {
    my ($self, $noforce) = @_;

    return if ($noforce == 1 && defined $self->{'files'});
    print STDERR $self->{'filedir'}."\n\n";
    return -60 unless (defined $self->{'filedir'} &&
		      -d $self->{'filedir'} && 
		      -r $self->{'filedir'});

    my $res = opendir(DIR, $self->{'filedir'});
    return -61 unless ($res);

    # eliminate dotfiles, non-files, and non-readable files
    my @Files = map { ((-f $self->{'filedir'}."/$_" &&
	                -r $self->{'filedir'}."/$_") ? $_ : ()) }  grep { !/^\./} readdir(DIR);

    my %FileList;
    foreach my $F (@Files) {
	if ($F =~ /(\-|\.)(\d+)/) {
	    $FileList{$self->{'filedir'}."/$F"} = {'time' => $2};
	}
    }
    $self->{'files'} = \%FileList;

    return 1;
}

sub find_lease {
    my ($self, $match, $time) = @_;

    my $file = $self->_find_closest_lease_file($time);
    return $file if ($file < 0);

    return $self->_find_lease_in_file($file, $match);
}

# From the list of files we have, figure out which one we should be using
# to match against for the given time.
# It's pretty simple: just find the next file after the time.
sub _find_closest_lease_file {
    my ($self, $time) = @_;

    my $ret = $self->load_filelist(1);
    return $ret if ($ret < 0);

    my $rFiles = $self->{'files'};

    # %times ends up being a hash of 
    # [difference in time between query and file] => [filename]
    # So if we have: 0 => 'dhcpd-leases.1092256003', the file has the
    # same time as the query, and we'll use it.
    # But if the time would otherwise be < 0 (e.g. file created before target
    # time) the file is ignored by the if {} else {} clause in the map.
    my %times =
    map { if ($rFiles->{$_}->{'time'} < $time) { (); }
	  else { ($rFiles->{$_}->{'time'}-$time, $_); } } keys %$rFiles;

    my @diffs = sort {$a <=> $b} keys %times;

    return $self->{'currentLeasesFile'} if ($#diffs == -1);

    return $times{$diffs[0]};
}
    
# Look for the requested information in the specified file.
sub _find_lease_in_file {
    my ($self, $file, $match) = @_;

    # using this we read one lease a time from the file
    $/ = "}\n";

    my $res = open(FILE, $file);
    unless ($res) {
      warn "Opening $file: $!";
      return -61;
    }

    my %LeasesFound;
    while(my $Lease = <FILE>) {
	my ($ip, $data) = $self->_lease_parse($Lease);
	$res = $self->_lease_matches($ip, $data, $match);
	return $res if ($res < 0);
	$LeasesFound{$ip} = $data if ($res);
    }
    close(FILE);
    return \%LeasesFound;
}

sub _lease_parse {
    my ($self, $Lease) = @_;
    $Lease =~ /lease ([0-9\.]+)\s+\{\s*(.+)/s;

    my ($IP, $Start, $End, $MAC, $CLH, $DDNS_FWD, $BS);

    $IP = $1;
    my @Lines = split(/\;\s+/, $2);
    foreach my $Line (@Lines) {

	if ($Line =~ /starts (\S+) (\S+) (\S+)/) {
	    $Start = ($1 eq 'never' ? 0 : 
		      $self->dhcptime_to_unixtime("$2 $3"));
	}elsif($Line =~ /ends (\S+) (\S+) (\S+)/) {
	    $End = ($1 eq 'never' ? 0 : 
		    $self->dhcptime_to_unixtime("$2 $3"));
	}elsif($Line =~ /hardware ethernet ([^\;]{17})/) {
	    $MAC = $1;
	}elsif($Line =~ /client-hostname \"([^\;\"]+)\"/) {
	    $CLH = $1 if ($CLH eq '');
      }elsif($Line =~ /set ddns-fwd-name = \"([^\;\"]+)\"/) {
	  $CLH = $1;
	  $DDNS_FWD = $1;
      }elsif($Line =~ /^binding state ([^\;]+)/) {
	  $BS = $1;
      }
    }

    return ($IP, {'ip_address' => $IP,
		  'start' => $Start,
		  'end' => $End,
		  'mac_address' => $MAC,
		  'client_hostname' => $CLH,
		  'ddns_fwdname' => $DDNS_FWD,
		  'binding_state' => $BS});
}

sub _lease_matches {
    my ($self, $IP, $LInfo, $match) = @_;
    my @Tokens = split(/(\s+)/, $match);

    my $aggr = '';
    @Tokens = map {   if (($_ =~ /^\"/ && $aggr eq '') ||
			  $aggr ne '') {
	                  $aggr .= $_; 
			  $_ = '';
		      }
		      if ($aggr =~ /\"$/) {
			  $_ = $aggr;
			  $_ =~ s/^\"//;
			  $_ =~ s/\"$//;
			  $aggr = '';
		      }
		      if ($_ eq '' || $_ =~ /^\s*$/) {
			  ();
		      }else{
			  $_;
		      }
		  } @Tokens;
         
    my @Stack;
    while($#Tokens != -1) {
	my $Tok = shift(@Tokens);
	if ($Tok =~ /^\$(.+)/) {
	    if (defined $LInfo->{$1}) {
		push(@Stack, $LInfo->{$1});
	    }else{
		return 0;
	    }
	}elsif($Tok eq '=') {
	    my $b = pop(@Stack);
	    my $a = pop(@Stack);

	    push(@Stack, ($a eq $b));
	}elsif($Tok eq '=~') {
	    my $b = quotemeta(pop(@Stack));
	    my $a = pop(@Stack);
	    my $comp = $a =~ /$b/i;
	    push(@Stack, defined $comp && $comp);
	}elsif($Tok eq '!') {
	    my $a = pop(@Stack);
	    push(@Stack, !$a);
	}elsif($Tok eq '>') {
	    my $b = pop(@Stack);
	    my $a = pop(@Stack);
	    push(@Stack, ($a > $b));
	}elsif($Tok eq '<') {
	    my $b = pop(@Stack);
	    my $a = pop(@Stack);
	    push(@Stack, ($a < $b));
	}elsif($Tok eq 'AND') {
	    my $b = pop(@Stack);
	    my $a = pop(@Stack);
	    push(@Stack, ($a & $b));
	}elsif($Tok eq 'OR') {
	    my $b = pop(@Stack);
	    my $a = pop(@Stack);
	    push(@Stack, ($a | $b));
	}elsif($Tok eq 'strftime_l') {
	    my $a = pop(@Stack);
	    my $b = pop(@Stack);
	    push(@Stack, strftime($a, localtime($b)));
	}else{
	    push(@Stack, $Tok);
        }
    }
    return pop(@Stack) if ($#Stack == 0);
    return -63;
}

# Try to generate a query based upon the input
sub educated_guess {
    my ($self, $query) = @_;

    if ($query =~ /\$/) {
	return $query;
    }

    if ($query =~ /^(\d+)\.(\d+)\.(\d+).(\d+)$/) {
	return "\$ip_address $query =";
    }

    if ($query =~ /^[0-9\.]+$/) {
	return "\$ip_address $query =~";
    }

    if ($query =~ /^[0-9a-f]{1,2}\:[0-9a-f]{1,2}\:[0-9a-f\:]+$/i) {
	return "\$mac_address $query =~";
    }

    return "\$ip_address $query =~ \$mac_address $query =~ ".
	"\$start \"%Y/%m/%d %T\" strftime_l $query =~ ".
	"\$end \"%Y/%m/%d %T\" strftime_l $query =~ ".
	"\%client_hostname $query =~ OR OR OR OR";
}    
	   
sub dhcptime_to_unixtime {
    my ($self, $dhcptime) = @_;
#         2000/09/08 13:17:03
    
    my ($date, $time) = split(" ", $dhcptime, 2);
    my ($year, $month, $day) = split(/\//, $date);
    my ($hour, $minute, $second) = split(/\:/, $time);

    my $unixtime = timegm($second, $minute, $hour, $day, $month-1, $year);
    return $unixtime;
}

1;
