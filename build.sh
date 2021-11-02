#!/bin/bash

set -e

#build environment
docker-compose up -d

#add source connector
docker exec -it connect confluent-hub install debezium/debezium-connector-postgresql:1.7.0 --no-prompt
docker restart connect

#add sink connector
docker exec -it connect confluent-hub install mongodb/kafka-connect-mongodb:1.6.1 --no-prompt
docker restart connect
