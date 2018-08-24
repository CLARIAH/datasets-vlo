#!/usr/bin/env bash
source "$(dirname $0)/_inc.sh"

SRC_DIR="${VLO_RESTORE_DIR:-${HOST_BACKUP_DIR}/backup}" #matches default in backup script

set -e

function main {
	check_env
	check_service
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

	while ! (cd $VLO_COMPOSE_DIR && docker-compose exec "${VLO_SOLR_SERVICE}" \
		curl -f -u ${VLO_SOLR_BACKUP_USERNAME}:${VLO_SOLR_BACKUP_PASSWORD} "${VLO_SOLR_INDEX_URL}/replication") > /dev/null
	do
		echo "Waiting for Solr..."
		sleep 5
	done
}

function do_restore {
	echo -e "\nCarrying out restore...\n"
	#close all indexes
	(cd $VLO_COMPOSE_DIR && docker-compose exec "${VLO_SOLR_SERVICE}" \
		bash -c "
			mv \$SOLR_DATA_HOME/vlo-index/data/index \$SOLR_DATA_HOME/vlo-index/data/index_old;
			(cp -r ${CONTAINER_BACKUP_DIR}/snapshot.${BACKUP_NAME} \$SOLR_DATA_HOME/vlo-index/data/index && rm -rf \$SOLR_DATA_HOME/vlo-index/data/index_old) ||
			(echo 'Failed, reverting old index' && mv \$SOLR_DATA_HOME/vlo-index/data/index_old \$SOLR_DATA_HOME/vlo-index/data/index)
		")
	echo -e "\nDone...\n"
}

function finalize {
	echo "Stopping services"
	(cd $VLO_COMPOSE_DIR && \
		docker-compose down)
}

main
