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
