///|
priv struct SimulatedLap {
  tyre_state : SimulatedTyreState
  lap_time_ms : Int
  cumulative_time_ms : Int
}

///|
fn lap_state_or_error(
  analysis : RaceAnalysis,
  driver : String,
  lap : Int,
) -> Result[DriverLapState, StrategyError] {
  match find_lap_state(analysis, driver, lap) {
    Some(state) => Ok(state)
    None =>
      Err(
        strategy_error(
          MissingLapState,
          Some(lap),
          "race analysis is missing a required driver lap state",
        ),
      )
  }
}

///|
fn stop_for_lap(stops : Array[PlannedPitStop], lap : Int) -> PlannedPitStop? {
  for stop in stops {
    if stop.pit_lap == lap {
      return Some(stop)
    }
  }
  None
}

///|
fn derive_neutral_anchors(
  analysis : RaceAnalysis,
  config : PaceModelConfig,
  target_driver : String,
) -> Result[Array[Int], StrategyError] {
  let anchors : Array[Int] = []
  for lap = 1; lap <= analysis.lap_count; lap = lap + 1 {
    let actual = match lap_state_or_error(analysis, target_driver, lap) {
      Ok(state) => state
      Err(error) => return Err(error)
    }
    match
      derive_neutral_lap_time_ms(
        config,
        actual.lap_time_ms,
        actual.compound,
        actual.tyre_age_laps,
        actual.weather,
        actual.track_status,
        actual.pit,
      ) {
      Ok(anchor) => anchors.push(anchor)
      Err(error) =>
        return Err(
          strategy_error(
            NeutralLapFailure,
            Some(lap),
            "could not derive neutral lap time: " + error.message,
          ),
        )
    }
  }
  Ok(anchors)
}

///|
fn build_simulated_laps(
  analysis : RaceAnalysis,
  config : PaceModelConfig,
  request : StrategyRequest,
  anchors : Array[Int],
) -> Result[Array[SimulatedLap], StrategyError] {
  let simulated : Array[SimulatedLap] = []
  let first_actual = match
    lap_state_or_error(analysis, request.target_driver, 1) {
    Ok(state) => state
    Err(error) => return Err(error)
  }
  let mut compound = first_actual.compound
  let mut tyre_age_laps = first_actual.tyre_age_laps
  let mut cumulative_time_ms = 0
  for lap = 1; lap <= analysis.lap_count; lap = lap + 1 {
    let actual = match
      lap_state_or_error(analysis, request.target_driver, lap) {
      Ok(state) => state
      Err(error) => return Err(error)
    }
    let planned_stop = stop_for_lap(request.stops, lap)
    let pit = planned_stop is Some(_)
    let lap_time_ms = match
      estimate_lap_time_ms(
        config,
        anchors[lap - 1],
        compound,
        tyre_age_laps,
        actual.weather,
        actual.track_status,
        pit,
      ) {
      Ok(time) => time
      Err(error) =>
        return Err(
          strategy_error(
            EstimatedLapFailure,
            Some(lap),
            "could not estimate simulated lap time: " + error.message,
          ),
        )
    }
    cumulative_time_ms = cumulative_time_ms + lap_time_ms
    simulated.push({
      tyre_state: { compound, tyre_age_laps, pit, },
      lap_time_ms,
      cumulative_time_ms,
    })
    match planned_stop {
      Some(stop) => {
        compound = stop.next_compound
        tyre_age_laps = 1
      }
      None => tyre_age_laps = tyre_age_laps + 1
    }
  }
  Ok(simulated)
}

///|
fn simulated_position(
  analysis : RaceAnalysis,
  target_driver : String,
  lap : Int,
  target_cumulative_time_ms : Int,
) -> Result[Int, StrategyError] {
  let ranking : Array[(String, Int)] = []
  for driver in analysis.drivers {
    if driver == target_driver {
      ranking.push((driver, target_cumulative_time_ms))
    } else {
      let actual = match lap_state_or_error(analysis, driver, lap) {
        Ok(state) => state
        Err(error) => return Err(error)
      }
      ranking.push((driver, actual.cumulative_time_ms))
    }
  }
  ranking.sort_by((left, right) => {
    if left.1 != right.1 {
      left.1 - right.1
    } else {
      left.0.compare(right.0)
    }
  })
  for index = 0; index < ranking.length(); index = index + 1 {
    if ranking[index].0 == target_driver {
      return Ok(index + 1)
    }
  }
  Err(
    strategy_error(
      MissingLapState,
      Some(lap),
      "target driver is missing from simulated ranking",
    ),
  )
}

///|
fn build_comparisons(
  analysis : RaceAnalysis,
  request : StrategyRequest,
  anchors : Array[Int],
  simulated : Array[SimulatedLap],
) -> Result[Array[StrategyLapComparison], StrategyError] {
  let comparisons : Array[StrategyLapComparison] = []
  for lap = 1; lap <= analysis.lap_count; lap = lap + 1 {
    let actual = match
      lap_state_or_error(analysis, request.target_driver, lap) {
      Ok(state) => state
      Err(error) => return Err(error)
    }
    let opponent = match
      lap_state_or_error(analysis, request.opponent_driver, lap) {
      Ok(state) => state
      Err(error) => return Err(error)
    }
    let simulated_lap = simulated[lap - 1]
    let position = match
      simulated_position(
        analysis,
        request.target_driver,
        lap,
        simulated_lap.cumulative_time_ms,
      ) {
      Ok(position) => position
      Err(error) => return Err(error)
    }
    comparisons.push({
      lap,
      neutral_lap_time_ms: anchors[lap - 1],
      weather: actual.weather,
      track_status: actual.track_status,
      actual_lap_time_ms: actual.lap_time_ms,
      actual_cumulative_time_ms: actual.cumulative_time_ms,
      actual_compound: actual.compound,
      actual_tyre_age_laps: actual.tyre_age_laps,
      actual_pit: actual.pit,
      actual_position: actual.position,
      actual_signed_gap_to_opponent_ms: actual.cumulative_time_ms -
      opponent.cumulative_time_ms,
      simulated_lap_time_ms: simulated_lap.lap_time_ms,
      simulated_cumulative_time_ms: simulated_lap.cumulative_time_ms,
      simulated_compound: simulated_lap.tyre_state.compound,
      simulated_tyre_age_laps: simulated_lap.tyre_state.tyre_age_laps,
      simulated_pit: simulated_lap.tyre_state.pit,
      simulated_position: position,
      simulated_signed_gap_to_opponent_ms: simulated_lap.cumulative_time_ms -
      opponent.cumulative_time_ms,
      cumulative_time_gain_ms: actual.cumulative_time_ms -
      simulated_lap.cumulative_time_ms,
    })
  }
  Ok(comparisons)
}

///|
fn count_actual_stops(
  analysis : RaceAnalysis,
  target_driver : String,
) -> Result[Int, StrategyError] {
  let mut count = 0
  for lap = 1; lap <= analysis.lap_count; lap = lap + 1 {
    let state = match lap_state_or_error(analysis, target_driver, lap) {
      Ok(state) => state
      Err(error) => return Err(error)
    }
    if state.pit {
      count = count + 1
    }
  }
  Ok(count)
}

///|
fn build_summary(
  analysis : RaceAnalysis,
  request : StrategyRequest,
  comparisons : Array[StrategyLapComparison],
) -> Result[StrategySummary, StrategyError] {
  let final_comparison = comparisons[comparisons.length() - 1]
  let actual_stop_count = match
    count_actual_stops(analysis, request.target_driver) {
    Ok(count) => count
    Err(error) => return Err(error)
  }
  let actual_final_gap = final_comparison.actual_signed_gap_to_opponent_ms
  let simulated_final_gap = final_comparison.simulated_signed_gap_to_opponent_ms
  Ok({
    target_driver: request.target_driver,
    opponent_driver: request.opponent_driver,
    lap_count: analysis.lap_count,
    actual_stop_count,
    simulated_stop_count: request.stops.length(),
    actual_total_time_ms: final_comparison.actual_cumulative_time_ms,
    simulated_total_time_ms: final_comparison.simulated_cumulative_time_ms,
    time_gain_ms: final_comparison.cumulative_time_gain_ms,
    actual_finish_position: final_comparison.actual_position,
    simulated_finish_position: final_comparison.simulated_position,
    positions_gained: final_comparison.actual_position -
    final_comparison.simulated_position,
    actual_final_signed_gap_to_opponent_ms: actual_final_gap,
    simulated_final_signed_gap_to_opponent_ms: simulated_final_gap,
    opponent_gap_gain_ms: actual_final_gap - simulated_final_gap,
  })
}

///|
/// Replay a complete replacement pit plan for one target driver against real rivals.
pub fn simulate_strategy(
  data : RaceData,
  config : PaceModelConfig,
  request : StrategyRequest,
) -> Result[StrategySimulation, StrategyError] {
  match validate_pace_model_config(config) {
    Err(error) =>
      return Err(
        strategy_error(
          InvalidModel,
          None,
          "invalid pace model: " + error.message,
        ),
      )
    Ok(_) => ()
  }
  let analysis = analyze_race(data)
  let normalized_request = match
    validate_and_normalize_request(analysis, request) {
    Ok(request) => request
    Err(error) => return Err(error)
  }
  let anchors = match
    derive_neutral_anchors(analysis, config, normalized_request.target_driver) {
    Ok(anchors) => anchors
    Err(error) => return Err(error)
  }
  let simulated = match
    build_simulated_laps(analysis, config, normalized_request, anchors) {
    Ok(laps) => laps
    Err(error) => return Err(error)
  }
  let laps = match
    build_comparisons(analysis, normalized_request, anchors, simulated) {
    Ok(laps) => laps
    Err(error) => return Err(error)
  }
  let summary = match build_summary(analysis, normalized_request, laps) {
    Ok(summary) => summary
    Err(error) => return Err(error)
  }
  Ok({ request: normalized_request, laps, summary, })
}
