#! /bin/bash
# This script checks to see if the service in its argument is running
# and if it is, it restarts it. This is to restart "hung" services that
# have stopped heartbeating.

if status "$1" | grep running
then
    # Get some info from top about the process we're about to kill/restart
    pid=$(status "$1" | awk '/start/ {print $NF}')
    if [ -n "$pid" ] ; then
        export COLUMNS=400
        top -b -n 1 -c -p "$pid" | logger -t restart_service
    else
        logger -t restart_service "No PID for $1"
    fi

    /usr/local/bin/log-top

    # Jobs that use ALSA need to stop with failures, which SIGABRT should
    # accomplish. But just in case it doesn't, we need to
    # explicitly kill the process, since upstart's SIGTERM/SIGKILL will
    # not result in a failure, so it won't spawn the alsa-dshare-reset job.
    #
    # Also, always generate a backtrace from QtCar if it's killed
    if [[ "$1" = "qtcar-audiod" || \
          "$1" = "qtcar-mediaserver" || \
          "$1" = "qtcar-mediaserver2" || \
          "$1" = "qtcar-spotifyserver" || \
          "$1" = "qtcar-nav-audio" || \
          ("$1" = "qtcar" && "$2" = "dead") ]] ; then

        if [ -n "$pid" ] ; then
            logger -t restart_service "Sending SIGABRT to gather backtrace from $1 [$pid]"
            kill -ABRT "$pid"

            # Wait up to 15 seconds for the process to die
            COUNT=60
            while ((COUNT > 0)) ; do
                kill -0 "$pid" >/dev/null 2>&1 || break
                sleep 0.25
                COUNT=$((COUNT-1))
            done

            # If it's still not dead, kill it.
            if ((COUNT == 0)) ; then
                logger -t restart_service "Sending SIGKILL to $1 [$pid]"
                kill -KILL "$pid"
            fi
        fi
    else
        logger -t restart_service "Restarting $1"
        restart "$1"
    fi
fi
