#
#
# Revision 1.29  2004/07/15 16:12:06  vitroth
# Remove escaping backslashes from the zone dig results, since Net::DNS expects
# to add those itself.
#
# We should switch to using Net::DNS to do the AXFR, instead of calling dig.
#
# Revision 1.28  2004/07/13 18:39:25  vitroth
# dns.pl & related modules should send ddns updates to the servers that netreg
# say are authoritative, instead of resolving an SOA.  The SOA lookup is still
# done if netreg didn't have an entry.  And if the SOA lookup returns nothing
# the update should be aborted, instead of letting Net::DNS::Resolver pick
# a server to send it to, which doesn't work at all.  We were sending updates
# to web5.andrew.cmu.edu, because N:D:R was looking up an A record for the
# andrew.cmu.edu (presumably because its the default zone in resolv.conf) and
# sending to that.
#
# Revision 1.27  2004/07/08 18:51:05  vitroth
# production code should not refer to developer's sandboxes
#
# Revision 1.26  2003/11/29 23:07:19  kevinm
# * Uppercase the host portions of rdata for CNAME, MX, SRV, NS, PTR records
#
# Revision 1.25  2003/11/18 02:49:40  kevinm
# * Backwards log messages
#
# Revision 1.24  2003/08/01 05:34:08  kevinm
# * Changed for SNMP to work; reduced logging
#
# Revision 1.23  2002/08/09 03:45:08  kevinm
# * Changes to deal with TTL changes
#
# Revision 1.22  2002/08/05 15:07:27  kevinm
# * Changes for more debugging output...
#
# Revision 1.21  2002/06/04 20:15:48  kevinm
# * Fixed problems deleting PTR records --> canonicalization problem (doh.)
#
# Revision 1.20  2002/05/10 15:05:41  kevinm
# * Fixes for the LBPool (call Set_DefZone to get the right zone updated)
#
# Revision 1.19  2002/05/06 19:41:02  kevinm
# * Fix to deal with deletion of old-style TXT records
#
# Revision 1.18  2002/05/06 19:18:19  kevinm
# * Changes to use the Perl DNS Update stuff
#
# Revision 1.17  2002/04/08 01:53:23  kevinm
# * Fix LB stuff. This now all works AFAIK
#
# Revision 1.16  2002/04/05 04:11:51  kevinm
# * Lots of fixes for getting LB stuff in order.
#
# Revision 1.15  2002/03/11 04:10:43  kevinm
# * Added AFSDB support
#
# Revision 1.14  2002/01/10 22:42:06  kevinm
# Fix while generating TXT records: make 'em like dig!
#
# Revision 1.13  2002/01/10 22:27:03  kevinm
# Added return text of NSUpdate update statement
#
# Revision 1.12  2002/01/06 04:41:04  kevinm
# More debugging for C-C errors.
#
# Revision 1.11  2001/12/20 19:14:02  kevinm
# Final round of changes for today (hopefully) to fix DDNS update issues
#
# Revision 1.10  2001/12/20 18:54:23  kevinm
# More changes to update expect
#
# Revision 1.9  2001/12/20 18:53:39  kevinm
# Added quotations to TXT records.
#
# Revision 1.8  2001/12/20 16:33:05  kevinm
# Fixed NSUpdates
#
# Revision 1.7  2001/12/12 20:04:27  kevinm
# Changes to CNAME/NS TXT record bindings.
#
# Revision 1.6  2001/12/12 19:10:49  kevinm
# Removing stale stuff, adding KMemLB functions
#
# Revision 1.5  2001/12/06 18:21:52  kevinm
# Committing just so that I have a log of code that I'm going to remove.
#
# Revision 1.4  2001/11/29 06:37:37  kevinm
# Fixed the dottify stuff
#
# Revision 1.3  2001/11/05 21:13:41  kevinm
# Latest round of DDNS stuff.
#
# Revision 1.2  2001/10/31 02:00:37  kevinm
# Updates; going to have this run statics with TXT records
#
# Revision 1.1  2001/10/29 16:41:59  kevinm
# Initial DNS checkin
#
#
#

package DNS::ZoneParse;

require 5.005_03;
use vars qw($VERSION @ISA @EXPORT);
use strict;
use Carp;

use IPC::Open3;
use IO::Select;
use IO::File;

use Expect;
use IO::Stty;

use Net::DNS;
use Net::DNS::Update;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw/NSUpdate Set_Debug Set_DefZone Set_DefTTL Clear_Zone Get_Zone Get_DefZone/;
$VERSION = '0.36C';

my $Ns_Update_Cmd = '/usr/bin/nsupdate';

sub new {
  my $self = {};
  bless $self;
  $self->{Zone} = {};
  $self->{Debug} = 0;
  $self->{DefZone} = '.'; ## DefZone should ALWAYS contain a trailing dot
  $self->{DefTTL} = 86400;
  $self->{CanonFunc} = sub { return uc($_[0]); }; 
#  print STDERR "ZoneParse: Using module ".__FILE__."\n";
  return $self;
}

## Sets the debugging level. 0 is no debugging.
sub Set_Debug   { $_[0]->{Debug} = int($_[1]); }
sub Set_DefZone { $_[0]->{DefZone} = $_[1]."."; $_[0]->{DefZone} =~ s/\.{2,}$/\./; }
sub Set_DefTTL  { $_[0]->{DefTTL} = int($_[1]); }
sub Set_CanonFunc { $_[0]->{CanonFunc} = $_[1]; }
sub Clear_Zone  { delete $_[0]->{Zone}; $_[0]->{Zone} = {}; }
sub Get_Zone    { $_[0]->{Zone}; }
sub Get_DefZone { $_[0]->{DefZone}; }

## This is a generic frontend to setting up the default zone and TTL, as well 
## as loading a zone.
## Arguments:
##  - zonefile: either a reference to a SCALAR containing the zone file, or
##       the zone filename, or a string "dig:zone@server", replacing "zone" and "server"
##  - DefZone: the default zone to use in parsing (overridden by $ORIGIN directives)
##  - DefTTL: the default TTL of the zone (overridden by "$TTL" zf directives)
## Returns:
##   0 on error
##   1 on success
sub Prepare {
  my ($self, $zonefile, $DefZone, $DefTTL) = @_;
  
  $self->{Zone} = {};
  $self->Set_DefZone($DefZone);
  $self->Set_DefTTL($DefTTL);
  
  if(ref($zonefile) eq "SCALAR") {
    $self->{ZoneFile} = $$zonefile;
    _parse($self);
  }else{
    if ($zonefile =~ /^dig:([^\@]+)\@(.+)/) {
      $self->{ZoneFile} = _dig($1, $2);
#      $self->Set_Debug(5);
      _parse($self);
    }else{
      print "opening $zonefile\n";
      if (open(INZONE, "$zonefile")) {
	 while (<INZONE>) { $self->{ZoneFile} .= $_ }
	 close(INZONE);
	 _parse($self);
       } else {
	 print STDERR "DNS::ParseZone Could not open input file: \"$zonefile\" $!\n";
	 return 0;
       }
    }
  }
  return 1;
}

## Valid lines can be
#$rname $TTL $class $type $rdata    # Class 2
#$rname $class $type $rdata         # Class 1
#       $TTL $class $type $rdata    # Class 1
#       $class $type $rdata         # Class 0

## ******************************************************************************************
## _parse
## Parses the $self->{ZoneFile} data into RRs
sub _parse {
  my ($self) = @_;
  
  my $LastRName;

  my $Zone = $self->{DefZone};
  
  my $ValidClasses = qr/in|hs|ch/i;
  my ($RName, $TTL, $Class, $Type, $RData);
  $self->{RRs} = [];
  _clean_records($self);
  
  foreach my $RR (@{$self->{RRs}}) {
    print "Parsing $RR\n" if ($self->{Debug} >= 65);
    next if ($RR =~ /^(\#|\;)/ || $RR eq '');

    ($RName, $TTL, $Class, $Type, $RData) = ('', '', '', '', '');
    my @elem = split(/\s+/, $RR);
    while($elem[0] eq '') { shift(@elem); }
    
    # Take care of special directives
    if ($elem[0] eq '$TTL') {
      $self->Set_DefTTL($elem[1]);
      next;
    }elsif($elem[0] eq '$ORIGIN') {
      $Zone = $elem[1];
      $Zone .= '.' unless ($Zone =~ /\.$/);
      next;
    }
    
    # Find the class, and from there, find the rest of the fields
    # Start with elem[2] because we could have degenerate cases
    # that starting from the left would be wrong
    if ($elem[2] =~ /^$ValidClasses$/) {
      $RName = shift(@elem);
      $TTL = shift(@elem);
      $Class = shift(@elem);
      $Type = shift(@elem);
      $RData = join(" ", @elem);
      $LastRName = $RName;
    }elsif($elem[1] =~ /^$ValidClasses$/) {
      ## RName is first if no whitespace or it doesn't match a TTL
      if ($RR !~ /^\s+/ || $elem[0] !~ /^\d+[YMWDH]$/) {
	$RName = shift(@elem);
	$TTL = $self->{DefTTL};
	$Class = shift(@elem);
	$Type = shift(@elem);
	$RData = join(" ", @elem);
	$LastRName = $RName;
      }else{
	$RName = $LastRName;
	$TTL = shift(@elem);
	$Class = shift(@elem);
	$Type = shift(@elem);
	$RData = join(" ", @elem);
      }
    }elsif($elem[0] =~ /^$ValidClasses$/) {
      $RName = $LastRName;
      $TTL = $self->{DefTTL};
      $Class = shift(@elem);
      $Type = shift(@elem);
      $RData = join(" ", @elem);
    }
    

    $RData = $self->_parse_rdata($RData, $Type, $Zone);
    $self->Add_RR($RName, $TTL, $Class, $Type, $RData);
    print "Parsed: $RR\n[RN: $RName; TTL: $TTL; Class: $Class; Type: $Type: RD: $RData\n\n" 
      if ($self->{Debug} > 50);
  }
}

## _parse_rdata
## Parses the RData (right side of an RR) and returns it canonicalized - ie, add
## the default zone to names that have been shortened.
## Arguments:
##  - $RData: the RData to parse
##  - $Type: the type of RR (ie IN, MX)
##  - $Zone: the name of the current domain
## Returns:
##  - Properly formatted RData
sub _parse_rdata {
  my ($self, $RData, $Type, $Zone) = @_;

  $RData =~ s/^\s+//;
  $RData =~ s/\s+$//;
  $RData =~ tr/\(\)\n//d;

  if ($Type eq 'MX' || $Type eq 'AFSDB') {
    my @rec = split(/\s+/, $RData);
    $rec[1] = $self->_zp_vcan_dot($self->{CanonFunc}->($rec[1]), 'dot', $Zone);
    return join(' ', @rec);

  } elsif($Type eq 'CNAME' || $Type eq 'PTR') {
    if ($RData =~ /\s+/) {
      print "Error parsing rdata [$RData] for [type $Type] (contains spaces!)\n";
    }
    return $RData if ($RData =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);
    return $self->_zp_vcan_dot($self->{CanonFunc}->($RData), 'dot', $Zone);

  } elsif($Type eq 'NS') {
    if ($RData =~ /\s+/) {
      print "Error parsing rdata [$RData] for [type $Type] (contains spaces!)\n";
    }
    return $self->_zp_vcan_dot($self->{CanonFunc}->($RData), 'dot', $Zone);
    
  } elsif($Type eq 'SRV') {
    my @rec = split(/\s+/, $RData);
    $rec[3] = $self->_zp_vcan_dot($self->{CanonFunc}->($rec[3]), 'dot', $Zone);
    return join(' ', @rec);

  }elsif($Type eq 'TXT' ) {
    # Just remove extraneous space, and kill the quotes...
    my @RD = split(/\"/, $RData);
    @RD = grep { !/^\s*$/ } @RD;
    $RData = join(' ', @RD);
    return $RData;
  }elsif ($Type eq 'HINFO' || $Type eq 'RP') {
    # Net::DNS wants HINFO to contain exactly two quoted elements
    # It's already quoted coming in..
    return $self->{CanonFunc}->($RData);
  }else{
    return $RData;
  }
}
  
sub _clean_records {
  my ($self) = @_;
  
  my $zone = $self->{ZoneFile};
  print "_clean_records: Cleaning zone\n$zone\n" if ($self->{Debug} >= 100);
  $zone =~ s/\;.{0,}$//mg;        # Remove comments
  $zone =~ s/^\s*?$//mg;          # Remove empty lines
  $zone =~ s#$/{2,}#$/#g;         # Remove double carriage returns
  # Remove escaping backslashes from zone, since dig added them,
  # but Net::DNS expects to add them too.  FIXME.  We should
  # convert to doing AXFR via Net::DNS, and then remove this
  # line.
  $zone =~ s/\G([^\\]*?)\\(.)/\1\2/g;

  print "_clean_records: Cleaned zone:\n$zone\n" if ($self->{Debug} >= 100);
  # Concatenate everything split over multiple lines i.e. elements 
  # surrounded by parentheses can be
  # split over multiple lines. See RFC 1035 section 5.1
  $zone=~ s{(\([^\)]*?\))}{_concatenate( $1)}egs;
  
  @{$self->{RRs}} = split (m#$/#, $zone);
  foreach (@{$self->{RRs}}) { s/\s+/\t/g; }
			   
  return 1;
}

sub _concatenate {
  my ($TextInParen) = @_;
  $TextInParen =~ s{$/}{}g;
  return $TextInParen;
}

## **************************************************************************

## UpdatePrint
## Updater: reference to a Net::DNS::Updater structure
## AddDel: 'add' or 'del'
sub UpdatePrint {
  my ($self, $Updater, $AddDel, $Count) = @_;

  my $SaveDefZone = $self->{DefZone};
  $self->Set_DefZone('.');

  my ($rec, $last) == ('', '');
  my $rentry;
  foreach my $RName (sort {$a cmp $b} keys %{$self->{Zone}}) {
    while($Count && ($rentry = shift(@{$self->{Zone}->{$RName}}))) {
      $Count--;
      ($rec, $last) = _make_RR($self, $RName, $rentry->{ttl}, $rentry->{class},
			       $rentry->{type}, $rentry->{rdata}, '');
      if ($AddDel eq 'del') {
	if ($rentry->{type} eq 'TXT') {
         print "ZONE_SEND: Quoting $rec\n" if ($self->{Debug} > 12);
         $rec =~ s/(\s+IN\s+TXT)\s.+$/$1/;
         print "ZONE_SEND: Quoted $rec\n" if ($self->{Debug} > 12);
	}
	print __FILE__ .'::'. __LINE__, .": ZONE_SEND update del $rec for ".join('::',caller())."\n" if ($self->{Debug} > 12);
	$Updater->push("update", rr_del($rec));
        print __FILE__ .'::'. __LINE__, .": ZONE_SEND complete\n" if ($self->{Debug} > 12);
      }else{
        if ($rentry->{type} eq 'TXT') {
         print "ZONE_SEND: Quoting $rec\n" if ($self->{Debug} > 12);
         $rec =~ s/(\s+IN\s+TXT)\s(.+\s+.+)$/$1 "$2"/;
         print "ZONE_SEND: Quoted $rec\n" if ($self->{Debug} > 12);
        }
        print __FILE__ .'::'. __LINE__, .": ZONE_SEND update add $rec for ".join('::',caller())."\n" if ($self->{Debug} > 12);
	$Updater->push("update", rr_add($rec));
        print __FILE__ .'::'. __LINE__, .": ZONE_SEND complete\n" if ($self->{Debug} > 12);
      }
    }
  }
  $self->Set_DefZone($SaveDefZone);

  return $Count;
}

## PrintZone
## This will print the zone file for the default zone
## Arguments:
##  - partialZone: setting to '1' will turn off zonefile optimizations [for nsupdate]
## Returns:
##  - $self->{ZoneFile}, which HAS BEEN MODIFIED! 
sub PrintZone {
  my ($self, $partialZone) = @_;

  ## If partialZone is set, we're going to temporarily move DefZone out of the way,
  ## since otherwise it will filter the defzone name in printing the RNames
  my $SaveDefZone = $self->{DefZone};
  $self->Set_DefZone('.') if ($partialZone);

  my ($rec, $tZoneFile) = ('', '');
  $tZoneFile .= ";
;  DNS Zone File [$self->{DefZone}]
;
\$ORIGIN $self->{DefZone}
\$TTL $self->{DefTTL}\n" unless ($partialZone);
  
  ## Print items with rname == zone name first, specifically print the SOA first.
  my $Stage = 0;
  my $LastRName = '';
  map {
    if ($_->{type} eq 'SOA') {
      ($rec, $LastRName) = _make_RR($self, $self->{DefZone}, $_->{ttl}, $_->{class}, 
				    $_->{type}, $_->{rdata}, $LastRName);
      $tZoneFile .= $rec;
      $Stage++;
      $LastRName = '' if ($partialZone == 1);
    }
  } @{$self->{Zone}->{$self->{DefZone}}};
  
  if ($Stage == 0 && $partialZone != 1) {
    print STDERR "Unable to write zone record: no SOA for zone $self->{DefZone} found!\n";
    return;
  }
  
  map {
    if ($_->{type} ne 'SOA') {
      ($rec, $LastRName) = _make_RR($self, $self->{DefZone}, $_->{ttl}, $_->{class}, 
				    $_->{type}, $_->{rdata}, $LastRName);
      $tZoneFile .= $rec;
      $Stage = 2;
      $LastRName = '' if ($partialZone == 1);
    }
  } @{$self->{Zone}->{$self->{DefZone}}};
  
  $tZoneFile .= ";\n; Regular zone RRs\n;\n";

  ## Print out the rest of the RRs in alpha order
  foreach my $RName (sort {$a cmp $b} keys %{$self->{Zone}}) {
    next if ($RName eq $self->{DefZone});
 
    map {
      ($rec, $LastRName) = _make_RR($self, $RName, $_->{ttl}, $_->{class}, $_->{type}, 
				    $_->{rdata}, $LastRName);
      $tZoneFile .= $rec;
      $LastRName = '' if ($partialZone == 1);
    } @{$self->{Zone}->{$RName}};
  }

  $self->{ZoneFile} = $tZoneFile;
  $self->Set_DefZone($SaveDefZone);
  return $self->{ZoneFile};
}

## _make_RR
## This formats an RR for addition to the zone (called by PrintZone)
## Arguments:
##  - RName: Resource Record [RR] name
##  - TTL: Time-To-Live value for this RR
##  - Class: Class of RR (most commonly 'IN')
##  - Type: Type of RR (ie A, CNAME, PTR, MX, NS, etc.)
##  - RData: The record data (formatted for the particular type)
##  - LastName: The last RName printed; for optimization purposes
sub _make_RR {
  my ($self, $RName, $TTL, $Class, $Type, $RData, $LastName) = @_;

  $RName = $self->_zp_vcan_dot($RName, 'nodot', 'default');
  $RName = '@' if ($RName eq '');
 
  $RName = '' if ($RName eq $LastName && $LastName ne '');
  
  my ($spacing, $spaceTxt) = (2-(int(length($RName)/8)), '');
  for(0..$spacing) { $spaceTxt .= "\t"; }

  my $RR = "$RName\t$spaceTxt$TTL $Class $Type\t$RData\n";
#  if ($Type eq 'TXT' && $Class eq 'IN') {
#    my @RDA = split(/\s+/, $RData);
#    $RR .= '"'.join('" "', @RDA)."\"\n";
#  }else{
#    $RR .= "$RData\n";
#  }
  print "Generated RR: $RR for ".join('::',caller())."\n" if ($self->{Debug} >= 5);
  
  return ($RR, $LastName) if ($RName eq '');
  return ($RR, $RName); # LastName was different
}

## ******************************************************************************************

## NSUpdate
## Causes an NSUpdate to be performed
##   We assume that the current zonefile contains items that should be added to the
##   zone (duplicates get squished anyway)
## 
## Arguments:
##  - $DelZ: Reference to a common-format zone of RRs that should be deleted
##  - $KeyName: The name of the authentication key to use (empty for IP based auth)
##  - $Key: The actual key contents
##       A special format of "file=<filename>" will specify a filename that contains the key
sub NSUpdate {
  my ($self, $DelZ, $KeyName, $Key, $Masters) = @_;

  my $CorrectText = '';
  my @Cres;

  ## Use the new Net::DNS::Update stuff
  
  my $Result;
  do {
    my $Updater = Net::DNS::Update->new($self->Get_DefZone());
    
    $Result = _ddns_update_statements($self, $self->Get_Zone(), 
					 $DelZ, $Updater);
    return (-3, "Error generating DDNS Update statements") 
      if ($Result == 0);

    # If there are no entries in the update (aka authority) section, then
    # just return
    my @UpdateRecs = $Updater->authority;
    return (1, '') if ($#UpdateRecs == -1);
    
    my $tsig = Net::DNS::RR->new("$KeyName TSIG $Key");
    $tsig->fudge(60);
    
    $Updater->push("additional", $tsig);
    
    # Find the master
    my $DNSMaster;
    my $zonekey = $self->Get_DefZone();
    $zonekey =~ s/\.$//;
    if (defined $Masters && ref $Masters eq 'HASH'
	&& exists $Masters->{$zonekey}
	&& defined $Masters->{$zonekey}) {
      print "NSUpdate: Setting nameserver for ".$zonekey." to ".$Masters->{$zonekey}."\n" if ($self->{Debug} >= 12);
      $DNSMaster = $Masters->{$zonekey};
    } else {
      print "NSUpdate: Calling find_master to get nameserver for ".$zonekey."\n" if ($self->{Debug} >= 12);
      $DNSMaster = $self->find_master($self->Get_DefZone());
      return (-2, "Update failed: No master nameserver found for ".$zonekey) if (!$DNSMaster);
    }

    my $res = Net::DNS::Resolver->new;
    $res->nameservers($DNSMaster);
    my $reply;
    undef $reply;
    print "NSUpdate sending update for ".$self->Get_DefZone()." to: ".join(', ', $res->nameservers()).".\n" if ($self->{Debug} >= 12);
    print "NSUpdate update contents: ".$Updater->string if ($self->{Debug} >= 12);
    $reply = $res->send($Updater);
    print "NSUpdate update complete\n" if ($self->{Debug} >= 12);
    
    if (defined $reply) {
      if ($reply->header->rcode eq 'NOERROR') {
	# Update succeded
        print "NSUpdate update successful\n" if ($self->{Debug} >= 12);
        $CorrectText .= "Update succeeded: \n\nData:".$Updater->string;
      }else{
        print "NSUpdate update failed".$reply->header->rcode."\n" if ($self->{Debug} >= 12);
        return (-1, "Update failed: ".$reply->header->rcode."\n\nData:".
  	 	$Updater->string);
      }
    }else{
      return (-2, "Update failed: ".$res->errorstring."\n\nData:".$Updater->string);
    }
  } while ($Result == 2);
  
  return (1, $CorrectText);
}

# Returns: 
#  - 0 on failure
#  - 1 on success
#  - 2 on success but need another round

sub _ddns_update_statements {
  my ($self, $AddZ, $DelZ, $Updater) = @_;
  warn __FILE__ . ":" . __LINE__ . ": Entering _ddns_update_statements ...\n" if ($self->{Debug} >= 9);
  warn __FILE__ . ":" . __LINE__ . ": Caller is " . join ('::', caller()) . "\n" if ($self->{Debug} >= 9);

  my $Result = 1;
  my $Count = 30;

  ## Copy the zone aside for now
  my $SaveZone = $self->{Zone};

  $self->{Zone} = $DelZ;
 
  # map out the TTLs on the deletion side
  foreach my $Rec (keys %{$self->{Zone}}) {
    foreach my $id (@{$self->{Zone}->{$Rec}}) {
      $id->{ttl} = '';
    }
  }

  my $res = $self->UpdatePrint($Updater, 'del', $Count);
  return 0 if ($res < 0);
  if ($res == 0) {
    $Result = 2;
    goto DUS_OUT;
  }

  $self->{Zone} = $AddZ;

  $res = $self->UpdatePrint($Updater, 'add', $Count);
  return 0 if ($res < 0);
  $Result = 2 if ($res == 0);

 DUS_OUT:
  $self->{Zone} = $SaveZone;

  return $Result;
}
## ******************************************************************************************

## Add_RR
## Add an RR to the in-memory zone
## Arguments:
##   - $RName: Name of the Resource Record
##   - $TTL: Time-To-Live of the record
##   - $Class: The class of record (most commonly 'IN')
##   - $Type: The type of record (ie A, MX, NS, CNAME, etc.)
##   - $RData: Everything on the right side of the type (ie IP address, MX info, etc.)
## Returns:
##  0 on failure
##  1 on success
##  2 on success/already exists
sub Add_RR {
  my ($self, $RName, $TTL, $Class, $Type, $RData) = @_;

  $RName = $self->{CanonFunc}->($RName);

  my $FullRName = $self->_zp_vcan_dot($RName, 'dot', 'default') unless ($RName eq '@');
  $FullRName = $self->{DefZone} if ($RName eq '@');
  
  foreach my $RN (@{$self->{Zone}->{$FullRName}}) {
    return 2 if ($RN->{ttl} eq $TTL &&
		 $RN->{class} eq $Class,
		 $RN->{type} eq $Type,
		 $RN->{rdata} eq $RData);
  }
  
  # Canonicalize the rdata portion of PTR, NS, and CNAME records
  $RData = $self->{CanonFunc}->($RData) 
      if ($Class eq 'IN' && 
	  ($Type eq 'PTR' || $Type eq 'CNAME' || $Type eq 'NS'));
  
  push(@{$self->{Zone}->{$FullRName}}, { ttl => $TTL,
					 class => $Class,
					 type => $Type,
					 rdata => $RData});
  return 1;
}

## _zp_vcan_dot
## Verify Canonical Dot
## Basically, verify there is (or is NOT) a trailing dot on the name.
## Optionally tack on the default zone, a zone of your choosing, or just a dot.
## Arguments:
##  - Name: The name to perform the operation on
##  - VDot: Verify the dot or not? ('dot' or 'nodot', default 'dot')
##  - Zone: Specify the zone to tack on (or remove, in the case of VDot), 
##           or none, or 'default' for the default zone..
## Returns:
##  - The fixed up hostname

sub _zp_vcan_dot {
  my ($self, $Name, $VDot, $Zone) = @_;

  print "ZP_VCAN: $Name $VDot, $Zone ($self->{DefZone})\n" if ($self->{Debug} >= 65);
  # Eliminate multiple dots at the end..
  $Name =~ s/\.{2,}$/\./;

  $Zone = $self->{DefZone} if ($Zone eq 'default');

  if ($Name =~ /\.$/) {
    if ($VDot eq 'nodot') {
      $Name =~ s/\.?\Q$Zone\E\.?$//;
    }else{
#      $Name .= "$Zone" unless ($Name =~ /\Q$Zone\E\.?$/);
    }
  }else{
    if ($VDot eq 'nodot') {
      $Name =~ s/\.?\Q$Zone\E$//;
    }else{
      $Name .= ".$Zone" unless ($Name =~ /\Q$Zone\E$/);
      $Name .= ".";
    }
  }
  $Name =~ s/\.{2,}$/\./;
  print "\tZP: ret $Name\n" if ($self->{Debug} >= 65);
  return $Name;
}

## Execute a dig on the specified zone
sub _dig {
  my ($zone, $ns) = @_;
  my $res = '';
  open(PROC, "/usr/bin/dig axfr $zone \@$ns|");
  while(<PROC>) {
    $res .= $_;
  }
  close(PROC);
  return $res;
}

## Given a zone, find the zone master based on the MNAME field of the SOA
sub find_master {
  my ($self, $Zone) = @_;
  my $Res = Net::DNS::Resolver->new;
  my $packet = $Res->search($Zone, "SOA");
  if (!defined $packet) {
    print "find_master: No response to SOA query for $Zone, returning undef.\n" if ($self->{Debug} >= 12);
    return undef;
  }

  my @RRs = $packet->answer();
  foreach my $R (@RRs) {
    if ($R->type() eq 'SOA') {
      print "find_master: Returning ".$R->mname." for $Zone\n" if ($self->{Debug} >= 12);
      return $R->mname;
    }
  }
  print "find_master: No SOA for for $Zone, returning empty string.\n" if ($self->{Debug} >= 12);
  return '';
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 8
# perl-indent-level: 2
# cperl-indent-level: 2
# End:

__END__

