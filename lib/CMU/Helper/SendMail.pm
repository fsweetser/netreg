package CMU::Helper::SendMail;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug);

use POSIX qw(ctime);
use Data::Dumper;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(sendMail setDebug);

$debug = 0;

my %ERRCODES = ('ERROR' => 0,
		'ENOTO' => -1,
		'ENOFROM' => -2,
		'ENOSUBJECT' => -3,
		'ENOMSG' => -4,
		'EINVALID' => -5,
		'ESENDMAIL' => -6);

my %ERRMSG = ('0' => 'Unknown Error',
	      '-1' => 'Insufficient Argument (ENOTO)',
	      '-2' => 'Insufficient Argument (ENOFROM)',
	      '-3' => 'Insufficient Argument (ENOSUBJECT)',
	      '-4' => 'Insufficient Argument (ENOMSG)',
	      '-5' => 'Data Format: Invalid characters',
	      '-6' => 'SendMail Error:');

## sendMail
## MAILER    /usr/sbin/sendmail
## SENDER_ADDRESS
## SENDER_NAME
## ADMIN_ADDRESS
## ADMIN_NAME
## TO
## CC
## SUBJECT
## MESSAGE
## REPLY_TO
## RETURN_PATH
## X_MAILER
sub sendMail {
    my ($rMailArgs) = @_;

    my ($now, $date);

    $now = time();
    $date = arpaDate();

    $rMailArgs->{MAILER} = '/usr/sbin/sendmail' if (! defined $rMailArgs->{MAILER});

    if ($rMailArgs->{TO} eq "") {
	if ($rMailArgs->{ADMIN_ADDRESS} ne "") {
	    $rMailArgs->{TO} = $rMailArgs->{ADMIN_ADDRESS} ;
	    return ($ERRCODES{'EINVALID'}, {'err' => $ERRMSG{$ERRCODES{'EINVALID'}},
					    'field' => "ADMIN_ADDRESS"})
		if ($rMailArgs->{TO} eq '');
	}
    } else {
	$rMailArgs->{TO} = exec_cleanse($rMailArgs->{TO});
	return ($ERRCODES{'EINVALID'}, {'err' => $ERRMSG{$ERRCODES{'EINVALID'}},
					'field' => "TO"})
	    if ($rMailArgs->{TO} eq '');
    }

    return ($ERRCODES{'ENOTO'}, {'err' => $ERRMSG{$ERRCODES{'ENOTO'}}})
	if ($rMailArgs->{TO} eq '');

    if ($rMailArgs->{CC} ne '') {
	$rMailArgs->{CC} = exec_cleanse($rMailArgs->{CC});
	return ($ERRCODES{'EINVALID'}, {'err' => $ERRMSG{$ERRCODES{'EINVALID'}},
					'field' => "CC"})
	    if ($rMailArgs->{CC} eq '');
    }

    if ($rMailArgs->{RETURN_PATH} ne '') {
	$rMailArgs->{RETURN_PATH} = exec_cleanse($rMailArgs->{RETURN_PATH});
	return ($ERRCODES{'EINVALID'}, {'err' => $ERRMSG{$ERRCODES{'EINVALID'}},
					'field' => "RETURN_PATH"})
	    if ($rMailArgs->{RETURN_PATH} eq '');

	$rMailArgs->{RETURN_PATH} = "-f $rMailArgs->{RETURN_PATH}";
    }

    if ($rMailArgs->{REPLY_TO} ne '') {
	$rMailArgs->{REPLY_TO} = exec_cleanse($rMailArgs->{REPLY_TO});
	return ($ERRCODES{'EINVALID'}, {'err' => $ERRMSG{$ERRCODES{'EINVALID'}},
					'field' => "REPLY_TO"})
	    if ($rMailArgs->{REPLY_TO} eq '');
    }

    print Dumper($rMailArgs)
	if ($debug > 10);

    unless (open(MAIL, "|$rMailArgs->{MAILER} $rMailArgs->{RETURN_PATH} -t  ")) {
	warn "Cannot open $rMailArgs->{MAILER}.\n";
	return($ERRCODES{'ESENDMAIL'}, {'err' => $ERRMSG{$ERRCODES{'ESENDMAIL'}}});
    }

    print  	"X-Mailer: $rMailArgs->{X_MAILER}\n".
		"Reply-To: $rMailArgs->{REPLY_TO}\n".
		"Errors-To: $rMailArgs->{REPLY_TO}\n".
		"From:  $rMailArgs->{FROM}\n".
		"To: $rMailArgs->{TO}\n" if ($debug >= 3);

    print MAIL 	"X-Mailer: $rMailArgs->{X_MAILER}\n".
		"Reply-To: $rMailArgs->{REPLY_TO}\n".
		"Errors-To: $rMailArgs->{REPLY_TO}\n".
		"From:  $rMailArgs->{FROM}\n".
		"To: $rMailArgs->{TO}\n";

    print  "CC: $rMailArgs->{CC}\n"
	if (defined $rMailArgs->{CC} && $rMailArgs->{CC} ne '' && $debug >= 3);

    print MAIL "CC: $rMailArgs->{CC}\n"
	if (defined $rMailArgs->{CC} && $rMailArgs->{CC} ne '');

    print  	"Date: $date\n".
		"Subject: $rMailArgs->{SUBJECT}\n\n".
		"$rMailArgs->{MESSAGE}\n" if ($debug >= 3);

    print MAIL 	"Date: $date\n".
		"Subject: $rMailArgs->{SUBJECT}\n\n".
		"$rMailArgs->{MESSAGE}\n";

    close(MAIL);

    return (1,{});
}

sub setDebug {
    my ($debugA) = @_;
    $debug = $debugA;
}

sub arpaDate {
  my($date, @l, @g, $zone, $zoneflg);

    # Fetch date, time
    $date = ctime(time);
    @l 	= localtime(time);
    @g 	= gmtime(time);

    # Time zone
    $zone = $l[2] - $g[2];
    $zoneflg = '+';
    $zone += 24 if ($zone < -12);
    $zone -= 24 if ($zone > 12);
    if ($zone < 0) {
	$zoneflg = '-';
	$zone = -$zone;
    }

    # Create date string
    $date = substr($date,0,3).",". 	# Day
	    substr($date,7,3).     	# Date
	    substr($date,3,4).     	# Month
	    substr($date,19,5).    	# Year
	    substr($date,10,9).   	# Time
            " $zoneflg".        	# Zone direction
            sprintf("%02d",$zone). 	# Zone offset
            "00";

    return $date;
}

sub exec_cleanse {
    my ($input) = @_;
    if ($input =~ /([\w\d\.\;\,\<\>\-\_\/\s\@\+]+)/) {
	return $1;
    }
    return '';
}

1;
