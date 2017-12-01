#!/usr/bin/env bash
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bash "${DIR}/check-hostname.sh" "lvps92-51-161-129.dedicated.hosteurope.de"
bash "${DIR}/docker-compose.sh" -f "production.yml" -f "jmx.yml" $@
