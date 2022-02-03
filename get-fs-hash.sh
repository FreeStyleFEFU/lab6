#!/bin/bash
find $1 -printf "%P\n" | md5sum | awk '{ print $1 }'
