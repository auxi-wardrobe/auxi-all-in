# Wardrobe QA Boot Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `scripts/qa-boot.sh` and `scripts/qa-stop.sh` so a single command from the umbrella repo root brings up the FastAPI backend, the RN mobile app on the iOS simulator, verifies both healthy, prints the QA regression checklist, and exits with both apps still running in the background.

**Architecture:** Two bash scripts at the umbrella level. `qa-boot.sh` runs synchronously through preflight → free-ports → backend (venv + pip + uvicorn + healthcheck) → iOS sim + Metro + `yarn ios` + bundle-id verify → printout. Long-running processes are backgrounded with `nohup ... &`, output redirected to `logs/*.log`, PIDs persisted to `logs/pids.txt`. `qa-stop.sh` reads that file and kills them. Failures abort with a tail of the relevant log; no silent fallbacks.

**Tech Stack:** bash, `lsof`, `xcrun simctl`, `nohup`, `curl`, `/usr/libexec/PlistBuddy`. Lint with `shellcheck`.

**Spec:** `docs/superpowers/specs/2026-05-05-qa-boot-script-design.md`

---

## File Structure

```
wardrobe_project/
├── scripts/
│   ├── qa-boot.sh          # CREATE — main one-shot, ~150 lines
│   └── qa-stop.sh          # CREATE — kills backgrounded procs, ~30 lines
├── logs/
│   └── .gitkeep            # CREATE — to commit empty dir
└── .gitignore              # MODIFY — add logs/ rules
```

Responsibilities:
- `qa-boot.sh` — orchestration, idempotent, fail-fast
- `qa-stop.sh` — teardown, tolerant of missing pids file (reads pids if present, safety-nets ports either way)
- `logs/` — runtime artefacts (logs + pids), gitignored except the keep file

---

## Task 1: Scaffold directories, gitignore, empty executables

**Files:**
- Create: `scripts/qa-boot.sh`
- Create: `scripts/qa-stop.sh`
- Create: `logs/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Verify shellcheck is available (used as our lint test)**

Run: `shellcheck --version`
Expected: prints version. If missing: `brew install shellcheck` first.

- [ ] **Step 2: Create directories and empty executable scripts**

```bash
cd /Users/nguyenminhduc/Desktop/wardrobe_project
mkdir -p scripts logs
touch logs/.gitkeep
cat > scripts/qa-boot.sh <<'EOF'
#!/usr/bin/env bash
# Placeholder — implemented in Task 3+
set -euo pipefail
echo "qa-boot.sh: not implemented yet"
exit 1
EOF
cat > scripts/qa-stop.sh <<'EOF'
#!/usr/bin/env bash
# Placeholder — implemented in Task 2
set -uo pipefail
echo "qa-stop.sh: not implemented yet"
exit 1
EOF
chmod +x scripts/qa-boot.sh scripts/qa-stop.sh
```

- [ ] **Step 3: Update .gitignore so logs/ artefacts are ignored except .gitkeep**

Append to `.gitignore` (the existing file already has `*.log`, but we want to be explicit about everything inside `logs/`):

```
# QA boot script artefacts
logs/*
!logs/.gitkeep
```

- [ ] **Step 4: Run shellcheck on both scripts (test gate)**

Run: `shellcheck scripts/qa-boot.sh scripts/qa-stop.sh`
Expected: no output, exit 0. (Placeholders are valid bash.)

- [ ] **Step 5: Verify executables run and fail with the placeholder message**

Run: `./scripts/qa-boot.sh`
Expected: prints `qa-boot.sh: not implemented yet`, exits 1.

Run: `./scripts/qa-stop.sh`
Expected: prints `qa-stop.sh: not implemented yet`, exits 1.

- [ ] **Step 6: Commit**

```bash
git add scripts/qa-boot.sh scripts/qa-stop.sh logs/.gitkeep .gitignore
git commit -m "chore(qa-boot): scaffold scripts/ and logs/ with gitignore"
```

---

## Task 2: Implement qa-stop.sh

This is the simpler of the two scripts and pins the `pids.txt` file format that `qa-boot.sh` will write later.

**Files:**
- Modify: `scripts/qa-stop.sh`

- [ ] **Step 1: Write the script**

Replace `scripts/qa-stop.sh` contents with:

```bash
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
```

- [ ] **Step 2: Lint with shellcheck**

Run: `shellcheck scripts/qa-stop.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Smoke test — run with no pids file**

Run: `rm -f logs/pids.txt && ./scripts/qa-stop.sh`
Expected: yellow warning about missing pids file, then green stop message. Exit 0.

- [ ] **Step 4: Smoke test — run with a fake pids file pointing at a sleeping process**

```bash
sleep 60 &
echo "fake=$!" > logs/pids.txt
./scripts/qa-stop.sh
```
Expected: prints "Stopping fake (PID <n>)...", then green stop message. `ps -p <n>` should show the process is gone.

- [ ] **Step 5: Commit**

```bash
git add scripts/qa-stop.sh
git commit -m "feat(qa-boot): implement qa-stop.sh with pid-file teardown + port safety net"
```

---

## Task 3: qa-boot.sh — preflight + free ports

Build `qa-boot.sh` incrementally. This task adds the harness, log helpers, preflight, and port-freeing — runnable end-to-end after this task (it will exit cleanly after freeing ports).

**Files:**
- Modify: `scripts/qa-boot.sh`

- [ ] **Step 1: Write the harness, log helpers, preflight, and port-freeing**

Replace `scripts/qa-boot.sh` contents with:

```bash
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
```

- [ ] **Step 2: Lint with shellcheck**

Run: `shellcheck scripts/qa-boot.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Smoke — run from umbrella root**

Run: `cd /Users/nguyenminhduc/Desktop/wardrobe_project && ./scripts/qa-boot.sh`
Expected: blue ▸ preflight, green ✓ Preflight OK, blue ▸ free ports, green ✓ Ports free, green ✓ "preflight + ports done...". Exit 0.

- [ ] **Step 4: Smoke — run from wrong directory (should fail loud)**

Run: `cd /tmp && /Users/nguyenminhduc/Desktop/wardrobe_project/scripts/qa-boot.sh`
Expected: red ✗ "Not at umbrella repo root: auxi/ missing" (because the script `cd`s to `REPO_ROOT` which is the umbrella, this should still pass — verify it does. If you want to actually test the failure path, temporarily rename `auxi/` and re-run, then rename back).

Better test: bypass the auto-cd by sourcing manually:

```bash
cd /tmp
mkdir -p fake_root && cd fake_root
bash -c 'cd "$(pwd)" && [[ -d auxi ]] || echo "would fail: auxi missing"'
```
Expected: prints "would fail: auxi missing". This confirms the assertion logic without messing with the real repo.

- [ ] **Step 5: Smoke — port-free idempotency**

```bash
# Start a process listening on :5001
python3 -m http.server 5001 &
HTTP_PID=$!
sleep 1
# Now run boot — should kill it
./scripts/qa-boot.sh
# Verify the http.server is gone
ps -p $HTTP_PID && echo "STILL RUNNING — BUG" || echo "killed as expected"
```
Expected: `./scripts/qa-boot.sh` succeeds, final line confirms "killed as expected".

- [ ] **Step 6: Commit**

```bash
git add scripts/qa-boot.sh
git commit -m "feat(qa-boot): preflight + free-ports stage in qa-boot.sh"
```

---

## Task 4: qa-boot.sh — backend bring-up

Add the backend section. End-state of this task: script brings up backend, healthchecks, exits.

**Files:**
- Modify: `scripts/qa-boot.sh`

- [ ] **Step 1: Add `start_backend` function and call from main**

Insert this function in `scripts/qa-boot.sh` between the `free_ports` function and the `main` function. It reuses an existing `.venv/` if present (the repo already ships one), otherwise creates `.venv/`. The leading-dot name is the existing convention in this repo:

```bash
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
```

Then update `main` to call it:

```bash
main() {
  preflight
  free_ports
  start_backend
  ok "preflight + ports + backend done — mobile not yet implemented"
}
```

(Replace the previous `main` body — the old `ok "preflight + ports done..."` line goes away.)

- [ ] **Step 2: Lint**

Run: `shellcheck scripts/qa-boot.sh`
Expected: no output, exit 0. (The `# shellcheck source=/dev/null` directive suppresses the "can't follow non-constant source" warning for the venv activate.)

- [ ] **Step 3: Smoke test — successful backend boot**

Run: `./scripts/qa-boot.sh`
Expected output sequence:
- Preflight OK
- Ports free
- Starting backend...
- (first run only) Creating Python venv... — takes ~10s
- Installing backend deps — takes 30-90s on first run, near-instant on repeat
- Launching uvicorn...
- Backend healthy after Ns
- "preflight + ports + backend done — mobile not yet implemented"

Exit 0. After exit:
```bash
curl -s http://localhost:5001/docs | head -3
```
Expected: HTML response (FastAPI Swagger page).

- [ ] **Step 4: Verify backend is still running and stoppable**

```bash
cat logs/pids.txt
# Should show: backend=<some-pid>
./scripts/qa-stop.sh
# Should kill the backend
curl -s http://localhost:5001/docs && echo "STILL UP — BUG" || echo "killed as expected"
```
Expected: `qa-stop.sh` runs cleanly, curl fails (no listener), final line says "killed as expected".

- [ ] **Step 5: Smoke test — backend startup failure**

Simulate a failure by introducing a syntax error briefly:

```bash
cd wardrobe-backend
mv app.py app.py.bak
echo "raise RuntimeError('boom')" > app.py
cd ..
./scripts/qa-boot.sh
```
Expected: red ✗ "Backend failed to start", with the last 20 lines of `backend.log` printed (showing the RuntimeError). Exit 1.

Restore:
```bash
mv wardrobe-backend/app.py.bak wardrobe-backend/app.py
```

- [ ] **Step 6: Commit**

```bash
git add scripts/qa-boot.sh
git commit -m "feat(qa-boot): backend bring-up with venv, pip, uvicorn, /docs healthcheck"
```

---

## Task 5: qa-boot.sh — iOS simulator + Metro + mobile build

Add simulator boot, Metro start, `yarn ios`, bundle-id verification.

**Files:**
- Modify: `scripts/qa-boot.sh`

- [ ] **Step 1: Add `boot_simulator` and `start_mobile` functions, declare globals**

Near the top of `scripts/qa-boot.sh` (after the LOG_DIR/PIDS_FILE block), add globals for simulator + bundle-id (so other functions can read them):

```bash
SIM_NAME=""
SIM_UDID=""
BUNDLE_ID=""
```

Then insert these functions between `start_backend` and `main`:

```bash
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

  if ! xcrun simctl listapps booted | grep -q "$BUNDLE_ID"; then
    fail "Build succeeded but $BUNDLE_ID not on sim — check $METRO_LOG"
  fi
  ok "App $BUNDLE_ID installed on $SIM_NAME"
  cd "$REPO_ROOT"
}
```

Update `main`:

```bash
main() {
  preflight
  free_ports
  start_backend
  boot_simulator
  start_mobile
  ok "All stages done — hand-off printout not yet implemented"
}
```

- [ ] **Step 2: Lint**

Run: `shellcheck scripts/qa-boot.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Smoke test — full happy path**

Run: `./scripts/qa-boot.sh`

Expected output sequence:
- Preflight OK
- Ports free
- Backend healthy after Ns
- Sim booted (or already booted)
- Metro PID=N
- Building + installing app...
- Xcode build output (live in terminal)
- ✓ App com.something.auxi installed on iPhone XX
- "All stages done — hand-off printout not yet implemented"

Then verify visually:
- iOS simulator window is open
- App icon present on the home screen
- App may have auto-launched

```bash
cat logs/pids.txt
# Should show: backend=<n>\nmetro=<n>
xcrun simctl listapps booted | grep -i auxi
# Should print the bundle id
```

- [ ] **Step 4: Cleanup before next task**

```bash
./scripts/qa-stop.sh
```
Expected: backend + metro stopped, sim left running.

- [ ] **Step 5: Commit**

```bash
git add scripts/qa-boot.sh
git commit -m "feat(qa-boot): iOS sim boot, Metro start, yarn ios build, bundle-id verify"
```

---

## Task 6: qa-boot.sh — QA hand-off printout

Final stage — replace the placeholder `ok "..."` with the formatted handoff block.

**Files:**
- Modify: `scripts/qa-boot.sh`

- [ ] **Step 1: Add `print_handoff` function**

Insert this function between `start_mobile` and `main`:

```bash
# --- QA hand-off ---
print_handoff() {
  local backend_pid metro_pid
  backend_pid=$(grep '^backend=' "$PIDS_FILE" | cut -d= -f2)
  metro_pid=$(grep '^metro=' "$PIDS_FILE" | cut -d= -f2)

  cat <<EOF

${GREEN}✅ Wardrobe stack up${NC}

Backend  : http://localhost:5001  (PID $backend_pid, log: logs/backend.log)
Metro    : :8081                  (PID $metro_pid, log: logs/metro.log)
iOS sim  : $SIM_NAME ($SIM_UDID)
App      : $BUNDLE_ID installed and launched

QA test account (already registered against local backend):
  email    : qa-test@auxi.app
  password : QaTest!2026

──────────────────────────────────────
QA regression checklist (auxi-qa-test.md)
──────────────────────────────────────
1. Auth        — login with the QA test account above → kill app → reopen →
                 still logged in. (Use a different fake email for the *register*
                 flow; this account already exists.)
2. Onboarding  — Welcome → LocationPermission → preference → first home recommendation
                  ⚠ confirm with mobile-dev which entry path is active (legacy vs new)
3. Home        — recommendation loads, occasion/weather/time chips refetch,
                 favorite + try-on hit backend
4. Wardrobe    — 4-col grid, category filters, photo upload, item edit
5. Body photos — upload, list, delete
6. Settings    — daily reminders toggle, style direction edit, preference reset

Bug reports → auxi/docs/qa-findings/YYYY-MM-DD-<slug>.md
              (severity, repro rate, build SHA, sim spec)

To stop: ./scripts/qa-stop.sh

EOF
}
```

Update `main` to call it (replacing the placeholder `ok "..."`):

```bash
main() {
  preflight
  free_ports
  start_backend
  boot_simulator
  start_mobile
  print_handoff
}
```

- [ ] **Step 2: Lint**

Run: `shellcheck scripts/qa-boot.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Smoke test — full run, confirm printout matches the spec**

Run: `./scripts/qa-boot.sh`
Expected: full boot sequence, then the green "✅ Wardrobe stack up" block with all six numbered regression flows. Exit 0.

Confirm the printout has:
- A real PID for backend (not blank)
- A real PID for metro (not blank)
- A real iPhone name and UDID
- A real bundle id (not blank)
- All six numbered checklist items
- The "To stop:" hint

- [ ] **Step 4: Cleanup**

```bash
./scripts/qa-stop.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/qa-boot.sh
git commit -m "feat(qa-boot): QA hand-off printout with checklist + PIDs"
```

---

## Task 7: End-to-end verification + idempotency + docs

Final task — exercise the whole spec's acceptance criteria, fix anything weird, document the entry point in the umbrella README.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Acceptance test 1 — fresh boot from clean state**

```bash
./scripts/qa-stop.sh   # ensure clean
# (Optional) force venv recreation to test the cold path. ONLY do this if you have time —
# pip install can take 30-90s. Skip if .venv/ already exists and is healthy.
# rm -rf wardrobe-backend/.venv
./scripts/qa-boot.sh
```
Expected: full happy path, ending with the green ✅ block. Both apps reachable.

- [ ] **Step 2: Acceptance test 2 — idempotent re-run**

While the stack is up from Step 1:
```bash
./scripts/qa-boot.sh
```
Expected: blue "Killing existing listener on :5001" and ":8081", then full boot succeeds again. Exit 0.

- [ ] **Step 3: Acceptance test 3 — stop returns ports to free state**

```bash
./scripts/qa-stop.sh
lsof -ti :5001 :8081
```
Expected: `qa-stop.sh` prints green stop message; `lsof` returns nothing (ports free). Exit code of `lsof` will be 1 because no PIDs match — that confirms ports are clear.

- [ ] **Step 4: Acceptance test 4 — verify logs are usable for bug reports**

```bash
./scripts/qa-boot.sh
wc -l logs/backend.log logs/metro.log
head -5 logs/backend.log
head -5 logs/metro.log
```
Expected: both logs have content (>0 lines), backend log shows uvicorn startup, metro log shows Metro startup banner. These are the artefacts the QA skill expects to attach to bug reports.

- [ ] **Step 5: Document the entry point in the umbrella README**

Open `README.md`. Find the existing Quick Start section (or equivalent) and add the subsection below just after it (or before the "Updating submodules" section if that exists). The block between the `<<<` and `>>>` markers below is the literal markdown to paste — copy everything between the markers (without the markers themselves):

```
<<<
## QA boot (one-shot)

For QA sessions that need both backend and mobile up at once:

    ./scripts/qa-boot.sh    # brings up backend, Metro, iOS sim, prints checklist
    ./scripts/qa-stop.sh    # tears it down (sim stays open)

Logs land in `logs/backend.log` and `logs/metro.log` — attach them to any
bug report per `auxi-qa-test.md`. PIDs are tracked in `logs/pids.txt`.

First run takes ~2 minutes (creates the backend `venv/` and runs `pip
install`). Subsequent runs are ~30-60s.

The script is idempotent — re-running kills any existing listeners on
:5001 and :8081 before starting fresh.
>>>
```

Note: the indented (4-space) lines in the snippet above will render as a code block in markdown, matching the rest of the README's style. If the README uses fenced code blocks (triple-backtick) elsewhere, convert those two indented lines to a fenced bash block to match — purely a stylistic match.

- [ ] **Step 6: Final lint pass on both scripts**

Run: `shellcheck scripts/qa-boot.sh scripts/qa-stop.sh`
Expected: no output, exit 0.

- [ ] **Step 7: Tear down**

```bash
./scripts/qa-stop.sh
```

- [ ] **Step 8: Commit docs and verify clean tree**

```bash
git add README.md
git commit -m "docs(qa-boot): document scripts/qa-boot.sh in umbrella README"
git status
```
Expected: working tree clean (except possibly the untracked `.dev-team/` and submodule diffs that pre-existed — those are not part of this work).

---

## Acceptance criteria (from the spec)

Cross-check after Task 7:

1. ✅ From a fresh terminal at umbrella root, `./scripts/qa-boot.sh` ends with the green checklist and both apps demonstrably running.
2. ✅ Re-running `./scripts/qa-boot.sh` immediately works (Task 7 Step 2).
3. ✅ `./scripts/qa-stop.sh` returns ports 5001 and 8081 to free state (Task 7 Step 3).
4. ✅ Failures during boot print actionable diagnostics (covered by Task 4 Step 5 — backend failure path; same pattern in `start_mobile`).
5. ✅ `logs/backend.log` and `logs/metro.log` contain enough output to attach to a bug report (Task 7 Step 4).
