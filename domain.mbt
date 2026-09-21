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
