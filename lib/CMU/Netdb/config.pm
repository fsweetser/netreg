#   -*- perl -*-
#
# CMU::Netdb::config
# General configuration bits
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
# $Id: config.pm,v 1.26 2005/06/29 22:04:26 fes Exp $
# 
# $Log: config.pm,v $
# Revision 1.26  2005/06/29 22:04:26  fes
# Back out changes that missed the branch and hit HEAD
#
# Revision 1.24  2004/02/20 03:09:53  kevinm
# * External config file updates
#
# Revision 1.23  2003/11/13 20:29:43  kevinm
# * Removing notifications
#
# Revision 1.22  2003/08/18 01:47:18  kevinm
# *** empty log message ***
#
# Revision 1.21  2003/08/13 19:06:42  kevinm
# * Notifications registry
#
# Revision 1.20  2003/07/09 20:57:20  ebardsle
# Default AUTHBRIDGE to off.
#
# Revision 1.19  2003/05/13 20:39:47  ktrivedi
# *** empty log message ***
#
# Revision 1.18  2003/05/12 19:36:56  ktrivedi
# *** empty log message ***
#
# Revision 1.17  2003/05/12 19:30:27  ktrivedi
# authbridge variables
#
# Revision 1.16  2003/02/26 22:49:35  fk03
# Fixed typo in zone protection change.
#
# Revision 1.15  2003/02/26 22:45:12  fk03
# configured new zones to be accessable by netreg:police
#
# Revision 1.14  2003/01/07 15:58:51  kevinm
# * Force SSH v1 for now
#
# Revision 1.13  2003/01/07 12:33:25  kevinm
# * Moving caching DNS to anycast
#
# Revision 1.12  2002/09/30 01:21:18  kevinm
# * Added DBMS_XACTION flag to enable transactions
# * Added MAX_CASCADE_DEPTH variable to control cascade deletion depth
#
# Revision 1.11  2002/08/22 15:47:48  kevinm
# * Added file header
#
# Revision 1.10  2002/08/22 15:35:56  kevinm
# * Changes to the new netreg-install format
#
# Revision 1.9  2002/08/20 21:38:48  kevinm
# * [Bug 1355] Add default protections to zones, buildings, dhcp options, and services.
#
# Revision 1.8  2002/07/18 03:48:10  kevinm
# * Added support for quickreg stuff
#
# Revision 1.7  2002/05/02 20:44:49  kevinm
# * Accidentaly had the DHCP_SERVICE variable in there twice
#
# Revision 1.6  2002/04/05 16:56:21  kevinm
# * Added service xfer path variable
#
# Revision 1.5  2002/03/14 03:59:16  kevinm
# * Enforce hostnames for all machines coming into NetReg
#
# Revision 1.4  2002/03/08 00:56:07  kevinm
# * DNS_ETC shouldn't refer to itself. (Thanks: Mike Nguyen)
#
# Revision 1.3  2002/03/04 00:34:08  kevinm
# * New DHCP Option Type stuff
#
# Revision 1.2  2002/01/17 22:01:24  kevinm
# Added support utility configuration options
#
# Revision 1.1  2002/01/03 20:52:22  kevinm
# Initial checking of general configuration file for Netdb.
#
#
#

package CMU::Netdb::config;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $debug );

use Config::General;

use CMU::Netdb;

require Exporter;
@ISA = qw(Exporter);

# Do not allow any blank lines in here!
@EXPORT = qw/get_multi_conf_var/;

$debug = 0;

my %Config;

sub netreg_multi_load_config {
  my ($type, $hints) = @_;

  if (defined $ENV{"NETREG_${type}_CONF"} && -r $ENV{"NETREG_${type}_CONF"}) {
    return __netreg_mload_config($type, $ENV{"NETREG_${type}_CONF"});
  }elsif(-r "/etc/netreg-${type}.conf") {
    return __netreg_mload_config($type, "/etc/netreg-${type}.conf");
  }elsif(defined $hints && $hints ne '' && !ref $hints && -r $hints) {
    return __netreg_mload_config($type, $hints);
  }elsif(defined $hints && ref $hints eq 'ARRAY') {
    foreach my $F (@$hints) {
      return __netreg_mload_config($type, $F) if (-r $F);
    }
  }

  die "Could not find configuration file (type: $type); set the environment ".
    "variable NETREG_${type}_CONF to the file location.";
}

sub __netreg_mload_config {
  my ($type, $file) = @_;

  my $CT = new Config::General(-ConfigFile => $file, -InterPolateVars => 1);
  my %ConfigVars = $CT->getall;
  $Config{$type} = \%ConfigVars;
}

sub get_multi_conf_var {
  my ($type, $var) = @_;

  warn __FILE__, ':', __LINE__, ' :>'.
    "get_multi_conf_var($type, $var)" if ($debug >= 1);

  netreg_multi_load_config($type) unless (defined $Config{$type});

  if (!defined $Config{$type}) {
    return ($CMU::Netdb::errors::errcodes{'ENOCONFVAR'}, {'type' => $type,
							 'var' => $var});
  }
  return (1, $Config{$type}->{$var}) if (defined $Config{$type}->{$var});
  return ($CMU::Netdb::errors::errcodes{'ENOCONFVAR'}, {'type' => $type,
						       'var' => $var});
}

1;
