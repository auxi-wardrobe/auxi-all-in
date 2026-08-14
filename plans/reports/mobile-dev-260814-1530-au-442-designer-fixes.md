# mobile-dev — AU-442 designer-gate MAJOR fixes (Finding 1 + Finding 2)

Source: `auxi/docs/design-reviews/2026-08-14-au-442-paywall.md`
Build base: `625c895` (branch `nguyenthaihiep94/au-442-paywall`)

## Finding 1 — ghost transition artifact on entry to NotifyMeScreen (FIXED)

### Root cause

`UsageLimitSheet` sits on `MBottomSheet`, which uses `useOverlayProgress`
(`auxi/src/components/design-system/lib/useOverlayProgress.ts`). `onDismiss`
only flips `visible=false`; the sheet itself stays **mounted** for the
duration of its close animation (`motion.duration.fast` = 120ms, exit-eased
`Animated.timing`) before `setMounted(false)` unmounts its content.

All 4 call sites fired `navigation.navigate('NotifyMe', …)` **synchronously
in the same tick** as `dismiss()`. That pushes the new screen while the old
screen (still holding the sheet, mid-close-animation) is the one
`react-native-screens` snapshots for the native-stack push transition. The
snapshot/freeze captured a partial mid-animation frame of the sheet's
floating card (rounded corners + drop shadow, not yet slid/faded fully out,
not yet at its resting off-screen transform), which is what rendered as the
"miniature card, top-left, behind the header" ghost the designer
reproduced — it wasn't a leftover on the new screen, it was a stale
transition snapshot of the *old* screen's still-animating sheet, bleeding
through the push transition.

No existing precedent in the codebase does a "close a sheet/modal, then
immediately push" sequence safely (`useAiLimitGate` never navigates itself —
it delegates the dismiss side-effect to the caller, and no caller pushes on
dismiss). `BodyScreen.tsx`/`ImportFromWebScreen.tsx` use `setTimeout` after
closing a modal before the next side-effect (opening the camera / posting an
import), which is the same shape of fix, just for a different consumer.

### Fix

Added `dismissThenNavigate(after: () => void)` to `useUsageLimitGate`
(`auxi/src/hooks/useUsageLimitGate.ts`) — hides the sheet, then invokes
`after` via `setTimeout(after, motion.duration.fast)`, i.e. only once the
sheet's own close-animation window (same token `MBottomSheet` closes on)
has elapsed and the sheet has unmounted. Centralized in the gate hook
(single source of truth per its own DRY header comment) instead of
duplicating the timing logic across 4 call sites.

Updated all 4 call sites to use it instead of `dismiss()` +
synchronous `navigate()`:
- `auxi/src/screens/settings/SettingsAboutScreen.tsx:102-110`
- `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx:710-717`
- `auxi/src/screens/item-detail/EnhanceImageScreen.tsx:392-399`
- `auxi/src/screens/wardrobe/useAddWardrobeItem.ts:259-266`

### Verification

- `npx tsc --noEmit` — clean on touched files (3 pre-existing baseline
  errors remain in unrelated `see-this-on-me/components.tsx` +
  `StomStepLayout.tsx`, confirmed present before my changes via `git
  stash`).
- `yarn lint` — zero errors/warnings in any touched file (repo-wide 2
  errors / 24 warnings are all pre-existing in `web/` files, unrelated).
- `yarn jest` — `useUsageLimitGate.test.ts`, `UsageLimitSheet.render.test.tsx`,
  `NotifyMeScreen.render.test.tsx`, `EnhanceImageScreen.test.tsx`,
  `WardrobeScreen.test.tsx`, `StomStepScreen.limit.test.tsx`,
  `SeeThisOnMeConfirmScreen.test.tsx` — all pass, no updates needed (no
  existing test asserted the removed synchronous `dismiss()`+`navigate()`
  sequencing at any of the 4 call sites, so nothing broke; no new dedicated
  trigger-site tests existed to extend and adding them wasn't in scope of
  this fix pass).
- `./scripts/auxi-lint-tokens.sh` (umbrella root) — 13 pre-existing
  violations, none in touched files (confirmed same list as the designer's
  report noted as pre-existing/unrelated).

### Visual verification — PARTIAL, see caveat

Confirmed sim is booted and live (`iPhone 17 Pro`,
`34528D25-C08D-4E54-89B8-BDA0E3226B7F`), Metro running on `:8081`, and
captured a baseline screenshot showing the current app state (HomeScreen)
via `xcrun simctl io booted screenshot` — Fast Refresh should have already
applied the JS-only change.

**I could not execute the interactive tap-through repro myself** (Settings →
About → QA row → Upgrade). Per `auxi/CLAUDE.md`'s mobile-mcp tool-grant
table, `mobile-dev` deliberately does not carry mobile-mcp/interactive-sim
tools (that's `qa-mobile`'s / `qa-ui`'s tier) — I only have `Bash` +
file/Figma tools this session. `xcrun simctl` has no tap/touch primitive,
`idb`/`idb_companion` aren't installed, and AppleScript (`osascript`) GUI
automation is blocked (`osascript is not allowed assistive access`, -1719 —
no accessibility permission granted to this process, and I can't grant it
myself non-interactively).

**Recommend dispatching `qa-mobile`** to run the exact repro (Settings →
About → "Preview usage limit sheet (QA)" → "Upgrade to Macgie+") and confirm
the ghost snapshot is gone, and to sanity-check the ~120ms navigation delay
doesn't read as a perceptible lag (it shouldn't — it's below the
~100-130ms "instant" perception threshold and matches the sheet's own
existing close-animation duration, so the screen change lands right as the
sheet visually finishes closing, not before).

---

## Finding 2 — "We'll notify you" confirmed state reads as disabled, not success (FIXED)

### Fix

Added a `confirmed?: boolean` prop to `MButton`
(`auxi/src/components/design-system/lib/MButton.tsx`) — additive, backward
compatible (undefined by default, no behavior change for existing callers).
When `confirmed` is true:
- Fill swaps to `theme.ds.color.green` (`#039855` — the DS's canonical
  **radio/confirm** accent per `color-rules.md` §1-2; explicitly NOT
  `teal`, which is reserved for switches, and NOT a new/hardcoded hex).
  Reused via a direct `theme.ts` import into `MButton.tsx` — the same
  cross-token-system precedent `MBottomSheet.tsx` (same directory) already
  uses for `theme.zIndex.modal`.
- Leading icon becomes `Icons.CheckCircle` (existing `icon_check_circle.svg`
  asset, already used for success/confirmation elsewhere — e.g.
  `ItemReadySnackbar.tsx`, `WardrobeGridTile.tsx` selection state — not a
  new asset).
- The generic `disabled && styles.disabled` (`opacity: 0.5`) wash is
  **skipped** when `confirmed` is true (`disabled && !confirmed &&
  styles.disabled`) — the green fill + checkmark IS the state signal now;
  opacity would mute it back toward the same washed-out look the finding
  flagged.

`disabled` is still passed and still gates `PressScale`'s press-handling
(`disabled={disabled || loading}`) — the locked mechanism (label swap +
inert button, no toast, no new component) is untouched; only the *visual*
language of the inert state changed, per the finding's own framing.

`auxi/src/screens/NotifyMeScreen.tsx:126-131` now passes both
`disabled={notified}` and `confirmed={notified}`.

### Verification

- `npx tsc --noEmit` / `yarn lint` — clean (see Finding 1 section, same
  runs covered both).
- `yarn jest src/screens/__tests__/NotifyMeScreen.render.test.tsx` — passes
  unchanged; the existing assertions (`disabled` prop stays `true` on the
  confirmed testID, second tap stays a no-op, testID flips
  `notify-me-cta` → `notify-me-cta-confirmed`) all hold since the
  interaction contract didn't change, only the rendered fill/icon.
- `./scripts/auxi-lint-tokens.sh` — `MButton.tsx` lives under
  `components/design-system/lib/`, outside the scanned scope by design (same
  as `m-tokens.ts`'s own raw hex/font declarations) — not applicable here
  regardless, since the green value is a `theme.ds.color.green` token
  reference, not a hex literal.

### Visual verification — same caveat as Finding 1

Could not screenshot the actual tapped-confirmed state myself (requires
reaching `NotifyMeScreen` via the same tap sequence as Finding 1's repro —
same tooling gap). Recommend `qa-mobile` capture
`notify-me-cta-confirmed` post-tap alongside the Finding 1 repro run, and
`designer` re-run the lens-5/8 check that originally flagged this to confirm
the green + checkmark reads as "success," not "broken."

---

## Files changed

- `auxi/src/hooks/useUsageLimitGate.ts` — `dismissThenNavigate` helper
- `auxi/src/screens/settings/SettingsAboutScreen.tsx` — call site 1
- `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx` — call site 2
- `auxi/src/screens/item-detail/EnhanceImageScreen.tsx` — call site 3
- `auxi/src/screens/wardrobe/useAddWardrobeItem.ts` — call site 4
- `auxi/src/components/design-system/lib/MButton.tsx` — `confirmed` prop
- `auxi/src/screens/NotifyMeScreen.tsx` — passes `confirmed={notified}`

## Not touched (per explicit instruction)

- `notifyMe.title` = "Upgrade" header copy (Finding 3, ESCALATE) — left as-is
  per user confirmation; CEO taste-call, not a code defect.

## Unresolved / open questions

1. **Finding 1 & 2 visual re-verification is still pending** — I don't hold
   interactive sim tools this session (by design, per the mobile-dev role's
   tool-grant tier). Both fixes are code-complete and pass every
   non-interactive gate (tsc, lint, tests, token-lint), but the designer
   gate's own re-run scope ("Finding 1 all 4 call sites, Finding 2
   confirmed-state styling — lenses 2, 5, 7") needs a session with
   mobile-mcp (`qa-mobile` or `designer`) to close out visually before this
   can be called fully verified end-to-end.
2. The 120ms `dismissThenNavigate` delay is a deliberate, minimal choice
   (matches the sheet's own close-animation token exactly, so it's not an
   arbitrary number) — flagging in case product/design wants a different
   feel (e.g. navigate the instant the sheet visually clears vs. exactly
   when animation math says `mounted=false`); no evidence either way without
   a live device pass.

**Status:** DONE_WITH_CONCERNS
**Summary:** Both MAJOR findings fixed at the code level (root-caused +
patched) and pass tsc/lint/tests/token-lint; visual re-verification on the
live sim is blocked by this session's tool grants (no mobile-mcp) and needs
`qa-mobile`/`designer` to close out.
**Concerns/Blockers:** Cannot self-verify the fixes visually on simulator —
recommend immediate `qa-mobile` dispatch to re-run the designer's exact
repro before this is marked PASS end-to-end.
