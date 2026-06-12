# qa-ui Review-Extraction Audit — AU-303 Two-Axis Swipe + Guidance Overlays

**Mode:** Review-extraction (Pass 1 ONLY — no code, no sim)
**Artifact:** `plans/260531-1326-au-303-two-axis-swipe/figma-extraction-au303-guidance.md`
**Figma:** file `0nXXMAR4Arf1ZfjtQvtBh0`, section `3140:8191` (overlays `3140:9520` H / `3140:9797` V, home-active `3140:8227`)
**Date:** 2026-05-31 · **Auditor:** qa-ui

---

## VERDICT: PASS

The extraction artifact faithfully matches Figma at the structural and token level. Every claim I could verify against `get_metadata` + `get_variable_defs` + `get_design_context` checks out. The artifact correctly **refutes the task brief's button-state attribution** (Q-BRIEF) — this is the right call and is well-evidenced. Open PO questions are genuinely scoped to intent/timing that Figma cannot answer; they do not block extraction PASS.

---

## Pass-1 checklist

| Check | Result |
|---|---|
| Frame tree matches Figma `get_metadata` | PASS — all 3 frames + child node IDs match |
| Token list complete (every fill/font/radius/pad → variable, captured) | PASS |
| Icon enumeration complete (size + currentColor flag) | PASS — H 54×54, V 54×54 (2 vectors), pagination 16×16 |
| Variant/state coverage (every variant used → listed) | PASS — Got it Enable; Show another Enable+Disable; dots active/inactive |
| Open questions non-empty where ambiguous | PASS — Q2, Q3, Q-BRIEF, Q-DRIFT-1/2, Q-ICON |
| New backend fields accurate vs services | PASS — none net-new; flags "next-set exists" as contract follow-up, correctly defers to tech-lead |

---

## Confirmed against Figma (verbatim evidence)

### Q-BRIEF — CONFIRMED: overlays contain "Got it" ONLY
`get_design_context` for both overlay nodes returns exactly one button each:
- Horizontal `3140:9520` → single Headline + single `Button` "Got it". **No "See another" node present.**
- Vertical `3140:9797` → two Headlines + single `Button` "Got it". **No "See another" node present.**

The brief's "inactive vs active See another inside the overlay" is **not in Figma**. The enable/disable state lives on the home pagination row's **"Show another"** button (`3140:8255`, `opacity-50`, component `State=Disable` `2403:13611`). The artifact's reading is correct: **Figma is authoritative — overlays = "Got it" only; the brief conflated home chrome with the overlay card.**

### Overlay dims / scrim / typography — CONFIRMED
- Card width **366**, `left:24`, vertically centered, `rounded-[16px]` (`border-radius/2xl`=16) ✓
- Scrim `background/primary/bold_600` **#262421** `opacity-70` (`418×897` at `x:-2 y:-1`, full-bleed) ✓
- Card bg `background/neutral/subtlest` = **#ffffff** ✓ (artifact correctly routes to `theme.colors.white`, NOT the #fcfcfd subtlest token)
- Headline `Text-md (l-24)/Regular` = **Poppins 400 16/24**, color `text/neutral/base` **#1d1f23**, center ✓
- "Got it" `Text-md (l-24)/Medium` = **Poppins 500 16/24**, #1d1f23; content `h-[56px] rounded-[100px] px-[20px]`, `max-w-[327px]`, text button (component `470:2533`, container invisible until press) ✓

### Copy strings — CONFIRMED VERBATIM
- H: `"Swipe left or right to explore different outfit options."` ✓
- V line 1: `"Swipe up to explore another outfit set."` ✓
- V line 2: `"Swipe down to go back"` ✓ (**no trailing period** — artifact flagged this correctly; it is two distinct text nodes `3140:9803` + `3140:9906`, gap 16)
- Button: `"Got it"` (both) ✓

### Two overlays differ ONLY by icon + copy — CONFIRMED
Backdrop, card, radius, fonts, "Got it" CTA identical across both nodes. Only deltas: icon (H = material-symbols:swipe-outline 1 img; V = icons swipe-up 2 vectors) and copy (1 line vs 2). ✓

### Pagination dots — CONFIRMED
- 3 ellipses 4×4 (`3140:8252/8253/8254`), gap 8, in 52-wide inner frame within 94-wide `3140:8250` ✓
- Active `icon/primary/bold_500` = **#5b5550** ✓; Inactive `icon/primary/subtle_300` = **#c6bcb1** ✓ (both confirmed via `get_variable_defs` on `3140:8248`)
- Position: between "Remix" (left, `3140:8249` enabled) and "Show another" (right, `3140:8255` `opacity-50`) ✓
- NOTE: in `get_design_context` the dots render as a flattened image (`imgFrame2036`); per-dot fill is not in the emitted CSS but IS exposed via the variable defs above. Color claims hold.

### Token mappings + 2 flagged drifts — SANE
- `figmaChipBg` #5b5550 reuse for active dot — correct (same hex). ✓
- Drift 1: scrim #262421 @70% has no token → `figmaOverlayScrim` proposal sound. ✓
- Drift 2: inactive dot #c6bcb1 has no token → `figmaDotInactive` proposal sound. ✓
- Routing note: both drifts correctly flagged to run `figma-theme-sync` before per-screen literals. Endorsed.

### Icon node `3140:9902` (swipe-up) — PRESENT + EXPORTABLE
Confirmed: 54×54, composed of 2 vectors (`I3140:9902;2403:13629` + `;2403:13630`), asset URLs returned by `get_design_context`. Q-ICON (does repo `icon_swipe.svg` match this swipe-UP vector vs the horizontal `icon_swipe_hand.svg`) is a legitimate open verification, not a blocker.

---

## Minor notes (non-blocking — do NOT route back to re-extract)

1. **Frame-name node IDs vs brief.** The dispatch brief listed horizontal overlay as `3140:9520` and home-active as `3140:8227`; the artifact's frame table also references parent frames `3140:9395` ("first time") / `3140:9763` ("after see 1 set"). Both are correct — `9520`/`9797` are the `noti` overlay children of `9395`/`9763`. No conflict.
2. **Headline node height.** Artifact §1 says H headline node measures `318×48` (2 visual lines wrapped). Figma metadata confirms `3140:9524` height 48 — consistent (single string that wraps to 2 lines). Fine.
3. **Dots as flattened image** (above) — implementer should render 3 real dots from tokens, not the exported PNG. Artifact already specs 3 ellipses + colors, so this is covered.

---

## Open questions: which need a HUMAN/PO decision vs answerable from Figma

| Q | Answerable from Figma? | Disposition |
|---|---|---|
| **Q-BRIEF** (overlay = "Got it" only vs "See another" inside) | **YES — RESOLVED by Figma.** | Figma is authoritative. Overlays have ONLY "Got it". Brief was wrong. **No PO decision needed**, but PM should note the brief↔Figma divergence so the ticket text is corrected. |
| **Q2** (vertical overlay trigger timing: after viewing all 3 horizontal options vs on first vertical-swipe attempt) | **NO.** Frame name "after see 1 set (3 options)" *implies* the former but trigger logic is not encoded in static frames. | **PO/CEO decision required.** |
| **Q3** (dismiss: tap-anywhere-on-backdrop vs "Got it" only) | **NO.** Figma shows no backdrop interaction; only the "Got it" button exists. Ticket says "touch everywhere to close" — conflicts. | **PO/CEO decision required.** |
| Q-DRIFT-1 / Q-DRIFT-2 (new tokens) | Partially — values are from Figma; *whether to add a token* is a theme-governance call. | tech-lead sign-off (run `figma-theme-sync`). Not PO. |
| Q-ICON (swipe-up asset match) | Verifiable in repo, not Figma intent. | mobile-dev verifies; export via `figma-icons-sync` if mismatch. Not PO. |

**Genuinely require human/PO:** Q2 (trigger timing) and Q3 (dismiss behavior). These are interaction-intent questions a static Figma frame cannot resolve, and the ticket text actively conflicts with Figma on Q3.

**Answerable now / not PO:** Q-BRIEF (Figma-authoritative), Q-DRIFT-1/2 (tech-lead), Q-ICON (mobile-dev).

---

## Routing

- mobile-dev: **PROCEED to `figma-to-rn-workflow` Phase 1** for the overlay card + pagination chrome (everything except trigger/dismiss logic). Run `figma-theme-sync` for the 2 drifts before adding literals; verify `icon_swipe.svg` for Q-ICON.
- pm: surface **Q2 + Q3** to CEO/PO before the gesture/trigger wiring is built; also correct the ticket brief's "See another inside overlay" wording (Q-BRIEF is settled — Figma wins).

---

**Status:** DONE
**Summary:** PASS — AU-303 extraction artifact matches Figma exactly (overlay dims, #262421@70% scrim, Poppins 16/24, verbatim copy incl. "Swipe down to go back" no-period, 3 dots #5b5550/#c6bcb1, "Got it"-only overlays). Q-BRIEF confirmed: overlays contain ONLY "Got it"; the active/inactive button is the home-row "Show another" — brief conflated chrome with overlay. Only Q2 (trigger timing) + Q3 (dismiss) genuinely need a PO decision.
