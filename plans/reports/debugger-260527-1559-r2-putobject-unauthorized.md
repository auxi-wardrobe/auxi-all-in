# R2 PutObject `Unauthorized` — Sentry PYTHON-FASTAPI-3/4/2  (RESOLVED)

**Date:** 2026-05-27 · **Scope:** `wardrobe-backend` (prod infra) · **Sentry:** [PYTHON-FASTAPI-3](https://auxi.sentry.io/issues/7492098041/)

## Symptom
`POST /api/upload/file` → `logger=utils.s3_utils` → `PutObject` to `auxi/uploads/*` →
`An error occurred (Unauthorized) when calling the PutObject operation: Unauthorized`.
3 grouped issues, one cause: **-3** (`.jpg`) + **-4** (`.png`) = Unauthorized; **-2** = downstream `503`. Prod, since ~May 19.

## Root cause (PROVEN)
**Corrupted production R2 credential in Railway.** The prod `S3_ACCESS_KEY` was one character off the working key:
- Railway (broken): `2bfc901bbc2e040e084a36665cda9ced`
- local `.env` (works): `2bfc901bbc2e040e084a36665cda9ded`

Direct `PutObject` test against the real `auxi` bucket (same endpoint/region, only creds differ):
| Creds | default cfg (`when_supported`) | `when_required` cfg |
|---|---|---|
| **Prod (Railway)** | ❌ Unauthorized | ❌ Unauthorized |
| **Local `.env`** | ✅ SUCCESS | ✅ SUCCESS |

Only `/api/upload/file` surfaced in Sentry because it's the only actively-hit S3 write path (mobile `wardrobeService.ts` + `bodyService.ts`); all writes share one `S3Manager` singleton + the same broken creds.

## Disproven theory (initial, wrong)
botocore ≥1.36 default request checksums breaking R2. **False** — R2 accepts both `when_supported` and `when_required` (tested live). Cost a wasted code PR (#70, merged but harmless/unnecessary). Lesson: test creds against the real service **before** theorising an SDK/code cause.

## Fix (applied + verified)
- Set Railway prod `S3_ACCESS_KEY` + `S3_SECRET_KEY` to the proven-working local values (`railway variables --set`, auto-redeploy). Old key noted for rollback: `...cda9ced`.
- Deploy came up 09:42:56Z; **live `curl` upload → HTTP 201** with valid R2 key + public URL. Test object deleted.

## Loose ends
- PR #70 (`when_required` checksum config) merged before I could close it — harmless (valid R2 setting), but not the fix. Commented on the PR with the real cause.
- The corrupted Railway key likely came from a manual paste/typo; consider how prod secrets are set to avoid recurrence.

## Open questions
- Why did prod and local diverge by one char? (typo on a manual Railway edit vs an intended separate prod token that got mangled.)
- Confirm PYTHON-FASTAPI-2/3/4 stop firing over the next hours (passive confirmation).
