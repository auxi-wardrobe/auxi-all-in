# Designer role + design-system rules — design spec

**Date:** 2026-06-18 · **Status:** approved (decisions below) · **Owner:** umbrella

## Problem
UI shipped via mobile-dev + qa-ui still isn't "ngon mà chuẩn". qa-ui only does
pixel-diff vs one Figma frame; nobody enforces holistic **design-system craft**
(motion language, color semantics, header/footer/layout consistency, cross-screen
coherence). The CEO is the designer but there's no agent proxy that enforces the
*system* as a gate. Fix: add a `designer` agent (post-code, hard gate) + publish
the missing design-system rule docs.

## Decisions (user-approved)
- **Authority:** findings-only (routes fixes to mobile-dev), **HARD GATE** — FAIL blocks PR.
- **Position:** POST-code, **step 6.5** of the Figma→RN workflow — after qa-ui Compare (Pass 2+3) PASS, before qa-mobile smoke / PR.
- **Rule-docs scope (KISS):** exactly 4 files — design-system, motion, color, header+footer.
- **Boundary:** NOT pixel-diff (qa-ui) · NOT UX heuristics/a11y (qa-ux) · NOT code (mobile-dev) · NOT design *approval* authority (CEO). Designer enforces the SYSTEM; escalates taste calls to CEO.

## Differentiation vs existing roles
| Role | Question it answers |
|---|---|
| qa-ui | "Does code match this Figma frame?" (pixel-diff, token drift) |
| qa-ux | "Can the user understand/use it?" (Nielsen heuristics, a11y) |
| **designer** | **"Is it on-system + crafted: right token tier, right motion, right color semantics, consistent header/footer/layout, coherent across screens?"** |

Note: existing pre-code skill `auxi-mobile-designer.md` (design validation/handoff) is the PRE-code counterpart — out of scope here; this is the POST-code craft gate.

## Artifacts to build

### A. `.claude/agents/designer.md`
House style mirrors `qa-ui.md`/`qa-ux.md` frontmatter (`name`, `description`, `tools`).
- **Tools:** Read, Bash, Grep, Glob, Write, Skill + Figma MCP (`get_metadata`, `get_design_context`, `get_variable_defs`, `search_design_system`, `get_screenshot`) + read-only screenshot mobile-mcp tier (`launch_app`, `take_screenshot`, `save_screenshot`, `list_available_devices`, `list_elements_on_screen`, `click_on_screen_at_coordinates`) — so it can view the actual rendered screen.
- **Output:** verdict PASS / FAIL / ESCALATE + findings to `auxi/docs/design-reviews/<YYYY-MM-DD>-<screen-slug>.md` (severity BLOCKER/MAJOR/MINOR).
- **Sections:** role + hard boundaries; the 6-lens review checklist (design-system tokens → motion → color → header/footer/layout → cross-screen consistency → component states); routing table (fixes→mobile-dev, taste→CEO, pixel→qa-ui, a11y→qa-ux); hard-gate semantics (FAIL blocks PR).

### B. `.claude/skills/auxi-design-review.md`
The playbook the designer runs (the 6-lens pass), referencing the rule docs (C) and the real token files (`auxi/src/theme/theme.ts`, `auxi/src/theme/motion.ts`). Each lens: what to check, against which rule doc, what counts as BLOCKER vs MINOR.

### C. Rule docs (grounded in REAL tokens — no generic boilerplate)
- `.claude/rules/design-review-required.md` — the cross-cutting rule (every new UI feature passes the designer gate + follows the design system), mirroring the `analytics-tracking-required.md` precedent; points to the docs below.
- `auxi/docs/design-system/design-system.md` — token tiers overview: the canonical `ds.*` layer (`ds.color`, `ds.radius`, `ds.shadow`, z-index six-tier `base:0, content:1, sticky:100, dim:1000, modal:1100, toast:1200`), spacing 4px grid (`xs:4…xxl:48`), "use `ds.*` first, Figma aliases are legacy".
- `auxi/docs/design-system/motion-rules.md` — from `motion.ts`: durations (`instant:50…reveal:700`), easing (`standard/enter/exit/emphasized`), spring (`soft/standard/confident`), scale (`press:0.97…emphasis:1.05`), stagger. Which token per interaction (press feedback, sheet/drawer open=`medium 350`+`enter`, close=`normal 250`+`exit`, list stagger); reduce-motion fallback rule.
- `auxi/docs/design-system/color-rules.md` — `ds.color` semantic usage (ink, slate, teal, green, danger, surfaces); when each; contrast expectations; "no hex literals in screens" (ties to `auxi-lint-tokens.sh`).
- `auxi/docs/design-system/header-footer-rules.md` — canonical `Header.tsx` (76px, title-center, left back+hamburger, right user icon, bg `figmaBackground`); push-drawer pattern (Sidebar 317px, `motion.duration.medium` open / `normal` close). Footer: NO bottom tab-bar today (native-stack) — rule covers bottom safe-area + sticky-CTA pattern + what a future bottom nav must follow.

### D. Wiring `CLAUDE.md` (umbrella)
- Agent table: add `designer` row (auxi read-only · Figma-fluent · post-code design-system craft gate).
- Figma→RN workflow: insert **step 6.5** "designer design-review (hard gate) — PASS before qa-mobile smoke / PR".
- Mobile-MCP tiers table: add `designer` under the Read-only screenshot tier.
- PR template (`.github/PULL_REQUEST_TEMPLATE.md`): add "designer design-review PASS" checkbox.

## Out of scope (YAGNI)
- typography-roles.md + component-states matrix (real gaps, but deferred — not in the approved 4).
- Pre-code designer gate (existing `auxi-mobile-designer` skill already covers it).
- Editing any RN component / changing the design system itself.

## Success criteria
- A new UI feature cannot merge without a designer PASS recorded in `auxi/docs/design-reviews/`.
- Designer findings cite a specific rule doc + token (e.g. "uses raw #1d1f23 instead of `ds.color.ink` — color-rules.md").
- No overlap complaints: designer never re-does qa-ui pixel-diff or qa-ux heuristics.

## Open questions
- Does the CEO want the designer to also enforce on the `wardrobe-admin` SPA, or auxi-only? (assume auxi-only for now)
