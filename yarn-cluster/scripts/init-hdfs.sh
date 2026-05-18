#!/usr/bin/env bash
# init-hdfs.sh — Create required HDFS directories on first start.
# Runs as an init container (depends_on: namenode healthy).
# Script is idempotent: uses -p flag everywhere.
set -euo pipefail

echo "==> Waiting for HDFS to accept commands..."
until hdfs dfs -ls / &>/dev/null 2>&1; do
    sleep 2
done

echo "==> Creating HDFS directory tree..."
hdfs dfs -mkdir -p /data/raw
hdfs dfs -mkdir -p /data/bronze
hdfs dfs -mkdir -p /data/silver
hdfs dfs -mkdir -p /data/gold
hdfs dfs -mkdir -p /data/dead-letter
hdfs dfs -mkdir -p /jars
hdfs dfs -mkdir -p /user/spark/spark3ApplicationHistory

echo "==> Setting permissions..."
hdfs dfs -chmod 1777 /user/spark/spark3ApplicationHistory
hdfs dfs -chmod 777  /data
hdfs dfs -chmod 777  /jars

echo "==> HDFS init complete."
hdfs dfs -ls /
