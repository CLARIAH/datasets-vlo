#!/usr/bin/env bash
SCRIPT_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
VLO_COMPOSE_DIR="${SCRIPT_BASE_DIR}/../clarin"

VLO_WEB_SERVICE="vlo-web"
VLO_SOLR_SERVICE="vlo-solr"

SOLR_HOME_PROVISIONING_VOLUME_NAME="solr-home-provisioning"

VLO_SOLR_INDEX_URL="${VLO_SOLR_INDEX_URL:-http://localhost:8983/solr/vlo-index}"
CONTAINER_BACKUP_DIR="${CONTAINER_BACKUP_DIR:-/var/backup}"
HOST_BACKUP_DIR="${VLO_SOLR_BACKUP_DIR:-/tmp/vlo-solr-backup}"
BACKUP_NAME="${VLO_SOLR_BACKUP_NAME:-vlo-index}"

VLO_IMAGE_IMPORT_COMMAND="/opt/importer.sh"

check_service() {	
	if ! (cd $VLO_COMPOSE_DIR && docker-compose exec -T ${VLO_SOLR_SERVICE} \
		curl -s -f -u ${VLO_SOLR_BACKUP_USERNAME}:${VLO_SOLR_BACKUP_PASSWORD} "${VLO_SOLR_INDEX_URL}/replication") > /dev/null
	then
		echo -e "Fatal: could not connect to Solr's replication API! Are the services running and credentials configured correctly?\n\n"
		(cd $VLO_COMPOSE_DIR && docker-compose ps)
		exit 3
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
