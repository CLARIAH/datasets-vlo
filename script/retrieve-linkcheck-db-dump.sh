#!/usr/bin/env bash
set -e

source "$(dirname $0)/_inc.sh"
DUMP_URL="${LINK_CHECKER_DUMP_URL:-https://curate.acdh.oeaw.ac.at/mysqlDump.gz}"
SERVICE_NAME="vlo-linkchecker-db"
MONGO_DB_NAME="curateLinkTest"
DB_PRUNE_AGE_DAYS="${LINK_CHECKER_PRUNE_AGE:-100}"
DEBUG="${LINK_CHECKER_DEBUG:-false}"
DRY_RUN="${LINK_CHECKER_DRY_RUN:-false}"
MYSQL_OPTS="-s"
MONGO_RESTORE_OPTS="--quiet"
CURL_OPTS="-s"

if [ "${DEBUG}" = "true" ]; then
	MYSQL_OPTS="-v"
	MONGO_RESTORE_OPTS="-vvv"
	CURL_OPTS="-v"
fi


check_db_container() {
	echo "Looking for container..."
	CONTAINER_ID="$(_docker-compose -f docker-compose.yml -f linkchecker.yml ps -q "${SERVICE_NAME}")"
	if ! docker ps -f id="${CONTAINER_ID}" | grep "${SERVICE_NAME}" > /dev/null; then
		echo "Link checker DB container not found"
		exit 1
	fi

	if [ "${DEBUG}" = "true" ]; then
		echo "Using link checker container ${CONTAINER_ID} (service ${SERVICE_NAME})"
	fi
}

mysql_command() {
	echo "mysql ${MYSQL_OPTS} --user=${LINK_CHECKER_DB_USER} --password=${LINK_CHECKER_DB_PASSWORD} --database=${LINK_CHECKER_DB_NAME}"
}

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
		echo "Dry run - skipping restore of ${DUMP_CONTAINER_FILE} in ${CONTAINER_ID}"
		sleep 1
	else
		# Check if file is found in container
		if ! docker exec "${CONTAINER_ID}" bash -c "[ -e ${DUMP_CONTAINER_FILE} ]"; then
			echo "Error: file not found in container ${DUMP_CONTAINER_FILE}" > /dev/stderr
			exit 1
		fi

		# Carry out actual restore
		echo "Restoring database in container"
		if ! docker exec "${CONTAINER_ID}" nice -n 10 mongorestore ${MONGO_RESTORE_OPTS} --host=127.0.0.1 --drop --gzip --archive="${DUMP_CONTAINER_FILE}"; then
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
		DB_CMD='select * from status limit 0;'
		docker exec "${CONTAINER_ID}" bash -c "echo '${DB_CMD}'|$(mysql_command)"
	fi
}

prune() {
	echo "Pruning database: removing documents older than ${DB_PRUNE_AGE_DAYS} days"
	if [ "${DRY_RUN}" = "true" ]; then
		echo "Dry run - skipping pruning of ${MONGO_DB_NAME} in ${CONTAINER_ID}"
	else
		MONGO_CMD="oldest=new Date\(\).getTime\(\) - ${DB_PRUNE_AGE_DAYS} \* 86400000\; db.linksChecked.remove\(\{\'timestamp\': \{\\\$lt: oldest\}\}\)"
		docker exec "${CONTAINER_ID}" bash -c "echo ${MONGO_CMD}|mongo ${MONGO_OPTS} ${MONGO_DB_NAME}"
	fi
}

read_settings() {
	ENV_FILE=$1
	if ! [ -e "${ENV_FILE}" ]; then
		echo "Error: cannot find .env file at expected location (${ENV_FILE})" > /dev/stderr
		exit 1
	fi

	LINK_CHECKER_DUMP_HOST_DIR=$(		read_env_var "${ENV_FILE}" "LINK_CHECKER_DUMP_HOST_DIR")
	LINK_CHECKER_DUMP_CONTAINER_DIR=$(	read_env_var "${ENV_FILE}" "LINK_CHECKER_DUMP_CONTAINER_DIR")
	LINK_CHECKER_PRUNE_AGE=$(			read_env_var "${ENV_FILE}" "LINK_CHECKER_PRUNE_AGE")
	LINK_CHECKER_DUMP_URL=$(			read_env_var "${ENV_FILE}" "LINK_CHECKER_DUMP_URL")
	LINK_CHECKER_DB_NAME=$(				read_env_var "${ENV_FILE}" "LINK_CHECKER_DB_NAME")
	LINK_CHECKER_DB_USER=$(				read_env_var "${ENV_FILE}" "LINK_CHECKER_DB_USER")
	LINK_CHECKER_DB_PASSWORD=$(			read_env_var "${ENV_FILE}" "LINK_CHECKER_DB_PASSWORD")
	LINK_CHECKER_DEBUG=$(				read_env_var "${ENV_FILE}" "LINK_CHECKER_DEBUG")
	
	echo "Environment variables read from ${ENV_FILE}"

	#override some defaults

	if [ "${LINK_CHECKER_PRUNE_AGE}" ]; then
		DB_PRUNE_AGE_DAYS="${LINK_CHECKER_PRUNE_AGE}"
	fi
	
	if [ "${LINK_CHECKER_DUMP_URL}" ]; then
		DUMP_URL="${LINK_CHECKER_DUMP_URL}"
	fi
	
	if [ "${LINK_CHECKER_DB_NAME}" ]; then
		MONGO_DB_NAME="${LINK_CHECKER_DB_NAME}"
	fi
	
	if [ "${LINK_CHECKER_DEBUG}" ]; then
		DEBUG="${LINK_CHECKER_DEBUG}"
	fi	
}

main() {
	read_settings "${PROJECT_BASE_DIR}/../.env"

	echo "-------"
	echo "LINK_CHECKER_DUMP_HOST_DIR: ${LINK_CHECKER_DUMP_HOST_DIR}"
	echo "LINK_CHECKER_DUMP_CONTAINER_DIR: ${LINK_CHECKER_DUMP_CONTAINER_DIR}"
	echo "MONGO_DB_NAME: ${MONGO_DB_NAME}"
	echo "DB_PRUNE_AGE_DAYS: ${DB_PRUNE_AGE_DAYS}"
	echo "DUMP_URL: ${DUMP_URL}"
	if [ "${DEBUG}" = "true" ]; then
		echo "DEBUG: ${DEBUG} -> output will be verbose!"
	else		
		echo "DEBUG: ${DEBUG}"
	fi
	echo "-------"
	
	if ! [ ${DB_PRUNE_AGE_DAYS} -ge 0 ]; then
		echo "DB_PRUNE_AGE_DAYS expected to be a number >= 0"
		exit 1
	fi
	
	check_db_container
	connect
	update_linkchecker_db "$LINK_CHECKER_DUMP_HOST_DIR" "$LINK_CHECKER_DUMP_CONTAINER_DIR"

	echo "Waiting..."
	sleep 120
	connect
	echo "Waiting..."
	sleep 120

	connect
	prune
}

main
