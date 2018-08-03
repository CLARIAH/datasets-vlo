#!/usr/bin/env bash
set -e

function pw_hash {
	java -jar /opt/solr-init/SolrPasswordHash.jar $1
}

PROVISIONING_SECURITY_JSON=${SOLR_HOME_PROVISIONING_PATH}/security.json
HOME_SECURITY_JSON=${SOLR_HOME}/security.json

export VLO_DOCKER_SOLR_PASSWORD_READ_ONLY_HASH="$(pw_hash $VLO_DOCKER_SOLR_PASSWORD_READ_ONLY)"
export VLO_DOCKER_SOLR_PASSWORD_READ_WRITE_HASH="$(pw_hash $VLO_DOCKER_SOLR_PASSWORD_READ_WRITE)"
export VLO_DOCKER_SOLR_PASSWORD_ADMIN_HASH="$(pw_hash $VLO_DOCKER_SOLR_PASSWORD_ADMIN)"

if [  -e "$PROVISIONING_SECURITY_JSON" ]; then
	bash /opt/solr-init/filter-config-file.sh "${PROVISIONING_SECURITY_JSON}" \
		VLO_DOCKER_SOLR_USER_READ_ONLY \
		VLO_DOCKER_SOLR_PASSWORD_READ_ONLY_HASH \
		VLO_DOCKER_SOLR_USER_READ_WRITE \
		VLO_DOCKER_SOLR_PASSWORD_READ_WRITE_HASH \
		VLO_DOCKER_SOLR_PASSWORD_ADMIN_HASH
fi

if [ -e "$HOME_SECURITY_JSON" ]; then
	bash /opt/solr-init/filter-config-file.sh "${HOME_SECURITY_JSON}" \
		VLO_DOCKER_SOLR_USER_READ_ONLY \
		VLO_DOCKER_SOLR_PASSWORD_READ_ONLY_HASH \
		VLO_DOCKER_SOLR_USER_READ_WRITE \
		VLO_DOCKER_SOLR_PASSWORD_READ_WRITE_HASH \
		VLO_DOCKER_SOLR_PASSWORD_ADMIN_HASH
fi
	