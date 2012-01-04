#   -*- perl -*-
#
# CMU::Errors
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
# $Id: Errors.pm,v 1.7 2008/03/27 19:42:33 vitroth Exp $
#
# $Log: Errors.pm,v $
# Revision 1.7  2008/03/27 19:42:33  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.6.24.1  2007/10/11 20:59:38  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.6.22.1  2007/09/20 18:43:03  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.1.1.1  2004/11/17 18:12:41  kcmiller
#
#
# Revision 1.6  2002/09/07 11:59:55  kevinm
# * Fix the syslog error
#
# Revision 1.5  2002/08/12 13:16:33  kevinm
# * A bit of memory management cleanup
#
# Revision 1.4  2002/07/18 03:47:29  kevinm
# * unix/inet sock type parameter for syslog added
#
# Revision 1.3  2002/07/10 12:24:32  kevinm
# * Return values from _Error_Queue functions
#
# Revision 1.2  2002/04/05 18:00:38  kevinm
# * Fixed a few delete -> undef issues
#
# Revision 1.1  2002/04/02 03:56:47  kevinm
# * Initial checkin of general error reporting module
#
#
#

package CMU::Errors;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK);

{
  no strict;
  $VERSION = '0.01';
}

use Exporter;
use Sys::Syslog qw(:DEFAULT setlogsock); 
@ISA = qw(Exporter);

@EXPORT = qw/new Record_Error Run SetVar GetVar/;

sub new {
  my ($name) = @_;
  my $self = {};
  bless $self;
  $self->{_ErrMsg} = {};
  $self->{_ErrQueue} = ();
  $self->{ErrMsgID} = 0;
  $self->{Variables} = {};
  $self->{Name} = $name;

  return $self;
}

##
## 
sub Record_Error {
  my ($self, $Crit, $Message) = @_;

  my $Now = time();

  # Allocate a unique message ID
  my $MsgId = $self->{ErrMsgID}++;
  $self->{_ErrMsg}->{$MsgId} = {'Crit' => $Crit,
				'Time' => $Now,
				'Msg' => $Message};
  
  push(@{$self->{_ErrQueue}}, $MsgId);

  $self->_Run_ErrorQueue();
  return 1;
}

## Just call the internal queue run function
sub Run {
  my ($self) = @_;
  return $self->_Run_ErrorQueue();
}

## Set a variable in our error variable space
sub SetVar {
  my ($self, $Key, $Value) = @_;
  $self->{Variables}->{$Key} = $Value;
  return 1;
}

## Returns a variable from our error variable space
sub GetVar {
  my ($self, $Key) = @_;
  return $self->{Variables}->{$Key};
}

## Run through our error queues, and send off any error reports
## as needed.
## We can log through:
##   - Email (Log_Email_Address, Log_Email_Interval, Log_Email_Level)
##   - Syslog
##   - Stderr
## This is NOT THREAD SAFE. In particular for threading we should record
## the ErrMsgID coming in and make all the functions operate with an
## upper bound (instead of assuming that no additional error messages
## can arrive while we're running)
##
sub _Run_ErrorQueue {
  my ($self) = @_;

  $self->_ErrorQueue_Init();

  my $MinMsgID = $self->{ErrMsgID};
  my $Now = time();

  # EMail logging
  if ($self->GetVar('__log_email_status') eq 'on') {
    my $MaxID = $self->GetVar('__log_email_maxid');
    
    my $EmailAddress = $self->GetVar('Log_Email_Address');
    if ($EmailAddress eq '') {
      $MaxID = $self->{ErrMsgID};
    }else{
      my $EmailInterval = $self->GetVar('Log_Email_Interval');
      
      if ($EmailInterval eq '') {
        # If no interval is set, default to every 30 minutes
        $EmailInterval = 30*60;
        $self->SetVar('Log_Email_Interval', $EmailInterval);
      }
      
      my $EmailLevel = $self->GetVar('Log_Email_Level');
      
      if ($EmailLevel eq '') {
        # if no interval is set, default to "WARN"
        $EmailLevel = 'WARN';
        $self->SetVar('Log_Email_Level', $EmailLevel);
      }
      
      my $LastEmailed = $self->GetVar('__log_email_last');
      $LastEmailed = 0 if ($LastEmailed eq '');
      if ($LastEmailed + $EmailInterval < $Now) {
        my $Ret = $self->_ErrorQueue_Report($MaxID, $EmailLevel, 
					    \&_Error_Report_Email,
                                            { 'Address' => $EmailAddress });
        warn "_ErrorQueue_Report (Email) returned: $Ret" if ($Ret != 1);
        $MaxID = $self->{ErrMsgID} if ($Ret == 1);
      }
    }
    $self->SetVar('__log_syslog_maxid', $MaxID);
    
    $MinMsgID = $MaxID if ($MaxID < $MinMsgID);
  }
  
  # Syslog logging
  if ($self->GetVar('__log_syslog_status') eq 'on') {
    my $MaxID = $self->GetVar('__log_syslog_maxid');
    my $Ret = $self->_ErrorQueue_Report($MaxID, 'DEBUG', 
					\&_Error_Report_Syslog);
    
    warn "_ErrorQueue_Report (Syslog) returned: $Ret" if ($Ret != 1);
    $MaxID = $self->{ErrMsgID} if ($Ret == 1);
    $self->SetVar('__log_syslog_maxid', $MaxID);
    
    # This could never happen. But we'll leave it here anyway
    $MinMsgID = $MaxID if ($MaxID < $MinMsgID);
  }
  
  # Stderr logging
  if ($self->GetVar('__log_stderr_status') eq 'on') {
    # Stderr will report errors as quickly as possible
    my $MaxID = $self->GetVar('__log_email_maxid');
    my $Ret = $self->_ErrorQueue_Report($MaxID, 'DEBUG', 
					\&_Error_Report_Stderr);
    warn "_ErrorQueue_Report (Stderr) returned: $Ret" if ($Ret != 1);
    
    $MaxID = $self->{ErrMsgID} if ($Ret == 1);
    
    $self->SetVar('__log_email_maxid', $MaxID);
    
    # This could never happen. But we'll leave it here anyway
    $MinMsgID = $MaxID if ($MaxID < $MinMsgID);
  }
  
  ## Queue Pruning
  my $LastPruned = $self->GetVar('__log_prunelast');
  $LastPruned = '0' if ($LastPruned eq '');
  return 1 if ($Now + 60 > $LastPruned);
  
  $self->SetVar('__log_prunelast', $Now);
  # Take MinMsgID and remove all messages IDs less than MinMsgID ==>
  # these messages have already been reported
  if ($MinMsgID == $self->{ErrMsgID}) {
    # Special case -- all messages everywhere are reported
    delete $self->{_ErrMsg};
    $self->{_ErrMsg} = {};
    
    delete $self->{_ErrQueue};
    $self->{_ErrQueue} = ();
  }else{
    ## Need to keep some messages around somewhere
    foreach my $msgid (keys %{$self->{_ErrMsg}}) {
      delete $self->{_ErrMsg}->{$msgid}
      if ($msgid < $MinMsgID);
    }
    my $EQ = $self->_ErrorQueue_Prune($MinMsgID, $self->{_ErrQueue});
    delete $self->{_ErrQueue};
    $self->{_ErrQueue} = $EQ;
  }
  return 1;
}

## Prune off reference to MsgIDs less than MinMsgID, which is
## determined to be the global minimum message ID still in use
sub _ErrorQueue_Prune {
  my ($MinMsgID, $rQueue) = @_;

  my @Needed = grep { $_ >= $MinMsgID } @$rQueue;
  undef $rQueue;
  return \@Needed;
}

## Go through all the pool queues and the global queue, find
## messages that haven't been reported, and call the pool
## specific reporting function on them
sub _ErrorQueue_Report {
  my ($self, $MinID, $Crit, $Func, $UserData) = @_;
  
  my %Levels = ('CRIT' => 1,
                'ERR' => 2,
                'WARNING' => 3,
                'INFO' => 4,
                'DEBUG' => 5);

  my @Messages;
  foreach my $ID (@{$self->{_ErrQueue}}) {
    if ($ID >= $MinID &&
	$Levels{$self->{_ErrMsg}->{$ID}->{Crit}} 
	<= $Levels{$Crit}) {
      push(@Messages, $ID);
    }
  }
  return $Func->($self, \@Messages, $UserData);
}


sub _Error_Report_Syslog {
  my ($self, $rMessages) = @_;

  foreach my $MessID (sort {$a <=> $b} @$rMessages) {
    my $Crit = $self->{_ErrMsg}->{$MessID}->{Crit};
    my $Msg = $self->{_ErrMsg}->{$MessID}->{Msg};
    print STDERR "Logging to syslog with crit $Crit, $Msg\n";
    next if $Msg eq '' || $Crit eq '';
    syslog ($Crit, $Msg); 
  }
  return 1;
}

sub _Error_Report_Stderr {
  my ($self, $rMessages) = @_;
  
  # Print the messages in order
  foreach my $MessID (sort {$a <=> $b} @$rMessages) {
    my $PrTime = localtime($self->{_ErrMsg}->{$MessID}->{Time});
    my $Crit = $self->{_ErrMsg}->{$MessID}->{Crit};
    my $Msg = $self->{_ErrMsg}->{$MessID}->{Msg};
    print STDERR "$PrTime:$Crit:$Msg\n";
  }  
  return 1;
}

sub _Error_Report_Email {
  my ($self, $rMessages, $UserData) = @_;
  
  return 0 if ($#$rMessages == -1);
  my %Messages;
  foreach my $MessID (sort {$a <=> $b} @$rMessages) {
    my $PrTime = localtime($self->{_ErrMsg}->{$MessID}->{Time});
    my $Crit = $self->{_ErrMsg}->{$MessID}->{Crit};
    my $Msg = $self->{_ErrMsg}->{$MessID}->{Msg};
    $Messages{$Crit} .= "$PrTime:$Msg\n";
  }
  
  my $Msg;
  foreach my $K (keys %Messages) {
    $Msg .= "---------------------------------------------------------\n".
      "Criticality level: $K\n";
    $Msg .= $Messages{$K}.
      "---------------------------------------------------------\n";
  }
  my $HN = `hostname`;
  chomp($HN);
  
  return _send_mail($Msg, $UserData->{'Address'}, 
	     '"Error Reporting" <root@'.$HN.'>', 
	     'Error Report');
}

sub _send_mail {
  my ($Message, $To, $From, $Subject) = @_;

  my $arpadate = &_ArpaDate();
  open(MAIL, "|/usr/lib/sendmail $To")
    || warn "Cannot open sendmail.\n";
  print MAIL "X-Mailer: CMU::Errors\n";
  print MAIL "From: $From\n";
  print MAIL "To: Errors <$To>\n";
  print MAIL "Date: $arpadate\n";
  print MAIL "Subject: $Subject\n\n";
  print MAIL $Message;
  close(MAIL);
  return 1;
}

sub _ArpaDate {
  my($date, @l, @g, $zone, $zoneflg);

  # Fetch date, time
  #
  $date = ctime(time);
  @l = localtime(time);
  @g = gmtime(time);

  # Time zone
  #
  $zone = $l[2] - $g[2];
  $zoneflg = '+';
  if ($zone < 0) {
    $zoneflg = '-';
    $zone = -$zone;
  }

  # Create date string
  #
  $date = substr($date,0,3).",". #  Day
    substr($date,7,3).          # Date
      substr($date,3,4).        # Month
        substr($date,19,5).     # Year
          substr($date,10,9).   # Time
            " $zoneflg".        # Zone direction
              sprintf("%02d",$zone). # Zone offset
                "00";

  return $date;
}


## Perform basic enabling/disabling based on management
## updates
sub _ErrorQueue_Init {
  my ($self) = @_;

  ## See if we need to initialize syslog, etc.
  my $ReqVal = $self->GetVar('Log_Syslog');
  my $CurVal = $self->GetVar('__log_syslog_status');
  if ($CurVal ne $ReqVal) {
    if ($CurVal eq 'on' && $ReqVal ne 'on') {
      ## Disable syslog logging.
      $self->SetVar('__log_syslog_status', $ReqVal);
      closelog();
    }elsif($CurVal ne 'on' && $ReqVal eq 'on') {
      ## Enable syslog logging.
      my $Fac = 'local4';
      $Fac = $self->GetVar('Log_Syslog_Facility')
	if ($self->GetVar('Log_Syslog_Facility') ne '');
      my $LogSock = '';
      $LogSock = $self->GetVar('Log_Syslog_LogSock')
        if ($self->GetVar('Log_Syslog_LogSock') ne '');
     
      setlogsock($LogSock) if ($LogSock ne ''); 
      print STDERR "Calling openlog with $self->{Name}, pid, $Fac\n";
      openlog($self->{Name}, 'pid', $Fac);
      $self->SetVar('__log_syslog_status', 'on');
      $self->SetVar('__log_syslog_maxid', $self->{ErrMsgID}-1);
    }
  }

  ## See about initializing email logging
  $ReqVal = $self->GetVar('Log_Email');
  $CurVal = $self->GetVar('__log_email_status');
  if ($CurVal ne $ReqVal) {
    if ($CurVal eq 'on' && $ReqVal ne 'on') {
      ## Disable email logging.
      $self->SetVar('__log_email_status', $ReqVal);

    }elsif($CurVal ne 'on' && $ReqVal eq 'on') {
      ## Enable email logging.
      $self->SetVar('__log_email_status', 'on');
      $self->SetVar('__log_email_maxid',
                    $self->{ErrMsgID}-1);
    }
  }

  ## See about initializing stderr logging
  $ReqVal = $self->GetVar('Log_Stderr');
  $CurVal = $self->GetVar('__log_stderr_status');
  if ($CurVal ne $ReqVal) {
    if ($CurVal eq 'on' && $ReqVal ne 'on') {
      ## Disable stderr logging.
      $self->SetVar('__log_stderr_status', $ReqVal);

    }elsif($CurVal ne 'on' && $ReqVal eq 'on') {
      ## Enable stderr logging.
      $self->SetVar('__log_stderr_status', 'on');
      $self->SetVar('__log_stderr_maxid',
                    $self->{ErrMsgID}-1);
    }
  }
  return 1;
}

1;

__END__

=head1 NAME

  CMU::Errors - General error reporting system

=head1 SYNOPSIS

  use CMU::Errors;

=head1 DESCRIPTION

C<CMU::Errors> provides a general interface for reporting error 
conditions via one of several means. The currently supported
methods include stderr, syslog, and email.

=head1 CONSTRUCTOR

=over 4

=item new( [ARGS] )

  Creates a new error object.

=back

=head1 METHODS

=over 4

=item Run()

=item Record_Error($Criticality, $Message)

Reports an error of criticality $Criticality. The error should be
included as $Message. A timestamp is attached to the message. The
valid criticality levels are: CRIT, ERR, WARNING, INFO, DEBUG.

=item SetVar($Key, $Value)

Sets the value of $Key to value $Value.

=item GetVar($Key)

Gets the value of $Key.

=back

=head1 ERROR-SPECIFIC VARIABLES

=head1 AUTHOR

Kevin Miller; Carnegie Mellon University.

=head1 COPYRIGHT

Copyright (c) 2002 Carnegie Mellon University. All rights reserved.
See the copyright statement of CMU NetReg/NetMon for more details
(http://www.net.cmu.edu/netreg).

=cut






