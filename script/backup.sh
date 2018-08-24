#!/usr/bin/env bash
source "$(dirname $0)/_inc.sh"

TARGET_DIR="${VLO_SOLR_BACKUP_DIR:-/tmp/vlo-solr-backup}"

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

	echo "Backing up to ${TARGET_DIR}"
}

function set_permissions {
	echo -e "Setting target permission...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker-compose exec -u root vlo-solr chown -R solr "${CONTAINER_BACKUP_DIR}" )
}

function do_backup {
	echo -e "\nCarrying out backup...\n"
	if ! (cd $VLO_COMPOSE_DIR && 
		docker-compose exec vlo-solr curl -f -u ${VLO_SOLR_BACKUP_USERNAME}:${VLO_SOLR_BACKUP_PASSWORD} "${VLO_SOLR_INDEX_URL}/replication?command=backup&location=${CONTAINER_BACKUP_DIR}&name=${BACKUP_NAME:-backup}") > /dev/null
	then
		echo "Failed to create backup!"
		cleanup_backup
		exit 5
	fi

	echo -e "\nDone...\n"
}

function extract_backup {
	
	if [ ! -e "${TARGET_DIR}" ]; then
		echo -e "Making target directory ${TARGET_DIR}...\n"
		mkdir -p "${TARGET_DIR}"
	fi

	echo -e "Extracting to ${TARGET_DIR}...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker cp "vlo_vlo-solr_1:${CONTAINER_BACKUP_DIR}" "${TARGET_DIR}")
}

function cleanup_backup {
	echo -e "Cleaning up...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker-compose exec vlo-solr bash -c "if [ -d '${CONTAINER_BACKUP_DIR}' ]; then rm -rf ${CONTAINER_BACKUP_DIR}/*; fi")
}

main
