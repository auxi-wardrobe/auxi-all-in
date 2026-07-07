---
id: WAR-GH364-PR147-01
parent: WAR-GH364-PR147-00
type: chore
title: "Resolve 4 open DS decisions for PR #147 standardization"
state: Backlog
priority: P1
labels: [type:chore, area:mobile, design-system, design-decision, role:designer, source:pr147-analysis]
team: Auxi
workspace: duncan-1
owner: designer / CEO
estimate: XS
linear_parent_url: TBD — GH-364 parent
created: 2026-06-26
linear_sync_status: pending
---

## Context

The PR #147 → DS standardization analysis surfaced 4 decisions that gate the
Phase 1-4 work. Answer all 4 in one pass — each phase ticket is blocked until its
decision lands. Decisions are CEO/designer calls, not mobile-dev's.

**This ticket blocks: `-02`, `-03`, `-05`, `-07`.**

## Decisions to make

### D1 — `figmaItemDetailDanger` (#c0392b) fate  (token-map bug #2)
PR #147 uses `figmaItemDetailDanger` = `#c0392b` for the Discard label and the
remove (⊖) icon. Canonical destructive is `ds.color.danger` = `#bb251a`. There are
three destructive reds in theme.ts; only `ds.color.danger` is canonical.
- **Option A:** alias `figmaItemDetailDanger → ds.color.danger` (#bb251a) and recolor.
- **Option B:** formally bless #c0392b as a distinct item-detail danger and document it.
- Analysis lean: A (collapse to canonical) unless there is a deliberate item-detail red.
- **Decision needed:** A or B?

### D2 — `BlurMenuHeader` shape  (blocks `-05`)
The translucent list-screen header (Favourite + My Creations both hand-roll it).
- **Option A:** new `BlurMenuHeader` layout component (sibling to `Header.tsx`).
- **Option B:** `Header.tsx` gains a `variant="blur"` prop.
- Analysis lean: A (own safe-area/tint/pointer-events concerns; B bloats Header).
- **Decision needed:** A or B?

### D3 — `MEmptyState` shape  (blocks `-03`)
`MEmptyState` is a genuine new primitive (CEO sign-off needed for a new pattern).
- Does Favourite's empty state need an action CTA (e.g. "Browse")? If yes, the
  `action` slot covers it.
- Discard sheet: add an explicit Cancel button, or keep backdrop-only cancel
  (PR #147 is backdrop-only today)?
- **Decision needed:** empty-state CTA yes/no + discard Cancel button yes/no.

### D4 — Phase 4 = the lint-flip + batch-migrate point  (blocks `-07`)
Confirm GH-364 **Phase 4** is the agreed point to:
- flip `auxi-lint-ds-primitives.sh` from warn → error, AND
- batch-migrate the Favourite family + #147 together onto `ds.*`+`M*`.
The "mirrors a shipped legacy sibling = MINOR" pass expires at Phase 4.
- **Decision needed:** confirm yes (or name a different phase).

## Acceptance criteria

- [ ] D1 answered (A or B) — recorded on ticket.
- [ ] D2 answered (A or B).
- [ ] D3 answered (empty-state CTA + discard Cancel).
- [ ] D4 confirmed.
- [ ] Decisions propagated to `-02`/`-03`/`-05`/`-07` AC before those start.

## Out of scope

- Any code. This is a decision-capture ticket only.

## Refs

- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/plan.md` (Unresolved questions §)
- `/Users/nguyenminhduc/dev/wardrobe_project/plans/260625-2344-GH-364-pr147-ds-standardization/token-map.md` (§0 bug #2)
- PRs: `auxi-wardrobe/auxi-all-in#29`, `auxi-wardrobe/auxi-mobile#149`, ref `auxi-wardrobe/auxi-mobile#147`
