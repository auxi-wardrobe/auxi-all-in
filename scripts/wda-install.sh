#!/usr/bin/env bash
# scripts/wda-install.sh — clone WebDriverAgent into tools/wda/ and run xcodebuild test
# in background. Idempotent: skips clone if present; skips xcodebuild if WDA is already
# responding on :8100.
#
# Exit codes:
#   0 = WDA running and responsive
#   1 = no booted iPhone simulator (run qa-boot.sh first)
#   2 = xcodebuild started but WDA did not respond within timeout
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WDA_PARENT="$REPO_ROOT/tools/wda"
WDA_DIR="$WDA_PARENT/WebDriverAgent"
LOG_DIR="$REPO_ROOT/logs"
WDA_LOG="$LOG_DIR/wda.log"
WDA_PORT="${WDA_PORT:-8100}"
WDA_TIMEOUT_SEC="${WDA_TIMEOUT_SEC:-180}"  # first cold build needs ~2-3 min for codesign + xctest

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
log()  { printf "%b\n" "${BLUE}▸${NC} $*"; }
ok()   { printf "%b\n" "${GREEN}✓${NC} $*"; }
warn() { printf "%b\n" "${YELLOW}!${NC} $*"; }
fail() { printf "%b\n" "${RED}✗${NC} $*" >&2; exit "${2:-1}"; }

mkdir -p "$LOG_DIR" "$WDA_PARENT"

# Health check: WDA returns 200 from /status when up
wda_up() {
  curl -sf "http://localhost:${WDA_PORT}/status" >/dev/null 2>&1
}

if wda_up; then
  ok "WebDriverAgent already running on :$WDA_PORT"
  exit 0
fi

# Identify booted simulator (xcodebuild needs an explicit destination name)
SIM_NAME=$(xcrun simctl list devices booted 2>/dev/null \
  | grep -E "iPhone" | head -1 \
  | sed -E 's/^[[:space:]]+//' | sed -E 's/ \(.*//') || true
if [[ -z "$SIM_NAME" ]]; then
  fail "No iPhone simulator booted. Run ./scripts/qa-boot.sh first." 1
fi
log "Target simulator: $SIM_NAME"

# Clone WebDriverAgent if not present (shallow clone — we don't need history)
if [[ ! -d "$WDA_DIR" ]]; then
  log "Cloning WebDriverAgent into $WDA_DIR (first run)..."
  git clone --depth 1 https://github.com/appium/WebDriverAgent.git "$WDA_DIR" \
    || fail "git clone failed — check network or proxy settings" 2
  ok "Cloned"
fi

cd "$WDA_DIR"
log "Launching WebDriverAgentRunner via xcodebuild test (background; log: $WDA_LOG)..."
nohup xcodebuild \
  -project WebDriverAgent.xcodeproj \
  -scheme WebDriverAgentRunner \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  test > "$WDA_LOG" 2>&1 &

# Poll for WDA readiness
log "Polling :$WDA_PORT (timeout ${WDA_TIMEOUT_SEC}s)..."
for i in $(seq 1 "$WDA_TIMEOUT_SEC"); do
  if wda_up; then
    ok "WebDriverAgent ready on :$WDA_PORT after ${i}s"
    exit 0
  fi
  sleep 1
done

warn "WebDriverAgent did not respond within ${WDA_TIMEOUT_SEC}s. Tail of $WDA_LOG:"
tail -30 "$WDA_LOG" >&2 || true
fail "WebDriverAgent startup failed — check Xcode signing, sim runtime, $WDA_LOG" 2
