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

## Non-goals

- No real-time race API integration.
- No complete vehicle-physics simulation.
- No complete overtaking, DRS, traffic, or driver-behavior AI.
- No promise of precise prediction for real races.

## Open questions

- CSV v1 fields and missing-value rules are decided as specified above.
- Gap and position are decided and reconstructed from `lap_time_ms` as defined in M2.
- Tyre-degradation model parameter format.
- Pit-loss calculation under a Safety Car.
- Final CLI commands and parameter names.
- Whether final reports are terminal output, HTML, or both.

## Acceptance principles

- A third party must be able to run the project independently using the README.
- Include example data usable without network access.
- Include automated tests.
- Clearly identify the open-source license.
- Before final submission, check the MoonBit official website's upload and acceptance steps.
