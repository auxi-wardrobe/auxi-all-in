# qa-ui · Review-Extraction Audit — Onboarding Redesign

> **Mode:** Pass-1 review-extraction (pre-code gate). Artifact-vs-Figma diff ONLY.
> No code, no sim screenshot, no theme edits. Per `auxi-figma-audit` Pass 1.

- **Date:** 2026-05-26 15:56
- **Auditor:** qa-ui
- **Figma:** `0nXXMAR4Arf1ZfjtQvtBh0` · section `2849:8331` ("onboarding", 17 frames)
- **Artifact:** `plans/260526-1443-onboarding-figma-extraction/figma-extraction-onboarding.md`
- **Decisions (settled, not re-litigated):** `plans/260526-1451-onboarding-redesign-implementation/phase-00-decision-gates.md`
- **Method:** `get_metadata` (full tree) + `get_screenshot` (all 8 distinct screen types) + `get_variable_defs` (section-level), diffed against artifact claims.

---

## VERDICT: **PASS** (with 5 minor notes for implementation)

The extraction artifact faithfully captures the Figma design. All 8 distinct
screen types, the flow order, the frame tree, the token list, components,
states, copy (including the typos), and icon enumeration match what Figma
actually renders. Discrepancies found are **naming-level / non-blocking** —
none change what gets built. No re-extraction required. Phase 1 implementation
is unblocked.

---

## Pass-1 checklist results

| Check | Result | Notes |
|---|---|---|
| Frame tree matches `get_metadata` (no missing/hidden/invented node) | ✅ | 17 frames, every node-id in artifact §1 verified against metadata. Hidden groups (`Group 11/12/13`, in-flow `button group` `hidden=true`) correctly flagged as hidden, not rendered. |
| Token list complete (every fill/stroke/pad/font → var, captured) | ✅ | All rendered tokens captured. 2 unused vars omitted (correctly — see Note 2). |
| Icon enumeration complete (size + currentColor flag) | ✅ | 6 icon needs listed w/ size + export convention. |
| Variant/state coverage (every variant used → listed) | ✅ | Button ×4 variants, tile default/selected/disabled/pinned, chip selected, header, pin all listed. |
| "Open questions" non-empty where intent ambiguous | ✅ | §9 has 11 questions; all resolved in phase-00 D1–D11. |
| "New backend fields" accurate vs services/* | ✅ | §8 escalations (Mixed, 2-pick, fit field) all addressed in phase-00 (backend verified ready, no migration). |

---

## Screen-by-screen verification (Figma render vs artifact)

| # | Screen | node | Figma render confirms artifact? |
|---|---|---|---|
| 1 | Welcome Home | `2849:8332` | ✅ "Welcome to auxi" 2-line Poppins Bold; subtitle w/ grammar slip; dark CTA "Get started — takes 1 min"; logo mark centered; no header. |
| 2 | Step 1 wardrobe | `2849:8339` | ✅ Step 1/3 + 3-seg progress (1st active); "What's your wardrobe like?"; 3 tiles (2-up Womenswear/Menswear + solo Mixed); caption pills; **disabled grey Continue**. |
| 3 | Step 2 fit (menswear) | `2849:8423` | ✅ Step 2/3; "How do you like things to fit?"; Slim/Regular/Relaxed; **Slim+Relaxed dimmed (unselected), Regular selected w/ dark 4px border**; enabled dark Continue. |
| 3b/3c | fit womenswear/mixed | `2849:8443`/`8460` | ✅ Branch headline differs ("Which fit makes you feel most confident?") — captured in §3.3. |
| 4 | Step 3 styles (base) | `2849:9748` | ✅ Step 3/3; 5 tiles; "Pick up to two". |
| 4-pin | Step 3 styles (pinned) | `2849:9883` | ✅ Pin badges **"1" & "2"** on selected tiles w/ borders; sticky bottom secondary **"(2/3) Next"** + chevron. |
| 5 | Loading | `2849:8477` | ✅ Cream bg; "You selected" chips; "MACGIE…will be ready"; 2 loading rows w/ spinners; **disabled grey Next + Retake** text button. |
| 6 | Completed | `2849:8498` | ✅ Same layout; "is ready"; NO loading rows; **enabled dark Next + Retake**. |
| 7 | Outro | `2849:8510` | ✅ Cream bg; quote "One small step is enough." w/ leading quote glyph; bottom-sheet "See my outfit" text button + icon. |

**Flow order** (Welcome → Step1 → Step2 → Step3 → Loading → Completed → Outro)
and back-nav / progress-bar / no-skip claims all match.

---

## Discrepancies (all minor — do NOT block code)

**Note 1 — Chip-bg variable name mislabel (cosmetic, same hex).**
Artifact §3.5 / §4.1 attributes the selected-chip bg `#5b5550` to var
`background/primary/bold_500`. The section `get_variable_defs` exposes **both**
`background/primary/bold_500` = `#5b5550` AND `border/primary/bold_500` =
`#5b5550` (same hex, two var names). Artifact's proposed new token
`figmaChipBg`/`colorPrimaryBold500` is still correct — just note the canonical
Figma var name is ambiguous between the two. No build impact.

**Note 2 — Two section-level vars resolve but aren't in artifact §4.1 table.**
`get_variable_defs` on the section returns two colors the artifact doesn't list:
- `border/primary/subtle_100` = `#c6bcb1`
- `background/neutral/subtlest` = `#ffffff` / `background/neutral/base` = `#1d1f23` (dupes of captured hexes under alt names)

`#c6bcb1` does **not** appear on any rendered layer I could see in the 8
screenshots (likely a component-library default on a hidden/instance sub-layer).
Artifact's omission is acceptable (it captured *rendered* tokens), but
implementation should treat `#c6bcb1` as **out of scope unless a tile
border/disabled-state surfaces it** during Phase 2. Flagging so it isn't a
surprise.

**Note 3 — `border-radius/sm` = 6 is a real Figma var, not an inference.**
Artifact §4.3 marks chip radius `6` as "❌ NEW radius needed … inferred." The
section vardefs confirm `border-radius/sm` = `6` **exists as a Figma variable**.
Conclusion (add `borderRadius.chip = 6`) is unchanged; just upgrade confidence
from "inferred" to "confirmed Figma token."

**Note 4 — Step-2 womenswear/mixed branch frames have NO `header` instance.**
Metadata shows `2849:8443` (womenswear fit) and `2849:8460` (mixed fit) use a
plain `Top bar` frame (`2849:8455` / `2849:8472`, 45×45 back) instead of the
shared `header` instance (h107) that the menswear frame `2849:8423` and Steps
1/3 use. Artifact §2 says "Steps 1–3 carry a `header` instance (h107)" — true
for the menswear/base frames but **the womenswear+mixed fit branches use a bare
Top-bar back button, not the header component**. Since D8 resolves Step 2 to
**one parameterised screen** (using the shared header), this is just a Figma
artboard inconsistency and the implementation (one header) is correct. Note it
so QA Pass 2/3 doesn't flag the womenswear branch as "missing header."

**Note 5 — "Continue" CTA vertical position differs across Step frames (non-spec).**
Button y-offset varies: Step1/menswear-fit Continue at y≈786, womenswear-fit at
y≈758, mixed-fit at y≈742 (metadata). Artifact gives a single position. These
are artboard drift, not distinct states — a single bottom-anchored CTA (as the
artifact implies) is correct. No action; just don't pixel-match per-branch y.

---

## Cross-check: artifact's open questions are all resolved

All 11 §9 questions map cleanly to phase-00 D1–D11 resolutions (MACGIE→"Your
wardrobe", typos fixed, caption pill = `rgba(18,18,18,0.75)`, pin = View+number
max 2, one parameterised screen, location prompt placement = Welcome→Location→
Step1, Loading = real async on `/generate`, dup frame `2850:13995` ignored).
Nothing left dangling that would force an ESCALATE.

---

## Unresolved questions (for implementer awareness, not blockers)

1. `#c6bcb1` (`border/primary/subtle_100`) — confirm it never surfaces on a
   tile border/disabled chrome during Phase 2; if it does, add the token.
2. Chip-bg canonical Figma var name (`background/` vs `border/`/primary/bold_500)
   — cosmetic; pick one alias name in `theme.ts`.

**Routing:** PASS → mobile-dev proceeds to `figma-to-rn-workflow` Phase 1.
No re-extraction. Carry Notes 1–5 into implementation; re-verify Note 2/4 in
Pass 2/3 (code-vs-Figma) once screens exist.
