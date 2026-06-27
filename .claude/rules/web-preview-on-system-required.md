# Web Preview (Sandbox) Vibe Loop — Must Stay On-System

> **Rule:** When a change is made for the designer to **vibe on the web preview
> ("sandbox")**, the UI MUST be **on-system from the first edit** — design-system
> tokens, `M*` primitives, `motion.ts`, canonical header/footer. A vibe-edit is
> NOT a throwaway mock. What the designer approves on the sandbox URL must be
> **shippable code**, not something that has to be rebuilt at PR time.

## Why

The designer vibes by chatting with Claude Code directly ("Sửa Home: card to
hơn…" → "sandbox đi" → a URL), per `auxi/docs/designer-quickstart.md`. That fast
loop **bypasses the Figma→RN pipeline** — no extraction artifact, no qa-ui
Compare, no step-6.5 designer gate. So nothing stops a quick vibe-edit from
landing **off-system** (raw hex, a hand-rolled `TouchableOpacity` button, ad-hoc
motion). The designer then approves a vibe built on throwaway code, and the drift
surfaces only later at PR (rework) — or slips through. This rule makes on-system
the **default in the fast loop**, so the sandbox the designer approves == the PR.

This complements, does not duplicate, the gates: `design-review-required.md` and
`design-system-primitives-required.md` are **post-code gates in the full
pipeline**; this rule governs the **informal sandbox loop** that skips them.

## When this applies

- Any UI edit to `auxi/src/screens/**` or
  `auxi/src/components/{features,layout}/**` made in a sandbox/vibe context.
- Binds **both** the designer's own Claude Code session (auto-loaded) and the
  `mobile-dev` agent (mandatory section in `.claude/agents/mobile-dev.md`).
- Any change you expect to follow with "sandbox đi" / "deploy đi" / "preview".

## When this does NOT apply

- Pure logic / service / data / hook changes with no visual surface.
- Backend (`wardrobe-backend`) — no RN surface.
- `wardrobe-admin` SPA — separate codebase, not under the auxi design system.
- Copy-only / i18n string changes with no layout change.
- The `M*` lib itself (`auxi/src/components/design-system/**`).
- Auth/UAC dark screens until DS dark roles land (Phase 1 of the DS migration).

## The rule — on-system in the vibe loop

1. **Vibe-edits are not throwaway.** Build it on-system the first time; the
   approved sandbox is the eventual PR, not a mock to redo.
2. **Tokens only.** Colors from `ds.color` / `src/theme/theme.ts`; spacing on the
   4px grid; radius / shadow / z-index from tokens. No raw hex, no magic numbers.
   (→ `auxi/docs/design-system/color-rules.md`, `design-system.md`)
3. **`M*` primitives, not hand-rolled.** button / icon button / input / switch /
   checkbox / radio / dialog / sheet / row / chip / badge / segmented / tabs /
   divider / avatar → import from `src/components/design-system/lib`. Raw RN
   primitives only when no `M*` fits — justify it.
   (→ `.claude/rules/design-system-primitives-required.md`)
4. **Motion via `motion.ts`.** Use a motion token per interaction; open/close
   asymmetry; reduce-motion fallback. No hardcoded duration literals.
   (→ `auxi/docs/design-system/motion-rules.md`)
5. **Header / footer / safe-area via canonical components** — not hand-rolled.
   (→ `auxi/docs/design-system/header-footer-rules.md`)
6. **Cross-screen consistency.** Any new visual treatment matches sibling
   screens — don't invent a one-off card/pill/CTA that diverges.
7. **Honest vibe (web-aware).** The preview renders on `react-native-web` (~95%
   like native). Verify the tokens/primitives you used look the same on web; if a
   change leans on a native-only effect (blur / shadow / gesture) that won't show
   on web, **say so to the designer** so the vibe isn't misleading.
8. **Before "sandbox đi".** Token lint + DS-primitives lint clean, and
   `yarn web:build` succeeds — so a deploy never serves drift or a broken,
   un-vibe-able build.

## What "done" means

A vibe-edit is incomplete if any of these are true:

- Raw hex / magic number where a token exists (token lint would flag it).
- A control hand-rolled with raw `Pressable`/`TextInput`/`Switch`/`Modal` where
  an `M*` exists, without a justification.
- A motion uses one duration for open and close, or has no reduce-motion branch.
- A header/footer is hand-rolled, or a bottom control ignores safe-area.
- A treatment diverges from sibling screens with no reason.
- The change relies on a native-only effect the web preview can't render and the
  designer wasn't told.

## Enforcement

- **Advisory-by-default**, with the **existing** lints as the mechanical backstop
  (no new script — KISS). Same posture as `design-system-primitives-required`
  (warn now → error at Phase 4).
- Token drift: `./scripts/auxi-lint-tokens.sh` (umbrella root) — hex + font drift.
- Primitive drift: `auxi/scripts/auxi-lint-ds-primitives.sh` — raw-control usage.
- Detailed dev/designer checklist (travels with the mobile repo):
  `auxi/docs/web-preview-on-system.md`.

## Roles — who owns what

| Question | Owner |
|---|---|
| "Is this vibe-edit on-system?" (this rule) | **whoever makes the edit** (Claude in the designer's session, or `mobile-dev`) |
| "Does it match this Figma frame?" (pixel-diff) | qa-ui |
| "Is it on-system + crafted holistically?" (step 6.5 gate) | designer agent |
| "Is the *taste* right?" | **CEO** |

The sandbox loop is fast and ungated — so on-system is the author's
responsibility here, not a downstream gate's. The downstream gates still run when
the change goes to PR; this rule just keeps the vibe honest before then.

## Related

- `auxi/docs/web-preview-on-system.md` — the practical checklist
- `auxi/docs/designer-quickstart.md` — how the designer vibes ("sandbox đi")
- `auxi/docs/web-review-architecture.md` — how the web preview is built (RNW)
- `.claude/skills/deploy-auxi-web.md` — how a sandbox is deployed
- `.claude/rules/design-system-primitives-required.md` — `M*` rule (backstop)
- `.claude/rules/design-review-required.md` — the post-code designer gate
- `auxi/docs/design-system/` — the four authoritative rule docs
