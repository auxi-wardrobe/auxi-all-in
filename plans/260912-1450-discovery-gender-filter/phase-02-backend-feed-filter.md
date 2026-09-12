# Phase 02 — Feed filters by the user's persisted wardrobe direction

**Repo:** `auxi-wardrobe/auxi-backend` · **Owner:** backend-dev, then **tech-lead sign-off**
**Effort:** 2h · **Status:** pending · **Blocked by:** 01 · **BLOCKS: phase 06**

## Context

- `repositories/discovery_repository.py::list` — already narrows in SQL by
  `status` / `is_enabled` / `season` and eager-loads items (`selectinload`, the
  N+1 fix from the AU-457 review). Add the gender narrowing here.
- `services/discovery_service.py` — `list_servable`, `get_servable`,
  `list_trend_tags`. Owns the servability + tag filtering.
- `routers/discovery.py` — three GETs, all `Depends(get_current_user)`, shared
  `_READ_LIMITER = SimpleRateLimiter(60)`.
- Gender source: `user.user_metadata["wardrobe_direction"]` — written by
  `routers/v05_onboarding.py`, read the same way as
  `services/admin_user_recommendation_profile.py::_extract_onboarding`.

## Key insights

- `user` is already injected into all three routes by `Depends(get_current_user)`
  — the direction is available with **zero extra query**.
- `user_metadata` is a JSON column and can be `None` on a user who never
  onboarded. `(user.user_metadata or {}).get("wardrobe_direction")` is the only
  safe read. A missing direction yields `None` from
  `allowed_wardrobe_genders`, which means **do not filter** — an un-onboarded
  user sees the full feed rather than an empty one.
- Narrow in SQL, not Python. `season` sets the precedent, the column is indexed,
  and the feed paginates — a Python filter would break `total`.
- `gender IS NULL` must pass the filter (legacy rows are universal — phase 01).

## Requirements

### 1. `repositories/discovery_repository.py`

Import the helper set type and extend `list`:

```python
    def list(
        self,
        status: Optional[str] = None,
        is_enabled: Optional[bool] = None,
        season: Optional[str] = None,
        allowed_genders: Optional[Set[str]] = None,
    ) -> List[DiscoveryOutfit]:
```

Docstring addition:

```
        ``allowed_genders`` is the AU-305 allowed-set from
        ``utils.gender_scoring.allowed_wardrobe_genders`` — pass None to skip
        gender narrowing entirely (no gender context). A row with
        ``gender IS NULL`` always passes: NULL means "every wardrobe" (see
        ``models.discovery.DiscoveryGender``), so legacy outfits curated before
        gender targeting stay servable.
```

Filter clause, right after the `season` clause:

```python
        if allowed_genders is not None:
            query = query.filter(
                sa.or_(
                    DiscoveryOutfit.gender.in_(sorted(allowed_genders)),
                    DiscoveryOutfit.gender.is_(None),
                )
            )
```

Add `import sqlalchemy as sa` and `Set` to the typing import. `sorted()` keeps
the emitted SQL deterministic (stable query plans, stable test assertions).

**Do not** add a `gender` kwarg that takes a raw direction string — the
repository must not know the AU-305 rule.

### 2. `services/discovery_service.py`

```python
from utils.gender_scoring import allowed_wardrobe_genders
```

`list_servable` gains `wardrobe_direction` as the FIRST new kwarg:

```python
    def list_servable(
        self,
        season: Optional[str] = None,
        trend_tag: Optional[str] = None,
        limit: int = 20,
        offset: int = 0,
        wardrobe_direction: Optional[str] = None,
    ) -> Tuple[List[dict], int, Optional[str]]:
```

Body change — one added line plus the widened return:

```python
        allowed = allowed_wardrobe_genders(wardrobe_direction)
        outfits = self.repo.list(
            status=DiscoveryStatus.PUBLISHED,
            is_enabled=True,
            season=season,
            allowed_genders=allowed,
        )
        ...
        return [o.to_card_dict() for o in page], total, resolve_wardrobe_gender(
            wardrobe_direction
        )
```

The third tuple element is the **resolved** `M|W|U` (or `None`) that was actually
applied — the router surfaces it as `applied_gender`. Import
`resolve_wardrobe_gender` alongside the helper.

`list_trend_tags` gains the same kwarg and passes `allowed_genders` through, so
the chip row never offers a tag that yields an empty grid for this user:

```python
    def list_trend_tags(self, wardrobe_direction: Optional[str] = None) -> List[str]:
        outfits = self.repo.list(
            status=DiscoveryStatus.PUBLISHED,
            is_enabled=True,
            allowed_genders=allowed_wardrobe_genders(wardrobe_direction),
        )
```

`get_servable` is **deliberately unchanged** — add this comment above it so the
asymmetry reads as intentional rather than forgotten:

```python
    # NOT gender-filtered, by decision (see plan.md §Decisions). A user who
    # taps a shared link asked for THAT outfit; the gender rule curates the
    # feed, it is not access control. 404-ing an off-gender deep link would
    # break the social-share flow AU-457 was built for.
```

### 3. `routers/discovery.py`

Add one module-level helper (mirrors `_extract_onboarding`'s read):

```python
def _wardrobe_direction(user: User) -> Optional[str]:
    """The user's persisted onboarding direction, or None.

    `user_metadata` is JSON and is None for a user who never completed V05
    onboarding — None flows through `allowed_wardrobe_genders` as "no gender
    context", i.e. show the whole feed. Never read `users.gender`: that column
    is dead (prod holds NULL/MASCULINE/UNISEX/"male") and the engine has keyed
    on the onboarding direction since AU-305.
    """
    return (user.user_metadata or {}).get("wardrobe_direction")
```

`list_outfits` — pass it down, surface what was applied:

```python
    outfits, total, applied_gender = service.list_servable(
        season=season,
        trend_tag=trend_tag,
        limit=limit,
        offset=offset,
        wardrobe_direction=_wardrobe_direction(user),
    )
    return {
        "outfits": outfits,
        "count": len(outfits),
        "total": total,
        "limit": limit,
        "offset": offset,
        "applied_gender": applied_gender,
    }
```

`get_trend_tags`:

```python
    return {"tags": service.list_trend_tags(_wardrobe_direction(user))}
```

`applied_gender` is `"M"|"W"|"U"|null` — `null` meaning "no direction on file,
feed unfiltered". It is additive, so no existing client breaks.

## Related code files

- MODIFY `repositories/discovery_repository.py`
- MODIFY `services/discovery_service.py`
- MODIFY `routers/discovery.py`

## Implementation steps

1. Repository: typing imports, `allowed_genders` kwarg, the `or_` clause.
2. Service: imports, the two kwargs, the widened `list_servable` return, the
   `get_servable` intent comment.
3. Router: `_wardrobe_direction`, wire both routes, add `applied_gender`.
4. `grep -rn "list_servable\|list_trend_tags" --include=*.py .` — confirm no
   other caller needs updating (AU-457 shipped only the one router).
5. Start the app and verify the OpenAPI still generates:
   `uvicorn app:app --port 5099` then `curl -s localhost:5099/openapi.json | head -c 200`.
6. `python -m pytest tests/test_discovery_public_router.py -x` (existing AU-457
   tests must still pass — they assert the old envelope keys, which are
   unchanged; only a new key is added).

## Todo

- [ ] Repository narrows by `gender IN (...) OR gender IS NULL`
- [ ] Service threads `wardrobe_direction` → `allowed_wardrobe_genders`
- [ ] `list_trend_tags` filtered too
- [ ] `get_servable` left unfiltered WITH the intent comment
- [ ] Router reads `user_metadata` defensively, returns `applied_gender`
- [ ] No other caller of the two service methods
- [ ] Existing AU-457 public-API tests still green
- [ ] **tech-lead contract sign-off recorded** (blocks phase 06)

## Success criteria

- A user with `wardrobe_direction="Menswear"` gets only `gender in {"M", NULL}`
  outfits; `"Womenswear"` only `{"W", NULL}`; `"Mixed"` gets all.
- A user with no `user_metadata` gets the unfiltered feed and
  `applied_gender: null`.
- `total` reflects the gender-filtered set (pagination stays correct).
- `GET /api/discovery/outfits/{id}` still resolves an off-gender outfit.
- One SQL query per feed request (the `selectinload` eager-load is not
  regressed — check the echoed SQL count, this was an AU-457 review finding).

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| `user_metadata` is None → `AttributeError` 500 on the whole feed | **H**×H | `(user.user_metadata or {})` — the single most likely bug in this phase; phase 04 tests a metadata-less user explicitly |
| Dirty direction value in metadata (e.g. `"male"`, as `users.gender` holds) | M×M | `resolve_wardrobe_gender` returns None for anything unmapped → no filter → full feed. Degrades open, never to empty |
| Filtering in Python instead of SQL → wrong `total` | L×H | Narrowing is in the repo query, before pagination; success criteria asserts `total` |
| Someone later "fixes" the detail route to filter too | M×M | The intent comment on `get_servable` states the decision and its reason |

## Security

- No new user input: the direction comes from the authenticated user's own
  persisted metadata, never from a query param — so a user cannot widen their own
  feed, and there is nothing new to validate or escape.
- No IDOR surface: `applied_gender` echoes only the caller's own direction.
- Rate limiting unchanged (shared 60/min read limiter).
- The filter is **not** a security boundary — it is curation. Off-gender outfits
  remain reachable by id, by decision. Do not document it as access control.

## Next steps

Tech-lead signs off the `applied_gender` envelope change in
`API_DOCUMENTATION.md` (written in phase 03) → unblocks phase 06.
