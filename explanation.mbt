///|
fn pad_three_digits(value : Int) -> String {
  if value < 10 {
    "00" + value.to_string()
  } else if value < 100 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
/// Format an integer-millisecond duration without a leading positive sign.
pub fn format_duration_ms(milliseconds : Int) -> String {
  if milliseconds < 0 {
    "-" + format_duration_ms(0 - milliseconds)
  } else {
    let seconds = milliseconds / 1000
    let remainder_ms = milliseconds % 1000
    seconds.to_string() + "." + pad_three_digits(remainder_ms) + " s"
  }
}

///|
/// Format an integer-millisecond signed gain or gap with an explicit sign.
pub fn format_signed_ms(milliseconds : Int) -> String {
  if milliseconds > 0 {
    "+" + format_duration_ms(milliseconds)
  } else if milliseconds < 0 {
    "-" + format_duration_ms(0 - milliseconds)
  } else {
    "0.000 s"
  }
}

///|
fn validate_strategy_simulation(
  simulation : StrategySimulation,
) -> Result[Unit, ExplanationError] {
  if simulation.laps.length() == 0 {
    return Err(
      explanation_error(
        EmptySimulation,
        None,
        "strategy simulation must contain at least one lap",
      ),
    )
  }
  let summary = simulation.summary
  let request = simulation.request
  if summary.target_driver != request.target_driver ||
    summary.opponent_driver != request.opponent_driver {
    return Err(
      explanation_error(
        InconsistentSimulation,
        None,
        "strategy summary drivers do not match the simulation request",
      ),
    )
  }
  if summary.lap_count != simulation.laps.length() {
    return Err(
      explanation_error(
        InconsistentSimulation,
        None,
        "strategy summary lap count does not match the lap comparisons",
      ),
    )
  }
  let mut actual_stop_count = 0
  let mut simulated_stop_count = 0
  let mut previous_actual_cumulative_time_ms = 0
  let mut previous_simulated_cumulative_time_ms = 0
  for index = 0; index < simulation.laps.length(); index = index + 1 {
    let comparison = simulation.laps[index]
    if comparison.lap != index + 1 {
      return Err(
        explanation_error(
          InconsistentSimulation,
          Some(comparison.lap),
          "strategy lap comparisons must be continuous and sorted by lap",
        ),
      )
    }
    if comparison.cumulative_time_gain_ms !=
      comparison.actual_cumulative_time_ms -
      comparison.simulated_cumulative_time_ms ||
      comparison.actual_cumulative_time_ms !=
      previous_actual_cumulative_time_ms + comparison.actual_lap_time_ms ||
      comparison.simulated_cumulative_time_ms !=
      previous_simulated_cumulative_time_ms + comparison.simulated_lap_time_ms {
      return Err(
        explanation_error(
          InconsistentSimulation,
          Some(comparison.lap),
          "strategy lap comparison times and gains are inconsistent",
        ),
      )
    }
    if comparison.actual_pit {
      actual_stop_count = actual_stop_count + 1
    }
    if comparison.simulated_pit {
      simulated_stop_count = simulated_stop_count + 1
    }
    previous_actual_cumulative_time_ms = comparison.actual_cumulative_time_ms
    previous_simulated_cumulative_time_ms = comparison.simulated_cumulative_time_ms
  }
  let final_lap = simulation.laps[simulation.laps.length() - 1]
  if summary.actual_total_time_ms != final_lap.actual_cumulative_time_ms ||
    summary.simulated_total_time_ms != final_lap.simulated_cumulative_time_ms ||
    summary.time_gain_ms != final_lap.cumulative_time_gain_ms ||
    summary.actual_stop_count != actual_stop_count ||
    summary.simulated_stop_count != simulated_stop_count ||
    summary.actual_finish_position != final_lap.actual_position ||
    summary.simulated_finish_position != final_lap.simulated_position ||
    summary.positions_gained !=
    final_lap.actual_position - final_lap.simulated_position ||
    summary.actual_final_signed_gap_to_opponent_ms !=
    final_lap.actual_signed_gap_to_opponent_ms ||
    summary.simulated_final_signed_gap_to_opponent_ms !=
    final_lap.simulated_signed_gap_to_opponent_ms ||
    summary.opponent_gap_gain_ms !=
    final_lap.actual_signed_gap_to_opponent_ms -
    final_lap.simulated_signed_gap_to_opponent_ms {
    return Err(
      explanation_error(
        InconsistentSimulation,
        Some(final_lap.lap),
        "strategy summary does not match the final lap comparison",
      ),
    )
  }
  Ok(())
}

///|
fn verdict_for(summary : StrategySummary) -> StrategyVerdict {
  if summary.time_gain_ms > 0 {
    Improved
  } else if summary.time_gain_ms < 0 {
    Worsened
  } else {
    Unchanged
  }
}

///|
fn actual_or_simulated_stop(
  laps : Array[StrategyLapComparison],
  actual : Bool,
) -> Array[StrategyPitStop] {
  let stops : Array[StrategyPitStop] = []
  for index = 0; index < laps.length(); index = index + 1 {
    let comparison = laps[index]
    let pit = if actual {
      comparison.actual_pit
    } else {
      comparison.simulated_pit
    }
    if pit {
      let next_compound = if index == laps.length() - 1 {
        None
      } else if actual {
        Some(laps[index + 1].actual_compound)
      } else {
        Some(laps[index + 1].simulated_compound)
      }
      stops.push({ lap: comparison.lap, next_compound, })
    }
  }
  stops
}

///|
fn track_status_name(status : TrackStatus) -> String {
  match status {
    Green => "GREEN"
    SafetyCar => "SAFETY_CAR"
  }
}

///|
fn weather_name(weather : Weather) -> String {
  match weather {
    Dry => "DRY"
    Damp => "DAMP"
    Wet => "WET"
  }
}

///|
fn crossover_turning_kind(kind : CrossoverKind) -> TurningPointKind {
  match kind {
    Performance => PerformanceCrossover
    Strategic => StrategicCrossover
    Opponent => OpponentCrossover
  }
}

///|
fn crossover_direction_message(direction : CrossoverDirection) -> String {
  match direction {
    AlternativeBecomesFaster => "Alternative becomes faster"
    ActualBecomesFaster => "Actual becomes faster"
    AlternativeBecomesBetter => "Alternative becomes better"
    ActualBecomesBetter => "Actual becomes better"
    TargetMovesAhead => "Target moves ahead of opponent"
    TargetFallsBehind => "Target falls behind opponent"
  }
}

///|
fn append_crossover_turning_points(
  turning_points : Array[TurningPoint],
  crossovers : Array[CrossoverPoint],
) -> Unit {
  for point in crossovers {
    turning_points.push({
      lap: point.lap,
      kind: crossover_turning_kind(point.kind),
      impact_ms: Some(point.current_value_ms),
      message: crossover_direction_message(point.direction) + ".",
    })
  }
}

///|
fn append_lap_state_turning_points(
  turning_points : Array[TurningPoint],
  config : PaceModelConfig,
  laps : Array[StrategyLapComparison],
) -> Unit {
  for index = 0; index < laps.length(); index = index + 1 {
    let current = laps[index]
    if index > 0 {
      let previous = laps[index - 1]
      if previous.track_status != current.track_status {
        turning_points.push({
          lap: current.lap,
          kind: TrackStatusChange,
          impact_ms: None,
          message: "Track status changed from " +
          track_status_name(previous.track_status) +
          " to " +
          track_status_name(current.track_status) +
          ".",
        })
      }
      if previous.weather != current.weather {
        turning_points.push({
          lap: current.lap,
          kind: WeatherChange,
          impact_ms: None,
          message: "Weather changed from " +
          weather_name(previous.weather) +
          " to " +
          weather_name(current.weather) +
          ".",
        })
      }
    }
    if current.actual_pit {
      turning_points.push({
        lap: current.lap,
        kind: ActualPitStop,
        impact_ms: None,
        message: "Actual strategy pit stop.",
      })
    }
    if current.simulated_pit {
      turning_points.push({
        lap: current.lap,
        kind: SimulatedPitStop,
        impact_ms: None,
        message: "Simulated strategy pit stop.",
      })
      if current.track_status == SafetyCar {
        let savings_ms = config.pit_loss_profile.green_pit_loss_ms -
          config.pit_loss_profile.safety_car_pit_loss_ms
        turning_points.push({
          lap: current.lap,
          kind: SafetyCarPitOpportunity,
          impact_ms: Some(savings_ms),
          message: "Simulated pit during Safety Car; modeled pit loss is " +
          format_duration_ms(savings_ms) +
          " lower than GREEN.",
        })
      }
    }
    if index > 0 {
      let previous = laps[index - 1]
      let previous_relative = previous.actual_position -
        previous.simulated_position
      let current_relative = current.actual_position -
        current.simulated_position
      if current_relative > previous_relative {
        turning_points.push({
          lap: current.lap,
          kind: RelativePositionGain,
          impact_ms: None,
          message: "Relative position improved.",
        })
      } else if current_relative < previous_relative {
        turning_points.push({
          lap: current.lap,
          kind: RelativePositionLoss,
          impact_ms: None,
          message: "Relative position worsened.",
        })
      }
    }
  }
}

///|
fn best_and_worst_lap_impacts(
  laps : Array[StrategyLapComparison],
) -> (LapImpact?, LapImpact?) {
  let mut best : LapImpact? = None
  let mut worst : LapImpact? = None
  for comparison in laps {
    let impact = {
      lap: comparison.lap,
      lap_time_gain_ms: comparison.actual_lap_time_ms -
      comparison.simulated_lap_time_ms,
      cumulative_time_gain_ms: comparison.cumulative_time_gain_ms,
    }
    if impact.lap_time_gain_ms > 0 {
      match best {
        None => best = Some(impact)
        Some(previous) =>
          if impact.lap_time_gain_ms > previous.lap_time_gain_ms {
            best = Some(impact)
          }
      }
    }
    if impact.lap_time_gain_ms < 0 {
      match worst {
        None => worst = Some(impact)
        Some(previous) =>
          if impact.lap_time_gain_ms < previous.lap_time_gain_ms {
            worst = Some(impact)
          }
      }
    }
  }
  (best, worst)
}

///|
fn append_best_and_worst_turning_points(
  turning_points : Array[TurningPoint],
  best : LapImpact?,
  worst : LapImpact?,
) -> Unit {
  match best {
    Some(impact) =>
      turning_points.push({
        lap: impact.lap,
        kind: BestLapGain,
        impact_ms: Some(impact.lap_time_gain_ms),
        message: "Best single-lap gain.",
      })
    None => ()
  }
  match worst {
    Some(impact) =>
      turning_points.push({
        lap: impact.lap,
        kind: WorstLapLoss,
        impact_ms: Some(impact.lap_time_gain_ms),
        message: "Worst single-lap loss.",
      })
    None => ()
  }
}

///|
fn turning_point_rank(kind : TurningPointKind) -> Int {
  match kind {
    TrackStatusChange => 1
    WeatherChange => 2
    ActualPitStop => 3
    SimulatedPitStop => 4
    SafetyCarPitOpportunity => 5
    PerformanceCrossover => 6
    StrategicCrossover => 7
    OpponentCrossover => 8
    RelativePositionGain => 9
    RelativePositionLoss => 10
    BestLapGain => 11
    WorstLapLoss => 12
  }
}

///|
fn sorted_turning_points(
  config : PaceModelConfig,
  laps : Array[StrategyLapComparison],
  performance : Array[CrossoverPoint],
  strategic : Array[CrossoverPoint],
  opponent : Array[CrossoverPoint],
  best : LapImpact?,
  worst : LapImpact?,
) -> Array[TurningPoint] {
  let turning_points : Array[TurningPoint] = []
  append_lap_state_turning_points(turning_points, config, laps)
  append_crossover_turning_points(turning_points, performance)
  append_crossover_turning_points(turning_points, strategic)
  append_crossover_turning_points(turning_points, opponent)
  append_best_and_worst_turning_points(turning_points, best, worst)
  turning_points.sort_by((left, right) => {
    if left.lap != right.lap {
      left.lap - right.lap
    } else {
      turning_point_rank(left.kind) - turning_point_rank(right.kind)
    }
  })
  turning_points
}

///|
/// Explain one completed M4 simulation without replaying or mutating it.
pub fn explain_strategy(
  config : PaceModelConfig,
  simulation : StrategySimulation,
) -> Result[StrategyExplanation, ExplanationError] {
  match validate_pace_model_config(config) {
    Err(error) =>
      return Err(
        explanation_error(
          InvalidModel,
          None,
          "invalid pace model: " + error.message,
        ),
      )
    Ok(_) => ()
  }
  match validate_strategy_simulation(simulation) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let performance_crossovers = match
    detect_performance_crossovers(config, simulation.laps) {
    Ok(points) => points
    Err(error) => return Err(error)
  }
  let strategic_crossovers = detect_strategic_crossovers(simulation.laps)
  let opponent_crossovers = detect_opponent_crossovers(simulation.laps)
  let (best_lap_gain, worst_lap_loss) = best_and_worst_lap_impacts(
    simulation.laps,
  )
  let turning_points = sorted_turning_points(
    config,
    simulation.laps,
    performance_crossovers,
    strategic_crossovers,
    opponent_crossovers,
    best_lap_gain,
    worst_lap_loss,
  )
  Ok({
    verdict: verdict_for(simulation.summary),
    target_driver: simulation.request.target_driver,
    opponent_driver: simulation.request.opponent_driver,
    actual_stops: actual_or_simulated_stop(simulation.laps, true),
    simulated_stops: actual_or_simulated_stop(simulation.laps, false),
    performance_crossovers,
    strategic_crossovers,
    opponent_crossovers,
    turning_points,
    best_lap_gain,
    worst_lap_loss,
    summary: simulation.summary,
    laps: simulation.laps,
  })
}
