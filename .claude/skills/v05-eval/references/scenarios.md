# V05 Eval Scenario Matrix

## Default scenarios (8 cells)

Picked for coverage + diagnostic value. Includes 2 known-failure (regression) + 1 known-success (positive control) + 5 exploratory.

| # | gender | temp_c | bucket | occasion | mood | rationale |
|---|---|---:|---|---|---|---|
| 1 | M | 22 | WARM | casual | — | Regression — baseline first eval (260513-001819) |
| 2 | W | 15 | MILD↑ | casual | confident | Regression — bracket run (260513-002509) |
| 3 | M | 30 | HOT | casual | — | Known fail before fix — now expect common_essential injection |
| 4 | M | 5 | COOL | casual | — | Known fail before fix — now expect wardrobe_gap |
| 5 | W | 5 | COOL | casual | low_energy | Counter to #4: W wardrobe richer, see if escapes gap |
| 6 | W | 18 | MILD | work | playful | Known best (75% success) — positive control |
| 7 | M | 28 | WARM↑ | work | grounded | New: boundary + work + mood combo |
| 8 | W | 32 | HOT | event | confident | New: extreme HOT + W + event + mood |

## Climate buckets recap

From `engine_v05_constants.warmth_constraint(temp_c)`:

| Bucket | Range | allowed_warmth | l3_required |
|---|---|---|:---:|
| HOT | > 28°C | [1] | × |
| WARM | 20-28°C | [1, 2] | × |
| MILD | 15-20°C | [2, 3] | × |
| COOL | < 15°C | [3, 4, 5] | ✓ |

## CSV override format

User can pass `--scenarios "<gender>/<temp_c>/<occasion>[/<mood>],..."`. Example:

```
--scenarios "M/22/casual,W/5/work/confident,U/18/event/playful"
```

## Custom scenarios checklist

When designing new scenarios, ensure:
- [ ] Covers a climate bucket boundary (29°C, 19°C, 14°C are sensitive)
- [ ] Tests mood combinations not in default matrix
- [ ] Exercises deep try_another sessions (≥10 calls) to probe distance-floor exhaustion / ladder behavior
- [ ] Includes occasion variants (casual + work + event)
- [ ] Tests across genders (M and W) for symmetry

## Rate limit budget

Default 8 scenarios × 5 calls = 40 API calls. With 10s spacing → ~7 min wall time. Backend rate limit windows:
- `/api/login`: 5/min — login once, reuse token
- `/api/v05/recommendation/*`: 20/min — 8 scenarios will hit 429 several times → built-in 429 retry handles it

Bigger matrices (15+ scenarios) recommend `--skip-images` to keep total runtime tractable.

## Special scenario types

### Regression check (post-engine-change)
Always include scenarios 1, 2, 6 (known baselines). If their success rate drops, regression.

### Failure surface mapping (after seeding new items / catalog change)
Always include scenarios 3, 4, 5 (climate edges). Track:
- Does fewer wardrobe_gap fire?
- Does common_essential injection rate go up (good) or down (bad)?

### Bug repro (after Linear bug filed)
Add custom scenario matching bug input. E.g. "U gender at 14.9°C with style_feedback='polished'".
