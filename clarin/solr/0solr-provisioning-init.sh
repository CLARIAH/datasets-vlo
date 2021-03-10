#!/bin/bash

if ! [ -f "${SOLR_HOME_PROVISIONING_PATH}/solr.xml" ]; then
	echo "FATAL: expected '${SOLR_HOME_PROVISIONING_PATH}/solr.xml' but did not find"
	exit 1
fi

echo "Filtering solr security settings"

if ! bash '/opt/solr-init/filter-solr-security.sh'; then
	echo "FATAL: error while filtering solr security settings"
	exit 1
fi
