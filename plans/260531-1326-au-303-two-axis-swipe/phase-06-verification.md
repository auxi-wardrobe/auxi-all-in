# Phase 06 — Verification

**Priority:** P0 (gate) · **Status:** ☐ · **Agents:** mobile-dev → qa-ui → qa-mobile

## Static gates

- [ ] `cd auxi && npx tsc --noEmit` — clean (legacy `_HomeScreen.tsx` errors allowed, no regression)
- [ ] `cd auxi && yarn lint` — no new errors over baseline (4 err + 3 warn, all in `_HomeScreen.tsx`)
- [ ] `./scripts/auxi-lint-tokens.sh` — no hex/font drift (guidance overlay uses theme tokens only)

## qa-ui (Compare mode, Pass 2+3)

- [ ] Guidance overlay 1 (horizontal) code-vs-Figma + sim screenshot
- [ ] Guidance overlay 2 (vertical) code-vs-Figma + sim screenshot
- [ ] Home active: `• • •` pagination dots placement vs Figma frame 2
- [ ] No token drift, icon fidelity (hand-swipe icons)

## qa-mobile (Maestro + exploratory, on sim)

- [ ] Fresh install → overlay 1 appears on first outfit view; tap-anywhere dismisses
- [ ] Swipe L/R cycles the 3 outfits in the set; dots track active outfit
- [ ] After exploring 3 outfits → overlay 2 appears once; dismiss
- [ ] Swipe up → next set (3 new outfits), starts at outfit 0
- [ ] Swipe down → previous set
- [ ] 3 unfavorited browses → `ContextChipsModal` opens (per session); heart-tap resets
- [ ] Prefetch: reaching last set loads next set silently (no flicker)
- [ ] Re-launch → neither guidance overlay re-shows
- [ ] Authored Maestro flow under `maestro/flows/home/` driven off new testIDs

## Contract / backend

- No new backend contract required for AU-303 (uses existing `/build` + `/try_another` count:3).
  If set-aware fetching needs a backend signal later, file a tech-lead follow-up — not in this PR.

## PR

- [ ] PR template all green: Figma URL + node-id, extraction artifact path, qa-ui review-extraction PASS,
      `auxi-lint-tokens.sh` clean, sim screenshot / qa-mobile verify ID
- [ ] Link AU-303; note HOME_SWIPE_PLAN.md §1 rewrite

## Done = AU-303 closeable

Two intentional axes shipped, two guidance overlays first-time-only, coachmark copy corrected, docs
no longer contradict the design.
