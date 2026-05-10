# V05 Launch Plan — Ship "Lắc lại" feature

**Created**: 2026-05-08
**Owner**: PM (Duc)
**Goal**: Ship V05 recommendation + lắc lại UX to end users
**Strategy**: Option B — AU-251 trong Cycle 10, AU-250 đầu Cycle 11. V05 flag KHÔNG flip cho user đến khi cả 2 done.

---

## Critical path

```
TODAY (5/8) ────► 5/9 ──► 5/10 ──► 5/11 ──► 5/12 ──► 5/13 ──► 5/14 ──► 5/15 LAUNCH
                                  │
                                  ├──► [AU-251 BE]  5pt · backend-dev
                                  │     /next + Redis session + 4-axis + anchor-pin
                                  │
                                  └──► [AU-250 ME]  8pt · mobile-dev (blocked by AU-251)
                                        Wire V05 + lắc lại UX + daily reset
```

## Timeline

| Day | AU-251 (BE) | AU-250 (ME) | Other |
|---|---|---|---|
| **5/8 today** | Start: scaffold `engine_v05_variation.py`, `recommendation_session_v05.py`, Redis schema | (blocked) | Tech-lead review V05 session contract design (sync, ~30min). Ping Viet for design assets. |
| **5/9** | Implement 4 axis handlers (port V2). Anchor-pin + single-layer swap invariant tests. | (blocked) | Viet ships design assets (button, axis hints, copy). |
| **5/10** (cycle 10 end) | PR open, tech-lead review. Merge if green. | Branch from main, scaffold V05 service layer. | Cycle 10 retro. |
| **5/11** (cycle 11 start) | (done) | Replace `valenGetRecommendation` → V05 `buildRecommendation`. Add `/next` call. | |
| **5/12** | (done) | Pull-to-refresh + "Lắc lại" button. Axis hint UI (`trace.variation_axis` → label). | |
| **5/13** | (done) | Daily reset (AppState listener, useFocusEffect). Local memory persistence. Edit Context wire. | |
| **5/14** | (done) | Maestro flows + Jest. QA pass. | qa-mobile runs full regression. |
| **5/15** | (done) | Polish + bugfixes from QA. | **Flip V05 feature flag → user-facing launch.** |

## Dependencies

| Dependency | Status | Owner | Risk |
|---|---|---|---|
| PR #42 merged (V05 engine MVP AU-246/247) | ✅ Done 5/8 02:07 | — | — |
| AU-244 V05 Phase 0 PR #41 merged | ⏳ In Review | backend-dev | Medium — needed for SYSTEM items in DB |
| AU-245 V05 Phase 1 Onboarding API | 🔄 In Progress | backend-dev | Low — only blocks NEW users; existing users can test V05 |
| Tech-lead V05 session contract review | ⏳ Today | tech-lead | High — blocks AU-251 start |
| Viet design assets cho AU-250 | ⏳ Today-tomorrow | vietdesign81 | Medium — can MVP UI first, polish later |
| AU-72 Location/Weather | 🔄 In Progress | mobile-dev | Low — fallback to default temp if not ready |

## Decision points

1. **Today**: Tech-lead approve V05 `/next` contract design (Redis schema, 4-axis state machine)
2. **Today**: Viet confirm design direction cho lắc lại UX (button placement, axis hint copy)
3. **5/9**: Backend descope decision — nếu AU-251 slip, drop NEW_ANCHOR axis (ship 3-axis cycle, full regen later)
4. **5/12**: Mobile descope decision — nếu AU-250 slip, ship lắc lại + V05 wire trước, daily reset + Edit Context Phase 5

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| AU-251 BE > 2 days (V2 patterns complex) | M | H | Timebox; descope NEW_ANCHOR axis nếu kẹt day 2 |
| Mobile V05 integration breaks legacy Home | M | H | Feature flag V05 path; fallback to `/recommendation/start` if V05 fails |
| Viet design late → ship UI without copy | L | M | Ship placeholder copy "Lắc lại" + generic axis hints; Viet polish post-launch |
| Tech-lead review delay | L | H | Pre-impl sync sáng nay 5/8 (30min) |
| QA finds regression | M | M | Maestro flows trong AU-250 AC; smoke V2 path vẫn work |
| AU-245 onboarding chưa xong khi V05 launch | M | L | Limit V05 launch to existing users first; new-user flow lands sau |

## Cycle 10 → 11 transition

**Cycle 10 closes 5/10**:
- AU-244 ✅ → Done sau merge PR #41
- AU-245 → có thể slip Cycle 11 (still acceptable, không block launch)
- AU-246 ✅ Done
- AU-247 → trạng thái?
- AU-251 (new) → ship Cycle 10
- AU-242 UAC Auth → keep Cycle 10
- AU-72 Location/Weather → keep Cycle 10 (small)

**Cycle 11 opens 5/11**:
- AU-250 → main focus đầu cycle
- AU-245 carry-over nếu slip
- Bug fixes + polish from V05 launch
- File new tickets từ launch feedback

## Communication plan

- **Today 5/8**: Comment on AU-243 (done above) — heads-up Viet + tech-lead
- **5/9 EOD**: Status update on AU-251 progress
- **5/10**: Cycle 10 retro — what shipped, what slipped
- **5/14**: Pre-launch checklist verify
- **5/15**: Launch announcement — internal Slack

## Definition of "V05 launch"

V05 considered launched khi:
- ✅ PR #42 merged (engine MVP)
- ⏳ AU-251 merged (axis cycling endpoint)
- ⏳ AU-250 merged (mobile wired + lắc lại UX)
- ⏳ Maestro E2E green
- ⏳ Existing user smoke test pass (1-2 internal users)
- ⏳ Feature flag flipped on prod
- ⏳ Mixpanel event "v05_recommendation_shown" firing
