# GH-364 — Update in-app Design System page to new claude.ai DS + gate menu

## Goal
1. **Gate** a "Design System" entry in the sidebar menu — visible ONLY when logged-in `user.email ∈ {duc2820@gmail.com, vietdesign81@gmail.com}`.
2. **Rebuild the DS page** (`DesignSystemScreen` + `src/components/design-system/*`) to match the NEW claude.ai showcase, **including motion/animation**.
3. Deploy to the **web sandbox** for CEO review.

## HARD GUARDRAILS
- **Do NOT change any product/app screen or behavior.** Touch ONLY: `src/components/layout/SidebarMenu.tsx` (1 gated row), `src/screens/DesignSystemScreen.tsx`, `src/components/design-system/**`, and (allowed) a NEW DS-page-local token module. Nothing else.
- **JS-only — hot-reload, NO native rebuild** (per `.claude/rules/ios-build-workflow-required.md`). No new native deps. Use existing `react-native-reanimated`/`Animated` already in the app.
- **Poppins-only** (CEO 2026-06-24). Do not add Inter/Roboto. Mono → existing platform-mono fallback (`dsShared.MONO_FAMILY`), spec overlines only.
- **Do NOT mutate `theme.ts` / `theme.ds.*`** (product screens depend on it). The new DS radius scale + color ramps DIVERGE on purpose — put them in a DS-page-local token const (e.g. `src/components/design-system/ds-tokens.ts`), used ONLY by the DS page.
- Web-compatible (renders on react-native-web sandbox). Prefer `Animated`/reanimated APIs that work on web; gate anything web-unsafe.

## Authoritative source
`plans/260624-0030-GH-364-design-system-page/reference/auxi-showcase.reference.css` — exported from claude.ai/design "auxi" (`Auxi Design System Showcase.html` → `auxi-showcase.css`). Every value (radius/color/shadow/size/state) comes from there. The OLD `auxi-ds.css` (Roboto/Inter) is superseded — ignore.

## Current state (audited)
- `DesignSystemScreen.tsx:54-69` renders: ColorSection, TypeSection, SpaceFormSection, ComponentsSection, PrinciplesSection. Hero+footer bookend.
- DS components in `src/components/design-system/`: ColorSection, TypeSection, SpaceFormSection, ComponentsSection (composes DsButtons+DsControls+DsSurfaces), PrinciplesSection, dsShared (SectionHeader/SubHead/Caption/NoteCard/MONO_FAMILY).
- Route already registered: `AppNavigator.tsx:158-161` name `'DesignSystem'` (post-auth stack). **No new nav registration needed.**
- Menu: `SidebarMenu.tsx:86-137` hardcoded `<MenuItem>` rows (Wardrobe/Favourite/Feedback/Settings/Outfit Canvas/Logout). No DS entry today. `const { user } = useAuth()` → `user?.email` (string, `types/auth.ts:28`).
- Motion tokens exist: `theme/motion.ts` (duration instant50/fast120/normal250/medium350/slow500/reveal700; easing standard/enter/exit/emphasized; scale press.97/background.96/select1.03/emphasis1.05; spring soft/standard/confident; `useReducedMotion()`). **Reuse these — do not invent durations.**

## Work

### A. Menu gate (small)
In `SidebarMenu.tsx`: read `const { user } = useAuth()`. Add `const DS_EMAILS = ['duc2820@gmail.com','vietdesign81@gmail.com']`. Render a new `<MenuItem>` "Design System" (→ `navigation.go('DesignSystem')`, testID `sidebar-menu-design-system`, an icon e.g. grid/sparkle) **only if** `user?.email && DS_EMAILS.includes(user.email.toLowerCase())`. Place above Logout.
- Analytics: optional (internal admin gate). If trivial, add `track('design_system_opened')` via `services/analytics.ts`; else log a §6 gap. Do NOT block on it.

### B. DS-page rebuild to new showcase (large)
Update existing 5 sections to new token values AND add the missing component sections so the page mirrors the showcase's 13 component groups + foundations. Keep EACH section file < 200 lines (split as needed). Sections to cover (source = reference CSS):
- **Foundations:** Color (new ramps p/n/su/da/wa/in + semantic roles) · Type (Poppins-only, scale display40/h1 32/h2 24/h3 20/body16/body-sm14/caption12/overline10) · Space&Radius (4-pt scale + NEW radius xs4/sm6/md8/lg10/xl12/2xl16/3xl24/4xl32/full999) · Elevation (card/raised/dialog/sheet) · Icons (size L32/M24/S16).
- **Components:** Buttons (primary/outline/text/danger/danger-outline/icon; sizes lg56/md44/sm32; states enabled→pressed→disabled→loading) · Divider (h + labeled + inset) · Selection (switch/checkbox/radio + checkmenu) · Inputs (default/focus/error) · Chips/Tags/Badges (suggestion/removable/filter + tag + badge cream/tan/soft + status ok/warn/err/info) · List rows (value/chevron/danger) · Tabs/Segments (segmented + underline tabs + dark tab bar + floating pill footer) · Cards/Tiles (item + outfit + pin/pin-status) · Avatar (88/44 + initials/fallback) · Navigation (top app bar) · Overlays (dialog/sheet/snackbar neutral+mint/action-sheet/toast) · Date picker (calendar + time picker) · Keyboard.
- **Patterns:** keep/refresh example screens if present.

### C. Motion/animation (the explicit CEO ask — "nhớ để ý")
Wire real interaction motion, mapped to `motion.ts` tokens + honor `useReducedMotion()`:
- Button press → `scale(.96)` spring (`spring.confident` / `scale.background`), no shadow/opacity change. Loading → 3-dot loader (`auxiDot`: 1s loop, dot delays 0/.16/.32, opacity .3→1 + scale .72→1).
- Switch knob slide ~`duration.fast`(120-180). Tile pin: press → `scale(1.06)` (`duration.fast` ~160); pin-status slide-in (opacity+translateY -3→0, ~200ms).
- Snackbar/Toast: opacity + `scale(.9→1)` ~200ms; toast spinner = continuous 360° rotate .8s linear (`atoastSpin`).
- Footer floating-pill thumb: spring **overshoot** — `cubic-bezier(.34,1.32,.5,1)` ~340ms on translateX/width (this is the signature springy nav; map to `spring.confident` or a custom withSpring).
- Make these LIVE/interactive in the showcase (tappable demos) where feasible, with a reduce-motion fallback.

## Gates (after build)
1. `cd auxi && npx tsc --noEmit && yarn lint` clean.
2. `./scripts/auxi-lint-tokens.sh` — note: DS-page-local tokens are intentional; ensure no raw hex leaks into non-DS screens.
3. designer review (this IS the DS page — high relevance).
4. Confirm product screens unchanged (git diff scoped to the 4 allowed paths).

## Deploy
After gates pass → deploy web sandbox (`deploy-auxi-web` skill, CF `auxi-web-review`) → return preview URL. NOTE: menu entry is email-gated, so to see it on sandbox the reviewer logs in as duc2820@gmail.com / vietdesign81@gmail.com (the `DesignSystem` route is also reachable in `__DEV__` via Settings→Version).

## Unresolved
- New DS radius/colors diverge from theme.ts — confirmed intentional (DS page = new target; product migration is a later, separate task).
- Header height 107 vs 76 — out of scope here (tracked in GH-364 gap report).
