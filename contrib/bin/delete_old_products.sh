#!/bin/bash
. /etc/default/nwws
/usr/bin/find $DATADIR -type f -mtime +2 -delete
