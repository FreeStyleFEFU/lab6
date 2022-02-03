#!/bin/sh
if [ "$1" = "" ]; then echo "usage: $0 path\n where path is an upstart .conf file (like in /etc/init)"; fi
(echo UPSTART_JOB=$(basename $1 .conf) ; \
 sed  -n '/^env/s/env/export/p' < $1 ; \
 sed  -n '/^pre-start script/,/^end/{/^pre-start script/n;/^end/n;p}' < $1 ;
 sed  -n '/^script/,/^end/{/^script/n;/^end/n;p}' < $1 ) | dash $2 

