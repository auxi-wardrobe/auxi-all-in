---
name: auxi-qa-ux
description: UX heuristic + accessibility review playbook for the Auxi RN app. Bootstrap state via Maestro login, screenshot post-login surfaces, evaluate against Nielsen's 10 + mobile patterns + state coverage + IA + a11y. Findings only — never fix code. Use when verifying that users can understand and complete tasks (distinct from qa-ui's pixel-fidelity scope).
---

# Auxi UX Review Playbook

You are running the heuristic UX pass on Auxi. Pixel fidelity belongs to
`qa-ui`. Functional regression belongs to `qa-mobile` (executing Maestro
flows). Your job: judge whether users can understand and successfully
complete tasks. Every finding has a screenshot. No exceptions.

## Setup (do this once per session)

The sim must already be booted with the app installed via
`./scripts/qa-boot.sh`. Quick health check:

1. `mcp__mobile-mcp__mobile_list_available_devices` — at least one
   iPhone in `Booted` state.
2. `mcp__mobile-mcp__mobile_list_apps` — `com.auxi` present.

If either fails, tell the user to run `./scripts/qa-boot.sh` and stop.

Make a session screenshot directory:

```bash
SCREENSHOTS_DIR="auxi/docs/qa-findings/screenshots/$(date +%Y-%m-%d)"
mkdir -p "$SCREENSHOTS_DIR"
```

Capture screen size once with `mcp__mobile-mcp__mobile_get_screen_size`
so touch-target measurements have a frame of reference.

## Login bootstrap (use Maestro — do NOT type credentials)

Per the project's QA architecture, Maestro is the deterministic state
driver. The `_shared/login.yaml` flow logs into the QA test account and
exits at the post-login surface. Run it before any sweep:

```bash
cd auxi
maestro test maestro/flows/_shared/login.yaml \
  -e QA_EMAIL=qa-test@auxi.app \
  -e QA_PASSWORD='QaTest!2026'
```

Exit code 0 = logged in, app is on the post-login default screen.
Now drive the rest with mobile-mcp screenshots.

**Why not type creds yourself?** Per-character `mobile_type_keys` costs
60–120s per run, and Metro hot-reload during a session can drop
auth state silently. Maestro handles both.

If Maestro is broken or the flow itself is the bug under review, fall
back to `mobile_type_keys` — but document the fallback in your report.

## Visual sources of truth (read once, cite often)

```bash
# Theme tokens — for color contrast checks
cat auxi/src/theme/theme.ts

# Icons registry — to verify temp_* placeholders are gone
cat auxi/src/assets/icons/index.ts

# testID + accessibilityLabel discipline (per auxi/CLAUDE.md)
grep -rn "testID=" auxi/src/screens/<X>.tsx
grep -rn "accessibilityLabel=" auxi/src/screens/<X>.tsx
```

You'll cite these in findings (e.g., "Icons.User used for both 'My
body' and 'My account' rows — fails N4 consistency / IA disambiguation").

## The 5 checklists (run all 5 per screen)

### 1. Nielsen's 10

Walk all 10. The most common Auxi violations to scan for first:

- **N1 (status)**: bare spinners with no label
- **N3 (control)**: dead-end screens, missing back, no undo
- **N4 (consistency)**: same action labeled differently across siblings
- **N5 (error prevention)**: destructive action without confirmation
- **N9 (error recovery)**: "Something went wrong" with no retry

### 2. Mobile patterns

- Thumb-zone reachability (CTAs in lower 2/3 on iPhone Pro Max)
- Gesture conflicts (horizontal card swipe vs back-swipe)
- Bottom-sheet vs full-screen modal weight match
- Notification permission asked in context, not at cold-start

### 3. State coverage (every screen has 4 states)

| State | What to check |
|---|---|
| Empty | First-action guidance present? Or just a sad face? |
| Loading | Labeled? Skeleton vs spinner? |
| Error | Diagnoseable? Retry path? Offline distinguished from server error? |
| Populated | Happy path renders, but is it scannable? |

### 4. Information architecture

- Every primary action ≤2 taps from Home
- Back button goes back to where the user came from (not a fixed parent)
- Every screen has an exit (back, close, swipe-to-dismiss)
- **Dead controls**: grep for interactive primitives without `onPress`:
  ```bash
  # Quick scan — interactive elements likely missing handlers
  grep -nE "<(TouchableOpacity|Pressable|Touchable)[^>]*>" auxi/src/screens/<X>.tsx
  ```
  Cross-check each match — does it have an `onPress`? Sidebar's
  "My favourite" / "Archive" rows historically failed this.
- Sibling consistency — does `delete` behave the same on
  `WardrobeScreen` as on `BodyScreen`?

### 5. Accessibility (full scope)

Per directive, qa-ux covers full a11y, not just touch targets.

#### Touch targets (≥ 44×44pt)

For every interactive element measured in the screenshot, compute
rendered hit area. Common Auxi failures:

```bash
# Find <TouchableOpacity> with no padding / hitSlop / explicit width
grep -nE "TouchableOpacity[^>]*>" auxi/src/screens/<X>.tsx | head -20
```

Inline `<Text>` wrapped in `TouchableOpacity` with no `padding` or
`hitSlop` is the classic offender (Login "Sign Up" link was 50×19).

#### Color contrast (≥ 4.5:1 normal, ≥ 3:1 large)

For each text-on-background pair, compute contrast ratio. Tools:
- WebAIM contrast checker (manual): https://webaim.org/resources/contrastchecker/
- Or compute by hand: relative luminance per WCAG formula

Cite the foreground/background hex pair AND the measured ratio in the
finding.

#### VoiceOver

- Every interactive element has visible text OR `accessibilityLabel`
- Icon-only buttons MUST have `accessibilityLabel` (per `auxi/CLAUDE.md`)
- `<Image>` / SVG that conveys meaning (not decoration) needs label
- Form `TextInput` paired with visible label, mirrored as `accessibilityLabel`

```bash
# Quick scan — interactive primitives with no a11y label
grep -nE "(TouchableOpacity|Pressable)" auxi/src/screens/<X>.tsx | grep -v "accessibilityLabel"
```

#### Dynamic Type

Set sim to 200% (Settings → Display & Brightness → Text Size).
Re-screenshot. File findings on:
- Truncated headlines or labels
- Layout collapse (cards overflowing)
- Buttons whose text wraps to 3+ lines

#### Reduce Motion

Set sim to Reduce Motion ON (Settings → Accessibility → Motion).
File findings on:
- Animations that ignore the setting
- Transitions that become unintelligible without motion (e.g., a
  cross-fade where the two states are nearly identical)

## Procedure (per dispatch)

### Hard constraint: at most 4 surfaces per dispatch

iPhone screenshots are 1170×2532px. Claude's per-conversation image
budget exhausts after roughly 15–20 such images. A "sweep mode" run
covering 8 surfaces × 2–3 screenshots each will crash the agent before
the findings file is written, leaving orphan screenshots and no report.

**Default to focus mode**: cover 3–4 surfaces in one dispatch. The
orchestrator can dispatch you multiple times in sequence (Login+Welcome,
Home+Sidebar, Wardrobe+AddSheet+Database, Body+Settings) to cover the
full app — that's far more reliable than one giant sweep.

If the user explicitly requests sweep-mode coverage of >4 surfaces,
push back and recommend multi-dispatch.

### One canonical screenshot per surface

Take ONE screenshot per surface as the "actual state" for the
checklist. Only take a secondary screenshot if a finding requires a
distinct state to be evidenced — e.g., a dead-control test legitimately
needs a before+after pair to prove "tap did nothing".

**Don't** screenshot every keyboard state, every typing variant, every
intermediate animation frame. Each shot consumes image budget.

### Write findings INCREMENTALLY (append per surface)

Create the findings file with the header + coverage section BEFORE
visiting any surface. Then after each surface evaluation, APPEND that
surface's findings to the file. This way:

- A crash mid-run leaves a partial-but-useful report on disk
- The orchestrator can resume from where you stopped without re-running
  surfaces already covered
- Self-audit at the end is just a final tally + summary, not the
  entire write

```bash
# Initialize the file (do this BEFORE the first surface)
cat > auxi/docs/qa-findings/$(date +%Y-%m-%d)-ux-<slug>.md <<'EOF'
# Auxi UX heuristic + a11y sweep — <date>

**Build**: ...
**Device**: ...
**Coverage**: <list surfaces in scope>

EOF
```

Then after each surface, append:

```bash
cat >> auxi/docs/qa-findings/<file>.md <<'EOF'

## <Surface name>

### UX-<id> · <severity> · <heuristic>
...

EOF
```

### Per-surface loop

For each surface in scope (max 4):

```
1. Navigate via mobile-mcp (use list_elements_on_screen to find tap targets)
2. ONE screenshot → $SCREENSHOTS_DIR/ux-<surface>.png
   (only add ux-<surface>-<state>.png if a finding requires distinct state)
3. Open auxi/src/screens/<X>.tsx — read the relevant components
4. Walk the 5 checklists; for each violation, draft a finding
5. Cross-reference testID + accessibilityLabel coverage via grep
6. APPEND the surface's findings to the report file
```

After all surfaces in scope are evaluated:

```
7. Append the self-audit section + routing summary to the file
8. Print pass/fail summary in your final message
```

## Finding template

```markdown
# <Short user-facing problem title>

**Severity**: blocker | critical | major | minor
**Heuristic**: N1–N10 | Mobile | State | IA | A11y (touch | contrast | VO | DT | Motion)
**Screen**: <name>
**Build**: <commit sha>
**Device**: iOS Simulator <model + OS>

## What the user sees

<Plain language. No code-speak.>

## Why it's a problem

<Cite the heuristic + user impact.>

## Evidence

- Screenshot: <path>
- Source: `auxi/src/<file>.tsx:<line>`
- Measurement (a11y only): <value vs spec, e.g., "touch target 50×19pt vs 44×44 minimum">

## Routing

- mobile-dev (implementation)
- (escalate to tech-lead → designer if intent unclear)
```

## Severity guidance (UX flavor)

Different from qa-ui's pixel-deviation severity. UX severity is about
user task completion:

- **blocker** — primary task impossible (dead control on only path,
  unrecoverable auth state)
- **critical** — likely abandonment without recourse (no error
  recovery, dead-end empty state)
- **major** — meaningful friction; user completes with confusion
  (dead-link, ambiguous CTA, inconsistent siblings)
- **minor** — polish (copy nit, sub-optimal thumb-zone)

## Sign-off rule

UX-verified only when:
1. Build SHA recorded
2. Every cited finding has a screenshot on disk
3. Every finding has a heuristic label
4. Device + OS recorded

If anything is missing, verification is incomplete. Say so.

## End-of-turn summary

Report:
- N surfaces swept
- M findings filed at `auxi/docs/qa-findings/<date>-ux-<slug>.md`
- Severity counts (blocker / critical / major / minor)
- Heuristic counts (Nielsen / Mobile / State / IA / A11y breakdown)
- Routing (how many → mobile-dev, how many escalated to tech-lead)
- Any surface NOT reached + why (don't let it silently fall off)
- Self-audit result: N findings, S with verified screenshots, D deleted as unverified
