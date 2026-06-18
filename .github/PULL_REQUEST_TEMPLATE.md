<!-- Wardrobe umbrella PR template. Submodules (auxi/, wardrobe-backend/) may
     have their own templates — those take precedence inside the submodule PR. -->

## What changed

<!-- 1–3 sentences. Why this PR exists, what it does, who asked. -->

## Type

- [ ] feat — new user-facing feature
- [ ] fix — bug fix
- [ ] refactor — code change, no behavior change
- [ ] chore — submodule bump, config, infra, docs
- [ ] design — visual fidelity / token / spacing change (mobile UI)

## Linear ticket

`AU-` <!-- replace with ticket ID; "none" only for chore/infra -->

## Mobile UI changes (required if Type includes `feat` or `design` touching `auxi/src/screens/**` or `auxi/src/components/**`)

- [ ] **Figma URL with frame node-id:** <!-- https://figma.com/design/<fileKey>/?node-id=<nodeId> -->
- [ ] **Extraction artifact:** path to `plans/<plan>/figma-extraction-<screen>.md`
- [ ] **qa-ui review-extraction:** PASS / link to findings
- [ ] **No new hex literals or font-family strings** in `src/screens/**` / `src/components/**` (`./scripts/auxi-lint-tokens.sh` clean)
- [ ] **designer design-review:** PASS (step 6.5 hard gate) / link to `auxi/docs/design-reviews/<date>-<screen>.md`
- [ ] **Sim screenshot OR qa-mobile verify run ID** attached below

<!-- Drop screenshots / qa-mobile log excerpt here -->

## Backend / contract changes (required if touching `wardrobe-backend/routers/**`)

- [ ] `wardrobe-backend/API_DOCUMENTATION.md` updated
- [ ] `auxi/src/services/*.ts` client synced (or follow-up ticket filed)
- [ ] tech-lead signed off on contract change

## Verification

- [ ] `npx tsc --noEmit` (auxi) clean
- [ ] `yarn lint` (auxi) baseline preserved
- [ ] Backend tests pass (`python test_server.py`) — if backend touched
- [ ] Smoke tested against real local backend (no mocks)

## Notes for reviewer

<!-- Anything reviewer should know upfront. -->
