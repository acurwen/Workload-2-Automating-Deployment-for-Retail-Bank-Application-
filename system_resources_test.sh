 1 #!/bin/bash
 2 
 3 # Checking memory
 4 # Isolating used MEM from top output
 5 used_mem1=$(top -b -n1 | grep "MiB Mem" | awk '{print $6}')
 6
 7 # Removing everything after the decimal point to convert it to an integer
 8 used_mem2=${used_mem1%.*}
 9
10 # Check if used memory exceeds 900 MiB
11 if [ "$used_mem2" -gt 900 ]; then
12   echo "Memory use ("$used_mem2" MiB) exceeds the threshold of 900 MiB. Exiting script."
13   exit 1
14 else
15   echo "Memory use is within limits."
16 fi
17
