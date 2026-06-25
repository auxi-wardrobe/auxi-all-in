# mobile-dev — AU-361 "Item is ready" toast

**Ticket:** AU-361 — "[bug] There is no toast message to inform an item is ready"
**Reporter:** Viet (CEO/designer)
**Figma:** https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2852-18884
**Date:** 2026-06-17
**Scope:** `auxi/` only.

## Root cause

The `WardrobeItem` model already carries `is_preparing` — items uploaded via
take-photo are background-processed (bg-removal + auto-tagging), and the flag
flips `true → false` when processing completes. The wardrobe grid already
renders a "Preparing this item" overlay while `is_preparing` is true
(`WardrobeScreen.tsx:304`) and item-detail gates editing on it
(`ItemDetailScreen.tsx:775`).

But **nothing detected the `preparing → ready` transition**, so no toast ever
fired when an item became ready. The post-upload success toast
(`wardrobe.list.added_title`) fires once at upload time and is unrelated to the
async ready state. Additionally, the screen only refetched on focus, so a user
who stayed on the wardrobe screen would never observe the transition at all
(the item sat "preparing" until they navigated away and back).

The Figma storyboard confirms the intended lifecycle across three frames:
`wardrobe` (preparing) → `wardrobe - added` (Snackbar **"Your item is ready"**,
node 3915:30077) → `wardrobe - seen` (toast auto-dismissed).

## Fix

In `WardrobeScreen.tsx`:

1. **Transition detection** — `reconcileReadyItems(data)` compares each fetch
   against the previous fetch's set of preparing item IDs. When an item that
   was preparing last fetch is now ready, fire the toast exactly once.
2. **Dedup** — two module-scoped refs: `preparingIdsRef` (prior-fetch preparing
   set) and `readyToastedIdsRef` (IDs already toasted this session). An item
   fires its ready toast at most once even across polls / refocus.
3. **Lightweight polling** — while the screen is focused AND any item is still
   preparing, refetch every 4s (`PREPARING_POLL_MS`) so the transition is
   actually observed. Poll uses a new `fetchItems({ silent: true })` path that
   skips the skeleton spinner and the error toast, and stops the instant nothing
   is preparing or the screen loses focus.
4. **Toast** reuses the app-wide `react-native-toast-message` `success` channel
   (mounted in `App.tsx:83`, used by 9 other screens) — no new dependency, no
   bespoke component. Copy goes through `t('wardrobe.list.item_ready_title')`.

No new backend fields or endpoints — purely client-side detection on the
existing `is_preparing` flag. No new theme tokens or icons needed.

## Files changed (path:line)

- `auxi/src/screens/WardrobeScreen.tsx`
  - `:1` — added `useRef` import
  - `:88` — `isPreparing()` helper + `PREPARING_POLL_MS` constant
  - `:117-119` — `preparingIdsRef`, `readyToastedIdsRef`
  - `:123-159` — `reconcileReadyItems()` (transition detection + toast + analytics)
  - `:163-192` — `fetchItems()` now accepts `{ silent }`, calls `reconcileReadyItems`
  - `:202-211` — preparing-poll `useEffect`
- `auxi/src/translations/en-EN.json:239` — `item_ready_title`: "Your item is ready"
- `auxi/src/translations/vi-VN.json:239` — "Món của bạn đã sẵn sàng"
- `auxi/src/translations/fr-FR.json:239` — "Votre article est prêt"
- `auxi/docs/analytics/mixpanel-tracking-plan.md` — §5.4 event row + §10 funnel tail
- `plans/260617-1743-au-361-item-ready-toast/figma-extraction-item-ready-toast.md` — extraction artifact

## Analytics event added

- **Event:** `item_ready_toast_shown` (past-tense, snake_case, literal constant)
- **Fires:** `WardrobeScreen.tsx:152` — when an uploaded item flips
  `is_preparing` true→false and the ready toast shows
- **Properties:** `item_category?` (omitted when unknown; no PII, no
  filenames/urls/ids beyond category string)
- **Goes through:** `src/services/analytics.ts` `track()` (single seam)
- **Funnel:** tail of the Wardrobe-grow (take-photo) funnel — documented in §10
- **Doc:** `auxi/docs/analytics/mixpanel-tracking-plan.md` §5.4 (wired) + §10

## Verification

- `npx tsc --noEmit` — **clean** (Node 20)
- `npx eslint src/screens/WardrobeScreen.tsx` — **clean** (0 issues)
- `yarn lint` (full) — 1 error + 7 warnings, **all in OTHER files**
  (HomeScreen, OutfitCanvasScreen, SignInScreen) from parallel work; none in
  files I touched. (Note: repo lint baseline has drifted from the "4 errors /
  3 warnings" in CLAUDE.md due to concurrent agents.)
- `scripts/auxi-lint-tokens.sh` — 34 pre-existing violations, **none in my
  files** (confirmed via grep: WardrobeScreen + 3 locales produce NONE).
- All 3 locale JSONs validate via `JSON.parse`.
- The eslint "Parsing error" on the JSON files is a missing JSON-parser config
  (affects all JSON files, pre-existing), not a content error.

**Simulator:** NOT run in this session — no sim access here. Code complete;
**visual verification pending**. Hand to qa-mobile (exploratory) / qa-ui
(Figma compare) to: upload an item that returns `is_preparing: true`, stay on
the wardrobe screen, confirm the "Your item is ready" toast fires once when
processing completes (and does not duplicate on re-focus).

## Open questions / follow-up

- **Backend contract:** confirmed `is_preparing` is consumed by the client but
  it is NOT explicitly documented in `wardrobe-backend/API_DOCUMENTATION.md`'s
  wardrobe item schema (the client reads it via the `WardrobeItem` index
  signature). The fix degrades gracefully if the backend never sets the flag
  (no item is ever "preparing" → no toast, no regression). Worth a backend-dev
  follow-up to document `is_preparing` in the wardrobe item response schema so
  the contract is explicit. **Not blocking.**
- **Snackbar pixel-fidelity:** Figma uses a bespoke M3 snackbar (`#4cf4d3`
  success bg, 4px radius). I reused the app-wide `react-native-toast-message`
  `success` preset to match the 9 existing success toasts and avoid introducing
  a one-off component in a bug fix. If the CEO wants the exact M3 snackbar
  visual, that is a separate design-system task (would re-skin ALL success
  toasts, not just this one). Flagged in the extraction artifact.
- **qa-ui review-extraction:** the extraction artifact was saved but I cannot
  dispatch qa-ui from this session; the orchestrator should run the
  review-extraction pass. Artifact has no open questions (copy is explicit in
  Figma, no new tokens/icons/BE fields).
