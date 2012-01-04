#! /bin/sh

# Expect parameter 1: subnet, 2: time  , 3: value (dynamic) $4:$5 (static)
/usr/local/bin/rrdtool update $1 $2:$3 $4:$5
