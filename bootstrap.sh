#!/usr/bin/env bash
# bootstrap.sh — First-time setup for data-platform-ops-e2e
# Usage: ./bootstrap.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Initializing submodules..."
git -C "$REPO_ROOT" submodule update --init --recursive

echo ""
echo "==> Verifying required tooling..."

check_tool() {
  local cmd="$1"
  local label="${2:-$1}"
  if command -v "$cmd" &>/dev/null; then
    echo "  [OK] $label ($(command -v "$cmd"))"
  else
    echo "  [MISSING] $label — please install it before running ops.sh"
  fi
}

check_tool docker       "Docker"
check_tool "docker compose" "Docker Compose v2"
check_tool sbt          "sbt (Scala build tool)"
check_tool java         "Java (JDK)"
check_tool git          "Git"

echo ""
echo "==> Bootstrap complete."
echo "    Run './ops.sh start yarn' to bring up the cluster."
