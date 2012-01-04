#   -*- perl -*-
#
# CMU::WebInt::errors
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

package CMU::WebInt::errors;
use strict;
use CMU::WebInt;
use CMU::Netdb;


use vars qw(@ISA @EXPORT @EXPORT_OK %err_p $ERR_TOP %errmeanings);

require Exporter;
@ISA = qw(Exporter);

$ERR_TOP = "/home/netreg/htdocs/help/errors";
%err_p = %{CMU::Netdb::makemap(\@CMU::Netdb::structure::error_fields)};
%errmeanings = %CMU::Netdb::errors::errmeanings;

## Error interface
sub err_lookup {
  my ($q) = @_;
  my ($dbh, $query, $sth, $res, @row, $url);

  $dbh = CMU::WebInt::db_connect();
  my ($user, $p, $r) = CMU::WebInt::getUserInfo();
  CMU::WebInt::setHelpFile('err_lookup');
  print CMU::WebInt::errhdr($q, $dbh, $user, "Errors");

  $url = $ENV{SCRIPT_NAME};

  my ($loc, $fields, $errcode) = (CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'location')),
				  CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'fields')),
				  CMU::Netdb::cleanse(CMU::WebInt::gParam($q, 'errcode')));


  if (!defined $errmeanings{$errcode}) {
    print &CMU::WebInt::subHeading("Unknown error code");
    print "<font face=\"Arial,Helvetica,Geneva,Charter\">
Unknown error code, no information available.</font>\n";
    print CMU::WebInt::stdftr($q);
    $dbh->disconnect();
    return;
  }

  $query = "SELECT ".join(',', @CMU::Netdb::structure::error_fields)."
FROM _sys_errors
WHERE errcode = '$errcode'
AND (errfields = '$fields' OR errfields = '')
AND (location = '$loc' OR location = '')
ORDER BY location desc, errfields desc LIMIT 0,1
";
  $sth = $dbh->prepare($query);
  $sth->execute();
  @row = $sth->fetchrow_array;
  if (!@row || !defined $row[0]) {
    print &CMU::WebInt::subHeading("No additional information");
    print "<font face=\"Arial,Helvetica,Geneva,Charter\">
The default meaning for error code $errcode is: $errmeanings{$errcode}.<br><br>
There is no additional information for this error.</font>\n";
  }else{
    print &CMU::WebInt::subHeading("Error Explanation");
    print "<font face=\"Arial,Helvetica,Geneva,Charter\">
The default meaning for error code $errcode is: $errmeanings{$errcode}.<br><br>
Additional information is available and may be helpful: <br>";
    print $row[$err_p{'_sys_errors.errtext'}];
  }
  print CMU::WebInt::stdftr($q);
  $dbh->disconnect();
}    

1;  





  


