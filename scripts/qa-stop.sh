#!/usr/bin/env bash
# scripts/qa-stop.sh — stop processes started by qa-boot.sh.
#
# Reads logs/pids.txt (lines: "name=pid"), kills each PID with SIGTERM
# (then SIGKILL after 2s), and as a safety net frees ports 5001 and 8081.
# Leaves the iOS simulator running on purpose — preserves QA state between
# runs.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PIDS_FILE="$REPO_ROOT/logs/pids.txt"

GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

if [[ -f "$PIDS_FILE" ]]; then
  while IFS='=' read -r name pid; do
    [[ -z "${pid:-}" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      echo "Stopping $name (PID $pid)..."
      kill "$pid" 2>/dev/null || true
      # gentle wait
      for _ in 1 2; do
        sleep 1
        kill -0 "$pid" 2>/dev/null || break
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
  done < "$PIDS_FILE"
else
  printf "%b\n" "${YELLOW}!${NC} no pids file at $PIDS_FILE — falling back to port kill"
fi

# Safety net: kill anything still on the ports we use
lsof -ti :5001 :8081 2>/dev/null | xargs kill -9 2>/dev/null || true

# Truncate the pids file so a fresh boot starts clean
: > "$PIDS_FILE" 2>/dev/null || true

printf "%b\n" "${GREEN}🛑 backend stopped, metro stopped. iOS sim left running.${NC}"
