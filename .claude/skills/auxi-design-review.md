# auxi-design-review — the designer's 6-lens craft pass

> The playbook the `designer` agent runs at **step 6.5** of the Figma→RN
> workflow (after qa-ui Compare PASS, before qa-mobile smoke / PR). HARD GATE:
> any open BLOCKER or MAJOR → FAIL → PR blocked.
>
> Rule: `.claude/rules/design-review-required.md`. Agent:
> `.claude/agents/designer.md`. Token sources: `auxi/src/theme/theme.ts`,
> `auxi/src/theme/motion.ts`. Rule docs: `auxi/docs/design-system/*.md`.

## Inputs

- The changed screen(s) / component(s) — branch or commit.
- The Figma URL + node-id (for confirming a token value — NOT for pixel-diff).
- qa-ui Compare PASS (this gate runs *after* it). If qa-ui hasn't passed, stop —
  you're out of order.

## Pre-flight (do not skip)

1. `./scripts/mcp-doctor.sh` from umbrella root → exit 0 before any mobile-mcp
   call. Non-zero (sim/WDA down) → STOP, don't fake a static-only PASS.
2. Initialize the findings file FIRST:
   `auxi/docs/design-reviews/<YYYY-MM-DD>-<screen-slug>.md` with a header
   (build SHA, device, screens in scope). Append findings as you go.
3. Identify the changed files: `git diff --name-only main...HEAD -- 'auxi/src/**'`.
   Scope the review to what changed + its direct sibling screens (for lens 5).

## The six lenses

Run all six, in order. Each cites its rule doc and a BLOCKER/MAJOR/MINOR bar.

### Lens 1 — Design-system tokens (`design-system.md`)
**Check:** every value comes from a token, at the right tier (`ds.*` first).
```bash
# raw hex / fontFamily / raw zIndex in changed screens (lint backstop):
./scripts/auxi-lint-tokens.sh
grep -nE "zIndex:\s*[0-9]" auxi/src/screens/<X>.tsx     # raw z-index → BLOCKER
grep -nE "#[0-9a-fA-F]{3,8}" auxi/src/screens/<X>.tsx   # raw hex → BLOCKER
```
- **BLOCKER:** raw hex, raw `fontFamily` string, raw `zIndex` number.
- **MAJOR:** off-grid spacing that breaks alignment vs a sibling.
- **MINOR:** legacy `figma*`/`uac*` alias where a `ds.*` token exists; off-grid
  spacing that's cosmetically fine.

### Lens 2 — Motion (`motion-rules.md`)
**Check:** every animation references a `motion.*` token; open/close asymmetry;
reduce-motion branch present.
```bash
grep -nE "duration:\s*[0-9]|Easing\.|toValue:\s*0\.[0-9]" auxi/src/**/<X>.tsx
grep -n "useReducedMotion" auxi/src/**/<X>.tsx          # must exist for translate/scale
```
- **BLOCKER:** hardcoded duration / easing / scale / spring literal.
- **MAJOR:** open and close use the same duration, or swapped enter/exit easing
  (house signature is OPEN `medium 350`+`enter` / CLOSE `normal 250`+`exit`); no
  `useReducedMotion` branch on a translate/scale animation.
- **MINOR:** off-token stagger (100 where 80/120 fits); slightly-off mapping.

### Lens 3 — Color (`color-rules.md`)
**Check:** semantic tokens used for their meaning; no hex in screens.
- **BLOCKER:** raw hex color literal (lint would catch).
- **MAJOR:** wrong semantic token — `green` (radio/confirm) on a switch instead
  of `teal`; raw `red` `#ff0000` for destructive instead of `ds.color.danger`;
  light cream text on a light surface (invisible-on-light).
- **MINOR:** on-system value via legacy alias where a `ds.color.*` exists.
- **Route contrast *measurement* to qa-ux** — you flag the risk, they verdict it.

### Lens 4 — Header / footer / layout (`header-footer-rules.md`)
**Check:** reuse `<Header>` (76px, center title, left nav, right action); drawer
follows the 317px push pattern + open/close asymmetry; bottom controls clear the
safe-area.
```bash
grep -n "useSafeAreaInsets\|insets.bottom" auxi/src/screens/<X>.tsx
```
- **MAJOR:** hand-rolled header instead of `<Header>`; drawer/sheet open=close
  timing; bottom control ignores `insets.bottom` (collides with home indicator);
  header right-slot/title alignment drift vs siblings.
- **ESCALATE:** an off-pattern bottom tab-bar introduced without a CEO ticket
  (the app is native-stack today — no bottom nav exists).
- **MINOR–MAJOR:** sticky CTA missing the blur/tint treatment where it overlays
  scroll (per visual weight).

### Lens 5 — Cross-screen consistency (all four docs)
**Check:** the same element reads the same across screens. Compare the changed
screen's primitives against its siblings (Home/Wardrobe/ItemDetail/Settings/…).
- **MAJOR:** same logical element (a CTA, a card, a header action, a selected
  pill) styled differently than its sibling without a documented reason.
- **MINOR:** small divergence that doesn't break the family resemblance.
- Use ONE sim screenshot per surface (budget cap 4/dispatch) to compare visually.

### Lens 6 — Component states (`motion-rules.md` + `color-rules.md`)
**Check:** interactive elements have the states the pattern requires.
```bash
grep -nE "Pressable|TouchableOpacity" auxi/src/screens/<X>.tsx
```
- **MAJOR:** a pressable with no press-feedback (`scale.press` 0.97 +
  `spring.standard`); a toggle/pill with no selected treatment; a control that
  can be disabled but has no disabled style.
- **MINOR:** state present but slightly off-token.
- (Functional dead-control / no-`onPress` is a qa-ux finding — if you spot one,
  route it, don't claim it.)

## Screenshot discipline

- Cap **4 surfaces per dispatch.** Save to
  `auxi/docs/design-reviews/screenshots/<YYYY-MM-DD>/designer-<surface>.png`.
- One canonical shot per surface; add a `-<state>` shot only when a finding needs
  it evidenced (e.g. press-feedback before/after).
- Every finding citing a screenshot must point to a path that exists on disk.

## Verdict

- Any open **BLOCKER or MAJOR** → **FAIL** → PR blocked. List each with rule doc
  + exact token, route to mobile-dev.
- Only **MINOR** (or none) → **PASS** → record it; the PR may proceed to step 7
  (qa-mobile smoke).
- A taste / scope question the docs can't answer → **ESCALATE** to CEO; pause the
  gate until the CEO calls it.

## Self-audit before returning (mandatory)

1. Count findings (N) and findings whose screenshot path exists (S). If `N ≠ S`,
   delete findings without evidence; print the delete count.
2. Confirm every finding cites a rule doc + a concrete token (not "looks off").
3. Confirm the verdict follows the ladder (any BLOCKER/MAJOR ⇒ FAIL).
4. Print: `M surfaces reviewed · N findings (B:x/Maj:y/Min:z) · VERDICT · routing`.

## Composition with the team

| Hand-off | When |
|---|---|
| → mobile-dev | Every BLOCKER/MAJOR/MINOR on-system fix, with file:line + token |
| → CEO (ESCALATE) | Taste / scope / off-pattern-without-ticket |
| → qa-ui | Pixel mismatch vs the Figma frame (don't re-audit) |
| → qa-ux | Contrast measurement / touch target / VoiceOver (don't re-measure) |
| → mobile-dev (`figma-theme-sync`) | Token drift needing a one-time `theme.ts` fix |
