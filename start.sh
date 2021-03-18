#!/usr/bin/env bash
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
. "${BASE_DIR}/script/_inc.sh"

COMPOSE_OPTS="$1"
COMPOSE_CMD_ARGS="$2"

start_vlo_main() {
	create_missing_volume "vlo-data"
		
	create_missing_network "network_linkchecker" "--internal"

	if check_service; then
		echo "Warning: service already appears to be running, will not try to remove home provisioning volume"
	else		
		remove_solr_home_provisioning_volume
	fi
	_docker-compose ${COMPOSE_OPTS} up -d ${COMPOSE_CMD_ARGS}
}

create_missing_volume() {
	VOLUME="$1"
	shift
	OPTIONS="$*"
	if [ "${VOLUME}" ] && [ "$(docker volume ls |grep -c "${VOLUME}")"  -eq 0 ]; then	
		echo "Creating missing volume '${VOLUME}'"
		if [ "${OPTIONS}" ]  && [ "${#OPTIONS[@]}" ]; then
			docker volume create "${OPTIONS[@]}" -- "${VOLUME}"
		else
	        docker volume create -- "${VOLUME}"
	    fi
    fi

}

create_missing_network() {
	NETWORK="$1"
	shift
	OPTIONS="$*"
	if [ "${NETWORK}" ] && [ "$(docker network ls |grep -c "${NETWORK}")"  -eq 0 ]; then
		echo "Creating missing network '${NETWORK}'"
		if [ "${OPTIONS}" ]  && [ "${#OPTIONS[@]}" ]; then
	        docker network create "${OPTIONS[@]}" -- "${NETWORK}"
	    else
		    docker network create -- "${NETWORK}"
		fi
    fi
}

remove_solr_home_provisioning_volume() {
	echo "Trying to remove solr home provisioning volume...."
	eval "$(grep "COMPOSE_PROJECT_NAME" "${VLO_COMPOSE_DIR}/.env")"
	if [ "${COMPOSE_PROJECT_NAME}" ]; then
		VOLUME_NAME="${COMPOSE_PROJECT_NAME}_${SOLR_HOME_PROVISIONING_VOLUME_NAME}"
		if docker volume ls | grep -E "${VOLUME_NAME}$"; then
			ACTUAL_VOLUME_NAME=$(docker volume ls | grep -E -o "${VOLUME_NAME}$")
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

start_vlo_main "$@"
