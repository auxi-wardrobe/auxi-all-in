# Auxi Mobile — PR Gate Sweep (Designer + Tech-Lead)

**Date:** 2026-06-28 00:22 · **Repo:** auxi-wardrobe/auxi-mobile · **Scope:** all 18 open PRs (#149, #153–#169)
**Method:** 14 sub-agents (6 designer-gate + 8 tech-lead), clustered by shared files to catch cross-PR conflicts. Static review only — no simulator (runtime/visual verification deferred). Every verdict posted as a scoped PR comment.

## Verdict matrix

| PR | Title | 🎨 Designer | 🧭 Tech-Lead | Git state | Net |
|----|-------|------------|-------------|-----------|-----|
| #157 | Remove AI disclosure toast (Home) | ESCALATE | REQUEST-CHANGES | OPEN · MERGEABLE | 🛑 **HOLD — App Store compliance** |
| #163 | Thread persona prefs → build req | n/a (logic) | REQUEST-CHANGES | OPEN | 🛑 **HOLD — backend-first (sent-but-ignored)** |
| #162 | Deterministic collage engine | ESCALATE | REQUEST-CHANGES | OPEN | ❌ critical drop-bug + re-seed wipes edits |
| #156 | Add Schedule screen | FAIL | APPROVE-WITH-NITS | OPEN · CONFLICTING | ❌ M* sheet bypass + reduce-motion + safe-area + rebase |
| #153 | My Creations unseen + removal | ESCALATE | REQUEST-CHANGES | OPEN | ❌ scope-split + analytics gap + skipped header gate |
| #164 | Favourite sticky footer | PASS-WITH-MINORS | REQUEST-CHANGES | OPEN | ❌ funnel pollution + untested scroll |
| #158 | Header → canonical component | ESCALATE | APPROVE-WITH-NITS | OPEN · CONFLICTING | ⚠️ ratify title size (CEO) · **merge first** |
| #155 | Sidebar width responsive | PASS-WITH-MINORS | APPROVE-WITH-NITS | OPEN | ⚠️ confirm width canonical + dark seam |
| #161 | Canvas prefetch + loading | PASS-WITH-MINORS | APPROVE-WITH-NITS | OPEN · MERGEABLE | ⚠️ gated on rebase after #162 |
| #165 | Temperature override toast | PASS-WITH-MINORS | APPROVE-WITH-NITS | OPEN | ✅ rebase + reconcile bottom toast slot |
| #168 | Rec memory + mood signals | n/a (logic) | APPROVE-WITH-NITS | OPEN | ✅ contract verified consumed; async-hydrate nit |
| #159 | docs: rec architecture ADR | n/a (docs) | APPROVE-WITH-NITS | OPEN | ✅ 2 doc fixes |
| #160 | DB clone per-item endpoints | PASS-WITH-MINORS | APPROVE-WITH-NITS | **MERGED** | ✅ contract verified (fixed phantom endpoint) |
| #167 | Canvas icon refresh + viewBox | PASS-WITH-MINORS | APPROVE-WITH-NITS | **MERGED** | ⚠️ follow-up: hardcoded hex → currentColor |
| #169 | Saved btn → Favourites link | PASS-WITH-MINORS | APPROVE-WITH-NITS | **MERGED** | ✅ done; event-source nit |
| #166 | Label "Self viz" → "See on me" | n/a (copy) | COMMENT | **MERGED** | ⚠️ follow-up: fr/vi parity break |
| #154 | Refine toast ("Relaxed applied!") | **FAIL** | APPROVE-WITH-NITS | **MERGED** | ⚠️ **merged despite designer FAIL** → rebuild on MSnackbar |
| #149 | docs: designer-gate record #147 | n/a (docs) | APPROVE | **MERGED** | ✅ historical artifact |

## Must-decide (blocking / CEO calls)

1. **#157 — AI-disclosure removal = App Store compliance regression.** PR #100 deliberately added the AI-generated-content disclosure on the Home recommendation surface for App Store readiness. The surviving `AiContentDisclosure` is try-on-image-only (`OutfitPreview.tsx:41`, `surface="tryon"`) — it does NOT preserve Home coverage. **PR is MERGEABLE — risk of accidental merge.** Decision: mount a persistent Home disclosure, or documented CEO/PM compliance sign-off.
2. **#163 — persona prefs are a contract no-op.** Mobile POSTs `style_direction`/`confidence_level` to `/v05/build`, but backend `UserDTO` (`schemas/v05_recommendation.py:48`) accepts only `{gender, occasion}` with `extra='ignore'` → silently dropped; V05 engine never reads persona (only V2/V3 do). Backend-first: extend `UserDTO` + wire into `engine_v05` scoring + update API doc, deploy, then ship mobile. Hold #163.
3. **#162 — collage engine has a data-loss bug.** `buildSkeleton` (`collage-seed-layout.ts`) silently drops same-role garments (output can be shorter than input; whole-canvas re-seed can delete an existing item), uncovered by tests. Plus re-seed wipes all manual x/y/scale/rotation on every add. CEO taste calls: Save outline→filled, and a new second "+" glyph colliding with the toolbar add.
4. **Header title typography — one canonical size.** Three PRs contest it (all Poppins; doc "Playfair"/#153 "Inter" are stale misnomers): doc 24/32-Medium vs **#158 16/24-SemiBold** vs #153 14/20-SemiBold. CEO ratify one; update `header-footer-rules.md`.
5. **#154 already merged despite designer FAIL** — hand-rolls a toast where `MSnackbar` exists, no enter/exit animation, duplicate `figmaToastInfoBg` token. Needs a follow-up PR to rebuild on `MSnackbar`.

## Cross-PR conflict map + merge order

- **`HomeScreen/index.tsx`** — #165, #157, #163 (open) + already-merged #169/#154. Open ones must rebase onto current main.
- **`Header.tsx`** — #158 (rewrite) ↔ #156 (incompatible prop names `leftTestID` vs `leftIconTestID`).
- **`SidebarMenu.tsx`** — 3-way: #155 (width) + #156 (items) + #153 (badge).
- **`OutfitCanvasScreen.tsx`** — #162 ↔ #161 (same `handlePickerConfirm`/`setItems` + `saveRow`).
- **`v05Api.ts`** — #168 ↔ #163 (import-line).
- **7 screens** — #158 ↔ #153 (both edit all 7).

**Recommended sequence:**
- Chrome: **#155 + #158 first** → then #156 + #153 rebase onto preset Header API + reconcile SidebarMenu.
- Canvas: **#162 first** (fix drop-bug) → rebase #161 on top.
- HomeScreen toasts: land #165 (rebased) with bottom-slot mutual-exclusion.

## Follow-ups on already-merged PRs

- **#154** → rebuild toast on `MSnackbar` (designer FAIL was merged).
- **#166** → fr-FR/vi-VN still say old meaning ("Auto-visualisation"/"Tự hình dung"); 2-line i18n fix + CEO call on whether "See on Me" stays English.
- **#167** → migrate `canvas-icons/*` to `currentColor`; `trash.svg` `#C0392B` → `ds.color.danger #bb251a`.
- **#160** → partial-failure success toast masks the error toast.

## Ready to merge (after rebase, nits non-blocking)

#168, #159, #165, #161 (post-#162).

## Unresolved questions

1. #157 — does the Home recommendation surface legally require the AI disclosure, or is try-on-only sufficient? (gates merge)
2. #163 — is persona-into-V05 a real engine feature to prioritize as a backend ticket now?
3. #162 — is "one garment per role, extras dropped" intended, and is re-seed-discards-manual-arrangement approved?
4. Canonical header title size + sidebar 4/5-width-vs-317px — ratify and doc-sync.
5. #155 dark back-layer reversal — confirm no seam regression on device (qa-ui/qa-mobile).
