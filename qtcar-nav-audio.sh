#!/bin/bash

TAG=${1-qtcar-nav-audio}
TOP=${2-/tmp/nav-audio}

# This script assumes that it is being invoked as the main process of
# an upstart job.  Upstart arranges for the job to run in a new
# process group, and this means that when we detect a failure we can
# use pkill to send a TERM signal to all the processes in the job.
# pkill lets us use group 0 to indicate the process group of pkill
# itself, which contains all the other processes invoked by this
# script, so we don't need to explicitly track any process IDs.

# The basic scheme here is that we have one process that uses socat to
# listen on a server socket and creates a file in WAITDIR.  When it
# has a complete transfer it moves that file into PLAYDIR.  We have a
# second process that uses inotify to wait for the file to be moved
# in, whereupon it feeds it to aplay.

if [ "$TOP/" = / ]; then exit 1; fi

rm -rf $TOP/*
PLAYDIR=$TOP/playing
WAITDIR=$TOP/waiting
mkdir -p $PLAYDIR
mkdir -p $WAITDIR

logger "TOP=$TOP WAITDIR=$WAITDIR PLAYDIR=$PLAYDIR"

# We have a pipeline set up to capture the output from the rplay and
# socat commands, and we want to catch their exit status.  If either
# of these fail we want to kill this script and propagate the status
# back to upstart.
set -o pipefail

# The process that waits for MOVED_TO events in PLAYDIR.
inotifywait -q -m -e moved_to $PLAYDIR | \
while read DIR EVENT FILE
do
    # logger -t $TAG "DIR=$DIR EVENT=$EVENT FILE=$FILE"
    PLAYFILE=${DIR}${FILE}

    # There appears to be a bug in ALSA where if the requested sample
    # rate is an exact integer fraction of what the hardware provides
    # then it refuses to accept it.  When we were running at 48 kHz we
    # didn't hit this issue, but Rev-E boards run at 44.1 kHz and now
    # we have a problem.
    #
    #RATE=22050
    RATE=22049

    if ! rplay -D navigation -c 1 -r $RATE -f S16_LE $PLAYFILE |& logger -t $TAG
    then
	logger -t $TAG "Sending TERM to process group because rplay pipeline failed"
	pkill -TERM -g 0
    fi

    rm -f $PLAYFILE
done &

# The process that runs the server.
while true
do
    WAITFILE=$(tempfile -d $WAITDIR)

    if ! socat -u tcp-listen:4102,reuseaddr $WAITFILE |& logger -t $TAG
    then
	logger -t $TAG "Sending TERM to process group because socat pipeline failed"
	pkill -TERM -g 0
    fi

    mv $WAITFILE $PLAYDIR
done
