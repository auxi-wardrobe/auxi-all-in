# PR #138 — DS-Primitive Conformance Audit

**Date:** 2026-06-25 · **Reviewer:** mobile-dev (read-only)
**Worktree:** `/tmp/auxi-pr138-review` @ `claude/vibrant-clarke-pmx77o` (merged-main state)
**PR:** "Add outfit limit sheet & randomize context chips"
**Rule:** `.claude/rules/design-system-primitives-required.md` · **Plan:** GH-364 (`plans/260624-1110-GH-364-ds-primitive-migration/plan.md`)
**CEO question:** when we apply the `M*` design-system components, will these PR components still be correct?

> Scope note: M* migration is **CEO-decided Phase 0 ONLY right now** (enforcement scaffolding + warn-lint). Phase 1 token-unify and Phase 3 screen migration are NOT yet greenlit. So "needs-M*" below = future migration target, not a this-PR blocker. The DS-primitive lint is **warn-mode**, not a gate yet.

## Verdicts

| File | Verdict | Which M* | file:line | Note |
|---|---|---|---|---|
| `components/features/OutfitLimitSheet.tsx` (NEW) | **needs-M*** | `MBottomSheet` + 2× `MButton` | `:94` (raw `Modal`), `:127` & `:138` (raw `TouchableOpacity` CTAs) | Headline finding. Hand-rolled `Modal`+`Animated` slide-up + 2 raw CTAs. Reimplements MBottomSheet (scrim, slide motion, backdrop dismiss, push-scale) by hand. Off-system; will be replaced in Phase 3. |
| `components/features/ContextChipsModal.tsx` | OK (token-only) | (already raw `Modal`/`TouchableOpacity`, pre-existing) | `:136` (raw Modal, pre-existing) | PR change = pure token re-point (`figmaAction`→`figmaPrimaryButtonBg`, `archivoButton`→`poppinsButton`, new `skipText`). No new structure. Modal→`MBottomSheet` is a pre-existing Phase-3 target, not introduced here. |
| `components/features/AiConsentDialog.tsx` | OK (token-only) | — | styles `:150,158` | Pure fill/label token re-point to `figmaPrimaryButtonBg`/`Text`. No structural change. |
| `components/features/PinConfirmModal.tsx` | OK (token-only) | — | styles `:311,323` | Same: `ds.color.ink`→`figmaPrimaryButtonBg`. Pre-existing raw Modal (`:138`) untouched by PR. |
| `components/features/PinGenerationError.tsx` | OK (token-only) | — | styles `:79,85` | Re-point + radius `999`→`16` + Poppins-Medium. No new primitive. |
| `components/settings/SettingsDialog.tsx` | OK (token-only) | — | styles `:160,172` | `figmaButtonDark`→`figmaPrimaryButtonBg`. Token re-point only. |
| `components/atoms/Button.tsx` | OK (token-only) | (atom slated for retirement) | styles `:101,126` | Primary fill→`figmaPrimaryButtonBg`, label→`figmaPrimaryButtonText`+medium weight. `atoms/Button` is itself a Phase-4 removal target (→MButton), but this PR only adjusts its tokens — no regression. |
| `components/primitives/FigmaPrimitives.tsx` | OK (token-only) | (PillButton → MButton in Phase 2) | `:225,304,328` | `PillButton` filled fill/label re-pointed to `figmaPrimaryButtonBg/Text`. PillButton itself is a Phase-2 absorb-into-MButton target; PR change is token-only and aligns it toward the M* primary. |
| `screens/HomeScreen/index.tsx` | OK | — | wiring `:986-1020`, `:1480` | New logic = limit-sheet state/handlers + renders `<OutfitLimitSheet>`. Pure wiring; carries `track()` events. Inherits the OutfitLimitSheet finding by composition, nothing else off-system. |
| `screens/HomeScreen/context-chips.ts` | OK | — | n/a | Pure data/logic (chip pool + Fisher-Yates `pickContextChips`). No UI. |
| `screens/HomeScreen/hooks/useContextRefineModal.ts` | OK | — | n/a | Hook/state only — random subset + shuffle + `refine_chips_shuffled` track. No UI. |
| `screens/HomeScreen/styles.ts` | OK (token-only) | — | `:474,479` | `pinGuestCta` re-point to `figmaPrimaryButtonBg`+Poppins-Medium. |
| `screens/OutfitCanvasScreen.tsx` | OK (token-only) | — | `pickerStyles confirmBtn :995,1007` | Confirm-button fill/label/radius re-point. Pre-existing raw `TextInput` (`:699`) + `TouchableOpacity` are NOT touched by this PR (own Phase-3 debt). |
| `screens/auth/*` (Email/SignIn/PasswordCreation/ResetNewPassword/Forgot*/Verify*/Welcome/Verified) | **out-of-scope-auth** | (MInput later, after dark roles) | EmailInput `:239`, SignIn `:213`, etc. | Rule EXEMPTS auth/UAC dark screens until DS dark roles land (Phase 1/D4). PR change there = same token/font re-point only; introduces NO new raw primitives. Nothing egregious. Leave as-is. |

## Conflict / double-style risk

**None found** — and importantly, the opposite is true: this PR's token work **de-risks** the migration.

- The PR introduces `figmaPrimaryButtonBg = #1D1F23` and `figmaPrimaryButtonText = #EFE9E3` (theme.ts `:55-60`) as the single primary-CTA source of truth, and re-points ~9 bespoke buttons to them.
- Those values are **already aligned to the M* primary button**: m-tokens `n800 = #1D1F23` = `role.ink` (what `MButton variant="primary"` fills with), and `p100 = #EEE6DE ≈ #EFE9E3` (its label). So when these buttons become `MButton`/`MBottomSheet` later, the visual stays put — clean swap, no double-style fight.
- No PR component wraps a would-be-M* in a manual height/bg container the way the just-fixed `WardrobeScreen.emptyCtaWrap` did. OutfitLimitSheet sets its own height/radius (`:213-219`) but that's self-contained bespoke styling that gets *deleted* on migration, not a wrapper clashing with an M*.

## Bottom line (CEO answer)

When DS primitives are applied, **everything in this PR stays visually correct**, and almost all of it is already on-system: 11 of the touched files are pure token/font re-points that deliberately steer toward the M* primary palette, so the migration is a clean find-and-replace with no visual shift and **zero conflicts**. The **one off-system component is the new `OutfitLimitSheet.tsx`** — it hand-rolls a raw `Modal` + `Animated` slide-up + raw `TouchableOpacity` CTAs instead of building on `MBottomSheet`/`MButton`; it works today but is the one piece the migration will re-do (and re-doing it as `MBottomSheet` would shed ~150 lines of duplicated scrim/motion/dismiss scaffolding). Auth screens are correctly out-of-scope (exempt until DS dark roles ship) and this PR adds no new raw primitives there. Nothing in PR #138 will fight the migration; the token unification actively makes it easier.

**Recommendation:** merge is fine as-is (migration is Phase-0-only right now). When Phase 3 reaches Home cohort, port `OutfitLimitSheet` to `MBottomSheet` + `MButton` first — it's the only net-new off-system surface this PR adds, and porting it now (before it's copied as a pattern) is cheap.

## Unresolved questions
1. Should OutfitLimitSheet be ported to `MBottomSheet` *in this PR* (prevents the raw-Modal pattern propagating — its header comment even cites ContextChipsModal/MoodFeedbackSheet as the "house pattern" it's copying), or deferred to the Home cohort in Phase 3? Recommend: defer, but flag it in the migration plan's Cohort B Home line so it isn't missed.
2. `figmaPrimaryButtonText #EFE9E3` vs m-tokens `p100 #EEE6DE` differ by ~2 LSB per channel — intentional, or should they be unified to one hex when Phase 1 lands? (Imperceptible; flag for the token-unify pass, not this PR.)
