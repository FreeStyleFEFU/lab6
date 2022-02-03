#!/bin/bash

# quickscan2 by Thomas Z

### ASSUMPTIONS ###
# requires /home/tesla/.Tesla/data/odin_params_[platform].json where [platform]= "model3" or "modelsx"
# syslogs in /var/log/syslog
# klog in /var/log/klog
# tai64 syslog format @400000005af0c7860b4bfd9c.[su]
# timestamps are PDT

# Check inputs
if [ -z "$1" ]; then
	echo "platform argument not found"
	exit 1
fi

if [ -z "$2" ]; then
	echo "num_files argument not found"
	exit 1
fi

platform="$1"
num_files="$2"
counter=0
start=$(date +%s)

# Setup
quickscan_version="v1.00"
params_path="/home/tesla/.Tesla/data/odin_params_$platform".json
run_time=$(date "+%Y-%m-%d_%H:%M:%S")

# Check if file is empty or non-existent
if [[ ! -s $params_path || ! -e $params_path ]]; then
	echo "Odin parameters file not found, unable to continue"
	exit 1
elif [[ ! $(jq '.quickscan2 | .metadata? and .syslogs? and .klog?' "$params_path") == "true" ]]; then
	echo "Data missing from Odin parameters file, check $params_path"
	exit 1
fi

OUTPUT="/var/run/quickscan_$run_time"_results
touch "$OUTPUT" /var/run/fixed_strings /var/run/klog_strings

# Read parameters
keywords_json=$(jq '.quickscan2' "$params_path")
params_version=$(echo "$keywords_json" | jq -r '.metadata | .version')
fixed_strings=$(echo "$keywords_json" | jq -r '.syslogs | .fixed_strings | .[]')
regex_to_ignore=$(echo "$keywords_json" | jq -r '.syslogs |.regex_to_ignore')
klog_strings=$(echo "$keywords_json" | jq -r '.klog | .fixed_strings | .[]')
echo "$fixed_strings" > /var/run/fixed_strings
echo "$klog_strings" > /var/run/klog_strings

# Populate arrays of keywords to count
# Use IFS to preserve spaces in keywords
IFS=$'\n' read -r -d '' -a syslog_counts \
  < <( jq -r '.syslogs | .patterns_to_count | .[]' <<< "$keywords_json")
IFS=$'\n' read -r -d '' -a klog_counts \
  < <( jq -r '.klog | .patterns_to_count | .[]' <<< "$keywords_json")

# Output header
echo "Quickscan version:  $quickscan_version" > "$OUTPUT"
echo "Parameters version: $params_version" >> "$OUTPUT"
echo >> "$OUTPUT"

# Generate list of syslogs
cd /var/log/syslog || exit 1
syslog_list=$(ls @4* | tail -n "$num_files")

### SYSLOG parsing ###
echo "Searching across the last $num_files syslogs plus latest" >> "$OUTPUT"
for pattern in "${syslog_counts[@]}"; do
	counter=0
	echo -ne "\\t$pattern: " >> "$OUTPUT"
	for logfile in $syslog_list; do
		temp=$(zegrep "$pattern" "$logfile" | egrep -v "$regex_to_ignore" | wc -l)
		counter=$(( counter + temp ))
	done
	temp=$(egrep "$pattern" current | egrep -v "$regex_to_ignore" | wc -l)
	counter=$(( counter + temp ))
	echo "$counter" >> "$OUTPUT"
done

echo >> "$OUTPUT"

for logfile in $syslog_list; do
	timestamp=$(echo "$logfile" | tai64 | sed 's/\.[0-9]*\.[su]//')
	echo "Syslog $logfile up to $timestamp PDT:" >> "$OUTPUT"
	zfgrep -f /var/run/fixed_strings "$logfile" | egrep -v "$regex_to_ignore" >> "$OUTPUT"
done
echo "Most recent syslog:" >> "$OUTPUT"
fgrep -f /var/run/fixed_strings current | egrep -v "$regex_to_ignore" >> "$OUTPUT"

# Generate list of klogs
cd /var/log/klog || exit 1
klog_list=$(ls @4* | tail -n "$num_files")

{ echo; echo; } >> "$OUTPUT"

### KLOG parsing ###
echo "Searching across the last $num_files klogs plus latest" >> "$OUTPUT"
for pattern in "${klog_counts[@]}"; do
	counter=0
	echo -ne "\\t$pattern: " >> "$OUTPUT"
	for logfile in $klog_list; do
		temp=$(zegrep "$pattern" "$logfile" | wc -l)
		counter=$(( counter + temp ))
	done
	temp=$(egrep "$pattern" current | wc -l)
	counter=$(( counter + temp ))
	echo "$counter" >> "$OUTPUT"
done

echo >> "$OUTPUT"

for logfile in $klog_list; do
	timestamp=$(echo "$logfile" | tai64 | sed 's/\.[0-9]*\.[su]//')
	echo "Klog $logfile up to $timestamp PDT:" >> "$OUTPUT"
	zfgrep -f /var/run/klog_strings "$logfile" >> "$OUTPUT"
done
echo "Most recent Klog:" >> "$OUTPUT"
fgrep -f /var/run/klog_strings current >> "$OUTPUT"


# Finish
rm /var/run/klog_strings
rm /var/run/fixed_strings
end=$(date +%s)
runtime=$((end-start))
{ echo; echo "Quickscan complete in $runtime seconds"; } >> "$OUTPUT"

cat "$OUTPUT"

