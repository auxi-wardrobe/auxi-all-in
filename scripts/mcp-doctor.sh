#!/usr/bin/env bash
# scripts/mcp-doctor.sh — health-check for the mobile-mcp + WebDriverAgent stack.
# Auto-invokes wda-install.sh if WDA is down.
#
# Exit codes:
#   0 = healthy (sim booted + WDA up + mobile-mcp resolvable)
#   1 = no booted iPhone simulator
#   2 = WebDriverAgent not responding (and wda-install.sh failed to start it)
#   3 = mobile-mcp npm package not resolvable
set -uo pipefail   # not -e: we want to report per-step status, not abort first failure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WDA_PORT="${WDA_PORT:-8100}"
MOBILE_MCP_PKG="@mobilenext/mobile-mcp"

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
log()  { printf "%b\n" "${BLUE}▸${NC} $*"; }
ok()   { printf "%b\n" "${GREEN}✓${NC} $*"; }
warn() { printf "%b\n" "${YELLOW}!${NC} $*"; }
fail() { printf "%b\n" "${RED}✗${NC} $*" >&2; exit "${2:-1}"; }

log "MCP doctor: checking mobile-mcp + WebDriverAgent + simulator..."

# Check 1: iPhone simulator booted
if ! xcrun simctl list devices booted 2>/dev/null | grep -qE "iPhone"; then
  fail "No iPhone simulator booted. Run ./scripts/qa-boot.sh first." 1
fi
SIM=$(xcrun simctl list devices booted 2>/dev/null | grep -E "iPhone" | head -1 \
  | sed -E 's/^[[:space:]]+//' | sed -E 's/ \(.*//')
ok "Simulator booted: $SIM"

# Check 2: WebDriverAgent responding (auto-install if down)
if ! curl -sf "http://localhost:${WDA_PORT}/status" >/dev/null 2>&1; then
  warn "WebDriverAgent not responding on :$WDA_PORT — invoking wda-install.sh..."
  if ! "$SCRIPT_DIR/wda-install.sh"; then
    fail "WebDriverAgent failed to start. See logs/wda.log." 2
  fi
fi
ok "WebDriverAgent up on :$WDA_PORT"

# Check 3: mobile-mcp package resolvable via npm registry
# (We verify the package is fetchable; actual MCP server is invoked by the agent harness.)
if ! npm view "$MOBILE_MCP_PKG" version >/dev/null 2>&1; then
  fail "$MOBILE_MCP_PKG not resolvable via npm. Check network / registry / version pin in .mcp.json." 3
fi
PINNED_VERSION=$(grep -oE '"@mobilenext/mobile-mcp@[^"]+"' \
  "$(cd "$SCRIPT_DIR/.." && pwd)/.mcp.json" 2>/dev/null \
  | sed -E 's/.*@([^"]+)"/\1/' || true)
LATEST_VERSION=$(npm view "$MOBILE_MCP_PKG" version 2>/dev/null || echo "?")
if [[ -n "$PINNED_VERSION" ]] && [[ "$PINNED_VERSION" != "$LATEST_VERSION" ]]; then
  warn "Pinned: $PINNED_VERSION · Latest on npm: $LATEST_VERSION (intentional pin — bump in .mcp.json if needed)"
else
  ok "mobile-mcp resolvable (pinned=${PINNED_VERSION:-?}, latest=$LATEST_VERSION)"
fi

echo
ok "MCP stack healthy. Agents can use mobile-mcp tools."
