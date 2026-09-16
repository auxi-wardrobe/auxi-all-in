# Missing item images in wardrobe — root cause (Black Ballerina Flats + 93 others)

**Date:** 2026-09-16 · **Reported:** "Black Ballerina Flats — món này bị mất hình trong tủ đồ user"
**Status:** Root cause CONFIRMED (live evidence, prod). Not a one-item bug — **94 of 196 catalog items (48%) are affected.**

## TL;DR

`Black Ballerina Flats` (`SYS_SH_FLT_BLK_REG_01`) has an `image_png` pointing at an R2 object that **does not exist (HTTP 404)**. The client prefers `image_png` over `image_url`, so it loads a dead URL. `LoadableRemoteImage` treats `onError` as "loaded", hides the skeleton and renders an empty `<Image>` — **no error state, no fallback**. Result: a blank tile.

The original photo (`image_url`) is **alive for all 94 broken items**. The data is recoverable without re-running background removal.

## Evidence

Catalog row (prod, `GET /api/wardrobe/common-items` — unauthenticated):

```json
{
  "id": "49d18bf9-8d96-4e3c-af9f-76f91b043e50",
  "human_readable_id": "SYS_SH_FLT_BLK_REG_01",
  "name": "Black Ballerina Flats",
  "category": "shoes",
  "image_url":    ".../uploads/e7b1f434e4b74998bd1b72f690ec3576.png",
  "image_png":    ".../processed/4233567458c7468397a12d42adbf3230.png",
  "image_studio": null,
  "beautify_status": "none",
  "is_deleted": false
}
```

Live object check against `https://pub-3f31fc6ccb6e427bb12afe09359a1692.r2.dev`:

| URL | HTTP |
|---|---|
| `uploads/e7b1f434e4b74998bd1b72f690ec3576.png` (image_url) | **206** ✅ |
| `processed/4233567458c7468397a12d42adbf3230.png` (image_png) | **404** ❌ |

Swept the whole catalog (196 items, one ranged GET each against the URL the client would actually pick):

| Result | Count |
|---|---|
| Resolves (206) | 102 |
| **Dead (404)** | **94** |
| Dead items whose picked field was `image_png` | 94 / 94 (100%) |
| Dead items whose `image_url` fallback is alive | **94 / 94 (100%)** |

Field distribution: 162 items carry `image_png`, 0 carry `image_studio`, all 196 carry `image_url`.
Of the 162 `image_png` values, **94 are dead, 68 are alive** — same bucket, same `processed/` prefix, interleaved by `created_at` (both groups span 2026-03-08 → 2026-05-07). So this is **not** a bulk delete, a prefix-level ACL change, or a date-bounded purge — it is per-object.

Breakdown of the 94 by category: top 33, bottom 18, outerwear 13, shoes 12, accessory 12, onepiece 6.

## Root cause

**Primary (data / backend):** rows carry an `image_png` URL for a `processed/` object that was never persisted. The background-removal path records the destination URL on the item without verifying the upload succeeded, so a failed/partial bg-removal leaves a permanently dangling pointer. 58% of the rows that ever got an `image_png` are dangling.

**Secondary (client, turns a 404 into a blank tile):**

1. `auxi/src/utils/url.ts` → `resolveItemImage()` picks `image_studio ?? image_png ?? image_url` **statically**. It has no knowledge of whether the winner actually loads, so a dead `image_png` permanently shadows a healthy `image_url`.
2. `auxi/src/components/features/LoadableRemoteImage.tsx:58` — `onError={handleImageSettled}` is the *same handler* as `onLoadEnd`. An error is recorded as a successful load: `complete: true` → skeleton unmounts → the `<Image>` renders at full opacity with nothing in it. There is **no error state**, so `WardrobeGridTile`'s `common.no_image` fallback never fires (it only covers `imageUrl === undefined`, i.e. no URL at all — not a URL that 404s).

Blast radius of (2) is app-wide, not just the wardrobe grid — the same resolver/component pair backs Home, Today's Picks, outfit cards, discovery, canvas item picker, capsule and item detail (30+ call sites reference `resolveItemImage`/`image_png`).

## Fix

**1. Data repair (backend — restores all 94 items with no app release).** For every common item whose `image_png` object is absent in R2, set `image_png = NULL`. The client then falls back to `image_url`, which is verified alive for all 94. Then re-run bg-removal for those items as a follow-up (quality, not availability).
Full list of the 94 (hrid, name, category, item id, dead key) is appended below.

**2. Propagate to cloned user items.** `POST /api/wardrobe/common-items/{id}/clone` copies catalog fields into the user's wardrobe, so any user who picked one of these 94 carries the same dangling `image_png`. The repair must cover user-owned rows too, not just `owner_id = 'SYSTEM'`. *(Unverified — needs DB access; see open questions.)*

**3. Stop creating dangling pointers (backend).** Write `image_png` only after the R2 PUT is confirmed. On failure leave it `NULL` — `image_url` already renders correctly.

**4. Client hardening (auxi — do this regardless; it prevents the whole class).**
   - `LoadableRemoteImage`: separate `onError` from `onLoadEnd`, add an `error` state, and expose an `onError` / fallback-source prop.
   - `resolveItemImage`: return the *ordered candidate list*, and have the image component walk to the next candidate on error (`image_studio` → `image_png` → `image_url`) before giving up to the `common.no_image` placeholder.
   - Add a regression test: a URL that 404s must render the placeholder, never a blank tile.

Ordering: **1 is the unblock** (minutes, no release). 4 is the durable fix. 3 stops the bleeding.

## Repository access note

`wardrobe-backend` is private and cannot be attached to this session (cross-owner add refused), and `auxi-mobile` is only readable, not pushable. All of the above was established against the **live production API + R2 endpoint**, read-only. The code fixes need to be applied in their own repos.

## Unresolved questions

1. How many *user-owned* items (not catalog) carry a dangling `image_png`? Needs DB — `SELECT count(*) FROM items WHERE image_png IS NOT NULL` cross-checked against R2.
2. Why did bg-removal drop 94 objects? Silent exception, R2 write throttling, or a bucket/prefix change mid-migration? Backend logs for 2026-03-08 → 2026-05-07 would say.
3. Were the 68 surviving `processed/` objects written by a different code path or a later retry?
4. Is there any R2 lifecycle rule on the `processed/` prefix? (Per-object, interleaved dates argue against it, but worth ruling out.)

---

## Appendix — the 94 broken catalog items

| # | human_readable_id | name | category | item id | dead image_png key |
|---|---|---|---|---|---|
| 1 | `SYS_AC_BAG_BLK_BCK_01` | Black BAG (BCK) | accessory | `93275020-5c4f-4658-9856-f11358781dce` | `processed/de84dfa03cef405a9333b4e50220f4af.png` |
| 2 | `SYS_AC_BAG_BLK_STR_01` | Structured Leather Bag · Black | accessory | `be3a211c-94b0-4090-9d95-29eb7e7f3258` | `processed/e5a3d48006b64ccaa0b1bfa67e0ce40b.png` |
| 3 | `SYS_AC_BAG_BLK_TLR_01` | Black BAG (SHO) | accessory | `1bb80df2-4f29-4c77-a8ca-1bb11bf673db` | `processed/9c82621bf2af4faab292b53844fdce3a.png` |
| 4 | `SYS_AC_BAG_BRN_REG_02` | BRN BAG (CRO) | accessory | `1c9d6faf-21e9-4fd2-8911-16e1df34208f` | `processed/0f27ee4e79b748b09c8fa30dda5c4194.png` |
| 5 | `SYS_AC_BAG_BRN_TLR_01` | BRN BAG (BRF) | accessory | `4839f532-b1fe-4f73-94bb-dad883ee5bf6` | `processed/06a848d3c47046579e154e381b7d8a91.png` |
| 6 | `SYS_AC_BAG_WHT_OVS_01` | White BAG (TOT) | accessory | `4c43d40e-e718-470e-9f2f-055be427c63b` | `processed/99c863463bde4794bee29639d105b732.png` |
| 7 | `SYS_AC_BLT_BLK_REG_01` | Black BLT (LEA) | accessory | `0b5e803d-505b-4ba9-b779-bfd30c8683f3` | `processed/a36c75e9fe4a40e8b1ef0ba393b7577a.png` |
| 8 | `SYS_AC_CAP_NVY_REG_01` | Navy CAP (BAS) | accessory | `4a23fb09-8756-4eae-8d71-df8c54d639de` | `processed/0fbac98c9dde41f1af2bf0ee9a95da73.png` |
| 9 | `SYS_AC_GLS_BLK_REG_02` | Black GLS (WAY) | accessory | `11abb3c6-a8af-4c13-a81d-e20ef3ef4c36` | `processed/a80ac7efd63e4942a9ab7d480bfc5e10.png` |
| 10 | `SYS_AC_HAT_GRY_REG_01` | Grey HAT (KNT) | accessory | `ab3a8a47-b84c-4ed6-86cd-b8bc87615d8e` | `processed/fbcb0e74615645c4a9e10f654895934a.png` |
| 11 | `SYS_AC_SCF_BGE_REG_01` | CHK SCF (WOL) | accessory | `eace5c72-44bb-421a-aecf-a1c624c9abbc` | `processed/05a62a23da054e278d5c704f4ccd8f8f.png` |
| 12 | `SYS_L3_WST_BGE_REG_01` | BGE HAR (Regular) | accessory | `4a9fb2f1-4aa7-48e3-a019-bf737c0e37c1` | `processed/a76ac87f6e304658bbbe41da0d76ef70.png` |
| 13 | `SYS_BT_CHI_OLV_RLX_01` | Relaxed Chinos · Olive | bottom | `9e9faa41-82e1-4869-b084-e4137341691e` | `processed/3f1c8f6f8a154f4c9fdb01bac7da5184.png` |
| 14 | `SYS_BT_CHI_TAN_SLM_01` | BGE CHI (Slim) | bottom | `31ef9a5d-22de-47d1-80b0-2a6ee42dd73f` | `processed/db30284610fa47f490b21fe47fc1fbba.png` |
| 15 | `SYS_BT_JNS_BLU_REG_01` | BLU Jeans (STR) | bottom | `f855d368-0b5f-4922-a33a-b5ad88ed8379` | `processed/c151623a1efd465d90eb2712efeaea0c.png` |
| 16 | `SYS_BT_JNS_LBL_OVS_01` | LBL Jeans (Loose) | bottom | `cd4470d7-25dd-4f2d-9dcf-fab3fba443a0` | `processed/bdbb8c3e633b47fab01aac9e7b3e0ef8.png` |
| 17 | `SYS_BT_SHO_BLK_DNM_01` | Denim Shorts · Black | bottom | `d180cb65-1208-4362-bd7b-d498f44b2a56` | `processed/686cdcbdf0aa40f38b7621f1cb243afd.png` |
| 18 | `SYS_BT_SHO_GRY_REG_01` | Grey SHO (SWT) | bottom | `71704258-5d4c-41f7-87fd-2e4da3cb3bd5` | `processed/ad5c765a9e3b4599a219670f4d159c16.png` |
| 19 | `SYS_BT_SHO_NVY_REG_01` | Navy SHO (Regular) | bottom | `5f8aab76-0a58-4227-874e-5b708e826ba9` | `processed/6e0825c55ba148e7ab1195b6cb22d686.png` |
| 20 | `SYS_BT_SKR_BLU_MDI_01` | Midi Skirt · Cobalt | bottom | `db6c5489-2234-4814-beb1-06e77389336c` | `processed/78b12da474154487ba402983716b1a18.png` |
| 21 | `SYS_BT_SKR_TAN_TLR_01` | BGE SKR (PLT) | bottom | `96bc605f-8f7d-4eae-aa0e-5b7806522c97` | `processed/71e9b42c9d79473aa2731175b720f0e6.png` |
| 22 | `SYS_BT_TRS_BLK_WID_02` | Wide Trousers · Black | bottom | `0f30f9f1-9c12-45d9-97cb-ee581c5e4ef0` | `processed/4f1dd201a8784b0baa33ec122f60e036.png` |
| 23 | `SYS_BT_TRS_BRN_WID_02` | Wide Trousers · Rust | bottom | `7b1c5424-b7b4-44e5-846a-b1dc8558c17c` | `processed/cc625fb6f9b8433880cd12c9272a14f0.png` |
| 24 | `SYS_BT_TRS_CAM_STR_01` | Straight Trousers · Camel | bottom | `73615425-0a87-4a3f-a2e6-6b5adb9e7c28` | `processed/7ed26e3d85414e0cb3c27b817a6ec828.png` |
| 25 | `SYS_BT_TRS_CAM_WID_01` | Wide Trousers · Camel | bottom | `5ee3fdc3-7590-4464-965d-7f2ac46b88f1` | `processed/7505944e07b54313baa11a106a98d864.png` |
| 26 | `SYS_BT_TRS_GRY_TLR_01` | Grey TRS (Tailored) | bottom | `4b741d30-70c4-43ca-837f-21faf252d6f4` | `processed/a56790d8b93e4d37833d5567aa72d107.png` |
| 27 | `SYS_BT_TRS_MUL_LIN_01` | Linen Trousers · Mauve | bottom | `70f902b0-9bd2-4e9c-9790-19b940b7fea9` | `processed/bc9a1d8c5de843eaad9766d03b8297a9.png` |
| 28 | `SYS_BT_TRS_MUS_STR_01` | Straight Trousers · Mustard | bottom | `6367c26f-e6eb-4c04-b4f7-10ab75378a9f` | `processed/e44e1173aa354fb6b52477687f7b0bfa.png` |
| 29 | `SYS_BT_TRS_OLV_STR_01` | Straight Trousers · Olive | bottom | `006caea9-ac95-4e5a-a42b-855e566b7d15` | `processed/f533c2ebf9694ecd8d57be3cc75486fa.png` |
| 30 | `SYS_BT_TRS_WHT_LIN_01` | Linen Trousers · White | bottom | `613e62ba-cd5a-404f-9ca8-ca54d3aa69fd` | `processed/07302cd886db4141b71454129068d13e.png` |
| 31 | `SYS_FB_DRS_BLK_REG_01` | Black DRS (MIN) | onepiece | `14de61b4-d67e-4c35-b176-94ed96755a4e` | `processed/5d3fbd9596bc41a2a33667a9c4c25054.png` |
| 32 | `SYS_FB_DRS_BLK_TLR_01` | Black DRS (BLZ) | onepiece | `3586cfd0-1faf-4f97-b122-565eedf66a01` | `processed/0ee5f224d8d74e5eaad09290dc4a28f0.png` |
| 33 | `SYS_FB_DRS_BRN_SLM_01` | BRN DRS (KNT) | onepiece | `c199b473-a484-404d-a262-8105d3ad7fab` | `processed/4e62d6553a7c427581dd89a661705409.png` |
| 34 | `SYS_FB_DRS_RED_REG_01` | Red DRS (WRP) | onepiece | `6e3e93c5-fcdf-4a2e-a45d-e93f287800a2` | `processed/398dbe6fc9af48dda68a5f8d8e4ffaec.png` |
| 35 | `SYS_FB_DRS_WHT_REG_01` | White DRS (Regular) | onepiece | `27f73a3b-1b31-453d-b74c-6473fa73bca2` | `processed/e238a8bd9e9343d7b9637d05fa879979.png` |
| 36 | `SYS_FB_JMP_BLK_REG_01` | Black Wide-Leg Jumpsuit | onepiece | `ea54c9c9-bb73-406b-bea6-0b7af46adb66` | `processed/8f24235dde5847bca747292238ce5954.png` |
| 37 | `SYS_BT_LEA_BLK_STR_01` | Leather Trousers · Black | outerwear | `8f9a47ac-5d3d-44f2-996a-d7986ebdcb65` | `processed/546b467410e64b8387149cf73f900918.png` |
| 38 | `SYS_L2_CRD_BLK_OVS_01` | Black CRD (CRP) | outerwear | `05d986fa-79f7-4c36-8430-17990125063a` | `processed/42f9c81d488149dba77035589902a52b.png` |
| 39 | `SYS_L3_BLZ_GRY_TLR_01` | Grey BLZ (Tailored) | outerwear | `c98894af-48d6-43e1-834e-e9ac2b402864` | `processed/e60df7e96c6c44e48626d222a56484b3.png` |
| 40 | `SYS_L3_BLZ_NVY_REG_01` | Navy BLZ (Regular) | outerwear | `b4ccdd3e-f30a-4c81-81a3-59a4d6d9f016` | `processed/2965a5c8f66e4781a94ce3c53dbd26e4.png` |
| 41 | `SYS_L3_BLZ_RED_OVS_01` | Oversized Blazer · Deep Red | outerwear | `23f2e4cd-6039-4005-a2cb-1c4ea5627f1d` | `processed/3561ad23be3f430a82cb8d64b8fee47e.png` |
| 42 | `SYS_L3_BLZ_YLW_REG_01` | Blazer · Pale Yellow | outerwear | `9dddcd08-54bd-4e89-b039-d95563da7470` | `processed/8f2f287676be4a75a06939fb290dcf7f.png` |
| 43 | `SYS_L3_BOM_OLV_REG_01` | GRN BOM (PUF) | outerwear | `ae345f45-0e32-42e2-b98c-c6a43ed75fd9` | `processed/d991417c543147a7b7bff0844c4b1a90.png` |
| 44 | `SYS_L3_CRD_TAN_LNG_01` | Longline Cardigan · Beige | outerwear | `fe7dfb53-1388-4948-98ac-4f12cb37ef7d` | `processed/42d8efd0aaa549e0b6b7cf83e6da4940.png` |
| 45 | `SYS_L3_DNM_BLU_OVS_01` | Light-Wash Denim Jacket | outerwear | `39d2986a-a4c2-4f60-8816-3eeacaacb695` | `processed/8cf9d5d8aed3475099d2945fc5144ffb.png` |
| 46 | `SYS_L3_LTR_BLK_REG_01` | Black LTR (Regular) | outerwear | `99d2e5fe-0e0e-444d-a7f7-4e49935fe1aa` | `processed/cc2b5a17433d4b2aa5fd44026789b5f2.png` |
| 47 | `SYS_L3_PUF_BLK_REG_01` | Black PUF (Regular) | outerwear | `b3217362-a1d0-43c6-b65c-9add3e68d00c` | `processed/7bb69dd1adfa4d9490f809aa996dac5b.png` |
| 48 | `SYS_L3_VES_BLK_REG_01` | Black VES (PUF) | outerwear | `75ae5119-d3b8-4db4-bc67-392d3bcba86c` | `processed/1bb8dc0bdc894406b545b580c1f8bcc4.png` |
| 49 | `SYS_L3_WND_BLK_REG_01` | Black WND (SPT) | outerwear | `7ad2dc45-62cb-4b75-9766-dd79cf7e9642` | `processed/b538ed4c80fa40b881ada6375af6c499.png` |
| 50 | `SYS_SH_BOT_BLK_REG_01` | Black BOT (CHE) | shoes | `6b38997a-2363-49e1-a1ef-098c471a2403` | `processed/e40032c188224f4ab5ec60f112686225.png` |
| 51 | `SYS_SH_BOT_MRN_ANK_01` | Ankle Boots · Deep Red | shoes | `5a87e195-71ef-414d-b095-ba648b8b09a6` | `processed/a25f60a6645a4aa0bc7ed49dfe4bac35.png` |
| 52 | `SYS_SH_BOT_WHT_REG_01` | White BOT (HEL) | shoes | `d7cd122b-f9ea-448f-a6dd-c0fd899f7e79` | `processed/5170fd02b13e4f2280f375d01afb9807.png` |
| 53 | `SYS_SH_FLT_BGE_REG_01` | Ballet Flats · Nude | shoes | `8d8fad9c-74fa-4337-a05e-5259da6562cf` | `processed/2f9ad7e796e9443780e7ab9cb969ad0b.png` |
| 54 | `SYS_SH_FLT_BLK_REG_01` | Black Ballerina Flats | shoes | `49d18bf9-8d96-4e3c-af9f-76f91b043e50` | `processed/4233567458c7468397a12d42adbf3230.png` |
| 55 | `SYS_SH_LOA_BLK_REG_01` | Black LOA (CHK) | shoes | `40462d92-df8e-4f67-b901-333bf344e0f5` | `processed/2607053ab2f14552bde63ca4102a76d9.png` |
| 56 | `SYS_SH_LOA_BLK_REG_02` | Black LOA (LEA) | shoes | `9c8ab072-f00b-4397-8f49-467212bee1cb` | `processed/1bc76ce04bef47b99630f64178142e9c.png` |
| 57 | `SYS_SH_LOA_BLU_LEA_01` | Loafers · Cobalt | shoes | `96db2453-f580-404f-85bc-7ed781d6b216` | `processed/2a65e62e786e4abba6610f4c73830b44.png` |
| 58 | `SYS_SH_LOA_TAN_LEA_01` | Loafers · Tan | shoes | `2a1238ee-fb1a-42b6-9ded-48bfcd42d776` | `processed/88b50ea4874d44709529da01e38b7c6c.png` |
| 59 | `SYS_SH_LOA_TAN_SDE_01` | Suede Loafers · Tan | shoes | `322b6cec-0550-4797-a6e3-a3c435943354` | `processed/b2d35869ab4b42aeada40c8c86f217dc.png` |
| 60 | `SYS_SH_SLD_BLK_REG_02` | Black SLD (RUB) | shoes | `f96708f8-b77e-463a-a85a-cf0b789b5d1c` | `processed/ba2cda2089604f23959da5d2d236d67b.png` |
| 61 | `SYS_SH_SNK_BLK_REG_01` | Black SNK (HIG) | shoes | `44f12370-0843-481d-8cc0-c7dba86ef925` | `processed/091cae1bf507427f822b53555b4c4f5d.png` |
| 62 | `SYS_BT_JOG_BLK_RLX_01` | Jogger Pants · Black | top | `36e2f917-8b00-47f8-ac64-3f8858c36bf6` | `processed/dae13dda083a48cc9873eaf57085e8b5.png` |
| 63 | `SYS_BT_TRK_NVY_RLX_01` | Track Pants · Navy | top | `a5e15c86-fbb3-49ab-bafe-2c91f01c70ca` | `processed/afdf609bf2164baab0fa7a9e5040795f.png` |
| 64 | `SYS_L1_CAM_CAM_SKN_01` | Blush Pink Satin Camisole | top | `2431b135-91fd-4ea0-8847-ae1d6f96fa67` | `processed/28dc94c0ffb3428d90e6145c50dd2552.png` |
| 65 | `SYS_L1_CAM_WHT_REG_01` | White CAM (Regular) | top | `58538e8f-5d44-4cac-abb4-74a6701ed8f5` | `processed/f826dad69b154b2aabdeae60f84b8c19.png` |
| 66 | `SYS_L1_TEE_BGE_REG_01` | STR T-shirt (Regular) | top | `ef7b65e3-8366-4caf-b74a-8fbb497b5a7c` | `processed/39f2d1d70c7044e5b3ad718ed0cafcbf.png` |
| 67 | `SYS_L1_TEE_BLK_OVS_01` | Black T-shirt (Oversize) | top | `49e03427-a48e-4a51-accf-975be7ec5005` | `processed/f76e223eb60b49d4bae433a56ceb5f45.png` |
| 68 | `SYS_L1_TEE_GRY_REG_02` | Grey T-shirt (Regular) | top | `9e6985a5-e0b7-40f7-bd87-5ea4ebc968ba` | `processed/446bf7bfca614542afc4901a1cc9280f.png` |
| 69 | `SYS_L1_TEE_WHT_OVS_01` | White T-shirt (Oversize) | top | `4b75b47c-e283-4bc7-9c81-84a09b1f6acc` | `processed/803d41e8e0a24f86be4b88842b6aab06.png` |
| 70 | `SYS_L1_TNK_WHT_REG_01` | White TNK (Regular) | top | `a2178a15-1e83-4d90-9799-a0b4abad331a` | `processed/70a640403dc8470a9a17271be340a2d6.png` |
| 71 | `SYS_L2_BDY_BLK_SLM_01` | Black BDY (SKN) | top | `a44b075f-df03-4f4d-b8f1-20dd53619e22` | `processed/0ea2876374f24b668abdfb4f68f217f2.png` |
| 72 | `SYS_L2_BLS_BGE_REG_01` | BGE BLS (Regular) | top | `3b3085a7-cf74-4610-855e-52613fae7afb` | `processed/fde59ba15701487d98fc1c0603caa968.png` |
| 73 | `SYS_L2_BLS_BLK_REG_01` | Black PEP (Regular) | top | `15cf9b2d-67c7-4f0e-8a73-58267709bf8d` | `processed/d83f6b8d0adf4bacafa2c8b1f2c53585.png` |
| 74 | `SYS_L2_BLS_BLU_STR_01` | Structured Blouse · Cobalt | top | `818bc88d-9a69-4c2a-8455-9cc4ed761795` | `processed/b0c83bf40f4248b3af4d21a1d9540d37.png` |
| 75 | `SYS_L2_BLS_WHT_REG_01` | White Off-Shoulder Ruched Top | top | `141692e3-2576-4fef-95a3-a21519aeec48` | `processed/4755d7bae7534cc39ee193c29c646233.png` |
| 76 | `SYS_L2_DRP_MUS_REG_01` | Draped Top · Mauve | top | `fc3929ea-3689-4447-a3c2-aa70a98299b0` | `processed/35a2d7021e31429f9fb76f40d9157ae5.png` |
| 77 | `SYS_L2_HOD_BLK_OVS_01` | Black HOD (Oversize) | top | `78681088-e18d-456e-b136-5ed088a75a74` | `processed/bdbe5b6b506244afbabba706965f4f64.png` |
| 78 | `SYS_L2_KNT_CAM_REG_01` | Knit Sweater · Camel | top | `d74302e7-6d78-4e9c-ae02-e0dcf2dba04a` | `processed/ec266364af0c4193b046688342bc369d.png` |
| 79 | `SYS_L2_KNT_OLV_REG_01` | Knit Sweater · Sage | top | `eb519c9f-6cbe-48a0-96a4-886293ea6914` | `processed/3838bff1fa9946299e2fdfd7cf0d5c7a.png` |
| 80 | `SYS_L2_LIN_BGE_OVS_01` | BGE Linen (Loose) | top | `53655bca-3a03-435e-b4df-2eeb6678a1eb` | `processed/197f0336fe04463d9f69aa050e479bbb.png` |
| 81 | `SYS_L2_LIN_MUL_REG_01` | Linen Shirt · Dusty Rose | top | `fe938dec-9492-41b4-9988-5a7873b151fa` | `processed/ad08acf7ef6e466fbf66b762df9f9592.png` |
| 82 | `SYS_L2_SHR_IND_REG_01` | Indigo Dress Shirt (Regular) | top | `7b7c2a22-2dfe-4aac-8487-2a54b7ba90b3` | `processed/382c4672d57e4c17ac6c9c1fbdd79a6c.png` |
| 83 | `SYS_L2_SHR_MUS_OVS_01` | Oversized Shirt · Mustard | top | `5406abc9-5b77-4e3e-8562-a2ebe6aca2a6` | `processed/a2dc5c55c81a4eeba41de9247e166dd0.png` |
| 84 | `SYS_L2_SHR_WHT_REG_01` | White Shirt (Regular) | top | `741e8642-1181-435e-a0d3-e7d7ddf45b04` | `processed/b3a549eaed2b4a71a26b76bc2a8d38b0.png` |
| 85 | `SYS_L2_SHR_WHT_SLM_01` | White Shirt (Slim) | top | `847638b4-f2f5-4df1-b5b1-e87c45aa9655` | `processed/b9f0c1c3e32d4aa4a4372176b0a8a7a2.png` |
| 86 | `SYS_L2_SWT_NVY_REG_01` | Navy Sweater (Regular) | top | `45700cbf-d7db-453c-bc8f-9c70da1a7e11` | `processed/3344e7c722544b84b98fd24271426739.png` |
| 87 | `SYS_L2_TEE_BLK_REG_01` | Black T-shirt (Regular) | top | `74a5d431-65ce-4bb5-8c34-d31115caf385` | `processed/f03cb49f2b304c4d925af8ce1817c79f.png` |
| 88 | `SYS_L2_TEE_WHT_REG_01` | White T-shirt (Regular) | top | `cfdb520c-55d3-4350-bb3f-45c0a19d4180` | `processed/4a02f72f50134bf3acaaffeb9e5f9fff.png` |
| 89 | `SYS_L2_TRT_RED_SLM_01` | Turtleneck · Deep Red | top | `cfa3bfef-6221-42b9-98cf-23228b37b7e5` | `processed/c9cc5dba62ac438789917c7bf85e34a7.png` |
| 90 | `SYS_L2_VST_MUS_KNT_01` | Knit Vest · Mustard | top | `76b46b4f-6987-4a60-912f-425c3fcd5fd9` | `processed/df1c0ba2ab9545b196c94cb6c7593757.png` |
| 91 | `SYS_L3_HOD_GRY_REG_01` | Grey ZHO (Regular) | top | `7408ad7e-6363-49e0-bc5d-0626daee53dd` | `processed/2aca0dc449a246339075ed876e6b1756.png` |
| 92 | `SYS_SH_FRM_BLK_DRB_01` | Derby Shoes · Black | top | `c221ede4-dec9-425d-83c5-a6d65618ecda` | `processed/698fbf1e69fb4437a446d4c98bc62256.png` |
| 93 | `SYS_SH_FRM_BRN_REG_01` | BRN FRM (STR) | top | `e1171095-c78f-4f93-984b-77eee99991b3` | `processed/95c08362793c4280b7eef8667738f4cd.png` |
| 94 | `SYS_SH_TEE_RED_OVS_01` | Red VAR (Oversize) | top | `f926f73b-30cc-4015-bf87-24108e44f674` | `processed/3e0887aabce6485291b60b3ccd715c10.png` |

---

# Follow-up (2026-09-16) — "ảnh gốc trong admin đã tách nền rồi, chỉ lấy ảnh gốc được không?"

**Verdict: đúng cho catalog, SAI nếu áp dụng toàn cục.** Bỏ `image_png` trên client sẽ sửa 94 món catalog và đồng thời làm hỏng mọi món do user tự chụp.

## Kiểm chứng: ảnh gốc catalog đã tách nền chưa?

Tải toàn bộ 196 `image_url` của catalog, đọc alpha channel (Pillow):

| Kết quả | Count |
|---|---|
| PNG mode RGBA (có alpha channel) | **196 / 196** |
| Nền thực sự trong suốt (>5% pixel alpha=0) | **194 / 196** |
| Đặc (alpha toàn 255) | **2** |

Tỉ lệ pixel trong suốt: min 0.000 · median **0.706** · max 0.991. Không có món nào rơi vào vùng 1–5% → phân tách nhị phân rõ ràng, không mơ hồ.

**Người dùng nói đúng: 194/196 ảnh gốc catalog đã tách nền sẵn.**

## Kiểm chứng mạnh hơn: `image_png` có đóng góp gì không?

Tải 68 ảnh `processed/` còn sống, so pixel-by-pixel với `image_url` tương ứng:

| Kết quả | Count |
|---|---|
| **Giống hệt từng pixel** với ảnh gốc | **67 / 68** |
| Cùng kích thước | 68 / 68 |
| Tách nền chặt hơn ảnh gốc | 1 |
| Tách nền tệ hơn ảnh gốc | 0 |

Cộng với 94 cái đã chết: **161 trong 162 giá trị `image_png` của catalog là vô dụng** — hoặc trỏ vào object không tồn tại, hoặc là bản sao y hệt ảnh gốc. `image_png` chỉ mang giá trị thật cho đúng **1** món.

## 2 ngoại lệ — đều nằm trên prefix legacy `common_items/`, không phải `uploads/`

| hrid | name | image_url prefix | gốc | image_png | Hệ quả nếu chỉ dùng ảnh gốc |
|---|---|---|---|---|---|
| `SYS_AC_BLT_BLK_WID_01` | Wide Statement Belt | `common_items/` | **đặc** | 206, cutout thật (83.6% trong suốt) | **regress** — mất tách nền |
| `SYS_AC_BAG_BLK_BCK_01` | Black BAG (BCK) | `common_items/` | **đặc** | 404 | cải thiện (trắng → có ảnh, nhưng còn nền) |

Cross-tab sạch tuyệt đối:

```
   1  image_url_prefix=common_items  image_png=206     original=OPAQUE
   1  image_url_prefix=common_items  image_png=404     original=OPAQUE
  67  image_url_prefix=uploads       image_png=206     original=cutout
  93  image_url_prefix=uploads       image_png=404     original=cutout
  34  image_url_prefix=uploads       image_png=no_png  original=cutout
```

Mọi món trên `uploads/` đều đã cutout; chỉ 2 món legacy `common_items/` là chưa.

## Tại sao KHÔNG được bỏ `image_png` trên client

Item do user tự chụp đi đường khác (xác nhận trong `wardrobeService.uploadWardrobeItem` + OpenAI spec prod):

```
POST /api/upload/            → ảnh RAW từ camera, lưu vào uploads/  → trả về image_url
POST /api/wardrobe/items/ai-enhanced → enqueue AI processing (tách nền + auto-tag)
                                      → sinh processed/…  → image_png
```

Với item của user, **`image_url` là ảnh chụp thô còn nguyên nền phòng ngủ/sàn nhà**; `image_png` mới là bản đã tách. Cờ `is_preparing` tồn tại chính xác để che giai đoạn này. Bỏ `image_png` toàn cục = mọi item user tự thêm hiện ảnh thô. Đó là regression nặng hơn 94 tile trắng rất nhiều.

**Điểm mấu chốt:** catalog và user-item dùng CHUNG prefix `uploads/`, vì admin upload qua đúng endpoint `/api/upload/` — chỉ khác là admin upload file đã cutout sẵn. Nên **không thể nhìn URL mà biết `image_url` đã tách nền hay chưa**. Chỉ phân biệt được bằng alpha channel hoặc bằng `owner_id == 'SYSTEM'` / `is_common_item`.

## Kết luận — sửa thế nào

Giữ nguyên 4 bước ở phần trên, không đổi. Bằng chứng mới chỉ làm bước 1 và 4 mạnh hơn:

- **Bước 1 (data, backend) — giờ an toàn hơn dự kiến.** `UPDATE ... SET image_png = NULL` cho catalog item có object chết: fallback về `image_url` đã cutout sẵn → **chất lượng hiển thị không giảm chút nào** cho 93/94 món trên `uploads/`. Có thể mở rộng: null luôn 67 cái identical để dọn con trỏ thừa. Chừa `SYS_AC_BLT_BLK_WID_01`.
- **Bước 4 (client) — đúng cho CẢ HAI loại item**, đó là lý do nên làm nó thay vì đổi precedence:
  - catalog có `image_png` chết → rơi về `image_url` đã cutout → hoàn hảo
  - item user có `image_png` chết → rơi về ảnh thô → không đẹp, nhưng hơn hẳn tile trắng
- **Thêm:** 2 món legacy `common_items/` cần admin upload lại bản đã cutout vào `image_url`.

## Câu hỏi còn treo (bổ sung)

5. Có bao nhiêu item **của user** mà `image_url` cũng đã cutout sẵn (import-from-web có thể trả PNG trong suốt)? Ảnh hưởng tới việc có dám nới bước 1 sang row user-owned hay không.
6. Vì sao 67 object `processed/` lại là bản sao y hệt input? Pipeline tách nền có phát hiện "đã có alpha, bỏ qua" rồi vẫn ghi ra một copy không — nếu vậy đó là lãng phí storage + là đường dẫn nghi ngờ số 1 cho 94 lần ghi hụt.

---

# Repair script (2026-09-16)

`scripts/repair-dangling-image-png.py` — nulls `image_png` on catalog items whose R2 object is gone.

Blocked on credentials, not on knowledge: `PATCH /api/admin/common-items/{id}` requires an admin bearer
token, and this session has none. Verified against prod with the exact intended payload — returns
`401 {"error":"Unauthorized","message":"Missing authorization token"}`, nothing was modified.

```bash
python3 scripts/repair-dangling-image-png.py                      # dry run, touches nothing
ADMIN_TOKEN=<jwt> python3 scripts/repair-dangling-image-png.py --apply
```

Design notes:
- Re-derives the broken set live each run (fetch catalog → ranged-GET every `image_png`) instead of
  trusting a baked-in id list, so it stays correct as the catalog drifts and is safe to re-run.
- Only a literal 404 counts as "object gone". 403 / 5xx / throttling raise instead of silently
  nulling a row — absence of evidence is not evidence of absence.
- `SYS_AC_BAG_BLK_BCK_01` is excluded by default: it is the one dangling item whose `image_url` is
  NOT background-removed, so clearing it trades a blank tile for a garment on an opaque background.
  Pass `--include-opaque` to clear it too.
- Sends an explicit User-Agent — Cloudflare fronts the public R2 bucket and 403s `Python-urllib/*`,
  which would otherwise be indistinguishable from a real permission error.

Dry run against prod, 2026-09-16: 196 items · 162 carry `image_png` · **94 dangling** · 93 would be
cleared · 1 skipped as opaque-original.
