#!/usr/bin/env bash
source "$(dirname $0)/_inc.sh"

TARGET_DIR="${HOST_BACKUP_DIR}"

set -e

function main {
	check_env
	check_service
	cleanup_backup
	set_permissions
	do_backup
	extract_backup
	cleanup_backup
}

function check_env {
	if [ -z "$VLO_COMPOSE_DIR" ]; then
		echo "Please set environment variable VLO_COMPOSE_DIR"
		exit 1
	fi

	if [ -z "$VLO_SOLR_INDEX_URL" ]; then
		echo "Please set environment variable VLO_SOLR_INDEX_URL"
		exit 1
	fi

	if [ -z "$VLO_SOLR_BACKUP_USERNAME" ] || [ -z "$VLO_SOLR_BACKUP_PASSWORD" ]; then
		echo "Please set environment variables VLO_SOLR_BACKUP_USERNAME and VLO_SOLR_BACKUP_PASSWORD"
		exit 1
	fi

	echo "Will backing up ${TARGET_DIR}"
}

function set_permissions {
	echo -e "Setting target permission...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker-compose exec -T -u root "${VLO_SOLR_SERVICE}" chown -R solr "${CONTAINER_BACKUP_DIR}" )
}

function get_backup_status {
	solr_api_get "${VLO_SOLR_INDEX_URL}/replication?command=details"
}

function do_backup {
	echo -e "\nCarrying out backup...\n"
	if (cd $VLO_COMPOSE_DIR && 
		solr_api_get "${VLO_SOLR_INDEX_URL}/replication?command=backup&location=${CONTAINER_BACKUP_DIR}&name=${BACKUP_NAME:-backup}")
	then
		echo "Checking status..."
		SUCCESS="false"
		while [ "$SUCCESS" != "true" ]; do
			if get_backup_status | grep "success"; then
				SUCCESS="true"
			else
				echo "Not successful (yet). Status: "
				get_backup_status
				echo "Checking again in 5 seconds..."
				sleep 5
			fi
		done
	else
		echo "Failed to create backup!"
		cleanup_backup
		exit 5
	fi
	
	echo "Final backup status: "
	get_backup_status

	echo -e "\nDone...\n"
}

function extract_backup {
	
	if [ ! -e "${TARGET_DIR}" ]; then
		echo -e "Making target directory ${TARGET_DIR}...\n"
		mkdir -p "${TARGET_DIR}"
	fi

	echo -e "Extracting to ${TARGET_DIR}...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker cp "vlo_${VLO_SOLR_SERVICE}_1:${CONTAINER_BACKUP_DIR}" "${TARGET_DIR}")
}

function cleanup_backup {
	echo -e "Cleaning up...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker-compose exec -T "${VLO_SOLR_SERVICE}" bash -c "if [ -d '${CONTAINER_BACKUP_DIR}' ]; then rm -rf ${CONTAINER_BACKUP_DIR}/*; fi")
}

main
