# QA-Mobile Live Verify — AU-361 / AU-354 / AU-358

**Date:** 2026-06-17 23:44 local
**Build:** auxi @ home-grid layout (PR #74 lineage) · backend `au-346` feature-complete on :5001
**Device:** iOS Simulator iPhone 16 Pro (iOS 18.1) · UDID `9DCBFE8A-EE9E-4AD6-8F45-91B3F7AC5916`
**Session:** logged in as `qa-test@auxi.app` (user_id `b32cb743-2264-411c-abf1-ee14f6733368`) — **confirmed** (see Login note)
**App crashes:** none (`com.auxi2026.app` absent from crash list before and after)

---

## Pre-flight (all green)
- `mcp-doctor.sh` → exit 0: sim booted, WDA up on :8100, mobile-mcp 0.0.56 (pinned).
- `psql` present at `/opt/homebrew/bin/psql`; `DATABASE_URL` resolved from `.env`.
- App relaunched (terminate → launch) to drop stale cache, then re-fetched from the new backend.

## Login note (resolved — no re-login needed)
The relaunched app retained a valid session and landed on Home already authenticated. I could not reach Settings/Account to read the email (same menu blocker below), so I confirmed identity **behaviorally + via DB**: favouriting an outfit on Home created `favorites.id=01a6908a-…` under `user_id=b32cb743…` at the exact tap time (16:40 UTC). That user_id == `qa-test@auxi.app` and == the owner of the AU-361 seed item. **Session is the correct seeded user.**

---

## BLOCKER (root cause for both fixes): Home hamburger menu is not actionable via mobile-mcp

All app navigation (Wardrobe, Favourites, Settings, Body) funnels through a single sidebar drawer (`RootDrawer` + `SidebarMenu`) opened ONLY by the Home header hamburger (`home-menu-button`, `TopIconButton` at `auxi/src/screens/HomeScreen.tsx:1722`, `onPress → openSidebar()`). There is **no edge-swipe gesture** and **no deep-link route** to Wardrobe/Favourites (`auxi://` Linking only registers verify-email / reset-password).

The hamburger could not be actuated:
- `home-menu-button` **never appears in the mobile-mcp / WDA accessibility element list** (10+ snapshots), while sibling header button `home-heart-toggle` does.
- 10+ coordinate taps across the full 44×44 hit area (x∈{18,20,22,24,28,30}, y∈{44,46,47,48,52}), plus high/low left-edge swipes and an 8px micro-swipe, never opened the drawer. Other Home controls (heart, pins, remix, footer tabs, "Wear this", swipe-to-page) all respond — so taps reach the screen; only this button is dead to automation.
- Not a crash (app stable throughout).

**Suspected area:** `auxi/src/screens/HomeScreen.tsx:1722` + `auxi/src/components/primitives/FigmaPrimitives.tsx:57` (`TopIconButton`). The menu button renders only an SVG child (`IconHomeMenu`) and, unlike the heart at `HomeScreen.tsx:1737`, does **not** set `accessibilityRole="button"`. Result: it's invisible to the a11y tree and WDA's synthetic tap doesn't drive its `onPress` (likely the vertical `home-set-pager` FlatList responder also overlays the left header zone — see the dev note at `HomeScreen.tsx:2570` about "stray long swipes mis-arbitrate to the hamburger").
**Routing:** `mobile-dev` (add `accessibilityRole="button"` + a stable testID surfaced to a11y on the menu `TopIconButton`; verify hit-test isn't shadowed by the set-pager). Secondary: `qa-ui` to add a Maestro selector once the testID is exposed.

---

## 1) AU-361 — item-ready snackbar → **BLOCKED (could not reach Wardrobe)**
- Seed item `e2879f93-…` ("Leather Trousers · Black", owner = qa-test) re-armed to `is_preparing=true` (verified via DB).
- Wardrobe tab is reachable only via the sidebar → blocked by the hamburger issue above. Could not open Wardrobe, so could not observe the preparing state, the true→false poll transition, or the `wardrobe-item-ready-snackbar`.
- The DB-flip half of the test was therefore not exercised. Seed left **armed (`is_preparing=true`)** so a follow-up run (once the menu is fixed) can verify without re-seeding.
- **Verdict: BLOCKED** — not a fail of the fix; navigation prerequisite unmet. Backend side is ready (`is_preparing` present on `/api/wardrobe/items`).

## 2) AU-354 — reuse body-photo confirm screen → **BLOCKED (could not enter See-on-me)**
- Backend prerequisite confirmed by dispatch (`GET /api/body/active` → 200, body_shape hourglass, full_body_url set).
- Only code path into the flow is `navigation.navigate('SeeThisOnMe', …)` from **FavouriteScreen** (`auxi/src/screens/FavouriteScreen.tsx:117`) — and Favourites is behind the same sidebar. Home's "Wear this" button is the **mood-feedback** sheet ("How did this outfit feel?"), not try-on; there is no direct Home → See-on-me entry.
- Could not reach the reuse-confirm screen → "Use this photo" / "Retake photos" not observed.
- **Verdict: BLOCKED** — navigation prerequisite unmet (sidebar → Favourites → "See on me").

## 3) AU-358 — quit affordance on generating screen → **NOT REACHED**
- Depends on entering the try-on generating screen (AU-354 path). Blocked upstream. `stom-quit-generating` not observed.
- **Verdict: NOT REACHED.**

---

## Evidence (screenshots)
- `/Users/nguyenminhduc/dev/wardrobe_project/plans/reports/screenshots-260617-2009/qa-mobile-home-menu-blocked.png` — Home screen; hamburger (top-left) that would not open the sidebar despite repeated taps. This is the gate for all three fixes.
- In-session captures also recorded: Home outfit carousel, the "How did this outfit feel?" mood sheet (what "Wear this" actually opens), and the "Saved to favourites" toast (which proved the qa-test session).

## DB state left for next run
- AU-361 seed `e2879f93-…`: `is_preparing = true` (armed).
- A favourite (`favorites.id=01a6908a-…`) was created under qa-test during identity verification — harmless; remove if it pollutes favourites tests.

## Unresolved questions / asks
1. **mobile-dev:** the Home hamburger needs `accessibilityRole="button"` + an a11y-exposed testID so QA/VoiceOver can actuate it; confirm the `home-set-pager` FlatList isn't shadowing the left header hit-zone. This blocks ALL mobile-mcp + Maestro navigation past Home.
2. Is there an intended non-sidebar entry to See-on-me (e.g., a Home try-on CTA)? If so it wasn't present on this build; if not, AU-354 QA always depends on Favourites reachability.
3. Re-dispatch AU-361/AU-354/AU-358 verification once the menu fix lands; seed is already armed.
