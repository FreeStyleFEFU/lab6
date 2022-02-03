#!/bin/bash -x
#
# NAME
#
#	firmware-heartbeat.sh - tell our firmware server who and what we are
#
# SYNOPSIS
#
#	firmware-heartbeat.sh
#
# DESCRIPTION
#
#	Uses curl to post a Vehicle Hardware Configuration string and a platform_release
#
# BUGS
#
#	This version does not actually send the final version of the software or firmware configuration.
#	The system for naming software configurations has not been developed yet.
#
# AUTHOR
#
#	David Wuertele, dwuertele@teslamotors.com, 24 October 2011
#	Cribbed from UI/bin/heartbeat.sh by rduncan and ghuff
#	Copyright 2011 Tesla Motors

source /etc/firmware.conf

VIN=$(< /var/etc/vin)
VEHICLE_HARDWARE_CONFIGURATION_STRING=`/usr/local/bin/vehicle_hardware_configuration_string`

#  Wait until our VPN is up.
while ! /sbin/ifconfig tun0 | grep  "UP POINTOPOINT RUNNING"
do
  logger reboot "Status reporting still has no tun0.  sleeping"
  sleep 5
done

diag_vitals=`curl --max-time 30 http://localhost:4035/Debug/vitals`
# How to parse the carserver return json for a given field and set a variable to its value
read_diag_value () {
    eval $1=`echo $diag_vitals | awk -F"," -v k=$1 '{
        gsub(/{|}/,"")
        for (i=1; i<=NF; i++) {
            if ( $i ~ k ) {
                gsub (/\"/,"",$i)
                size = split ($i,a,/:/)
		result = a[2]
		for (j=3; j<=size; j++) {
		    result = result ":" a[j]
		}
		print result
            }
        }
    }'`
}

read_diag_value carver

if [ -f $latest_firmware_md5 ]
then
    md5=`cat $latest_firmware_md5`
    curl --max-time 30 -X POST http://firmware:4567/vehicles/$VIN/heartbeat --data-urlencode "vehicle_hardware_configuration_string=$VEHICLE_HARDWARE_CONFIGURATION_STRING" --data-urlencode "package_signature=$md5" --data-urlencode "platform_release_name=$carver"
else
    curl --max-time 30 -X POST http://firmware:4567/vehicles/$VIN/heartbeat --data-urlencode "vehicle_hardware_configuration_string=$VEHICLE_HARDWARE_CONFIGURATION_STRING" --data-urlencode "platform_release_name=$carver"
fi

# The above curl doesn't output a newline, but I don't like the way that looks when I run this command.  So here's a newline.
echo ""
