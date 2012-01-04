#   -*- perl -*- 
# 
# CMU::WebInt::switch_panel_config
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

 
package CMU::WebInt::switch_panel_config; 
use strict; 
use warnings;
use vars qw (@ISA @EXPORT @EXPORT_OK %errmeanings $THCOLOR 
	    $cpt); 
use CMU::WebInt; 
use CMU::Netdb; 
use SNMP_util;
use CGI; 
use DBI; 
use CMU::WebInt::S_P_status;
{ 
  no strict; 
  $VERSION = '0.01'; 
} 
 
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(switch_panel_main);

%errmeanings = %CMU::Netdb::errors::errmeanings;
my ($gmcvres);
($gmcvres, $THCOLOR) = CMU::Netdb::config::get_multi_conf_var('webint', 'THCOLOR');

require CMU::WebInt::switch_panel_templates;
$cpt = $CMU::WebInt::switch_panel_templates::switch_panel_template;

sub switch_panel_main {
  my ($q, $errors) = @_;
  my ($dbh, $device, $title);
  my ($name, $bldg, $clos, $rack, $pane);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('switch_panel_list');

  print CMU::WebInt::stdhdr($q, $dbh, $user, "Switch/Panel Display", $errors);

  $name = (CMU::WebInt::gParam($q, "device") eq '') ? '0' : CMU::WebInt::gParam($q, "device"); 
  if ($name ne '0') {
    $name = CMU::Netdb::valid("machine.host_name", $name, $user, 1, $dbh);
    CMU::WebInt::accessDenied() if (CMU::Netdb::getError($name) != 1);
    print CMU::WebInt::stdftr($q);
    return;
  }

  $bldg = (CMU::WebInt::gParam($q, "bldg") eq '') ? '0' : CMU::WebInt::gParam($q, "bldg"); 
  $clos = (CMU::WebInt::gParam($q, "closet") eq '') ? '0' : CMU::WebInt::gParam($q, "closet"); 
  $rack = (CMU::WebInt::gParam($q, "rack") eq '') ? '0' : CMU::WebInt::gParam($q, "rack"); 
  $pane = (CMU::WebInt::gParam($q, "panel") eq '') ? '0' : CMU::WebInt::gParam($q, "panel"); 
  
#  warn __FILE__ . ":" . __LINE__ . ": name is $name, bldg is $bldg, clos = $clos, rack = $rack, pane = $pane\n";
  if ((defined $name) && ($name ne "0")) {
    $title = "Switch/Panel Display: " . $name;
  } elsif (
	   (defined $bldg) && ($bldg ne "0") &&
	   (defined $clos) && ($clos ne "0") &&
	   (defined $rack) && ($rack ne "0") &&
	   (defined $pane) && ($pane ne "0")
	  ) {
    $title = "Switch/Panel Display: Panel $bldg - $clos$rack$pane";
  } else {
    $title = "Switch/Panel Display ";
  }
  if (CMU::Netdb::get_user_admin_status($dbh, $user) != 1) {
    CMU::WebInt::accessDenied();
  } else {
    
    print "$CMU::WebInt::switch_panel_templates::style\n";
    
    if ((defined $name) && ($name ne "0") ||
	(
	 (defined $bldg) && ($bldg ne "0") &&
	 (defined $clos) && ($clos ne "0") &&
	 (defined $rack) && ($rack ne "0") &&
	 (defined $pane) && ($pane ne "0")
	)
       ) {
      my ($dev) = CMU::WebInt::S_P_status->new(name => $name, bldg => $bldg, clos => $clos, rack => $rack, pane => $pane, g_context => $q );
      $title = "Switch/Panel Display: " . $dev->name();
      &CMU::WebInt::title($title);
      print $dev->display(form=>"HTML-display");
      print "<br /><hr /><br />\n";
      print $dev->display();
    } elsif (
	     (! defined $bldg) || ($bldg eq "0") ||
	     (! defined $clos) || ($clos eq "0") ||
	     (! defined $rack) || ($rack eq "0") ||
	     (! defined $pane) || ($pane eq "0")
	    ) {
      print "<h2> Please fully specify the panel information</h2>\n";
    }
    
    display_switch_panel_query($dbh, $q, $user, $p, $r);
  }
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect;
}


sub display_switch_panel_query {
  my ($dbh, $q, $user, $p, $r) = @_;
  my ($query, $result, $repos, $err);
  
  my ($dev, $bldg, $clos, $rack, $pan, $default);
  my ($tgt, $tgt2);

  $dev    = CMU::WebInt::gParam($q, "device");	    
  $bldg   = CMU::WebInt::gParam($q, "bldg");
  $clos   = CMU::WebInt::gParam($q, "closet");
  $rack   = CMU::WebInt::gParam($q, "rack");
  $pan    = CMU::WebInt::gParam($q, "panel");


  print "<br /><hr /><br />\n";
  $query = "( machine.host_name like \"%.sw.%\") order by machine.host_name";

  ($result, $err ) = CMU::Netdb::list_trunkset_presences($dbh, $user, 'machine', $query);
  $repos = CMU::Netdb::makemap(shift @$result);
  
  $tgt = [ map {$_->[$repos->{'machine.host_name'}]} (@$result) ];
  
  map { $tgt2->{$_} = 1 } (@$tgt);
  $tgt = [ sort keys %$tgt2 ];


  print $q->start_form(-method=>'GET');
  print "Device " . $q->popup_menu(-name=>"device",
				   -values=> $tgt,
				   -default => $dev
				  );
  print $q->hidden('op', 'sw_panel_config');
  print $q->submit();
  print $q->end_form();
  print "<hr />\n";
  print $q->start_form(-method=>'GET');
  print "Building " . $q->textfield(-name => 'bldg',
				    -size => 20,
				    -maxlength => 5,
				    -default => $bldg
				   );
  print "Closet " . $q->textfield(-name => 'closet',
				  -size => 3,
				  -maxlength => 1,
				  -default => $clos
				 );
  print "Rack " . $q->textfield(-name => 'rack',
				-size => 3,
				-maxlength => 1,
				-default => $rack
				 );
  print "Panel " . $q->textfield(-name => 'panel',
				 -size => 3,
				 -maxlength => 1,
				 -default => $pan
				);
  print $q->hidden('op', 'sw_panel_config');
  print $q->submit();
  print $q->end_form();


}


1;

