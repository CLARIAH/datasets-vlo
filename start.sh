#!/usr/bin/env bash
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
. "${BASE_DIR}/script/_inc.sh"

COMPOSE_OPTS=$1
COMPOSE_CMD_ARGS=$2

start_vlo() {
	if check_service; then
		echo "Warning: service already appears to be running, will not try to remove home provisioning volume"
	else
		remove_solr_home_provisioning_volume
	fi
	_docker-compose $COMPOSE_OPTS up -d ${COMPOSE_CMD_ARGS}
}

remove_solr_home_provisioning_volume() {
	echo "Trying to remove solr home provisioning volume...."
	eval "$(grep "COMPOSE_PROJECT_NAME" "${VLO_COMPOSE_DIR}/.env")"
	if [ "${COMPOSE_PROJECT_NAME}" ]; then
		VOLUME_NAME="${COMPOSE_PROJECT_NAME}_${SOLR_HOME_PROVISIONING_VOLUME_NAME}"
		if docker volume ls | egrep "${VOLUME_NAME}$"; then
			ACTUAL_VOLUME_NAME=$(docker volume ls | egrep -o "${VOLUME_NAME}$")
			echo -n "Remove volume ${ACTUAL_VOLUME_NAME}... "
			if docker volume rm "${ACTUAL_VOLUME_NAME}" > /dev/null; then
				echo "done"
			else
				echo "FAILED!"
				exit 1
			fi
		else
			echo "No Solr home provisioning volume found"
		fi
	else
		echo "Warning: Could not determine compose project name. Solr home provisioning will NOT be cleaned up!"	
	fi
}

start_vlo
