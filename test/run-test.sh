#!/usr/bin/env bash
set -e

POSTFIX_NETWORKNAME=postfix_mail

docker-compose --env-file .env -f ../clarin/docker-compose.yml -f compose-test-override.yml down -v
if [ $(docker network ls |grep "${POSTFIX_NETWORKNAME}"|wc -l)  -eq 0 ]; then
    docker network create "${POSTFIX_NETWORKNAME}"
fi

echo "Starting application..."
docker-compose --env-file .env -f ../clarin/docker-compose.yml -f compose-test-override.yml up

#Verify all containers are closed nicely
number_of_failed_containers="$(docker-compose --env-file .env -f ../clarin/docker-compose.yml -f compose-test-override.yml \
    ps -q | xargs docker inspect -f '{{ .State.ExitCode }}' | grep -c 0 -v | tr -d ' ')"
#cleanup
docker-compose --env-file .env -f ../clarin/docker-compose.yml -f compose-test-override.yml down -v

exit "$number_of_failed_containers"
