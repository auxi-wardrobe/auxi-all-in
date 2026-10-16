# Dispatch — wide-leg shoe coverage (paste vào session mới trên `auxi-wardrobe/auxi-backend`)

> Self-contained. Session nhận prompt này KHÔNG có umbrella repo.
> Spec đầy đủ: `plans/260918-0156-tryon-wide-leg-shoe-coverage/plan.md` (umbrella).

---

You are working in `auxi-wardrobe/auxi-backend` (FastAPI · SQLAlchemy · Postgres). Fresh session.

# Goal

CEO requirement: when See on me renders a **wide-leg** trouser, the hem must cover **at least
half the shoe**. Reported failure: wide-leg renders short/narrow with the whole shoe visible.

# Ground truth — verified at `ac9bd56`, do NOT rebuild any of it

The silhouette system already exists and is good. Read these before touching anything:

- `blueprints/tryon/garment_fit.py` — per-fit/per-length prompt directives. `_BOTTOM_DIRECTIVES["WIDE"]`
  already carries a measurable spec + explicit negation, and `build_silhouette_section` is placed
  LAST in the prompt on purpose.
- `utils/garment_fit_derivation.py` — `resolve_garment_fits` / `resolve_garment_lengths`, single
  source of truth shared with `scripts/backfill-normalized-fit.py`.
- `blueprints/tryon/openai_service.py:467` (COMPOSITION) — already forbids trading hem length for
  shoe visibility.
- `scripts/eval-tryon-fit-fidelity.py` — blind-classification A/B eval.

**Your job is three small deltas, not a redesign.**

# The three gaps

**G1 — `LONG` has no measurable floor.** `garment_fit.py:_LENGTH_DIRECTIVES["LONG"]` says the hem
rests on the instep "partially covering the foot". "Partially" is exactly the weak adjective this
module's own docstring says loses to the training prior. Give it a ratio.

**G2 — the compact template is the production path.** `config.py:77`
`TRYON_RENDER_PROVIDER` defaults to `kling_image`, which renders through
`build_compact_fit_clause` (`openai_service.py:712`), NOT `build_silhouette_section`.
`_COMPACT_LENGTH["LONG"]` is weaker still. **Fixing only the full template fixes a path that
production does not run.** Change both tables.

**G3 — a WIDE bottom with unknown length emits no length line at all.**
`resolve_item_length` returns `None` when the tagger never wrote `length_type` and the item name
carries no keyword. The model then picks the hem freely — the likely source of "shoe fully
visible". A wide-leg bottom is almost always full-length.

# Phase 1 — data check FIRST (gate, cheap)

Against prod-mirror Postgres, count bottoms with `normalized_fit = 'WIDE'` whose `length_type`
is NULL or outside `LENGTH_TYPES`. Report the number and the share.

- High share → G3 is the dominant gap; G1/G2 wording alone will not move the metric.
- Near zero → G3 is not worth the conditional; do G1+G2 only.

**Do not skip this.** It decides whether Phase 3 ships.

# Phase 2 — measurable floor (G1 + G2)

In `garment_fit.py`, rewrite the `LONG` entry in **both** `_LENGTH_DIRECTIVES` and
`_COMPACT_LENGTH` so it states a ratio instead of "partially". Target wording (adapt to house
style, keep the compact one inside its char budget): the hem breaks over the shoe and covers **at
least the upper half of it** — only the toe area stays visible; it must NOT stop at or above the
ankle.

Aim the prompt at full break (only the toe cap), not at exactly one half: the generator undershoots
toward its prior, so a prompt aimed at 1/2 lands at the ankle. The half is the ACCEPTANCE bar, not
the target.

Leave `MAXI` alone — it already says the shoes may be fully hidden and that this is correct.

Watch the compact path's `_COMPACT_PROMPT_CHAR_BUDGET = 2700`; FLUX hard-rejects over 3000. Verify
the rendered compact prompt still fits.

# Phase 3 — conditional default (G3), only if Phase 1 justifies it

When a bottom resolves `fit == "WIDE"` and length is `None`, render it as `LONG`.

- Do this at the **render layer only**. Do NOT write the inferred value to the DB and do NOT change
  `resolve_item_length`'s contract — the backfill shares it, and a guess must not become
  persisted truth.
- Keep it to bottoms. Never infer a length for `NO_FIT_CATEGORIES`.

# Phase 4 — measure (no number, no conclusion)

`scripts/eval-tryon-fit-fidelity.py` judges `shoes_visible` as a boolean. A boolean cannot express
"at least half", so it cannot accept or reject this change.

Add an ordinal `shoe_coverage` to the judge's JSON, asked as a classification (never leak the
expected answer — preserve the existing blind-classification design):

- `0` hem above the ankle bone, the whole shoe visible
- `1` hem at the ankle bone, nearly all of the shoe visible
- `2` hem at or below the top line of the shoe
- `3` hem breaks onto the toe area, the shoe mostly covered

PASS = `>= 2`. Score it only for fixtures whose expected length is `LONG`; **exempt `CROPPED`** —
a correct cropped wide-leg shows the ankle and must not be flagged.

Then run `--arm both` on WIDE fixtures and report before/after.

# Constraints

- Backend only. No mobile changes.
- `API_DOCUMENTATION.md` unchanged — no route/contract change here.
- Existing prompt string assertions in `tests/` will break on the reworded directive; update them
  to assert the new substance, don't delete them.
- Conventional commits. No AI references in commit messages.

# Report back

Phase 1 numbers, the diff, the Phase 4 before/after, and anything above that turned out false.
