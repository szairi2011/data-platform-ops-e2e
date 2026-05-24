#!/usr/bin/env bash
# Simulate a CI deploy: write the manifest that jar_version_watcher polls.
# Run from repo root: bash simulate_deploy.sh [version]
set -euo pipefail

NAMENODE="http://localhost:9870/webhdfs/v1"
VERSION="${1:-smoke001}"
JAR_PATH="hdfs:///jars/spark-jobs-assembly-0.1.0.jar"
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

DN_CONNECT=(--connect-to "datanode1:9864:127.0.0.1:9864" --connect-to "datanode2:9864:127.0.0.1:9865")

webhdfs_put() {
  local hdfs_path="$1"
  local body="$2"
  LOCATION=$(curl -sS -D - -o /dev/null -H 'Content-Length: 0' -X PUT \
    "${NAMENODE}${hdfs_path}?op=CREATE&overwrite=true" \
    | grep -i '^Location:' | tr -d '\r' | sed 's/^.*ocation: //')
  if [[ -z "$LOCATION" ]]; then
    echo "ERROR: no redirect for $hdfs_path" >&2; return 1
  fi
  echo "$body" | curl -fsS "${DN_CONNECT[@]}" -X PUT "$LOCATION" \
    -H 'Content-Type: application/json' --data-binary @-
}

# 1. Verify JAR exists on HDFS
echo "=== Verifying JAR on HDFS ==="
STATUS=$(curl -s "${NAMENODE}/jars/spark-jobs-assembly-0.1.0.jar?op=GETFILESTATUS")
LENGTH=$(echo "$STATUS" | grep -o '"length":[0-9]*' | head -1 | cut -d: -f2)
echo "  JAR size: ${LENGTH} bytes"
if [[ -z "$LENGTH" || "$LENGTH" == "0" ]]; then
  echo "ERROR: JAR not found or empty on HDFS" >&2; exit 1
fi

# 2. Ensure /ops dir exists
echo ""
echo "=== Creating /ops directory ==="
curl -fsS -X PUT "${NAMENODE}/ops?op=MKDIRS" && echo " OK"

# 3. Write manifest
MANIFEST=$(printf '{"version":"%s","jar_path":"%s","pipeline_id":"local-sim","commit_ref":"main","deployed_at":"%s"}' \
  "$VERSION" "$JAR_PATH" "$DEPLOYED_AT")
echo ""
echo "=== Writing manifest: $MANIFEST ==="
webhdfs_put "/ops/deploy-trigger.json" "$MANIFEST"
echo " manifest written"

# 4. Verify it's readable
echo ""
echo "=== Verify manifest readable ==="
curl -sS -L "${DN_CONNECT[@]}" "${NAMENODE}/ops/deploy-trigger.json?op=OPEN"
echo ""

echo ""
echo "=== Deploy simulation DONE — version=$VERSION ==="
echo "    Watch Airflow UI at http://localhost:8080"
echo "    jar_version_watcher should fire within 60 seconds"
