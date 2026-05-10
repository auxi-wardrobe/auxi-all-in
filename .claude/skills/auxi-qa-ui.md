---
name: auxi-qa-ui
description: Mobile QA flow authoring playbook for the Auxi RN app — author deterministic Maestro YAML flows with explicit UI state assertions targeting testID + accessibilityLabel. Use when writing or maintaining flows in auxi/maestro/flows/. Does NOT execute flows (use auxi-qa-test for that) and does NOT modify production code.
---

# Auxi Maestro Flow Authoring Playbook

Authoring rule #1: every assertion is a deterministic state check. No
screenshots, no OCR, no visual reasoning. If a requirement can't be
expressed as `assertVisible` / `assertNotVisible` / element state, it's
not in this QA model — push back to the user.

## File layout

```
auxi/maestro/
├── README.md                 # how to run, current flow inventory
├── config.yaml               # shared appId, default env, regression tags
└── flows/
    ├── _shared/              # sub-flows reused across features (login, etc.)
    │   ├── login.yaml
    │   └── reset-app-state.yaml
    ├── auth/
    │   ├── login.yaml
    │   └── register.yaml
    ├── onboarding/
    │   └── full.yaml
    ├── home/
    │   ├── swipe.yaml
    │   ├── modes.yaml
    │   ├── heart.yaml
    │   └── pin.yaml
    ├── wardrobe/
    ├── body/
    └── settings/
```

Naming: `<feature>/<verb-or-state>.yaml`. One flow = one journey, ~5-30
steps. If you exceed 50 steps, split.

## Selector hierarchy (use in this order)

1. **`id: <testID>`** — preferred. The screen author is on the hook to
   ship every interactive element with a `testID` (see
   `mobile-dev.md` testability rule).
2. **`id: <accessibilityLabel>`** — second choice for icon-only buttons.
   Maestro on iOS unifies `testID` and `accessibilityLabel` into the
   same `id:` matcher.
3. **`text: "..."`** — last resort. Only acceptable when the copy is a
   designer-confirmed static label and never i18n-rotated.

If the screen has none of the above for the element you need, that's a
testability gap — file a backfill request with `mobile-dev` BEFORE
authoring the flow:

```markdown
## testID gap — <screen>

To author `auxi/maestro/flows/home/swipe.yaml`, these elements need testIDs:

| Element | File:line | Proposed testID |
|---|---|---|
| Mode pill (Safe) | `auxi/src/screens/HomeScreen.tsx:512` | `home-mode-pill-safe` |
| Heart toggle | `auxi/src/screens/HomeScreen.tsx:678` | `home-heart-toggle` |
| Outfit sheet (active) | `auxi/src/screens/HomeScreen.tsx:842` | `home-outfit-sheet-active` |

Routing: mobile-dev
```

Don't pick fragile fallbacks (text matching on dynamic copy, coordinate
clicks). The whole point of the Maestro shift is to eliminate that
flakiness.

## testID naming convention

`<feature>-<element>-<state-or-purpose>`. Examples:

| testID | Element |
|---|---|
| `auth-email-input` | login email field |
| `auth-password-input` | login password field |
| `auth-login-submit` | login button |
| `home-screen-root` | Home root view (use as "we are on Home" anchor) |
| `home-mode-pill-safe` | Safe mode pill |
| `home-mode-pill-power` | Power mode pill |
| `home-mode-pill-creative` | Creative mode pill |
| `home-heart-toggle` | favorite heart |
| `home-heart-toggle-saved` | favorite heart in saved state |
| `home-outfit-sheet-{index}` | outfit sheet (e.g., `home-outfit-sheet-1`) |
| `home-tile-pin-{index}` | pin button on tile N |
| `home-show-another` | "Show another" CTA |
| `home-this-works` | "This works" CTA |
| `home-edit-context` | "Edit context" CTA |

Keep names short, predictable, and hyphenated. No camelCase.

## Flow skeleton

```yaml
# auxi/maestro/flows/home/swipe.yaml
appId: ${MAESTRO_APP_ID}
name: home-swipe
tags:
  - home
  - regression
---
- runFlow: ../_shared/login.yaml
- assertVisible:
    id: home-screen-root
- assertVisible:
    id: home-outfit-sheet-0
- swipe:
    direction: UP
- waitForAnimationToEnd
- assertVisible:
    id: home-outfit-sheet-1
- tapOn:
    id: home-show-another
- waitForAnimationToEnd
- assertVisible:
    id: home-outfit-sheet-2
```

## Common patterns

### Login (sub-flow)

```yaml
# auxi/maestro/flows/_shared/login.yaml
appId: ${MAESTRO_APP_ID}
---
- launchApp:
    clearState: true
- assertVisible:
    id: auth-email-input
- tapOn:
    id: auth-email-input
- inputText: ${QA_EMAIL}
- tapOn:
    id: auth-password-input
- inputText: ${QA_PASSWORD}
- tapOn:
    id: auth-login-submit
- assertVisible:
    id: home-screen-root
    timeout: 15000
```

### Toggle and assert state

```yaml
- assertVisible:
    id: home-heart-toggle
- tapOn:
    id: home-heart-toggle
- assertVisible:
    id: home-heart-toggle-saved
- tapOn:
    id: home-heart-toggle-saved
- assertVisible:
    id: home-heart-toggle
- assertNotVisible:
    id: home-heart-toggle-saved
```

### Cycle through options

Mode-pill changes do NOT auto-refetch — the new mode is picked up by
the next prefetch (or "Show another" tap that reaches the lookahead
window). Assert the pill is tappable, then trigger the refetch
explicitly via "Show another".

```yaml
- assertVisible:
    id: home-mode-pill-safe
- tapOn:
    id: home-mode-pill-power
- assertVisible:
    id: home-mode-pill-power   # still mounted; selection flipped via a11yState
- tapOn:
    id: home-show-another      # trigger fetch; mode is now 'power'
- assertVisible:
    id: home-outfit-sheet-1
    timeout: 10000
```

### Wait for an async operation

```yaml
- tapOn:
    id: home-show-another
- assertNotVisible:
    id: home-loading-spinner
    timeout: 8000      # spinner clears when fetch returns
- assertVisible:
    id: home-outfit-sheet-1
```

### Hide-keyboard before next interaction

```yaml
- inputText: ${QA_EMAIL}
- hideKeyboard
- tapOn:
    id: auth-password-input
```

## What flaky assertions look like (don't write these)

| Bad | Why it's bad | Better |
|---|---|---|
| `assertVisible: text="32°C"` | weather varies | `assertVisible: id=home-weather-chip` |
| `assertVisible: text="2 items in wardrobe"` | seed data drifts | `assertVisible: id=wardrobe-item-tile-0` |
| `tapOn: { point: "50%, 80%" }` | layout drifts | `tapOn: id=home-show-another` |
| `assertVisible: text="Hello, Lan"` | i18n + user state | `assertVisible: id=home-greeting` |
| any assertion on randomized recommendation copy | content varies | structural id only |

## Self-review checklist

Before handing a flow to `qa-mobile`:

- [ ] Every `tapOn` / `inputText` targets `id:`, not raw `text:` or coords.
- [ ] Every meaningful state change has an `assertVisible` / `assertNotVisible` after it.
- [ ] No assertions on randomized data (temperatures, counts, copy).
- [ ] No screenshots, no `runScript` with image diffing, no OCR.
- [ ] Sub-flows used for any setup reused across 3+ flows.
- [ ] Sensitive values (`QA_EMAIL`, `QA_PASSWORD`) come from env, not hardcoded.
- [ ] Flow file lives at `auxi/maestro/flows/<feature>/<name>.yaml`.
- [ ] Tags include `regression` if it should run every release.
- [ ] `auxi/maestro/README.md` updated with the new flow.

## Sub-flow vs duplication

Use a sub-flow (`runFlow: ../_shared/<x>.yaml`) when:
- The setup is used by 3+ flows (e.g., login)
- The setup steps would otherwise be copy-pasted

Don't sub-flow when:
- It's used in 1-2 places (just inline)
- The shared steps differ subtly between callers (forking causes more
  pain than the duplication it avoids)

## Maestro feature reference (the subset we use)

Documented at https://maestro.mobile.dev. The verbs you'll use 90% of the time:

| Verb | Purpose |
|---|---|
| `launchApp` | Launch app, optionally `clearState: true` to clear keychain + storage |
| `tapOn` | Tap an element by `id:`, `text:`, etc. |
| `inputText` | Type into the focused field |
| `swipe` | `direction: UP / DOWN / LEFT / RIGHT`, optionally `from`/`to` |
| `scroll` | Page-style scroll inside a scrollable view |
| `assertVisible` | Element is on screen and hittable |
| `assertNotVisible` | Element is not on screen |
| `waitForAnimationToEnd` | Block until animations settle |
| `runFlow` | Inline another YAML flow |
| `hideKeyboard` | Dismiss the iOS keyboard |
| `pressKey` | Hardware-style keys (rare on iOS sim) |
| `back` | iOS swipe-back / Android back |

Avoid `runScript` and JavaScript blocks unless absolutely necessary —
they reintroduce non-determinism. If you find yourself reaching for
one, ask whether the flow is wrong.

## Composition with the team

| Trigger | You do |
|---|---|
| New feature with AC | Author flow(s), update `auxi/maestro/README.md`, hand off to `qa-mobile` |
| testID gap blocking a flow | File a backfill ticket → `mobile-dev` (with proposed names + file:line); pause flow authoring until shipped |
| `qa-mobile` reports a flow failure that's a YAML bug | Fix the YAML, re-run via `qa-mobile` |
| `qa-mobile` reports a flow failure that's a real product bug | Leave the flow alone — the failure IS the signal — and route to `mobile-dev` or `backend-dev` |
| User asks for a "visual sweep" / Figma compare | Decline. That's not in this QA model. Direct them to mobile-dev's `figma-to-rn-workflow` during implementation. |

## End-of-turn summary

```
Flows authored: N (at <paths>)
testID gaps filed: K → mobile-dev
Ready for execution by qa-mobile: <flow paths>
```
