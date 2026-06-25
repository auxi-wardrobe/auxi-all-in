# Plan — Migrate product screens onto M* primitives + force DS usage (GH-364)

**Goal:** product pages currently build UI ad-hoc (214 raw Pressable, 27 raw TextInput, 18 PillButton, 33 Button atom, 6 modal styles → "loạn"). Migrate them to the `M*` primitive lib (`src/components/design-system/lib/`) for consistency, and **enforce** (mobile-dev must use M*, not bespoke). PLAN ONLY — no code yet.

## Ground truth (from audit)
- 13 active product screens, large; heaviest chaos = buttons + text inputs + modals.
- M* lib covers most needs. Clean drop-ins: MInput, MSwitch, MIconButton, MDialog, MBottomSheet, MListRow, MButton (≈atoms/Button).
- Gaps / no direct M*: **PillButton (18 uses)**, PressableScale (2), feature cards (OutfitCard/Skeleton/Shimmer — stay bespoke).
- Token delta `m-tokens` vs `theme.ts`: numerically >80% overlap, but real visual shifts — `radius.sm 4→6`, `radius.3xl 18→24`, primary near-black→warm taupe (#262321), new ramps (info/warning/mint). Blast radius wide (≈78 files) but **centralized in theme.ts**.
- Reconcile = value-swap feasible (theme.ts adopts m-tokens as canonical). Cautions: (a) weight 600/700→Poppins faces, (b) **m-tokens has NO dark tokens** while auth/UAC screens are dark, (c) M* are behavior-rich (motion/a11y) — not silent swaps.

## ⚠️ Decisions needed before execution (recommendations marked ✅)
- **D1 Token strategy / visual shift.** ✅ Unify: make `theme.ts` adopt m-tokens as the canonical source (additive), so M* + product share one system. Consequence: **app-wide visual change** (radius, primary taupe, ramps) — needs CEO/designer sign-off per cohort. (Alt: keep two systems, migrate per-screen — messier, deferred debt.)
- **D2 PillButton (18 uses).** ✅ Absorb into `MButton` (add a `pill`/size variant + leading/trailing) and migrate; retire PillButton. (Alt: keep PillButton as a thin MButton wrapper.)
- **D3 Enforcement hardness.** ✅ New rule `design-system-primitives-required.md` + update `mobile-dev.md` + a lint check flagging raw TouchableOpacity/TextInput/Switch in `src/screens/**` where an M* exists. Warn-first → error after Phase 3. PR-gated.
- **D4 Dark mode.** ✅ Add `inverse`/dark roles to the DS (m-tokens) BEFORE migrating auth/UAC dark screens (else two color systems).
- **D5 Pace.** ✅ Cohort-by-cohort, each cohort = sandbox preview + designer gate + qa before next.

## Phases

### Phase 0 — Enforcement scaffolding (no screen changes)
- Add `.claude/rules/design-system-primitives-required.md` (mandate M* for button/input/switch/dialog/sheet/list-row/chip; bespoke only with written justification).
- Update `.claude/agents/mobile-dev.md`: new "Design System primitives (mandatory)" section + skill/trigger row; keep Figma + theme rules.
- Add lint: extend `scripts/auxi-lint-tokens.sh` (or new `auxi-lint-ds-primitives.sh`) — flag raw `TouchableOpacity`/`Pressable`-as-button, raw `TextInput`, raw `Switch` in `src/screens/**`. Warn mode first.

### Phase 1 — Token unification (prereq, 1 pass, designer sign-off)
- `theme.ts` adopts m-tokens values as canonical (radius/spacing/color/type), additive; map font weights → Poppins faces; add dark/inverse roles.
- Verify: tsc/lint/web-build; visual diff sandbox; designer gate (this changes the whole app's look). NO screen logic touched.

### Phase 2 — Primitive parity
- MButton absorbs PillButton variants (pill/size, leading/trailing, soft→secondary); bake PressableScale-style press into M* where needed. Confirm M* covers every product button/input/modal case before mass migration.

### Phase 3 — Cohort migration (component-by-component, screen-by-screen)
- **Cohort A (quick win, establishes pattern):** auth inputs → MInput (EmailInput/SignIn/PasswordCreation/Reset); SettingsScreen → MSwitch/MDialog/MListRow; ItemDetailScreen → MBottomSheet/MDialog.
- **Cohort B:** Home, Wardrobe, Body, Favourite, SeeThisOnMe, OutfitCanvas, Feedback, Onboarding.
- Per screen: swap to M*, keep feature-specific components (OutfitCard etc.), run tsc/lint/ds-lint, sandbox preview → **designer/CEO review (visual change)** → qa → next.

### Phase 4 — Cleanup + hard gate
- Remove legacy atoms/Button + FigmaPrimitives (PillButton/TopIconButton/DividerRow/BottomSheetSurface) once all call sites migrated.
- Flip ds-primitive lint from warn → error (the "force" is now mechanical).

## Verification (every phase)
`npx tsc --noEmit` · eslint · `auxi-lint-tokens.sh` + ds-primitive lint · `yarn web:build` · sandbox preview · designer gate (visual) · qa-mobile smoke.

## Risks
- Visual regressions (token shift) — mitigate via per-cohort sandbox + designer gate.
- Dark auth screens (D4) — gate auth cohort behind dark-roles work.
- Large screens (Home 1490 LOC) — migrate incrementally, don't rewrite logic.
- Concurrent CC sessions — JS-only, branch-isolated, no native rebuild.

## Decisions (CEO, 2026-06-24)
- **D1 ✅ UNIFY app-wide** — theme.ts adopts m-tokens as canonical; whole-app visual shift, per-cohort designer sign-off. (Phase 1.)
- **D2 ✅ PillButton ABSORBED into MButton** (add pill variant/size) — Phase 2.
- **Scope NOW = Phase 0 ONLY** — enforcement scaffolding (rule + mobile-dev agent + warn-lint). **STOP for review** before Phase 1 (token unify).
- D3 enforcement: lint **warn-first** now → **error** at Phase 4 (PR gate).
- D4 dark roles: still required before the auth cohort (in Phase 1).
