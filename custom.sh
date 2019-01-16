#!/usr/bin/env bash
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source "${BASE_DIR}/script/_inc.sh"

sub_help(){
    echo "Usage: ${PROGRAM_NAME} <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "    test           Test subcommand"
    echo ""
    echo "For help with each subcommand run:"
    echo "${PROGRAM_NAME} <subcommand> -h|--help"
    echo ""
}

#todo: run-import
sub_import() {
	if check_service; then
		_docker-compose exec -T ${VLO_WEB_SERVICE} nice -n10 ${VLO_IMAGE_IMPORT_COMMAND}
	else
		echo "Service not running, cannot execute import."
		exit 1
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
    "run-import")
    	sub_import
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
