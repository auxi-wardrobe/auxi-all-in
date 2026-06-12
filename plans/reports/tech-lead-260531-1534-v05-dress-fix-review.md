# Tech-Lead Review — V05 Dress-Exclusion Fix (uncommitted)

**Date:** 2026-05-31 · **Branch:** `feat/backfill-cutout-rembg` · **Reviewer:** tech-lead
**Scope:** 4 files in working tree (engine only) — `engine_v05_layers.py`, `engine_v05_signature.py`,
`engine_v05_constants.py`, `tests/test_engine_v05_unit.py`. Unrelated `*feedback*` working-tree changes ignored per brief.

## Verdict: PASS-WITH-NOTES

Sound to commit/ship. Zero contract-breaking changes, zero critical findings. Two non-blocking
data-hygiene items to route (one is more serious than the blast-radius report framed it).

---

## 1. API contract impact — NO SHAPE CHANGE, no auxi sync needed

**Answer: NO.** `is_one_piece` never reaches the wire.

Trace:
- Engine emits it: `engine_v05_signature.py:88` (`compute_vibe_signature` return dict) +
  `:53` (empty-items early return).
- Response is built via `OutfitDTO(**o)` at `services/v05_build_service.py:232`, coercing the
  engine `vibe_signature` dict into `VibeSignatureDTO` (`schemas/v05_recommendation.py:114-119`).
- `VibeSignatureDTO` is a strict 5-field model (`dominant_color_family`, `dominant_silhouette`,
  `formality_band`, `statement_level_avg`, `aesthetic_tags`) with **no `model_config`/`extra`** →
  Pydantic v2 default `extra="ignore"` **drops `is_one_piece` at validation**.
- Both `/build` (`response_model=BuildResponse`) and `/try_another` (`response_model=TryAnotherResponse`,
  via `OutfitWithHash(OutfitDTO)`) re-serialize through that DTO. `is_one_piece` is grep-clean across
  `routers/`, `services/`, `schemas/` — present only in the two engine files.
- `API_DOCUMENTATION.md` §V05 documents `vibe_signature` with exactly the 5 fields
  (lines 3509-3513, 3559-3565, 3860-3865) → still accurate, **no doc edit required**.

**auxi side confirmed in sync:** `auxi/src/services/v05Api.ts:163-169` `VibeSignature` is the same
5-field shape, used both as the per-outfit read (`V05Outfit.vibe_signature`, `:245`) and the echoed
input (`BuildMemory.recent_signatures?: VibeSignature[]`, `:194`). Because the backend strips
`is_one_piece` from the response, the client never sees it and never echoes it. The construction-aware
novelty throttle (C2) operates **entirely server-side** on freshly-computed signatures
(`engine_v05_layers.py:1031` `signature_similarity` on `compute_vibe_signature` output) — it does NOT
depend on the client round-trip. **No auxi action.**

> One subtlety worth noting (not a defect): client-echoed `recent_signatures[]` will lack
> `is_one_piece`, so `signature_similarity(client_sig, fresh_sig)` adds 0 on the construction term
> for the False==missing case. This only weakens the throttle on the *cross-build* memory path, not
> the in-session `recompose`/build path where both sigs are server-computed. Acceptable for this
> iteration; if cross-build construction-throttle is wanted later, that WOULD require adding the field
> to the wire (additive) + an auxi echo — file as a follow-up, not a blocker.

## 2. C3 deviation soundness — SOUND (no guard needed)

`layer6_diversify` family floor (`engine_v05_layers.py:1079-1092`) fires only when BOTH:
(a) `len(selected) < count` (diversity pass left slots open), AND
(b) every already-selected outfit is one-piece.

It then **appends one** separate (single `sep`, not a loop) — first from `top_k` (best-scored set),
falling back to the full candidate list sorted by score.

- The top-scored outfit (`top_k[0]`) is always pick #1 and is **never displaced** — the separate is
  added to an open slot, so quality of the lead card is untouched.
- The full-list fallback picks `max(score)` among separates, i.e. the best available separate, not an
  arbitrary low one. The "below top-K threshold" risk is bounded: it only surfaces a sub-top-K outfit
  when the wardrobe genuinely has no separate in the top-K AND the user owns separates — exactly the
  exclusion case this fix targets. Surfacing the best-of-a-weak-set separate is the intended product
  behaviour (CEO Hướng 1: "she sees separates"), strictly better than 100% one-piece.
- No IndexError risk: `layer6_diversify` early-returns on empty `candidates`; `o["items"][0]` follows
  the established anchor-at-index-0 convention already used elsewhere in the engine.

No additional quality guard required. If product later wants a hard score-floor on the surfaced
separate, that's a tunable, not a correctness fix.

## 3. U (unisex) 0% -> 63% — DESIRABLE, low regression risk in the engine; BUT see §4b

Engine-side: `fb_share = fb_bonus/(fb_bonus+1)` with `fb_bonus=1.0` for U → 0.50 cutoff share, and the
proportional cutoff lets U users who *own* dresses actually see them. This is the same exclusion bug
(U was also 0% with no lean) and the fix is correct and symmetric. A U user with no FULL_BODY items is
unaffected (`if fb_cands and top_cands:` guard — single-family wardrobes fall through to the old path).
M stays 0% (empty FB pool after the L1 `forbid_family` gate). **Desirable, no surprising engine regression.**

The real surprise is NOT in the engine — it's that **auxi sends `gender:'U'` for every Home build**
(see §4b), so this 0→63% U change is the one that actually hits production users today. That makes the
U path the *primary* behavioural change for live users, not a secondary one. Still desirable (a Mixed/any
user who owns dresses now sees ~50% one-piece instead of 0%), but worth calling out for QA: the visible
Home behaviour change is driven by the U band, not the W band.

## 4. Data-hygiene flags — routing

**(a) `users.gender` has zero FEMININE rows in prod — DEAD mapping.** Confirmed conceptually: the engine
keys exclusively on the `user.gender` payload (`M|W|U`, validated in `UserDTO`,
`schemas/v05_recommendation.py:52-57`), NOT on a `users.gender` column. Any code gating on
`gender=="FEMININE"` is dead relative to V05. **Route to: backend-dev** (cleanup ticket, non-blocking) —
audit/remove dead `FEMININE`-keyed branches; confirm onboarding writes the canonical value the engine
expects. Not part of this fix.

**(b) Mixed → W|U mapping — MORE SERIOUS THAN FRAMED. The auxi Home client does NOT map at all.**
`auxi/src/screens/HomeScreen.tsx:559` hardcodes `user: { gender: 'U', occasion }` on the `/build` call.
`wardrobe_direction` (Menswear/Womenswear/Mixed) is collected in onboarding and sent only to
`/onboarding/generate` — it is **never** translated to `M|W|U` for the per-Home `/build`. Consequences:
  - Every Home recommendation runs as **U**, regardless of the user's wardrobe direction.
  - A Womenswear user therefore gets the **U** band (0.50 fb_share post-fix), **not** the W lean (0.67)
    the design's headline metric ("SURFACED W 100%→70.1%") is tuned against. The W-band fix is currently
    **unreachable from the mobile Home flow** — only the onboarding generate path (which does pass
    `wardrobe_direction`) exercises W.
  - This is a **pre-existing** mobile gap, NOT introduced by this backend fix, and it does NOT block the
    commit. But it means the design's W acceptance band won't be what real Home users experience until
    auxi maps direction→gender on the build call.

  **Route to: tech-lead follow-up + mobile-dev.** This is a genuine cross-repo contract gap worth a
  ticket: decide the canonical `Womenswear→"W"`, `Menswear→"M"`, `Mixed→"U"` (or `"W"`) mapping and wire
  it into the auxi build call. Until then, the W-lean lands for onboarding-generate only. Flag to PM as
  "W-band fix not live on Home until mobile direction→gender mapping ships."

## 5. Overall

- **Engine logic:** C1 cleanly decouples `cutoff_key` (versatility, family-blind) from `draw_weight`
  (versatility × lean), and the family-proportional cutoff (`fb_share = fb_bonus/(fb_bonus+1)`) is a
  sound, tie-robust way to express the lean as a share rather than an exclusion. The `force_axis` boost
  correctly applies to BOTH keys (preserves signature-flip reach). 3-tuple refactor is applied
  consistently through the weighted-draw loop.
- **C2:** `is_one_piece` added; `signature_similarity` rebalanced to sum 1.0 (color .20 / silhouette .20
  / formality .15 / construction .25 / statement .10 / tags .10). Weight sum verified by the new unit
  test. `CONSTRUCTION_SIMILARITY_WEIGHT=0.25` is documented as a tuned ceiling — reasonable.
- **Tests:** `tests/test_engine_v05_unit.py` 65 passed (re-ran, 0.13s). Covers exclusion regression,
  lean-preserved, M-gate-intact, one-piece flag, similarity-sum-1.0.
- **Verification still owed before merge (per umbrella gate):** `python test_server.py` green +
  `v05-eval --fresh` no PoolInsufficient regression (plan Task 5 Steps 3+5). The brief reports the
  structural harness numbers; confirm the e2e server test is green at commit time.

## Findings by severity
- **critical:** none.
- **major:** none in the diff. (§4b is a pre-existing auxi gap, not in this diff — routed as a follow-up
  ticket, not a blocker on this commit.)
- **minor:** §1 subtlety — client-echoed `recent_signatures` lack `is_one_piece`, so the construction
  throttle is server-side-only on the cross-build memory path. Acceptable; document as known.

## Unresolved questions
1. Did `python test_server.py` pass at HEAD-of-working-tree? (umbrella gate — confirm before commit)
2. §4b: product call on `Mixed → "W"` vs `"U"` for the Home build mapping (decides whether Mixed users
   get the lean). Needs PM + mobile-dev.
