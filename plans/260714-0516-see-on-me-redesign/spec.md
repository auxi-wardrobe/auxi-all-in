# See-on-me redesign — chat-transcript → stepped onboarding flow

**Figma:** `Macgie` file `0nXXMAR4Arf1ZfjtQvtBh0`, section `See this on me - 1.1` node `4814:11694`.
**Branch (auxi submodule):** `claude/see-on-me-redesign-ygds3d`.
**Delivery:** commit in `auxi` submodule; umbrella bumps the pointer. Backend endpoint is a follow-up (repo not reachable this session).

## Goal

Replace the current **conversational transcript** (accumulating prompt bubbles + thumbnails) UI of `see-this-on-me` with a **full-screen stepped onboarding-style flow** matching the Figma frames. The async generation backbone (`tryOnGenerationStore`, `use-try-on-generation`, background-notify, completion notice) and the services layer are UNCHANGED — only the presentation shell + two new behaviors + a feedback vote are added.

## Frame → screen map (all frames 390×844)

| Figma frame | node | Screen |
|---|---|---|
| step 1 - ask to upload selfie | 4814:11695 | Step 1/3 selfie card |
| step 2 - ask to upload body | 4814:11710 | Step 2/3 full-body card (optional) |
| Loading step 3 | 4814:11737 | Body-shape generation loading |
| step 3 - choose a body fit | 4814:12741 | Body-fit picker (Next disabled) |
| step 3 - choose a body fit (selected) | 4814:13267 | Picker with middle tile selected, Next enabled |
| step 3 - choose a body fit - expanded | 4814:11783 | Expand bottom sheet (silhouette detail) |
| loading to see result | 4814:13137 | Outfit render loading |
| success AI | 4814:11877 | Result + thumbs feedback |

`Favourite collection` (4814:11887) is NOT part of this flow — ignore.

## Reuse map (build on these, do NOT recreate)

- **Step header + 3-segment progress bar** — `src/onboarding/v2/OnboardingStepHeader.tsx` renders the exact "Step n/3" + segmented bar. Lift it into a shared location (e.g. `src/components/layout/StepProgressHeader.tsx`) or reuse in place. The See-on-me header (`StomHeader`, centered "See on me" title) stays as the top app-bar; the "Step n/3" + segments sit BELOW it (Figma `Frame 2086`).
- **Async store + hooks** — `try-on-generation-store.ts`, `use-try-on-generation.ts`, `try-on-background-notify.ts`, `try-on-completion-notice.ts`: unchanged.
- **Body-fit picker + expand sheet** — `StepBodyShape.tsx` (row of 3 tap tiles) + `BodyShapeCarousel.tsx` (expand sheet: dots, opt-in checkbox, Retake / Use this photo). Reuse; see behavior change below.
- **Loading mascot + quit** — `GeneratingView.tsx` + `MacgieLoader`/`components/macgie` cat. Reuse the mascot + the "Leave — notify me when ready" quit CTA (`seeThisOnMe.quit.cta`). See staggered behavior below.
- **Checkmark loading rows** — mirror `OnboardingLoadingScreen.tsx`'s `LoadingRow` pattern (spinner + label row) but with a completed-check state.
- **Result preview** — `OutfitPreview.tsx` + `AiContentDisclosure`. Reuse; add thumbs row.
- **Primitives** — `PillButton`, `TopIconButton`, `Header.BackTitle`, `LoadableRemoteImage`, `PrivacyFooter`.
- **Privacy footer** — Figma `footer` "Your photos are always kept private" → `seeThisOnMe.privacy` already exists (long copy). Figma uses a shorter line; add `seeThisOnMe.privacyShort` = "Your photos are always kept private".

## New behaviors

### B1 — Staggered loading reveal + min-wait gate (both loading screens)
Figma "Loading step 3" (3 rows) and "loading to see result" (4 rows). Each row = a 24×24 check/spinner icon + label.
- Rows reveal **one every 2 s** (row 1 at t=0, row 2 at t=2s, …). A revealed row shows a green check (or transitions spinner→check); unrevealed rows are hidden.
- The **"Leave — notify me when ready"** CTA (Figma `button group` Button) is **disabled until ≥ 7 s** have elapsed, then enabled — regardless of how many rows are shown. (3 rows = 4s of reveals, so the 7s floor is the binding gate; 4 rows = 6s, still gated to 7s.)
- Copy: shapes loading headline `seeThisOnMe.loadingShapes.title` = "Creating your starting point…" with rows: "Analyzing facial features from your selfie", "Understanding body proportions from your photo", "Creating 3 realistic body variations for you to choose from". Result loading headline `seeThisOnMe.loadingResult.title` = "Creating your outfit preview…" with rows: "Matching your selected body shape", "Mapping clothing fit and proportions", "Adjusting layering and garment details", "Rendering your personalized outfit".
- Footer supporting text (Figma `footer`): `seeThisOnMe.loading.footer` = "This can take longer than expected.\nYou can leave — we'll let you know the second it's ready."
- Implement the reveal/gate as a small reusable hook, e.g. `useStaggeredReveal(rowCount, { stepMs: 2000, minCtaMs: 7000 })` returning `{ visibleCount, ctaEnabled }`. Respect reduce-motion (still gate the CTA to 7s, but reveal all rows immediately). This is a UX timer only — it does NOT gate the real async job; if the job finishes first, transition normally.

### B2 — Next-button gating on the body-fit step
Today `BodyShapeCarousel`'s "Use this photo" immediately fires the render. New flow (Figma 4814:12741 → 13267 → success):
- Tapping a tile opens the expand sheet. In the sheet, "Use this photo" **selects** the build (records `selectedShape`) and closes the sheet — it does NOT render yet.
- The selected tile shows a selected border on the picker screen (Figma 13267, middle tile).
- A bottom **Next** button (Figma `button group`) is **disabled until a shape is selected**; tapping Next fires `handleSelectShape`/render → the result-loading screen.
- Keep the opt-in checkbox ("Use this photo for future outfit previews") in the sheet as today.
- Preserve partial/regenerate affordance.

### B3 — Thumbs feedback on the success screen (Figma 4814:11877)
- Two 32×32 white rounded-8 buttons (shadow `0px 1px 1px rgba(0,0,0,0.15)`), 4px gap, overlaid bottom-center ON the result image (Figma nodes 4814:13242 thumb-up, 4814:13237 thumb-down; icons 24×24 at 4814:13244 / 4814:13239).
- Export the two glyphs as SVGs with the `currentColor` convention → `src/assets/images/icon_thumb_up.svg`, `icon_thumb_down.svg`, register in `src/assets/icons/index.ts` as `Icons.ThumbUp` / `Icons.ThumbDown` (use the Figma download/asset for the exact path; do not hand-draw).
- Tap toggles a single-choice vote (up XOR down); selected state fills/tints the chosen thumb. Optimistic UI.
- Fire the vote via a new `src/services/tryOnFeedbackService.ts` → `POST /api/tryon/feedback` (contract below). **Fire-and-forget / optimistic**: swallow errors (endpoint may not be live yet) — never block or error the UI on failure. Debounce/allow changing the vote.
- testIDs: `stom-feedback-like`, `stom-feedback-dislike` (flip suffix for selected state, e.g. `-like-selected`). a11yLabels "Like result" / "Dislike result".

## Backend contract (follow-up — repo not reachable this session)
`POST /api/tryon/feedback`
```
Request:  { job_id: string, result_url: string, vote: "up" | "down" }
Response: 200 { ok: true }   (idempotent per job_id; latest vote wins)
```
Document in `wardrobe-backend/API_DOCUMENTATION.md` and file a backend follow-up issue. Mobile ships against this contract now.

## Analytics (rule: `.claude/rules/analytics-tracking-required.md`)
All via `src/services/analytics.ts`, literal names, past tense, no PII. Existing events (`try_on_started`, `body_shape_generation_started/completed/failed`, `body_shape_selected`, `try_on_completed`, `try_on_failed`, quit/backgrounded, etc.) stay. Add:
- `try_on_step_viewed` `{ step: "selfie" | "full_body" | "body_fit" }` — on each stepped screen focus.
- `try_on_result_liked` `{ outfit_hash }` — thumb up.
- `try_on_result_disliked` `{ outfit_hash }` — thumb down.
- (Next-gating reuses existing `body_shape_selected` on Next tap.)
Update `auxi/docs/analytics/mixpanel-tracking-plan.md` §5 (shipped) + §6 (the feedback endpoint dependency if the like/dislike write is server-gated) + §10 (funnel: the try-on funnel gains a result-satisfaction step).

## Tokens / lint
No raw hex in screens — use `theme.ts` tokens (`ds.*` where available). Run `./scripts/auxi-lint-tokens.sh` clean. Figma vars already map: `background/primary/subtle_50 #f2efec` (image bg), `text/neutral/base #1d1f23`, `background/neutral/subtlest #ffffff`, Poppins body md/xs.

## Verification (this environment — no iOS sim available)
- `cd auxi && npx tsc --noEmit` (legacy `_HomeScreen.tsx` errors expected) — must be clean otherwise.
- `yarn lint` — no NEW errors/warnings beyond the known `_HomeScreen.tsx` baseline (4 err / 3 warn).
- `yarn jest` for touched areas; add/adjust tests for the staggered hook + Next-gating + feedback vote.
- `./scripts/auxi-lint-tokens.sh` clean.
Sim / qa-ui Compare / designer gate / qa-mobile can't run headless here — leave those for an interactive session; note it in the delivery report.

## Out of scope
Backend endpoint implementation; iOS-sim visual verification; any change to the reuse/rehydrate/cached-result/AI-consent/AI-limit logic beyond wiring it into the new shells.
