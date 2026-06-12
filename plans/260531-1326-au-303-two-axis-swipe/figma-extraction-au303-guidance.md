# Figma Extraction — AU-303 Two-Axis Home Swipe + Guidance Overlays

> **GateGuard facts**: (1) New extraction doc, linked from `plan.md` / `phase-01-figma-extraction.md`. (2) No duplicate — confirmed via `ls`, file did not exist before this write. (3) No data I/O — markdown artifact only. (4) User instruction = "follow AU-303 spec / fix wrong swipe behavior".

- **Ticket**: AU-303 — Home outfit exploration on TWO axes (horizontal = browse 3 outfits within a set, vertical = next/previous set of 3) + two first-time guidance overlays.
- **Figma file**: `0nXXMAR4Arf1ZfjtQvtBh0`
- **Section node**: `3140:8191` — "Home | behavior guide" (1746×1212, contains 3 frames).
- **Plan**: `plans/260531-1326-au-303-two-axis-swipe/`
- **Extracted**: 2026-05-31 by mobile-dev
- **Scope of THIS artifact**: the two guidance overlays (net-new UI) + the home-active pagination/button chrome that drives the two-axis interaction. Header/footer/grid-item shells already shipped (AU-253 Home grid) — referenced, not re-specced.

---

## Frame map (corrects the task brief's frame ordering)

The screenshot shows 3 phones L→R, but the Figma frame names/triggers are:

| Phone (L→R) | Frame node | Frame name | Role |
|---|---|---|---|
| Left | `3140:9395` | **"first time"** | HORIZONTAL guidance overlay (single-line copy, `material-symbols:swipe-outline` 54×54). Overlay node `3140:9520`. Button = "Got it" only — there is NO inactive "See another" button inside the overlay; the dimmed "Show another" the brief refers to lives in the **home chrome behind** the backdrop. |
| Center | `3140:8227` | **"Home 1/3"** | Home ACTIVE — 2×2 item grid, pagination row (`Remix` ◦ `• • •` ◦ `Show another`), `Wear this ♡` CTA, footer view toggle. No overlay. |
| Right | `3140:9763` | **"after see 1 set (3 options)"** | VERTICAL guidance overlay (two-line copy, custom `icons` swipe-up vector 54×54). Overlay node `3140:9797`. Button = "Got it" only. |

> **Brief mismatch flagged**: the brief says the horizontal overlay shows an inactive "See another" button and the vertical overlay shows an active one. In Figma BOTH overlays contain only a single "Got it" text button. The active/inactive "Show another" difference is a property of the **home pagination row behind the overlay**, not the overlay card. See §6.

---

## 1. Guidance overlay — HORIZONTAL ("first time", node `3140:9520`)

### Backdrop (node `3140:9521`, "Rectangle 346")
- Full-bleed `418 × 897`, positioned `x:-2 y:-1` (overscans the 414-wide frame by 2px each side — i.e. cover the whole screen).
- Fill: `background/primary/bold_600` = **#262421**, **opacity 70%**.
- → token: NO exact match. Closest is `figmaButtonDark`/`figmaCtaLabel` family but those are solid. **DRIFT — needs new token** (see §8).

### Overlay card (node `3140:9522`, "Basic Dialog")
- Width **366**, vertically centered (`top: 50%`, translateY -50%), `left: 24` → 24px horizontal inset each side (366 + 24×2 = 414). Height HUGs content (Figma measured 238).
- Corner radius `border-radius/2xl` = **16** → `theme.borderRadius.l` (16) ✓.
- Background `background/neutral/subtlest` = **#FFFFFF** → `theme.colors.white` / `uacBackgroundNeutralSubtlest` (#fcfcfd ✗ — this is pure #FFFFFF, use `theme.colors.white`).
- `overflow: clip`, auto-layout VERTICAL, `align-items: center`.
- **Effect**: none in metadata (no drop shadow on card).

### Title & Description block (node `3140:9523`)
- VERTICAL auto-layout, `gap 16`, padding `top 24 / x 24 / bottom 4`.
- Children: icon (54×54) → headline text.

### Icon (node `3140:9642`, "material-symbols:swipe-outline")
- Size **54 × 54**.
- This is the **horizontal hand-swipe** icon. Asset already in repo: `src/assets/images/icon_swipe_hand.svg` (54×54 viewBox, fill `#070707`). **Already wired** via `SwipeCoachMark.tsx`. No export needed.

### Headline (node `3140:9524`)
- String (verbatim): **"Swipe left or right to explore different outfit options."**
- Style `Text-md (l-24)/Regular`: family **Poppins**, weight 400, size **16**, line-height **24**, letter-spacing 0.
- Color `text/neutral/base` = **#1d1f23**.
- Align: **center**. `min-width: 100%` (fills card width minus padding).
- → token: `theme.typography.aliases.poppinsBody` (Poppins-Regular 16/24) ✓. Color → `uacTextBase`/`figmaText`? `#1d1f23` = `uacTextBase` ✓ (NOT `figmaText` #272A32).

### "Got it" CTA (nodes `3140:9533` Actions → `3140:9535` Button)
- Actions block: `align-items: end, justify: center`, padding `top 12 / x 24 / bottom 24`, full width.
- Button: text-only (Figma component `Hierarchy=Text button, State=Enable, Icon=No, Size=56`, node `470:2533`). Container invisible until pressed (per component doc — low-emphasis text button).
- Height **56**, radius **100** (pill), padding-x 20, content centered. `flex: 1` up to `max-width: 327`.
- Label "Got it": `Text-md (l-24)/Medium` — Poppins Medium 16/24, color `text/neutral/base` #1d1f23.
- → `theme.typography.aliases.poppinsButton` (Poppins-Medium 16/24) ✓. Radius → `uacRadioPill` (100) ✓. Height → `uacButtonHeight` (56) ✓.

---

## 2. Guidance overlay — VERTICAL ("after see 1 set", node `3140:9797`)

Identical structure to §1 with these deltas:

### Backdrop (node `3140:9798`)
- Same: #262421 @ 70%, full-bleed.

### Card (node `3140:9799`)
- Same: 366 wide, centered, radius 16, white. Height HUGs (measured 254, taller — two copy lines).

### Icon (node `3140:9902`, "icons")
- Size **54 × 54**. This is the **swipe-up** hand icon — a different vector from the horizontal one. Composed of 2 vectors (instance `2403:13629` + `2403:13630`); it's the `Icons` component variant **`name="swipe"`** (the same component used at 16px in the "Show another" button, node `2403:13628`).
- **In repo**: `src/assets/images/icon_swipe.svg` exists — needs verification it matches THIS swipe-up vector (vs `icon_swipe_hand.svg` which is the horizontal one). **Open question Q-ICON** (see §8). If mismatch → export node `3140:9902` as `icon_swipe_up.svg` with `currentColor` fill.

### Copy — TWO text nodes (NOT one)
- Node `3140:9803`: **"Swipe up to explore another outfit set."**
- Node `3140:9906`: **"Swipe down to go back"** (note: no trailing period in Figma).
- Both: `Text-md (l-24)/Regular` Poppins 400 16/24, color #1d1f23, **center**.
- Title&Description block (`3140:9800`) gap 16 → both lines are separate flex children with 16px gap (visually they read as 2 lines but are distinct nodes; the period/no-period split is intentional per design).

### "Got it" CTA (nodes `3140:9806` → `3140:9808`)
- **Identical** to §1 "Got it" — same text button, "Got it", Poppins Medium 16/24, #1d1f23, pill h56.

---

## 3. Overlays are visually IDENTICAL except: icon + copy

The only diffs between the two overlays:
| Property | Horizontal (§1) | Vertical (§2) |
|---|---|---|
| Icon | `icon_swipe_hand.svg` (54) | swipe-up vector (54) — Q-ICON |
| Copy | 1 line | 2 lines |
| CTA | "Got it" | "Got it" (same) |
| Backdrop / card / radius / fonts | same | same |

→ Implementation recommendation (for `figma-to-rn-workflow`, NOT this artifact): the existing `SwipeCoachMark.tsx` should be **parameterized** (icon + copy lines + storage key) to render both, rather than a second bespoke component. Keeps DRY.

---

## 4. Home-active chrome (node `3140:8227` "Home 1/3") — context for the two-axis interaction

The 2×2 grid + pagination + CTA is the EXISTING `optionSheet` shell already in `HomeScreen.tsx` (answers Q1). Specced here only for the parts AU-303 touches.

### 4.1 Item grid (Frame 2009 `3140:8241` → rows `3140:8242`/`3140:8245`)
- 2 rows × 2 cols. Each row: HORIZONTAL, gap **4** (`GRID_GAP` in HomeScreen ✓). Rows stacked gap 4.
- Each tile (`Image 3:4`): aspect **3/4**, `flex:1`, bg `background/primary/subtle_50` #f2efec (`figmaCardSurface` ✓), radius `border-radius/xl` **12** (`figmaTile` ✓).
- Pin badge top-right (already shipped). "common" tag bottom-center: bg `color/neutral/black/Alpha300` rgba(18,18,18,0.75) (`figmaCardTag` ✓), radius 8, text Inter Regular 10/12 (`interCaptionXxs` ✓ — note Figma var says Inter; family-token resolves to Poppins but the tag node explicitly uses Inter) color #fcfcfd. Already shipped.

### 4.2 Pagination row (Frame 2105 `3140:8248`) — **the two-axis driver**
- HORIZONTAL, `justify: space-between`, full width (382), height 32.
- **Left = "Remix" button** (`3140:8249`): text-icon button, ENABLED (full opacity). Label "Remix" Inter Regular 12/16 (`uacBodyXsRegular` ✓), color #1d1f23. Icon = `Icons name="mix"` 16×16 (the `✂`-looking mix glyph). Pill, gap 8, padding-x 12, radius 100.
  - → This is the existing Home "Remix" → AU-285 Outfit Canvas (per MEMORY). NOT net-new.
- **Center = pagination dots** (`3140:8250` → `3140:8251`): three 4×4 ellipses, gap **8** (positions x12/x24/x36 within a 52-wide frame). 
  - **Active dot color** `icon/primary/bold_500` = **#5b5550** (`figmaChipBg` ✓ — same hex).
  - **Inactive dot color** `icon/primary/subtle_300` = **#c6bcb1**. **DRIFT — no token** (see §8).
  - In "Home 1/3" the FIRST dot is active (1 of 3 within the set) — confirms dots = horizontal position within the 3-outfit set.
- **Right = "Show another" button** (`3140:8255`): text-icon button, **`opacity: 50`** (DISABLED — Figma component `State=Disable`, node `2403:13611`). Label "Show another" Inter Regular 12/16 #1d1f23. Icon = `Icons name="swipe"` 16×16 (swipe-up glyph). Pill, gap 8, padding-x 12, radius 100.
  - **This is the brief's "See another"** — actual label is **"Show another"**. It is shown INACTIVE/50% in the home-active frame (this is the captured state; presumably active when a next set exists).

### 4.3 "Wear this" CTA (Frame 2035 `3140:8256`)
- Two button instances: `3140:8257` (160.5w) is **hidden** (`hidden=true`) — do NOT render. `3140:8258` (327w, centered) is the live one.
- Secondary button (`Hierarchy=Secondary, Size=56`): border 1.5px `border/neutral/base` #1d1f23, radius **16**, padding 20×16, gap 8.
- Label "Wear this" Poppins Medium 16/24, color `border/primary/bold_600` **#262421** (`figmaCtaLabel` ✓). Heart icon 24×24 (`Icons` heart vector). Already shipped.

### 4.4 Footer view toggle (`3140:8260` footer instance) + header (`3140:8259`)
- Already shipped (AU-253 Home grid). Active-tab pill `background/primary/subtle_200` #eee6df (`figmaFooterActivePill` ✓). Not re-specced.

---

## 5. Tokens used (full list + mapping to `auxi/src/theme/theme.ts`)

| Figma token | Value | theme.ts mapping | Status |
|---|---|---|---|
| `background/primary/bold_600` | #262421 | `figmaCtaLabel` / `figmaButtonDark`(✗ #121212) | solid match (`figmaCtaLabel`); **@70% opacity has no token** |
| `background/neutral/subtlest` | #FFFFFF | `theme.colors.white` | ✓ |
| `border-radius/2xl` | 16 | `theme.borderRadius.l` (16) | ✓ |
| `text/neutral/base` | #1d1f23 | `uacTextBase` | ✓ |
| `font-family/body` + `body/md` Regular | Poppins 16/24 | `poppinsBody` | ✓ |
| `body/md` Medium | Poppins-Medium 16/24 | `poppinsButton` | ✓ |
| `uacButtonHeight` / Size=56 | 56 | `uacButtonHeight` | ✓ |
| radius 100 (pill) | 100 | `uacRadioPill` | ✓ |
| padding 24 (card x), 24/12 actions | 24/12 | `uacDimension24`, `uacDimension12` | ✓ |
| gap 16 (title block) | 16 | `spacing.m` (16) / `uacDimension16` | ✓ |
| `icon/primary/bold_500` (active dot) | #5b5550 | `figmaChipBg` (#5b5550) | ✓ (same hex, semantically reused) |
| `icon/primary/subtle_300` (inactive dot) | #c6bcb1 | — | **DRIFT (new token)** |
| `background/primary/bold_600` @70% (backdrop) | #262421 @ .70 | — | **DRIFT (new token)** |
| `border/primary/bold_600` (Wear this label) | #262421 | `figmaCtaLabel` | ✓ |
| `body/xs` Regular | Inter 12/16 | `uacBodyXsRegular` | ✓ |

---

## 6. Variants / states

| Element | States in Figma | Notes |
|---|---|---|
| "Got it" button | Enable only (component `470:2533`). Pressed = container becomes visible (per component doc). | Implement default + pressed (low-emphasis text button reveals container on press). |
| "Show another" button | **Enable** (`2403:13607`) AND **Disable** (`2403:13611`, opacity 50). | Home-active frame captures the **Disable** state. Wire enabled when a next set exists, disabled (opacity 50) otherwise. |
| "Remix" button | Enable only (`2403:13607`). | Existing AU-285 entry. |
| Pagination dots | active (#5b5550) vs inactive (#c6bcb1). | 3 dots, index = horizontal position within the 3-outfit set. |
| Overlays | single appearance each; no hover/pressed on backdrop documented. | Dismiss interaction not encoded in Figma — see Q3. |

---

## 7. Icons needed

| Icon | Size | Status |
|---|---|---|
| Horizontal hand-swipe (`material-symbols:swipe-outline`, node `3140:9642`) | 54×54 | **Exists** — `icon_swipe_hand.svg`, wired in `SwipeCoachMark.tsx`. |
| Vertical swipe-up (`icons` swipe variant, node `3140:9902`) | 54×54 | **Verify** — `icon_swipe.svg` exists but unconfirmed it matches this swipe-up vector. Q-ICON. If mismatch, export node `3140:9902` → `icon_swipe_up.svg` (currentColor). |
| Mix glyph (`Icons name="mix"`, pagination "Remix") | 16×16 | Existing (AU-285 chrome). |
| Swipe glyph (`Icons name="swipe"`, pagination "Show another") | 16×16 | Same family as swipe-up; existing or share with Q-ICON asset. |

---

## 8. Open questions for CEO / tech-lead

- **Q-DRIFT-1 (backdrop token)**: overlay dim = `background/primary/bold_600` (#262421) at **70% opacity**. No theme token for this. Existing `SwipeCoachMark.tsx` already renders a backdrop — confirm its current value matches #262421@70% or needs a `figmaOverlayScrim` token added to `theme.ts`. **Will trigger `figma-theme-sync`.**
- **Q-DRIFT-2 (inactive dot token)**: `icon/primary/subtle_300` = **#c6bcb1** has no theme token. Propose adding `figmaDotInactive: '#c6bcb1'` (and reuse `figmaChipBg` #5b5550 for active). Confirm before introducing. **Will trigger `figma-theme-sync`.**
- **Q-ICON (vertical swipe icon)**: does the existing `icon_swipe.svg` match the Figma swipe-UP vector (node `3140:9902`), or is it a generic/horizontal swipe? If not a match, need to export `icon_swipe_up.svg`. **May trigger `figma-icons-sync`.**
- **Q1 (grid shell) — RESOLVED**: the home-active 2×2 grid is the **same** existing `optionSheet` shell already in `HomeScreen.tsx` (no separate `OptionSheet` component exists in repo; `grep` confirms grid lives in HomeScreen). Not a different layout. AU-303 adds the vertical-axis gesture + overlays on top of it.
- **Q2 (vertical overlay trigger) — UNRESOLVED**: Figma frame is named "after see 1 set (3 options)", implying the vertical overlay fires **after the user has browsed all 3 outfits horizontally** (seen one full set). The brief's alternative ("after first vertical swipe attempt") is NOT supported by the frame name. **PO to confirm**: trigger = after viewing all 3 horizontal options, OR on first vertical-swipe attempt?
- **Q3 (dismiss behavior) — UNRESOLVED**: ticket says "Touch every[where] to close". Figma only shows a "Got it" button; the backdrop has no documented tap-to-dismiss interaction. Existing `SwipeCoachMark.tsx` dismisses via "Got it" + persists a flag. **PO to confirm**: tap-anywhere-on-backdrop closes (in addition to "Got it"), or "Got it" only?
- **Q-BRIEF (button state location)**: the brief attributes an inactive vs active "See another" button to the two **overlays**. In Figma the overlays have only "Got it"; the "Show another" enable/disable lives on the **home pagination row** behind the scrim. Confirm the intended spec — is there meant to be a "See another" button INSIDE the overlay that's missing from this Figma frame, or is the brief conflating the home chrome with the overlay? (Implementation assumes Figma is authoritative: overlays = "Got it" only.)

---

## 9. New backend fields (vs current API client)

**None** — guidance overlays are pure client-side (AsyncStorage one-time flags, per existing `SwipeCoachMark.tsx` pattern). The two-axis interaction browses outfit SETS that the recommendation client already returns; whether a "next set" exists (to enable "Show another") may need a count/cursor — but that is a `recommendation.ts` consumption question, not a new field. Flag to tech-lead: **confirm the recommendation response exposes enough to know if another SET exists** (to drive the "Show another" enabled/disabled state). If not, that's a backend/contract follow-up — escalate to tech-lead, do not invent.

---

## Status block

**Status:** DONE_WITH_CONCERNS
**Summary:** Extracted both AU-303 guidance overlays (horizontal `3140:9520`, vertical `3140:9797`) and the home-active two-axis chrome to token level; artifact saved. Overlays are structurally identical (white card 366w, radius 16, #262421@70% scrim, Poppins 16/24, "Got it" pill) differing only by icon + copy. Two token drifts (overlay scrim opacity, inactive dot #c6bcb1) and one icon-match question identified.
**Concerns/Blockers:** The task brief's frame mapping and button-state attribution conflict with Figma (overlays contain only "Got it", not an active/inactive "See another" — that state lives on the home pagination row). Flagged as Q-BRIEF. Two unresolved PO questions (Q2 trigger, Q3 dismiss) must be answered before `figma-to-rn-workflow` Phase 1.

**Unresolved PO questions:** Q-BRIEF (overlay button-state vs home-chrome conflation), Q2 (vertical overlay trigger: after 3 horizontal vs first vertical swipe), Q3 (dismiss: tap-anywhere vs "Got it" only). Plus Q-DRIFT-1/Q-DRIFT-2 (new theme tokens) and Q-ICON (vertical swipe-up asset) for tech-lead.
