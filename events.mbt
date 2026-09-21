///|
fn build_events(
  drivers : Array[String],
  states : Array[DriverLapState],
  lap_count : Int,
) -> Array[RaceEvent] {
  let events : Array[RaceEvent] = []
  let driver_count = drivers.length()
  for lap = 1; lap <= lap_count; lap = lap + 1 {
    let start = (lap - 1) * driver_count
    if lap > 1 {
      let previous_lead_state = states[start - driver_count]
      let current_lead_state = states[start]
      if previous_lead_state.track_status != current_lead_state.track_status {
        events.push(
          TrackStatusChange({
            lap,
            previous: previous_lead_state.track_status,
            current: current_lead_state.track_status,
          }),
        )
      }
      if previous_lead_state.weather != current_lead_state.weather {
        events.push(
          WeatherChange({
            lap,
            previous: previous_lead_state.weather,
            current: current_lead_state.weather,
          }),
        )
      }
    }
    for offset = 0; offset < driver_count; offset = offset + 1 {
      let state = states[start + offset]
      if state.pit {
        let next_compound = if lap == lap_count {
          None
        } else {
          Some(states[start + driver_count + offset].compound)
        }
        events.push(
          PitStop({
            lap,
            driver: state.driver,
            outgoing_compound: state.compound,
            next_compound,
          }),
        )
      }
    }
    if lap > 1 {
      for offset = 0; offset < driver_count; offset = offset + 1 {
        let previous = states[start - driver_count + offset]
        let current = states[start + offset]
        if previous.position != current.position {
          events.push(
            PositionChange({
              lap,
              driver: current.driver,
              previous_position: previous.position,
              current_position: current.position,
            }),
          )
        }
      }
    }
  }
  events
}
