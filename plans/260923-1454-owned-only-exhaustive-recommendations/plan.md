# Owned-only + exhaustive V05 recommendations · drop "Mixed"

Status: implemented (pending review + design gate + deploy) · Branch (all repos): `claude/eloquent-dijkstra-31h54u`
Repos: `auxi-wardrobe/auxi-backend` (engine/API), `auxi-wardrobe/auxi-mobile` (app)

## Why
Tester account (male) got near-duplicate outfits + WOMEN's items not in wardrobe.
Root causes (verified in code):
1. Mobile hardcodes `user.gender = 'U'` on /build → engine gender gate = union M∪W.
2. Engine injects SYSTEM catalog items (starved-slot backfill, COOL thin enrichment,
   empty-wardrobe fallback) — with gender U → women's catalog items for men.
3. Diversity = item-Jaccard distance → "same top+bottom, other jacket/shoes" counts as new;
   anchors limited to top-30% versatility → low-versatility items never used;
   exhaustion silently relaxes floor (0.5×) then re-serves seen outfits (`cycled`);
   every /build restarts from zero (no persistent seen state).

## Product decisions (CEO, 2026-09-23)
- Onboarding: only Menswear / Womenswear (drop Mixed). Existing Mixed users → random M/W.
- Item tags unchanged. `U` items visible to both M and W wardrobes.
- Gender editable in Settings (drives Discovery + catalog + starter items).
- Recommendations: ONLY items the user owns. Exhaust every distinct outfit first, then
  tell the user "no more options" — never pad with outside items.
- App is test-users only → migration impact on existing users can be light.

## Design
### Gender (P0)
- Server resolves wardrobe gender from `user_metadata.wardrobe_direction` (M/W);
  client `user.gender` is ignored (kept for wire compat, deprecated).
- Visibility rule: M sees tags ∋ M, or ∋ U and ∌ W. W symmetric. (Keeps AU-305: [W,U] never to M.)
- Gender gate applies only to items the user did NOT choose: SYSTEM catalog + Macgie starter
  seeds (`is_default_item`). User uploads / user-picked clones = ownership is intent → no gate.
- `PUT /api/me/wardrobe-direction` → validates M/W, stores, re-seeds starter (default) items.

### Owned-only (P0)
- Remove catalog injection + empty-wardrobe SYSTEM fallback. Starved slot → `wardrobe_gap`.
- Hard ownership guard on every served outfit (build + try_another): item must be owned,
  not deleted; starter seeds must match wardrobe gender. Violations dropped + logged.

### Exhaustive coverage (P1)
- "Primary" = TOP+BOTTOM pair or FULL_BODY. Two outfits with the same primary = same outfit.
- Engine enumerates ALL valid primaries in the L1 pool (no top-30% anchor cutoff), composes
  footwear/outer per primary with existing rules.
- Persistent seen store (Redis, per user × gender × climate bucket × occasion, TTL 14d):
  seen primaries + item exposure counts. /build continues where the user left off.
- Order: most never-shown items first (coverage) → avoid recent anchors → score/distance.
- Exhausted (no unseen primary, incl. "less used" rung) → `exhausted=true`, no relax, no cycle.
  `/build reset_seen=true` restarts.

## Phases
1. Backend P0 gender + owned-only + guard + settings endpoint + migration — [x] `auxi-backend@8e8d77b`
2. Backend P1 coverage engine + seen store + try_another/build rewiring — [x]
3. Backend tests + API_DOCUMENTATION.md — [x] (new: `tests/test_v05_coverage_exhaustive.py`)
4. Mobile: onboarding M/W only, Settings gender, drop hardcoded 'U', exhausted UX, tracking — [x] `auxi-mobile@20ca2a1`
5. Verify + push both repos — [x] pytest: 0 new failures (15 pre-existing: S3/tryon/chat/…);
   tsc: 3 pre-existing errors only; jest: 0 new failures, 6 previously-failing now pass; eslint clean.

## Deploy order
1. Backend first (`alembic upgrade head` runs `dropmixed1a2b`). Old app vs new backend is safe:
   its `gender:'U'` is ignored; `exhausted` responses render as an empty deck.
2. Then mobile (needs `PUT /api/me/wardrobe-direction` + `exhausted`).

## Open items
- designer gate (step 6.5) NOT run — no simulator in this session. New UI reuses existing
  patterns only: Home error/empty-state styles, SettingsRow/SettingsDialog/RadioOptionList,
  InfoSnackbar action. Needs qa-ui/designer pass on sim before merge.
- Starter seeds of former-Mixed users: other-gender seeds are hidden from suggestions but
  stay visible in the Wardrobe until the user switches direction in Settings (re-seed).
- Latency measured (engine, synthetic): 40 tops × 25 bottoms → ~0.1 s per call.
- Umbrella submodule pointers NOT bumped (branches unmerged; submodule URLs point at the
  ducga1998/* mirrors).

## Tracking (mobile)
- `wardrobe_direction_changed` {from, to} (Settings)
- `recommendation_exhausted` {occasion, outfits_seen}
- `recommendation_seen_reset` {occasion}
