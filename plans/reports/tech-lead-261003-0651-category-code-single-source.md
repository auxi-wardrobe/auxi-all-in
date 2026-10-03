# Category code enum — single source of truth (wardrobe-backend)

Branch: `wardrobe-backend` → `feature/category-taxonomy-single-source` (commit `83445eb`)
Trigger: "trong category trang common items ở admin và AI tagging có chỗ dành cho socks không" → no; root cause was five drifted copies of the enum.

## Problem

`category_code` enum existed in 5 hand-typed copies, none canonical:

| Copy | Consumers |
|---|---|
| `commonItems/constants.py` ITEM_CODES + CATEGORY_CODE_TO_CATEGORY | admin dropdowns, seeder, ID generator, clone |
| `utils/category_taxonomy.py` CATEGORY_CODE_TO_FAMILY | AI validator, V05 engine, matcher, onboarding |
| `commonItems/migrate_to_v05.py` KNOWN_CATEGORY_FAMILIES | migration script |
| `services/ai_service.py` prompt string | LLM extraction of user items |
| `wardrobe-admin/.../item-code-labels.ts` | admin display names |
| (+ `insert_v05_to_db.py` had a 6th copy with PLURAL labels `tops`/`dresses`) | seed script |

Concrete drift found: hoodie `HDD` (admin) vs `HOD` (AI/engine); `LOF`/`LOA`, `BTS`/`BOT`; `VAR` (varsity jacket) mapped to FOOTWEAR and offered in the prompt's "shoes" row; `SCK` (socks), `EAR`, `NCK`, `BRC`, `SDL`, `ROM`, `LGG`, `JOG`, `TRK`, `DRP`, `VST`, `TOP`, `ROB` accepted by AI but impossible to create in admin.

## Change

- `utils/category_codes.py` — ONE table: code → family + display label (59 canonical codes, incl. `SCK` Socks). Alias map for 17 legacy spellings (per ratified `migrate_to_v05.CATEGORY_CODE_MAPPING`): UND→TEE, HDD/ZHO→HOD, CRP/TUB→TOP, DSH→SHR, OFF/PEP→BLS, WST/HAR→VST, PNT→TRS, LEG→LGG, RBE→ROB, VAR→JKT, LOF→LOA, BTS→BOT, SLD→SDL. `normalize_category_code()` resolves alias + case; unknown → None.
- All five copies now import/derive from it. `utils/category_prompt_spec.py` generates the prompt enum lines.
- Admin API `GET /admin/common-items` enums: + `CATEGORY_LABELS`, + `LEGACY_CATEGORY_ALIASES`. Create/update normalize codes; unknown code → 400 (was silently written). `?category=` filter matches legacy spellings.
- Admin SPA merges server labels (`applyServerCategoryLabels`); static map = fallback.
- `id_generator` + wardrobe clone write canonical codes; AI validator canonicalizes.
- V2/V3 engine maps (`item_derivations`, `engine_v3`) accept canonical keys alongside legacy ones → behaviour identical before/after backfill.
- `scripts/normalize_legacy_category_codes.py` — dry-run backfill: alias codes → canonical, plural labels → singular, missing `category_family` filled. Never touches `id`/`human_readable_id`.
- `tests/test_category_codes_single_source.py` (28 tests) pins every projection.
- Docs: `API_DOCUMENTATION.md` enums section, `CLAUDE.md` taxonomy rule.

## Verification

- `pytest -m "not slow"` with CI deselect list: **2021 passed, 106 skipped, 18 deselected**.
- admin: `tsc -b` clean, `eslint` clean on changed files.

## Behaviour changes to be aware of

1. Admin `POST/PUT /admin/common-items` with an unknown `category_code` now returns 400.
2. Editing a common item still carrying a legacy code rewrites `category_code` and the HRID prefix to the canonical spelling (e.g. `SYS_L2_HDD_…` → `SYS_L2_HOD_…`). `id` unchanged.
3. `category` label for admin-created items now follows the ratified family: `CRD` → `top` (was `outerwear`), `LEA` → `bottom` (was `outerwear`), `WST`/`HAR`/`RBE` no longer `accessory`.
4. `insert_v05_to_db.py` now writes singular labels (`top`), not plural (`tops`).

## Not done / needs the CEO or ops

- **Backfill not run** (no DB access from this session): `python scripts/normalize_legacy_category_codes.py` (dry run) then `--write`.
- **Mobile (`auxi`) not checked** — repo not in session. If it has its own category list / picker, it is a 7th copy; should read `enums` or at least be diffed against `utils/category_codes.py`.
- PR not opened (not requested). Branch is pushed and ready.
