#!/bin/bash
df -h -l | egrep "/$|/home$|/var$"  | awk '{ printf("%s:%s; ", $6, $4) }'
echo ""
