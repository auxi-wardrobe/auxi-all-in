# Phase 01 — Figma extraction + qa-ui review

**Priority:** P0 (gate) · **Status:** ☐ not started
**Agent:** mobile-dev (extract) → qa-ui (review-extraction mode)

## Why first

Umbrella CLAUDE.md canonical Figma→RN workflow: extraction artifact + qa-ui PASS BEFORE any code.
The guidance overlays are net-new UI with exact copy/icon/layout — must be pinned to Figma, not guessed.

## Source

Figma `0nXXMAR4Arf1ZfjtQvtBh0`, node `3140-8191`. Three frames observed in screenshot:
1. **Guidance overlay (horizontal)** — centered white card, hand-swipe-horizontal icon, copy
   "Swipe left or right to explore different outfit options.", "Got it" CTA, dimmed backdrop. "See another"
   button shown **inactive**.
2. **Home active** — outfit = 2×2 item grid (4 tiles, "common" tag each); `• • •` pagination between
   "Remix ✂" and "Show another" = 3 outfits/set; "Wear this ♡" CTA; bottom view toggle.
3. **Guidance overlay (vertical)** — hand-swipe-up icon, copy "Swipe up to explore another outfit set. /
   Swipe down to go back.", "Got it" CTA. "See another" button shown **active**.

## Steps

1. mobile-dev runs `figma-design-extraction` skill on node `3140-8191` → save
   `figma-extraction-au303-guidance.md` in this plan dir. Capture: overlay card dims, corner radius,
   bg/backdrop opacity, icon node ids, exact copy strings, CTA style, pagination-dot spec, button
   active vs inactive states.
2. mobile-dev auto-dispatches qa-ui (review-extraction, Pass 1 only, NO code) → audit note vs Figma.
3. Record verdict: PASS / FAIL / ESCALATE.

## Open questions to resolve in extraction

- Is the home-active grid 2×2 the SAME `OptionSheet` already shipped, or a different layout? (current code
  already renders 4-item 2×2 grid — likely same shell, confirm.)
- Exact trigger for guidance overlay 2: "after finishing 3 outfits" — is it after 3 horizontal swipes
  within set 0, or after first vertical swipe attempt? Ticket says "After finishing 3 outfit another
  guidance screen appears." Pin this.
- Backdrop dismiss: ticket says "Touch every to close" (touch anywhere closes). Confirm tap-anywhere.

## Success criteria

- Extraction artifact saved with token-level detail for both overlays.
- qa-ui review-extraction = PASS (or escalation resolved with CEO).

## Next

Phase 02 (data model) can start in parallel with this — it's pure logic, no Figma dependency.
