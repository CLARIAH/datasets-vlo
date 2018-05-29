#!/bin/bash

# Replaces all placeholders in the format of "${XYZ}" with the value of environment
# variable XYZ. If no value is found for one of the specified environment variables, the
# script terminates with a non-zero exit code.
# 

if [ "$#" -le 1 ]; then
	echo "Usage: $0 path-to-file [variable-names....]"
	exit 1
fi

# Target file location
TARGET_FILE=$1

if [ -z "$TARGET_FILE" ]
then
	echo "Please provide the location of the file to be filtered"
	exit 1
fi

if [ ! -f "$TARGET_FILE" ]
then
	echo "$TARGET_FILE: file not found"
	exit 1
fi

shift

echo "Looking up $# placeholder values for ${TARGET_FILE}"

SED_COMMAND=""

for v in $@
do
	echo $v
	# ugly eval call to allow looping through options/environment variables and assigning default values if set
	val=$(eval echo \${${v}\})
	if [ -z "${val+x}" ]
	then
		echo "Error: environment variable ${v} not set"
		exit 1
	fi
	echo "\${$v} -> ${val} -> ${val//\//\\/}"
	SED_COMMAND+="s/\${${v}}/${val//\//\\/}/g;"
done

echo "Substituting placeholder values in ${TARGET_FILE}"
echo $SED_COMMAND
sed -i -e "$SED_COMMAND" $TARGET_FILE
