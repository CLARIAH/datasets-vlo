#!/usr/bin/env bash
set -e

# shellcheck source=_inc.sh
source "$(dirname "$0")/_inc.sh"

LINKCHECKER_OVERLAY="linkchecker.yml"

(cd "${VLO_COMPOSE_DIR}" \
	&& _docker-compose -f docker-compose.yml -f "${LINKCHECKER_OVERLAY}" \
		exec "${COMPOSE_OPTS}" "${VLO_LINKCHECKER_DB_SERVICE}" \
		bash -c 'mysql --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --database=${MYSQL_DATABASE}')
