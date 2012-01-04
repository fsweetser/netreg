# -*- perl -*-
#
# DNS::NetRegZone
#   Tie DNS::ZoneFile to NetReg zone building
# 
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
# Kevin Miller <kcm@cmu.edu>
# 
# $Id: NetRegZone.pm,v 1.25 2008/03/27 19:42:40 vitroth Exp $
#
# Revision 1.24  2007/07/18 14:24:14  vitroth
# Added code to delete overlapping RR's, which can get created when a host
# is converted from dynamic to static and dhcpd doesn't remember to delete
# the old RR.  i.e. NetReg is asserting that it owns all values for any RR
# that it publishes.  This code is currently disabled, just loggign the
# potential changes for analysis.
#
# $Log: NetRegZone.pm,v $
# Revision 1.25  2008/03/27 19:42:40  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.24.4.1  2007/10/11 20:59:45  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.24.2.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.8  2005/08/14 03:59:10  kcmiller
# * Syncing with mainline
#
# Revision 1.7  2004/12/14 03:53:02  kcmiller
# * canonfunc for _DZ-
#
# Revision 1.6  2004/12/14 02:20:42  kcmiller
# * DNS canonicalization functions
#
# Revision 1.5  2004/12/03 22:58:47  kcmiller
# * match_rinfo accepts quotes
#
# Revision 1.4  2004/12/03 21:56:26  kcmiller
# * rinfo will validate if differences are just quoting
#
# Revision 1.3  2004/12/03 04:36:20  kcmiller
# * Replace ALL the quotes..
#
# Revision 1.2  2004/12/03 04:33:18  kcmiller
# * Eliminate quotes from TXT records
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.20  2004/07/13 18:39:25  vitroth
# dns.pl & related modules should send ddns updates to the servers that netreg
# say are authoritative, instead of resolving an SOA.  The SOA lookup is still
# done if netreg didn't have an entry.  And if the SOA lookup returns nothing
# the update should be aborted, instead of letting Net::DNS::Resolver pick
# a server to send it to, which doesn't work at all.  We were sending updates
# to web5.andrew.cmu.edu, because N:D:R was looking up an A record for the
# andrew.cmu.edu (presumably because its the default zone in resolv.conf) and
# sending to that.
#
# Revision 1.19  2002/09/30 19:06:08  kevinm
# * all TXT ttls will be 3600; tired of dealing with this
#
# Revision 1.18  2002/09/30 03:43:36  kevinm
# * Move many TXT records (CNAMEs) from the zone name itself to _DOT-ZONE
#
# Revision 1.17  2002/08/09 03:45:07  kevinm
# * Changes to deal with TTL changes
#
# Revision 1.16  2002/08/05 15:07:27  kevinm
# * Changes for more debugging output...
#
# Revision 1.15  2002/06/04 20:15:48  kevinm
# * Fixed problems deleting PTR records --> canonicalization problem (doh.)
#
# Revision 1.14  2002/06/04 15:47:43  kevinm
# * Added log message about source of dig
#
# Revision 1.13  2002/05/10 15:05:41  kevinm
# * Fixes for the LBPool (call Set_DefZone to get the right zone updated)
#
# Revision 1.12  2002/05/06 19:16:52  kevinm
# * Changes to use the Perl DNS Update library stuff
#
# Revision 1.11  2002/04/10 06:01:02  kevinm
# * Do not try and add a TXT record on the same level as a CNAME
#
# Revision 1.10  2002/02/23 06:13:51  kevinm
# Case insensitive RR comparison
#
# Revision 1.9  2002/01/11 05:24:18  kevinm
# Re-fixed actual CNAME addition
#
# Revision 1.8  2002/01/11 05:17:33  kevinm
# Fixed CNAME addition foo
#
# Revision 1.7  2001/12/12 20:10:34  kevinm
# Problem with the defzone setup
#
# Revision 1.6  2001/12/12 20:04:27  kevinm
# Changes to CNAME/NS TXT record bindings.
#
# Revision 1.5  2001/11/29 06:47:45  kevinm
# Removed exporting the key in the TXT records.
#
# Revision 1.4  2001/11/05 21:13:41  kevinm
# Latest round of DDNS stuff.
#
# Revision 1.3  2001/10/31 05:56:34  kevinm
# Removed TEST-NET debug code
#
# Revision 1.2  2001/10/31 02:00:36  kevinm
# Updates; going to have this run statics with TXT records
#
# Revision 1.1  2001/10/29 16:41:59  kevinm
# Initial DNS checkin
#
#

package DNS::NetRegZone;

require 5.005_03;
use vars qw($VERSION @ISA @EXPORT);
use strict;
use Carp;

use CMU::Netdb;
use Digest::MD5 qw/md5_base64/;
use IPC::Open3;
use IO::File;
use IO::Select;
use DNS::ZoneParse;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);
$VERSION = '0.36C';

my $TXT_REC_TTL = 3600;
@EXPORT = qw/new CheckAndAdd Debug Prepare DDNS_NSUpdate DDNS_Cons_TXT/;

sub new {
  my $self = {};
  bless $self;
  $self->{ZP} = new DNS::ZoneParse;
  $self->Set_Debug(0);
#  print STDERR "NetRegZone: Using module ".__FILE__."\n";
  return $self;
}

sub Set_CanonFunc {
    my ($self, $CF) = @_;
    $self->{CanonFunc} = $CF;
    $self->{ZP}->Set_CanonFunc($CF);
}

sub Prepare {
  my ($self, $key, $Roldkey) = @_;
  $self->{NewZone} = {};
  $self->{DelZone} = {};
  
  ## These are the TXT Auth Keys Only - NOT the DDNS Auth keys
  $self->{key} = $key;
  $self->{oldkeys} = $Roldkey;
  push(@{$self->{oldkeys}}, $key);
  ############################################################

  # FIXME : Remove SOA
}

sub Set_Zone { $_[0]->{Zone} = $_[1]; }

sub Set_Debug { $_[0]->{Debug} = int($_[1]); }

sub Set_Zone_Dig {
  my ($self, $ZoneName, $ZoneNS, $TTL) = @_;
  my $ZP = new DNS::ZoneParse;
  $self->{ZP}->Prepare("dig:$ZoneName\@$ZoneNS", $ZoneName, $TTL);
  $self->{Zone} = $self->{ZP}->Get_Zone();
  $self->{ZP}->Clear_Zone();
  if ($self->{Debug} >= 5) {
    print "Zone $ZoneName has been transferred from $ZoneNS.\nRNames: ";
    print join(', ', keys %{$self->{Zone}})."\n";
  }
}

## Given a record, check if we have a matching RR + TXT
## in the zone. If not, schedule an addition. If we do,
## delete it
sub CheckAndAdd {
  my ($self, $RR_Name, $RR_TTL, $RR_Class, $RR_Type, $R_Data, $NR_Type, $NR_ID) = @_;

  ($RR_Class, $RR_TTL) = (uc($RR_Class), uc($RR_TTL));

  print "CheckAndAdd: $RR_Name $RR_TTL $RR_Class $RR_Type $R_Data $NR_Type $NR_ID\n"
    if ($self->{Debug} >= 5);

  my ($MatchRR, $MatchTXT, $i) = (-1, -1, 0);
  my $newTXT = DDNS_Cons_TXT($self, $NR_Type, $RR_Class, 
			     $RR_Type, $R_Data, $NR_ID, $RR_Name);

  my ($TTL_Change_RR, $TTL_Change_TXT) = (0,0);

  my (%Overlapping_RR, %Overlapping_TXT);
  # Loop over existing entries in the zone, looking for a match for both the record
  # and the netreg TXT record
  foreach my $R (@{$self->{Zone}->{$RR_Name}}) {
    print "Comparing $R->{type}\n" if ($self->{Debug} >= 75);
    if ($R->{type} eq $RR_Type && $R->{class} eq $RR_Class) {
      # The name/type/class of this record matches the intended record, does the data?
      if (_ddns_match_rinfo($R->{rdata}, $R_Data)) {
	# Yes this record matches.  Does the TTL?
 	if ($R->{ttl} ne $RR_TTL) {
	  # TTL mismatch, fix it
  	print "$RR_Name NONTXT ($RR_Type); TTL_MISMATCH, currently $R->{ttl}, want $RR_TTL\n";
  	$TTL_Change_RR = 1;
 	}

	# Note that the record matched
 	$MatchRR = $i;
       } else {
	# Data didn't match netreg.  Should we delete?
	if ($RR_Type =~ /^(A|PTR)$/) {
	  print "$RR_Name found with non matching rdata:\n   Current: $R->{rdata}\n   New:$R_Data\n" ;
	  $Overlapping_RR{$i} = $R->{rdata};
	}
      }
    }elsif($R->{type} eq 'TXT' && $R->{rdata} eq $newTXT) {
      $TTL_Change_TXT = 1 if ($R->{ttl} ne $TXT_REC_TTL);
      $MatchTXT = $i;
    }elsif($R->{type} eq 'TXT') {
      print "$RR_Name TXT record found with non matching rdata: $R->{rdata} ne $newTXT\n" if ($self->{Debug} >= 12);
      if ($R->{rdata} =~ /_(IN_PTR|in_ptr|IN_A|in_a)_/) {
	$Overlapping_TXT{$i} = $R->{rdata};
      }
    }
    # need to find all mismatching records, must go through full list
    #last if ($MatchRR != -1 && $MatchTXT != -1);
    $i++;
  }

  if (keys(%Overlapping_RR) && ! keys(%Overlapping_TXT)) {
    # These are overlapping RR entries (A and PTR only for now) 
    # without any possible overlapping netreg TXT entry
    # We're going to delete them, asserting that NetReg owns all values of this RR
    # (Actual delete not yet enabled, just logging the changes for now.)
    foreach my $i (keys %Overlapping_RR) {
      my $rec = $self->{Zone}{$RR_Name}[$i];
      print "SKIPPING ZONE DELETION (Overlapping Entries): $RR_Name ($rec->{class}/$rec->{type}/$rec->{rdata})\n";# if ($self->{Debug} >= 5);
      #push(@{$self->{DelZone}->{$RR_Name}}, $rec);
    }
  }

  my $DefZone = $self->{ZP}->Get_DefZone();

  my $zName = $RR_Name;

  # If the record type is CNAME, or the record type is NS and we're working
  # in the parent zone, then the NS record is a delegation point and we have
  # to add the TXT to the parent 
  if ($RR_Class eq 'IN' && (
      $RR_Type eq 'CNAME' || $RR_Type eq 'NS')) {
    my @hn = split(/\./, $RR_Name);
    $zName = $self->{CanonFunc}->("_DZ-$hn[0].$DefZone");
    # Reset MatchTXT to -1. If we found one above, it's an ERROR and doesn't
    # actually match
    $MatchTXT = -1;
    $TTL_Change_TXT = 0;
    print "Set zname to $zName (from $RR_Name)\n" if ($self->{Debug} >= 12);
    $i = 0;
    if ($MatchRR != -1) {
      foreach my $R (@{$self->{Zone}->{$zName}}) {
        print "Comparing $R->{type} ($R->{rdata})\n" if ($self->{Debug} >= 12);
        if($R->{type} eq 'TXT' && $R->{rdata} eq $newTXT) {
  	  $MatchTXT = $i;
   	  if ($R->{ttl} ne $TXT_REC_TTL) {
  	    print "$RR_Name TXT ($zName); TTL_MISMATCH, currently $R->{ttl}, want $RR_TTL\n";
	    $TTL_Change_TXT = 1;
          }
	  last;
        }elsif($R->{type} eq 'TXT') {
	  print "$R->{rdata} ne $newTXT\n" if ($self->{Debug} >= 75);
        }
        $i++;
      }
    }
  }
  
  print "Matches: [$MatchRR $MatchTXT]\n" if ($self->{Debug} >= 10);
  ## We found a match on RR and TXT. Delete and return 1
  if ($MatchRR != -1 && $MatchTXT != -1) {
    print " $RR_Name $RR_Class $RR_Type ($MatchRR, $MatchTXT) matched. \n" 
      if ($self->{Debug} >= 50);
    # Have to be careful, otherwise we change the index when we delete the first...
    print " DELETING: ".$self->{Zone}->{$RR_Name}->[$MatchRR]->{rdata}." AND ".
      $self->{Zone}->{$zName}->[$MatchTXT]->{rdata}."\n" if ($self->{Debug} >= 50);
    if ($MatchRR > $MatchTXT) {
      splice(@{$self->{Zone}->{$RR_Name}}, $MatchRR, 1);
      splice(@{$self->{Zone}->{$zName}}, $MatchTXT, 1);
    }else{
      splice(@{$self->{Zone}->{$zName}}, $MatchTXT, 1);
      splice(@{$self->{Zone}->{$RR_Name}}, $MatchRR, 1);
    }

    # If the TTLs changed, we record an "added" record, because it will do the right
    # thing. We don't have to delete the old records.
    if ($TTL_Change_TXT) {
      $self->{ZP}->Add_RR($zName, $TXT_REC_TTL, $RR_Class, 'TXT', 
			  DDNS_Cons_TXT($self, $NR_Type, $RR_Class, $RR_Type,
					$R_Data, $NR_ID, $RR_Name));
    }
    if ($TTL_Change_RR) {
      $self->{ZP}->Add_RR($RR_Name, $RR_TTL, $RR_Class, $RR_Type, $R_Data);
    }

    return 1;
  } elsif ($MatchRR != -1 && $MatchTXT != -1) {

  }
  
  # No match, so put them in the ZoneParse for addition
  print " ADDING TO ZONE: $RR_Name $RR_Class $RR_Type $R_Data\n" if ($self->{Debug} >= 5);
  $self->{ZP}->Add_RR($RR_Name, $RR_TTL, $RR_Class, $RR_Type, $R_Data);
  $self->{ZP}->Add_RR($zName, $TXT_REC_TTL, $RR_Class, 'TXT', 
		DDNS_Cons_TXT($self, $NR_Type, $RR_Class, $RR_Type,
			      $R_Data, $NR_ID, $RR_Name));
}

## Anything left with a TXT record should be deleted at this point
sub MarkDeletions {
  my ($self) = @_;

  my %TXTrec;

  my $delTxt;
  foreach my $RName (keys %{$self->{Zone}}) {
    # Build a hash of all the TXT record keys
    foreach my $rec (@{$self->{Zone}->{$RName}}) {
      if ($rec->{class} eq 'IN' && $rec->{type} eq 'TXT' && 
	  $rec->{rdata} =~ /\[NR..\s+\S+\s+([^\]]+)\]/) {
	$TXTrec{$RName}->{$1} = $rec;
	print "MD: $RName:$1 ==> $rec\n" if ($self->{Debug} >= 2);
      }
    }
  }

  foreach my $RName (keys %{$self->{Zone}}) {
    # Now go back through each record and see if a TXT record is around
    foreach my $rec (@{$self->{Zone}->{$RName}}) {
      print "MarkDeletions: At $RName, checking \"$rec->{rdata}\"\n";

      my $zName = $RName; # when a CNAME, there shouldn't be multiple RRs for a single RName
      my $DefZone = $self->{ZP}->Get_DefZone();
      my @hn = split(/\./, $RName);
      $zName = "_DZ-$hn[0].$DefZone"
        if ($rec->{class} eq 'IN' && 
	    ($rec->{type} eq 'CNAME' || $rec->{type} eq 'NS'));
      $zName = $self->{CanonFunc}->($zName);

      foreach my $key (@{$self->{oldkeys}}) {
	my $txt = _ddns_auth_str($key, $rec->{class}, $rec->{type}, 
				$rec->{rdata}, $RName);
	print "Calculated: $txt ($key, $RName, $rec->{class}, $rec->{type}, $rec->{rdata}, $RName)\n";
        print "Keys at $zName: ".join(',', keys %{$TXTrec{$zName}})."\n" if ($self->{Debug} >= 5);
        if (defined $TXTrec{$zName}->{$txt}) {
          print "ZONE DELETION: $RName ($rec->{class}/$rec->{type}/$rec->{rdata}) TXT $TXTrec{$zName}->{$txt}->{rdata}\n" if ($self->{Debug} >= 5);
  	  push(@{$self->{DelZone}->{$zName}}, $TXTrec{$zName}->{$txt});
	  push(@{$self->{DelZone}->{$RName}}, $rec);
	  delete $TXTrec{$zName}->{$txt};
	  last;
	}
      }
    }
  }
  
  foreach my $RName (keys %{$self->{Zone}}) {
    # Delete any remaining TXT records that appear to be NetReg TXT records
    foreach my $txt (keys %{$TXTrec{$RName}}) {
      print "ZONE DELETION: $RName TXT $TXTrec{$RName}->{$txt}\n" if ($self->{Debug} >= 5);
      push(@{$self->{DelZone}->{$RName}}, $TXTrec{$RName}->{$txt});
    }
  }
}

## ddns_nsupdate
## Dynamic DNS Updater
## Arguments:
##  - KName: The name of the key being passed in..
##  - Key: The key contents
sub DDNS_NSUpdate {
  my ($self, $KName, $Key, $Masters) = @_;

  $self->{ZP}->Set_Debug(100);
  return $self->{ZP}->NSUpdate($self->{DelZone}, $KName, $Key, $Masters);
}

sub _ddns_match_rinfo {
  my ($S1, $S2) = @_;
  ($S1, $S2) = (uc($S1), uc($S2));

  my $nS1 = join(' ', split(/\s+/, $S1));
  my $nS2 = join(' ', split(/\s+/, $S2));
  $nS1 =~ s/^\s+//;
  $nS1 =~ s/\s+$//;
  $nS2 =~ s/^\s+//;
  $nS2 =~ s/\s+$//;
  
  return ($nS1 eq $nS2 || '"'.$nS1.'"' eq $nS2);
}    

## DDNS_Cons_TXT
## Construct a TXT NetReg Authority Record
## Arguments:
##   NR_Type:  The type of the NetReg generation..
##   RR_Class: The record class (ex. IN)
##   RR_Type:  The record type (ex. A, CNAME, MX, NS, etc.)
##   R_Info:   The right-hand info of the record (formatted for the class/type) 
##   NR_ID:    The NetReg ID of the resource record
##   R_Name:   The name of the resource record (for adding to the TXT auth string)
## Returns:
##   The RData for the TXT record
## ASSUME: $R_Name is the FQDN with trailing 'dot'
sub DDNS_Cons_TXT {
  my ($self, $NR_Type, $RR_Class, $RR_Type, $R_Info, $NR_ID, $R_Name) = @_;

  unless ($R_Name =~ /\.$/) {
    my ($p, $f, $l) = caller();
    print STDERR "$R_Name does not contain a trailing dot ($p $f $l)!\n";
    &CMU::Netdb::admin_mail('NetRegZone.pm', "Error in DDNS_Cons_TXT: R_Name did not ".
			    "contain\na trailing dot: $R_Name\n");
    return '[DDCT_Inv :$NR_Type:$NR_ID:$RR_Type --]';
  }
  
  if ($NR_Type !~ /(NRMR|NRDR|NRGR|NRCA)/) {
    print STDERR "$R_Name does not contain a trailing dot!\n";
    &CMU::Netdb::admin_mail('NetRegZone.pm', "Error in DDNS_Cons_TXT: Invalid NR_Type ".
			    "specified:\n $NR_Type ($NR_ID, $RR_Type, $R_Name)\n");
    return '[DDCT_Inv :$NR_Type:$NR_ID:$RR_Type --]';
  }
  
  $NR_ID .= '_'.$RR_Class.'_'.$RR_Type.'_'.$R_Info;
  $NR_ID =~ s/\s+/\./g;
  $NR_ID =~ s/\"//g;
  my $RFName = $R_Name;

  print "DDNS_Cons_TXT: R_Name ($R_Name), RFName ($RFName) with $RR_Class, $RR_Type, $self->{key}\n" if ($self->{Debug} >= 55);
    
  return "[$NR_Type $NR_ID "._ddns_auth_str($self->{key}, $RR_Class, $RR_Type, 
					   $R_Info, $RFName)."]";
}

## ASSUME: $R_Name is the FQDN with trailing 'dot'
sub _ddns_auth_str {
  my ($key, $RR_Class, $RR_Type, $R_Info, $R_Name) = @_;
  
  unless ($R_Name =~ /\.$/) {
    &CMU::Netdb::admin_mail('NetRegZone.pm', "Error in _ddns_auth_str: R_Name did not ".
			    "contain\na trailing dot: $R_Name\n");
  }
  return md5_base64("$key $RR_Class $RR_Type $R_Info $R_Name");
}


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 8
# perl-indent-level: 2
# cperl-indent-level: 2
# End:
