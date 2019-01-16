#!/usr/bin/env bash
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
. "${BASE_DIR}/script/_inc.sh"

set -e

main() {

	if [ "$1" != "-f" ]; then
		echo "WARNING: Skipping backup. Run with '-f' option to force backup."
		exit 0
	fi

	if service_is_running ${VLO_SOLR_SERVICE}; then
		echo -e "VLO Solr is running. Starting backup procedure...\n"
	else
		echo "VLO Solr does not seem to be running. Please start the service and try again.."
		exit 1
	fi

	BACKUP_DIR="${HOST_BACKUP_DIR}" #"${COMPOSE_DIR}/${BACKUP_DIR_RELATIVE_PATH}" #host only dir
	VLO_SOLR_BACKUP_DIR="${BACKUP_DIR}/work-backup"
	export TARGET_DIR="${VLO_SOLR_BACKUP_DIR}"
	
	export_credentials
	
	if ! (mkdir -p "${BACKUP_DIR}" && [ -d "${BACKUP_DIR}" ] && [ -x "${BACKUP_DIR}" ]); then
		echo "Cannot create and/or access backup directory ${BACKUP_DIR}"
		exit 1
	fi
	
# 	echo "Archiving old backups..."
# 	mkdir -p "${BACKUP_DIR}/archived"
# 	(
# 		cd "${BACKUP_DIR}"
# 		mv "${BACKUP_FILE_PREFIX}"*".tgz" "archived/" && echo " Done" || echo " Nothing to do"
# 	)
# 	
# 	if [ -d "${VLO_SOLR_BACKUP_DIR}" ]; then
# 		echo "Moving old work directory out of the way ${VLO_SOLR_BACKUP_DIR}"
# 		mv "${VLO_SOLR_BACKUP_DIR}" "${BACKUP_DIR}/lost+found-work-backup-$(date +%Y%m%d%H%M%S)"
# 	fi
	
	check_env
	check_replication_service
	cleanup_backup
	set_permissions
	do_backup
	extract_backup
	remove_backup
	cleanup_backup
	
	if ! [ -d "${VLO_SOLR_BACKUP_DIR}" ]; then
		echo "Backup directory does not exist after backup. Failed backup?"
		exit 1
	fi
	
	echo "Compressing new backup..."
	COMPRESSED_BACKUP_FILE="${BACKUP_FILE_PREFIX}-$(date +%Y%m%d%H%M%S).tgz"
	(cd "${VLO_SOLR_BACKUP_DIR}" && \
		tar zcf "${COMPRESSED_BACKUP_FILE}" *)
	if mv "${VLO_SOLR_BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}" "${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}"; then
		echo "Moved to ${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}. Cleaning up uncompressed backup..."
		_remove_dir "${VLO_SOLR_BACKUP_DIR}"
		echo "Done!"
	else
		echo "Creation of backup archive failed. Target directory '${VLO_SOLR_BACKUP_DIR}' left as is."
		exit 1
	fi
}

check_env() {
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

set_permissions() {
	echo -e "Setting target permission...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker-compose exec -T -u root "${VLO_SOLR_SERVICE}" chown -R solr "${CONTAINER_BACKUP_DIR}" )
}

get_backup_status() {
	solr_api_get "${VLO_SOLR_INDEX_URL}/replication?command=details"
}

do_backup() {
	echo -e "\nCarrying out backup...\n"
	if solr_api_get "${VLO_SOLR_INDEX_URL}/replication?command=backup&location=${CONTAINER_BACKUP_DIR}&name=${BACKUP_NAME:-backup}"; then
		echo "Checking status..."
		SUCCESS="false"
		while [ "$SUCCESS" != "true" ]; do
			if get_backup_status | grep "success"; then
				SUCCESS="true"
			else
				if get_backup_status | grep "exception"; then
					echo "Exception occurred. Terminating..."
					remove_backup
					cleanup_backup
					exit 1
				else
					echo "Not successful (yet). Status: "
					get_backup_status
					echo "Checking again in 5 seconds..."
					sleep 5
				fi
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

extract_backup() {
	
	if [ ! -e "${TARGET_DIR}" ]; then
		echo -e "Making target directory ${TARGET_DIR}...\n"
		mkdir -p "${TARGET_DIR}"
	fi

	echo -e "Extracting to ${TARGET_DIR}...\n"
	(cd $VLO_COMPOSE_DIR && \
		docker cp "vlo_${VLO_SOLR_SERVICE}_1:${CONTAINER_BACKUP_DIR}" "${TARGET_DIR}")
}

remove_backup() {
	echo -e "Deleting backup from volume...\n"
	
	if ! solr_api_get \
			"${VLO_SOLR_INDEX_URL}/replication?command=deletebackup&location=${CONTAINER_BACKUP_DIR}&name=${BACKUP_NAME:-backup}"; then
		echo "Failed to delete backup!" 
	fi
}

cleanup_backup() {
	echo -e "Cleaning up...\n"
	
	(cd $VLO_COMPOSE_DIR && \
		docker-compose exec -T "${VLO_SOLR_SERVICE}" bash -c "if [ -d '${CONTAINER_BACKUP_DIR}' ]; then rm -rf ${CONTAINER_BACKUP_DIR}/*; fi")
}

main $@
