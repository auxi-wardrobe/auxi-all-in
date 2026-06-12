# Phase 0 — Decision Gates + Contract Resolution

**Priority:** P1 (blocks ALL) · **Status:** CEO decisions RESOLVED 2026-05-26 · qa-ui review-extraction PENDING · D1 tech-lead rubber-stamp PENDING · **Effort:** ~2h
**Owner:** tech-lead (contract) + CEO/designer (copy/visual) + mobile-dev (qa-ui dispatch)

> **2026-05-26 — CEO delegated all UX/UI calls to the implementer.** D2–D11 resolved below (inline ✅).
> Remaining gate items before Phase 3 impl: D1 tech-lead rubber-stamp (verdict = N/A) and the qa-ui review-extraction PASS.
> CEO also added new scope: a **Replay Onboarding dev mode** (see bottom) — already implemented as testing tooling.

## Context links
- Extraction §9 (11 open questions): `plans/260526-1443-onboarding-figma-extraction/figma-extraction-onboarding.md`
- Backend contract: `wardrobe-backend/API_DOCUMENTATION.md` L3373-3462
- Client enums: `auxi/src/services/v05Api.ts:22-48`

## Overview
No code is written until this gate clears. Resolves the backend-contract verdict,
the legacy swap-vs-keep product decision, and the CEO copy/visual decisions. Also
runs the **qa-ui review-extraction** pass mandated by the Figma→RN workflow.

## Key insights (verified during planning)
- **Backend is ready.** `/onboarding/generate` (L3393-3395) accepts
  `wardrobe_direction ∈ {Menswear,Womenswear,Mixed}`, `fit_preference ∈
  {Slim Fit,Classic Fit,Relaxed Fit}`, `style_preferences` = 2-3 ranked from
  {Minimal,Casual,Soft,Bold,Formal}. The current `StylePickerScreen.tsx:44-45`
  already enforces MIN=2/MAX=3. **No router/model/migration work.**
- **One real mismatch:** Figma Step-2 labels are **Slim / Regular / Relaxed**;
  the wire allowlist is **Slim Fit / Classic Fit / Relaxed Fit**. "Regular"≠
  "Classic Fit" semantically. Existing `StylePreferenceScreen.tsx:57-61` already
  maps `classic → 'Classic Fit'` with label "Classic fit". → keep the wire
  value, decide the **display label** (Phase 0 decision #2).
- **Figma says "pick up to two"** but the contract allows 2-3. Plan implements
  **max 2** to match Figma (the pin badges only show "1","2"). Backend accepts
  a 2-element array fine. Confirm CEO wants exactly-2 (not 2-3).

## Decisions to resolve (gate)

### Contract / tech-lead
- [~] **D1 — Verdict sign-off:** NO backend change (verified). ⏳ tech-lead rubber-stamp
      pending so "route change → doc update" rule is formally satisfied as N/A.
- [x] **D2 — Fit display label:** ✅ Display **"Regular"** (UI). Wire value stays
      `Classic Fit`. Mapping table in `config.ts`: Slim→`Slim Fit`, Regular→`Classic Fit`,
      Relaxed→`Relaxed Fit`. Never hardcode wire values in UI.
- [x] **D7 — Style pick count:** ✅ **Max 2** ranked picks (matches Figma pins). KISS.

### CEO / designer (copy + visual)
- [x] **D3 — "MACGIE wardrobe":** ✅ placeholder → **"Your wardrobe"**.
      Loading: "Your wardrobe will be ready in a moment". Completed: "Your wardrobe is ready".
- [x] **D4 — Copy typos:** ✅ "Minmal"→"Minimal"; "in you profile"→"in your profile";
      drop stray quote; clean "Get outfit suggestions that work". All final strings in `config.ts`.
- [x] **D5 — Caption-pill color:** ✅ canonical = **`rgba(18,18,18,0.75)`** (the majority tiles).
      Treat the one `rgba(39,42,50,0.9)` tile as a Figma inconsistency, not a variant.
- [x] **D6 — Pin badge:** ✅ styled **View + number** (number is dynamic), max count **2**.
- [x] **D8 — Branch behaviour:** ✅ **ONE screen parameterised** by wardrobe choice
      (matches current code), not 3 distinct flows. DRY.
- [x] **D9 — Location-permission placement:** ✅ keep existing
      `Welcome → LocationPermission → Step1` order.
- [x] **D10 — Loading mechanics:** ✅ **real async wait on `/generate`** — Loading IS the
      in-flight call; auto-advance to Completed on success. No timed splash.

### Product / cutover
- [x] **D11 — Legacy swap:** ✅ new flow REPLACES V05 behind **`ONBOARDING_V2_ENABLED`**,
      legacy kept as fallback until verified in prod, then deleted (mirrors
      `UAC_V2_ENABLED` at `auxi/src/config/featureFlags.ts:29`).

### Load-bearing architecture decision
- [x] ✅ **Defer `completeOnboarding()` to the Outro "See my outfit" tap** (was: on
      `/generate` success). `/generate` is idempotent → mid-flow drop relaunches cleanly.
      Without this, the new Loading/Completed/Outro screens are unmounted when
      `AppNavigator` remounts to the Home stack.

## qa-ui review-extraction (workflow gate)
- [ ] mobile-dev dispatches `qa-ui` in **review-extraction** mode against the
      extraction artifact (Pass 1 only, no code). Outcome: PASS / FAIL / ESCALATE.
      Must be PASS before Phase 3 implementation begins.

## Implementation steps
1. tech-lead reviews §8 of extraction + contract L3373; records D1 verdict.
2. Compile D2-D11 into a single CEO message; capture answers.
3. mobile-dev dispatches qa-ui review-extraction; attach result.
4. Update `plan.md` decision-gate checklist with resolutions.

## Success criteria
- All D1-D11 answered and recorded in this file.
- qa-ui review-extraction = PASS (or ESCALATE resolved).
- `plan.md` "Decision gates" section updated; Phase 1 unblocked.

## Risks
| Risk | L×I | Mitigation |
|---|---|---|
| CEO copy answers slow → blocks all phases | M×H | Decouple: Phases 1-2 (tokens/scaffold) need only D5/D6/D8; copy (D3/D4) blocks only Phase 4 content, not structure. Start 1-2 on partial answers. |
| Hidden contract gap surfaces mid-impl | L×H | Phase 5 does a real HTTP smoke vs local backend before QA; any 400 caught early. |
| qa-ui FAILs extraction | L×M | Re-extract the failing frame; do not proceed to code. |

## Replay Onboarding dev mode — IMPLEMENTED 2026-05-26
CEO-added scope: let a logged-in user re-run onboarding repeatedly WITHOUT a new account (testing).
Client-only, no backend change. Double-gated (`__DEV__` + `ONBOARDING_REPLAY_ENABLED`), unreachable in release.

Files (auxi/):
- `src/config/featureFlags.ts` — `ONBOARDING_REPLAY_ENABLED = __DEV__`.
- `src/context/AuthContext.tsx` — `forceOnboarding` state (persisted `@auxi/force_onboarding`),
  `startOnboardingReplay()`, and clears `forceOnboarding` inside `completeOnboarding()`.
- `src/navigation/AppNavigator.tsx` — gate `is_first_login || forceOnboarding` (~L54).
- `src/screens/SettingsScreen.tsx` — dev-gated "Replay onboarding (dev)" row.

Trigger: Settings → "Replay onboarding (dev)" → swaps to onboarding `Welcome`; persists across reload;
clears on true completion (works post-V2 since clear lives inside `completeOnboarding()`).
Status: tsc/lint/token-lint clean for touched files. ⏳ qa-mobile sim verify pending.

> Finding: there is NO onboarding store — onboarding state lives in `AuthContext` + nav params.
> Phase 2 should build the V2 config/state on top of `AuthContext`, not a new store.
