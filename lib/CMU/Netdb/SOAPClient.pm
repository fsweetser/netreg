#  -*- perl -*-
#
# SOAP Client functions
#
# Copyright (c) 2003 Carnegie Mellon University. All rights reserved.
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
#
# $Id: SOAPClient.pm,v 1.4 2008/03/27 19:42:34 vitroth Exp $
#
# $Log: SOAPClient.pm,v $
# Revision 1.4  2008/03/27 19:42:34  vitroth
# Merging changes from duke merge branch to head, with some minor type corrections
# and some minor feature additions (quick jump links on list pages, and better
# handling of partial range allocations in the subnet map)
#
# Revision 1.3.14.1  2007/10/11 20:59:38  vitroth
# Massive merge of all Duke changes with latest CMU changes, and
# conflict resolution therein.   Should be ready to commit to the cvs HEAD.
#
# Revision 1.3.12.1  2007/09/20 18:43:03  kevinm
# Committing all local changes to CVS repository
#
# Revision 1.3  2005/08/14 04:38:36  kcmiller
# * Adding basic auth method
#
# Revision 1.2  2005/08/09 01:52:51  kcmiller
# * Updates from CMU
#
# Revision 1.3  2005/01/03 21:08:12  vitroth
# Less low level debugging.
#
# Revision 1.2  2004/07/21 18:31:45  vitroth
# minor fix to remove a startup warning
#
# Revision 1.1  2004/04/15 18:50:12  vitroth
# Checking in initial version of SOAP API
#
#
#

package CMU::Netdb::SOAPClient;

use Data::Dumper;

use SOAP::Lite on_fault => sub { my ($soap, $res) = @_;
				 if (!ref $res && 
				     $soap->transport->status =~ /certs.+Illegal seek/) {
				   die "Password incorrect";
				   return new SOAP::SOM;
				 }
				 eval { die ref $res ? "FS: ".$res->faultstring : 
					  "TS: ".$soap->transport->status };
				 return ref $res ? $res : new SOAP::SOM;
			       };

use vars qw/@ISA @EXPORT @EXPORT_OK/;

require Exporter;
@ISA = qw/Exporter/;

@EXPORT = qw/getSOAPConnection getSOAPHashDataMap getSOAPErr/;

my %DefaultConnProfile = 
  ('method' => 'x509',
   'proxy' => 'https://example.net.cmu.edu/cbin/netreg-soap/default',
   'x509' => {'type' => 'pkcs12',
	      'pkcs12' => { 'filename' => $ENV{HOME}.'/.identity.pfx',
			    'password-prompt' => 1,
			  },

	      # PEM unused unless 'type' is 'pem'
	      'pem' => {'certfile' => '/path/to/cert/file',
			'keyfile' => '/path/to/key/file',
		       },
	     },
  );

sub getSOAPConnection {
  my ($RCP) = @_;

  $RCP = \%DefaultConnProfile unless (ref $RCP);

  die "No SOAP proxy specified" unless ($RCP->{proxy} ne '');

  if ($RCP->{method} eq 'x509') {
    die "Missing x509 configuration" unless (ref $RCP->{x509});
    my $x509 = $RCP->{x509};

    if ($x509->{type} eq 'pkcs12') {
      die "Missing PKCS12 configuration" unless (ref $x509->{pkcs12});
      my $pkcs12 = $x509->{pkcs12};

      die "No PKCS12 filename specified" unless ($pkcs12->{filename} ne '');
      $ENV{HTTPS_PKCS12_FILE} = $pkcs12->{filename};

      if ($pkcs12->{'password-prompt'}) {
	$ENV{HTTPS_PKCS12_PASSWORD} = getPassword('Enter PKCS12 password: ');
      }else{
	die "No PKCS12 password provided" unless ($pkcs12->{password} ne '');
	$ENV{HTTPS_PKCS12_PASSWORD} = $pkcs12->{password};
      }
    }elsif($x509->{type} eq 'pem') {
      my $pem = $x509->{pem};
      die "Missing X509/PEM certificate file" unless ($pem->{certfile} ne '');
      die "Missing X509/PEM key file" unless ($pem->{keyfile} ne '');
      $ENV{HTTPS_CERT_FILE} = $pem->{certfile};
      $ENV{HTTPS_KEY_FILE} = $pem->{keyfile};
    }
  }elsif($RCP->{method} eq 'basic') {
    die "Missing basic auth configuration" unless (ref $RCP->{basic});
    my $basic = $RCP->{basic};

    my $creds = $basic->{'username'}.':'.$basic->{'password'};
    $RCP->{proxy} =~ s-https://-http://$creds\@-;
  }else{
    die "Unknown method type: $RCP->{method}";
  }

  return SOAP::Lite->uri('CMU/Netdb/SOAPAccess')->proxy($RCP->{proxy});
}

sub getPassword {
  my ($Prompt) = @_;

  system("stty -echo");
  print STDERR $Prompt;
  my $PWD = <STDIN>;
  chomp($PWD);
  system("stty echo");
  print STDERR "\n";

  return $PWD;
}

sub getSOAPErr {

}

sub getSOAPHashDataMap {
  my ($rData, $rKey) = @_;

  my @First = @{$rData->[0]};
  my $rMap = {};
  for my $i (0..$#First) {
    $rMap->{$First[$i]} = $i;
  }

  my %Data;
  my @Elem = sort { $rMap->{$a} <=> $rMap->{$b} } keys %$rMap;

  my @Order;

  my $line = 0;
  foreach my $row (@$rData) {
    next if ($line++ == 0);
    my $Key = $row->[$rMap->{$rKey}];
    push(@Order, $Key);
    for my $i (0..$#$row) {
      $Data{$Key}->{$Elem[$i]} = $row->[$i];
    }
  }
  if (wantarray) {
    return (\%Data, \@Order);
  } else {
    return \%Data;
  }
}

1;
