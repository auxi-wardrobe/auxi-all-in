# Delete account → re-register → wardrobe items have no image

**Date:** 2026-09-17 · **Repo:** `auxi-wardrobe/auxi-backend` (+ symptom in `auxi-mobile`)
**Severity:** P0 — silent, permanent, **cross-user** destruction of shared catalog assets in R2.
**Status:** root cause confirmed by code + git history. No fix on any branch.

---

## 1. Verdict

Deleting an account (or using "Delete My Data") **deletes the SHARED common-catalog
cutout PNGs out of R2** — not just the deleting user's own blobs. Every other user who
holds a clone of those same catalog items loses their images too. The re-registered
account then re-clones the same catalog rows, gets image URLs that now 404, and the
mobile image resolver has no fallback → blank tiles.

The bug is a **stale invariant**: the storage-cleanup code was written against a
guarantee ("clones carry NULL processed blobs") that a later fix (AU-437) silently
broke, and the unit tests hard-code the old guarantee into their fixtures, so nothing
caught it.

---

## 2. Chain of causation

### (a) Onboarding clones now copy the SYSTEM item's processed blobs

`services/v05_wardrobe_clone_service.py:264-272` — landed in `a950a7e`
("fix: carry background-removed image to onboarding wardrobe clones (#169)",
**2026-08-11**):

```python
image_url=src.image_url,
# AU-437: mobile's resolveItemImage gives image_studio/image_png
# display precedence over image_url. ...
image_png=src.image_png,
image_studio=src.image_studio,
is_common_item=False,
is_cloned_from_common=True,
```

The clone stores the **same URL strings** as the SYSTEM row. No copy of the blob,
no back-reference (`cloned_from_common_item_id` is NOT set on onboarding clones —
only `wardrobe_service.py` sets it).

### (b) Those URLs live under `processed/`, which the cleanup treats as user-owned

- `services/remove_bg_service.py:119` → `s3_key = f"processed/{uuid4().hex}.png"`
- `scripts/backfill_cutout_images.py:126` → `select(WardrobeItem).where(WardrobeItem.image_png.is_(None))`
  — **no `is_common_item` filter**, so SYSTEM catalog rows were backfilled with
  `processed/…` cutouts too. (This is exactly what AU-437's "the SYSTEM source has a
  cutout ready" refers to.)

### (c) Cleanup collects them and deletes them

`services/user_data_storage_cleanup.py`:

```python
rows = db.query(
    WardrobeItem.image_url, WardrobeItem.image_png,
    WardrobeItem.image_studio, WardrobeItem.image_studio_candidate,
).filter(
    WardrobeItem.owner_id == user_id,
    WardrobeItem.is_common_item.is_(False),   # ← clones pass this filter
).all()
```

Its docstring (`:56-59`) still asserts the pre-AU-437 world:

> "Clones also have NULL processed blobs (`image_png` / `image_studio` /
> `image_studio_candidate`), so those columns naturally contribute nothing for a clone"

**False since 2026-08-11.** The `common_items/` carve-out in `_extract_storage_key`
protects `image_url` only:

```python
for marker in ("uploads/", "bodies/", "tryon/", "processed/"):
    index = path.find(marker)
    if index >= 0:
        return path[index:]
```

`https://pub-….r2.dev/processed/<uuid>.png` → key `processed/<uuid>.png` →
`s3_manager.delete_file(key)` → **shared blob gone**.

Note the query also has **no `is_deleted` filter**, so every clone the user ever
held (including soft-deleted ones) contributes keys.

### (d) Both entry points are affected

- `DELETE /api/me` (`routers/auth.py:464`) → `delete_user_account` → reuses
  `reset_user_owned_data` → same `collect_reset_storage_keys`.
- `POST /api/me/reset-preferences` (`routers/auth.py:429`) → same path.
  "Delete My Data" destroys the shared catalog exactly as hard as account deletion.

### (e) Mobile has no fallback, so it renders blank

`auxi/src/utils/url.ts:48-57`:

```ts
const source = studio ?? png ?? item.image_url;   // non-empty dead URL wins
```

Precedence is `image_studio → image_png → image_url` on **string presence**, not on
fetch success. A dead `processed/…` URL beats the perfectly alive `common_items/…`
original. `LoadableRemoteImage`'s `onError` only clears the spinner
(`src/components/features/LoadableRemoteImage.tsx:58`) — it does not fall back.
Result: empty tile.

---

## 3. Why the tests never caught it

Both suites hard-code the obsolete invariant into the clone fixture:

- `tests/test_reset_user_data.py:178-192` — `_clone_item(...)` sets
  `image_png=None, image_studio=None, image_studio_candidate=None`, docstring
  *"A cloned common item: shared catalog image_url, NULL processed blobs."*
- `tests/test_delete_account.py:217` — same `image_png=None`.

The catalog-safety assertion
(`assert not any("common_items/" in key for key in deleted_keys)`) only ever checks
the `image_url` path, which was never the vulnerable one.

---

## 4. Timeline

| Date | Commit | Event |
|---|---|---|
| 2026-07-08 | `fa17dc9` | Delete-My-Data reset + storage cleanup written — invariant TRUE at the time |
| 2026-07-09 | `7bd781a` | Reset widened to the entire wardrobe |
| 2026-07-27 | `4a6d074` | Permanent account deletion (Apple 5.1.1(v)) reuses the same cleanup |
| **2026-08-11** | **`a950a7e`** | **AU-437 copies `image_png`/`image_studio` into onboarding clones → invariant BROKEN** |
| — | — | No commit touches `user_data_storage_cleanup.py` after 2026-07-27 |

---

## 5. Blast radius

- Damage is **not scoped to the deleting user**. One deletion nukes the cutouts of
  every SYSTEM item in that user's starter wardrobe, for **all** users holding the
  same clones, plus the admin catalog itself.
- Cumulative and irreversible at the blob level — each deletion takes out more of
  the catalog.
- Loss is **silent**: `delete_reset_storage_objects` swallows every failure at
  `logger.warning` and the DB rows keep pointing at dead keys.
- Also fires on "Delete My Data", which users hit far more often than account delete.

---

## 6. Fix

### 6.1 Stop the bleeding (ship first, trivial)

In `_wardrobe_urls`, exclude clone-owned blob columns. Collect `image_png` /
`image_studio` / `image_studio_candidate` **only** for genuine uploads:

```python
WardrobeItem.is_common_item.is_(False),
WardrobeItem.is_cloned_from_common.is_(False),   # ← clones own no blobs
```

…for the processed columns, while still collecting `image_url` from everything
(the `common_items/` carve-out already makes that safe).

Belt-and-braces: make `_extract_storage_key` return `None` for any path containing
`common_items/` **before** the marker loop, and consider salting user-owned cutouts
with the owner id (`processed/{user_id}/{uuid}.png`) so ownership is provable from
the key alone.

### 6.2 Fix the tests

Change the `_clone_item` fixtures in `tests/test_reset_user_data.py` and
`tests/test_delete_account.py` to the **current** clone shape — `image_png` /
`image_studio` set to the SYSTEM source's `processed/…` URLs — and assert those
keys are NOT in `deleted_keys`. That test fails today; that is the regression test.

### 6.3 Data recovery (devops, needs prod)

The originals under `common_items/` were never touched, so cutouts are regenerable:

1. Enumerate `WardrobeItem.image_png` / `image_studio` values on SYSTEM rows
   (`is_common_item=True`); HEAD each key in R2; null the 404s.
2. Re-run `scripts/backfill_cutout_images.py` (it picks up `image_png IS NULL`) to
   regenerate from `image_url` via rembg.
3. Re-point existing clones. There is no `cloned_from_common_item_id` on onboarding
   clones, so join `clone.image_url == system.image_url` and re-copy
   `image_png`/`image_studio` from the SYSTEM row.
4. Re-run for `image_studio` separately — the backfill script only covers `image_png`.

### 6.4 Defensive (mobile, separate PR)

`resolveItemImage` picks on string presence and never recovers from a 404. Add an
`onError` fallback chain (`image_studio → image_png → image_url`) in
`LoadableRemoteImage` so a dead processed URL degrades to the with-background
original instead of a blank tile.

---

## Unresolved questions

1. How many SYSTEM `processed/` keys are already dead in prod? Needs an R2 HEAD sweep —
   determines whether this is "a few items" or the whole starter catalog.
2. How many account-deletes / Delete-My-Data calls ran since 2026-08-11? `logger.info`
   lines "permanently deleted account %s" and "reset owned data" in Railway logs give
   the count and the per-call `deleted_counts`.
3. Do SYSTEM items carry `image_studio` at all, or only `image_png`? Only the latter
   is covered by the backfill script; recovery for the former may need a new path.
4. Is `auxi-web` affected by the same resolver precedence? Not checked.
