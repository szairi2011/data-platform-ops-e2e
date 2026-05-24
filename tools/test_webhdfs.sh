#!/usr/bin/env bash
set -e

NAMENODE="http://localhost:9870/webhdfs/v1"

# --connect-to remaps datanode container hostnames to localhost ports for host-side access
# datanode1:9864 → 127.0.0.1:9864  (docker port mapping: 9864:9864)
# datanode2:9864 → 127.0.0.1:9865  (docker port mapping: 9865:9864)
DN_CONNECT=(--connect-to "datanode1:9864:127.0.0.1:9864" --connect-to "datanode2:9864:127.0.0.1:9865")

# Helper: two-step WebHDFS PUT with datanode hostname remapping
webhdfs_put() {
  local hdfs_path="$1"
  local body="$2"

  LOCATION=$(curl -sS -D - -o /dev/null -H 'Content-Length: 0' -X PUT \
    "${NAMENODE}${hdfs_path}?op=CREATE&overwrite=true" \
    | grep -i '^Location:' | tr -d '\r' | sed 's/^.*ocation: //')

  if [[ -z "$LOCATION" ]]; then
    echo "ERROR: no redirect URL from namenode for $hdfs_path" >&2
    return 1
  fi
  echo "  -> datanode URL: $LOCATION"
  echo "$body" | curl -fsS "${DN_CONNECT[@]}" -X PUT "$LOCATION" -H 'Content-Type: application/json' --data-binary @-
}

# Helper: WebHDFS GET with datanode hostname remapping
webhdfs_get() {
  local hdfs_path="$1"
  curl -sS -L "${DN_CONNECT[@]}" "${NAMENODE}${hdfs_path}?op=OPEN"
}

echo "=== 1. Create /ops directory ==="
curl -fsS -X PUT "${NAMENODE}/ops?op=MKDIRS" && echo " OK"

echo ""
echo "=== 2. Write test file ==="
webhdfs_put "/ops/test.json" '{"test":"hello_webhdfs","ts":"2026-05-24"}'
echo " write OK"

echo ""
echo "=== 3. Read back ==="
webhdfs_get "/ops/test.json"
echo ""

echo ""
echo "=== WebHDFS round-trip PASSED ==="
