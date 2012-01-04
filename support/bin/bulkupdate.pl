#!/usr/bin/perl
#
# Bulkupdate.pl
# This script takes files in a specific format, and uses them to 
# generate various types of update requests to the netreg server.
#
# The format of lines in these files should be
# OperationType,TargetType,Args
# OR comment lines starting with #
#
# OperationType:
# delete: delete matching entries, via API calls
# expire: expire matching machines
# separator: change the separator used for field delimination in the spec
#            file.
# add: Add an entry to a table
#
# TargetType:
# delete: table name
# expire: a time specificer, i.e. 'now() + interval 14 day'
# separator: new regexp to use for split
# add: table to add to, only machine supported at present
# addservicemember: table name  (currently limited to 'machine')

#
# Args
# delete: where clause to use for list_<foo> OR just a row ID.
# expire: where clause to use for list_machine OR just a row ID
# separator: none
# add: values of the fields for the entry.  The form of the values
#      should be fieldname=value.  Multiple fields are separated by the current
#      separator (comma default, changed via 'separator' command.).  
#      Permissions are specified via "perm=groupname PERMS level" i.e.
#      "perm=dept:nginfra READ,WRITE 1"  (note that the separator must not
#      be ',' for that to work)
# addservicemember: two arguments.  The first argument is a numeric service id.
#      the second argument is a where clause to use for list_<foo>, or just a rowID.
#
# Copyright (c) 2000-2006 Carnegie Mellon University. All rights reserved.
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


# Portions Copyright (c) 2006 Managed and Monitored Network Services, LLC
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
# 3. The name "Managed and Monitored Network Services, LLC" must not be used to endorse or
#    promote products derived from this software without prior written
#    permission. For permission or any legal details, please contact
#    info@managedandmonitored.net
#
# 4. Redistributions of any form whatsoever must retain the following
#    acknowledgment: "This product includes software developed by 
#    Managed and Monitored Network Services, LLC (http://www.managedandmonitored.net)"
#
# MANAGED AND MONITORED NETWORK SERVICES, LLC, DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL MANAGED
# AND MONITORED NETWORK SERVICES, LLC, BE LIABLE FOR ANY SPECIAL,
# INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
# RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
# CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
#



# $Id: bulkupdate.pl,v 1.13 2006/10/10 12:04:57 vitroth Exp $
#
# $Log: bulkupdate.pl,v $
# Revision 1.13  2006/10/10 12:04:57  vitroth
# added addservicemember support, submission from Managed and Monitored
# Network Services, LLC, and copyright notice
#
# Revision 1.12  2006/10/10 11:46:48  vitroth
# minor debugging output changes.
#
# Revision 1.11  2005/08/17 15:21:18  fk03
# Remove debugging statement.
#
# Revision 1.10  2005/08/17 13:34:56  fk03
# Fixed to allow adding outlets in any valid state.
#
# Revision 1.9  2005/08/03 14:19:00  vitroth
# Added bulk expire capability
#
# Revision 1.8  2005/02/15 22:02:11  vitroth
# Added support for adding outlets via bulkupdate.
# Also added a bugfix from Jason Shulz (js4450@albany.edu) for
# handing result codes from delete properly.
#
# Revision 1.7  2002/01/30 20:56:54  kevinm
# Fixed vars_l
#
# Revision 1.6  2001/07/20 22:22:26  kevinm
# Copyright info
#
# Revision 1.5  2000/10/03 16:26:00  vitroth
# Fixed error reporting stuff.
#
# Revision 1.4  2000/09/29 20:40:00  vitroth
# turned off netdb debuging
#
# Revision 1.3  2000/09/29 17:29:02  vitroth
# typo in cs report stuff
#
# Revision 1.2  2000/09/20 15:56:40  vitroth
# Adding machines basically works.
#
# Revision 1.1  2000/09/01 14:39:38  vitroth
# Initial checkin of bulkupdate script.  Only delete implemented at present.
#
#
#

BEGIN {
  my @LPath = split(/\//, __FILE__);
  push(@INC, join('/', @LPath[0..$#LPath-1]));
}
use vars_l;
use lib $vars_l::NRLIB;
use CMU::Netdb;
use strict;
use Data::Dumper;

my ($op, $type, $args);
my ($todo, $typekey, $targetkey);
# If $debug is 3 nothing will actually be changed.  Lots of debugging output.
# If $debug is 2 changes will be made, and you'll still get lots of 
# debugging output.
my $debug = 2;
#$CMU::Netdb::debug = 2;
#$CMU::Netdb::machines_subnets::debug = 2;
#$CMU::Netdb::auth::debug = 2;
#$CMU::Netdb::primitives::debug = 2;
#$CMU::Netdb::helper::debug = 2;

my $separator = ',';
while (<>) {
  chomp;
  if (/^\#/) {
    next;
  }
  if (/^\s*$/) {
    next;
  }

  ($op, $type, $args) = split /$separator/, $_, 3;
  print STDERR "Op is '$op'\n" if ($debug >= 2);

  if ($op eq "separator") {
    if ($type eq "") {
      print STDERR "No separator specified\n";
      exit;
    }
    print STDERR "Changing separator to: '$type'\n" if ($debug >= 1);
    $separator = $type;
    next;
  }

  if ($op eq "delete") {
    if (($type eq "") || ($args eq "")) {
      print STDERR "Invalid delete format: $_\n";
      next;
    }
    
    $todo->{"delete"}->{$type}->{$args} = 1;
    print STDERR "Added:$op:$type:$args\n" if ($debug >= 1);
    next;
  }

  if ($op eq "expire") {
    if (($type eq "") || ($args eq "")) {
      print STDERR "Invalid expire format: $_\n";
      next;
    }
    $todo->{"expire"}->{$type}->{$args} = 1;
    print STDERR "Added:$op:$type:$args\n" if ($debug >= 1);
    next;
  }

  if ($op eq "addservicemember") {
    if (($type eq "") || ($args eq "")) {
      print STDERR "Invalid addservicemember format: $_\n";
      next;
    }
    $todo->{"addservicemember"}->{$type}->{$args} = 1;
    print STDERR "Added:$op:$type:$args\n" if ($debug >= 1);
    next;
  }

  if ($op eq "perm") {
    if (($type eq "") || ($args eq "")) {
      print STDERR "Invalid permissions format: $_\n";
      next;
    }
    
    $todo->{"perm"}->{$type}->{$args} = 1;
    print STDERR "Added $op $type $args\n" if ($debug >= 1);
    next;
  }

  if ($op eq "add") {
    if (($type eq "") || ($args eq "")) {
      print STDERR "Invalid add format: $_\n";
      next;
    }
    
    $todo->{"add"}->{$type}->{$args} = 1;
    print STDERR "Added $op $type $args\n" if ($debug >= 1);
    next;
  }

  print STDERR "Unknown format: $_\n";
}

my $where;
my ($code, $ref, $i, $id, $ver);
my $dbh = CMU::Netdb::lw_db_connect();

print "Processing bulk tasks:\n".Data::Dumper->Dump([$todo], ['todo']) if ($debug >= 2);

foreach $typekey (keys %{$todo->{"delete"}}) {
  $where = "";
  if (($typekey eq "users") || ($typekey eq "groups") || ($typekey eq "protections") || ($typekey eq "memberships")) {
    print STDERR "Users/Groups/Protections may not be deleted directly.\n";
    next;
  }
  foreach $targetkey (keys %{$todo->{"delete"}->{$typekey}}) {
    $where .= " OR " if ($where ne "");
    $where .= "(" . $targetkey . ")";
  }
  $code = "CMU::Netdb::list_$typekey";
  $code =~ s/([^s])$/$1s/;
  $code .= '($dbh, "netreg", $where);';

  print STDERR "About to eval: " . $code . "\n" if ($debug >= 2);
  print STDERR "     \$where is $where\n" if ($debug >= 2);

  $ref = eval $code;
  if ($ref == undef) {
    print STDERR "Eval failed on " . $code . "\n";
  }
  if (!ref $ref) {
    print STDERR "Bad data returned during eval of " . $code . "\n";
  }

  for($i=0; $i<=$#{$ref->[0]}; $i++) {
    if ($ref->[0]->[$i] eq "$typekey.id") {
      $id = $i;
    }
    if ($ref->[0]->[$i] eq "$typekey.version") {
      $ver = $i;
    }
  }

  for ($i=1; $i <= $#$ref; $i++) {
    $code = "CMU::Netdb::delete_$typekey";
    $code .= '($dbh, "netreg", $ref->[$i]->[$id], $ref->[$i]->[$ver]);';
    print STDERR "About to eval: " . $code . "\n" if ($debug >= 2);
    print STDERR "     id is $ref->[$i]->[$id]\n" if ($debug >= 2);
    if ($debug < 3) {  
      my ($result, $ref1) = eval $code;
      if ($@) {
	print STDERR "Eval failed on " . $code . " with error $@\n";
      } elsif (defined $result && $result == 1) {
	print "Deleted id $ref->[$i]->[$id] from $typekey\n";
      } else {
	print STDERR "Error during delete: $result ($CMU::Netdb::errors::errmeanings{$result})";
	print STDERR "(".join(', ', @$ref1).")" if (ref $ref1 eq 'ARRAY');
	print STDERR "\n";
      }
    }
  }
  print STDERR "Deleted ".($i - 1) . " entries from $typekey\n";
}

foreach my $when (keys %{$todo->{"expire"}}) {
  print STDERR "Processing expirations for $when\n" if ($debug >= 2);
  $where = "";
  foreach $targetkey (keys %{$todo->{"expire"}->{$when}}) {
    print STDERR "Processing expirations for $targetkey\n" if ($debug >= 2);
    $where .= " OR " if ($where ne "");
    $where .= "(" . $targetkey . ")";
  }
  $code = "CMU::Netdb::list_machines";
  $code =~ s/([^s])$/$1s/;
  $code .= '($dbh, "netreg", $where);';

  print STDERR "About to eval: " . $code . "\n" if ($debug >= 2);
  print STDERR "     \$where is $where\n" if ($debug >= 2);

  $ref = eval $code;
  if ($ref == undef) {
    print STDERR "Eval failed on " . $code . "\n";
  }
  if (!ref $ref) {
    print STDERR "Bad data returned during eval of " . $code . "\n";
  }

  for($i=0; $i<=$#{$ref->[0]}; $i++) {
    if ($ref->[0]->[$i] eq "machine.id") {
      $id = $i;
    }
    if ($ref->[0]->[$i] eq "machine.version") {
      $ver = $i;
    }
  }

  for ($i=1; $i <= $#$ref; $i++) {
    $code = "CMU::Netdb::expire_machine";
    $code .= '($dbh, "netreg", $ref->[$i]->[$id], $ref->[$i]->[$ver], '.$dbh->quote($when).');';
    print STDERR "About to eval: " . $code . "\n" if ($debug >= 2);
    print STDERR "     id is $ref->[$i]->[$id]\n" if ($debug >= 2);
    if ($debug < 3) {  
      my ($result, $errref) = eval $code;
      if ($@) {
	print STDERR "Eval failed on " . $code . " with error $@\n";
      } elsif (defined $result && $result == 1) {
	print "Expired machine id $ref->[$i]->[$id]\n";
      } else {
	print STDERR "Error during expire: $result";
	print STDERR "(".join(', ', @$errref).")" if (ref $errref eq 'ARRAY');
	print STDERR "\n";
      }
    }
  }
  print STDERR "Expired ".($i - 1) . " machines\n";
}


foreach my $type (keys %{$todo->{"addservicemember"}}) {
  print STDERR "Processing addservicemember for $type\n" if ($debug >= 2);
  foreach $targetkey (keys %{$todo->{"addservicemember"}->{$type}}) {
    print STDERR "Processing addservicemember for $targetkey\n" if ($debug >= 2);

    my ($service, $where) = split /$separator/, $targetkey;

    die "Invalid service id $service" if ($service !~ /^\d+$/);

    $code = "CMU::Netdb::list_machines";
    $code =~ s/([^s])$/$1s/;
    $code .= '($dbh, "netreg", $where);';
    
    print STDERR "About to eval: " . $code . "\n" if ($debug >= 2);
    print STDERR "     \$where is $where\n" if ($debug >= 2);
    
    $ref = eval $code;
    if ($ref == undef) {
      print STDERR "Eval failed on " . $code . "\n";
    }
    if (!ref $ref) {
      print STDERR "Bad data returned during eval of " . $code . "\n";
    }

    for($i=0; $i<=$#{$ref->[0]}; $i++) {
      if ($ref->[0]->[$i] eq "machine.id") {
      $id = $i;
      }
      if ($ref->[0]->[$i] eq "machine.version") {
      $ver = $i;
      }
    }

    for ($i=1; $i <= $#$ref; $i++) {
      if ($debug < 3) {  
      my ($result, $errref) = CMU::Netdb::add_service_membership($dbh, 'netreg', {'member_type' => 'machine',
                                                                                  'member_tid' => $ref->[$i][$id],
                                                                                  'service' => $service});
      if ($@) {
        print STDERR "Eval failed on " . $code . " with error $@\n";
      } elsif (defined $result && $result == 1) {
        print "Added service member machine id $ref->[$i]->[$id]\n";
      } else {
        print STDERR "Error during add_service_membership: $result";
        print STDERR "(".join(', ', @$errref).")" if (ref $errref eq 'ARRAY');
        print STDERR "\n";
      }
      }
    }
    print STDERR "Added ".($i - 1) . " service members\n" if ($debug >= 1);
  }
}




foreach $typekey (keys %{$todo->{"perm"}}) {

}

foreach $typekey (keys %{$todo->{"add"}}) {
  if ($typekey eq "machine") {
    my ($arg, $rest, %fields, %perms, $f1, $f2, $f3, @result, $key, $user);
  
    foreach $targetkey (keys %{$todo->{"add"}->{$typekey}}) {
      $rest = $targetkey;
      undef %fields;
      undef %perms;
      $user = "netreg";

      while ($rest ne "") {
	($arg, $rest) = split /$separator/, $rest, 2;
	($f1, $f2) = split /=/, $arg, 2;
	if ($f1 eq "perm") {
	  ($f1, $f2, $f3) = split / /, $f2, 3;
	  $perms{$f1}->[0] = $f2;
	  $perms{$f1}->[1] = $f3;
	  print STDERR "Queuing permission of: $f1 $f2 $f3\n" if ($debug >=2);
	} elsif ($f1 eq "user") {
	  $user = $f2;
	  print STDERR "Adding as $user\n";
	} else {
	  $fields{$f1} = $f2;
	  print STDERR "Queuing field of: $f1 $f2\n" if ($debug >=2);
	}
      }

      print STDERR "About to add machine, fields are:\n" if ($debug >=1);
      foreach $key (keys %fields) {
	print STDERR "$key=$fields{$key}\n" if ($debug >= 1);
      }

      my @result = CMU::Netdb::add_machine($dbh, $user, 9, \%fields, \%perms) if ($debug <= 2);

      if ($result[0] <= 0) {
	print STDERR "Error: $result[0] ($CMU::Netdb::errors::errmeanings{$result[0]}) on @{$result[1]}\n";
      } elsif (%{$result[1]}) {
	print STDERR "Result $result[0]: ";
	foreach $key (keys %{$result[1]}) {
	  print STDERR "$key=$result[1]{$key} ";
	}
	print STDERR "\n";
      }
   
    }
  } elsif ($typekey eq 'outlet') {
    my ($arg, $rest, %fields, %perms, $f1, $f2, $f3, @result, $key, $user);

    foreach $targetkey (keys %{$todo->{"add"}->{$typekey}}) {
      $rest = $targetkey;
      undef %fields;
      undef %perms;
      $user = "netreg";

      while ($rest ne "") {
	($arg, $rest) = split /$separator/, $rest, 2;
	($f1, $f2) = split /=/, $arg, 2;
	if ($f1 eq "perm") {
	  ($f1, $f2, $f3) = split / /, $f2, 3;
	  $perms{$f1}->[0] = $f2;
	  $perms{$f1}->[1] = $f3;
	  print STDERR "Queuing permission of: $f1 $f2 $f3\n" if ($debug >=2);
	} elsif ($f1 eq "user") {
	  $user = $f2;
	  print STDERR "Adding as $user\n";
	} else {
	  $fields{$f1} = $f2;
	  print STDERR "Queuing field of: $f1 $f2\n" if ($debug >=2);
	}
      }

      print STDERR "About to add outlet, fields are:\n" if ($debug >=1);
      foreach $key (keys %fields) {
	print STDERR "$key=$fields{$key}\n" if ($debug >= 1);
      }

      if ($debug <= 2) {
	my @result = CMU::Netdb::add_outlet($dbh, $user, 9, \%fields, \%perms);

	if ($result[0] <= 0) {
	  print STDERR "Error: $result[0] ($CMU::Netdb::errors::errmeanings{$result[0]}) on @{$result[1]}\n";
	} elsif (%{$result[1]}) {
	  print STDERR "Result: ";
	  foreach $key (keys %{$result[1]}) {
	    print STDERR "$key -> $result[1]->{$key}\n";
	  }
	  print STDERR "\n";
	}
      }
    }
  } else {
    print STDERR "Don't know how to add entries to table $typekey.\n";
    next;
  }
}

$dbh->disconnect();

