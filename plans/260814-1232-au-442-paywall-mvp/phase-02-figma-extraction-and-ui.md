# Phase 02 — Figma extraction + UI (sheet + Notify-me page)

**Owner:** mobile-dev (Figma MCP) · **Priority:** P1 · **Status:** pending · **Effort:** 5h
**Scope:** `auxi/` only. File-disjoint from phase 01 → runs in parallel.

## Context links

- Figma: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Macgie?node-id=4444-26066&m=dev
- Canonical workflow: umbrella `CLAUDE.md` → "Figma → mobile UI workflow"
- Skills (both, in order): `figma-design-extraction` → `figma-to-rn-workflow`
- Design system: `auxi/docs/design-system/{design-system,motion-rules,color-rules,header-footer-rules}.md`

## Key insights (verified 2026-08-14)

- **A reusable gate pattern already exists — copy it, don't invent.**
  `auxi/src/hooks/useAiLimitGate.ts:40-64` returns `{ check, open, sheetProps }`;
  `auxi/src/components/features/AiLimitSheet.tsx` is a presentational `MBottomSheet` with
  i18n-keyed title/body/CTA and a `testID` prop. The new sheet is the same shape with two CTAs.
- `MBottomSheet` is the on-system primitive (`auxi/src/components/design-system/lib/index.ts:75`) —
  scrim, motion, swipe-to-dismiss and tokens come free. Do not hand-roll a Modal.
- **A real RevenueCat paywall already exists and is deliberately dark:**
  `auxi/src/screens/UpgradeScreen.tsx:165` (route registered `auxi/src/navigation/AppNavigator.tsx:222`),
  gated off by `const SHOW_UPGRADE_PAYWALL = false` (`auxi/src/screens/SettingsScreen.tsx:69`, used
  at `:162`). **This phase must not touch, unhide, or navigate into it.** "Upgrade" in the new sheet
  goes to the new Notify-me screen.
- "Coming soon" copy for subscriptions already exists at
  `auxi/src/translations/en-EN.json:1019-1020` — reuse the tone, add new keys under a new namespace.
- `isFreeUser` selector lives at `auxi/src/services/subscription.ts:12-17` — reuse; do not re-derive.

## Requirements

**Functional**
1. `UsageLimitSheet` — bottom sheet, feature-parameterised copy, two CTAs: primary "Upgrade",
   secondary dismiss.
2. `NotifyMeScreen` — full screen pushed by the "Upgrade" CTA, with a "Notify me" CTA and a
   post-tap confirmed state (the button must visibly acknowledge; the tap is the whole deliverable).
3. `useUsageLimitGate` hook — owns visibility + which feature triggered, mirroring `useAiLimitGate`.
4. Both surfaces localised (en-EN + fr-FR), no inline strings.

**Non-functional**
5. Zero raw hex / raw `zIndex` / hardcoded motion literals — `./scripts/auxi-lint-tokens.sh` clean.
6. `testID` on every interactive element (`auxi/CLAUDE.md` convention), plus distinct
   `accessibilityLabel`s.
7. New screen registered in BOTH `auxi/src/types/navigation.ts` `AppStackParamList` AND
   `auxi/src/navigation/AppNavigator.tsx` — skipping either is silent cold-start breakage.

## Architecture

```
useUsageLimitGate(feature)                 hooks/useUsageLimitGate.ts
   ├─ open(feature) / dismiss()
   └─ sheetProps ──► <UsageLimitSheet />   components/features/UsageLimitSheet.tsx
                          │ onUpgrade
                          ▼
                     navigation.navigate('NotifyMe', { feature })
                          ▼
                     <NotifyMeScreen />     screens/NotifyMeScreen.tsx
                          └─ "Notify me" → local confirmed state (no network call)
```

**Data in:** `feature: 'see_on_me' | 'wardrobe_items' | 'enhance_photo'` (string union shared with
phase 03 and with the backend's feature keys — declare it once, in the gate hook's module, and
import it everywhere).
**Data out:** analytics events only (phase 03). No API writes, no persisted state.

## Related code files

**Create**
- `auxi/src/components/features/UsageLimitSheet.tsx`
- `auxi/src/hooks/useUsageLimitGate.ts`
- `auxi/src/screens/NotifyMeScreen.tsx`
- `plans/260814-1232-au-442-paywall-mvp/figma-extraction-paywall-sheet.md` (extraction artifact)

**Modify**
- `auxi/src/types/navigation.ts` — add `NotifyMe: { feature: UsageLimitFeature; source?: string }`
- `auxi/src/navigation/AppNavigator.tsx` — register the screen
- `auxi/src/translations/en-EN.json`, `auxi/src/translations/fr-FR.json` — `usageLimit.*` namespace

**Read for context (do not edit)**
- `auxi/src/components/features/AiLimitSheet.tsx`, `auxi/src/hooks/useAiLimitGate.ts`
- `auxi/src/screens/UpgradeScreen.tsx` (visual language reference only)

## Implementation steps

1. **Extraction first.** Invoke `figma-design-extraction` on node-id `4444-26066`; capture the
   sheet AND the follow-up Notify-me frame (find its sibling node — the ticket implies a second
   frame; if absent, ESCALATE to CEO rather than inventing it). Save the artifact to the plan folder.
2. **Auto-dispatch `qa-ui` in review-extraction mode. No code until PASS** (workflow step 3).
3. Invoke `figma-to-rn-workflow`; Phase 0 verifies the artifact + qa-ui status.
4. Build `UsageLimitSheet` on `MBottomSheet`, props mirroring `AiLimitSheetProps`
   (`visible`, `onDismiss`, `onUpgrade`, `feature`, `testID`).
5. Build `useUsageLimitGate` — same `{ open, dismiss, sheetProps }` contract as `useAiLimitGate`.
6. Build `NotifyMeScreen`; register the route in both files; wire back-navigation.
7. Add i18n keys to both locale files (fr-FR must not be left English).
8. `npx tsc --noEmit` + `yarn lint` (baseline: 4 errors / 3 warnings in `_HomeScreen.tsx` — do not
   add more) + `./scripts/auxi-lint-tokens.sh`.

## Test matrix

| Level | Case | Expect |
|---|---|---|
| unit (jest) | sheet renders with each of the 3 feature keys | correct i18n copy per feature |
| unit | `onUpgrade` fires once per tap | no double-navigate |
| unit | gate `open()` while already visible | idempotent (mirrors `useAiLimitGate` semantics) |
| unit | NotifyMe "Notify me" tap | switches to confirmed state, button inert afterwards |
| static | `npx tsc --noEmit` | clean |
| static | `auxi-lint-tokens.sh` | clean |
| gate | qa-ui review-extraction (pre-code), qa-ui Compare (post-code) | PASS — phase 04 |

## Todo

- [ ] Figma extraction artifact saved
- [ ] qa-ui review-extraction PASS (blocks coding)
- [ ] `UsageLimitSheet`
- [ ] `useUsageLimitGate`
- [ ] `NotifyMeScreen` + navigation registration (BOTH files)
- [ ] i18n en-EN + fr-FR
- [ ] tsc / lint / token-lint clean
- [ ] jest unit tests

## Success criteria

- Sheet and Notify-me page render on the iOS sim matching the Figma frame.
- Route reachable via a debug navigate; no cold-start crash.
- Token lint clean; qa-ui review-extraction PASS recorded.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| Figma node has only the sheet, no Notify-me frame | M×M | ESCALATE to CEO before inventing UI; do not guess |
| Dev accidentally reuses `UpgradeScreen` for "Upgrade" | M×H | explicit non-goal here + phase-03 acceptance check; kill-switch stays false |
| Screen registered in only one of the two nav files | M×H | listed as a single todo item covering both; jest smoke on navigator |
| New sheet diverges visually from `AiLimitSheet` | M×L | designer gate (phase 04) |

## Security

None — no network, no user input, no PII. The Notify-me tap stores nothing.

## Backwards compatibility

Additive route + additive component. No existing screen changes behaviour in this phase (wiring is
phase 03), so this phase alone is a no-op for users.

## Next steps

Hands off to phase 03 (wiring + analytics). Design gates run in phase 04.
