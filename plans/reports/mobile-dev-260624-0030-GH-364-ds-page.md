# GH-364 — DS page rebuild + menu gate (mobile-dev)

Date: 2026-06-24 · Branch: `feat/au-364-ds-page-claude-sync` (auxi submodule)

## Summary
Rebuilt the in-app Design System page to the new claude.ai showcase (Poppins-only,
new ramps + radius scale, all 13 component groups + foundations + live motion) and
email-gated a "Design System" sidebar entry. JS-only; no native rebuild.

## Branch + commits
```
fc8907f  feat(ds): add DS-page-local tokens for new claude.ai design system
a0cf206  feat(ds): email-gate Design System entry in sidebar menu
d8a15ed  docs(analytics): document design_system_opened event
12e5540  feat(ds): rebuild Design System page to new claude.ai system + motion
9c9df7b  refactor(ds): split floating-pill, checkmenu, toasts into own files (<200 LOC)
```

## Files changed (all within allowed scope)
A. Menu gate
- `src/components/layout/SidebarMenu.tsx` — `DS_EMAILS` gate; renders one
  "Design System" row (testID `sidebar-menu-design-system`) only when
  `user?.email ∈ {duc2820, vietdesign81}` (lowercased). Fires
  `track('design_system_opened',{source:'sidebar'})`.

B. DS-page-local tokens
- `src/components/design-system/ds-tokens.ts` (NEW) — FONT (Poppins faces) + MONO
  fallback, 6 color ramps (p/n/su/da/wa/in) + mint, semantic roles, radius
  (xs4…4xl32+full), 4-pt spacing, 4 elevation shadows, icon sizes, Poppins type
  scale (display/h1/h2/h3/body/bodySm/caption/overline). Intentionally diverges
  from theme.ts; used ONLY by the DS page.

B. Sections (foundations + components + motion)
- `dsShared.tsx` — SectionHeader/SubHead/Caption/NoteCard/SpecList/Stage on new tokens.
- `ColorSection.tsx` — 6 ramps + 8 semantic roles.
- `TypeSection.tsx` — Poppins weights + 8-role type scale.
- `SpaceFormSection.tsx` — spacing + new radius scale + elevation + icon sizes.
- `ComponentsSection.tsx` — composes the 13 component groups onto stages.
- `DsButtons.tsx` — 6 variants × 3 sizes × states (enabled/pressed/disabled/loading).
- `DsDivider.tsx` — h / labeled / inset / vertical.
- `DsControls.tsx` + `DsCheckMenu.tsx` (NEW) — switch (knob slide) / checkbox /
  radio (+ disabled) / checkmenu.
- `DsInputsChips.tsx` (NEW) — inputs (default/focus/error+hint); chips
  (filter/removable); tag; badges (cream/tan/soft); status (ok/warn/err/info).
- `DsListsTabs.tsx` (NEW) — list rows (value/chevron/danger); segmented; underline
  tabs; dark tab bar.
- `DsFloatingPill.tsx` (NEW) — springy floating-pill footer (overshoot).
- `DsCardsAvatar.tsx` (NEW) — item/outfit tile + pin (scale 1.06 + status slide);
  avatar 88/44 (initials/fallback); top app bar.
- `DsOverlays.tsx` — dialog / sheet / action-sheet.
- `DsToasts.tsx` (NEW) — snackbar (neutral + mint) + toast (spinner), live reveal.
- `DsDateKeyboard.tsx` (NEW) — calendar + time picker + keyboard.
- `MotionSection.tsx` (NEW) — section C: live demos + reduce-motion banner.
- `DsMotion.tsx` (NEW) — PressScale (.96 spring), DotsLoader (3-dot), SpinLoader
  (360° .8s), useToggleValue; all honor `useReducedMotion()`.
- `PrinciplesSection.tsx` — refreshed notes/caveats for the new system.
- `DsSurfaces.tsx` — DELETED (replaced by the split files above).
- `src/screens/DesignSystemScreen.tsx` — rebuilt on ds-tokens; hero/footer/topbar
  + Color→Type→Space→Components→Motion→Principles.

Doc (mandatory analytics rule)
- `docs/analytics/mixpanel-tracking-plan.md` — §5.9 entry for `design_system_opened`.

## Showcase coverage
DONE — Foundations: Color, Type, Space&Radius, Elevation, Icons.
DONE — Components (all 13): Buttons, Divider, Selection, Inputs, Chips/Tags/Badges,
List rows, Tabs/Segments (segmented+underline+dark bar+floating pill), Cards/Tiles,
Avatar, Navigation (top app bar), Overlays (dialog/sheet/snackbar neutral+mint/
action-sheet/toast), Date picker (calendar+time), Keyboard.
DONE — Motion (§C): button press scale .96 spring + 3-dot loader; switch knob
slide; tile pin scale 1.06 + pin-status slide-in; snackbar/toast opacity+scale +
toast spinner; floating-pill spring overshoot. All interactive + reduce-motion
fallback. Web-safe (`Animated`, no native-only APIs).

Note: "checkmenu" (section B) implemented as a static-ish checkbox menu; the
calendar uses a fixed June-2026 grid (showcase reference, not a live date engine).

## Gates
- `npx tsc --noEmit` → EXIT 0 (clean).
- `npx eslint` on changed files → EXIT 0 (0 problems). [full-repo `yarn lint`
  baseline is ~25k pre-existing problems incl. `web/` + legacy; my files add none.]
- `scripts/auxi-lint-tokens.sh` → NONE of my files flagged. (27 pre-existing
  violations exist in OTHER product screens — unrelated, out of scope.) DS-page-
  local hex/font live under `components/design-system/**` which the lint scope
  excludes by design; the in-scope `DesignSystemScreen.tsx` + `SidebarMenu.tsx`
  are token-only.

## Product screens untouched (`git diff --name-only main...HEAD`)
```
docs/analytics/mixpanel-tracking-plan.md
src/components/design-system/* (all)
src/components/layout/SidebarMenu.tsx
src/screens/DesignSystemScreen.tsx
```
No product screen/behavior changed. `DesignSystem` route was already registered
(navigation.ts + AppNavigator) — no nav change needed.

## Open items / notes
- File size: DsCardsAvatar (219), DsControls (202), DsMotion (202), ds-tokens
  (205) sit slightly over the <200 guideline. ds-tokens/DsMotion are infra
  (token data / motion helpers), not section files; DsCardsAvatar/DsControls are
  cohesive small-component groups — split further would hurt cohesion (KISS/DRY).
  Left intentionally; flag if the gate wants them broken up.
- Pre-existing dirty `scripts/post-testflight-release.sh` + `release-testflight.sh`
  in the submodule were NOT touched and NOT staged.
- Visual verification: NOT run (mobile-dev has no sim/mobile-mcp; iOS rebuild is
  shared-singleton and out of scope). Hand off to qa-ui (Compare) + designer gate.
- Deploy: NOT done (orchestrator owns the web-sandbox deploy).
```
```
