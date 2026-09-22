///|
priv struct TimedRecord {
  record : LapRecord
  cumulative_time_ms : Int
}

///|
fn cumulative_for(totals : Array[(String, Int)], driver : String) -> Int {
  for (known_driver, total) in totals {
    if known_driver == driver {
      return total
    }
  }
  0
}

///|
fn update_cumulative(
  totals : Array[(String, Int)],
  driver : String,
  cumulative_time_ms : Int,
) -> Unit {
  for index = 0; index < totals.length(); index = index + 1 {
    if totals[index].0 == driver {
      totals[index] = (driver, cumulative_time_ms)
      return
    }
  }
  totals.push((driver, cumulative_time_ms))
}

///|
fn time_records(data : RaceData) -> Array[TimedRecord] {
  let totals : Array[(String, Int)] = []
  let timed : Array[TimedRecord] = []
  for record in data.records {
    let cumulative_time_ms = cumulative_for(totals, record.driver) +
      record.lap_time_ms
    update_cumulative(totals, record.driver, cumulative_time_ms)
    timed.push({ record, cumulative_time_ms, })
  }
  timed
}

///|
fn rank_of(ranking : Array[TimedRecord], driver : String) -> Int {
  for index = 0; index < ranking.length(); index = index + 1 {
    if ranking[index].record.driver == driver {
      return index + 1
    }
  }
  0
}

///|
fn build_states(
  data : RaceData,
  drivers : Array[String],
) -> Array[DriverLapState] {
  let timed = time_records(data)
  let states : Array[DriverLapState] = []
  let driver_count = drivers.length()
  let lap_count = data.records.length() / driver_count
  for lap = 1; lap <= lap_count; lap = lap + 1 {
    let start = (lap - 1) * driver_count
    let ranking : Array[TimedRecord] = []
    for offset = 0; offset < driver_count; offset = offset + 1 {
      ranking.push(timed[start + offset])
    }
    ranking.sort_by((left, right) => {
      if left.cumulative_time_ms != right.cumulative_time_ms {
        left.cumulative_time_ms - right.cumulative_time_ms
      } else {
        left.record.driver.compare(right.record.driver)
      }
    })
    let leader_time_ms = ranking[0].cumulative_time_ms
    for offset = 0; offset < driver_count; offset = offset + 1 {
      let timed_record = timed[start + offset]
      let position = rank_of(ranking, timed_record.record.driver)
      let interval_to_ahead_ms = if position == 1 {
        None
      } else {
        Some(
          timed_record.cumulative_time_ms -
          ranking[position - 2].cumulative_time_ms,
        )
      }
      let record = timed_record.record
      states.push({
        lap: record.lap,
        driver: record.driver,
        lap_time_ms: record.lap_time_ms,
        cumulative_time_ms: timed_record.cumulative_time_ms,
        position,
        gap_to_leader_ms: timed_record.cumulative_time_ms - leader_time_ms,
        interval_to_ahead_ms,
        compound: record.compound,
        tyre_age_laps: record.tyre_age_laps,
        pit: record.pit,
        track_status: record.track_status,
        weather: record.weather,
      })
    }
  }
  states
}

///|
/// Reconstruct a deterministic end-of-lap timeline from validated CSV v1 data.
///
/// `data` must come from `parse_race_csv`; the result contains cumulative
/// milliseconds, positions, leader gaps, intervals, stints, and stable events.
/// A positive signed driver-to-driver gap means the named driver trails.
pub fn analyze_race(data : RaceData) -> RaceAnalysis {
  let drivers : Array[String] = []
  for record in data.records {
    if record.lap == 1 {
      drivers.push(record.driver)
    }
  }
  drivers.sort_by((left, right) => left.compare(right))
  let lap_count = data.records.length() / drivers.length()
  let states = build_states(data, drivers)
  let stints = build_stints(drivers, states)
  let events = build_events(drivers, states, lap_count)
  { drivers, lap_count, states, stints, events, }
}

///|
/// Find one driver's end-of-lap state, or `None` when the driver or lap is absent.
///
/// `analysis` is not mutated. The returned state is the end-of-lap state for
/// the exact `driver` and one-based `lap` query.
pub fn find_lap_state(
  analysis : RaceAnalysis,
  driver : String,
  lap : Int,
) -> DriverLapState? {
  for state in analysis.states {
    if state.driver == driver && state.lap == lap {
      return Some(state)
    }
  }
  None
}

///|
/// Return driver time minus opponent time at a lap, or `None` for an unknown query.
///
/// The result is in milliseconds: positive means `driver` trails `opponent`,
/// negative means `driver` leads, and zero means equal cumulative time.
pub fn signed_gap_ms(
  analysis : RaceAnalysis,
  driver : String,
  opponent : String,
  lap : Int,
) -> Int? {
  match
    (
      find_lap_state(analysis, driver, lap),
      find_lap_state(analysis, opponent, lap),
    ) {
    (Some(driver_state), Some(opponent_state)) =>
      Some(driver_state.cumulative_time_ms - opponent_state.cumulative_time_ms)
    _ => None
  }
}

///|
/// Return stints in number order for one driver; an unknown driver returns an empty array.
///
/// Each stint is reconstructed from validated end-of-lap states and is returned
/// in chronological stint-number order without mutating `analysis`.
pub fn stints_for_driver(
  analysis : RaceAnalysis,
  driver : String,
) -> Array[Stint] {
  let matching : Array[Stint] = []
  for stint in analysis.stints {
    if stint.driver == driver {
      matching.push(stint)
    }
  }
  matching
}
