#!/bin/bash

if [ "$1" = "--debug" ]; then
        set -x
        shift
fi

# Send a simple command to the mothership. Currently only used to
# send the heartbeat message and the going-to-sleep message.  Could
# be extended to send commands with interesting parameters, but
# right now the commands don't have any.

COMMAND="$1"

MOTHERSHIP_HOST="mothership.vn.teslamotors.com"
MOTHERSHIP_PORT="4567"
DT=$(date)
MAX_TIME=15

# Check that there is a connection to Mothership regardless of
# whether over the VPN or Hermes.
STATUS=$(curl --silent \
              --verbose \
              --max-time "$MAX_TIME" \
              --location \
              --write-out "%{http_code}" \
              --output /dev/null \
              http://"$MOTHERSHIP_HOST":"$MOTHERSHIP_PORT"/status)
if [ $STATUS -ne 200 ]; then
    echo "$DT No connection to Mothership, exiting..."
    exit
fi

VIN=$(< /var/etc/vin)

# Release builds report the true version; other builds report a special identifier
source /etc/tesla.env
if ! grep -q DEV "$TESLA_BIN"/origin.txt; then
    VER=$(/usr/local/bin/lv VAPI_carVersionString | sed 's/"//g')
else
    VER=999.9.9
fi

# CID:
#    # lv LINK_linkState
#    "PreferWifi"
#
# ICE:
#    # lv LINK_linkState
#    "wifi"
LINKWIFI=$(/usr/local/bin/lv LINK_linkState | grep -i wifi)
WIFI=""
if [ -n "$LINKWIFI" ]; then
  WIFI="--data-ascii wifi=true"
fi

VITALS_DIR=""
VITALS="vitals="
if [ "$COMMAND" = "going_to_low_power" ] || [ "$COMMAND" = "going_to_sleep" ] || [ "$COMMAND" = "shutting_down" ] || [ "$COMMAND" = "vitals" ]; then
    VITALS_DIR=$(mktemp -d -t mothership-XXXXXX)
    VITALS_JSON="$VITALS_DIR"/vitals.json

    curl --silent \
         --verbose \
         --max-time "$MAX_TIME" \
         --output "$VITALS_JSON" \
         "http://localhost:4035/vitals?raw=true"

    VITALS="vitals@$VITALS_JSON"
    VITALS_SIZE=$(cat "$VITALS_JSON" | wc -c)

    curl --silent \
         --verbose \
         --max-time "$MAX_TIME" \
         "http://localhost:4035/mothership_bandwidth?bytes=$VITALS_SIZE"
fi

STAY_ONLINE=$(/usr/local/bin/lv POWER_sleepStayOnline)
MANAGER_STATE=$(/usr/local/bin/lv POWER_managerState)

LOW_POWER=""
if [ "$STAY_ONLINE" = '"true"' ] && [ "$MANAGER_STATE" = '"Gateway_Sleep"' ]; then
    LOW_POWER="--data-ascii low_power=true"
fi

if [ -n "$VIN" ] && [ "$VIN" != "vinisempty" ] && [ "$VIN" != "unknown" ]; then
   echo "Sending $COMMAND to mothership ($MOTHERSHIP_HOST) with VIN $VIN version $VER $WIFI $LOW_POWER"
   curl --silent \
        --verbose \
        --max-time "$MAX_TIME" \
        --data-ascii "current_version=$VER" \
        --data-urlencode "$VITALS" \
        $WIFI \
        $LOW_POWER \
        "http://$MOTHERSHIP_HOST:$MOTHERSHIP_PORT/vehicles/$VIN/$COMMAND"
   echo ""
fi

[ -d "$VITALS_DIR" ] && rm -rf "$VITALS_DIR"

# Force a true result
exit 0
