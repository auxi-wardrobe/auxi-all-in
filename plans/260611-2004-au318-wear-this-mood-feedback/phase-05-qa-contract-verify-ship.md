---
phase: 5
title: QA Contract Verify & Ship
status: completed
priority: P2
effort: 1d
dependencies:
  - 1
  - 2
  - 3
  - 4
---

# Phase 5: QA Contract Verify & Ship

## Overview

Cross-repo verification gates from umbrella `CLAUDE.md`, QA delegation (qa-ui spec review, qa-mobile
Maestro smoke), analytics verification, and shipping: two PRs (auxi + wardrobe-backend) + umbrella
submodule bump. The real-HTTP smoke is mandatory — contract drift between mocked backend and shipped
mobile is exactly what this umbrella repo exists to prevent.

## Requirements

Functional:
- All ticket scenarios pass end-to-end on iOS sim against the real local backend.
- Maestro flow covering the mood sheet happy path + dismiss path, testID-driven.
- qa-ui review vs ticket spec (NOT Figma — no frame exists; decision documented in PRs).
- All 9 analytics events verified once each.

Non-functional:
- Zero engine file diffs (`git diff --stat blueprints/recommendation/` clean).
- Lint/type/token gates clean in auxi; pytest + e2e green in backend.
- API_DOCUMENTATION.md matches shipped contract; tech-lead sign-off recorded on the backend PR.

## Architecture

Verification stack (umbrella CLAUDE.md gates):
```
1. Backend:  cd wardrobe-backend && pytest tests/test_mood_* && python test_server.py   (e2e :5002)
2. Mobile:   cd auxi && npx tsc --noEmit && yarn lint && cd .. && ./scripts/auxi-lint-tokens.sh
3. Smoke:    backend on :5001 + sim app, REAL HTTP (no mocks)
4. QA:       qa-ui (spec compare) → qa-mobile (Maestro + exploratory)
5. Ship:     PR auxi + PR wardrobe-backend → merge → umbrella submodule bump
```

## Related Code Files

Create:
- `auxi/maestro/flows/home/mood-feedback.yaml` — Maestro flow (testIDs from Phase 3/4)

Modify:
- none (verification + PR phase; fixes loop back into Phases 1–4 files)

Delete: none.

## Implementation Steps

1. **Backend gates.** `cd wardrobe-backend && pytest tests/test_mood_feedback_service.py tests/test_mood_affinity.py tests/test_mood_feedback_policy.py && python test_server.py` — all green. `alembic upgrade head` on a fresh DB copy verified.
2. **Mobile gates.** `cd auxi && npx tsc --noEmit && yarn lint` (baseline: only the 4 legacy `_HomeScreen.tsx` errors) and `./scripts/auxi-lint-tokens.sh` clean.
3. **Real-HTTP smoke.** Boot backend :5001 (`uvicorn app:app --reload --port 5001`), run sim (`yarn ios:sim`). Walk every ticket scenario: primary flow, multi-select, deselect, dismiss + re-tap, dedup (already-saved → "Mood updated for this saved look."), error (backend killed), timeout, rapid taps. Seed 15+ mood signals via psql to verify `occasional` tier → direct-save branch.
4. **Maestro flow.** Author `mood-feedback.yaml`: launch → navigate to outfit → tap `home-this-works-*` → assert `mood-feedback-sheet` visible → tap `mood-chip-confident` → assert `mood-feedback-done` enabled → tap Done → assert `mood-feedback-banner` → relaunch dismiss path (open → backdrop tap → assert sheet gone). Run: `maestro test maestro/flows/home/mood-feedback.yaml`.
5. **qa-ui dispatch.** Spec-based review (no Figma): copy strings verbatim vs ticket, chip styling vs theme tokens, ≤8 chips, animation parity with house modals, overflow on small devices (SE-class). Findings loop back to Phase 3.
6. **qa-mobile dispatch.** Exploratory smoke on sim incl. crash check (`get_crash`), VoiceOver labels present, state restore after background/foreground while sheet open.
7. **Analytics verify.** Dev-mode Mixpanel flush: confirm each of the 9 events fires exactly once per its trigger; `negative_mood_selected` only when `not_quite_me` selected.
8. **Docs + sign-off.** Final API_DOCUMENTATION.md review (favorites + policy endpoint sections); tech-lead contract sign-off comment on backend PR.
9. **PRs.** Branch per repo (`feat/au318-mood-feedback`): backend PR first (contract), then auxi PR. PR template: Figma URL/extraction/qa-ui-extraction fields → N/A with "no Figma frame exists for AU-318; built per ticket spec" justification; attach lint-tokens output, sim screenshots, Maestro run, qa verify IDs. After merges: umbrella `git add auxi wardrobe-backend && git commit -m "chore: bump submodules for AU-318 mood feedback"`. Link PRs on AU-318, move ticket to In Review/Done per linear-pm-workflow.

## Success Criteria

- [x] All commands in steps 1–2 exit 0.
- [x] Every ticket scenario (primary, secondary, error, edge) demonstrated against real backend — checklist in PR description.
- [ ] Maestro `mood-feedback.yaml` passes locally. — authored; run blocked by stale shared auth selectors + Done-tap settle — qa-ui follow-ups filed
- [x] qa-ui + qa-mobile reports filed with no open blockers.
- [ ] 9/9 analytics events verified. — wired in hook, runtime flush unobservable in RN 0.83 Metro — code-level verified
- [x] `git diff --stat blueprints/recommendation/` shows zero changes (learning rides existing L4).
- [ ] Both PRs merged with template checklists green; umbrella submodule bump committed; AU-318 updated with PR links. — PRs CREATED: auxi-backend#91, auxi-mobile#62 (stacked on #60) — merge is human-gated; umbrella submodule bump after merge

## Risk Assessment

- **Contract drift** (umbrella #1 concern). Mitigation: backend PR merges first; mobile smoke runs against the merged contract; API doc is the contract artifact tech-lead signs.
- **Maestro flakiness on modal animations.** Mitigation: testID-driven waits (`assertVisible` with timeout), no coordinate taps.
- **Policy-gated branch untestable without data.** Mitigation: psql seeding script documented in step 3 (dev DB only).
- **Two-repo PR sequencing.** Mitigation: backend first, auxi second, umbrella bump last; never ship auxi against unmerged backend contract.
