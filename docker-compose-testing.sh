#!/usr/bin/env bash
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bash "${DIR}/docker-compose.sh" -f "testing.yml" -f "jmx.yml" -f "data.yml" $@
