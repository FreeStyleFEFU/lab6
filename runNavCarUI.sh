#/bin/bash
cd $(dirname $0)
readlink $0 && cd $(dirname $(readlink $0))

QTSDK=${QTSDK:-qtsdk-2010.02}
QTDIR=${QTDIR:-$HOME/$QTSDK}
QTGRAPHICS="raster"
QCSUBNET=${QCSUBNET:-192.168.90}
QCIC=${QCIC:-101}
QCCID=${QCCID:-100}
QCGW=${QCGW:-102}
QCPORT=":20101"
QCTDEV="/dev/ttyHS3"
QCTOUCH="--touch $QTCDEV"
QCAPLAY=":4111"

QCNUIARGS="--gpssvc $QTCDEV --gw ${QCSUBNET}.${QCGW} --udp ${QCSUBNET}.${QCGW}${QCPORT} --audio ${QCSUBNET}.${QCCID}${QCAPLAY}"

MAPS=$(sed -n 's/MapPath.*= //p' ./NaviKernelConf.ini | tr -d '\r\n' )
if [ ! -r $MAPS/. ]; then echo "ERROR: Maps directory $MAPS not readable.  Is it mounted?"; exit 1; fi

DEV=$(echo "$@" | tr ' ' '\n' | grep -e '--dev')
GDB=$(echo "$@" | tr ' ' '\n' | grep -e '^--gdb' | tail -1)

[ "$DISPLAY" != "" ] || export DISPLAY=:0
export LD_LIBRARY_PATH=`dirname $PWD`/lib:${LD_LIBRARY_PATH:-/lib}

GDBCMD="gdb --args";

case "$GDB" in
"--gdbremserver")  GDBCMD="gdbserver :7777" ;;
"--gdbremui")      GDBCMD="gdbserver :8888" ;;
esac


trap "{ kill %1 %2; }" EXIT

case "$GDB" in
"--gdbserver"|"--gdbremserver" )
    ./QtCarNavUI ${QCNUIARGS} "$@" &
    ${GDBCMD} ./QtCarNavServer --gpssvc $DEV "$@"
;;
"--gdbui"|"--gdbremui")
    (sleep 15; ./QtCarNavServer --gpssvc $DEV "$@" ) &
    ${GDBCMD} ./QtCarNavUI ${QCNUIARGS} "$@"
;;
*)
    ./QtCarNavServer $DEV --gpssvc "$@" &
    sleep 1
    ./QtCarNavUI ${QCNUIARGS} "$@" &
    wait
;;
esac
