# Backend support for wardrobe tile tags (PR #148) — first-class `usage_frequency`

**Date:** 2026-06-26
**Frontend PR:** auxi-wardrobe/auxi-mobile #148 — "Add tile status tags (new/less use/common) to wardrobe grid" (branch `claude/inspiring-hamilton-v01och`, OPEN)
**Repo for this work:** `wardrobe-backend/` → dispatch to `backend-dev`; contract sign-off → `tech-lead`
**Status:** Planned, not started

---

## 1. Context — what the frontend already ships

PR #148 renders one status pill per wardrobe grid tile with precedence **new > less use > common**:

| Tag | Backend dependency | Today |
|---|---|---|
| **new** | none — local AsyncStorage per-user (`WardrobeViewedContext`) | ✅ no backend work |
| **common** | `is_common_item` | ✅ already served (`models/wardrobe.py:32`, `to_dict` :98) |
| **less use** | `usage_frequency === 'LESS_USED'` (else style-tag `less-used`) | ⚠️ **field missing** |

Frontend contract (already merged in `auxi/src/services/wardrobeService.ts`):
- Type: `usage_frequency?: 'NORMAL' | 'LESS_USED'` on `WardrobeItem` (`:17`,`:50`).
- Read: `getItemUsageFrequency()` (`:198`) returns `LESS_USED` if `usage_frequency === 'LESS_USED'`, **else falls back** to `style_tags.includes('less-used')`.
- Write: `updateUsageFrequency()` (`:419`) `PATCH /wardrobe/items/{id}/usage-frequency` body `{usage_frequency}`, **on 404/405 falls back** to writing the `less-used` style tag via `POST /wardrobe/items/{id}/attributes`.
- Response unwrap: `getSingleItem()` (`:90`) = `payload.item || payload.wardrobe_item || payload`.

## 2. Current backend reality (why "less use" "works" but isn't right)

- **No `usage_frequency` column** on `WardrobeItem`. The dedicated `PATCH .../usage-frequency` route **does not exist** → every demote/promote eats a wasted 404 → frontend silently falls back to the `less-used` **style tag**.
- The fallback **does persist**: `POST /items/{id}/attributes` (`routers/wardrobe.py:139`) whitelists `style_tags` (schema `:43`, repo `updatable_fields` `repositories/wardrobe_repository.py:145`), and `to_dict()` returns `style_tags`. So the pill **displays correctly today** for user-owned items (uploads + `USR_` clones; raw SYSTEM items have `user_id=None` and can't be demoted — correct, you only demote items in your own wardrobe).
- **Demotion has zero semantic effect**: the only `LESS_USED` references in the backend are two *comments* (`services/wardrobe_service.py:182,206`); the V05 engine never reads the tag. "Less use" is currently a **display-only label**.

## 3. Decisions (CEO, 2026-06-26)

1. **Storage:** make `usage_frequency` a **first-class field + dedicated endpoint**, and **dual-write** the legacy `less-used` style tag for back-compat.
2. **Effect:** **display-only for now** — no V05 recommendation-engine changes this round (down-ranking is a deferred follow-up, see §8).

## 4. Design

### 4.1 Critical invariant — dual-write keeps field & tag in sync
Because the frontend read path *falls through* to `style_tags` whenever `usage_frequency !== 'LESS_USED'`, the new endpoint **must** keep both in sync or promotion will appear to fail:

- `LESS_USED` → set `usage_frequency='LESS_USED'` **and** ensure `'less-used'` ∈ `style_tags`.
- `NORMAL`   → set `usage_frequency='NORMAL'`   **and** **remove** `'less-used'` from `style_tags`.

(The frontend's own fallback already does this via `replaceTag`; the dedicated endpoint bypasses that path, so the backend owns the sync.)

### 4.2 File-by-file changes (all in `wardrobe-backend/`)

**`models/wardrobe.py`**
- Add column: `usage_frequency = db.Column(db.String(20), nullable=True, default='NORMAL')` (String, matching the model's convention; no index — display-only, YAGNI).
- In `to_dict()` base dict: `'usage_frequency': self.usage_frequency or 'NORMAL'` (always present, NULL→NORMAL).

**`migrations/versions/<rev>_add_usage_frequency_to_wardrobe.py`** (new)
- `down_revision` = **current alembic head** — resolve via the revision graph (`alembic heads` from a properly-configured shell, or trace `down_revision` chain; do NOT guess).
- `op.batch_alter_table('wardrobe_items')` → `add_column(sa.Column('usage_frequency', sa.String(20), nullable=True, server_default='NORMAL'))` (batch_op = SQLite-safe; prod = Postgres on Railway).
- **Best-effort backfill** (not required for correctness — frontend fallback covers misses): `UPDATE wardrobe_items SET usage_frequency='LESS_USED' WHERE style_tags::text LIKE '%less-used%'`. Guard for dialect; skip silently on SQLite if cast unsupported.
- `downgrade()`: `batch_op.drop_column('usage_frequency')`.

**`repositories/wardrobe_repository.py`**
- Add `'usage_frequency'` to `updatable_fields` (`:142-147`) so it persists through the existing update path (reuses `user_edits` tracking — DRY).

**`services/wardrobe_service.py`**
- New method `set_usage_frequency(item_id, user_id, usage_frequency)`:
  1. fetch item (ownership = `id` + `user_id`, mirrors existing logic).
  2. compute synced `style_tags` (add/remove `'less-used'`).
  3. call `wardrobe_repo.update_item_attributes(item_id, user_id, {'usage_frequency': X, 'style_tags': synced})`.
  4. return `to_dict()` or `None` (not found / not owned).

**`routers/wardrobe.py`**
- Request model: `class UpdateUsageFrequencyRequest(BaseModel): usage_frequency: Literal['NORMAL','LESS_USED']` (invalid value → 422 automatically).
- Endpoint `@router.patch("/items/{item_id}/usage-frequency")`, `Depends(get_current_user)`:
  - `None` from service → `404` `{"error":"Item not found or access denied", "request_id": ...}` (same shape as `/attributes`).
  - success → `{"message": "Usage frequency updated", "item": updated_item}` (envelope `getSingleItem` unwraps).
  - mirror the try/except + `request_id` pattern of `update_item_attributes`.

**`API_DOCUMENTATION.md`** (MANDATORY per backend rule)
- Document `PATCH /wardrobe/items/{item_id}/usage-frequency`: auth, request body, 200/404/422, example. Note `usage_frequency` now in every wardrobe item response.

### 4.3 Tests (`tests/`)
- demote → `usage_frequency=='LESS_USED'` **and** `'less-used'` ∈ `style_tags`.
- promote → `'NORMAL'` **and** `'less-used'` removed.
- another user's item → 404; non-existent item → 404.
- invalid enum → 422.
- `to_dict()` / `GET /items` includes `usage_frequency` (defaults `'NORMAL'` for untouched rows).
- Gate: `pytest -m "unit or integration"` + `python test_server.py` green.

## 5. Phases & todos

**Phase 1 — schema**
- [ ] Add `usage_frequency` column + `to_dict` (`models/wardrobe.py`)
- [ ] Migration (resolve real head; backfill best-effort); `alembic upgrade head` locally

**Phase 2 — write path**
- [ ] `'usage_frequency'` → repo `updatable_fields`
- [ ] `set_usage_frequency` service method (with style-tag sync)
- [ ] `PATCH /items/{id}/usage-frequency` route + request model

**Phase 3 — verify & document**
- [ ] Tests (Phase 4.3) green; `python test_server.py` green
- [ ] `API_DOCUMENTATION.md` updated
- [ ] `tech-lead` contract sign-off (umbrella two-repo contract)

**Phase 4 — integration / deploy**
- [ ] Run backend on :5001, real device/sim against PR #148 — confirm dedicated endpoint hit (no 404 in logs), demote/promote round-trips, pill flips correctly
- [ ] `devops`: Railway deploy runs the migration (Postgres)
- [ ] No mobile code change — frontend already speaks this contract; fallback simply stops firing

## 6. Success criteria
- `PATCH /wardrobe/items/{id}/usage-frequency` returns 200 with `usage_frequency` reflected; field present on all item reads.
- Demote/promote keeps field ↔ `less-used` tag in sync (no stale tag re-shows the pill after promote).
- Frontend "less use" pill driven by the first-class field, fallback path no longer triggered (no 404).
- Pre-existing style-tag-only demoted items still render correctly (fallback intact during/after rollout).

## 7. Risks
- **Sync bug** = promote appears to fail (stale `less-used` tag wins via fallback). Mitigated by §4.1 + explicit promote test.
- **Migration dialect**: Postgres prod vs SQLite dev — use `batch_alter_table`; keep backfill dialect-guarded.
- **Head collision**: confirm real `down_revision`; a second migration branch breaks `alembic upgrade`.

## 8. Out of scope (deferred follow-ups)
- **V05 engine down-ranking of `LESS_USED`** (the deferred "demotion effect" option) — separate ticket; needs eval (`/v05-eval`).
- **Item-level favorite** (`is_favorited`) is the *identical* gap (frontend `toggleFavorite` → `PATCH /items/{id}/favorite` → 404 → `favorite` style-tag fallback; no column, no route). Not part of PR #148's tags — flag to PM as a sibling cleanup if desired; not bundled here.

## Unresolved questions
- Linked Linear/GH issue id for PR #148 (none surfaced) — confirm with PM for traceability.
- Confirm the real current alembic head before authoring the migration.
