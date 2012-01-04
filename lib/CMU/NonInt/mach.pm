#   -*- perl -*-
#
# CMU::NonInt::mach
#
# 
# $Id: mach.pm,v 1.5 2008/03/27 19:42:36 vitroth Exp $
# 
# $Log: mach.pm,v $
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



package CMU::NonInt::mach;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK);
use CMU::Netdb;
use CGI;
use DBI;



require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(list_machines_by_user mach_view);


sub xmlformat_machinelist {
  my ($dbh, $ref) = @_;
  my $output;
  my $machpos = CMU::Netdb::makemap($ref->[0]);
  
  my ($i, $col);
  
  $output = '<?xml version="1.0" standalone="yes"?>'. "\n<machinelist>\n";
  foreach $i (1..$#$ref) {
    $output .= "<machine>\n";
    # Start with all the fields that can be output directly
    foreach $col (qw{machine.host_name machine.mac_address machine.ip_address machine.mode machine.flags machine.id machine.created machine.version machine.expires}) {
      $output .= "  <$col>" . $ref->[$i][$machpos->{"$col"}] 
	. "</$col>\n";
    }
    
    # Now fields that we need to do a subquery for
    # IP Address
    my $sref = CMU::Netdb::list_subnets_ref($dbh, "netreg", "subnet.id = '" . $ref->[$i][$machpos->{"machine.ip_address_subnet"}] ."'", 'subnet.name');
    $output .= "  <subnet.name>". $sref->{$ref->[$i][$machpos->{'machine.ip_address_subnet'}]} . "</subnet.name>\n";
    

    # Owner/Department
    my $pref = CMU::Netdb::list_protections($dbh, "netreg", "machine", $ref->[$i][$machpos->{"machine.id"}], "");
    if (ref $pref) {
      foreach my $j (0..$#$pref) {
	if ($pref->[$j][0] eq "user") {
	  $output .= "  <users.name>" . $pref->[$j][1] . "</users.name>\n";
	} elsif ($pref->[$j][0] eq "group") {
	  $output .= "  <groups.name>" . $pref->[$j][1] . "</groups.name>\n";
	}
      }
    }
    
    $output .= "</machine>\n";
    
  }

  $output .= "</machinelist>\n";

  return $output;

}

sub list_machines_by_user {
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
  
  my $ref = CMU::Netdb::list_machines_munged_protections($dbh, $user, "USER", $userid, "");
  
  die "list_machines failed" unless (ref $ref);
  
  $output = xmlformat_machinelist($dbh, $ref);

  print $q->header('text/xml');
  print $output;
  
  $dbh->disconnect;
  
};


sub mach_view {
  my ($q) = @_;
  my ($dbh, $userid, $output);
  
  $dbh = CMU::Netdb::report_db_connect;
  
  my $hostname = $q->param("machine.host_name");
  my $hwaddr = $q->param("machine.mac_address");
  my $ip_address = $q->param("machine.ip_address");

  my $where = "";

  if ($hostname ne "") {
    $where = "machine.host_name like \"%" . $hostname . "%\"";
  }
  if ($hwaddr ne "") {
    $where .= " OR " if ($where ne "");
    $where .= "machine.mac_address = \"" . $hwaddr . "\"";
  }
  if ($ip_address ne "") {
    $where .= " OR " if ($where ne "");
    $where .= "machine.ip_address = " . CMU::Netdb::dot2long($ip_address);
  }

  die "No machine information provided" unless ($where ne "");

  $where = "($where)";

  my $ref = CMU::Netdb::list_machines($dbh, "netreg", $where);
  
  die "list_machines failed" unless (ref $ref);
  
  $output = xmlformat_machinelist($dbh, $ref);

  print $q->header('text/xml');
  print $output;
  
  $dbh->disconnect;
  
}


1;
