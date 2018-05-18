#!/usr/bin/env bash
set -e
DIR=$(dirname $BASH_SOURCE)
if [ $(readlink $0) ]; then
        DIR=$(dirname $(readlink $0))
fi
$(cd "${DIR}/clarin" \
  && docker-compose \
    -f docker-compose.yml \
    $@)

