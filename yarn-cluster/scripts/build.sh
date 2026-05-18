#!/usr/bin/env bash
# build.sh — Build images in dependency order.
# Must be run before `docker compose up` on first use.
# Usage: ./scripts/build.sh [--no-cache]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NO_CACHE="${1:-}"

echo "==> [1/3] Building base Hadoop image (yarn-cluster-hadoop:latest)..."
docker build ${NO_CACHE} \
    -t yarn-cluster-hadoop:latest \
    -f "${REPO_ROOT}/docker/hadoop/Dockerfile" \
    "${REPO_ROOT}"

echo "==> [2/3] Building singleuser image (yarn-cluster-singleuser:latest)..."
docker build ${NO_CACHE} \
    -t yarn-cluster-singleuser:latest \
    -f "${REPO_ROOT}/docker/singleuser/Dockerfile" \
    "${REPO_ROOT}"

echo "==> [3/3] Building remaining compose images (livy, nodemanager, hive-metastore, jupyterhub)..."
docker compose -f "${REPO_ROOT}/docker-compose.yml" build ${NO_CACHE}

echo ""
echo "==> All images built. Run: docker compose up -d"
