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
	for c in `seq 5 1`; do echo -n "${c}..."; sleep 1; done
fi
