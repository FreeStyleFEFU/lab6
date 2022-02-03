#!/bin/bash
# Logs a serial stream to a file

AT_PORT="/dev/ttyUSB0"
LOG_FILE="nmea.log"
BAUD=4800

if [ ! -e "$AT_PORT" ]; then
    echo "$AT_PORT not found, exiting..."
    exit 1
fi

echo -e "Logging from ($AT_PORT)"
echo -e '\n'$(date) >> $LOG_FILE
stty -F $AT_PORT $BAUD raw -echo
while true; do
    cat $AT_PORT>>$LOG_FILE
done
