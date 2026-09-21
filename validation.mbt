///|
fn find_record(
  records : Array[ParsedRecord],
  driver : String,
  lap : Int,
) -> ParsedRecord? {
  for item in records {
    if item.record.driver == driver && item.record.lap == lap {
      return Some(item)
    }
  }
  None
}

///|
fn has_driver(drivers : Array[String], driver : String) -> Bool {
  for candidate in drivers {
    if candidate == driver {
      return true
    }
  }
  false
}

///|
fn validate_records(
  parsed : Array[ParsedRecord],
) -> Result[Array[LapRecord], RaceError] {
  for index = 1; index < parsed.length(); index = index + 1 {
    let previous = parsed[index - 1]
    let current = parsed[index]
    if previous.record.lap == current.record.lap &&
      previous.record.driver == current.record.driver {
      return Err(
        csv_error(
          DuplicateDriverLap,
          current.line,
          "driver,lap",
          "each driver may appear only once per lap",
        ),
      )
    }
  }
  let drivers = []
  for item in parsed {
    if item.record.lap == 1 && !has_driver(drivers, item.record.driver) {
      drivers.push(item.record.driver)
    }
  }
  if drivers.length() == 0 {
    return Err(
      csv_error(MissingLap, 0, "lap", "every driver must start at lap 1"),
    )
  }
  let max_lap = parsed[parsed.length() - 1].record.lap
  for item in parsed {
    if !has_driver(drivers, item.record.driver) {
      return Err(
        csv_error(
          InconsistentLaps,
          item.line,
          "driver",
          "every driver must start at lap 1",
        ),
      )
    }
  }
  for lap = 1; lap <= max_lap; lap = lap + 1 {
    let first = match find_record(parsed, drivers[0], lap) {
      Some(item) => item
      None =>
        return Err(
          csv_error(
            MissingLap,
            0,
            "lap",
            "all drivers must have every consecutive lap",
          ),
        )
    }
    for driver in drivers {
      let current = match find_record(parsed, driver, lap) {
        Some(item) => item
        None =>
          return Err(
            csv_error(
              InconsistentLaps,
              0,
              "lap",
              "all drivers must have the same consecutive laps",
            ),
          )
      }
      if current.record.track_status != first.record.track_status {
        return Err(
          csv_error(
            InconsistentTrackStatus,
            current.line,
            "track_status",
            "all drivers must share track_status on the same lap",
          ),
        )
      }
      if current.record.weather != first.record.weather {
        return Err(
          csv_error(
            InconsistentWeather,
            current.line,
            "weather",
            "all drivers must share weather on the same lap",
          ),
        )
      }
      if lap > 1 {
        let previous = match find_record(parsed, driver, lap - 1) {
          Some(item) => item
          None =>
            return Err(
              csv_error(
                MissingLap,
                current.line,
                "lap",
                "laps must be continuous for each driver",
              ),
            )
        }
        if previous.record.pit {
          if current.record.tyre_age_laps != 1 {
            return Err(
              csv_error(
                InvalidTyreTransition,
                current.line,
                "tyre_age_laps",
                "tyre_age_laps must be 1 after a pit stop",
              ),
            )
          }
        } else {
          if current.record.compound != previous.record.compound {
            return Err(
              csv_error(
                InvalidTyreTransition,
                current.line,
                "compound",
                "compound may change only after a pit stop",
              ),
            )
          }
          if current.record.tyre_age_laps != previous.record.tyre_age_laps + 1 {
            return Err(
              csv_error(
                InvalidTyreTransition,
                current.line,
                "tyre_age_laps",
                "tyre_age_laps must increase by 1 without a pit stop",
              ),
            )
          }
        }
      }
    }
  }
  let records = []
  for item in parsed {
    records.push(item.record)
  }
  Ok(records)
}
