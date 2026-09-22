# Changelog

## 0.1.0 — Initial public version

RaceDelta's first public release provides a deterministic, offline MoonBit race-strategy analysis workflow.

- CSV v1 parsing and strict validation for fictional lap-by-lap race data.
- End-of-lap timeline reconstruction for cumulative time, ranking, gap, stint, and race events.
- Configurable demonstration pace, tyre-degradation, and Green/Safety Car pit-loss model.
- Counterfactual replacement pit-strategy simulation against an unchanged opponent timeline.
- Performance, Strategic, and Opponent crossover detection with explanatory turning points.
- Stable Markdown strategy reports and a Native CLI for local CSV input and report output.
- 209 automated tests covering the public workflow and model invariants.

The pace and pit-loss parameters are teaching values, not official F1 data or a claim of precise real-race prediction.
