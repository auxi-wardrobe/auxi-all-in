---
ticket: AU-307
title: Pin Item & Build Around Outfit
status: design-approved
date: 2026-06-15
figma: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=3140-5959&m=dev
branch: duc2820/au-307-uac-pin-item-build-around-outfit
---

# AU-307 — Pin Item & Build Around Outfit — Design Spec

## 1. Context

User lock một item trong outfit hiện tại; backend regenerate phần còn lại sao cho outfit chứa item đó. Pin chỉ tồn tại trong session, single-item, session-based. Áp dụng cho cả Home outfit grid và Item Detail screen.

Source UAC: Linear AU-307. Figma frame node-id `3140-5959`. Final product decisions table trong UAC là binding.

## 2. Scope

**In scope:**
- Pin confirmation modal trên Home outfit grid
- Generate outfit quanh pinned item (mới)
- Skeleton loading cho non-pinned slots
- Unpin (tap pinned item)
- "Replace pinned item?" khi đã có pin
- Item Detail "Build around this" — navigate Home + auto-pin + auto-generate
- Backend: extend `/api/v05/recommendation/build` chấp nhận `pinned_item_id`
- Error/retry, network timeout, pinned item unavailable, guest auth wall
- i18n 3 locale (en, vi-VN, fr-FR), a11y labels, Maestro smoke

**Out of scope (UAC final decisions):**
- Multi-pin
- Cross-session persistence
- Accessory pinning (MVP)
- Auto-save pinned outfits
- Hard remix cap (chỉ soft guidance)

## 3. Decisions (locked)

| Decision | Choice |
|---|---|
| ItemDetail "Build around this" flow | Navigate Home + auto-pin + auto-generate |
| Backend strategy | Extend `/build` accept `pinned_item_id` + engine filter |
| PR scope | Bundle BE + FE trong 1 sprint, 3 PR phối hợp |
| State management | `useReducer` trong HomeScreen, single dispatcher |
| Pin từ ItemDetail khi không có Home session | Gọi `/build` với `pinned_item_id` |
| Pin từ Home khi đã có session | Gọi `/try_another` với `pinned_item_id` (existing) |
| Generation timeout | 30s client-side → GENERATE_ERROR |
| Cached outfit recovery | Snapshot trước generate; restore on error |

## 4. Architecture

### 4.1 Mobile (auxi/)

**Touched / new files:**

| File | Action |
|---|---|
| `src/screens/HomeScreen.tsx` | Refactor `pinnedItemId` + loading useState → `useReducer`; wire modal; thay direct `onTogglePin` → `PIN_TAP` dispatch; **ẩn pin icon overlay nếu tile có `source="common_essential"`** |
| `src/components/features/PinConfirmModal.tsx` | **NEW** — confirm + replace variants |
| `src/components/features/SkeletonTile.tsx` | **NEW** — match tile dimensions; shimmer |
| `src/components/features/PinnedItemTooltip.tsx` | **NEW** — "Touch to unpin", dismiss after first session |
| `src/screens/ItemDetailScreen.tsx` | Replace "Coming soon" alert → `navigation.navigate('Home', { pinFromDetail: itemId })` |
| `src/services/v05Api.ts` | No code change; `pinned_item_id` đã thread sẵn |
| `src/hooks/usePinReducer.ts` | **NEW** — state machine reducer + types |
| `src/utils/snapshotOutfit.ts` | **NEW** — deep clone helper cho `lastOutfitSnapshot` |
| `src/i18n/locales/{en,vi-VN,fr-FR}.json` | Thêm keys: `pin.modal_title`, `pin.modal_subtitle`, `pin.build_cta`, `pin.cancel_cta`, `pin.replace_title`, `pin.unpinned_toast`, `pin.fallback_message`, `pin.error_message`, `pin.network_error`, `pin.item_unavailable`, `pin.tooltip_unpin`, `pin.guest_blocker` |
| `tests/maestro/pin-build-around.yml` | **NEW** — primary + replace + error retry |

**State machine (canonical):** xem §5.

### 4.2 Backend (wardrobe-backend/)

**Touched / new code:**

| File | Action |
|---|---|
| `schemas/v05_recommendation.py` | Add `pinned_item_id: Optional[str]` to `BuildRequest` |
| `services/v05_build_service.py` | Thread `pinned_item_id` → `BuildInput` |
| `blueprints/recommendation/engine_v05_layers.py` | L1: filter pool to outfits containing pinned id; L2: enforce in ranking |
| `blueprints/recommendation/engine_v05.py` | Use `BuildInput.pinned_item_id` (đã có field, chưa wired vào pipeline) |
| `tests/test_v05_build_service.py` | Add `TestPinnedItem` class — clone từ `test_v05_try_another_service.py::TestPinnedItem` |
| `tests/test_v05_recommendation_router.py` | Add integration test cho `/build` với `pinned_item_id` |
| `API_DOCUMENTATION.md` | Update V05 build section (~line 3600-3650) |

**Fallback strategy (UAC: no compatible items):**
- Nếu L1 pool sau filter < N (threshold = 3 candidates), relax constraints (drop axis/distance floor) và trả best-effort
- Response include `low_confidence: true` (mới) → FE hiện inline "We couldn't fully match this item, but here's the closest fit."

## 5. State machine — single source of truth

```
State = {
  pinnedItemId: string | null,
  pendingPinnedItemId: string | null,
  pinReplaceCandidate: string | null,
  modal: 'closed' | 'confirm' | 'replace',
  outfit: 'idle' | 'generating' | 'fallback' | 'error' | 'auth_required',
  lastOutfitSnapshot: Outfit | null,
  pendingUnpin: boolean,
}

Events:
  PIN_TAP(itemId)
    pinnedItemId === null      → modal='confirm', pendingPinnedItemId=itemId
    pinnedItemId === itemId    → UNPIN
    else                       → modal='replace', pinReplaceCandidate=itemId

  CONFIRM_PIN                  → snapshot outfit, pinnedItemId=pendingPinnedItemId,
                                 modal='closed', outfit='generating', fire generation
  CONFIRM_REPLACE              → snapshot outfit, pinnedItemId=pinReplaceCandidate,
                                 modal='closed', outfit='generating', fire generation
  CANCEL_MODAL                 → modal='closed', clear pending+replaceCandidate
  UNPIN                        → if outfit==='generating' → pendingUnpin=true
                                 else pinnedItemId=null, optional toast
  GENERATE_SUCCESS(outfit)     → outfit='idle', snapshot=null;
                                 if pendingUnpin → apply unpin
  GENERATE_FALLBACK(outfit)    → outfit='fallback'
  GENERATE_ERROR               → restore snapshot, outfit='error'
  RETRY                        → outfit='generating', fire generation
  PINNED_ITEM_GONE             → pinnedItemId=null, snapshot=null,
                                 show "This item is no longer available."
  AUTH_BLOCK                   → outfit='auth_required', open auth modal
```

**Coverage check vs UAC scenarios:**
- ✅ Primary: pin tap → confirm modal → CONFIRM_PIN → generating → success
- ✅ Cancel: CANCEL_MODAL
- ✅ Unpin: UNPIN (queued nếu generating)
- ✅ Remix while pinned: tái sử dụng generation request với current `pinnedItemId`
- ✅ Edge — replace: modal='replace' branch
- ✅ Edge — rapid taps: debounce CTA + dispatch guard khi `outfit==='generating'`
- ✅ Edge — no compatible: GENERATE_FALLBACK
- ✅ Edge — pinned unavailable: PINNED_ITEM_GONE
- ✅ Error API: GENERATE_ERROR + restore + RETRY
- ✅ Error network: GENERATE_ERROR (cùng path, different message từ axios error)
- ✅ ItemDetail flow: navigate Home with `pinFromDetail` param → mount effect dispatch CONFIRM_PIN
- ✅ Guest: AUTH_BLOCK trigger từ 401 response

## 6. Backend contract change

### BuildRequest schema delta

```python
class BuildRequest(BaseModel):
    # ... existing fields ...
    pinned_item_id: Optional[str] = Field(
        None,
        description="If set, the generated outfit must include this wardrobe item."
    )
```

### Engine integration (engine_v05_layers.py)

- **L1 pool filter** — sau khi gather candidate outfits, filter `[c for c in pool if pinned_item_id in c.item_ids]`. Nếu len < 3 → set `_relaxed=True`, retry với axis floor giảm
- **L2 ranking** — assert pinned item present trong top-1 outfit; nếu missing (shouldn't happen), log warning, fallback to swap

### Response delta

```python
class BuildResponse(BaseModel):
    # ... existing fields ...
    low_confidence: bool = False  # True if relaxed constraints during fallback
```

### Ownership validation (IDOR + scope)

Engine V05 query `WardrobeItem WHERE owner_id == user_id AND is_deleted=False` (`engine_v05.py:1045-1051`). Trước khi đẩy `pinned_item_id` vào pool filter, BE PHẢI:

1. **IDOR check** — `db.query(WardrobeItem).filter(id==pinned_item_id, owner_id==user_id, is_deleted==False).first()` → nếu missing → HTTP 410 Gone (map UAC "Pinned item becomes unavailable"). FE bắt 410 → dispatch `PINNED_ITEM_GONE`.
2. **Source check** — chỉ chấp nhận `WardrobeItem.is_common_item == False` (tức `source="user"` trong ItemDTO). Nếu user pass id của SYSTEM common-essential item → HTTP 422 với detail `"pinned_item_must_be_user_owned"`. FE thường không gửi case này vì pin icon ẩn trên SYSTEM tile.

Validation chạy ở `V05BuildService.build_v05_for_user()` trước khi gọi engine, KHÔNG ở engine layer (để engine giữ pure).

### Tests

Model after `tests/test_v05_try_another_service.py::TestPinnedItem`:
- `test_build_with_pinned_item_returns_outfit_containing_it`
- `test_build_with_unavailable_pinned_item_returns_410`
- `test_build_with_pinned_item_low_pool_sets_low_confidence`
- `test_build_with_pinned_item_owned_by_other_user_returns_410` (IDOR defense)
- `test_build_with_pinned_common_essential_item_returns_422` (source guard)
- Router integration: `test_build_pinned_unauthorized_returns_401`

## 7. UX details (Figma binding)

| Element | Spec |
|---|---|
| Modal overlay | Dim background `rgba(0,0,0,0.5)`, non-interactive (existing pattern từ `ContextChipsModal`) |
| Modal title | i18n `pin.modal_title` → "Keep this item" |
| Modal subtitle | i18n `pin.modal_subtitle` → "We'll keep this piece and remix the rest." |
| Primary CTA | i18n `pin.build_cta` → "Build around this", filled, disable on first tap |
| Secondary CTA | i18n `pin.cancel_cta` → "Cancel", outline |
| Pinned indicator inside modal | Filled pin SVG (`IconHomePin` charcoal) |
| Pinned tile in grid | Existing `figmaAction` charcoal fill (HomeScreen line 2503) |
| Tooltip "Touch to unpin" | Show first 3 pin actions per session, then auto-dismiss |
| Skeleton tile | Match tile dims; subtle shimmer (use existing animation pattern) |
| Header "Generating" status | Reuse existing pattern (MacgieLoader inline variant title) |
| Error inline message | Below outfit grid, với Retry button |
| Fallback inline message | Below outfit grid, no CTA |

## 8. Defaults applied (open questions)

Defaults chọn cho MVP; có thể điều chỉnh sau khi review Figma chi tiết:

| Question | Default |
|---|---|
| Toast "Item unpinned" | **Skip** — UAC nói optional, giảm noise |
| Tooltip persistence | **First 3 pin actions per session**, sau đó tắt |
| Fallback message wording | UAC verbatim: "We couldn't fully match this item, but here's the closest fit." |
| Maestro coverage | Primary pin flow + Replace flow + Error retry (3 flows) |

## 9. Risks & mitigations

| Risk (UAC 🔴) | Mitigation |
|---|---|
| Duplicate generation từ rapid taps | Debounce CTA + reducer guard khi `outfit==='generating'` |
| Pinned item accidentally replaced during remix | Engine L2 assert + log warning; FE check response outfit chứa pinned |
| Grid position shifts | Pinned item keep same `slotIndex` trong outfit response (BE contract) |
| Cached outfit overwritten on failure | `lastOutfitSnapshot` restore on `GENERATE_ERROR` |
| Race remix vs unpin | Reducer queue `pendingUnpin` cho tới SUCCESS |
| Stale pinned ref sau wardrobe sync | `useEffect` watch wardrobe items; if pinned id missing → `PINNED_ITEM_GONE` |
| Loading infinite | 30s client timeout via AbortController → `GENERATE_ERROR` |
| Tooltip blocks interactions | Tooltip pointer-events: 'box-none' + auto-dismiss timer |
| Backend duplicate items | BE assert response items unique; test: `test_build_pinned_no_duplicate_items` |
| Orphaned request on exit screen | AbortController cleanup trong unmount + query `enabled` flag |
| **IDOR — user pin item của user khác** | BE validate `WardrobeItem.owner_id == user_id` trước khi vào pool; missing → 410 Gone |
| **User pin SYSTEM common-essential item (cold-start)** | FE ẩn pin icon trên tile có `source="common_essential"`; BE reject 422 nếu vượt FE guard |

## 10. Verification gates

1. Backend: `cd wardrobe-backend && pytest tests/test_v05_build_service.py tests/test_v05_recommendation_router.py -v`
2. Mobile typecheck: `cd auxi && npx tsc --noEmit`
3. Mobile lint: `cd auxi && yarn lint`
4. Token drift: `./scripts/auxi-lint-tokens.sh`
5. Maestro: `cd auxi && maestro test tests/maestro/pin-build-around.yml`
6. Manual smoke: backend `:5001` + mobile sim iOS, primary + replace + error flows
7. qa-ui Compare mode (Figma vs sim screenshot)
8. qa-mobile smoke verify

## 11. PR plan (3 PRs phối hợp)

**PR-BE** (`backend-dev`):
- Schema delta + engine wiring + tests + API_DOCUMENTATION.md
- Merge **trước** mobile PR
- Branch: `duc2820/au-307-be-pin-build`

**PR-FE-core** (`mobile-dev`):
- `usePinReducer` + `PinConfirmModal` + `SkeletonTile` + HomeScreen wiring + ItemDetail wiring + i18n + a11y
- Depends on PR-BE merged
- Branch: `duc2820/au-307-uac-pin-item-build-around-outfit` (existing Linear branch)

**PR-FE-polish** (`mobile-dev` + `qa-ui`):
- Tooltip + Maestro flow + Compare mode review pass
- Branch: `duc2820/au-307-fe-polish`

## 12. Definition of done

- [ ] BE tests pass; API_DOCUMENTATION.md updated; PR-BE merged
- [ ] FE typecheck + lint + token-lint clean
- [ ] All 14 UAC scenarios manually verified on iOS sim
- [ ] Maestro 3 flows pass
- [ ] qa-ui Compare mode PASS (Figma fidelity)
- [ ] qa-mobile smoke PASS
- [ ] i18n 3 locale parity
- [ ] a11y labels on pin badge, modal CTAs, tooltip
- [ ] PR description includes Figma URL + extraction artifact + sim screenshot
- [ ] Linear AU-307 transitioned to Done

## 13. Open items (defer to implementation)

- Exact threshold for "low pool → relax constraints" (3 candidates suggested; engineer chốt sau khi test với real wardrobe data)
- Snapshot deep clone perf — check nếu outfit object >5KB; nếu yes dùng shallow + immutable
- ItemDetail navigation param shape — `{ pinFromDetail: itemId }` vs route param vs deeplink; mobile-dev quyết khi đụng navigation.ts
