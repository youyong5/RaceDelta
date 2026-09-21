///|
fn states_for_driver(
  states : Array[DriverLapState],
  driver : String,
) -> Array[DriverLapState] {
  let matching : Array[DriverLapState] = []
  for state in states {
    if state.driver == driver {
      matching.push(state)
    }
  }
  matching
}

///|
fn stint_time_ms(states : Array[DriverLapState], start : Int, end : Int) -> Int {
  let mut total = 0
  for index = start; index <= end; index = index + 1 {
    total = total + states[index].lap_time_ms
  }
  total
}

///|
fn build_stints(
  drivers : Array[String],
  states : Array[DriverLapState],
) -> Array[Stint] {
  let stints : Array[Stint] = []
  for driver in drivers {
    let driver_states = states_for_driver(states, driver)
    let mut start = 0
    let mut stint_number = 1
    for index = 0; index < driver_states.length(); index = index + 1 {
      let current = driver_states[index]
      if current.pit || index == driver_states.length() - 1 {
        let first = driver_states[start]
        stints.push({
          driver,
          stint_number,
          start_lap: first.lap,
          end_lap: current.lap,
          compound: first.compound,
          start_tyre_age_laps: first.tyre_age_laps,
          end_tyre_age_laps: current.tyre_age_laps,
          lap_count: current.lap - first.lap + 1,
          total_time_ms: stint_time_ms(driver_states, start, index),
          ended_by_pit: current.pit,
        })
        start = index + 1
        stint_number = stint_number + 1
      }
    }
  }
  stints
}
