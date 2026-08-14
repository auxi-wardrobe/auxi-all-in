# AU-442 Ghost/Duplicate Screen Snapshot — Round 3 Re-verify

**Verdict: Finding 1 — FIXED (PASS)**
**Finding 2 (green confirmed state) — still intact (PASS, quick sanity check)**

## Setup
- Device: iOS Simulator, iPhone 17 Pro, UDID `34528D25-C08D-4E54-89B8-BDA0E3226B7F`
- Commit: `7d0082529adfc06e280b7783940c379adc7ff26e`
- Branch: `nguyenthaihiep94/au-442-paywall`
- App relaunched (terminate + launch) to pick up fresh JS bundle from live Metro `:8081`. No native rebuild performed.
- `./scripts/mcp-doctor.sh` pre-flight: healthy (sim booted, WDA up on :8100).

## Repro executed
1. Launch app → hamburger (`home-menu-button`) → Settings → About (`settings-about-row`) → "Preview usage limit sheet (QA)" (`settings-dev-usage-limit-preview`).
2. `UsageLimitSheet` opened.
3. Tapped "Upgrade to Macgie+".
4. Screenshot immediately post-transition, then 2 more spaced ~2s apart.
5. Repeated the entire flow a second time (close via `notify-me-close-button` → About → re-trigger) to rule out intermittency.
6. On each run, also tapped "Notify me" (`notify-me-cta`) to sanity-check the green confirmed state.

## Result

**No ghost/duplicate miniaturized card appeared in any screenshot, across two independent trigger runs (6 screenshots total spanning ~0s to ~5s post-transition).**

Run 1: immediate + 2 delayed screenshots (t≈0s, 2s, 4s) — clean, no ghost, no artifacts top-left under the status bar.
Run 2 (repeat, after closing back to About and re-triggering): immediate + 1 delayed screenshot (t≈0s, 2s) — clean, no ghost.

Finding 2 sanity check: "Notify me" → green "We'll notify you" pill with checkmark icon rendered correctly on both runs, no ghost card present in that state either.

Screenshots saved:
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-round3-notifyme-no-ghost.png` (immediate post-transition, run 1, black "Notify me" CTA state, no ghost)
- `auxi/docs/qa-findings/screenshots/2026-08-14/qa-mobile-au442-round3-notifyme-confirmed-green.png` (green confirmed state, run 2, no ghost)

`mobile_list_crashes` at end of session: `[]` — no crashes.

## Diagnostic note re: SeeThisOnMeScreen.tsx (not re-verified)

Per the dispatch, `SeeThisOnMeScreen.tsx` reportedly still uses the same
Fragment-sibling mount pattern that originally caused the ghost bug, and was
NOT touched in this round's fix. I did not find a quick QA/debug trigger for
the real See-on-Me limit sheet on the About screen (only one dev row exists:
`settings-dev-usage-limit-preview`, which is the NotifyMe path already
exercised above). Forcing 2 real try-on generations to hit that real limit
flow was out of scope per the "don't spend excessive time" instruction, so
this path is **not verified this round** — still an open risk if
`SeeThisOnMeScreen.tsx` shares the un-fixed Fragment-sibling pattern.

## Verdict summary

- Finding 1 (ghost card via NotifyMe debug-row path): **FIXED**, confirmed across 2 back-to-back runs, no intermittency observed.
- Finding 2 (green confirmed state): **intact**.
- Open/unresolved: `SeeThisOnMeScreen.tsx` Fragment-sibling pattern not re-verified — same bug could still be reachable via the real See-on-Me limit flow (not the debug row). Recommend a follow-up smoke pass once a real See-on-Me limit exhaustion is reachable cheaply (e.g., seeded low-limit QA account), or ask mobile-dev to confirm whether `SeeThisOnMeScreen.tsx` was updated to the same nested-`<View>` mount pattern as the debug row.
