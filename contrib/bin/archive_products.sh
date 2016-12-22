#!/bin/bash
if [ "$1" = "" ]; then
	echo "Usage: $0 <days>"
	exit 1
fi
if [ -e "/etc/default/nwws"]; then
	. /etc/default/nwws
fi
if [ "$BASEDIR" = "" ]; then
	echo "Error: \$BASEDIR is not set."
	exit 1
fi
if [ "$DATADIR" = "" ]; then
	echo "Error: \$DATADIR is not set."
	exit 1
fi
ARCHIVE_FILE=$(date +"%Y%m%d.tar.gz")
# Create archive directory if it doesn't exist
if [ ! -d "$BASEDIR/archive/" ]; then
	mkdir $BASEDIR/archive/
fi
# Create tar.gz backup of products
/usr/bin/find $DATADIR -type f +mtime $1 -print0 | tar -czvf $BASEDIR/archive/$ARCHIVE_FILE --null -T -
# Done
exit 0
