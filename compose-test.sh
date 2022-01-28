#!/usr/bin/env bash

set -e

BUILD_IMAGE="registry.gitlab.com/clarin-eric/build-image:1.3.0"

#
# Set default values for parameters
#
MODE="gitlab"
VERBOSE=0

#
# Process script arguments
#
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
        MODE="help"
        ;;
    -l|--local)
        MODE="local"
        ;;
    -v|--verbose)
        VERBOSE=1
        ;;
    *)
        echo "Unkown option: $key"
        MODE="help"
        ;;
esac
shift # past argument or value
done

# Print parameters if running in verbose mode
if [ ${VERBOSE} -eq 1 ]; then
    set -x
fi

# Source variables if it exists
if [ -f variables.sh ]; then
    . ./variables.sh
fi

#
# Execute based on mode argument
#
if [ ${MODE} == "help" ]; then
    echo ""
    echo "compose-test.sh [-hlv]"
    echo ""
    echo "  -l, --local      Run workflow locally in a local docker container"
    echo "  -v, --verbose    Run in verbose mode"
    echo ""
    echo "  -h, --help       Show help"
    echo ""
    exit 0
elif [ "${MODE}" == "gitlab" ]; then
    #Test
    echo "**** Testing image *******************************"
    if [ ! -d 'test' ]; then
        echo "Test directory (./test/) not found"
        exit 1
    fi
    if [ ! -f 'test/compose-test-override.yml' ]; then
        echo "compose-test-override.yml not found in test directory (./test/compose-test-override.yml)"
        exit 1
    fi
    
    cd -- 'test/'
    ./run-test.sh
    exit $?

elif [ "${MODE}" == "local" ]; then
    #
    # Setup all commands
    #
    if [ ${VERBOSE} -eq 1 ]; then
        FLAGS="-x"
    fi

    #Start the test process
    docker run \
        --volume='/var/run/docker.sock:/var/run/docker.sock' \
        --rm \
        --volume="$PWD":"$PWD" \
        --workdir="$PWD" \
        -it \
        ${BUILD_IMAGE} \
        bash ${FLAGS} ./compose-test.sh
else
    exit 1
fi
