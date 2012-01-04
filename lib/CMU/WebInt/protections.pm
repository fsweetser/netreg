#   -*- perl -*-
#
# CMU::WebInt::protections
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

package CMU::WebInt::protections;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings $THCOLOR
	    @valid_perms %perm_tables $debug);
use CMU::Netdb;
use CMU::WebInt;
require CMU::Netdb::structure;
require CMU::WebInt::machines; 

use CGI;
use DBI;
{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(prot_s1 prot_s2 prot_s3 prot_add prot_del 
	     prot_radd_list prot_radd_del prot_deptadmin prot_radd_add);

%errmeanings = %CMU::Netdb::errors::errmeanings;

my ($gmcvres);
($gmcvres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'THCOLOR');

@valid_perms = @CMU::Netdb::structure::valid_perms;

$debug = 0;

sub prot_s1 {
  my ($q, $errors) = @_;
  my ($dbh);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('prot_main');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Protections Admin", $errors);
  &CMU::WebInt::title("Protections Administration");
  print "<hr>";
  print CMU::WebInt::smallRight(CMU::WebInt::pageHelpLink(''));
  my $url = $ENV{SCRIPT_NAME};
  print CMU::WebInt::errorDialog($url, $errors);

  print "<table border=0>
<tr><td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("<u>S</u>elect the Table")."</td></tr>
<tr><td>
  <form method=get>
  <input type=hidden name=op value=prot_s2>Table: ";
  
  my @vt = sort @CMU::Netdb::structure::valid_tables;
  print $q->popup_menu(-name => 'table',
			   -accesskey => 's',
		      -values => \@vt);
  print "<br>
<input type=submit value=\"Continue\">
</td></tr></table>\n";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub prot_s2 {
  my ($q, $errors) = @_;
  my ($dbh);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('prot_s2');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Protections Admin", $errors);
  &CMU::WebInt::title("Protections Administration");
  print "<hr>";
  print CMU::WebInt::smallRight(CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::errorDialog($ENV{SCRIPT_NAME}, $errors);
  print "<form method=get>
  <input type=hidden name=op value=prot_s3>
  <input type=hidden name=table value=\"".CMU::WebInt::gParam($q, 'table')."\">
  <table border=0>
<tr><td bgcolor=$THCOLOR colspan=3>".CMU::WebInt::tableHeading("Select the records to ".
						  "view from \'".
						  CMU::WebInt::gParam($q, 'table')."\'")."</td></tr>
<tr><td width=15>&nbsp;</td><td>
  <input accesskey=n type=radio name=tidType value=0>
  </td><td>E<u>n</u>tire table</td></tr>

<tr><td width=15>&nbsp;</td><td>
  <input accesskey=s type=radio name=tidType value=1>
  </td><td><u>S</u>pecific record: <input type=text name=tid>
  </td></tr>

<tr><td width=15>&nbsp;</td>
  <td colspan=2><input type=submit value=\"View Protections\"></td></tr>

  </table>";

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub prot_s3 {
  my ($q, $errors) = @_;
  if (CMU::WebInt::gParam($q, 'tidType')) {
    prot_s3_record($q, $errors);
  }else{
    prot_s3_table($q, $errors);
  }
}

## View the protections for a specific record/tid
sub prot_s3_record {
  my ($q, $errors) = @_;
  my ($dbh, $table, $ref, $url, $tid);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('prot_s3_record');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Protections Admin", $errors);
  &CMU::WebInt::title("View Protections");

  $url = $ENV{SCRIPT_NAME};
  $table = CMU::WebInt::gParam($q, 'table');
  $tid = CMU::WebInt::gParam($q, 'tid');

  my $verbose = CMU::WebInt::gParam($q, 'bmvm');
  $verbose = 1 if ($verbose ne '0');

  $ref = CMU::Netdb::list_protections($dbh, $user, $table, $tid);
  if (!ref $ref) {
    $$errors{type} = 'ERR';
    $$errors{loc} = 'prot_S3_table';
    $$errors{code} = $ref;
    $$errors{msg} = 'Error in listing protections.';
    $$errors{fields} = '';
  }

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  if (!ref $ref) {
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my $rSub = recordSubHeading($dbh, $user, $table, $tid);
  print &CMU::WebInt::subHeading($rSub, 
		    "[<b><a href=\"$url?op=prot_s3&tidType=0&table=$table&tid=0\">Table Protections</b></a>] ".CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=prot_s3&tid=$tid&tidType=1&table=$table\">Refresh</a></b>]\n");
  
  print CMU::WebInt::printVerbose('prot_s3.general', $verbose);

  print "<form method=get>
<input type=hidden name=op value=prot_s4>
<input type=hidden name=tidType value=1>
<input type=hidden name=table value=$table>
<input type=hidden name=tid value=$tid>
<table border=1>
<tr><td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Identity")."</td>
    <td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Level")."</td>
    <td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Rights")."</td>
    <td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Delete")."</td>
</tr>";

  foreach my $k (@{$ref}) {
    print "<tr>";
    if ($$k[0] ne 'group') {
      print "<td><input type=hidden name=INF$$k[1] value=1>$$k[1]</td>";
    }else{
      print "<td><input type=hidden name=INF$$k[1] value=1><a href='$url?op=auth_grp_info&gName=$$k[1]'>$$k[1]</a></td>";
    }
   # print "<td><input type=hidden name=INF$$k[1] value=1>$$k[1]</td>".
    print "<td>".$q->popup_menu(-name => 'LEVEL'.$$k[1],
					       -values => [1,5,9],
					       -default => $$k[3])."</td>";
    print "<td>";
    my $vp;
    foreach $vp (@CMU::Netdb::structure::valid_perms) {
      print $q->checkbox(-name => $vp.$$k[1],
			 -checked => ($$k[2] =~ /$vp/ ? 1 : 0),
			 -label => $vp);
    }
    print "</td>";
    
    print "<td><a href=\"$url?op=delProt&table=$table&tid=$tid&id=$$k[1]&l=$$k[3]\">".
      "Delete</a></td></tr>\n";
  }
  print "</table>\n";
  print "<input type=submit value=\"Update\">";
  
  print "</form><form method=get>
<input type=hidden name=table value=\"$table\">
<input type=hidden name=op value=protAdd>
<input type=hidden name=tid value=$tid>";
  
  print &CMU::WebInt::subHeading("<u>A</u>dd user/group to protections", CMU::WebInt::pageHelpLink(''));
  print "<table border=0>";
  print "<tr>".CMU::WebInt::printPossError(0, 'Identity', 1, 'protections.identity').
    CMU::WebInt::printPossError(0, 'Level', 1, 'protections.rlevel').
    CMU::WebInt::printPossError(0, 'Rights', 1, 'protections.rights')."</tr>";
 print "<tr><td>";

  print $q->textfield(
          -name=>'identity',
          -accesskey=>'a');

  CMU::WebInt::drawUserRealmPopup($q,'uidrealm','r');

  print "</td><td>";
  my @rlevels = (1,5,9);
  print $q->popup_menu(-name => 'level',
		       -values => \@rlevels);
  print "</td><td>";
  foreach my $vp (@CMU::Netdb::structure::valid_perms) {
    print $q->checkbox(-name => $vp."_new",
		       -value => '1',
		       -label => $vp);
  }
  print "</td></tr></table><input type=submit value=\"Add Protection\">
</form>\n";
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;

}

## View the protections for the entire table (tid == 0)
sub prot_s3_table {
  my ($q, $errors) = @_;
  my ($dbh, $table, $ref, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('prot_s3_table');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Protections Admin", $errors);
  &CMU::WebInt::title("View Protections");

  $url = $ENV{SCRIPT_NAME};
  $table = CMU::WebInt::gParam($q, 'table');

  $ref = CMU::Netdb::list_protections($dbh, $user, $table, 0);
  if (!ref $ref) {
    $$errors{type} = 'ERR';
    $$errors{loc} = 'prot_S3_table';
    $$errors{code} = $ref;
    $$errors{msg} = 'Error in listing protections.';
    $$errors{fields} = '';
  }

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  if (!ref $ref) {
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  print &CMU::WebInt::subHeading("Global protections for table: ".$table, CMU::WebInt::pageHelpLink(''));
  print CMU::WebInt::smallRight("[<b><a href=\"$url?op=prot_s3&tid=&tidType=0&table=$table\">Refresh</a></b>]\n");
  print "<form method=get>
<input type=hidden name=op value=prot_s4>
<input type=hidden name=tidType value=0>
<input type=hidden name=table value=$table>
<input type=hidden name=tid value=0>

<table border=1>
<tr><td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Identity")."</td>
    <td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Level")."</td>
    <td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Rights")."</td>
    <td bgcolor=$THCOLOR>".CMU::WebInt::tableHeading("Delete")."</td>
</tr>";

  foreach my $k (@{$ref}) {
    print "<tr>";
    print "<td><input type=hidden name=INF$$k[1] value=1>$$k[1]</td>".
      "<td>".$q->popup_menu(-name => 'LEVEL'.$$k[1],
					       -values => [1,5,9],
					       -default => $$k[3])."</td>";
    print "<td>";
    foreach my $vp (@CMU::Netdb::structure::valid_perms) {
      print $q->checkbox(-name => $vp.$$k[1],
			 -checked => ($$k[2] =~ /$vp/ ? 1 : 0),
			 -label => $vp);
    }
    print "</td>";
    
    print "<td><a href=\"$url?op=delProt&table=$table&tid=0&id=$$k[1]&l=$$k[3]\">".
      "Delete</a></td></tr>\n";
  }
  print "</table>\n";
  print "<input type=submit value=\"Update\">";
  
  print "</form><form method=get>
<input type=hidden name=table value=\"$table\">
<input type=hidden name=op value=protAdd>
<input type=hidden name=tid value=0>";

  print &CMU::WebInt::subHeading("Add user/group to protections", CMU::WebInt::pageHelpLink(''));
  print "<table border=0>";
  # FIXME really should be printable lookups. sigh.
  print "<tr>".CMU::WebInt::printPossError(0, 'Identity', 1, 'protections.identity').
    CMU::WebInt::printPossError(0, 'Level', 1, 'protections.rlevel').
    CMU::WebInt::printPossError(0, 'Rights', 1, 'protections.rights')."</tr>";
  print "<tr><td><input type=text name=identity></td>
<td>";
  my @rlevels = (1, 5, 9);
  # FIXME why is this broken?
#  @rlevels = @$CMU::Netdb::structure::perm_map{$table}
#    if (defined $CMU::Netdb::structure::perm_map{$table});
  print $q->popup_menu(-name => 'level',
		       -values => \@rlevels);
  print "</td><td>";
  foreach my $vp (@CMU::Netdb::structure::valid_perms) {
    print $q->checkbox(-name => $vp."_new",
		       -value => '1',
		       -label => $vp);
  }
  print "</td></tr></table><input type=submit value=\"Add Protection\">
</form>\n";
  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}

sub prot_add {
  my ($q) = @_;
  my ($dbh, $table, $res, $url, $tid, $rights, $identity, $uidrealm, $fields, $level, $msg);


  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $table = CMU::WebInt::gParam($q, 'table');
  $tid = CMU::WebInt::gParam($q, 'tid');
  $rights = join(',', map { (CMU::WebInt::gParam($q, $_."_new") eq '1' ? ($_) : ()) } @CMU::Netdb::structure::valid_perms);
  $level = CMU::WebInt::gParam($q, 'level');
  warn __FILE__, ':', __LINE__, ' :>'.
    " Rights: $rights\n" if ($debug >= 2);
  $identity = CMU::WebInt::gParam($q, 'identity');
  $uidrealm = CMU::WebInt::gParam($q, 'uidrealm');

  if (($uidrealm ne undef) && ($uidrealm ne '--none--'))
  {
          $identity = $identity . '@' . $uidrealm;
  }

  # deal with secondary ip additions
  my @tids = ( $tid );
  if ($table eq 'machine') {
    my $maref = CMU::Netdb::list_machines($dbh, $user, "machine.id = $tid");
    if (!ref $maref) {
      $msg .= "Error calling CMU::Netdb::list_machines: ".$CMU::Netdb::errmeanings{$maref};
    } elsif (defined $maref->[1]) {
      my %map = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::machine_fields)};
      $maref = CMU::Netdb::list_machines($dbh, $user, "machine.mode='secondary' AND machine.mac_address='$maref->[1][$map{'machine.mac_address'}]' AND machine.ip_address_subnet=$maref->[1][$map{'machine.ip_address_subnet'}]");
      my $c = 1;
      $msg .= "Error calling CMU::Netdb::list_machines: ".$errmeanings{$maref}."<BR>"
        if (!ref $maref);
      while (ref $maref && defined $maref->[$c]) {
        push(@tids,$maref->[$c][$map{'machine.id'}]);
        $c++;
      }
    }  
  }   

  foreach my $utid (@tids) { 
    if ($identity =~ /\:/) {
      # add group 
      ($res, $fields) = CMU::Netdb::add_group_to_protections($dbh, $user, $identity, $table, $utid, $rights, $level, 'DEFAULT');
    }else{
      ($res, $fields) = CMU::Netdb::add_user_to_protections($dbh, $user, $identity, $table, $utid, $rights, $level, 'DEFAULT');
    }
    if ($res < 1) {
      $msg .= "Error adding protection: ".$errmeanings{$res};
      $msg .= " (DB Error: ".$CMU::Netdb::primitives::db_errstr.") "
        if ($CMU::Netdb::errcodes{EDB} == $res);
      $msg .= " [Fields: ".join(',', @$fields)."] ";
    }
  }

  warn __FILE__, ':', __LINE__, ' :>'.
    "prot_add result: $res\n" if ($debug >= 2);
  my (%errors);
  if ($res >= 1) {
    $msg .= "Protection added.\n";
  }else{
    $errors{type} = 'ERR';
    $errors{loc} = 'prot_add';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
  }
  $errors{msg} = $msg;

  $dbh->disconnect;
  return prot_s3_table($q, \%errors) if ($tid == 0);
  prot_s3_record($q, \%errors);
}

sub prot_s4 {
  my ($q) = @_;
  my ($dbh, $table, $url, $tid, $msg, @IDs);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $table = CMU::WebInt::gParam($q, 'table');
  $tid = CMU::WebInt::gParam($q, 'tid');

  # deal with secondary ip updates
  my @tids = ( $tid );
  if ($table eq 'machine') {
    my $maref = CMU::Netdb::list_machines($dbh, $user, "machine.id = $tid");
    if (!ref $maref) {
      $msg .= "Error calling CMU::Netdb::list_machines: ".$CMU::Netdb::errmeanings{$maref}
    } elsif (defined $maref->[1]) {
      my %map = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::machine_fields)};
      $maref = CMU::Netdb::list_machines($dbh, $user, "machine.mode='secondary' AND machine.mac_address='$maref->[1][$map{'machine.mac_address'}]' AND machine.ip_address_subnet=$maref->[1][$map{'machine.ip_address_subnet'}]");
      my $c = 1;
      $msg .= "Error calling CMU::Netdb::list_machines: ".$errmeanings{$maref}."<BR>"
        if (!ref $maref);
      while (ref $maref && defined $maref->[$c]) {
        push(@tids,$maref->[$c][$map{'machine.id'}]);
        $c++;
      }
    }
  }

  @IDs = grep (/INF/, $q->param());

  foreach my $id (@IDs) {
    $id =~ s/INF//;
    warn __FILE__, ':', __LINE__, ' :>'.
      "prot_s4: updating $id\n" if ($debug >= 2);
    foreach my $utid (@tids) {
      my $res = prot_update($dbh, $user, $id, $table, $utid, $q);
      if ($res < 1) {
        $msg .= "Error updating $id: ".$errmeanings{$res} . "<BR>";
      }
    }
  }

  CMU::WebInt::prot_s3($q, {'msg' => $msg});
}

# database handle, database user, identity, table, tid, CGI handle
sub prot_update {
  my ($dbh, $dbuser, $id, $table, $tid, $q) = @_;

  my @perms;
  foreach (qw/READ WRITE ADD/) {
    push(@perms, $_) if (CMU::WebInt::gParam($q, $_.$id) eq 'on');
  }
  my $perm = join(',', @perms);

  if ($id =~ /\:/) {
    # group
    return CMU::Netdb::modify_group_protection($dbh, $dbuser, $id, $table, $tid,
				   $perm, CMU::WebInt::gParam($q, 'LEVEL'.$id));
  }else{
    # user
    return CMU::Netdb::modify_user_protection($dbh, $dbuser, $id, $table, $tid,
				  $perm, CMU::WebInt::gParam($q, 'LEVEL'.$id));
  }
}

sub prot_del {
  my ($q) = @_;
  my ($dbh, $table, $res, $url, $tid, $rights, $identity, $fields, $rlevel, $msg);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  $url = $ENV{SCRIPT_NAME};
  $table = CMU::WebInt::gParam($q, 'table');
  $tid = CMU::WebInt::gParam($q, 'tid');
#  $rights = join(',', map { $_ if (CMU::WebInt::gParam($q, $_."_new") eq '1') } @CMU::Netdb::structure::valid_perms);
  $identity = CMU::WebInt::gParam($q, 'id');
  $rlevel = CMU::WebInt::gParam($q, 'l');
  
  # deal with secondary ip deletes
  my @tids = ( $tid );
  if ($table eq 'machine') {
    my $maref = CMU::Netdb::list_machines($dbh, $user, "machine.id = $tid");
    if (!ref $maref) {
      $msg .= "Error calling CMU::Netdb::list_machines: ".$CMU::Netdb::errmeanings{$maref};
    } elsif (defined $maref->[1]) {
      my %map = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::machine_fields)};
      $maref = CMU::Netdb::list_machines($dbh, $user, "machine.mode='secondary' AND machine.mac_address='$maref->[1][$map{'machine.mac_address'}]' AND machine.ip_address_subnet=$maref->[1][$map{'machine.ip_address_subnet'}]");
      my $c = 1;
      $msg .= "Error calling CMU::Netdb::list_machines: ".$errmeanings{$maref}."<BR>"
        if (!ref $maref);
      while (ref $maref && defined $maref->[$c]) {
        push(@tids,$maref->[$c][$map{'machine.id'}]);
        $c++;
      }
    }
  }

  foreach my $utid (@tids) {
    if ($identity =~ /\:/) {
      # add group
      ($res, $fields) = CMU::Netdb::delete_group_from_protections($dbh, $user, $identity, $table, $utid, $rlevel);
    }else{
      ($res, $fields) = CMU::Netdb::delete_user_from_protections($dbh, $user, $identity, $table, $utid, $rlevel);
    }
    if ($res < 1) {
      $msg .= "Error removing protection: ".$errmeanings{$res};
      $msg .= " (DB Error: ".$CMU::Netdb::primitives::db_errstr.") "
        if ($CMU::Netdb::errcodes{EDB} == $res);
      $msg .= " [Fields: ".join(',', @$fields)."] ";
    }
  }

  my (%errors);
  if ($res >= 1) {
    $msg .= "Protection removed.\n";
  }else{
    $errors{type} = 'ERR';
    $errors{loc} = 'prot_del';
    $errors{code} = $res;
    $errors{fields} = join(',', @$fields);
  }
  $errors{msg} = $msg;

  $dbh->disconnect;
  return prot_s3_table($q, \%errors) if ($tid == 0);
  prot_s3_record($q, \%errors);
}

sub recordSubHeading {
  my ($dbh, $user, $table, $tid) = @_;

  my $default = "Protections for record $tid from $table";

  if ($table eq 'machine') {
    my $mrec = CMU::Netdb::list_machines($dbh, $user, "machine.id = '$tid'");
    return $default if (!ref $mrec || !defined $mrec->[1]);
    my $hn = "host ".$mrec->[1]->[$CMU::WebInt::machines::machine_pos{'machine.host_name'}];
    $hn = "machine with hardware address: ".$mrec->[1]->[$CMU::WebInt::machines::machine_pos{'machine.mac_address'}] if ($hn eq 'host ');
    return "Protections for ".$hn;
  } elsif ($table eq 'outlet') {
    my $mrec = CMU::Netdb::list_outlets_cables($dbh, $user, "outlet.id = '$tid'");
    return $default if (!ref $mrec || !defined $mrec->[1]);
    my $hn = "outlet ".$mrec->[1]->[$CMU::WebInt::outlets::outlet_cable_pos{'cable.label_from'}]."/".$mrec->[1]->[$CMU::WebInt::outlets::outlet_cable_pos{'cable.label_to'}];
    return "Protections for ".$hn;
  } elsif ($table eq 'dns_zone') {
    my $mrec = CMU::Netdb::list_zone_ref($dbh, $user, 
					 "dns_zone.id = '$tid'", 
					 'dns_zone.name');
    return $default if (!ref $mrec || !defined $mrec->{$tid});
    return "Protections for DNS Zone: $mrec->{$tid}";
  } elsif ($table eq 'subnet') {

   my $subnetl = CMU::Netdb::get_subnets($dbh, $user, "P.rlevel >= 5 AND subnet.id='$tid'");

   if (ref $subnetl) {
     my %snPos = %{CMU::Netdb::makemap($subnetl->[0])};
     shift(@$subnetl);
     return 'Protections for Subnet: '.$subnetl->[0]->[$snPos{'subnet.name'}];
   }
  }
  return $default;
}

# prot_radd_add
# Add a protection entry for a single row ADD ability
#  ie: As a user/admin with l5 ADD on a row, grant others L1 ADD as well
sub prot_radd_add {
  my ($q, $errors) = @_;
  my ($dbh, $ref, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};

  my ($table, $tid)  = (CMU::WebInt::gParam($q, 'table'),
			CMU::WebInt::gParam($q, 'tid'));
  my $type; # group/user
  my $pid;
  my %errors;
  if (CMU::WebInt::gParam($q, 'user') ne '') {
    $type = 'user';
    $pid = CMU::WebInt::gParam($q, 'userid');
  }elsif(CMU::WebInt::gParam($q, 'group') ne '') {
    $type = 'group';
    $pid = CMU::WebInt::gParam($q, 'groupid');
  }elsif(CMU::WebInt::gParam($q, 'members') ne '') {
    ## Give them the membership
    return prot_radd_gmem($q, $errors, CMU::WebInt::gParam($q, 'groupid'));
  }else{
    $errors{type} = 'ERR';
    $errors{msg} = "Could not determine user/group add parameter";
    return prot_radd_list($q, \%errors);
  }

  if ($type eq 'group') {
    ## Add group
    my ($res, $err) = CMU::Netdb::add_group_to_protections
      ($dbh, $user, $pid, $table, $tid, 'ADD', 1);
    if ($res != 1) {
      $errors{msg} = "Error adding protection for group $pid: ".$errmeanings{$res};
      $errors{msg} .= " (DB Error: ".$CMU::Netdb::primitives::db_errstr.") "
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $errors{msg} .= " [Fields: ".join(',', @$err)."] ";
      $errors{type} = 'ERR';
      $errors{loc} = 'prot_radd_add';
      $errors{code} = $res;
      $errors{fields} = join(',', @$err);
    }else{
      $errors{msg} = "Added group $pid";
    }
  }else{
    ## Add user
    my ($res, $err) = CMU::Netdb::add_user_to_protections
      ($dbh, $user, $pid, $table, $tid, 'ADD', 1);
    if ($res != 1) {
      $errors{msg} = "Error adding protection for user $pid: ".$errmeanings{$res};
      $errors{msg} .= " (DB Error: ".$CMU::Netdb::primitives::db_errstr.") "
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $errors{msg} .= " [Fields: ".join(',', @$err)."] ";
      $errors{type} = 'ERR';
      $errors{loc} = 'prot_radd_add';
      $errors{code} = $res;
      $errors{fields} = join(',', @$err);
    }else{
      $errors{msg} = "Added user $pid";
    }
  }
  
  prot_radd_list($q, \%errors);
}

# prot_radd_list
# List the L1 protections entries for a row
#   .. so that the admin can change them
sub prot_radd_list {
  my ($q, $errors) = @_;
  my ($dbh, $ref, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('prot_radd_list');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Authorization for Add Access", $errors);
  &CMU::WebInt::title("Authorization for Add Access");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_user_deptadmin_status($dbh, $user);
  if ($ul < 1) {
    CMU::WebInt::accessDenied();
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  my ($table, $tid) = (CMU::WebInt::gParam($q, 'table'),
		       CMU::WebInt::gParam($q, 'tid'));
  
  if ($table eq '' || $tid eq '' || $tid eq '0') {
    print "<br><br>The table and/or table ID to administer protections is missing or invalid.";
    print "<br><br>Please visit the <a href=\"$url?op=prot_deptadmin\">".
      "Departmental Administrators Control Page</a>.\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  $ref = CMU::Netdb::list_protections($dbh, 'netreg', $table, $tid,
				      "P.rlevel < 5 ".
				      "AND P.rights = 'ADD'");
  if (!ref $ref) {
    $$errors{type} = 'ERR';
    $$errors{loc} = 'prot_radd_list';
    $$errors{code} = $ref;
    $$errors{msg} = 'Error in listing protections.';
    $$errors{fields} = '';
  }

  print "<hr>";
  print CMU::WebInt::errorDialog($url, $errors);
  if (!ref $ref) {
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  my %DescribeAction = (
	# This interface allows you to {ENTRY 0}.
	# The following groups and users can {ENTRY 1}.
	# Authorizing additional users or groups to {ENTRY 1} is easy...
	'dns_zone' => [	'register machines in a particular zone.',
			'register machines in this zone' ],
	'subnet' =>   [	'register machines in a particular subnet',
			'register machines in this subnet' ]
  );

  if (defined $DescribeAction{$table}) {
    print 'This interface allows you to add or delete the authorization for certain groups or users to '.$DescribeAction{$table}->[0]."<br><br>";

    print CMU::WebInt::subHeading(recordSubHeading($dbh, $user, $table, $tid));
    print CMU::WebInt::smallRight("[<b><a href=\"$url?op=prot_radd_list&table=$table&tid=$tid\">Refresh</a></b>]\n");

    print 'The following groups and users can '.$DescribeAction{$table}->[1].".\n<br><br>";
  }else{
    print "This table type is unsupported at this time.\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  ## Get the names of all the groups and users
  my %GroupNames;
  my %UserNames;
  my $grInfo = CMU::Netdb::list_groups($dbh, $user, '');
  if (ref $grInfo) {
    my %grpos = %{CMU::Netdb::makemap($grInfo->[0])};
    shift(@$grInfo);
    map { 
      $GroupNames{$_->[$grpos{'groups.name'}]} = $_->[$grpos{'groups.description'}];
    } @$grInfo;
  }
  $GroupNames{'system:anyuser'} = 'Any NetReg User';

  my $usInfo = CMU::Netdb::list_users($dbh, $user, '');
  if (ref $usInfo) {
    my %uspos = %{CMU::Netdb::makemap($usInfo->[0])};
    shift(@$usInfo);
    map {
      $UserNames{$_->[$uspos{'credentials.authid'}]} = 
	$_->[$uspos{'credentials.description'}];
    } @$usInfo;
  }

  print "   
<table border=1>
<tr><th>".CMU::WebInt::tableHeading("Identity")."</th>
    <th>".CMU::WebInt::tableHeading("Name")."</th>
    <th>".CMU::WebInt::tableHeading("Delete")."</th>
</tr>";

  foreach my $k (@{$ref}) {
    print "<tr>";
    if ($$k[0] ne 'group') {
      print "<td class=smtext>$$k[1]</td>\n";
      
      print "<td class=smtext>$UserNames{$$k[1]}</td>\n" if (defined $UserNames{$$k[1]});
      print "<td class=smtext>[unknown]</td>\n" if (!defined $UserNames{$$k[1]});
    }else{
      print "<td class=smtext>$$k[1]</td>\n";

      print "<td class=smtext>$GroupNames{$$k[1]}</td>\n" if (defined $GroupNames{$$k[1]});
      print "<td class=smtext>[unknown]</td>\n" if (!defined $GroupNames{$$k[1]});
    }
    print "<td class=smtext><a href=\"$url?op=prot_radd_del&table=$table&tid=$tid&".
      "id=$$k[1]&l=$$k[3]\">Delete</a></td>\n";
    print "</tr>\n";
  }
  print "</table>\n";
  print "<br>".CMU::WebInt::subHeading("Authorize User or Group").
    'Authorizing additional users or groups to '.$DescribeAction{$table}->[1].' is '.
      'easy: simply enter the Andrew UserID in the user area, or select '.
	'the group name. The "Members" button will take you to a list '.
	  "of the members of the selected group.<br>\n";

  print "<form method=get><input type=hidden name=op value=prot_radd_add>".
    "<input type=hidden name=table value=$table>".
      "<input type=hidden name=tid value=$tid>";

  my %Groups;
  my @grIDs;
  $grInfo = CMU::Netdb::list_groups($dbh, $user, '');

  if (ref $grInfo) {
    my %grPos = %{CMU::Netdb::makemap($grInfo->[0])};
    shift(@$grInfo);
    map {
      $Groups{$_->[$grPos{'groups.name'}]} = $_->[$grPos{'groups.name'}]." -- ".$_->[$grPos{'groups.description'}];
    } @$grInfo;
    $Groups{'system:anyuser'} = 'system:anyuser -- Any NetReg User';
    @grIDs = sort {$Groups{$a} cmp $Groups{$b}} keys %Groups;
  }

  
  print "<table>
<tr>
  <th><u>U</u>ser:</th>
  <td><input accesskey=u type=text name=userid>
  <input type=submit name=user value=\"Add User\"></td>
</tr>
<tr>
  <th><u>G</u>roup:</th>
  <td>";
  print $q->popup_menu(-name => 'groupid',
			    -accesskey => 'g',
		       -values => \@grIDs,
		       -labels => \%Groups);

  print "
  </td><td><input type=submit name=group value=\"Add Group\">
      <input type=submit name=members value=\"Members\">

  </td>
</tr>
</table>";
	

  print CMU::WebInt::stdftr($q);
}


sub prot_radd_del {
  my ($q, $errors) = @_;
  my ($dbh, $ref, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};

  my ($table, $tid, $pid, $glevel) = (CMU::WebInt::gParam($q, 'table'),
				      CMU::WebInt::gParam($q, 'tid'),
				      CMU::WebInt::gParam($q, 'id'),
				      CMU::WebInt::gParam($q, 'l'));
  my %errors;

  if ($pid =~ /\:/) {
    ## Delete group
    my ($res, $err) = CMU::Netdb::delete_group_from_protections
      ($dbh, $user, $pid, $table, $tid, $glevel);
    if ($res != 1) {
      $errors{msg} = "Error deleting protection for group $pid: ".$errmeanings{$res};
      $errors{msg} .= " (DB Error: ".$CMU::Netdb::primitives::db_errstr.") "
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $errors{msg} .= " [Fields: ".join(',', @$err)."] ";
      $errors{type} = 'ERR';
      $errors{loc} = 'prot_radd_del';
      $errors{code} = $res;
      $errors{fields} = join(',', @$err);
    }else{
      $errors{msg} = "Deleted group $pid";
    }
  }else{
    ## Delete user
    my ($res, $err) = CMU::Netdb::delete_user_from_protections
      ($dbh, $user, $pid, $table, $tid, $glevel);
    if ($res != 1) {
      $errors{msg} = "Error deleting protection for user $pid: ".$errmeanings{$res};
      $errors{msg} .= " (DB Error: ".$CMU::Netdb::primitives::db_errstr.") "
	if ($CMU::Netdb::errcodes{EDB} == $res);
      $errors{msg} .= " [Fields: ".join(',', @$err)."] ";
      $errors{type} = 'ERR';
      $errors{loc} = 'prot_radd_del';
      $errors{code} = $res;
      $errors{fields} = join(',', @$err);
    }else{
      $errors{msg} = "Deleted user $pid";
    }
  }
  
  prot_radd_list($q, \%errors);
}

sub prot_deptadmin {
  my ($q, $errors) = @_;
  my ($dbh, $ref, $url);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('prot_deptadmin');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Department Admin Control", $errors);
  &CMU::WebInt::title("Department Admin Control");
  
  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_user_deptadmin_status($dbh, $user);
  if ($ul < 1) {
    CMU::WebInt::accessDenied();
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }
  print "<br><br>Welcome to the Department Admin Control area.<br><br>\n";

  # Zone Admin
  print CMU::WebInt::subHeading("Authorization for Registration in Zones");
  print "Using this interface, you can change the user groups authorized ".
    "to register machines in certain DNS zones. ";
  print "<br><br>Select the zone to administer:\n";
  
  my %Zones;
  my @zoneIDs;
  my $zonel = CMU::Netdb::get_dns_zones_l5_add($dbh, $user, 
					       "dns_zone.type like 'fw-%'");
  if (ref $zonel) {
    my %znPos = %{CMU::Netdb::makemap($zonel->[0])};
    shift(@$zonel);
    map {
      $Zones{$_->[$znPos{'dns_zone.id'}]} = $_->[$znPos{'dns_zone.name'}];
    } @$zonel;

    @zoneIDs = sort {$Zones{$a} cmp $Zones{$b}} keys %Zones;
  }
  print "<form method=get><input type=hidden name=op value=prot_radd_list>
<input type=hidden name=table value=dns_zone>";
  print "<table><tr><th><u>Z</u>one:</th><td>\n";
  print $q->popup_menu(-name => 'tid',
		       -accesskey => 'z',
		       -values => \@zoneIDs,
		       -labels => \%Zones);
  print "</td><td><input type=submit value=\"Administer\"></td>".
    "</tr></table>\n";
  print "</form>\n";

  print '<br>';

  # Subnet Admin
  print CMU::WebInt::subHeading("Authorization for Registration in Subnets");
  print "Using this interface, you can change the user groups authorized ".
    "to register machines in certain subnets. ";
  print "<br><br>Select the subnet to administer:\n";
  
  my %Subnets;
  my @subnetIDs;
  my $subnetl = CMU::Netdb::get_subnets($dbh, $user, "P.rlevel >= 5");

  if (ref $subnetl) {
    my %snPos = %{CMU::Netdb::makemap($subnetl->[0])};
    shift(@$subnetl);
    map {
      $Subnets{$_->[$snPos{'subnet.id'}]} = $_->[$snPos{'subnet.name'}];
    } @$subnetl;

    @subnetIDs = sort {$Subnets{$a} cmp $Subnets{$b}} keys %Subnets;
  }
  print "<form method=get><input type=hidden name=op value=prot_radd_list>
<input type=hidden name=table value=subnet>";
  print "<table><tr><th><u>S</u>ubnet:</th><td>\n";
  print $q->popup_menu(-name => 'tid',
		       -accesskey => 's',
		       -values => \@subnetIDs,
		       -labels => \%Subnets);
  print "</td><td><input type=submit value=\"Administer\"></td>".
    "</tr></table>\n";
  print "</form>\n";

  print CMU::WebInt::stdftr($q);
}
 
sub prot_radd_gmem {
  my ($q, $errors, $gid) = @_;
  my ($dbh, $ref, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('prot_radd_gmem');
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Group Membership", $errors);
  &CMU::WebInt::title("Group Membership");

  $url = $ENV{SCRIPT_NAME};
  my $ul = CMU::Netdb::get_user_deptadmin_status($dbh, $user);
  if ($ul < 1) {
    CMU::WebInt::accessDenied();
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect;
    return;
  }

  if ($gid eq 'system:anyuser') {
    print "<br>The \"system:anyuser\" group is a special group encompassing ".
      "all NetReg users.\n";
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  ## Translate name to ID
  my $gr = CMU::Netdb::list_groups($dbh, $user, "groups.name = '$gid'");
  my $g = 0;
  my $gname;
  if (ref $gr && defined $gr->[1]) {
    my %gp = %{CMU::Netdb::makemap($gr->[0])};
    $g = $gr->[1]->[$gp{'groups.id'}];
    $gname = $gr->[1]->[$gp{'groups.description'}];
  }

  print "<br>".CMU::WebInt::subHeading("Members of Group: $gname")."<br>";

  my $rGmem = CMU::Netdb::list_members_of_group
    ($dbh, $user, $g, ' 1 ORDER BY credentials.authid');
  if (!ref $rGmem) {
    print "error in list_members_of_group: ".$errmeanings{$rGmem}."<br>\n";
  }else{
    my %users_pos = %{CMU::Netdb::makemap($rGmem->[0])};
    CMU::WebInt::generic_tprint($url, $rGmem, 
				['credentials.authid', 
				 'credentials.description'],
				[], "sop=auth_grp_info&g=$g", '', '',
				\%users_pos,
				\%CMU::Netdb::structure::users_printable,
				'credentials.authid', 'users.id', '', []);
  }
  print CMU::WebInt::stdftr($q);
}

1;
