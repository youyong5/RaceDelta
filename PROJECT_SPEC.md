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

## Non-goals

- No real-time race API integration.
- No complete vehicle-physics simulation.
- No complete overtaking, DRS, traffic, or driver-behavior AI.
- No promise of precise prediction for real races.

## Open questions

- CSV v1 fields and missing-value rules are decided as specified above.
- Gap and position are decided to be derived from `lap_time_ms` in M2.
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
