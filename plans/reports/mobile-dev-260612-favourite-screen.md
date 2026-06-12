# mobile-dev — Favourite (Love Collection) screen + service fixes

Date: 2026-06-12 · Branch `feat/au226-favourite-and-see-this-on-me`
Worktree: `/Users/nguyenminhduc/dev/auxi-favourite-wt`
Ticket: AU-226 (Workstreams 2 + 4 + 6). Workstream 5 ("See this on me") NOT built.

## Files created
- `src/screens/FavouriteScreen.tsx` — Love Collection screen (TanStack Query)
- `src/screens/favourite/EmptyState.tsx` — green-heart empty state
- `src/screens/favourite/FavouriteOutfitCard.tsx` — per-outfit caption + tile grid + action row
- `src/screens/favourite/group-by-date.ts` — date-bucketing helper

## Files modified
- `src/services/favouriteService.ts` — +`listFavourites` / +`removeFavourite` / +types
- `src/services/tryOnService.ts` — fixed contract → `POST /tryon/highres`
- `src/services/bodyService.ts` — fixed endpoints → `/body` (GET/POST multipart/DELETE)
- `src/screens/BodyScreen.tsx` — updated the one `generateTryOn` call site to new contract
- `src/types/navigation.ts` — `Favourite: undefined` in `AppStackParamList`
- `src/navigation/AppNavigator.tsx` — registered `<Stack.Screen name="Favourite" …>`
- `src/components/layout/Sidebar.tsx` — wired "My Favourite" → `navigate('Favourite')`
- `src/translations/{en-EN,vi-VN,fr-FR}.json` — `favourite.*` namespace

## Figma extraction
- Note saved: `plans/260611-2348-favourite-see-this-on-me/figma-extraction-favourite.md`
- File key `0nXXMAR4Arf1ZfjtQvtBh0`. Child node-ids extracted:
  - Favourite collection: `3230:35028` → date group `3230:35031` (header `3230:35032`,
    caption row `3230:35033`, grid `3230:35039`, tiles `3230:35041..45`),
    action row `3230:35046` (remove `3230:35048`, Self-viz `3230:35049`)
  - Header instance: `3230:35070` (back chevron + centered "Favourite", Inter Med 14/20)
  - Remove dialog + empty state: `3539:23335` → dialog `3539:23380` / `3539:23381`
  - Variable defs pulled for `3230:35028`; screenshots of `3230:35028` + `3539:23335`

## Reuse vs created
- REUSED: `OutfitCardCaption` (caption+idea pill), `HomeViewToggleFooter` (grid/collage),
  `SettingsDialog` (danger remove-confirm), `TopIconButton` (header back), `Icons.*`
  (`icon_minus_circle`, `icon_remix`, `icon_idea`, `icon_chevron_left`,
  `icon_home_heart_filled`), `resolveItemImage`, `theme` tokens.
- CREATED: the 4 favourite files above. No new primitives, no new theme tokens, no new SVGs.
- The hardcoded "common" rarity tag from HomeScreen was FIXED to render conditionally on
  `is_common_item` (only shows the badge for common items).

## Service contract changes
- `favouriteService.listFavourites(limit=20, offset=0, sort='recent')` → `GET /favorites`
  (params); `removeFavourite(id)` → `DELETE /favorites/{id}` → `{message}`. Added
  `Favourite`, `FavouriteItem`, `FavouriteContext`, `FavoriteListResponse` types reusing
  `Item` fields. `saveFavourite` left untouched.
- `tryOnService.generateTryOn` now POSTs `/tryon/highres` with
  `{body_id, wardrobe_item_ids, gemini_opt_in:true, prompt_params?}`, reads `composite_url`
  (+ `composite_key`/`processing_time_ms`/`provider`/`composite_png` fallback), 120000ms
  timeout. Function name kept stable; BodyScreen call site updated.
- `bodyService`: `getBodies()` → `GET /body` (`{count,items}`); `uploadBody(file)` →
  `POST /body` multipart `file` directly (NO prior `/upload/file` — confirmed in
  `routers/body.py`); `deleteBody(id)` → `DELETE /body/{id}`. Moved off the bespoke
  `bodyApi` axios instance onto `apiClient` (inherits 401-refresh interceptor).

## Verification
Worktree had NO `node_modules` installed → temporarily symlinked the main submodule's
install (`wardrobe_project/auxi/node_modules`) to run the real toolchain, then removed it.
- `tsc --noEmit`: CLEAN for all my files. Remaining 19 errors are pre-existing only —
  `_HomeScreen.tsx` (legacy, known) + `reactotron.config.ts` (reactotron dev-dep not
  installed). Neither touched by me.
- `eslint` on all 11 changed files: CLEAN (0 errors / 0 warnings). (One `react-hooks/
  exhaustive-deps` error I introduced was fixed by wrapping `favourites` in `useMemo`.)
- token-lint (auxi-lint-tokens.sh logic) run against worktree: NONE of my files appear in
  the 45 pre-existing violations. My code is hex/font-literal clean.
- Simulator: NOT run (no deps installed in worktree; qa handles sim verify). Visual
  side-by-side is PENDING — code complete.

## testIDs shipped
`favourite-screen`, `favourite-loading`, `favourite-error`, `favourite-empty`,
`favourite-list`, `favourite-back-button`, `favourite-view-toggle`,
`favourite-card-{id}` (+ `-caption`, `-tile-{itemId}`), `favourite-remove-{id}`,
`favourite-self-visualization-{id}`, `favourite-remove-cancel`,
`favourite-remove-confirm`, `sidebar-menu-favourite`.

## Deltas / concerns for qa-ui + CEO
1. **Footer tab testIDs**: spec asked `favourite-toggle-grid/collage`. Reusing
   `HomeViewToggleFooter` (primitives-first) means its INTERNAL tab testIDs stay
   `home-footer-tab-grid` / `home-footer-tab-collage`; I added `favourite-view-toggle`
   on the wrapper. Forking the shared footer just to rename testIDs would violate reuse —
   flag if QA needs feature-scoped tab selectors.
2. **Remove dialog shape**: per task I reused `SettingsDialog` (centered modal card).
   Figma draws a bottom-sheet. Functional/danger/copy match; structural delta documented.
3. **Rarity badge**: backend gives only `is_common_item: bool`. Badge shows "common" for
   common items, hidden otherwise. Figma renders "uncommon" on user tiles — no backend
   field for that. Confirm we should NOT invent an "uncommon" label.
4. **Empty-state heart color**: green hue not a published var; used `theme.colors.success`
   (#388E3C) on `icon_home_heart_filled.svg`. Confirm tone.
5. **Collage view**: footer toggles grid↔collage but the collage tile arrangement isn't
   separately specced; collage re-flows the same 3:4 tiles 3-per-row. Confirm intent.
6. **qa-ui review-extraction**: workflow wants qa-ui Pass-1 on the extraction note BEFORE
   code. As a subagent I can't dispatch peers — parent should route the extraction note to
   qa-ui (review-extraction mode) and qa-mobile/qa-ui for the sim compare.

**Status:** DONE_WITH_CONCERNS
**Summary:** Built the Favourite screen + the 3 service-contract fixes + i18n/tokens;
tsc/eslint/token-lint clean for all authored files (verified via the main submodule's
toolchain since the worktree has no deps installed).
**Concerns:** 6 documented deltas above (footer testID naming, dialog shape, rarity/empty
tokens, collage spec, and the pending qa-ui extraction review + sim visual pass).
