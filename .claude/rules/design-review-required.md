# Design Review — Required For Every New UI Feature

> **Rule:** Every new UI feature, screen, or significant visual change in the
> mobile app passes the **`designer` design-review gate** AND follows the design
> system. A feature isn't "done" until a designer PASS is recorded in
> `auxi/docs/design-reviews/` and the implementation is on-system (right token
> tier, right motion, right color semantics, consistent header/footer/layout,
> coherent across screens).

## When this applies

- Any new screen, route, modal, sheet, drawer, or bottom-tab
- Any new component with its own visual treatment (card, pill, chip, CTA, header)
- Any change that introduces or restyles motion (a new transition, animated reveal)
- Any change to the app chrome (header, drawer, sticky CTA, footer)
- Any feature touching `auxi/src/screens/**` or
  `auxi/src/components/{features,layout}/**` that a PR types `feat` or `design`

If a Figma→RN feature reaches qa-ui Compare PASS (Pass 2+3), it is at the
designer gate next — the gate is **step 6.5** of the canonical workflow.

## When this doesn't apply

- Pure logic / data / service changes with no visual surface
- Refactors that preserve the rendered UI exactly (same tokens, same motion)
- Backend-only work (`wardrobe-backend`) — no RN surface
- `wardrobe-admin` SPA — separate codebase, not under the auxi design system
- Copy-only / i18n string changes with no layout change

## Position in the workflow (POST-code, hard gate)

The `designer` gate is **step 6.5** of the Figma→RN workflow: **after** qa-ui
Compare mode (Pass 2+3) PASS, **before** qa-mobile smoke / PR. It is a **HARD
GATE** — a FAIL blocks the PR until mobile-dev fixes and the review re-runs.

```
… → 6. qa-ui Compare Pass 2+3 PASS
    → 6.5 designer design-review (HARD GATE) — PASS recorded
    → 7. qa-mobile smoke verify → 8. PR
```

## Authoritative sources of truth

The design system the gate enforces lives in four docs — read them before
building, cite them in findings:

- **`auxi/docs/design-system/design-system.md`** — token tiers (`ds.*`
  canonical layer, z-index six-tier, 4px spacing grid).
- **`auxi/docs/design-system/motion-rules.md`** — `motion.ts` token per
  interaction; open/close asymmetry; reduce-motion fallback.
- **`auxi/docs/design-system/color-rules.md`** — `ds.color` semantics; no hex
  in screens.
- **`auxi/docs/design-system/header-footer-rules.md`** — canonical Header,
  push-drawer, footer / sticky-CTA, future-bottom-nav rules.

Code sources of truth: `auxi/src/theme/theme.ts` + `auxi/src/theme/motion.ts`.
Mechanical backstop: `scripts/auxi-lint-tokens.sh`.

## What "done" means

A feature PR is incomplete if any of these are true:

- No `designer` PASS recorded at `auxi/docs/design-reviews/<YYYY-MM-DD>-<screen-slug>.md`
- A BLOCKER finding is open (raw hex, raw `zIndex`, hardcoded motion literal)
- Motion uses one duration for open and close, or no reduce-motion branch
- Header is hand-rolled instead of `<Header>`; a bottom control ignores safe-area
- An off-pattern bottom tab-bar was added without a CEO ticket

## Roles — who owns what (no overlap)

The `designer` enforces the **system**; it does NOT re-do other gates:

| Question | Owner |
|---|---|
| "Is it on-system + crafted? (token tier, motion, color semantics, chrome, cross-screen)" | **designer** |
| "Does code match this Figma frame?" (pixel-diff, token drift) | qa-ui |
| "Can the user understand/use it?" (Nielsen, a11y, contrast measurement) | qa-ux |
| "Does it implement?" (writes the RN code + fixes) | mobile-dev |
| "Is the *taste* right?" (final design approval) | **CEO** (designer escalates) |

The designer routes fixes to **mobile-dev**, taste calls to **CEO**, pixel-diff
to **qa-ui**, a11y to **qa-ux**. It never edits production code and is not the
design *approval* authority — the CEO is.

## Why

UI shipped via mobile-dev + qa-ui still wasn't "ngon mà chuẩn" — qa-ui only
pixel-diffs one Figma frame; nobody enforced holistic design-system craft
(motion language, color semantics, header/footer/layout consistency, cross-
screen coherence). The CEO is the designer but couldn't be a gate on every PR.
The `designer` agent is the system proxy that catches the on-system drift a
single-frame pixel-diff misses.

## Related

- `.claude/agents/designer.md` — the gate agent (findings-only, hard gate)
- `.claude/skills/auxi-design-review.md` — the 6-lens review playbook
- `auxi/docs/design-system/` — the four rule docs above
- `plans/260618-1115-designer-role/spec.md` — the approved spec
