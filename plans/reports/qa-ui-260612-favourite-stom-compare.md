# QA-UI Compare Audit — Favourite (Love Collection) + See This On Me (STOM)

- Date: 2026-06-12
- Mode: Compare (design-vs-actual), 3-pass
- Figma file: `0nXXMAR4Arf1ZfjtQvtBh0`
- Figma sections audited: `2852:21222` Favorite, `2852:23091` collage layouts, `2852:22266` See this on me
- Actual: captured sim screenshots in `plans/reports/qa-screens/`
- Figma refs downloaded to `plans/reports/figma-ref/`
- Implementation (read-only): `/Users/nguyenminhduc/dev/auxi-favourite-wt/src/screens/favourite/*`, `src/screens/see-this-on-me/*`

> Node-id note: the task pointed Favourite at `2849-8205`, but that board is the
> onboarding "choose wardrobe" board. The real Favourite frames live under
> section `2852:21222` (`Favourite collection` `2852:22063`, empty-state
> `2852:22228`, collage `3230:35028`) and the Remove dialog at `3539:23335`.
> Audited against those.

---

## Per-screen verdict table

| # | Screen | Figma node | Actual capture | Verdict |
|---|--------|-----------|----------------|---------|
| F1 | Favourite — empty state | 2852:22228 | (fav empty — Figma only; sim empty not captured post-remove sequence) | MINOR |
| F2 | Favourite — grid/list cards | 2852:22063 | 02-favourite-grid-layout | **MAJOR** |
| F3 | Favourite — collage cards | 3230:35028 | 03-favourite-collage-layout | MINOR |
| F4 | Favourite — remove dialog | 3539:23335 | 06-favourite-remove-dialog | **MAJOR** |
| F5 | Favourite — view toggle pill | 2852:22228 footer | 03 / 08 | PASS |
| S1 | STOM step 1 — selfie | 3395:8480 | 02-step1-selfie | MINOR |
| S2 | STOM step 2 — full body | 3395:9006 | 03-step2-fullbody | MINOR |
| S3 | STOM step 3 — body shape (transcript) | 3395:9248 | 04-step3-bodyshape | **MAJOR** |
| S4 | STOM — body-shape silhouettes | 3395:9248 / 3398:17745 | 04 / 05 | **MAJOR** |
| S5 | STOM — expanded shape carousel | 3398:17745 | 05-shape-carousel | MINOR |
| S6 | STOM — outfit preview ("success AI") | 3398:17581 | (UNVERIFIED — try-on errored) | BLOCKED |
| S7 | STOM — photo source sheet | (native action sheet) | photo-source-gallery | PASS |

---

## Adjudication 1 — STOM step-subtitle stacking (intended transcript vs bug)

**Verdict: REAL BUG. The actual retains the WRONG prior step.**

This is an intentional accumulating chat-transcript pattern — Figma confirms it.
But the implementation accumulates the *wrong* bubble on step 3.

What Figma's step-3 frame (`3395:9248` "choose a body fit") actually shows, top→bottom:
1. user selfie photo thumbnail (1/3 result, scrolled near top)
2. **"2/3 - Add a full-body photo. Optional, but it helps Macgie understand proportions and styling better."** bubble + body-outline icon
3. user full-body photo thumbnail (2/3 result)
4. **"3/3 - Choose the shape that feels most like you. Tap to expand"** bubble
5. three photographic body silhouettes

So the prior bubble retained alongside 3/3 in Figma is the **2/3 bubble** (the
immediately-preceding step), with its captured full-body photo. (The 1/3 bubble
has scrolled off the top of the frame — the transcript still contains it, it's
just above the fold.)

What the actual step-3 (`04-step3-bodyshape`) shows:
1. **"1/3 - Start with a selfie photo. No need to be perfect, you can change it later."** bubble
2. one photo thumbnail
3. **"3/3 - Choose the shape that feels most like you. Tap to expand"** bubble
4. text labels Pear / Hourglass / Rectangle

The actual keeps the **1/3** bubble and **drops the 2/3** bubble entirely. The
2/3 prompt ("Add a full-body photo…") and its captured thumbnail never appear on
step 3. So qa-mobile's flag is correct in substance but the framing is inverted:
it's not "an earlier subtitle persisting that shouldn't" — it's that the **wrong
earlier subtitle persists and the correct (immediately-prior) one is missing.**

Root cause (confirmed in code): `SeeThisOnMeScreen.tsx` lines 225-243. On the
`bodyShape` step the code renders only `PromptBubble step1.prompt` (line 229) above
`<StepBodyShape>`. It never re-renders the step-2 prompt bubble nor the full-body
photo thumbnail. To match Figma the transcript on step 3 should render, in order:
step-1 bubble → selfie thumb → **step-2 bubble → full-body thumb** → step-3 bubble
→ shape picker. The simplest faithful fix is to render the *full* accumulated
transcript (all completed steps' bubbles + their thumbnails) rather than hand-picking
the step-1 bubble. Right now the transcript is hard-coded to one prior bubble.

(Note: the photo thumbnail in the actual captures is a screenshot of the app UI,
not a body photo — that's a test-data artifact from picking a sim-library screenshot,
not a UI bug. Ignore for fidelity.)

---

## Adjudication 2 — Body-shape silhouette asset gap

**Verdict: MAJOR fidelity gap. `figma-icons-sync` is the wrong tool — these are
photographic assets, not icons. Needs an asset/design decision, not an SVG export.**

Figma's step-3 (`3395:9248`) and the expanded detail (`3398:17745`) render the
three body shapes as **full-colour photographic instances** — real people in white
outfits, three different body poses (a 3-up `Frame 2009` of `Image 3:4` instances
in step 3, and a full-bleed swipeable image carousel in the detail frame).

The implementation (`BodyShapeCarousel.tsx`, `body-shapes.ts`) renders each
"page" as a **centred text label on a flat `primary/subtle` rectangle** —
"Pear" / "Hourglass" / "Rectangle". `body-shapes.ts:5` and `BodyShapeCarousel.tsx:6`
both carry an explicit `ASSET GAP` comment acknowledging no silhouette assets exist.

Fidelity gap, quantified:
- step-3 inline preview: Figma = 3 photographic thumbnails side-by-side;
  actual = 3 bare text labels (no image, no card frame visible at that scroll
  position in `04`). ~0% visual fidelity.
- expanded carousel: Figma = full-bleed body photo with page dots + Retake / Use
  this photo footer; actual = a flat beige card with the centred word "Hourglass"
  + page dots + same footer. Layout/chrome/footer match; the **content (the body
  image) is entirely absent**, replaced by a label. ~30% fidelity (chrome correct,
  hero content missing).
- Figma uses 3 shapes; actual carousel shows **5 page dots** (`05-shape-carousel`)
  vs Figma's 3 — extra/placeholder pages. Count mismatch.

This is NOT an `figma-icons-sync` job (that's for `currentColor` line-icon SVGs).
The shapes are photographic. Resolution options for mobile-dev + CEO/designer:
(a) export the 3 body-shape photos from Figma as raster assets and bundle them, or
(b) if the photos are placeholders, get the designer to confirm the intended
silhouette asset set. Until assets exist, the labeled fallback is a known stub —
flag it as a design-blocked item, not something mobile-dev can faithfully ship
from code alone. Also fix the 5-dots → 3-dots page count regardless.

---

## Detailed findings

### F2 — Favourite grid/list cards — MAJOR
Expected (Figma `2852:22063`), per card top→bottom: date ("6 May") → **bold outfit
title** ("Bring some warmth." / "Easy lines") → **mood/vibe tag pill** ("Confident",
filled) → 2×2 item grid where **each tile has a dark "common" rarity pill** beneath
it → action row: red ⊖ remove + "Self visualization" + **purple sparkle/AI star icon**.

Actual (`02-favourite-grid-layout`):
- **No outfit title.** Cards lead with date ("31 May") then a beige
  **"Clean. Ready for today"** banner (the bulb/idea row) — the bold title line and
  the "Confident" vibe-tag pill are both absent. The bulb-row was promoted to the
  top slot where the title should be.
- **No rarity tags on grid tiles.** Figma's list variant renders a "common" pill
  under every item; the actual grid shows none. Code (`FavouriteOutfitCard.tsx:31,44`)
  gates the badge on `item.is_common_item === true` and the comment (lines 23-24)
  says this *intentionally* diverges from Figma's "hardcoded common on every tile."
  That's a deliberate product call, but it reads as a fidelity miss vs the design —
  needs CEO sign-off that data-driven rarity is the intended behaviour (likely yes,
  but document it; Figma's "common on every tile" is placeholder content).
- **Self-visualization icon is wrong.** Figma = purple sparkle (✨ AI star). Actual
  renders `IconRemix` (a scissors/remix glyph "✂…") — wrong asset. Code
  `FavouriteOutfitCard.tsx:132` imports `icon_remix.svg`. Should be the sparkle/AI
  icon. The trailing "…" suggests it may also be clipping.

### F3 — Favourite collage cards — MINOR
Figma collage (`3230:35028`) = title + bulb-row + 2×2 collage WITHOUT rarity tags +
self-viz row. Actual (`03`) matches the no-rarity-tag collage and the bulb-row, and
the toggle pill highlights the collage icon correctly. Same missing-title + wrong
self-viz-icon issues as F2 carry over, but layout/structure of the collage grid is
faithful. Note: code (`FavouriteOutfitCard.tsx:66-74`) reuses the same tiles at
3-per-row for collage with an Open-Q comment — acceptable interim per extraction note.

### F4 — Remove dialog — MAJOR (interaction/structure)
Copy matches Figma exactly ("Remove from your favourite" / "Are you sure to remove
this outfit from your favourite list"). But button layout diverges:
- Figma (`3539:23335`): **"Yes 🗑"** on the LEFT — red text, ghost/outlined, with a
  trash icon — and **"Cancel"** on the RIGHT (outlined).
- Actual (`06`): **"Cancel"** on the LEFT (ghost) and **"Yes"** on the RIGHT — a
  **solid red filled** button, **no trash icon**.

Two deltas: (1) destructive/cancel order is swapped vs design; (2) the Yes button
style (solid-red fill vs Figma's red-text ghost + trash glyph). The destructive
action's visual weight and position both differ from the spec. Token check: the
red is `icon/danger/base #c0392b` per the Figma vars — verify the fill/​text colour
matches that token, not a literal.

### F1 — Empty state — MINOR
Figma (`2852:22228`): centred solid-black heart + "Tap "Wear this" button to add an
outfit" + toggle pill at bottom. Matches the design intent. (Live empty-state sim
capture wasn't isolated in this run — the remove sequence ended with remaining
cards. Heart glyph + copy verified against Figma; recommend a dedicated empty-state
sim capture to confirm the heart is the SVG asset and not a text/emoji glyph.)

### S1 — STOM step 1 (selfie) — MINOR
Layout, copy ("1/3 - Start with a selfie photo…"), Take-photo CTA, and privacy
footer all match. **Icon mismatch:** Figma uses `hugeicons:face-id` (a face inside
camera-focus brackets). Actual renders a **generic person/avatar glyph** (head +
shoulders outline). Wrong icon — swap to the face-id bracket asset.

### S2 — STOM step 2 (full body) — MINOR
Structure matches (retains 1/3 bubble + selfie thumb, shows 2/3 bubble, Skip + Take
photo CTAs). Two deltas:
- **Copy drift:** Figma = "…it helps **Macgie** understand proportions…"; actual =
  "…it helps **us** understand proportions…". Brand name dropped.
- **Icon:** Figma `ion:body-outline` (spread-limb running figure) vs actual's
  simpler head-over-torso stick figure. Close but not the same asset.

### S5 — STOM expanded carousel — MINOR (chrome) / see S4 for content
Bottom-sheet chrome, "Choose the shape that feels most like you." headline, page
dots, and Retake / Use-this-photo footer all match Figma's detail frame
(`3398:17745`). The hero content is the silhouette gap (S4). Page-dot count is 5
vs Figma's 3.

### S6 — STOM outfit preview ("success AI") — BLOCKED
Could not verify. The try-on backend call failed in this run
(`stom-generate` / `stom-preview-image` show "We couldn't create your look. Please
try again." + a `generateTryOn error AxiosError: Request fai…` dev toast). The
success/preview frame (`3398:17581` — full-bleed result image, hamburger + download
header, "Back to home" CTA, "Use this photo for future outfit previews" checkbox)
was never reached. **The error-state handling itself looks reasonable** (clear red
message + dark "Try again" pill, `GeneratingView` errored branch). But the
"Your outfit preview" success screen is UNVERIFIED — needs a working try-on call
(real backend on :5001, valid body photo) and a re-capture to audit. This is an
environment/data block, not a confirmed defect.

---

## Prioritized fix list (routed to mobile-dev)

### MAJOR (fix before merge)
1. **STOM step-3 transcript drops the 2/3 bubble.** `SeeThisOnMeScreen.tsx:225-243`
   render the full accumulated transcript on `bodyShape` step — step-2 prompt
   bubble + full-body thumbnail must appear between the selfie thumb and the 3/3
   bubble, matching Figma `3395:9248`. Don't hand-pick the step-1 bubble.
2. **Favourite Self-visualization icon is wrong** (scissors/remix instead of purple
   sparkle). `FavouriteOutfitCard.tsx:132` — replace `icon_remix.svg` with the
   sparkle/AI-star SVG. If the asset doesn't exist, run `figma-icons-sync` to export
   it (`currentColor` convention), then import. Also check the trailing-"…" clip.
3. **Favourite card missing outfit title + "Confident" vibe-tag pill.** Figma cards
   lead with a bold title then a filled mood tag above the bulb-row; actual drops
   both. Restore title + vibe-tag, demote the bulb-row to its Figma position.
4. **Remove dialog button order + style.** Swap to Figma layout: "Yes 🗑" left
   (red-text ghost + trash icon), "Cancel" right (outlined). Verify red =
   `icon/danger/base #c0392b` token, not a literal.
5. **Body-shape silhouettes absent (design-blocked).** Photographic body assets,
   NOT icons. Route to CEO/designer via pm to confirm/export the 3 body-shape
   images; bundle as raster assets. `figma-icons-sync` does not apply. Until then
   the labeled fallback is a known stub. Also fix carousel page-dot count 5 → 3.

### MINOR (fix opportunistically)
6. **STOM step-1 icon:** generic avatar → `hugeicons:face-id` bracket asset.
7. **STOM step-2 icon:** stick figure → `ion:body-outline` (spread-limb) asset.
8. **STOM step-2 copy drift:** "…helps **us** understand…" → "…helps **Macgie**
   understand…" (i18n string `seeThisOnMe.step2.prompt`).
9. **Favourite rarity tag (product decision):** Figma shows "common" on every grid
   tile; code gates on `is_common_item`. Confirm with CEO that data-driven rarity is
   intended (likely yes — Figma content is placeholder), then document so it's not
   re-flagged. No code change if confirmed.
10. **Empty-state heart:** capture an isolated empty-state sim screenshot to confirm
    the heart is the SVG asset (not an emoji/text glyph) and copy matches.

### Token routing note
If the remove-dialog red or the self-viz icon colour turn out to be literals rather
than `theme.ts` tokens, route mobile-dev to run `figma-theme-sync` first to confirm
drift class before patching per-screen.

---

## Unresolved questions
- S6 preview: needs a successful try-on (working backend + valid body photo) to
  verify the "success AI" frame. Re-dispatch a Compare pass once the AxiosError
  is resolved.
- Rarity-tag behaviour (F2 #9): product call — data-driven vs Figma's
  "common-on-every-tile" placeholder. Needs CEO confirmation via pm.
- Body-shape assets (#5): blocked on designer providing/confirming the 3
  photographic silhouettes.

---

**Status: DONE_WITH_CONCERNS**

**Summary:** 3-pass Compare audit of Favourite + STOM complete against Figma file
`0nXXMAR4Arf1ZfjtQvtBh0`. 5 MAJOR, 5 MINOR fidelity findings; 1 surface (STOM
success/preview) BLOCKED by a try-on AxiosError in the capture run. The
step-subtitle flag is adjudicated a **real bug** (transcript retains the wrong
prior step — keeps 1/3, drops the immediately-preceding 2/3 bubble + its thumbnail).
Body-shape silhouettes are a genuine **photographic asset gap** (not an icon-sync
job — escalate to designer). Concerns: 2 findings (#5 silhouettes, #9 rarity) need
CEO/designer decisions before mobile-dev can close them; preview frame unverified.

**Overall per-screen fidelity verdict:**
- Favourite empty state — PASS (pending isolated capture)
- Favourite grid/list — **FAIL** (missing title/vibe-tag, no rarity tags, wrong self-viz icon)
- Favourite collage — PASS-with-minors (layout faithful; inherits self-viz-icon miss)
- Favourite remove dialog — **FAIL** (button order + destructive style differ from Figma)
- Favourite view toggle — PASS
- STOM step 1 (selfie) — PASS-with-minors (icon mismatch)
- STOM step 2 (full body) — PASS-with-minors (icon + "us"/"Macgie" copy drift)
- STOM step 3 (body shape) — **FAIL** (transcript drops 2/3 bubble; silhouettes missing)
- STOM expanded carousel — **FAIL** (silhouette content absent; 5 dots vs 3)
- STOM outfit preview — BLOCKED (unverified — try-on errored)
- STOM photo source sheet — PASS
