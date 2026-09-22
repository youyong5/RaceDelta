///|
/// CSV tyre compounds supported by RaceDelta CSV v1.
pub(all) enum Compound {
  Soft
  Medium
  Hard
  Intermediate
  Wet
} derive(Eq, Debug)

///|
pub extend Compound with Eq::{not_equal, equal}

///|
pub extend Compound with @debug.Debug::{to_repr}

///|
/// Race-control state shared by every driver on a lap.
pub(all) enum TrackStatus {
  Green
  SafetyCar
} derive(Eq, Debug)

///|
/// Track weather condition shared by every driver on a lap.
pub(all) enum Weather {
  Dry
  Damp
  Wet
} derive(Eq, Debug)

///|
/// One validated row in CSV v1.
pub struct LapRecord {
  lap : Int
  driver : String
  lap_time_ms : Int
  compound : Compound
  tyre_age_laps : Int
  pit : Bool
  track_status : TrackStatus
  weather : Weather
} derive(Eq, Debug)

///|
/// Canonically ordered and validated race input.
pub struct RaceData {
  records : Array[LapRecord]
} derive(Eq, Debug)

///|
/// Stable categories for CSV v1 parse and validation errors.
pub(all) enum RaceErrorCode {
  EmptyInput
  InvalidHeader
  FieldCount
  UnsupportedCsvSyntax
  InvalidInteger
  InvalidValue
  DuplicateDriverLap
  MissingLap
  InconsistentLaps
  InconsistentTrackStatus
  InconsistentWeather
  InvalidTyreTransition
} derive(Eq, Debug)

///|
/// A user-facing error. `line` is a one-based CSV line; zero denotes a global error.
pub struct RaceError {
  code : RaceErrorCode
  line : Int
  field : String
  message : String
} derive(Eq, Debug)

///|
/// A driver's complete race state at the end of one lap.
pub struct DriverLapState {
  lap : Int
  driver : String
  lap_time_ms : Int
  cumulative_time_ms : Int
  position : Int
  gap_to_leader_ms : Int
  interval_to_ahead_ms : Int?
  compound : Compound
  tyre_age_laps : Int
  pit : Bool
  track_status : TrackStatus
  weather : Weather
} derive(Eq, Debug)

///|
/// A consecutive tyre run, closed by a pit stop or by the final lap.
pub struct Stint {
  driver : String
  stint_number : Int
  start_lap : Int
  end_lap : Int
  compound : Compound
  start_tyre_age_laps : Int
  end_tyre_age_laps : Int
  lap_count : Int
  total_time_ms : Int
  ended_by_pit : Bool
} derive(Eq, Debug)

///|
/// Details of an end-of-lap pit stop.
pub struct PitStopEvent {
  lap : Int
  driver : String
  outgoing_compound : Compound
  next_compound : Compound?
} derive(Eq, Debug)

///|
/// A track-status change detected between two completed laps.
pub struct TrackStatusChangeEvent {
  lap : Int
  previous : TrackStatus
  current : TrackStatus
} derive(Eq, Debug)

///|
/// A weather change detected between two completed laps.
pub struct WeatherChangeEvent {
  lap : Int
  previous : Weather
  current : Weather
} derive(Eq, Debug)

///|
/// A driver's end-of-lap position change.
pub struct PositionChangeEvent {
  lap : Int
  driver : String
  previous_position : Int
  current_position : Int
} derive(Eq, Debug)

///|
/// A deterministically ordered race event.
pub(all) enum RaceEvent {
  PitStop(PitStopEvent)
  TrackStatusChange(TrackStatusChangeEvent)
  WeatherChange(WeatherChangeEvent)
  PositionChange(PositionChangeEvent)
} derive(Eq, Debug)

///|
/// The complete deterministic reconstruction produced from validated CSV data.
pub struct RaceAnalysis {
  drivers : Array[String]
  lap_count : Int
  states : Array[DriverLapState]
  stints : Array[Stint]
  events : Array[RaceEvent]
} derive(Eq, Debug)

///|
/// Demonstration fresh-tyre pace deltas by weather, in integer milliseconds.
pub(all) struct WeatherPaceDeltas {
  dry_ms : Int
  damp_ms : Int
  wet_ms : Int
} derive(Eq, Debug)

///|
/// Configurable pace and degradation parameters for one tyre compound.
pub(all) struct TyreProfile {
  compound : Compound
  fresh_deltas : WeatherPaceDeltas
  degradation_ms_per_lap : Int
  cliff_age_laps : Int
  cliff_extra_ms_per_lap : Int
} derive(Eq, Debug)

///|
/// Configurable modeled pit loss for each supported track status.
pub(all) struct PitLossProfile {
  green_pit_loss_ms : Int
  safety_car_pit_loss_ms : Int
} derive(Eq, Debug)

///|
/// The complete replaceable configuration for the explanatory pace model.
pub(all) struct PaceModelConfig {
  tyre_profiles : Array[TyreProfile]
  pit_loss_profile : PitLossProfile
} derive(Eq, Debug)

///|
/// Stable error categories for model configuration and calculations.
pub(all) enum ModelErrorCode {
  MissingTyreProfile
  DuplicateTyreProfile
  NegativeLinearDegradation
  InvalidCliffAge
  NegativeCliffExtraDegradation
  NegativeGreenPitLoss
  NegativeSafetyCarPitLoss
  InvalidTyreAge
  InvalidLapTime
  NonPositiveResult
} derive(Eq, Debug)

///|
/// A deterministic, user-facing model error suitable for future CLI output.
pub(all) struct ModelError {
  code : ModelErrorCode
  message : String
} derive(Eq, Debug)

///|
/// A planned end-of-lap pit stop and the compound used from the following lap.
pub(all) struct PlannedPitStop {
  pit_lap : Int
  next_compound : Compound
} derive(Eq, Debug)

///|
/// The target, opponent, and complete replacement pit plan for a replay.
pub(all) struct StrategyRequest {
  target_driver : String
  opponent_driver : String
  stops : Array[PlannedPitStop]
} derive(Eq, Debug)

///|
/// The target driver's simulated tyre state for one completed lap.
pub(all) struct SimulatedTyreState {
  compound : Compound
  tyre_age_laps : Int
  pit : Bool
} derive(Eq, Debug)

///|
/// Actual and simulated end-of-lap facts for a target-driver strategy replay.
pub(all) struct StrategyLapComparison {
  lap : Int
  neutral_lap_time_ms : Int
  weather : Weather
  track_status : TrackStatus
  actual_lap_time_ms : Int
  actual_cumulative_time_ms : Int
  actual_compound : Compound
  actual_tyre_age_laps : Int
  actual_pit : Bool
  actual_position : Int
  actual_signed_gap_to_opponent_ms : Int
  simulated_lap_time_ms : Int
  simulated_cumulative_time_ms : Int
  simulated_compound : Compound
  simulated_tyre_age_laps : Int
  simulated_pit : Bool
  simulated_position : Int
  simulated_signed_gap_to_opponent_ms : Int
  cumulative_time_gain_ms : Int
} derive(Eq, Debug)

///|
/// Final comparison between actual and simulated target-driver outcomes.
pub(all) struct StrategySummary {
  target_driver : String
  opponent_driver : String
  lap_count : Int
  actual_stop_count : Int
  simulated_stop_count : Int
  actual_total_time_ms : Int
  simulated_total_time_ms : Int
  time_gain_ms : Int
  actual_finish_position : Int
  simulated_finish_position : Int
  positions_gained : Int
  actual_final_signed_gap_to_opponent_ms : Int
  simulated_final_signed_gap_to_opponent_ms : Int
  opponent_gap_gain_ms : Int
} derive(Eq, Debug)

///|
/// A complete deterministic counterfactual replay result.
pub(all) struct StrategySimulation {
  request : StrategyRequest
  laps : Array[StrategyLapComparison]
  summary : StrategySummary
} derive(Eq, Debug)

///|
/// Stable categories for invalid replay requests and model failures.
pub(all) enum StrategyErrorCode {
  UnknownTargetDriver
  UnknownOpponentDriver
  SameDriver
  InvalidPitLap
  DuplicatePitLap
  InvalidModel
  NeutralLapFailure
  EstimatedLapFailure
  MissingLapState
} derive(Eq, Debug)

///|
/// A user-facing replay error; `lap` is populated for lap-specific failures.
pub(all) struct StrategyError {
  code : StrategyErrorCode
  lap : Int?
  message : String
} derive(Eq, Debug)

///|
/// Final time-based assessment of a counterfactual strategy.
pub(all) enum StrategyVerdict {
  Improved
  Worsened
  Unchanged
} derive(Eq, Debug)

///|
/// The independent relationship represented by a crossover point.
pub(all) enum CrossoverKind {
  Performance
  Strategic
  Opponent
} derive(Eq, Debug)

///|
/// The direction in which a crossover changes its relationship.
pub(all) enum CrossoverDirection {
  AlternativeBecomesFaster
  ActualBecomesFaster
  AlternativeBecomesBetter
  ActualBecomesBetter
  TargetMovesAhead
  TargetFallsBehind
} derive(Eq, Debug)

///|
/// A deterministic sign-change point in a strategy comparison.
pub(all) struct CrossoverPoint {
  lap : Int
  kind : CrossoverKind
  direction : CrossoverDirection
  previous_value_ms : Int
  current_value_ms : Int
} derive(Eq, Debug)

///|
/// The actual-versus-simulated effect measured on one lap.
pub(all) struct LapImpact {
  lap : Int
  lap_time_gain_ms : Int
  cumulative_time_gain_ms : Int
} derive(Eq, Debug)

///|
/// Stable categories for explainable strategy turning points.
pub(all) enum TurningPointKind {
  TrackStatusChange
  WeatherChange
  ActualPitStop
  SimulatedPitStop
  SafetyCarPitOpportunity
  PerformanceCrossover
  StrategicCrossover
  OpponentCrossover
  RelativePositionGain
  RelativePositionLoss
  BestLapGain
  WorstLapLoss
} derive(Eq, Debug)

///|
/// A concise, deterministic event used by the report and future CLI output.
pub(all) struct TurningPoint {
  lap : Int
  kind : TurningPointKind
  impact_ms : Int?
  message : String
} derive(Eq, Debug)

///|
/// A pit stop reconstructed from a completed strategy comparison.
pub(all) struct StrategyPitStop {
  lap : Int
  next_compound : Compound?
} derive(Eq, Debug)

///|
/// A deterministic explanation derived from, but not mutating, a simulation.
pub(all) struct StrategyExplanation {
  verdict : StrategyVerdict
  target_driver : String
  opponent_driver : String
  actual_stops : Array[StrategyPitStop]
  simulated_stops : Array[StrategyPitStop]
  performance_crossovers : Array[CrossoverPoint]
  strategic_crossovers : Array[CrossoverPoint]
  opponent_crossovers : Array[CrossoverPoint]
  turning_points : Array[TurningPoint]
  best_lap_gain : LapImpact?
  worst_lap_loss : LapImpact?
  summary : StrategySummary
  laps : Array[StrategyLapComparison]
} derive(Eq, Debug)

///|
/// Stable categories for explanation and report-generation failures.
pub(all) enum ExplanationErrorCode {
  InvalidModel
  TyreDeltaFailure
  EmptySimulation
  InconsistentSimulation
} derive(Eq, Debug)

///|
/// A user-facing explanation error; `lap` identifies a lap-specific failure.
pub(all) struct ExplanationError {
  code : ExplanationErrorCode
  lap : Int?
  message : String
} derive(Eq, Debug)

///|
pub extend TrackStatus with Eq::{not_equal, equal}

///|
pub extend TrackStatus with @debug.Debug::{to_repr}

///|
pub extend Weather with Eq::{not_equal, equal}

///|
pub extend Weather with @debug.Debug::{to_repr}

///|
pub extend LapRecord with Eq::{not_equal, equal}

///|
pub extend LapRecord with @debug.Debug::{to_repr}

///|
pub extend RaceData with Eq::{not_equal, equal}

///|
pub extend RaceData with @debug.Debug::{to_repr}

///|
pub extend RaceErrorCode with Eq::{not_equal, equal}

///|
pub extend RaceErrorCode with @debug.Debug::{to_repr}

///|
pub extend RaceError with Eq::{not_equal, equal}

///|
pub extend RaceError with @debug.Debug::{to_repr}

///|
pub extend DriverLapState with Eq::{not_equal, equal}

///|
pub extend DriverLapState with @debug.Debug::{to_repr}

///|
pub extend Stint with Eq::{not_equal, equal}

///|
pub extend Stint with @debug.Debug::{to_repr}

///|
pub extend PitStopEvent with Eq::{not_equal, equal}

///|
pub extend PitStopEvent with @debug.Debug::{to_repr}

///|
pub extend TrackStatusChangeEvent with Eq::{not_equal, equal}

///|
pub extend TrackStatusChangeEvent with @debug.Debug::{to_repr}

///|
pub extend WeatherChangeEvent with Eq::{not_equal, equal}

///|
pub extend WeatherChangeEvent with @debug.Debug::{to_repr}

///|
pub extend PositionChangeEvent with Eq::{not_equal, equal}

///|
pub extend PositionChangeEvent with @debug.Debug::{to_repr}

///|
pub extend RaceEvent with Eq::{not_equal, equal}

///|
pub extend RaceEvent with @debug.Debug::{to_repr}

///|
pub extend RaceAnalysis with Eq::{not_equal, equal}

///|
pub extend RaceAnalysis with @debug.Debug::{to_repr}

///|
pub extend WeatherPaceDeltas with Eq::{not_equal, equal}

///|
pub extend WeatherPaceDeltas with @debug.Debug::{to_repr}

///|
pub extend TyreProfile with Eq::{not_equal, equal}

///|
pub extend TyreProfile with @debug.Debug::{to_repr}

///|
pub extend PitLossProfile with Eq::{not_equal, equal}

///|
pub extend PitLossProfile with @debug.Debug::{to_repr}

///|
pub extend PaceModelConfig with Eq::{not_equal, equal}

///|
pub extend PaceModelConfig with @debug.Debug::{to_repr}

///|
pub extend ModelErrorCode with Eq::{not_equal, equal}

///|
pub extend ModelErrorCode with @debug.Debug::{to_repr}

///|
pub extend ModelError with Eq::{not_equal, equal}

///|
pub extend ModelError with @debug.Debug::{to_repr}

///|
pub extend PlannedPitStop with Eq::{not_equal, equal}

///|
pub extend PlannedPitStop with @debug.Debug::{to_repr}

///|
pub extend StrategyRequest with Eq::{not_equal, equal}

///|
pub extend StrategyRequest with @debug.Debug::{to_repr}

///|
pub extend SimulatedTyreState with Eq::{not_equal, equal}

///|
pub extend SimulatedTyreState with @debug.Debug::{to_repr}

///|
pub extend StrategyLapComparison with Eq::{not_equal, equal}

///|
pub extend StrategyLapComparison with @debug.Debug::{to_repr}

///|
pub extend StrategySummary with Eq::{not_equal, equal}

///|
pub extend StrategySummary with @debug.Debug::{to_repr}

///|
pub extend StrategySimulation with Eq::{not_equal, equal}

///|
pub extend StrategySimulation with @debug.Debug::{to_repr}

///|
pub extend StrategyErrorCode with Eq::{not_equal, equal}

///|
pub extend StrategyErrorCode with @debug.Debug::{to_repr}

///|
pub extend StrategyError with Eq::{not_equal, equal}

///|
pub extend StrategyError with @debug.Debug::{to_repr}

///|
pub extend StrategyVerdict with Eq::{not_equal, equal}

///|
pub extend StrategyVerdict with @debug.Debug::{to_repr}

///|
pub extend CrossoverKind with Eq::{not_equal, equal}

///|
pub extend CrossoverKind with @debug.Debug::{to_repr}

///|
pub extend CrossoverDirection with Eq::{not_equal, equal}

///|
pub extend CrossoverDirection with @debug.Debug::{to_repr}

///|
pub extend CrossoverPoint with Eq::{not_equal, equal}

///|
pub extend CrossoverPoint with @debug.Debug::{to_repr}

///|
pub extend LapImpact with Eq::{not_equal, equal}

///|
pub extend LapImpact with @debug.Debug::{to_repr}

///|
pub extend TurningPointKind with Eq::{not_equal, equal}

///|
pub extend TurningPointKind with @debug.Debug::{to_repr}

///|
pub extend TurningPoint with Eq::{not_equal, equal}

///|
pub extend TurningPoint with @debug.Debug::{to_repr}

///|
pub extend StrategyPitStop with Eq::{not_equal, equal}

///|
pub extend StrategyPitStop with @debug.Debug::{to_repr}

///|
pub extend StrategyExplanation with Eq::{not_equal, equal}

///|
pub extend StrategyExplanation with @debug.Debug::{to_repr}

///|
pub extend ExplanationErrorCode with Eq::{not_equal, equal}

///|
pub extend ExplanationErrorCode with @debug.Debug::{to_repr}

///|
pub extend ExplanationError with Eq::{not_equal, equal}

///|
pub extend ExplanationError with @debug.Debug::{to_repr}
