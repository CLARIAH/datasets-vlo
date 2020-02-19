#!/usr/bin/env bash
set -e

source "$(dirname $0)/_inc.sh"
DUMP_URL="${LINK_CHECKER_DUMP_URL:-https://curate.acdh.oeaw.ac.at/mysqlDump.gz}"
SERVICE_NAME="vlo-linkchecker-db"
DB_NAME="linkchecker"
DB_TABLE_NAME="status"
DB_PRUNE_AGE_DAYS="${LINK_CHECKER_PRUNE_AGE:-100}"
DRY_RUN="${LINK_CHECKER_DRY_RUN:-false}"
MYSQL_OPTS="-s"
CURL_OPTS="-s"

if [ "${DEBUG}" = "true" ]; then
	MYSQL_OPTS="-v"
	CURL_OPTS="-v"
fi

main() {
	read_settings "${PROJECT_BASE_DIR}/../.env"

	log_info "-------"
	log_info "LINK_CHECKER_DUMP_HOST_DIR: ${LINK_CHECKER_DUMP_HOST_DIR}"
	log_info "LINK_CHECKER_DUMP_CONTAINER_DIR: ${LINK_CHECKER_DUMP_CONTAINER_DIR}"
	log_info "DB_NAME: ${DB_NAME}"
	log_info "DB_PRUNE_AGE_DAYS: ${DB_PRUNE_AGE_DAYS}"
	log_info "DUMP_URL: ${DUMP_URL}"
	if [ "${DRY_RUN}" = "true" ]; then
		log_info "DRY_RUN: ${DRY_RUN} -> no changes will be made to the database!"
	fi
	if [ "${DEBUG}" = "true" ]; then
		log_info "DEBUG: ${DEBUG} -> output will be verbose!"
	else		
		log_info "DEBUG: ${DEBUG}"
	fi
	log_info "-------"
	
	if ! [ ${DB_PRUNE_AGE_DAYS} -ge 0 ]; then
		log_error "DB_PRUNE_AGE_DAYS expected to be a number >= 0"
		exit 1
	fi
	
	check_db_container
	connect
	update_linkchecker_db "$LINK_CHECKER_DUMP_HOST_DIR" "$LINK_CHECKER_DUMP_CONTAINER_DIR"
	prune
}

check_db_container() {
	log_info "Looking for container..."
	CONTAINER_ID="$(_docker-compose -f docker-compose.yml -f linkchecker.yml ps -q "${SERVICE_NAME}")"
	if ! docker ps -f id="${CONTAINER_ID}" | grep "${SERVICE_NAME}" > /dev/null; then
		log_error "Link checker DB container not found"
		exit 1
	fi

	log_debug "Using link checker container ${CONTAINER_ID} (service ${SERVICE_NAME})"
}

connect() {
	DB_CMD='select * from '"${DB_TABLE_NAME}"' limit 0;'
	log_debug "Checking connection with command '${DB_CMD}' passed to $(mysql_command)"

	log_info "Connecting and disconnecting"
	if [ "${DRY_RUN}" = "true" ]; then
		log_info "(Dry run)"
	else
		docker exec "${CONTAINER_ID}" bash -c "echo '${DB_CMD}'|$(mysql_command)"
	fi
}

update_linkchecker_db() {
	DUMP_HOST_DIR=$1
	DUMP_CONTAINER_DIR=$2
	
	# Download file to mounted host directory
	DUMP_FILENAME="linkchecker_dump_$(date +%Y%m%d%H%M%S).gz"
	DUMP_TARGET_LOCATION="${DUMP_HOST_DIR}/${DUMP_FILENAME}"
	
	log_info "Downloading dump file from <${DUMP_URL}> to ${DUMP_TARGET_LOCATION}"
	
	if [ "${DRY_RUN}" = "true" ]; then
		log_info "Dry run - skipping retrieval of ${DUMP_URL} to ${DUMP_TARGET_LOCATION}"
		sleep 1
	else
		if ! curl ${CURL_OPTS} -L "${DUMP_URL}" > "${DUMP_TARGET_LOCATION}"; then
			log_error "Failed to download dump file!"
			exit 1
		fi
	fi

	# Find and process file in container	
	DUMP_CONTAINER_FILE="${DUMP_CONTAINER_DIR}/${DUMP_FILENAME}"

	if [ "${DRY_RUN}" = "true" ]; then
		log_info "Dry run - skipping restore of ${DUMP_CONTAINER_FILE} in ${CONTAINER_ID}"
		sleep 1
	else
		# Check if file is found in container
		if ! docker exec "${CONTAINER_ID}" bash -c "[ -e ${DUMP_CONTAINER_FILE} ]"; then
			log_error "File not found in container ${DUMP_CONTAINER_FILE}"
			exit 1
		fi

		# Carry out actual restore		
		echo "Dropping current ${DB_TABLE_NAME} table"
		DB_CMD="DROP TABLE ${DB_TABLE_NAME};"
		if docker exec "${CONTAINER_ID}" bash -c "echo '${DB_CMD}'|$(mysql_command)"; then
			log_info "Restoring database in container"
			if ! docker exec "${CONTAINER_ID}" bash -c "gunzip -c '${DUMP_CONTAINER_FILE}'|$(mysql_command)"; then
				log_error "Failed to restore database"
				exit 1
			fi
		else
			log_error "Failed to drop old data"
			exit 1
		fi
	fi
	
	if [ "${DRY_RUN}" = "true" ]; then
		log_info "Removing ${DUMP_TARGET_LOCATION} (dry run)"
		sleep 1
	else
		log_info "Removing $(rm -v "${DUMP_TARGET_LOCATION}")"
	fi
}

prune() {
	DB_CMD='DELETE FROM '"${DB_TABLE_NAME}"' where timestamp < DATE_SUB(NOW(), INTERVAL '"${DB_PRUNE_AGE_DAYS}"' DAY);'
	log_debug "Checking connection with command '${DB_CMD}' passed to $(mysql_command)"

	log_info "Pruning database: removing documents older than ${DB_PRUNE_AGE_DAYS} days"
	if [ "${DRY_RUN}" = "true" ]; then
		log_info "Dry run - skipping pruning of ${DB_NAME} in ${CONTAINER_ID}"
	else
		docker exec "${CONTAINER_ID}" bash -c "echo '${DB_CMD}'|$(mysql_command)"
	fi
}

read_settings() {
	ENV_FILE=$1
	if ! [ -e "${ENV_FILE}" ]; then
		log_error "Cannot find .env file at expected location (${ENV_FILE})"
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
	
	log_info "Environment variables read from ${ENV_FILE}"

	#override some defaults

	if [ "${LINK_CHECKER_PRUNE_AGE}" ]; then
		DB_PRUNE_AGE_DAYS="${LINK_CHECKER_PRUNE_AGE}"
	fi
	
	if [ "${LINK_CHECKER_DUMP_URL}" ]; then
		DUMP_URL="${LINK_CHECKER_DUMP_URL}"
	fi
	
	if [ "${LINK_CHECKER_DB_NAME}" ]; then
		DB_NAME="${LINK_CHECKER_DB_NAME}"
	fi
	
	if [ "${DEBUG}" = "" ] && [ "${LINK_CHECKER_DEBUG}" ]; then
		DEBUG="${LINK_CHECKER_DEBUG}"
	fi	
}

mysql_command() {
	echo "mysql ${MYSQL_OPTS} --user=${LINK_CHECKER_DB_USER} --password=${LINK_CHECKER_DB_PASSWORD} --database=${LINK_CHECKER_DB_NAME}"
}

log_error() {
	if [ "${DEBUG}" = "true" ]; then
		echo "[ERROR] $@"
	else
		echo "$@"
	fi		
}

log_info() {
	if [ "${DEBUG}" = "true" ]; then
		echo "[INFO] $@"
	else
		echo "$@"
	fi		
}

log_debug() {
	if [ "${DEBUG}" = "true" ]; then
		echo "[DEBUG] $@"
	fi
}

main
