# V05 Eval Report Template

Use these skeletons depending on mode. Fill placeholders `<...>`.

---

## Template 1 — `--fresh` mode

```markdown
# V05 Fresh Eval — <YYMMDD-HHMM> <slug>

**Mode**: `--fresh`
**Scenarios run**: <N>
**Total calls**: <total>
**Rubric**: preliminary (AU-259 pending)
**Backend**: <commit_sha>
**Eval account**: <email>

---

## Executive verdict: <PASS|FAIL|MIXED>

<1-2 sentence summary of overall outcome>

## Outcome matrix

| # | scenario | build | TA success | avg coherence | avg weather_fit | common_essential |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 1 | M/22°C/casual | ✅ | 1/4 | 3.3/5 | 4.5/5 | 0 |
| 2 | W/15°C/confident | ✅ | 4/4 | 4.1/5 | 4.0/5 | 0 |
| 3 | M/30°C/casual | common_essential | — | 3.5/5 | 3.0/5 | 1 (BOTTOM) |
| 4 | M/5°C/casual | wardrobe_gap | — | — | — | — |
| ... | ... | | | | | |

## Per-scenario details

### Scenario 1: M / 22°C / casual

**Build**: <human-readable summary of build outfit>
**Try Another results**:
- silhouette: <result>
- layering: <result>
- color: <result>
- footwear: <result>
- accessory: <result>

**Coherence highlights**: <notes from vision subagent>
**Weather fit notes**: <any hard-rule violations or marginal scores>
**Source breakdown**: user=N, common_essential=N

(repeat per scenario)

## Aggregate findings

### What works
- <bullet observations>

### What doesn't
- <bullet observations>

### Hard-rule violations
| Scenario | Outfit | Violation | Severity |
|---|---|---|:---:|
| ... | ... | ... | 🔴/🟡 |

## Comparison to prior runs

| Scenario | Today | Previous | Δ |
|---|---|---|---|
| ... | ... | ... | ↑/↓/= |

## Recommendations

1. <action item with rationale>
2. ...

## Open questions

- <questions surfaced by eval>

## Raw artifacts

- `eval_runs/<ts_1>/outfits.json` — scenario 1
- `eval_runs/<ts_2>/outfits.json` — scenario 2
- ...
```

---

## Template 2 — `--logs` mode

```markdown
# V05 Log Mining — last <N> days

**Mode**: `--logs`
**Lookback**: <N> days
**Query date**: <date>
**Total events**: <total>

---

## Cluster summary

| Metric | Value |
|---|---:|
| Total events | <total> |
| Unique users affected | <count> |
| WardrobeGapError | <count> |
| PoolInsufficientError | <count> |
| Most common failure | <reason> (<cnt>x) |

## Top failure patterns

| Cluster | Count | % of total | Hypothesis | Suggested action |
|---|---:|---:|---|---|
| M × COOL × FOOTWEAR starvation | 45 | 32% | SYS catalog has 1 boot for M | AU-260 in flight ✓ |
| W × HOT × BOTTOM starvation | 12 | 8% | W wardrobe lacks light shorts/skirts | Catalog audit needed |
| _ × MILD × no_outfits_after_L2 | 8 | 6% | Engine bug — L2 cap binding | Investigate visual_weight cap |

## Layer breakdown

Which pipeline stage raises most:

| Layer | Count | % |
|---|---:|---:|
| L2 | <n> | <pct>% |
| L1 (post-filter) | <n> | <pct>% |
| pre-L1 (no_user_items) | <n> | <pct>% |
| L4 (mood) | <n> | <pct>% |
| L5 (force_axis) | <n> | <pct>% |

## Per-user repeat failures

Top users with most repeated failures (≥3 in window):

| user_id | fail_count | distinct_reasons | first | last |
|---|---:|---:|---|---|
| <uuid_truncated> | <n> | <n> | <ts> | <ts> |

→ Action: outreach? Specific wardrobe audit? Or engine fix targeting their pattern.

## Climate distribution heatmap

| temp_c bucket | M | W | U | Total |
|---|---:|---:|---:|---:|
| < 5°C | <n> | <n> | <n> | <n> |
| 5-15°C | <n> | <n> | <n> | <n> |
| 15-20°C | <n> | <n> | <n> | <n> |
| 20-28°C | <n> | <n> | <n> | <n> |
| > 28°C | <n> | <n> | <n> | <n> |

## Top skip reasons (aggregated across all failures)

| Reason | Total skipped items |
|---|---:|
| warmth_outside_5c | <n> |
| occasion_mismatch | <n> |
| gender_mismatch | <n> |
| ... | ... |

## Hypotheses + recommended Linear tickets

### H1 — <hypothesis>
Evidence: <events>
Suggested ticket: `[Catalog]` / `[Engine]` / `[Data]` — <title>
Owner candidate: <person>
Priority: P1/P2/P3

(repeat per major finding)

## Open questions

- <items where data is ambiguous>
- <areas needing deeper investigation>
```

---

## Template 3 — `--hybrid` cross-ref section

Append to either fresh or logs report:

```markdown
## Cross-reference: live eval vs production logs

### Mismatches

| Scenario | Live eval result | Production log says | Hypothesis |
|---|---|---|---|
| M/22°C/casual | Build ✅ | 18 failures in 7d | Live qa-test ≠ real users (different wardrobes) |
| ... | ... | ... | ... |

### Validations

| Scenario | Live eval result | Production log says | Verdict |
|---|---|---|:---:|
| M/5°C/casual | wardrobe_gap | 45 wardrobe_gap_outerwear events | ✓ consistent |
| ... | ... | ... | ✓/✗ |

### Findings

- <observations from cross-ref>
- <regressions or improvements detected>
```

---

## Conventions

- Save to `wardrobe-backend/plans/reports/v05-eval-<YYMMDD-HHMM>-<mode>.md`
- Always include "Rubric: preliminary (AU-259 pending)" until anh Viet's rubric lands
- Link back to relevant Linear tickets (AU-252, AU-259, AU-260)
- Reference raw `eval_runs/<ts>/outfits.json` paths for reproducibility
- Sacrifice grammar for concision — bullet over prose
