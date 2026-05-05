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
BACKEND_LOG="$LOG_DIR/backend.log"
METRO_LOG="$LOG_DIR/metro.log"

SIM_NAME=""
SIM_UDID=""
BUNDLE_ID=""

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

# --- backend ---
start_backend() {
  log "Starting backend..."
  cd "$REPO_ROOT/wardrobe-backend"

  local venv_dir=".venv"
  if [[ ! -d "$venv_dir" ]]; then
    log "Creating Python venv at $venv_dir (first run)..."
    python3 -m venv "$venv_dir" || fail "venv creation failed (need python3 with venv module)"
  fi

  # shellcheck source=/dev/null
  source "$venv_dir/bin/activate"

  log "Installing backend deps (pip install -q -r requirements.txt)..."
  if ! pip install -q -r requirements.txt; then
    warn "pip install failed. Re-running verbose for diagnostics:"
    pip install -r requirements.txt 2>&1 | tail -20 >&2
    fail "Backend dep install failed"
  fi

  log "Launching uvicorn (python app.py)..."
  nohup python app.py > "$BACKEND_LOG" 2>&1 &
  local pid=$!
  echo "backend=$pid" >> "$PIDS_FILE"
  log "Backend PID=$pid, polling http://localhost:5001/docs (30s timeout)..."

  local i
  for i in $(seq 1 30); do
    if curl -sf -o /dev/null "http://localhost:5001/docs"; then
      ok "Backend healthy after ${i}s"
      deactivate
      cd "$REPO_ROOT"
      return 0
    fi
    sleep 1
  done

  warn "Backend did not respond within 30s. Last 20 lines of $BACKEND_LOG:"
  tail -20 "$BACKEND_LOG" >&2
  kill "$pid" 2>/dev/null || true
  fail "Backend failed to start"
}

# --- iOS simulator ---
boot_simulator() {
  log "Checking iOS simulator state..."
  local booted
  booted=$(xcrun simctl list devices booted 2>/dev/null | grep -E "iPhone" || true)
  if [[ -n "$booted" ]]; then
    SIM_NAME=$(echo "$booted" | head -1 | sed -E 's/^[[:space:]]+//' | sed -E 's/ \(.*//')
    SIM_UDID=$(echo "$booted" | head -1 | grep -oE '[0-9A-Fa-f-]{36}')
    ok "Sim already booted: $SIM_NAME ($SIM_UDID)"
    return 0
  fi

  log "No sim booted — picking first available iPhone..."
  local pick
  pick=$(xcrun simctl list devices available 2>/dev/null | grep -E "iPhone" | head -1 || true)
  [[ -n "$pick" ]] || fail "No iPhone simulator available — install one in Xcode (Window → Devices and Simulators)"

  SIM_NAME=$(echo "$pick" | sed -E 's/^[[:space:]]+//' | sed -E 's/ \(.*//')
  SIM_UDID=$(echo "$pick" | grep -oE '[0-9A-Fa-f-]{36}')
  log "Booting $SIM_NAME ($SIM_UDID)..."
  xcrun simctl boot "$SIM_UDID" || fail "Failed to boot $SIM_NAME"
  open -a Simulator
  sleep 3
  ok "Sim booted: $SIM_NAME"
}

# --- mobile (Metro + yarn ios) ---
start_mobile() {
  cd "$REPO_ROOT/auxi"

  log "Starting Metro bundler..."
  nohup yarn start > "$METRO_LOG" 2>&1 &
  local pid=$!
  echo "metro=$pid" >> "$PIDS_FILE"
  log "Metro PID=$pid (giving it 5s to come up)..."
  sleep 5

  log "Building + installing app on $SIM_NAME (this takes ~1 minute)..."
  if ! yarn ios --udid "$SIM_UDID"; then
    warn "yarn ios failed. Last 40 lines of $METRO_LOG:"
    tail -40 "$METRO_LOG" >&2
    fail "Mobile build/install failed"
  fi

  local plist="$REPO_ROOT/auxi/ios/auxi/Info.plist"
  [[ -f "$plist" ]] || fail "Info.plist not found at $plist"
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist") \
    || fail "Could not read CFBundleIdentifier from $plist"

  # Info.plist may contain an unresolved Xcode build variable (e.g. $(PRODUCT_BUNDLE_IDENTIFIER)).
  # In that case, resolve the real bundle ID from the xcodeproj build settings.
  # xcode_var holds the literal two-char sequence dollar+paren used by Xcode build vars.
  local xcode_var
  # shellcheck disable=SC2016
  xcode_var='$('
  if [[ "$BUNDLE_ID" == *"${xcode_var}"* ]]; then
    local pbxproj="$REPO_ROOT/auxi/ios/auxi.xcodeproj/project.pbxproj"
    local resolved
    resolved=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" "$pbxproj" \
      | grep -v 'org\.cocoapods' \
      | sed -E 's/.*PRODUCT_BUNDLE_IDENTIFIER = "?([^";]+)"?;.*/\1/' \
      || true)
    # The pbxproj value may itself contain $(PRODUCT_NAME:rfc1034identifier);
    # resolve PRODUCT_NAME as well.
    if [[ "$resolved" == *"${xcode_var}"* ]]; then
      local product_name
      product_name=$(grep -m1 "PRODUCT_NAME = " "$pbxproj" \
        | sed -E 's/.*PRODUCT_NAME = ([^;]+);.*/\1/' | xargs || true)
      resolved="${resolved/\$(PRODUCT_NAME:rfc1034identifier)/$product_name}"
    fi
    [[ -n "$resolved" ]] || fail "Could not resolve PRODUCT_BUNDLE_IDENTIFIER from $pbxproj"
    BUNDLE_ID="$resolved"
  fi

  if ! xcrun simctl listapps booted | grep -q "$BUNDLE_ID"; then
    fail "Build succeeded but $BUNDLE_ID not on sim — check $METRO_LOG"
  fi
  ok "App $BUNDLE_ID installed on $SIM_NAME"
  cd "$REPO_ROOT"
}

main() {
  preflight
  free_ports
  start_backend
  boot_simulator
  start_mobile
  ok "All stages done — hand-off printout not yet implemented"
}

main "$@"
