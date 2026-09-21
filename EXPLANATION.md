# RaceDelta Crossover and Report Contract

## Scope

M5 explains one completed M4 counterfactual replay. It does not read files, parse command-line arguments, rerun a strategy simulation, automatically search strategies, or claim precise prediction of a real race.

The public functions are:

```moonbit
explain_strategy(config, simulation)
render_strategy_markdown(explanation)
```

`explain_strategy` validates the supplied pace model and the internal consistency of the simulation, then returns `StrategyExplanation` or a structured `ExplanationError`. Normal simulations with no crossover are valid and return empty crossover arrays.

## Crossover definitions

All values are integer milliseconds.

### Performance crossover

```text
performance_advantage_ms
  = actual_tyre_pace_delta_ms - simulated_tyre_pace_delta_ms
```

The deltas use the M3 compound, tyre age, weather, linear degradation, and cliff degradation. They do not include neutral lap time, pit loss, cumulative time, or opponent performance.

Positive means the alternative tyre state is theoretically faster; negative means the actual tyre state is theoretically faster; zero means equal modeled tyre performance.

### Strategic crossover

```text
cumulative_time_gain_ms
  = actual cumulative time - simulated cumulative time
```

Positive means the alternative strategy is cumulatively better; negative means it is worse; zero means equal. This is the complete M4 result, including modeled pit loss, tyre selection, and degradation.

### Opponent crossover

```text
simulated_signed_gap_to_opponent_ms
  = simulated target cumulative time - actual opponent cumulative time
```

Positive means the target trails the opponent; negative means the target leads; zero means a tie. The opponent keeps the observed M4 cumulative time.

## Zero and sign-change rules

Performance and strategic detection remember the last non-zero sign. Their first non-zero value produces an Equal-to-Faster/Slower or Equal-to-Better/Worse point. Later zeros do not emit points and do not reset the remembered sign. A later opposite non-zero sign emits one crossover, using the preceding non-zero value as `previous_value_ms`.

Opponent detection uses the same zero handling, but its first non-zero relation only establishes a baseline. It emits a point only when a later non-zero relation changes side: behind to ahead gives `TargetMovesAhead`, while ahead to behind gives `TargetFallsBehind`.

## Turning points

M5 emits turning points for adjacent-lap track-status and weather changes; actual and simulated pit stops; simulated Safety Car pit opportunities; performance, strategic, and opponent crossovers; relative position improvements/losses; and best/worst single-lap gain.

Safety Car pit opportunity savings are calculated as:

```text
green_pit_loss_ms - safety_car_pit_loss_ms
```

They describe only the lower modeled pit loss on that lap and do not attribute the whole final result to Safety Car timing.

Points sort by lap, then by this order:

1. TrackStatusChange
2. WeatherChange
3. ActualPitStop
4. SimulatedPitStop
5. SafetyCarPitOpportunity
6. PerformanceCrossover
7. StrategicCrossover
8. OpponentCrossover
9. RelativePositionGain
10. RelativePositionLoss
11. BestLapGain
12. WorstLapLoss

## Markdown report

`render_strategy_markdown` produces stable English Markdown with these sections:

1. `# RaceDelta Strategy Report`
2. `## Verdict`
3. `## Strategy Comparison`
4. `## Crossovers`
5. `## Key Turning Points`
6. `## Lap Trace`
7. `## Assumptions and Limitations`

The lap trace shows actual and simulated tyre compound/age/pit markers, positions, signed opponent gaps, and cumulative gain. Empty stop and crossover lists are rendered as `No stops` and `None` respectively.

## Time formatting and limitations

Durations are formatted from integer milliseconds without floating point: `6200` becomes `6.200 s`. Signed gains and gaps use an explicit sign: `+6.200 s`, `-0.450 s`, or `0.000 s`.

Only the target strategy changes. Other drivers retain observed lap times, weather and track status remain fixed, and no traffic, overtaking-cost, DRS, driver response, or vehicle-physics model is included. Default parameters are illustrative rather than official F1 data; report outcomes are explanatory counterfactuals, not precise predictions.
