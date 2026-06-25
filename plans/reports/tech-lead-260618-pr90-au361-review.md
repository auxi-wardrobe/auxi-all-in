# Tech-Lead Review — PR #90 (AU-361 item-ready snackbar)

- **PR:** https://github.com/auxi-wardrobe/auxi-mobile/pull/90
- **Branch:** `fix/au361-toast-config-wiring` → `main`
- **Reviewer:** tech-lead · 2026-06-18
- **Verdict:** APPROVED + MERGED

## Scope confirmed
Effective net diff (`gh pr diff 90`) is exactly two files:
- `src/components/feedback/ItemReadySnackbar.tsx` (new, presentational overlay)
- `src/screens/WardrobeScreen.tsx` (modified, self-controlled snackbar state)

The branch's add-then-delete of `toastConfig.tsx` and change-then-revert of
`App.tsx` net to zero — confirmed: `git diff main..HEAD -- App.tsx` is empty,
`App.tsx:83` still renders bare `<Toast />` for the app's other built-in toasts.

## Checklist
- **In-screen overlay sound:** `showReadySnackbar` clears any prior timer before
  re-arming (re-trigger safe); `useEffect` cleanup clears the pending timeout on
  unmount (no leak / no setState-after-unmount). `pointerEvents="none"` on the
  overlay so touches pass through to the grid. `zIndex/elevation: 1000` floats it
  above the grid. PASS.
- **Dedup / detection unchanged:** `preparingIdsRef` + `readyToastedIdsRef` logic
  untouched; `readyToastedIdsRef.current.add(item.id)` still gates one fire per
  item per session (WardrobeScreen.tsx:178). PASS.
- **Analytics unchanged:** `track('item_ready_toast_shown', readyProps)` preserved
  (WardrobeScreen.tsx:188), same props, fires after dedup add. No new event, no
  PII. Tracking-plan doc needs no change (event already documented). PASS.
- **No dead refs:** zero `successSnackbar` occurrences tracked; only `toastConfig`
  mention is a history comment in ItemReadySnackbar.tsx:13 (doc, not code). The
  remaining `Toast.show(...)` calls (WardrobeScreen.tsx:278/343/353) are the
  built-in upload success/failure toasts — legitimately retained; `Toast` import
  still needed. PASS.
- **Theme tokens, no hex:** figmaSnackbarSuccessBg / figmaTextDark / uacTextBase /
  borderRadius.s / spacing.s / spacing.m all resolve in theme.ts. Two raw numbers
  (`width: 344`, `paddingVertical: 14`) are Figma-exact with no matching token and
  are commented as such — consistent with existing convention. PASS.
- **testID + a11y:** `testID="wardrobe-item-ready-snackbar"`, `accessibilityRole="alert"`,
  `accessibilityLabel={message}` on the snackbar; overlay carries its own testID.
  PASS.
- **Contract:** no `src/services/*` change, no backend touch. Out of scope for the
  two-repo contract — no API_DOCUMENTATION.md impact. PASS.
- **Commits:** conventional (`fix(wardrobe):`, `fix(a11y):`, `feat(ci):`). No
  secrets / PII / AI refs. PASS.

## Verification
- `npx tsc --noEmit` (Node 20.12.2) → exit 0. CLEAN.
- Live-verified by qa-mobile (screen recording: snackbar renders at preparing→ready
  transition, fires once, auto-dismisses at 4s, no crash) —
  plans/reports/qa-mobile-260618-1121-au361-inscreen-verify.md.

## Findings
- **minor (resolved at merge):** PR title/body still describe the superseded
  `toastConfig.tsx` registration approach, not the in-screen overlay that actually
  shipped. Not a code issue. Corrected the squash commit message at merge so the
  merged-history record matches the real change.

## CI
- Only red check is `archive` (GitHub Actions billing/infra, 2s, no log) — not a
  required check, no branch protection. Squash-merge proceeds without --admin.

## Merge
- Strategy: `--squash --delete-branch`. SHA recorded below.

## Merge outcome — DONE
- **State:** MERGED (2026-06-18T04:52:23Z)
- **Squash SHA on main:** `a1f2daff8f07076923698bc984959badb71bbc77`
- **Branch `fix/au361-toast-config-wiring`:** deleted
- Squash subject corrected to: `fix(wardrobe): render item-ready snackbar as in-screen overlay (AU-361) (#90)`
