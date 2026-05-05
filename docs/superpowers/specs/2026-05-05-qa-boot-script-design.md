# Wardrobe QA Boot Script — Design

**Date**: 2026-05-05
**Owner**: duncan
**Status**: Approved, ready for implementation plan

## Goal

One command from the umbrella repo root that:

1. Starts the FastAPI backend (`wardrobe-backend`, port 5001).
2. Starts Metro + builds + launches the RN app (`auxi`) on the iOS simulator.
3. Verifies both are healthy.
4. Prints the QA regression checklist (from `auxi-qa-test.md`) and exits, leaving both apps running in the background.

The script exists so the QA workflow starts from a known-good state instead of re-discovering setup steps each session. Logs are persisted as evidence — the QA skill requires it ("evidence — not fabricated 'passed' results").

## Files

```
wardrobe_project/
├── scripts/
│   ├── qa-boot.sh        # main one-shot
│   └── qa-stop.sh        # kills the backgrounded processes
└── logs/                 # gitignored
    ├── backend.log
    ├── metro.log
    └── pids.txt          # "backend=<pid>\nmetro=<pid>\n"
```

`logs/` is added to the umbrella `.gitignore`. The two scripts are committed to the umbrella repo (not to either submodule) — they coordinate across both, so they belong at the umbrella level.

## `qa-boot.sh` — flow

Each step exits non-zero with a diagnostic on failure. No silent fallbacks. If a step fails, no later step runs (in particular, Metro is never started if backend health fails).

### 1. Preflight
- Assert `pwd` contains `auxi/` and `wardrobe-backend/` directories.
- Assert `xcrun simctl` is on PATH (macOS + Xcode required).
- Assert `python3`, `yarn`, `lsof` on PATH.
- `mkdir -p logs/`.

### 2. Free ports
- `lsof -ti :5001 | xargs kill -9 2>/dev/null` (backend).
- `lsof -ti :8081 | xargs kill -9 2>/dev/null` (Metro).
- No-op if nothing listening; do not fail on either.

### 3. Backend bring-up
- `cd wardrobe-backend`.
- If `.venv/` missing: `python3 -m venv .venv` (the leading dot matches the existing convention in `wardrobe-backend/`).
- `source .venv/bin/activate`.
- `pip install -q -r requirements.txt` — idempotent. On failure: print last 20 lines of pip output, exit 1.
- Start backend in background:
  ```bash
  nohup python app.py > ../logs/backend.log 2>&1 &
  echo "backend=$!" > ../logs/pids.txt
  ```
  (Uses `python app.py` because `app.py` already calls `uvicorn.run(...)` at the bottom — keeps the script source-of-truth.)
- Health check: poll `http://localhost:5001/docs` (FastAPI's auto-generated Swagger, always available) every 1s up to 30s. On timeout: print last 20 lines of `backend.log`, kill the backend PID, exit 1.

### 4. Mobile bring-up
- Check booted simulator: `xcrun simctl list devices booted | grep -E "iPhone"`.
- If none booted: pick first available iPhone from `xcrun simctl list devices available`, boot it (`xcrun simctl boot <udid>`), `open -a Simulator`.
- Capture `SIM_UDID` and `SIM_NAME` for later printout.
- `cd auxi`.
- Start Metro in background:
  ```bash
  nohup yarn start > ../logs/metro.log 2>&1 &
  echo "metro=$!" >> ../logs/pids.txt
  ```
- Wait 5s for Metro to come up (lightweight — Metro doesn't have a single health endpoint, and `yarn ios` will block until it can talk to it anyway).
- Run `yarn ios` foreground (this builds + installs + launches; we want to see build output live so failures are visible).
- After `yarn ios` returns: read bundle id with `/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" auxi/ios/auxi/Info.plist`, then verify it appears in `xcrun simctl listapps booted`. If the Info.plist path differs (Xcode rename), fail with the path it tried.

### 5. QA hand-off (printout)

```
✅ Wardrobe stack up

Backend  : http://localhost:5001  (PID <n>, log: logs/backend.log)
Metro    : :8081                  (PID <n>, log: logs/metro.log)
iOS sim  : <SIM_NAME> (<SIM_UDID>)
App      : <bundle-id> installed and launched

──────────────────────────────────────
QA regression checklist (auxi-qa-test.md)
──────────────────────────────────────
1. Auth        — register → login → kill app → reopen → still logged in
2. Onboarding  — Welcome → LocationPermission → preference → first home recommendation
                  ⚠ confirm with mobile-dev which entry path is active (legacy vs new)
3. Home        — recommendation loads, occasion/weather/time chips refetch, favorite + try-on hit backend
4. Wardrobe    — 4-col grid, category filters, photo upload, item edit
5. Body photos — upload, list, delete
6. Settings    — daily reminders toggle, style direction edit, preference reset

Bug reports → auxi/docs/qa-findings/YYYY-MM-DD-<slug>.md (severity, repro rate, build SHA, sim spec)

To stop: ./scripts/qa-stop.sh
```

The script then exits 0. Both apps stay running.

## `qa-stop.sh` — flow

- Read `logs/pids.txt`.
- For each `name=pid` line: `kill <pid> 2>/dev/null` (gentle), wait 2s, then `kill -9 <pid> 2>/dev/null` if still alive.
- Also `lsof -ti :5001 :8081 | xargs kill -9 2>/dev/null` as a safety net (in case the user started extras manually).
- Do NOT shut down the iOS simulator — preserves state between runs (per design decision).
- Print: `🛑 backend stopped, metro stopped. iOS sim left running.`

## Failure modes — what each looks like

| Failure | Detection | Output | Exit |
|---|---|---|---|
| Wrong cwd | `auxi/` or `wardrobe-backend/` missing | "Run from umbrella repo root" | 1 |
| No Xcode | `xcrun simctl` not found | "Xcode + simulator required" | 1 |
| Port stuck | re-running `lsof -ti :PORT` 1s after kill still returns a PID | "Port :PORT still in use after kill, investigate (PID=...)" | 1 |
| venv create fails | `python3 -m venv` non-zero | last 10 lines of stderr | 1 |
| pip install fails | non-zero exit | last 20 lines of pip output | 1 |
| Backend timeout | `/docs` not 200 in 30s | last 20 lines of `backend.log` | 1 |
| No iPhone available | `simctl list` returns nothing | "No iPhone simulator available — install one in Xcode" | 1 |
| `yarn ios` fails | non-zero exit | exit code propagated, metro.log path printed | 1 |
| App not installed | `simctl listapps` doesn't list bundle id | "Build succeeded but app not on sim — check metro.log" | 1 |

## Not in scope

- **No `.env` bootstrap** — assumes `wardrobe-backend/.env` is already configured (Gemini key, S3, etc.). Separate concern.
- **No Jest auto-run** — per user decision A, hand-off is the printed checklist only.
- **No sim device picker** — uses first available iPhone. To override, edit `SIM_PREFERENCE` var at top of `qa-boot.sh`.
- **No sim shutdown on stop** — preserves state.
- **No Android** — iOS-only per project conventions.
- **No CI usage** — script is interactive, assumes a developer terminal with macOS + Simulator.app.

## Open questions

None — all resolved during brainstorming:
- Hand-off behavior: print checklist, leave running (A)
- Process management: background + log files + separate stop script (A)
- Backend env: auto-create venv + pip install (B)
- Port conflict: kill existing listeners (Y)

## Acceptance criteria

A QA session is "smooth" when:

1. From a fresh terminal at umbrella root, `./scripts/qa-boot.sh` ends with the green checklist and both apps demonstrably running (backend `/docs` reachable, app visible on sim).
2. Re-running `./scripts/qa-boot.sh` immediately works (idempotent — kills old, restarts).
3. `./scripts/qa-stop.sh` returns the system to a state where ports 5001 and 8081 are free.
4. Any failure during boot prints actionable diagnostics — never leaves the user staring at a silent shell.
5. `logs/backend.log` and `logs/metro.log` contain enough output to attach to a bug report per `auxi-qa-test.md`'s evidence rule.
