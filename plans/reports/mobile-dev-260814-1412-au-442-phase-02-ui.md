# mobile-dev — AU-442 phase 02 — UsageLimitSheet / useUsageLimitGate / NotifyMeScreen

**Status:** DONE
**Scope:** `auxi/` only. Code complete; simulator/visual verification pending (no mobile-mcp/sim tools in this session — hands off to qa-ui/designer/qa-mobile per the canonical workflow's step 6.5/7).

## What shipped

New files:
- `auxi/src/hooks/useUsageLimitGate.ts` — `{ open(feature), dismiss, sheetProps }`, mirrors `useAiLimitGate`. Declares `UsageLimitFeature = 'see_on_me' | 'wardrobe_items' | 'enhance_photo'` once, imported everywhere else.
- `auxi/src/components/features/UsageLimitSheet.tsx` — `MBottomSheet`-based, 3 feature-parameterised copy variants, two CTAs (`MButton variant="primary"` upgrade / `MButton variant="text"` maybe-later). Mascot = existing `MacgieFace` (locked decision #1).
- `auxi/src/screens/NotifyMeScreen.tsx` — header (✕ close, "Upgrade" title) + MacgieFace/`MacgiePlusWordmark` hero + "is coming soon." + 6-row feature grid (reuses `upgrade.feature_*` i18n keys and icons verbatim — locked decisions #2/#3) + single "Notify me" CTA with local confirmed-state (label swap + `disabled`, no toast/network — locked decision #4).
- Tests: `auxi/src/hooks/__tests__/useUsageLimitGate.test.ts` (5), `auxi/src/components/features/__tests__/UsageLimitSheet.render.test.tsx` (7), `auxi/src/screens/__tests__/NotifyMeScreen.render.test.tsx` (3). All pass (14/14).

Modified:
- `auxi/src/types/navigation.ts` — `NotifyMe: { feature: UsageLimitFeature; source?: string }` added to `AppStackParamList`; imports `UsageLimitFeature` from the gate hook.
- `auxi/src/navigation/AppNavigator.tsx` — `<Stack.Screen name="NotifyMe" component={NotifyMeScreen} />` registered next to `Upgrade`. **Both nav files confirmed updated.**
- `auxi/src/translations/en-EN.json` / `fr-FR.json` — new `usageLimit.*` (8 keys) and `notifyMe.*` (5 keys) namespaces added to both. `vi-VN.json` intentionally left untouched per task scope (task named only en-EN + fr-FR); flagging since the repo's existing convention keeps all 3 locales in parity — worth a follow-up if vi-VN is actively served.

## Build-time judgment calls (flagged, not silently invented)

1. **3-photo collage hero — not built.** The extraction note claims NotifyMeScreen reuses "UpgradeScreen's 3-photo collage hero," but `UpgradeScreen.tsx` has no such component — its hero is `MacgieFace` + `MacgiePlusWordmark` + text. Since no reusable collage component/assets exist and inventing new photo assets is out of scope for this MVP pass, I substituted the actual reusable hero pattern (`MacgieFace` + gradient wordmark) instead. Visual delta from Figma; call out at the qa-ui Compare / designer gate.
2. **Sheet body copy has no inline-bold span.** Figma highlights the feature name mid-sentence in bold; shipped as a single plain-text i18n string per feature (YAGNI — avoids 3-part key-splitting for an MVP cosmetic nuance). Flag for designer gate if it matters.
3. **Secondary CTA uses `MButton variant="text"`**, whose label color token (`role.secondaryBtnLabel` #1C1A19) is a near-but-not-exact match for Figma's `text/neutral/base` #1d1f23 (`role.ink`). No existing MButton variant is an exact pixel match for a borderless pill secondary CTA; reused the closest on-system variant per extraction's open question #7 recommendation rather than inventing a new one.
4. **Icon chip radius**: reused `theme.ds.radius.sm` (12) exactly as `UpgradeScreen`'s existing `featureIcon` style does, per extraction's open question #6 recommendation (Figma wants 8, no exact token exists).
5. **"Version 1.0.3" footer omitted** (extraction open question #5 — Figma canvas artifact, not app content), per task instruction.

None of these are silent — all were called out in the extraction artifact's "Open questions" section (items 5–7 explicitly deferred to build time) or are new judgment calls documented here for the qa-ui/designer gates.

## Verification

- `npx tsc --noEmit` — clean for all new/modified files. 4 pre-existing errors remain, all in files I did not touch (`src/screens/see-this-on-me/components.tsx`, `StomStepLayout.tsx`, `src/services/featureFlags.tsx`) — count unchanged, none introduced by this change. (Note: these differ from the `_HomeScreen.tsx` baseline described in `auxi/CLAUDE.md`; the doc's baseline description appears stale, but the total error count — 4 — matches what was there before my edit, confirmed via `git status` showing none of those files as modified.)
- `yarn lint` — clean for all new/modified files (grepped output for `UsageLimit`/`NotifyMe`/`useUsageLimitGate` — zero hits). 2 pre-existing errors + 24 warnings remain in untouched `web/mocks/handlers.ts`, `web/stubs/toast.tsx`, and various other pre-existing files — none from this change.
- `./scripts/auxi-lint-tokens.sh` — 13 pre-existing violations remain, all in files untouched by this change (`BodyPhotoGrid.tsx`, `BodyTryOnView.tsx`, `ItemPickerPanel.styles.ts`, `LanguageSettingsScreen.tsx`, `HomeScreen/styles.ts`, `ContextChipsModal.tsx`, `PinGenerationError.tsx`). Zero hex/font violations in `UsageLimitSheet.tsx` or `NotifyMeScreen.tsx`.
- `npx jest` on the 3 new test files — **14/14 pass**: sheet renders per feature key (3x, parametrized), `onUpgrade` fires exactly once, `onDismiss` fires, gate `open()` idempotent while visible, gate starts hidden, `dismiss()`/`onDismiss` hide, NotifyMe mounts all 6 rows (and confirms the 2 dropped rows are absent), close button navigates back, "Notify me" tap flips to confirmed state + goes `disabled` + a second tap is a no-op.
- `npx jest src/navigation src/translations` — no regressions (8/8 pass).
- Both locale JSON files verified as valid JSON (`node -e "JSON.parse(...)"`).
- Simulator/visual side-by-side: **not performed** — no mobile-mcp/sim tooling available in this session. Marking "code complete, visual verification pending" per the workflow skill's explicit fallback. Hands off to qa-ui Compare mode (Pass 2+3) next.

## testID inventory (for qa-ui/Maestro)

- `usage-limit-sheet`, `usage-limit-sheet-upgrade`, `usage-limit-sheet-dismiss`, `usage-limit-sheet-backdrop` (from `MBottomSheet`)
- `notify-me-close-button`, `notify-me-feature-{wardrobe,see_on_me,suggestions,enhance,schedule,canvas}`, `notify-me-cta` / `notify-me-cta-confirmed` (stateful, always-defined per convention)

## Open questions for CEO/designer (unresolved, non-blocking for this phase)

- Is the missing 3-photo collage hero acceptable for MVP, or should it be built in a follow-up pass with real assets?
- Is the plain-text sheet body (no inline-bold feature-name emphasis) acceptable, or worth a 3-part i18n key split?
- Should `vi-VN.json` get the same `usageLimit.*`/`notifyMe.*` keys for locale parity with the rest of the app?

**Status:** DONE
**Summary:** Built `UsageLimitSheet`, `useUsageLimitGate`, `NotifyMeScreen` per the AU-442 extraction's locked decisions; registered `NotifyMe` in both nav files; added bilingual i18n; tsc/lint/token-lint clean (no new violations); 14 new jest tests pass. Visual sim verification pending (no mobile-mcp in this session).
**Concerns/Blockers:** 3 build-time deviations flagged above (missing collage hero asset, no inline-bold body span, near-match secondary CTA color token) — none blocking, all are designer-gate material.
