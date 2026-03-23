#!/bin/bash

# Load environment variables
set -a
source "${WORKSPACE_FOLDER}/.env"
set +a

# Create data directory
mkdir -p "${WORKSPACE_FOLDER}/data/mysql"

# Start or run MySQL container
docker start mysql 2>/dev/null || \
docker run -d --name mysql \
    -p ${DB_PORT:-3306}:3306 \
    -v ${WORKSPACE_FOLDER}/data/mysql:/var/lib/mysql \
    -e MYSQL_ROOT_HOST=% \
    -e MYSQL_ROOT_PASSWORD="${DB_PASSWORD:-root}" \
    -e MYSQL_DATABASE=${DB_NAME:-dev} \
    mysql:8.0

