# mobile-dev — Home hamburger menu a11y / hit-target fix

**Date:** 2026-06-17 23:46
**Scope:** `auxi/` only. New follow-up change in working tree (PR #87 already merged the 6 bug fixes; this is separate, uncommitted).
**Ticket context:** Home `home-menu-button` invisible to VoiceOver + Maestro/mobile-mcp — blocks the only path to Wardrobe + Favourites drawer.

## Root cause (singular)

`TopIconButton` (`auxi/src/components/primitives/FigmaPrimitives.tsx`) rendered its
`TouchableOpacity` with **no `accessibilityRole`**. Its only child is an SVG icon
(`<IconHomeMenu>`) — no text node. On iOS, a `TouchableOpacity` with an SVG-only
child and no explicit role does **not** enter the accessibility tree, so:
- VoiceOver can't announce or activate it.
- Maestro / mobile-mcp can't resolve it as a tappable element (testID alone isn't
  enough when the node isn't accessibility-exposed).

The heart/favourite button (`HomeScreen.tsx:1737`) works because it's a raw
`TouchableOpacity` that **does** set `accessibilityRole="button"`. The menu button
already had a correct `accessibilityLabel={t('home.a11y_open_menu')}` and
`testID="home-menu-button"` — only the role was missing.

### Hit-zone / set-pager overlay theory — investigated, NOT the cause

The dev note at `HomeScreen.tsx:~2569` ("`home-set-pager` … stray long swipes
mis-arbitrate to the hamburger") is **legacy text** describing the old AU-303
two-axis vertical FlatList pager, which was **replaced** by the Tinder-style
`OutfitSwipeDeck` (`HomeScreen.tsx:1882-1886`). Verified the current layout does
not overlay the header:
- `styles.header` and `styles.deckWrap` (`flex: 1`, `paddingTop: 4`) are **flex
  siblings** in the SafeAreaView column — deck sits *below* the header in normal
  flow. No `position: absolute`, no negative margin, no `zIndex` lifting the deck
  over the header.
- `OutfitSwipeDeck` (`src/components/features/OutfitSwipeDeck.tsx:117-138`) uses
  **only** `onMoveShouldSetPanResponder` (requires `|dx|>|dy|` AND `|dx|>6`) — it
  never claims the down-press via `onStartShouldSetPanResponder`, and its cards are
  `position: absolute` inside a `position: relative` stack confined to its own
  bounds. It cannot intercept a tap on the header.
- The earlier arbitration leak was already neutralised by `scrollEnabled={false}`
  on the inner grid ScrollView (`HomeScreen.tsx:2575`).

Conclusion: no z-order / pointerEvents fix required for the current Tinder-deck
layout — the menu button is geometrically reachable; the only defect was the
missing a11y role. No hit-zone change made (would have been dead code / scope creep).

## Exact changes

### 1. `auxi/src/components/primitives/FigmaPrimitives.tsx` (the real fix — covers all icon-only TopIconButtons)
- **Import** (`+AccessibilityRole`): added `AccessibilityRole` to the `react-native` import.
- **`TopIconButtonProps`**: added optional `accessibilityRole?: AccessibilityRole;` with an explanatory comment.
- **Component body** (`~line 57-78` post-edit):
  - destructure `accessibilityRole = 'button'` (defaults to `button` — every TopIconButton is one).
  - pass `accessibilityRole={accessibilityRole}` to the `TouchableOpacity`.
  - also pass `accessibilityState={{ disabled: !!disabled }}` so disabled icon buttons announce state correctly to VoiceOver.

This single change exposes **every** `TopIconButton` usage in the app to the a11y
tree, not just the menu button — DRY, no per-call-site churn.

### 2. `auxi/src/screens/HomeScreen.tsx` (`~line 1721`, menu button usage)
- Added explicit `accessibilityRole="button"` to the `home-menu-button`
  `TopIconButton` (defensive — survives any future `TopIconButton` refactor that
  might change the default) plus a comment documenting why the SVG-only icon needs
  an explicit role and why testID vs accessibilityLabel differ in value.
- `testID="home-menu-button"` (machine selector) and
  `accessibilityLabel={t('home.a11y_open_menu')}` (human VoiceOver text) — kept,
  values intentionally differ per `auxi/CLAUDE.md` convention.

## i18n keys

**None added.** `home.a11y_open_menu` already exists in all three locales:
- `en-EN.json:372` `"Open menu"` (and dup at `:559`)
- `vi-VN.json:372` `"Mở menu"` (and dup at `:558`)
- `fr-FR.json:372` `"Ouvrir le menu"` (and dup at `:559`)

## Analytics

None. Pure a11y/hit-target fix per task. `handleLeadingAction` → `openSidebar()`
already exists; no new handler, no tracking site introduced. (`analytics-tracking-required`
rule: this is a behavior-preserving a11y exposure, not a new interaction.)

## Verification

- **`npx tsc --noEmit`** (Node 20.12.2 via `nvm use 20`): **CLEAN** — zero `error TS`
  across the whole project, including the two touched files.
- **`eslint`** on both touched files: my changes add **0 new** problems.
  `FigmaPrimitives.tsx` lints clean. The one `HomeScreen.tsx:685:6`
  exhaustive-deps error is **pre-existing** — verified by stashing my edit and
  re-linting (error still present); it's a `useEffect` ~1040 lines above my edits,
  untouched by this change.
- **Simulator:** NOT run this session (no sim launched). Code-complete; visual /
  VoiceOver / Maestro verification pending — hand to `qa-mobile` (mobile-mcp tap of
  `home-menu-button` → drawer opens) and/or `qa-ui`.

## Files changed (working tree, uncommitted)

- `auxi/src/components/primitives/FigmaPrimitives.tsx` (+9)
- `auxi/src/screens/HomeScreen.tsx` (+7)

## Open questions

- The duplicate `a11y_open_menu` blocks in each locale (`:372` and `:558/559`)
  suggest two `home`-ish namespaces in the translation files — out of scope here,
  but worth a cleanup ticket if intentional dedupe is wanted.

---
**Status:** DONE
**Summary:** Root cause was `TopIconButton` omitting `accessibilityRole`, keeping the SVG-only menu button out of the iOS a11y tree (invisible to VoiceOver + Maestro/mobile-mcp). Added `accessibilityRole` support to `TopIconButton` (defaults `button`) + explicit `accessibilityRole="button"` on the menu usage. The set-pager overlay theory was investigated and ruled out (deck is a flex sibling below the header, move-only PanResponder — no touch interception), so no hit-zone change was needed.
**Files changed:** `auxi/src/components/primitives/FigmaPrimitives.tsx`, `auxi/src/screens/HomeScreen.tsx` (uncommitted, working tree)
**Concerns/Blockers:** None blocking. tsc clean; no new lint. Sim/VoiceOver/Maestro verification not run this session — needs qa-mobile tap-through of `home-menu-button` → drawer opens. Pre-existing `HomeScreen.tsx:685` exhaustive-deps lint error is unrelated to this change.
