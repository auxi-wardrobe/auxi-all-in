# Beautify flow completion — push notification + status-based tap routing

## Context

The "Beautify" feature (AI studio-shot generation for a wardrobe item photo,
`gpt-image-1` via `wardrobe-backend/services/beautify_service.py`) already
ships end-to-end: upload → `beautify_status` pending → ready/failed → accept/
discard on `BeautifyReviewScreen`. The request that triggered this spec asked
for four behaviors; investigation found two already shipped and two missing.

### Already shipped — no work in this spec

- **In-progress tile badge.** `auxi/src/screens/wardrobe/WardrobeGridTile.tsx:79-90`
  renders a top-left "✨" badge while `item.beautify_status === 'pending'`. It's
  independent of the bottom-center New/Less-use pill (`TileStatusBadge`), so
  there's no precedence conflict — they occupy different corners.
- **Foreground auto-update + toast on completion.** `WardrobeScreen`'s
  `wardrobeQuery` polls every `PREPARING_POLL_MS` while focused and something
  is beautifying (`anyBeautifying`, stops when backgrounded —
  `refetchIntervalInBackground: false`). `useItemReadySnackbar.reconcileReadyItems`
  detects the `pending → ready` transition and fires a "Studio shot ready —
  Review" snackbar (`WardrobeScreen.tsx:704-720`) that navigates to
  `BeautifyReview` on tap.

### Gaps this spec covers

- **Gap A — push notification when backgrounded.** No beautify push exists.
  Try-on already solved this exact problem for a different async job
  (`tryon_render_service.py:273-294` → `notification_service.enqueue_tryon_result`),
  including a mobile deep-link branch the app already parses
  (`deepLinkHandler.ts:373-380`). This spec mirrors that pattern for beautify.
- **Gap B — tap-to-route by status.** `WardrobeScreen.handleItemPress` (line
  326) always navigates to `ItemDetail` regardless of `beautify_status`. Needs
  branching so a mid-flight or ready item routes to the right screen instead
  of the normal edit/detail screen.

## Design

### Gap A — backend: beautify push notification

**`wardrobe-backend/services/notification_service.py`**

Add, mirroring `enqueue_tryon_result`/`_tryon_payload` (lines 68-108):

- Constants `BEAUTIFY_READY_TYPE = "beautify_ready"`,
  `BEAUTIFY_FAILED_TYPE = "beautify_failed"`.
- `_beautify_payload(item_id: str, status: str) -> dict` — minimal payload,
  no image URL (mirrors try-on's minimalism, keeps payload light):
  ```python
  {"kind": "route", "screen": "Home", "type": "beautify_result",
   "action": "beautify_result", "item_id": item_id, "status": status}
  ```
  `screen: "Home"` is the curated-allowlist fallback for old clients (same
  role "Creations" plays for try-on) — never the literal navigation target on
  a client that understands the richer `type`/`action` fields.
- `enqueue_beautify_result(db, *, user_id, item_id, status) -> bool` — same
  shape as `enqueue_tryon_result`: build title/body from `status`
  ("Your studio shot is ready" / "Studio shot generation failed"),
  `create_system_notification`, commit (so the notification worker's separate
  DB session sees the row before the Redis job pops), then
  `queue_service.push_notification_job(...)`.

**`wardrobe-backend/services/beautify_service.py`**

Add a private best-effort helper mirroring
`tryon_render_service._notify_tryon_result` (lines 273-294) — try/except,
logs and swallows on failure, never lets a notification error break the
beautify job:

```python
def _notify_beautify_result(self, user_id: str, item_id: str, status: str) -> None:
    try:
        from services import notification_service
        notification_service.enqueue_beautify_result(
            self.db, user_id=user_id, item_id=item_id, status=status,
        )
    except Exception as exc:
        logger.warning("beautify: push notification skipped for %s: %s", item_id, exc)
```

Call it in `generate_studio_shot`:
- After `item.beautify_status = "ready"` + `self.db.commit()` (line ~101) →
  `self._notify_beautify_result(item.user_id, item_id, "ready")`.
- After `item.beautify_status = "failed"` + `self.db.commit()` (line ~112) →
  `self._notify_beautify_result(item.user_id, item_id, "failed")`.

**Docs + tests**

- Update `API_DOCUMENTATION.md` §Beautify: note the push side-effect and the
  `type=beautify_result` data-payload shape on terminal status.
- Extend `tests/test_beautify_service.py`: mock `notification_service` and
  assert `enqueue_beautify_result` fires exactly once on the ready path and
  once on the failed path, with the correct `user_id`/`item_id`/`status`
  (mirror the existing assertion pattern in `test_tryon_render_service.py`).

### Gap A — mobile: deep-link tap handling

**`auxi/src/services/deepLinkHandler.ts`**

Add a branch in `resolveNotificationData`, alongside the existing
`tryon_render`/`tryon_result` branch (before the generic curated-`screen`
fallback, same reasoning — the richer fields let a tap land on the right
screen instead of a generic tab):

```ts
if (data.type === 'beautify_result' && data.action === 'beautify_result') {
  if (data.status === 'ready' && data.item_id) {
    navRef.navigate('BeautifyReview', {
      itemId: data.item_id,
      originalUri: '',
      from: 'push',
    });
  } else {
    fallbackHome();
  }
  return;
}
```

`originalUri: ''` on a cold-start push tap is an accepted, deliberate
tradeoff (confirmed) — `BeautifyReviewScreen` already renders an empty-source
`<Image>` tolerantly (same as the existing snackbar path when
`item.image_url` is falsy); no extra fetch-before-navigate is added.
`status === 'failed'` falls back Home (no candidate to review).

**`auxi/src/types/navigation.ts`**

Extend `BeautifyReview`'s `from` union: `'loader' | 'snackbar' | 'push'` —
keeps the existing entry-point analytics dimension accurate.

### Gap B — mobile: status-based tap routing

**`auxi/src/screens/WardrobeScreen.tsx`** — `handleItemPress` (line 326),
insert the branch after the existing `isSelectMode`/`PENDING_IMPORT_ID`
guards, before the current unconditional `navigation.navigate('ItemDetail', ...)`:

```ts
if (item.beautify_status === 'pending') {
  track('wardrobe_item_opened', { item_id: item.id, beautify_status: 'pending' });
  navigation.navigate('BeautifyPending', {
    itemId: item.id,
    originalUri: item.image_url ?? '',
  });
  return;
}
if (item.beautify_status === 'ready') {
  track('wardrobe_item_opened', { item_id: item.id, beautify_status: 'ready' });
  navigation.navigate('BeautifyReview', {
    itemId: item.id,
    originalUri: item.image_url ?? '',
    from: 'snackbar', // tile tap reuses the existing "ready" entry semantics
  });
  return;
}
// falls through to existing ItemDetail navigation — covers 'none' and
// 'failed' (confirmed: failed has no candidate to review, behaves as if
// nothing special happened).
```

No branch needed for `'failed'` — it's the fall-through default, matching
existing `ItemDetail` behavior exactly.

## Analytics

Per `.claude/rules/analytics-tracking-required.md`: the existing
`wardrobe_item_opened` event gains an optional `beautify_status` property on
the two new branches (values `'pending'`/`'ready'`); the fall-through path
keeps firing unchanged. `auxi/docs/analytics/mixpanel-tracking-plan.md` gets
a one-line addition under the existing `wardrobe_item_opened` entry — this is
a property addition to a shipped event, not a new event, so no funnel-impact
statement is needed.

## Testing

- Backend: `tests/test_beautify_service.py` — push enqueue assertions (above).
  `python test_server.py` before commit (per repo convention).
- Mobile: `npx tsc --noEmit` + `yarn lint`. Unit tests:
  - `deepLinkHandler.test.ts` — new `beautify_result` cases (ready → navigate
    with `from: 'push'`; failed → fallback Home; missing `item_id` → fallback
    Home), mirroring the existing `tryon_render` test block.
  - A `WardrobeScreen`/`handleItemPress` test (or extend existing coverage if
    present) for the three-way branch: pending → `BeautifyPending`, ready →
    `BeautifyReview`, none/failed → `ItemDetail`.
- Manual/smoke: not required to hit the simulator for this (logic-only
  branching + backend push wiring); `qa-mobile` smoke pass still applies per
  the umbrella verification gate before merge.

## Out of scope (explicitly, per YAGNI)

- No changes to the tile badge or the foreground snackbar — both already do
  what was asked.
- No new curated push screen (`"Wardrobe"` etc.) — `"Home"` fallback is
  sufficient since the richer `type`/`action` fields carry the real target.
- No fetch-before-navigate for cold-start push taps missing `originalUri`
  (confirmed tradeoff).
- No special UI on `BeautifyPendingScreen` for the `failed` tap-routing case
  — failed routes to `ItemDetail`, not `BeautifyPending` (confirmed).
