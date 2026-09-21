# RaceDelta Pace Model

## Purpose and boundaries

This M3 model is a deterministic, integer-millisecond explanation of how tyre conditions and a modeled pit stop affect a lap-time anchor. It is intended to make later strategy comparisons inspectable; it is not a real F1 prediction model.

`neutral_lap_time_ms` is the lap-time anchor after removing the model's tyre and current-lap pit-loss effects. It may still include driver and car pace, circuit characteristics, fuel change, traffic, mistakes, Safety Car slowing, and other unexplained factors. M3 does not infer those factors.

M4 may derive a neutral anchor from an observed lap and replace strategy-related components. M3 does not perform a counterfactual simulation, crossover search, file read, or CLI operation.

## Formulae

All values are integer milliseconds.

```text
tyre_pace_delta_ms
  = fresh_delta_ms(compound, weather)
  + (tyre_age_laps - 1) * degradation_ms_per_lap
  + max(0, tyre_age_laps - cliff_age_laps) * cliff_extra_ms_per_lap
```

Tyre age begins at 1. Therefore age 1 has no linear degradation; at exactly `cliff_age_laps` there is still no cliff loss, which starts on the next lap. A negative delta means faster than the neutral anchor, while a positive delta means slower.

```text
predicted_lap_time_ms
  = neutral_lap_time_ms + tyre_pace_delta_ms + current_lap_pit_loss_ms

neutral_lap_time_ms
  = observed_lap_time_ms - tyre_pace_delta_ms - current_lap_pit_loss_ms
```

`current_lap_pit_loss_ms` is zero when `pit=false`; otherwise it is selected by track status. With identical conditions, deriving a neutral anchor and then estimating it restores the observed lap time exactly, provided both results are positive.

Safety Car slowing itself is not added to the pit-loss model. It remains part of the neutral anchor supplied or derived for that lap.

## Default demonstration parameters

The following parameters are centralized in `default_pace_model_config()`. They are deliberately simple, explainable demonstration assumptions for strategy relationships. They are not official data for any real circuit or tyre, and must not be presented as a real F1 prediction. Callers can replace the complete configuration.

| Compound | DRY fresh delta | DAMP fresh delta | WET fresh delta | Linear degradation/lap | Cliff age | Cliff extra/lap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| SOFT | -700 | 6500 | 24000 | 120 | 12 | 240 |
| MEDIUM | 0 | 7000 | 25000 | 80 | 20 | 180 |
| HARD | 500 | 7500 | 26000 | 55 | 30 | 120 |
| INTERMEDIATE | 4000 | 0 | 3500 | 95 | 22 | 180 |
| WET | 9000 | 3000 | 500 | 70 | 28 | 140 |

Default modeled pit loss is `22000 ms` under `GREEN` and `12000 ms` under `SAFETY_CAR`.

These values make a fresh dry SOFT quickest, give SOFT earlier and steeper degradation, allow MEDIUM and HARD long-run advantages, make INTERMEDIATE quickest in DAMP conditions, make WET quickest in WET conditions, and make a Safety Car pit loss smaller than a green-flag loss.

## Configuration validation

`PaceModelConfig` requires exactly one profile for each of the five compounds. Linear and cliff-extra degradation values must be non-negative, cliff age must be at least 1, and both pit losses must be non-negative. Calculations additionally reject tyre ages below 1, non-positive input lap times, and non-positive derived or estimated results.
