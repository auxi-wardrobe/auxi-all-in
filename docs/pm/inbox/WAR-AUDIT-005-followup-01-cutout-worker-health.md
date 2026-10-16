---
id: WAR-AUDIT-005-followup-01
type: task
title: "[Devops] Verify ai_worker + Redis health; consider scheduling cutout backfill"
state: Backlog
priority: P1
labels: [audit, ops, area:backend, role:devops]
assignee: null
parent: WAR-AUDIT-005
created: 2026-07-17
---

## Context

Split out of WAR-AUDIT-005 (auto-remove-bg) audit findings. The background
removal pipeline is wired correctly and now self-heals transient cutout misses
via the `cutout_retry` job (shipped on `auxi-backend` branch
`claude/item-upload-background-removal-3rdyd1`). But one class of failure is
**not** fixable in app code and needs a devops verification:

> If the standalone `ai_worker.py` service is down/unhealthy in prod, NO async
> job (metadata, cutout, tryon, body-shape) completes and EVERY upload keeps its
> background. The web image's `CMD` is gunicorn-only — the worker is a separate
> Railway service consuming the Redis queue.

## Acceptance criteria

- [ ] Confirm the `ai_worker.py` Railway service exists, is running, and is
      consuming `ai_processing_queue` (check logs for "Processing job" lines).
- [ ] Confirm Redis (`REDIS_URL`) is reachable from both web + worker services.
- [ ] Check queue depth / backlog — a growing `ai_processing_queue` means the
      worker isn't keeping up (or is down).
- [ ] Decide whether to **schedule** `scripts/backfill_cutout_images.py`
      (e.g. a Railway cron) as a periodic safety net for `image_png IS NULL`
      items, or leave recovery to the new auto-retry + manual runs. If left
      manual, run it once now against prod to recover items uploaded while the
      worker/cutout was failing.

## Notes

- `cutout_retry` handles per-item transient misses automatically (bounded, 3
  attempts + backoff); it does NOT help when the worker itself is down.
- A miss that outlives the retries still lands in the `image_png IS NULL` set
  the backfill sweeps — so nothing is lost, but recovery is only automatic if
  the backfill is scheduled.

## Hand-off

Primary: `devops` (Railway + Redis health, cron decision).
Reference: WAR-AUDIT-005 audit findings section.
