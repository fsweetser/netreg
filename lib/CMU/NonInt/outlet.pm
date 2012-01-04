#   -*- perl -*-
#
# CMU::NonInt::outlet
#
# 
# $Id: outlet.pm,v 1.5 2008/03/27 19:42:36 vitroth Exp $
# 
# $Log: outlet.pm,v $
# Revision 1.5  2008/03/27 19:42:36  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.4.26.1  2007/10/11 20:59:41  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.4.24.1  2007/09/20 18:43:05  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.4  2001/06/28 22:45:47  vitroth
# Next phase complete
#
# Revision 1.3  2001/06/28 16:40:05  vitroth
# Fixed XML error.
#
# Revision 1.2  2001/06/25 21:03:02  vitroth
# Minor fixes for older perl then what I was testing with.
#
# Revision 1.1  2001/06/25 19:18:08  vitroth
# Initial checkin of netreg noninteractive interface.  Partially implemented.
#
#
#



package CMU::NonInt::outlet;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK);
use CMU::Netdb;
use CGI;
use DBI;



require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(list_outlets_by_user outlet_view);

sub xmlformat_outletlist {
  my ($dbh, $ref) = @_;
  my $output;
  my $outletpos = CMU::Netdb::makemap($ref->[0]);

  my ($i, $col);
  
  $output = '<?xml version="1.0" standalone="yes"?>'. "\n<outletlist>\n";
  foreach $i (1..$#$ref) {
    $output .= "<outlet>\n";
    # Start with all the fields that can be output directly
    foreach $col (qw(outlet.id outlet.version outlet.device outlet.port outlet.attributes outlet.flags outlet.status cable.id cable.label_from cable.label_to cable.to_room_number)) {
      $output .= "  <$col>" . $ref->[$i][$outletpos->{"$col"}] 
	. "</$col>\n";
    }
    
    # Now fields that we need to do a subquery for
    # Building
    my $bref = CMU::Netdb::list_buildings_ref($dbh, "netreg", "building.building = '" . $ref->[$i][$outletpos->{"cable.to_building"}] ."'", 'building.name');
    $output .= "  <building.name>". $bref->{$ref->[$i][$outletpos->{'cable.to_building'}]} . "</building.name>\n";

    # Owner/Department
    my $pref = CMU::Netdb::list_protections($dbh, "netreg", "outlet", $ref->[$i][$outletpos->{"outlet.id"}], "");
    if (ref $pref) {
      foreach my $j (0..$#$pref) {
	if ($pref->[$j][0] eq "user") {
	  $output .= "  <users.name>" . $pref->[$j][1] . "</users.name>\n";
	} elsif ($pref->[$j][0] eq "group") {
	  $output .= "  <groups.name>" . $pref->[$j][1] . "</groups.name>\n";
	}
      }
    }
    
    
    $output .= "</outlet>\n";

  }

  $output .= "</outletlist>\n";

  return $output;
}

sub list_outlets_by_user {
  my ($q) = @_;
  my ($dbh, $userid, $output);
  
  $dbh = CMU::Netdb::report_db_connect;
  
  my $user = $q->param("user");
  my $uref = CMU::Netdb::list_users($dbh, "netreg", "users.name = \"$user\"");
  if (ref $uref && $#$uref == 1) {
    $userid = $uref->[1][1];
  } else {
    die "Unable to find user";
  }

  my $ref = CMU::Netdb::list_outlets_cables_munged_protections($dbh, $user, "USER", $userid, "");

  die "list_outlets failed" unless (ref $ref);

  $output = xmlformat_outletlist($dbh, $ref);

  print $q->header('text/xml');
  print $output;

  $dbh->disconnect;

};

sub outlet_view {

  my ($q) = @_;
  my ($dbh, $userid, $output);
  
  $dbh = CMU::Netdb::report_db_connect;
  
  my $from = $q->param("cable.label_from");
  my $to = $q->param("cable.label_to");
  my $building = $q->param("cable.to_building");
  my $room = $q->param("cable.to_room");

  my $where = "";

  if ($from ne "") {
    $where = "cable.label_from like \"%" . $from . "%\"";
  }
  if ($to ne "") {
    $where .= " OR " if ($where ne "");
    $where .= "cable.label_to like \"%" . $to . "%\"";
  }
  if (($building ne "") && ($room ne "")) {
    $where .= " OR " if ($where ne "");
    $where .= "(cable.to_building = $building AND cable.to_room = \"$room\")";
  }

  die "No outlet information provided\n" unless ($where ne "");
  $where = "($where)";

  my $ref = CMU::Netdb::list_outlets_cables($dbh, "netreg", $where);

  die "list_outlets failed" unless (ref $ref);

  $output = xmlformat_outletlist($dbh, $ref);

  print $q->header('text/xml');
  print $output;

  $dbh->disconnect;

}


1;
