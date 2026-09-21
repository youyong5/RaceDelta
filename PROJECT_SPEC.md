# RaceDelta Product Specification

## Overview

**Project name:** RaceDelta

**One-line description:** A MoonBit race strategy analyzer and counterfactual simulator.

## Core idea

Combine GapTrace-style race-process analysis with Crossover-style counterfactual strategy simulation.

## MVP features

- Import lap-by-lap CSV data.
- Reconstruct driver stints, tyre compounds, pit windows, cumulative time, and relative gaps.
- Analyze pace changes and key turning points in an actual race.
- Select one target driver and one opponent.
- Adjust the target driver's pit lap or tyre compound.
- Re-simulate and compare actual and counterfactual results.
- Distinguish performance crossover from strategic crossover.
- Produce explainable written conclusions, not only a final number.
- Support dry, damp, and wet track states, plus Safety Car scenarios.
- Analyze multiple drivers while focusing each strategy replay on one target driver and one opponent.

## CSV v1 format

The header must be exactly this text, in this order:

```text
lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather
```

| Field | Rules |
| --- | --- |
| `lap` | Integer starting at 1. Each driver starts at lap 1 and laps are continuous in the MVP. |
| `driver` | Non-empty, case-sensitive string. Examples use short uppercase codes such as `ALP` and `BRV`. |
| `lap_time_ms` | Complete lap time in milliseconds; integer greater than 0. Floating-point seconds are not used. |
| `compound` | One of `SOFT`, `MEDIUM`, `HARD`, `INTERMEDIATE`, or `WET`. |
| `tyre_age_laps` | Tyre laps completed at the end of this lap; integer at least 1. A driver's first lap may be greater than 1 for used starting tyres. |
| `pit` | Exactly lowercase `true` or `false`. `true` means the driver pits at the end of this lap; its loss is included in `lap_time_ms`, and the new tyre begins next lap. |
| `track_status` | `GREEN` or `SAFETY_CAR`. |
| `weather` | `DRY`, `DAMP`, or `WET`. |

### Parsing rules

- Only the exact header and order above are accepted.
- Windows CRLF and LF line endings are accepted. Fully blank lines are ignored, and ordinary leading/trailing cell whitespace is trimmed.
- Quoted fields, embedded commas, embedded newlines, and comment lines are not supported.
- Rows may be supplied in any order. Valid records are canonically ordered by ascending `lap`, then lexicographic `driver`.
- Unknown enum values are errors; they are never substituted silently.

### MVP data constraints

- Each `(driver, lap)` pair appears once. Every driver has the same continuous laps, starting at 1.
- Every driver has identical `track_status` and `weather` for a given lap.
- If the preceding lap has `pit=false`, the next lap keeps its compound and increments `tyre_age_laps` by 1.
- If the preceding lap has `pit=true`, the next lap has `tyre_age_laps=1`; its compound may remain the same or change.
- Tyre compounds are not restricted by weather, so deliberately unsuitable-strategy and crossover inputs remain expressible.
- `gap` and `position` are not input fields. They are decided to be derived from `lap_time_ms` in M2.
- Retirements, missed laps, lapping, and mid-race entries are not supported in the MVP.

## M2 race timeline reconstruction

M2 reconstructs deterministic, end-of-lap facts from validated CSV v1 data. All calculations remain integer milliseconds; it does not model unobserved in-lap movement or change Safety Car gaps.

### Cumulative time, positions, and gaps

- `cumulative_time_ms(driver, N)` is the sum of that driver's `lap_time_ms` from lap 1 through lap `N`.
- At the end of each lap, drivers are ordered by ascending cumulative time. Equal cumulative times use lexicographic `driver` order, producing unique positions `1, 2, …`.
- `gap_to_leader_ms` is the driver's cumulative time minus the lap leader's cumulative time. The leader is always zero; a lexicographically second driver tied on time also has gap zero.
- `interval_to_ahead_ms` is the driver's cumulative time minus that of the immediately preceding position. P1 has no interval and is represented as `None`.
- `signed_gap_ms(driver, opponent, lap)` is driver cumulative time minus opponent cumulative time: positive means the driver trails, negative means the driver leads, and zero means a tie. Unknown drivers or laps return `None`.
- Positions and gaps describe the state after crossing the timing line for a completed lap. They are not real-time within-lap telemetry.

Safety Car laps are reconstructed from the supplied `lap_time_ms` exactly like any other lap. M2 does not compress or recalculate gaps; Safety Car effects on simulated outcomes remain a later modeling concern.

### Stints

A stint starts at lap 1 or on the lap after a `pit=true` record. A pit lap belongs to the outgoing stint, including its full lap time and any embedded pit loss. The following lap starts a new stint with tyre age 1. A new stint is created even if the compound remains unchanged after the stop. The last stint closes on the race's final lap.

Each stint records its driver, one-based stint number, start/end lap, compound, start/end tyre age, lap count, integer total time, and whether it ended by a pit stop.

### Race events

M2 emits these events:

- `PitStop`: emitted for every `pit=true` lap with lap, driver, outgoing compound, and the next lap's compound when one exists; a final-lap stop has `None` for next compound.
- `TrackStatusChange`: emitted from lap 2 when the shared track status differs from the preceding lap.
- `WeatherChange`: emitted from lap 2 when the shared weather differs from the preceding lap.
- `PositionChange`: emitted from lap 2 for each driver whose end-of-lap position differs from the preceding lap.

Events are ordered by lap, then by type (`TrackStatusChange`, `WeatherChange`, `PitStop`, `PositionChange`), then by lexicographic driver when a type has multiple drivers. This type ordering provides stable output only; it does not claim to represent the real within-lap order of events.

`RaceAnalysis` stores drivers in lexicographic order, states by lap then driver, stints by driver then stint number, and events in this stable event order.

## M3 explanatory pace model

The [pace model](MODEL.md) is a deterministic, integer-millisecond model for tyre pace deltas and current-lap pit loss. Its neutral lap time is an anchor after removing only these modeled effects; it can still contain driver/car pace, circuit characteristics, fuel, traffic, mistakes, Safety Car slowing, and other unexplained factors. M3 does not attempt to infer them.

```text
tyre_pace_delta_ms
  = fresh_delta_ms(compound, weather)
  + (tyre_age_laps - 1) * degradation_ms_per_lap
  + max(0, tyre_age_laps - cliff_age_laps) * cliff_extra_ms_per_lap

predicted_lap_time_ms
  = neutral_lap_time_ms + tyre_pace_delta_ms + current_lap_pit_loss_ms
```

Tyre age starts at 1; cliff loss begins only after the cliff age. A negative pace delta is faster than the neutral anchor. The inverse calculation removes the same tyre delta and modeled pit loss from an observed lap, and estimate/derive round-trip exactly with identical valid conditions.

Pit loss is zero for `pit=false`; for a pit lap it is selected by track status. The default demonstration configuration uses `22000 ms` under `GREEN` and `12000 ms` under `SAFETY_CAR`. Safety Car slowing itself remains in the neutral anchor rather than being added by this model.

The default profile values are replaceable demonstration assumptions for explaining strategy relationships. They are not official parameters for any real circuit or tyres and must not be presented as real F1 predictions. The basic tyre degradation and pit-loss rules are decided; M4 uses them for a deterministic, complete replacement strategy replay. Performance-crossover search remains later work.

## M4 counterfactual strategy replay

M4 provides a deterministic library-level replay for one target driver against one selected opponent. Its public entry point is `simulate_strategy(data, config, request)`, which returns either a complete `StrategySimulation` or a structured `StrategyError`.

- `StrategyRequest` contains a target driver, an opponent driver, and a complete list of `PlannedPitStop` values.
- A planned stop occurs at the end of its `pit_lap`; the selected `next_compound` begins on the following lap. Stops must be on laps `1 <= pit_lap < lap_count`, are normalized by ascending lap, and duplicate laps are rejected. A stop may select the same compound to obtain fresh tyres.
- The plan replaces the target driver's actual pit strategy completely. The target starts with the actual first-lap compound and tyre age, but no actual target pit stop or later actual target tyre transition is reused unless the plan explicitly reproduces it.
- For every target lap, M4 derives a neutral anchor from the actual record using the M3 model, then estimates the simulated lap with the planned tyre state and the actual lap's weather and track status. All values remain integer milliseconds.
- Every non-target driver keeps the actual CSV lap times and cumulative times. The target's simulated cumulative time is ranked against those unchanged rivals after each lap, with lexicographic driver names breaking exact timing ties.
- `StrategyLapComparison` exposes actual and simulated lap/cumulative times, tyre states, pits, positions, signed opponent gaps, weather, track status, neutral anchor, and cumulative time gain. Signed gaps are target cumulative time minus opponent cumulative time: positive means the target trails.
- `StrategySummary` exposes actual and simulated stop counts, final totals, finish positions, signed opponent gaps, and gains. Time and gap gains are actual minus simulated; positions gained are actual finish position minus simulated finish position.

M4 is not a physics or traffic simulation. It does not alter other drivers, infer overtakes within a lap, model traffic/DRS/driver behavior, search strategies, classify crossovers, read files, or provide a complete CLI. See [SIMULATION.md](SIMULATION.md) for the full replay contract and error behavior.

## M5 crossover detection and explanations

M5 derives deterministic crossover points and an English Markdown explanation from an already-completed `StrategySimulation`; it never reruns the simulation.

- A **performance crossover** compares only M3 tyre pace deltas: `actual_tyre_pace_delta_ms - simulated_tyre_pace_delta_ms`. Positive means the alternative tyre state is theoretically faster; negative means the actual tyre state is theoretically faster. Neutral anchors, pit loss, cumulative time, and opponent behaviour are excluded.
- A **strategic crossover** uses M4 `cumulative_time_gain_ms`, defined as actual target cumulative time minus simulated target cumulative time. Positive means the alternative is cumulatively better; negative means it is worse. This includes the modeled effects of pit loss, tyre choice, and degradation.
- An **opponent crossover** uses M4 `simulated_signed_gap_to_opponent_ms`, defined as simulated target cumulative time minus actual opponent cumulative time. Positive means the target trails; negative means the target leads.

For performance and strategic relationships, the first non-zero value produces an Equal-to-non-equal point. Thereafter zero values neither produce an event nor erase the last non-zero relationship. A subsequent opposite sign produces exactly one crossover and records the last non-zero value as `previous_value_ms`. Thus positive → zero → positive is not repeated, while negative → zero → positive changes at the later positive lap. For opponent relationships, the first non-zero relationship only establishes the baseline; an event is emitted only when a later non-zero value has the opposite sign, with zero values handled the same way.

M5 also emits stable turning points for status/weather changes, actual and simulated pits, simulated Safety Car pit opportunities, the three crossover kinds, changes in relative actual-versus-simulated position, and the best positive / worst negative single-lap gain. Points sort by ascending lap, then by the documented type order in [EXPLANATION.md](EXPLANATION.md). Safety Car opportunity savings are calculated from the supplied `PaceModelConfig`, never hard-coded.

`explain_strategy(config, simulation)` returns a `StrategyExplanation` or a structured `ExplanationError`; `render_strategy_markdown(explanation)` renders its stable report. The report includes verdict, stop comparison, crossover lists, turning points, a lap trace, and explicit model limitations. Its time values are formatted from integer milliseconds to seconds with three decimals. See [EXPLANATION.md](EXPLANATION.md) for the full contract.

## Non-goals

- No real-time race API integration.
- No complete vehicle-physics simulation.
- No complete overtaking, DRS, traffic, or driver-behavior AI.
- No promise of precise prediction for real races.

## Open questions

- CSV v1 fields and missing-value rules are decided as specified above.
- Gap and position are decided and reconstructed from `lap_time_ms` as defined in M2.
- The tyre degradation and pit-loss model rules are decided in [MODEL.md](MODEL.md); callers may replace parameters through `PaceModelConfig`.
- M4 replay semantics and its complete replacement-pit-plan input are decided in [SIMULATION.md](SIMULATION.md).
- Automatic strategy search remains a later optional capability; M5 only explains an explicit M4 replay.
- Final CLI commands and parameter names.
- Whether final reports are terminal output, HTML, or both.

## Acceptance principles

- A third party must be able to run the project independently using the README.
- Include example data usable without network access.
- Include automated tests.
- Clearly identify the open-source license.
- Before final submission, check the MoonBit official website's upload and acceptance steps.
