#   -*- perl -*-
#
# CMU::WebInt::quickreg
#
# $Id: quickreg.pm,v 1.26 2008/03/27 19:42:38 vitroth Exp $
#

package CMU::WebInt::quickreg;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %errmeanings $debug);

use CMU::WebInt;
use CMU::Netdb;
use Expect;
use Data::Dumper;

BEGIN {
  # Have to do this ourself, since "use" is done as a BEGIN
  require CMU::Netdb::config; import CMU::Netdb::config;

  my ($homRes, $hom) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'HAVE_OMAPI_MODULE');

  if ($hom == 1) {
#    push(@INC, '/usr/ng/lib/perl5');
    require OMAPI::DHCP; import OMAPI::DHCP;
    require MIME::Base64; import MIME::Base64;
  }
}

##

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw/qreg_loginhook/;

$debug = 0;

%errmeanings = %CMU::Netdb::errors::errmeanings;

# Do a lookup to see if:
#  a) the user has no machines registered
#  b) the subnet they are coming from is flagged prereg_subnet
# If so, send them to the quickreg page
# Return:
#  -1 if they don't qualify
#  1 if they DO qualify (and they've already been given the reg page..)
sub qreg_loginhook {
  my ($q, $dbh, $userid) = @_;
  
  # Quick check
  warn __FILE__, ':', __LINE__, ' :>'.
    "QuickReg: Login hook running.\n" if ($debug > 1);
  my ($res, $errfields, $vres, $Method);

  ($res, $Method) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'QUICKREG_METHOD');

  $Method = 'no_regs' if ($Method ne 'no_regs' && $Method ne 'machine_unreg');

  if ($Method eq 'no_regs') {
    ($res, $errfields) = qreg_hasmachreg($q, $dbh, $userid);
    warn __FILE__, ':', __LINE__, ' :>'.
      "QuickReg: HasMachReg returns: $res ".Dumper($errfields)."\n"
	if ($debug > 1);
    return ($res, $errfields) if ($res <= 0);
  }
  
  ($res, $errfields) = qreg_findsubnet($q, $dbh, $userid);
  warn __FILE__, ':', __LINE__, ' :>'.
    "QuickReg: FindSubnet returns: $res ".Dumper($errfields)."\n"
      if ($debug > 1);
  return ($res, $errfields) if ($res <= 0);
  
  my $Subnet = $res;
  
  if ($Method eq 'machine_unreg') {
    ($res, $errfields) = qreg_currmachinereg($q, $dbh, $userid);
    warn __FILE__, ':', __LINE__, ' :>'.
      "QuickReg: CurrMachineReg returns: $res ".Dumper($errfields)."\n"
	if ($debug > 1);
    return ($res, $errfields) if ($res <= 0);
  }
  
  my ($id, $ref) = qreg_prereg_text($q, $dbh, $Subnet);
  warn __FILE__, ':', __LINE__, ' :>'.
    "QuickReg: Register returns: $id ".Dumper($ref)."\n"
      if ($debug > 1);
  return ($res, $ref) if ($id <= 0);
  
  return 1;  
}

# See if the user has a machine registered.
# We'll do this by a quick lookup into the protections table.
# We want this query to be as fast as possible, because it will be
# run for every homepage load. :(
sub qreg_hasmachreg {
  my ($q, $dbh, $userid) = @_;
  
  # Better safe...
  $userid = CMU::Netdb::cleanse($userid); 
  
  my $Query = "SELECT C.id FROM credentials AS C, protections ".
    "C.authid = '$userid' AND protections.identity = C.user ".
      "AND protections.tname = 'machine' LIMIT 0,1";
  my $rUsers = $dbh->selectall_arrayref($Query);
  return (-1, ['dbh']) if (!ref $rUsers);
  
  # We return an "error" if the user has any entries
  return (-1, ['has.reg']) if ($#$rUsers != -1);
  return (1);
}

# See if the user has *this* machine registered. 
# (QUICKREG_METHOD == machine_unreg)
# This is slower than seeing if they have *any* machine registered,
# because we need to query the DHCP servers to get the MAC address
sub qreg_currmachinereg {
  my ($q, $dbh, $userid) = @_;
  
  my ($res, $MAC) = qreg_omapi_getmac($q, $dbh, $ENV{REMOTE_ADDR});
  return ($res, $MAC) if ($res != 1);
  
  ## We'll call findsubnet again so we can check for registration
  ## on any of the subnets possible.
  ## There could be more than one possible
  ## subnet that a registration could be made on, so a complete
  ## solution checks all of them
  
  my ($sid, $rSubnets) = qreg_findsubnet($q, $dbh, $userid);
  return ($sid, $rSubnets) if ($res <= 0);
  
  $MAC =~ s/\://g;
  my $Query = "SELECT machine.host_name FROM machine WHERE ".
    "mac_address = '$MAC' AND ".
      "ip_address_subnet IN (".join(',', @$rSubnets).") ";
  my $rMachines = $dbh->selectall_arrayref($Query);
  return (-1, ['dbh']) if (!ref $rMachines);
  
  # Error if there are any machines
  return (-1, ['machine.reg']) if ($#$rMachines != -1);
  return (1);
}

# Find the subnet that we'd register them from
sub qreg_findsubnet {
  my ($q, $dbh, $user) = @_;
  
  my $IP = CMU::Netdb::valid('env.remote_addr',
			     $ENV{REMOTE_ADDR}, $user, 0, $dbh);
  
  return (-1, ['ip']) if (CMU::Netdb::getError($IP) != 1);
  
  my ($res, $Share, $subnet) = qreg_findsubnetshare($dbh, $IP);
  return ($res, $Share) if ($res != 1);

  # We have a subnet share. Look for other subnets with the same
  # share ID.
  # This allows the administrator to setup multiple subnets on
  # the same wire and let the system just tell the user what subnet
  # they'll be using. Ideally we'd pick the subnet with the least
  # IPs registered (or some other administrator-controlled metric)
  # but for now we'll just select a valid one. :)
  
  my $Query =<<END_QR_FS_QUERY;
    subnet.share = '$Share' AND subnet.id != '$subnet'
AND FIND_IN_SET('prereg_subnet', flags)
AND ( 
        (default_mode = 'static' AND NOT FIND_IN_SET('no_static', flags))
     OR (default_mode = 'dynamic' AND (dynamic = 'permit' OR 
				       dynamic = 'restrict')
	 )
     )
END_QR_FS_QUERY
  
  my $rSubInfo = CMU::Netdb::list_subnets_ref($dbh, 'netreg', 
					      $Query, 'subnet.name');
  
  return (-1, ['find', 'subnet.id']) if (!ref $rSubInfo);
  my @Subnets = keys %$rSubInfo;
  
  # More than one subnet is okay, we'll just use the first one :)
  return (-1, ['find', 'subnet.id', 'zero']) if ($#Subnets == -1);
  
  return ($Subnets[0], \@Subnets);
}

# Given an IP address in integer format, figure out what subnet
# share is on it.
sub qreg_findsubnetshare {
  my ($dbh, $IP) = @_;
  
  # Figure out the share 
  my $rSubInfo = CMU::Netdb::list_subnets_ref($dbh, 'netreg', 
					      " ($IP ".
					      " & network_mask) ".
					      " = base_address ",
					      'subnet.share');
  return (-1, ['subnet.share']) if (!ref $rSubInfo);
  my @Subnets = keys %$rSubInfo;
  
  # More than 1 subnet that matches is an error
  if ($#Subnets == -1) {
    # No subnet, can't find a registration subnet
    return (-1, ['subnet.id', $IP]);
  }elsif($#Subnets > 0) {
    # Send mail
    CMU::WebInt::admin_mail('quickreg.pm:qreg_findsubnet',
			    'ERROR',
			    'Multiple subnets returned.',
			    { 'remote_addr' => $ENV{REMOTE_ADDR},
			      'ip' => $IP,
			      'subnets' => join(',', @Subnets) });
    return (-1, ['subnet.id', 'multiple']);
  }
  
  my $Subnet = $Subnets[0];
  my $Share = $rSubInfo->{$Subnet};
  return (-1, ['subnet.share', 'zero']) if ($Share eq '' || 
					    $Share <= 0);
  
  return (1, $Share, $Subnet);
}


sub qreg_prereg_text {
  my ($q, $dbh, $SID) = @_;
  
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $url = $ENV{SCRIPT_NAME};
 
  $dbh = CMU::WebInt::db_connect() unless (ref $dbh);

  my ($res, $MAC) = qreg_omapi_getmac($q, $dbh, $ENV{REMOTE_ADDR});

  if ($q->param('op') eq 'quickreg_fake') {
    $SID = 1;
    $MAC = '00:01:02:03:04:05';
  }elsif($res != 1) {
    return ($res, $MAC);
  }

  my %Vars = ('mac' => $MAC,
	      'subnet_id' => $SID);
  
  # Get the subnet name
  my $subnet = CMU::Netdb::list_subnets_ref($dbh, $user, "subnet.id = '$SID'",
					    'subnet.name');
  if (!ref $subnet) {
    return ($subnet, ['list_subnets']);
  }else{
    $Vars{'subnet_name'} = $subnet->{$SID};
  }
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Quick Registration", {});
  CMU::WebInt::title("Select Your Network Registration Method");

  print "<p>There are two options for registering on this network: <b>Simple</b>".
     " and <b>Advanced</b>.";

  print "<table width=100%><tr><td valign=top>";
  print "<b>Simple registration</b> will immediately register this system for ".
	"your use on this network. The settings selected are appropriate for everyday ".
	"use of computers for Internet access, email, and productivity.<br><br>".
	"<b>Almost all students, faculty, and staff should choose the Simple option.</b>";

  print "</td><td valign=top><b>Advanced Registration</b> allows the selection of more ".
	"advanced ".
	"network registration options, including DNS names and static IP addressing. ".
	"This option is more appropriate for machines that will be used as servers.";

  print "</td></tr><tr><td>";

  print "<center><font size=+1>Proceed with<br>".
     	"<a href=\"".CMU::WebInt::encURL("$url?op=quickreg_simple&sid=$SID&mac=$MAC").
	"\">Simple Registration</a></font></center>";

  print "</td><td>";

  print "<center><font size=+1>Proceed with<br>".
 	"<a href=\"".CMU::WebInt::encURL("$url?op=quickreg_continue&sid=$SID&mac=$MAC").
	"\">Advanced Registration</a></font></center>";

  print "</td></tr></table>";
	
  print CMU::WebInt::stdftr($q);  
}

sub qreg_reg_setup {
  my ($q, $errors) = @_;
  
  my $MAC = CMU::WebInt::gParam($q, 'mac');
  my $SID = CMU::WebInt::gParam($q, 'sid');
  
  $q->delete('op');
  $q->param('op', 'mach_reg_s1');
  
  $q->param('bmvm', '1');
  $q->param('subnet', $SID);
  $q->param('subnetNEXT', 'Continue');
  $q->param('mac_address', $MAC);
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "Setting bmvm: 1, subnet $SID, mac: $MAC\n";
  CMU::WebInt::machines::mach_reg_s1($q, $errors);
  return (1, '');
}

sub qreg_reg_simple {
  my ($q, $errors) = @_;

  my $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  my $MAC = CMU::WebInt::gParam($q, 'mac');
  my $SID = CMU::WebInt::gParam($q, 'sid');

  $q->delete('op');
  $q->param('op', 'mach_reg_s3');

  # Perform a simple registration. We need to supply:
  #  - domain name
  #  - mode (static/dynamic)
  #  - affiliation
  #  - subnet
  #  - MAC address

  # Affiliation
  my ($dGrpRes, $defaultGroup) = CMU::Netdb::list_user_default_group
				($dbh, $user, $user);
  if ($dGrpRes == 1) {
    $q->param('dept', $defaultGroup->{'group'});
  }else{
    return qreg_reg_setup($q, {});
  }

  # Mode
  my $modes_plus = CMU::Netdb::get_machine_modes($dbh, $user, $SID, 1);
  {
    my $default;
    my @modes;
    if (exists $modes_plus->{'_default_mode'}) {
      $q->param('mode', $modes_plus->{'_default_mode'});
    }else{
      @modes = keys %$modes_plus;
      if (scalar(@modes) < 1) {
        # Send an error
        &CMU::WebInt::admin_mail('quickreg.pm:qreg_reg_simple', 'WARNING',
				 "No modes for user '$user' on subnet $SID",
				{'subnet' => $SID,
				 'mac_address' => $MAC,
				 'user' => $user});
        return qreg_reg_setup($q, {'type' => 'ERR', 
                       'msg' => 'There are no available registration modes '. 
                                'on this subnet. The administrators have been '. 
                                'notified.'});
      }else{
        $q->param('mode', $modes[0]);
      }
    }
  }

  # Domain
  my @domains = sort {$a cmp $b} @{CMU::Netdb::get_domains_for_subnet
 			           ($dbh, $user, "subnet_domain.subnet = '$SID'")};
  if (scalar(@domains) < 1) {
    &CMU::WebInt::admin_mail('quickreg.pm:qreg_reg_simple', 'WARNING',
                             "No domains for user '$user' on subnet $SID",
                             {'subnet' => $SID,
                              'mac_address' => $MAC,
                              'user' => $user});
    return qreg_reg_setup($q, {'type' => 'ERR',    
                     'msg' => 'There are no available domains '. 
                              'on this subnet. The administrators have been '.
                              'notified.'});
  }else{
    $q->param('domain', $domains[0]);
  }
    
  # Subnet, hostname, mac address   
  $q->param('subnet', $SID);
  $q->param('host', '');
  $q->param('mac_address', $MAC);
  $q->param('ip_address', '');
  $q->param('comment_lvl9', '');
  $q->param('ip_address_ttl', '');
  $q->param('host_name_ttl', '');

  # protections - lvl9 only
  $q->param('IDtype0', '0');
  $q->param('ID0', $user);
  $q->param('read0', '1');
  $q->param('write0', '1');

  warn __FILE__, ':', __LINE__, ' :>'.
    "Simple registration: subnet $SID, mac: $MAC, mode: ".$q->param('mode').
	", domain: $domains[0], dept: ".$q->param('dept')."\n";
  CMU::WebInt::machines::mach_reg_s3($q, {});
  return (1, '');
}


# Given an IP address, query the DHCP server for the MAC Address
# that got the lease
sub qreg_omapi_getmac {
  my ($q, $dbh, $IP) = @_;

  my ($vres, $OmshellCmd, $DhcpService);
  ($vres, $OmshellCmd) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DHCP_OMSHELL');
  ($vres, $DhcpService) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DHCP_SERVICE');

  my $KeyName = 'defomapi';

  # Determine the proper service type
  my $rSrvType = CMU::Netdb::list_service_types_ref
    ($dbh, 'netreg', "service_type.name = 'DHCP Server Pool'",
     'service_type.name');

  return ($rSrvType, ['list_service_types_ref']) if (!ref $rSrvType);

  my $STypeID = 0;

  foreach my $K (keys %$rSrvType) {
    if ($rSrvType->{$K} eq 'DHCP Server Pool') {
      $STypeID = $K;
      last;
    }
  }

  return (-1, ['list_service_types_ref', 'DHCP Server Pool'])
    if ($STypeID == 0);

  # We need to get the service ID in order to use list_service_full_ref,
  # which gives us all the info
  my $rSrvInfo = CMU::Netdb::list_services($dbh, 'netreg', 
					   "service.type = $STypeID");
  return ($rSrvInfo, ['list_services', $STypeID]) if (!ref $rSrvInfo);

  my %SMap = %{CMU::Netdb::makemap($rSrvInfo->[0])};

  my %DHCP_Servers;
  my %ServiceOMAPI;

  shift(@$rSrvInfo);

  foreach my $row (@$rSrvInfo) {
    my $SID = $row->[$SMap{'service.id'}];

    my $rService = CMU::Netdb::list_service_full_ref($dbh, 'netreg', $SID);
    return ($rService, ['full_ref', $SID]) if (!ref $rService);

    # Find any machine members that are configured as 'dynamic' servers
    # ("File Type")
    foreach my $MachID (@{$rService->{'memberSum'}->{'machine'}}) {
      # Assume "File Type" only has one value
      next if (!defined $rService->{'member_attr'}->{"machine:$MachID"});
      next if (!defined 
	       $rService->{'member_attr'}->{"machine:$MachID"}->{"File Type"});

      my @FT = @{$rService->{'member_attr'}->{"machine:$MachID"}->{"File Type"}->[0]};

      next if ($#FT < 0);
      next unless ($FT[0] eq 'dynamic');
      
      my $IP = CMU::Netdb::long2dot($rService->{'memberData'}->{"machine:$MachID"}->{'machine.ip_address'});

      # Key is in the service
      return (-1, ['omapi_key']) 
	unless (defined $rService->{'attributes'}->{'OMAPI Key'});
      my $Key = $rService->{'attributes'}->{'OMAPI Key'}->[0];

      return (-1, ['omapi_port'])
	unless (defined $rService->{'attributes'}->{'OMAPI Port'});
      my $Port = $rService->{'attributes'}->{'OMAPI Port'}->[0];
      $DHCP_Servers{$IP} = {'key' => $Key,
			    'port' => $Port};
    }
  }

  my @ErrFields;
  foreach my $ServerIP (keys %DHCP_Servers) {
    my ($Key, $Port) = ($DHCP_Servers{$ServerIP}->{'key'},
			$DHCP_Servers{$ServerIP}->{'port'});

    my ($oRes, $MAC) = qreg_omapi_exec($OmshellCmd, $ServerIP, 
				       $IP, $KeyName, $Key, $Port);
    warn __FILE__, ':', __LINE__, ' :>'.
      "Returned from qreg_omapi: $oRes, $MAC\n" if ($debug > 2);
    return (1, $MAC) if ($oRes == 1);
    push(@ErrFields, @$MAC);
  }
  return (-1, ['servers']);
}

sub qreg_omapi_exec {
  my ($OmshellCmd, $ServerIP, $IP, $KeyName, $Key, $Port) = @_;

  warn __FILE__, ':', __LINE__, ' :>'.
    "qreg_omapi_exec($OmshellCmd, $ServerIP, $IP, $KeyName, $Key, $Port)"
      if ($debug >= 2);

  my ($homRes, $hom) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'HAVE_OMAPI_MODULE');

  if ($hom == 1) {
    return qreg_omapi_exec_module($ServerIP, $IP, $KeyName, $Key, $Port);
  }

  warn __FILE__, ':', __LINE__, ' :>'.
    "Spawning $OmshellCmd\n";
  $Expect::Log_Stdout = 0;
  my $con = Expect->spawn("$OmshellCmd") || warn "Cannot spawn $OmshellCmd";
  $con->send("key $KeyName $Key\n");
  $con->send("server $ServerIP\nport $Port\n");
  $con->send("connect\n");
  sleep(1);
  $con->send("new lease\nset ip-address = $IP\n");
  sleep(1);
  $con->send("open\n");
  my ($mpp, $err, $ms, $bm, $am) = $con->expect(5, 'hardware-address = ');
  if ($mpp != 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "$mpp\n$err\n$ms\n$bm\n$am\n" if ($debug > 2);
    # couldn't find it, let's move on
    return (-1, ['hardware-address']);
  }
  my $txt = "$bm$ms$am";  
  $txt =~ /hardware-address\s+=\s+(\S+)/;
  my $MAC = $1;
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "Found: $MAC\n" if ($debug > 2);
  $MAC = CMU::Netdb::valid('local.dhcp_server', $MAC, 'netreg', 9, '');
  warn __FILE__, ':', __LINE__, ' :>'.
    "Translated: $MAC ".CMU::Netdb::getError($MAC)."\n"
      if ($debug > 2);
  return (-1, ['geterror', 'mac-address']) if (CMU::Netdb::getError($MAC) != 1);
  return (1, $MAC);
}

sub qreg_omapi_exec_module {
  my ($ServerIP, $IP, $KeyName, $Key, $Port) = @_;
  
  my $BKey = decode_base64($Key);
  
  my $Conn = eval { new OMAPI::DHCP($ServerIP, $Port, "$KeyName:$BKey"); };
  return (-1, ['omapi_conn']) if (!defined $Conn);
  
  my $Lease = $Conn->Select_Lease({'ip-address' => $IP});
  return (-1, ['omapi_lease']) if (!defined $Lease);
  return (-1, ['lease_contents']) if (!defined $Lease->{'hardware-address'});
  
  my $HA = $Lease->{'hardware-address'};
  return (-1, ['hardware-address']) if ($HA eq '');
  $HA = unpack('H12', $HA);
  $HA =~ s/(..)/$1\0/g;
  $HA = join(":", split(/\0/, $HA));
  return (1, $HA);
}  

1;
