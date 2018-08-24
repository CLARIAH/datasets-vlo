# Common functions and variables for backup.sh and restore.sh

VLO_SOLR_INDEX_URL="${VLO_SOLR_INDEX_URL:-http://localhost:8983/solr/vlo-index}"
CONTAINER_BACKUP_DIR="${CONTAINER_BACKUP_DIR:-/var/backup}"

check_service() {	
	if ! docker-compose exec vlo-solr curl -f -u ${SOLR_USERNAME}:${SOLR_PASSWORD} "${VLO_SOLR_INDEX_URL}/replication" > /dev/null
	then
		echo -e "Fatal: could not connect to Solr's replication API! Are the services running and credentials configured correctly?\n\n"
		(cd $VLO_COMPOSE_DIR && docker-compose ps)
		exit 3
	fi
}
