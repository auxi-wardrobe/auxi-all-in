# App Store Submission Readiness — Auxi (Macgie) iOS

**Date:** 2026-06-19 · **App:** Auxi / display name "Macgie" · bundle `com.auxi2026.app` · v1.0 (build 24) · iOS target 15.1
**Method:** code audit of `auxi/` (RN 0.83) + `wardrobe-backend/`, 3 parallel agents. Evidence-backed verdicts only.
**Note on template:** original checklist was written for a Strava AI-coaching *subscription* app. Auxi is **free (no monetization)** and is **not** Strava — so the IAP/§4 and Strava-OAuth items collapse to N/A, while the **AI data-sharing** items get *more* severe because Auxi sends body/full-body photos to third-party AI.

---

## VERDICT: NOT READY — 5 blockers

Zero of the blockers are about monetization (there is none). Four are squarely the **2026 AI + privacy** tightening, one is the classic #1 rejection cause (dead/placeholder UI). All are fixable in mobile-dev scope without backend contract changes.

---

## ▶ Live remediation progress (updated 2026-06-19, goal: "làm hết")

Branch: `feat/legal-terms-privacy-screens` (auxi). 🟢 done · 🟡 in progress / code-done-pending-gate · 🔴 not started · 👤 human-only.

| Blocker | Status | Notes |
|---|---|---|
**ALL code-side work merged into PR #100** → https://github.com/auxi-wardrobe/auxi-mobile/pull/100 · designer hard gate **PASS** · 8 commits, 37 files.

| Blocker | Status | Notes |
|---|---|---|
| **B5** Legal docs reachable | 🟢 code done (`792e6b47`) | Terms+Privacy RN screens, linkified, Settings rows. Residue: host URL → ASC 👤 · CEO approve Privacy text 👤 |
| **B1** AI consent | 🟢 code done (`a0539601`) | consent gate + `gemini_opt_in` wired to real consent + revoke toggle + truthful copy (en/vi/fr) |
| **B2** AI label + Report | 🟢 code done (`48f114f4`) | "AI-generated" label + mailto Report on try-on + recommendation |
| **B3** Dead/placeholder UI | 🟢 code done (`796c5175`,`14456eb2`) | drawer Feedback wired, dead rows + "Import from web" removed, root ErrorBoundary added |
| **B4** SIWA entitlement | 🟢 code done (`35be5d10`) | `auxi.entitlements` + pbxproj (Debug+Release). Residue: enable capability on Apple Developer portal + regen provisioning 👤 |
| **Warnings** | 🟢 mostly done (`a06f86be`,`8334ee0b`,`14456eb2`) | privacy-manifest data-types, dropped always-location, ErrorBoundary. Deferred: Mixpanel prod token (needs separate token/decision 👤) |
| **Designer follow-ups** | 🟡 non-blocking | 3 MINOR (header seam · SettingsDialog scrim token · link-style) in PR body; gate already PASSED |

**Human-only residue (cannot be done from code):** CEO approval of Privacy Policy draft text + legal entity/jurisdiction/contact email; host Privacy Policy at a public URL; App Store Connect (App Privacy nutrition label matching the 5 manifest types + AI-sharing disclosure, working demo account for the hard login wall, age rating, export compliance, screenshots); Apple Developer portal "Sign in with Apple" capability + provisioning regen; build with Xcode 26 SDK + real-device cold-launch smoke (open Hermes crash REACT-NATIVE-2); decide Mixpanel prod-vs-dev token.

---

## 1. BLOCKERS (must fix before submit)

### B1 — No consent before sending body/wardrobe photos to AI (Guideline 5.1.1 / 5.1.2, tightened 2026) — **HIGHEST RISK**
- `gemini_opt_in` is **hardcoded `true`** — `auxi/src/screens/BodyScreen.tsx:301` and `auxi/src/screens/see-this-on-me/try-on-generation-store.ts:135`. The user is never asked.
- Photos provably leave to third parties: `wardrobe-backend/blueprints/tryon/gemini_service.py:163,649` (Google Gemini), OpenAI in `wardrobe-backend/services/ai_service.py:93`.
- In-app copy is **misleading** — `body.privacy_note` "🔒 Your photo stays private." and `seeThisOnMe.privacy` "Your photos are always kept private" (`auxi/src/translations/en-EN.json:441,601`). Telling users photos "stay private" while shipping them to Gemini/OpenAI is itself a rejection trigger and a trust/legal problem.
- The only real consent toggle (`analyticsConsent`, `auxi/src/services/analytics.ts`) governs Mixpanel, not AI.
- **Fix:** add an explicit AI-data-sharing consent gate (modal/checkbox) before the first try-on/recommendation that names Google Gemini + OpenAI as recipients of the photos; bind `gemini_opt_in` to that real decision; persist it; remove or qualify the "stays private" copy.

### B2 — No AI-generated disclosure + no Report mechanism (Apple 2026 AI rules)
- No "AI-generated" label on try-on result `auxi/src/screens/see-this-on-me/OutfitPreview.tsx:27-47` (only a "Back to home" pill). No `ai_generated|disclaimer` strings exist.
- No **Report** affordance anywhere for inappropriate AI output (try-on or recommendations). No rights/limitations statement.
- **Fix:** on `OutfitPreview.tsx` + the recommendation result (`HomeScreen.tsx`) add (a) an "AI-generated" label, (b) a "Report" action (mailto or a report endpoint), (c) a short "AI-generated, may be inaccurate" note.

### B3 — Dead / placeholder UI visible to reviewer (Guideline 2.1 — #1 rejection cause)
- 3 tap-and-do-nothing rows with visible labels + chevrons: Settings "Your information" `auxi/src/screens/SettingsScreen.tsx:633` (no-op); Sidebar "Feedback" `auxi/src/components/layout/Sidebar.tsx:162` (a `Feedback` route **already exists** at `AppNavigator.tsx:135` — just unwired); Sidebar "My account" `auxi/src/components/layout/Sidebar.tsx:179`.
- "Coming soon" surface: Wardrobe → Add item → **Import from web** shows "Coming soon / …enabled after the next backend update" (`auxi/src/screens/WardrobeScreen.tsx:345-353`, strings `en-EN.json:206-207,344`).
- **Fix:** hide/remove the three dead rows + the "Import from web" option for the shipped build, OR implement them. Sidebar Feedback is a one-line wire: `navigation.navigate('Feedback')`.

### B4 — Sign in with Apple capability/entitlement appears missing (Guideline 4.8 + build config)
- SIWA is *required* because Google sign-in (third-party social login) is offered (`auxi/src/screens/auth/WelcomeScreen.tsx:278`), and SIWA **is fully implemented in code** (`auxi/src/services/oauth/appleSignIn.ts:36-57`, rendered `WelcomeScreen.tsx:309`, iOS-gated). That part is good.
- BUT there is **no `.entitlements` file at all** in `auxi/ios/auxi/` → the `com.apple.developer.applesignin` capability is not declared. Without it, Apple Sign-In fails at runtime and Apple flags a capability mismatch — turning a required, coded feature into a dead button on the reviewer's build.
- **Fix:** add the Sign in with Apple capability in Xcode (Signing & Capabilities) so an `auxi.entitlements` with `com.apple.developer.applesignin` is generated; confirm the entitlement ships in the archive.

### B5 — Privacy Policy / Terms not reachable from the app (Guideline 2.1 broken refs + 5.1.1)
- `WelcomeScreen.tsx:369-371` renders "By continuing, you agree to our Terms of Service and Privacy Policy" as **plain non-tappable text**; `legal_terms_link`/`legal_privacy_link` strings exist (`en-EN.json:79-80`) but are not linkified. Settings has no Privacy Policy row (`your_information` is a no-op). No privacy-policy URL exists anywhere in `src/`.
- Apple requires a reachable Privacy Policy URL (metadata-mandatory under 5.1.1), and a referenced-but-dead "Privacy Policy" is a broken-reference 2.1 flag.
- **Fix:** host a real privacy policy (must cover the AI third-party sharing from B1), linkify the Welcome legal substrings + add a Settings → Privacy Policy row via `Linking.openURL`, and set the Privacy Policy URL in App Store Connect.

---

## 2. WARNINGS (soft-rejection / risk — fix recommended)

- **Privacy manifest under-declares.** `auxi/ios/auxi/PrivacyInfo.xcprivacy` is present and valid (NSPrivacyTracking=false, required-reason APIs declared) but `NSPrivacyCollectedDataTypes` is **empty** while the app collects photos, email, analytics, crash data → label-mismatch risk. Populate it (Photos/UserContent, EmailAddress, ProductInteraction, CrashData).
- **Over-broad location permission.** `NSLocationAlwaysAndWhenInUseUsageDescription` declared (`Info.plist:66-69`) but stated use ("local weather") is foreground-only. Apple may question "Always" — drop to When-In-Use.
- **No connectivity detection / no crash boundary.** `@react-native-community/netinfo` not installed; no root `ErrorBoundary` in `src/`. Error copy + ~52 TanStack query error sites exist, so failed requests surface text+retry, but an unexpected render error = white screen on review. Add a root ErrorBoundary.
- **OAuth/Apple provisioning must be live in the release build.** `WelcomeScreen.tsx:215-224` falls back to a "Sign-in is not set up" toast when `isOAuthConfigured()` is false. If the release build ships placeholder client IDs / missing provisioning, **both Google and Apple buttons are dead** → 2.1 reject. Verify live config + that Google/Apple consoles are registered against `com.auxi2026.app` (OAuth comments still reference old `com.auxi.app`).
- **Hard login wall → demo account is mandatory.** `AppNavigator.tsx:92` gates all content on a user; no guest path. A working demo account (or a completable Apple/Google login) **must** be in App Store Connect review notes, and the Railway backend must be live during review.
- **Analytics hygiene.** Prod Mixpanel reuses the dev token (`auxi/src/config/analytics.ts:21`, TODO). Not a review blocker; fix for clean data.

---

## 3. CANNOT VERIFY (needs App Store Connect access or a real-device run)

- **Demo account (2.1)** — set in ASC → App Review Information; confirm it logs in and has wardrobe/body data. **Mandatory given the login wall.**
- **App Privacy nutrition label match (5.1.1)** — must declare: Photos/user-content, Email, Coarse location, Product-interaction (Mixpanel, EU residency), Crash/diagnostics (Sentry, PII off) — **and** the AI third-party data sharing (ties to B1). Reconcile in ASC.
- **Built with Xcode 26 SDK (April 2026 hard stop)** — set at archive time. Confirm SDK ≥ Xcode 26 at upload.
- **Crash-free launch on a real device** — repo memory notes a sim-only toolchain trap (Xcode 26.5 ↔ RN 0.83.1 unlinked pods) and an open iOS-26.5 Hermes crash (Sentry REACT-NATIVE-2). Run a **release archive on a physical device** before submit.
- **Distribution signing/provisioning, screenshots (6.9"/6.5"), age rating, support URL, EULA, export-compliance (encryption)** — all ASC-side metadata; verify manually.

---

## 4. PASS (verified in code)

- **No external payments; IAP N/A** — zero billing SDKs / paywall / Stripe; app is fully free (`package.json`, exhaustive src grep). §0-IAP and all of §4 N/A.
- **SIWA implemented in code** — `appleSignIn.ts` + rendered, iOS-gated (entitlement caveat = B4).
- **Not a web wrapper (4.2)** — no `react-native-webview`; 35 native screens, native-stack nav, native modules.
- **No hardcoded secrets (8 / security)** — only public OAuth client IDs + public Mixpanel token; no `.env`/keys tracked; prod backend over HTTPS (`env.ts`), ATS `NSAllowsArbitraryLoads=false` (`Info.plist:61`).
- **Permission usage strings present + specific** — Camera, Photo Library, Location When-In-Use all explain why (`Info.plist:66-73`).
- **ATT correctly absent** — no IDFA/cross-app tracking; Mixpanel opt-in, Sentry `sendDefaultPii:false`. Consistent with NSPrivacyTracking=false.
- **No cross-platform refs in shipped UI (2.1)** — no user-visible Android/Play strings.
- **Native value present (2.2)** — camera, photo library, GPS, Apple/Google sign-in, Keychain, crash reporting.
- **Background modes correct** — no `UIBackgroundModes`; matches actual (no background work).
- **Bundle/version present** — `com.auxi2026.app`, v1.0 / build 24, target iOS 15.1.

---

## Unresolved questions
1. Is there an actual hosted Privacy Policy + Terms URL anywhere (B5)? None found in code.
2. Does the release build ship live OAuth + the Apple Sign-In entitlement (B4 + provisioning warning)? Cannot confirm from source.
3. Is the App Store Connect privacy label already filled, and does it disclose AI third-party sharing?
4. Has a release archive been cold-launched on a physical device since the Hermes crash (REACT-NATIVE-2)?
