# RaceDelta Strategy Report

## Verdict

- Target: ALP
- Opponent: BRV
- Verdict: Worsened
- Time gain: -0.300 s
- Finish position: actual P1; simulated P1
- Positions gained/lost: 0
- Final opponent gap: actual -0.900 s; simulated -0.600 s

## Strategy Comparison

- Actual stops: Lap 3 -> MEDIUM
- Simulated stops: Lap 2 -> MEDIUM

## Crossovers

### Performance crossovers

- Lap 3: Actual becomes faster (0.000 s -> -0.220 s)

### Strategic crossovers

- Lap 2: Actual becomes better (0.000 s -> -22.000 s)

### Opponent crossovers

- Lap 2: Target falls behind opponent (-0.420 s -> +21.280 s)
- Lap 3: Target moves ahead of opponent (+21.280 s -> -1.040 s)

## Key Turning Points

- Lap 2: Simulated strategy pit stop.
- Lap 2: Actual becomes better. Impact: -22.000 s.
- Lap 2: Target falls behind opponent. Impact: +21.280 s.
- Lap 2: Relative position worsened.
- Lap 2: Worst single-lap loss. Impact: -22.000 s.
- Lap 3: Actual strategy pit stop.
- Lap 3: Actual becomes faster. Impact: -0.220 s.
- Lap 3: Target moves ahead of opponent. Impact: -1.040 s.
- Lap 3: Relative position improved.
- Lap 3: Best single-lap gain. Impact: +21.780 s.

## Lap Trace

| Lap | Actual tyre | Simulated tyre | Actual position | Simulated position | Actual gap to opponent | Simulated gap to opponent | Cumulative gain |
| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | SOFT age 3 | SOFT age 3 | P1 | P1 | -0.420 s | -0.420 s | 0.000 s |
| 2 | SOFT age 4 | SOFT age 4 (pit) | P1 | P2 | -0.720 s | +21.280 s | -22.000 s |
| 3 | SOFT age 5 (pit) | MEDIUM age 1 | P1 | P1 | -1.260 s | -1.040 s | -0.220 s |
| 4 | MEDIUM age 1 | MEDIUM age 2 | P1 | P1 | -0.900 s | -0.600 s | -0.300 s |

## Assumptions and Limitations

- Only the target driver's strategy changes.
- Other drivers retain their observed lap times.
- Weather and track status remain fixed.
- No traffic, overtaking-cost, DRS, or driver-response model is included.
- Default pace parameters are illustrative, not official F1 data.
- Results are explanatory counterfactuals, not precise predictions.
