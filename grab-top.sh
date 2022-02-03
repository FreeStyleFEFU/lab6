#!/bin/bash

# Grabs one output of the top program and returns 6 values separated by spaces
# cpu% total-memory used-memory buffered-memory cached qtcar-process-info

COLUMNS_PREV=$COLUMNS
export COLUMNS=512
top -b -n 2 -d0.2 | egrep "Tasks|Cpu|Mem|Swap:| QtCar" | grep -v -i defunct | awk '{ \
    if (match($0,"Tasks")) \
    { \
        task_count += 1; \
    } \
    else if (task_count == 2 && match($0,"Cpu")) \
    { \
        match($2,"[0-9.]*"); \
        printf("%s ", substr($2,1,RLENGTH)); \
    } \
    else if (task_count == 2 && match($0, "Mem")) \
        printf("%s %s %s ",$2,$4,$8); \
    else if (task_count == 2 && match($0, "Swap:"))\
        printf("%s ", $8); \
    else if (task_count == 2) \
        printf("%s=%s%%,%s;", $12, $9, $6);
}'
export COLUMNS=$COLUMNS_PREV