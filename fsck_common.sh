#!/bin/bash

# Shared fsck functions on USB drives

# fsck and then verify if fsck actually fixes the problem
# param 1 - the device to be checked
# param 2 - the path to the fsck tool
# param 3 - the arg to give to the fsck tool to fix fs
fsck_and_verify () {
    if "$2" "$3" "$1" ; then
        log info "fsck: No errors on partition. Mounting."
    else
        result=$?

        # FSCK return codes 2="reboot the system" 128="Shared library error"
        # Let's hope to not have to reboot the system by not mounting.
        if [ "$(( ( $result & 2 ) || ( $result & 128 ) ))" -gt 0 ] ; then
            log info "fsck: Reported status $result. fsck might have crashed. Will not mount."
            return $result
        fi

        log info "fsck: Reported status $result. Checking if fixed."

        # common to all fsck tools:
        #      -n no-op,check non-interactively without changing
        if "$2" -n "$1" ; then
            log info "fsck: Fixed! Mounting."
        else
            result=$?
            log info "fsck: Still reported error $result. Will not mount."
            return $result
        fi
    fi
    return 0
}
