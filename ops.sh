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
RUNNER_DIR="$REPO_ROOT/gitlab-runner"

# --------------------------------------------------szairi2011-------------------------
# Helpers
# ---------------------------------------------------------------------------

ensure_spark_net() {
  docker network inspect spark-net >/dev/null 2>&1 \
    || docker network create --driver bridge spark-net
}

dc_up() {
  local dir="$1"
  ensure_spark_net
  echo "==> Starting stack in $dir"
  docker compose -f "$dir/docker-compose.yml" up -d
}

dc_down() {
  local dir="$1"
  echo "==> Stopping stack in $dir"
  docker compose -f "$dir/docker-compose.yml" down
}

usage() {
  echo "Usage: $0 <command> <target> [args...]"
  echo ""
  echo "Commands:"
  echo "  start     yarn|airflow|governance|runner|all"
  echo "  stop      yarn|airflow|governance|runner|all"
  echo "  build     spark-jobs|runner|airflow"
  echo "  run       spark-jobs <fully.qualified.ClassName>"
  echo "  register  runner   (one-time interactive GitLab Runner registration)"
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
    runner)     dc_up "$RUNNER_DIR" ;;
    all)
      dc_up "$YARN_DIR"
      dc_up "$AIRFLOW_DIR"
      dc_up "$GOVERNANCE_DIR"
      dc_up "$RUNNER_DIR"
      ;;
    *) echo "Unknown target: $1"; usage ;;
  esac
}

cmd_stop() {
  case "$1" in
    yarn)       dc_down "$YARN_DIR" ;;
    airflow)    dc_down "$AIRFLOW_DIR" ;;
    governance) dc_down "$GOVERNANCE_DIR" ;;
    runner)     dc_down "$RUNNER_DIR" ;;
    all)
      dc_down "$RUNNER_DIR"
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
      (cd "$JOBS_DIR" && SBT_OPTS="-Xmx2g" sbt clean assembly)

      JAR_PATH=$(find "$JOBS_DIR/target" -name "*-assembly-*.jar" | head -1)
      if [[ -z "$JAR_PATH" ]]; then
        echo "ERROR: assembly JAR not found under $JOBS_DIR/target"
        exit 1
      fi

      echo "==> Uploading JAR to HDFS..."
      MSYS_NO_PATHCONV=1 docker exec namenode hdfs dfs -mkdir -p /jars
      # cygpath -w converts /c/Users/... → C:\Users\... so Docker CLI on Windows can find the file
      JAR_WIN=$(cygpath -w "$JAR_PATH" 2>/dev/null || echo "$JAR_PATH")
      MSYS_NO_PATHCONV=1 docker cp "$JAR_WIN" namenode:/tmp/spark-jobs-assembly-0.1.0.jar
      # 1. Upload versioned JAR (matches CI pattern)
      MSYS_NO_PATHCONV=1 docker exec namenode hdfs dfs -put -f /tmp/spark-jobs-assembly-0.1.0.jar /jars/spark-jobs-assembly-0.1.0.jar
      MSYS_NO_PATHCONV=1 docker exec namenode rm /tmp/spark-jobs-assembly-0.1.0.jar
      # 2. Promote: replace canonical path by copying versioned (same as CI self-hosted runner)
      MSYS_NO_PATHCONV=1 docker exec namenode hdfs dfs -rm -f /jars/spark-jobs-assembly.jar || true
      MSYS_NO_PATHCONV=1 docker exec namenode hdfs dfs -cp /jars/spark-jobs-assembly-0.1.0.jar /jars/spark-jobs-assembly.jar

      echo "==> JAR promoted to hdfs:///jars/spark-jobs-assembly.jar (versioned: hdfs:///jars/spark-jobs-assembly-0.1.0.jar)"
      ;;
    runner)
      echo "==> Rebuilding gitlab-runner image..."
      docker compose -f "$RUNNER_DIR/docker-compose.yml" build
      ;;
    airflow)
      echo "==> Rebuilding airflow image..."
      docker compose -f "$AIRFLOW_DIR/docker-compose.yml" build
      ;;
    *) echo "Unknown build target: $1"; usage ;;
  esac
}

cmd_run() {
  case "$1" in
    spark-jobs)
      # Get the class name from the second argument -- e.g. com.dataplatform.bronze.TransactionBronzeIngester
      local CLASS="${2:-}"
      if [[ -z "$CLASS" ]]; then
        echo "ERROR: missing class name"
        echo "Usage: $0 run spark-jobs <fully.qualified.ClassName>"
        exit 1
      fi
      echo "==> Submitting $CLASS to YARN..."
      MSYS_NO_PATHCONV=1 docker exec livy /opt/spark/bin/spark-submit \
        --master yarn \
        --deploy-mode client \
        --class "$CLASS" \
        --conf spark.hadoop.fs.defaultFS=hdfs://namenode:9000 \
        hdfs:///jars/spark-jobs-assembly-0.1.0.jar
      ;;
    *) echo "Unknown run target: $1"; usage ;;
  esac
}

cmd_register() {
  case "$1" in
    runner)
      echo "==> Launching interactive GitLab Runner registration..."
      echo "    You will need:"
      echo "      - GitLab project URL (e.g. https://gitlab.com/your-username/spark-jobs)"
      echo "      - Registration token from: Project → Settings → CI/CD → Runners → New runner"
      echo "      - Executor: shell"
      echo "      - Tag: self-hosted"
      docker exec -it gitlab-runner gitlab-runner register
      ;;
    *) echo "Unknown register target: $1"; usage ;;
  esac
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

[[ $# -lt 2 ]] && usage

COMMAND="$1"
TARGET="$2"

case "$COMMAND" in
  start)    cmd_start    "$TARGET" ;;
  stop)     cmd_stop     "$TARGET" ;;
  build)    cmd_build    "$TARGET" ;;
  run)      cmd_run      "$TARGET" "${3:-}" ;;
  register) cmd_register "$TARGET" ;;
  *)        echo "Unknown command: $COMMAND"; usage ;;
esac
