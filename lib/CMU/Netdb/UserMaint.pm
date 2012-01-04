#   -*- perl -*-
#
# CMU::Netdb::UserMaint::UserMaint
# This module provides the necessary API functions for
# manipulating user/group/memberships/protections data
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

package CMU::Netdb::UserMaint;

use strict;

use DBI;
use CMU::Netdb;

use CMU::Helper::SendMail;

use Text::Wrap;
use Data::Dumper;
use POSIX qw(strftime);

use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
  usermaint_enumerate
  usermaint_delete_user
  usermaint_add_user
);

my $debug = 4;
my $total_outlets_deleted = 0;
my $total_machines_deleted = 0;

sub usermaint_enumerate {
  my ($dbh, $dbuser, $users, $type) = @_;

  if (!$dbh) {
    $dbh = CMU::Netdb::lw_db_connect();
    if (!$dbh) { 
      warn __FILE__ .':'. __LINE__ . " usermaint_enumerate: Database handle could not be established: $dbh\n";
      return (0, []);
    }
  }

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  # Validate the type and access to it
  $type = CMU::Netdb::valid('user_type.name', $type, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($type), ['type']) if (CMU::Netdb::getError($type) != 1);

  warn "UserMaint: usermaint_enumerate called by $dbuser on type $type\n";

  my $user_types = CMU::Netdb::UserMaint::get_user_types($dbh, $dbuser, "user_type.name = '$type'");
  return ($user_types, ['user_type']) if (!ref $user_types);

  my $ut_map = CMU::Netdb::makemap(shift @$user_types);
  my $ut_id = $user_types->[0][$ut_map->{'user_type.id'}];

  # level 5 ADD is add/delete/enumerate
  my $level = CMU::Netdb::get_add_level($dbh, $dbuser, 'user_type', $ut_id);
  if ($level < 5) {
    warn __FILE__ .':'. __LINE__ . " usermaint_enumerate: user $dbuser tried to enumerate user_type $type. access denied!\n";
    return ($CMU::Netdb::errcodes{EPERM}, ['user_type']);
  }

  # Verify that we got a structure of users like:
  # | user@id | user name |
  # | abc@def,foo@bar | Blah Blah |

  return ($CMU::Netdb::errcodes{EINVALID}, ['users']) if (ref $users ne 'ARRAY');

  my @errors;

  warn __FILE__ . ':' . __LINE__ . " UserMaint: usermaint_enumerate starting validation of ".scalar(@$users)." users.\n";
  foreach my $row (@$users) {
    return ($CMU::Netdb::errcodes{EINVALID}, ['users']) if (ref $row ne 'ARRAY');

    # check for comma separated list of userids, re-assemble after validtion
    my @uidlist = split /,/, $row->[0];
    foreach my $uid (@uidlist) {
      $uid = CMU::Netdb::valid('credentials.authid', $uid, $dbuser, 0, $dbh);
      if (CMU::Netdb::getError($uid) != 1) {  
	push @errors, [CMU::Netdb::getError($uid), ['user']];
	warn __FILE__ .':'.__LINE__ . " usermaint_enumerate: error on user $row->[0]\n";
      }
    }
    $row->[0] = join(',', sort(@uidlist));

    $row->[1] = CMU::Netdb::valid('credentials.description', $row->[1], $dbuser, 0, $dbh);
    if (CMU::Netdb::getError($row->[1]) != 1) {
      push @errors, [CMU::Netdb::getError($row->[1]), ['comment']];
      warn __FILE__ .':'.__LINE__ . " usermaint_enumerate: error on user $row->[0]\n";
    }
  }

  return @{$errors[0]} if (@errors);


  my $where = "credentials.type = " . $ut_id;
  my $ret = CMU::Netdb::auth::list_users($dbh, 'netreg', $where);
  return ($ret, []) if (!ref $ret);

  my $hashmap = CMU::Netdb::helper::makemap(shift @$ret);

  my $netregUsers;
  my $netregUIDs;
  my $incomingUsers;

  # Build hash of existing credentials/descriptions and credentials/uids
  foreach my $a (@$ret) {
    $netregUsers->{lc $a->[$hashmap->{'credentials.authid'}]} = $a->[$hashmap->{'credentials.description'}];
    $netregUIDs->{byuser}{lc $a->[$hashmap->{'credentials.authid'}]} = $a->[$hashmap->{'users.id'}];
    push @{$netregUIDs->{byuid}{$a->[$hashmap->{'users.id'}]}}, lc $a->[$hashmap->{'credentials.authid'}];
  }

  # Build hash of incoming user list
  foreach my $b (@$users) {
    $incomingUsers->{lc $b->[0]} = $b->[1];
  }

  warn __FILE__ .':'. __LINE__ . " usermaint_enumerate: input: ", scalar keys %$incomingUsers, ", netreg: ", scalar keys %$netregUsers, "\n" if ($debug >= 1);

  my ($add, $delete) = userAddDelete($incomingUsers, $netregUsers, $netregUIDs);

  my $aerrors = [];
  my $derrors = [];

  warn __FILE__ .':'. __LINE__ . " usermaint_enumerate: add: ", scalar @$add, ", delete: ", scalar @$delete, "\n" if ($debug >= 1);

  sleep 10 if ($debug >= 5);

  foreach my $a (@$add) {
    my ($user, $other) = @$a;
    my $result = usermaint_add_user($dbh, $dbuser, $user, $incomingUsers->{$other}, $type, $other);
    if ($result < 1) {
      warn __FILE__ .':'. __LINE__." Failed to add user $user/$other: $result";
      push @$aerrors, "Failed to add user $user/$other: $result";;
    } 
  }

  foreach my $a (@$delete) {
    my $result = usermaint_delete_user($dbh, $dbuser, $a);
    if ($result < 1) {
      warn __FILE__ .':'. __LINE__." Failed to delete user $a: $result";
      push @$derrors, "Failed to delete user $a: $result";;
    }
  }

  my $total = scalar @$add + scalar @$delete;
  warn __FILE__ .':'. __LINE__ . " Total: $total, Add/Errors: " . scalar @$add . "/" . scalar @$aerrors 
    . " *** Delete/Errors/Machines/Outlets: " . scalar @$delete . "/" . scalar @$derrors . "/$total_machines_deleted/$total_outlets_deleted\n" if ($debug >= 1);

  if ((@$aerrors) || (@$derrors)) {
    return (0, [@$aerrors, @$derrors]);;
  }

  return (1, []);
}

sub usermaint_add_user {
  my ($dbh, $dbuser, $user, $comment, $type, $otheruserids) = @_;
  my @uidlist;
  warn __FILE__ .':'. __LINE__ . " usermaint_add_user: dbuser=$dbuser, user=$user, comment=$comment, type=$type, otheruserids=$otheruserids\n" if ($debug >= 2);
  
  # check for db connection, if it doesn't exist connect to the database.
  if (!$dbh) {
    $dbh = CMU::Netdb::lw_db_connect();
    if (!$dbh) { 
      warn __FILE__ .':'. __LINE__ . " Fail: Database handle could not be established: $dbh\n";
      return ($CMU::Netdb::errcodes{EDB}, []);
    }
  }

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['user']) if (CMU::Netdb::getError($user) != 1);

  if ($otheruserids) {
    @uidlist = split /,/, $otheruserids;
    foreach my $userid (@uidlist) {
      # Any modifications to $userid will modify @uidlist, so that list will be safe to use later.
      $userid = CMU::Netdb::valid('credentials.authid', $userid, $dbuser, 0, $dbh);
      return (CMU::Netdb::getError($userid), ['user']) if (CMU::Netdb::getError($userid) != 1);
    }
  }
  $comment = CMU::Netdb::valid('credentials.description', $comment, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($comment), ['comment']) if (CMU::Netdb::getError($comment) != 1);

  # get a specific user type by name ($type) passed by SOAP.
  $type = CMU::Netdb::valid('user_type.name', $type, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($type), ['type']) if (CMU::Netdb::getError($type) != 1);

  my $user_types = CMU::Netdb::UserMaint::list_user_types($dbh, $dbuser, "user_type.name = '$type'");
  return ($user_types, []) if (!ref $user_types);

  my $ut_map = CMU::Netdb::makemap(shift @$user_types);

  # if there's no entry, nothing was returned, so there's no type by the name of $type.
  if (! @$user_types) { 
    warn __FILE__ .':'. __LINE__." user_type doesn't exist or doesn't have enough permissions: $type";
    return ($CMU::Netdb::errcodes{"EINVALID"}, ['type']);
  }

  my $ut_id = $user_types->[0][$ut_map->{'user_type.id'}];
  
  # level 1 ADD is add/delete
  my $level = CMU::Netdb::get_add_level($dbh, $dbuser, 'user_type', $ut_id);
  return ($CMU::Netdb::errcodes{EPERM}, ['user_type']) if ($level < 1);

  my $uid = cred_exists($dbh, $dbuser, $user);
  if ($uid < 0) {
    return ($CMU::Netdb::errcodes{ERROR}, ['credentials.auth_id']);
  }

  if ($uid == 0) {
    # Primary userid doesn't exist.  Before we create it check the other accounts list
    foreach (@uidlist) {
      last if ($uid = cred_exists($dbh, $dbuser, $_));
    }

    if ($uid < 0) {
      return ($CMU::Netdb::errcodes{ERROR}, ['credentials.auth_id']);
    }

    # If we found a uid, make user $user is in the uidlist and skip the initial add

    if ($uid != 0) {
      push @uidlist, $user;
    } else {
      # If still no uid found, add the primary user

      my $fields = {
		    'comment' => $comment
		   };

      my ($ret, $ref) = CMU::Netdb::auth::add_user($dbh, 'netreg', $fields);
      if ($ret != 1) {
	warn __FILE__ .':'. __LINE__." add_user: failed, $ret.";
	return ($ret, $ref);
      }

      $uid = $$ref{insertID};
      if ($uid < 1) {
	warn __FILE__ .':'. __LINE__." usermaint_add_user: uid isn't valid - $uid";
	return (0, ['insert_id']);
      }

      $fields = {
		 'type' => $ut_id,
		 'user' => $uid,
		 'authid' => $user,
		 'description' => $comment
		};
 
      ($ret, $ref) = CMU::Netdb::auth::add_credentials($dbh, 'netreg', $fields);

      if ($ret != 1) {
	warn __FILE__ .':'. __LINE__." add_cred: failed, $ret.";
	warn __FILE__ .':'. __LINE__." usermaint_add_user: deleting stale user $uid.";
	my $res = ut_delete_user($dbh, $dbuser, $uid);
	return ($ret, $ref);
      }
    }
  } else {
    # primary userid existed, nothing to do
  }

  # Now process extra userids
  if (@uidlist) {
    foreach my $userid (@uidlist) {

      # Test for existing credential
      my $id = cred_exists($dbh, $dbuser, $userid);

      if ($id < 0) {
	return ($CMU::Netdb::errcodes{ERROR}, ['credentials.auth_id']);
      } elsif ($id == 0) {
	# No credential, add to user
	my $fields = {
		      'type' => $ut_id,
		      'user' => $uid,
		      'authid' => $userid,
		      'description' => $comment
		     };

	my ($ret, $ref) = CMU::Netdb::auth::add_credentials($dbh, 'netreg', $fields);

	if ($ret != 1) {
	  warn __FILE__ .':'. __LINE__." add_cred: failed to add $userid to $uid, $ret.";
	  return ($ret, $ref);
	}
      } elsif ($id != $uid) {
	# Error!  Credential already existed, but is tied to a different user.  
	# Manual correction will be required.  Return error.
	return ($CMU::Netdb::errcodes{EEXISTS}, ['credentials.auth_id', "$userid already exists on user $id, not user $uid"]);
      } else {
	# Credential already exists on this user, nothing to do.
      }
    }
  }

  return (1, []);
}

# this actually deletes a credential
sub usermaint_delete_user {
  my ($dbh, $dbuser, $user) = @_;
  warn __FILE__ .':'. __LINE__ . " usermaint_delete_user: attempting to delete user=$user\n" if ($debug >= 2);

  if (!$dbh) {
    $dbh = CMU::Netdb::lw_db_connect();
    if (!$dbh) { 
      warn __FILE__ .':'. __LINE__ . " Database handle could not be established: $dbh\n";
      return ($CMU::Netdb::errcodes{EDB}, []);
    }
  }
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('credentials.authid', $user, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($user), ['user']) if (CMU::Netdb::getError($user) != 1);

  my $where = "credentials.authid = '$user'";
  my $ret = CMU::Netdb::auth::list_users($dbh, 'netreg', $where);
  if (!ref $ret) {
    warn __FILE__ .':'. __LINE__." list_users failed: $ret";
    return ($ret, []);
  }

  my $hashmap = CMU::Netdb::helper::makemap(shift @$ret);
  my $count = scalar (@$ret);

  if ($count > 1) { 
    warn __FILE__ .':'. __LINE__." usermaint_delete_user: multiple users coming back for search for $user.  That's not normal, failure!";
    return (0, ['user']);
  }

  if ($count == 0) {
    warn __FILE__ .':'. __LINE__." usermaint_delete_user: user does not exist ($user)";
    return ($CMU::Netdb::errcodes{ENOENT}, ['user']);
  }
  
  my $type = $ret->[0]->[$hashmap->{'credentials.type'}];
  my $id   = $ret->[0]->[$hashmap->{'users.id'}];
  my $name = $ret->[0]->[$hashmap->{'credentials.authid'}];
  my $version = $ret->[0]->[$hashmap->{'users.version'}];
  my $userflags = $ret->[0]->[$hashmap->{'users.flags'}];

  # get user type information and create a hashmap for it
  # this will also enforce requirement of ADD access >= 1 on the type
  my $user_type = get_user_types($dbh, $dbuser, "user_type.id = '$type'");
  return ($user_type, ['user_type']) if (!ref $user_type);

  my $user_type_map = CMU::Netdb::helper::makemap(shift @$user_type);

  if (scalar @$user_type < 1) {
    warn __FILE__ .':'. __LINE__." user type invalid, or no permission to manipulate users of this type\n";
    return ($CMU::Netdb::errcodes{EINVALID}, ['user_type']);
  }

  # call lists users again by users.id to check for the multiple credential case
  my $usersret = CMU::Netdb::auth::list_users($dbh, 'netreg', "users.id = $id");
  if (!ref $usersret) {
    warn __FILE__ .':'. __LINE__." list_users failed: $usersret\n";
    return ($usersret, []);
  }

  shift @$usersret;

  if (scalar @$usersret > 1) {
    # More then one credential on this user, clear the credential but do nothing else
    my ($result, $dref) = CMU::Netdb::auth::delete_credentials($dbh, 'netreg', $ret->[0]->[$hashmap->{'credentials.id'}], $ret->[0]->[$hashmap->{'credentials.version'}]);
    if ($result < 0) {
      warn __FILE__ .':'. __LINE__." delete_credentials failed: $result\n";
      return ($result, $dref);
    }
    return (1, []);
  }



  # get a list of outlets munged protections
  my $outlets = CMU::Netdb::list_outlets_cables_munged_protections($dbh, $user, 'USER', '', '');
  if (!ref $outlets) {
    warn __FILE__ .':'. __LINE__." list_outlets_cables_munged_protections failed: $outlets\n";
    return ($outlets, ['outlets']);
  }

  my $outlet_hashmap = CMU::Netdb::helper::makemap(shift @$outlets);

  warn "Found " . scalar @$outlets . " outlet(s) for user $user\n" if ($debug >= 3);
   
  # for each outlet list the protections and modify based on that
  foreach my $outlet (@$outlets) {
    my $outlet_id = $outlet->[$outlet_hashmap->{'outlet.id'}];
    my $outlet_version = $outlet->[$outlet_hashmap->{'outlet.version'}];
    my $outlet_flags = $outlet->[$outlet_hashmap->{'outlet.flags'}];

    my $outlet_prot = CMU::Netdb::list_protections($dbh, 'netreg', 'outlet', $outlet_id);
    if (!ref $outlet_prot) {
      warn __FILE__ .':'. __LINE__." list_protections failed: $outlet_prot\n";
      return ($outlet_prot, ['outlet protections']);
    }
    
    my ($users, $groups);

    foreach my $prot (@$outlet_prot) {
      if ($prot->[0] eq 'user') { 
        push(@$users, $prot->[1] );
      } elsif ($prot->[0] eq 'group') {
        push(@$groups, $prot->[1]);
      }
    }

    if ($user_type->[0][$user_type_map->{'user_type.expire_days_outlet'}] < 1) {
      # deactivate the outlet now!
      warn __FILE__ .':'. __LINE__ . " deactivating the outlet now\n" if ($debug > 4);
      
      my $action = "OUTLET_WAIT_PARTITION";

      if (index($outlet_flags, 'permanent') >= 0) { 
        $action = "OUTLET_PERM_WAIT_PARTITION";
      }

      $total_outlets_deleted++;

      my $res = CMU::Netdb::buildings_cables::modify_outlet_state_by_name(
        $dbh, 'netreg', $outlet_id, $outlet_version, $action);
      if ($res < 1) {
        warn __FILE__ .':'. __LINE__." deleting outlet $outlet_id $outlet_version failed: $res\n";
        return (0, []);
      }
    } else {
      warn __FILE__ .':'. __LINE__ . " more than one day, must expire instead of deactivate\n" if ($debug > 4);
      if (scalar @$users == 1) {    
	# Only one user on the outlet, expire the outlet
        warn __FILE__ .':'. __LINE__ . " set expire and email\n" if ($debug >= 5);

        # set expire on them
	$total_outlets_deleted++;
        my $res = expire_outlet($dbh, $dbuser, $outlet_hashmap, $outlet, $user_type->[0][$user_type_map->{'user_type.expire_days_outlet'}]);
        if ($res != 1) { 
          warn __FILE__ .':'. __LINE__." expire_outlet failed: $res\n";
          return (0, []);
        }

        if (index($user_type->[0][$user_type_map->{'user_type.flags'}], 'send_email_outlet') >= 0) {
          # now send emails to everybody
          warn __FILE__ .':'. __LINE__ . " now sending emails to everybody\n" if ($debug >= 5);

          $res = email_expire_notice_outlet($dbh, $dbuser, $outlet_hashmap, $outlet, $user_type->[0][$user_type_map->{'user_type.expire_days_outlet'}], $user);
          if ($res == 0) { 
            warn __FILE__ .':'. __LINE__." email_expire_notice_outlet failed: $res\n";
            return (0, []);
          }
        } # end -- if (index...)
      } else {
        # this means more than one user, so we leave the outlet alone.
        warn __FILE__ .':'. __LINE__ . " Outlet has more than one user, don't do anything.\n" if ($debug >= 5);
      }
    }
    
    warn __FILE__ .':'. __LINE__ . " removing user from outlet\n" if ($debug >= 5);
    my $res = delete_user_from_outlet($dbh, $dbuser, $user, $outlet_hashmap, $outlet);
    if ($res == 0) {
      warn __FILE__ .':'. __LINE__." delete_user_from_outlet failed: $res\n";
      return (0, []);
    }
  }
    
  # take care of the machines
  my $machines = CMU::Netdb::machines_subnets::list_machines_munged_protections($dbh, $user, 'USER', $user, '');
  if (!ref $machines) {
    warn __FILE__ .':'. __LINE__." list_machines_munged_protections failed: $machines\n";
    return (0, []);
  }

  my $mach_hashmap = CMU::Netdb::helper::makemap(shift @$machines);

  warn __FILE__ .':'. __LINE__ . " Found " . scalar @$machines . " machines(s) for user $user\n" if ($debug >= 3);
 
  foreach my $machine (@$machines) {
    warn __FILE__ .':'. __LINE__ . Data::Dumper->Dump([$machine],['machine']) if ($debug >= 6);

    my $mach_id = $machine->[$mach_hashmap->{'machine.id'}];
    my $mach_version = $machine->[$mach_hashmap->{'machine.version'}];
    
    my $mach_prot = CMU::Netdb::list_protections($dbh, 'netreg', 'machine', $mach_id);
    if (!ref $mach_prot) {
      warn __FILE__ .':'. __LINE__." list_protections failed: $mach_prot\n";
      return (0, []);
    }
    
    warn __FILE__ .':'. __LINE__ . Data::Dumper->Dump([$mach_prot],['mach_prot']) if ($debug >= 6);

    my ($users, $groups);

    foreach my $prot (@$mach_prot) {
      if ($prot->[0] eq 'user') { 
        push(@$users, $prot->[1] );
      } elsif ($prot->[0] eq 'group') {
        push(@$groups, $prot->[1]);
      }
    }

    if ($user_type->[0][$user_type_map->{'user_type.expire_days_mach'}] < 1) {
      warn __FILE__ .':'. __LINE__ . " delete the machine now!" if ($debug >= 3); 
      $total_machines_deleted++;
      my $res = CMU::Netdb::machines_subnets::delete_machine($dbh, 'netreg', $mach_id, $mach_version);
      if ($res < 0) {
        warn __FILE__ .':'. __LINE__." delete_machine $mach_id $mach_version failed $res\n";
        return (0, []);
      } # if ($res < 0)
    } else {
      if (scalar @$users == 1) {    
	# Only one user on the machine, expiring the machine.
        warn __FILE__ .':'. __LINE__ . " set expire and email" if ($debug >= 5);

	warn __FILE__ .':'. __LINE__ . Data::Dumper->Dump([$user_type->[0][$user_type_map->{'user_type.expire_days_mach'}], $user_type_map], ['user_type','user_type_map']) if ($debug >= 6);

	$total_machines_deleted++;

        # set expire on them
        my $res = expire_machine($dbh, $dbuser, $mach_hashmap, $machine, $user_type->[0][$user_type_map->{'user_type.expire_days_mach'}]);
        if ($res != 1) { 
          warn __FILE__ .':'. __LINE__." expire_machine failed: $res\n";
          return (0, []);
        }

        if (index($user_type->[0][$user_type_map->{'user_type.flags'}], 'send_email_mach') >= 0) {
          # now send emails to everybody
          warn __FILE__ .':'. __LINE__ . " now sending emails to everybody.\n" if ($debug >= 5);

          $res = email_expire_notice_machine($dbh, $dbuser, $mach_hashmap, $machine, $user_type->[0][$user_type_map->{'user_type.expire_days_mach'}], $user);
          if ($res == 0) { 
            warn __FILE__ .':'. __LINE__." email_expire_notice_machine failed: $res\n";
            return (0, []);
          }
        } # end -- if (index...)
      } else { # if multiple users
        # this means more than one user, so we leave the outlet alone.
        warn __FILE__ .':'. __LINE__ . " Machine has more than one user, don't do anything.\n" if ($debug >= 4);
      }
    }

    my $res = delete_user_from_machine($dbh, $dbuser, $user, $mach_hashmap, $machine);
    if ($res == 0) {
      warn __FILE__ .':'. __LINE__." delete_user_from_machine failed: $res\n";
      return (0, []);
    }
  }
    
  my $users = CMU::Netdb::auth::list_users($dbh, 'netreg', "credentials.authid = '$user'");
  if (!ref $users) {
    warn __FILE__ .':'. __LINE__." list_users for $user failed: $users\n";
    return (0, []);
  }
 
  # delete user from all groups
  if (delete_user_from_all_groups($dbh, $dbuser, $user) == 0) {
    warn __FILE__ .':'. __LINE__." delete_user_from_all_groups failed!\n";
    return (0, ['memberships']);
  }
  
  # delete or disable user
  if (index($user_type->[0][$user_type_map->{'user_type.flags'}], 'disable_acct') >= 0) {
    # set suspend flag
    if (index($userflags, 'abuse') >= 0) {
      $userflags = 'abuse,suspend';
    } else {
      $userflags = 'suspend';
    }
    
    my $fields;
    
    $fields->['flags'] = $userflags;

    my $res = CMU::Netdb::auth::modify_user($dbh, 'netreg', $id, $version, $fields);
    if ($res != 1) {
      warn __FILE__ .':'. __LINE__." modify_user failed: $res\n";
      return (0, []);
    }
  } else {
    # delete user
    my ($res, $ref) = CMU::Netdb::auth::delete_user($dbh, 'netreg', $id, $version);
    if ($res != 1) {
      warn __FILE__ .':'. __LINE__." delete_user $id, $version failed\n\n", Data::Dumper->Dump([$res, $ref],['res', 'ref']);
      return (0, []);
    }
  }

  return (1, []);
}

sub delete_user_from_all_groups {
  my ($dbh, $dbuser, $user) = @_;
  my $groups = CMU::Netdb::auth::list_memberships_of_user($dbh, 'netreg', $user);
  if (!ref $groups) {
    warn __FILE__ .':'. __LINE__." list_memberships_of_users failed: $groups\n";
    return 0;
  }

  my $ghm = CMU::Netdb::helper::makemap(shift @$groups);
  
  foreach my $g (@$groups) {
    my $dfgres = CMU::Netdb::auth::delete_user_from_group($dbh, 'netreg', $user, $g->[$ghm->{'groups.id'}]);
    if ($dfgres < 0) {
      warn __FILE__ .':'. __LINE__." delete_user_from_all_groups failed: $user, user is stuck in group # $g->[$ghm->{'groups.id'}]\n";
      return 0;
    }
  }
  return 1;
}


# delete_user_from_outlet
# deletes a user from a machine
# input: database handle, authed user, user to delete, machine hashmap, machine array
# output: true/false = success/fail
sub delete_user_from_outlet {
  my ($dbh, $dbuser, $user, $outlet_hashmap, $outlet) = @_;
 
  my $outlet_id = $outlet->[$outlet_hashmap->{'outlet.id'}];
  
  my $res = CMU::Netdb::list_protections($dbh, 'netreg', 'outlet', $outlet_id);
  if (!ref $res) {
    warn __FILE__ .':'. __LINE__." list_protections failed on " . $outlet->[$outlet_hashmap->{'outlet.id'}] . " ** $res\n";
    return 0;
  }
  
  warn __FILE__ .':'. __LINE__ . Data::Dumper->Dump([$res],['prot']) if ($debug >= 7);
  
  foreach my $prot (@$res) {
    warn __FILE__ .':'. __LINE__ . Data::Dumper->Dump([$prot],['prot']) if ($debug >= 8);
    
    if (($prot->[0] eq 'user') && ($prot->[1] eq $user)) {
      my $rlevel = $prot->[3];
      my ($result, $ref) = CMU::Netdb::auth::delete_user_from_protections($dbh, 'netreg', $user, 'outlet', $outlet_id, $rlevel);
      if ($result != 1) {
        warn __FILE__ .':'. __LINE__. Data::Dumper->Dump([$result,$ref],['result','ref']) if ($debug >= 8);
        warn __FILE__ .':'. __LINE__." removing user from protections: failed: $result, $outlet_id, $rlevel, $user.\n";
        return 0;
      } 
    }
  }
  return 1;
}


# delete_user_from_machine
# deletes a user from a machine
# input: database handle, authed user, user to delete, machine hashmap, machine array
# output: true/false = success/fail
sub delete_user_from_machine {
  my ($dbh, $dbuser, $user, $mach_hashmap, $machine) = @_;
 
  my $mach_id = $machine->[$mach_hashmap->{'machine.id'}];
  
  my $res = CMU::Netdb::list_protections($dbh, 'netreg', 'machine', $mach_id);
  if (!ref $res) {
    warn __FILE__ .':'. __LINE__." list_protections failed on " . $machine->[$mach_hashmap->{'machine.id'}] . " ** $res\n";
    return 0;
  }
  
  foreach my $prot (@$res) {
    if (($prot->[0] eq 'user') && ($prot->[1] eq $user)) {
      my $rlevel = $prot->[3];
      my ($result, $ref) = CMU::Netdb::auth::delete_user_from_protections($dbh, 'netreg', $user, 'machine', $mach_id, $rlevel);
      if ($result != 1) {
        warn __FILE__ .':'. __LINE__." removing user from protections: failed: $result, $mach_id, $rlevel, $user.\n";
        return 0;
      } 
    }
  }
 
  return 1;
}

# email_expire_machine_notice
# expires a machine
# input: database handle, authed user, machine hashmap, machine array, days in the future
# output: true/false = success/fail
sub email_expire_notice_machine {
  my ($dbh, $dbuser, $mach_hashmap, $machine, $expire_in_days, $user) = @_;
 
  my $machine_id = $machine->[$mach_hashmap->{'machine.id'}];
  
  my $res = CMU::Netdb::list_protections($dbh, 'netreg', 'machine', $machine_id);
  if (!ref $res) {
    warn __FILE__ .':'. __LINE__." list_protections failed on " . $machine->[$mach_hashmap->{'machine.id'}] . " ** $res\n";
    return 0;
  }

  my $users;

  foreach my $prot (@$res) {
    if ($prot->[0] eq 'user') {
      push(@$users, $prot->[1]);
    } elsif ($prot->[0] eq 'group') {
      warn "Notifying $prot->[1] about machine ".$machine->[$mach_hashmap->{'machine.host_name'}] . " previously owned by $user\n" if ($debug >= 4);
      my $u = get_users_in_group($dbh, $dbuser, $prot->[1]);
      if ($u == 0) { 
        warn __FILE__ .':'. __LINE__." get_users_in_group failed\n";
        return 0;
      }
      if ($u == 1) {
        $u = undef;
      }
      foreach my $i (@$u) {
        push(@$users, $i);
      }
    }

  }
 
  # get only uniques.
  my %seen = (); 
  my $uniq;
  foreach my $item (@$users) {
    push(@$uniq, $item) unless $seen{$item}++;
  }

  $users = $uniq;

  my $mail_res = send_mail('machine', $machine_id, $machine->[$mach_hashmap->{'machine.host_name'}], $expire_in_days, $users, $mach_hashmap, $machine, $user);
  
  return $mail_res;
}

# email_expire_notice_outlet
# expires a machine
# input: database handle, authed user, outlet hashmap, outlet array, days in the future
# output: true/false = success/fail
sub email_expire_notice_outlet {
  my ($dbh, $dbuser, $outlet_hashmap, $outlet, $expire_in_days, $user) = @_;
 
  my $outlet_id = $outlet->[$outlet_hashmap->{'outlet.id'}];
  
  my $res = CMU::Netdb::list_protections($dbh, 'netreg', 'outlet', $outlet_id);
  if (!ref $res) {
    warn __FILE__ .':'. __LINE__." list_protections failed on " . $outlet->[$outlet_hashmap->{'outlet.id'}] . " ** $res\n";
    return 0;
  }

  my $users;

  foreach my $prot (@$res) {
    if ($prot->[0] eq 'user') {
      push(@$users, $prot->[1]);
    } elsif ($prot->[0] eq 'group') {
      warn "Notifying $prot->[1] about outlet ".$outlet->[$outlet_hashmap->{'cable.label_from'}] . "/".$outlet->[$outlet_hashmap->{'cable.label_to'}] ." previously owned by $user\n" if ($debug >= 4);
      my $u =  get_users_in_group($dbh, $dbuser, $prot->[1]);
      if ($u == 0) { 
        warn __FILE__ .':'. __LINE__." get_users_in_group failed\n";
        return 0;
      }
      if ($u == 1) {
        $u = undef;
      }
      foreach my $i (@$u) {
        push(@$users, $i);
      }
    }

  }
 
  # get only uniques.
  my %seen = (); 
  my $uniq;
  foreach my $item (@$users) {
    push(@$uniq, $item) unless $seen{$item}++;
  }

  $users = $uniq;

  my $mail_res = send_mail('outlet', $outlet_id, '', $expire_in_days, $users, $outlet_hashmap, $outlet, $user);
  
  return $mail_res;
}

# send_mail
# generalized mail mailer
# input: object (outlet/machine), id, object name, expire in days (14), array of carbon copied users (who else)
# output: 1 if good, 0 if failed.
sub send_mail {
  my ($object_type, $object_id, $object_name, $expire_in_days, $cc, $hashmap, $data, $user) = @_;
  
  my $carbon_users = join(', ', @$cc);

  my ($file, $subject);
  
  if ($object_type eq 'machine') {
    $file = 'EXPIRE_MACHINE_TEMPLATE';
    $subject = 'EXPIRE_MACHINE_SUBJECT';
  } else {
    $file = 'EXPIRE_OUTLET_TEMPLATE';
    $subject = 'EXPIRE_OUTLET_SUBJECT';
  }
 
  my ($fromRes, $from) = CMU::Netdb::config::get_multi_conf_var('netdb', 'EXPIRE_EMAIL_FROM');
  my ($ccRes, $ccalways) = CMU::Netdb::config::get_multi_conf_var('netdb', 'EXPIRE_EMAIL_CC');
  my ($fromNameRes, $fromName) = CMU::Netdb::config::get_multi_conf_var('netdb', 'EXPIRE_EMAIL_FROM_NAME');
  my ($subjRes, $subj) = CMU::Netdb::config::get_multi_conf_var('netdb', $subject);
  my ($fileRes, $file2) = CMU::Netdb::config::get_multi_conf_var('netdb', $file);
  my ($emailRes, $sendEmail) = CMU::Netdb::config::get_multi_conf_var('netdb', 'USERMAINT_SEND_EMAIL');

  open(DAT, $file2) || warn __FILE__ .':'. __LINE__." cannot open file $file\n" && return 0;
  my @data = <DAT>;
  close(DAT);
  
  my $wholefile = join('',@data);

  my %replaces = (
    '%CURRENT_DATE%' => strftime('%Y-%m-%d', localtime(time)),
    '%EXPIRE_DATE%' => strftime('%Y-%m-%d', localtime(time_machine($expire_in_days))),
    '%USER%' => "$user",
  );

  if ($object_type eq 'machine') {
    $replaces{'%HOST_NAME%'} = $data->[$hashmap->{'machine.host_name'}];
    $replaces{'%MAC_ADDR%'} = $data->[$hashmap->{'machine.mac_address'}];
  } else {
    $replaces{'%OUTLET_NUM%'} = $data->[$hashmap->{'cable.label_from'}] . ' / ' . $data->[$hashmap->{'cable.label_to'}];
    $replaces{'%OUTLET_BUILDING%'} = $data->[$hashmap->{'building.name'}];
    $replaces{'%OUTLET_ROOM%'} = $data->[$hashmap->{'cable.to_room_number'}];
  }

  warn __FILE__ .':'. __LINE__ . Data::Dumper->Dump([\%replaces, $expire_in_days], ['email macros', 'expire in days']) if ($debug >= 6);
  
  foreach my $i (keys %replaces) {
    $wholefile =~ s/$i/$replaces{$i}/g;
    $subj =~ s/$i/$replaces{$i}/g;
  }

  my $wrapped = Text::Wrap::wrap('', '', $wholefile);

  my $m = {
    'SENDER_ADDRESS' => $from,
    'FROM'           => $from,
    'SENDER_NAME'    => $fromName,
    'TO'             => join(',', @$cc),
    'CC'             => $ccalways,
    'SUBJECT'        => $subj,
    'MESSAGE'        => $wrapped,
    'X_MAILER'       => 'NetReg'
  };
 
  if ($emailRes && $sendEmail == 1) {
    my $res = CMU::Helper::SendMail::sendMail($m);
    if ($res == 1) { 
      warn __FILE__ .':'. __LINE__ ." sending mail failed!  Message was\n". Data::Dumper->Dump([$m], ['message']);
      return 0; 
    }
  } else {
    warn __FILE__ .':'. __LINE__ ." sending email not enabled!  Message was\n". Data::Dumper->Dump([$m], ['message']) if ($debug >= 5);
  }
  return 1;
}


# get_users_in_group
# returns an array of users that are in the group
# input: database handle, authed user, group name
# output: array or 0 if fail
sub get_users_in_group {
  my ($dbh, $dbuser, $group) = @_;
 
  my $where = "";
  
  my $res = CMU::Netdb::auth::list_members_of_group($dbh, 'netreg', $group, $where);
  if (!ref $res) {
    warn __FILE__ .':'. __LINE__." get_users_in_group: failure with $res\n";
    return 0;
  }

  my $hashmap = CMU::Netdb::helper::makemap(shift @$res);
  my @users;
  
  foreach my $prot (@$res) {
    my $id = $prot->[$hashmap->{'credentials.authid'}];
    push(@users, $id);
  }
 
  if ((scalar @users) < 1) {
    return 1;
  }
 
  return \@users;
}

# expire_outlet
# expires a machine
# input: database handle, authed user, machine hashmap, machine array, days in the future
# output: true/false = success/fail
sub expire_outlet {
  my ($dbh, $dbuser, $outlet_hashmap, $outlet, $expire_in_days) = @_;

  my $outlet_id = $outlet->[$outlet_hashmap->{'outlet.id'}];
  my $outlet_ver = $outlet->[$outlet_hashmap->{'outlet.version'}];

  my $expires = strftime('%Y-%m-%d', localtime(time_machine($expire_in_days)));

  my ($res, $ref) = CMU::Netdb::buildings_cables::expire_outlet($dbh, 'netreg', $outlet_id, $outlet_ver, $expires);
  if ($res != 1) { 
    warn __FILE__ .':'. __LINE__." expire_outlet failed: $res\n";
    return 0; 
  }

  return 1;
}


# expire_machine
# expires a machine
# input: database handle, authed user, machine hashmap, machine array, days in the future
# output: true/false = success/fail
sub expire_machine {
  my ($dbh, $dbuser, $mach_hashmap, $machine, $expire_in_days) = @_;

  my $mach_id = $machine->[$mach_hashmap->{'machine.id'}];
  my $mach_ver = $machine->[$mach_hashmap->{'machine.version'}];

  my $expires = strftime('%Y-%m-%d', localtime(time_machine($expire_in_days)));
  
  warn __FILE__ .':'. __LINE__ . " ##### expire_in_days: $expire_in_days - expires: $expires\n\n" if ($debug >= 6);

  my ($res, $ref) = CMU::Netdb::machines_subnets::expire_machine($dbh, 'netreg', $mach_id, $mach_ver, $expires);

  if ($res != 1) { 
    warn __FILE__ .':'. __LINE__." expire_machine failed: $res\n";
    return 0; 
  }

  return 1;
}

# time_machine
# returns an integer of time from the epoch currently plus days
# input: days in the future
# output: integer of time
sub time_machine {
  my ($days) = @_;

  return time() + 86400 * $days;
}

# add_cred
# uses netreg api to add a credential to a user
# input:  database handle, auth user, hash of fields
# output: 0 if failed, 1 if true
#sub add_cred {
#  my ($dbh, $dbuser, $fields) = @_;
#
#  my ($ret, $ref) = CMU::Netdb::auth::add_credentials($dbh, $dbuser, $fields);
#
#  if ($ret != 1) {
#    warn "add_cred: failed, $ret.";
#    return 0;
#  }
#
#  return 1;
#}

# add_user
# uses netreg api to add a user
# input:  database handle, authorized user, hash of fields
# output: either an insert id (positive integer) or 0 if it failed.
#sub add_user {
#  my ($dbh, $dbuser, $fields) = @_;
#
# my ($ret, $ref) = CMU::Netdb::auth::add_user($dbh, $dbuser, $fields);
#  if ($ret != 1) {
#    warn "add_user: failed, $ret.";
#    return 0;
#  }
#
#  return $$ref{insertID};
#}

# ut_delete_user
# deletes a user
# input: database handle, authorized user, table id
# output: 1 if completed, 0 if failed
sub ut_delete_user {
  my ($dbh, $dbuser, $insertid) = @_;
  my $version;

  my $where = "users.id = $insertid";
  my $result = CMU::Netdb::auth::list_users($dbh, $dbuser, $where);
  
  if (!ref $result) {
    warn __FILE__ .':'. __LINE__." delete_user: failed list_users: $result\n";
    return 0;
  }

  my $hashmap = CMU::Netdb::helper::makemap(shift @$result);

  $version = $result->[0]->[$hashmap->{'users.version'}];

  $result = CMU::Netdb::auth::delete_user($dbh, 'netreg', $insertid, $version);

  if ($result < 1) { 
    warn __FILE__ .':'. __LINE__." delete_user: failed deleting user $insertid with version of $version, result is $result\n";
    return 0;
  }
    
  warn __FILE__ .':'. __LINE__." delete_user: Deleted $insertid with version of $version\n";

  return 1;
}

# cred_exists
# checks to see if there is an existing credential
# input: database handle, credential
# output: users.id if exists, 0 if not exists, -1 if error
sub cred_exists {
  my ($dbh, $dbuser, $cred) = @_;

  my $where = "credentials.authid = \'$cred\'";
  my $result = CMU::Netdb::auth::list_users($dbh, $dbuser, $where);

  return -1 if (!ref $result);

  my %map = %{CMU::Netdb::helper::makemap(shift @$result)};

  if (@$result) {
    return $result->[0][$map{'users.id'}];
  } else {
    return 0;
  }
}

# list_user_types
# gets the user_types
# input:  database handle, database user
# output: hash of names to numbers
sub list_user_types {
  my ($dbh, $dbuser, $where) = @_;

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  my $result = CMU::Netdb::primitives::list($dbh, $dbuser, 'user_type', \@CMU::Netdb::structure::user_type_fields, $where);

  if (!ref $result) {
    return $result;
  }

  unshift @$result, \@CMU::Netdb::structure::user_type_fields;
  return $result
}

# get_user_types
# gets one specific user_type
# input:  database handle, database user, where clause
# output: hash of names to numbers
sub get_user_types {
  my ($dbh, $dbuser, $where) = @_;

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  my $result = CMU::Netdb::primitives::get($dbh, $dbuser, 'user_type', \@CMU::Netdb::structure::user_type_fields, $where);

  if (!ref $result) {
    return $result;
  }

  unshift @$result, \@CMU::Netdb::structure::user_type_fields;
  return $result
}

# add_user_type
# adds a user type if it's not already existing
# input:  database handle, hash of data
# output: anything but 1 for failure, 1 for success
sub add_user_type {
  my ($dbh, $dbuser, $data) = @_;
  my ($user, $flags);

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $user = CMU::Netdb::valid('user_type.name', $data->{'name'}, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  $user = CMU::Netdb::valid('user_type.expire_days_mach', $data->{'m_d_e'}, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  $user = CMU::Netdb::valid('user_type.expire_days_outlet', $data->{'o_d_e'}, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  if ($data->{'m_m'} eq 1) { $flags .= 'send_email_mach '; }
  if ($data->{'o_m'} eq 1) { $flags .= 'send_email_outlet '; }
  if ($data->{'disable'} eq 1) { $flags .= 'disable_acct'; }

  #$user = CMU::Netdb::valid('user_type.flags', $flags, $dbuser, 0, $dbh);
  #return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  my %fields = (
    'user_type.name' => $data->{'name'},
    'user_type.expire_days_mach' => $data->{'m_d_e'},
    'user_type.expire_days_outlet' => $data->{'o_d_e'},
    'user_type.flags' => join(',', split(' ', $flags))
  );

  my $res = CMU::Netdb::primitives::add($dbh, $dbuser, 'user_type', \%fields);
  if ($res < 1) {
    return ($res, []);
  }
  my %warns = ('insertID' => $CMU::Netdb::primitives::db_insertid);

  my @profiles = ('admin_default_add');
  foreach my $prot_profile (@profiles) {
    my ($ARes, $AErrf) = CMU::Netdb::apply_prot_profile
      ($dbh, $dbuser, $prot_profile, 'user_type', $warns{insertID}, '', {});

    if ($ARes == 2 || $ARes < 0) {
      my $Pr = ($ARes < 0 ? "Total" : "Partial");
      warn __FILE__, ':', __LINE__, ' :>'.
	"$Pr failure adding protections entries for ".
	  "user_type/$warns{insertID}: ".join(',', @$AErrf)."\n";
    }
  }

  return ($res, \%warns);
}

# modify_user_type
# modifies an existing user type
# input:  database handle, hash of data
# output: 0 for failure, 1 for success
sub modify_user_type {
  my ($dbh, $dbuser, $id, $version, $fields) = @_;

  my ($user, $flags);
  
  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid('user_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid('user_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);

  $user = CMU::Netdb::valid('user_type.name', $fields->{'name'}, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  $user = CMU::Netdb::valid('user_type.expire_days_mach', $fields->{'m_d_e'}, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  $user = CMU::Netdb::valid('user_type.expire_days_outlet', $fields->{'o_d_e'}, $dbuser, 0, $dbh);
  return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  if ($fields->{'m_m'} eq 1) { $flags .= 'send_email_mach '; }
  if ($fields->{'o_m'} eq 1) { $flags .= 'send_email_outlet '; }
  if ($fields->{'disable'} eq 1) { $flags .= 'disable_acct'; }

  #$user = CMU::Netdb::valid('user_type.flags', $flags, $dbuser, 0, $dbh);
  #return CMU::Netdb::getError($user) if (CMU::Netdb::getError($user) != 1);

  my %newfields = (
    'name' => $fields->{'name'},
    'expire_days_mach' => $fields->{'m_d_e'},
    'expire_days_outlet' => $fields->{'o_d_e'},
    'flags' => join(',', split(' ', $flags))
  );

  my $result = CMU::Netdb::primitives::modify($dbh, $dbuser, 'user_type', $id, $version, \%newfields);

  if ($result == 0) {
    # An error occurred
    my $query = "SELECT id FROM user_type WHERE id='$id' AND version='$version'";
    my $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::modify_user_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::modify_user_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($CMU::Netdb::errcodes{"ERROR"}, ['unknown']);
    }
  }

  return ($result, []);
}

sub delete_user_type {
  my ($dbh, $dbuser, $id, $version) = @_;

  $dbuser = CMU::Netdb::valid('credentials.authid', $dbuser, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($dbuser), ['dbuser']) if (CMU::Netdb::getError($dbuser) != 1);

  $id = CMU::Netdb::valid('user_type.id', $id, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($id), ['id']) if (CMU::Netdb::getError($id) != 1);

  $version = CMU::Netdb::valid('user_type.version', $version, $dbuser, 0, $dbh);
  return (CMU::Netdb::getError($version), ['version']) if (CMU::Netdb::getError($version) != 1);

  my ($result, $dref) = CMU::Netdb::primitives::delete($dbh, $dbuser, 'user_type', $id, $version);

  if ($result != 1) {
    # An error occurred
    my $query = "SELECT id FROM user_type WHERE id='$id' AND version='$version'";
    my $sth = $dbh->prepare($query);
    warn  __FILE__, ':', __LINE__, ' :>'.
      "CMU::Netdb::machines_subnets::delete_user_type: $query\n" if ($debug >= 2);
    $sth->execute();
    if ($sth->rows() == 0) {
      warn  __FILE__, ':', __LINE__, ' :>'.
	"CMU::Netdb::machines_subnets::delete_user_type: id/version were stale\n" if ($debug);
      return ($CMU::Netdb::errcodes{"ESTALE"}, ['stale']);
    } else {
      return ($result, $dref);
    }
  }
  
  return ($result, []);
}

# userAddDelete - Does some magic and gives you what would need to be deleted and added to the second array
# input: two hashes
# output: two arrays, add, and delete
sub userAddDelete {
  my ($incoming, $netreg, $netregUIDs) = @_;

  my @add;
  my @delete;

  my $counter = 0;
  foreach my $user (sort keys %$incoming) {
    warn __FILE__ .':'. __LINE__ . " Processing $user\n" if ($debug >= 8);
    my @useridlist = split /,/, $user;
    my $uid;

    $counter++;
    warn __FILE__ .':'. __LINE__ ." Processed $counter users\n" 
      if ($debug >= 2 && $counter % 1000 == 0);

    # Need to find a uid to lookup the existing credential list
    foreach (@useridlist) {
      if (exists $netregUIDs->{byuser}{$_}) {
	$uid = $netregUIDs->{byuser}{$useridlist[0]};
	# Found a uid, stop looking
	warn __FILE__ .':'. __LINE__ . " Found uid $uid\n" if ($debug >= 9);
	last;
      }
    }


    if (!$uid) {
      # No matching userids, add the list
      warn __FILE__ .':'. __LINE__ . " No existing user, queueing $user\n" if ($debug >= 9);
      push @add, [$useridlist[0], $user];
      next;

    } else {

      # At least one userid exists.  Check the list
      if ($user eq join(',', sort(@{$netregUIDs->{byuid}{$uid}}))) {
	# Userid list is the same, nothing to do
	warn __FILE__ .':'. __LINE__ . " User exists as is, skipping\n" if ($debug >= 9);
	foreach my $existing (@{$netregUIDs->{byuid}{$uid}}) {
	  # We've processed this userid fully now, delete it from the list of existing users;
	  delete $netreg->{$existing};
	}
	next;
      }

      # Non exact match...  Now we have to compare in detail.

      # Look for userids to add
      foreach my $userid (@useridlist) {
	if (grep(/^$userid$/, @{$netregUIDs->{byuid}{$uid}})) {
	  # This userid exists on this user, nothing to do
	  warn __FILE__ .':'. __LINE__ . " Userid exists on user, skipping\n" if ($debug >= 9);
	} else {
	  # Need to add this userid, just add the list and move on
	  warn __FILE__ .':'. __LINE__ . " Userid missing from user, queueing\n" if ($debug >= 8);
	  push @add, [$useridlist[0], $user];
	  last;
	}
      }

      # Look for userids to delete
      foreach my $existing (@{$netregUIDs->{byuid}{$uid}}) {
	if (grep(/^$existing$/, @useridlist)) {
	  # This userid still exists on this user, nothing to do
	} else {
	  # Need to delete this userid
	  push @delete, $existing;
	}

	# We've processed this userid fully now, delete it from the list of existing users;
	delete $netreg->{$existing};

      }


    }



  }


  warn __FILE__ .':'. __LINE__ ." Done processing $counter users\n";

  # Anything left in $netreg should be deleted
  push @delete, keys %$netreg;

  return (\@add, \@delete);

}

1;
