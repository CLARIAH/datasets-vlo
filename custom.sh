#!/usr/bin/env bash
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "${BASE_DIR}/script/_inc.sh"

sub_help(){
    echo "Usage: ${PROGRAM_NAME} <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "    run-import                Start an import inside the running VLO container"
    echo "    run-link-status-update    Start an update of the indexed link status inside the running VLO container"
    echo "    update-linkchecker-db     Start an update of the link checker database inside the running link checker database "
    echo ""
    echo "    restart-web-app           Restart VLO web app (no container recreate) "
    echo "    restart-solr              Restart VLO Solr instance (no container recreate) "
    echo "    restart-proxy             Restart nginx proxy service (no container recreate) "
    echo "    restart-linkchecker-db    Restart linkchecker database (no container recreate) "
    echo "    restart-jmxtrans          Restart jmxtrans (no container recreate) "
    echo ""
    echo "    drop-solr-data [-f]       Drop the VLO Solr index (requires confirmation unless -f is provided)"
    echo ""    
    echo "For help with each subcommand run:"
    echo "${PROGRAM_NAME} <subcommand> -h|--help"
    echo ""
}

sub_run-import() {
	if check_service; then
		_docker-compose exec -T ${VLO_WEB_SERVICE} nice -n10 ${VLO_IMAGE_IMPORT_COMMAND}
	else
		echo "Service not running, cannot execute import."
		exit 1
	fi
}

sub_run-link-status-update() {
	if check_service; then
		_docker-compose exec -T ${VLO_WEB_SERVICE} nice -n10 ${VLO_IMAGE_LINK_STATUS_UPDATER_COMMAND}
	else
		echo "Service not running, cannot execute import."
		exit 1
	fi
}

sub_restart-web-app() {
	if check_service; then
		_docker-compose ${COMPOSE_OPTS} restart "${VLO_WEB_SERVICE}"
	else
		echo "Service not running, cannot restart."
		exit 1
	fi
}

sub_restart-solr() {
	if check_service; then
		_docker-compose ${COMPOSE_OPTS} restart "${VLO_SOLR_SERVICE}"
	else
		echo "Service not running, cannot restart."
		exit 1
	fi
}

sub_restart-linkchecker-db() {
	_docker-compose ${COMPOSE_OPTS} restart "${VLO_LINKCHECKER_DB_SERVICE}"
}

sub_restart-jmxtrans() {
	_docker-compose ${COMPOSE_OPTS} restart "${VLO_JMXTRANS_SERVICE}"
}

sub_restart-proxy() {
	_docker-compose ${COMPOSE_OPTS} restart "${VLO_PROXY_SERVICE}"
}

sub_update-linkchecker-db() {
	bash "${BASE_DIR}/script/retrieve-linkcheck-db-dump.sh"
}

sub_drop-solr-data() {
	if [ "-f" = "$@" ]; then
		CONFIRMATION="y"
	else
		echo -n "Warning: This will drop all persisted Solr data for the VLO by removing the volume '${VLO_SOLR_DATA_VOLUME}'. Continue? (y/n)"
		read CONFIRMATION
	fi
	
	if [ "y" = "${CONFIRMATION}" ]; then
		echo "Stopping Solr service ..."
		if _docker-compose stop "${VLO_SOLR_SERVICE}" \
			&& _docker-compose rm -f "${VLO_SOLR_SERVICE}" \
			&& echo -n "Removing volume " && docker volume rm "${VLO_SOLR_DATA_VOLUME}"; then
				echo "Restarting Solr service..."
			_docker-compose ${COMPOSE_OPTS} up -d --force-recreate "${VLO_SOLR_SERVICE}"
		else
			echo "Failed to remove Solr data volume '${VLO_SOLR_DATA_VOLUME}'. Service may be left in a broken state!"
			exit 1
		fi
	fi
}

#
# Process subcommands
#
subcommand=$1
case $subcommand in
    "" | "-h" | "--help")
        sub_help
        ;;
    *)
        shift
        sub_${subcommand} $@
        if [ $? = 127 ]; then
            echo "Error: '${subcommand}' is not a known subcommand." >&2
            echo "       Run '${PROGRAM_NAME} --help' for a list of known subcommands." >&2
            exit 1
        fi
        ;;
esac
