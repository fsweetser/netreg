#   -*- perl -*-
#
# CMU::WebInt::helper
# General helper functions
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
# $Id: helper.pm,v 1.46 2008/04/04 16:01:14 vitroth Exp $
#

package CMU::WebInt::helper;
use strict;
use vars qw (@ISA @EXPORT @EXPORT_OK %UserAttributes);
use CMU::WebInt;
use CMU::Netdb;
use Data::Dumper;

require CMU::WebInt::config;

require CMU::Netdb::config;

use CMU::Netdb::helper;

use CGI;
use DBI;
use POSIX qw(ctime);

{
  no strict;
  $VERSION = '0.052';
}

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(getUserInfo db_connect gParam admin_mail encURL %UserAttributes drawUserRealmPopup);

%UserAttributes = ();
my $debug = 0;

sub getUserInfo {
  my ($Real) = @_;

  my ($userID, $principal, $realm);
  my $user = '';
  $user = $ENV{REMOTE_USER} if (defined $ENV{REMOTE_USER});

  if ($user eq '' && defined $ENV{SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME}) {
    my @AltNames = split(/\s*\,\s*/, $ENV{SSL_CLIENT_V3EXT_SUBJECT_ALT_NAME});
    my @EmailNames = grep (/^email:/i, @AltNames);
    if ($#EmailNames > -1) {
      # Can only use one email sadly
      $user = $EmailNames[0];
      $user =~ s/^email://i;
    }else{
      # Just get the first one
      if ($#AltNames > -1) {
	my $nul;
	($nul, $user) = split(/\:/, $AltNames[0], 2);
      }
    }
  }

  $user = $ENV{SSL_CLIENT_S_DN_Email} if ($user eq '' &&
					  defined $ENV{SSL_CLIENT_S_DN_Email});
  $user = $ENV{SSL_CLIENT_EMAIL} if ($user eq '' &&
				     defined $ENV{SSL_CLIENT_EMAIL});

  my $authuser = $ENV{'authuser'};

  if ($authuser ne '' && $Real ne 'Real') {
    my ($vres, $rSuperUsers) = CMU::Netdb::config::get_multi_conf_var
      ('webint', 'SuperUsers');
    $rSuperUsers = [$rSuperUsers] if ($vres == 1 && ref $rSuperUsers ne 'ARRAY');

    if (grep /^$user$/i, @$rSuperUsers) {
      $user = $authuser;
    }else{
      $ENV{'authuser'} = '';
    }
  }

  my ($vres, $local_realm) = CMU::Netdb::config::get_multi_conf_var('webint',
								    'LocalRealm');
  ($principal, $realm) = split(/\@/, $user);
  if ((uc($realm) ne uc($local_realm))
      && ($realm ne "")) {
    $userID = "$principal\@$realm";
  } else {
    $userID = $principal;
  }

  return ($userID, $principal, $realm) if (wantarray);
  return $userID;
}

sub db_connect {
  my ($SilentMode) = @_;
  my ($dbh, $pass, $sth, @superusers, $q, @row);

  $SilentMode = 0 unless ($SilentMode ne '');

  my ($vres, $NR_DB) = CMU::Netdb::config::get_multi_conf_var('webint',
							       'NetReg_Web_DB');
  die "Error connecting to netreg database: NetReg_Web_DB connect info not found".
    "($vres)" if ($vres != 1);

  if (defined $NR_DB->{'password_file'}) {
    open(FILE, $NR_DB->{'password_file'})
      || die "Cannot open NetDB password file (".$NR_DB->{'password_file'}.")!";
    $pass = <FILE>;
    close(FILE);
    chomp($pass);
  }else{
    $pass = $NR_DB->{'password'};
  }

  warn __FILE__, ':', __LINE__, ' :>'.
    "connection: ".$NR_DB->{'connect_string'}." / ".$NR_DB->{'username'}."\n"
      if ($debug >= 1);
  
  $dbh = DBI->connect($NR_DB->{'connect_string'},
		      $NR_DB->{'username'},
		      $pass);
  if (!$dbh) {
    if ($SilentMode) {
      die "Error connecting to netreg database.";
    }else{
      my ($bgres, $bgcolor) = CMU::Netdb::config::get_multi_conf_var('webint',
								     'BGCOLOR');

      $q = new CGI;
      print $q->header, $q->start_html(-BGCOLOR => $bgcolor)."<H1>Database Error</H1>";
      &CMU::WebInt::title("Database Error");
      print "<hr>There was an error while connecting to the netreg database. The ".
	"administrator has been informed. Please try again later.\n";
      print &CMU::WebInt::stdftr($q);
      CMU::WebInt::admin_mail('helper.pm:db_connect', 'CRITICAL',
			      'Database not accessible.', {});
      exit 0;
    }
  }
  unless ($SilentMode) {
    my ($user, $p, $r) = &getUserInfo;

    my ($vres, $rSuperUsers) = CMU::Netdb::config::get_multi_conf_var
      ('webint', 'SuperUsers');
    $rSuperUsers = [$rSuperUsers] if ($vres == 1 && ref $rSuperUsers ne 'ARRAY');

    if ($user eq 'netreg') {
      $q = new CGI;
      print &CMU::WebInt::stdhdr($q, $dbh, $user, "Not Allowed", {});
      &CMU::WebInt::title("Netreg User Denied");
      print "<hr>For safety reasons, the netreg user is not allowed to use the ".
	"web interface to the database.\n";
      print &CMU::WebInt::stdftr($q);
      exit 0;
    }
    if (!grep(/^$user$/, @$rSuperUsers)) {
      my ($code, $val) = CMU::Netdb::get_sys_key($dbh, 'DB_OFFLINE');
      if ($code >= 1) {
	$q = new CGI;
	print &CMU::WebInt::stdhdr($q, $dbh, $user, "Database Offline", {});
	&CMU::WebInt::title("Database Temporarily Offline");
	print "<hr>The database is temporarily offline. Please try again later.\n";
	print "<br><table border=1><tr><td>System Message:</td></tr>".
	  "<tr><td>$val</td></tr></table>\n";
	print &CMU::WebInt::stdftr($q);
	exit 0;
      }
    }
    loadUserAttributes($dbh, $user);
  }

  return $dbh;
}

sub loadUserAttributes {
  my ($dbh, $user) = @_;

  %UserAttributes = ();

  my $User = CMU::Netdb::list_users($dbh, $user, "credentials.authid = '$user'");
  return if (!ref $User || !defined $User->[1]);

  my %pos = %{CMU::Netdb::makemap($User->[0])};
  my $UserID = $User->[1]->[$pos{'users.id'}];
  return if ($UserID eq '');

  my $Attr = CMU::Netdb::list_attribute($dbh, $user,
					"attribute.owner_table = 'users' ".
					"AND attribute.owner_tid = '$UserID'");
  return if (!ref $Attr);

  %pos = %{CMU::Netdb::makemap($Attr->[0])};
  shift(@$Attr);
  foreach my $A (@$Attr) {
    $UserAttributes{$A->[$pos{'attribute_spec.name'}]} =
      $A->[$pos{'attribute.data'}];
  }

}

sub gParam {
  my ($q, $name) = @_;
  if (wantarray) {
    my @a = $q->param($name);
    my (@ret,$a);
    foreach $a (@a) {
      return '' unless (defined $a && $a ne '');
      push @ret, CMU::Netdb::helper::cleanse($a);
    }
    return @ret;
  } else {
    my $a = $q->param($name);
    return CMU::Netdb::helper::cleanse($a) if (defined $a && $a ne '');
    return '';
  }
}

sub admin_mail {
  my ($location, $level, $subj, $msg) = @_;

  my $now = time();
  my $arpadate = &CMU::Netdb::ArpaDate();
  warn __FILE__, ':', __LINE__, ' :>'.
    "sending mail...\n" if ($debug >= 1);

  my ($mailer, $senderN, $sendA, $adminN, $adminA, $vres);

  ($vres, $mailer) = CMU::Netdb::config::get_multi_conf_var('webint', 'MAILER');
  if ($vres == $CMU::Netdb::errors::errcodes{'ENOCONFVAR'}) {
    warn "CMU::WebInt::admin_mail: Missing configuration variable MAILER\n";
    return -1;
  }

  ($vres, $senderN) = CMU::Netdb::config::get_multi_conf_var('webint', 
                                                             'SENDER_NAME');
  if ($vres == $CMU::Netdb::errors::errcodes{'ENOCONFVAR'}) {
    warn "CMU::WebInt::admin_mail: Missing configuration variable SENDER_NAME\n";
    $senderN = 'NetReg';
  }
  ($vres, $sendA) = CMU::Netdb::config::get_multi_conf_var('webint',
                                                          'SENDER_ADDRESS');
  if ($vres == $CMU::Netdb::errors::errcodes{'ENOCONFVAR'}) {
    warn "CMU::WebInt::admin_mail: Missing configuration variable SENDER_ADDRESS\n";
    $sendA = 'netreg@localhost';
  }
  ($vres, $adminN) = CMU::Netdb::config::get_multi_conf_var('webint',
                                                           'ADMIN_NAME');
  if ($vres == $CMU::Netdb::errors::errcodes{'ENOCONFVAR'}) {
    warn "CMU::WebInt::admin_mail: Missing configuration variable ADMIN_NAME\n";
    $adminN = 'NetReg Admin';
  }
  ($vres, $adminA) = CMU::Netdb::config::get_multi_conf_var('webint',
                                                           'ADMIN_ADDRESS');
  if ($vres == $CMU::Netdb::errors::errcodes{'ENOCONFVAR'}) {
    warn "CMU::WebInt::admin_mail: Missing configuration variable ADMIN_ADDRESS\n";
    return -1;
  }

  my $cmd = "|$mailer $adminA";
  open(MAIL, $cmd) || warn "Cannot open mail prog [$cmd].\n";
  print MAIL "X-Mailer: Netreg WebInt";
  print MAIL "From: $senderN <$sendA>\n";
  print MAIL "To: $adminN <$adminA>\n";
  print MAIL "Date: $arpadate\n";
  print MAIL "Subject: $subj\n\n";

  print MAIL "================== netreg error report ==================\n";
  print MAIL "Date: ".localtime($now)." [$now]\n";
  print MAIL "Location: $location\n";
  print MAIL "Error Level: $level\n";
  print MAIL "User: ".&getUserInfo()."\n";
  print MAIL "Address: ".$ENV{REMOTE_ADDR}."\n";
  print MAIL "Server: ".$ENV{SERVER_NAME}." (PID: $$)\n";
  print MAIL "Query: ".$ENV{QUERY_STRING}."\n";
  print MAIL "\nMessage Details:\n";

  map { print MAIL "$_: $$msg{$_}\n"; } keys %$msg;
  print MAIL "\n=========================================================\n";
  close(MAIL);
} 

# encodes a url re: RFC 2396  
# slightly wrong in that it allows some 'reserved' chars through all the time,
# but we can't really verify this, so.x
sub encURL {
  my ($url) = @_;

  my $prefix = '';
  my @comp = split(/\:/, $url);

  if ($comp[0] eq 'http' || $comp[0] eq 'https') {
    $prefix = $comp[0].':';
    shift(@comp);
  }
  $url = join(':', @comp);

  my $nUrl = join('', map { ($_ =~ /[a-zA-Z0-9\-\_\.\!\~\*\'\(\)\=\/\&\?\#]/ ? $_ : 
			     sprintf "%%%x", ord($_)) } split ('', $url));
  return $prefix.$nUrl;
}

# draws a nice popup for user realms
sub drawUserRealmPopup {
  my ($cgiHandle, $objName, $accessKey, $selectedRealm) = @_;
  my $userRealms;
  my $defaultRealm;

  $userRealms = get_userrealms();

  if ($userRealms eq undef) { return -1 ; }

  $defaultRealm = get_defaultuserrealm();

  if ($selectedRealm eq undef) { $selectedRealm = $defaultRealm; }

  unshift @{$userRealms}, "--none--";

  if ((scalar [$userRealms] > 0) and ($userRealms ne undef))
  {
    print " @ " .
        $cgiHandle->popup_menu(
                               -name => $objName,
                               -accesskey => $accessKey,
                               -values => $userRealms,
                               -default => $selectedRealm);
    return 1;
  }

  return 0;
}

## get_userrealms
## arguments: none

## Returns: an array of user realms

sub get_userrealms {
  my ($vres, $rUserRealms) = CMU::Netdb::config::get_multi_conf_var ('webint', 'UserRealm');
  if ($vres < 1) { return undef; }

  $rUserRealms = [$rUserRealms] if ($vres == 1 && !(ref $rUserRealms eq 'ARRAY')); 

  my $copy = [@$rUserRealms];
  return $copy;

}

## get_defaultuserrealm
## arguments: none

## Returns: string with the default realm

sub get_defaultuserrealm {
  my ($vres, @defaultUserRealm) = CMU::Netdb::config::get_multi_conf_var ('webint', 'DefaultUserRealm');
  if ($vres < 1) { return undef; }

  return $defaultUserRealm[0];
}


1;  
