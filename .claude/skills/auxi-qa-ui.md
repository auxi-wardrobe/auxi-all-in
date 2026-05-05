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
# Theme tokens — single file in this project
ls auxi/src/theme/                              # confirms theme.ts is the only file
cat auxi/src/theme/theme.ts                     # palette + spacing + typography all live here
# (if the layout ever splits across files, ls above will show them)

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
