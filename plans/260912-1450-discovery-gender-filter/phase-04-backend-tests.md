# Phase 04 — Backend tests

**Repo:** `auxi-wardrobe/auxi-backend` · **Owner:** tester · **Effort:** 1.5h
**Status:** pending · **Blocked by:** 02, 03

## Context

AU-457 shipped five discovery test files — extend them, don't duplicate:

| File | Owns |
|---|---|
| `tests/test_discovery_model.py` | `is_servable`, `live_items`, the DTOs |
| `tests/test_discovery_repository.py` | `list` narrowing, `replace_items`, cascade |
| `tests/test_discovery_admin_service.py` | `assert_publishable`, `normalize_tags`, item validation |
| `tests/test_discovery_admin_router.py` | admin CRUD HTTP |
| `tests/test_discovery_public_router.py` | public HTTP envelopes, 404 collapse |

Plus ONE new file for the rule itself:
`tests/test_discovery_gender_filter.py`.

Harness is SQLite (see `models/discovery.py` header) — no Postgres-only types,
and `ondelete=CASCADE` is not enforced unless `PRAGMA foreign_keys` is on (the
repo deletes children app-side for exactly this reason).

## Requirements

### New: `tests/test_discovery_gender_filter.py`

**A. The rule helper** (`utils/gender_scoring.allowed_wardrobe_genders`)

- `"Menswear"` / `"MASCULINE"` / `"M"` / `"men"` → `{"M"}` (all four spellings
  route through `_PREF_TO_WARDROBE_GENDER`)
- `"Womenswear"` → `{"W"}`
- `"Mixed"` / `"UNISEX"` / `"U"` → `{"M","W","U"}`
- `None` / `""` / `"male"` / `"garbage"` → `None` (**degrade open, never to an
  empty set** — an empty set would blank the feed; `"male"` is the real dirty
  value sitting in prod's `users.gender` today)

**B. Anti-drift property test** — the whole reason two projections exist:

```python
@pytest.mark.parametrize("direction", [
    "Menswear", "Womenswear", "Mixed", "MASCULINE", "FEMININE", "UNISEX",
])
@pytest.mark.parametrize("code", ["M", "W", "U"])
def test_allowed_set_agrees_with_au305_predicate(direction, code):
    """allowed_wardrobe_genders is the SQL-shaped projection of
    is_item_visible_to_wardrobe. For a single-gender row the two MUST agree,
    or the Discovery feed and the V05 engine disagree about the same user.
    """
    allowed = allowed_wardrobe_genders(direction)
    assert (code in allowed) == is_item_visible_to_wardrobe([code], direction)
```

**C. Feed filtering, end to end** — fixture: one servable PUBLISHED outfit per
gender (`M`, `W`, `U`) plus one with `gender=None`.

| User | Sees | `applied_gender` |
|---|---|---|
| `user_metadata={"wardrobe_direction":"Menswear"}` | `M`, `None` | `"M"` |
| `"Womenswear"` | `W`, `None` | `"W"` |
| `"Mixed"` | all four | `"U"` |
| `user_metadata={}` (onboarded, no direction) | all four | `None` |
| `user_metadata=None` (**never onboarded**) | all four | `None` |
| `user_metadata={"wardrobe_direction":"male"}` (dirty) | all four | `None` |

The `user_metadata=None` row is the regression test for the highest-likelihood
bug in phase 02 (`AttributeError` → 500 on the entire feed). It must assert
**200**, not just a non-empty list.

**D. Pagination correctness** — 3 `M` + 3 `W` outfits, Menswear user,
`limit=2&offset=0`: `total == 3` (not 6) and `count == 2`. Proves the narrowing
happens in SQL before pagination.

**E. NULL-is-universal regression** — the migration-safety test. A PUBLISHED,
enabled, `gender=None` outfit with ≥1 live item appears for a Menswear user, a
Womenswear user AND a Mixed user. If this ever fails, shipping blanks the live
feed.

**F. Trend tags are filtered** — a tag that exists only on a `W` outfit is
absent from `GET /api/discovery/trend-tags` for a Menswear user.

**G. Detail is NOT filtered** (asserts the decision, so a later "fix" breaks a
test instead of the product) — a Menswear user `GET`s a `W` outfit by id →
**200**, not 404.

### Extend existing files

- `test_discovery_model.py` — `to_card_dict()`/`to_admin_dict()` carry `gender`;
  `gender=None` does not affect `is_servable()`.
- `test_discovery_admin_service.py` — `assert_publishable` raises for
  `gender=None` and for `gender="X"`; passes for each of `M`/`W`/`U`.
- `test_discovery_admin_router.py` — create with `gender:"M"` → 201 echoing it;
  PATCH a gender-less DRAFT → PUBLISHED → **422**; PUT `{"gender": null}` → 200
  and cleared; `GET /gender-coverage` returns the right counts, `untagged`, and
  `empty_cohorts` (include a case where `untagged > 0` suppresses
  `empty_cohorts`).
- `test_discovery_repository.py` — `list(allowed_genders={"M"})` returns `M` +
  `None` rows only; `list(allowed_genders=None)` returns everything.

## Implementation steps

1. Read `tests/conftest.py` for the existing session/auth fixtures — reuse them;
   do not hand-roll a new app client.
2. Find how existing discovery tests build an authenticated user and extend that
   fixture with a `user_metadata` parameter rather than creating users inline.
3. Write the new file, then the five extensions.
4. `python -m pytest tests/test_discovery_gender_filter.py -v`
5. `python -m pytest tests/ -k discovery -v` — all six files green.
6. `python -m pytest tests/ -x -q` — full suite, no regressions. In particular
   `tests/test_v05_onboarding_service.py` and any `test_gender_filtering.py`
   must stay green: phase 01 touched `utils/gender_scoring.py`, which the V05
   engine shares. A red test there means the shared rule was altered, not
   extended — revert and add, don't modify.
7. `python test_server.py` (full e2e on :5002, the umbrella gate).

## Todo

- [ ] `tests/test_discovery_gender_filter.py` covering A–G
- [ ] Anti-drift property test green
- [ ] `user_metadata=None` returns 200
- [ ] Pagination `total` correct under filtering
- [ ] NULL-is-universal regression green
- [ ] Five existing discovery files extended
- [ ] Full suite green, V05 onboarding/gender tests untouched-and-green
- [ ] `python test_server.py` green

## Success criteria

All of A–G pass; `pytest tests/ -q` has no new failures; `test_server.py` green.
No test is skipped, xfailed, or marked flaky to get there — per
`.claude/rules/development-rules.md`, a failing test gets fixed, never silenced.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| Shared `gender_scoring` change silently breaks V05 onboarding | M×H | Step 6 runs those suites explicitly; the new function is purely additive |
| Tests assert on fixture insertion order instead of the filter | M×M | Assert on outfit **ids/genders**, never on list position — the feed orders by `sort_order, created_at DESC` |
| SQLite/Postgres divergence on `IN (...) OR IS NULL` | L×M | Plain SQL, no JSON operators — that was the whole point of a scalar column over `gender_tags` |

## Next steps

Green suite → phase 07 verification.
