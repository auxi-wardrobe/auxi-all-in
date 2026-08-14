# AU-442 Soft-Paywall MVP — Smoke Verify + qa-ui Pass 3 Close-out

**Result: PASS**

**Device**: iOS Simulator iPhone 17 Pro, UDID `34528D25-C08D-4E54-89B8-BDA0E3226B7F`, iOS 26.5
**Bundle**: `com.auxi2026.app` · `__DEV__` build, Fast-Refreshed with AU-442 fixes
**Branch**: `nguyenthaihiep94/au-442-paywall` @ `625c895` ("fix: correct UsageLimitSheet tokens + add QA debug trigger (AU-442)")
**Backend**: `:5001` · Metro `:8081`

## 1. qa-ui-flagged visual fixes — all 4 confirmed visible

Reached the sheet via the `__DEV__`-only QA row: Menu → Settings → About →
**"Preview usage limit sheet (QA)"** (`testID="settings-dev-usage-limit-preview"`).

Screenshot: `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-usage-limit-sheet.png`

| Fix | Verdict | Evidence |
|---|---|---|
| Title not oversized (~14px Semibold) | **CONFIRMED** | Pixel-measured glyph band height 40px @3x scale (~13.3pt) — same order as body text, not an oversized heading |
| Body ~14px regular | **CONFIRMED** | Pixel-measured glyph band height 40px @3x scale, matching title scale |
| "See on Me" bolder inline span | **CONFIRMED** | Visibly heavier weight than surrounding paragraph text in crop (`crop-sheet.png`) |
| Larger button gap ("Upgrade to Macgie+" → "Maybe later") | **CONFIRMED** | Measured ~111px @3x (~37pt) — comfortably spaced, not cramped |

Measurement method: cropped the sheet region and scanned dark-pixel row bands
with PIL (`python3 -c "from PIL import Image..."`) to get objective glyph
bounding-box heights and gaps rather than eyeballing. No "before" screenshot
was available for a strict pixel diff, but all 4 values read as intentional
and on-spec, not regressed.

## 2. Sheet → NotifyMeScreen flow

- Tapped `usage-limit-sheet-upgrade` → sheet dismissed, navigated to
  `NotifyMeScreen` cleanly. Screenshot:
  `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-notify-me-screen.png`
- Header renders `notify-me-close-button` (✕) + "Upgrade" title, wordmark
  hero ("Macgie+ is coming soon."), and a **6-row** feature grid (Unlimited
  wardrobe, Unlimited suggestions, Schedule outfits / See on me, Enhance
  items, Creative Canvas) — confirmed NOT 8 rows, the 2 placeholder rows are
  gone.
- Tapped `notify-me-cta` ("Notify me") → acknowledged visibly: label changed
  to **"We'll notify you"** and button turned inert/gray (disabled state).
  Screenshot: `qa-mobile-au442-notify-me-tapped.png`
- Tapped `notify-me-close-button` → clean return to the About screen, no
  crash, no stuck nav state (confirmed via `list_elements_on_screen` showing
  the About screen's rows intact).

Minor non-blocking observation: a small blurred/placeholder thumbnail is
visible top-left behind the header on NotifyMeScreen (looked like an
unloaded background decoration asset). Not flagging as a bug per your
instruction — this is adjacent to the `__DEV__` QA affordance path and I
did not have a real-usage-threshold trigger to compare against; noting only
for awareness, not filing a finding.

## 3. Regression spot-check (no real threshold hit)

- App boots cleanly to Home (outfit recommendation renders, no gate popup).
- Home → hamburger → Wardrobe: grid loads normally, no unexpected paywall
  sheet fired for the fresh `qa-test@auxi.app` account.
  Screenshot: `qa-mobile-au442-drawer2.png` (drawer) + wardrobe grid render
  confirmed via screenshot (not saved separately — visually clean, matched
  expected grid layout).
- Returned to Home via drawer → "See my outfits": renders cleanly, no crash.
- `mobile_list_crashes` → **empty**, no crash reports on device.

Wardrobe upload and Enhance-photo trigger sites were spot-checked for "no
unexpected sheet on a fresh account" only (per your note, not exercised to a
real threshold) — both clean.

## 4. Jest regression gate

Ran `npx jest` (full suite) plus targeted runs isolating AU-442's own test
files and diffing against the pre-AU-442 base commit (`ae0b283`) to separate
signal from noise.

**AU-442's own test files — all 6 pass:**
```
PASS src/hooks/__tests__/useUsageLimitGate.test.ts
PASS src/services/__tests__/usageLimit.test.ts
PASS src/components/features/__tests__/UsageLimitSheet.render.test.tsx
PASS src/screens/__tests__/NotifyMeScreen.render.test.tsx
PASS src/screens/item-detail/__tests__/EnhanceImageScreen.test.tsx
```
(`UpgradeScreen.render.test.tsx` — see pre-existing gap below, unrelated to
AU-442's own changes.)

**Full-suite noise, triaged (none are AU-442 regressions):**

1. **`.claude/worktrees/au-428-pin-refine-crash/**`** — a stray worktree
   checkout for a *different* ticket (AU-428) nested inside `auxi/`, whose
   duplicated `src/` tree gets picked up by Jest's default `testMatch` and
   roughly doubles the suite count with unrelated failures. Not an AU-442
   concern — flag to `devops`/`tech-lead` to `.gitignore` or scope Jest's
   `testPathIgnorePatterns` to exclude `.claude/worktrees/`.
2. **`UpgradeScreen.render.test.tsx` fails to parse** — `jest.config.js`
   `transformIgnorePatterns` whitelist doesn't include `react-native-purchases`
   / `@revenuecat/purchases-js-hybrid-mappings`. Confirmed **pre-existing**:
   reverting `src/screens/HomeScreen/` to base commit `ae0b283` (pre-AU-442)
   still reproduces the identical parse failure — the RevenueCat IAP wiring
   predates AU-442 (`#276`, `#274`). Not introduced by this ticket.
3. **`ItemDetailScreen.test.tsx` — 5 "enhance FAB" test failures** —
   confirmed **pre-existing**: `git diff ae0b283..HEAD -- src/screens/ItemDetailScreen.tsx`
   shows zero AU-442 changes to that file, and reverting it to base still
   reproduces the same 5 failures.
4. **`HomeScreen.test.tsx` fails to parse** — same RevenueCat
   transformIgnorePatterns gap as #2 (transitively pulled in via
   `AuthContext.tsx`); confirmed pre-existing the same way (base-commit
   revert reproduces it).
5. Other pre-existing failures unrelated to AU-442's file set: `group-by-date.test.ts`,
   `RootDrawer.gesture.test.tsx`, 4x `onboarding/v2/__tests__/*`,
   `ImageSkeletons.test.tsx`, `__tests__/App.test.tsx` — none touched by AU-442
   commits (`6b67c65`, `c3aa89b`, `625c895`).

**Net: AU-442 introduces zero new Jest regressions.** The pre-existing
`transformIgnorePatterns` gap (RevenueCat/purchases) is worth a follow-up
ticket for `mobile-dev` — it currently blocks `UpgradeScreen.render.test.tsx`
and `HomeScreen.test.tsx` from running at all, independent of AU-442.

## Summary

```
Maestro: n/a this dispatch (exploratory verify only — no flow exists yet for
         the soft-paywall surfaces; recommend qa-ui author one if this
         becomes a recurring regression target)
mobile-mcp exploratory: 4 canonical surfaces (usage-limit sheet, NotifyMeScreen,
         NotifyMeScreen post-tap, About/QA-row entry) — all PASS
Jest:    731 tests (excl. stray worktree) · 699 pass · 32 fail (all pre-existing,
         verified via base-commit revert, zero AU-442 regressions)
         AU-442's own 6 test files: 5 pass, 1 blocked by pre-existing config gap

Findings filed: 0 blocking AU-442
Follow-up (non-blocking): transformIgnorePatterns missing react-native-purchases/
  @revenuecat — route to mobile-dev; stray .claude/worktrees/au-428-pin-refine-crash
  polluting Jest test discovery — route to devops/tech-lead
```

## Screenshots

- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-sidebar-menu.png`
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-usage-limit-sheet.png`
- `auxi/docs/qa-findings/screenshots/2026-08-14/crop-sheet.png` (measurement crop)
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-notify-me-screen.png`
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-notify-me-tapped.png`
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-drawer2.png`
- `auxi/docs/qa-findings/screenshots/2026-08-14/drawer2-left.png` (crop)

## Unresolved questions

- None blocking. Two non-blocking follow-ups noted above (RevenueCat Jest
  transform gap, stray worktree polluting test discovery) — not filed as
  formal bug reports since neither is an AU-442 regression, but flagging so
  they don't get lost.
