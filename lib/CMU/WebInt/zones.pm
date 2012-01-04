#   -*- perl -*-
#
# CMU::WebInt::zones
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
# 09/18/2007 13:44:54- RCH
# Charged sorting bahavior for list_zones to make life easier for
# our sysadmin. 

package CMU::WebInt::zones;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings %zone_pos %dom_subnet_pos
	    %zone_output_order_by %zone_p $THCOLOR $TACOLOR);
use CMU::Netdb;
use CMU::WebInt;
use CMU::Helper;

use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(zone_list_old zone_list zone_view zone_search zone_s_exec zone_add zone_add_form
	    zone_delete zone_confirm_del);

%errmeanings = %CMU::Netdb::errors::errmeanings;
%zone_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::dns_zone_fields)};
%dom_subnet_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::domain_subnet_fields)};
%zone_p = %CMU::Netdb::structure::dns_zone_printable;
%zone_output_order_by = (1 => 'dns_zone.name', 
			 2 => 'dns_zone.type',
			3 => 'dns_zone.soa_serial');
my ($gmcvres);
($gmcvres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'THCOLOR');
($gmcvres, $TACOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'TACOLOR');

sub zone_list_old {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('zone_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone Admin", $errors);
  &CMU::WebInt::title("List of Zones");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dns_zone', 0);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dns_zone', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=zone_search>Search Zones</a></b>]
 [<b><a href=$url?op=zone_add_form>Add Zone</a></b>] ".CMU::WebInt::pageHelpLink(''));

  $sort = CMU::WebInt::gParam($q, 'sort');
  $sort = 'dns_zone.name' if ($sort eq '');
  
  $res = zone_print_zones($user, $dbh, $q, 
			  " 1 ".
			  CMU::Netdb::verify_orderby($sort),
			  '',
			  $ENV{SCRIPT_NAME}, "sort=$sort", 'start', 'zone_list_old');

  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# new zone list that utilizes dropdown boxen
sub zone_list {
  my ($q, $errors) = @_;
  my ($dbh, $zlref, $url, @zl);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('zone_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone Admin", $errors);
  &CMU::WebInt::title("List of Zones");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dns_zone', 0);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', 0);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dns_zone', 'READ', 0, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight("[<b><a href=$url?op=zone_search>Search Zones</a></b>]
 [<b><a href=$url?op=zone_add_form>Add Zone</a></b>] ".CMU::WebInt::pageHelpLink('')."<BR>
 [<b><A HREF=$url?op=zone_list_old>Zone List</a></b>]");
 

  print CMU::WebInt::subHeading("<u>F</u>orward Zones");
  print '<form method="get"><input type="hidden" name="op" value="zone_info">';
  $zlref = CMU::Netdb::list_zone_ref($dbh,$user,"type NOT LIKE 'rv-%' ");


# rch: I removed the heir_Sort b/c our sys admins found it easier to search an "alphabetical" List
# It also make allow you to start typing what you are looking for and the dropdown to auto-complete
# Maybe add a select here? Or just show both list?

# Nolan:  Making it a config option

  my ($zsortres, $ZONESORT) = CMU::Netdb::config::get_multi_conf_var('webint', 'ZONESORT_ALPHABETICAL');

  $ZONESORT = 0 if ($zsortres != 1);

  if ($ZONESORT) {
      # Alphabetical zone sort
      @zl = sort {$zlref->{$a} cmp $zlref->{$b}} keys %$zlref;
  } else {
      @zl = sort { CMU::Helper::hier_sort($zlref->{$a}, $zlref->{$b}) } keys %$zlref;
  }

  print $q->popup_menu(-accesskey => 'f', -name => 'id',-values => \@zl,-labels => $zlref);
  print ' <input type="submit" value="View Zone"></form><br>';
  
  print CMU::WebInt::subHeading("<u>R</u>everse Zones");
  print '<form method="get"><input type="hidden" name="op" value="zone_info">';  
  $zlref = CMU::Netdb::list_zone_ref($dbh,$user,"type LIKE 'rv-%' ");

  if ($ZONESORT) {
      # Alphabetical zone sort
      @zl = sort {$zlref->{$a} cmp $zlref->{$b}} keys %$zlref;
  } else {
      @zl = sort { CMU::Helper::hier_sort($zlref->{$a}, $zlref->{$b}) } keys %$zlref;
  }

  print $q->popup_menu(-accesskey => 'r', -name => 'id',-values => \@zl,-labels => $zlref);  
  print ' <input type="submit" value="View Zone"></form><br>';
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

# zone_print_zones
# Arguments:
#   - user that is performing this operation
#   - database handle
#   - CGI handle
#   - any parameters to the WHERE clause
#   - the url of the refresh page
#   - any additional keys for the refresh (i.e. op=search)
#   - the key to use for the 'start' parameter
sub zone_print_zones {
  my ($user, $dbh, $q, $where, $cwhere, $url, $oData, $skey, $lmach) = @_;
  my ($start, $ctRow, $ruRef, $defitems, $i, @tarr, $out, $vres, $maxPages);

  $start = CMU::WebInt::gParam($q, $skey);
  $start = 0 if ($start eq '');

  $ctRow = CMU::Netdb::primitives::count($dbh, $user, 'dns_zone', $cwhere);

  return 0 if (!ref $ctRow);

  ($vres, $defitems) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DEF_ITEMS_PER_PAGE');
  return 0 if ($vres != 1);

  ($vres, $maxPages) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DEF_MAX_PAGES');
  return 0 if ($vres != 1);

  $lmach .= "&$oData" if ($oData ne '');
  print &CMU::WebInt::pager_Top($start, $$ctRow[0], $defitems, $maxPages,
				$url, "op=".$lmach, $skey);
  $where = "1" if ($where eq '');
  $ruRef = CMU::Netdb::list_dns_zones($dbh, $user, " $where ".
				      CMU::Netdb::verify_limit($start, $defitems));
  if (!ref $ruRef) {
    print "ERROR with list_dns_zones: ".$errmeanings{$ruRef};
    return 0;
  }

  # IMPORTANT! Changing the order of fields or callbacks
  # may require changes to the WHERE/ORDER BY clauses of 
  # functions calling this function.
  CMU::WebInt::generic_tprint($ENV{SCRIPT_NAME}, $ruRef, 
		 ['dns_zone.name', 'dns_zone.type', 'dns_zone.soa_serial'],
		 [], '',
		 'zone_list_old', 'op=zone_info&id=',
		 \%zone_pos, \%zone_p,
		 'dns_zone.name', 'dns_zone.id', 'sort',
			      ['dns_zone.name', 'dns_zone.type', 'dns_zone.soa_serial']);
  
  return 1;
}

#######################################################################
## zone_view
##  -- Prints info about a dns_zone

sub zone_view {
  my ($q, $errors) = @_;
  my ($dbh, $id, $url, $res);

  $id = CMU::WebInt::gParam($q, 'id');
  $$errors{msg} = "DNS Zone ID not specified!" if ($id eq '');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('zone_view');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone", $errors);
  &CMU::WebInt::title("Zone Information");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dns_zone', $id);
  my $wl = CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', $id);
  my $al = CMU::Netdb::get_add_level($dbh, $user, 'dns_zone', $id);  

  if ($ul < 1) {
    CMU::WebInt::accessDenied('dns_zone', 'READ', $id, 1, $ul, $user);
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  # basic zone information
  # dynamic info, expire static, expire dynamic
  my $sref = CMU::Netdb::list_dns_zones($dbh, $user, "dns_zone.id='$id'");
  if (!ref $sref || !defined $sref->[1]) {
    print "ERROR: Unable to read zone information.\n";
     &CMU::WebInt::admin_mail('zones.pm:zone_view', 'WARNING',
		'Error loading zone information.',
		  {'dns_zone.id' => $id});
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  my @sdata = @{$sref->[1]};
 my $zone_name = $sdata[$zone_pos{'dns_zone.name'}];
  my $zone_type = $sdata[$zone_pos{'dns_zone.type'}];
  
  print CMU::WebInt::subHeading("Information for: ".$zone_name, CMU::WebInt::pageHelpLink(''));
  my $version = $sdata[$zone_pos{'dns_zone.version'}];
  my $sR = "[<b><a href=$url?op=zone_info&id=$id>Refresh</a></b>] ";
  $sR .= " [<b><a href=$url?op=prot_s3&table=dns_zone&tidType=1&tid=$id>View/Update Protections</a></b>]"
    if ($ul > 1);
  $sR .= " [<b><a href=\"".CMU::WebInt::encURL("$url?op=zone_del&id=$id&version=$version")."\">Delete Zone</a></b>]\n"
    if ($wl >= 9);

  print CMU::WebInt::smallRight($sR);

  # name, type
  print "<form method=get>
<input type=hidden name=id value=$id>
<input type=hidden name=op value=zone_update>
<input type=hidden name=version value=\"".$sdata[$zone_pos{'dns_zone.version'}]."\">
<table border=0><tr>".CMU::WebInt::printPossError(defined $errors->{'name'}, $zone_p{'dns_zone.name'}, 1, 'dns_zone.name').
  CMU::WebInt::printPossError(defined $errors->{'type'}, $zone_p{"dns_zone.type"}, 1, 'dns_zone.type').
    "</tr>";

  print "<tr><td>".CMU::WebInt::printVerbose('dns_zone.name', $verbose);
  if ($wl > 5) {
    print $q->textfield(-name => 'name', -accesskey => 'n', -value => $zone_name)."</td><td>".CMU::WebInt::printVerbose('dns_zone.type', $verbose).
      $q->popup_menu(-name => 'type', -accesskey => 't',
		     -values => \@CMU::Netdb::structure::dns_zone_types,
		     -default => $zone_type)."</td></tr>\n";
  }else{
      print $zone_name."</td><td>".
	  $zone_type."</td></tr>";
  }
  
  # soa_host, soa_email (if type is 'toplevel')
  if ($zone_type =~ /toplevel/ && $ul > 5) {
    print "</table>\n";
    print &CMU::WebInt::subHeading("SOA Information");
    print "<table border=0>
<tr>".
  CMU::WebInt::printPossError(defined $errors->{'soa_host'}, $zone_p{'dns_zone.soa_host'}, 1, 'soa_host').
    CMU::WebInt::printPossError(defined $errors->{'soa_email'}, $zone_p{'dns_zone.soa_email'}, 1, 'soa_email').
    "</tr>";
    print "<tr><td>".CMU::WebInt::printVerbose('dns_zone.soa_host', $verbose);
    if ($wl > 5) {
      print $q->textfield(-name=> 'soa_host', -accesskey => 'h',
		-value=> $sdata[$zone_pos{'dns_zone.soa_host'}])."</td><td>".
		  CMU::WebInt::printVerbose('dns_zone.soa_email', $verbose).
		  $q->textfield(-name=> 'soa_email', -accesskey => 'e',
				-value=> $sdata[$zone_pos{'dns_zone.soa_email'}]).
				  "</td></tr>\n";
    }else{
      print $sdata[$zone_pos{'dns_zone.soa_host'}]."</td><td>".
	$sdata[$zone_pos{'dns_zone.soa_email'}]."</td></tr>\n";
    }
    # soa_serial, soa_refresh
    print "
<tr>".
  CMU::WebInt::printPossError(defined $errors->{'soa_serial'}, $zone_p{'dns_zone.soa_serial'}, 1, 'soa_serial').
    CMU::WebInt::printPossError(defined $errors->{'soa_refresh'}, $zone_p{'dns_zone.soa_refresh'}, 1, 'soa_refresh').
    "</tr>";
    print "<tr><td>".CMU::WebInt::printVerbose('dns_zone.soa_serial', $verbose).
      $sdata[$zone_pos{'dns_zone.soa_serial'}]."</td><td>".
      CMU::WebInt::printVerbose('dns_zone.soa_serial', $verbose);
    if ($wl > 5) {
      print $q->textfield(-name=> 'soa_refresh', -accesskey => 'r',
			  -value=> $sdata[$zone_pos{'dns_zone.soa_refresh'}]).
			    "</td></tr>\n";
    }else{
      print $sdata[$zone_pos{'dns_zone.soa_serial'}]."</td></tr>\n";
    }
    # soa_retry, soa_expire
    print "
<tr>".
  CMU::WebInt::printPossError(defined $errors->{'soa_retry'}, $zone_p{'dns_zone.soa_retry'}, 1, 'soa_retry').
    CMU::WebInt::printPossError(defined $errors->{'soa_expire'}, $zone_p{'dns_zone.soa_expire'}, 1, 'soa_expire').
    "</tr>";
    print "<tr><td>".CMU::WebInt::printVerbose('dns_zone.soa_retry', $verbose);
    if ($wl > 5) {
      print $q->textfield(-name=> 'soa_retry', -accesskey => 'r',
		-value=> $sdata[$zone_pos{'dns_zone.soa_retry'}])."</td><td>".
		  CMU::WebInt::printVerbose('dns_zone.soa_expire', $verbose).
		  $q->textfield(-name=> 'soa_expire', -accesskey => 'e',
				-value=> $sdata[$zone_pos{'dns_zone.soa_expire'}]).
				  "</td></tr>\n";
    }else{
      print $sdata[$zone_pos{'dns_zone.soa_retry'}]."</td><td>".
	$sdata[$zone_pos{'dns_zone.soa_expire'}]."</td></tr>\n";
    }
    # soa_minimum, soa_default
    print "<tr>".
      CMU::WebInt::printPossError(defined $errors->{'soa_minimum'}, 
		     $zone_p{'dns_zone.soa_minimum'}, 1, 'soa_minimum').
		       CMU::WebInt::printPossError(defined $errors->{'soa_default'}, 
				      $zone_p{'dns_zone.soa_default'}, 1, 'soa_default').
					"</tr><tr><td>".
					  CMU::WebInt::printVerbose('dns_zone.soa_minimum', $verbose);
    if ($wl > 5) {
      print $q->textfield(-name=> 'soa_minimum', -accesskey => 'm',
			  -value=> $sdata[$zone_pos{'dns_zone.soa_minimum'}])."</td><td>".CMU::WebInt::printVerbose('dns_zone.soa_default', $verbose).
		  $q->textfield(-name => 'soa_default', -accesskey => 'd',
				-value => $sdata[$zone_pos{'dns_zone.soa_default'}])."</td></tr>";
    }else{
      print $sdata[$zone_pos{'dns_zone.soa_minimum'}]."</td><td>".
	CMU::WebInt::printVerbose('dns_zone.soa_default', $verbose).
	$sdata[$zone_pos{'dns_zone.soa_default'}]."</td></tr>\n";
    }
    
    # ddns auth
    if ($ul > 5) {
      print "<tr>".
	CMU::WebInt::printPossError(defined $errors->{'ddns_auth'},
				    $zone_p{'dns_zone.ddns_auth'}, 2, 'ddns_auth').
				      "</tr><tr><td colspan=2>".
					CMU::WebInt::printVerbose('dns_zone.ddns_auth', $verbose);
      if ($wl > 5) {
	print $q->textfield(-name => 'ddns_auth', -accesskey => 'd',
			    -value => $sdata[$zone_pos{'dns_zone.ddns_auth'}],
			    -size => 80)."</td></tr>\n";
      }else{
	print $sdata[$zone_pos{'dns_zone.ddns_auth'}]."</td></tr>\n";
      }
    }
  }

  # buttons
  print "<tr><td colspan=2>".$q->submit(-value=>'Update')."</td></tr>\n"
    unless ($wl < 1);
	
  print "</table></form>\n";
#  unless ($zone_type =~ /toplevel/) {
#    print &CMU::WebInt::stdftr($q);
#    $dbh->disconnect();
#    return;
#  }
  
  ## DNS Resources
  if ($al > 0) {
    if ($al >= 5) {
      print &CMU::WebInt::subHeading("DNS Resources", "[<b><a href=\"$url?op=mach_dns_res_add&owner_tid=$id&host=$zone_name&owner_type=dns_zone\">Add DNS Resource</a></b>] ".CMU::WebInt::pageHelpLink('dns_resource'));
    } else {
      print &CMU::WebInt::subHeading("DNS Resources", CMU::WebInt::pageHelpLink('dns_resource'));
	}
    my $DNSquery = "dns_resource.owner_type = 'dns_zone' AND dns_resource.owner_tid = '$id'";
    my $ldrr = CMU::Netdb::list_dns_resources($dbh, 'netreg', $DNSquery);
    if (!ref $ldrr) {
      print "Unable to list DNS resources.\n";
      &CMU::WebInt::admin_mail('zones.pm:zone_view', 'WARNING',
			       'Unable to list DNS resources.', 
                               {'name' => $zone_name});
    }elsif($#$ldrr == 0) {
      print "[There are no DNS resources for this zone.]\n";
    }else{
      print "<table border=0 width=520><tr bgcolor=".$TACOLOR.">";
      print "<td><b>Type</b></td><td colspan=2><b>Options</b></td>";
      print "<td><b>Delete</b></td>" if ($wl >= 1);
      print "</tr>\n";
      
      my $i = 1;
      my ($Res, $Type);
      my %pos = %CMU::WebInt::dns::dns_r_pos;
      my %tpos = %CMU::WebInt::dns::dns_r_t_pos;
      my $FS = $CMU::WebInt::interface::SMFONT;
      while($Res = $$ldrr[$i]) {
	print "<tr>" if ($i % 2 == 1);
	print "<tr bgcolor=".$TACOLOR.">" if ($i % 2 == 0);
	$i++;
	## Customized code for DNS resource types
	$Type = $$Res[$pos{'dns_resource.type'}];
	if($Type eq 'NS') {
	  print "<td><B>NS</B></TD>\n";
	  print "<td>${FS}Nameserver: $$Res[$pos{'dns_resource.rname'}]<br>".
	    "Host/domain: $$Res[$pos{'dns_resource.name'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
	}elsif($Type eq 'MX') {
	  print "<td><B>MX</B></TD>\n";
	  print "<td>${FS}Mail exchanger: $$Res[$pos{'dns_resource.rname'}]<br>".
	    "Host/domain: $$Res[$pos{'dns_resource.name'}]</td>\n";
	  print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]<BR>\n".
	    "Metric: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
	}elsif($Type eq 'AFSDB') {
	  print "<td><b>AFSDB</b></td>\n";
	  print "<td>${FS}DB Server: $$Res[$pos{'dns_resource.rname'}]</td>";
	  print "<td>Type: $$Res[$pos{'dns_resource.rmetric0'}]</td>\n";
	}elsif($Type eq 'TXT') {
          print "<td><b>TXT</b></td>\n";
          print "<td>${FS}Value: $$Res[$pos{'dns_resource.text0'}]</td>";
          print "<td>${FS}TTL: $$Res[$pos{'dns_resource.ttl'}]</td>\n";
        }else{
	  print "<td><b>$Type</b></td><td colspan=2>[no format information]</td>\n";
	}
	# the delete link
	my $tyref = CMU::Netdb::get_dns_resource_types($dbh, $user,"dns_resource_type.name='$Type' AND P.rlevel >= 5");
        print "<td><a href=\"".CMU::WebInt::encURL("$url?op=mach_dns_res_del&id=$$Res[$pos{'dns_resource.id'}]&version=$$Res[$pos{'dns_resource.version'}]&owner_type=dns_zone&owner_tid=$id")."\">Delete</a></td>\n"
	  if ($wl > 1 && ref $tyref && (grep /^$Type$/, values %$tyref)); # { && CMU::Netdb::get_add_level($dbh,$user,'dns_resource_type',3) >= );
	print "</tr>\n";
      }
      print "</table>\n";
    }
  }

  # subnets on which we are allowed (forward zones only)
  if ($zone_type =~ /^fw-/) {
    print "<br><br>\n".CMU::WebInt::subHeading("Subnets Allowing this Zone",
                                   CMU::WebInt::pageHelpLink('subnet_domain'));
    my $subref = CMU::Netdb::list_domain_subnets($dbh, $user,
         "subnet_domain.domain=".$dbh->quote($zone_name).
         " ORDER BY subnet.name");
    my $sname = CMU::Netdb::list_subnets_ref($dbh, $user, '', 'subnet.name');
    $$sname{'##q--'} = $q;
    $$sname{'##zid--'} = $id;
    $$sname{'##zname--'} = $zone_name;
    CMU::WebInt::generic_smTable($url, $subref,
                     ['subnet.name','subnet.abbreviation'],
                     \%dom_subnet_pos,
                     \%CMU::Netdb::structure::domain_subnet_printable,
                     "zid=$id", 'subnet_domain', 'sub_del_domain',
                     \&CMU::WebInt::zones::cb_zone_add_subnet, $sname,
                     'subnet.id', 'op=sub_info&sid=');
  }

  # Service Groups
  if ($ul >= 5) {
    my $servicequery = "service_membership.member_type = 'dns_zone' AND ".
      "service_membership.member_tid = '$id'";
    
    my ($lsmr, $rMemRow, $rMemSum, $rMemData) =
      CMU::Netdb::list_service_members($dbh, 'netreg', $servicequery);
    
    if ($lsmr < 0) {
      print "Unable to list Service Groups ($lsmr).\n";
      &CMU::WebInt::admin_mail('subnets.pm:subnets_view', 'WARNING',
			       'Unable to list Service Groups ($lsmr).',
			       { 'id' => $id});
    }else {
      print "<br>" . CMU::WebInt::subHeading("Service Groups","");
      print CMU::WebInt::printVerbose('subnet_view.service_groups');
      
      my @data = map {
	["<a href=\"$url?op=svc_info&sid=".$rMemRow->{$_}->{'service.id'}."\">".
	 $rMemRow->{$_}->{'service.name'}."</a>", $rMemRow->{$_}->{'service_membership.id'},
	 $rMemRow->{$_}->{'service_membership.version'}];
      } keys %$rMemRow;
      unshift(@data, ['service.name']);
      my $gsrr = CMU::Netdb::get_services_ref($dbh, $user, '', 'service.name');
      my %printable = (%CMU::Netdb::structure::dns_zone_printable, %CMU::Netdb::structure::service_printable);
      $$gsrr{'##q--'} = $q;
      $$gsrr{'##mid--'} = $id;
      CMU::WebInt::generic_smTable($url, \@data, ['service.name'],
				   {'service.name' => 0,
				    'service_membership.id' => 1,
				    'service_membership.version' => 2},
				   \%printable,
				   "sid=$id&back=zone", 'service_membership', 'svc_del_member',
				   \&CMU::WebInt::zones::cb_zone_add_service,
				   $gsrr);
    }
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub cb_zone_add_service {
  my ($sref) = @_;
  my $q = $$sref{'##q--'}; delete $$sref{'##q--'};
  my $id = $$sref{'##mid--'}; delete $$sref{'##mid--'};
  my $res = "<tr><td><form method=get>
<input type=hidden name=op value=svc_add_member>
<input type=hidden name=zone value=$id>
<input type=hidden name=id value=$id>
<input type=hidden name=back value=zone>\n";
  my @ss = sort {$sref->{$a} cmp $sref->{$b}} keys %$sref;
  $res .= $q->popup_menu(-name=>'sid',
                         -values=>\@ss,
                         -labels=> $sref);
  $res .= "</td><td>\n<input type=submit value=\"Add to Service Group\"></form></td></tr>\n";
}

sub cb_zone_add_subnet {
  my ($sref) = @_;
  my $q = $$sref{'##q--'}; delete $$sref{'##q--'};
  my $zid = $$sref{'##zid--'}; delete $$sref{'##zid--'};
  my $zname = $$sref{'##zname--'}; delete $$sref{'##zname--'};
  my @sids = sort {$sref->{$a} cmp $sref->{$b}} keys %$sref;
  my $res = "
<tr><td colspan=3><form method=get>
<input type=hidden name=op value=sub_add_domain>
<input type=hidden name=zid value=$zid>
<input type=hidden name=newDomain value=\"$zname\">
";
  $res .= $q->popup_menu(-name => 'sid',
                         -values => \@sids,
                         -labels => $sref);
  $res .= "
<input type=submit value=\"Add Subnet\"></form></td></tr>
";
  return $res;
}

sub zone_search {
  my ($q, $errors) = @_;
  my ($dbh, $res, $url, $sort, %groups, $grp, $mem, $gwhere);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('zone_search');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Zones", $errors);
  &CMU::WebInt::title("Search Zones");

  $url = $ENV{SCRIPT_NAME};
  my %numKeys = ('lt' => 'Less than',
		 'eq' => 'Equals',
		 'gt' => 'Greater than');
  my @nks = ('lt', 'eq', 'gt');
	       
  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  print CMU::WebInt::smallRight(CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::printVerbose('machine.search_general', 1);

  print "<form method=get>\n
<input type=hidden name=op value=zone_s_exec>
<table border=1>";

  # name
  print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.name'}, 1, 'dns_zone.name').
    "<td>".$q->textfield(-name => 'name')."</td></tr>";
  
  # soa_host
  print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.soa_host'}, 1, 'dns_zone.soa_host').
    "<td>".$q->textfield(-name => 'soa_host')."</td></tr>";
  # soa_email
  print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.soa_email'}, 1, 'dns_zone.soa_email').
    "<td>".$q->textfield(-name => 'soa_email')."</td></tr>";
  # soa_serial
  print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.soa_serial'}, 1, 'dns_zone.soa_serial').
    "<td>".$q->radio_group(-name => 'soa_serial.v',
			   -labels => \%numKeys,
			   -values => \@nks)
      ."<br>".
	$q->textfield(-name => 'soa_serial')."</td></tr>\n";
  # soa_refresh
 print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.soa_refresh'}, 1, 'dns_zone.soa_refresh').
   "<td>".$q->radio_group(-name => 'soa_refresh.v',
			  -labels => \%numKeys,
			  -values => \@nks)."<br>".
			    $q->textfield(-name => 'soa_refresh')."</td></tr>\n";
  # soa_retry
 print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.soa_retry'}, 1, 'dns_zone.soa_retry'). 
   "<td>".$q->radio_group(-name => 'soa_retry.v',
			  -labels => \%numKeys,
			  -values => \@nks)."<br>".
			    $q->textfield(-name => 'soa_retry')."</td></tr>\n";
  # soa_expire
  print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.soa_expire'}, 1, 'dns_zone.soa_expire').
    "<td>".$q->radio_group(-name => 'soa_expire.v',
			   -labels => \%numKeys,
			   -values => \@nks)."<br>".
			     $q->textfield(-name => 'soa_expire')."</td></tr>\n";
  # types
  {
    my @types = @CMU::Netdb::structure::dns_zone_types;
    unshift(@types, '--select--');
    print "<tr>".CMU::WebInt::printPossError(0, $zone_p{'dns_zone.type'}, 1, 'dns_zone.type').
      "<td>".$q->popup_menu(-name => 'type',
			    -values => \@types)."</td></tr>";
  }

  print "</table>\n";
  print "<input type=submit value=\"Search\"></form>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub zone_s_exec {
  my ($q, $errors) = @_;
  my ($dbh, $url, $query, @q);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('zone_s_exec');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Zones", $errors);
  &CMU::WebInt::title("Search Zones");

  $url = $ENV{SCRIPT_NAME};
  my %numMap = ('lt' => '<',
		'eq' => '=',
		'gt' => '>');

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);

  print CMU::WebInt::smallRight(CMU::WebInt::pageHelpLink(''));
  # name
  if (CMU::WebInt::gParam($q, 'name') ne '') {
    if (CMU::WebInt::gParam($q, 'name') =~ /\%/) {
      push(@q, 'dns_zone.name like '.$dbh->quote(CMU::WebInt::gParam($q, 'name')));
    }else{
      push(@q, 'dns_zone.name like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'name').'%'));
    }
  }
  # soa_host
  if (CMU::WebInt::gParam($q, 'soa_host') ne '') {
    if (CMU::WebInt::gParam($q, 'soa_host') =~ /\%/) {
      push(@q, 'soa_host like '.$dbh->quote(CMU::WebInt::gParam($q, 'soa_host')));
    }else{
      push(@q, 'soa_host like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'soa_host').'%'));
    }
  }
  # soa_email
  if (CMU::WebInt::gParam($q, 'soa_email') ne '') {
    if (CMU::WebInt::gParam($q, 'soa_email') =~ /\%/) {
      push(@q, 'soa_email like '.$dbh->quote(CMU::WebInt::gParam($q, 'soa_email')));
    }else{
      push(@q, 'soa_email like '.$dbh->quote('%'.CMU::WebInt::gParam($q, 'soa_email').'%'));
    }
  }
  # soa_serial
  push(@q, "soa_serial ".$numMap{CMU::WebInt::gParam($q, 'soa_serial.v')}." ".
       CMU::WebInt::gParam($q, 'soa_serial')) 
    if (CMU::WebInt::gParam($q, 'soa_serial') ne '' && defined $numMap{CMU::WebInt::gParam($q, 'soa_serial.v')});
  # soa_refresh
  push(@q, "soa_refresh ".$numMap{CMU::WebInt::gParam($q, 'soa_refresh.v')}." ".
       CMU::WebInt::gParam($q, 'soa_refresh')) 
    if (CMU::WebInt::gParam($q, 'soa_refresh') ne '' && defined $numMap{CMU::WebInt::gParam($q, 'soa_refresh.v')});
  
  # soa_retry
  push(@q, "soa_retry ".$numMap{CMU::WebInt::gParam($q, 'soa_retry.v')}." ".
       CMU::WebInt::gParam($q, 'soa_retry')) 
    if (CMU::WebInt::gParam($q, 'soa_retry') ne '' && defined $numMap{CMU::WebInt::gParam($q, 'soa_retry.v')});
  
  # soa_expire
  push(@q, "soa_expire ".$numMap{CMU::WebInt::gParam($q, 'soa_expire.v')}." ".
       CMU::WebInt::gParam($q, 'soa_expire')) 
    if (CMU::WebInt::gParam($q, 'soa_expire') ne '' && defined $numMap{CMU::WebInt::gParam($q, 'soa_expire.v')});
  
  # types
  push(@q, 'type = \''.CMU::WebInt::gParam($q, 'type').'\'') if (CMU::WebInt::gParam($q, 'type') ne '' &&
					   CMU::WebInt::gParam($q, 'type') ne '--select--');

  my @rurl;
  foreach my $f(qw/name soa_host soa_email soa_serial soa_refresh soa_retry
		soa_expire soa_minimum type/) {
    my $v = CMU::WebInt::gParam($q, $f);
    push(@rurl, "$f=$v") if ($v ne '');
  }

  my $gwhere = join(' AND ', @q);
  $gwhere = '1' if ($gwhere eq '');

  my $sort = 1;
  push(@rurl, "sort=$sort");
  my $res = zone_print_zones($user, $dbh, $q, 
			     $gwhere.CMU::Netdb::verify_orderby($zone_output_order_by{$sort}),
			     $gwhere,
			     $url, join('&', @rurl), 'start', 'zone_s_exec');
  
  print "ERROR: ".$errmeanings{$res} if ($res <= 0);

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub zone_add_form {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dns_zone', 0);

  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  CMU::WebInt::setHelpFile('zone_add_form');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone Admin", $errors);
  &CMU::WebInt::title("Add a DNS Zone");

  print CMU::WebInt::errorDialog($url, $errors);
  
  if ($userlevel < 1) {
    CMU::WebInt::accessDenied('dns_zone', 'ADD', 0, 1, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');
  print CMU::WebInt::subHeading("Basic Information", CMU::WebInt::pageHelpLink(''));
  
  # Name, type
  print "
<form method=get>
<input type=hidden name=op value=zone_add>
<table border=0>
<tr>".CMU::WebInt::printPossError(defined $errors{name}, $zone_p{'dns_zone.name'}, 1, 'dns_zone.name').
  CMU::WebInt::printPossError(defined $errors{type}, $zone_p{'dns_zone.type'}, 1, 'dns_zone.type')."</tr>
<tr><td>".CMU::WebInt::printVerbose('dns_zone.name', $verbose).
  $q->textfield(-name => 'name', -accesskey => 'n')."</td><td>".
  CMU::WebInt::printVerbose('dns_zone.type', $verbose).
  $q->popup_menu(-name => 'type', -accesskey => 't',
		 -values => \@CMU::Netdb::structure::dns_zone_types).
		   "</td></tr>\n";

  print "</table>".CMU::WebInt::subHeading("SOA Parameters")."<table border=0>";

  # soa_email, host
  print "<tr>".
    CMU::WebInt::printPossError(defined $errors{soa_email}, $zone_p{'dns_zone.soa_email'}, 1, 'dns_zone.soa_email').
      CMU::WebInt::printPossError(defined $errors{soa_host}, $zone_p{'dns_zone.soa_host'}, 1, 'dns_zone.soa_host').
	"</tr><tr><td>".CMU::WebInt::printVerbose('dns_zone.soa_email', $verbose).
	  $q->textfield(-name => 'soa_email', -accesskey => 'e')."</td><td>".
	    CMU::WebInt::printVerbose('dns_zone.soa_host', $verbose).
	    $q->textfield(-name => 'soa_host', -accesskey => 'h')."</td></tr>\n";

  # soa_refresh, soa_retry
  print "<tr>".
    CMU::WebInt::printPossError(defined $errors{soa_refresh}, $zone_p{'dns_zone.soa_refresh'}, 1, 'dns_zone.soa_refresh').
      CMU::WebInt::printPossError(defined $errors{soa_retry}, $zone_p{'dns_zone.soa_retry'}, 1, 'dns_zone.soa_retry').
	"</tr><tr><td>".
	  CMU::WebInt::printVerbose('dns_zone.soa_refresh', $verbose).
	  $q->textfield(-name => 'soa_refresh', -accesskey => 'r')."</td><td>".
	    CMU::WebInt::printVerbose('dns_zone.soa_retry', $verbose).
	    $q->textfield(-name => 'soa_retry', -accesskey => 'r')."</td></tr>";

  # soa_expire, soa_minimum
  print "<tr>".
    CMU::WebInt::printPossError(defined $errors{soa_expire}, $zone_p{'dns_zone.soa_expire'}, 1, 'dns_zone.soa_expire').
      CMU::WebInt::printPossError(defined $errors{soa_minimum}, $zone_p{'dns_zone.soa_minimum'}, 1, 'dns_zone.soa_minimum').
	"</tr><tr><td>".
	  CMU::WebInt::printVerbose('dns_zone.soa_expire', $verbose).
	  $q->textfield(-name => 'soa_expire', -accesskey => 'e')."</td><td>".
	    CMU::WebInt::printVerbose('dns_zone.soa_minimum', $verbose).
	    $q->textfield(-name => 'soa_minimum', -accesskey => 'm')."</td></tr>";

  # soa_default, ddns_auth
  print "<tr>".
    CMU::WebInt::printPossError(defined $errors{soa_default}, $zone_p{'dns_zone.soa_default'}, 1, 'dns_zone.soa_default').      
      CMU::WebInt::printPossError(defined $errors{ddns_auth}, $zone_p{'dns_zone.ddns_auth'}, 1, 'dns_zone.ddns_auth').
        "</tr><tr><td>".
	CMU::WebInt::printVerbose('dns_zone.soa_default', $verbose).
	  $q->textfield(-name => 'soa_default', -accesskey => 'd')."</td><td>\n".
	    CMU::WebInt::printVerbose('dns_zone.ddns_auth', $verbose).
	      $q->textfield(-name => 'ddns_auth', -accesskey => 'd')."</td></tr>\n";
;

  print "</table>\n";
  print "<input type=submit value=\"Add Zone\">\n";

  print &CMU::WebInt::stdftr($q);
}

sub zone_add {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel, $addret);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  foreach(qw/name soa_host soa_email soa_refresh soa_retry
	  soa_expire soa_minimum soa_default type/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }
  my ($res, $errfields) = CMU::Netdb::add_dns_zone($dbh, $user, \%fields);

  if ($res > 0) {
    my %warns = %$errfields;
    $nerrors{'msg'} = "Added zone $fields{name}.";
    $q->param('id', $warns{insertID});
    $dbh->disconnect(); # we use this for the insertid ..
    CMU::WebInt::zone_view($q, \%nerrors);
  }else{
    if ($res <= 0 && ref $errfields) {
      map { $nerrors{$_} = 1 } @$errfields if ($res <= 0);
      $nerrors{'msg'} .= $errmeanings{$res};
      $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") ";
      $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.")"
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $nerrors{code} = $res;
      $nerrors{type} = 'ERR';
      $nerrors{fields} = join(',', @$errfields);
      $nerrors{loc} = 'zone_add';
    }
    $dbh->disconnect();
    &CMU::WebInt::zone_add_form($q, \%nerrors);
  }
}

sub zone_delete {
  my ($q) = @_;
  my ($url, $dbh, $ul, $res) = @_;
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('zone_del');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone Admin", {});
  &CMU::WebInt::title('Delete DNS Zone');
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', $id);
  if ($ul < 1) {
    CMU::WebInt::accessDenied('dns_zone', 'WRITE', $id, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # basic machine infromation
  my $sref = CMU::Netdb::list_dns_zones($dbh, $user, "dns_zone.id='$id'");
  if (!defined $sref->[1]) {
    print "Error: DNS Zone not defined!\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  my @sdata = @{$sref->[1]};
  print "<br><br>Please confirm that you wish to delete the following zone.\n";
  
  my @print_fields = ('dns_zone.name', 'dns_zone.type');

  print "<table>\n";
  foreach my $f (@print_fields) {
    print "<tr><th>".$zone_p{$f}."</th>
<td>";
    print $sdata[$zone_pos{$f}];;
    print "</td></tr>\n";
  }
  print "</table>\n";
  print "<BR><a href=\"".CMU::WebInt::encURL("$url?op=zone_del_conf&id=$id&version=$version")."\">
Yes, delete this zone";
  print "<br><a href=\"$url?op=zone_list\">No, return to the zones list</a>\n";
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub zone_confirm_del {
  my ($q, $errors) = @_;
  my ($url, $dbh, $ul, $res, $erf, $msg) = @_;

  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  
  $$errors{msg} = "Delete Zone: DNS Zone ID not specified!" if ($id eq '');
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $ul = CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', $id);
  
  if ($ul < 1) {
    $msg = "Delete Zone: Access denied while trying to delete $id.\n";
    my %ne = ('msg' => 'Delete Zone: Access denied while trying to delete $id',
	      'type' => 'ERR',
	      'fields' => '',
	      'code' => $CMU::Netdb::errcodes{EPERM},
	      'loc' => 'zone_del_conf');

    $dbh->disconnect();
    CMU::WebInt::zone_view($q, \%ne);
    return;
  }
  
  ($res, $erf) = CMU::Netdb::delete_dns_zone($dbh, $user, $id, $version);
  
  if ($res == 1) {
    $dbh->disconnect();
    CMU::WebInt::zone_list($q, {'msg' => 'The DNS Zone has been deleted.'});
  }else{
    $msg = "There was an error while deleting the machine: ".$errmeanings{$res}."\n";
    $msg .= "Fields: ".join(',', @$erf);
    $dbh->disconnect();
    my %ne = ('msg' => $msg,
	     'code' => $res,
	     'type' => 'ERR',
	     'fields' => join(',', @$erf),
	     'loc' => 'zone_del_conf');
    CMU::WebInt::zone_view($q, \%ne);
  }
}

sub zone_update {
  my ($q, $errors) = @_;
  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my $id = CMU::WebInt::gParam($q, 'id');
  my $version = CMU::WebInt::gParam($q, 'version');
  $userlevel = CMU::Netdb::get_write_level($dbh, $user, 'dns_zone', $id);

  if ($userlevel < 9) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone Admin", $errors);
    &CMU::WebInt::title("Update DNS Zone");
    CMU::WebInt::accessDenied('dns_zone', 'WRITE', $id, 9, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  foreach(qw/name soa_host soa_email soa_refresh soa_retry
	  soa_expire soa_minimum soa_default type ddns_auth/) {
    $fields{$_} = CMU::WebInt::gParam($q, $_);
  }

  my ($res, $errfields) = CMU::Netdb::modify_dns_zone($dbh, $user, $id, $version, \%fields);

  if ($res > 0) {
    $nerrors{'msg'} = "Updated DNS zone.";
    $dbh->disconnect(); 
    &CMU::WebInt::zone_view($q, \%nerrors);
  }else{
    map { $nerrors{$_} = 1 } @$errfields if (ref $errfields);
    $nerrors{'msg'} = $errmeanings{$res};
    $nerrors{'msg'} .= " [$res] (".join(',', @$errfields).") " if (ref $errfields);
    $nerrors{'msg'} .= " (Database: ".$CMU::Netdb::primitives::db_errstr.") " if ($res eq $CMU::Netdb::errcodes{EDB});
    $nerrors{code} = $res;
    $nerrors{type} = 'ERR';
    $nerrors{fields} = join(',', @$errfields);
      $nerrors{loc} = 'zone_upd';
    $dbh->disconnect();
    &CMU::WebInt::zone_view($q, \%nerrors);
  }
}

sub zone_bulk_rv {
  my ($q, $errors) = @_;

  my $subop = CMU::WebInt::gParam($q, 'sop');
  $subop = 1 if ($subop eq '' ||
		 !$subop =~ /^\d+$/ ||
		 $subop < 1 || $subop > 3);

  my ($dbh, %fields, %nerrors, $userlevel);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $userlevel = CMU::Netdb::get_add_level($dbh, $user, 'dns_zone', 0);

  if ($userlevel < 9) {
    print &CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone Admin", $errors);
    &CMU::WebInt::title("Bulk Reverse Management");
    CMU::WebInt::accessDenied('dns_zone', 'ADD', 0, 9, $userlevel, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  
  my %Titles = (1 => 'Specify Zone Range',
		2 => 'Specify Protections',
		3 => 'Update Zones');

  print &CMU::WebInt::stdhdr($q, $dbh, $user, "DNS Zone Admin", $errors);
  &CMU::WebInt::title("Bulk Reverse Zone Management");
  
  print CMU::WebInt::subHeading($Titles{$subop});
  if ($subop == 3) {

  }

  if ($subop == 2) {
    print CMU::WebInt::printVerbose('zone_rv_mgmt.txt2', 1);

  }
  
  if ($subop == 1) {
    print CMU::WebInt::printVerbose('zone_rv_mgmt.txt1', 1);
    print "<form method=get><input type=hidden name=op value=zone_bulk_rv>".
      "<input type=hidden name=sop value=2>\n";
    

    print "</form>";

  }

  $dbh->disconnect();
  print CMU::WebInt::stdftr($q);

}
1;
