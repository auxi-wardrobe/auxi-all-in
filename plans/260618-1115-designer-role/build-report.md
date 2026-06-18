# Build report — designer role + design-system rule docs

**Date:** 2026-06-18 · **Status:** DONE · per `spec.md` (approved)

## What the designer role is (3 lines)

A post-code, **HARD GATE** design-system craft reviewer for `auxi/` — the CEO's
system proxy at **step 6.5** of the Figma→RN workflow (after qa-ui Compare PASS,
before qa-mobile smoke / PR). Asks "is it on-system + crafted?" across 6 lenses
(tokens → motion → color → header/footer/layout → cross-screen → component
states); a FAIL blocks the PR. Findings-only — routes fixes to mobile-dev, taste
to CEO; never edits prod code, never re-does qa-ui pixel-diff or qa-ux a11y, and
is not the design approval authority (the CEO is).

## Files created (7)

- `/Users/nguyenminhduc/dev/wardrobe_project/.claude/agents/designer.md`
- `/Users/nguyenminhduc/dev/wardrobe_project/.claude/skills/auxi-design-review.md`
- `/Users/nguyenminhduc/dev/wardrobe_project/.claude/rules/design-review-required.md`
- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/design-system/design-system.md`
- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/design-system/motion-rules.md`
- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/design-system/color-rules.md`
- `/Users/nguyenminhduc/dev/wardrobe_project/auxi/docs/design-system/header-footer-rules.md`

## Files edited (2)

- `/Users/nguyenminhduc/dev/wardrobe_project/CLAUDE.md` — agent table `designer`
  row; mobile-mcp Read-only screenshot tier + prose; workflow **step 6.5** block;
  supporting-skills list; PR-template-enforces list.
- `/Users/nguyenminhduc/dev/wardrobe_project/.github/PULL_REQUEST_TEMPLATE.md` —
  "designer design-review PASS" checklist item.

## Grounding (real tokens cited, no boilerplate)

- `theme.ds.*` canonical layer, z-index six-tier (`base:0…toast:1200`), 4px
  spacing grid (`xs:4…xxl:48`), `ds.radius`, `ds.shadow`, `ds.font` — from
  `theme.ts`.
- motion tokens (`duration.medium:350`/`normal:250`, `easing.enter`/`exit`,
  `scale.press:0.97`, springs, stagger, `useReducedMotion`) — from `motion.ts`.
- `ds.color` semantics (ink/slate/teal/green/danger/surfaces) — from `theme.ts`.
- Header 76px + center title + `figmaBackground`; push-drawer 317px + open
  `medium`+`enter` / close `normal`+`exit` — from `Header.tsx`, `RootDrawer.tsx`,
  `SidebarMenu.tsx`, `Sidebar.tsx`.

## Constraints honored

- No RN component / `theme.ts` / `motion.ts` edits. No commit. No files outside
  the spec list. Findings path `auxi/docs/design-reviews/<date>-<slug>.md` (dir
  is created on first review — not pre-stubbed).

## Open questions

- Spec open Q (unresolved by design): does the gate also apply to the
  `wardrobe-admin` SPA? Docs assume **auxi-only**; flagged for CEO.

**Status:** DONE
