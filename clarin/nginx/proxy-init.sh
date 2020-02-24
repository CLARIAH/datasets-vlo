#!/bin/bash
echo -n "Checking VLO front end availability... "
if ! wait-for -t 5 vlo-web:8080; then
  echo "Waiting for VLO front end..."
  wait-for vlo-web:8080
fi
echo "Connected to front end"

