#!/bin/bash
set -e

# Match host docker socket GID so gitlab-runner can run docker commands.
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    if ! getent group "$DOCKER_GID" > /dev/null 2>&1; then
        groupadd -g "$DOCKER_GID" docker-host
    fi
    usermod -aG "$DOCKER_GID" gitlab-runner
fi

# Ensure home directory exists (may be missing after package installs).
mkdir -p /home/gitlab-runner
chown gitlab-runner:gitlab-runner /home/gitlab-runner

exec /entrypoint "$@"
