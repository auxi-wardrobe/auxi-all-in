# Remix — Feature Plan

**Feature codename**: Remix
**Created**: 2026-05-08
**Owner**: PM (Duc)
**Status**: Planning → Cycle 10 (BE) / Cycle 11 (ME)
**Linear**: parent AU-243 · BE AU-251 · ME AU-250

---

## 1. Vision

Remix is V05's "give me another outfit" feature — but **never random**. Each tap shifts ONE dimension (top, layer, color, or full anchor) while keeping the rest of the outfit's vibe intact.

**Brand promise**: "Same vibe, fresh take."

**Why this matters**: Random rerolls = jarring (minimal-casual → preppy formal feels broken). Remix preserves user's selected style direction while exploring the wardrobe.

---

## 2. User flows

### 2.1 Primary flow — single Remix tap

```
[Home: outfit A shown] ──tap "Remix"──► [Toast: "Đang đổi…" 200ms]
                                          ↓
                                        BE call: POST /api/v05/recommendation/next
                                          ↓
                                        [Home: outfit B shown · axis chip "New top"]
```

### 2.2 Multi-Remix progression (4-axis cycle)

```
Outfit A ── Remix tap 1 ──► Outfit B (top swapped, vibe kept)        chip: "New top"
         ── Remix tap 2 ──► Outfit C (layer swapped, vibe kept)      chip: "New layer"
         ── Remix tap 3 ──► Outfit D (color swapped, vibe kept)      chip: "New color"
         ── Remix tap 4 ──► Outfit E (full reset with new anchor)    chip: "Full remix"
         ── Remix tap 5 ──► cycle restarts at SILHOUETTE
```

### 2.3 Forced axis (UX shortcut)

```
[User long-presses Remix button]
        ↓
[Sheet: "Remix what?"]
  ┌─────────────────┐
  │ • Top           │  → forces SILHOUETTE
  │ • Layer         │  → forces LAYERING
  │ • Color         │  → forces COLOR
  │ • Full remix    │  → forces NEW_ANCHOR
  └─────────────────┘
```

### 2.4 Daily reset

```
App foregrounded after midnight ──► Discard session_id
                                    ↓
                                  Call /start fresh
                                    ↓
                                  Header: "Today's outfit"
```

### 2.5 Edge cases

| Case | Behavior |
|---|---|
| Network fail mid-Remix | Keep current outfit, toast "Couldn't remix — try again" |
| Wardrobe < 5 items per layer | Disable Remix button, show empty state "Add more items to enable Remix" |
| Same axis exhausts pool (e.g., only 1 top) | Skip that stage, go to next axis automatically |
| User Remix 10+ times in row | OK — backend handles, no rate limit user-side |
| Session expires (Redis 30min) | Silent re-`/start`, continue from outfit shown |
| User pulls-to-refresh | Same as Remix tap (auto-cycle) |

---

## 3. Technical architecture

### 3.1 Backend (AU-251) — 5pt

**New endpoint**: `POST /api/v05/recommendation/next`

```
Request:
{
  session_id: string
  current_outfit_hash: string
  rejected_items?: string[]
  preferred_colors?: string[]
  style_feedback?: string
  force_variation_axis?: "SILHOUETTE" | "LAYERING" | "COLOR" | "NEW_ANCHOR"
}

Response: same shape as /build, plus trace.variation_axis
```

**Redis session**: `v05_recsess:{uuid}` TTL 1800s, fields:
- `current_outfit`, `variation_stage` (1-4), `seen_item_ids`, `anchor_id` (BT), `style_signals`

**4 axis handlers** (port V2 patterns):
- L1 SILHOUETTE: swap L2, keep BT/SH/L3
- L2 LAYERING: swap L3 (cold) or SH (warm)
- L3 COLOR: swap L2 different color
- L4 NEW_ANCHOR: full regen

**Invariants**:
- Stages 1-3: exactly 1 layer changed vs `current_outfit` (hard-fail if violated)
- Anchor pin: BT frozen stages 1-3
- Pre-filtered candidates (formality±3, weight±2, color-temp, fit-contrast)

### 3.2 Mobile (AU-250) — 8pt

**Replace**: `valenGetRecommendation` (legacy `/start|next`) → V05 `buildRecommendation` (`/start`) + new `remixOutfit` (`/next`)

**New files**:
- `auxi/src/utils/recommendationMemory.ts` — session_id + signature ring buffer persist
- `auxi/src/hooks/useRemix.ts` — Remix mutation + axis hint state
- `auxi/src/hooks/useTodayOutfit.ts` — date-aware refetch
- `auxi/src/components/RemixButton.tsx` — primary CTA component
- `auxi/src/components/AxisChip.tsx` — hint label

**HomeScreen changes** (`HomeScreen.tsx`):
- Replace `valenGetRecommendation` mount call → V05 `/start`
- Add `RefreshControl` (pull-to-refresh = Remix tap)
- Add `RemixButton` floating action OR header trailing
- Add long-press → sheet for forced axis
- Mode/pin change → Remix tap (auto-cycle)
- Edit Context submit → Remix tap with `style_feedback`

### 3.3 Data flow

```
Mobile                                    Backend                Redis
─────                                    ──────                ──────
[Home mount]
  └─ /start ────────────────────────────► engine_v05.build()
                                            ├─ pick BT anchor
                                            ├─ pre-filter pool
                                            └─ create session ───► SET v05_recsess:{uuid}
                                            ◄─ outfit + session_id

[User taps Remix]
  └─ /next {session_id, current_hash} ──► session.next()
                                            ├─ GET v05_recsess:{uuid}
                                            ├─ stage++ (cycle 1→2→3→4→1)
                                            ├─ axis-handler(stage)
                                            └─ SET v05_recsess:{uuid} ←
                                            ◄─ outfit + variation_axis

[Daily midnight foreground]
  └─ /start (new session) ──────────────► engine_v05.build()
                                            └─ DEL old session, SET new
```

---

## 4. UX spec

### 4.1 Button states

| State | Appearance | Disabled? |
|---|---|---|
| Default | "Remix" + cyclone icon | No |
| Loading (200-800ms) | Spinner | Yes (debounce) |
| Cooldown after Full remix | "Remixing..." 1.5s | Yes |
| Wardrobe too small | Greyed out + tooltip | Yes |
| Network error | Default + toast on tap | No |

### 4.2 Axis hint chip

Appears next to outfit title, fades after 3s, optional tap to expand:

| Stage | Chip text | Color |
|---|---|---|
| SILHOUETTE | "New top" | neutral |
| LAYERING | "New layer" | neutral |
| COLOR | "New color" | accent |
| NEW_ANCHOR | "Full remix" | bold |

### 4.3 Animation

- Outfit swap: 250ms cross-fade (no slide, jarring)
- Chip enter: slide-up + fade (200ms)
- Remix button press: 100ms scale-down haptic

### 4.4 First-time tooltip (1 time only)

> "Tap Remix to swap part of your outfit. Long-press to choose what to change."

### 4.5 Marketing copy (launch announcement)

> Introducing **Remix** — get a different outfit without losing your vibe. Each tap shifts one dimension (top, layer, color, or anchor) while keeping the rest of the look intact.

---

## 5. Telemetry

Events to fire (Mixpanel):

| Event | Properties |
|---|---|
| `remix_button_shown` | session_id, outfit_hash |
| `remix_tapped` | session_id, current_outfit_hash, force_axis (null if auto) |
| `remix_completed` | session_id, variation_axis, latency_ms |
| `remix_failed` | session_id, error_code |
| `remix_axis_picker_opened` | session_id |
| `remix_axis_picker_selected` | session_id, axis |
| `daily_reset_triggered` | session_id_old, session_id_new |
| `pull_to_refresh_remix` | session_id |

Dashboards:
- Remix taps per active user per day (target: 3-7)
- Distribution across 4 axes (should be ~uniform if auto-cycle works)
- p95 latency `/next` (target < 250ms)
- Remix → save outfit conversion rate

---

## 6. Phasing & timeline

| Phase | Scope | Tickets | Days |
|---|---|---|---|
| **Phase 4a — BE** | `/next` endpoint + Redis session + 4-axis cycle + invariants + tests | AU-251 | 5/8-5/10 |
| **Phase 4b — ME MVP** | Replace legacy → V05 `/start` + `/next`. Remix button (auto-cycle only). Pull-to-refresh. Daily reset. | AU-250 | 5/11-5/13 |
| **Phase 4c — ME polish** | Long-press axis picker. Axis hint chip animation. First-time tooltip. Edit Context wire. | AU-250 | 5/13-5/14 |
| **Phase 4d — QA & launch** | Maestro flows. Internal smoke. Flag flip. | AU-250 + ops | 5/14-5/15 |

**Launch date**: 2026-05-15

---

## 7. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| BE complexity > 5pt (V2 port) | M | H | Descope NEW_ANCHOR axis if stuck day 2; ship 3-axis MVP |
| Mobile single-layer swap UX feels weird (user confused why only top changed) | M | M | Axis chip hint solves this; first-time tooltip explains |
| Long-press axis picker discoverability low | H | L | Auto-cycle works without it; picker is power-user feature |
| Daily reset surprises user mid-day if device timezone wrong | L | M | Use device local time, not server UTC |
| Wardrobe too small to support 4 axes | M | M | Skip exhausted axes silently, advance to next |
| Mode/Pin change conflicts with Remix cycle | M | M | Mode change → force `/start` not `/next` (reset session) |

---

## 8. Success metrics

**Launch criteria** (must hit):
- Maestro E2E green (Remix tap × 4 → 4 distinct outfits with correct axis)
- p95 `/next` latency < 250ms
- 0 single-layer-swap invariant violations in QA logs
- Internal smoke test: 2 testers complete 10+ Remixes each without confusion

**4-week post-launch metrics**:
- Daily active users tap Remix ≥ 3× per session (median)
- Axis distribution uniform (no single axis > 40% of taps)
- Remix → "save outfit" conversion ≥ 15%
- Crash rate from Remix path < 0.1%
- User feedback: "outfit feels jarring after Remix" mentions < 5%

---

## 9. Open questions / decisions needed

| # | Question | Owner | Deadline |
|---|---|---|---|
| 1 | Tech-lead approve V05 `/next` contract design | tech-lead | 5/8 |
| 2 | Viet design assets: button visual + axis chip + tooltip copy | vietdesign81 | 5/9 |
| 3 | Long-press picker: in MVP or polish phase? | PM | 5/9 |
| 4 | Pull-to-refresh = Remix tap, or = `/start` reset? (recommend: Remix tap) | PM | 5/8 |
| 5 | Remix cooldown after Full remix? (recommend: 1.5s) | PM | 5/9 |
| 6 | Telemetry events approved by data team? | data-team | 5/12 |

---

## 10. Decision log

| Date | Decision | By |
|---|---|---|
| 2026-05-08 | Feature codename: **Remix** (English-only, no Vietnamese alias) | Anh Duc (user) |
| 2026-05-08 | 4-axis cycle: SILHOUETTE → LAYERING → COLOR → NEW_ANCHOR (port from V2) | PM |
| 2026-05-08 | Anchor pin: BT (bottom) frozen across stages 1-3 | PM |
| 2026-05-08 | Single-layer swap invariant: hard-fail if >1 layer changed | PM |
| 2026-05-08 | Strategy: Option B — AU-251 in Cycle 10, AU-250 early Cycle 11. V05 flag stays off until both done. | PM |
| 2026-05-08 | Launch target: 2026-05-15 | PM |

---

## Appendix: codebase references

V2 source patterns:
- `wardrobe-backend/utils/recommendation_session.py:120-333` — RecommendationSession.next()
- `wardrobe-backend/utils/recommendation_session.py:185-209` — 4 stage handlers
- `wardrobe-backend/blueprints/recommendation/engine_v2.py:486` — _pre_filter_for_anchor
- `wardrobe-backend/blueprints/recommendation/engine_v2.py:1207, 1334-1338` — single-layer swap invariant + LLM prompt
- `wardrobe-backend/routers/recommendation.py:350` — POST /api/recommendation/next

V05 destinations:
- `wardrobe-backend/blueprints/recommendation/engine_v05.py` — add next() entry
- New: `wardrobe-backend/blueprints/recommendation/engine_v05_variation.py`
- New: `wardrobe-backend/utils/recommendation_session_v05.py`
- `wardrobe-backend/routers/v05_recommendation.py` — add /next
- `wardrobe-backend/blueprints/recommendation/engine_v05_layers.py` — _pre_filter_for_anchor_v05

Mobile destinations:
- `auxi/src/screens/HomeScreen.tsx` — wire V05 + Remix
- `auxi/src/services/v05Api.ts` — consumer
- New: `auxi/src/utils/recommendationMemory.ts`
- New: `auxi/src/hooks/useRemix.ts`
- New: `auxi/src/hooks/useTodayOutfit.ts`
- New: `auxi/src/components/RemixButton.tsx`
- New: `auxi/src/components/AxisChip.tsx`
