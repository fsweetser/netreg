#   -*- perl -*-
#
# CMU::WebInt::reports
#
# Copyright 2001 Carnegie Mellon University 
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
# $Id: reports.pm,v 1.71 2008/03/27 19:42:38 vitroth Exp $
#
#

package CMU::WebInt::reports;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug $THCOLOR $fcolor);
use Data::Dumper;
use CMU::WebInt;
use CMU::Netdb;
use CGI::Pretty;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw/rep_subnet_util rep_dept_mach rep_outlet_util rep_main rep_zone_config rep_panels
  rep_subnet_map rep_zone_util rep_subnet_zone_map rep_ipr_util/;

$debug = 0;

my ($gmcvres);
($gmcvres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'THCOLOR');

$fcolor = {
	   request     => "blue",
	   active      => "green",
	   delete      => "#888888",
	   error       => "red",
	   errordelete => "red",
	   novlan      => "#BBBBBB"
	  };

# Since err never gets used, but is confusing in the legend
my %SMap_Default_Colors = ( # 'err' => 'red',
			   'multiple' => 'magenta',
			   'free' => '#DFDFDF',
			   'reserved' => 'lightgreen',
			   'phaseout' => 'yellow',
			   'shared' => '#F6A694',
			   'delegated' => 'orange',
			   'routed-nondhcp' => 'lightblue',
			   'routed' => 'red');

sub rep_dept_mach {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  my @modes=('static','dynamic','reserved','broadcast','pool','base');

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, 
			    "Machine Registrations by Department", $errors);
  &CMU::WebInt::title("Machine Registrations by Department");

  print CMU::WebInt::errorDialog($url, $errors);

  my ($display_table, %column_headings, $dept, $type, $i);
  
  $display_table = CMU::Netdb::general_query($dbh, 'netreg', 'count_machines_departments', \&CMU::Netdb::remove_dept_tag_hash2, undef);

  if (!ref $display_table) {
    if ($display_table eq $CMU::Netdb::errcodes{EPERM}) {
      CMU::WebInt::accessDenied();
    }else{
      warn __FILE__, ':', __LINE__, ' :>'.
	"Unknown error reading machine table.\n";
    }
    $dbh->disconnect();
    return;
  }


  print "<table border=1>\n";
  print "<tr><th>Department</th>";
# Ideally, this should be dynamic based on what's in the db.  But Russell 
# wants all the possible modes hard coded.  
# To use the dynamic method, simply simply replace the foreach statements 
# that are used with the one's I've commented out. ken2

#  foreach $type (sort keys %column_headings) {
  foreach $type (@modes) {
    print "<th>$type</th>";
  }

  my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  
  foreach $dept (sort keys %$display_table) {
    print "<tr><td><b>$FF$dept</b></td>";
#    foreach $type (sort keys %column_headings) {
    foreach $type (@modes) {
      if ($$display_table{$dept}{$type}) {
	print "<td ALIGN=RIGHT>$$display_table{$dept}{$type}</td>";
      }
      else {
	print "<td ALIGN=RIGHT> 0 </td>";
      }
    }
  }

  print "</table>\n";
  print &CMU::WebInt::stdftr($q);

  $dbh->disconnect();
}

sub rep_expired_mach {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, 
			    "Expiring Machine Registrations by Department", $errors);
  &CMU::WebInt::title("Expiring Machine Registrations by Department");

  print CMU::WebInt::errorDialog($url, $errors);

  my ($display_table, %column_headings, $dept, $type, $i);
  
  $display_table = CMU::Netdb::general_query($dbh, 'netreg', 'count_expired_machines_departments', \&CMU::Netdb::remove_dept_tag_hash2, undef);


  warn Data::Dumper->Dump([$display_table],['expired machines']) if ($debug);

  if (!ref $display_table) {
    if ($display_table eq $CMU::Netdb::errcodes{EPERM}) {
      CMU::WebInt::accessDenied();
    }else{
      warn __FILE__, ':', __LINE__, ' :>'.
	"Unknown error reading machine table.\n";
    }
    $dbh->disconnect();
    return;
  }


  print "<table border=1>\n";
  print "<tr><th>Department</th>";
  print "<th>Expiring Machines</th></tr>";


  my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  
  foreach $dept (sort keys %$display_table) {
    print "<tr><td><b>$FF$dept</b></td>";
    if ($$display_table{$dept}{expired}) {
      print "<td ALIGN=RIGHT>$$display_table{$dept}{expired}</td>";
    } else {
      print "<td ALIGN=RIGHT> 0 </td>";
    }
    print "</tr>\n";
  }


  print "</table>\n";
  print &CMU::WebInt::stdftr($q);

  $dbh->disconnect();
}


sub rep_expired_outlet {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, 
			    "Expiring Outlet Registrations by Department", $errors);
  &CMU::WebInt::title("Expiring Outlet Registrations by Department");

  print CMU::WebInt::errorDialog($url, $errors);

  my ($display_table, %column_headings, $dept, $type, $i);
  
  $display_table = CMU::Netdb::general_query($dbh, 'netreg', 'count_expired_outlets_departments', \&CMU::Netdb::remove_dept_tag_hash2, undef);


  warn Data::Dumper->Dump([$display_table],['expired outlets']) if ($debug);

  if (!ref $display_table) {
    if ($display_table eq $CMU::Netdb::errcodes{EPERM}) {
      CMU::WebInt::accessDenied();
    }else{
      warn __FILE__, ':', __LINE__, ' :>'.
	"Unknown error reading outlets table.\n";
    }
    $dbh->disconnect();
    return;
  }


  print "<table border=1>\n";
  print "<tr><th>Department</th>";
  print "<th>Expiring Outlets</th></tr>";


  my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  
  foreach $dept (sort keys %$display_table) {
    print "<tr><td><b>$FF$dept</b></td>";
    if ($$display_table{$dept}{expired}) {
      print "<td ALIGN=RIGHT>$$display_table{$dept}{expired}</td>";
    } else {
      print "<td ALIGN=RIGHT> 0 </td>";
    }
    print "</tr>\n";
  }


  print "</table>\n";
  print &CMU::WebInt::stdftr($q);

  $dbh->disconnect();
}


sub rep_orphan_mach {
    my ($q, $errors) = @_;
    my ($dbh, $url, $userlevel, %errors);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    $url = $ENV{SCRIPT_NAME};
  
    print CMU::WebInt::stdhdr($q, $dbh, $user, 
			      "Orphan Machines", $errors);
    &CMU::WebInt::title("Orphan Machines");

    print CMU::WebInt::errorDialog($url, $errors);

    my $orphans = CMU::Netdb::list_orphan_machines($dbh, $user);

    print "<p>Found total of ", $#{$orphans} + 1, " orphaned machines</p>\n";

    print "<table><tr><th>Hostname</th><th>MAC Address</th></tr>\n";

    foreach my $o ( @{$orphans} ){
	print "<tr><td><a href=$url?op=mach_view&id=", $o->[0], ">", $o->[1], "</a></td><td>", $o->[2],"</td></tr>\n";
    }

    print "</table>";
    print &CMU::WebInt::stdftr($q);
    $dbh->disconnect();
}

sub rep_outlet_util {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Outlet Utilization", $errors);
  &CMU::WebInt::title("Outet Utilization Report");

  print CMU::WebInt::errorDialog($url, $errors);

  my ($display_table, %column_headings, $dept, $type, $i);
  
  $display_table = CMU::Netdb::general_query($dbh, 'netreg', 'count_outlettypes_departments', \&CMU::Netdb::remove_dept_tag_hash2, undef);

  if (!ref $display_table) {
    if ($display_table eq $CMU::Netdb::errcodes{EPERM}) {
      CMU::WebInt::accessDenied();
    }else{
      warn __FILE__, ':', __LINE__, ' :>'.
	"Unknown error reading outlet table.\n";
    }
    $dbh->disconnect();
    return;
  }


  ## Get heading info (from 2nd level of hash 

  foreach $dept (keys %$display_table ) {
    foreach $type (keys %{$$display_table{$dept}}) {
      $column_headings{$type} = 1; # this is just to get a list of columns
    }
  }

  print "<table border=1>\n";
  print "<tr><th>Department</th>";
  foreach $type (sort keys %column_headings) {
    print "<th>$type</th>";
  }

  my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  
  foreach $dept (sort keys %$display_table) {
    print "<tr><td><b>$FF$dept</b></td>";
    foreach $type (sort keys %column_headings) {
      if ($$display_table{$dept}{$type}) {
	print "<td ALIGN=RIGHT>$$display_table{$dept}{$type}</td>";
      }
      else {
	print "<td ALIGN=RIGHT> 0 </td>";
      }
    }
  }

  print "</table>\n";
  print &CMU::WebInt::stdftr($q);

  $dbh->disconnect();
}

sub rep_ipr_util {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  $url = $ENV{SCRIPT_NAME};

  print CMU::WebInt::stdhdr($q, $dbh, $user, "IP Range Utilization", $errors);
  &CMU::WebInt::title("IP Range Utilization Report");

  print CMU::WebInt::errorDialog($url, $errors);

  my $rur = CMU::Netdb::rep_ipr_utilization($dbh, $user);
  if(!ref $rur){
    if ($rur eq $CMU::Netdb::errcodes{EPERM}){
      CMU::WebInt::accessDenied();
    } else {
      print "Unknown error reading ip range table.\n";
    }
    $dbh->disconnect;
    print CMU::WebInt::stdftr($q);
    return;
  }

  print "<table border=1>\n";
  print "<tr><th>IP Range</th><th>Utilization</th><th>Used</th><th>Pools</th></tr>\n";
  my @rorder = sort { $$rur{$b}->[1]/$$rur{$b}->[2] <=> $$rur{$a}->[1]/$$rur{$a}->[2] } keys %$rur;

  my ($percent, $imgColor, $width);
  foreach my $r (@rorder){
    my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
    print "<tr><td><b>$FF<a href=$url?op=range_view&rid=$r>$$rur{$r}->[0]</a></b></td><td>";
    $percent = $$rur{$r}->[1]/$$rur{$r}->[2];
    $imgColor = 'red';
    $imgColor = 'yellow' if ($percent < 0.90);
    $imgColor = 'green' if ($percent < 0.80);
    $width = int($percent*200);
    $width = 1 if ($width == 0);
    print "<img src=/img/$imgColor-small.jpg height=10 width=$width></td><td>$FF$$rur{$r}->[1]/$$rur{$r}->[2] (".int($percent*100)."%)</td><td>$$rur{$r}->[3]</td></tr>\n";

  }

  print "</table>\n";
  print &CMU::WebInt::stdftr($q);

  $dbh->disconnect;
}

sub rep_subnet_util {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Utilization", $errors);
  &CMU::WebInt::title("Subnet Utilization Report");
  
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $sur = CMU::Netdb::rep_subnet_utilization($dbh, $user);
  if (!ref $sur) {
    if ($sur eq $CMU::Netdb::errcodes{EPERM}) {
      CMU::WebInt::accessDenied();
    }else{
      print "Unknown error reading subnet table.\n";
    }
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<table border=1>\n";
  print "<tr><th>Subnet</th><th>Utilization</th><th>Used/Total</th><th>Dynamics/Pools</th>\n";
  my @sorder = sort { $$sur{$b}->[1]/$$sur{$b}->[2] <=> $$sur{$a}->[1]/$$sur{$a}->[2] } keys %$sur;
  
  my ($percent, $imgColor, $width);
  my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  foreach my $s (@sorder) {
    print "<tr><td><b>$FF<a href=$url?op=sub_info&sid=$s>$$sur{$s}->[0]</a></b></td><td>";
    $percent = $$sur{$s}->[1]/$$sur{$s}->[2];
    $imgColor = 'red';
    $imgColor = 'yellow' if ($percent < 0.90);
    $imgColor = 'green' if ($percent < 0.80);
    $width = int($percent*200);
    $width = 1 if ($width == 0);
    print "<img src=/img/$imgColor-small.jpg height=10 width=$width></td>
<td>$FF$$sur{$s}->[1]/$$sur{$s}->[2] (".int($percent*100)."%)</td><td>$$sur{$s}->[3]/$$sur{$s}->[4]</td></tr>\n";
  }
  
  print "</table>\n";
  print &CMU::WebInt::stdftr($q);
  
  $dbh->disconnect();
}

sub rep_cname_util {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "CNAME Utilization", $errors);
  &CMU::WebInt::title("CNAME Utilization Report");
  
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $sur = CMU::Netdb::rep_cname_by_machine($dbh, $user);
  if (!ref $sur) {
    if ($sur eq $CMU::Netdb::errcodes{EPERM}) {
      CMU::WebInt::accessDenied();
    }else{
      print "Unknown error reading rep_cname_by_machine.\n";
    }
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<table border=1>\n";
  print "<tr><th>Host</th><th>Utilization</th><th>CNAMEs</th>\n";
  my @sorder = sort { $$sur{$b}->[0] <=> $$sur{$a}->[0] } keys %$sur;
  
  my ($stat, $imgColor, $width);
  my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  foreach my $s (@sorder) {
    next if ($$sur{$s}->[0] < 2);
    print "<tr><td><b>$FF<a href=$url?op=mach_view&id=$$sur{$s}->[1]>$s</a></b></td><td>";
    $stat = $$sur{$s}->[0];
    $imgColor = 'red';
    $imgColor = 'yellow' if ($stat < 10);
    $imgColor = 'green' if ($stat < 4);
    $width = int($stat*10);
    $width = 1 if ($width == 0);
    print "<img src=/img/$imgColor-small.jpg height=10 width=$width></td>
<td>$$sur{$s}->[0]</td></tr>\n";
  }
  
  print "</table>\n";
  print &CMU::WebInt::stdftr($q);
  
  $dbh->disconnect();
}

sub rep_user_mach {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  $url = $ENV{SCRIPT_NAME};
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Machines By User", $errors);
  &CMU::WebInt::title("Machines By User");
  
  print CMU::WebInt::errorDialog($url, $errors);
  
  my $sur = CMU::Netdb::rep_machines_by_user($dbh, $user);
  if (!ref $sur) {
    if ($sur eq $CMU::Netdb::errcodes{EPERM}) {
      CMU::WebInt::accessDenied();
    }else{
      print "Unknown error reading rep_machines_by_user.\n";
    }
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }
  print "<table border=1>\n";
  print "<tr><th>User</th><th>Utilization</th><th>Machines</th>\n";
  my @sorder = sort { $$sur{$b}->[1] <=> $$sur{$a}->[1] } keys %$sur;
  
  my ($stat, $imgColor, $width);
  my $FF = "<font face=\"Arial,Helvetica,Geneva,Charter\">";
  foreach my $s (@sorder) {
    next if ($$sur{$s}->[1] < 15);
    my $uid = $s;
    $uid =~ s/\,.+//;

    print "<tr><td><b>$FF<a href=$url?op=mach_s_exec&ugtype=USER&uid=$uid>".
      "$$sur{$s}->[0] [$uid]</a></b></td><td>";
    $stat = $$sur{$s}->[1];
    $imgColor = 'red';
    $imgColor = 'yellow' if ($stat < 100);
    $imgColor = 'green' if ($stat < 50);
    $width = int($stat);
    $width = 301 if ($width >= 300);
    print "<img src=/img/$imgColor-small.jpg height=10 width=$width>";
    print "+" if ($width == 301);
    print "</td><td>$$sur{$s}->[1]</td></tr>\n";
  }
  
  print "</table>\n";
  print &CMU::WebInt::stdftr($q);
  
  $dbh->disconnect();
}

sub rep_printlabels {
  my ($q, $errors) = @_;
  my ($dbh, @params, $i);
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my %cable_p = %CMU::Netdb::structure::cable_printable;
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Print Labels", $errors);
  &CMU::WebInt::title("Outlet Label Generation");
  print &CMU::WebInt::subHeading("Label Parameters");
  
  if ($q->param("from_or_to") eq "") {
    print "<br><form method=get>
<input type=hidden name=op value=rep_printlabels>
<table border=0>
<tr><td bgcolor=$THCOLOR>Choose labels by</td>
<td>" . $q->radio_group(-name=>"from_or_to", -values=>["from", "to"], 
			-default=>"from", -linebreak=>"true", 
			-labels=>{"from" => "Closet location",
				  "to" => "Outlet location"}) . "</td></tr></table>";
    print "<input type=submit value=\"Continue\"></form>\n";
  } elsif ($q->param("from_or_to") eq "from") {
    print "<br><form method=get>
<input type=hidden name=op value=rep_printlabels_confirm>
<table border=0>";
    foreach (qw/from_building from_closet from_rack from_panel/) {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.'.$_}."</td><td>".$q->textfield(-name => $_)."</td></tr>\n";
    }
    print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_x'}." Start</td><td>".$q->textfield(-name => "from_x")."</td></tr>\n";
    print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_x'}." End</td><td>".$q->textfield(-name => "from_x_end")."</td></tr>\n";
    print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_y'}." Start</td><td>".$q->textfield(-name => "from_y")."</td></tr>\n";
    print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_y'}." End</td><td>".$q->textfield(-name => "from_y_end")."</td></tr>\n";
    print "<tr><td bgcolor=$THCOLOR>Use XY as:".
      $q->radio_group(-name => 'xytype',
		      -values => ['grid','range'],
		      -default=>'grid',
		      -labels=> {'grid' => 'coordinate grid',
				 'range' =>'numeric range'}) . "</td></tr>\n";
    print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.prefix'}."</td><td>".$q->textfield(-name => "prefix")."</td></tr>\n";
    print "</table>\n";
  
    @params = $q->param();
    $i=0;
    foreach (grep /^multilabel/, @params) {
      print "<input type=hidden name=multilabel$i value=" . $q->param($_) . ">\n";
      $i++;
    }
    if ($i > 0){
      print "<br><b>$i</b> other sets of labels already entered.<br>\n";
    }

    print "<input type=hidden name=from_or_to value=from>\n";
    print "<input type=submit value=\"Generate Labels\"></form>\n";
  } elsif ($q->param("from_or_to") eq "to") {
    print "<br><form method=get>
<input type=hidden name=op value=rep_printlabels_confirm>
<table border=0>";
    foreach (qw/to_building to_wing to_floor/) {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.'.$_}."</td><td>".$q->textfield(-name => $_)."</td></tr>\n";
    }
    print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.prefix'}."</td><td>".$q->textfield(-name => "prefix")."</td></tr>\n";
    print "</table>\n";
  
    @params = $q->param();
    $i=0;
    foreach (grep /^multilabel/, @params) {
      print "<input type=hidden name=multilabel$i value=" . $q->param($_) . ">\n";
      $i++;
    }
    if ($i > 0){
      print "<br><b>$i</b> other sets of labels already entered.<br>\n";
    }

    print "<input type=hidden name=from_or_to value=to>\n";
    print "<input type=submit value=\"Generate Labels\"></form>\n";
  } else {
    if ($debug >= 1) {
      print "<br>Unknown from_or_to value " . $q->param("from_or_to") . "<br>";
    }
  }

  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}

sub rep_printlabels_confirm {
  my ($q, $errors) = @_;
  my ($dbh, $query, $param, $cables, $i, $short_form, @params, $morelabels_url);
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my %cable_p = %CMU::Netdb::structure::cable_printable;
  my ($building, $wing, $floor, $closet, $rack, $panel, $xstart, 
      $xend, $ystart, $yend, $xytype, $prefix);
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Print Labels", $errors);
  
  my ($res, $DoNoGrid) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DoNoGrid');

  if (($res != 1) || (! defined $DoNoGrid) || ($DoNoGrid ne '1')) {
    $DoNoGrid = 0;
  } else {
    $DoNoGrid = 1;
  }

  $query = "";
  $short_form = "";
  &CMU::WebInt::title("Outlet Label Generation Confirmation");
  print &CMU::WebInt::subHeading("Label Parameters");
  
  print "<br><form method=get>
<input type=hidden name=op value=rep_genlabel_ps>
<table border=0>";
  
  if ($q->param("from_or_to") eq "from") {
    if ($q->param("from_building") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_building'}."</td><td>"
	. $q->param("from_building")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_building", $q->param("from_building"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_building"]) if (CMU::Netdb::getError($param) != 1);
      $building=$param;
      $query .= " AND" if ($query ne "");
      $query .= " from_building = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_building'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("from_closet") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_closet'}."</td><td>"
	. $q->param("from_closet")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_closet", $q->param("from_closet"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_closet"]) if (CMU::Netdb::getError($param) != 1);
      $closet=$param;
      $query .= " AND" if ($query ne "");
      $query .= " from_closet = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_closet'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("from_rack") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_rack'}."</td><td>"
	. $q->param("from_rack")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_rack", $q->param("from_rack"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_rack"]) if (CMU::Netdb::getError($param) != 1);
      $rack=$param;
      $query .= " AND" if ($query ne "");
      $query .= " from_rack = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_rack'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("from_panel") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_panel'}."</td><td>"
	. $q->param("from_panel")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_panel", $q->param("from_panel"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_panel"]) if (CMU::Netdb::getError($param) != 1);
      $panel=$param;
      $query .= " AND" if ($query ne "");
      $query .= " from_panel = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_panel'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("from_x") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_x'}."</td><td>"
	. $q->param("from_x")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_x", $q->param("from_x"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_x"]) if (CMU::Netdb::getError($param) != 1);
      $xstart=$param;
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_x'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("from_x_end") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_x'}."</td><td>"
	. $q->param("from_x_end")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_x", $q->param("from_x_end"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_x"]) if (CMU::Netdb::getError($param) != 1);
      $xend=$param;
    } 
    if ($q->param("from_y") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_y'}."</td><td>"
	. $q->param("from_y")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_y", $q->param("from_y"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_y"]) if (CMU::Netdb::getError($param) != 1);
      $ystart=$param;
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_y'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("from_y_end") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.from_y'}."</td><td>"
	. $q->param("from_y_end")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.from_y", $q->param("from_y_end"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["from_y"]) if (CMU::Netdb::getError($param) != 1);
      $yend=$param;
    } 
    if ($q->param("xytype") ne "") {
      print "<tr><td bgcolor=$THCOLOR>XY Type</td><td>"
	. $q->param("xytype") . "</td></tr>\n";
      $xytype = $q->param("xytype");
    }
    if ($q->param("prefix") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.prefix'}."</td><td>"
	. $q->param("prefix")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.prefix", $q->param("prefix"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["prefix"]) if (CMU::Netdb::getError($param) != 1);
      $prefix=$param;
      $query .= " AND" if ($query ne "");
      $query .= " prefix = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.prefix'}."</td><td>Any</td></tr>\n";
    }
    
    print "</table>\n";
    
    if ($xytype eq 'grid') {
      if ($xstart ne "")  {
	if (($xend eq "") || 
	    ($xend eq $xstart)) {
	  $query .= " AND" if ($query ne "");
	  $query .= " from_x = \"$xstart\"";
	} else {
	  $query .= " AND" if ($query ne "");
	  $query .= " from_x >= \"$xstart\" AND from_x <= \"$xend\"";
	}
      }
      if ($ystart ne "") {
	if (($yend eq "") || 
	    ($yend eq $ystart)) {
	  $query .= " AND" if ($query ne "");
	  $query .= " from_y = \"$ystart\"";
	} else {
	  $query .= " AND" if ($query ne "");
	  $query .= " from_y >= \"$ystart\" AND from_y <= \"$yend\"";
	}
      }
    } elsif ($xytype eq 'range') {
      if ($xstart ne "")  {
	if (($xend eq "") || 
	    ($xend eq $xstart)) {
	  $query .= " AND" if ($query ne "");
	  $query .= " from_x = \"$xstart\"";
	  if ($ystart ne "") {
	    if (($yend eq "") || 
		($yend eq $ystart)) {
	      $query .= " AND" if ($query ne "");
	      $query .= " from_y = \"$ystart\"";
	    } else {
	      $query .= " AND" if ($query ne "");
	      $query .= " from_y >= \"$ystart\" AND from_y <= \"$yend\"";
	    }
	  }
	} else {
	  if ($ystart ne "") {
	    if (($yend eq "") || 
		($yend eq $ystart)) {
	      $query .= " AND" if ($query ne "");
	      $query .= " from_x >= \"$xstart\" and from_x <= \"$xend\"";
	      $query .= " AND from_y = \"$ystart\"";
	    } else {
	      $query .= " AND" if ($query ne "");
	      $query .= " (from_x * 10) + from_y >= \"" .(($xstart * 10) + $ystart) . "\" AND (from_x * 10) + from_y <= \"" . (($xend *10) +$yend) ."\"";
	    }
	  } else {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_x >= \"$xstart\" AND from_x <= \"$xend\"";
	  }
	}
      } else {
	if ($ystart ne "") {
	  if (($yend eq "") || 
	      ($yend eq $ystart)) {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_y = \"$ystart\"";
	  } else {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_y >= \"$ystart\" AND from_y <= \"$yend\"";
	  }
	}
      }
    }
    
    $short_form = "$building-$closet-$rack-$panel-$xstart-$xend-$ystart-$yend-$xytype-$prefix";

    $query .= " AND" if ($query ne "");
    $query .= " label_to != ''";

    $morelabels_url="&from_or_to=from&multilabel0=" . $short_form;
  
    print "<input type=hidden name=from_or_to value=from>\n";

  } elsif ($q->param("from_or_to") eq "to") {
    if ($q->param("to_building") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.to_building'}."</td><td>"
	. $q->param("to_building")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.to_building", $q->param("to_building"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["to_building"]) if (CMU::Netdb::getError($param) != 1);
      $building=$param;
      $query .= " AND" if ($query ne "");
      $query .= " to_building = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.to_building'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("to_wing") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.to_wing'}."</td><td>"
	. $q->param("to_wing")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.to_wing", $q->param("to_wing"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["to_wing"]) if (CMU::Netdb::getError($param) != 1);
      $wing=$param;
      $query .= " AND" if ($query ne "");
      $query .= " to_wing = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.to_wing'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("to_floor") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.to_floor'}."</td><td>"
	. $q->param("to_floor")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.to_floor", $q->param("to_floor"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["to_floor"]) if (CMU::Netdb::getError($param) != 1);
      $floor=$param;
      $query .= " AND" if ($query ne "");
      $query .= " to_floor = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.to_floor'}."</td><td>Any</td></tr>\n";
    }
    if ($q->param("prefix") ne "") {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.prefix'}."</td><td>"
	. $q->param("prefix")."</td></tr>\n";
      $param = CMU::Netdb::valid("cable.prefix", $q->param("prefix"), $user, 0, $dbh);
      return (CMU::Netdb::getError($param), ["prefix"]) if (CMU::Netdb::getError($param) != 1);
      $prefix=$param;
      $query .= " AND" if ($query ne "");
      $query .= " prefix = \"$param\"";
    } else {
      print "<tr><td bgcolor=$THCOLOR>".$cable_p{'cable.prefix'}."</td><td>Any</td></tr>\n";
    }

    print "</table>\n";

    $short_form = "$building-$wing-$floor-$prefix";

    $query .= " AND to_closet = ''";

    $morelabels_url="&from_or_to=to&multilabel0=" . $short_form;
  
    print "<input type=hidden name=from_or_to value=to>\n";


  } else {
    if ($debug >= 1) {
      print "<br>Unknown from_or_to value " . $q->param("from_or_to") . "<br>";
    }
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }
  $cables = CMU::Netdb::list_cables($dbh, $user, $query);
  if (!ref $cables) {
    print "ERROR with list_cables: ".$CMU::Netdb::errors::errmeanings{$cables};
    print &CMU::WebInt::stdftr($q);
    return;
  }
  
  print "<br><b>" . ($#$cables + 1) . "</b> Cables match this query.<br>\n";
  
  @params = $q->param();
  $i=1;
  print "<input type=hidden name=multilabel0 value=$short_form>\n";
  foreach (grep /^multilabel/, @params) {
    $morelabels_url .= "&multilabel" . $i . "=" . $q->param($_);
    print "<input type=hidden name=multilabel$i value=" . $q->param($_) . ">\n";
    $i++;
  }
  if ($i > 1){
    print "<br><b>". ($i - 1) . "</b> other sets of labels already entered.<br>\n";
  }
  
  print "<br>Need to add more labels to this output? Click <a href=" 
    . $ENV{SCRIPT_NAME} . "?op=rep_printlabels" . $morelabels_url . ">here</a>.\n";
  print "<br>Ready to print labels?  Click below.\n";

  if ($DoNoGrid) {
    print "<br>Print labels " . $q->popup_menu(-name=>'noGrid',
					       -values=>[0,1],
					       -default=>0,
					       -labels=>{0=>'with',
							 1=>'without'
							}
					      ) . ' grid coordinates';
  }
  print "<br>Skip how many LAT-11 labels?  " . $q->textfield(-name => "lat11skip",
							     -value => 0) . "\n";
  print "<input type=submit name=\"type\" value=\"Generate LAT-11 Labels\">\n";
  print "<br>Skip how many LAT-4 labels?  " . $q->textfield(-name => "lat4skip",
							    -value => 0) . "\n";
  print "<input type=submit name=\"type\" value=\"Generate LAT-4 Labels\">\n";
  print "</form><br>" . CMU::WebInt::stdftr($q);
  
  $dbh->disconnect();
  
}


sub rep_genlabel_ps {
  my ($q, $errors) = @_;
  my ($dbh, $query, $param, $cables, $ps, $i, $skip, @params, 
      $page, $pagesize, $label_from, $label_to, $mainquery,
      $basevert, $basehorz, $spc, $interline, $horizspace, $pagewidth,
      $fontmatrix, $labeltype, $building, $wing, $floor, $closet, $rack, $panel, 
      $xstart, $xend, $ystart, $yend, $xytype, $prefix, $attribs, $atpos,
      $uinfo, $uipos, $attr_hash, $noGrid, $capos, $cable);
  my %cable_p = %CMU::Netdb::structure::cable_printable;
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  my ($res, $DoNoGrid) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'DoNoGrid');

  if (($res != 1) || (! defined $DoNoGrid) || ($DoNoGrid ne '1')) {
    $noGrid = 0;
  } else {
    if (defined($q->param('noGrid'))) {
      $noGrid = $q->param('noGrid');
    } else {
      $noGrid = 0;
    }
  }
  

  if ($q->param("from_or_to") eq "from") {
    $mainquery="";
    @params = $q->param();
    $i=1;
    foreach (grep /^multilabel/, @params) {
      $query = "";
      ($building, $closet, $rack, $panel, $xstart, $xend, $ystart, $yend, $xytype, $prefix) =
	split /-/, $q->param($_), 10;
      
      
      if ($building ne "") {
	$param = CMU::Netdb::valid("cable.from_building", $building, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_building"]) if (CMU::Netdb::getError($param) != 1);
	$building=$param;
	$query .= " AND" if ($query ne "");
	$query .= " from_building = \"$param\"";
      }
      if ($closet ne "") {
	$param = CMU::Netdb::valid("cable.from_closet", $closet, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_closet"]) if (CMU::Netdb::getError($param) != 1);
	$closet=$param;
	$query .= " AND" if ($query ne "");
	$query .= " from_closet = \"$param\"";
      } 
      if ($rack ne "") {
	$param = CMU::Netdb::valid("cable.from_rack", $rack, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_rack"]) if (CMU::Netdb::getError($param) != 1);
	$rack=$param;
	$query .= " AND" if ($query ne "");
	$query .= " from_rack = \"$param\"";
      }
      if ($panel ne "") {
	$param = CMU::Netdb::valid("cable.from_panel", $panel, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_panel"]) if (CMU::Netdb::getError($param) != 1);
	$panel=$param;
	$query .= " AND" if ($query ne "");
	$query .= " from_panel = \"$param\"";
      }
      if ($xstart ne "") {
	$param = CMU::Netdb::valid("cable.from_x", $xstart, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_x"]) if (CMU::Netdb::getError($param) != 1);
	$xstart=$param;
      }
      if ($xend ne "") {
	$param = CMU::Netdb::valid("cable.from_x", $xend, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_x"]) if (CMU::Netdb::getError($param) != 1);
	$xend=$param;
      } 
      if ($ystart ne "") {
	$param = CMU::Netdb::valid("cable.from_y", $ystart, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_y"]) if (CMU::Netdb::getError($param) != 1);
	$ystart=$param;
      }
      if ($yend ne "") {
	$param = CMU::Netdb::valid("cable.from_y", $yend, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["from_y"]) if (CMU::Netdb::getError($param) != 1);
	$yend=$param;
    } 
#      if ($xytype ne "") {
#	print "<tr><td bgcolor=$THCOLOR>XY Type</td><td>$xytype</td></tr>\n";
#      }
      if ($prefix ne "") {
	$param = CMU::Netdb::valid("cable.prefix", $prefix, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["prefix"]) if (CMU::Netdb::getError($param) != 1);
	$prefix=$param;
	$query .= " AND" if ($query ne "");
	$query .= " prefix = \"$param\"";
      }
      
      
      if ($xytype eq 'grid') {
	if ($xstart ne "")  {
	  if (($xend eq "") || 
	      ($xend eq $xstart)) {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_x = \"$xstart\"";
	  } else {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_x >= \"$xstart\" AND from_x <= \"$xend\"";
	  }
	}
	if ($ystart ne "") {
	  if (($yend eq "") || 
	      ($yend eq $ystart)) {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_y = \"$ystart\"";
	  } else {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_y >= \"$ystart\" AND from_y <= \"$yend\"";
	  }
	}
      } elsif ($xytype eq 'range') {
	if ($xstart ne "")  {
	  if (($xend eq "") || 
	      ($xend eq $xstart)) {
	    $query .= " AND" if ($query ne "");
	    $query .= " from_x = \"$xstart\"";
	    if ($ystart ne "") {
	      if (($yend eq "") || 
		  ($yend eq $ystart)) {
		$query .= " AND" if ($query ne "");
		$query .= " from_y = \"$ystart\"";
	      } else {
		$query .= " AND" if ($query ne "");
		$query .= " from_y >= \"$ystart\" AND from_y <= \"$yend\"";
	      }
	    }
	  } else {
	    if ($ystart ne "") {
	      if (($yend eq "") || 
		  ($yend eq $ystart)) {
		$query .= " AND" if ($query ne "");
		$query .= " from_x >= \"$xstart\" and from_x <= \"$xend\"";
		$query .= " AND from_y = \"$ystart\"";
	      } else {
		$query .= " AND" if ($query ne "");
		$query .= " (from_x * 10) + from_y >= \"" .(($xstart * 10) + $ystart) . "\" AND (from_x * 10) + from_y <= \"" . (($xend *10) +$yend) ."\"";
	      }
	    } else {
	      $query .= " AND" if ($query ne "");
	      $query .= " from_x >= \"$xstart\" AND from_x <= \"$xend\"";
	    }
	  }
	} else {
	  if ($ystart ne "") {
	    if (($yend eq "") || 
		($yend eq $ystart)) {
	      $query .= " AND" if ($query ne "");
	      $query .= " from_y = \"$ystart\"";
	    } else {
	      $query .= " AND" if ($query ne "");
	      $query .= " from_y >= \"$ystart\" AND from_y <= \"$yend\"";
	    }
	  }
	}
      }
      
      if ($query ne "") {
	$mainquery .= " OR " if ($mainquery ne "");
	$mainquery .= "( $query )";
      }
    }
    
    $mainquery .= " AND label_to != '' ORDER BY label_from";

  } elsif ($q->param("from_or_to") eq "to") {
    $mainquery="";
    @params = $q->param();
    $i=1;
    foreach (grep /^multilabel/, @params) {
      $query = "";
      ($building, $wing, $floor, $prefix) =
	split /-/, $q->param($_), 4;
      
      
      if ($building ne "") {
	$param = CMU::Netdb::valid("cable.to_building", $building, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["to_building"]) if (CMU::Netdb::getError($param) != 1);
	$building=$param;
	$query .= " AND" if ($query ne "");
	$query .= " to_building = \"$param\"";
      }
      if ($wing ne "") {
	$param = CMU::Netdb::valid("cable.to_wing", $wing, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["to_wing"]) if (CMU::Netdb::getError($param) != 1);
	$wing=$param;
	$query .= " AND" if ($query ne "");
	$query .= " to_wing = \"$param\"";
      } 
      if ($floor ne "") {
	$param = CMU::Netdb::valid("cable.to_floor", $floor, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["to_floor"]) if (CMU::Netdb::getError($param) != 1);
	$floor=$param;
	$query .= " AND" if ($query ne "");
	$query .= " to_floor = \"$param\"";
      }
      if ($prefix ne "") {
	$param = CMU::Netdb::valid("cable.prefix", $prefix, $user, 0, $dbh);
	return (CMU::Netdb::getError($param), ["prefix"]) if (CMU::Netdb::getError($param) != 1);
	$prefix=$param;
	$query .= " AND" if ($query ne "");
	$query .= " prefix = \"$param\"";
      }

      if ($query ne "") {
	$mainquery .= " OR " if ($mainquery ne "");
	$mainquery .= "( $query )";
      }
    }

    $mainquery .= " AND to_closet = '' ORDER BY label_to";

  } else {
    if ($debug >= 1) {
      print "<br>Unknown from_or_to value " . $q->param("from_or_to") . "<br>";
    }
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  $cables = CMU::Netdb::list_cables($dbh, $user, $mainquery);
  if (!ref $cables) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Print labels", $errors);
    &CMU::WebInt::title("Outlet Label Generation Confirmation");
    print "ERROR with list_cables: ".$CMU::Netdb::errors::errmeanings{$cables};
    print &CMU::WebInt::stdftr($q);
    return;
  }
  
  if ($#$cables == 0) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Print labels", $errors);
    &CMU::WebInt::title("Outlet Label Generation Confirmation");
    print "<br>No matching cables.<br>\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  

  $uinfo = CMU::Netdb::list_users($dbh, $user, "credentials.authid = \"$user\"");
  $uipos = CMU::Netdb::makemap(shift(@$uinfo));
  


  if ($q->param("type") eq "Generate LAT-4 Labels") {
# Get any user attributes for printing these

    $attribs = CMU::Netdb::list_attribute($dbh, $user, "((attribute_spec.name like \"lat-4 %\") and (owner_tid = $uinfo->[0][$uipos->{'users.id'}]))");
    $atpos = CMU::Netdb::makemap(shift(@$attribs));
    
    $attr_hash = {};
    foreach (@$attribs) {
      $attr_hash->{$_->[$atpos->{'attribute_spec.name'}]} = $_->[$atpos->{'attribute.data'}];
    }

    #Initialize parameters
    $basevert = (defined $attr_hash->{'lat-4 vertical offset'}) ? $attr_hash->{'lat-4 vertical offset'} : 6700;
    $basehorz = (defined $attr_hash->{'lat-4 horizontal offset'}) ? $attr_hash->{'lat-4 horizontal offset'} : 4000;
    $spc = (defined $attr_hash->{'lat-4 vertical spacing'}) ? $attr_hash->{'lat-4 vertical spacing'} : 1800;
    $interline = (defined $attr_hash->{'lat-4 interline space'}) ? $attr_hash->{'lat-4 interline space'} : 750;
    $horizspace = (defined $attr_hash->{'lat-4 horizontal spacing'}) ? $attr_hash->{'lat-4 horizontal spacing'} : 7200;
    $pagewidth = 58000;
    $fontmatrix = "[800 0 0 -800 0 0]";
    $labeltype = "LAT-4 forms";
    $skip = $q->param("lat4skip");
    if (($skip < 0) || $skip > 37) {
      $skip = 0;
    }
    $pagesize = 38;
  } elsif ($q->param("type") eq "Generate LAT-11 Labels") {
# Get any user attributes for printing these

    $attribs = CMU::Netdb::list_attribute($dbh, $user, "((attribute_spec.name like \"lat-11 %\") and (owner_tid = $uinfo->[0][$uipos->{'users.id'}]))");
    $atpos = CMU::Netdb::makemap(shift(@$attribs));
    
    $attr_hash = {};
    foreach (@$attribs) {
      $attr_hash->{$_->[$atpos->{'attribute_spec.name'}]} = $_->[$atpos->{'attribute.data'}];
    }

    #Initialize parameters
    $basevert = (defined $attr_hash->{'lat-11 vertical offset'}) ? $attr_hash->{'lat-11 vertical offset'} : 7100;
    $basehorz = (defined $attr_hash->{'lat-11 horizontal offset'}) ? $attr_hash->{'lat-11 horizontal offset'} : 3800;
    $spc = (defined $attr_hash->{'lat-11 vertical spacing'}) ? $attr_hash->{'lat-11 vertical spacing'} : 2695;
    $interline = (defined $attr_hash->{'lat-11 interline space'}) ? $attr_hash->{'lat-11 interline space'} : 1100;
    $horizspace = (defined $attr_hash->{'lat-11 horizontal spacing'}) ? $attr_hash->{'lat-11 horizontal spacing'} : 14300;
    $pagewidth = 58000;
    $fontmatrix = "[1400 0 0 -1200 0 0]";
    $labeltype = "LAT-11 forms";
    $skip = $q->param("lat11skip");
    if (($skip < 0) || $skip > 24) {
      $skip = 0;
    }
    $pagesize = 25;
  } else {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Print labels", $errors);
    &CMU::WebInt::title("Outlet Label Generation Confirmation");
    print "Error: Unknown label type\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  
  $ps = <<END_PS;
%!PS-Adobe-1.0
%%DocumentFonts: Courier-Bold
%%Title: Outlet Labels, PostScript Format, $labeltype
%%Creator: Netdb, written by CMU Network Development
%%For: $user
%%Pages: (atend)
%%EndComments

statusdict begin
/manualfeed true def
/manualfeedtimeout 300 def
end

/Courier-Bold findfont
$fontmatrix makefont
setfont

/basevert $basevert def      % Base vertical offset for first label
/basehoriz  $basehorz def    % Base horizontal inset for beginning of row
/spc $spc def           % Vertical spacing between labels
/interline $interline def     % Interline spacing on a single label
/horizspace $horizspace def      % Horizontal distance between labels
/PageWidth $pagewidth def
/setup {
        0 792 translate
        0.01 -0.01 scale
        /curvert basevert def   % Current vertical displacement
/} def
/ShowLabel {
        exch
        /TopLine exch def
        /BottomLine exch def
        basehoriz horizspace PageWidth {
                /curhoriz exch def      % Current horizontal displacement
                curhoriz curvert moveto
                TopLine show
                curvert interline add curhoriz exch moveto
                BottomLine show
                } for
        /curvert curvert spc add def
} def

<< /Staple 0 /OutputType (LEFT OUTPUT BIN) >> setpagedevice

%%EndProlog
END_PS
  
  
  $capos = CMU::Netdb::makemap(shift(@$cables));


  $label_from=$capos->{'cable.label_from'};
  $label_to=$capos->{'cable.label_to'};
  
  $ps .= "%%Page: 1 1\n\nsetup\n";
  $page = 1;
  for ($i=0; $i < $skip; $i++) {
    $ps .= "() () ShowLabel\n";
  }
  
  

  $i = 0;
  foreach $cable (@$cables) {
    my ($top, $bottom);
    $i++;
    if ($noGrid) {
      $top = $cable->[$label_from];
      $bottom = $cable->[$label_to];
      $bottom =~ s/-[^-]*$// if ($bottom =~ /^[^-]+-[^-]+$/);
      if ($labeltype eq "LAT-4 forms") {
	$top =~ s/[^-]*-//;
	if ($bottom !~ /-/) {
	  $bottom = '#' . substr($cable->[$capos->{'cable.to_room_number'}],0,10);
	} else {
	  $bottom =~ s/[^-]*-//;
	}
      }
    } else {
      $top = $cable->[$label_from];
      $bottom = $cable->[$label_to];
      $top =~ s/[^-]*-// if ($labeltype eq "LAT-4 forms");
      $bottom =~ s/[^-]*-// if ($labeltype eq "LAT-4 forms");
    }
    $ps .= "($top) ($bottom) ShowLabel\n";
    if ((($i + $skip) % $pagesize) == 0) {
      $page++;
      $ps .= "showpage\n%%Page: $page $page\n\nsetup\n";
    }
  }
  
  $ps .= "showpage\n%%Trailer\n%%Pages: $page\n";

  use Digest::MD5 qw(md5_base64);
  my $digest = md5_base64($mainquery . time());
  $digest =~ s,/,,g;
  open PSFILE, ">/home/netreg/htdocs/reports/$digest.ps" or die("Unable to open report output file /home/netreg/htdocs/reports/$digest.ps");

  print PSFILE $ps;

  close PSFILE;
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Print Labels", $errors);
  &CMU::WebInt::title("Outlet Label Generation");
  print "<br><a href=\"http://" . $q->server_name() . "/reports/$digest.ps\">Download Labels Now</a>\n";
  print CMU::WebInt::stdftr($q);
  
  $dbh->disconnect;
  
}

sub rep_telecomdump {
  my ($q, $errors) = @_;
  my ($dbh, @params, $i);
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my %cable_p = %CMU::Netdb::structure::cable_printable;
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Telecom Cable Dump", $errors);
  &CMU::WebInt::title("Cable Dump Generation");
  print &CMU::WebInt::subHeading("Cable Parameters");

  print "<br><form method=get>
<input type=hidden name=op value=rep_telecomdump_s2>\n";
  my $building = CMU::WebInt::gParam($q, 'from_building');
  if ($building) {
    print $q->hidden('from_building');
    print "Generate dump of cables in building $building that have been updated since:<br>\n";
  } else {
    print "Generate dump of cables in all buildings that have been updated since:<br>\n"
  }

  my @curtime = localtime(time);
  print $q->popup_menu(-name=>'month',
		       -values=>[1..12],
		       -default=>$curtime[4] + 1,
		       -labels=>{1 => 'Jan',
				 2 => 'Feb',
				 3 => 'Mar',
				 4 => 'Apr',
				 5 => 'May',
				 6 => 'Jun',
				 7 => 'Jul',
				 8 => 'Aug',
				 9 => 'Sep',
				 10 => 'Oct',
				 11 => 'Nov',
				 12 => 'Dec',});
  print $q->popup_menu(-name=>'day',
		       -values => [1..31],
		       -default => 1);
  print $q->popup_menu(-name=>'year',
		       -values => [2000..($curtime[5] + 1900)],
		       -default => ($curtime[5] + 1900));
  print "<input type=submit value=\"Generate Dump\"></form>\n";
  print CMU::WebInt::stdftr($q);
  
  $dbh->disconnect();
}

sub rep_telecomdump_s2 {
  my ($q, $errors) = @_;
  my ($dbh, $param, $building, $to_building, $label_from, $label_to, $room, 
      $query, $cables, $output, $i, %nerrors, $month, $day, $year, $when);
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  my %cable_p = %CMU::Netdb::structure::cable_printable;

  $building = CMU::WebInt::gParam($q,'from_building');
  $query = "";
  if ($building ne "") {
    $param = CMU::Netdb::valid("cable.from_building", $building, $user, 0, $dbh);
    return (CMU::Netdb::getError($param), ["from_building"]) if (CMU::Netdb::getError($param) != 1);
    $building = $param;
    
    $query = "from_building = $building";
  }

  $month = CMU::WebInt::gParam($q, 'month');
  $day = CMU::WebInt::gParam($q, 'day');
  $year = CMU::WebInt::gParam($q, 'year');
  
  $when = sprintf('%4.4d%2.2d%2.2d000000', $year, $month, $day);
  $query .= " AND " if ($query ne "");
  $query .= "version >= $when";

  $cables = CMU::Netdb::list_cables($dbh, $user, $query);
  
  if (!ref $cables) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Dump", $errors);
    &CMU::WebInt::title("Cable Dump Generation");
    print "ERROR with list_cables: ".$CMU::Netdb::errors::errmeanings{$cables};
    print &CMU::WebInt::stdftr($q);
    return;
  }
  
  if ($#$cables == 0) {
    print CMU::WebInt::stdhdr($q, $dbh, $user, "Cable Dump", $errors);
    &CMU::WebInt::title("Cable Dump Generation");
    print "<br>No matching cables.<br>\n";
    print &CMU::WebInt::stdftr($q);
    return;
  }
  
  for ($i = 0; $i <= $#{$cables->[0]}; $i++){
    if ($cables->[0]->[$i] eq "cable.label_from") {
      $label_from=$i;
    }
    if ($cables->[0]->[$i] eq "cable.label_to") {
      $label_to=$i;
    }
    if ($cables->[0]->[$i] eq "cable.to_room_number") {
      $room=$i;
    }
    if ($cables->[0]->[$i] eq "cable.to_building") {
      $to_building = $i;
    }
  }
  
  for ($i = 1; $i <= $#$cables; $i++) {
    $output .= $cables->[$i]->[$label_from] . "|" .
      $cables->[$i]->[$label_to] . "|" .
	$cables->[$i]->[$to_building] . "|" . 
	  $cables->[$i]->[$room] . "\n";
  }
  
  use Digest::MD5 qw(md5_base64);
  my $digest = md5_base64($output . time());
  $digest =~ s,/,,g;
  open DUMPFILE, ">/home/netreg/htdocs/reports/$digest.txt" or die("Unable to open report output file /home/netreg/htdocs/reports/$digest.txt");
  print DUMPFILE $output;
  close DUMPFILE;
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Telecom Cable Dump", $errors);
  &CMU::WebInt::title("Cable Dump Generation");
  print "<br><a href=\"http://" . $q->server_name() . "/reports/$digest.txt\">Download Dump Now</a>\n";
  print CMU::WebInt::stdftr($q);
  
  $dbh->disconnect;

}

sub rep_zone_config {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Zone Configurations", $errors);
  &CMU::WebInt::title("Zone Configurations");
  
  print CMU::WebInt::errorDialog($url, $errors);
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'dns_zone', 0);

  if ($ul < 9) {
    &CMU::WebInt::accessDenied('dns_zone', 'READ', 0, 9, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  my $zoneRef = CMU::Netdb::list_dns_zones
    ($dbh, $user, 
     " (type like '%toplevel' OR type like '%delegated') ".
     "ORDER BY type, name");
  if (!ref $zoneRef) {
    print "ERROR with list_dns_zones: ".$$CMU::Netdb::errors::errmeanings{$zoneRef};
    return 0;
  }
  my %zone_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::dns_zone_fields)};
  shift @$zoneRef;
  my %zone_p = %CMU::Netdb::structure::dns_zone_printable;
  
  my $resRef = CMU::Netdb::list_dns_resources($dbh, $user, " type = 'NS' ORDER BY rname");
  if (!ref $resRef) {
    print "ERROR with list_dns_resources: ".$CMU::Netdb::errors::errmeanings{$resRef};
    return 0;
  }
  my %res_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::dns_resource_fields)};
  shift(@$resRef);
  my %res_p =  %CMU::Netdb::structure::dns_resource_printable;
  
  my %ns;
  map {
    my ($ot, $rn) = ($ {$_}[$res_pos{'dns_resource.owner_tid'}],
		     $ {$_}[$res_pos{'dns_resource.rname'}]);

    if (!defined $ns{$ot}) {
      $ns{$ot} = [$rn];
    }else{
      push(@{$ns{$ot}}, $rn);
    }
  } @$resRef;
  
  my %zoneIDName;
  print &CMU::WebInt::subHeading("DNS Zones");
  print "<table><tr><th>Zone</th><th>Servers</th></tr>\n";
  foreach my $zr (@$zoneRef) {
    print "<tr><td><font face=\"Arial,Helvetica,Geneva,Charter\"<b> ".
      " ${$zr}[$zone_pos{'dns_zone.name'}] </b></td><td> ";
    my $ot = $ {$zr}[$zone_pos{'dns_zone.id'}];

    if (!defined $ns{$ot}) {
      print "No nameserver records for zone found!<br>\n";
    }else{
      print join(", ", @{$ns{$ot}})."<br>";
      $zoneIDName{$ot} = $ {$zr}[$zone_pos{'dns_zone.name'}];
    }
    print "</td></tr>\n";
  }
  print "</table>\n";
  
  print "<br>".&CMU::WebInt::subHeading("Nameserver Report");
  my $last = 'NO-NAME';
  foreach my $dr (@$resRef) {
    if ($last ne $ {$dr}[$res_pos{'dns_resource.rname'}]) {
      $last = $ {$dr}[$res_pos{'dns_resource.rname'}];
      print "</ul><br><font face=\"Arial,Helvetica,Geneva,Charter\" size=+1><b> ".
        "$last</b></font><br><ul>\n";
    }
    my $ot = $ {$dr}[$res_pos{'dns_resource.owner_tid'}];
    if (!defined $zoneIDName{$ot}) {
      print "<li>Unknown owner: $ot\n";
    }else{
      print "<li>".$zoneIDName{$ot}."\n";
    }
  }
  print "</ul>\n";
  $dbh->disconnect();
  print CMU::WebInt::stdftr($q);
}

sub rep_abuse_suspend {
  my ($q, $errors) = @_;
  my ($dbh, $userlevel, %errors);

  my $url = $ENV{SCRIPT_NAME};
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  print CMU::WebInt::stdhdr($q, $dbh, $user,
			    "Abuse/Suspended Machine Report", $errors);
  &CMU::WebInt::title("Abuse/Suspended Machine Report");
  
  print CMU::WebInt::errorDialog($url, $errors);
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'machine', 0);

  if ($ul < 1) {
    &CMU::WebInt::accessDenied('machine', 'READ', 0, 1, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  print "<br><br>Users in <b>bold</b> are attached to directly to the record. Non-bold users ".
    "are in an associated group.<br>\n";
 
  my $ruRef = CMU::Netdb::list_machines
    ($dbh, $user, 
     " find_in_set('abuse', flags) OR find_in_set('suspend', flags) ORDER BY machine.host_name");
  if (!ref $ruRef) {
    print "ERROR with list_machine: ".$CMU::Netdb::errors::errmeanings{$ruRef};
    $dbh->disconnect;
    print CMU::WebInt::stdftr($q);
    return;
  }

  my %machine_pos = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::machine_fields)};
  my %edata = ('machine_pos' => \%machine_pos,
	       'dbh' => $dbh,
	       'user' => $user);
  CMU::WebInt::generic_tprint($url, $ruRef, 
			      ['machine.host_name', 'machine.mac_address', 'machine.comment_lvl9'],
			      [\&CMU::WebInt::machines::mach_cb_print_IP,
			       \&rep_cb_abuse_flags, \&rep_cb_abuse_upd, 
			       \&rep_cb_abuse_users],
			      \%edata, '', 'op=mach_view&id=', \%machine_pos,
			      \%CMU::Netdb::structure::machine_printable,
			      'machine.host_name', 'machine.id', '', []);

  $dbh->disconnect;
  print CMU::WebInt::stdftr($q);
}

sub rep_cb_abuse_upd {
  my ($url, $row, $edata) = @_;
  my %edata = %{$edata};
  my %machine_pos = %{$edata{'machine_pos'}};
  return 'Last updated' unless (ref $row);
  my @rrow = @{$row};
  return $rrow[$machine_pos{'machine.version'}] . "\n";
}

sub rep_cb_abuse_flags {
  my ($url, $row, $edata) = @_;
  my %edata = %{$edata};
  my %machine_pos = %{$edata{'machine_pos'}};

  return $CMU::Netdb::structure::machine_printable{'machine.flags'} unless (ref $row);
  my @rrow = @{$row};
  return join(', ', map { ucfirst($_); } 
	      split(/\s*\,\s*/, $rrow[$machine_pos{'machine.flags'}]));
}

sub rep_cb_abuse_users {
  my ($url, $row, $edata) = @_;
  my %edata = %{$edata};
  my %machine_pos = %{$edata{'machine_pos'}};
  my $dbh = $edata{'dbh'};
  return 'Contacts' unless (ref $row);
  ## get the registered user info
  my @rrow = @{$row};
  my $perm = CMU::Netdb::list_protections($edata{dbh}, $edata{user}, 'machine', 
			      $rrow[$machine_pos{'machine.id'}], '');
  return 'Error!' if (!ref $perm);

  my (@us, @grp);
  foreach (@$perm) {
    my @lrow = @{$_};
    push (@us, $lrow[1]) if ($lrow[0] eq 'user');
    push (@grp, $lrow[1]) if ($lrow[0] eq 'group');
  }
  return join(", ", ((map { "<b>$_</b>" } @us), @grp));
}
			   
sub rep_subnet_map {
  my ($q, $errors) = @_;

  my ($dbh, $url, $userlevel, %errors);

  $url = $ENV{SCRIPT_NAME};

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();

  print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Map", $errors);
  &CMU::WebInt::title("Subnet Map");

  print CMU::WebInt::errorDialog($url, $errors);
  my $ul = CMU::Netdb::get_read_level($dbh, $user, 'subnet', 0);
  my $al = CMU::Netdb::get_add_level($dbh, $user, 'subnet', 0);

  if ($ul < 9) {
    &CMU::WebInt::accessDenied('subnet', 'READ', 0, 9, $ul, $user);
    $dbh->disconnect();
    print CMU::WebInt::stdftr($q);
    return;
  }

  # Variables that control the way we make the tables
  my ($res, $SMConfig) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'SubnetMap');

  warn __FILE__ . ":" . __LINE__ . ": get_multi_conf_var returned \n" . Data::Dumper->Dump([$res, $SMConfig],[qw(res SMConfig)]) . "\n" if ($debug); 

  if (! ref $SMConfig eq 'HASH') {
    # For backwards compatibility, check the netdb config file...
    ($res, $SMConfig) = CMU::Netdb::config::get_multi_conf_var
    ('netdb', 'SubnetMap');

  warn __FILE__ . ":" . __LINE__ . ": get_multi_conf_var returned \n" . Data::Dumper->Dump([$res, $SMConfig],[qw(res SMConfig)]) . "\n" if ($debug);
  }

  $SMConfig = {} unless (ref $SMConfig eq 'HASH');

  # Defaults
  $SMConfig->{'bucket-step'} = 8 unless (defined $SMConfig->{'bucket-step'});
  $SMConfig->{'table-threshold'} = 0.5
    unless (defined $SMConfig->{'table-threshold'});
  $SMConfig->{'table-width'} = 4
    unless (defined $SMConfig->{'table-width'});
  $SMConfig->{'show-create-links'} = 0
    unless (defined $SMConfig->{'show-create-links'});
  
  
  $SMConfig->{'show-create-links'} &= ($al >= 9);
 
  # Print out a color legend

  my @types = sort keys %SMap_Default_Colors;
  print "<table>\n";
  print "<tr><th>Subnet Type</th><td>", join("</td><td>", map { ucfirst } @types), "</td></tr>\n";
  print "<tr><th>Color</th>", join('', map { "<td bgcolor=\"" . $SMap_Default_Colors{$_} . "\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>" } @types), "</tr>\n";

  print "</table>\n";

  warn __FILE__ . ":" . __LINE__ . ": calling rep_smap_rec with \n" . Data::Dumper->Dump([$SMConfig],[qw(SMConfig)]) . "\n" if $debug;

  rep_smap_rec($dbh, $user, $url, $q, $SMConfig,
	       CMU::Netdb::helper::dot2long('0.0.0.0'), '0');

  print CMU::WebInt::stdftr($q);

  $dbh->disconnect;
}

sub rep_smap_rec {
  my ($dbh, $user, $url, $q, $SMConfig, $base, $mask) = @_;
  my (%hr_keys, $force, $fbase, $fmask);

  my $longMask = CMU::Netdb::helper::CIDR2mask($mask);

  # Check to see if this is a "forced" table.
  if (defined $SMConfig->{force}) {

    $SMConfig->{force} = [ $SMConfig->{force} ] if (! ref $SMConfig->{force});
    
    warn __FILE__ . ":" . __LINE__ . ": Force check for $base/$mask\n" if ($debug);
    $force = scalar (
		     grep {
		       ($fbase, $fmask) = split(/\//, $_);
		       (($fbase eq $base) && ($fmask == $mask));
		     } @{$SMConfig->{force}}
		    );
    warn __FILE__ . ":" . __LINE__ . ": Forcing $base/$mask\n" if ($force);
  }
    

  # Break into buckets
  # the numbers of bits to break the current base into (n buckets)
  my $bucketCIDR = $mask + $SMConfig->{'bucket-step'};
  my $bucketMask = CMU::Netdb::helper::CIDR2mask($bucketCIDR);
  my $bucketIPs = 2**(32-$bucketCIDR);

  warn __FILE__ . ":" . __LINE__ . ": Running rep_smap_rec \nbase = " .
    CMU::Netdb::long2dot($base) .
	"\nbucketMask = $bucketMask\n" .
	  "bucketIPs = $bucketIPs\n" if $debug;

  my $Q = "SELECT subnet.id, subnet.name, ".
" base_address & INET_ATON('$bucketMask') AS bucket, ".
" (((~network_mask & 0xFFFFFFFF) +1 )/".
" $bucketIPs) ".
" FROM subnet ".
" WHERE base_address & INET_ATON('$longMask') = INET_ATON('$base') ";


  warn __FILE__ . ":" . __LINE__ . ": Running rep_smap_rec query: $Q\n" if ($debug >= 3);

  my $sth = $dbh->prepare($Q);

  unless ($sth->execute()) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "rep_smap_rec: Query error: $DBI::errstr";
    return 0;
  }

  my $data = $sth->fetchall_arrayref;

# If we are not forcing this network, check to see if any of the 
#  forced subnets are in this range and not explicitly found by 
#  the database query.  If they should be and are not in the 
#  bucket list, put them in.
  if (defined $SMConfig->{force} && ! $force) {
    foreach (@{$SMConfig->{force}}) {
      ($fbase, $fmask) = split(/\//, $_);
      next if ((CMU::Netdb::dot2long($fbase) & CMU::Netdb::dot2long($longMask)) != CMU::Netdb::dot2long($base));
      push (@$data, [
		     0,
		     "Force of $_",
		     CMU::Netdb::dot2long($fbase) & CMU::Netdb::dot2long($bucketMask),
		     ((~ CMU::Netdb::dot2long(CMU::Netdb::CIDR2mask($fmask))) & 0xFFFFFFFF)/ $bucketIPs
		    ])
	unless ( grep { $_->[2] == (CMU::Netdb::dot2long($fbase) & CMU::Netdb::dot2long($bucketMask)) } @$data);
    }

  }
  

  my %Buckets;
  # Count the buckets
  foreach my $row (@$data) {
    my ($id, $name, $bucket, $bcnt) = @$row;
    warn __FILE__ . ":" . __LINE__ . ": Processing \n" . Data::Dumper->Dump([$row, CMU::Netdb::long2dot($row->[2])],[qw(row ip)]) . "\n" if $debug;
    if ($bcnt > 1) {
      $Buckets{$bucket}++;
    } else {
      # For partial buckets, keep a partial count, so we decide to render the sub layout
      $Buckets{$bucket}+= $bcnt;
    }
    my $curr_bucket = $bucket;
    $bcnt = int($bcnt);

    while($bcnt-- > 1) {
      $curr_bucket += $bucketIPs;
      $Buckets{$curr_bucket}++;
    }
  }

#  map { $hr_keys{CMU::Netdb::long2dot($_)} = $Buckets{$_} } keys %Buckets;

#  warn __FILE__ . ":" . __LINE__ . ": \n" . Data::Dumper->Dump([\%hr_keys],[qw(Buckets)]) . "\n"; 

  # If there are more buckets than the threshold, we'll print out a table.
  my $PrintedTable = 0;
  if ((scalar(keys %Buckets) > 
      $SMConfig->{'table-threshold'}*(2**$SMConfig->{'bucket-step'}))
      || $bucketCIDR >= 28
      || $force
     ) {
    rep_smap_print_table($dbh, $user, $SMConfig, $base, $mask);
    $PrintedTable = 1;
  }

  # Foreach bucket, recurse into it
  if ($bucketCIDR < 28) {
    foreach my $B (sort {$a <=> $b} keys %Buckets) {
      # Skip recursing down if we printed a table at this level, which would
      # include the subnet if it's the only one in that bucket. If we didn't
      # print the table, we'll need to recurse down to print the subnet.
      next if ($PrintedTable && $Buckets{$B} == 1);

      my $res = rep_smap_rec($dbh, $user, $url, $q, $SMConfig,
			     CMU::Netdb::helper::long2dot($B),
                             $bucketCIDR);
      return $res if ($res < 1);
    }
  }

  return 1;
}

sub rep_smap_print_table {
  my ($dbh, $user, $SMConfig, $base, $mask) = @_;
  my ($rbase);

  warn __FILE__ . ":" . __LINE__ . ": rep_smap_print_table called with \n" .
    "base = " . CMU::Netdb::long2dot($base) . "\n" .
      "mask = $mask\n" if $debug;

  print "<a name=\"${base}_$mask\">";
  print CMU::WebInt::subHeadingAnchored("$base/$mask", undef, "$base/$mask");


  # List the subnets in the range
  my $dmask = CMU::Netdb::helper::CIDR2mask($mask);
  my $rSubnets = CMU::Netdb::list_subnets($dbh, $user,
					  " base_address & ".
					  " INET_ATON('$dmask') = ".
					  " INET_ATON('$base') ");
  return 0 unless (ref $rSubnets eq 'ARRAY');
  my %smap = %{CMU::Netdb::makemap($rSubnets->[0])};
  shift(@$rSubnets);

  # Calculate the width and length of the output table in bits. The
  # width will be user-configurable (defaults to 4 or 2^4=16 blocks wide).
  # The length can be 0 (2^0 = 1 row) and up. The max length is determined
  # by the bucket size/step and the configured width.

  my $WidthB = $SMConfig->{'table-width'};
  my $MaxLengthB = $SMConfig->{'bucket-step'} - $WidthB;
  $MaxLengthB = 0 if ($MaxLengthB < 0);

  # Determine the minimum block size. This can be in the range
  # ($mask + $WidthB) to ($mask + $WidthB + $MaxLengthB).
  # We base the decision on the minimum subnet size, since we just waste
  # space if we choose a small minimum block size and there are only
  # a couple subnets (closer to ($mask + $WidthB) in size).
  my $MinBS_Min = $mask + $WidthB;
  my $MinBS_Max = $mask + $WidthB + $MaxLengthB;

  my $MinBS = rep_smap_minss($rSubnets, \%smap);

  $MinBS = $MinBS_Max if ($MinBS > $MinBS_Max);
  $MinBS = $MinBS_Min if ($MinBS < $MinBS_Min);

  # Determine the length, which is based on the minimum block size.
  my $LengthB = $MinBS - $MinBS_Min;

  my $rSubnetBuckets = rep_smap_bucketize($rSubnets, \%smap,
					  $mask,
					  $mask + $LengthB + $WidthB);

  print "<table border=1>\n";

  # Print header row
  rep_smap_pr_header_row($base, $mask, $WidthB, $MinBS, $LengthB);

  my $CurCell = {'remain' => 0,
		 'color' => '',
		 'name' => '',
		 'link' => ''};

  for my $row (0..(2**$LengthB-1)) {
    # Left Header
    $rbase = CMU::Netdb::long2dot(CMU::Netdb::dot2long($base) + ($row * (2**(32 - ($LengthB+$mask)))));
    print "<tr class=\"smapLeftHeader\">\n";
    print "<td>$rbase/".($LengthB+$mask)."</td>\n";

    for my $col (0..((2**$WidthB)-1)) {
      if ($CurCell->{'remain'} > 0) {
        if ($col == 0) {
          rep_smap_pr_cell($CurCell, $WidthB);
        }
        $CurCell->{'remain'}--;
        next;
      }
      $CurCell = rep_smap_calc_curcell($row, $col, $WidthB, $rSubnetBuckets,
				       \%SMap_Default_Colors, $base, $MinBS, $SMConfig);
      rep_smap_pr_cell($CurCell, $WidthB);
      $CurCell->{'remain'}--;
    }
    print "</tr>\n";
  }

  print "</table>";
  #  print "Would be printing: $base/$mask<br>\n";
  print "<br>";
}

sub rep_smap_pr_cell {
  my ($CurCell, $WidthB) = @_;
  my ($vspan) = 1;
  return if (defined $CurCell->{'spanned'});
  my $span = $CurCell->{'remain'};
  $span = 2**$WidthB if ($span > 2**$WidthB);
  $vspan = int($CurCell->{'remain'} / 2**$WidthB) + (($CurCell->{'remain'} % (2**$WidthB)) ? 1 : 0) ;
  $CurCell->{'spanned'} = 1 if ($vspan > 1);
  print "<td class=\"smapCell\" bgcolor=\"".$CurCell->{'color'}.
    "\" colspan=\"$span\" rowspan=\"$vspan\">";
  print "<a href=\"".$CurCell->{'link'}."\">" if (defined $CurCell->{'link'});
  print $CurCell->{'name'} if (defined $CurCell->{'name'});
  print "</a>" if (defined $CurCell->{'link'});
  print "</td>\n";
}

sub rep_smap_calc_curcell {
  my ($row, $col, $WidthB, $rSBuckets, $rColors, $base, $cmask, $SMConfig) = @_;

  my $URL = $ENV{SCRIPT_URL};
  my $sURL = "$URL?op=sub_info&sid=";
  my $mURL = "$URL?op=rep_subnet_map#";
  my $cURL = "$URL?op=sub_add_form&";

  my $bucket = $row*(2**$WidthB) + $col;

  unless (defined $rSBuckets->{$bucket}) {
    if ($SMConfig->{'show-create-links'}) {
      return {'color' => $rColors->{'free'},
	      'remain' => 1,
	      'name' => 'Create',
	      'link' => $cURL . "base_address=" .
	      CMU::Netdb::long2dot(CMU::Netdb::dot2long($base) + ($bucket << (32 - $cmask))) .
	      "&network_mask=" .
	      CMU::Netdb::CIDR2mask($cmask),
	      'status' => 'free',
	     };
    } else {
      return {'color' => $rColors->{'free'},
	      'remain' => 1,
	      'name' => '',
	      'status' => 'free',
	     };
    }
  }


  # Is this a simple one-subnet cell, or a multiple/partial cell?
  if (scalar(@{$rSBuckets->{$bucket}}) == 1) {
    my $SInfo = $rSBuckets->{$bucket}->[0];
    if ($SInfo->{bcount} > 1
	|| $SInfo->{'subnet.network_mask'} == CMU::Netdb::dot2long(CMU::Netdb::CIDR2mask($cmask))) {
      # Only one, not a partial
      return {'color' => rep_smap_getcolor($SInfo, $rColors),
	      'name' => $SInfo->{'subnet.abbreviation'},
	      'link' => $sURL.$SInfo->{'subnet.id'},
	      'remain' => $SInfo->{'bcount'},
	      'status' => 'ok',
	     };
    }
  }


  # Either this is a multiple or a partial...
  foreach my $SInfo (@{$rSBuckets->{$bucket}}) {
    if ($SInfo->{'bcount'} > 1) {
      warn __FILE__, ':', __LINE__, ' :>'.
	"rep_smap_calc_curcell: Multiple bucket items and bcount > 1!\n". Data::Dumper->Dump([$rSBuckets->{$bucket}], ["bucket $bucket"]);
      return {'color' => $rColors->{'err'},
	      'name' => 'Error!',
	      'status' => 'err',
	      'remain' => 1,
	     };
    }
  }
  # Multiple/partial bucket items; presumably they will be broken out
  my $type = 'Multiple';
  $type = 'Partial' if (scalar(@{$rSBuckets->{$bucket}}) == 1);

  return {'color' => $rColors->{'multiple'},
	    'name' => $type . ' (' . scalar(@{$rSBuckets->{$bucket}}) . ")",
	    'status' => 'mult',
	    'link' => $mURL . CMU::Netdb::long2dot(CMU::Netdb::dot2long($base) + ($bucket << (32 - $cmask))) . "/$cmask",
	    'remain' => 1,
	   };
  

}

sub rep_smap_getcolor {
  my ($SInfo, $rColors) = @_;

  return $rColors->{'reserved'}
    if ($SInfo->{'subnet.abbreviation'} =~ /-res$/);

  return $rColors->{'reserved'}
    if ($SInfo->{'subnet.name'} =~ /reserved/i);

  return $rColors->{'phaseout'}
    if ($SInfo->{'subnet.name'} =~ /phase ?out/i);

  return $rColors->{'shared'}
    if ($SInfo->{'subnet.share'} != 0);

  return $rColors->{'delegated'}
    if ($SInfo->{'subnet.flags'} =~ /delegated/);

  return $rColors->{'routed-nondhcp'}
    if ($SInfo->{'subnet.flags'} =~ /no-dhcp/);

  return $rColors->{'routed'};
}

sub rep_smap_pr_header_row {
  my ($base, $mask, $WidthB, $MinBS, $LengthB) = @_;
  my ($rbase);

  print "<tr>";
  print "<td>&nbsp;</td>\n";
  for my $i (0..((2**$WidthB)-1)) {
    $rbase = long2dot_bits($i * (2**(32 - ($WidthB+$mask+$LengthB))), $WidthB+$mask+$LengthB-1);
    print "<td class=\"smapHeader\">$rbase/".($WidthB+$mask+$LengthB)."</td>\n";
  }
  print "</tr>\n";
}

# find the minimum subnet size for the given subnets
sub rep_smap_minss {
  my ($rSubnets, $rMap) = @_;

  my $MinSS = 0;
  foreach my $row (@$rSubnets) {
    my $mask = $row->[$rMap->{'subnet.network_mask'}];
    my $maskC = CMU::Netdb::helper::mask2CIDR($mask);
    $MinSS = $maskC if ($maskC > $MinSS);
  }

  return $MinSS;
}

# bucketize the subnets
sub rep_smap_bucketize {
  my ($rSubnets, $rMap, $topMask, $bucketMask) = @_;

  if ($bucketMask > 32) {
    warn __FILE__, ':', __LINE__, ' :>'.
      "rep_smap_bucketsize: Bucket mask > 32 ($bucketMask)";
    return {};
  }

  my %Buckets;
  foreach my $row (@$rSubnets) {
    my $base = $row->[$rMap->{'subnet.base_address'}];

    # right shift to move the bucket data into the low bits
    my $bucketStart = $base >> (32-$bucketMask);

    # mask off the bits defining the table
    $bucketStart = $bucketStart & (2**($bucketMask-$topMask)-1);

    # determine the ending bucket
    my $smask = $row->[$rMap->{'subnet.network_mask'}];
    my $calcb = ($base | (~($smask&(2**32-1))));

    my $bucketEnd = $calcb >> (32-$bucketMask);

    $bucketEnd = $bucketEnd & (2**($bucketMask-$topMask)-1);

    # put the data into a descriptive 
    my %SData = map { ($_,  $row->[$rMap->{$_}]) } keys %$rMap;
    $SData{'bcount'} = $bucketEnd-$bucketStart+1;

    push(@{$Buckets{$bucketStart}}, \%SData);
  }

  return \%Buckets;
}

sub rep_cb_s24_block_start {
  return ((($_[0] >> 8) & 255)*64) +
    int(($_[0] & 255) / 4);
}

sub rep_cb_s24_block_end {
  return rep_cb_s24_block_start( ($_[0] | ~$_[1]) );
}

## Function: rep_print_subnet_map
## Arguments:
##  - title: Title of the report
##  - smaj: Major block to begin on
##  - emaj: Major block to end on
##  - smin: Minor block to begin with
##  - emin: Minor block to end on
##  - cbBlockStart: Function to determine the starting block number from
##                  subnet information
##  - cbBlockEnd:   Function to determine the end block number from subnet
##  - ruRef: Reference to subnet information blocks
##  - cmap: Color map (name => color)
##  - url: URL to netreg subnet information page
##  - mult: Multiplier for minor number -> block number
##  - offset: offset of first block text
##  - mode: 0 = standard, 1 = utilization
##  - dbh: database handle
##  - dbuser: database user
sub rep_print_subnet_map {
  my ($title, $smaj, $emaj, $smin, $emin, $cbBlockStart, $cbBlockEnd,
      $ruRef, $cmap, $url, $mult, $offset, $util, $dbh, $user) = @_;
  
  my %SubMap = %{CMU::Netdb::makemap($ruRef->[0])};
  
  my %blocks;
  my %sInfo;
  my %len;
  my %share;
  my %delegated;
  my %nondhcp;
  my %sname;
  my @skipped;
  my $lastcolor;

  my $skipFirst = 1;
  foreach (@$ruRef) {
    if ($skipFirst == 1) {
      $skipFirst = 0;
      next;
    }

    my ($id, $ba, $nm) = ($_->[$SubMap{'subnet.id'}],
			  $_->[$SubMap{'subnet.base_address'}],
			  $_->[$SubMap{'subnet.network_mask'}]);
    $ba = CMU::Netdb::dot2long(CMU::Netdb::long2dot($ba));
    $nm = CMU::Netdb::dot2long(CMU::Netdb::long2dot($nm));

    my $block = $cbBlockStart->($ba);              #($ba >> 8) & 255;
    my $blockEnd = $cbBlockEnd->($ba, $nm);        #($ba | ~$nm) >> 8 & 255;

#    print "SET BLOCK $_->[$SubMap{'subnet.name'}] ".CMU::Netdb::long2dot($ba)." : $block<br>\n";
    $len{$id} = $blockEnd-$block+1;
    
    if (defined $blocks{$block}) {
      push(@{$blocks{$block}}, $id);
    }else{
      $blocks{$block} = [$id];
    }
    $sInfo{$id} = $_->[$SubMap{'subnet.abbreviation'}];
    $share{$id} = 1 if ($_->[$SubMap{'subnet.share'}] != 0);
    $delegated{$id} = 1 if ($_->[$SubMap{'subnet.flags'}] =~ /delegated/);
    $nondhcp{$id} = 1 if ($_->[$SubMap{'subnet.flags'}] =~ /no_dhcp/);
    $sname{$id} = $_->[$SubMap{'subnet.name'}];
  }

  my $sur;
  if ($util) {
    $sur = CMU::Netdb::rep_subnet_utilization($dbh, $user);
    if (!ref $sur) {
      if ($sur eq $CMU::Netdb::errcodes{EPERM}) {
	my $ul = CMU::Netdb::get_read_level($dbh, $user, 'subnet', 0);
	CMU::WebInt::accessDenied('subnet', 'READ', 0, 9, $ul, $user);
      }else{
	print "Unknown error reading subnet table.\n";
      }
      return;
    }
  }
  
  print "<br>".&CMU::WebInt::subHeading($title)."<table border=1>\n";
  
  my $mskip = 0;
  for my $major (-1..$emaj) { 
    next if ($major != -1 && $major < $smaj);
    print "<tr>\n";

    for my $minor (-1..$emin) {
      my $sminor = ( ($minor != -1) ? $minor * $mult : -1);
      next if ($minor != -1 && $sminor < $smin);
      next if ($minor > 0 && $mskip-- > 0);
      $mskip-- if ($minor == 0);
      if ($major == -1) {
	$sminor = '+' if ($sminor == -1);
	print "<td width=30 height=30 bgcolor=white align=center><font face=\"Tahoma,Arial,Helvetica,Geneva,Charter\"><b>$sminor</b></td>\n";
      }else{
	if ($sminor == -1) {
	  print "<td width=30 height=30 bgcolor=white align=center><font face=\"Tahoma,Arial,Helvetica,Geneva,Charter\"><b>".($major*16*$mult-$offset)."</b></td>\n";
	}elsif($sminor == 0 && $mskip > 0) {
	  my $span = $mskip+1;
	  print "<td width=30 height=30 align=center bgcolor=$lastcolor colspan=$span><font face=\"Tahoma,Arial,Helvetica,Geneva,Charter\" size=-1>[continued]</font></td>\n";
	}else{
	  my $bid = $major*16+$sminor;
#	  print "Calculating block ID: $bid ($major, $mult, $sminor)\n";

	  my @binfo = @{$blocks{$bid}} if (defined $blocks{$bid});
	  my $finfo = "<font face=\"Tahoma,Arial,Helvetica,Geneva,Charter\" size=-1>";

	  # None
	  if ($#binfo == -1) {
	    print "<td width=30 height=30 align=center>${finfo}open</td>";
	  }elsif($#binfo == 0) {
	    my $color = $$cmap{routed};
	    my $name = $sInfo{$binfo[0]};
	    
	    if ($sInfo{$binfo[0]} =~ /^res/) {
	      $color = $$cmap{reserved};
	      $name = 'Reserved';
	    }elsif($sname{$binfo[0]} =~ /Phase Out/i) {
	      $color = $$cmap{phaseout};
	    }elsif(defined $share{$binfo[0]}) {
	      $color = $$cmap{bridged};
	    }elsif(defined $delegated{$binfo[0]}) {
	      $color = $$cmap{delegated};
	    }elsif(defined $nondhcp{$binfo[0]}) {
	      $color = $$cmap{'routed-nondhcp'};
	    }
	    
	    $color = 'white' if ($util);
	    $lastcolor = $color;
	    $name = substr($name, 0, $len{$binfo[0]}*5)
	      if ($util);
	    print "<td width=30 height=30 align=center bgcolor=$color colspan=$len{$binfo[0]}>${finfo}".
	      "<a href=\"$url?op=sub_info&sid=$binfo[0]\">$name</a>";
	    if ($util) {
	      my $percent;
	      unless (defined $sur->{$binfo[0]}) {
		$percent = 0;
	      }else{
		$percent = $sur->{$binfo[0]}->[1]/$sur->{$binfo[0]}->[2];
	      }
	      my $imgColor = 'red';
	      $imgColor = 'yellow' if ($percent < 0.90);
	      $imgColor = 'green' if ($percent < 0.80);
	      my $width = int($percent*10)*4*$len{$binfo[0]};
	      $width = 1 if ($width == 0);
	      print "<br><img src=\"/img/$imgColor-small.jpg\" height=8 width=$width>";
	    }
	    print "</td>\n";
	    $mskip = $len{$binfo[0]} - 1;
	  }elsif($#binfo == 1) {
	    my $color = $$cmap{routed};
	    if ($sInfo{$binfo[0]} =~ /^res/) {
	      $color = $$cmap{reserved};
	    }elsif(defined $share{$binfo[0]}) {
	      $color = $$cmap{bridged};
	    }elsif(defined $delegated{$binfo[0]}) {
	      $color = $$cmap{delegated};
	    }elsif($sname{$binfo[0]} =~ /Phase Out/i) {
	      $color = $$cmap{phaseout};
	    }

	    $color = 'white' if ($util);
	    $lastcolor = $color;
	    
	    print "<td width=30 height=30 align=center bgcolor=$color>${finfo}";

	    if ($util) {
	      print "Mult<br>";
	      # Fudge a +1 just so that we don't divide by 0. Sigh.
	      my $percent = ($sur->{$binfo[0]}->[1] + $sur->{$binfo[1]}->[1]) /
		($sur->{$binfo[0]}->[2] + $sur->{$binfo[1]}->[2] + 1);
	      my $imgColor = 'red';
              $imgColor = 'yellow' if ($percent < 0.90);
              $imgColor = 'green' if ($percent < 0.80);
              my $width = int($percent/10)*4;
              $width = 1 if ($width == 0);
              print "<br><img src=\"/img/$imgColor-small.jpg\" height=8 width=$width>";
	    }else{
	      print "<a href=\"$url?op=sub_info&sid=$binfo[0]\">$sInfo{$binfo[0]}</a>/".
		"<br><a href=\"$url?op=sub_info&sid=$binfo[1]\">$sInfo{$binfo[1]}</a></td>\n";
	    }
	  }else{
	    my $color = $$cmap{seebelow};
	    $color = 'white' if ($util);
	    print "<td width=30 height=30 align=center bgcolor=$color>${finfo}";
	    print "Multiple" unless ($util);
	    print "Mult" if ($util);
					  

	    if ($util) {
	      # Fudge max +1 so we don't divide by 0.
	      my ($used, $max) = (0,1);
	      foreach my $sb (@binfo) {
		$used += $sur->{$sb}->[1];
		$max += $sur->{$sb}->[2];
	      }
	      my $percent = $used/$max;
	      my $imgColor = 'red';
              $imgColor = 'yellow' if ($percent < 0.90);
              $imgColor = 'green' if ($percent < 0.80);
              my $width = int($percent/10)*4;
              $width = 1 if ($width == 0);
              print "<br><img src=\"/img/$imgColor-small.jpg\" height=8 width=$width>";
	    }
	    print "</td>\n";
	    push(@skipped, $bid);
	  }
	}
      }
    }
    print "</tr>\n";
  }
  
  print "</table>\n";
  return \@skipped;
}

my ($to) = undef;

sub rep_panels {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  my ($bldg, $closet, $rack, $panel);
  my ($data, %dapos, $err);
  my ($display, $curr_panel, $display_as);
  my ($caption, $datum);

  $dbh = CMU::WebInt::db_connect();
  if (! ref $dbh) {
    warn __FILE__ . ":" . __LINE__ . ": Could not connect to database\n";
    print "Could not connect to database<br />\n";
    return(-1);
  }

  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  print CMU::WebInt::stdhdr($q, $dbh, $user, 
			    "Panel Map", $errors);
  &CMU::WebInt::title("Panel Map");

  my ($vres, $eco) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_CABLES_OUTLETS');

  if ($eco != 1) {
    CMU::WebInt::accessDenied();
    print &CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  } 

  print CMU::WebInt::errorDialog($url, $errors);

  print $q->start_form(-method=>"GET") . "\n";
  print $q->table($q->Tr({-align => "LEFT", cellpadding=>16},
			 [
			  $q->td(["Building&nbsp;&nbsp;", $q->textfield(-name => "bldg")]) . "\n",
			  $q->td(["Closet", $q->textfield(-name => "closet")]) . "\n",
			  $q->td(["Rack", $q->textfield(-name => "rack")]) . "\n",
			  $q->td(["Panel", $q->textfield(-name => "panel")]) . "\n",
			  '<td colspan="2" align="RIGHT">' . $q->submit(-name=>'Submit',
							  -value=>'submit') . "</td>\n"
			 ]
			)
		  );
			  
  print "\n", $q->hidden(-name=>'op',
			    -default => "rep_panels");
  print $q->end_form;

  $bldg = CMU::WebInt::gParam($q, 'bldg');
  $closet = CMU::WebInt::gParam($q, 'closet');
  $rack = CMU::WebInt::gParam($q, 'rack');
  $panel = CMU::WebInt::gParam($q, 'panel');


  if ((length($bldg) + length($closet) + length($rack) + length($panel)) > 0) {

    if (! defined $to) {
      $to = CMU::Netdb::list_outlet_types_ref($dbh, $user, 'GET');
    }


    $bldg = "%" if length($bldg) == 0;
    $closet = "%" if length($closet) == 0;
    $rack = "%" if length($rack) == 0;
    $panel = "%" if length($panel) == 0;
    print &CMU::WebInt::subHeading("Information for \"$bldg???-$closet$rack$panel\"");

    ($data, $err) = CMU::Netdb::list_cables_outlets($dbh, $user, "cable.from_building like \"$bldg\" and " .
						    "cable.from_closet like \"$closet\" and " . 
						    "cable.from_rack like \"$rack\" and " . 
						    "cable.from_panel like \"$panel\" and " .
						    "cable.type in (\"CAT5\", \"CAT6\", \"TYPE1\", \"TYPE2\") and " . 
						    "outlet.id is not null " . 
						    " order by " .
						    "cable.from_building, cable.from_closet, ".
						    "cable.from_rack, cable.from_panel, " .
						    "cable.from_x  ,cable.from_y ");


    if (! ref $data) {
      warn __FILE__ . ":" . __LINE__ . ": Error getting cable/outlet list, error $data ($CMU::Netdb::errors::errmeanings{$data})" . join (",", $err) . "\n" . Data::Dumper->Dump([$data, $err],[qw(data err)]) . "\n"; ;
      return(-1);
    }
    
    get_vlans($q, $dbh, $user, $data);

    %dapos = %{CMU::Netdb::makemap($data->[0])};
    
    shift @$data;
    
#    print "Columns are <br />\n" . join(",<br /> ", (map { "$_ => $dapos{$_}" } (sort keys %dapos))) . "\n";
    
    foreach (@$data) {

#      print "Processing " . join(":", @$_) . "<br />\n";

      $_->[$dapos{'cable.label_from'}] =~ /(\d\d)...-(...)-(..)/;
      
      $datum = $3;
      my ($this_panel) = "$1$2";
#      print "<br /> Comparing $curr_panel with $this_panel<br />\n";
      if ($curr_panel ne $this_panel) {
	
#	print "cable.type is $_->[$dapos{'cable.type'}]<br />\n";
	next if ((! defined $_->[$dapos{'cable.type'}]) || (length($_->[$dapos{'cable.type'}]) == 0));
	$curr_panel = "$1$2";
	print $q->table({-border=>undef},
			$q->caption($caption),
			$q->Tr({-align=>"CENTER",-valign=>"TOP"},
			       [
				map { $q->td($_)} (@{$display->{data}})
			       ])) if (defined $display);
	print "Legend: Vlan Status is one of " .
	  "<font style=\"color:$fcolor->{request}\">request</font>, " . 
	    "<font style=\"color:$fcolor->{active}\">active</font>, " . 
	      "<font style=\"color:$fcolor->{delete}\">delete</font>, " . 
		"<font style=\"color:$fcolor->{error}\">error</font>, " . 
		  "<font style=\"color:$fcolor->{novlan}\">novlan</font><br />" if (defined $display);
	
	print "<br /><br />\n" if defined $display;
	$_->[$dapos{'cable.label_from'}] =~ /(.....-...)-(..)$/;
	$caption = $1;
	$display = create_ptemplate((defined $display_as) ? $display_as : $_->[$dapos{'cable.type'}]);
	if (! defined $display) {
	  warn __FILE__ . ":" . __LINE__ . ": Processing " . join(":", @$_) . "\n";
	  last;
	}
      }
      last if (! plot_panel($q, $display, $datum, $_, \%dapos));
    }
  }
  print $q->table({-border=>undef},
		  $q->caption($caption),
		  $q->Tr({-align=>"CENTER",-valign=>"TOP"},
			 [
			  map { $q->td($_) } (@{$display->{data}})
			 ])) if (defined $display);
  print "Legend: Vlan Status is one of " .
    "<font style=\"color:$fcolor->{request}\">request</font>, " . 
      "<font style=\"color:$fcolor->{active}\">active</font>, " . 
	"<font style=\"color:$fcolor->{delete}\">delete</font>, " . 
	  "<font style=\"color:$fcolor->{error}\">error</font>, " . 
	    "<font style=\"color:$fcolor->{novlan}\">novlan</font><br />";
  
  print "<br /><br />\n" if defined $display;
  
  print &CMU::WebInt::stdftr($q);
  
  $dbh->disconnect();
  
}  


sub get_vlans{
  my ($q, $dbh, $user, $outlets) = @_;

  my ($data, @oids, $query, $headers, %oupos);
  my ($row, %dapos, $vlans);
  my ($url) = $q->url(-path_info=>1);
  my ($get_vlan) = "?op=vlan_info&vid=";

 # print "Getting information for vlans<br />\n";


#  print "<pre>\nURL is $url\n</pre>";


  @oids = ();
  undef $headers;
  @$headers = @{shift @$outlets};

  push (@$headers, "local.vlans");
  %oupos = %{CMU::Netdb::makemap($headers)};

  foreach $row (@$outlets) {
    if ((! defined $row->[$oupos{'outlet.id'}]) || (length($row->[$oupos{'outlet.id'}]) == 0)) {
      $row->[$oupos{'local.vlans'}] = "";
      next;
    }
    push(@oids, $row->[$oupos{'outlet.id'}]);
  }


#  print "Looking up information on outlets<br />\n" . join("<br />\n",@oids) . "<br />\n";

  $data = CMU::Netdb::list_outlet_vlan_memberships($dbh, $user, "outlet_vlan_membership.outlet in (" . join (",", @oids) . ") order by outlet_vlan_membership.outlet, outlet_vlan_membership.type");

  %dapos = %{CMU::Netdb::makemap($data->[0])};

  shift @$data;

# make a hash of the data
#  $vlans->{outlet_id}{vlan_abbrev}{status} = status;
#  $vlans->{outlet_id}{vlan_abbrev}{id} = vlan_id;

  undef $vlans;
  foreach (@$data) {
    $vlans->{$_->[$dapos{'outlet.id'}]}{$_->[$dapos{'vlan.abbreviation'}]}{status} = $_->[$dapos{'outlet_vlan_membership.status'}];
    $vlans->{$_->[$dapos{'outlet.id'}]}{$_->[$dapos{'vlan.abbreviation'}]}{id} = $_->[$dapos{'outlet_vlan_membership.vlan'}];
  }
  
#  print "<pre>" . Data::Dumper->Dump([\%oupos],[qw(oupos)]) . "</pre>\n"; 

  
  # update the outlets array
  foreach $row (@$outlets) {
    next if (! defined $row->[$oupos{'outlet.id'}]);
    foreach (keys %{$vlans->{$row->[$oupos{'outlet.id'}]}}) {
#      print "Checking for \$vlans->{$row->[$oupos{'outlet.id'}]}{$_}{status} = " . (defined $vlans->{$row->[$oupos{'outlet.id'}]}{$_} ? $vlans->{$row->[$oupos{'outlet.id'}]}{$_}{status} : "UNDEFINED" ) . "\n";
      $row->[$oupos{'local.vlans'}] = defined $row->[$oupos{'local.vlans'}] ? 

	"$row->[$oupos{'local.vlans'}]<br /> <a target=\"_blank\" style=\"text-decoration:none; color: $fcolor->{$vlans->{$row->[$oupos{'outlet.id'}]}{$_}{status}}\" href=${url}${get_vlan}$vlans->{$row->[$oupos{'outlet.id'}]}{$_}{id}>$_</a>":
	      "<a target=\"_blank\" style=\"text-decoration:none; color: $fcolor->{$vlans->{$row->[$oupos{'outlet.id'}]}{$_}{status}}\" href=${url}${get_vlan}$vlans->{$row->[$oupos{'outlet.id'}]}{$_}{id}>$_</a>";
    }
    
  }
  
  unshift @$outlets, $headers;



}


sub create_ptemplate{
  my ($template) = @_;
  my ($rec, $x, $y);

  if (($template eq 'TYPE2') || ($template eq 'TYPE1')) {
    $rec->{type} = "IBM";
    
    $rec->{data}[0] = ["&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;A&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;B&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;C&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;D&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;E&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;F&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;G&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;H&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"];
    foreach $x (1..8) {
      $rec->{data}->[$x][0] = $x;
      foreach $y (1 .. 8) {
	$rec->{data}[$y][$x] = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
      }
    }
    return($rec);
  } elsif (($template eq 'CAT5') || ($template eq 'CAT6')) {
    $rec->{type} = "cat24";
    foreach (0..23) {
      $rec->{data}[0][$_ + int(($_ ) / 6)] = sprintf("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;%02d&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", $_ + 1);
      $rec->{data}[1][$_ + int(($_ ) / 6)] = "&nbsp;&nbsp;&nbsp;";
    }
    return($rec);
  } else {
    print "Unknown template type \"$template\"\n";
    warn __FILE__ . ":" . __LINE__ . ": Unknown template type \"$template\"\n";
    return(undef);
  }
}

my ($a2n) = {
	     A => 1,
	     B => 2,
	     C => 3,
	     D => 4,
	     E => 5,
	     F => 6,
	     G => 7,
	     H => 8
	    };

sub plot_panel{
  my ($q, $rec, $datum, $line, $fields) = @_;

  my ($url) = $q->url(-path_info=>1);
  my ($get_outlet) = "?op=outlets_info&oid=";

  my ($outtype) = {
		   1 => "SH10",
		   2 => "SW10",
		   3 => "SH100",
		   4 => "SW100",
		   5 => "SW1000",
		   6 => "NETBAR"
		  };

  return(undef) if (!defined $rec);
  return(1) if ((! defined $line->[$fields->{'outlet.type'}]) || (length($line->[$fields->{'outlet.type'}]) == 0));

  if ($rec->{type} eq "IBM") {
    $datum =~ /(.)(.)/;
    $rec->{data}[$2][$a2n->{$1}] =  "<a target=\"_blank\" style=\"text-decoration:none; color:black\"  href=${url}${get_outlet}$line->[$fields->{'outlet.id'}]>$outtype->{$line->[$fields->{'outlet.type'}]}</a>";
    $rec->{data}[$2][$a2n->{$1}] .= "<br />$line->[$fields->{'local.vlans'}]"if ((defined $line->[$fields->{'local.vlans'}]) &&
									  (length($line->[$fields->{'local.vlans'}]) > 0));
    $rec->{otype}{$line->[$fields->{'outlet.type'}]} = 1;
    return(1);
  } elsif ($rec->{type} eq "cat24") {
#    $rec->{data}[1][$datum + int(($datum - 1) / 6) -1 ] = $outtype->{$line->[$fields->{'outlet.type'}]};
    $rec->{data}[1][$datum + int(($datum - 1) / 6) -1 ] = "<a target=\"_blank\" style=\"text-decoration:none; color:black\" href=${url}${get_outlet}$line->[$fields->{'outlet.id'}]>$outtype->{$line->[$fields->{'outlet.type'}]}</a>";
    $rec->{data}[1][$datum + int(($datum - 1) / 6) -1 ] .= "<br />$line->[$fields->{'local.vlans'}]" if ((defined $line->[$fields->{'local.vlans'}]) &&
												 (length($line->[$fields->{'local.vlans'}]) > 0));
    $rec->{otype}{$line->[$fields->{'outlet.type'}]} = 1;
    return(1);
  } else {
    warn __FILE__ . ":" . __LINE__ . ": Unknown record type(\"$rec->{type}\", this should not happen.\n";
    return (undef);
  }

}

sub rep_subnet_zone_map {
    my ($q, $errors) = @_;
    my ($dbh, $url, $userlevel, %errors);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();
    my %stats;
    my @subnets;
    my @zones;
    my $zone;
    my $subnet;

    $url = $ENV{SCRIPT_NAME};
    %errors = %{$errors} if defined($errors);

    print CMU::WebInt::stdhdr($q, $dbh, $user, "Subnet Zone Mapping Usage", $errors);
    &CMU::WebInt::title("Subnet Zone Mapping Usage");

    my $zref = CMU::Netdb::list_dns_zones($dbh, 'netreg', " dns_zone.type in ('fw-toplevel', 'fw-permissible')");
    my %zmap = %{CMU::Netdb::makemap(shift(@{$zref}))};
    foreach $zone ( @{$zref} ){
 	push @zones, $zone->[$zmap{'dns_zone.name'}];
    }
    @zones = sort @zones;

    my $sref = CMU::Netdb::list_subnets($dbh, 'netreg', " 1");
    my %smap = %{CMU::Netdb::makemap(shift(@{$sref}))};
    foreach $subnet ( @{$sref} ){
 	push @subnets, $subnet->[$smap{'subnet.name'}];
    }
    @subnets = sort @subnets;

    my $qry = $dbh->prepare("select dns_zone.name, subnet.name, count(*) from machine, dns_zone, subnet 
                              where machine.ip_address_subnet = subnet.id 
                              and machine.host_name_zone = dns_zone.id 
                              group by host_name_zone, ip_address_subnet");
    $qry->execute;
    while( my $rw = $qry->fetchrow_arrayref ){
 	$stats{$rw->[0]}{$rw->[1]} = $rw->[2];
    }
    $qry->finish;

    print "<table border=1>\n";

    print "<tr><td></td><th>", join("</th><th>", @zones), "</th></tr>\n";

    foreach $subnet ( @subnets ){
	print "<tr><th>", $subnet, "</th>";
	foreach $zone ( @zones ){
	    print "<td>";
	    if(defined($stats{$zone}{$subnet})){
		print "<font color=blue>", $stats{$zone}{$subnet}, "</font>";
	    } else {
		print "0";
	    }
	    print "</td>";
	}
	print "</tr>\n";
    }

    print "</table>\n";

    print CMU::WebInt::stdftr($q);
}

sub rep_zone_util {
    my ($q, $errors) = @_;
    my ($dbh, $url, $userlevel, %errors, $zone, %mcnt, @rrtypes, %rr, %subz);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();

    $url = $ENV{SCRIPT_NAME};
    %errors = %{$errors} if defined($errors);

    print CMU::WebInt::stdhdr($q, $dbh, $user, "Zone Utilization", $errors);
    &CMU::WebInt::title("Zone Utilization");

    print "<table>";
    my $hdr = "<tr><th>Zone</th><th>Hosts</th><th>Subzones</th>";

    # generate headers for all dns_resource types
    my $typeqry = $dbh->prepare("select distinct type from dns_resource order by type");
    $typeqry->execute;
    while(my $t = $typeqry->fetchrow_arrayref){
	$hdr .= "<th>" . $t->[0] . "</th>";
	push @rrtypes, $t->[0];
    }
    $hdr .= "</tr>\n";

    # get the count of machine records per zone
    my $machqry = $dbh->prepare("select machine.host_name_zone, count(*) from
                                 machine group by machine.host_name_zone");
    $machqry->execute;
    while(my $m = $machqry->fetchrow_arrayref){
	$mcnt{$m->[0]} = $m->[1];
    }

    # get the dns resource info
    my $rrqry = $dbh->prepare("select name_zone, type, count(*) from dns_resource group by type, name_zone");
    $rrqry->execute;
    while(my $rr = $rrqry->fetchrow_arrayref){
	$rr{$rr->[0]}{$rr->[1]} = $rr->[2];
    }

    # get a list of all sub zones
    my $szqry = $dbh->prepare("select parent.id, count(child.name) from dns_zone parent,
                               dns_zone child where child.name like '%.' || parent.name
                               group by parent.id, parent.name");
    $szqry->execute;
    while(my $sz = $szqry->fetchrow_arrayref){
	$subz{$sz->[0]} = $sz->[1];
    }

    # get list of zones
    my $zoneqry = $dbh->prepare("select dns_zone.name, dns_zone.id from dns_zone where
                          dns_zone.type in ('fw-toplevel', 'fw-permissible')
                          order by dns_zone.name");
    $zoneqry->execute;
    my $row = 0;
    while($zone = $zoneqry->fetchrow_arrayref){
	print $hdr if ($row % 20 == 0);
	print "<tr", ($row++ % 2 == 0 ? " bgcolor=#c0f7de" : ""), "><td>",
	  "<a href=\"", $url, "?op=zone_info&id=", $zone->[1], "\">",
	  $zone->[0], "</a></td><td>", $mcnt{$zone->[1]}, "</td>";
	print "<td>", $subz{$zone->[1]}, "</td>";
	foreach my $type ( @rrtypes ){
	    print "<td>", $rr{$zone->[1]}{$type}, "</td>";
	}
	print "</tr>\n";
    }

    print "</table>\n";

    print CMU::WebInt::stdftr($q);
}

sub rep_resnet_progress {
    my ($q, $errors) = @_;
    my ($dbh, $url, $userlevel, %errors);

    $dbh = CMU::WebInt::db_connect();
    my ($user, $p, $r) = CMU::WebInt::getUserInfo();

    $url = $ENV{SCRIPT_NAME};
    %errors = %{$errors} if defined($errors);

    print CMU::WebInt::stdhdr($q, $dbh, $user, "ResNet Signup Progress", $errors);
    &CMU::WebInt::title("ResNet Signup Progress");

    # note that this depends upon the far from normalized resdrop schema
    my $qry = $dbh->prepare("select r0.bld,
 ( select count(distinct r2.id) from resdrop r2, machine_outlet m2
   where m2.outlet = r2.id and r2.id > 0 and r2.building = r0.bld) as live,
 ( select count(distinct r3.id) from resdrop r3 left join machine_outlet m3 on r3.id = m3.outlet
   where m3.id is null and r3.building = r0.bld) as off,
 ( select count(distinct r4.id) from resdrop as r4
   where r4.building = r0.bld ) as total
from ( select distinct resdrop.building as bld from resdrop ) r0 order by r0.bld");
    $qry->execute;
    my $row = 0;

    print "<table><tr><th>Building</th><th>Active</th><th>Inactive</th><th>Total</th><th>Percent</th></tr>\n";
    while (my $rw = $qry->fetchrow_arrayref){
	print "<tr", ($row++ % 2 == 0 ? " bgcolor=#c0f7de" : ""), "><td>", join('</td><td>', @{$rw}), 
	  "</td><td>", int(($rw->[1] / $rw->[3]) * 100), "%</td></tr>\n";
    }
    print "</table>";

    print CMU::WebInt::stdftr($q);
}

sub rep_main {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  
  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  
  $url = $ENV{SCRIPT_NAME};
  %errors = %{$errors} if defined ($errors);
  
  print CMU::WebInt::stdhdr($q, $dbh, $user, "Reports", $errors);
  &CMU::WebInt::title("Network Group Reports");
  print "<hr>\n";

  print "Subnet Reports<ul>\n";
  print "<li><a href=$url?op=rep_subnet_map>Subnet Map</a>\n";
  print "<li><a href=$url?op=rep_sub_util>Subnet Utilization</a>\n";

# IP ranges not yet integrated
#  print "<li><a href=$url?op=rep_ipr_util>IP Range Utilization</a>\n";

# This report generates a ridiculously large table for large netreg databases
# rethink design or make configurable?
#  print "<li><a href=$url?op=rep_subnet_zone_map>Subnet and Zone Mapping Usage</a>\n";

  print "</ul>\n";

  print "DNS Zone Reports<ul>\n";
  print "<li><a href=$url?op=rep_zone_config>Zone Nameservers</a>\n";
  print "<li><a href=$url?op=rep_zone_util>Zone Utilization</a>\n";
  print "</ul>\n";

  print "Machine Reports<ul>\n";
  print "<li><a href=$url?op=rep_user_mach>Machines by User</a>\n";
  print "<li><a href=$url?op=rep_dept_mach>Machines by Department</a>\n";
  print "<li><a href=$url?op=rep_abuse_suspend>Abuse/Suspend Report</a>\n";
  print "<li><a href=$url?op=rep_cname_util>CNAME Utilization</a>\n";
  print "<li><a href=$url?op=rep_expired_mach>Expiring Machines by Department</a>\n";

# Orphaned machines query requires subselects, disable for now
#  print "<li><a href=$url?op=rep_orphan_mach>Orphaned Machines</a>\n";

  print "</ul>\n";

  my ($vres, $eco) = CMU::Netdb::config::get_multi_conf_var
    ('webint', 'ENABLE_CABLES_OUTLETS');

  if ($eco == 1) {
    print "Outlet Reports<ul>\n";

    print "<li><a href=$url?op=rep_outlet_util>Outlet Utilization by Department</a>\n";
    print "<li><a href=$url?op=rep_expired_outlet>Expiring Outlets by Department</a>\n";
    print "<li><a href=$url?op=rep_panels>Panel Map</a>\n";
    print "<li><a href=$url?op=sw_panel_config>Switch/Panel Configuration</a>\n";
    print "</ul>\n";
  }
  print CMU::WebInt::stdftr($q);
}
  
sub History {
  my ($q, $errors) = @_;
  my ($dbh, $url, $userlevel, %errors);
  my ($data, $dapos, $res, $table, $row, $disp, $header);
  my ($display_cols) = [ 
			'_sys_changerec_row.tname',
			'_sys_changerec_row.row',
			'_sys_changerec_row.type',
			'_sys_changerec_col.name',
			'_sys_changerec_col.data',
			'_sys_changerec_col.previous'
		       ];

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('history');
  $table = CMU::Netdb::valid("_sys_changerec_row.tname", $q->param("tname"), $user, 0, $dbh);
  $row = CMU::Netdb::valid("_sys_changerec_row.row", $q->param("row"), $user, 0, $dbh);

  print CMU::WebInt::stdhdr($q, $dbh, $user, "History", $errors);
  if (CMU::Netdb::get_user_admin_status($dbh, $user) != 1) {
    CMU::WebInt::accessDenied();
  } else {

    ($data, $res) = CMU::Netdb::list_history($dbh, $user, $table, $row);

    if (! ref $data) {
      print CMU::WebInt::errorDialog($q->url(-base=>1), { msg=>$CMU::Netdb::errors::errmeanings{$data} . " [" . join (',', @$res ) . "]",
							  type=>'ERR',
							  code=>$data });
    } else {
      $dapos = CMU::Netdb::makemap($data->[0]);

      print "</tr><tr><td colspan='2'><h1>History for \"$table\" table, row $row</h1></td></tr><tr><td colspan='2'>\n";

      $header = shift(@$data);
      $disp = [];
      while (scalar @$data) {
	push(@$disp, shift(@$data));
	if ((! scalar @$data) || ($data->[0][$dapos->{'_sys_changelog.id'}] != $disp->[$#$disp][$dapos->{'_sys_changelog.id'}])) {
	  print CMU::WebInt::subHeading("Changes by $disp->[0][$dapos->{'_sys_changelog.name'}] ($disp->[0][$dapos->{'_sys_changelog.user'}]) at $disp->[0][$dapos->{'_sys_changelog.time'}]<br />$disp->[0][$dapos->{'_sys_changelog.info'}]\n");
	  unshift(@$disp, $header);
	  CMU::WebInt::generic_tprint($q->url(-base=>1), # url
				      $disp,             # ruRef
				      $display_cols,  # dFields
				      undef,             # eCol
				      undef,             # uData
				      "history",         # listop
				      undef,             # infoprefix
				      $dapos,            # position map
				      \%CMU::Netdb::structure::history_fields_printable,    # printable map
				      '_sys_changelog.id', # nameFieldCol
				      '_sys_changelog.id', # idFieldCol
				      undef,             # sortparam
				      undef,             # sortField
				      undef,             # addRow
				      undef              # cData
				     );
	  $disp = [];
	}
      }
      
    }
  }  
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}



sub long2dot_bits {
  my ($addr, $bits) = @_;
  warn __FILE__ . ":" . __LINE__ . ": long2dot_bits called with $addr, $bits\n" if $debug;
  my ($chars) = int($bits / 8);

  warn __FILE__ . ":" . __LINE__ . ": chars = $chars\n" if $debug;
  warn __FILE__ . ":" . __LINE__ . ": returning " . join('.', (unpack("C4", pack('N', $addr)))[$chars .. 3]) . "\n" if $debug;
  return join('.', (unpack("C4", pack('N', $addr)))[$chars .. 3]);
}

1;
