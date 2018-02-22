#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
	COMMAND_PARAMS="-f dev.yml"
	;;
testing)
	COMMAND_PARAMS="-f testing.yml -f jmx.yml -f data.yml"
	;;
alpha)
	EXPECTED_HOSTNAME="rs236235"
	COMMAND_PARAMS="-f testing.yml -f jmx.yml -f data.yml"
	;;
beta)
	EXPECTED_HOSTNAME="beta-vlo-clarin.esc.rzg.mpg.de"
	COMMAND_PARAMS="-f beta.yml -f jmx.yml -f data.yml"
	;;
production)
	EXPECTED_HOSTNAME="lvps92-51-161-129.dedicated.hosteurope.de"
	COMMAND_PARAMS="-f production.yml -f jmx.yml -f data.yml"
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