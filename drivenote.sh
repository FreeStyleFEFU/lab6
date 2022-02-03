#!/bin/bash
# args
#  screenshot - true/false
#  description

if [[ $1 == --debug ]] ; then
  set -x
  set -e
  shift
fi

. /etc/tesla.env
. /etc/RunQtCar.env

TESLA_SS_DIR=$TESLA_HOME/.Tesla/data/screenshots/
TESLA_CAP_DIR=$TESLA_HOME/.Tesla/data/drivenotes
mkdir -p $TESLA_CAP_DIR

CAP_DATE=$(date "+%Y-%m-%d-%H:%M:%S")
OUTPUT_FILE=$TESLA_CAP_DIR/note.$CAP_DATE.txt

echo "File: $OUTPUT_FILE" > $OUTPUT_FILE
echo "Description: $2" >> $OUTPUT_FILE

VIN=$(cat /var/etc/vin)
echo "Vin: $VIN" >> $OUTPUT_FILE

target_mcu()    { [ "$UI_TARGET" = "MCU" ]; }
target_ice()    { [ "$UI_TARGET" = "ICE" ]; }

platform_m3()   { [ "$UI_PLATFORM" = "M3" ]; }
platform_sx()   { [ "$UI_PLATFORM" = "SX" ]; }

have_cluster()  { platform_sx; }
have_ic_host()  { target_mcu; }

screenshot()
{
    URL=$1
    # The screenshot service returns the file path in JSON. Print just
    # this value so it can be added to the drivenote log.
    curl -s $URL | jq -r '.["_rval_"]' 2>/dev/null
}

centerdisplay_screenshot()
{
  if target_mcu ; then
    # TODO: fix tegra builds so screenshot service works
    is-development-car && SS_ARGS="" || SS_ARGS="--silent"
    LD_LIBRARY_PATH=$TESLA_LIB $TESLA_BIN/QtCarScreenshot $SS_ARGS
    LAST_CID_SS="$(ls -t $TESLA_SS_DIR | head -1)"
    LAST_CID_SS="$TESLA_SS_DIR/$LAST_CID_SS"
  else
    is-development-car && SS_MESSAGE="Saved%20display%20screenshot" || SS_ARGS=""
    LAST_CID_SS=$(screenshot "http://localhost:4070/screenshot?popupMessage=$SS_MESSAGE")
  fi

  echo >> $OUTPUT_FILE
  echo "CID Screenshot: $LAST_CID_SS" >> $OUTPUT_FILE
}

clusterdisplay_screenshot()
{
  if have_ic_host ; then
    # TODO: fix tegra builds so screenshot service works
    sudo ssh ic "su - tesla -c '. /etc/tesla.env; LD_LIBRARY_PATH=$TESLA_LIB $TESLA_BIN/QtCarScreenshot $SS_ARGS'"
    LAST_IC_SS=$(sudo ssh ic "ls -t $TESLA_SS_DIR | head -1")
    LAST_IC_SS="$TESLA_SS_DIR/$LAST_IC_SS"
  else
    LAST_IC_SS=$(screenshot "http://localhost:4130/screenshot")
  fi

  echo "IC Screenshot: $LAST_IC_SS" >> $OUTPUT_FILE
}

# get cid and ic screenshots early to indicate visually we're doing something
if [ "$1" = "true" ]
then
  centerdisplay_screenshot

  if have_cluster ; then
    clusterdisplay_screenshot
  fi
fi

# get process info
printf "\n\n-------------------- CID PROCESSES\n" >> $OUTPUT_FILE
ps -AwwL -o pid,ppid,tid,pcpu,vsize,rss,tty,psr,nwchan,wchan:42,stat,start,time,command >> $OUTPUT_FILE
if have_ic_host ; then
  printf "\n\n-------------------- IC PROCESSES\n" >> $OUTPUT_FILE
  sudo ssh ic "ps -AwwL -o pid,ppid,tid,pcpu,vsize,rss,tty,psr,nwchan,wchan:42,stat,start,time,command" >> $OUTPUT_FILE
fi

# save all published data values
printf "\n\n-------------------- DATA VALUES\n" >> $OUTPUT_FILE
curl -s "http://localhost:4035/get_data_values?format=csv&show_invalid=true" >> $OUTPUT_FILE

# get network config and stats
printf "\n\n-------------------- NETWORK CONFIGURATION/STATS\n" >> $OUTPUT_FILE
ifconfig >> $OUTPUT_FILE
sudo nme -a >> $OUTPUT_FILE 2>/dev/null
sudo netstat -s >> $OUTPUT_FILE

# get disk stats
printf "\n\n-------------------- CID DISK INFO\n" >> $OUTPUT_FILE
df >> $OUTPUT_FILE
if ! target_ice ; then # busybox df does not support inode option
  echo >> $OUTPUT_FILE
  df -i >> $OUTPUT_FILE
fi

if have_ic_host ; then
  printf "\n\n-------------------- IC DISK INFO\n" >> $OUTPUT_FILE
  sudo ssh ic "df" >> $OUTPUT_FILE
  echo >> $OUTPUT_FILE
  sudo ssh ic "df -i" >> $OUTPUT_FILE
fi

# other system info
if target_mcu ; then
  printf "\n\n-------------------- DSPT\n" >> $OUTPUT_FILE
  sudo tail -250 /var/log/dspt.log >> $OUTPUT_FILE
else
  echo >> $OUTPUT_FILE
  if platform_m3 ; then
    # Only the Model3 platform has the ability to check the speakers
    # and doing so on Info1/2 causes an audible pop
    AUDIOOPTIONS="check-speakers"
  fi
  AUDIOLOGS=$(/usr/bin/audiologs.sh $AUDIOOPTIONS)
  echo "Audiologs: $AUDIOLOGS" >> $OUTPUT_FILE
fi
printf "\n\n-------------------- LSUSB\n" >> $OUTPUT_FILE
sudo lsusb -v >> $OUTPUT_FILE

# display status
if target_ice ; then
  printf "\n\n-------------------- DISPLAYS\n" >> $OUTPUT_FILE
  ice-display >> $OUTPUT_FILE
fi

# post vitals to mothership
sudo $TESLA_BIN/mothership.sh vitals

# get memory stats
printf "\n\n-------------------- CID MEMORY INFO\n" >> $OUTPUT_FILE
cat /proc/meminfo >> $OUTPUT_FILE
echo >> $OUTPUT_FILE
cat /proc/zoneinfo >> $OUTPUT_FILE
echo >> $OUTPUT_FILE
slabtop -o -s c >> $OUTPUT_FILE
if have_ic_host ; then
  printf "\n\n-------------------- IC MEMORY INFO\n" >> $OUTPUT_FILE
  sudo ssh ic "cat /proc/meminfo" >> $OUTPUT_FILE
  echo >> $OUTPUT_FILE
  sudo ssh ic "cat /proc/zoneinfo" >> $OUTPUT_FILE
  echo >> $OUTPUT_FILE
  sudo ssh -t ic "slabtop -o -s c" >> $OUTPUT_FILE
fi
