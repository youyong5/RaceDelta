# RaceDelta Agent Guide

## Scope and architecture

- RaceDelta is a MoonBit project. MoonBit is the primary development language.
- Keep core calculation logic separate from CLI or UI layers.
- Prefer deterministic, pure functions for core models so they are easy to test.
- The MVP is a race-strategy analysis and teaching tool. Do not claim it can precisely predict real races.

## Dependencies and data

- Prefer the MoonBit standard library. Obtain explicit user approval before adding a dependency.
- The MVP must not use real-time F1 APIs or any network dependency.
- Use bundled synthetic CSV data or publicly licensed CSV example data.

## Quality rules

- Every behavioral change requires corresponding tests.
- Keep code, documentation, and tests synchronized.
- After completing changes, run `moon fmt`, `moon check`, and `moon test`.

## MVP boundaries

- Until the MVP is complete, do not independently expand into real-time telemetry, full overtaking simulation, driver AI, or a complex graphical interface.

## Git and release safety

- Do not run `git commit`, `git push`, publish, or upload anything without explicit instruction.
