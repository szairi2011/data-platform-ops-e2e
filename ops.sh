#!/usr/bin/env bash
# ops.sh — Operator CLI for data-platform-ops-e2e
# Usage: ./ops.sh <command> <target>
#
#   start  yarn|airflow|governance|all
#   stop   yarn|airflow|governance|all
#   build  spark-jobs
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

YARN_DIR="$REPO_ROOT/yarn-cluster"
AIRFLOW_DIR="$REPO_ROOT/airflow-dags-prod"
GOVERNANCE_DIR="$REPO_ROOT/data-governance"

# --------------------------------------------------szairi2011-------------------------
# Helpers
# ---------------------------------------------------------------------------

dc_up() {
  local dir="$1"
  echo "==> Starting stack in $dir"
  docker compose -f "$dir/docker-compose.yml" up -d
}

dc_down() {
  local dir="$1"
  echo "==> Stopping stack in $dir"
  docker compose -f "$dir/docker-compose.yml" down
}

usage() {
  echo "Usage: $0 <command> <target>"
  echo ""
  echo "Commands:"
  echo "  start  yarn|airflow|governance|all"
  echo "  stop   yarn|airflow|governance|all"
  echo "  build  spark-jobs"
  exit 1
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_start() {
  case "$1" in
    yarn)       dc_up "$YARN_DIR" ;;
    airflow)    dc_up "$AIRFLOW_DIR" ;;
    governance) dc_up "$GOVERNANCE_DIR" ;;
    all)
      dc_up "$YARN_DIR"
      dc_up "$AIRFLOW_DIR"
      dc_up "$GOVERNANCE_DIR"
      ;;
    *) echo "Unknown target: $1"; usage ;;
  esac
}

cmd_stop() {
  case "$1" in
    yarn)       dc_down "$YARN_DIR" ;;
    airflow)    dc_down "$AIRFLOW_DIR" ;;
    governance) dc_down "$GOVERNANCE_DIR" ;;
    all)
      dc_down "$GOVERNANCE_DIR"
      dc_down "$AIRFLOW_DIR"
      dc_down "$YARN_DIR"
      ;;
    *) echo "Unknown target: $1"; usage ;;
  esac
}

cmd_build() {
  case "$1" in
    spark-jobs)
      local JOBS_DIR="$REPO_ROOT/spark-jobs"
      echo "==> Building spark-jobs assembly JAR..."
      sbt -J-Xmx2g -f "$JOBS_DIR/build.sbt" clean assembly

      JAR_PATH=$(find "$JOBS_DIR/target" -name "*-assembly-*.jar" | head -1)
      if [[ -z "$JAR_PATH" ]]; then
        echo "ERROR: assembly JAR not found under $JOBS_DIR/target"
        exit 1
      fi

      echo "==> Uploading JAR to HDFS..."
      docker exec namenode hdfs dfs -mkdir -p /jars
      docker cp "$JAR_PATH" namenode:/tmp/spark-jobs-assembly.jar
      docker exec namenode hdfs dfs -put -f /tmp/spark-jobs-assembly.jar /jars/spark-jobs-assembly.jar

      echo "==> JAR uploaded to hdfs:///jars/spark-jobs-assembly.jar"
      ;;
    *) echo "Unknown build target: $1"; usage ;;
  esac
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

[[ $# -lt 2 ]] && usage

COMMAND="$1"
TARGET="$2"

case "$COMMAND" in
  start) cmd_start "$TARGET" ;;
  stop)  cmd_stop  "$TARGET" ;;
  build) cmd_build "$TARGET" ;;
  *)     echo "Unknown command: $COMMAND"; usage ;;
esac
