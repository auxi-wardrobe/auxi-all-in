# Phase 08 — Cross-file dedup (P3)

**Scope:** architectural duplication across screens · **Depends on:** phases 04 + 07 landed
**Status:** ⬜ todo

## Problem 1 — Photo-source sheet exists in 3 forms
- BodyScreen: 2 raw `Modal`s (phase 04 replaces with `PhotoSourceSheet`).
- `see-this-on-me/components.tsx`: `PhotoSourceSheet` — but still a raw `Modal` internally.
- **Action:** make ONE canonical `PhotoSourceSheet` built on `MActionSheet`/`MSheetOption`; both Body + SeeThisOnMe import it. Delete the other two. Location: `components/features/PhotoSourceSheet.tsx` (promote out of see-this-on-me).
- **Saving:** removes 2 duplicate implementations + 1 raw Modal.

## Problem 2 — Two divergent try-on pipelines
- BodyScreen: **synchronous** `generateTryOn` + inline `pollJob` (L301–340).
- SeeThisOnMe: **background** `tryOnGenerationStore` (survives backgrounding, rehydrates).
- Same feature, two implementations → drift risk (different error handling, no shared retry/poll policy).
- **Action:** unify on `tryOnGenerationStore` (the more robust one). Migrate BodyScreen's sync path to submit via the store + subscribe. Verify Body's UX (it may intentionally block-wait) — if a synchronous UX is required, at minimum extract a shared `useTryOnJob` hook wrapping poll/retry/error so both share one policy.
- **Decision needed:** is Body's synchronous try-on UX intentional, or legacy? Confirm before unifying.

## Steps
1. After phase 04 + 07 land, promote canonical `PhotoSourceSheet` (on `M*`); repoint both imports; delete duplicates.
2. Audit both try-on call sites; decide unify-on-store vs shared-hook (per decision above).
3. Implement chosen path; verify try-on works identically from both Body and SeeThisOnMe on sim (incl. backgrounding on the SeeThisOnMe path).

## Success criteria
- Exactly one `PhotoSourceSheet` implementation, on `M*`.
- One shared try-on job policy (store or `useTryOnJob` hook); no duplicated poll/error logic.
- Try-on generation verified end-to-end from both entry points. `track()` preserved on both.

## Risks
- Try-on pipeline is user-facing + costs API (OpenAI gpt-image-1 primary + Gemini fallback — see memory `tryon-image-provider`). Do NOT change provider logic; only unify the client-side job orchestration.
- Backgrounding/rehydrate behavior must not regress on the SeeThisOnMe path.

## Unresolved questions (whole plan)
1. `FigmaPrimitives` legacy vs approved parallel DS? (defaults to migrate→`M*`)
2. `SettingsSwitch` retire for `MSwitch`? (phase 05)
3. Wardrobe AI-processing raw `Modal` → `MBottomSheet`? (phase 06)
4. ItemDetail exported helpers — external test imports? (phase 03)
5. `_HomeScreen.tsx` legacy — shared blocks / safe to delete? (phase 01)
6. Body synchronous try-on UX — intentional or legacy? (this phase)
