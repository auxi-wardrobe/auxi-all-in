# Phase 03 — Trigger wiring + analytics

**Owner:** mobile-dev · **Priority:** P1 · **Status:** pending · **Effort:** 4h
**Blocked by:** phase 01 (endpoint live + documented), phase 02 (sheet + screen exist)
**Scope:** `auxi/` only.

## Context links

- Rule: `.claude/rules/analytics-tracking-required.md` (event naming, no-PII, doc update)
- Taxonomy: `auxi/docs/analytics/mixpanel-tracking-plan.md`
- Single tracking seam: `auxi/src/services/analytics.ts:136` (`track(event, props)`)

## Key insights (verified 2026-08-14)

**The three trigger sites already exist as success-analytics call sites.** Wire the gate check
immediately after each, so the check runs exactly when a use has definitely happened:

| Feature | Trigger site | Existing event |
|---|---|---|
| See on Me | `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx:318` | `try_on_completed` |
| Enhance photo | `auxi/src/screens/item-detail/EnhanceImageScreen.tsx:164` | `enhance_completed` |
| Wardrobe upload | `auxi/src/screens/wardrobe/useAddWardrobeItem.ts:173` | `add_item_upload_succeeded` |

(`useAddWardrobeItem.ts:141` `wardrobe_item_added` fires slightly earlier in the same handler; use
`:173` so the item is definitely persisted.)

Naming precedent for a gate sheet already exists: `ai_limit_gate_shown`
(`SeeThisOnMeScreen.tsx:287,333,419`) with `{ feature, phase }` props. Mirror that shape.

**Collision check** against the shipped taxonomy: `paywall_viewed` / `paywall_dismissed` are already
taken by the real RevenueCat paywall (`auxi/src/screens/UpgradeScreen.tsx:216,226`), as are
`purchase_started|succeeded|failed|restored` (`analytics.ts:485` region). **Do not reuse them** — a
soft-paywall impression must not pollute the real paywall funnel. New names below are collision-free
(grepped `auxi/src/services/analytics.ts`, 2026-08-14).

## Requirements

**Functional**
1. After each of the 3 successful actions, fetch usage and open the sheet iff the corresponding
   `limit_reached` is true AND the user is free (`isFreeUser`, `auxi/src/services/subscription.ts:12`).
2. Fail-open: any error/timeout on `GET /api/me/usage` → no sheet, no toast, no retry storm.
3. Show at most once per feature per app session.
4. Emit the events below.

**Non-functional**
5. The check must never delay or block the success UI — fire-and-forget after the success render.
6. Kill-switch `PAYWALL_MVP_ENABLED` const in the gate module (same pattern as
   `SHOW_UPGRADE_PAYWALL`, `auxi/src/screens/SettingsScreen.tsx:69`).

## Architecture — data flow

```
user completes action (try-on / enhance / upload)
        │  existing success track() fires (unchanged)
        ▼
maybeShowUsageLimit(feature)          services/usageLimit.ts
        │  guard 1: PAYWALL_MVP_ENABLED
        │  guard 2: isFreeUser(user)
        │  guard 3: not already shown this session for `feature`
        ▼
GET /api/me/usage   (usageService.ts → apiClient)   ── error/timeout ──► return false (fail-open)
        ▼
features[feature].limit_reached ?
        ├─ false → return false
        └─ true  → mark shown · track('usage_limit_gate_shown') · gate.open(feature)
                        ▼
                 <UsageLimitSheet />
                    ├─ dismiss  → track('usage_limit_gate_dismissed')
                    └─ Upgrade  → track('usage_limit_upgrade_tapped') → navigate('NotifyMe')
                                          ▼
                                   NotifyMeScreen
                                     ├─ mount    → track('notify_me_viewed')
                                     └─ CTA tap  → track('notify_me_tapped')
```

**Session-shown memory**: module-scope `Set<UsageLimitFeature>` in `services/usageLimit.ts`, cleared
on logout — exactly the `aiLimitStore` pattern (`auxi/src/services/aiLimitStore.ts`, in-memory,
self-healing, never persists a wrong block).

## Analytics spec

All names `snake_case`, past tense / noun_verb, literal string constants (no template literals).
No PII: only the feature key and integer counts.

| Event | Props | Fires when |
|---|---|---|
| `usage_limit_gate_shown` | `feature`, `used` (int), `limit` (int) | sheet becomes visible |
| `usage_limit_gate_dismissed` | `feature` | sheet dismissed without tapping Upgrade |
| `usage_limit_upgrade_tapped` | `feature` | "Upgrade" CTA tapped **(ticket requirement)** |
| `notify_me_viewed` | `feature` | NotifyMe screen mounts |
| `notify_me_tapped` | `feature` | "Notify me" CTA tapped **(ticket requirement)** |

`feature` values: `see_on_me` \| `wardrobe_items` \| `enhance_photo` (lowercase, matches the
backend keys exactly — one vocabulary across both repos).

**Funnel** (add to `mixpanel-tracking-plan.md` §10):
`usage_limit_gate_shown → usage_limit_upgrade_tapped → notify_me_viewed → notify_me_tapped`
= the demand signal the ticket exists to produce. Segment by `feature` to learn which threshold
converts.

**Doc update is part of "done"**: add all 5 events to `auxi/docs/analytics/mixpanel-tracking-plan.md`
§5 with `file:line`, and the funnel to §10.

## Related code files

**Create**
- `auxi/src/services/usageLimit.ts` — feature union, session memory, `maybeShowUsageLimit`, kill-switch
- `auxi/src/services/usageService.ts` — `getUsage()` wrapping `apiClient` (never import axios directly)
- `auxi/src/services/__tests__/usageLimit.test.ts`

**Modify**
- `auxi/src/screens/see-this-on-me/SeeThisOnMeScreen.tsx` (after `:318`)
- `auxi/src/screens/item-detail/EnhanceImageScreen.tsx` (after `:164`)
- `auxi/src/screens/wardrobe/useAddWardrobeItem.ts` (after `:173`)
- `auxi/src/screens/NotifyMeScreen.tsx` (add the 2 events — file created in phase 02)
- `auxi/src/components/features/UsageLimitSheet.tsx` (dismiss/upgrade callbacks)
- `auxi/src/context/AuthContext.tsx` — clear session memory on logout (follow the
  `setTryOnResultUser(null)` precedent in `auxi/src/services/tryOnResultStore.ts`)
- `auxi/docs/analytics/mixpanel-tracking-plan.md`

## Implementation steps

1. `usageService.getUsage()` — typed response matching phase-01's shape.
2. `usageLimit.ts` — union type, `SHOWN` set, `PAYWALL_MVP_ENABLED`, `maybeShowUsageLimit(feature, user)`
   returning `Promise<{ used, limit } | null>`; all three guards + fail-open try/catch.
3. Mount the gate in each of the 3 screens: `const gate = useUsageLimitGate()` and render
   `<UsageLimitSheet {...gate.sheetProps} />` in each tree (mirrors how `AiLimitSheet` is mounted at
   `SeeThisOnMeScreen.tsx:674-708`).
   `useAddWardrobeItem` is a hook — return `usageLimitSheetProps` for `WardrobeScreen` to render,
   the same way it already returns `aiConsentDialogProps`.
4. Wire the 5 `track()` calls.
5. Update the tracking-plan doc.
6. `npx tsc --noEmit`, `yarn lint`, jest.

## Test matrix

| Level | Case | Expect |
|---|---|---|
| unit | `limit_reached: true`, free user, first time | sheet opens, `usage_limit_gate_shown` once |
| unit | same feature twice in one session | sheet opens once, event fires once |
| unit | different feature after the first | sheet opens again (per-feature memory) |
| unit | premium user | never opens, no event, no request |
| unit | `getUsage()` rejects (network) | returns null, no sheet, no crash, no toast |
| unit | `getUsage()` times out | same as above |
| unit | `PAYWALL_MVP_ENABLED = false` | no request at all |
| unit | logout then login as another user | session memory cleared |
| unit | event props | contain only `feature`/`used`/`limit`; no urls, no item ids, no free text |
| integration | backend on :5001, real HTTP | sheet appears at the real boundary (no mocks — umbrella verification gate) |
| e2e (Maestro) | try-on flow to the 2nd render | sheet visible by `testID` |

## Todo

- [ ] `usageService.getUsage()`
- [ ] `usageLimit.ts` (guards + fail-open + session memory + kill-switch)
- [ ] wire 3 trigger sites
- [ ] wire 5 analytics events
- [ ] clear session memory on logout
- [ ] `mixpanel-tracking-plan.md` §5 + §10
- [ ] tsc / lint / jest clean
- [ ] real-HTTP smoke against `:5001`

## Success criteria

- On a free account: 2nd See-on-me render → sheet; Upgrade → NotifyMe; Notify me → confirmed state.
- Mixpanel live view shows all 5 events with the expected props.
- Killing the backend mid-flow produces **no** sheet and **no** error UI (fail-open proven).
- Third repeat of the same action in the same session produces no second sheet.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| Sheet interrupts the try-on result reveal / feels like an error | H×M | open AFTER the success UI settles; designer gate (phase 04) reviews the moment, not just the pixels |
| Nag loop (sheet on every subsequent action) | H×H | per-feature per-session memory + unit tests for it |
| Endpoint latency delays success UI | M×M | fire-and-forget, never awaited by the render path |
| Event-name collision with the real paywall funnel | M×H | distinct `usage_limit_*` / `notify_me_*` namespace, grepped clean |
| Extra request on every successful AI action | M×L | guarded by free-user + not-yet-shown checks, so it stops firing once shown |
| User thinks they were charged / blocked | M×H | copy must say "coming soon", not "buy now"; qa-ux review in phase 04 |

## Security

- No PII in any event (rule: `.claude/rules/analytics-tracking-required.md`).
- No new persisted state; nothing written to AsyncStorage or Keychain.
- Endpoint is auth-scoped to the caller (phase 01).

## Backwards compatibility

- Old app builds never call `/api/me/usage` → unaffected.
- A new app build against an old backend gets 404 → fail-open path → no sheet. **Ship backend first.**

## Unresolved questions

Operator semantics, reset cadence, and "Notify me" scope are confirmed (2026-08-14): `used >= limit`
at 2/51/31; see_on_me + enhance_photo reset monthly, wardrobe_items never; Notify-me is
**Mixpanel-only**, no backend waitlist write.

Still open:
1. Should the sheet also be reachable from a passive entry (e.g. Settings) or strictly
   threshold-triggered? Plan assumes **strictly threshold-triggered**.
2. Is `NotifyMe` a full screen or a second sheet state? Depends on the Figma frame — mobile-dev
   resolves this in phase 02 during Figma extraction, escalates if node `4444-26066` has no sibling
   frame for it rather than inventing UI.
