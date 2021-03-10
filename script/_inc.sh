#!/usr/bin/env bash
SCRIPT_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
export PROJECT_BASE_DIR="$SCRIPT_BASE_DIR/.."
if [ "${COMPOSE_DIR}" ]; then
	export VLO_COMPOSE_DIR="${COMPOSE_DIR}/clarin"
else
	export VLO_COMPOSE_DIR="${PROJECT_BASE_DIR}/clarin"
fi

export VLO_WEB_SERVICE="vlo-web"
export VLO_SOLR_SERVICE="vlo-solr"
export VLO_PROXY_SERVICE="vlo-proxy"
export VLO_JMXTRANS_SERVICE="jmxtrans"
export VLO_LINKCHECKER_DB_SERVICE="vlo-linkchecker-db"

export VLO_SOLR_DATA_VOLUME="vlo-solr-data"

export SOLR_HOME_PROVISIONING_VOLUME_NAME="solr-home-provisioning"

export VLO_SOLR_INDEX_URL="${VLO_SOLR_INDEX_URL:-http://localhost:8183/solr/vlo-index}"
export VLO_SOLR_INDEX_REMOTE_URL="${VLO_SOLR_INDEX_REMOTE_URL:-http://${VLO_SOLR_SERVICE}:8983/solr/vlo-index}"
export CONTAINER_BACKUP_DIR="${CONTAINER_BACKUP_DIR:-/var/backup}"
export HOST_BACKUP_DIR="${HOST_BACKUP_DIR:-${PROJECT_BASE_DIR}/../backups}"
export BACKUP_NAME="${VLO_SOLR_BACKUP_NAME:-vlo-index}"
export BACKUP_FILE_PREFIX="vlo-backup"

export VLO_IMAGE_IMPORT_COMMAND="/opt/importer.sh"
export VLO_IMAGE_LINK_STATUS_UPDATER_COMMAND="/opt/vlo/bin/vlo_link_availability_status_updater.sh /opt/vlo/config/VloConfig.xml"

check_service() {
	#see if solr can be reached from web container (curl exit code 22 is ok, likely a 401)
	#run in sub shell to allow for exit code analysis but prevent termination due to non-zero exit code
	bash -c '(
        (cd '"${VLO_COMPOSE_DIR}"' && docker-compose exec -T '"${VLO_WEB_SERVICE}"' \
                curl -s -f "'"${VLO_SOLR_INDEX_REMOTE_URL}"'") > /dev/null 2>&1
		service_status=$?
		if [ "$service_status" -ne 0 ] && [ "$service_status" -ne 22 ]; then
			exit 1
		fi
		)'
}

check_replication_service() {	
	echo "${VLO_SOLR_INDEX_URL}/replication?command=status"

	if ! (cd "${VLO_COMPOSE_DIR}" && docker-compose exec -T "${VLO_SOLR_SERVICE}" \
		curl -s -f -u "${VLO_SOLR_BACKUP_USERNAME}":"${VLO_SOLR_BACKUP_PASSWORD}" "${VLO_SOLR_INDEX_REMOTE_URL}/replication?command=status") > /dev/null
	then
		echo -e "Fatal: could not connect to Solr's replication API! Are the services running and credentials configured correctly?\n\n"
		(cd "$VLO_COMPOSE_DIR" && docker-compose ps)
		exit 3
	fi
}

service_is_running() {
    if ! (_docker-compose ps "$1" |grep -q "Up "); then
        return 1
    else
        return 0
    fi
}


solr_api_get() {
	(cd "${VLO_COMPOSE_DIR}" && 
		docker-compose exec -T "${VLO_SOLR_SERVICE}" curl -s -f -u "${VLO_SOLR_BACKUP_USERNAME}":"${VLO_SOLR_BACKUP_PASSWORD}" $@)
}

_remove_dir() {
	if [ -n "$1" ] && [ -d "$1" ]; then
		(cd "$1" \
			&& if [ "$(ls -f | wc -l)" -gt 0 ]; then rm -rf -- *; fi) \
			&& rmdir -- "$1"
	else
		echo "Remove directory: $1 not found"
		return 1
	fi
}

_docker-compose() {
	(
		cd "${VLO_COMPOSE_DIR}"
		stdbuf -oL docker-compose --no-ansi "$@" 2>&1 |
		while IFS= read -r line
        do
            info "$line" "compose"
        done
	)
}

export_credentials() {
	eval "$(grep "VLO_DOCKER_SOLR_PASSWORD_ADMIN" "${VLO_COMPOSE_DIR}/.env")"
	export VLO_SOLR_BACKUP_USERNAME="${VLO_DOCKER_SOLR_ADMIN_USER:-user_admin}"
	export VLO_SOLR_BACKUP_PASSWORD="${VLO_DOCKER_SOLR_PASSWORD_ADMIN}"
}

read_env_var() {
	ENV_VAR_FILE=$1
	ENV_VAR_NAME=$2
	
	if ! { [ "${ENV_VAR_FILE}" ] && [ "${ENV_VAR_NAME}" ]; }; then
		echo "Error: provide file name and variable name" > /dev/stderr
		return
	fi
	
	if ! [ -e "${ENV_VAR_FILE}" ]; then
		echo "Error: cannot find .env file at expected location (${ENV_VAR_FILE})" > /dev/stderr
		return
	fi
	
	ENV_VAR_LINE=$(grep -E "^${ENV_VAR_NAME}=" -- "${ENV_VAR_FILE}"|tail -n1)
	
	if ! [ "${ENV_VAR_LINE}" ]; then
		echo "Warning: variable not found: ${ENV_VAR_NAME}" > /dev/stderr
		return
	fi
	
	echo "${ENV_VAR_LINE/${ENV_VAR_NAME}=/}"
}

# logging util functions


debug() {
	tag="${2}"
	if [ "${2}" == "" ]; then
			tag="default"
	fi
	log "DEBUG" "${1}" "${tag}"
}

info() {
    tag="${2}"
    if [ "${2}" == "" ]; then
        tag="default"
    fi
    log "     " "${1}" "${tag}"
}

warn() {
    tag="${2}"
    if [ "${2}" == "" ]; then
        tag="default"
    fi
    log "     " "${1}" "${tag}"
}

error() {
    tag="${2}"
    if [ "${2}" == "" ]; then
        tag="default"
    fi
    log "     " "${1}" "${tag}"
}

fatal() {
    tag="${2}"
    if [ "${2}" == "" ]; then
        tag="default"
    fi
    log "FATAL" "${1}" "${tag}"
    exit 1
}

log() {
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    LVL="$(printf '%6s' "$1")"
    MSG="$2"
    TAG="$(printf '%8s' "$3")"
    LOG_CONTEXT="${BASH_SOURCE[0]}"
    if [ "${LOG_CONTEXT}" ]; then
    	LOG_CONTEXT="$(printf '%15s:%03d' "${LOG_CONTEXT}" "${BASH_LINENO[0]}")"
    fi
    echo "[${TIMESTAMP}] [${LVL}] [${TAG}] [${LOG_CONTEXT}] ${MSG}"
}
