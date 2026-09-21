# RaceDelta Development Plan

**Competition target date:** 2026-09-30

## M0 — Project initialization, conventions, license, and baseline verification — Complete

**Goal:** Establish a runnable MoonBit scaffold, repository conventions, license, and baseline commands.

**Done when:** The scaffold, documentation, license, and validation commands are present and the generated starter example remains runnable.

## M1 — CSV data structures, parsing, and input validation — Complete

**Goal:** Define lap-by-lap CSV input structures and validate parse errors and missing data.

**Done when:** Local example CSV data can be parsed and invalid input produces tested, actionable errors.

## M2 — Cumulative time, gaps, stints, and race-event analysis — Not started

**Goal:** Reconstruct race timelines and identify stints, gaps, and notable events.

**Done when:** Tested deterministic analysis derives these values from CSV input.

## M3 — Tyre degradation, track state, and pit-loss models

**Goal:** Model tyre degradation, dry/damp/wet states, and pit-stop loss including Safety Car conditions.

**Done when:** Model assumptions are documented and verified by focused tests.

## M4 — Counterfactual strategy simulator

**Goal:** Simulate target-driver pit-lap or tyre-compound alternatives against one selected opponent.

**Done when:** Actual and counterfactual outcomes can be compared reproducibly from the same input.

## M5 — Turning-point explanations and report output

**Goal:** Explain performance and strategic crossovers in readable reports.

**Done when:** Reports distinguish the two crossover types and cite the modeled factors behind the result.

## M6 — Example data, tests, README, demonstration, and competition acceptance

**Goal:** Package a documented, offline-capable MVP for demonstration and competition review.

**Done when:** Example data, automated tests, README instructions, and demonstration material are complete; MoonBit upload and acceptance requirements have been checked before final submission.
