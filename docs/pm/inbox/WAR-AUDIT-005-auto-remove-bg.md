---
id: WAR-AUDIT-005
type: feature
title: "[Backend/Mobile] Auto-remove background on item upload"
state: Backlog
priority: P1
labels: [audit, figma, area:backend, area:mobile, role:backend-dev]
assignee: null
parent: WAR-AUDIT-000
created: 2026-05-05
figma_node: "1064:1168"
figma_file: "0nXXMAR4Arf1ZfjtQvtBh0"
---

## Context

Designer specced auto-removal of photo background when a user uploads a
new wardrobe item. Likely a backend job (image processing pipeline), but
needs verification. Audit found no remove-bg call in mobile code.

## Designer note (verbatim)

> "**Auto remove background**"

Source: Figma sticky note `1064:1168` (section `909:11258` "wardrobe").

## Code reference checked

- `auxi/src/services/itemService.ts` — no remove-bg call.
- `auxi/src/services/wardrobeService.ts` — no remove-bg call.
- `wardrobe-backend/` — **NOT YET INSPECTED**. This is the verify step.

## Acceptance criteria

- [ ] Backend audit: confirm whether `wardrobe-backend/` already runs a
      remove-bg step on upload. Comment findings on this ticket.
- [ ] If backend handles it: confirm processed image is what mobile
      receives + displays. No mobile work needed beyond verification.
- [ ] If backend does NOT handle it: implement remove-bg pipeline in
      `wardrobe-backend/` (likely in the upload service / item-create
      route). Update `wardrobe-backend/API_DOCUMENTATION.md` if the
      response shape changes.
- [ ] If implementation is mobile-side: file a follow-up sub-issue for
      `auxi/` covering the call.
- [ ] qa-mobile flow: upload an item with a clearly-non-white background
      (e.g., a shirt on a wooden floor) → confirm the stored thumbnail
      shows the item on a clean background.

## Out of scope

- Manual background-edit UI (separate ticket if designer wants it).

## Dependencies

- Backend audit (assign to `backend-dev`).
- Possibly: a background-removal library or service decision (rembg,
  remove.bg API, Gemini vision, etc.) — tech-lead approval.

## Verification

- `cd wardrobe-backend && python test_server.py` green.
- `wardrobe-backend/API_DOCUMENTATION.md` updated if route shape changed.
- qa-mobile manual smoke after backend ships.

## Hand-off

Primary: `backend-dev` for verification + implementation in
`wardrobe-backend/`. Secondary: `mobile-dev` if/when contract change
requires client update.

## Audit findings (2026-07-15)

**Backend DOES run remove-bg on upload — no mobile work needed.** Pipeline is
wired correctly end-to-end:

- Mobile `wardrobeService.ts` → `POST /api/wardrobe/items/ai-enhanced` (verified
  in `auxi-mobile`). The plain `POST /api/wardrobe/` create path has NO cutout,
  but mobile does not use it.
- `create_and_enhance_item` creates the item `is_preparing=True` + enqueues a
  Redis job → `ai_worker.py` → `enhance_item_with_ai` runs metadata +
  `remove_background` (rembg, local `isnet-general-use`) in parallel → stores the
  transparent cutout in `image_png`. Mobile display precedence:
  `image_studio → image_png → image_url`.
- rembg code is correct; imports on Python 3.11; Dockerfile pre-fetches the model
  at build time.

**Why a user still sees a background:** the cutout is best-effort. On any failure
`image_png` stays NULL, the item is kept Ready with its ORIGINAL image (AU-408),
and recovery was only via a **manually-run** `scripts/backfill_cutout_images.py`
(not scheduled anywhere) — so a single transient miss (network/S3 blip, worker
flap, briefly-expired source URL) became permanent.

**Fix shipped** (`auxi-backend` branch
`claude/item-upload-background-removal-3rdyd1`): bounded automatic `cutout_retry`
job that self-heals a missed cutout without waiting for the backfill. Additive to
AU-408, no API contract change. Tests:
`tests/test_ai_service_cutout_retry.py`.

**Operational caveat (needs devops):** if the standalone `ai_worker.py` service
is down/unhealthy in prod, NO async job (metadata, cutout, tryon) completes and
EVERY upload keeps its background — no code change fixes that. Verify the Railway
worker + Redis health, and consider scheduling `backfill_cutout_images.py` to
recover items uploaded while any of the above was failing.
