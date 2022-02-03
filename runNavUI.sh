#/bin/bash
cd $(dirname $0)
readlink $0 && cd $(dirname $(readlink $0))

export TESLA_GW=192.168.90.102
export TESLA_HOME=/home/tesla

if [ "$HOME" = "/root" ]; then HOME=$TESLA_HOME; fi

MAPS=$(sed -n 's/MapPath.*= //p' ./NaviKernelConf.ini | tr -d '\r\n' )
if [ ! -r $MAPS/. ]; then echo "ERROR: Maps directory $MAPS not readable.  Is it mounted?"; exit 1; fi


[ "$DISPLAY" != "" ] || export DISPLAY=:0
export LD_LIBRARY_PATH=`dirname $PWD`/lib:/usr/lib/qt-4.7.2/lib:/usr/lib:/lib


DEV='--dev'
WIN=
RUNNAV=
RUN=
RUNUI=
RUNNAV=
if [ $(id -u) = 0 ]; then
    RUNSTARTUP=
    RUN="sudo -u tesla env LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
    RUNUI="$RUN"
    RUNNAV="$RUN"
else
    RUNSTARTUP="sudo env LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi


while [ "$1" != "" ]; do
case "$1" in
"-dev")    DEV="--dev";; # --listen localhost" ;;
"-local")    DEV="--dev --listen localhost" ;;
"-car")    DEV="--gw $TESLA_GW"; UDP="--udp :20101" ;;
"-window") WIN='--window 1.0' ;;
"-scale")  WIN="--window $2"; shift ;;
"-no-navserver") RUNNAV=: ;;
"-no-startup") RUNSTARTUP=: ;;
"-gps") GPS="-gps $2"; shift;;
"-no-base") RUNSTARTUP=: ; RUN=: ;;
*)  break;;
esac

shift
done

function cleanup() {
    JOBS=`jobs -p`;
    for j in $JOBS; do
        echo killing $j
        sudo kill $j
    done
}

trap "cleanup;" EXIT
NAVOPTS="$DEV --rotate 180 --audio ${QCSUBNET}.${QCNA}${QCNAPORT} --gpsservice --debug GpsSource=All"

$RUNSTARTUP ./QtCarStartup &
#$RUN ./QtCarVehicle $DEV --car ModelS &
$RUN ./QtCarNetManager $DEV $GPS &
$RUNNAV     ./QtCarNavServer  $DEV  $NAV_OPTS "$@" &
$RUNUI      ./QtCarNavUI $DEV $WIN $UDP --car ModelS "$@" &

wait
