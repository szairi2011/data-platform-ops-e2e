#!/bin/bash
set -e

# Format NameNode on first boot (idempotent: checks for existing data)
if [ "$1" = "hdfs" ] && [ "$2" = "namenode" ]; then
    if [ ! -d "${HADOOP_HOME}/data/namenode/current" ]; then
        echo "==> First boot: formatting NameNode..."
        hdfs namenode -format -nonInteractive -clusterId yarn-cluster
    fi
fi

exec "$@"
