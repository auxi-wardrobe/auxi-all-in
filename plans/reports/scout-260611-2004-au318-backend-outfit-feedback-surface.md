# Scout: wardrobe-backend outfit save + feedback/learning surface (AU-318)

## Favorites (what "Wear this" hits today)
- `routers/favorites.py:61-146` — `POST /api/favorites`, req `AddFavoriteRequest` (outfit_items, item_ids, outfit_hash, source, outfit_context, outfit_thumbnail_url), auth get_current_user. NO service/repo layer — direct SQLAlchemy in router. Also GET list/single + DELETE (149-260)
- `models/favorite.py` — `favorites` table: id UUID, user_id FK, outfit_context JSON (occasion/weather/styling_note/outfit_hash/source), thumbnail, timestamps. M2M `favorite_items` junction → wardrobe_items
- API_DOCUMENTATION.md:1113-1225 documents favorites endpoints

## Existing feedback/learning tables
1. `models/recommendation_feedback.py` — `recommendation_feedback`: like/dislike + `reason_chips` JSON (bounded vocab) + free_text + context_snapshot. Endpoint `POST /api/v05/recommendations/feedback` (routers/recommendation_feedback.py:36-84), 20/min, V05FeedbackService
2. `models/v05_outcome_event.py` — `v05_outcome_events`: build/pick/wear/abandon, session_id, event_metadata JSON. Endpoints `POST /api/v05/event/{pick,wear,abandon}` (routers/v05_outcome.py), 204, 60/min, fire-and-forget never-raise
3. `models/v05_user_style_signal.py` — `v05_user_style_signals`: axis_dislikes/axis_likes JSON, occasion_fit, would_wear_again, confidence (0-1), source (feedback_prompt/voluntary), `decay_at` (30-day, NULL=never). Written by LLM-2 from post-wear feedback via `POST /api/v05/feedback` (routers/v05_feedback.py:51-142), min confidence 0.3

## Engine learning (V05 L4) — KEY REUSE TARGET
- `blueprints/recommendation/engine_v05.py:354-376` — loads active (non-decayed) V05UserStyleSignal rows → signal vector {axis: multiplier}: dislike 0.7, like 1.3, conflict 1.0
- L4 re-weight at engine_v05.py:708-741 — `apply_signal_reweight()` per candidate, clamped [0.5, 1.5]
- Axes: rubber_slides, loose_silhouette, tight_silhouette, dark_palette, bright_palette, heavy_layering (engine_v05_layers.py:942-949; helpers 827-863, 969-1019)
- → Mood learning can ride this pipeline: write V05UserStyleSignal rows (source='mood_feedback') derived from mood→axis affinity map; ZERO engine changes needed for v1 of learning

## Migrations
- Alembic, `migrations/versions/`. Recent example: `appfb1a2b3c4d_add_app_feedback.py` (May 29); structure example `b7e3f4a8c9d2_add_v05_outcome_events.py`

## Conventions (wardrobe-backend/CLAUDE.md)
- Service-repository pattern: router → service → repository, ORM only no raw SQL (NB: favorites router violates this today — direct DB)
- `Depends(get_current_user)` on all protected routes; rate limit via SimpleRateLimiter per endpoint (writes ~20/min)
- Errors: `{"error", "request_id"}`, no stack traces; tokens never logged
- API_DOCUMENTATION.md update MANDATORY on contract change; tech-lead signs off

## Gaps for AU-318
- No mood tag persistence; no per-save mood linkage to favorites
- No prompt-frequency/maturity surface (client has no way to ask "should I prompt?")
- Favorites POST has no upsert semantics for outfit_hash dedup ("already saved → update mood only" needs it)
