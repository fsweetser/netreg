#!/bin/sh
#
# DHCP Configuration file updater:: 
# Kevin Miller/Ros Neplokh, Carnegie Mellon University, 2001
# netreg-bugs@andrew.cmu.edu
#
PATH=/bin:/usr/bin:/usr/local/bin
HOSTNAME=`hostname`
ORIG=/home/netreg/etc/dhcp-xfer/dhcpd.conf.$HOSTNAME
MAIL=your.email.address@example.org

cd /home/iscdhcpd/scripts
cp $ORIG dhcpd.conf.new
gdiff /etc/dhcpd.conf dhcpd.conf.new > /dev/null
if [ $? != "0" ]; then
        /home/iscdhcpd/sbin/dhcpd -t -cf dhcpd.conf.new > config.test 2>&1
        if [ $? != "0" ]; then
                cat config.test | mail -s "generate.sh: $HOSTNAME failed to load dhcpd.conf" $MAIL
        else    
                mv dhcpd.conf.new /etc/dhcpd.conf
        fi
fi
