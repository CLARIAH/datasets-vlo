#!/usr/bin/env bash
if [ -z "$1" ]; then
	echo "Usage: $0 <expected-hostname>"
	exit 1
fi

if [ "$1" != "$(hostname)" ]; then
	echo "WARNING: Unexpected hostname - this may not be the right environment!"
	echo "Expected: $1"
	echo "Found: $(hostname)"
	echo ""
	echo -n "Continuing in "
	for c in `seq 10 1`; do echo -ne "\a${c}..."; sleep 1; done
else
	echo "OK: Hostname matches expected ($1)"
fi
