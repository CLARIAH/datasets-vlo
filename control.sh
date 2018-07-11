#!/usr/bin/env bash
DIR=$(dirname $BASH_SOURCE)
if [ $(readlink $0) ]; then
        DIR=$(dirname $(readlink $0))
fi

function usage() {
	echo "Usage: 
	$0 --help 
	
		Shows this message
		
	$0 {dev|alpha|testing|beta|production} [docker-compose-opts]
	
		Calls docker compose with the right overlays for the specified
		environment and the specified compose options"
}

if [ "--help" == "$1" ]; then
	usage
	exit 0
fi

ENVIRONMENT=$1
if [ -z "$ENVIRONMENT" ]; then
	usage
	exit 1
fi

shift

EXPECTED_HOSTNAME=""
COMMAND_PARAMS=""

case $ENVIRONMENT in
dev)
	COMMAND_PARAMS="-f dev.yml -f couchdb-rating.yml"
	;;
alpha)
	EXPECTED_HOSTNAME="rs236235"
	COMMAND_PARAMS="-f testing.yml -f jmx.yml -f data.yml -f mopinion.yml"
	;;
beta)
	EXPECTED_HOSTNAME="beta-vlo-clarin.esc.rzg.mpg.de"
	COMMAND_PARAMS="-f beta.yml -f jmx.yml -f data.yml -f mopinion.yml"
	;;
production)
	EXPECTED_HOSTNAME="rs238144"
	COMMAND_PARAMS="-f production.yml -f jmx.yml -f data.yml -f mopinion.yml"
	;;
*)
	echo "Not a recognised environment name: $ENVIRONMENT"
	echo "Type '$0 --help' for help"
	exit 2
esac

if ! [ -z "${EXPECTED_HOSTNAME}" ]; then
	if ! bash "${DIR}/check-hostname.sh" "${EXPECTED_HOSTNAME}"; then
		exit 3
	fi
fi

bash "${DIR}/docker-compose.sh" ${COMMAND_PARAMS} $@
