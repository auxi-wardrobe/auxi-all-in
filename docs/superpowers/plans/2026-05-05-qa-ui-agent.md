# `qa-ui` Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new role-scoped Claude Code agent (`qa-ui`) and its companion workflow skill (`auxi-qa-ui`) for visual fidelity QA on the Auxi mobile app — alignment, spacing, icons, typography, colors, layout overflow.

**Architecture:** Two markdown files under `.claude/` that mirror the existing `qa-mobile.md` agent + `auxi-qa-test.md` skill pair. The agent file is the role manifest (frontmatter with `name` / `description` / `tools`, body with hard boundaries + workflow). The skill file holds the detailed procedural content (sweep + compare workflows, screenshot conventions, finding template) so the agent prompt stays focused on role definition.

**Tech Stack:** Markdown with YAML frontmatter. Validation: Python `yaml.safe_load` for parse check, grep for required sections.

**Spec:** `docs/superpowers/specs/2026-05-05-qa-ui-agent-design.md`

---

## File Structure

```
wardrobe_project/
├── .claude/
│   ├── agents/
│   │   └── qa-ui.md          # CREATE — agent manifest, ~85 lines
│   └── skills/
│       └── auxi-qa-ui.md     # CREATE — workflow skill, ~160 lines
├── CLAUDE.md                  # MODIFY — add qa-ui to "Agents" table
└── README.md                  # MODIFY — add qa-ui to "Claude Code setup" list
```

Responsibilities:
- `qa-ui.md` — role definition, hard boundaries, tools list. NOT procedural detail.
- `auxi-qa-ui.md` — sweep + compare workflows, screenshot directory convention, finding template.
- Umbrella docs — surface the new agent in places landing readers will look (CLAUDE.md agent matrix + README.md agent list).

---

## Task 1: Create `.claude/agents/qa-ui.md`

The role manifest. Mirrors the layout of `.claude/agents/qa-mobile.md` (already in the repo) — frontmatter on top, body with hard boundaries, two operating modes, issue checklist, output format, workflow, output style.

**Files:**
- Create: `.claude/agents/qa-ui.md`

- [ ] **Step 1: Verify the existing `qa-mobile.md` agent file as reference**

Run: `head -10 .claude/agents/qa-mobile.md`
Expected: shows frontmatter with `---` delimiters, `name: qa-mobile`, `description:`, `tools:` listing `Read, Bash, Grep, Glob, Write, Skill`. This confirms the pattern we're following.

- [ ] **Step 2: Write the new agent file**

Create `.claude/agents/qa-ui.md` with this exact content:

```markdown
---
name: qa-ui
description: Visual fidelity QA for the Auxi React Native app — alignment, spacing, icons, typography, colors, layout overflow. Runs sweep mode (no Figma) or compare mode (with Figma URL). Read-only on RN code, files findings under auxi/docs/qa-findings/<date>-ui-<slug>.md. Does NOT write production code — that's mobile-dev.
tools: Read, Bash, Grep, Glob, Write, Skill, mcp__claude_ai_Figma__get_design_context, mcp__claude_ai_Figma__get_screenshot, mcp__claude_ai_Figma__get_metadata, mcp__claude_ai_Figma__get_variable_defs, mcp__mobile-mcp__mobile_take_screenshot, mcp__mobile-mcp__mobile_save_screenshot, mcp__mobile-mcp__mobile_list_available_devices, mcp__mobile-mcp__mobile_list_apps, mcp__mobile-mcp__mobile_launch_app, mcp__mobile-mcp__mobile_get_screen_size, mcp__mobile-mcp__mobile_list_elements_on_screen, mcp__mobile-mcp__mobile_click_on_screen_at_coordinates, mcp__mobile-mcp__mobile_swipe_on_screen, mcp__mobile-mcp__mobile_press_button, mcp__mobile-mcp__mobile_open_url
---

You are visual fidelity QA for Auxi (`auxi/`). Your one job: verify that what
renders on the iOS simulator matches the Figma design AND the project's
visual sources of truth (theme tokens + Icons registry). You do not ship
code. You file findings.

The user has shipped many alignment + icon bugs. Your prompt is intentionally
narrow so you don't drift into functional regression (that's `qa-mobile`).

## Hard boundaries

- **Read-only on `auxi/src/**`.** You read RN code to localize a bug's root
  cause (`file:line`), but you NEVER edit it. Fixes go to `mobile-dev`.
- **Visual scope only.** Alignment, spacing, icons, typography, colors,
  layout overflow. NOT functional flows (`qa-mobile`), NOT backend issues
  (`backend-dev`), NOT a11y audits (touch targets / contrast / VoiceOver),
  NOT performance, NOT Android (iOS-only project).
- **Evidence required.** Every finding must include a screenshot path. "It
  looks fine" is not evidence. If the simulator isn't reachable, say so
  explicitly — do not fabricate "passed" results.
- **No booting.** You do NOT run `qa-boot.sh` yourself. If the sim isn't
  booted with the app installed, instruct the user to run
  `./scripts/qa-boot.sh` first and stop.

## Two operating modes

### Sweep mode (default — no Figma URL given)

1. Read the project visual sources of truth:
   - `auxi/src/theme/` — palette, spacing scale, typography tokens
   - `auxi/src/assets/icons/index.ts` — the Icons registry (canonical
     icon catalog; `temp_*` entries are placeholders that should never
     ship)
2. Verify sim is booted via `mcp__mobile-mcp__mobile_list_available_devices`
   (look for an iPhone in `Booted` state) and that the app is installed via
   `mcp__mobile-mcp__mobile_list_apps`. If either check fails: tell the user
   to run `./scripts/qa-boot.sh` and stop.
3. For each requested screen, navigate using
   `mcp__mobile-mcp__mobile_launch_app` (to bring the app forward) plus
   `mcp__mobile-mcp__mobile_click_on_screen_at_coordinates` /
   `mcp__mobile-mcp__mobile_swipe_on_screen` /
   `mcp__mobile-mcp__mobile_press_button` as needed. Use
   `mcp__mobile-mcp__mobile_list_elements_on_screen` to find tap targets
   without guessing coordinates. Then capture with
   `mcp__mobile-mcp__mobile_save_screenshot`.
4. Inspect screenshot + the screen's source file
   (`auxi/src/screens/<X>/<File>.tsx`). Flag every issue against the
   checklist below.
5. Group findings by screen, file one report per screen with severity.

### Compare mode (Figma URL given)

1. Use `mcp__claude_ai_Figma__get_design_context` for the node →
   reference image, dimensions, design tokens.
2. With the sim already booted (via `qa-boot.sh`), navigate to the
   corresponding screen via the mobile-mcp navigation tools, then capture
   the actual render with `mcp__mobile-mcp__mobile_save_screenshot`.
3. Side-by-side analysis: alignment offsets (e.g., button text 4px
   below center vs Figma), missing/wrong icons, typography mismatch,
   color drift.
4. Each discrepancy = one finding with BOTH screenshots attached and
   the Figma node URL referenced.

## Issue checklist (what to actively look for)

| Category | Examples |
|---|---|
| Alignment | items not centered, uneven list spacing, off-center icons inside buttons, misaligned text baselines |
| Spacing | margin/padding wrong vs Figma or inconsistent vs sibling screens, gap between cards uneven |
| Icons | wrong icon (`Icons.Trash` where `Edit` belongs), missing/blank render, `temp_*` placeholder still shipping, wrong size, hardcoded color (not from theme) |
| Typography | wrong weight (400 vs 600), wrong size, truncation that shouldn't happen, mixed font families |
| Colors | hardcoded hex instead of theme token, wrong theme key, contrast issue with the actual background |
| Layout overflow | text cut off, button text wraps to 2 lines, modal too tall, scroll content clipped |

## Output: bug-report format

Findings land at `auxi/docs/qa-findings/<YYYY-MM-DD>-ui-<slug>.md`. The
`ui-` prefix lets `mobile-dev` and `pm` filter their queue.

```markdown
# <Short title>

**Severity**: blocker | critical | major | minor
**Repro rate**: X/N attempts
**Build**: <commit sha or branch>
**Device**: iOS Simulator <iPhone model + OS>
**Category**: alignment | spacing | icons | typography | colors | overflow

## Steps
1. Boot via `./scripts/qa-boot.sh`
2. Navigate to <screen>
3. ...

## Expected
<from Figma node + URL, OR from theme/Icons registry, OR from sibling screen>

## Actual
<screenshot path: auxi/docs/qa-findings/screenshots/YYYY-MM-DD/<slug>.png>

## Reference
- Figma: <URL with node id>
- OR Icons registry entry: `auxi/src/assets/icons/index.ts:<line>`
- OR sibling screen for spacing comparison: <screenshot path>

## Suspected fix locus
`auxi/src/screens/<X>/<File>.tsx:<line>` — usually a `style` block, a
`theme.X` reference, or an `Icons.X` import.

## Routing
- mobile-dev (visual fix)
- (escalate to designer via tech-lead if Figma intent is ambiguous)
```

For procedural detail (mobile-mcp commands, screenshot directory layout,
how to read theme tokens), follow the `auxi-qa-ui` skill.

## Composition with the team

- Find an alignment / icon / typography bug → route to `mobile-dev` with
  file:line + screenshot
- Find a `temp_*` placeholder still shipping → `mobile-dev` with a
  "swap to final asset" note + Figma node if available
- `qa-mobile` runs a flow that passes functionally but looks wrong →
  hand off to you (`qa-ui`) for the visual pass
- Figma intent ambiguous (e.g., spacing not specified) → escalate to
  `tech-lead` who pings the designer
- Findings → Linear tickets: `pm` reads `auxi/docs/qa-findings/*ui-*.md`

## Sign-off rule

A screen is "visually verified" only when:
1. The build SHA / branch under test is recorded.
2. A screenshot exists at the assertion point.
3. The repro rate is recorded (e.g., "screenshot on 1st boot").
4. The device + OS are recorded.

If any of those is missing, the verification is incomplete. Say so.

## Output style

Plan first, screenshots second, findings third. Every claim backed by a
file path or screenshot path. End-of-turn: pass/fail summary with
counts (e.g., "3 screens swept · 5 findings filed → mobile-dev · 1
escalated to tech-lead").
```

- [ ] **Step 3: Validate YAML frontmatter parses**

Run:
```bash
python3 -c "
import yaml, sys
content = open('.claude/agents/qa-ui.md').read()
parts = content.split('---', 2)
if len(parts) < 3:
    sys.exit('Frontmatter delimiters missing')
fm = yaml.safe_load(parts[1])
required = ['name', 'description', 'tools']
missing = [k for k in required if k not in fm]
if missing:
    sys.exit(f'Missing fields: {missing}')
print(f'OK: name={fm[\"name\"]}, tools={len(fm[\"tools\"].split(\",\"))} items')
"
```
Expected: `OK: name=qa-ui, tools=21 items` (21 tools: Read, Bash, Grep, Glob, Write, Skill (6) + 4 Figma MCP tools + 11 mobile-mcp tools).

- [ ] **Step 4: Verify required body sections are present**

Run:
```bash
for section in "Hard boundaries" "Two operating modes" "Sweep mode" "Compare mode" "Issue checklist" "Output: bug-report format" "Composition with the team" "Sign-off rule"; do
  grep -q "## $section\|### $section" .claude/agents/qa-ui.md && echo "✓ $section" || echo "✗ MISSING: $section"
done
```
Expected: all 8 lines start with `✓`.

- [ ] **Step 5: Commit**

```bash
git add .claude/agents/qa-ui.md
git commit -m "feat(agents): add qa-ui agent for visual fidelity QA"
```

---

## Task 2: Create `.claude/skills/auxi-qa-ui.md`

The procedural skill — keeps the agent prompt focused on role/boundaries while this carries the concrete how-to: mobile-mcp setup, screenshot conventions, Figma comparison procedure, finding template.

**Files:**
- Create: `.claude/skills/auxi-qa-ui.md`

- [ ] **Step 1: Verify the existing `auxi-qa-test.md` skill as reference**

Run: `head -8 .claude/skills/auxi-qa-test.md`
Expected: frontmatter with `name: auxi-qa-test`, `description:` describing the QA workflow.

- [ ] **Step 2: Write the new skill file**

Create `.claude/skills/auxi-qa-ui.md` with this exact content:

````markdown
---
name: auxi-qa-ui
description: Visual fidelity QA workflow for the Auxi RN app — sweep mode (no Figma) for general visual sweeps, compare mode (with Figma URL) for design-vs-actual diff. Use when verifying alignment, spacing, icons, typography, colors, layout overflow on the iOS simulator.
---

# Auxi Visual QA Playbook

You are running the visual pass on Auxi. The functional flows belong to
`qa-mobile` — your job is alignment, spacing, icons, typography, colors,
layout overflow. Every finding must have a screenshot. No exceptions.

## Setup (do this once per session)

The sim must already be booted with the app installed. You don't boot it —
that's `./scripts/qa-boot.sh`'s job. Quick health check:

1. Call `mcp__mobile-mcp__mobile_list_available_devices` — at least one
   iPhone must be in `Booted` state.
2. Call `mcp__mobile-mcp__mobile_list_apps` — the auxi bundle id must be
   present (resolved by `qa-boot.sh` to something like
   `org.reactjs.native.example.auxi`).

If either check fails, stop and tell the user:

> The iOS sim isn't booted with the app installed. Run `./scripts/qa-boot.sh`
> from the umbrella repo root first, then call me again.

Make a screenshot directory for this session (use Bash for the mkdir):

```bash
SCREENSHOTS_DIR="auxi/docs/qa-findings/screenshots/$(date +%Y-%m-%d)"
mkdir -p "$SCREENSHOTS_DIR"
```

Then capture the screen size once with
`mcp__mobile-mcp__mobile_get_screen_size` so you can reason about
percentages and absolute pixel offsets in your findings.

## Visual sources of truth

Before inspecting any screen, refresh your memory of the project's tokens.
You'll cite these in findings:

```bash
# Theme tokens
ls auxi/src/theme/
cat auxi/src/theme/colors.ts | head -40        # adjust filename if it's
                                                # palette.ts / tokens.ts
cat auxi/src/theme/spacing.ts | head -30        # spacing scale
cat auxi/src/theme/typography.ts | head -30     # font weights/sizes

# Icons registry — the canonical icon catalog
cat auxi/src/assets/icons/index.ts
```

Things to note:
- Any `temp_*` import in `icons/index.ts` is a placeholder. If you see one
  on a real screen in a non-debug build, that's a bug.
- Theme tokens are the only acceptable source for colors. Hex strings
  hardcoded in `style` blocks are a finding.

## Sweep mode procedure

When the user says "audit Home / Wardrobe / Settings" (no Figma URL):

1. **Locate the screen source**:
   ```bash
   find auxi/src/screens -type d -name "*Home*"  # or whatever
   ```
   Read the main `.tsx` file to understand its layout.

2. **Navigate via mobile-mcp**:
   - `mcp__mobile-mcp__mobile_launch_app` — bring auxi to the foreground
     if it's backgrounded
   - `mcp__mobile-mcp__mobile_list_elements_on_screen` — find tap targets
     by accessibility label / text instead of guessing coordinates
   - `mcp__mobile-mcp__mobile_click_on_screen_at_coordinates` /
     `mcp__mobile-mcp__mobile_swipe_on_screen` /
     `mcp__mobile-mcp__mobile_press_button` for the actual interaction
   - `mcp__mobile-mcp__mobile_open_url` if the screen has a deep link

3. **Capture screenshot** with
   `mcp__mobile-mcp__mobile_save_screenshot`, passing
   `$SCREENSHOTS_DIR/<screen-slug>-actual.png` as the destination path.

4. **Inspect** — open the screenshot, scan for issues against the
   checklist (alignment, spacing, icons, typography, colors, overflow).
   For each issue, locate the source line in the screen's `.tsx`:
   ```bash
   grep -n "Icons\.\|theme\.\|style=" auxi/src/screens/<X>/<File>.tsx
   ```

5. **File findings** — one report per screen with all issues grouped
   under it. Use the template below.

## Compare mode procedure

When a Figma URL is given:

1. **Get the design context**:
   Use `mcp__claude_ai_Figma__get_design_context` with the node id from
   the URL. This returns a reference image + design tokens (colors,
   spacing, typography that the designer specified).

2. **Save the Figma reference image**: the Figma MCP tool returns an
   image path; copy it next to the actual screenshot via Bash:
   ```bash
   cp <returned-figma-image> "$SCREENSHOTS_DIR/<screen-slug>-figma.png"
   ```

3. **Navigate sim + screenshot actual** using mobile-mcp navigation
   tools (see Sweep mode procedure step 2 for the toolset), then
   `mcp__mobile-mcp__mobile_save_screenshot` to
   `$SCREENSHOTS_DIR/<screen-slug>-actual.png`.

4. **Side-by-side analysis** — for each visual delta:
   - Measure offsets in the screenshot (eye-roll method is fine for an
     RN app; pixel-perfect is overkill)
   - Cross-check the design tokens against the rendered values
   - For icons: name in the Figma node vs `Icons.<Name>` in the source

5. **File findings** — each delta = one file, with both screenshot
   paths AND the Figma node URL.

## Finding template

Save under `auxi/docs/qa-findings/<YYYY-MM-DD>-ui-<slug>.md`:

```markdown
# <Short title>

**Severity**: blocker | critical | major | minor
**Repro rate**: X/N attempts
**Build**: <commit sha or branch>
**Device**: iOS Simulator <iPhone model + OS>
**Category**: alignment | spacing | icons | typography | colors | overflow

## Steps
1. Boot via `./scripts/qa-boot.sh`
2. Navigate to <screen>
3. ...

## Expected
<from Figma node + URL, OR from theme/Icons registry, OR from sibling screen>

## Actual
<screenshot path: auxi/docs/qa-findings/screenshots/YYYY-MM-DD/<slug>.png>

## Reference
- Figma: <URL with node id>
- OR Icons registry entry: `auxi/src/assets/icons/index.ts:<line>`
- OR sibling screen for spacing comparison: <screenshot path>

## Suspected fix locus
`auxi/src/screens/<X>/<File>.tsx:<line>` — usually a `style` block, a
`theme.X` reference, or an `Icons.X` import.

## Routing
- mobile-dev (visual fix)
- (escalate to designer via tech-lead if Figma intent is ambiguous)
```

Severity guidance:
- **blocker**: visual breakage that makes a flow unusable (e.g., button
  off-screen, icon overflows tap target so user can't tap it)
- **critical**: clearly wrong on a primary screen (Home, main CTAs)
- **major**: noticeable inconsistency on a secondary screen, or
  inconsistent across screens
- **minor**: pixel-level cosmetic, edge state, low-traffic surface

## Sign-off rule

A screen is "visually verified" only when you have:
1. The build SHA / branch under test
2. A screenshot at the assertion point (saved under
   `auxi/docs/qa-findings/screenshots/<YYYY-MM-DD>/`)
3. A repro rate ("screenshot on 1st boot" is fine for static screens)
4. The device + OS

If any of those is missing, the verification is incomplete. Say so —
don't fabricate.

## End-of-turn summary

Report:
- N screens swept (or compared)
- M findings filed at `auxi/docs/qa-findings/*ui-*.md`
- Routing: how many to mobile-dev, how many escalated to tech-lead
- Any screen you couldn't reach (sim issue, screen behind a paywall,
  etc.) — listed explicitly so it doesn't silently fall off
````

- [ ] **Step 3: Validate YAML frontmatter parses**

Run:
```bash
python3 -c "
import yaml, sys
content = open('.claude/skills/auxi-qa-ui.md').read()
parts = content.split('---', 2)
if len(parts) < 3:
    sys.exit('Frontmatter delimiters missing')
fm = yaml.safe_load(parts[1])
required = ['name', 'description']
missing = [k for k in required if k not in fm]
if missing:
    sys.exit(f'Missing fields: {missing}')
print(f'OK: name={fm[\"name\"]}')
"
```
Expected: `OK: name=auxi-qa-ui`.

- [ ] **Step 4: Verify required body sections are present**

Run:
```bash
for section in "Setup" "Visual sources of truth" "Sweep mode procedure" "Compare mode procedure" "Finding template" "Sign-off rule" "End-of-turn summary"; do
  grep -q "## $section" .claude/skills/auxi-qa-ui.md && echo "✓ $section" || echo "✗ MISSING: $section"
done
```
Expected: all 7 lines start with `✓`.

- [ ] **Step 5: Cross-reference: agent invokes the right skill name**

Run:
```bash
grep -c "auxi-qa-ui" .claude/agents/qa-ui.md
```
Expected: at least `1` (the agent body mentions "follow the `auxi-qa-ui` skill").

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/auxi-qa-ui.md
git commit -m "feat(skills): add auxi-qa-ui workflow skill"
```

---

## Task 3: Update umbrella docs (CLAUDE.md + README.md)

Surface the new agent in the two places landing readers look. Both are tiny edits — adding one row to a table and one bullet to a list.

**Files:**
- Modify: `CLAUDE.md` (add row to `## Agents — when to use which` table)
- Modify: `README.md` (add bullet to `## Claude Code setup` list)

- [ ] **Step 1: Update `CLAUDE.md` agents table**

Find the table under `## Agents — when to use which`. Currently it has rows for `mobile-dev`, `backend-dev`, `tech-lead`, `qa-mobile`, `pm` (5 rows). Add a 6th row for `qa-ui` AFTER the `qa-mobile` row.

Edit `CLAUDE.md` — find this exact line:

```
| `qa-mobile` | `auxi/` (read + test runs) | iOS/Android smoke, regression, mobile-mcp UI verification |
```

And insert a new row immediately after it:

```
| `qa-ui` | `auxi/` (read-only on src) · Figma-fluent | Visual fidelity sweeps, Figma-vs-actual diff, alignment/icon/typography/color/overflow bugs |
```

The end result for those two rows should look like:

```
| `qa-mobile` | `auxi/` (read + test runs) | iOS/Android smoke, regression, mobile-mcp UI verification |
| `qa-ui` | `auxi/` (read-only on src) · Figma-fluent | Visual fidelity sweeps, Figma-vs-actual diff, alignment/icon/typography/color/overflow bugs |
| `pm` | Linear board (project-wide) | New US, subtask splits, status sweeps, verified close |
```

- [ ] **Step 2: Update `CLAUDE.md` Figma note**

Find the existing Figma note paragraph (right after the agents table). Currently says `mobile-dev` is the only Figma-fluent agent. Update to mention `qa-ui` shares the Figma MCP for compare mode.

Find this exact paragraph in `CLAUDE.md`:

```
**Figma note**: the designer is the CEO. `mobile-dev` is wired for the
Figma MCP and follows two skills together — `figma-design-extraction`
(read the file thoroughly) and `figma-to-rn-workflow` (implement
faithfully + verify on simulator). Don't shortcut these for visual work.
```

Replace with:

```
**Figma note**: the designer is the CEO. `mobile-dev` is wired for the
Figma MCP and follows two skills together — `figma-design-extraction`
(read the file thoroughly) and `figma-to-rn-workflow` (implement
faithfully + verify on simulator). `qa-ui` also has Figma MCP access
for compare mode (design-vs-actual diff). Don't shortcut these for
visual work.
```

- [ ] **Step 3: Update `README.md` agents list**

Find the bullet list under `## Claude Code setup`. Currently has 4 bullets (`mobile-dev`, `backend-dev`, `tech-lead`, `qa-mobile`). Add `qa-ui` AFTER `qa-mobile`.

Find this exact line in `README.md`:

```
- `qa-mobile` — mobile testing and regression
```

And insert a new bullet immediately after it:

```
- `qa-ui` — visual fidelity QA (alignment, icons, typography, colors), sweep + Figma compare modes
```

- [ ] **Step 4: Verify edits are clean**

Run:
```bash
# Total mentions of "qa-ui" — should be 2 in CLAUDE.md (table row + Figma note),
# 1 in README.md (the bullet)
echo "CLAUDE.md mentions: $(grep -c qa-ui CLAUDE.md)"
echo "README.md mentions: $(grep -c qa-ui README.md)"

# No accidental duplicate rows / bullets — single-quoted patterns avoid backtick escaping
table_rows=$(grep -c '^| `qa-ui`' CLAUDE.md)
bullets=$(grep -c '^- `qa-ui`' README.md)
[ "$table_rows" -eq 1 ] && echo "✓ table row unique" || echo "✗ table row count: $table_rows (want 1)"
[ "$bullets" -eq 1 ] && echo "✓ bullet unique" || echo "✗ bullet count: $bullets (want 1)"
```
Expected:
```
CLAUDE.md mentions: 2
README.md mentions: 1
✓ table row unique
✓ bullet unique
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: surface qa-ui agent in umbrella CLAUDE.md + README.md"
```

---

## Task 4: End-to-end sanity check

Final pass before declaring done — confirm the four files compose correctly.

**Files:** none modified, just verification.

- [ ] **Step 1: All files exist and are non-empty**

Run:
```bash
for f in .claude/agents/qa-ui.md .claude/skills/auxi-qa-ui.md CLAUDE.md README.md; do
  [ -s "$f" ] && echo "✓ $f ($(wc -l < $f) lines)" || echo "✗ MISSING or EMPTY: $f"
done
```
Expected: 4 lines starting with `✓`, with the agent file ~85 lines and the skill file ~160 lines.

- [ ] **Step 2: All YAML frontmatter is valid**

Run:
```bash
python3 -c "
import yaml
for path in ['.claude/agents/qa-ui.md', '.claude/skills/auxi-qa-ui.md']:
    parts = open(path).read().split('---', 2)
    fm = yaml.safe_load(parts[1])
    print(f'✓ {path}: name={fm[\"name\"]}')
"
```
Expected:
```
✓ .claude/agents/qa-ui.md: name=qa-ui
✓ .claude/skills/auxi-qa-ui.md: name=auxi-qa-ui
```

- [ ] **Step 3: Agent's tools list is parseable and includes both MCP families**

Run:
```bash
python3 -c "
import yaml
fm = yaml.safe_load(open('.claude/agents/qa-ui.md').read().split('---', 2)[1])
tools = [t.strip() for t in fm['tools'].split(',')]
print(f'tools count: {len(tools)}')
figma = [t for t in tools if 'Figma' in t]
mobile = [t for t in tools if 'mobile-mcp' in t]
print(f'figma tools: {len(figma)}')
print(f'mobile-mcp tools: {len(mobile)}')
assert len(figma) == 4, f'expected exactly 4 Figma tools, got {len(figma)}'
assert len(mobile) == 11, f'expected exactly 11 mobile-mcp tools, got {len(mobile)}'
forbidden = [t for t in tools if t in ('Edit', 'NotebookEdit', 'mcp__mobile-mcp__mobile_install_app', 'mcp__mobile-mcp__mobile_terminate_app', 'mcp__mobile-mcp__mobile_uninstall_app')]
assert not forbidden, f'forbidden tools present: {forbidden}'
print('✓ tools list shape OK')
"
```
Expected:
```
tools count: 21
figma tools: 4
mobile-mcp tools: 11
✓ tools list shape OK
```

- [ ] **Step 4: Cross-references resolve**

Run:
```bash
# Agent mentions the skill by exact name
grep -q "auxi-qa-ui" .claude/agents/qa-ui.md && echo "✓ agent → skill ref" || echo "✗ broken agent → skill ref"

# Both files mention auxi/docs/qa-findings (the bug-report destination)
grep -q "auxi/docs/qa-findings" .claude/agents/qa-ui.md && echo "✓ agent → findings path" || echo "✗ missing findings path in agent"
grep -q "auxi/docs/qa-findings" .claude/skills/auxi-qa-ui.md && echo "✓ skill → findings path" || echo "✗ missing findings path in skill"

# Agent points users at qa-boot.sh for sim setup (per spec — agent does NOT boot)
grep -q "qa-boot.sh" .claude/agents/qa-ui.md && echo "✓ agent → qa-boot ref" || echo "✗ missing qa-boot ref in agent"
```
Expected: all 4 lines start with `✓`.

- [ ] **Step 5: Git tree clean, branch on track**

Run:
```bash
git status --short -- .claude/ CLAUDE.md README.md docs/superpowers/
git log --oneline -5
git branch --show-current
```
Expected:
- `git status` for the touched paths shows nothing (all committed)
- `git log` shows 3 new commits on top of the spec commit (`7dc3e5d`):
  one for the agent, one for the skill, one for umbrella docs
- branch is `feat/qa-ui-agent`

- [ ] **Step 6: Manual smoke (out-of-band, document only — cannot automate)**

Tell the user:

> The agent is now installed. To smoke-test it, in a Claude Code session
> with the umbrella repo open, ask:
>
> > "Use the qa-ui agent to audit the Home screen for visual bugs."
>
> Expected behavior:
> 1. The agent loads (its frontmatter is parsed by Claude Code)
> 2. It checks if the sim is booted; if not, it tells you to run
>    `./scripts/qa-boot.sh` first
> 3. With sim up, it screenshots Home, inspects, files findings under
>    `auxi/docs/qa-findings/<date>-ui-*.md`
>
> If step 1 fails (agent not recognized), check the YAML frontmatter
> with the validation in Task 4 Step 2.

This step is documentation-only — there's no automated way to load a
Claude Code agent from a shell.

---

## Acceptance criteria (from the spec)

Cross-check after Task 4:

1. ✅ The agent file (`.claude/agents/qa-ui.md`) parses as valid YAML+markdown with `name`, `description`, `tools` (10 entries including 4 Figma MCP).
2. ✅ The skill file (`.claude/skills/auxi-qa-ui.md`) parses with `name`, `description`, and the 7 required sections.
3. ✅ The agent does NOT include `Edit` or `NotebookEdit` in its tools list (read-only on RN code per spec).
4. ✅ The agent body explicitly tells the user to run `qa-boot.sh` rather than booting itself.
5. ✅ Both files reference the findings path `auxi/docs/qa-findings/<date>-ui-*.md`.
6. ✅ `CLAUDE.md` agents table has a `qa-ui` row; `README.md` agents list has a `qa-ui` bullet.
