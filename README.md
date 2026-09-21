# RaceDelta

> A MoonBit race strategy analyzer and counterfactual simulator.

**Status: Project scaffold / early development.** RaceDelta will combine race-process analysis with counterfactual strategy simulation as a teaching and analysis tool. Racing-analysis features are not implemented yet.

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

Race pace analysis, gap calculation, strategy analysis, counterfactual simulation, and a full CLI are still not implemented.

## Project direction

- [Product specification](PROJECT_SPEC.md)
- [Development plan](DEVELOPMENT_PLAN.md)

The MVP will use bundled synthetic or publicly licensed CSV example data and will not depend on live F1 APIs or network access.
