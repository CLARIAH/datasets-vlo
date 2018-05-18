#!/usr/bin/env bash
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
(cd "${DIR}/clarin" \
  && docker-compose \
    -f docker-compose.yml \
    $@
)
