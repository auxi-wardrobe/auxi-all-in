# mobile-dev — GH-364 DS page: per-component animation pass

Branch: `feat/au-364-ds-page-claude-sync`
Date: 2026-06-24
Context: CEO reviewed sandbox — "animation các component KHÔNG ĐỦ". Component
specimens were mostly static; motion only lived in the dedicated MotionSection.
Goal: every specimen animates (interaction + entrance where it elevates) and is
interactive/auto-demo so motion is visible to a web reviewer.

## Commits

1. `5f7f52c6` style(ds): prettier reflow across DS specimens — committed the
   pre-existing uncommitted formatter churn first as a clean checkpoint (guard
   against branch-thrash losing work; pure line-wrapping, zero logic).
2. `a0ee9ff9` feat(ds): animate every component specimen — the substantive pass.

## Shared helpers added (DsMotion.tsx — extended, not duplicated)

- `useSpringToggle(on, native, spring)` — springs a 0↔1 value with
  `spring.confident` (brand overshoot). Drives check-mark / radio-dot / chip /
  calendar-day scale-ins.
- `usePressHighlight()` — returns `{ v, onPressIn, onPressOut }`; press → bg
  crossfade + small translate. Drives list rows, keyboard keys, topbar icons,
  tile press.
- `useEntrance(index, distance)` — staggered fade-up (opacity + translateY,
  `stagger.normal`, spring settle) for tile mount.

All reference motion.ts tokens; all branch on `useReducedMotion()` → jump to end
state (no transform/opacity/spin).

## Per-component: before → after

| Component | Before | After |
|---|---|---|
| Buttons (all variants + icon) | press scale + loader (already) | verified runs — unchanged |
| Switch | knob slide + track crossfade (already) | verified — unchanged |
| Checkbox | check popped in instantly | box fill crossfade + spring check-mark scale-in |
| Radio | dot popped in instantly | ring color crossfade + spring dot scale-in |
| Checkmenu | static highlight | row bg crossfade + spring check-mark per row |
| Filter chips | bg style swap (no anim) | bg crossfade + select pop (1→1.04→1 spring) |
| Removable chips | instant removal | collapse (scale→0 + fade) then unmount; Reset to replay |
| Segmented control | bg style swap | **SLIDING spring thumb** (translateX + width, spring) |
| Underline tabs | underline appeared under active | **SLIDING spring underline** (translateX + width) |
| Dark tab bar | color swap only | active icon springs up (scale 1→1.12) |
| Floating pill | spring overshoot (already) | verified — unchanged |
| List rows | static View | now Pressable: press bg fade + chevron nudge (translateX) |
| Dialog | always-visible static View | Show trigger + scale .92→1 + fade, backdrop crossfade, faster exit-eased close |
| Bottom sheet | always-visible static View | Show trigger + slide-up translateY + backdrop, faster close |
| Action sheet | always-visible static View | Show trigger + slide-up + staggered row fade-up |
| Snackbar (×2) | reveal + scale (already) | verified — unchanged |
| Toast | reveal + spinner (already) | verified — unchanged |
| Cards/tiles | pin press + status slide (already) | + entrance fade-up stagger on mount + press scale .97 |
| Avatar | static | left static (low-priority per brief; pure display) |
| Top app bar | Pressable, no feedback | icon press scale .88 + bg fade |
| Calendar day | bg style swap | ink fill springs in (scale + fade) |
| Time picker AM/PM | bg style swap | fill crossfade |
| Keyboard | static Views | keys now Pressable: press scale .92 + bg highlight |

## Asymmetry / brand feel

- Overlays: ENTER springs (spring.standard), CLOSE is a faster `duration.fast`
  timing with `easing.exit` — open/close asymmetry per motion-rules.
- Spring overshoot (the brand signature) used for selection scale-ins, chip pop,
  sliding indicators, tab-bar icon — not generic linear fades.

## Left intentionally static / why

- **Avatar** — pure display specimen, brief marked low-priority / skippable.
- **Inputs (default/focus/error)** — these are *state* specimens shown
  side-by-side to document the three states; animating focus between them would
  misrepresent the spec board. Field borders already encode state.
- **Tags / badges / status pills** — static status indicators, not interactive;
  no interaction to demo.
- **Dividers** — layout, non-interactive.

## Verification

- `npx tsc --noEmit` — clean (no new errors; legacy _HomeScreen unaffected).
- `npx eslint src/components/design-system/` — clean (0 errors/warnings).
- `scripts/auxi-lint-tokens.sh` — design-system/** is NOT in the script's scan
  set (it scans screens + components/features + components/layout). 27 violations
  reported are all pre-existing in OTHER files (ItemDetailScreen color picker,
  etc.) — none from this work. My added literals are `rgba()` forms, explicitly
  whitelisted.
- `yarn web:build` — succeeds (888ms). Confirms all `Animated` interpolations
  (incl. color/layout drivers with useNativeDriver:false) bundle for
  react-native-web — the actual sandbox target.

## Scope confirmation

`git diff --name-only origin/feat/au-364-ds-page-claude-sync` → all changes in
`src/components/design-system/**` (+ the earlier-committed
`src/screens/DesignSystemScreen.tsx` from prior session work). No product
screens, no `theme.ts`, no `motion.ts` touched. Within allowed paths.

## Notes / open items

- Did NOT deploy the sandbox — orchestrator redeploys per instruction.
- Nested-pressable on the pinnable tile (pin button inside tile Pressable): both
  the tile press-scale and the pin toggle fire on a pin tap. Visually fine for a
  demo (tile dips while pinning); flag if a reviewer wants them isolated.
- Reduce-motion fallback is wired through every new helper but only mechanically
  verified (logic branch + tsc), not visually toggled on-device this session —
  no simulator run (JS-only / web-target task).

## Unresolved questions

- None blocking. If the CEO wants entrance stagger applied section-wide (not just
  tiles), that's a cheap follow-up via `useEntrance` — held back per YAGNI /
  brief's "nice-to-have, only if cheap".
