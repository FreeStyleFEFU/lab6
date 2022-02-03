#/bin/bash
if [ ! -r /dev/ttyUSB5 ]; then echo "GPS not readable on ttyUSB5"; exit 1; fi
cd $(dirname $(readlink $0 || echo $0))
[ "$DISPLAY" != "" ] || export DISPLAY=:0
export LD_LIBRARY_PATH=`dirname $PWD`/lib:$LD_LIBRARY_PATH
./QtCarNavServer  &
#gdbserver :9999 ./QtCarNavServer  &
#sleep 7
./QtCarNavUI --gps /dev/ttyUSB5@4800 --touch /dev/ttyHS2 "$@" &

trap "{ kill %1 %2; }" EXIT
wait



