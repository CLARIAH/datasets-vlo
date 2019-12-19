#!/bin/sh
echo "Waiting for Solr at ${SOLR_HOST}:${SOLR_PORT}"
wait-for ${SOLR_HOST}:${SOLR_PORT} -t 3600

