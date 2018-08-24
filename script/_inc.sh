# Common functions and variables for backup.sh and restore.sh

VLO_SOLR_INDEX_URL="${VLO_SOLR_INDEX_URL:-http://localhost:8983/solr/vlo-index}"
CONTAINER_BACKUP_DIR="${CONTAINER_BACKUP_DIR:-/var/backup}"

check_service() {	
	if ! docker-compose exec \
		vlo-solr curl -f -u ${VLO_SOLR_BACKUP_USERNAME}:${VLO_SOLR_BACKUP_PASSWORD} "${VLO_SOLR_INDEX_URL}/replication" > /dev/null
	then
		echo -e "Fatal: could not connect to Solr's replication API! Are the services running and credentials configured correctly?\n\n"
		(cd $VLO_COMPOSE_DIR && docker-compose ps)
		exit 3
	fi
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