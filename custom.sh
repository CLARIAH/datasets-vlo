#!/usr/bin/env bash
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "${BASE_DIR}/script/_inc.sh"

sub_help(){
    echo "Usage: ${PROGRAM_NAME} <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "    run-import                Start an import inside the running VLO container"
    echo "    run-link-status-update    Start an update of the indexed link status inside the running VLO container"
    echo "    update-linkchecker-db     Start an update of the link checker database inside the running MongoDB container "
    echo ""
    echo "    restart-web-app           Restart VLO web app (no recreate) "
    echo "    restart-solr              Restart VLO Solr instance (no recreate) "
    echo "    restart-mongo             Restart mongo linkchecker database (no recreate) "
    
    
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

sub_restart-mongo() {
	_docker-compose ${COMPOSE_OPTS} restart "${VLO_LINKCHECKER_MONGO_SERVICE}"
}

sub_update-linkchecker-db() {
	bash "${BASE_DIR}/script/retrieve-linkcheck-mongo-db.sh"
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
