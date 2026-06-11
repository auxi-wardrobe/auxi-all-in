---
title: AU-318 Wear This Mood Feedback Experience
description: ''
status: completed
priority: P2
branch: main
tags: []
blockedBy: []
blocks: []
created: '2026-06-11T13:15:41.246Z'
createdBy: 'ck:plan'
source: skill
---

# AU-318 Wear This Mood Feedback Experience

## Overview

"Wear this" stops saving immediately. It opens a mood feedback bottom sheet so users
optionally tag how an accepted outfit emotionally resonated; outfit + mood signals save
atomically. Mood signals feed soft preference learning by writing existing
`V05UserStyleSignal` rows (mood→axis affinity map) that ride the existing engine L4
re-weight — zero engine changes. Prompt frequency reduces as confidence grows via a new
policy endpoint. Tone: a stylist quietly learning confidence patterns — not mood tracking.

## Context Links

- Ticket (authoritative AC): [linear-au318-ticket.md](./linear-au318-ticket.md) · [AU-318 on Linear](https://linear.app/duncan-1/issue/AU-318)
- Scout — auxi flow: `plans/reports/scout-260611-2004-au318-auxi-wear-this-flow.md`
- Scout — backend surface: `plans/reports/scout-260611-2004-au318-backend-outfit-feedback-surface.md`

## Key Decisions

- Contract: extend `POST /api/favorites` with optional `mood_tags: string[]`, upsert-by-`outfit_hash` (existing favorite → update mood linkage, return `updated: true`).
- Persistence: new model `OutfitMoodSignal` (`outfit_mood_signals`) + Alembic migration; new `MoodFeedbackService` + repository (service-repo pattern). Favorites router touched minimally (service call only).
- Bounded mood vocab (shared client/server), max 8 chips/context; soft-negative `not_quite_me`.
- Learning v1: static mood→axis affinity map → write `V05UserStyleSignal` rows (`source='mood_feedback'`); rides existing L4 re-weight (`engine_v05.py:354-376, 708-741`), clamp `[0.5,1.5]` already mitigates diversity-collapse risk. ZERO engine changes.
- Prompt policy v1: `GET /api/v05/mood-feedback/policy` → `{should_prompt, tier}` from signal count + recency thresholds. Client caches per session, refetches after submit.
- Mobile: new `MoodFeedbackSheet` cloning `ContextChipsModal` pattern; theme tokens only (no hex, lint-tokens gate); i18n en/vi/fr.
- No Figma exists. Build per ticket spec + theme tokens. PR template Figma fields → N/A + this justification.

## Dependencies

- P1 → P2 (policy + learning read the mood table) and P1 → P4 (wiring needs the extended contract).
- P3 is independent of P1/P2 (UI shell + chips) — can run in parallel.
- P5 is last (verifies the full cross-repo contract).

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Backend Contract & Mood Persistence](./phase-01-backend-contract-mood-persistence.md) | Completed |
| 2 | [Backend Learning & Prompt Policy](./phase-02-backend-learning-prompt-policy.md) | Completed |
| 3 | [Mobile Mood Feedback Sheet UI](./phase-03-mobile-mood-feedback-sheet-ui.md) | Completed |
| 4 | [Mobile Wear-This Flow Wiring & Analytics](./phase-04-mobile-wear-this-flow-wiring-analytics.md) | Completed |
| 5 | [QA Contract Verify & Ship](./phase-05-qa-contract-verify-ship.md) | Completed |
