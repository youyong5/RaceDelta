///|
fn strategy_error(
  code : StrategyErrorCode,
  lap : Int?,
  message : String,
) -> StrategyError {
  { code, lap, message, }
}

///|
fn driver_exists(analysis : RaceAnalysis, driver : String) -> Bool {
  for candidate in analysis.drivers {
    if candidate == driver {
      return true
    }
  }
  false
}

///|
/// Validate driver selection and return a copied, lap-sorted pit plan.
fn validate_and_normalize_request(
  analysis : RaceAnalysis,
  request : StrategyRequest,
) -> Result[StrategyRequest, StrategyError] {
  if !driver_exists(analysis, request.target_driver) {
    return Err(
      strategy_error(
        UnknownTargetDriver,
        None,
        "target driver does not exist in this race",
      ),
    )
  }
  if !driver_exists(analysis, request.opponent_driver) {
    return Err(
      strategy_error(
        UnknownOpponentDriver,
        None,
        "opponent driver does not exist in this race",
      ),
    )
  }
  if request.target_driver == request.opponent_driver {
    return Err(
      strategy_error(
        SameDriver,
        None,
        "target driver and opponent driver must be different",
      ),
    )
  }
  let stops : Array[PlannedPitStop] = []
  for stop in request.stops {
    stops.push(stop)
  }
  stops.sort_by((left, right) => left.pit_lap - right.pit_lap)
  for index = 0; index < stops.length(); index = index + 1 {
    let stop = stops[index]
    if stop.pit_lap < 1 || stop.pit_lap >= analysis.lap_count {
      return Err(
        strategy_error(
          InvalidPitLap,
          Some(stop.pit_lap),
          "planned pit lap must be within the race and before the final lap",
        ),
      )
    }
    if index > 0 && stops[index - 1].pit_lap == stop.pit_lap {
      return Err(
        strategy_error(
          DuplicatePitLap,
          Some(stop.pit_lap),
          "only one planned pit stop is allowed per lap",
        ),
      )
    }
  }
  Ok({
    target_driver: request.target_driver,
    opponent_driver: request.opponent_driver,
    stops,
  })
}
