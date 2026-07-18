# Capsule Wardrobe — Frozen Spec & API Contract

> Single source of truth for the Capsule Wardrobe feature across `auxi-backend`
> (FastAPI) and `auxi-mobile` (RN). Both sides implement to THIS contract — do
> not drift. Repos live at `/workspace/auxi-backend` and `/workspace/auxi-mobile`
> (the umbrella submodules are stale/empty). Branch in every repo:
> `claude/capsule-wardrobe-creation-fyhrsm`.

## 1. Goal

Users create a curated subset of their wardrobe (a "capsule") for work / travel /
season, get AI-generated outfits inside it, and manage items/outfits — while
existing wardrobe items and saved outfits are always preserved.

## 2. Data model (backend)

All ids are `String(36)` UUIDs; timestamps `DateTime` UTC. Mirror the
`models/favorite.py` + `migrations/versions/ea7fe40cbb25_add_favorites_table.py`
patterns (Flask-SQLAlchemy `db.Model`, `db.Table` M2M, `batch_alter_table`,
`sqlite.JSON()`).

### `capsules`
| col | type | notes |
|---|---|---|
| id | String(36) PK | uuid |
| user_id | String(36) FK users.id, indexed, not null | owner |
| name | String(120) not null | |
| temp_min | Integer nullable | °C, requirement |
| temp_max | Integer nullable | °C |
| formalness_level | Integer nullable | 1–10 |
| outfit_target | Integer nullable | requested outfit count |
| shoe_limit | Integer nullable | max distinct shoes |
| status | String(32) not null default 'draft' | see states |
| missing_categories | JSON default [] | populated on success_with_gaps |
| created_at / updated_at | DateTime | |

**status states**: `generating` → `success` \| `success_with_gaps` \| `failed`.
`draft` exists ONLY as the column default and is **never persisted** — `create_capsule`
constructs the row directly in `generating` (shipped: `capsule_service.create_capsule`,
`status='generating'`), so the server never observes a `draft` row. The "draft" of the
create wizard (name entered, not yet submitted) is **client-side only** — the mobile app
holds it in navigation state and no row exists until Create. The default is kept for
schema clarity; treat `draft` as client-vocabulary, not a server lifecycle state.

### `capsule_items` (M2M capsule ↔ wardrobe_items)
`capsule_id` FK capsules.id, `wardrobe_item_id` FK wardrobe_items.id, PK(both).
Relationship on `Capsule.items` (`secondary=capsule_items`, `lazy='subquery'`).
An item may belong to multiple capsules (product decision: supported).

### `capsule_outfits`
| col | type | notes |
|---|---|---|
| id | String(36) PK | |
| capsule_id | String(36) FK capsules.id, indexed | cascade-delete with capsule |
| outfit_hash | String(64) | dedup/identity — see note |
| styling_note | Text nullable | |
| created_at | DateTime | |

**`outfit_hash` — width vs value (deliberate).** The value is the **first 12 hex
chars of `sha256(sorted item-id list)`** (48 bits) — that is the identity/dedup
key, and BOTH sides must derive it identically (sha256, sort item ids, take
`[:12]`). The `String(64)` column is only headroom for a full digest; do NOT
store the full 64 on one side and 12 on the other. 48 bits is ample for
per-capsule dedup (a capsule holds tens of outfits, not millions); collision risk
is negligible at this scope. Shipped: `capsule_generation_service.outfit_hash()`.

### `capsule_outfit_items` (M2M capsule_outfits ↔ wardrobe_items)
`capsule_outfit_id` FK, `wardrobe_item_id` FK, PK(both). Lets us count
"outfits using item X" and regenerate. Relationship `CapsuleOutfit.items`.

**Deletion**: deleting a capsule deletes its `capsule_outfits` (+ join rows) and
`capsule_items` join rows, but NEVER deletes `wardrobe_items` or `favorites`.

## 3. Generation algorithm (`services/capsule_generation_service.py`)

Deterministic, rule-based (no external LLM — mirrors the rule-based V05 engine;
keeps it testable). Input: capsule constraints + the user's wardrobe items (the
capsule's item pool = its `capsule_items`, or on first generation the selected
seed set; if empty pool, use all non-deleted wardrobe items filtered by
constraints). Output: up to `outfit_target` outfits + `missing_categories`.

Rules:
1. Filter pool by `formalness_level` tolerance (±2 of item `formality_level` when
   present; items lacking formality pass).
2. Bucket by `category_family`: OUTER, TOP, BOTTOM, FULL_BODY, FOOTWEAR, ACCESSORY.
3. An outfit = (TOP + BOTTOM + FOOTWEAR) or (FULL_BODY + FOOTWEAR), optionally
   + OUTER when `temp_min` is low (< 15°C) and outer exists, optionally + 1 ACCESSORY.
4. Respect `shoe_limit`: use at most `shoe_limit` distinct FOOTWEAR items across
   the capsule's outfits (round-robin).
5. Generate distinct combos (dedup by `outfit_hash`) until `outfit_target` reached
   or combinations exhausted.
6. `missing_categories`: human-readable gaps that blocked reaching the target —
   e.g. "Formal shoes", "Additional trousers", "Lightweight outerwear". If
   `len(outfits) < outfit_target` → status `success_with_gaps`, else `success`.
7. `outfit_hash` = first 12 chars of sha256 over sorted item-id list.

Regeneration (add/remove items) recomputes outfits from the current pool but
**preserves** existing outfits whose items still all belong to the pool; only
adds NEW distinct outfits (spec: "Preserve existing outfits", "Generate
additional outfit combinations"). Returns count of newly created outfits.

## 4. API contract (all under `/api`, all `Depends(get_current_user)`)

Rate limits: writes 20/60s, reads 60/60s, generate uses the processing bucket
(20/60s) + `enforce_ai_daily_limit` is NOT required (rule-based, cheap). Errors
follow the repo convention: `HTTPException(status, detail={"error","message","request_id"})`.
404 for not-found-or-not-owned (no ownership leak).

### Shapes
```
CapsuleSummary   = { id, name, status, item_count, outfit_count, created_at }
Requirements     = { temp_min, temp_max, formalness_level, outfit_target, shoe_limit }
CategoryGroups   = { outer, top, bottom, footwear, accessory }        # ints
CapsuleSummaryBlock = { outer_count, top_count, bottom_count, shoe_count,
                        accessory_count, weather_range, formalness_score } # for expandable summary
CapsuleOutfitDTO = { id, outfit_hash, styling_note, item_ids:[...], items:[WardrobeItem] }
CapsuleFull      = CapsuleSummary + { requirements, category_groups, summary:CapsuleSummaryBlock,
                        items:[WardrobeItem], outfits:[CapsuleOutfitDTO], missing_categories:[...] }
```
`WardrobeItem` = the existing `WardrobeItem.to_dict()` shape (already used by the app).

### Endpoints
| Method | Path | Body | Success | Notes |
|---|---|---|---|---|
| POST | `/api/capsules` | `{name, temp_min?, temp_max?, formalness_level?, outfit_target?, shoe_limit?, item_ids?[]}` | 201 `CapsuleFull` | creates row (generating) → generates synchronously → returns final (success / success_with_gaps / failed). `item_ids` optional seed pool; if omitted, generator draws from full wardrobe by constraints. |
| GET | `/api/capsules` | — | 200 `{capsules:[CapsuleSummary]}` | user-scoped, newest first |
| GET | `/api/capsules/{id}` | — | 200 `CapsuleFull` | 404 if not owned |
| DELETE | `/api/capsules/{id}` | — | 200 `{deleted:true}` | preserves items/outfits/favorites |
| POST | `/api/capsules/{id}/generate/retry` | — | 200 `CapsuleFull` | only when status `failed`; re-runs generation |
| POST | `/api/capsules/{id}/items` | `{item_ids:[...]}` | 200 `{items_added, already_existed, new_outfits, capsule:CapsuleFull}` | add wardrobe items; dedup; regenerate additional outfits |
| POST | `/api/capsules/{id}/items/from-outfits` | `{outfit_source:'favourites'\|'creations', outfit_ids:[...]}` | 200 `{items_added, already_existed, new_outfits, capsule:CapsuleFull}` | extract items from selected saved outfits (favorites/creations), dedup, add unique, regenerate. If all items already present → items_added=0, new_outfits=0. |
| DELETE | `/api/capsules/{id}/items/{itemId}` | — | 200 `{removed:true, capsule:CapsuleFull}` | remove item from capsule; drop outfits that used it; regenerate suggestions. Preserves saved outfits (favorites). |
| POST | `/api/capsules/{id}/items/{itemId}/change` | `{replacement_item_id, scope:'outfit'\|'all', outfit_id?}` | 200 `CapsuleFull` | swap item. scope=outfit needs outfit_id (that outfit only); scope=all → every capsule outfit using item. Adds replacement to capsule pool if absent. |

**Concurrency / risk mitigations** (spec high-risk list):
- All mutations are transactional; on error `db.rollback()` + 500 with request_id
  (→ "Roll back incomplete updates").
- Item/outfit counts derived from live joins, never cached separately
  (→ "counts consistent after partial updates").
- Swap scope explicit (`outfit` vs `all`) (→ "Swap updates unintended outfits").
- Add-items dedups against existing `capsule_items` (→ "Duplicate prevention").

## 5. Mobile surface (`auxi-mobile`)

### Routes (add to `src/types/navigation.ts` `AppStackParamList` + register in `src/navigation/AppNavigator.tsx`)
- `CapsuleWardrobe: undefined` — list + empty state; `+` → CapsuleCreate.
- `CapsuleCreate: undefined` — Step 1 name entry (Continue → CapsuleInfo step).
- `CapsuleInfo: { name: string }` — Step 2 requirements; Create → generating.
- `CapsuleGenerating: { name, temp_min, temp_max, formalness_level, outfit_target, shoe_limit, item_ids? }` — runs create mutation, progress UI, "Leave — notify me when ready".
- `CapsuleDetail: { capsuleId: string }` — full detail, summary expand, add/delete.
- `CapsuleItemDetail: { capsuleId: string, itemId: string }` — item detail, change/remove.

(Create wizard may be one screen with internal steps instead of 3 routes — impl
choice — but the state transitions and copy below are mandatory.)

### Menu entry
Add `<MenuItem testID="sidebar-menu-capsule">` in `src/components/layout/SidebarMenu.tsx`
bottomGroup → `go('CapsuleWardrobe', close)`.

### Service `src/services/capsuleService.ts`
Export interfaces (`Capsule`, `CapsuleFull`, `CapsuleOutfit`, `CapsuleRequirements`,
`AddItemsResult`) + `capsuleKeys` factory + `capsuleService` object on `apiClient`,
one fn per endpoint above.

### Hooks (colocate under `src/screens/capsule/hooks/` or `src/hooks/`)
`useCapsules`, `useCapsule(id)`, `useCreateCapsule`, `useAddCapsuleItems`,
`useAddFromOutfits`, `useRemoveCapsuleItem`, `useChangeCapsuleItem`,
`useDeleteCapsule`, `useRetryGeneration`. Invalidate `capsuleKeys.all` +
the specific `capsuleKeys.detail(id)` on mutation success.

### Reuse
`MBottomSheet`/`MActionSheet` (add-source picker), `MDialog` (remove-confirm,
change-scope), imperative `toast` (all toasts), `MacgieLoader`/`Shimmer` (loading),
`Header` (all screens), `WardrobeItem`/`V05Outfit` types.

### Copy (exact — put in i18n `boilerplate.capsule.*`, all 3 locales en/fr/vi)
- Empty state / list title: "Capsule Wardrobe"
- Add-source sheet options: "My Wardrobe", "My Favourites", "My Creations"; helper: "Choose where you'd like to add from."
- Already-in-capsule tag: "Already in capsule"
- Generation progress steps: "Analyzing weather", "Analyzing formalness", "Analyzing items in your wardrobe"
- Background CTA: "Leave — notify me when ready"
- Ready toast: "Your capsule is ready."
- Add-from-wardrobe toast: "{{items}} items added to your capsule." / "{{outfits}} new outfits created."
- Add-from-favourites toast: "{{items}} new items added." / "{{existed}} items already existed in this capsule." / "{{outfits}} new outfits created."
- All-existing toast: "All items from this outfit are already included in this capsule."
- Remove unused toast: "Item removed from capsule."
- Remove-used modal: title "Remove item"; msg "This item is used in {{count}} outfits in this capsule. Removing it may update those outfits."; actions "Cancel" / "Remove"
- After confirmed removal toast: "Capsule updated."
- Change modal: title "Change item"; desc "This item appears in multiple outfits in this capsule. Where would you like to apply this change?"; options "This outfit only" / "All outfits using this item"; actions "Cancel" / "Change"
- Delete confirm + toast: "Capsule deleted successfully."
- Generation failed: "We couldn't create your capsule. Please try again."; actions "Retry" / "Edit settings" / "Cancel"
- Network lost during update: "Couldn't update your capsule. Check your connection and try again."
- Gaps: "We created {{made}} outfits instead of {{target}}." + list missing categories.

## 6. Analytics (`src/services/analytics.ts` — `trackCapsule*` wrappers, literal names, no PII)

Never send the capsule name (free text). Numeric constraints OK. Events:
| event | props | fired |
|---|---|---|
| `capsule_creation_started` | `{ source }` | `+` tapped on list |
| `capsule_configured` | `{ has_temp_range, formalness_level, outfit_target, shoe_limit }` | Create tapped |
| `capsule_generation_started` | `{ outfit_target }` | generation begins |
| `capsule_generation_backgrounded` | `{}` | "Leave" tapped |
| `capsule_generated` | `{ status, item_count, outfit_count }` | success/gaps |
| `capsule_generation_failed` | `{ error_kind, status? }` | API error (sanitized) |
| `capsule_viewed` | `{ item_count, outfit_count }` | detail opened — **once per capsule per session** (Set dedup like `trackRecommendationViewedOnce`) |
| `capsule_summary_expanded` | `{}` | summary expand |
| `capsule_add_source_selected` | `{ source }` | wardrobe\|favourites\|creations |
| `capsule_items_added` | `{ source, items_added, new_outfits, already_existed }` | add success |
| `capsule_item_removed` | `{ used_in_outfits }` | remove success |
| `capsule_item_changed` | `{ scope }` | change success |
| `capsule_deleted` | `{}` | delete success |

Update `docs/analytics/mixpanel-tracking-plan.md` §5 (shipped) accordingly.

## 7. Tests / verification
- Backend: `tests/test_capsules.py` (copy `tests/test_creations.py` harness) covering create→success, success_with_gaps, list, get, delete-preserves-items, add-items dedup, add-from-outfits all-existing, remove used/unused, change scope. Run `python test_server.py` clean if runnable.
- Mobile: `npx tsc --noEmit` clean; jest tests for `capsuleService` (unwrapping) + generation-copy helpers; a `maestro/flows/capsule/` create flow (best-effort, testID-driven).
- Contract doc: append all capsule endpoints to `API_DOCUMENTATION.md` in the per-endpoint format.

### 7.1 Cross-repo enforcement (anti-drift)
This spec is only anti-drift if the implementation PRs point back to it and the
mandated doc updates ship WITH their code (not after):
- **Both implementation PRs must link this file** (`plans/260718-0433-capsule-wardrobe/spec.md`)
  in their description so "do not drift" is enforceable.
- **Backend** (`auxi-backend` branch `claude/capsule-wardrobe-creation-fyhrsm`): the
  `API_DOCUMENTATION.md` append (§7) ships in the same commit as `routers/capsule.py`.
  ✅ Done — the capsule commit includes the "Capsule Wardrobe" API_DOCUMENTATION.md section.
- **Mobile** (`auxi-mobile` branch `claude/capsule-wardrobe-creation-fyhrsm`): the
  tracking-plan §5 update (§6) ships in the same commit as the analytics wrappers.
  ✅ Done — the capsule commit includes `docs/analytics/mixpanel-tracking-plan.md` §5.24.

## 8. Out of scope (documented, not built)
- Redis-worker true background generation (client-side React-Query continuation +
  local notification covers the UX; server generation is synchronous & fast).
- LLM/Gemini stylist prose (rule-based generator ships; LLM swap is a later drop-in
  behind `CapsuleGenerationService`).
- Weather automation (product decision: future version).
