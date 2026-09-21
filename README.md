# RaceDelta

> A MoonBit race strategy analyzer and counterfactual simulator.

**Status: Early development.** RaceDelta is building a race-process analysis and counterfactual strategy simulation teaching tool. It currently validates CSV input, reconstructs deterministic end-of-lap timelines, replays an explicit replacement pit plan, detects crossover points, and renders Markdown strategy reports.

## Current commands

The generated MoonBit starter example can be checked and tested locally:

```sh
moon fmt
moon check
moon test
moon run cmd/main
```

The `moon run cmd/main` example currently prints the template greeting; it is not a race-analysis CLI.

## CSV v1 input

The current library validates CSV v1 input with these fields:

```text
lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather
```

Offline fictional examples are available at [basic_race.csv](examples/basic_race.csv) and [mixed_conditions.csv](examples/mixed_conditions.csv). The full validation rules are in the [product specification](PROJECT_SPEC.md#csv-v1-format).

## Current timeline reconstruction

From validated CSV v1 data, the library currently reconstructs integer-millisecond cumulative times, end-of-lap positions, leader gaps, intervals to the car ahead, signed driver-to-driver gaps, tyre stints, and stable pit/status/weather/position events. Safety Car lap times are accumulated exactly as supplied; M2 does not compress gaps.

The project still has no complete CLI, automatic strategy-search workflow, or final competition delivery.

## Current explanatory pace model

RaceDelta now includes a configurable, integer-millisecond pace model for fresh-tyre weather deltas, linear and cliff degradation, plus modeled Green-flag and Safety Car pit losses. See [MODEL.md](MODEL.md) for the formulae and demonstration parameters.

The default parameters are explainable teaching assumptions, not official data for real F1 tyres or circuits, and do not constitute a real-race prediction.

## Current counterfactual replay

The library can replay a complete, explicit set of end-of-lap pit stops for one target driver against one opponent. It derives a neutral anchor from each actual target lap, applies the selected tyres and Green-flag or Safety Car pit loss, and ranks the resulting target cumulative time against unchanged real rivals. The output preserves actual and simulated per-lap facts plus final time, position, and signed-gap comparisons.

A plan replaces the target driver's actual pit plan: an unplanned real pit does not carry into the replay. This is deterministic teaching-model output, not a real-race prediction or a strategy recommendation. See [SIMULATION.md](SIMULATION.md) for the input, output, assumptions, and boundaries.

## Current explanations and reports

The core library can explain an already-completed counterfactual replay with performance, strategic, and opponent crossover detection; stable key turning points; and an English Markdown report. The report shows the target/opponent verdict, stop comparison, crossover lists, lap trace, and explicit limitations. It does not search for strategies or make a precise real-race prediction. See [EXPLANATION.md](EXPLANATION.md) for the definitions and report contract.

## Project direction

- [Product specification](PROJECT_SPEC.md)
- [Development plan](DEVELOPMENT_PLAN.md)
- [Pace-model assumptions](MODEL.md)
- [Counterfactual replay contract](SIMULATION.md)
- [Crossover and report contract](EXPLANATION.md)

The MVP will use bundled synthetic or publicly licensed CSV example data and will not depend on live F1 APIs or network access.
