# AU-442 See-on-Me Live Verify — Retry

**Result: BLOCKED before reaching the real limit-sheet trigger** (progressed further than the previous attempt, but hit a new, separate blocker)

**Build**: `2b0c000` ("fix: single-root wrap for UsageLimitSheet in SeeThisOnMeScreen (AU-442)") on branch `nguyenthaihiep94/au-442-paywall`, `auxi/`
**Device**: iOS Simulator iPhone 17 Pro, iOS 26.5, UDID `34528D25-C08D-4E54-89B8-BDA0E3226B7F`
**Stack**: backend `:5001` (200 on `/health`), Metro `:8081` (200 on `/status`). `./scripts/mcp-doctor.sh` preflight: healthy.
**Account**: `qa-test@auxi.app` / `QaTest!2026`

## 0. Backend migration check (done first, per dispatch)

```
curl -s http://localhost:5001/api/me/usage -H "Authorization: Bearer <token>"
→ 200 {"is_premium":false,"features":{"see_on_me":{"used":0,"limit":2,"limit_reached":false},"wardrobe_items":{"used":52,"limit":51,"limit_reached":true},"enhance_photo":{"used":0,"limit":31,"limit_reached":false}}}
```

**Confirmed fixed** — no more 500. `usagepwl1a2b_add_usage_tracking` migration is applied and the endpoint returns real usage data. `see_on_me.used=0` baseline before this session's attempts (still 0 at end of session — no real try-on generation was completed, see §3).

## 1. Finding a real entry point (last attempt's blocker — now resolved)

The previous attempt reported "My Favourite" empty after "Wear this" from a Home outfit and couldn't find another way in. This time:

1. Cold-launched the app (`terminate_app` + `launch_app`) to rule out stale nav/cache state — **important**: the very first launch in this session showed a `FavouriteScreen` with a card already on it (testID `favourite-card-a3e04a85-...`), which turned out to be leftover resumed nav state from a prior session, not a true cold Home. After a real terminate+relaunch, Home rendered correctly (outfit deck, "Generating" → rendered outfit).
2. Tapped `home-wear-this` on the rendered outfit ("Brighter today.", red dress) → a mood-tagging sheet appeared ("How did this outfit feel?", `mood-chip-*` chips) → picked "Confident" → tapped `mood-feedback-done`.
3. Footer flipped to `home-wear-this-saved-favourites` with toast "Outfit saved. Open Favourites to use See on Me." — tapped it.
4. Landed on `FavouriteScreen` showing the just-saved outfit card (same id `a3e04a85-a9b9-450e-a4a3-a4a61a9e7725` reappeared — likely idempotent/upserted by outfit hash rather than a new row).
5. Tapped `favourite-self-visualization-active` ("See on me") on the card → navigated to the **real** `SeeThisOnMeScreen.tsx` capture flow — "See on me / Step 1/3", "Upload a clear selfie..." with a `stom-take-photo` CTA.

**This confirms "Wear this" → Favourite → "See on me" IS a working, reachable entry point** into the real `SeeThisOnMeScreen.tsx` (the exact file touched by commit `2b0c000`). Screenshot of this step (clean, no visible ghost artifact at this stage): `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-real-stom-step1.png`.

**Secondary anomaly (not blocking, noting for awareness):** `GET /api/favorites` via a freshly-minted curl token for the same account (`sub: b32cb743-2264-411c-abf1-ee14f6733368`) returned `{"count":0,"total":0,"favorites":[]}` at every check throughout the session (before "Wear this", after, and at session end) — yet the app itself, in the same session, consistently rendered the saved favourite card correctly on `FavouriteScreen`. Did not root-cause (out of scope / time-boxed) — could be a read-path difference (different query/filter than the client uses), an eventual-consistency lag on the remote Railway Postgres, or a token/session mismatch between my curl login and the app's persisted Keychain session. Flagging as a minor discrepancy worth a quick look, not filing as a blocking bug since the client-observed behavior (which is what matters for real users) is correct.

## 2. Blocked at Step 1/3: image picker fails in-simulator

Goal was to complete Step 1/3 (selfie upload) → Step 2/3 → Step 3/3 (generate) twice, to drive `see_on_me.used` to 2 and trigger the real `UsageLimitSheet` from `SeeThisOnMeScreen.tsx`.

Tapped `stom-take-photo` → native "Add a photo" action sheet (Take photo / Choose from library / Cancel) → **"Choose from library" consistently fails**:

```
Alert: "Error" / "Failed to pick image" / OK
```

Reproduced 3x, same result each time, across two things tried in between to rule out an environment cause:
1. Seeded a photo into the simulator's library: `xcrun simctl addmedia <udid> <jpg>` (verified file landed in `.../data/Media/DCIM/100APPLE/`).
2. Granted privacy permissions explicitly: `xcrun simctl privacy <udid> grant photos com.auxi2026.app`, `photos-add`, `camera`.
3. Opened `Photos.app` once directly to force library indexing (confirmed "10 Photos" showing in Library, including the seeded one), then relaunched the target app and retried.

All three attempts after these steps still produced the same "Failed to pick image" alert — the native `PHPickerViewController` sheet never even visibly opens (screenshot taken immediately after the "Choose from library" tap shows the error alert, not a picker UI). A `log stream` capture around the failure (filtered to `process == "auxi"`) showed no explicit error line surfaced at debug level — no clear native-side root cause captured.

The "Take photo" (camera) option, tried once for comparison, dismissed the sheet silently with no error (expected — no camera hardware on simulator, treated as cancel rather than a hard error).

Screenshot: `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-picker-failed-image-error.png`

**Library involved**: `react-native-image-picker@^8.2.1`, via `auxi/src/hooks/use-image-picker.ts` (`launchImageLibrary`). The error surfaces through the generic fallback path in that hook (`result.errorCode` truthy, `result.errorMessage` falsy → shows the hardcoded fallback text), meaning the native module returned an error code without a message — consistent with a native picker-launch failure rather than a JS-level bug.

**This is a different blocker than the "My Favourite empty" one from the prior attempt** — it's a photo-picker / simulator-environment issue, not a paywall/ghost-snapshot issue, and not obviously an AU-442 regression (the picker hook is shared, generic, unrelated to the paywall change set). Per the dispatch's guidance, stopping here rather than continuing to chase an environment issue — routing as a separate finding.

**Suggested next steps for whoever picks this up**: try a full simulator "Erase All Content and Settings" (destructive — did not do this myself per the no-unilateral-destructive-ops rule) or a different simulator instance to see if it's this specific sim's Photos/PHPicker state that's wedged, vs. a genuine `react-native-image-picker` + iOS 26.5 compatibility regression.

## 3. What was NOT verified this round

- Could not reach Step 2/3 or Step 3/3 of the real See-on-Me capture flow, so could not complete even one real try-on generation, let alone two.
- Could not drive `see_on_me.used` to 2 / `limit_reached: true` via the real flow.
- Could not observe `UsageLimitSheet` firing from `SeeThisOnMeScreen.tsx`'s real production trigger path (as opposed to the `__DEV__` debug row previously verified clean in round 3).
- Could not re-check the top-left corner of `NotifyMeScreen` for the ghost artifact via this specific trigger path (the debug-row path was already re-verified clean in the round-3 report; this round only got as far as confirming the capture-flow entry screen renders cleanly).

## Summary

```
Maestro: n/a — no flow exists yet for the paywall/see-on-me surfaces
mobile-mcp exploratory: reached the real SeeThisOnMeScreen.tsx entry (Step 1/3),
  clean render, no ghost artifact observed at that step. Blocked before reaching
  generation/limit-sheet trigger by an image-picker failure in-simulator.

Findings filed: 0 formal bug-report files this round (both issues below are
  reported inline per the dispatch's "acceptable outcome" instruction, not as
  separate docs/qa-findings/*.md, since neither blocks AU-442's actual
  ghost-snapshot fix from being assessed — the fix's target file renders clean
  as far as reached).

Blockers to report:
1. react-native-image-picker "Failed to pick image" on Choose from library,
   reproducible 3x even after seeding simulator photo library + granting
   photos/photos-add/camera privacy + forcing Photos.app indexing. Route:
   mobile-dev (or devops if it's simulator/environment state, not app code) —
   this blocks not just AU-442 QA but likely also Body-photo upload QA
   (auxi/src/hooks/use-image-picker.ts is shared with BodyScreen).
2. Minor anomaly: GET /api/favorites via curl returns empty for an account
   the app itself shows favourites for, in the same session. Not blocking,
   not root-caused, noting for backend-dev awareness.

mobile_list_crashes: [] — no crashes.
```

## Screenshots

- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-real-stom-step1.png` — real SeeThisOnMeScreen.tsx, Step 1/3, clean (no ghost)
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-picker-failed-image-error.png` — "Failed to pick image" error blocking further progress

## Unresolved questions

- Is the image-picker failure specific to this one simulator instance's Photos/PHPicker state, or a genuine `react-native-image-picker`+iOS 26.5 compatibility regression? Needs a fresh simulator or device to disambiguate.
- Why does `/api/favorites` via a fresh curl-minted token return empty when the app (same account) shows favourites correctly? Possible token/session mismatch, read-path difference, or replica lag — not root-caused this round.
- The real limit-sheet-triggered ghost-artifact check for `SeeThisOnMeScreen.tsx` (the actual goal of this dispatch) remains unverified. Recommend either: (a) a backend-side way to seed `see_on_me.used=2` directly for the QA account so the real trigger fires without going through the capture flow, or (b) get the image picker unblocked first.
