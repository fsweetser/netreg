package vars_l;

use strict;

use vars qw/@ISA @EXPORT 
            $NRHOME $NRLIB
           /;

require Exporter;

@ISA = qw/Exporter/;

@EXPORT = qw/
             $NRHOME $NRLIB
            /;

#########################################################333
##
## NetReg Home Directory
$NRHOME = '/home/netreg';

## NetReg library path
$NRLIB = $NRHOME.'/lib';
