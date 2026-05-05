#!/usr/bin/env bash
# scripts/qa-boot.sh — one-shot boot for the wardrobe stack.
#
# Brings up: FastAPI backend (:5001), Metro + iOS simulator + RN app.
# Verifies health at each step. On success, prints the QA regression
# checklist and exits with both apps still running.
#
# Stop with: ./scripts/qa-stop.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
PIDS_FILE="$LOG_DIR/pids.txt"
# shellcheck disable=SC2034
BACKEND_LOG="$LOG_DIR/backend.log"
# shellcheck disable=SC2034
METRO_LOG="$LOG_DIR/metro.log"

# --- output helpers ---
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

log()  { printf "%b\n" "${BLUE}▸${NC} $*"; }
ok()   { printf "%b\n" "${GREEN}✓${NC} $*"; }
warn() { printf "%b\n" "${YELLOW}!${NC} $*"; }
fail() { printf "%b\n" "${RED}✗${NC} $*" >&2; exit 1; }

# --- preflight ---
preflight() {
  log "Preflight checks..."
  cd "$REPO_ROOT"
  [[ -d auxi ]]              || fail "Not at umbrella repo root: auxi/ missing"
  [[ -d wardrobe-backend ]]  || fail "Not at umbrella repo root: wardrobe-backend/ missing"
  command -v xcrun   >/dev/null || fail "xcrun not found — Xcode required"
  command -v python3 >/dev/null || fail "python3 not found"
  command -v yarn    >/dev/null || fail "yarn not found"
  command -v lsof    >/dev/null || fail "lsof not found"
  command -v curl    >/dev/null || fail "curl not found"
  mkdir -p "$LOG_DIR"
  : > "$PIDS_FILE"
  ok "Preflight OK"
}

# --- ports ---
free_port() {
  local port="$1"
  local pids
  pids=$(lsof -ti ":$port" 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    log "Killing existing listener on :$port (PIDs: $pids)"
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
    sleep 1
    if lsof -ti ":$port" >/dev/null 2>&1; then
      fail "Port :$port still in use after kill, investigate (PID=$(lsof -ti ":$port"))"
    fi
  fi
}

free_ports() {
  log "Freeing ports :5001 (backend) and :8081 (Metro)..."
  free_port 5001
  free_port 8081
  ok "Ports free"
}

main() {
  preflight
  free_ports
  ok "preflight + ports done — backend/mobile not yet implemented"
}

main "$@"
