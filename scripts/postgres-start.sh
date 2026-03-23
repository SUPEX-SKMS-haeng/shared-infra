#!/bin/bash

# Load environment variables
set -a
source "${WORKSPACE_FOLDER}/.env"
set +a

# Create data directory
mkdir -p "${WORKSPACE_FOLDER}/data/postgres"

# Start or run PostgreSQL container
docker start postgres 2>/dev/null || \
docker run -d --name postgres \
    -p ${POSTGRES_PORT:-5432}:5432 \
    -v ${WORKSPACE_FOLDER}/data/postgres:/var/lib/postgresql/data \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}" \
    -e POSTGRES_USER="${POSTGRES_USER:-postgres}" \
    -e POSTGRES_DB=${POSTGRES_DB:-dev} \
    postgres:16
