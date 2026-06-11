# CRITICAL: local backend .env points at shared Railway prod Postgres

**Source**: AU-318 qa-mobile sim verification (2026-06-12)
**Severity**: Critical (ops/safety) — route to devops

## Finding

`wardrobe-backend/.env` `DATABASE_URL` = `switchback.proxy.rlwy.net:17805/railway` —
the same Postgres prod writes to. Proven during AU-318 QA: a favourite created via
the prod backend was immediately visible through localhost:5001.

Consequences observed:
- Local QA/dev traffic mutates prod data (QA deleted its own stray favourite).
- Any local `alembic upgrade` is a prod schema change — this blocked AU-318
  happy-path sim verification (migration `au318a1b2c3d` correctly left unapplied).

## Ask

- devops: provision a local/dev Postgres (or docker-compose) + split .env
  (dev vs prod), rotate the leaked prod credential if .env was ever shared.
- Until then: treat `alembic upgrade head` as a prod deploy step (devops-gated).

## Related

- AU-318 deploy step: apply `au318a1b2c3d_add_outfit_mood_signals` at release
  (single tracked-head parent `au242a1b2c3d`; in-flight feedback-system
  migrations re-parent on top when they land — tech-lead decision (d)).
- Also from same QA run (route to qa-ui): maestro `_shared/ensure-home.yaml` +
  `login.yaml` use stale `auth-email-input` selector (redesigned auth path is
  `welcome-cta-email` → `email-input-field`); `mood-feedback.yaml` Done-tap
  needs a settle/waitForAnimationToEnd after chip tap.
- wda-install.sh destination bug (route devops): use `id=<booted UDID>`.
