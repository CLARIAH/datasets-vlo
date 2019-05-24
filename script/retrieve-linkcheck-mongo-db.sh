#!/usr/bin/env bash
source "$(dirname $0)/_inc.sh"
DUMP_URL="${VLO_LINKCHECKER_DUMP_URL:-https://curate.acdh-dev.oeaw.ac.at/mongoDump.gz}"
CONTAINER_NAME="vlo_vlo-linkchecker-mongo_1"
MONGO_DB_NAME="curateLinkTest"
MONGO_PRUNE_AGE_DAYS="${VLO_LINKCHECKER_PRUNE_AGE:-100}"
DEBUG="${VLO_LINKCHECKER_DEBUG:-false}"
DRY_RUN="${VLO_LINKCHECKER_DRY_RUN:-false}"
MONGO_OPTS="--quiet"
MONGO_RESTORE_OPTS="--quiet"
CURL_OPTS="-s"

if [ "${DEBUG}" = "true" ]; then
	MONGO_OPTS="--verbose"
	MONGO_RESTORE_OPTS="-vvv"
	CURL_OPTS="-v"
fi

update_linkchecker_db() {
	DUMP_HOST_DIR=$1
	DUMP_CONTAINER_DIR=$2
	
	# Download file to mounted host directory
	DUMP_FILENAME="linkchecker_dump_$(date +%Y%m%d%H%M%S).gz"
	DUMP_TARGET_LOCATION="${DUMP_HOST_DIR}/${DUMP_FILENAME}"
	
	echo "Downloading dump file from <${DUMP_URL}> to ${DUMP_TARGET_LOCATION}" > /dev/stderr
	
	if [ "${DRY_RUN}" = "true" ]; then
		echo "Dry run - skipping retrieval of ${DUMP_URL} to ${DUMP_TARGET_LOCATION}"
		sleep 1
	else
		if ! curl ${CURL_OPTS} -L "${DUMP_URL}" > "${DUMP_TARGET_LOCATION}"; then
			echo "Error: failed to download dump file!" > /dev/stderr
			exit 1
		fi
	fi

	# Find and process file in container	
	DUMP_CONTAINER_FILE="${DUMP_CONTAINER_DIR}/${DUMP_FILENAME}"

	if [ "${DRY_RUN}" = "true" ]; then
		echo "Dry run - skipping restore of ${DUMP_CONTAINER_FILE} in ${CONTAINER_NAME}"
		sleep 1
	else
		# Check if file is found in container
		if ! docker exec "${CONTAINER_NAME}" bash -c "[ -e ${DUMP_CONTAINER_FILE} ]"; then
			echo "Error: file not found in container ${DUMP_CONTAINER_FILE}" > /dev/stderr
			exit 1
		fi

		# Carry out actual restore
		echo "Restoring database in container"
		if ! docker exec "${CONTAINER_NAME}" nice -n 10 mongorestore ${MONGO_RESTORE_OPTS} --drop --gzip --archive="${DUMP_CONTAINER_FILE}"; then
			echo "Error: failed to restore mongo database" > /dev/stderr
			exit 1
		fi
	fi
	
	echo -n "Removing "
	if [ "${DRY_RUN}" = "true" ]; then
		echo "${DUMP_TARGET_LOCATION} (dry run)"
		sleep 1
	else
		rm -v "${DUMP_TARGET_LOCATION}"
	fi
}

connect() {
	echo "Connecting and disconnecting"
	if [ "${DRY_RUN}" = "true" ]; then
		echo "(Dry run)"
	else
		MONGO_CMD="db.linksChecked.count\(\)"
		docker exec "${CONTAINER_NAME}" bash -c "echo ${MONGO_CMD}|mongo ${MONGO_OPTS} ${MONGO_DB_NAME}"
	fi
}

prune() {
	echo "Pruning database: removing documents older than ${MONGO_PRUNE_AGE_DAYS} days"
	if [ "${DRY_RUN}" = "true" ]; then
		echo "Dry run - skipping pruning of ${MONGO_DB_NAME} in ${CONTAINER_NAME}"
	else
		MONGO_CMD="oldest=new Date\(\).getTime\(\) - ${MONGO_PRUNE_AGE_DAYS} \* 86400000\; db.linksChecked.remove\(\{\'timestamp\': \{\\\$lt: oldest\}\}\)"
		docker exec "${CONTAINER_NAME}" bash -c "echo ${MONGO_CMD}|mongo ${MONGO_OPTS} ${MONGO_DB_NAME}"
	fi
}

read_settings() {
	ENV_FILE=$1
	if ! [ -e "${ENV_FILE}" ]; then
		echo "Error: cannot find .env file at expected location (${ENV_FILE})" > /dev/stderr
		exit 1
	fi

	VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR=$(			read_env_var "${ENV_FILE}" "VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR")
	VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR=$(	read_env_var "${ENV_FILE}" "VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR")
	VLO_LINKCHECKER_PRUNE_AGE=$(					read_env_var "${ENV_FILE}" "VLO_LINKCHECKER_PRUNE_AGE")
	VLO_LINKCHECKER_DUMP_URL=$(						read_env_var "${ENV_FILE}" "VLO_LINKCHECKER_DUMP_URL")
	VLO_LINK_CHECKER_MONGO_DB_NAME=$(				read_env_var "${ENV_FILE}" "VLO_LINK_CHECKER_MONGO_DB_NAME")
	VLO_LINKCHECKER_DEBUG=$(						read_env_var "${ENV_FILE}" "VLO_LINKCHECKER_DEBUG")

	if ! [ "${VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR}" ] || ! [ "${VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR}" ]; then
		echo "Error: failed to read VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR and/or VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR from .env file (${ENV_FILE})"
		exit 1
	fi
	
	echo "Environment variables read from ${ENV_FILE}"

	#override some defaults

	if [ "${VLO_LINKCHECKER_PRUNE_AGE}" ]; then
		MONGO_PRUNE_AGE_DAYS="${VLO_LINKCHECKER_PRUNE_AGE}"
	fi
	
	if [ "${VLO_LINKCHECKER_DUMP_URL}" ]; then
		DUMP_URL="${VLO_LINKCHECKER_DUMP_URL}"
	fi
	
	if [ "${VLO_LINK_CHECKER_MONGO_DB_NAME}" ]; then
		MONGO_DB_NAME="${VLO_LINK_CHECKER_MONGO_DB_NAME}"
	fi
	
	if [ "${VLO_LINKCHECKER_DEBUG}" ]; then
		DEBUG="${VLO_LINKCHECKER_DEBUG}"
	fi	
}

main() {
	read_settings "${PROJECT_BASE_DIR}/../.env"

	echo "-------"
	echo "VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR: ${VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR}"
	echo "VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR: ${VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR}"
	echo "MONGO_DB_NAME: ${MONGO_DB_NAME}"
	echo "MONGO_PRUNE_AGE_DAYS: ${MONGO_PRUNE_AGE_DAYS}"
	echo "DUMP_URL: ${DUMP_URL}"
	if [ "${DEBUG}" = "true" ]; then
		echo "DEBUG: ${DEBUG} -> mongo and curl output will be verbose!"
	else		
		echo "DEBUG: ${DEBUG}"
	fi
	echo "-------"
	
	if ! [ ${MONGO_PRUNE_AGE_DAYS} -ge 0 ]; then
		echo "MONGO_PRUNE_AGE_DAYS expected to be a number >= 0"
		exit 1
	fi
	
	connect
	update_linkchecker_db "$VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR" "$VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR"

	echo "Waiting..."
	sleep 120
	connect
	echo "Waiting..."
	sleep 120

	connect
	prune
}

main
