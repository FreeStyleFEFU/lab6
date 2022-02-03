#!/bin/bash

if [[ "$1" = "--debug" ]] ; then
    set -x
    shift
    DEBUG="yes"
fi

# to know whether we're MCU or ICE
. /etc/tesla.env > /dev/null 2>&1
. /etc/RunQtCar.env > /dev/null 2>&1

PATH=/usr/sbin/:$PATH

zero_if_empty()
{
    local value
    value=${1:-0}
    echo "$value"
}

parse_iptables_bytes() {
    local ip_addr in_iface out_iface val
    ip_addr=192.168.90."$1"
    in_iface="$2"
    out_iface="$3"

    val=$(grep "${in_iface} *$out_iface" "$TMPFILE" | fgrep "$ip_addr" | head -1 | sed 's/ *[0-9]* *\([0-9]*\).*/\1/')
    zero_if_empty "$val"
}

parse_net_bytes_in() {
    local val
    val=$(fgrep "$1" "$TMPFILE" | awk '{print $2}')
    zero_if_empty "$val"
}

parse_net_bytes_out() {
    local val
    val=$(fgrep "$1" "$TMPFILE" | awk '{print $10}')
    zero_if_empty "$val"
}

umask 077 # to ensure the tmpfile is not world-writable
MYNAME=$(basename "$0")
TMPFILE=$(mktemp "/root/$MYNAME".XXXXXX) # /root is a tmpfs and 0700, so better for security

if [[ -z "$1" ]] ; then
    iptables -nvxL FORWARD | fgrep ACCEPT > "$TMPFILE"
else
    cat "$1" > "$TMPFILE"
fi
shift

if [[ "$DEBUG" = "yes" ]] ; then
    cat "$TMPFILE"
fi

if [ "$UI_TARGET" = "ICE" ] ; then
    APE_CELL_IN=$(parse_iptables_bytes 103 'eth0\.2' eth0)
    APE_CELL_OUT=$(parse_iptables_bytes 103 eth0 'eth0\.2')
    APE_WIFI_IN=$(parse_iptables_bytes 103 wlan0 eth0)
    APE_WIFI_OUT=$(parse_iptables_bytes 103 eth0 wlan0)
else
    [ "$UI_TARGET" != "MCU" ] && logger -t "$MYNAME" "Unexpected UI_TARGET: $UI_TARGET"
    APE_CELL_IN=$(($(parse_iptables_bytes 103 ppp0 toucan) + $(parse_iptables_bytes 103 wwan0 toucan)))
    APE_CELL_OUT=$(($(parse_iptables_bytes 103 toucan ppp0) + $(parse_iptables_bytes 103 toucan wwan0)))
    APE_WIFI_IN=$(parse_iptables_bytes 103 parrot toucan)
    APE_WIFI_OUT=$(parse_iptables_bytes 103 toucan parrot)
    IC_CELL_IN=$(($(parse_iptables_bytes 101 ppp0 toucan) + $(parse_iptables_bytes 101 wwan0 toucan)))
    IC_CELL_OUT=$(($(parse_iptables_bytes 101 toucan ppp0) + $(parse_iptables_bytes 101 toucan wwan0)))
    IC_WIFI_IN=$(parse_iptables_bytes 101 parrot toucan)
    IC_WIFI_OUT=$(parse_iptables_bytes 101 toucan parrot)
fi

if [[ -z "$1" ]] ; then
    cat /proc/net/dev > "$TMPFILE"
else
    cat "$1" > "$TMPFILE"
fi

if [[ "$DEBUG" = "yes" ]] ; then
    cat "$TMPFILE"
fi

if [ "$UI_TARGET" = "ICE" ] ; then
    CELL_IN=$(parse_net_bytes_in eth0.2)
    CELL_OUT=$(parse_net_bytes_out eth0.2)
    WIFI_IN=$(parse_net_bytes_in wlan0)
    WIFI_OUT=$(parse_net_bytes_out wlan0)
else
    CELL_IN=$(($(parse_net_bytes_in ppp0) + $(parse_net_bytes_in wwan0)))
    CELL_OUT=$(($(parse_net_bytes_out ppp0) + $(parse_net_bytes_out wwan0)))
    WIFI_IN=$(parse_net_bytes_in parrot)
    WIFI_OUT=$(parse_net_bytes_out parrot)
fi

PARAMS="cell_in=$CELL_IN&cell_out=$CELL_OUT&wifi_in=$WIFI_IN&wifi_out=$WIFI_OUT"
PARAMS="${PARAMS}&ape_cell_in=$APE_CELL_IN&ape_cell_out=$APE_CELL_OUT&ape_wifi_in=$APE_WIFI_IN&ape_wifi_out=$APE_WIFI_OUT"
if [ "$UI_TARGET" = "MCU" ] ; then
    PARAMS="${PARAMS}&ic_cell_in=$IC_CELL_IN&ic_cell_out=$IC_CELL_OUT&ic_wifi_in=$IC_WIFI_IN&ic_wifi_out=$IC_WIFI_OUT"
fi

if [[ "$DEBUG" = "yes" ]] ; then
    echo "$PARAMS" | tr '&' '\n'
else
    curl --max-time 10 --silent "http://localhost:4032/send_network_data?${PARAMS}"
fi

rm -f "$TMPFILE"
