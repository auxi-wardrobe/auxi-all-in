# V05 Try Another — Mobile Swipe Wiring Fix

**Date:** 2026-05-25
**Scope:** `auxi/` only (mobile). Backend already ships both endpoints — no backend change.
**Priority:** High (every swipe = a full engine `build`; wasteful latency + LLM cost)

## Problem

Home swipe currently calls `POST /api/v05/recommendation/build` on **every** prefetch.
Backend designed 2 endpoints:
- `build` (heavy: 6-layer engine + LLM-1, returns 1–3 outfits + `session_id` + seeds a Redis pool)
- `try_another` (light: serves a variation from that pool with axis-distance scoring; recompose only on cache-miss)

Mobile `v05Api.ts` only implements `buildRecommendation` — there is **no** `tryAnother`, and the
`build` response `session_id` is discarded. So the pool cache + cheap variation path are unused, and
there's no cross-call diversity (`session_id` / `memory` / `exclude_ids` never threaded).

## Authority

- Contract: `wardrobe-backend/docs/v05-try-another-mobile-contract.md` (READ FULLY — it is the spec)
- API ref: `wardrobe-backend/API_DOCUMENTATION.md` §V05 Recommendation
- Existing V2 session-closure pattern to mirror: `auxi/src/services/recommendationService.ts`

## Design decisions (confirmed)

1. **Session state** lives in `v05Api.ts` module-scope closure (mirror `recommendationService.ts`).
   `session_id` is bearer-equivalent (contract §8) — never log it.
2. **build vs try_another routing:**
   - cold start → `build` (no session yet)
   - swipe prefetch / "Show another" → `try_another`
   - refine/context submit (`handleSubmitContext`) → `resetV05Session()` then `build`
   - error retry → `build`
   - **mode change** → `resetV05Session()` only (lazy); next prefetch rebuilds with new mode
     (try_another's `mode` is a no-op in MVP, so mode must rebuild to take effect)
3. **Fallback** (`fallback:true, outfit:null`) or `wardrobe_gap:true` → return empty outfits
   (no card appended, keep existing outfits, log). Toast / wardrobe-gap CTA = separate follow-up ticket.
4. **Error matrix** per contract §5/§6 — handle in the service:
   - `410 session_expired` (also cross-user) → silently `resetV05Session()` + `build`, return its outfits
   - `422 stale_hash` → treat like 410 (reset + build)
   - `429 session_locked` → silent retry w/ 200ms backoff, cap 2–3 attempts, then bubble
   - `429 rate-limit`, `401`, `500`, timeout → bubble to existing mutation `onError`

## Files

### Modify `auxi/src/services/v05Api.ts`
- Add types: `VariationAxis` (`silhouette|color|layering|footwear|accessory`), `TryAnotherInput`,
  `TryAnotherOutfit`, `TryAnotherResponse` (per contract §3/§4). Keep V05 enums separate from V2
  (contract §7: do NOT share enum strings).
- Add `tryAnother(input): Promise<TryAnotherResponse>` — thin axios wrapper to `/v05/recommendation/try_another`.
- Add module-scope `v05SessionId`, `v05LastOutfitHash`; `resetV05Session()`.
- Add façade `recommendV05(params): Promise<{ outfits: V05Outfit[] }>`:
  - if `!v05SessionId` → `build`, store `session_id` + `outfits[suggested_default].outfit_hash`,
    return its `outfits`.
  - else → `tryAnother({ session_id, current_outfit_hash: params.current_outfit_hash ?? v05LastOutfitHash, axis?, style_feedback?, pinned_item_id?, mode? })`;
    on success store new `outfit_hash`, return `[outfit]` (or `[]` on fallback/gap);
    on 410/stale → reset + build (return build outfits); on 429-locked → backoff retry.
  - `build` input keeps current mapping from `buildViaV05` (weather/user/intent/count:3).
- Keep `buildRecommendation` + `submitFeedback` as-is.

### Modify `auxi/src/screens/HomeScreen.tsx`
- `buildViaV05` (≈L390-446): call `recommendV05(params)` instead of `v05BuildRecommendation`
  directly; keep the existing `V05Outfit → legacy Outfit` mapping (`FAMILY_TO_CATEGORY`, `mapItem`).
  Thread `current_outfit_hash` = active sheet hash when available (mirror recommendationService).
- `handleSubmitContext` (≈L759-802): call `resetV05Session()` before `valenGetRecommendation(...)`.
- `handleSelectMode` (≈L653-662): call `resetV05Session()` so the next prefetch rebuilds.
- Cold-start useEffect (L501) + error retry (L970): unchanged (no session → build).
- On logout: add `resetV05Session()` only if an easy hook already exists; else leave the existing
  `recommendationService` TODO-note pattern. (Do not invent an AuthContext subscription now.)

## Out of scope (note as follow-ups, do NOT build)
- wardrobe-gap CTA + reason copy (contract §15), `source` badge (§16)
- refine-modal explicit-axis chips (contract §10 pattern 2)
- Mixpanel telemetry events (contract §11) — keep existing `console.info`/`track` calls
- `memory.recent_signatures` / `exclude_ids` cross-call diversity threading

## Verification (mobile-dev must run)
- `cd auxi && npx tsc --noEmit` — clean (legacy `_HomeScreen.tsx` errors expected/ignored)
- `cd auxi && yarn lint` — no NEW errors/warnings beyond the known baseline (4 err / 3 warn in `_HomeScreen.tsx`)
- Confirm no `axios` direct import; all HTTP via `apiClient`
- Confirm `session_id` is never passed to `console.*`

## Success criteria
- Swipe / "Show another" prefetch fires `POST /v05/recommendation/try_another` (not `build`)
- First load fires exactly one `build`; `session_id` captured and reused
- Refine submit + mode change cause the next fetch to be a fresh `build` (new session)
- 410/stale/locked handled silently per contract; fallback never crashes the screen
- tsc + lint green

## QA handoff (after mobile-dev)
- `qa-mobile`: iOS sim smoke — cold start (1 build), swipe several times (try_another each),
  change mode then swipe (build once), refine submit (build once). Inspect network if possible.
