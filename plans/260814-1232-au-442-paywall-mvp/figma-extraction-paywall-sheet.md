# Figma extraction — AU-442 soft paywall (UsageLimitSheet + NotifyMeScreen)

Figma: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Macgie?node-id=4444-26066&m=dev
File key: `0nXXMAR4Arf1ZfjtQvtBh0`
Section node: `4444:26066` ("Pricing") — extracted via `get_metadata` + `get_design_context` + `get_variable_defs` + `get_screenshot` (both Figma MCP tools verified live/authenticated this pass).

## Section overview (5 top-level frames under 4444:26066)

The section bundles 5 full-screen (390×844) mockups. Mapped to ticket scope:

| Node | Name | What it is | In scope for AU-442? |
|---|---|---|---|
| `4444:26176` | "pricing" | Real RevenueCat paywall (Upgrade to Macgie+, Yearly/Monthly plans, Subscribe CTA) | **NO** — this is `auxi/src/screens/UpgradeScreen.tsx`, already built, deliberately dark (`SHOW_UPGRADE_PAYWALL = false`). Confirms non-goal from phase-02 spec. Visual-language reference only. |
| `5078:13760` | "pricing" (2nd variant, "…is coming soon.") | Full-screen "Macgie+ is coming soon" feature-grid screen with a single "Notify me" CTA | **YES — this is the `NotifyMeScreen`.** |
| `5078:13668` | "noti - seeonme" | Bottom-sheet dialog: "You've reached today's See on Me limit" | **YES — `UsageLimitSheet` for `feature: 'see_on_me'`.** |
| `5078:13983` | "noti-items" | Bottom-sheet dialog: "You've reached the free limit" (wardrobe, 50 items) | **YES — `UsageLimitSheet` for `feature: 'wardrobe_items'`.** |
| `5078:14024` | "noti-enhance" | Bottom-sheet dialog: "You've reached today's limit" (10 enhancements) | **YES — `UsageLimitSheet` for `feature: 'enhance_photo'`.** |

**Resolution of the ticket's "find the sibling Notify-me frame" instruction:** FOUND, not escalating. The section contains all 4 frames needed (3 sheet variants + 1 follow-up screen), directly siblings of the real-paywall frame under the same "Pricing" section. Screenshot confirms the visual flow: tap "Upgrade to Macgie+" on a `noti-*` sheet → lands on the "…is coming soon." screen → tap "Notify me".

No explicit "confirmed / notified" state frame exists in Figma for the post-tap acknowledgement (see Open Questions).

## Frame 1 — UsageLimitSheet (3 copy variants, same structure)

Shared structure across `5078:13668` / `5078:13983` / `5078:14024`:

```
Frame (390×844, scrim) — bg rgba(25,27,34,0.3) over darkened bg/primary/bold_600 @70% opacity
└── Frame "Frame 2153" (390×446) bottom-anchored
    ├── "Basic Dialog" (390×270, auto-V, gap 16, padding 16/24, bg background/neutral/subtlest #fff,
    │      rounded top-left/top-right border-radius/2xl = 16px)
    │   └── Frame (auto-V, gap 8, items center)
    │       ├── "macgie-animate-2" illustration — 103×126 — sad/crying cat mascot with paw prints
    │       │      (composed of several Subtract/Vector SVG layers) — NOT the existing MacgieFace
    │       ├── Headline — Text-sm(l-20)/Semibold, 14px, text/neutral/base #1d1f23, center
    │       │      — copy varies per feature (see Copy table below)
    │       └── Supporting Text — 14px regular (body inline-bold span for the feature name),
    │              text/neutral/base #1d1f23, center — copy varies per feature
    └── "button group" (390×176, gap 12, pt 16 / pb 36, px 16, backdrop-blur 4px, bg white underlay)
        ├── Button "Upgrade to Macgie+" — PRIMARY — 327×56, bg background/neutral/base #1d1f23,
        │      radius 16px (border-radius/md=16 in theme.ds.radius), label
        │      text/primary/subtle_100 #eee6df, Text-md(l-24)/Medium 16px
        └── Button "Maybe later" — SECONDARY (text button) — 327×56, no fill, radius 100 (pill),
               label text/neutral/base #1d1f23, Text-md(l-24)/Medium 16px
```

### Copy per feature variant

| feature key | Node | Headline | Body |
|---|---|---|---|
| `see_on_me` | `5078:13668` | "You've reached today's See on Me limit" | "You've used all your free **See on Me** tries for today. Upgrade to Macgie+ to keep trying outfits anytime, or come back tomorrow when your free tries refresh." |
| `wardrobe_items` | `5078:13983` | "You've reached the free limit." | "Your wardrobe is full with 50 items. Upgrade to Macgie+ to add unlimited items and keep building your digital wardrobe." |
| `enhance_photo` | `5078:14024` | "You've reached today's limit." | "You've used all 10 image enhancements available today. Upgrade to Macgie+ to enhance more clothing photos every day." |

Both CTAs are identical copy/style across all 3 variants: **"Upgrade to Macgie+"** (primary) / **"Maybe later"** (secondary/dismiss). Note: ticket phrased the secondary CTA as "dismiss" generically — Figma copy is literally "Maybe later", not "Dismiss" or "Cancel".

## Frame 2 — NotifyMeScreen (`5078:13760`, "pricing" / "…is coming soon.")

```
Frame (390×844, radius 18 / theme.ds.radius.xl, bg background/neutral/subtlest #fff)
├── Header (0,0, 390×107) — matches Header.BackTitle pattern already used by UpgradeScreen:
│      left: "✕" close icon (NOT chevron-back — Icons.Close, not Icons.ChevronLeft)
│      center: "Upgrade" — Text-sm(l-20)/Medium, text/neutral/base
│      right: empty 44×44 spacer (symmetry)
│      bg: neutral/subtlest @ 90% opacity, backdrop-blur 7.5px (sticky/translucent header)
├── Content (List Item/List Item: 0 Density, 172px top offset from header, px 12, gap 16)
│   ├── Wordmark row: paw icons + gradient "Macgie" (H2/SemiBold 32px, gradient text fill orange→purple)
│   │      + "is coming soon." (Text-sm(l-20)/Semibold 14px, text/neutral/base) — DIFFERENT from
│   │      UpgradeScreen's "Get dressed with more clarity, less pressure." subtitle
│   ├── 3-photo collage hero (350×166) — same 3-photo stacked/rotated collage as UpgradeScreen hero
│   │      (rotate ±9deg side photos, radius border-radius/xl=12, shadow L-Shadow)
│   └── Feature grid — 2 columns × 4 rows (UpgradeScreen only has 2×3 = 6; this screen has 8):
│        1. Unlimited wardrobe — "Store all your clothes" — icon: mdi:forever/infinity-ish (existing Icons.Wardrobe candidate)
│        2. See on me — "80 visualization/ month" — icon: `ai` sparkle (Icons.Sparkle candidate)
│        3. Unlimited suggestions — "Outfit ideas, anytime" — icon: custom vector (SuggestionsIcon candidate, exists)
│        4. Enhance items — "100 enhancements/ month" — icon: custom vector (EnhanceIcon candidate, exists;
│             note: NotifyMe frame text differs from en-EN.json `feature_enhance_subtitle` = "50 enhancements/ month" — Figma says 100, see Open Questions)
│        5. Schedule outfits — "Plan ahead with ease" — icon: calendar (Icons.Calendar, exact match)
│        6. Creative Canvas — "Save and create freely" — icon: canvas (Icons.OutfitCanvas, exact match)
│        7. **Unlimited Capsule** — "Plan ahead with ease" [duplicate subtitle in Figma, likely WIP/placeholder] —
│             icon: canvas icon reused (same icon as Creative Canvas in the raw node) — **NEW, no i18n key, no icon mapped**
│        8. **Wardrobe analysis** — "Save and create freely" [duplicate subtitle, same as Creative Canvas] —
│             icon: canvas icon reused — **NEW, no i18n key, no icon mapped**
│      Grid item spec: icon chip 32×32 bg color/primary/50 (#f2efec = theme.ds.color.cream), radius 8
│      (theme.ds.radius — no exact 8 token; closest existing is xs=2/sm=12, FLAG as gap), gap 8 between
│      icon+text, title Text-xxs/Semibold 10px, subtitle Text-xxs/Regular 10px, both text/neutral/base
├── Button "Notify me" — PRIMARY, 327×56 @ (31.5, 733), bg background/neutral/base #1d1f23,
│      radius 16px, label text/primary/subtle_100 #eee6df, Text-md(l-24)/Medium 16px — SAME visual
│      spec as the sheet's primary CTA. No secondary/dismiss CTA on this screen (single-CTA screen).
└── Footer "Version 1.0.3" (centered, 12px, text/neutral/base) — likely a Figma-canvas artifact, not
       app content; UpgradeScreen has no such footer. FLAG — probably omit in implementation.
```

**No "confirmed" / post-tap state is depicted in Figma for the Notify-me button.** The phase-02 spec requires "the button must visibly acknowledge; the tap is the whole deliverable" — this is an implementation-only interaction with no Figma reference (see Open Questions).

## Tokens used (via `get_variable_defs` on `4444:26066`)

| Figma variable | Value | `auxi/src/theme/theme.ts` equivalent |
|---|---|---|
| `background/neutral/base` | `#1d1f23` | `theme.ds.color.ink` — exact match |
| `text/neutral/base` | `#1d1f23` | `theme.ds.color.ink` — exact match |
| `background/neutral/subtlest` | `#ffffff` | `theme.ds.color.white` — exact match |
| `color/primary/50` | `#f2efec` | `theme.ds.color.cream` — exact match |
| `text/primary/subtle_100` | `#eee6df` | `theme.ds.color.warm100` — exact match |
| `border-radius/2xl` | `16` | `theme.ds.radius.md` (named "md" in theme, value 16) — exact match, naming differs |
| `border-radius/xl` | `12` | `theme.ds.radius.sm` (named "sm" in theme, value 12) — exact match, naming differs |
| pill button radius (`100px`, unlabelled var) | `100` | `theme.ds.radius.full` — exact match |
| `dimension/8`, `dimension/12`, `dimension/16` | `8,12,16` | `space.s2` / `space.s3` / `space.s4` in `m-tokens.ts` — exact match |
| `body/sm` (14/20), `body/md` (16/24), `body/xxs` (10/12), `body/xs` (12/16) | — | need mapping to `theme.typography.aliases.*` — existing `interBodySm`/`interBody` etc. cover most; sheet body text (14px regular, one bold inline span) has no direct alias found yet, verify at build time |
| `heading/H2` (32/40, letterSpacing -0.64) | — | matches `MacgiePlusWordmark`/gradient wordmark treatment already used on UpgradeScreen hero — reuse that component, don't rebuild |
| gradient (orange→purple wordmark) | — | `BrandGradientFill` / `MacgiePlusWordmark` already implement this — reuse |
| `L-Shadow` (drop shadow 8,3,8.5,#00000026) | — | matches `theme.shadow.card`/`floatingButton` family — check exact offset at build time, may need a new named shadow alias if neither matches (8,3 offset is non-standard vs existing 0,8 / 0,4) |
| icon chip radius `8` (`bg-...rounded-[8px]`) | `8` | No exact `theme.ds.radius` token is 8 (scale jumps xs=2 → sm=12). **FLAG for build phase**: either reuse existing `UpgradeScreen` featureIcon style verbatim (it already renders this exact chip at `theme.ds.radius.sm` = 12, i.e., UpgradeScreen already approximates 8→12) or ask before introducing a new radius token. |

One-off literals spotted (not variables): scrim `rgba(25,27,34,0.3)` and dialog underlay `bg-primary/bold_600 @70%` on the sheet frames — these render the app screen behind the sheet for mockup purposes only, NOT part of the sheet's own visual spec (this is exactly what `MBottomSheet`'s built-in scrim already provides on-system — do not hand-roll).

## Icons / assets audit

| Figma element | Existing in `auxi/src/assets/icons` or `assets/images`? | Action |
|---|---|---|
| "macgie-animate-2" sad/crying cat mascot (sheet header illustration, 103×126) | **NO** — `src/components/macgie/` only has `MacgieFace`, `MacgieLoader`, `MacgieLogo`, `MacgieNod` (none crying/sad) | **NEW asset** — needs Figma export + `figma-icons-sync` in a later pass, or a bespoke RN illustration. Flag as open question (see below) — do not invent in this pass. |
| Wordmark "Macgie" gradient + paw icons | Reused verbatim from `MacgiePlusWordmark` (`auxi/src/components/upgrade/MacgiePlusWordmark.tsx`) | Reuse, no new asset |
| 3-photo collage hero | UpgradeScreen already renders an equivalent hero (verify exact assets match; Figma uses placeholder stock photography — check at build time whether UpgradeScreen's hero images are reusable or need re-export) | Reuse UpgradeScreen's hero pattern |
| Feature icon 1 "Unlimited wardrobe" | `Icons.Wardrobe` (`icon_wardrobe.svg`) — used by `UpgradeScreen` for the same feature key | Reuse |
| Feature icon 2 "See on me" | `Icons.Sparkle` (`icon_sparkle.svg`) — used by `UpgradeScreen` | Reuse |
| Feature icon 3 "Unlimited suggestions" | `SuggestionsIcon` (`assets/images/icon_upgrade_suggestions.svg`) — used by `UpgradeScreen` | Reuse |
| Feature icon 4 "Enhance items" | `EnhanceIcon` (`assets/images/icon_upgrade_enhance.svg`) — used by `UpgradeScreen` | Reuse |
| Feature icon 5 "Schedule outfits" | `Icons.Calendar` (`icon_calendar.svg`) | Reuse |
| Feature icon 6 "Creative Canvas" | `Icons.OutfitCanvas` (`icon_outfit_canvas.svg`) | Reuse |
| Feature icon 7 "Unlimited Capsule" (NEW row, not on UpgradeScreen) | **NO** — Figma reuses the canvas icon here (looks like an unfinished/placeholder icon assignment in the source file) | **NEW** — flag as open question, do not invent a bespoke icon |
| Feature icon 8 "Wardrobe analysis" (NEW row, not on UpgradeScreen) | **NO** — Figma reuses the canvas icon here (same placeholder pattern) | **NEW** — flag as open question |
| Header close "✕" icon | `Icons.Close` (`icon_close.svg`) — exact size/shape match expected, verify at build time | Reuse |
| Sheet primary/secondary button visual spec | No existing shared `MButton` variant matches exactly (primary = solid ink bg + warm100 text; secondary = borderless pill text button) — `AiLimitSheet` only uses ONE primary `MButton`, no precedent for the two-CTA pattern here | Verify `MButton` variants cover both, or extend `MBottomSheet`'s consuming component locally — **not a token gap, a component-composition question for `figma-to-rn-workflow` phase** |

## Variants / states

- **UsageLimitSheet**: 3 copy variants keyed by `feature` (`see_on_me` / `wardrobe_items` / `enhance_photo`), same layout/tokens across all 3 — confirms "feature-parameterised copy" requirement from phase-02 spec exactly.
- **NotifyMeScreen**: single static variant (all 8 features always shown, not filtered by triggering `feature`) — confirms this is a generic "coming soon" screen, not per-feature content.
- **Notify me button confirmed/pressed state**: NOT depicted in Figma. No secondary frame, no annotation. Implementation must invent a minimal in-place acknowledgement (e.g., swap label + disable) per phase-02 spec's explicit instruction — flagged as an open question for a design opinion, but the ticket already authorizes proceeding without a Figma ref for this one interaction ("the tap is the whole deliverable").
- **Button hover/pressed states**: Figma component descriptions only document "State=Enable" for both button variants — no pressed/disabled Figma state was defined at all. `MButton`/`PressScale` press feedback (already on-system per `AiLimitSheet`/`UpgradeScreen` precedent) should be treated as sufficient without further Figma reference.

## Open questions for CEO / tech-lead

1. **"macgie-animate-2" sad/crying cat illustration has no existing app asset.** Do we (a) export it from Figma as a static SVG via `figma-icons-sync`, or (b) reuse the existing `MacgieFace` mascot as a lower-fidelity stand-in for the soft-paywall MVP? Given this is explicitly an MVP ("soft-paywall"), (b) may be acceptable, but that's a taste call, not mobile-dev's to make silently.
2. **Feature icons 7 ("Unlimited Capsule") and 8 ("Wardrobe analysis") on the NotifyMeScreen have no distinct icon in the Figma source** (both reuse the Creative Canvas canvas-icon, and both share the exact subtitle copy "Plan ahead with ease" / "Save and create freely" duplicated from rows 5/6 respectively) — this looks like unfinished Figma work, not a deliberate design. Should the NotifyMeScreen ship only the 6 features that exist on `UpgradeScreen` (dropping rows 7–8), or should rows 7–8 ship with placeholder copy/icons as-is? Recommend dropping to 6 for MVP given the copy is a literal duplicate, but flagging rather than deciding unilaterally.
3. **`Enhance items` subtitle mismatch**: Figma's NotifyMeScreen says "100 enhancements/ month" but the shipped `en-EN.json` `upgrade.feature_enhance_subtitle` key (used by `UpgradeScreen`) says "50 enhancements/ month". Which number is current/correct? Needed before writing the `usageLimit.*` i18n keys (or whether `NotifyMeScreen` should just import the existing `upgrade.feature_enhance_subtitle` key rather than duplicate it with a different number).
4. **No post-tap "confirmed" state is designed for the "Notify me" button.** Phase-02 spec says the tap must "visibly acknowledge" — proposing a minimal on-system treatment (label swap to a checkmark/confirmed copy + `MButton` disabled state) at build time; flagging so this isn't silently invented without sign-off if the CEO has a different intent (e.g., a toast, an inline banner).
5. **"Version 1.0.3" footer text on the NotifyMeScreen frame** — likely a Figma mockup artifact (device/app-version debug label), not intended app content; `UpgradeScreen` has no equivalent. Recommend omitting at build time unless told otherwise.
6. **Icon chip radius is `8`** on the NotifyMeScreen feature grid but the nearest `theme.ds.radius` tokens are `xs=2` / `sm=12` — no exact `8` token exists. `UpgradeScreen`'s existing `featureIcon` style already uses `theme.ds.radius.sm` (12) for the same visual chip, so precedent exists to just reuse that approximation rather than adding a new token. Flagging in case the CEO/designer wants pixel-exact 8 instead.
7. **Two-CTA button visual spec (solid primary + borderless pill secondary) has no existing shared primitive precedent** — `AiLimitSheet` (the closest sibling pattern) only ever renders a single primary `MButton`. Need to confirm at build time whether existing `MButton` variants (`primary`, and whatever "text"/"ghost" variant exists) cover the secondary "Maybe later" pill exactly, or whether a new variant/local composition is needed. Not blocking extraction, but material to `figma-to-rn-workflow` Phase 4.

## Locked decisions (user-confirmed 2026-08-14, answers open questions 1–4 above)

1. **Mascot**: reuse existing `MacgieFace` as the sheet's stand-in illustration for MVP — do NOT export a new "macgie-animate-2" asset this pass.
2. **NotifyMeScreen feature grid**: ship only 6 rows (drop "Unlimited Capsule" / "Wardrobe analysis" — the two duplicate-copy placeholder rows). Matches `UpgradeScreen`'s existing 6.
3. **Enhance subtitle copy**: reuse the shipped `upgrade.feature_enhance_subtitle` i18n key ("50 enhancements/ month") — do NOT introduce Figma's "100" figure. Import/reuse the existing key rather than duplicating a new one with a different number.
4. **"Notify me" confirmed state**: label swap + disable the button in place (e.g. "We'll notify you" + inert `MButton` disabled state) — no toast, no new component.

Open questions 5–7 (footer version text, icon chip radius 8→12 approximation, two-CTA button primitive) remain build-time judgment calls for `figma-to-rn-workflow` — recommendations in the Open Questions section stand (omit footer, reuse `radius.sm`=12, verify `MButton` variant coverage before inventing a new one).

## New backend fields (vs current API client)

None — this phase is UI-only (no network calls; Notify-me tap stores nothing per phase-02 spec `Security` section). The `feature: 'see_on_me' | 'wardrobe_items' | 'enhance_photo'` union is a frontend-only type shared with phase 03's usage-gate wiring; phase 01 (backend usage endpoint) is a separate, already-scoped phase and out of extraction scope here.
