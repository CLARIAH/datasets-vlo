#!/usr/bin/env bash
set -e

POSTFIX_NETWORKNAME=postfix_mail
COMPOSE_OPTS=(--env-file .env -f ../clarin/docker-compose.yml -f ../clarin/nginx.yml -f compose-test-override.yml)

docker-compose "${COMPOSE_OPTS[@]}" down -v
if [ $(docker network ls |grep "${POSTFIX_NETWORKNAME}"|wc -l)  -eq 0 ]; then
    docker network create "${POSTFIX_NETWORKNAME}"
fi

echo "Starting application..."
docker-compose "${COMPOSE_OPTS[@]}" up

#Verify all containers are closed nicely
number_of_failed_containers="$(docker-compose "${COMPOSE_OPTS[@]}" ps -q \
    | xargs docker inspect -f '{{ .State.ExitCode }}' \
    | grep -c 0 -v \
    | tr -d ' ')"
#cleanup
docker-compose "${COMPOSE_OPTS[@]}" down -v

exit "$number_of_failed_containers"
