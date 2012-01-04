#!/usr/bin/perl
#
# Generate DNS Configuration Files for BIND 4,8,9 servers
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
# $Id: dns-config.pl,v 1.42 2008/03/27 19:42:41 vitroth Exp $


use strict;
use Fcntl ':flock';

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;

use CMU::Netdb;
use CMU::Netdb::config;
use Data::Dumper;

my $DBUSER = "netreg";
my $debug = 0;

my ($SERVICES, $CONFDIR, $vres);

($vres, $SERVICES) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'SERVICE_COPY');
($vres, $CONFDIR) = CMU::Netdb::config::get_multi_conf_var
  ('netdb', 'DNS_CONFPATH');

if ($ARGV[0] eq '-debug') {
  print "** Debug Mode Enabled**\n";
  $debug = 1;
  $SERVICES = '/tmp/services.sif';
  $CONFDIR = '/tmp/zones';
}

# Before we begin, delete all named.conf's from the confdir
unlink <$CONFDIR/named.conf*>;
unlink <$CONFDIR/dhcpd.conf.nsaux>;

## The completely new DNS Config Generation

my %KeyLoaded;
## Config will be:
## Associative array of Server Hostname (all lower-case) to:
##  - associative array of view name to view contents
##    _default_ will be the "global" view (ie, not in a view() statement)
##   View Contents is simply the contents of the view block

## Load the config from the services file
my ($rServerGroup, $rServerView, $rServerAuth, $rMachines, $rZones) = 
  load_services($SERVICES);

if ($debug) {
  print Dumper($rServerGroup);
  print Dumper($rServerView);
  print Dumper($rServerAuth);
}

write_config($rServerGroup, $rServerView, $rServerAuth, $rMachines, $rZones);

sub write_config {
  my ($rServerGroup, $rServerView, $rServerAuth, $rMachines, $rZones) = @_;

  ## We need to get a list of all the nameservers that we're
  ## generating configurations for
  
  my $ExtraDHCP;
  my %Servers;
  
  map {
    my $SG = $_;
    map { 
      push(@{$Servers{$_}}, $SG)
	if ($rServerGroup->{$SG}->{'machines'}->{$_}->{'type'} ne 'none');
    } keys %{$rServerGroup->{$SG}->{'machines'}};
  } keys %$rServerGroup;
  
  foreach my $HN (keys %Servers) {
    print "\n\nGenerating config for $HN:\n" if ($debug);
    
    # General plan for writing: find any _default_ options matching
    # the output format (bind4/bind8/bind9) 
    # 2) Look for view definitions (only bind9)
    # 3) Write zone definitions (with keys)
    
    my %ActiveViews;
    my ($ServerType, $ServerVersion) = ('', '');

    foreach my $SG (@{$Servers{$HN}}) {
      die_msg("ServerType of $HN mismatch (noticed on Server Group $SG)") 
	if ($ServerVersion ne '' 
	    && $rServerGroup->{$SG}->{'machines'}->{$HN}->{'version'} ne '' 
	    && $ServerVersion ne $rServerGroup->{$SG}->{'machines'}->{$HN}->{'version'});
      $ServerType = $rServerGroup->{$SG}->{'machines'}->{$HN}->{'type'};
      $ServerVersion = $rServerGroup->{$SG}->{'machines'}->{$HN}->{'version'} if ($rServerGroup->{$SG}->{'machines'}->{$HN}->{'version'});
      
      print "Server $HN in $SG is $rServerGroup->{$SG}->{'machines'}->{$HN}->{'type'}/$rServerGroup->{$SG}->{'machines'}->{$HN}->{'version'}\n" if ($debug);
      foreach my $View (keys %{$rServerGroup->{$SG}->{'views'}}) {
	if ($rServerGroup->{$SG}->{'machines'}->{$HN}->{'version'} eq $rServerView->{$View}->{'version'}) {
	  print "Adding service group $SG as active on view $View\n" if ($debug);
	  push(@{$ActiveViews{$View}}, $SG);
	}
      }
    }

    if ($ServerVersion eq '') {
      print "Skipping config generation for $HN, because the server version is not set.";
      next;
    }
    open(FILE, ">$CONFDIR/named.conf.$HN") ||
      die_msg("Cannot open $CONFDIR/named.conf.$HN for writing");

    ## ActiveViews now contains all views that this server will need to
    ## support (hash ref to the ServerGroups that use this view + server)

    my %RawOptions;    
    ## Go for _default_
    {
      my %DefOptions;
      my $nDO = 0;
      foreach my $SG (@{$Servers{$HN}}) {
	foreach my $AV (keys %ActiveViews) {
	  if ($rServerGroup->{$SG}->{'views'}->{$AV}->{'name'} 
	      eq '_default_') {
	    map { 
	      $DefOptions{$_} = 1;
	      } @{$rServerView->{$AV}->{'params'}};
            map {
              $RawOptions{$_} = 1;
            } @{$rServerView->{$AV}->{'raw_param'}};

	    $nDO++;
	  }
	}
      }
    
      if ($nDO != 0) {
	print FILE "options {\n";
	print FILE join("\n", map { "\t".$_.";" } 
			keys %DefOptions);
	print FILE "\n};\n\n";
      }
    }

    ## Print some boilerplate stuff for various servertypes
    if ($ServerVersion eq 'bind9') {
      print FILE "
include \"/etc/rndc.key\";

controls {
\tinet 127.0.0.1 allow { 127.0.0.1; } keys { rndckey; };
};\n

logging {
  channel \"xfer\" {
    file \"/usr/domain/var/xfer.log\" versions 4 size 250m;
    print-time yes;
    print-severity yes;
    print-category yes;
  };
  channel \"update\" {
    file \"/usr/domain/var/update.log\" versions 4 size 250m;
    print-time yes;
    print-severity yes;
  };
  channel \"queries\" {
    file \"/usr/domain/var/query.log\" versions 4 size 250m;
    print-time yes;
    print-severity yes;
  };
  category \"security\" { \"default_syslog\"; };
  category \"xfer-out\" { \"xfer\"; };
  category \"xfer-in\" { \"xfer\"; };
  category \"update\" { \"update\"; };
  category \"update-security\" { \"update\"; };
  category \"queries\" { \"queries\"; };
};

";
    }elsif($ServerVersion eq 'bind8') {
      print FILE "zone \".\" {
\ttype hint;
\tfile \"named.hints\";
};\n\n";
    }

    ## Construct the server blocks
    {
      my %ServerBlock;
      foreach my $SG (@{$Servers{$HN}}) {
	foreach my $lhn (keys %{$rServerGroup->{$SG}->{'server_blocks'}}) {
	  push(@{$ServerBlock{$lhn}}, 
	       @{$rServerGroup->{$SG}->{'server_blocks'}->{$lhn}});
	}
      }

      foreach my $lhn (sort {$a cmp $b} keys %ServerBlock) {
	my $lip = CMU::Netdb::long2dot($rMachines->{$lhn}->{ip_address});
	print FILE "server $lip {\n\t".join(";\n\t", @{$ServerBlock{$lhn}});
	print FILE ";\n};\n\n";
      }
    }
    
    my $FILE;
    ## First figure out the full set of views, the various view options,
    ## and the correct ordering
    my %ViewOrder;
    my %ViewContents;
    my %ViewMap;
    my $MaxOrder = -1;
    {
      foreach my $SG (@{$Servers{$HN}}) {
	foreach my $AV (keys %ActiveViews) {
	  next if ($rServerGroup->{$SG}->{'views'}->{$AV}->{'name'} eq '');
	  my $VName = $rServerGroup->{$SG}->{'views'}->{$AV}->{'name'};
	  my $VOrder = $rServerGroup->{$SG}->{'views'}->{$AV}->{'order'};
	  $ViewMap{$VName} = $AV;
	  $MaxOrder = $VOrder if ($VOrder > $MaxOrder);
	  print "Defining view $VName ($MaxOrder/$VOrder)\n" if ($debug);
	  if ($VName ne '_default_') {
	    push(@{$ViewOrder{$VOrder}}, $VName);
	    map {
	      $ViewContents{$VName}->{$_} = 1;
	    } @{$rServerView->{$AV}->{'params'}};
	  }
	}
      }
    }
    
    ## Define a default global view that includes
    ## all zones; allows all, etc.
    {
      $ViewOrder{$MaxOrder+1} = ['global'];
      $ViewContents{'global'}->{"match-clients { any; }"} = 1;
      $ViewContents{'global'}->{"recursion yes"} = 1;
      foreach my $k (keys %RawOptions) {
        $ViewContents{'global'}->{$k} = 1;
      }

    }
    
    ## Now that we have ViewOrder and ViewContents, print all the views
    ## while going through the server groups to find zones for this view

    print Data::Dumper->Dump([\%ViewOrder], ['View order']) if ($debug);
    foreach my $VOs (sort {$a <=> $b} keys %ViewOrder) { 
      foreach my $View (@{$ViewOrder{$VOs}}) {
	next if ($ServerVersion ne 'bind9' && $View ne 'global');
	
	my $Import = 'yes';
	print "Looking up $View in $ViewMap{$View}\n";
        $Import = $rServerView->{$ViewMap{$View}}->{'import'}
	  if (defined $ViewMap{$View} && 
	      defined $rServerView->{$ViewMap{$View}}->{'import'});
	
	# Print the view parameters, etc.
	if ($ServerVersion eq 'bind9') {
	  $FILE .= "view \"$View\" {\n";
	  $FILE .= join("\n",  map { "\t".$_.";" } 
			keys %{$ViewContents{$View}});
	  $FILE .= "\n\n";
	}

	# Print the zone contents
	foreach my $SG (@{$Servers{$HN}}) {
	  my @Masters;
	  my @Slaves;
   	  $ServerType = $rServerGroup->{$SG}->{'machines'}->{$HN}->{'type'};
	  next if ($rServerGroup->{$SG}->{'machines'}->{$HN}->{'version'} ne $ServerVersion);

	  # Find the masters and slaves
	  my ($Mach, $MInfo);
	  foreach my $Mach (keys %{$rServerGroup->{$SG}->{'machines'}}) {
	    my $MInfo = $rServerGroup->{$SG}->{'machines'}->{$Mach};
	    if ($MInfo->{'type'} eq 'master') {
	      push(@Masters, $Mach);
	    }elsif($MInfo->{'type'} eq 'slave') {
	      push(@Slaves, $Mach);
	    }
	  }

	  foreach my $Zone (sort {$a cmp $b} 
			    keys %{$rServerGroup->{$SG}->{'zones'}}) {
	    goto ZONE_PRINT
	      if ($ServerVersion ne 'bind9');

	    if ($Import ne 'yes') {
	      next 
		if (!defined 
		    $rServerGroup->{$SG}->{'zones'}->{$Zone}->{'views'} ||
		    $#{$rServerGroup->{$SG}->{'zones'}->{$Zone}->{'views'}}
                    == -1);
	    }
	    
	    goto ZONE_PRINT 
	      if (!defined
		  $rServerGroup->{$SG}->{'zones'}->{$Zone}->{'views'});
	    
	    goto ZONE_PRINT
	      if (
		  $#{$rServerGroup->{$SG}->{'zones'}->{$Zone}->{'views'}}
		  == -1);
	    
	    goto ZONE_PRINT
	      if (grep /^$View$/, 
		  @{$rServerGroup->{$SG}->{'zones'}->{$Zone}->{'views'}});
	    
	    next;

	  ZONE_PRINT: 
	    ## Figure out any keys / ACLs needed for this from DDNS_AUTH
	    my $ExtraZone;
	    if ($ServerType eq 'master') {
	      my $MasterIP = CMU::Netdb::long2dot($rMachines->{$HN}->{ip_address});

	      my $ExtraZoneAuth = find_zone_auth($Zone, $rServerAuth, $rMachines);
	      my ($ExtraDNS, $DHCPbits);
	      ($ExtraDNS, $ExtraZone, $DHCPbits) = 
		generate_ddns_keyacl($Zone, $View, $MasterIP, 
				     $rZones->{$Zone}->{'ddns_auth'},
				     $ExtraZoneAuth);
	      $ExtraDHCP .= $DHCPbits;
	      
	      # This needs to go directly into the file, because we want it
	      # to come before the views are actually printed.
	      print FILE join("\n", map {
		"$_";
	      } split(/\n/, $ExtraDNS))."\n\n" if ($ExtraDNS ne '');
	    }
	    
	    ## Print the actual zone
	    $FILE .= "\tzone \"$Zone\" {\n".
	      "\t\ttype $ServerType;\n";
	    
	    if ($ServerType ne 'forward') {
	      $FILE .= "\t\tfile \"$Zone.zone\";\n";
	    }
	    
	    if ($ServerType eq 'slave' || $ServerType eq 'stub') {
	      $FILE .= "\t\tmasters {".
		join(';', map {
		  CMU::Netdb::long2dot($rMachines->{$_}->{ip_address});
		} @Masters).";};\n";
	    }elsif($ServerType eq 'forward') {
	      my $FT = 'master';
	      $FT = $rServerGroup->{$SG}->{'forward_to'}
		if (defined $rServerGroup->{$SG}->{'forward_to'} ne '');

	      if ($FT eq 'master') {
		$FILE .= "\t\tforwarders {".
		  join(';', map {
		    CMU::Netdb::long2dot($rMachines->{$_}->{ip_address});
		  } @Masters).";};\n";
	      }elsif($FT eq 'slave') {
		$FILE .= "\t\tforwarders {".
		  join(';', map {
		    CMU::Netdb::long2dot($rMachines->{$_}->{ip_address});
		  } @Slaves).";};\n";
	      }elsif($FT eq 'both') {
		$FILE .= "\t\tforwarders {".
		  join(';', map {
		    CMU::Netdb::long2dot($rMachines->{$_}->{ip_address});
		  } @Masters, @Slaves).";};\n";
	      }
	    }

	    # Print the zone parameters
	    map {
	      $FILE .= "\t\t$_;\n";
	    } @{$rServerGroup->{$SG}->{'zones'}->{$Zone}->{'params'}};
	    
	    $FILE .= join("\n", map {
	      "\t\t$_"
	    } split(/\n/, $ExtraZone))."\n" if ($ExtraZone ne '');

	    $FILE .= "\t};\n\n";
	  }
	}

	$FILE .= "\n};\n\n" if ($ServerVersion eq 'bind9');
      }
    }
	
    print FILE $FILE;

    close(FILE);
  }  
  ## Write the DHCP bits
  open(FILE, ">$CONFDIR/dhcpd.conf.nsaux") ||
    die_msg("Cannot open $CONFDIR/dhcpd.conf.nsaux for writing");
  print FILE $ExtraDHCP;
  close(FILE);
}

exit(0);
## ***************************************************************************************
  
sub die_msg {
  &CMU::Netdb::netdb_mail('dns-config.pl', $_[0], 'dns-config died!');
  die $_[0];
}

## Go through the DDNS_Zone_Auth and figure out what IPs belong on this zone
sub find_zone_auth {
  my ($ZoneName, $rServerAuth, $rMachines) = @_;
  
  my @Machines;
  foreach my $SG (keys %$rServerAuth) {
    next unless (grep(/^$ZoneName$/i, keys %{$rServerAuth->{$SG}->{zones}}));
    foreach my $M (keys %{$rServerAuth->{$SG}->{machines}}) {
      push(@Machines, CMU::Netdb::long2dot($rMachines->{$M}->{ip_address}));
    }
  }
  return join(';', @Machines);
}

## Figure out what extra bits are needed for keys/ACLs for DDNS
sub generate_ddns_keyacl {
  my ($Zone, $View, $Master, $DDNS_Auth, $ZoneAuth) = @_;

  my ($ExtraDNS, $ExtraZone, $DHCPBits) = ('', '', '');
  my %AuthInfo;
  my @keys;
  
  my @dkey = split(/\s+/, $DDNS_Auth);
  map {
    my ($a, $b) = split(/\:/, $_);
    $AuthInfo{lc($a)} = $b;
  } @dkey;
 
  if (defined $AuthInfo{key}) {
    $ExtraDNS .= "key $Zone.key {\n\talgorithm hmac-md5;\n\t".
      "secret \"$AuthInfo{key}\";\n};\n\n"
	if (!defined $KeyLoaded{"$Zone.key"});
    push(@keys, "key $Zone.key");
    $KeyLoaded{"$Zone.key"} = 1;
  }
  
  foreach (grep {/^key\/\S+$/} keys %AuthInfo) {
    my $key = $AuthInfo{$_};
    $_ =~ /^key\/(\S+)$/;
    my $kname = $1;
    if ($kname eq 'key') {
      CMU::Netdb::netdb_mail('dns-config.pl', 
			     "Zone $Zone has DDNS_Auth Key named key/key ".
			     "-- this is not valid.\nKey is being ignored.");
      next;
    }
    $ExtraDNS .= "key $Zone.$kname {\n\talgorithm hmac-md5;\n\t".
      "secret \"$key\";\n};\n\n" if (!defined $KeyLoaded{"$Zone.$kname"});
    push(@keys, "key $Zone.$kname");
    if ($kname eq 'dhcp' && !defined $KeyLoaded{"$Zone.dhcp"}) {
      $DHCPBits .= "key $Zone.dhcp {\n\t".
	"algorithm HMAC-MD5.SIG-ALG.REG.INT;\n\t".
	  "secret $key;\n};\n\n".
	    "zone $Zone. {\n\tprimary $Master;\n\tkey $Zone.dhcp;".
	      "\n}\n\n";
    }
    $KeyLoaded{"$Zone.$kname"} = 1;
  }

  if (defined $AuthInfo{ip} || $ZoneAuth ne '') {
    $AuthInfo{ip} .= ';' if ($AuthInfo{ip} ne '');
    $ZoneAuth .= ';' if ($ZoneAuth ne '');

    $ExtraDNS .= "acl $Zone.acl { ".$AuthInfo{ip}.$ZoneAuth." };\n"
	if (!defined $KeyLoaded{"$Zone.acl"});
    push(@keys, "$Zone.acl");
    $KeyLoaded{"$Zone.acl"} = 1;
  }
  $ExtraZone = "allow-update {\n".
    "\t".join(";\n\t", @keys).";\n};\n" if ($#keys != -1);
  
  return ($ExtraDNS, $ExtraZone, $DHCPBits);
}
 

# Load the services.sif file. 
sub load_services {
  my ($File) = @_;

  # These are the returned structures
  my %ServerGroup;
  my %ServerView;
  my %ServerAuth;
  my %Machines;
  my %Zones;

  open(FILE, $File) || die_msg("Cannot open services file: $File\n");
  my ($depth, $loc, $SName, $SType,$MType,$MName) = (0,0,'','','','');
  %KeyLoaded = ();

  while(my $line = <FILE>) {
    if ($depth == 0) {

      ## Look for service definitions
      if ($line =~ /service\s+\"([^\"]+)\"\s+type\s+\"([^\"]+)\"\s*\{/) {
	($SName, $SType) = ($1, $2);
	$depth++;
	if ($SType eq 'DNS Server Group') {
	  $loc = 1;
	  $ServerGroup{$SName} = {};
	  print "Defined Group $SName\n";
	}elsif($SType eq 'DNS View Definition') {
	  $loc = 2;
	  $ServerView{$SName} = {};
	}elsif($SType eq 'DDNS_Zone_Auth') {
	  $loc = 20;
	  $ServerAuth{$SName} = {};
	}
	## Look for machine definitions
      }elsif($line =~ /machine\s+\"([^\"]+)\"\s*\{/) {
	$SName = $1;
	$depth++;
	$loc = 10;
	$SName = lc($SName);
	$Machines{$SName} = {};
	## Look for zone definitions
      }elsif($line =~ /dns_zone\s+\"([^\"]+)\"\s*\{/) {
	$SName = $1;
	$depth++;
	$loc = 15;
	$Zones{$SName} = {};
      }
    }elsif($depth == 1) {
      ## Look for attribute specifications
      if ($line =~ /attr\s*([^\=]+)\=\s*(.+)$/) {
	my ($AKey, $AVal) = ($1, $2);
	$AVal =~ s/\;$//;
	$AKey =~ s/\s*$//;
	
	if ($loc == 2 && $AKey eq 'Server Version') {
	  $ServerView{$SName}->{'version'} = $AVal;
	}elsif($loc == 2 && $AKey eq 'DNS Parameter') {
	  push(@{$ServerView{$SName}->{'params'}}, $AVal);
	}elsif($loc == 2 && $AKey eq 'Raw DNS Parameter') {
	  push(@{$ServerView{$SName}->{'raw_param'}}, $AVal);
	}elsif($loc == 2 && $AKey eq 'Import Unspecified Zones') {
	  $ServerView{$SName}->{'import'} = $AVal;
        }elsif($loc == 1 && $AKey eq 'Forward To') {
	  $ServerGroup{$SName}->{'forward_to'} = $AVal;
	}
	## Look for members of a service
      }elsif($line =~ /member\s*type\s*\"([^\"]*)\"\s*name\s*\"([^\"]*)\"/) {
	($MType, $MName) = ($1, $2);
	if ($MType eq '' || $MName eq '') {
	  CMU::Netdb::netdb_mail('dns-config.pl', 
				 "In service $SName, Type or Name of member ".
				 "is blank: ($MType), ($MName).");
	}
	  
	$depth++;
	
	if ($loc == 1 && $MType eq 'dns_zone') {
	  $ServerGroup{$SName}->{'zones'}->{$MName} = {};
	  $loc = 5;
	}elsif($loc == 1 && $MType eq 'service') {
	  $ServerGroup{$SName}->{'views'}->{$MName} = {};
	  $loc = 6;
	}elsif($loc == 1 && $MType eq 'machine') {
	  $MName = lc($MName);
	  $ServerGroup{$SName}->{'machines'}->{$MName} = {};
	  $loc = 7;
	}elsif($loc == 20 && $MType eq 'machine') {
	  $MName = lc($MName);
	  $ServerAuth{$SName}->{'machines'}->{$MName} = {};
	}elsif($loc == 20 && $MType eq 'dns_zone') {
	  $ServerAuth{$SName}->{'zones'}->{$MName} = {};
	}

      }elsif($loc == 10) {
	$line =~ s/\;$//;
	my @elem = split(/\s+/, $line);
	shift @elem while($elem[0] eq '');

	$Machines{$SName}->{$elem[0]} = $elem[1];
      }elsif($loc == 15) {
	$line =~ s/\;$//;
	my @elem = split(/\s+/, $line);
	shift @elem while($elem[0] eq '');
	my $Key = shift(@elem);
	my $Val = join(' ', @elem);

	$Zones{$SName}->{$Key} = $Val;
      }elsif($line =~ /\{/) {
	$depth++;
      }

      if ($line =~ /\}/ && $line !~ /\{/) {
	$depth--;
	$SName = '';
	$loc = 0;
      }
    }elsif($depth == 2) {
      if ($line =~ /attr\s*([^\=]+)\=\s*(.+)$/) {
	my ($AKey, $AVal) = ($1, $2);
	$AKey =~ s/\s*$//;
	$AVal =~ s/\;$//;
	$AVal =~ s/^\s+//;
	$AVal =~ s/\s+$//;

	if ($loc == 5 && $AKey eq 'Zone Parameter') {
	  push(@{$ServerGroup{$SName}->{'zones'}->{$MName}->{'params'}},
	       $AVal);
	}elsif($loc == 5 && $AKey eq 'Zone In View') {
	  print "pushing view $SName $MName $AVal\n";
	  push(@{$ServerGroup{$SName}->{'zones'}->{$MName}->{'views'}},
	       $AVal);
	}elsif($loc == 6 && $AKey eq 'Service View Name') {
	  $ServerGroup{$SName}->{'views'}->{$MName}->{'name'} = $AVal;
	}elsif($loc == 6 && $AKey eq 'Service View Order') {
	  $ServerGroup{$SName}->{'views'}->{$MName}->{'order'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Type') {
	  $ServerGroup{$SName}->{'machines'}->{$MName}->{'type'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Version') {
	  $ServerGroup{$SName}->{'machines'}->{$MName}->{'version'} = $AVal;
	}elsif($loc == 7 && $AKey eq 'Server Block Parameter') {
	  push(@{$ServerGroup{$SName}->{'server_blocks'}->{$MName}}, $AVal);
	}
      }

      if ($line =~ /\}/ && $line !~ /\{/) {
	$depth--;
	$loc = 1 if ($loc == 5 || $loc == 6 || $loc == 7);
	($MType, $MName) = ('', '');
      }
    }
  }
  close(FILE);

  return (\%ServerGroup, \%ServerView, \%ServerAuth, \%Machines, \%Zones);
}


