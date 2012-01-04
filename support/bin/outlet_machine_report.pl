#! /usr/bin/perl
#
# Copyright (c) 2000-2002 Carnegie Mellon University. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. The name "Carnegie Mellon University" must not be used to endorse or
#    promote products derived from this software without prior written
#    permission. For permission or any legal details, please contact:
#      Office of Technology Transfer
#      Carnegie Mellon University
#      5000 Forbes Avenue
#      Pittsburgh, PA 15213-3890
#      (412) 268-4387, fax: (412) 268-7395
#      tech-transfer@andrew.cmu.edu
#
# 4. Redistributions of any form whatsoever must retain the following
#    acknowledgment: "This product includes software developed by Computing
#    Services at Carnegie Mellon University (http://www.cmu.edu/computing/)."
#
# CARNEGIE MELLON UNIVERSITY DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
# SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS,
# IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY BE LIABLE FOR ANY SPECIAL,
# INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
# OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
#
#  This program outputs usage of Outlets, Wired-IP, Wireless-IP, ADSL-IP 
#  by Department for import into Excel or other such packages
#  
#  $output - file to output data to, STDOUT currently.
#  $field_sep - field separtor used between columns, currently ','
#
#
# $Id: outlet_machine_report.pl,v 1.4 2008/03/27 19:42:43 vitroth Exp $
#
# $Log: outlet_machine_report.pl,v $
# Revision 1.4  2008/03/27 19:42:43  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.3.22.1  2007/10/11 20:59:46  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.3.20.1  2007/09/20 18:43:07  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:42  kcmiller
#
#
# Revision 1.3  2002/01/30 21:34:17  kevinm
# Fixed vars_l
#
#
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}

use vars_l;
use lib $vars_l::NRLIB;
#use strict;

use CMU::Netdb::helper;
use CMU::Netdb::reports;

my ($output, $field_sep); 

$output = STDOUT;
$field_sep = ',';

# allow for command line args here.

my ($dbh);

## Getting outlet data

$dbh = report_db_connect();

  my ($outlet_table, %outlet_headings, %deparments, $dept, $type, $i);

  my $outlet_table =  general_query($dbh, 'netreg', 'count_outlettypes_departments', \&remove_dept_tag_hash2, undef);

  if (!ref $outlet_table) {
    if ($outlet_table eq $errcodes{EPERM}) {
      accessDenied();
    }else{
      print STDERR "Unknown error reading outlet table.\n";
    }
    $dbh->disconnect();
    return;
  }

foreach $dept (keys %$outlet_table) {
  $departments{$dept} = 1;
  foreach $type (keys %{$$outlet_table{$dept}}) { # can do this with a query on outlet types too
    $outlet_headings{$type} = 1;
  }
}

  my (%machine_table, %wireless_table, %adsl_table);
  my @modes=('static','dynamic','reserved','broadcast','pool','base');


### getting wired-ip machines 

  my $machine_table =  general_query($dbh, 'netreg', 'count_wiredmachines_departments', \&remove_dept_tag_hash2, undef);

  if (!ref $machine_table) {
    if ($machine_table eq $errcodes{EPERM}) {
      accessDenied();
    }else{
      print STDERR "Unknown error reading machine table.\n";
    }
    $dbh->disconnect();
    return;
  }

foreach $dept (keys %$machine_table) {
  $departments{$dept} = 1;

}


### wireless-ip

  my $wireless_table =  general_query($dbh, 'netreg', 'count_subnetabbrev-machines_departments', \&remove_dept_tag_hash2, [ 'wireless' ]);

  if (!ref $wireless_table) {
    if ($wireless_table eq $errcodes{EPERM}) {
      accessDenied();
    }else{
      print STDERR "Unknown error reading machine table.\n";
    }
    $dbh->disconnect();
    return;
  }

foreach $dept (keys %$wireless_table) {
  $departments{$dept} = 1;

}


### ADSL--ip

  my $adsl_table =  general_query($dbh, 'netreg', 'count_subnetabbrev-machines_departments', \&remove_dept_tag_hash2, [ 'ADSL' ]);

  if (!ref $adsl_table) {
    if ($adsl_table eq $errcodes{EPERM}) {
      accessDenied();
    }else{
      print STDERR "Unknown error reading machine table.\n";
    }
    $dbh->disconnect();
    return;
  }

foreach $dept (keys %$adsl_table) {
  $departments{$dept} = 1;

}

### get department descriptions

$sur = general_query($dbh, 'netreg', 'list_description_departments');
if (!ref $sur) {
  if ($sur eq $errcodes{EPERM}) {
    accessDenied();
  }else{
    print "Unknown error reading group table.\n";
  }
  $dbh->disconnect();
  return;
}

foreach $i (0 .. $#$sur) {
  if ($$sur[$i][0] =~ /^dept:(.*)/) { $$sur[$i][0] = $1; }   
  if ($departments{$$sur[$i][0]}) {  # only care about depts previously found
    $departments{$$sur[$i][0]} = $$sur[$i][1]; #set description
  }
}

$dbh->disconnect();

#############  OUTPUTING HERE ########################

  # top row heading: Ports, Wired-IP, Wireless-IP, ADSL-IP

  print $output $field_sep, $field_sep, "Ports";

  foreach $type (keys %outlet_headings) {
    print $output $field_sep;
  }
  print $output "Wired-IP";

  foreach $type (@modes) {
    print $output $field_sep;
  }
  print $output "Wireless-IP";

  foreach $type (@modes) {
    print $output $field_sep;
  }
  print $output "ADSL-IP";
  print $output "\n";

  # 2nd row headings
  print $output "Department", $field_sep;

  ### outlet headings
  foreach $type (sort  keys %outlet_headings) {
    print $output $field_sep, "$type";
  }
  ### outleted machine headings
  foreach $type (@modes) {
    print  $output $field_sep, "$type";
  }
  ### wireless machine headings
  foreach $type (@modes) {
    print  $output $field_sep, "$type";
  }
  ### ADSL machine headings
  foreach $type (@modes) {
    print  $output $field_sep, "$type";
  }
  print $output "\n";

##### Actual data output

foreach $dept (sort keys %departments) {
  print $output $dept, $field_sep, $departments{$dept};

  ### outlets
  foreach $type (sort keys %outlet_headings) {
    if ($$outlet_table{$dept}{$type}) {
      print $output $field_sep, $$outlet_table{$dept}{$type};
    }
    else { 
      print $output $field_sep, "0";
    }
  }
  ### Wired machines
  foreach $type(@modes) {
      if ($$machine_table{$dept}{$type}) {
	print $output $field_sep, $$machine_table{$dept}{$type};
      }
      else {
	print $output $field_sep, "0";
      }
    }
  
  ### wireless machines
  foreach $type(@modes) {
      if ($$wireless_table{$dept}{$type}) {
	print $output $field_sep, $$wireless_table{$dept}{$type};
      }
      else {
	print $output $field_sep, "0";
      }
    }
  
  ### ADSL machines
  foreach $type(@modes) {
      if ($$adsl_table{$dept}{$type}) {
	print $output $field_sep, $$adsl_table{$dept}{$type};
      }
      else {
	print $output $field_sep, "0";
      }
    }
  
  print $output "\n";
}

