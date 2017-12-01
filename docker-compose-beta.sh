#!/usr/bin/env bash
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bash "${DIR}/check-hostname.sh" "beta-vlo-clarin.esc.rzg.mpg.de"
bash "${DIR}/docker-compose.sh" -f "beta.yml" -f "jmx.yml" $@
