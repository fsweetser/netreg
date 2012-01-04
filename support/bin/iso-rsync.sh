#!/bin/bash

DUMP_DIR=/home/netreg/data/dumps
WORK_DIR=$DUMP_DIR/iso-dumps
EXCLUDE_TABLES="dns_zone attribute attribute_spec"
NRHOME=`grep "^NRHOME" /etc/netreg-netdb.conf | grep -v "^#" | awk 'BEGIN {FS="= "}{print $2}'`
export NRHOME
RSYNC_OPTIONS=`grep RSYNC_OPTIONS /etc/netreg-netdb.conf | grep -v "^#" | awk 'BEGIN {FS="= "}{print $2}'`
export RSYNC_OPTIONS
#This gets $NRHOME eval'ed in the context of RSYNC_RSH. Probably could be cleaner, but it works.
RSYNC_RSH=`grep "^RSYNC_RSH" /etc/netreg-netdb.conf | grep -v "^#" | awk 'BEGIN {FS="= "}{print $2}' | awk 'BEGIN {FS=".NRHOME"}{printf "%s %s%s", $1, ENVIRON["NRHOME"], $2}'`
export RSYNC_RSH
RSYNC_PATH=`grep "^RSYNC_PATH" /etc/netreg-netdb.conf | grep -v "^#" | awk 'BEGIN {FS="= "}{print $2}'`
export RSYNC_PATH
RSYNC_REM_USER=netreg
RSYNC_TIMEOUT=30

if [ ! -d $WORK_DIR ]; then
	echo "Work directory $WORK_DIR does not exist: creating..."
	mkdir $WORK_DIR
	if [ $? -ne 0 ];  then
		echo "Could not create work directory $WORK_DIR. Exiting..."
		return 1;
	else 
		echo "Created."
	fi
fi

LAST_BKP=`ls -t $DUMP_DIR/*tgz | head -1`;

echo "Last backup is $LAST_BKP. Moving to $WORK_DIR..."

cp "$LAST_BKP" "$WORK_DIR"

if [ $? -ne 0 ];  then
	echo "Could not copy $LAST_BKP to $WORK_DIR. Exiting..."
        return 1;
else 
	echo "Moved."
fi

echo "Unzipping backup..."

cd $WORK_DIR

tar xzvfp $LAST_BKP

if [ $? -ne 0 ];  then
	echo "Could not unzip $LAST_BKP. Exiting..."
        return 1;
else 
	echo "Unzipped."
fi


echo "Clearing data from requested tables"

WORK_BACKUP_DIR=`echo $LAST_BKP | awk 'BEGIN {FS="/"}{print $(NF)}' | awk 'BEGIN {FS=".tgz"}{print $1}'`

echo "Working directory is $WORK_BACKUP_DIR"

cd $WORK_DIR/$WORK_BACKUP_DIR

for i in `echo $EXCLUDE_TABLES`
do
	echo -n "Deleting data for table $i..."
	> $i.txt
	echo "done."
done

echo -n "Deleting old zip file..."

rm $LAST_BKP

if [ $? -ne 0 ];  then
	echo "Could not delete $LAST_BKP. Exiting..."
        return 1;
else 
	echo "deleted."
fi
echo "Re-zipping the archive..."

cd $WORK_DIR

tar cvzfp $LAST_BKP $WORK_BACKUP_DIR

if [ $? -ne 0 ];  then
	echo "Could not zip $LAST_BKP. Exiting..."
        return 1;
else 
	echo "Zipped."
fi

echo -n "Deleting unzipped archive..."

rm -rf $WORK_DIR/$WORK_BACKUP_DIR

if [ $? -ne 0 ];  then
	echo "Could not delete $WORK_DIR/$WORK_BACKUP_DIR. Exiting..."
        return 1;
else 
	echo "Deleted."
fi

SHORT_BKP_NAME=`echo $LAST_BKP | awk 'BEGIN {FS="/"}{print $(NF)}'`
echo "short is $SHORT_BKP_NAME"
 
cd $WORK_DIR

echo "Running: $RSYNC_PATH $RSYNC_OPTIONS $LAST_BKP $RSYNC_REM_USER@iso-db-01.andrew.cmu.local:/iso/netdb/$SHORT_BKP_NAME"
$RSYNC_PATH $RSYNC_OPTIONS $LAST_BKP $RSYNC_REM_USER@iso-db-01.andrew.cmu.local:/iso/netdb/$SHORT_BKP_NAME
