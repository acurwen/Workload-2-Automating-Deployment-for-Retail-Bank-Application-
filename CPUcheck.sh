#!/bin/bash

# Checking CPU usage

# Isolating idle CPU from top output
idle_cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")
echo "Idle CPU: $idle_cpu"

# Removing decimal point to convert it to an integer
no_id=$(echo "$idle_cpu" | awk -F '.' '{print $1}')
echo "Idle CPU as an integer: $no_id"

# Calculating total CPU used 
cpu_used=$((100 - no_id))
echo "CPU Used: $cpu_used%"

# Stop processes if CPU exceeds 75.
if [ "$cpu_used" -ge 75 ]
        then
        echo "CPU limit reached. Shutting down process."
        #stop/kill a process here 

        else 
        echo "CPU usage is fine."
fi
