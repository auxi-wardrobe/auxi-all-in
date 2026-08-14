# AU-442 soft-paywall MVP — designer-fix re-verify (retry)

**Build**: `936bb18` on branch `nguyenthaihiep94/au-442-paywall` (`auxi/`)
**Device**: iOS Simulator — iPhone 17 Pro, iOS 26.5, UDID `34528D25-C08D-4E54-89B8-BDA0E3226B7F`
**Method**: mobile-mcp exploratory verify (no Maestro flow exists yet for this screen)
**Stack**: backend `:5001` (pids 60730/60740), Metro `:8081` (pids 62726/84615) — both alive, no rebuild performed. `mcp-doctor.sh` preflight: healthy.

Note: this is a retry of an interrupted attempt. First `launch_app` call foregrounded a stale already-running app instance with leftover nav state from the prior session (landed directly on About screen, then a save_screenshot showed a mid-revert frame back to About). To get an unambiguous result I `terminate_app` + `launch_app`'d for a true cold start and redid the full repro from Home → drawer → Settings → About → QA preview row.

## Finding 1 — ghost/duplicate snapshot on sheet→NotifyMeScreen transition

**Result: FAIL — still reproduces.**

Repro: About → "Preview usage limit sheet (QA)" → UsageLimitSheet opens (clean, no artifacts) → tap "Upgrade to Macgie+" → transitions to NotifyMeScreen.

Immediately after the transition (and in every screenshot taken over the following ~1s, and still present after tapping the CTA to confirmed state), a small rounded-white card floats in the top-left, roughly behind/below the "Upgrade" header title, with a soft radial glow/shadow underneath it. A 3x crop confirms it is a **miniaturized duplicate snapshot of the NotifyMeScreen itself** — visible inside it: a tiny mock status bar, the "Upgrade" title text, the 4-row feature icon grid (matching "Unlimited wardrobe / See on me / Unlimited suggestions / Enhance items / Schedule outfits / Creative Canvas"), and a small dark bar mimicking the CTA button. It is not a single transient animation frame — it persisted across at least 4 separate screenshots taken several seconds apart, including after reaching the "We'll notify you" confirmed state.

Screenshots:
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-usage-limit-sheet.png` — sheet, pre-transition (clean baseline)
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-notifyme-transition-check.png` — immediately post-transition, ghost visible top-left
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-ghost-artifact-persist.png` — ~1s later, ghost still present (used for the 3x crop below)
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-notifyme-confirmed-state.png` — after tapping CTA, ghost still visible top-left alongside the now-green confirmed button

Suspected area: the sheet-close→navigate sequencing fix in `936bb18` ("fix: sequence sheet-close before navigate + add MButton confirmed state") — the MButton confirmed-state half of that commit verified clean (see Finding 2), but the ghost/duplicate-snapshot symptom the sequencing change was meant to resolve is unchanged from the original designer-gate finding. Worth checking whatever renders the outgoing sheet/modal snapshot during the transition (likely a screenshot-based transition or a leftover Modal/Portal layer not unmounting) in the paywall screens under `auxi/src/screens/` (UsageLimitSheet / NotifyMeScreen) — exact file:line not confirmed, no source read performed (read-only QA scope).

**Routing**: mobile-dev (UI/state) — the fix did not resolve the reported ghost/duplicate-snapshot symptom; needs another pass.

## Finding 2 — confirmed-state visual (green + checkmark) on "Notify me" CTA

**Result: PASS.**

On NotifyMeScreen, tapped "Notify me" (`notify-me-cta`). Result:
- (a) Button fill is visibly **green**, not gray. Confirmed.
- (b) A **checkmark icon** is visible to the left of the label. Confirmed.
- (c) Label changed to **"We'll notify you"**. Confirmed.
- (d) Tapped again at the same coordinates — no visual change, testID remained `notify-me-cta-confirmed` (was `notify-me-cta` pre-tap) — **still inert** to repeat taps. Confirmed.

Screenshot: `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-notifyme-confirmed-state.png`

## Regression check

Closed NotifyMeScreen via ✕ (`notify-me-close-button`) → landed cleanly back on About screen, no ghost artifact, no crash. Navigated: About → back → Settings → drawer → Home. Home rendered normally (outfit card, "Wear this" CTA, etc.), no stuck nav state.

`mobile_list_crashes` → `[]` (no crash reports).

## Summary

| Finding | Status |
|---|---|
| 1. Ghost/duplicate snapshot on sheet→NotifyMeScreen transition | **FAIL** — still reproduces, described above with crop evidence |
| 2. Confirmed-state visual (green + checkmark) on Notify me CTA | **PASS** |
| Regression (close, navigate, no crash) | **PASS** — no crashes, no stuck nav |

**Status: DONE_WITH_CONCERNS** — Finding 2 fix verified clean; Finding 1 fix did not resolve the reported symptom and needs to go back to mobile-dev.

## Unresolved questions
- Whether the ghost snapshot is a fixed-size scaled-down re-render of the same screen (suggesting a leftover transition/portal layer) vs. an actual cached bitmap of a previous screen state — could not determine without reading source (out of QA's read-only scope on `auxi/src`).
- Whether the ghost appears on every run or is timing-dependent — only one full repro cycle was executed in this retry (image budget: this exploratory run used all 4 canonical screenshots plus 2 supporting crops/closeups against the 4-surface cap).
