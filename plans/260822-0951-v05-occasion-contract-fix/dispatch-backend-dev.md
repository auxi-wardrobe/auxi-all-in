# Dispatch prompt — F1 implementation (paste vào session mới trên `auxi-wardrobe/auxi-backend`)

> Prompt tự chứa (self-contained). Session nhận prompt này KHÔNG có umbrella repo,
> nên mọi thứ cần thiết đã được inline. Spec đầy đủ: `plans/260822-0951-v05-occasion-contract-fix/plan.md`.
> Cách dùng: mở session Claude Code mới với source `auxi-wardrobe/auxi-backend`, dán phần dưới.
>
> **Thứ tự ưu tiên:** F6 (`plans/260822-0958-v05-coherence-floor/`) đứng TRƯỚC F1 này — xem plan.md §12.
> F1 là lớp phòng thủ thứ hai. Đừng dispatch F1 trước khi F6 đã ship hoặc CEO đổi thứ tự.

---

You are working in `auxi-wardrobe/auxi-backend` (FastAPI · SQLAlchemy · Postgres), the V05 outfit recommendation backend. Fresh session — no prior context. Read this whole brief before touching anything.

# Goal

The V05 formality gate is **disabled in production**. Restore it, behind a config flag, without collapsing the candidate pool.

# The bug

The mobile Home screen sends the UI *mode* in the `occasion` field:

```jsonc
{
  "user":   { "gender": "U", "occasion": mode },   // mode = 'safe' | 'power' | 'creative'
  "intent": { "mood": MODE_TO_MOOD[mode] }         // the SAME signal, already on its own path
}
```

`'safe'` / `'power'` / `'creative'` match no key in `OCCASION_FORMALITY`
(`blueprints/recommendation/engine_v05_constants.py`, ~line 272-289) → the lookup falls back to
`'unknown'` = `(3,6)`, then a ±2 widening → **window `[1,8]` = the entire formality scale**.
The gate rejects nothing.

Production evidence: `occasion='safe'` on **75 of 124** `v05_pool_insufficient_events`.
Consequence: nothing stops the engine pairing track pants (formality ≈1) with leather loafers (≈5).
First flagged 2026-05-22; still open.

**`MODE_TO_MOOD = { safe: 'calm', power: 'confident', creative: 'playful' }`** — the mode signal
already reaches the engine correctly through `intent.mood`. So `occasion: mode` is redundant data
whose only effect is breaking the formality window. Dropping it loses no signal.

# Phase 0 — HARD GATE. Verify before writing any code.

Reports below are dated 2026-05/06 and cite real `file:line`. It is now later. **If any check
fails, STOP and report — the design may need to change.**

1. **Is the bug still live?**
   ```sql
   SELECT occasion, COUNT(*) FROM v05_pool_insufficient_events
   WHERE created_at > NOW() - INTERVAL '14 days' GROUP BY 1;
   ```
   No `safe`/`power`/`creative` rows → someone already fixed it → **STOP, close this plan.**

2. **Read `OCCASION_FORMALITY` for real.** Which keys exist? What is the `unknown` tuple?
   **Where is the ±widening applied — to every occasion, or only to `unknown`?**
   The final number in "Change 1" below depends entirely on this answer.

3. **Does the engine actually read `intent.mood`?** If not, removing `occasion: mode` WOULD lose
   signal → change approach, report back.

4. **Does mobile still send it?** `auxi/src/screens/HomeScreen.tsx:610,629` — line numbers may have
   drifted after the `GH-364-mobile-screen-refactor`. (Mobile is a different repo; just confirm the
   contract, don't edit it — that's Phase 3, a different agent.)

# The changes (backend only — this dispatch is Phase 1)

## Change 1 — narrow the `unknown` fallback 🔴 this is the real fix

`blueprints/recommendation/engine_v05_constants.py` (~272-289)

| | tuple | after widening | meaning |
|---|---|---|---|
| now | `(3,6)` | `[1,8]` | gates nothing |
| target | `(3,5)`¹ | `[2,6]` | still generous, blocks the extremes |

¹ **Unverified assumption** — depends on the real widening amplitude (Phase 0 check 2).
**The target is the resulting window `[2,6]`, not the literal tuple.** Pick the tuple that produces it.

With `[2,6]`, track pants (f≈1) fall out of the window and the reported bad outfit cannot compose.

**Mandatory constraint: ship behind a config flag** via ML config versioning (AlgorithmCockpit),
same pattern as `NEW_ITEM_BOOST_ENABLED`. Do NOT hard-code the change. Reason: the pool-starvation
risk below.

## Change 2 — make sure real occasions exist

Verify `OCCASION_FORMALITY` has real keys (`casual` / `work` / `date` / `sport` …). Add the missing
ones. **Constants table only — do not touch the pipeline.** This is the precondition for mobile to
send something meaningful later.

## Change 3 — trace

Add `occasion_resolved` + `formality_window` to the build trace (the trace object already exists —
it carries `min_distance`, `seen_signatures_count`, around `engine_v05.py:~306`). Required to
measure Phase 2.

## Change 4 — docs (mandatory)

- `API_DOCUMENTATION.md`: document the valid `occasion` vocabulary and the behavior when the value
  is unknown or absent. **Required by the two-repo contract rule.**
- The umbrella's `docs/system-architecture.md:194-300` describes the V05 pipeline **incorrectly**
  (claims Silhouette→Color→Layering→Footwear→Accessory; the real shape is L1 hard gates → L2
  compose → L5 novelty → L6 rank). Different repo — file a follow-up ticket, don't leave it wrong.

# The trap — do not "fix" this on mobile alone

```
occasion = None  →  still falls back to 'unknown'  →  still [1,8]  →  bug unchanged
```

The fix lives in the **backend default**. Backend ships first: old app builds still send `'safe'`,
still resolve to `unknown` — but `unknown` is now narrow, so they're protected immediately without
waiting on an app release. Mobile cleanup follows as Phase 3.

# Rejected approaches (do not re-propose)

| Approach | Why rejected |
|---|---|
| Add `safe`/`power`/`creative` to `OCCASION_FORMALITY` | Legitimises conflating mood with occasion. Mood already has its own path (`intent.mood`). Permanently occupies the `occasion` field so a real occasion can never ship. |
| Mobile-only fix | Insufficient — `None` still resolves to `unknown` → `[1,8]`. Also leaves old clients unprotected. |
| Drop the fallback, require `occasion` | Breaking wire change. Violates the repo's additive-contract principle. |

# 🔴 Primary risk — narrowing the window can starve the pool

This is the reason the flag and the eval gate are mandatory, not optional.

The pool is **already** thin (real production numbers, 2026-06):

| | |
|---|---|
| Items with `warmth_level=0` or unset | 96/356 (**27%**) |
| TOP/BOTTOM/OUTER anchors excluded at every temperature | **25.9%** |
| Users with 0 surviving TOP in the HOT bucket | **4/7 (57%)** |

And a prior fix ("Formality cliff", V05 Phase 0 Task 1.1) had to **widen** formality precisely
because the gate was too tight: 49 TOPs collapsed to 8 passing L2.

**Tightening formality now can recreate the exact bug that fix repaired.**

Mitigation — all four steps required:
1. Capture a `/v05-eval --hybrid` baseline **before** enabling the flag.
2. Enable for a small cohort first.
3. Gate: `v05_pool_insufficient_rate` must **not increase**. If it does → roll the flag back, widen
   one notch, re-measure.
4. If `[2,6]` starves the pool: consider a **soft penalty** (score multiplier, same pattern as the
   existing `COMMON_INJECTED_PENALTY = 0.9`) instead of a hard gate.

# Tests required

- unknown occasion → new window
- valid occasion → correct window
- absent occasion → new window
- **regression: an outfit with formality spread > 4 cannot compose**
- **flag OFF reproduces current behavior exactly**

# Verification gates

- `pytest` green
- `python test_server.py` green
- `API_DOCUMENTATION.md` updated (mandatory — route/contract behavior changed)

# Definition of done (Phase 1)

- Unknown/absent occasion no longer yields `[1,8]`
- The outfit "linen shirt + track pants + leather loafers" (spread ≈4) cannot compose in the new window
- No breaking wire change; old clients degrade safely
- Everything behind the config flag, default OFF

Phase 2 (eval gate) and Phase 3 (mobile cleanup) are separate dispatches. **Do not do them here.**

# Report back

End with: `**Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`, a 1-2 sentence summary,
and any blockers. If Phase 0 check 1 says the bug is already fixed, report `BLOCKED — already fixed`
and change nothing.

---

## Open questions (carry into the session, answer with real data)

1. Final `unknown` window value — `[2,6]` is a proposal, not settled. Depends on Phase 0 check 2 + Phase 2 numbers.
2. Is the ±widening applied to every occasion or only `unknown`?
3. Hard gate or soft penalty if the window starves the pool? Decide from Phase 2 data.
4. Does Home need a real occasion picker, or is `intent.mood` enough? → CEO, out of scope this round.
