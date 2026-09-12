# Phase 03 — Admin API accepts `gender` + publish gate + API doc

**Repo:** `auxi-wardrobe/auxi-backend` · **Owner:** backend-dev · **Effort:** 1.5h
**Status:** pending · **Blocked by:** 01 · **BLOCKS: phase 05**

## Context

- `routers/admin/discovery_outfits.py` — admin CRUD. Note its existing
  constraint-alias idiom (`_Title`, `_Season`, `_TrendTag`) and the
  `Optional[Literal[...]]` pattern `_Season` already uses for a closed,
  nullable enum. `gender` is the same shape.
- `services/discovery_admin_service.py` — `validate_item_ids`,
  `find_duplicate_item_ids`, `assert_publishable`, `normalize_tags`.
- `assert_publishable` is already a **hard 422 gate**, not a warning, with the
  stated reason: "an unservable published outfit is a user-visible 404 from a
  social deep link". Requiring `gender` at publish belongs there.
- Contract rule: `wardrobe-backend/CLAUDE.md` §Rules — `API_DOCUMENTATION.md`
  update is MANDATORY. Section to extend: `## Discovery (AU-457)`.

## Key insights

- The `PUT` body's existing comment explains the `None`-default convention
  precisely: a non-`Optional` type with a `None` default means "omitting drops
  the key (`exclude_unset`), sending explicit `null` is a 422". `gender` must be
  **`Optional`** so an admin CAN clear it back to universal — matching `season`
  and `composite_image_url`, not `title`.
- Create leaves `gender=None` allowed (a DRAFT may be untagged); the gate fires
  only on the DRAFT→PUBLISHED transition. That is what lets legacy rows stay
  published while blocking any NEW untagged publish.
- `repo.create(**fields)` and `repo.update(**fields)` pass through `setattr`, so
  no repository change is needed for the new column.

## Requirements

### 1. `services/discovery_admin_service.py`

Import the enum and extend the gate:

```python
from models.discovery import DiscoveryGender, DiscoveryOutfit
```

Append to `assert_publishable`, after the item-count checks:

```python
        # Gender targeting (2026-09-12): a PUBLISHED outfit must declare which
        # wardrobe it targets. NULL means "every wardrobe" — valid for the rows
        # that predate this column, but never for a new publish, or the feed
        # silently un-targets itself one outfit at a time.
        if outfit.gender not in DiscoveryGender.ALL:
            raise ValueError(
                "Cannot publish an outfit without a wardrobe gender "
                f"({'/'.join(DiscoveryGender.ALL)})"
            )
```

`outfit.gender not in ALL` covers both `None` and any junk value in one check.

### 2. `routers/admin/discovery_outfits.py`

Constraint alias, next to `_Season`:

```python
_Gender = Optional[Literal["M", "W", "U"]]
```

- `DiscoveryOutfitCreateRequest`: add `gender: _Gender = None` after `season`.
- `DiscoveryOutfitUpdateRequest`: add `gender: _Gender = None` after `season`
  (`Optional` → an explicit `null` clears it back to universal).
- `create_outfit` → add `gender=payload.gender,` to the `repo.create(...)` call.
- `update_outfit` → no change; `model_dump(exclude_unset=True)` already carries
  it through.
- `transition_outfit` → no change; it already calls `assert_publishable` on a
  PUBLISHED transition, which now enforces the gender.

Add a coverage endpoint — the admin SPA needs it for the blackout warning
(phase 05), and deriving it client-side from a status-filtered list would be
wrong once the list paginates:

```python
@router.get("/gender-coverage")
async def gender_coverage(
    admin: User = Depends(get_current_admin),
) -> Dict[str, Any]:
    """PUBLISHED+enabled servable outfit counts per wardrobe gender.

    Strict gender targeting means a gender with zero servable outfits gets an
    EMPTY Discovery feed for every user in that cohort — silently. The admin
    SPA surfaces this as a warning; `untagged` counts legacy rows that are
    still visible to everyone.
    """
    with get_db_context() as db:
        repo = DiscoveryRepository(db)
        outfits = [
            o
            for o in repo.list(status=DiscoveryStatus.PUBLISHED, is_enabled=True)
            if o.is_servable()
        ]
        counts = {g: 0 for g in DiscoveryGender.ALL}
        untagged = 0
        for outfit in outfits:
            if outfit.gender in counts:
                counts[outfit.gender] += 1
            else:
                untagged += 1
        return {
            "counts": counts,
            "untagged": untagged,
            # A cohort's feed is non-empty if its own bucket OR the universal
            # (untagged) bucket has anything — mirrors the phase-02 SQL
            # `gender IN (...) OR gender IS NULL`.
            "empty_cohorts": [
                g for g, n in counts.items() if n == 0 and untagged == 0
            ],
        }
```

Route ordering matters: declare `/gender-coverage` **above** `@router.get("/{outfit_id}")`,
or FastAPI matches it as an outfit id and 404s. Import `DiscoveryGender` and
`DiscoveryStatus` from `models.discovery`.

### 3. `API_DOCUMENTATION.md` — MANDATORY

In `## Discovery (AU-457)`:

- `GET /api/discovery/outfits`: document `applied_gender` in the response
  (`"M"|"W"|"U"|null`) and add a **Gender targeting** note — filtered from the
  caller's `user_metadata.wardrobe_direction` via the AU-305 rule
  (`Menswear`→`M` only, `Womenswear`→`W` only, `Mixed`→all, no direction→all);
  `gender: null` outfits are visible to everyone; there is **no** client
  parameter and the client cannot override it.
- Card DTO: add `"gender": "M"|"W"|"U"|null`.
- `GET /api/discovery/outfits/{id}`: state explicitly that it is **not**
  gender-filtered, and why (deep links must resolve).
- `GET /api/discovery/trend-tags`: state that it IS gender-filtered.
- Admin section: `gender` on create/update; the new 422 on publishing without
  one; the new `GET /api/admin/discovery-outfits/gender-coverage`.

## Related code files

- MODIFY `services/discovery_admin_service.py`
- MODIFY `routers/admin/discovery_outfits.py`
- MODIFY `API_DOCUMENTATION.md`

## Implementation steps

1. Publish gate in the admin service.
2. `_Gender` alias + both request models + `create_outfit` kwarg.
3. `/gender-coverage`, declared before `/{outfit_id}`.
4. `API_DOCUMENTATION.md` — all six bullets above.
5. `uvicorn app:app --port 5099` → confirm in `/openapi.json` that
   `/api/admin/discovery-outfits/gender-coverage` is registered and that the
   create/update schemas show the `M|W|U` enum.
6. Manual check that the gate fires: PATCH `{"status":"PUBLISHED"}` on a
   gender-less DRAFT → expect 422, not 200.

## Todo

- [ ] `assert_publishable` rejects a gender-less publish
- [ ] `_Gender` alias; create + update accept it; `create_outfit` persists it
- [ ] `/gender-coverage` declared ABOVE `/{outfit_id}`
- [ ] `API_DOCUMENTATION.md` updated (all six bullets)
- [ ] OpenAPI shows the new route + the enum
- [ ] 422 verified by hand on a gender-less publish

## Success criteria

- Create a DRAFT with `gender: "M"` → 201, `to_admin_dict()` echoes it.
- PATCH a gender-less DRAFT to PUBLISHED → **422** naming the missing gender.
- PUT `{"gender": null}` on a PUBLISHED outfit → 200, clears to universal
  (deliberately allowed — that is the kill-switch in plan.md §Release order).
- `GET /gender-coverage` on a board with 2 `M` + 0 `W` + 0 untagged returns
  `empty_cohorts: ["W", "U"]`.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| `/gender-coverage` declared after `/{outfit_id}` → shadowed, returns 404 | **H**×M | Called out in the requirement AND the todo; success criteria exercises it |
| Publish gate blocks the CEO re-publishing a legacy outfit | M×M | Intended — it forces classification. The SPA disables the button with a tooltip (phase 05) rather than letting the 422 surface raw |
| `gender: null` on update mistaken for "leave unchanged" | M×M | Matches the existing `season` semantics documented in the PUT model's own docstring; phase 04 tests both clear-to-null and omit |
| Admin ships a `W`-only batch and blanks Menswear's feed | M×**H** | `/gender-coverage` + the phase-05 warning + the phase-06 `discovery_feed_empty` event |

## Security

- Every route stays behind `Depends(get_current_admin)`; no new public surface.
- `gender` is a closed `Literal` — a bad value is a 422 at the Pydantic layer,
  never a DB write, so the enum cannot be poisoned even though there is no CHECK
  constraint (the deliberate SQLite/Postgres-parity choice inherited from
  `season`/`status`).
- `/gender-coverage` returns aggregate counts only — no user data, no PII.

## Next steps

Unblocks phase 05 (admin SPA). Phase 04 needs both this and phase 02.
