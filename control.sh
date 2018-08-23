#!/bin/bash
set -e

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

BACKUP_DIR_RELATIVE_PATH="../../vlo-index-backup" #relative to compose dir
BACKUP_FILE_PREFIX="vlo-backup"

ARG_COUNT=$#

STOP=0
START=0
IMPORT=0
STATUS=0
BACKUP=0
RESTORE=0
HELP=0
VERBOSE=0

print_usage() {
    echo ""
    echo "control.sh [start|stop|restart|backup|restore] [-hd]"
    echo ""
    echo "  start       Start VLO services"
    echo "  stop        Stop VLO services"
    echo "  run-import  Run a VLO import"
    echo "  restart     Restart VLO services"
    echo "  status      Show status of VLO service containers"
    echo "  backup      Create a backup of the VLO Solr index"
    echo "                This will create a new backup archive (${BACKUP_FILE_PREFIX}...tgz)"
    echo "                in the backup directory (a sibling to the script directory)"
    echo "  restore     Restore a backup of the VLO Solr index into the current container"
    echo "                This will extract and apply the most recent backup archive"
    echo "                (${BACKUP_FILE_PREFIX}...tgz) in the backup directory  (a sibling to"
    echo "                the script directory)"
    echo ""
    echo "  -d, --debug Run this script in verbose mode"
    echo ""
    echo "  -h, --help  Show help"
}

main() {
	process_args $@
	execute_control_commands 
}

process_args() {
	#
	# Process script arguments
	#
	while [[ $# -gt 0 ]]
	do
	key="$1"
	case $key in
		'stop')
			STOP=1
			;;
		'start')
			START=1
			;;
		'restart')
			STOP=1
			START=1
			;;
		'status')
			STATUS=1
			;;
		'run-import')
			IMPORT=1
			;;
		'backup')
			BACKUP=1
			;;
		'restore')
			RESTORE=1
			;;
		'-h'|'--help')
			HELP=1
		   ;;
		'-d'|'--debug')
			VERBOSE=1
			;;
		*)
			echo "Unkown option: $key"
			HELP=1
			;;
	esac
	shift # past argument or value
	done
	
	BASH_OPTS=""
	# Print parameters if running in verbose mode
	if [ ${VERBOSE} -eq 1 ]; then
		set -x
		BASH_OPTS="${BASH_OPTS} -x"
	fi
}

execute_control_commands() {
	#
	# Execute based on mode argument
	#
	if [ $ARG_COUNT -le 0 ] || [ ${HELP} -eq 1 ]; then
		print_usage
	    exit 0
	else
		COMPOSE_OPTS="-f docker-compose.yml `read_compose_modules`"
		if [ $VERBOSE -eq 1 ]; then
			COMPOSE_OPTS="${COMPOSE_OPTS} --verbose"	
		fi
		COMPOSE_CMD_ARGS=""
		
		COMPOSE_DIR="${BASE_DIR}/clarin"
		SCRIPT_DIR="${BASE_DIR}/script"
	
		if [ ${STATUS} -eq 1 ]; then
			vlo_status
			exit 0
		fi

		if [ ${STOP} -eq 1 ]; then
			vlo_stop
		fi
		if [ ${START} -eq 1 ]; then
			vlo_start
		fi
		if [ ${BACKUP} -eq 1 ]; then
			vlo_backup
		fi
		if [ ${RESTORE} -eq 1 ]; then
			vlo_restore
		fi
	fi
}

vlo_status() {
	_docker-compose ${COMPOSE_OPTS} ps
}

vlo_start() {
	_docker-compose ${COMPOSE_OPTS} up -d ${COMPOSE_CMD_ARGS}
}

vlo_stop() {
	_docker-compose ${COMPOSE_OPTS} down ${COMPOSE_CMD_ARGS}
}

# vlo_backup() {
# 	if service_is_running ${ELASTICSEARCH_SERVICE}; then
# 		echo -e "Elasticsearch is running. Starting backup procedure...\n"
# 	else
# 		echo "Elasticsearch is not running. Please start Elasticsearch and try again.."
# 		exit 1
# 	fi
# 
# 	export ELASTIC_COMPOSE_DIR="${COMPOSE_DIR}"
# 
# 	BACKUP_DIR="${COMPOSE_DIR}/${BACKUP_DIR_RELATIVE_PATH}" #host only dir
# 	export ELASTIC_SEARCH_BACKUP_DIR="${BACKUP_DIR}/work-backup"
# 	
# 	export_credentials
# 	
# 	if ! (mkdir -p "${BACKUP_DIR}" && [ -d "${BACKUP_DIR}" ] && [ -x "${BACKUP_DIR}" ]); then
# 		echo "Cannot create and/or access backup directory ${BACKUP_DIR}"
# 		exit 1
# 	fi
# 	
# 	echo "Archiving old backups..."
# 	mkdir -p "${BACKUP_DIR}/archived"
# 	(
# 		cd "${BACKUP_DIR}"
# 		mv "${BACKUP_FILE_PREFIX}"*".tgz" "archived/" && echo " Done" || echo " Nothing to do"
# 	)
# 	
# 	if [ -d "${ELASTIC_SEARCH_BACKUP_DIR}" ]; then
# 		echo "Moving old work directory out of the way ${ELASTIC_SEARCH_BACKUP_DIR}"
# 		mv "${ELASTIC_SEARCH_BACKUP_DIR}" "${BACKUP_DIR}/lost+found-work-backup-$(date +%Y%m%d%H%M%S)"
# 	fi
# 	
# 	bash ${BASH_OPTS} "${SCRIPT_DIR}/backup.sh"
# 	
# 	if ! [ -d "${ELASTIC_SEARCH_BACKUP_DIR}" ]; then
# 		echo "Backup directory does not exist after backup. Failed backup?"
# 		exit 1
# 	fi
# 	
# 	echo "Compressing new backup..."
# 	COMPRESSED_BACKUP_FILE="${BACKUP_FILE_PREFIX}-$(date +%Y%m%d%H%M%S).tgz"
# 	(cd "${ELASTIC_SEARCH_BACKUP_DIR}" && \
# 		tar zcf "${COMPRESSED_BACKUP_FILE}" *)
# 	if mv "${ELASTIC_SEARCH_BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}" "${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}"; then
# 		echo "Moved to ${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}. Cleaning up uncompressed backup..."
# 		_remove_dir "${ELASTIC_SEARCH_BACKUP_DIR}"
# 		echo "Done!"
# 	else
# 		echo "Creation of backup archive failed. Target directory '${ELASTIC_SEARCH_BACKUP_DIR}' left as is."
# 		exit 1
# 	fi
# }

# vlo_restore() {
# 	BACKUP_DIR="${COMPOSE_DIR}/${BACKUP_DIR_RELATIVE_PATH}" #host only dir
# 	if ! [ -d "${BACKUP_DIR}" ]; then
# 		echo "Backup directory ${BACKUP_DIR} not found! Place a backup file in this location and try again."
# 		exit 1
# 	fi
# 	
# 	LAST_BACKUP_FILE=`find "${BACKUP_DIR}" -maxdepth 1 -name "${BACKUP_FILE_PREFIX}*.tgz" | sort | tail -n 1`	
# 	if [ "${LAST_BACKUP_FILE}" = "" ] || ! [ -e "${LAST_BACKUP_FILE}" ]; then
# 		echo "No backup file '${BACKUP_FILE_PREFIX}....tgz' found in ${BACKUP_DIR}. Place a backup file in this location and try again."
# 		exit 1
# 	fi
# 	
# 	if service_is_running ${ELASTICSEARCH_SERVICE}; then
# 		echo -e "Elasticsearch is running. Starting procedure to restore '${LAST_BACKUP_FILE}'...\n"
# 	else
# 		echo "Elasticsearch is not running. Please start Elasticsearch and try again.."
# 		exit 1
# 	fi
# 	
# 	echo "Uncompressing backup..."
# 	WORK_DIR="${BACKUP_DIR}/work-restore"
# 	if [ -d "${WORK_DIR}" ]; then
# 		echo "Moving old work directory out of the way ${WORK_DIR}"
# 		mv "${WORK_DIR}" "${BACKUP_DIR}/lost+found-work-restore-$(date +%Y%m%d%H%M%S)"
# 	fi
# 	mkdir -p "${WORK_DIR}"
# 	tar zxf "${LAST_BACKUP_FILE}" -C "${WORK_DIR}"
# 	
# 	export ELASTIC_COMPOSE_DIR="${COMPOSE_DIR}"
# 	export ELASTIC_SEARCH_BACKUP_DIR="${WORK_DIR}/backup" #'backup' dir expected (result of extracting from /var/backup in image on backup)
# 
# 	export_credentials
# 
# 	bash ${BASH_OPTS} "${SCRIPT_DIR}/restore.sh"
# 	
# 	echo "Cleaning up..."
# 	_remove_dir "${WORK_DIR}"
# 	
# 	if ! service_is_running "${ELASTICSEARCH_SERVICE}"; then
# 		vlo_start
# 	fi
# }



_docker-compose() {
	(cd $COMPOSE_DIR && docker-compose $@)
}

service_is_running() {
    if ! (_docker-compose ps $1 |grep -q "Up "); then
        return 1
    else
        return 0
    fi
}

export_credentials() {
	eval "$(grep "VLO_DOCKER_SOLR_PASSWORD_ADMIN" "${COMPOSE_DIR}/.env")"
	export VLO_DOCKER_SOLR_PASSWORD_ADMIN
}

read_compose_modules() {
	OVERLAYS_LIST_FILE="${BASE_DIR}/.compose-overlays"
	if [ -e "${OVERLAYS_LIST_FILE}" ]; then
		for OVERLAY in $(grep -v -e "^#" "$OVERLAYS_LIST_FILE"); do
			OVERLAY_FILE="${OVERLAY}.yml"
			echo "Including compose overlay ${OVERLAY_FILE}" >&2
			echo -n "-f ${OVERLAY_FILE} "
		done
	else
		echo "No file ${OVERLAYS_LIST_FILE} found, continuing without additional overlays" >&2
	fi
}

main $@