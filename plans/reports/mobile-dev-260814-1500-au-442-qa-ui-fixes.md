# mobile-dev report — AU-442 qa-ui Compare-mode fixes

Source findings: `auxi/docs/qa-findings/2026-08-14-figma-audit-au-442-paywall-mvp.md`
File: `auxi/src/components/features/UsageLimitSheet.tsx`

## Fixes applied

1. **HIGH — title token.** `styles.title` now uses
   `theme.typography.aliases.interSemiboldXsSm` (Inter-SemiBold 14/20) instead
   of `type.h3` (Semibold 20/26, from `m-tokens.ts`). Matched to the exact
   precedent already shipped in `ContextChipsModal.tsx:322` (title style for
   the same Figma "Text-sm(l-20)/Semibold" class).
2. **MEDIUM — body token.** `styles.body` now uses
   `theme.typography.aliases.interBodySm` (Inter-Regular 14/20) instead of
   `type.body` (Regular 16/24). Same precedent, `ContextChipsModal.tsx:326`.
3. **MEDIUM — inline bold emphasis.** Verified via Figma screenshots
   (`get_screenshot` on nodes `5078:13668` / `5078:13983` / `5078:14024`)
   that **only the `see_on_me` variant** actually has a bold inline run
   ("**See on Me**") — `wardrobe_items` and `enhance_photo` bodies are plain
   regular text throughout in Figma, no emphasis. No existing
   `Trans`/i18n-interpolation precedent exists anywhere in the codebase
   (grepped, none found), so added a minimal local `**bold**`-marker parser
   (`renderBodyWithEmphasis`) in `UsageLimitSheet.tsx` — splits on
   `**...**`, renders matched spans as a nested `<Text style={styles.bodyEmphasis}>`
   (same `interSemiboldXsSm` alias, Semibold at the same 14/20 size). Plain
   strings with no markers pass through unaffected (verified via the
   `wardrobe_items`/`enhance_photo` copy, which is untouched).
   Updated i18n: `usageLimit.see_on_me_body` in both
   `src/translations/en-EN.json` and `fr-FR.json` now wrap the feature-name
   phrase in `**...**` ("See on Me" / "« Voir sur moi »"). The other two
   `*_body` keys are unchanged (no markers, no bold — matches Figma).
4. **MEDIUM — button-group gap.** `styles.actions.gap` changed from
   `space.s2` (8px) to `space.s3` (12px), matching the Figma "button group"
   spec.

## Not touched (per explicit scope exclusion in the report)

- `MButton` `text`-variant font weight (secondary "Maybe later") — shared
  primitive, affects other screens, routed as DS-level.
- `role.primaryBtnLabel` vs `theme.ds.color.warm100` ~1% RGB drift — DS-level,
  pre-existing, out of scope.

## QA reachability aid (Pass 3 unblock)

Added a `__DEV__`-only "Preview usage limit sheet (QA)" row to
`auxi/src/screens/settings/SettingsAboutScreen.tsx`, following the exact
precedent already shipped for the Design System reference screen (the
"Version" row hidden-entry pattern, same file, `__DEV__`-gated, no i18n —
this screen already documents itself as QA/dev infra, not shipped copy).

**How it works:** the row mounts a local `useUsageLimitGate()` instance and
renders `<UsageLimitSheet {...gate.sheetProps} onUpgrade={...} />` as a
sibling of `SettingsScreenScaffold` (wrapped the return in a `<>` fragment).
`onUpgrade` mirrors the real production wiring
(`useAddWardrobeItem.ts` / `EnhanceImageScreen.tsx` / `SeeThisOnMeScreen.tsx`)
— it dismisses the preview sheet and calls
`navigation.navigate('NotifyMe', { feature, source: 'settings_dev_preview' })`.
So **one tap reaches both AU-442 surfaces**: the sheet, then (via its own
"Upgrade to Macgie+" CTA) `NotifyMeScreen`.

**Exact steps for qa-mobile / qa-ui, on a `__DEV__` build:**
1. Open the app → hamburger/sidebar → Settings.
2. Tap **About** (`settings-section-about` or equivalent row — existing nav,
   unchanged).
3. Scroll to the bottom. Below "Privacy Policy" there's a new row: **"Preview
   usage limit sheet (QA)"** — `testID="settings-dev-usage-limit-preview"`.
4. Tap it → `UsageLimitSheet` opens with `feature: 'see_on_me'` (the variant
   carrying the bold-span fix, and the primary regression target from finding
   #3). `testID="usage-limit-sheet"`, CTAs `usage-limit-sheet-upgrade` /
   `usage-limit-sheet-dismiss`.
5. Tap **"Upgrade to Macgie+"** (`usage-limit-sheet-upgrade`) → sheet
   dismisses, navigates to `NotifyMeScreen` (`notify-me-cta` /
   `notify-me-close-button` testIDs already shipped).

Note: the preview is wired to `feature: 'see_on_me'` only (not all 3
variants) — that's the variant carrying every fix in this pass (title/body
tokens + the bold span), so it's the one that matters for this verification
round. If qa-mobile also wants to eyeball `wardrobe_items` / `enhance_photo`
copy layout, that needs either a 2nd/3rd row or a quick edit to the row's
`onPress` — flagging as a possible follow-up, not adding proactively (YAGNI/
minimal-footprint per the task instruction).

## Verification

- `npx tsc --noEmit` — clean for all touched files. 3 pre-existing baseline
  errors remain in `src/screens/see-this-on-me/{components.tsx,StomStepLayout.tsx}`
  (`poppinsTimeLg`/`poppinsBodySm` missing aliases) — confirmed via `git
  stash` that these predate this change, unrelated to AU-442.
- `yarn lint` — 26 problems (2 errors / 24 warnings), identical count
  before/after (`git stash` diff-checked) — all in unrelated files
  (`web/mocks/handlers.ts`, `web/stubs/toast.tsx`, `web/device-frame/*`,
  etc.). Zero lint findings in either touched file.
- `./scripts/auxi-lint-tokens.sh` (umbrella root) — 13 violations, identical
  to the pre-existing set enumerated in the qa-ui report (`BodyPhotoGrid.tsx`,
  `BodyTryOnView.tsx`, `ItemPickerPanel.styles.ts`, `LanguageSettingsScreen.tsx`,
  `HomeScreen/styles.ts`, `ContextChipsModal.tsx`, `PinGenerationError.tsx`).
  Zero in `UsageLimitSheet.tsx` or `SettingsAboutScreen.tsx`.
- `npx jest src/components/features/__tests__/UsageLimitSheet.render.test.tsx`
  — 6/6 pass, no changes needed (the test's i18n mock echoes raw keys with no
  `**` markers, so `renderBodyWithEmphasis` no-ops and the existing
  `.toContain(...)` assertions still match).
- `npx jest src/services/__tests__/usageLimit.test.ts` — 10/10 pass
  (untouched, gate logic unaffected).
- `EnhanceImageScreen.test.tsx` has 2 pre-existing failures (mock-spy typing
  issue, `toast.show` not a jest mock) — confirmed via `git stash` to predate
  this change entirely, unrelated to AU-442/UsageLimitSheet.
- No `SettingsAboutScreen.tsx` test file exists — nothing to update there.

## Visual verification

Not run this pass — no simulator interaction was performed (I did not launch
`yarn ios:sim` or touch Metro/the sim, per the umbrella's concurrency rule
and since the task only asked for source fixes + a QA-reachability aid).
Fast Refresh should pick up these JS-only changes automatically in the
already-running session. Recommend qa-mobile/qa-ui use the exact dev-row
steps above for the live side-by-side pass (Pass 3) against the Figma
screenshots already pulled for this report (nodes `5078:13668` /
`5078:13983` / `5078:14024`).

## Unresolved questions

- None blocking. The two out-of-scope DS-level findings (`MButton` text
  weight, `primaryBtnLabel` hex drift) still need routing per the report's
  own recommendation (consult `figma-theme-sync` before touching
  `m-tokens.ts`/`MButton.tsx` — shared primitives, other screens depend on
  them).

**Status:** DONE
**Summary:** Fixed all 4 in-scope qa-ui findings in `UsageLimitSheet.tsx`
(title/body typography tokens, inline bold emphasis, button-group gap) and
added a `__DEV__`-only QA row in `SettingsAboutScreen.tsx` that reaches both
`UsageLimitSheet` and `NotifyMeScreen` in two taps. tsc/lint/token-lint clean
against baseline; existing `UsageLimitSheet` tests pass unmodified.
**Concerns/Blockers:** none.
