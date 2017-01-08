#!/bin/bash
. /etc/default/nwws
/usr/bin/find $BASEDIR -name "*.log" -mtime +7 -delete
