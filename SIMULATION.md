# RaceDelta Counterfactual Strategy Replay

## Purpose

M4 replays one explicit, complete replacement pit strategy for one target driver against one selected opponent. It is a deterministic, offline library feature for explaining modeled time and position differences. It is not a real-race prediction, optimisation engine, or recommendation system.

The public entry point is:

```moonbit
simulate_strategy(data, config, request)
```

It returns `Result[StrategySimulation, StrategyError]`.

## Input contract

`StrategyRequest` contains:

- `target_driver`: a driver present in the validated `RaceData`.
- `opponent_driver`: a different driver present in the same race.
- `stops`: an array of `PlannedPitStop { pit_lap, next_compound }`.

A planned stop happens at the end of `pit_lap`; `next_compound` starts on the following lap with tyre age 1. The allowed range is `1 <= pit_lap < lap_count`. Stops are sorted by ascending lap before replay, duplicate pit laps are errors, and a same-compound stop is valid because it supplies fresh tyres.

The request is a complete replacement plan. The target begins on the actual first-lap compound and tyre age, but its actual later pit flags, compounds, and tyre ages are not copied into the simulation. If the plan has no stops, the target does not pit in the replay.

## Replay method

For each target-driver lap, M4:

1. Reconstructs the validated actual timeline with M2.
2. Derives a neutral anchor from that target's actual lap using the M3 pace and pit-loss configuration.
3. Estimates the target's simulated lap using the planned tyre state and pit flag, while preserving that actual lap's weather and track status.
4. Adds the simulated lap to the target's simulated cumulative time.
5. Ranks that new target cumulative time against all other drivers' unchanged actual cumulative times. Equal times use lexicographic driver order.

This preserves unmodeled effects inside the per-lap neutral anchor, such as underlying car/driver pace, circuit characteristics, traffic, mistakes, fuel effects, and Safety Car slowing. The only replaced components are the target tyre state and the current-lap modeled pit loss.

All calculations use integer milliseconds. The model configuration is supplied by the caller; the default teaching parameters are documented in [MODEL.md](MODEL.md), including `22000 ms` Green-flag and `12000 ms` Safety Car pit loss.

## Output contract

`StrategySimulation` contains the normalized request, one `StrategyLapComparison` per lap, and a `StrategySummary`.

Each comparison includes actual and simulated lap time, cumulative time, compound, tyre age, pit flag, position, and signed gap to the selected opponent, as well as the actual weather, track status, neutral anchor, and cumulative time gain.

Signed opponent gap is:

```text
target cumulative time - opponent cumulative time
```

Positive means the target trails; negative means the target leads. `cumulative_time_gain_ms`, total time gain, and opponent-gap gain are actual minus simulated. `positions_gained` is actual finish position minus simulated finish position, so a positive value means an improvement.

## Errors

The replay rejects unknown target or opponent drivers, identical target/opponent selections, out-of-range or duplicate planned pit laps, invalid pace models, impossible neutral-anchor derivations, and impossible estimated replay laps. Errors use stable `StrategyErrorCode` values and carry a lap number when the failure is lap-specific.

## Boundaries

M4 does not:

- read files or provide a complete CLI;
- change rival lap times, pit plans, or tyre states;
- model within-lap overtakes, DRS, traffic, driver behavior, or vehicle physics;
- search or optimise alternative strategies;
- classify performance or strategic crossovers; or
- claim precise prediction of any real race.
