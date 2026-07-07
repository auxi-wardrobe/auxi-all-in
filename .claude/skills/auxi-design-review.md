# auxi-design-review — the designer's 8-lens product-experience pass

> The playbook the `designer` agent runs at **step 6.5** of the Figma→RN
> workflow (after qa-ui Compare PASS, before qa-mobile smoke / PR). HARD GATE:
> any open BLOCKER or MAJOR → FAIL → PR blocked.
>
> Goal: not pixel accuracy — **does the experience feel coherent, intentional,
> native, and on-system?** Rule: `.claude/rules/design-review-required.md`.
> Agent: `.claude/agents/designer.md`. Token sources: `auxi/src/theme/theme.ts`,
> `auxi/src/theme/motion.ts`. Rule docs: `auxi/docs/design-system/*.md`.

## Inputs

- The changed screen(s) / component(s) — branch or commit.
- The Figma URL + node-id (for confirming a token value / intended pattern — NOT
  for pixel-diff).
- qa-ui Compare PASS (this gate runs *after* it). If qa-ui hasn't passed, stop —
  you're out of order.

## Pre-flight (do not skip)

1. `./scripts/mcp-doctor.sh` from umbrella root → exit 0 before any mobile-mcp
   call. Non-zero (sim/WDA down) → STOP, don't fake a static-only PASS.
2. Initialize the findings file FIRST:
   `auxi/docs/design-reviews/<YYYY-MM-DD>-<screen-slug>.md` with a header
   (build SHA, device, screens in scope). Append findings as you go.
3. Identify the changed files: `git diff --name-only main...HEAD -- 'auxi/src/**'`.
   Scope the review to what changed + its direct sibling screens (lens 6) + the
   end-to-end flow it sits in (journey continuity).

## The eight lenses

Run all eight, in order. Review the **interaction lifecycle and how the
experience reads**, not just static values. Lenses 1/2/4/6 have a system rule
doc + mechanical backstop; lenses 3/7/8 are experiential (judge against the lens
question, route the craft fix to mobile-dev or ESCALATE to CEO).

### Lens 1 — Design-system compliance (`design-system.md`)
**Check:** every value comes from a token at the right tier (`ds.*` first) —
typography, spacing, radius, **elevation** — and components reuse approved
variants / layout primitives instead of bespoke ones.
```bash
./scripts/auxi-lint-tokens.sh
grep -nE "zIndex:\s*[0-9]" auxi/src/screens/<X>.tsx     # raw z-index → BLOCKER
grep -nE "#[0-9a-fA-F]{3,8}" auxi/src/screens/<X>.tsx   # raw hex → BLOCKER
```
- **BLOCKER:** raw hex, raw `fontFamily` string, raw `zIndex` number; a custom
  value where a token exists; a bypassed/duplicated system component.
- **MAJOR:** off-grid spacing that breaks alignment vs a sibling.
- **MINOR:** legacy `figma*`/`uac*` alias where a `ds.*` token exists; off-grid
  spacing that's cosmetically fine.

### Lens 2 — Motion & interaction (`motion-rules.md`)
**Check:** the full interaction lifecycle (tap → press → hold → release),
sheets, nav transitions, progressive reveals, shared-element behavior. Every
animation references a `motion.*` token; open/close asymmetry; reduce-motion
branch present. Ask: responsive? calm? intentional? premium?
```bash
grep -nE "duration:\s*[0-9]|Easing\.|toValue:\s*0\.[0-9]" auxi/src/**/<X>.tsx
grep -n "useReducedMotion" auxi/src/**/<X>.tsx          # must exist for translate/scale
```
- **BLOCKER:** hardcoded duration / easing / scale / spring literal; instant
  active-state scaling; bounce where the system forbids it.
- **MAJOR:** abrupt motion; open=close timing or swapped enter/exit easing
  (house signature OPEN `medium 350`+`enter` / CLOSE `normal 250`+`exit`);
  transition breaks continuity; no `useReducedMotion` branch on translate/scale.
- **MINOR:** off-token stagger; slightly-off mapping.

### Lens 3 — Visual hierarchy (experiential)
**Check:** attention is directed intentionally — headline prominence,
recommendation prominence, CTA hierarchy, information grouping, scannability.
Ask: what is noticed first? what deserves attention? is the recommendation
clearly prioritized? is the next action obvious?
- **MAJOR:** primary action unclear; the recommendation visually competes with
  secondary content; weak grouping makes the screen hard to scan.
- **MINOR:** small hierarchy nudge (a label too heavy, spacing that flattens a
  group).

### Lens 4 — Color & emphasis (`color-rules.md`)
**Check:** semantic tokens used for their meaning; color reinforces hierarchy;
emphasis (CTA, selection, supporting info) is consistent with the system.
- **BLOCKER:** raw hex color literal (lint would catch); non-system color.
- **MAJOR:** wrong semantic token (e.g. `green`/confirm on a switch instead of
  `teal`; raw `red` for destructive instead of `ds.color.danger`); incorrect
  emphasis hierarchy; light text on a light surface.
- **MINOR:** on-system value via a legacy alias where `ds.color.*` exists.
- **Route contrast *measurement* to qa-ux** — you flag the risk, they verdict it.

### Lens 5 — Component state coverage (`motion-rules.md` + `color-rules.md`)
**Check:** interactive components support every required state and each is
understandable: **default / pressed / selected / disabled / loading / empty /
error / success.**
```bash
grep -nE "Pressable|TouchableOpacity" auxi/src/screens/<X>.tsx
```
- **MAJOR:** missing a loading or empty state; a pressable with no press-feedback
  (`scale.press` 0.97 + `spring.standard`); a toggle/pill with no selected
  treatment; a control that can be disabled with no disabled style.
- **MINOR:** state present but slightly off-token.
- **ESCALATE:** a required state was never designed in Figma → CEO.
- (A functionally dead control / missing `onPress` is a qa-ux finding — route it.)

### Lens 6 — Cross-screen consistency (all rule docs)
**Check:** the same pattern reads/behaves the same across the product —
navigation, **headers, footers** (`header-footer-rules.md`: reuse `<Header>`,
317px push-drawer, bottom controls clear the safe-area), filters, selection
patterns, cards, recommendations. Compare the changed screen's primitives
against its siblings (Home/Wardrobe/ItemDetail/Settings/…).
```bash
grep -n "useSafeAreaInsets\|insets.bottom" auxi/src/screens/<X>.tsx
```
- **BLOCKER:** the same component behaves differently between screens (users
  must relearn the pattern).
- **MAJOR:** hand-rolled header instead of `<Header>`; inconsistent hierarchy /
  interaction pattern vs a sibling; bottom control ignores `insets.bottom`.
- **ESCALATE:** an off-pattern bottom tab-bar introduced without a CEO ticket
  (the app is native-stack today — no bottom nav exists).
- **MINOR:** small divergence that doesn't break the family resemblance.
- Use ONE sim screenshot per surface (budget cap 4/dispatch) to compare visually.

### Lens 7 — Native feel (experiential)
**Check:** the experience feels like a real iOS app, not a web page in a shell —
navigation behavior, gestures, sheets, scrolling, touch feedback, interaction
timing. Ask: does anything feel web-like?
- **MAJOR:** an interaction feels like an embedded web page (e.g. a tap target
  with no native press feedback, a sheet that doesn't behave like an iOS sheet,
  janky/linear scrolling, a web-style hover dependency).
- **MINOR:** timing slightly off the native rhythm.

### Lens 8 — Recommendation experience (Auxi-specific)
**Check:** recommendations feel thoughtful and trustworthy — recommendation
presentation, the "Why This" reasoning, the Favorite flow, the Build-Around-This
flow, and alternative recommendations. Ask: does it feel curated and prepared?
does the reasoning support the decision? does it inspire confidence?
- **MAJOR:** the recommendation is visually buried; the reasoning is disconnected
  from the recommendation it explains; the favorite / build-around / alternatives
  flow undercuts trust.
- **MINOR:** presentation polish that would raise perceived curation.

## Journey continuity (run across the whole flow)

On every screen ask the user's three questions: **Where was I? Where am I? What
should I do next?** If a user can't answer naturally → **MAJOR** (the experience
lacks continuity). File it against the screen where continuity breaks.

## Screenshot discipline

- Cap **4 surfaces per dispatch.** Save to
  `auxi/docs/design-reviews/screenshots/<YYYY-MM-DD>/designer-<surface>.png`.
- One canonical shot per surface; add a `-<state>` shot only when a finding needs
  it evidenced (e.g. press-feedback before/after, empty vs loaded).
- Every finding citing a screenshot must point to a path that exists on disk.

## Verdict (CEO-calibrated severity)

- **BLOCKER** = *violates the design system* (wrong tokens / component / motion /
  nav pattern, broken cross-screen consistency). Prevents PR approval.
- **MAJOR** = doesn't violate the system but **significantly reduces product
  quality** (weak hierarchy, poor recommendation presentation, missing states,
  abrupt interaction, native-feel issues, broken journey continuity). Must be
  fixed before release.
- Any open **BLOCKER or MAJOR** → **FAIL** → PR blocked. List each with its rule
  doc / lens question + exact token, route to mobile-dev.
- **MINOR** = craftsmanship polish (spacing/alignment/animation/minor hierarchy).
  Does NOT block — record for follow-up. Only MINOR (or none) → **PASS**.
- **ESCALATE** = needs product/design judgment (multiple valid solutions, Figma
  ambiguity, missing design decision, brand direction) → CEO; pause the gate.

## Self-audit before returning (mandatory)

1. Count findings (N) and findings whose screenshot path exists (S). If a visual
   finding lacks evidence, capture it or drop it; print the delete count.
2. Confirm each finding cites a rule doc + concrete token, OR (experiential
   lens) the specific lens question it fails — never "looks off."
3. Confirm the verdict follows the ladder (any BLOCKER/MAJOR ⇒ FAIL).
4. Print: `M surfaces reviewed · N findings (B:x/Maj:y/Min:z) · VERDICT · routing`.

## Composition with the team

| Hand-off | When |
|---|---|
| → mobile-dev | Every BLOCKER/MAJOR/MINOR fix — token swap, motion token, header reuse, safe-area, missing state, hierarchy / native-feel / recommendation craft (file:line + token/principle) |
| → CEO (ESCALATE) | Taste / product direction / off-pattern-without-ticket / Figma ambiguity |
| → qa-ui | Pixel mismatch vs the Figma frame (don't re-audit) |
| → qa-ux | Contrast measurement / touch target / VoiceOver (don't re-measure) |
| → mobile-dev (`figma-theme-sync`) | Token drift needing a one-time `theme.ts` fix |
