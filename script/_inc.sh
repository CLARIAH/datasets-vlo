#!/usr/bin/env bash
SCRIPT_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
PROJECT_BASE_DIR="$SCRIPT_BASE_DIR/.."
VLO_COMPOSE_DIR="${PROJECT_BASE_DIR}/clarin"

VLO_WEB_SERVICE="vlo-web"
VLO_SOLR_SERVICE="vlo-solr"

SOLR_HOME_PROVISIONING_VOLUME_NAME="solr-home-provisioning"

VLO_SOLR_INDEX_URL="${VLO_SOLR_INDEX_URL:-http://localhost:8983/solr/vlo-index}"
VLO_SOLR_INDEX_REMOTE_URL="${VLO_SOLR_INDEX_REMOTE_URL:-http://${VLO_SOLR_SERVICE}:8983/solr/vlo-index}"
CONTAINER_BACKUP_DIR="${CONTAINER_BACKUP_DIR:-/var/backup}"
HOST_BACKUP_DIR="${HOST_BACKUP_DIR:-${PROJECT_BASE_DIR}/../backups}"
BACKUP_NAME="${VLO_SOLR_BACKUP_NAME:-vlo-index}"
BACKUP_FILE_PREFIX="vlo-backup"

VLO_IMAGE_IMPORT_COMMAND="/opt/importer.sh"

check_service() {
	#see if solr can be reached from web container (curl exit code 22 is ok, likely a 401)
	#run in sub shell to allow for exit code analysis but prevent termination due to non-zero exit code
	bash -c '(
		(cd '${VLO_COMPOSE_DIR}' && docker-compose exec -T '${VLO_WEB_SERVICE}' \
			curl -s -f "'${VLO_SOLR_INDEX_REMOTE_URL}'") > /dev/null 2>&1
		service_status=$?
		if [ "$service_status" -ne 0 ] && [ "$service_status" -ne 22 ]; then
			exit 1
		fi
		)'
}

check_replication_service() {	
	if ! (cd $VLO_COMPOSE_DIR && docker-compose exec -T ${VLO_SOLR_SERVICE} \
		curl -s -f -u ${VLO_SOLR_BACKUP_USERNAME}:${VLO_SOLR_BACKUP_PASSWORD} "${VLO_SOLR_INDEX_URL}/replication") > /dev/null
	then
		echo -e "Fatal: could not connect to Solr's replication API! Are the services running and credentials configured correctly?\n\n"
		(cd $VLO_COMPOSE_DIR && docker-compose ps)
		exit 3
	fi
}

service_is_running() {
    if ! (_docker-compose ps $1 |grep -q "Up "); then
        return 1
    else
        return 0
    fi
}


solr_api_get() {
	(cd $VLO_COMPOSE_DIR && 
		docker-compose exec -T "${VLO_SOLR_SERVICE}" curl -s -f -u ${VLO_SOLR_BACKUP_USERNAME}:${VLO_SOLR_BACKUP_PASSWORD} $@)
}

_remove_dir() {
	if [ -n "$1" ] && [ -d "$1" ]; then
		(cd "$1" \
			&& if [ $(ls -f | wc -l) -gt 0 ]; then rm -rf -- *; fi) \
			&& rmdir -- "$1"
	else
		echo "Remove directory: $1 not found"
		return 1
	fi
}

_docker-compose() {
	(cd $VLO_COMPOSE_DIR && docker-compose $@)
}

export_credentials() {
	eval "$(grep "VLO_DOCKER_SOLR_PASSWORD_ADMIN" "${VLO_COMPOSE_DIR}/.env")"
	export VLO_SOLR_BACKUP_USERNAME="${VLO_DOCKER_SOLR_ADMIN_USER:-user_admin}"
	export VLO_SOLR_BACKUP_PASSWORD="${VLO_DOCKER_SOLR_PASSWORD_ADMIN}"
}
