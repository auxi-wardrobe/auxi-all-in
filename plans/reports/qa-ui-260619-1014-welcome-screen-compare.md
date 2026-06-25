# qa-ui Compare — Welcome screen (auth root) redesign

- **Date**: 2026-06-19
- **Mode**: Compare (post-code visual gate, workflow step 6 — Pass 2 + Pass 3)
- **Figma**: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-10085 · node `2849:10085` "Welcome Home"
- **Spec**: `plans/260618-2108-welcome-screen-redesign/figma-extraction-welcome.md`
- **Target**: `auxi/src/screens/auth/WelcomeScreen.tsx`, `auxi/src/components/macgie/MacgieLoader.tsx`

## Verdict: ESCALATE — artifact-under-test is missing

The redesigned implementation described in the dispatch **does not exist in
this checkout, on any branch, in any worktree, or as uncommitted work.** A
Compare audit cannot run because the code to compare has not landed. This is a
pre-flight stop, not a fidelity FAIL — screenshotting the warm sim would only
capture the OLD Welcome screen and produce false FAILs against a spec the
on-disk code was never meant to match.

## Pre-flight (both passed — blocker is the code, not the toolchain)

- `./scripts/mcp-doctor.sh` → exit 0. Sim iPhone 16 Pro booted, WDA up on :8100, mobile-mcp healthy.
- Figma MCP reachable — `get_metadata` on `2849:10085` returned the full "after" frame tree.

## Evidence the redesign is not present

| Expected (per dispatch + spec) | Actual on disk | Source of truth |
|---|---|---|
| `MacgieLoader` gains new `asLogo` prop | `MacgieLoaderProps` exposes only `variant` + `size`. No `asLogo`. | `MacgieLoader.tsx:38-46` |
| `WelcomeScreen` renders `<MacgieLoader variant="inline" size={126} asLogo />` hero | No `MacgieLoader` import or usage. Logo slot absent. | `WelcomeScreen.tsx` — `grep MacgieLoader` empty |
| Subtitle "Get dressed with more clarity, less pressure." | No subtitle node; only single `t('uac.welcome.headline')`. | `WelcomeScreen.tsx:270-272` |
| Hero group top / action stack bottom restructure | Headline is vertically centered (`headlineWrap: flex:1, justifyContent:'center'`). Old layout. | `WelcomeScreen.tsx:406-410` |
| "or" divider (line · or · line) | Single 1px `<View style={styles.divider}/>`, no "or". | `WelcomeScreen.tsx:343-344, 448-452` |
| i18n key `uac.welcome.subtitle` | Does not exist in `src/translations/`. | `grep` empty |

Repo state checks:
- `git diff --stat` on both target files → **empty** (no uncommitted edits).
- `git worktree list` → 16 worktrees scanned; `grep -rln "asLogo"` across the
  entire umbrella (excluding node_modules) → **zero hits**.
- Main auxi checkout is on branch `fix/ios-sim-debug-linker` @ `dc3324b0`
  (an iOS-sim linker fix, unrelated to the Welcome redesign). No
  welcome-redesign branch exists.

## Figma "after" target (confirmed via get_metadata — for reference when code lands)

The Figma frame `2849:10085` matches the spec's intended end-state:
- `Frame 2203` (hero, top, y≈171): `macgie-animate-2` 103×126 → "Welcome to Macgie" heading (360×88) → subtitle (360×32).
- `Frame 2108` (action stack, bottom, y≈546): two stacked Buttons (327×56, gap 12) → `Frame 2135` divider row with centered "or" text → email Button → legal Headline text.
- Language `Button` 106×44 top-right.

So the design is unambiguous and ready to audit — the moment the implementation
is actually wired and live on Metro, this gate can run Pass 2 + Pass 3 cleanly.

## Why no sim screenshot

Per qa-ui hard boundary: "a degraded audit pretending to be complete is worse
than no audit." Capturing the warm sim now would screenshot the legacy Welcome
screen and manufacture fidelity defects that belong to no real regression. Image
budget preserved for the real run.

## What's needed to unblock (route → mobile-dev)

1. Land the WelcomeScreen + MacgieLoader (`asLogo`) edits described in the spec
   onto a branch / worktree that this audit can see, and confirm them committed
   or at least present on disk.
2. Add the `uac.welcome.subtitle` i18n string (3-locale parity: en-US, vi-VN,
   fr-FR) — currently missing.
3. `terminate_app` + `launch_app` so Metro serves the fresh JS bundle, then
   re-dispatch this Compare gate.

The 3 pre-flagged known deviations (Nunito Sans→Poppins H1 font swap; outlined
radius 17→16 + hero gap 7→8 sub-1px snap; legal text non-tappable) were noted
and would NOT have failed the gate — they are deferred to designer/CEO. They are
moot until the code exists.

## Unresolved questions

1. Was the redesign committed to a branch not fetched into this umbrella's
   submodule, or is the dispatch's "my edits are live" premise stale? Need the
   branch name / worktree path where `asLogo` + the restructured screen live.
2. Was the warm sim app ever rebuilt against the redesigned bundle, or is it
   still serving `dc3324b0` (pre-redesign) JS?

**Status:** BLOCKED
**Summary:** Cannot run the Welcome Compare gate — the redesigned WelcomeScreen + MacgieLoader `asLogo` edits are absent from disk, all branches, and all worktrees (`git diff` empty, `grep asLogo` zero hits umbrella-wide), so there is nothing to compare against Figma `2849:10085`. Verdict **ESCALATE**: route to mobile-dev to land/point me at the actual implementation, then re-dispatch.
