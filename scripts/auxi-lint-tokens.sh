#!/usr/bin/env bash
# scripts/auxi-lint-tokens.sh — flag hex literals + font family strings outside theme.ts.
#
# Why: token drift (Poppins → Archivo/Inter, hex literals in screens) is the
# #1 recurring finding in qa-ui audits. Catches drift mechanically before PR.
#
# Scope:
#   - Scans auxi/src/screens/** and auxi/src/components/features|layout/**
#     (excludes primitives/ + atoms/ — those CAN hold tokens by design)
#   - Whitelist: theme.ts is the ONLY file allowed to declare hex / fontFamily literals
#   - Allowed in JSX: 'transparent', 'currentColor', rgba()/hsl() forms (intentional
#     designer escape hatches — not subject to token system)
#
# Exit codes:
#   0 = clean
#   1 = violations found (printed with file:line)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUXI_SRC="$REPO_ROOT/auxi/src"

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; NC=$'\033[0m'
ok()   { printf "%b\n" "${GREEN}✓${NC} $*"; }
warn() { printf "%b\n" "${YELLOW}!${NC} $*"; }
fail_line() { printf "%b\n" "${RED}✗${NC} $*"; }

[[ -d "$AUXI_SRC" ]] || { warn "auxi/src/ not present — skipping (submodule init?)"; exit 0; }

# Scan scope: screens + features + layout. Exclude primitives/atoms (those CAN hold tokens).
SCAN_PATHS=(
  "$AUXI_SRC/screens"
  "$AUXI_SRC/components/features"
  "$AUXI_SRC/components/layout"
)

# Pattern 1: hex literal in JSX/TSX (#RGB / #RGBA / #RRGGBB / #RRGGBBAA)
HEX_PATTERN="'#[0-9a-fA-F]{3,8}'"

# Pattern 2: font family string literal (Poppins, Inter, Archivo, Manrope, etc.)
FONT_PATTERN="fontFamily:\s*['\"][A-Za-z][^'\"]+['\"]"

VIOLATIONS=0

echo "▸ Scanning ${SCAN_PATHS[*]}..."
echo

for path in "${SCAN_PATHS[@]}"; do
  [[ -d "$path" ]] || continue

  # Hex literal violations
  while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    fail_line "HEX     $file:$line   $(echo "$content" | sed -E 's/^[[:space:]]+//' | cut -c1-100)"
    VIOLATIONS=$((VIOLATIONS+1))
  done < <(grep -rEn "$HEX_PATTERN" "$path" --include="*.tsx" --include="*.ts" 2>/dev/null || true)

  # Font family violations
  while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    fail_line "FONT    $file:$line   $(echo "$content" | sed -E 's/^[[:space:]]+//' | cut -c1-100)"
    VIOLATIONS=$((VIOLATIONS+1))
  done < <(grep -rEn "$FONT_PATTERN" "$path" --include="*.tsx" --include="*.ts" 2>/dev/null || true)
done

echo
if [[ "$VIOLATIONS" -eq 0 ]]; then
  ok "Token lint clean — no hex literals or font-family strings outside theme.ts"
  exit 0
else
  echo
  warn "$VIOLATIONS violation(s) found."
  warn "Fix: move the value into auxi/src/theme/theme.ts and import from there."
  warn "Whitelist for designer intent: use rgba()/hsl() forms, 'transparent', 'currentColor'."
  exit 1
fi
