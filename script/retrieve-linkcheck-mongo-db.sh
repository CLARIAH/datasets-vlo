#/usr/bin/env bash
VLO_DOCKER_LINK_CHECKER_DUMP_DIR=/home/twagoo/vlo/linkcheckerdump
curl -L https://curate.acdh-dev.oeaw.ac.at/mongoDump.gz > ${VLO_DOCKER_LINK_CHECKER_DUMP_DIR}/dump.gz
#TODO: drop database
docker exec vlo_vlo-linkchecker-mongo_1 nice -n 10 mongorestore --gzip --archive=/data/dump/dump.gz
rm ${VLO_DOCKER_LINK_CHECKER_DUMP_DIR}/dump.gz

