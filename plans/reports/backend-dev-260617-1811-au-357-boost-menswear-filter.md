# AU-357 — "boost should not appear in menswear suggestion"

**Agent:** backend-dev · **Date:** 2026-06-17 · **Scope:** wardrobe-backend only

## Ticket
Reporter (Viet): menswear default must only include items tagged `M` / `[m][w]`,
but "Boost" items tagged `[w]` / `[w][u]` (women-only) are leaking into menswear
suggestions. Exclude women-only items from menswear; do the symmetric thing for
womenswear.

## Root cause (exact bypass)
The V05 engine already had the correct AU-357 hard gate wired at BOTH leak sites:

- L1 candidate-pool build — `blueprints/recommendation/engine_v05_layers.py:200`
  `if not is_gender_eligible(_gender_tags(it), user_gender): continue`
- SYSTEM "Boost" / safety-injection path — `blueprints/recommendation/engine_v05.py:1119`
  `if not is_gender_eligible(it.gender_tags or [], user_gender): continue`

…but the predicate they both call, **`is_gender_eligible`, did not exist** in
`utils/gender_scoring.py`. It is imported at `engine_v05.py:60`,
`engine_v05_layers.py:63`, and `tests/test_gender_filtering.py:19`, yet was never
present in any committed version of `gender_scoring.py` (verified:
`git show HEAD:utils/gender_scoring.py | grep -c is_gender_eligible` → 0;
`git log -S is_gender_eligible -- utils/gender_scoring.py` → empty).

Consequences of the missing function:
- `from utils.gender_scoring import is_gender_eligible` raised **ImportError**, so
  the V05 engine and the entire `test_gender_filtering.py` suite were broken on import.
- Functionally, there was no engine-side hard gate excluding `[W]`/`[W][U]` from
  menswear → women-only "Boost" items leaked in (the reported bug).

`is_item_visible_to_wardrobe` (the canonical wardrobe-visibility gate) is *almost*
the right predicate but differs on one case: it rejects a lone `["U"]` for a
gendered wardrobe, whereas the engine intentionally admits pure unisex into a
gendered *outfit* (composability). The V05 author named a distinct function
`is_gender_eligible` for exactly this reason; it was just never written.

## Fix (surgical, additive — 1 new function)
Added `is_gender_eligible(item_tags, user_gender)` to `utils/gender_scoring.py`
(after `is_item_visible_to_wardrobe`). It reuses the existing canonical
`resolve_wardrobe_gender` normalization and `_VALID_ITEM_GENDER_TAGS` set (DRY)
and does NOT modify any existing function.

Rule:
- Empty / null / non-list / no-valid-tag → never eligible (strict gate).
- No constraint / `U` wardrobe → any validly-tagged item eligible.
- `M`: eligible iff `"M"` present, OR pure unisex (`"U"` present and no `"W"`).
  → excludes `["W"]` and `["W","U"]` (the Boost leak); admits `["U"]`, `["M"]`,
  `["M","W"]`, `["M","U"]`, `["M","W","U"]`.
- `W`: symmetric — excludes `["M"]`, `["M","U"]`; admits `["W"]`, `["M","W"]`,
  `["W","U"]`, `["U"]`.

This un-breaks the dangling import at both leak sites at once (L1 pool + Boost
injection) without touching the protected dirty V05 files.

## Files changed
- `utils/gender_scoring.py:84` — new `is_gender_eligible(...)` function (+47 lines,
  additive; existing functions untouched).
- `tests/test_gender_filtering.py:319` — new `TestBoostInjectionGenderGate` class
  (3 tests) pinning the Boost/safety-injection path semantics.

NOT touched: `blueprints/recommendation/engine_v05.py`,
`blueprints/recommendation/engine_v05_layers.py` (pre-existing dirty V05 work —
preserved as-is; they already call the gate correctly).

## Regression test
`tests/test_gender_filtering.py::TestBoostInjectionGenderGate` mirrors the exact
boost-path call shape (`is_gender_eligible(it.gender_tags or [], user_gender)`):
- `test_boost_excludes_women_only_from_menswear` — `[W]` and `[W][U]` → excluded.
- `test_boost_includes_men_items_in_menswear` — `M`, `[m][w]`, pure `[u]` → kept.
- `test_boost_symmetric_for_womenswear` — `M` / `[m][u]` excluded, `W` kept.

## Verification
- `ast.parse` syntax check — PASS on both edited files.
- `from utils.gender_scoring import is_gender_eligible` — OK.
- `import blueprints.recommendation.engine_v05[_layers]` — now imports clean
  (was ImportError before the fix).
- `python -m pytest tests/test_gender_filtering.py -q` → **53 passed in 0.65s**
  (the previously-broken predicate suite + 3 new boost-path tests).
- Did not run the full suite (per instruction — messy junk-drawer checkout).

## API / contract impact
None. No route, payload, or response shape changed → no `API_DOCUMENTATION.md`
update required.

## Notes / unresolved
- The HARD-RULE-protected V05 engine files were already broken-on-import in the
  restored baseline because they referenced this missing function. The fix makes
  them importable again purely by supplying the function they expect — no edits to
  those files. If the orchestrator intends `gender_scoring.py` to stay frozen,
  flag it; but the file is explicitly the place to add the reused predicate and
  this is the minimal way to honor "reuse, don't rewrite."
