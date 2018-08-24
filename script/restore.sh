#!/usr/bin/env bash
source "$(dirname $0)/_inc.sh"

SRC_DIR="${ELASTIC_SEARCH_BACKUP_DIR:-/tmp/esbackup/backup}" #matches default in backup script

set -e

function main {
	check_env
	check_service
	prepare_repo
	prepare_restore
	check_snapshot
	do_restore
	finalize
}

function check_env {
	if [ ! -d "${SRC_DIR}" ]; then
		echo "Expecting a directory ${SRC_DIR}"
		exit 2
	fi

	if [ -z "$ELASTIC_COMPOSE_DIR" ]; then
		echo "Please set environment variable ELASTIC_COMPOSE_DIR"
		exit 1
	fi

	if [ -z "$ELASTIC_COMPOSE_DIR" ]; then
		echo "Please set environment variable ELASTIC_COMPOSE_DIR"
		exit 1
	fi

	if [ -z "$ELASTICSEARCH_USERNAME" ]; then
		ELASTICSEARCH_USERNAME="${ELASTICSEARCH_USERNAME_DEFAULT}"
		echo "Using default elastic username!"
	fi
	if [ -z "$ELASTICSEARCH_PASSWORD" ]; then
		ELASTICSEARCH_PASSWORD="${ELASTICSEARCH_PASSWORD_DEFAULT}"
		echo "Using default elastic password!!"
	fi

	if [ -z "$SNAPSHOT_NAME" ]; then
		echo "Please set environment variable SNAPSHOT_NAME (see index-0 file for index info)"
		exit 1
	fi

	echo "Restoring from ${SRC_DIR}"
	echo "Using repository/snapshot '${REPO_NAME}/${SNAPSHOT_NAME}'"
}

function prepare_restore {
	echo -e "\nRestarting with backup mounted...\n"	
	export ELASTIC_SEARCH_BACKUP_REPOSITORY_LOCATION="${SRC_DIR}"
	(cd $ELASTIC_COMPOSE_DIR && \
		docker-compose down && \
		docker-compose -f docker-compose.yml -f restore.yml up -d --force-recreate elasticsearch)	

	while ! curl -s -f -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} "${ELASTIC_SEARCH_URL}" > /dev/null
	do
		echo "Waiting for Elasticsearch..."
		sleep 5
	done
}

function check_snapshot {
	if curl -s -f -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} "${ELASTIC_SEARCH_URL}/_snapshot/${REPO_NAME}/${SNAPSHOT_NAME}" > /dev/null
	then
		echo "Snapshot found..."
	else
		echo -e "Snapshot to restore not found. Cannot restore. Snapshots info:\n\n"
		echo curl -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} "${ELASTIC_SEARCH_URL}/_snapshot/${REPO_NAME}/*"
		exit 5
	fi
}

function do_restore {
	echo -e "\nCarrying out restore...\n"
	#close all indexes
	curl -s -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} -XPOST "${ELASTIC_SEARCH_URL}/_all/_close" > /dev/null
	#restore everything
 	curl -s -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} -XPOST "${ELASTIC_SEARCH_URL}/_snapshot/${REPO_NAME}/${SNAPSHOT_NAME}/_restore?wait_for_completion=true" -H 'Content-Type: application/json' -d'
 	{
 	  "include_global_state": true
 	}
 	'
	echo -e "\nDone...\n"
}

function finalize {
	echo "Stopping services"
	(cd $ELASTIC_COMPOSE_DIR && \
		docker-compose down)
}

main