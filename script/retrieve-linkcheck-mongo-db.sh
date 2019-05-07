#!/usr/bin/env bash
source "$(dirname $0)/_inc.sh"
DUMP_URL="${VLO_LINKCHECKER_DUMP_URL:-https://curate.acdh-dev.oeaw.ac.at/mongoDump.gz}"
CONTAINER_NAME="vlo_vlo-linkchecker-mongo_1"
MONGO_PRUNE_AGE_DAYS="${VLO_LINKCHECKER_PRUNE_AGE:-100}"
DEBUG="${VLO_LINKCHECKER_DEBUG:-false}"
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
	
	if ! curl ${CURL_OPTS} -L "${DUMP_URL}" > "${DUMP_TARGET_LOCATION}"; then
		echo "Error: failed to download dump file!" > /dev/stderr
		exit 1
	fi

	# Find and process file in container	
	DUMP_CONTAINER_FILE="${DUMP_CONTAINER_DIR}/${DUMP_FILENAME}"

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
	
	echo -n "Removing "
	rm -v "${DUMP_TARGET_LOCATION}"
}

prune() {
	echo "Pruning database: removing documents older than ${MONGO_PRUNE_AGE_DAYS} days"
	MONGO_CMD="oldest=new Date\(\).getTime\(\) - ${MONGO_PRUNE_AGE_DAYS} \* 86400000\; db.linksChecked.remove\(\{\'timestamp\': \{\\\$gt: oldest\}\}\)"
	docker exec "${CONTAINER_NAME}" bash -c "echo ${MONGO_CMD}|mongo ${MONGO_OPTS} curateLinkTest"
}

main() {
	ENV_FILE="${PROJECT_BASE_DIR}/../.env"

	if ! [ -e "${ENV_FILE}" ]; then
		echo "Error: cannot find .env file at expected location (${ENV_FILE})" > /dev/stderr
		exit 1
	fi

	DUMP_HOST_DIR_SET=$(egrep "^VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR" -- "${ENV_FILE}")
	if ! [ "${DUMP_HOST_DIR_SET}" ]; then
		echo "Error: could not find VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR in .env file (${ENV_FILE})" > /dev/stderr
		exit 1
	fi


	DUMP_CONTAINER_DIR_SET=$(egrep "^VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR" -- "${ENV_FILE}")
	if ! [ "${DUMP_HOST_DIR_SET}" ]; then
		echo "Error: could not find VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR in .env file (${ENV_FILE})" > /dev/stderr
		exit 1
	fi

	eval $DUMP_HOST_DIR_SET
	eval $DUMP_CONTAINER_DIR_SET

	if ! [ "${VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR}" ] || ! [ "${VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR}" ]; then
		echo "Error: failed to read VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR and/or VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR from .env file (${ENV_FILE})"
		exit 1
	fi

	echo "VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR: ${VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR}"
	echo "VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR: ${VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR}"

	update_linkchecker_db "$VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR" "$VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR"
	
	prune
}

main
