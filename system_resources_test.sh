#!/bin/bash

# Checking memory
# Isolating used MEM from top output

used_mem1=$(top -b -n1 | grep "MiB Mem" | awk '{print $6}')

# Removing everything after the decimal point to convert it to an integer
used_mem2=${used_mem1%.*}

# Check if used memory exceeds 900 MiB
if [ "$used_mem2" -gt 900 ]
then
    echo "Memory use ("$used_mem2" MiB) exceeds the threshold of 900 MiB. Exiting script."
    exit 1
else
    echo "Memory use is within limits."
fi

