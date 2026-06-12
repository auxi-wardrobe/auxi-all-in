# V05 Womenswear Dress-Exclusion Bias — Prod Blast-Radius Measurement

**Date:** 2026-05-31
**Author:** backend-dev
**Mode:** READ-ONLY prod DB (Railway `switchback.proxy.rlwy.net:17805/railway`), SELECT only.
**Status:** DONE_WITH_CONCERNS — measured cleanly, but prod is seed/test data, not organic users (see Caveats).

---

## TL;DR / Blast-radius conclusion

The bias's literal trigger is `user_gender == "W"` in `select_anchors`
(`engine_v05_layers.py:278`), where womenswear users get `W_FB_BIAS = 2.0×`
weight on FULL_BODY anchors, slicing separates out of the anchor pool once
they own ≳6 dresses.

In **production today there are 3 womenswear users** (identified by
`user_metadata.wardrobe_direction = "Womenswear"`; the `users.gender` column is
unused — `NULL` for all of them). **All 3 (100%) sit at exactly FULL_BODY = 6**,
i.e. exactly on the lower trigger threshold (≥6), and **all 3 also own a full
separates set** (≥1 TOP + ≥1 BOTTOM — in fact 16 TOPs + 12 BOTTOMs each), so by
the spec definition **3/3 (100%) womenswear users are in the "harmed" population.**
None reach the ≥9 high-confidence threshold. Median structural dress share
FB/(FB+TOP) = **0.273**.

**BUT:** these 3 womenswear wardrobes are byte-identical synthetic
onboarding-seed wardrobes (same exact family counts), not organic user data.
The honest blast-radius read is: **the bias is structurally live and would harm
100% of current womenswear profiles, but the absolute count is 3 seeded test
users — there is effectively no organic womenswear population in prod yet to
quantify.** Real-world blast radius is unknowable from this dataset.

---

## Headline numbers (womenswear = `wardrobe_direction == "Womenswear"`)

| Metric | Value |
|---|---|
| Total womenswear users with ≥1 wardrobe item | **3** |
| …with FULL_BODY ≥ 6 (lower trigger) | **3 (100.0%)** |
| …with FULL_BODY ≥ 9 (high-confidence trigger) | 0 (0.0%) |
| Harmed = FULL_BODY ≥ 6 **AND** owns ≥1 TOP + ≥1 BOTTOM | **3 (100.0%)** |
| Median structural dress share FB/(FB+TOP) | **0.273** (mean 0.273, p75 0.273, p90 0.273) |

---

## Schema / definitions used (verified against models + prod)

- **Womenswear user**: the canonical engine mapping is `users.gender == 'FEMININE'`
  → engine `"W"` (`engine_v3.py:191`, `engine_v2.py:313`, `utils/gender_scoring.py:53`).
  **In prod the `users.gender` column has ZERO `FEMININE` rows** (values present:
  `NULL`×13, `MASCULINE`×1, `UNISEX`×1, `male`×1). The actual womenswear signal
  lives in `user_metadata.wardrobe_direction` (`"Menswear"|"Womenswear"|"Mixed"`,
  set at V05 onboarding — `services/v05_onboarding_service.py:36`). I keyed the
  measurement on `wardrobe_direction == "Womenswear"`, since that is what maps
  client-side to the `user.gender = "W"` payload the V05 engine consumes
  (`schemas/v05_recommendation.py:55`, `services/v05_build_service.py:83`).
- **USER wardrobe items only**: `is_common_item = false AND owner_id <> 'SYSTEM' AND is_deleted = false`.
- **Family buckets**: `wardrobe_items.category_family` ∈ {TOP, BOTTOM, OUTER, FULL_BODY, FOOTWEAR, ACCESSORY}.
- **FULL_BODY** = dresses + jumpsuits (the dress bucket the bias over-weights).
- **Harmed**: FULL_BODY ≥ 6 (trigger) AND owns a separates set (≥1 TOP and ≥1 BOTTOM) they'd never be shown.
- **Structural dress share**: FULL_BODY / (FULL_BODY + TOP) per user.

---

## Aggregate tables (all womenswear-leaning + hygiene buckets)

### WOMENSWEAR (n=3 with items)
| FULL_BODY bucket | 0 | 1–2 | 3–5 | 6–8 | 9+ |
|---|---|---|---|---|---|
| users | 0 | 0 | 0 | **3** | 0 |

- FULL_BODY ≥6: **3 (100%)** · ≥9: 0 (0%)
- Harmed (≥6 FB + separates set): **3 (100%)**
- Dress share FB/(FB+TOP): mean 0.273 / median 0.273 / p75 0.273 / p90 0.273
- All 3 wardrobes identical: `FB=6 TOP=16 BOTTOM=12 OUTER=8 FOOT=8 ACC=8` → synthetic seed.

### MIXED (n=2 with items) — partial-relevance
| FULL_BODY bucket | 0 | 1–2 | 3–5 | 6–8 | 9+ |
|---|---|---|---|---|---|
| users | 0 | 0 | 0 | **2** | 0 |
- Both at FB=6 (same identical seed wardrobe). Mixed maps to gender_tags `{M,W,U}`;
  whether the bias fires depends on whether the client sends `gender="W"` or `"U"`
  for a Mixed profile — **backend can't disambiguate**. If the client sends `"W"`,
  these 2 are also harmed (so worst-case womenswear-bias-affected = 5).

### MENSWEAR (n=1) — hygiene control
- FB=0, TOP=16 BOTTOM=12 OUTER=6 FOOT=8 ACC=8. Gated correctly (no dresses). ✅

### NO_DIRECTION / unisex (n=1 with items, gender_col `male`/`NULL`)
- One `gender_col='male'` user: FB=0. One metadata-null user: 2 TOPs only.
- **Hygiene signal: no man/unisex user owns any FULL_BODY item** → no cross-gender
  dress contamination. Clean. ✅

### Whole-corpus context
- USER items (non-system, non-deleted): **360** across **7** users.
- `category_family` over USER+SYSTEM items: TOP 147, BOTTOM 114, FOOTWEAR 70, OUTER 69, ACCESSORY 66, FULL_BODY 40, NULL 20.
- Item-level `gender_tags` across user items: M 177, W 286, U 179 (286 W-tagged items, 7 distinct owners).
- SYSTEM/common items: 162 (excluded from all per-user measures).

---

## Queries used (read-only)

Core per-user family count (parameter-free constant SQL, no interpolation):

```sql
SELECT user_id, category_family, COUNT(*)
FROM wardrobe_items
WHERE is_common_item = false
  AND owner_id <> 'SYSTEM'
  AND is_deleted   = false
  AND user_id IS NOT NULL
GROUP BY user_id, category_family;
```

Womenswear identity (no women in the gender column → keyed on metadata):

```sql
SELECT id, gender, user_metadata FROM users;   -- wardrobe_direction read from JSON in Python
SELECT gender, COUNT(*) FROM users GROUP BY gender;  -- {NULL:13, MASCULINE:1, UNISEX:1, male:1}
```

Histogram / ≥6 / ≥9 / harmed / dress-share computed in Python from the GROUP BY
result (aggregates only; no PII emitted — anonymized `user#i` indices only).
Full scripts: `/tmp/probe_schema.py`, `/tmp/probe_meta.py`, `/tmp/probe_blast.py`
(ephemeral, not committed).

---

## Caveats / data-hygiene findings (READ THESE)

1. **Prod has no organic womenswear population.** The 3 "Womenswear" + 2 "Mixed"
   users have byte-identical wardrobes (`FB=6/TOP=16/BOTTOM=12/OUTER=8/FOOT=8/ACC=8`).
   These are onboarding-seeded synthetic test wardrobes. The 100% harmed figure is
   real *given the definition* but reflects seed data, not market reality.
2. **`users.gender` is dead for womenswear.** Canonical code maps `FEMININE → W`,
   but no user has `gender='FEMININE'`. Womenswear is tracked only in
   `user_metadata.wardrobe_direction`. If any analytics or gating relies on the
   `users.gender` column to detect women, it will silently never fire. Flag to tech-lead.
3. **Threshold position.** Every womenswear seed user sits at *exactly* FB=6 — the
   lower trigger. None reach 9. So the bias engages at its mildest tier; with 6
   dresses vs 16 tops, the 2.0× FB bias plus a top-30% anchor cutoff is what slices
   separates. The structural dress share is only 0.273 — i.e. these users are
   separates-dominant by inventory yet (per the controlled sim) get dress-dominant
   outfits. That's the harm: not that they own mostly dresses, but that 6 dresses is
   enough for the bias to crowd out 28 separates from the anchor pool.
4. **Mixed ambiguity.** Worst case (client sends `gender="W"` for Mixed) → 5 affected
   users; strict case (Mixed→`U`) → 3. Backend cannot tell which mapping the client uses.

---

## Unresolved questions

- Does the auxi client map `wardrobe_direction="Mixed"` → `gender="W"` or `"U"` in the
  V05 build payload? Determines whether Mixed users (2) are in-scope. (cross-repo → tech-lead/mobile-dev)
- Should `users.gender` be backfilled from `user_metadata.wardrobe_direction`, or is the
  metadata field now the canonical source? The `FEMININE→W` code path is effectively dead in prod.
- Is the ≥6 threshold (vs the controlled-sim ≥6–9 band) the right tripwire, given that
  every womenswear seed wardrobe lands exactly on 6?
