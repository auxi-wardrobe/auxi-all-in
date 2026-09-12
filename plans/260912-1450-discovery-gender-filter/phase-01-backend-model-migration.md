# Phase 01 — `discovery_outfits.gender` column + the shared allowed-set helper

**Repo:** `auxi-wardrobe/auxi-backend` · **Owner:** backend-dev · **Effort:** 1.5h
**Status:** pending · **Blocked by:** — · **BLOCKS: 02, 03**

## Context

- Model to extend: `models/discovery.py` (`DiscoveryOutfit`, `DiscoveryStatus`,
  `DiscoverySeason`). Note `season` is the exact precedent for this column:
  `String(16)`, nullable, `index=True`, closed enum enforced at the router not
  by a DB CHECK (keeps SQLite/Postgres parity).
- Rule to reuse, **never re-implement**: `utils/gender_scoring.py`
  (`resolve_wardrobe_gender`, `is_item_visible_to_wardrobe`).
- Migration style source: `migrations/versions/discovery1a2b_add_discovery_outfits.py`.
- Model registration: `migrations/env.py` already imports `models.discovery` —
  no change needed there.

## Key insights

- `resolve_wardrobe_gender` already accepts `"Menswear"`/`"Womenswear"`/`"Mixed"`
  (`_PREF_TO_WARDROBE_GENDER`), so nothing needs to translate the onboarding
  vocabulary before calling it.
- `is_item_visible_to_wardrobe` is **per-item, in Python**. The Discovery feed
  must narrow in **SQL** (it paginates). So this phase adds a second,
  SQL-friendly projection of the *same* rule — an allowed-set function — and
  phase 04 adds a property test proving the two agree. Do NOT hand-code the M/W/U
  branching in the repository.
- One outfit carries ONE gender (single-select, per the CEO ask), unlike
  `WardrobeItem.gender_tags` which is a list. The codes are deliberately the
  same `M|W|U` so one vocabulary spans the codebase.

## Requirements

### 1. `utils/gender_scoring.py` — add `allowed_wardrobe_genders`

Insert directly after `is_item_visible_to_wardrobe` (same AU-305 comment block
governs both):

```python
def allowed_wardrobe_genders(user_pref: Optional[str]) -> Optional[set]:
    """SQL-friendly projection of the AU-305 rule for SINGLE-gender rows.

    Returns the set of gender codes a single-gender row may carry to be
    visible to this wardrobe, or None when there is no gender context and
    the caller must not filter at all.

    This is the same rule as ``is_item_visible_to_wardrobe`` expressed as a
    set instead of a predicate, so a paginating SQL query can narrow with
    ``IN (...)`` instead of filtering in Python. The two MUST agree for
    single-tag rows — ``tests/test_discovery_gender_filter.py`` asserts it.

        >>> sorted(allowed_wardrobe_genders("Menswear"))
        ['M']
        >>> sorted(allowed_wardrobe_genders("Mixed"))
        ['M', 'U', 'W']
        >>> allowed_wardrobe_genders(None) is None
        True
    """
    gender = resolve_wardrobe_gender(user_pref)
    if gender is None:
        return None
    if gender == "U":
        # Union wardrobe — same carve-out as is_item_visible_to_wardrobe.
        return set(_VALID_ITEM_GENDER_TAGS)
    return {gender}
```

### 2. `models/discovery.py` — new enum-like class + column + DTO fields

Add after `DiscoverySeason`:

```python
class DiscoveryGender(object):
    """Enum-like wardrobe-gender values for a discovery outfit.

    Same ``M|W|U`` codes as ``WardrobeItem.gender_tags`` so there is one
    gender vocabulary across the codebase — but SINGULAR here (an outfit is
    curated as one look, for one wardrobe), where an item carries a list.

    NULL = visible to every wardrobe. That mirrors ``season`` NULL =
    all-season in this same model, and is what keeps pre-existing published
    outfits servable after the migration. Publishing a NEW outfit requires a
    non-NULL gender (``DiscoveryAdminService.assert_publishable``), so NULL
    only ever means "row predates gender targeting".
    """

    MEN = "M"
    WOMEN = "W"
    UNISEX = "U"

    ALL = [MEN, WOMEN, UNISEX]
```

Column, placed immediately after `season` so the diff reads as "the second
targeting axis":

```python
    # Wardrobe-gender target. NULL = every wardrobe (see DiscoveryGender).
    # Closed enum enforced at the router (phase 03), not by a DB CHECK —
    # same SQLite/Postgres-parity choice `season` and `status` made.
    gender = db.Column(db.String(16), nullable=True, index=True)
```

DTO changes — all three, so admin, feed and detail agree:

- `to_card_dict()` → add `"gender": self.gender`
- `to_admin_dict()` → add `"gender": self.gender` (next to `"season"`)
- `to_public_dict()` inherits it from `to_card_dict()`; no edit needed.

Adding `gender` to the public card DTO is deliberate: it costs nothing, and it
lets QA and the mobile debug overlay confirm the filter actually applied without
DB access.

### 3. Migration

`migrations/versions/discgender1a2b_add_discovery_outfit_gender.py`

```python
"""add_discovery_outfit_gender

Revision ID: discgender1a2b
Revises: mergediscdflt
Create Date: 2026-09-12 15:00:00.000000

Adds ``discovery_outfits.gender`` (M|W|U, nullable, indexed) — the wardrobe-
gender target for the Discovery feed filter.

Additive only. Existing rows backfill to NULL, which ``DiscoveryGender``
defines as "visible to every wardrobe": without that, every already-published
outfit would vanish from the feed of every onboarded user the moment this
lands. Tagging them is a curation task, not a migration.
"""
from alembic import op
import sqlalchemy as sa

revision = "discgender1a2b"
down_revision = "mergediscdflt"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "discovery_outfits",
        sa.Column("gender", sa.String(length=16), nullable=True),
    )
    op.create_index(
        "ix_discovery_outfits_gender", "discovery_outfits", ["gender"]
    )


def downgrade():
    op.drop_index("ix_discovery_outfits_gender", table_name="discovery_outfits")
    op.drop_column("discovery_outfits", "gender")
```

## Related code files

- MODIFY `utils/gender_scoring.py` (add `allowed_wardrobe_genders`)
- MODIFY `models/discovery.py` (`DiscoveryGender`, `gender` column, 2 DTOs)
- CREATE `migrations/versions/discgender1a2b_add_discovery_outfit_gender.py`

## Implementation steps

1. **Re-verify the head first:** `alembic heads`. Expected `mergediscdflt`
   (confirmed 2026-09-12 by reading every `down_revision`). If it differs,
   parent the new revision on the ACTUAL head — a stale parent creates two heads
   on main, the exact trap documented in `trendingdrop1a2b:16-19` and already hit
   once by `mergediscdflt` itself.
2. Add `allowed_wardrobe_genders` to `utils/gender_scoring.py`.
3. Add `DiscoveryGender`, the column, and the two DTO keys.
4. Write the migration against the verified head.
5. Round-trip: `alembic upgrade head` → `alembic downgrade -1` → `upgrade head`.
6. `python -c "import models.discovery, utils.gender_scoring"` clean.
7. `python -m pytest tests/ -m unit -x` still green (no behaviour change yet).

## Todo

- [ ] `alembic heads` re-verified and recorded in the delivery report
- [ ] `allowed_wardrobe_genders` added with docstring examples
- [ ] `DiscoveryGender` + `gender` column + `to_card_dict`/`to_admin_dict` keys
- [ ] Migration written against the verified head
- [ ] upgrade/downgrade/upgrade round-trip green
- [ ] `alembic heads` returns a SINGLE head afterwards

## Success criteria

- `alembic heads` returns exactly one head after upgrade.
- `DiscoveryOutfit(gender=None)` still `is_servable()` when PUBLISHED + enabled +
  ≥1 live item (i.e. the migration cannot blank the live feed).
- `allowed_wardrobe_genders("Menswear") == {"M"}`,
  `allowed_wardrobe_genders("Mixed") == {"M","W","U"}`,
  `allowed_wardrobe_genders("") is None`.

## Risk assessment

| Risk | L×I | Mitigation |
|---|---|---|
| Migration parented on a stale head → two heads on main | M×H | Step 1 re-verifies; this repo has already been bitten twice (`mergeheads1a2b`, `mergediscdflt`) |
| NULL treated as "invisible" downstream → whole live feed blanks | M×**H** | `DiscoveryGender` docstring states the contract; phase 02's SQL is `gender IN (...) OR gender IS NULL`; phase 04 has a dedicated regression test |
| Someone re-implements the M/W/U branching in the repo layer and it drifts from AU-305 | M×M | `allowed_wardrobe_genders` is the only sanctioned entry point; phase 04's property test fails if the two projections disagree |
| `String(16)` for a 1-char code looks wrong | L×L | Deliberate — matches `season`'s width so the columns are visually parallel, and leaves room if the vocabulary ever spells out |

## Security

No user input reaches this layer. The enum is validated at the router (phase 03).
The column is not user-writable on any public route.

## Next steps

Unblocks phase 02 (feed filter) and phase 03 (admin API) — run them in parallel.
