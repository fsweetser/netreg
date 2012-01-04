# -*-Perl-*-
#
# Perl5 general utility subroutines
#
# $Id: RyNetUtils.pm,v 1.2 2008/03/27 19:42:33 vitroth Exp $
#
###########################################################################

package RyNetUtils;
require 5.000;

use strict;
use SNMP 1.8;

my $SnmpErr;
###########################################################################

# Exports:

# AddMACToOID(".1.2.3.4.5", "000A0B0C0D0E");

###########################################################################

# "0" -> 0, "A" -> 10, "F" -> 15
sub Conv {
  my($a) = @_;

  if (($a >= 48) && ($a <= 58)) {
    return($a - 48); # 0-9
  } else {
    return($a - 55);
  }
}

# 0 -> "0", 10 -> "A", 15 -> "F"
sub UnConv {
  my($a) = @_;
  my($b);

  if (($a >= 0) && ($a <= 9)) {
    $b = ($a + 48);
  } else {
    $b = ($a + 55);
  }

  return(chr($b));
}

# 255 -> FF
sub Fix {
  my($n) = @_;

  my($a) = int($n / 16);
  my($b) = ($n - ($a * 16));

  my($A) = &UnConv($a);
  my($B) = &UnConv($b);

  return($A, $B);
}

sub AddMACToOID {
  my($OID, $MAC) = @_;

  # Make sure we only deal with CAPS
  $MAC =~ tr/a-z/A-Z/;

  my($a, $b, $c, $d, $e, $f);
  my($a1, $a2, $b1, $b2, $c1, $c2, 
   $d1, $d2, $e1, $e2, $f1, $f2) = unpack("cccccccccccc", $MAC);

  $a = (&Conv($a1) * 16) + &Conv($a2);
  $b = (&Conv($b1) * 16) + &Conv($b2);
  $c = (&Conv($c1) * 16) + &Conv($c2);
  $d = (&Conv($d1) * 16) + &Conv($d2);
  $e = (&Conv($e1) * 16) + &Conv($e2);
  $f = (&Conv($f1) * 16) + &Conv($f2);

  return("$OID.$a.$b.$c.$d.$e.$f");
}

sub OIDToMAC {
  my($OID) = @_;

  # ddd.ddd.ddd.ddd.ddd.ddd
  my($a, $b, $c, $d, $e, $f) = split(/\./, "$OID");

  my($a1, $a2) = &Fix($a);
  my($b1, $b2) = &Fix($b);
  my($c1, $c2) = &Fix($c);
  my($d1, $d2) = &Fix($d);
  my($e1, $e2) = &Fix($e);
  my($f1, $f2) = &Fix($f);


  my $RealMAC="$a1$a2$b1$b2$c1$c2$d1$d2$e1$e2$f1$f2";

  $RealMAC;
}  

# -------------------------------------------------------------------------

# Locate a MAC address on the specified host.  Returns the SNMP Interface
# on that host the MAC address is on, or 0.
#
sub FindMACOnHost {
  my($MAC, $Host) = @_;
  my($Port);

  # This is a two-stage process -- need to find the bridge table entry,
  # and then map it to the appropriate row in the interfaces table.

  my($MACOID)  = &RyNetUtils::AddMACToOID(".1.3.6.1.2.1.17.4.3.1.2", $MAC);
  my($PortOID) = ".1.3.6.1.2.1.17.1.4.1.2";

  $Port   = &RyNetUtils::SNMPGet($Host, "public", $MACOID);

  # Now translate this entry into the appropriate SNMP port number.
  &RyNetUtils::SNMPGet($Host, "public", "$PortOID.$Port");
}

###########################################################################

# Simple debugging for everything

sub Verbose {
  $RyNetUtils::Verbose = @_;
}

sub Msg {
  my($M) = @_;
  if (defined $RyNetUtils::Verbose) {
    print STDOUT "$M\n";
  }
}

###########################################################################

sub SNMPGet {
  my($Host, $Comm, $Oid) = @_;
  my($Ans);
  my($sess);

  $sess = new SNMP::Session('DestHost' => $Host, 'Community' => $Comm);
  if(!$sess) { $SnmpErr = "No session established to $Host\n"; return(-1) };
  $Ans=$sess->get([$Oid]);  
  $SnmpErr = $sess->{ErrorStr} if $sess->{ErrorStr};
  chomp($Ans);
  $Ans;
}

sub SNMPSetString {
  my($Host, $Comm, $Oid, $Str) = @_;
  system("snmpset $Host $Comm $Oid s \"$Str\"");
}
  

###########################################################################

sub snmp_walk {
  my ($server, $comm, $rootoid) = @_;

  my %walk=();
  my $sess = new SNMP::Session ( DestHost => $server,
                                 Community => $comm,
                                 UseNumeric => 1,
                                 UseLongNames => 2
                               );
  $SNMP::verbose=0;
  $SNMP::debugging=0;


  if(!$sess) { $SnmpErr = "No session established to $server\n"; return(-1) };
  my $rootlen = length($rootoid);
  
  my $var = new SNMP::Varbind(["$rootoid"]);
  my $val = $sess->getnext($var);
  my $name = $var->[$SNMP::Varbind::tag_f].".".$var->[$SNMP::Varbind::iid_f];

  while (!$sess->{ErrorStr} && substr($name, 0, $rootlen) eq $rootoid){
    my $value=$var->[$SNMP::Varbind::val_f];

    $walk{"$name"} = $value;
    $val = $sess->getnext($var);
    $name=$var->[$SNMP::Varbind::tag_f];
    $name.=".$var->[$SNMP::Varbind::iid_f]" if $var->[$SNMP::Varbind::iid_f];
  }  #while

  #$self->{SNMPErr} = $sess->{ErrorStr} if $sess->{ErrorStr};
  return(%walk);
}

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  return $self;
}

# Success!
1;

