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

## Non-goals

- No real-time race API integration.
- No complete vehicle-physics simulation.
- No complete overtaking, DRS, traffic, or driver-behavior AI.
- No promise of precise prediction for real races.

## Open questions

- Final CSV fields and missing-value rules.
- Whether gap and position are inputs or derived from lap times.
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
