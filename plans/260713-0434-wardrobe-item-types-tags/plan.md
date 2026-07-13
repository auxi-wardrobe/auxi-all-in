# Wardrobe item types & tile tags — canonical taxonomy + implementation plan

**Date:** 2026-07-13
**Branch (umbrella):** `claude/wardrobe-item-types-tags-030b9t`
**Scope:** cross-repo coordination — `auxi/` (mobile tag rendering) + `wardrobe-backend/` (source/state fields)
**Status:** Planned, not started
**Owner routing:** mobile → `mobile-dev` · backend → `backend-dev` · contract sign-off → `tech-lead`

> The submodule code repos (`ducga1998/auxi-mobile`, `ducga1998/wardrobe-backend`) are not
> reachable from this umbrella checkout, so this is the coordination artifact: the authoritative
> taxonomy + a phased plan to dispatch. Implementation lands in the submodules via the role agents.

---

## 1. The taxonomy — 4 item types, one tile tag each

Every wardrobe grid tile shows **at most one** status tag. The tag is a function of two
orthogonal dimensions: **source** (who the item belongs to) and, for user items, **state**
(viewed / demoted).

| # | Item type | Tag shown | Driven by |
|---|---|---|---|
| 1 | Belongs to **Macgie** (brand catalog / system item) | **`Macgie`** | backend `is_common_item === true` (system item, `user_id = None`) |
| 2 | Belongs to **user** (uploaded) | — | `is_common_item === false`, `user_id` set |
| 2a | ↳ uploaded, **not yet opened** | **`New`** | client viewed-state (`WardrobeViewedContext`) — item **not** in viewed set |
| 2b | ↳ uploaded, **already opened** | *(no tag)* | item **in** viewed set |
| 3 | User chose **Less use** (demoted) | **`Less use`** | backend `usage_frequency === 'LESS_USED'` (legacy fallback: `less-used` style tag) |

**"Opened" = user tapped the tile to view its detail.** That tap is what flips 2a → 2b.

### 1.1 Precedence — SOURCE FIRST, then STATE

Tag selection is a two-level decision. Resolve **source** first; only user items reach the state check:

```
resolveTileTag(item, viewedSet):
  1. if item.is_common_item        → 'Macgie'          # source wins; a catalog item is never New/Less-use
  2. else (user-owned):
       if item.usage_frequency == 'LESS_USED' → 'Less use'   # explicit user choice
       elif item.id NOT in viewedSet          → 'New'        # auto, until first open
       else                                    → none         # viewed, normal
```

Precedence within user items: **Less use > New > none** (an explicit demotion outranks the
auto "New" badge in the edge case where a never-opened item was demoted).

---

## 2. Delta vs what already ships (PR #148)

PR #148 ("tile status tags", auxi-mobile #148) already renders one pill per tile with
precedence **`new > less use > common`**. This spec is a **refinement**, not a greenfield build.
Three concrete changes:

| Change | From (shipped) | To (this spec) | Why it matters |
|---|---|---|---|
| **A. Rename label** | `common` | `Macgie` | Brand alignment (auxi → Macgie). Same underlying field (`is_common_item`), new label + pill style. |
| **B. Source-first precedence** | `new > less use > common` (common lowest) | `Macgie` decided first, before New/Less-use | **Behavior change:** a Macgie/catalog item the user hasn't opened currently shows **`New`** (because `new > common`). Under this spec it must show **`Macgie`**. "New" is reserved for *user uploads* only. |
| **C. Formalize "New"** | any unviewed tile | unviewed **user-uploaded** tile only | "New" now means "you uploaded this and haven't looked at it yet," not "any tile you haven't opened." |

Everything else (the `WardrobeViewedContext` mechanism, the `usage_frequency` field + its
`less-used` fallback, the `TileStatusBadge` component) is **reused as-is**.

---

## 3. Backend reality (mostly already there)

The taxonomy needs **no new backend fields** — it composes existing ones:

- **`is_common_item`** — served today (`models/wardrobe.py`, `to_dict`). Drives `Macgie`. ✅
- **`usage_frequency` (`NORMAL` | `LESS_USED`)** — first-class field + `PATCH /wardrobe/items/{id}/usage-frequency`
  is specified in `plans/260626-0005-pr148-usage-frequency-backend/plan.md`. Drives `Less use`.
  **Dependency:** that plan should land (or its `less-used` style-tag fallback remain) for the
  `Less use` tag to persist correctly. ✅ / ⚠️ (verify shipped)
- **Viewed-state (`New`)** — **client-only** today (`WardrobeViewedContext`, per-user AsyncStorage).
  No backend field. Keep it local (YAGNI) unless cross-device "New" consistency is a product
  requirement — see §6 open decision.

**Net backend work for THIS spec: none required** beyond confirming the usage-frequency plan is
shipped. Do **not** add a `source` enum column — `is_common_item` + `user_id` already encode the
source dimension; a new column would be redundant (DRY).

---

## 4. Mobile work (the real change — `auxi/`)

All in `auxi/`, dispatch to `mobile-dev`. Grounded in the refactor plan
(`plans/260701-1448-GH-364-mobile-screen-refactor/phase-06-wardrobe-screen.md`): tag logic lives in
`resolveTileStatus` (→ `wardrobeGrid.ts` helper) and renders via `TileStatusBadge` inside
`WardrobeGridTile.tsx`.

1. **Tag resolver — make it source-first.** Update `resolveTileStatus` (or `resolveTileTag`) to the
   §1.1 algorithm: `is_common_item` → `Macgie` **before** any viewed/usage check. Guard "New" so it
   only applies when `!is_common_item`.
2. **Rename `common` → `Macgie`.** Label string + i18n key + the `common` pill variant in
   `TileStatusBadge`. Keep the enum value internally consistent (e.g. status `'macgie'`); update all
   references. No hardcoded hex — use `ds.color` tokens per the design-system rule.
3. **Copy/i18n.** `Macgie`, `New`, `Less use` strings through the i18n layer, not inline literals.
4. **Verify viewed-state wiring.** Confirm the tile-open handler marks the item viewed in
   `WardrobeViewedContext` (flips `New` → none). If a Macgie item was previously getting a stale
   `New`, it now correctly shows `Macgie`.

### 4.1 Analytics (REQUIRED — `.claude/rules/analytics-tracking-required.md`)

The 2a → 2b transition is a new/clarified user interaction and must be tracked. Route through
`src/services/analytics.ts`, literal event names, snake_case, past tense, no PII:

- **`wardrobe_item_viewed`** — fired when a tile is opened (the tap that clears `New`).
  Props: `{ item_source: 'macgie' | 'user', had_new_tag: true|false }`. `item_source` from
  `is_common_item`; **no** free-text, no item name.
- If a `wardrobe_item_opened`/detail-view event already exists, **extend it** with `item_source` +
  `had_new_tag` rather than adding a duplicate (check §5 of the tracking plan for collisions first).
- Update `auxi/docs/analytics/mixpanel-tracking-plan.md` (§5 shipped or §6 gap) — mandatory.

---

## 5. Phases & todos

**Phase 1 — Backend confirm (backend-dev / tech-lead)**
- [ ] Verify `usage_frequency` field + endpoint (plan `260626-0005`) is shipped; if not, land it (or confirm `less-used` fallback is live) so `Less use` persists.
- [ ] Confirm `is_common_item` present on every wardrobe item response (it is). No new columns.

**Phase 2 — Mobile tag resolver (mobile-dev)**
- [ ] Rewrite `resolveTileStatus` → source-first (§1.1); "New" gated to `!is_common_item`.
- [ ] Rename `common` → `Macgie` (status value, `TileStatusBadge` variant, i18n, pill style via `ds.color`).
- [ ] Confirm tile-open marks viewed (`WardrobeViewedContext`) → `New` clears.

**Phase 3 — Analytics (mobile-dev)**
- [ ] `wardrobe_item_viewed` (or extend existing open event) with `item_source`, `had_new_tag`; via `analytics.ts`, no PII.
- [ ] Update `auxi/docs/analytics/mixpanel-tracking-plan.md`.

**Phase 4 — Gates & verify**
- [ ] `./scripts/auxi-lint-tokens.sh` clean (no hex/font drift on the renamed pill).
- [ ] qa-ui Compare (Figma pill vs render) → designer design-review gate (§6.5) → qa-mobile smoke: all 4 states render the right single tag; Macgie item never shows `New`.
- [ ] `cd auxi && npx tsc --noEmit && yarn lint` green.

---

## 6. Open decisions (need CEO / product sign-off)

1. **Source-first precedence (change B)** is a deliberate behavior change: a never-opened Macgie
   catalog item flips from `New` → `Macgie`. **Confirm this is intended** (it follows directly from
   the spec's "New = user upload" wording, but it changes existing pixels).
2. **Cross-device "New":** viewed-state is per-device (AsyncStorage) today, so `New` can reappear on
   a second device. Acceptable? If cross-device consistency is wanted, that's a backend `viewed_at`
   field + endpoint (out of scope here; separate ticket). Recommend **keep local** (YAGNI) unless CEO says otherwise.
3. **Pill visual for `Macgie`:** reuse the current `common` pill style, or does Macgie get its own
   treatment (brand color)? Design call → qa-ui / designer / CEO. This spec assumes label-only change.

## 7. Out of scope
- V05 recommendation-engine effects of `Less use` (down-ranking) — deferred (see plan `260626-0005` §8).
- Any new `source` enum column — redundant with `is_common_item` + `user_id`.
- Backend persistence of viewed-state — see §6.2.

## 8. Unresolved questions
- Is the usage-frequency backend plan (`260626-0005`) actually merged/deployed? (Phase 1 gate.)
- Linked Linear/GH issue id for this taxonomy work (for traceability).
- Does a detail-view analytics event already exist to extend, or is `wardrobe_item_viewed` net-new?
