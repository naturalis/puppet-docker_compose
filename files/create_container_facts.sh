#!/bin/bash
# 
# Create external facts for docker containers 
#
JSON_FILE=/etc/facter/facts.d/metadata_containers.json

# get container info from docker ps -a, add comma after each line
CONTAINER_INFO=`docker ps -a --no-trunc --format '{{json .}}' | while read line ; do echo $line"," ; done`

# strip last comma
CONTAINER_INFO=${CONTAINER_INFO%?};

# fix incorrect json for docker command
CONTAINER_INFO=${CONTAINER_INFO//\"Command\":\"\"/\"Command\":\"}
CONTAINER_INFO=${CONTAINER_INFO//\"\"\,\"CreatedAt\"/\"\,\"CreatedAt\"}

# add header and footer
CONTAINER_INFO="{\"metadata_containers\": [ ${CONTAINER_INFO} ]}"

echo $CONTAINER_INFO > $JSON_FILE

