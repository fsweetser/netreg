#! /bin/sh

NETREG_test-netdb_CONF=t-test-netdb-conf

export NETREG_test-netdb_CONF

./errors.pl
./helper.pl
./structure.pl
./primitives.pl

