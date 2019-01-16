#!/usr/bin/env bash
source "$(dirname $0)/_inc.sh"

SRC_DIR="${VLO_RESTORE_DIR:-${HOST_BACKUP_DIR}/backup}" #matches default in backup script

set -e

function main {
	check_env
	check_replication_service
	prepare_restore
	do_restore
	finalize
}

function check_env {
	if [ ! -d "${SRC_DIR}" ]; then
		echo "Expecting a directory ${SRC_DIR}"
		exit 2
	fi

	if [ -z "$VLO_COMPOSE_DIR" ]; then
		echo "Please set environment variable VLO_COMPOSE_DIR"
		exit 1
	fi

	if [ -z "$VLO_COMPOSE_DIR" ]; then
		echo "Please set environment variable VLO_COMPOSE_DIR"
		exit 1
	fi

	if [ -z "$VLO_SOLR_BACKUP_USERNAME" ] || [ -z "$VLO_SOLR_BACKUP_PASSWORD" ]; then
		echo "Please set environment variables VLO_SOLR_BACKUP_USERNAME and VLO_SOLR_BACKUP_PASSWORD"
		exit 1
	fi

	if [ -z "$BACKUP_NAME" ]; then
		echo "Please set environment variable BACKUP_NAME"
		exit 1
	fi

	echo "Restoring from ${SRC_DIR}"
}


# ${SRC_DIR}/backup/snapshot.vlo-index
# should go into $SOLR_DATA_HOME/vlo-index/data/index/

function prepare_restore {
	INDEX_SNAPSHOT_DIR="${SRC_DIR}/snapshot.${BACKUP_NAME}"
	if ! [ -d "${INDEX_SNAPSHOT_DIR}" ]; then
		echo "Snapshot not found in backup dir! Expected to find it at ${INDEX_SNAPSHOT_DIR}"
		exit 2
	fi

	echo -e "\nRestarting with backup mounted...\n"	
	export VLO_SOLR_BACKUP_LOCATION="${SRC_DIR}"
	export CONTAINER_BACKUP_DIR
	${VLO_COMPOSE_DIR}/../control.sh stop
	(cd $VLO_COMPOSE_DIR && \
		docker-compose -f docker-compose.yml -f solr-restore.yml up -d --force-recreate "${VLO_SOLR_SERVICE}")	

	while ! solr_api_get "${VLO_SOLR_INDEX_URL}/replication" > /dev/null
	do
		echo "Waiting for Solr..."
		sleep 5
	done
}

function get_restore_status {
	solr_api_get "${VLO_SOLR_INDEX_URL}/replication?command=restorestatus&name=${BACKUP_NAME}&location=${CONTAINER_BACKUP_DIR}"
}

function do_restore {
	echo -e "\nCarrying out restore...\n"
	#close all indexes
	if solr_api_get "${VLO_SOLR_INDEX_URL}/replication?command=restore&name=${BACKUP_NAME}&location=${CONTAINER_BACKUP_DIR}"; then
		echo "Checking status..."
		SUCCESS="false"
		while [ "$SUCCESS" != "true" ]; do
			if get_restore_status | grep "success"; then
				SUCCESS="true"
			else
				if get_restore_status | grep "exception"; then
					echo "Exception occurred. Terminating..."
					finalize
					exit 1
				else
					echo "Not successful (yet). Status: "
					get_restore_status
					echo "Checking again in 5 seconds..."
					sleep 5
				fi
			fi
		done
		echo -e "\nDone...\n"
	else
		echo "Failed to restore backup!"
		finalize
		exit 5
	fi
}

function finalize {
	echo "Stopping services"
	(cd $VLO_COMPOSE_DIR && \
		docker-compose down)
}

main
