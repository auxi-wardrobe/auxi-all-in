-- V05 PoolInsufficient / WardrobeGap analytics queries
-- Used by /v05-eval --logs mode
-- Table: v05_pool_insufficient_events (created by migration 02248e7676e0)

-- ═══════════════════════════════════════════════════════════════════════════
-- Q1 — Top failure reasons last N days
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  failure_reason,
  COUNT(*) AS cnt,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days'
GROUP BY failure_reason
ORDER BY cnt DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q2 — Climate × gender × starved-family heatmap
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  climate_bucket,
  gender,
  jsonb_array_elements_text(event_json -> 'common_injection' -> 'starved_families') AS starved_family,
  COUNT(*) AS cnt
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days'
GROUP BY climate_bucket, gender, starved_family
ORDER BY cnt DESC
LIMIT 30;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q3 — Per-user repeat failures (who is most affected)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  user_id,
  COUNT(*) AS fail_count,
  COUNT(DISTINCT failure_reason) AS distinct_reasons,
  MIN(created_at) AS first_fail,
  MAX(created_at) AS last_fail
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days'
GROUP BY user_id
HAVING COUNT(*) >= 3
ORDER BY fail_count DESC
LIMIT 20;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q4 — Failures with common-injection attempted vs not
-- (Did injection help? Compare injection-attempted gap rate to non-attempted)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  exception_class,
  (event_json -> 'common_injection' ->> 'attempted')::boolean AS injection_attempted,
  COUNT(*) AS cnt
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days'
GROUP BY exception_class, injection_attempted
ORDER BY cnt DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q5 — Climate-vs-wardrobe gap distribution
-- (At which temp_c does this user fail most? Density per bucket)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  climate_bucket,
  ROUND((event_json -> 'inputs' ->> 'temp_c')::numeric, 0) AS temp_round,
  COUNT(*) AS cnt
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days'
GROUP BY climate_bucket, temp_round
ORDER BY temp_round;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q6 — Layer where raise fired
-- (Which pipeline stage is the bottleneck?)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  event_json -> 'failure' ->> 'raised_at_layer' AS layer,
  failure_reason,
  COUNT(*) AS cnt
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days'
GROUP BY layer, failure_reason
ORDER BY cnt DESC
LIMIT 20;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q7 — Skipped-summary aggregate (top skip reasons across all failures)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  skip_reason,
  SUM((skip_count)::int) AS total_skipped
FROM v05_pool_insufficient_events,
     jsonb_each_text(event_json -> 'skipped_summary') AS s(skip_reason, skip_count)
WHERE created_at > NOW() - INTERVAL ':days days'
GROUP BY skip_reason
ORDER BY total_skipped DESC
LIMIT 20;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q8 — Recent N events (full payload for hypothesis-driven inspection)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  created_at,
  user_id,
  climate_bucket,
  failure_reason,
  event_json -> 'inputs' AS inputs,
  event_json -> 'wardrobe' -> 'per_family_warmth' AS warmth_profile
FROM v05_pool_insufficient_events
ORDER BY created_at DESC
LIMIT 20;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q9 — Distance-floor recompose failures (TA distance-filter exhaustion)
-- (Since 260611 `inputs` carries min_distance + seen_signatures_count instead
--  of force_axis. Did the engine recover, and at which floor?)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  event_json -> 'inputs' ->> 'min_distance' AS distance_floor,
  (event_json -> 'inputs' ->> 'seen_signatures_count')::int AS seen_count,
  failure_reason,
  COUNT(*) AS cnt
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days'
  AND event_json -> 'inputs' ->> 'min_distance' IS NOT NULL
GROUP BY distance_floor, seen_count, failure_reason
ORDER BY cnt DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- Q10 — Cluster summary (one-row digest for report header)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_id) AS unique_users,
  COUNT(DISTINCT failure_reason) AS distinct_reasons,
  COUNT(*) FILTER (WHERE exception_class = 'WardrobeGapError') AS wardrobe_gap_cnt,
  COUNT(*) FILTER (WHERE exception_class = 'PoolInsufficientError') AS pool_insufficient_cnt,
  MIN(created_at) AS oldest_event,
  MAX(created_at) AS newest_event
FROM v05_pool_insufficient_events
WHERE created_at > NOW() - INTERVAL ':days days';
