#!/usr/local/bin/perl5 
#
# CMU::Pstatus
#  Handles operations with NetReg
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

package CMU::Helper::Pstatus;

use strict;
use vars qw (@ISA @EXPORT $debug $type);

use Data::Dumper;

{
  no strict;
  $VERSION = '0.01';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     pstatus
	     tftp_queue
	    );

$debug = 0;
$type = {
	 'ps'      => 1,
	 'monTrap' => 2,
	 'zephyr'  => 3,
	 'stderr'  => 4,
	 'stdout'  => 5
	};

sub pstatus{
  my ($state_array, $msg, $class, $inst, $user) = @_;
  my ($state);

  warn __FILE__ . ":" . __LINE__ . ": Entering pstatus with \n" . Data::Dumper->Dump([$state_array, $msg, $class, $inst, $user],[qw(state_array msg class inst user)]) . "\n" if ($debug); 
  return(-1, [ "invalid state array" ]) if ((! defined $state_array) || (ref($state_array) ne 'ARRAY'));

  
  foreach $state (@$state_array) {

    if ($state == $type->{'ps'}) {
      warn __FILE__ . ":" . __LINE__ . ": Processing ps change request\n" if ($debug);
      $0 = (split(/\s+/,$0))[0] . " $msg";
      warn __FILE__ . ":" . __LINE__ . ": \$0 is now \"$0\"\n" if ($debug);
    }
    if ($state == $type->{'monTrap'}) {
      warn __FILE__ . ":" . __LINE__ . ": monTrap not implemented\n" if ($debug);
    }
    if ($state == $type->{'zephyr'}) {
      system ("zwrite -d " . (defined $class ? "-c $class " : "") . (defined $inst ? "-i $inst " : "") . (defined $user ? "$user " : "") . "-m \"$msg\" > /dev/null 2>&1");
    }
    if ($state == $type->{'stderr'}) {
      print STDERR "$msg\n";
    }
    if ($state == $type->{'stdout'}) {
      print "$msg\n";
    }
  }
  return(1, undef);

}

# ENDOFPSTATUS


sub tftp_queue{
  my ($pgm, $qlen) = @_;
  my ($mesg, $ahead);
  my ($procs, $pcount, $qpos, $enqueued);

  $mesg = [ split(/\s+/, $0) ];
  shift(@$mesg);
  $mesg = join(' ', @$mesg);
  $qpos = 0;
  $enqueued = 0;

  pstatus([$type->{'ps'}], $mesg . " : tftp queued $qpos");
  
 Outer:
  while (1) {
    $ahead = 0;
    $procs = get_procs();
    
    foreach (@$procs) {
      warn __FILE__ . ":" . __LINE__ . ": checking ". join ("<|>", $_) . "\n" if ($debug);

      if (($_->[0] =~ /$pgm/) && ($_->[0] =~ /tftp/) && ($$ != $_->[1])) {
	$_->[0]  =~ /(\d+)\s*$/;
	if (defined $1) {
	  if ($enqueued == 0) {
	    $qpos = $1 + 1 if ($1 >= $qpos);
	  } else {
	    if ($1 == $qpos) {
	      if ($$ > $_->[1]) {
		$enqueued = 0;
		sleep(1);
		next Outer;
	      }
	    } else {
	      $ahead++ if ($1 < $qpos);
	    }
	  }
	}
      }
    } 
    $qpos = 1 if ($qpos == 0);
    
    warn __FILE__ . ":" . __LINE__ . ": Setting queue position to $qpos\n" if ($debug);
    pstatus([$type->{'ps'}], $mesg . " : tftp queued $qpos");
    
    if ($enqueued == 0) {
      $enqueued = 1;
      next;
    }
    sleep(1);
    last if ($ahead < $qlen);
  }
  pstatus([$type->{'ps'}], $mesg . " : now serving tftp number $qpos");
}

sub get_procs {
  my (@procs, $proc, $procinfo, $plist);
  my ($pid, $cmd);

  $plist = [];

#  open(PROCS, '/bin/ls -1d /proc/[1-9]* |');
  open(PROCS, '/bin/ps axwwo pid,args |');
  @procs = ( <PROCS> );
  close(PROCS);
  warn __FILE__ . ":" . __LINE__ . ": Looping\n" if ($debug > 3);
  foreach $proc (@procs) {
    chomp $proc;
    $proc =~ s/^\s+//;
    ($pid, $cmd) = split(/\s+/, $proc,2);
    push(@$plist, [$cmd, $pid]);
  }

  return($plist);
}


1;
