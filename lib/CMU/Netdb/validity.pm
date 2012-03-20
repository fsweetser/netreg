#   -*- perl -*-
#
# CMU::Netdb::validity
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


package CMU::Netdb::validity;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $INVALID $debug);

use CMU::Netdb;
use CMU::Netdb::errors;
use CMU::Netdb::helper;
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(valid getError verify_limit verify_orderby);

$INVALID = chr(001);
$debug = 0;

my %validmap = ('building.name' => \&verify_bstring_64,
		'building.abbreviation' => \&verify_bstring_16,
		'building.building' => \&verify_bstring_8,
		
		'protections.identity' => \&verify_integer_err_default,
		'protections.tid' => \&verify_integer_err_default,
		'protections.rights' => \&verify_rights,
		'protections.tname' => \&verify_table_name,
		'protections.rlevel' => \&verify_integer_err_default,
		
		'machine.mac_address' => \&verify_macaddress,
		'machine.host_name' => \&verify_hostname_zone_lookup,
		'machine.ip_address' => \&verify_ip_null_ok,
		'machine.mode' => \&verify_machine_mode,
		'machine.flags' => \&verify_machine_flags,
		'machine.comment_lvl9' => \&verify_comment,
		'machine.comment_lvl5' => \&verify_comment,
		'machine.comment_lvl1' => \&verify_comment,
		'machine.host_name_ttl' => \&verify_integer_0_default,
		'machine.ip_address_ttl' => \&verify_integer_0_default,
		'machine.host_name_zone', => \&verify_integer_err_default,
		'machine.ip_address_zone', => \&verify_integer_0_default,
		'machine.ip_address_subnet' => \&verify_integer_err_default,
		'machine.created' => \&verify_created,
		'machine.expires' => \&verify_expires,
		'machine.account' => \&verify_bstring_32,

		'service.name' => \&verify_hostname,
		'service.description' => \&verify_bstring_255,
		'service_type.name' => \&verify_bstring_255,

		'service_membership.member_type' => \&verify_smem_member_type,

		'attribute.spec' => \&verify_attr_spec,
		'attribute.owner_table' => \&verify_attr_owner_table,
		'attribute.owner_tid' => \&verify_integer_err_default,

		'attribute_spec.name' => \&verify_bstring_255,
		'attribute_spec.format' => \&verify_attr_spec_format,
		'attribute_spec.scope' => \&verify_attr_spec_scope,
		'attribute_spec.type' => \&verify_integer_err_default,
		'attribute_spec.description' => \&verify_bstring_255,
		'attribute_spec.ntimes' => \&verify_integer_1_default,

		'users.flags' => \&verify_users_flags,
		'users.comment' => \&verify_comment,

		'credentials.authid' => \&verify_cred_authid,
		'credentials.authid_perm' => \&verify_cred_authid_perm,
		'credentials.description' => \&verify_bstring_64,
		'credentials.user' => \&verify_integer_err_default,
                'credentials.type' => \&verify_integer_blank_default,

		'groups.name' => \&verify_groups_name,
		'groups.flags' => \&verify_groups_flags,
		'groups.comment_lvl5' => \&verify_comment,
		'groups.comment_lvl9' => \&verify_comment,
		'groups.description' => \&verify_bstring_64,
		
		'subnet.name' => \&verify_bstring_64,
		'subnet.abbreviation' => \&verify_bstring_16,
		'subnet.network_mask' => \&verify_ip,
		'subnet.base_address' => \&verify_ip,
		'subnet.vlan' => \&verify_integer_blank_default, #FIXME should this be int or bstring?
		'subnet.dynamic' => \&verify_subnet_dynamic,
		'subnet.expire_static' => \&verify_integer_0_default,
		'subnet.expire_dynamic' => \&verify_integer_0_default,
		'subnet.default_mode' => \&verify_subnet_default_mode,
		'subnet.share' => \&verify_subnet_share,
		'subnet.flags' => \&verify_subnet_flags,
		'subnet.purge_interval' => \&verify_integer_0_default,
		'subnet.purge_notupd' => \&verify_integer_0_default,
		'subnet.purge_notseen' => \&verify_integer_0_default,
		'subnet.purge_explen' => \&verify_integer_0_default,
		'subnet.purge_lastdone' => \&verify_subnet_p_lastdone,
		
		# For the "register IPs" feature
		'subnet.number_of_ips' => \&verify_integer_err_default,
		'subnet.allocation_method' => \&verify_alloc_method,
		'subnet.machine_mode' => \&verify_subnet_machine_mode,
		'subnet.hostname' => \&verify_hostname,
		
		'subnet_presence.subnet' => \&verify_integer_0_default,
		'subnet_presence.building' => \&verify_bstring_252,
		
		'subnet_domain.subnet' => \&verify_integer_0_default,
		'subnet_domain.domain' => \&verify_domain,

		'subnet_registration_modes.subnet' => \&verify_integer_0_default,
		'subnet_registration_modes.mode' => \&verify_machine_mode,
		'subnet_registration_modes.mac_address' => \&verify_registration_mode_macaddr,
		'subnet_registration_modes.quota' => \&verify_integer_undef_default,

		'subnet_share.name' => \&verify_bstring_64,
		'subnet_share.abbreviation' => \&verify_bstring_16,

		'network.name' => \&verify_bstring_64,
                'network.subnet' => \&verify_integer_0_default,

		'dns_resource_type.name' => \&verify_bstring_8,
		'dns_resource_type.format' => \&verify_dns_type_format,
		
		'dns_resource.name_srvrecord' => \&verify_hostname_und_allow,
		'dns_resource.name' => \&verify_hostname_und_allow,
		'dns_resource.ttl' => \&verify_integer_0_default,
		'dns_resource.type' => \&verify_dns_resource_type,
		'dns_resource.rname' => \&verify_hostname,
		'dns_resource.rmetric0' => \&verify_integer_0_default,
		'dns_resource.rmetric1' => \&verify_integer_0_default,
		'dns_resource.rport' => \&verify_integer_0_default,
		'dns_resource.text0' => \&verify_bstring_255,
		'dns_resource.text1' => \&verify_bstring_255,
		'dns_resource.owner_type' => \&verify_dns_resource_owner,
		'dns_resource.owner_tid' => \&verify_integer_err_default,
		'dns_resource.name_zone' => \&verify_integer_0_default,

		'dns_resource.text0_rp' => \&verify_hostname,
		'dns_resource.text1_rp' => \&verify_hostname,
		
		'dhcp_option_type.name' => \&verify_bstring_64,
		'dhcp_option_type.number' => \&verify_integer_err_default,
		'dhcp_option_type.format' => \&verify_dhcp_option_format,
		'dhcp_option_type.format_arg' => \&verify_bstring_255,
		
		'dns_zone.name' => \&verify_hostname_zone_lookup,
		'dns_zone.soa_host' => \&verify_bstring_255,
		'dns_zone.soa_email' => \&verify_soa_email,
		'dns_zone.soa_serial' => \&verify_integer_0_default,
		'dns_zone.soa_refresh' => \&verify_integer_3600_default,
		'dns_zone.soa_retry' => \&verify_integer_600_default,
		'dns_zone.soa_expire' => \&verify_integer_3600000_default,
		'dns_zone.soa_minimum' => \&verify_integer_86400_default,
		'dns_zone.type' => \&verify_dns_zone_type,
		'dns_zone.ddns_auth' => \&verify_ddns_auth,
		
		# FIXME dns_zone.last_update
		
		'dhcp_option.type_id' => \&verify_dhcp_option_type_id,
		'dhcp_option.value' => \&verify_dopt_string,
		'dhcp_option.type' => \&verify_dhcp_option_type,
		'dhcp_option.tid' => \&verify_integer_err_default,
		
		'outlet_type.name' => \&verify_bstring_64,
		
		'outlet.type' => \&verify_outlet_type,
		#		'outlet.cable' => \&verify_cable_exists,
		'outlet.device' => \&verify_integer_0_default,
		'outlet.port' => \&verify_integer_blank_default,
		'outlet.attributes' => \&verify_outlet_attributes,
		'outlet.flags' => \&verify_outlet_flags,
		'outlet.status' => \&verify_outlet_status,
		'outlet.comment_lvl9' => \&verify_comment,
		'outlet.comment_lvl5' => \&verify_comment,
		'outlet.comment_lvl1' => \&verify_comment,
		'outlet.account' => \&verify_bstring_32,
		'outlet.device_string' => \&verify_outlet_device,
		'outlet.cable' => \&verify_integer_err_default,
		
		'outlet_subnet_membership.outlet' => \&verify_integer_0_default,
		'outlet_subnet_membership.subnet' => \&verify_integer_0_default,
		'outlet_subnet_membership.type' => \&verify_outlet_subnet_membership_type,
		'outlet_subnet_membership.trunk_type' => \&verify_outlet_subnet_membership_trunk_type,

		'outlet_vlan_membership.outlet' => \&verify_integer_0_default,
		'outlet_vlan_membership.vlan' => \&verify_integer_0_default,
		'outlet_vlan_membership.type' => \&verify_outlet_vlan_membership_type,
		'outlet_vlan_membership.trunk_type' => \&verify_outlet_vlan_membership_trunk_type,
		'outlet_vlan_membership.status' => \&verify_outlet_vlan_membership_status,

		'trunk_set.name' => \&verify_bstring_64,
		'trunk_set.abbreviation' => \&verify_bstring_64,
		'trunk_set.description' => \&verify_bstring_64,
		'trunk_set.primary_vlan' => \&verify_integer_0_default,
	
                'user_type.name' => \&verify_bstring_64,
                'user_type.expire_days_mach' => \&verify_integer_14_default,
                'user_type.expire_days_outlet' => \&verify_integer_14_default,
                'user_type.flags' => \&verify_user_type_flags,
	
		'vlan.name' => \&verify_bstring_64,
		'vlan.abbreviation' => \&verify_bstring_64,
		'vlan.description' => \&verify_bstring_64,
		'vlan.number' => \&verify_integer_0_default,

		'trunkset_building_presence.buildings' => \&verify_integer_0_default,
                'trunkset_building_presence.trunk_set' => \&verify_integer_0_default,

                'trunkset_machine_presence.device' => \&verify_integer_0_default,
                'trunkset_machine_presence.last_update' => \&verify_datetime,
                'trunkset_machine_presence.trunk_set' => \&verify_integer_0_default,

                'trunkset_vlan_presence.vlan' => \&verify_integer_0_default,
                'trunkset_vlan_presence.trunk_set' => \&verify_integer_0_default,
	
		'env.remote_addr' => \&verify_ip,

		'local.dhcp_server' => \&verify_macaddress,
		'local.table_name' => \&verify_table_name,
		'local.table_name_mult' => \&verify_table_name_mult,

		'_sys_changerec_row.changelog' => \&verify_integer_err_default,
		'_sys_changerec_row.tname' => \&verify_table_name,
		'_sys_changerec_row.row' => \&verify_integer_err_default,
		'_sys_changerec_row.type' => \&verify_changerec_row_type,

		'_sys_changerec_col.changerec_row' => \&verify_integer_err_default,
 		'_sys_changerec_col.name' => \&verify_changerec_col_name,
		'_sys_changerec_col.data_ref' => \&verify_changerec_col_string,
		'_sys_changerec_col.previous_ref' => \&verify_changerec_col_string,
	       );

# Function: CMU::Netdb::valid
# Arguments: 5:
#     The name of the field
#     The value
#     The username of the user performing the action
#     The user level of the user performing the action
#     Database handle
# Actions:
#     Just a placeholder for now
#     Eventually this will check that the given value is acceptable for 
#         the table/field.
# Return value: $INVALID$errorcode if invalid, otherwise a valid string for the
#               table/field (which MAY be different than the input)

sub valid {
  my ($field, $value, $user, $ul, $dbh) = @_;

  my $Ret;
  if (defined $validmap{$field}) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Calling field specific validation routine for $field: '$value'\n" if ($debug >= 3);
    $Ret = $validmap{$field}->(CMU::Netdb::cleanse($value), $user, $ul, $dbh);
    if (substr($Ret, 0, 1) eq $INVALID) {
      $value = 'undef' unless (defined $value);
      warn __FILE__, ':', __LINE__, ' :>'.
	"Validation of $field ($value) failed: ".substr($Ret, 1);
    }
    return $Ret;
  }elsif($field =~ /\.id$/s) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "Calling validation routine for id\n" if ($debug >= 3);
    $Ret = verify_integer_err_default(CMU::Netdb::cleanse($value), $user,
				      $ul, $dbh);
    if (substr($Ret, 0, 1) eq $INVALID) {
      $value = 'undef' unless (defined $value);
      warn __FILE__, ':', __LINE__, ' :>'.
	"Validation of $field ($value) failed: ".substr($Ret, 1) if $debug;
    }
    return $Ret;
  }elsif($field =~ /\.version$/s){
    warn __FILE__, ':', __LINE__, ' :>'.
      "Calling validation routine for version\n" if ($debug >= 3);
    return verify_timestamp(CMU::Netdb::cleanse($value), $user, $ul, $dbh);
  }else{
    warn __FILE__, ':', __LINE__, ' :>'.
      "No validity routine for '$field'; just cleansing data\n" if ($debug);
    return CMU::Netdb::cleanse($value);
  }
}

# given a return CMU::Netdb::valid from the CMU::Netdb::valid call, returns '1' if no error
# occurred (data is good to use) or the error code if not
sub getError {
  my ($in) = @_;
  if (substr($in, 0, 1) eq $INVALID) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::getError: Returning ".substr($in, 1) if ($debug >= 1);
    return substr($in, 1);
  }
  return 1;
}

# There are two possible default formats that a timestamp column can
# return.  In mysql 4.0 and previous, it returned as an integer
# formatted YYYYMMDDHHMMSS.  In 4.1 (as presumably after), the default
# return is a datetime string formatted 'YYYY-MM-DD HH-MM-SS'.  This
# function should accept either format.
#
# FIXME: We should be aware of what database version we're using and
# only accept the right format,
sub verify_timestamp {
  my ($in, $user, $ul, $dbh) = @_;
  return $in if ($in =~ /^\d{14}$/);
  return $in if ($in =~ /^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/);
  return "$INVALID$errcodes{EINVALID}";
}


# Function: CMU::Netdb::validtable
# Arguments: 3:
#     The name of the table
# Actions:
#     Just a placeholder for now
#     Eventually this will check that the given table actually exists
# Return value: 1 if CMU::Netdb::valid, 0 if inCMU::Netdb::valid

sub validtable {
  my ($table);
  
  return 1;
}

# Returns a valid limit statement.
sub verify_limit {
  my ($start, $run) = @_;
  
  my $StP = verify_integer_err_default($start);
  my $RunP = verify_integer_err_default($run);
  $StP = 0 if (getError($StP) != 1);
  $RunP = 0 if (getError($RunP) != 1);
  return " LIMIT $StP, $RunP ";  
}

# Returns a valid ORDER BY statement
sub verify_orderby {
  my ($field) = @_;
  if ($field =~ /^[a-zA-Z0-9\.\_\-]+$/) {
    return " ORDER BY $field ";
  }else{
    return '';
  }
}

# MAC Address Verification
# address can be specified in the following formats:
#  - 00aabbccddee
#  - 00:aa:bb:cc:dd:ee
#  - 0:a:b:c:d:e (assume leading 0s)
#  - 00aa.bbcc.ddee
#  - 00-aa-bb-cc-dd-ee
# Output is in a format suitable for insert into the database
# (6 chars)

sub verify_macaddress {
  my ($in, $user, $ul, $dbh) = @_;
  my (@components);
  
  $in = uc($in);
  return $in if ($in eq '');
  $in =~ s/^\s*//;
  $in =~ s/\s*$//;

  if ($in =~ /\./) {
    my @a = split(/\./, $in);
    map { push(@components, (substr($_, 0, 2), substr($_, 2, 2))) } @a;
  }elsif($in =~ /\:/) {
    @components = split(/\:/, $in);
    @components = map { if (length($_) == 1) { "0".$_ } else { $_ } } @components;
  }elsif($in =~ /\-/) {
    @components = split(/\-/, $in);
  }else{
    return "$INVALID$errcodes{EINVALID}" 
      unless ($in =~ /^[A-F0-9]{12}$/s);
    @components = map { substr($in, $_, 2) } (0,2,4,6,8,10);
  }
  my $rstring = join('', @components);
  ## PPP Adapter Addresses
  return "$INVALID$errcodes{EINVALID}" if ($rstring =~ /^44455354/s ||
					   $rstring =~ /^00534500/s);
  ## AOL Adapter
  return "$INVALID$errcodes{EINVALID}" if ($rstring =~ /^00038A/si);
  return "$INVALID$errcodes{EINVALID}" 
    unless ($rstring =~ /^[A-F0-9]{12}$/s);
  if ($ul < 9) {
    # Level 9 users can bypass STOLEN check.
    my $zref = CMU::Netdb::list_machines($dbh, 'netreg',
					 " machine.mac_address = '$rstring' AND FIND_IN_SET('stolen', machine.flags)");
    return "$INVALID$zref" if (!ref $zref);
    my @sref = @{$zref};
    if ($#sref > 0) {
  my ($stres, $Stolen_CC) = CMU::Netdb::config::get_multi_conf_var
                        ('netdb', 'STOLEN_ALERT_CC');
  my ($sttores, $Stolen_To) = CMU::Netdb::config::get_multi_conf_var
                        ('netdb', 'STOLEN_ALERT_TO');
      &CMU::Netdb::netdb_mail('CMU::Netdb::validity.pm:verify_macaddress', "User $user trying to register machine flagged STOLEN! (mac_address: $rstring)","NetReg Stolen Computer Alert",$Stolen_CC,$Stolen_To);
      return "$INVALID$errcodes{EEXISTS}" if ($#sref > 0);
    }
  }
  return $rstring;
}


sub verify_expires {
  my ($in) = @_;
  return $in if ($in eq '' || $in =~ /^\d{4}-\d{2}-\d{2}$/);
  return "$INVALID$errcodes{EINVCHAR}" unless ($in =~ /^\(now\(\) \+ interval \d+ day\)$/);
  return '*EXPR: '.$in;
}

sub verify_subnet_p_lastdone {
  my ($in) = @_;
  return $in if ($in eq '' || $in eq '0000-00-00' || $in =~ /\d\d\d\d-\d\d-\d\d/);
  return "$INVALID$errcodes{EINVCHAR}" unless ($in eq 'now()' || $in =~ /\A\d{4}-\d{2}-\d{2}\Z/);
  return '*EXPR: '.$in;
}

sub verify_datetime {
  my ($in) = @_;
  return $in if ($in eq '' || $in eq '0000-00-00');
  return $in if ($in =~ /^\A\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?\Z$/);
  return $in if ($in =~ /^\d{14}$/);
  return '*EXPR: now()' if ($in eq 'now()');
  return "$INVALID$errcodes{EINVCHAR}";
}

sub verify_created {
  my ($in) = @_;
  return '*EXPR: now()';
}

# Integer verification
sub verify_integer_n_def {
  my ($in, $v) = @_;
  $in = $v if ($in eq '');
  return "$INVALID$errcodes{ENONUM}" unless ($in =~ /^\d+$/s);
  return $in;
}

sub verify_integer_0_default { verify_integer_n_def($_[0], 0); }
sub verify_integer_1_default { verify_integer_n_def($_[0], 1); }
sub verify_integer_14_default { verify_integer_n_def($_[0], 14); }
sub verify_integer_600_default { verify_integer_n_def($_[0], 600); }
sub verify_integer_3600_default { verify_integer_n_def($_[0], 3600); }
sub verify_integer_86400_default { verify_integer_n_def($_[0], 86400); }
sub verify_integer_3600000_default { verify_integer_n_def($_[0], 3600000); }

sub verify_integer_err_default {
  my ($in) = @_;
  return "$INVALID$errcodes{ENONUM}" unless (defined $in && $in =~ /^\d+$/s);
  return $in;
}

sub verify_integer_blank_default {
  my ($in) = @_;
  return '' if (!defined $in || $in eq '');
  return "$INVALID$errcodes{ENONUM}" unless ($in =~ /^\d+$/s);
  return $in;
}

sub verify_integer_undef_default {
  my ($in) = @_;
  return undef if (!defined $in || $in eq '');
  return "$INVALID$errcodes{ENONUM}" unless ($in =~ /^\d+$/s);
  return $in;
}

# Machine Mode verification
sub verify_machine_mode {
  my ($in, $user, $ul, $dbh) = @_;
  my (@template, $var, @in);

  @template = @CMU::Netdb::structure::subnet_registration_modes_modes;

  @in = split(/\,/, $in);
  
  return verify_set(\@in, \@template);
}

sub verify_registration_mode_macaddr {
  my ($in, $user, $ul, $dbh) = @_;
  my (@template, $var, @in);

  @template = @CMU::Netdb::structure::subnet_registration_modes_mac_address;

  @in = split(/\,/, $in);
  
  return verify_set(\@in, \@template);
}

sub verify_ddns_auth {
  my ($in) = @_;
  #  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 128);
  return "$INVALID$errcodes{EINVCHAR}" unless ($in =~ /^[A-Za-z0-9\(\)\,\.\-\ \_\/\:\=\;]*$/s);
  return $in;
}

sub verify_dns_zone_type {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::dns_zone_types);
}

sub verify_outlet_device {
  my ($in, $user, $ul, $dbh) = @_;
  return $in if ($in eq '');
  return verify_host($in, $user, $ul, $dbh);
}

# all the fun of basic hostname verification, plus a little extra
# domain validation fun thrown in for good measure
sub verify_hostname_zone_lookup {
  my ($in, $user, $ul, $dbh) = @_;
  my (@parts, $host, $domain, $zref, @sref, $res);
  
  $in = uc($in);
  
  ($host, $domain) = CMU::Netdb::splitHostname($in);

  return "$INVALID$errcodes{EPERM}" if (lc($host) eq 'localhost' && $ul < 9);
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "verify_hostname_zone_lookup:: host: $host, domain: $domain, userlevel: $ul\n" if ($debug >= 2);
  
  return $in if ($in eq '.' && $ul >= 9);

  if ($in =~ /\.IN\-ADDR\.ARPA$/is) {
    $res = &verify_hostname_arpa($in,$user,$ul,$dbh);
    return $res if (CMU::Netdb::getError($res) != 1);
  } else {
    return "$INVALID$errcodes{ETOOSHORT}" if (length($host) < 2 && $ul < 9);
    return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);
    return "$INVALID$errcodes{ETOOLONG}" if (length($host) > 63);
    # Disallow underscore and dash as first character of hostname component
    # because ISC dhcpd won't allow it.
    return "$INVALID$errcodes{EINVCHAR}" 
      unless ($host =~ /^([A-Z\d]|[A-Z\d][A-Z\d\-\_]*[A-Z\d\_]+)$/is);
    return "$INVALID$errcodes{EINVCHAR}" 
      unless ($in =~ /^[A-Z\d\_][A-Z\.\d\-\_]*[A-Z\d\_]+$/is);

    my ($cres, $cval) = CMU::Netdb::config::get_multi_conf_var
                        ('netdb', 'VALIDATE_ALL_NUMERIC_HOSTNAMES');
    if (!($cres == 1 && $cval == 1)) {
      # Disallow all numeric hostnames for non admins
      return "$INVALID$errcodes{EINVCHAR}"
          if ($host =~ /^\d+$/is && $ul < 9);
    }
  }
  
  $zref = CMU::Netdb::list_zone_ref($dbh, $user,
				    " dns_zone.name = '$domain'", 'GET');
  return "$INVALID$errcodes{EDOMAIN}" if (!ref $zref);
  @sref = keys %{$zref};
  
  return "$INVALID$errcodes{EDOMAIN}" if ($#sref != 0);
  return $in;
}

sub verify_domain {
  my ($in, $user, $ul, $dbh) = @_;
  $in = uc($in);
  my $zref = CMU::Netdb::list_zone_ref($dbh, $user,
				       " dns_zone.name = '$in'", 'GET');
  return "$INVALID$errcodes{EDOMAIN}" if (!ref $zref);
  my @sref = keys %{$zref};
  
  return "$INVALID$errcodes{EDOMAIN}" if ($#sref != 0);
  return $in;
}

### NOT for testing if they are allowed to use this host. We're assuming
## people are smart enough not to... (and only netreg:admins can do so anyway)
sub verify_host {
  my ($in, $user, $ul, $dbh) = @_;
  my (@parts, $host, $domain, $zref, @sref);
  
  ($host, $domain) = CMU::Netdb::splitHostname($in);
  
  return "$INVALID$errcodes{ETOOSHORT}" if (length($host) < 2 && $ul < 9);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);
  return "$INVALID$errcodes{ETOOLONG}" if (length($host) > 63);
  return "$INVALID$errcodes{EINVCHAR}" 
    unless ($host =~ /^([A-Z\d]|[A-Z\d][A-Z\d\-]*[A-Z\d]+)$/si);
  return "$INVALID$errcodes{EINVCHAR}" 
    unless ($in =~ /^[A-Z\d][A-Z\.\d\-]*[A-Z\d]+$/si);
 return "$INVALID$errcodes{EINVCHAR}"
    if ($host =~ /^\d+$/is);

  my ($cres, $cval) = CMU::Netdb::config::get_multi_conf_var
                        ('netdb', 'VALIDATE_ALL_NUMERIC_HOSTNAMES');
  if (!($cres == 1 && $cval == 1)) {
    # Disallow all numeric hostnames for non admins
    return "$INVALID$errcodes{EINVCHAR}"
        if ($host =~ /^\d+$/is && $ul < 9);
  }
  
  $zref = CMU::Netdb::list_machines($dbh, 'netreg',
				    " machine.host_name = '$in'");
  return "$INVALID$zref" if (!ref $zref);
  @sref = @{$zref};
  return "$INVALID$errcodes{EHOST}" if ($#sref < 1);
  
  $zref = CMU::Netdb::list_zone_ref($dbh, 'netreg',
				    " dns_zone.name = '$domain'", "GET");
  return "$INVALID$zref" if (!ref $zref);
  @sref = keys %{$zref};
  
  return "$INVALID$errcodes{EDOMAIN}" if ($#sref != 0);
  return uc($in);
}

# Hostname verification
# The host part must be 63 bytes or less
# The entire hostname must be 255 bytes or less
# The host part must:
#   - be 63 bytes or less
#   - begin with a letter
#   - end with a letter or number
#   - contain only letters, numbers, or hyphens in the middle

sub verify_hostname {
  my ($in, $user, $ul, $dbh) = @_;
  my (@parts);
  
  return &verify_hostname_arpa($in,$user,$ul,$dbh)
    if ($in =~ /\.IN\-ADDR\.ARPA$/is);
  
  my ($host, $domain) = CMU::Netdb::splitHostname($in);
  warn __FILE__, ':', __LINE__, ' :>'.
    "verify_hostname: $in, $host, $domain, userlevel $ul\n" if ($debug >= 2);
  return "$INVALID$errcodes{ETOOSHORT}" if (length($host) < 2 && $ul < 9);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);
  return "$INVALID$errcodes{ETOOLONG}" if (length($host) > 63);
  return "$INVALID$errcodes{EINVCHAR}" 
    unless ($host =~ /^([A-Z\d]|[A-Z\d][A-Z\d\-]*[A-Z\d]+)$/is);
  return "$INVALID$errcodes{EINVCHAR}" 
    unless ($in =~ /^[A-Z\d][A-Z\.\d\-]*[A-Z\d]+$/is);
  return "$INVALID$errcodes{EINVCHAR}"
    if ($host =~ /^\d+$/is && $ul < 9);

  my ($cres, $cval) = CMU::Netdb::config::get_multi_conf_var
			('netdb', 'VALIDATE_ALL_NUMERIC_HOSTNAMES');
  if (!($cres == 1 && $cval == 1)) {
    # Disallow all numeric hostnames for non admins
    return "$INVALID$errcodes{EINVCHAR}"
        if ($host =~ /^\d+$/is && $ul < 9);
  }
  
  #  No reason for this to be unique. -vitroth
  #  my $lref = CMU::Netdb::list_machines($dbh, $user, "machine.host_name = '$in'");
  #  if ($#$lref > 0) {
  #    return "$INVALID$errcodes{EEXISTS}";
  #  }
  return $in;
}

# Hostname verification for dns resources, extra magic (underscores) allowed
# The host part must be 63 bytes or less
# The entire hostname must be 255 bytes or less
# The host part must:
#   - be 63 bytes or less
#   - begin with a letter
#   - end with a letter or number
#   - contain only letters, numbers, or hyphens in the middle

sub verify_hostname_und_allow {
  my ($in, $user, $ul, $dbh) = @_;
  my (@parts);
 
  return &verify_hostname_arpa($in,$user,$ul,$dbh)
    if ($in =~ /\.IN\-ADDR\.ARPA$/is);
 
  return $in if ($in eq '.' && $ul >= 9);

  my ($host, $domain) = CMU::Netdb::splitHostname($in);
  warn __FILE__, ':', __LINE__, ' :>'.
    "verify_hostname: $in, $host, $domain, userlevel $ul\n" if ($debug >= 2);
  return "$INVALID$errcodes{ETOOSHORT}" if (length($host) < 2 && $ul < 9);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);
  return "$INVALID$errcodes{ETOOLONG}" if (length($host) > 63);
  return "$INVALID$errcodes{EINVCHAR}" 
    unless ($host =~ /^([_A-Z\d]|[_A-Z\d][_A-Z\d\-]*[_A-Z\d]+)$/is);
  return "$INVALID$errcodes{EINVCHAR}" 
    unless ($in =~ /^[_A-Z\d][_A-Z\.\d\-]*[_A-Z\d]+$/is);
  return "$INVALID$errcodes{EINVCHAR}"
    if ($host =~ /^\d+$/is && $ul < 9);

  my ($cres, $cval) = CMU::Netdb::config::get_multi_conf_var
                        ('netdb', 'VALIDATE_ALL_NUMERIC_HOSTNAMES');
  if (!($cres == 1 && $cval == 1)) {
    # Disallow all numeric hostnames for non admins
    return "$INVALID$errcodes{EINVCHAR}"
        if ($host =~ /^\d+$/is && $ul < 9);
  }

  #  No reason for this to be unique. -vitroth
  #  my $lref = CMU::Netdb::list_machines($dbh, $user, "machine.host_name = '$in'");
  #  if ($#$lref > 0) {
  #    return "$INVALID$errcodes{EEXISTS}";
  #  }
  return $in;
}

# Hostname verification for IN-ADDR.ARPA stuff
# The host part must be 63 bytes or less
# The entire hostname must be 255 bytes or less
# The host part must:
#   - be 63 bytes or less
#   - begin with a letter
#   - end with a letter or number
#   - contain only letters, numbers, or hyphens in the middle

sub verify_hostname_arpa {
  my ($in, $user, $ul, $dbh) = @_;
  
  warn __FILE__, ':', __LINE__, ' :>'.
    "verify_hostname_arpa: $in\n" if ($debug >= 2);
  return "$INVALID$errcodes{ETOOSHORT}" if (length($in) < 14);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);
  return "$INVALID$errcodes{EINVCHAR}"
    unless ($in =~ /^([0-9]{1,3}\.){1,4}IN\-ADDR\.ARPA$/is);
  return $in;
}


# IP Address Verification
# Given an IP address in a format, returns the address as a long, suitable
# for insert into the database
# Input format may be:
#  - aaa.bbb.ccc.ddd
#  - a 32 bit unsigned integer (already in db format)
sub verify_ip {
  my ($in) = @_;
  
  return $in if ($in =~ /^\d+$/ && $in >= 0 && $in <= (2**32 - 1));
  return "$INVALID$errcodes{EDATA}" unless ($in =~ /^\d+\.\d+\.\d+\.\d+$/s);
  
  return CMU::Netdb::dot2long($in);
}

sub verify_ip_null_ok {
  my ($in) = @_;
  
  return $in if ($in eq '');
  warn __FILE__, ':', __LINE__, ' :>'.
    "verify_ip: $in\n" if ($debug >= 2);
  return "$INVALID$errcodes{EDATA}" unless ($in =~ /^\d+\.\d+\.\d+\.\d+$/s);
  my @b = split(/\./, $in);
  map { return "$INVALID$errcodes{ERANGE}" if ($_ < 0 || $_ > 255) } @b;
  
  return CMU::Netdb::dot2long($in);
}

# User name verification
# The name must:
#   - not have any chars other than A-Za-z0-9.@-_!/et
#   - be less than 255 chars
#   - have at least 1 char
sub verify_cred_authid {
  my ($in, $user, $ul, $dbh) = @_;

  return "$INVALID$errcodes{EINVCHAR}" unless (defined $in);
  return "$INVALID$errcodes{EINVCHAR}" 
      unless ($in =~ /^[A-Za-z0-9\.\@\-\_]+$/s);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);
  return $in;
}

sub verify_cred_authid_perm {
  my ($in, $user, $ul, $dbh) = @_;

  return "$INVALID$errcodes{EINVCHAR}" unless (defined $in);
  return "$INVALID$errcodes{EINVCHAR}"
      unless ($in =~ /^[A-Za-z0-9\.\@\-\_]+$/s);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);

  # Check to see if they are suspended
  return "$INVALID$errcodes{EUSERSUSPEND}"
    if (CMU::Netdb::auth::get_user_admin_status($dbh, $in) == -1);

  return $in;
}

## _sys_changerec_row.type verification
sub verify_changerec_row_type {
  return verify_enum($_[0], \@CMU::Netdb::structure::sys_changerec_row_type);
}

# User Flags Verification
# Make sure that all the flags are CMU::Netdb::valid
sub verify_users_flags {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::users_flags);
}

# Rights verification
sub verify_rights {
  my ($in) = @_;
  return "$INVALID$errcodes{EBLANKSET}" if ($in eq '');
  my @inright = split(/\,/, $in);
  my @rights = ('READ', 'WRITE', 'ADD');
  return verify_set(\@inright, \@rights);
}

# Group name verification
# The name must:
#   - not have any chars other than A-Za-z0-9, dashes and colons
#   - be less than 32 chars
#   - have at least 1 char on either side of any colon
sub verify_groups_name {
  my ($in) = @_;
  return "$INVALID$errcodes{EINVCHAR}" unless ($in =~ /^[A-Za-z0-9]+(\:[A-Za-z0-9-]+)+$/s);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 32);
  return $in;
}

# Group Flags Verification
# Make sure that all the flags are CMU::Netdb::valid
sub verify_groups_flags {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::groups_flags);
}

# Machine Flags Verification
# Make sure that all the flags are CMU::Netdb::valid
sub verify_machine_flags {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  warn __FILE__, ':', __LINE__, ' :>'.
    "inflags: ".join(',', @inflags)." ; machine flags: ".
      join(',', @CMU::Netdb::structure::machine_flags) if ($debug > 5);
  return verify_set(\@inflags, \@CMU::Netdb::structure::machine_flags);
}

# Called by functions that have a 'set' as the type
sub verify_set {
  my ($in, $template) = @_;
  my @tmp;
  my $result = 1;
  my %thash = map { lc($_) => 1 } @$template;
  foreach (@$in) {
    push @tmp, $_ if ($_ ne '') 
  }
  map { $result = 0 unless (defined $thash{lc($_)}) } @tmp;
  return "$INVALID$errcodes{ESETMEM}" unless $result;
  return join(',', @tmp);
}

# verify that DHCP option format is valid
#
# The verification routines accept basic contructs:
#  BOOLEAN, INTEGER, IP-ADDRESS, TEXT, STRING, RAW.
# And advanced constructs:
#  ARRAY OF <other type>
#  ENCAPSULATION <name of option>
#  { <type> [, <type>] }
#
sub verify_dhcp_option_format {
  my ($in) = @_;
  $in = uc($in);
  $in =~ s/^\s*//;
  $in =~ s/\s*$//;
  $in =~ s/(\S)(\,|\{|\})/$1 $2/g;
  $in =~ s/(\,|\{|\})(\S)/$1 $2/g;
  
  my @Tokens = split(/\s+/, $in);
  
  my $Res = verify_dhcp_of_recurse(\@Tokens, 0, []);
  return $in if ($Res > 0);
  return "$INVALID$errcodes{EDATA}";
}

sub verify_dhcp_of_recurse {
  my ($rTokens, $Pos, $rContinue) = @_;
  
  my $Head = shift(@$rTokens);
#  print "OF: $Head $Pos\n";
  if ($Pos == 0 || $Pos == 1) {
    if ($Head eq 'BOOLEAN' ||
        $Head eq 'INTEGER' ||
        $Head eq 'IP-ADDRESS' ||
        $Head eq 'TEXT' ||
        $Head eq 'STRING' ||
	$Head eq 'RAW') {
      return -1 if ($Pos == 1 && ($Head eq 'TEXT' || $Head eq 'STRING'));
      pop(@$rTokens) if ($Head eq 'INTEGER' && $#$rTokens > -1 && $rTokens->[0] =~ /^(8|16|32)$/);
      goto DOF_ACCEPT_OR_CONTINUE;
    }elsif($Head eq 'ARRAY') {
      return verify_dhcp_of_recurse($rTokens, 10, $rContinue);
    }elsif($Head eq 'ENCAPSULATION') {
      return verify_dhcp_of_recurse($rTokens, 20, $rContinue);
    }elsif($Head eq '{') {
      ## Records, ugh.
      push(@$rContinue, 30);
      return verify_dhcp_of_recurse($rTokens, 0, $rContinue);
    }elsif($Head eq 'SIGNED' || $Head eq 'UNSIGNED') {
      return verify_dhcp_of_recurse($rTokens, 0, $rContinue);
    }      
  }elsif($Pos == 10) {
    ## Array
    if ($Head eq 'OF') {
      return verify_dhcp_of_recurse($rTokens, 1, $rContinue);
    }
  }elsif($Pos == 20) {
    ## Encapsulation - basically accept anything
    goto DOF_ACCEPT_OR_CONTINUE;
  }elsif($Pos == 30) {
    ## Record continuation
    if ($Head eq ',') {
      push(@$rContinue, 30);
      return verify_dhcp_of_recurse($rTokens, 0, $rContinue);
    }elsif($Head eq '}') {
      goto DOF_ACCEPT_OR_CONTINUE;
    }
  }
  
  return -1;
  
 DOF_ACCEPT_OR_CONTINUE:
  # Reject if:
  #  - no more tokens, but more continuations
  #  - more tokens, but no more continuations
  # Accept if:
  #  - no more tokens, and no more continuations
  # Otherwise:
  #  - recurse on the next continuation
  return -1 if ( ($#$rTokens == -1 && $#$rContinue != -1) ||
                 ($#$rTokens != -1 && $#$rContinue == -1));
  return 1 if ( $#$rTokens == -1 && $#$rContinue == -1);
  my $Next = pop(@$rContinue);
  return verify_dhcp_of_recurse($rTokens, $Next, $rContinue);
}


# Validate a given option string on the format
sub verify_dhcp_option_value {
  my ($data, $format) = @_;
  
  my @Tokens = split(/\s+/, $format);
  
  $data =~ s/(\S)\,/$1 ,/g;
  $data =~ s/\,(\S)/\, $1/g;
  my @Data = split(/\s+/, $data);
  
  my $Res = verify_dhcp_ov_recurse(\@Tokens, \@Data, 0, []);
  return $data if ($Res > 0);
  return "$INVALID$errcodes{EDATA}";
}

sub verify_dhcp_ov_recurse {
  my ($rTokens, $rData, $Pos, $rContinue) = @_;
 
  warn __FILE__ . __LINE__ . Data::Dumper->Dump([$rTokens, $rData, $Pos, $rContinue], ['rTokens', 'rdata', 'Pos', 'rContinue']) if ($debug >= 2);
  # Special case: empty lines with type RAW are okay
  return 1
    if ($#$rTokens == 0 && $rTokens->[0] eq 'RAW' && $#$rData == -1);
  
  ## Pos == 0: default; 1: "array of" verification,
  ##  3: unsigned integer verification
  if ($Pos < 10) {
    my $Head = shift(@$rTokens);
    #print "OV: $Head $Pos\n";
    if ($Head eq 'BOOLEAN') {
      return -1 if ($#$rData == -1);
      my $HD = shift(@$rData);
      return -1 unless ($HD =~ /^(on|off|yes|no)$/i);
      goto DOV_ACCEPT_OR_CONTINUE;
    }elsif($Head eq 'INTEGER') {
      return -1 if ($#$rData == -1);
      my $HD = shift(@$rData);
      
      return -1 if ($HD =~ /^\-/ && $Pos == 3);
      return -1 unless ($HD =~ /^(\-?[0-9]+)$/);
      my $Integer = $1;
      
      # Determine if there is a bit limit
      if ($#$rTokens > -1 && $rTokens->[0] =~ /^(8|16|32)$/) {
        my $Limit = pop(@$rTokens);
        my $value = 2**$Limit;
	if ($Pos == 3) {
	  return -1 if ($Integer > $value);
	}else{
	  if ($Integer < 0) {
	    return -1 if ($Integer >> ($Limit - 1) != ( (1<<(32-$Limit+1))-1) )
	  }else{
	    return -1 if ($Integer >> ($Limit - 1) != 0);
	  }
	}
      }

	      goto DOV_ACCEPT_OR_CONTINUE;
    }elsif($Head eq 'IP-ADDRESS') {
      return -1 if ($#$rData == -1);
      my $HD = shift(@$rData);
      
      goto DOV_ACCEPT_OR_CONTINUE
        if ($HD =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);
      goto DOV_ACCEPT_OR_CONTINUE
        if (CMU::Netdb::getError(verify_hostname($HD, 'netreg', 9, 0)) == 1);
      return -1;
    }elsif($Head eq 'RAW') {
      return 1;
    }elsif($Head eq 'TEXT') {
      return -1 if ($#$rData == -1 || $Pos == 1);
      my $HD = shift(@$rData);
      return -1 unless ($HD =~ /^\"/);
      return -1 if ($HD =~ /.\"./);
      $HD =~ s/^\"//;		## We want to allow a single standalone quote to open
      while ($HD !~ /\"$/) {
        return -1 if ($#$rData == -1);
        $HD = shift(@$rData);
	return -1 if ($HD =~ /\"./);
      }
      goto DOV_ACCEPT_OR_CONTINUE;
    }elsif($Head eq 'STRING') {
      return -1 if ($#$rData == -1 || $Pos == 1);
      my $HD = shift(@$rData);
      if ($HD =~ /^\"/) {
	return -1 if ($HD =~ /.\"./);
	$HD =~ s/^\"//;
        while($HD !~ /\"$/) {
          return -1 if ($#$rData == -1);
          $HD = shift(@$rData);
	  return -1 if ($HD =~ /\"./);
        }
      }else{
	return -1 if ($HD =~ /\:\:/);
        my @Elem = map {
          return -1 unless ($_ =~ /^[0-9a-f]?[0-9a-f]$/i);
        } split(/\:/, $HD);
      }
      goto DOV_ACCEPT_OR_CONTINUE;
    }elsif($Head eq 'ARRAY') {
      # Just pop off the OF, and get to the data
      return -1 if ($#$rTokens < 1 || $rTokens->[0] ne 'OF');
      shift(@$rTokens);
      
      # Since it's an array, we need to keep a copy of the
      # current token list to continue. Also, the continuations
      # are replaced so we get back here.
      my @Tok = @$rTokens;
      while(1) {
        my @SendTok = @Tok;
	warn "Verifying token $SendTok[0]/$rData->[0]\n\n" if ($debug);
        my $Res = verify_dhcp_ov_recurse(\@SendTok, $rData, 1, [11]);
        return $Res if ($Res < 1);
	warn "Token OK\n" if ($debug);
        # Successful verification of array element. Check for a comma.
        # No comma == continue
        if ($#$rData != -1 && $rData->[0] eq ',') {
          # Have a comma.
	  shift(@$rData);
          next;
        }else{
          # Don't have a comma (or there is no more data)
	  #print "no comma/sendtok: ".join(',', @SendTok)."\n";
          # The tokens as they stand by the last round need to be passed along.
          @$rTokens = @SendTok;
          # Data is okay, we haven't messed with it.
          # We passed along a fresh continuation, so the continuation
          #  known by the goto is fine.
          goto DOV_ACCEPT_OR_CONTINUE;
        }
      }
    }elsif($Head eq 'ENCAPSULATION') {
      return -1;
    }elsif($Head eq '{') {
      push(@$rContinue, 30);
      return verify_dhcp_ov_recurse($rTokens, $rData, 0, $rContinue);
    }elsif($Head eq 'SIGNED') {
      return verify_dhcp_ov_recurse($rTokens, $rData, 0, $rContinue);
    }elsif($Head eq 'UNSIGNED') {
      return verify_dhcp_ov_recurse($rTokens, $rData, 3, $rContinue);
    }
  }elsif($Pos == 30) {
    ## Record continuation
    my $Head = shift(@$rTokens);
    
    if ($Head eq ',') {
      push(@$rContinue, 30);
      return verify_dhcp_ov_recurse($rTokens, $rData, 0, $rContinue);
    }elsif($Head eq '}') {
      goto DOV_ACCEPT_OR_CONTINUE;
    }
  }
  
  return -1;
  
 DOV_ACCEPT_OR_CONTINUE:
  # Reject if:
  #  - no more tokens, but more continuations
  #  - more tokens, but no more continuations
  #  - no more tokens, no more continuations, more data
  # Accept if:
  #  - no more tokens, and no more continuations
  # Otherwise:
  #  - recurse on the next continuation
  
  #  print "DOV_ACCEPT: ".join(',', @$rContinue)." -- ".join(',', @$rTokens)." -- ".join(',', @$rData)."\n";
  ## Continuation of 11 means we should just return -- array will 
  ## take care of it.
  return 1 if ($#$rContinue > -1 && $rContinue->[$#$rContinue] == 11);
  return -1 if ( ($#$rTokens == -1 && $#$rContinue != -1) ||
                 ($#$rTokens != -1 && $#$rContinue == -1));
  
  return 1 if ( $#$rTokens == -1 && $#$rContinue == -1 && $#$rData == -1);
  my $Next = pop(@$rContinue);
  return verify_dhcp_ov_recurse($rTokens, $rData, $Next, $rContinue);
}

sub verify_dopt_string {
  my ($in) = @_;
  $in =~ s/\\\\\"/\"/gs;
  return "$INVALID$errcodes{EINVCHAR}" 
    unless ($in =~ /^[A-Za-z0-9\(\)\,\.\-\ \\\_\/\"\=\[\]\{\}\<\>\?\:\;]*$/s);
  return $in;
}

sub verify_dhcp_option_type {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::dhcp_option_types);
}

sub verify_dns_resource_owner {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::dns_resource_owner_types);
}

sub verify_dns_type_format {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::dns_type_formats);
}

sub verify_comment {
  my ($in) = @_;

  return "$INVALID$errcodes{EBLANK}" unless (defined $in);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > 255);
  return "$INVALID$errcodes{EINVCHAR}" unless ($in =~ /^[A-Za-z0-9\(\)\,\.\-\ \_\/\:\<\>]*$/s);
  return $in;
}

sub verify_bstring_n {
  my ($in, $cnt) = @_;

  return "$INVALID$errcodes{EBLANK}" unless (defined $in);
  return "$INVALID$errcodes{ETOOLONG}" if (length($in) > $cnt);
  return "$INVALID$errcodes{EINVCHAR}" unless ($in =~ /^[A-Za-z0-9\(\)\,\.\-\ \_\/\:]*$/s);
  return $in;
}

# just verify that it's actually less than 64 chars and 
# contains acceptable chars
sub verify_bstring_2   { return verify_bstring_n($_[0], 2  ); }
sub verify_bstring_8   { return verify_bstring_n($_[0], 8  ); }
sub verify_bstring_16  { return verify_bstring_n($_[0], 16 ); }
sub verify_bstring_32  { return verify_bstring_n($_[0], 32 ); }
sub verify_bstring_64  { return verify_bstring_n($_[0], 64 ); }
sub verify_bstring_128 { return verify_bstring_n($_[0], 128); }
sub verify_bstring_252 { return verify_bstring_n($_[0], 252); }
sub verify_bstring_255 { return verify_bstring_n($_[0], 255); }

sub verify_subnet_dynamic {
  return verify_enum($_[0], \@CMU::Netdb::structure::subnet_dynamic);
}

sub verify_subnet_default_mode {
  return verify_enum($_[0], \@CMU::Netdb::structure::subnet_default_mode);
}

sub verify_table_name {
  return "$INVALID$errcodes{EBLANK}" unless (defined $_[0] && $_[0] ne '');
  return verify_enum($_[0], \@CMU::Netdb::structure::valid_tables);
}

# Verify that a given table field exists
sub verify_table_field {
  my ($in) = @_;

  my ($table, $col) = split(/\./, $in, 2);
  my $Ret = verify_table_name($table);
  if (getError($Ret) != 1) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "verify_table_field returning ESETMEM: $table did not validate"
	if ($debug >= 1);
    return $Ret;
  }

  my $TArray = "CMU::Netdb::structure::${table}_fields";
  {
    no strict 'refs';
    # Can't verify as the array doesn't exist.. but structure.pl tests this
    return $in unless (defined @{$TArray});
  }

  my @SFields;
  eval '@SFields = @'.$TArray.';';
  return $in if (grep(/^$table.$col$/, @SFields));
  warn __FILE__, ':', __LINE__, ' :>'.
    "verify_table_field returning ESETMEM: $table/$col (from $in) ".
      "did not validate" if ($debug >= 1);
  return "$INVALID$errcodes{ESETMEM}";
}

sub verify_table_name_mult {
  my ($in) = $_[0];

  return "$INVALID$errcodes{EBLANK}" unless (defined $in && $in ne '');

  my %VT = map { (lc($_), 1) } @CMU::Netdb::structure::valid_tables;

  my @intables = split(/\s*\,\s*/, $in);
TVERIFY:
  foreach my $T (@intables) {
    next TVERIFY if (defined $VT{lc($T)});

    my @Tok = split(/\s+/, $T);
    my $Loc = 0;
    while(scalar(@Tok) > 0) {
      my $CT = shift(@Tok);
      next if ($CT eq '');

      warn __FILE__, ':', __LINE__, ' :>'.
	"Processing $CT (loc $Loc)" if ($debug >= 2);

      # Quote handling
      if ($CT =~ /^\"/) {
	my $agg;
	do {
	  $agg .= $CT;
	} while($CT !~ /\"$/ && ($CT = shift(@Tok)));
	$CT = $agg;
	unless ($CT =~ /^\"[^\"]+\"$/) {
	  # Error
	  $Loc = 902;
	  next;
	}
      }

      if ($Loc == 0) {
	unless (defined $VT{lc($CT)}) {
	  $Loc = 901;
	  next;
	}
	$Loc = 1;
      }elsif($Loc == 1) {
	next if (uc($CT) eq 'LEFT');
	if (uc($CT) eq 'JOIN') {
	  $Loc = 2;
	  next;
	}

	# Error
	$Loc = 902;
      }elsif($Loc == 2) {
	# (LEFT?) JOIN
	unless (defined $VT{lc($CT)}) {
	  $Loc = 903;
	  next;
	}
	$Loc = 3;
      }elsif($Loc == 3) {
	# (LEFT?) JOIN machine
	unless (uc($CT) eq 'ON') {
	  $Loc = 904;
	  next;
	}
	$Loc = 4;
      }elsif($Loc == 4) {
	# (LEFT?) JOIN machine ON
	if ($CT =~ /^\".*\"$/) {
	  $Loc = 5;
	  next;
	}elsif($CT =~ /^(\S+\.\S+)$/) {
	  my $Ret = verify_table_field($CT);
	  if (getError($Ret) != 1) {
	    warn __FILE__, ':', __LINE__, ' :>'.
	      "verify_table_name_mult error in table verification ($CT): $Ret";
	    return $Ret;
	  }
	  $Loc = 5;
	  next;
	}

	$Loc = 905;
      }elsif($Loc == 5) {
	# (LEFT?) JOIN machine ON machine.id
	if ($CT eq '=') {
	  $Loc = 6;
	  next;
	}
	$Loc = 906;
      }elsif($Loc == 6) {
	# (LEFT?) JOIN machine ON machine.id =
	if ($CT =~ /^\".*\"$/) {
	  $Loc = 101;
	  next;
	}elsif($CT =~ /^(\S+\.\S+)$/) {
	  my $Ret = verify_table_field($CT);
	  if (getError($Ret) != 1) {
	    warn __FILE__, ':', __LINE__, ' :>'.
	      "verify_table_name_mult error in table verification ($CT): $Ret";
	    return $Ret;
	  }
	  $Loc = 102;
	  next;
	}

	$Loc = 907;
      }elsif($Loc > 100 && $Loc < 200) {
	## Success conditions
	if (uc($CT) eq 'AND') {
	  $Loc = 4;
	}elsif(uc($CT) eq 'JOIN') {
	  $Loc = 2;
	}elsif(uc($CT) eq 'LEFT') {
	  $Loc = 1;
	}else{
	  warn __FILE__,  ':', __LINE__, ' :>'.
	    "verify_table_name_mult token after success ($CT)";
	  $Loc = 908;
	}
	next;
      }elsif($Loc > 900) {
	## Error conditions
	warn __FILE__,  ':', __LINE__, ' :>'.
	  "verify_table_name_mult error in JOIN parsing ($Loc)";
	return "$INVALID$errcodes{EINVCHAR}";
      }
    }
    unless ($Loc > 100 && $Loc < 200) {
      warn __FILE__,  ':', __LINE__, ' :>'.
	"verify_table_name_mult out of tokens in JOIN parsing ($Loc)";
      return "$INVALID$errcodes{EINVCHAR}";
    }
  }
  return $in;
}

sub verify_outlet_subnet_membership_type { return verify_enum($_[0], \@CMU::Netdb::structure::outlet_subnet_membership_type); }
sub verify_outlet_subnet_membership_trunk_type { return verify_enum($_[0], \@CMU::Netdb::structure::outlet_subnet_membership_trunk_type); }

sub verify_outlet_vlan_membership_type { return verify_enum($_[0], \@CMU::Netdb::structure::outlet_vlan_membership_type); }
sub verify_outlet_vlan_membership_trunk_type { return verify_enum($_[0], \@CMU::Netdb::structure::outlet_vlan_membership_trunk_type); }
sub verify_outlet_vlan_membership_status { return verify_enum($_[0],\@CMU::Netdb::structure::outlet_vlan_membership_status); }

sub verify_enum {
  my ($key, $template) = @_;
  map { return $_ if (lc($key) eq lc($_)); } @$template;
  return "$INVALID$errcodes{ESETMEM}";
}

# Verify that the share number going into the 'subnet' table exists
# in the subnet_share table    
sub verify_subnet_share {
  my ($in, $user, $ul, $dbh) = @_;
  
  my $lref = CMU::Netdb::list_subnet_shares($dbh, $user, "subnet_share.id = '$in'");
  if ($#$lref < 0) {
    return "$INVALID$errcodes{EINVALID}";
  }
  return $in;
}

### FIXME:
## Make sure when verifying subnet_share.name that 'None' is disallowed

sub verify_outlet_attributes {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::outlet_attributes);
}

sub verify_outlet_flags {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::outlet_flags);
}

sub verify_subnet_flags {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::subnet_flags);
}

sub verify_user_type_flags {
  my ($in) = @_;
  my @inflags = split(/\,/, $in);
  return verify_set(\@inflags, \@CMU::Netdb::structure::user_type_flags);
}

sub verify_outlet_status { return verify_enum($_[0], \@CMU::Netdb::structure::outlet_status); }


sub verify_dns_resource_type {
  my ($in, $user, $ul, $dbh) = @_;
  my $tyref = CMU::Netdb::get_dns_resource_types($dbh, $user, "dns_resource_type.name='$in'");
  return "$INVALID$errcodes{ENORESTYPE}" if (!ref $tyref);
  return "$INVALID$errcodes{ENORESTYPE}" if (!grep($in, values %$tyref));
  return $in;
}

sub verify_dhcp_option_type_id {
  my ($in, $user, $ul, $dbh) = @_;
  my $tyref = CMU::Netdb::get_dhcp_option_types($dbh, $user, "dhcp_option_type.id = '$in'");
  return "$INVALID$errcodes{ENOOPTTYPE}" if (!ref $tyref);
  my %types = %$tyref;
  return "$INVALID$errcodes{ENOOPTTYPE}" if (!defined $types{$in});
  return $in;
}

sub verify_cable_exists {
  my ($in, $user, $ul, $dbh) = @_;
  my $tyref = CMU::Netdb::buildings_cables::list_cables
    ($dbh, $user, "cable.id = '$in'");
  return "$INVALID$errcodes{ENOCABLE}" if (!ref $tyref);
  my %types = %$tyref;
  return "$INVALID$errcodes{ENOCABLE}" if (!defined $types{$in});
  return $in;
}

sub verify_outlet_type {
  my ($in, $user, $ul, $dbh) = @_;
  my $tyref = CMU::Netdb::buildings_cables::list_outlet_types_ref
    ($dbh, $user, 'GET', "outlet_type.id = '$in'");
  return "$INVALID$errcodes{ENOOUTTYPE}" if (!ref $tyref);
  my %types = %$tyref;
  return "$INVALID$errcodes{ENOOUTTYPE}" if (!defined $types{$in});
  return $in;
}

## Formats can be:
##   ustring:   Unlimited text string
##   stringNNN: String of length NNN (where NNN must be filled in)
##   int:       General integer
##   uint:      Unsigned integer
##   enum():    One of the strings in the enumeration, default to first
##   set():     One or more of the strings specified
sub verify_attr_spec_format {
  my ($in, $user, $ul, $dbh) = @_;
  
  my $lin = lc($in);
  # First the easy types
  return $lin if ($lin eq 'ustring' || $lin eq 'int' || $lin eq 'uint');
  
  # Sized strings, 1-255
  if ($in =~ /^(string)(\d{1,3})$/i) {
    return lc($1).$2 if ($2 > 0 && $2 < 256);
    return "$INVALID$errcodes{ERANGE}";
  }
  
  $in =~ s/\s*//g;
  # enums/sets
  if ($in =~ /^(enum|set)\(([^\)]+)\)$/) {
    my @elem = split(/\,/, $2);
    return "$INVALID$errcodes{EBLANKSET}" if ($#elem == -1);
    #    map { return "$INVALID$errcodes{EINVCHAR}" unless 
    #    ($_ =~ /^[A-Za-z0-9\-\_\.]+$/); 
    #	} @elem;
    return lc($1)."(".join(',', @elem).")";
  }
  return "$INVALID$errcodes{EDATA}";
}

# Check if the new format completely includes the old format
# so that we can see if everything is still valid.
sub verify_attr_spec_format_compat {
  my ($old, $new) = @_;
  return 1 if ($old eq $new);
  return 1 if ($new eq 'ustring');
  if ($new =~ /^string(\d{1,3})$/) {
    my $lenNew = $1;
    if ($old =~ /^string(\d{1,3})$/) {
      return 1 if ($new >= $1);
    }
    return 0;
  }
  return 1 if ($new eq 'int' && $old eq 'uint');
  if ($new =~ /^(enum|set)\(([^\)]+)\)$/) {
    my $NewTy = $1;
    my @elem = split(/\,/, $2);
    
    return 0 unless ($old =~ /^(enum|set)\(([^\)]+)\)$/);
    return 0 if ($1 eq 'set' && $NewTy ne 'set');
    my @oldElem = split(/\,/, $2);
    my %OldTy;
    map { $OldTy{$_} = 1; } @oldElem;
    map { delete $OldTy{$_}; } @elem;
    my @oldLeft = keys %OldTy;
    return 1 if ($#oldLeft == -1);
  }
  return 0;
}

sub verify_attr_spec_scope {
  return verify_enum($_[0], 
		     \@CMU::Netdb::structure::attribute_spec_scope);
}

sub verify_attr_owner_table {
  return verify_enum($_[0],
		     \@CMU::Netdb::structure::attribute_owners);
}

sub verify_smem_member_type {
  return verify_enum($_[0],
		     \@CMU::Netdb::structure::service_member_types);
}

sub verify_attr_spec {
  my ($in, $user, $ul, $dbh) = @_;
  
  my $spec = CMU::Netdb::list_attribute_spec_ref($dbh, $user, 
						 'attribute_spec.id = \''.$in.'\'',
						 'attribute_spec.name');
  return "$INVALID$errcodes{EDB}" if (!ref $spec);
  return "$INVALID$errcodes{ENOENT}" if (!defined $spec->{$in});
  return $in;
}

## NOTE: verify_attr_data is specially linked from machines_subnets, since
## we also need the formatting information
sub verify_attr_data {
  my ($data, $format) = @_;
  if ($format eq 'uint') {
    return ($errcodes{ENONUM}, '') unless ($data =~ /^\-?(\d+)$/);
    $data = $1;
  }elsif($format eq 'int') {
    return ($errcodes{ENONUM}, '') unless ($data =~ /^\-?\d+$/);
  }elsif($format eq 'ustring') {
    return (1, $data);
    
  }elsif($format =~ /^string(\d{1,3})$/) {
    return ($errcodes{ETOOLONG}, '') if (length($data) > $1);
  }elsif($format =~ /^enum\(([^\)]+)\)$/) {
    my @form = split(/\,/, $1);
    $data =~ s/\s*//g;
    my $res = &verify_enum($data, \@form);
    return ($res, '') if (CMU::Netdb::getError($res) != 1);
  }elsif($format =~ /^set\(([^\)]+)\)$/) {
    my @form = split(/\,/, $1);
    $data =~ s/\s*//g;
    my @dAr = split(/\,/, $data);
    my $res = &verify_set(\@dAr, \@form);
    return ($res, '') if (CMU::Netdb::getError($res) != 1);
    $data = join(',', @dAr);
  }else{
    return ($errcodes{EDATA}, '');
  }
  return (1, $data);
}

sub verify_soa_email { 
  if ($_[0] =~ /^[\w\-\+]+(\.[\w\-\+]+)+$/){
    return &verify_bstring_255($_[0]);
  }
  return "$INVALID$errcodes{EDATA}";
}

sub verify_alloc_method {
  my @A = keys %CMU::Netdb::structure::AllocationMethods;
  warn __FILE__, ':', __LINE__, ' :>'.
    "AM: $_[0]\n" if ($debug >= 2);
  return verify_enum($_[0], \@A);
}

sub verify_subnet_machine_mode { 
  my @A = qw/pool reserved/;
  return verify_enum($_[0], \@A);
}

# just trim to 255
sub verify_changerec_col_string {
  my ($in) = @_;
  return substr($in, 0, 255);
}

sub verify_changerec_col_name {
  my ($in) = @_;
  my ($parts);

  $in = verify_bstring_255($in);
  
  return($in)
    if (getError($in) != 1);

  if ($in =~ /\./) {
    $parts = [split(/\./, $in)];
    $in = $parts->[$#$parts];
  }
  return($in);
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 8
# perl-indent-level: 2
# cperl-indent-level: 2
# End:

