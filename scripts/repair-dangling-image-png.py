#!/usr/bin/env python3
"""Null out `image_png` on common items whose R2 object no longer exists.

Context: ~94 of 196 catalog items carry an `image_png` pointing at a
`processed/` object that 404s. The mobile client prefers `image_png` over
`image_url`, so those items render as blank tiles. Every affected item's
`image_url` is alive AND already background-removed, so clearing `image_png`
restores the item at full quality with no app release.

See plans/reports/debugger-260916-0647-wardrobe-missing-item-images.md.

The script re-derives the broken set live on every run instead of trusting a
baked-in id list, so it stays correct as the catalog drifts and is safe to
re-run (idempotent: an item already cleared has no `image_png` to probe).

Usage:
    # 1. Dry run — prints exactly what would change, touches nothing.
    python3 scripts/repair-dangling-image-png.py

    # 2. Apply. Needs an admin bearer token.
    ADMIN_TOKEN=<jwt> python3 scripts/repair-dangling-image-png.py --apply

    # Point at a different deployment:
    API_BASE=http://localhost:5001 python3 scripts/repair-dangling-image-png.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

API_BASE = os.environ.get(
    "API_BASE", "https://wardrobe-backend-production-c8d9.up.railway.app"
).rstrip("/")
TIMEOUT = 30

# Cloudflare fronts the R2 public bucket and answers the default
# `Python-urllib/x.y` agent with a 403, which would otherwise be
# indistinguishable from a real permission error. Send an ordinary UA.
UA = "Mozilla/5.0 (compatible; auxi-image-repair/1.0)"

# Items whose `image_url` is NOT background-removed. Clearing image_png on
# these trades a blank tile for a garment on an opaque background — still an
# improvement, but flagged separately so the operator can decide. Verified
# 2026-09-16: both live on the legacy `common_items/` storage prefix.
OPAQUE_ORIGINAL_HRIDS = {"SYS_AC_BLT_BLK_WID_01", "SYS_AC_BAG_BLK_BCK_01"}


def fetch_catalog() -> list[dict]:
    req = urllib.request.Request(
        f"{API_BASE}/api/wardrobe/common-items", headers={"User-Agent": UA}
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.load(r)["items"]


def object_missing(url: str) -> bool:
    """True when the storage object behind `url` is gone.

    Uses a 1-byte ranged GET rather than HEAD: some object stores answer HEAD
    differently from GET, and a ranged GET costs the same as a HEAD while
    exercising the exact path the mobile client takes.
    """
    req = urllib.request.Request(
        url, headers={"Range": "bytes=0-0", "User-Agent": UA}
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return r.status not in (200, 206)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return True
        raise  # anything else (403, 5xx, throttling) is NOT evidence of absence
    except urllib.error.URLError as e:
        raise RuntimeError(f"probe failed for {url}: {e}") from e


def clear_image_png(item_id: str, token: str) -> None:
    req = urllib.request.Request(
        f"{API_BASE}/api/admin/common-items/{item_id}",
        data=json.dumps({"image_png": None}).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": UA,
        },
        method="PATCH",
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        if r.status != 200:
            raise RuntimeError(f"PATCH {item_id} returned {r.status}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--apply",
        action="store_true",
        help="actually PATCH. Without it the script only reports.",
    )
    ap.add_argument(
        "--include-opaque",
        action="store_true",
        help=(
            "also clear items whose image_url is not background-removed "
            f"({', '.join(sorted(OPAQUE_ORIGINAL_HRIDS))})"
        ),
    )
    args = ap.parse_args()

    items = fetch_catalog()
    candidates = [i for i in items if i.get("image_png")]
    print(f"catalog: {len(items)} items, {len(candidates)} carry image_png")

    with ThreadPoolExecutor(max_workers=12) as pool:
        missing = list(pool.map(lambda i: object_missing(i["image_png"]), candidates))

    broken = [i for i, gone in zip(candidates, missing) if gone]
    opaque = [i for i in broken if i.get("human_readable_id") in OPAQUE_ORIGINAL_HRIDS]
    targets = broken if args.include_opaque else [i for i in broken if i not in opaque]

    print(f"dangling image_png: {len(broken)}")
    for i in sorted(targets, key=lambda x: (x.get("category") or "", x["id"])):
        print(f"  {i.get('human_readable_id'):<24} {i.get('category'):<10} {i['id']}")
    if opaque:
        verb = "included" if args.include_opaque else "SKIPPED (pass --include-opaque)"
        print(f"\nimage_url not background-removed, {verb}:")
        for i in opaque:
            print(f"  {i.get('human_readable_id'):<24} {i['id']}")

    if not args.apply:
        print(f"\nDRY RUN — nothing changed. {len(targets)} item(s) would be cleared.")
        return 0

    token = os.environ.get("ADMIN_TOKEN")
    if not token:
        print("\nADMIN_TOKEN is not set — refusing to run with --apply.", file=sys.stderr)
        return 2

    failures = []
    for i in targets:
        try:
            clear_image_png(i["id"], token)
        except Exception as e:  # keep going; one bad row must not abort the sweep
            failures.append((i.get("human_readable_id"), e))
    print(f"\ncleared {len(targets) - len(failures)}/{len(targets)}")
    for hrid, err in failures:
        print(f"  FAILED {hrid}: {err}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
