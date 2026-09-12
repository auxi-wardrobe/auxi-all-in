# Phase 05 — Admin SPA: gender picker + coverage warning

**Repo:** `auxi-wardrobe/auxi-backend` → `wardrobe-admin/` · **Owner:** backend-dev
**Effort:** 1.5h · **Status:** pending · **Blocked by:** 03

## Context

React 19 + Vite + TS + Ant Design + Tailwind. Files shipped by AU-457 phase 04:

- `wardrobe-admin/src/services/discoveryOutfitsService.ts` — typed DTOs mirroring
  `to_admin_dict` **field-for-field**, plus `getAll/get/create/update/patch/
  replaceItems/remove/uploadCover`. Carries the "null clears / omit leaves
  unchanged" `exclude_unset` comment.
- `wardrobe-admin/src/components/discovery-outfits/DiscoveryOutfitModal.tsx` —
  has the existing season `<Select>` (spring/summer/fall/winter/none) to copy,
  and a Publish button already `disabled` + tooltipped under the 0/>4 item gate.
- `wardrobe-admin/src/pages/DiscoveryOutfits.tsx` — status filter + card grid
  with season badge, trend tags, item count, `has_dead_items` warning badge.
- `wardrobe-admin/src/components/discovery-outfits/DiscoveryItemPicker.tsx` —
  precedent for an inline amber constraint note.

This SPA is **not** under the auxi design system (`.claude/rules/design-review-required.md`
§"When this doesn't apply") — no designer 6.5 gate, no `auxi-lint-tokens.sh`.

## Key insights

- The season `<Select>` is the exact shape to clone for gender, with one
  difference: **gender is required to publish**, season is not. Mirror the
  server's 422 as a client-side `disabled` + tooltip, exactly as the item-count
  gate already does — the operator should never see a raw 422.
- Store codes `M`/`W`/`U`, label them `Menswear`/`Womenswear`/`Unisex (all
  wardrobes)`. The operator thinks in onboarding language; the API speaks codes.
  Do **not** invent a fourth "All" option — that is `gender: null`, offered as a
  distinct "Not set (visible to everyone)" entry so its legacy meaning is
  explicit rather than a blank.
- The coverage warning is the deliverable that actually prevents the product
  failure (plan.md §Content-coverage risk). The picker alone doesn't.

## Requirements

### 1. `services/discoveryOutfitsService.ts`

```ts
/** Wardrobe-gender target. null = visible to every wardrobe (legacy rows
 *  only — the API rejects publishing a new outfit without one). */
export type DiscoveryGender = 'M' | 'W' | 'U';
```

- `DiscoveryOutfit` → `gender: DiscoveryGender | null;`
- `DiscoveryOutfitCreateInput` → `gender?: DiscoveryGender | null;`
- `DiscoveryOutfitUpdateInput` → `gender?: DiscoveryGender | null;`
- New:

```ts
export interface DiscoveryGenderCoverage {
  counts: Record<DiscoveryGender, number>;
  untagged: number;
  empty_cohorts: DiscoveryGender[];
}

getGenderCoverage: () => /* GET /admin/discovery-outfits/gender-coverage */
```

Keep the field order matching `to_admin_dict` so the field-for-field convention
in the file's header comment stays true.

### 2. `DiscoveryOutfitModal.tsx`

- A `<Select>` labelled **"Wardrobe gender"**, placed directly after Season:
  `Menswear (M)` / `Womenswear (W)` / `Unisex — all wardrobes (U)` /
  `Not set — visible to everyone`.
- Helper text under it, one line:
  *"Menswear users only see M outfits. Womenswear users only see W. Unisex users
  see everything."* — states the strict rule where the decision is made, so the
  operator isn't surprised by an invisible outfit.
- Extend the existing publish gate: `publishDisabled = liveCount < 1 ||
  liveCount > 4 || gender == null`, with the tooltip reason
  *"Pick a wardrobe gender before publishing"* when that is the failing clause.
  Reuse the existing tooltip mechanism — do not add a second one.
- On save: include `gender` in create; in edit mode it rides the existing
  `exclude_unset` PUT. An explicit `null` must be **sent** (not omitted) when the
  operator picks "Not set" on a previously-tagged outfit — that is the
  documented clear-to-null semantic and the plan's kill-switch.

### 3. `DiscoveryOutfits.tsx`

- Gender badge on each card next to the season badge: `M` / `W` / `U`, and a
  neutral `All` for `null`. Distinct colour per gender so a mis-tagged batch is
  visible at a glance across the grid.
- **Coverage banner** above the grid, from `getGenderCoverage()`:
  - `empty_cohorts` non-empty → Ant Design `<Alert type="warning">`:
    *"No published outfits for: Womenswear. Users who onboarded as Womenswear
    see an empty Discovery feed."*
  - otherwise a quiet one-line summary: `Published — M: 12 · W: 9 · U: 4 · Not
    set: 3`.
- Add a gender value to the existing status filter row (client-side filter over
  the already-fetched list — the list route is unpaginated today, so no API
  change).

## Related code files

- MODIFY `wardrobe-admin/src/services/discoveryOutfitsService.ts`
- MODIFY `wardrobe-admin/src/components/discovery-outfits/DiscoveryOutfitModal.tsx`
- MODIFY `wardrobe-admin/src/pages/DiscoveryOutfits.tsx`

## Implementation steps

1. Service types + `getGenderCoverage`.
2. Modal select + helper text + publish-gate clause + save wiring.
3. List page badge + coverage banner + gender filter.
4. `cd wardrobe-admin && npx tsc -b` — must be **zero errors**.
5. `npm run build` — clean.
6. `npx eslint` scoped to the three changed files — zero errors/warnings.
   (Repo-wide `npm run lint` has ~23 pre-existing errors in unrelated files —
   `AuthContext.tsx`, `AlgorithmCockpit.tsx`, `CommonItems.tsx`. Do not fix them
   here; do not let them mask a new one in these three.)
7. Manual pass against a local backend: create a DRAFT, confirm Publish is
   disabled with the gender tooltip, pick `M`, publish, see the badge, then clear
   to "Not set" and confirm the badge flips to `All`.

## Todo

- [ ] `DiscoveryGender` type + three DTO/input fields + `getGenderCoverage`
- [ ] Modal select with all four options incl. explicit "Not set"
- [ ] Publish gate extended with a distinct tooltip reason
- [ ] Explicit `null` is sent on clear (not omitted)
- [ ] Gender badge on the cards
- [ ] Coverage banner warns on `empty_cohorts`
- [ ] `npx tsc -b` zero errors; `npm run build` clean; scoped eslint clean
- [ ] Manual create→publish→clear round trip

## Success criteria

- A DRAFT with no gender cannot be published from the UI (button disabled, reason
  visible) — the server's 422 is never reached by the happy path.
- Tagging `M` and publishing shows an `M` badge.
- With zero published `W` outfits and zero untagged, the warning banner names
  Womenswear.
- Clearing gender to "Not set" persists as `null` and the badge reads `All`.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| `undefined` sent instead of `null` on clear → `exclude_unset` drops the key, gender never clears | **H**×M | Explicit todo + success criterion; the service file's own header comment documents the semantic |
| Operator reads "Unisex" as "show to everyone" and picks `U` for a men's look | M×M | Label is `Unisex — all wardrobes (U)`; the helper text spells out that M users do NOT see U outfits |
| Coverage banner fires on a board of DRAFTs only | M×L | `/gender-coverage` counts PUBLISHED+enabled+servable only (phase 03) |
| Pre-existing repo-wide lint errors mask a new one | M×L | Step 6 scopes eslint to the three changed files |

## Security

Admin-only surface behind the existing SPA auth; no new endpoint beyond the
admin-guarded `/gender-coverage`. No PII rendered (aggregate counts only).

## Next steps

Deploy the SPA, then the CEO tags the existing published outfits before phase 06
ships (plan.md §Release order).
