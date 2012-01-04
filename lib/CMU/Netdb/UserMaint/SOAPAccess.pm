package CMU::Netdb::UserMaint::SOAPAccess;
use CMU::Netdb::UserMaint;
use CMU::Netdb;
use UNIVERSAL;
use Data::Dumper;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug $AUTOLOAD %SOAP_FUNCTIONS);

require Exporter;
@ISA = qw(Exporter SOAP::Server::Parameters);
@EXPORT = qw();

$debug = 0;

#################
# README
#
# Things still to be done/considered:
# - Error Output.  Right now three different types of errors can occur. 
#   I want to fix this. The three types are:
#     . NetReg API errors (standard two part error code array in
#       $soapRes->result->{result},
#     . wrapper config/argument errors (no $soapRes->result->{result},
#       instead ->{error} and ->{error_text} exist), and 
#     . wrapper runtime/generation errors, which currently call die
#       (bad idea?, should be changed to error/error_text style.
#   - UPDATE: FIXED in this version. Either $soapRes->result->{result} will
#     exist, and  have "valid" data, or a SOAP fault will be returned, which
#     should be tested for  via $soapRes->fault, with the fault message being
#     in $soapRes->faultdetail. This is the correct SOAP way to return errors.
#
# - API export configuration.  The 'what API calls to export' structure
#   should be moved to the config file.  This means new API calls could be
#   exported without having to restart the server
#   - I'm still debating this.  
#
# - API argument types.  At least one more argument type needs to be added,
#   UNSIGNED_INTEGER, for modify/delete calls that take an id & version.
#   - I'm also adding DATE and CONSTANT.
#
# - SQL Sanity checking.  Right now i'm only checking for semicolons in
#   the where clause
#
# - API argument sanity checking.  Right now we're just relying on the API
#   to catch argument errors.  This is probably ok, but as more of the API
#   is exported we need to be conscious of this.
#
# - The SOAP API doesn't do any per-column filtering by access level.
#   The  changes to the core API to do this must be deployed along with
#   the SOAP API.

%SOAP_FUNCTIONS = (
  'add_user' => { 
    'function' => \&CMU::Netdb::UserMaint::usermaint_add_user,
    'arguments' => [ { 'name' => 'userid',
                       'type' => 'CREDENTIAL',
                       'blank' => 'DISALLOWED',
                       'optional' => 0,
                     },
                     
                     { 'name' => 'comment',
                       'type' => 'STRING',
                       'blank' => 'DISALLOWED',
                       'optional' => 0,
                     },
                     
                     { 'name' => 'type',
                       'type' => 'STRING',
                       'blank' => 'DISALLOWED',
                       'optional' => 0,
                     },

                     { 'name' => 'accounts',
                       'type' => 'CREDENTIAL-LIST',
                       'blank' => 'ALLOWED',
                       'optional' => 1,
                     },
                  ],
                  'return' => 'ARRAY',
                },
                
  'delete_user' => { 
    'function' => \&CMU::Netdb::UserMaint::usermaint_delete_user,
    'arguments' => [ { 'name' => 'userid',
                       'type' => 'CREDENTIAL',
                       'blank' => 'DISALLOWED',
                       'optional' => 0,
                     },
                   ],
                   'return' => 'ARRAY',
                   },
  'enumerate_users' => { 
    'function' => \&CMU::Netdb::UserMaint::usermaint_enumerate,
    'arguments' => [ { 'name' => 'users',
                       'type' => 'ARRAYREF',
                       'blank' => 'DISALLOWED',
                       'optional' => 0,
                     },
                     { 'name' => 'type',
                       'type' => 'STRING',
                       'blank' => 'DISALLOWED',
                       'optional' => 0,
                     },
                   ],
                   'return' => 'ARRAY',
                   },
);


sub AUTOLOAD {
  return if $AUTOLOAD =~ /::DESTROY$/;
  warn Data::Dumper->Dump([\%SOAP_FUNCTIONS],
                          ['SOAP_FUNCTIONS']) if ($debug >= 3);
  $AUTOLOAD =~ s/^.*:://;
  die "No $AUTOLOAD method " .
      "in NetReg UserMaint SOAP API" unless defined($SOAP_FUNCTIONS{$AUTOLOAD});

  warn __FILE__, ':', __LINE__,
       ": SOAPAccess compiling subroutine for $AUTOLOAD\n" if ($debug >= 1);

  my $code = <<END_CODE;
sub $AUTOLOAD {
  my \$self = shift;
  my \$env = pop;
  my \$params = \$env->method();
  my %dummy;
  my \$dbuser = get_dbuser();
  my \$res;
  my \@ret;
  my \$dbh = soap_db_connect();
  if (!ref \$params) {
    \$params = {};
  }
  warn 'SOAPAccess:', __FILE__, ':', __LINE__,
       ": Entering $AUTOLOAD at " . localtime(time) . "\\n" if (\$debug >= 2); 
  if (\$debug >= 3) {
    warn "SOAPAccess: $AUTOLOAD: dbuser '\$dbuser'";
    warn "SOAPAccess: $AUTOLOAD: " .
         Data::Dumper->Dump([\$self, \$params, \$env->body],
                            ['object', 'params', 'request']) . "\\n";
  }

  my \$funcref = \$SOAP_FUNCTIONS{'$AUTOLOAD'};

  my \@args = ();
  my \$i = -1;
  for my \$argref (\@{\$funcref->{arguments}}) {
    my \$param = \$params->{\$argref->{name}};
    \$i++;

    if ( \$argref->{type} eq 'EVAL') {
      push \@args, eval(\$argref->{eval});
      next;
    } elsif (\$argref->{type} eq 'CONSTANT') {
      push \@args, \$argref->{value};
      next;
    } elsif (\$argref->{optional} == 1 && !defined(\$param)) {
      push \@args, undef;
      next;
    } elsif (!defined(\$argref->{name})) {
      die "Arg. \$i to $AUTOLOAD has no name.";
    } elsif (!defined(\$param)) {
      die "Arg. \$i (\$argref->{name}) of type '\$argref->{type}'".
          " to $AUTOLOAD is missing.";
    } elsif (\$argref->{blank} eq 'ALLOWED' && \$param eq '') {
      push \@args, '';
      next;
    } elsif (\$param eq '') {
      die "Arg. \$i (\$argref->{name}) of type '\$argref->{type}'".
          " to $AUTOLOAD may not be blank";
    } elsif (\$argref->{type} eq 'SQL') {
      #FIXME: Validate SQL here
      if (\$param =~ /;|--|union\\select/i) {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD failed SQL check.";
      } else {
        push \@args, \$param;
        next;
      }
    } elsif (\$argref->{type} eq 'UNSIGNED_INTEGER') {
      if (int(\$param) ne \$param || \$param < 0) {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
            " be of type '\$argref->{name}'.";
      } else {
        push \@args, \$param;
        next;
      }
    } elsif (\$argref->{type} eq 'CREDENTIAL') {
      # Netreg would call cleanse before validating the content, so we'll do the same.
      my \$tmp = CMU::Netdb::cleanse(\$param);
      if (\$tmp !~ /^[A-Za-z0-9\.\\@]+\$/s) {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
            " be of type '\$argref->{name}'.";
      } else {
        push \@args, \$tmp;
        next;
      }
    } elsif (\$argref->{type} eq 'CREDENTIAL-LIST') {
      # Netreg would call cleanse before validating the content, so we'll do the same.
      my \$tmp = CMU::Netdb::cleanse(\$param);
      if (\$tmp !~ /^[A-Za-z0-9\.\\@,]+\$/s) {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
            " be of type '\$argref->{name}'.";
      } else {
        push \@args, \$tmp;
        next;
      }
    } elsif (\$argref->{type} eq 'GROUPNAME') {
      if (\$param !~ /^[A-Za-z]+:[A-Za-z]+\$/s) {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
            " be of type '\$argref->{name}'.";
      } else {
        push \@args, \$param;
        next;
      }
    } elsif (\$argref->{type} eq 'DATE') {
      if (\$param !~ /^\d{4}-\d{2}-\d{2}\$/) {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
            " be of type '\$argref->{name}' (YYYY-MM-DD).";
      } else {
        push \@args, \$param;
        next;
      }
    } elsif (\$argref->{type} eq 'HASHREF') {
      if (ref(\$param) ne 'HASH') {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
            " be of type '\$argref->{name}'.";
      } else {
        push \@args, \$param;
        next;
      }
    } elsif (\$argref->{type} eq 'ARRAYREF') {
      if (ref(\$param) ne 'ARRAY') {
        die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
            " be of type '\$argref->{name}'.";
      } else {
        push \@args, \$param;
        next;
      }
    } elsif (\$argref->{type} eq 'STRING') {
      # Netreg would call cleanse before validating the content, so we'll do the same.
      my \$tmp = CMU::Netdb::cleanse(\$param);
      if (length(\$tmp) > 255 
          || \$tmp !~ /^[A-Za-z0-9\\(\\)\\,\\.\\-\\ \\_\\/\\:]*\$/s) {
          die "Arg. \$i (\$argref->{name}) to $AUTOLOAD must".
             " be a STRING.";
      } else {
        push \@args, \$tmp;
        next;
      }
    } else {
      die "Arg. \$i (\$argref->{name}) to $AUTOLOAD has".
          " unknown type '\$argref->{type}'";
    }
  }

  if (ref(\$funcref->{function}) ne "CODE") {
    warn Data::Dumper->Dump([\\\%SOAP_FUNCTIONS],['SOAP_FUNCTIONS']);
    die 'Server configuration error: No function pointer for $AUTOLOAD, found a reference to '.ref(\$funcref->{function}).' instead.';
  }
              
  eval {
    if (\$funcref->{return} eq 'INTEGER' ||
        \$funcref->{return} eq 'REFERENCE') {
        \$res= \$funcref->{function}->(\$dbh, \$dbuser, \@args);
    } elsif (\$funcref->{return} eq 'ARRAY') {
        \@\$res= \$funcref->{function}->(\$dbh, \$dbuser, \@args);  
    } else {
      die "Server configuration error: Unknown return type".
          " '\$funcref->{return}' for $AUTOLOAD";
    }
  };
  if (\$@) {
    warn __FILE__, ':', __LINE__, ': $AUTOLOAD: error: ', \$@, "\n".
         "Code: \$res=$AUTOLOAD(" . join(', ', \@args) . ");" if ($debug >= 3);
    die "API error: $AUTOLOAD: " . \$@;
  } elsif (\$funcref->{return} eq 'REFERENCE' && !ref(\$res)) {
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res}".
        " \$CMU::Netdb::primitives::db_errstr\\n"
                                  if (\$res eq \$CMU::Netdb::errcodes{EDB});
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res}\n";
  } elsif (\$funcref->{return} eq 'ARRAY' && \$res->[0] <= 0) {
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res->[0]}".
        " \$CMU::Netdb::primitives::db_errstr\\n"
                             if (\$res->[0] eq \$CMU::Netdb::errcodes{EDB});
    die "Error in $AUTOLOAD: \$CMU::Netdb::errors::errmeanings{\$res->[0]}".
        " (" . join(',',\@{\$res->[1]}) . ")\\n";
  } else {
     warn 'SOAPAccess:', __FILE__, ':', __LINE__,
          ": Normal exit of $AUTOLOAD at " . localtime(time) . "\\n"
                                                             if (\$debug >= 3);
     return SOAP::Data->name('result')
                      ->value(\$res)
                      ->uri('http://www.net.cmu.edu/netreg');
  }
}
END_CODE
  eval $code;
  if ($@) {
    die "Cannot create AUTOLOAD stub for $AUTOLOAD: $@\n$code\n";
  }
  goto &$AUTOLOAD;
}

sub soap_db_connect {
  my ($dbh, $pass);

  my ($vres, $SOAP_DB) = CMU::Netdb::config::get_multi_conf_var('soap', 'NetReg_SOAP_DB');

  die "Error connecting to netreg database: NetReg_SOAP_DB connect info not found".
    "($vres)" if ($vres != 1);

  if (defined $SOAP_DB->{'password_file'}) {
    open(FILE, $SOAP_DB->{'password_file'})
      || die "Cannot open NetDB password file (".$SOAP_DB->{'password_file'}.")!";
    $pass = <FILE>;
    chomp $pass;
    close(FILE);
  }else{
    $pass = $SOAP_DB->{'password'};
  }

  warn __FILE__, ':', __LINE__, ' :>'.
    "connection: ".$SOAP_DB->{'connect_string'}." / ".$SOAP_DB->{'username'}."\n"
      if ($debug >= 1);
  
  $dbh = DBI->connect($SOAP_DB->{'connect_string'},
		      $SOAP_DB->{'username'},
		      $pass);
  if (!$dbh) {
    die "Unable to get database connection.\n";
  }

  my $user = &get_dbuser;
  my ($vres, $rSuperUsers) = CMU::Netdb::config::get_multi_conf_var
    ('soap', 'SuperUsers');
  $rSuperUsers = [$rSuperUsers] if ($vres == 1 && !ref $rSuperUsers eq 'ARRAY');

  if ($user eq 'netreg') {
    die("Netreg User Denied: For safety reasons, the netreg user is not allowed to use the ".
	"soap interface to the database.\n");
  }
  if (!grep(/^$user$/, @$rSuperUsers)) {
    my ($code, $val) = CMU::Netdb::get_sys_key($dbh, 'DB_OFFLINE');
    if ($code >= 1) {
      die("Database Offline: The database is temporarily offline. Please try again later.\n");
    }
  }

  return $dbh;
}


sub get_dbuser {
  my $user = '';
  $user = $ENV{REMOTE_USER} if (defined $ENV{REMOTE_USER});
  if ($user eq '' && defined $ENV{SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME}) {
    my @AltNames = split(/\s*\,\s*/, $ENV{SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME});
    my @EmailNames = grep (/^email:/i, @AltNames);
    if (@EmailNames > 0) {
      # Can only use one email sadly
      $user = $EmailNames[0];
      $user =~ s/^email://i;
    } else {
      # Just get the first one
      if (@AltNames > 0) {
        my $nul;
        ($nul, $user) = split(/\:/, $AltNames[0], 2);
      }
    }
  }
  # In some strange cases, the SSL variables are passed in this way
  if ($user eq '' && defined $ENV{REDIRECT_SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME}) {
    my @AltNames = split(/\s*\,\s*/, $ENV{REDIRECT_SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME});
    my @EmailNames = grep (/^email:/i, @AltNames);
    if (@EmailNames > 0) {
      # Can only use one email sadly
      $user = $EmailNames[0];
      $user =~ s/^email://i;
    } else {
      # Just get the first one
      if (@AltNames > 0) {
        my $nul;
        ($nul, $user) = split(/\:/, $AltNames[0], 2);
      }
    }
  }
  if ($user eq '' && defined $ENV{SSL_CLIENT_S_DN_Email}) {
    $user = $ENV{SSL_CLIENT_S_DN_Email};
  }
  if ($user eq '' && defined $ENV{SSL_CLIENT_EMAIL}) {
    $user = $ENV{SSL_CLIENT_EMAIL};
  }
  warn "User is '$user'" if ($debug >= 2);

  CMU::Netdb::primitives::clear_changelog("UserMaint-SOAP:$ENV{REMOTE_ADDR}");

  return $user;
}

1;
