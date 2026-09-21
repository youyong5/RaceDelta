///|
priv enum NonZeroRelation {
  Positive
  Negative
} derive(Eq)

///|
fn explanation_error(
  code : ExplanationErrorCode,
  lap : Int?,
  message : String,
) -> ExplanationError {
  { code, lap, message, }
}

///|
fn non_zero_relation(value_ms : Int) -> NonZeroRelation? {
  if value_ms > 0 {
    Some(Positive)
  } else if value_ms < 0 {
    Some(Negative)
  } else {
    None
  }
}

///|
fn crossover_direction(
  kind : CrossoverKind,
  relation : NonZeroRelation,
) -> CrossoverDirection {
  match (kind, relation) {
    (Performance, Positive) => AlternativeBecomesFaster
    (Performance, Negative) => ActualBecomesFaster
    (Strategic, Positive) => AlternativeBecomesBetter
    (Strategic, Negative) => ActualBecomesBetter
    (Opponent, Positive) => TargetFallsBehind
    (Opponent, Negative) => TargetMovesAhead
  }
}

///|
fn detect_value_crossovers(
  values : Array[(Int, Int)],
  kind : CrossoverKind,
  record_initial_non_zero : Bool,
) -> Array[CrossoverPoint] {
  let points : Array[CrossoverPoint] = []
  let mut last_relation : NonZeroRelation? = None
  let mut last_value_ms = 0
  for (lap, value_ms) in values {
    match non_zero_relation(value_ms) {
      None => ()
      Some(current_relation) =>
        match last_relation {
          None => {
            if record_initial_non_zero {
              points.push({
                lap,
                kind,
                direction: crossover_direction(kind, current_relation),
                previous_value_ms: 0,
                current_value_ms: value_ms,
              })
            }
            last_relation = Some(current_relation)
            last_value_ms = value_ms
          }
          Some(previous_relation) => {
            if current_relation != previous_relation {
              points.push({
                lap,
                kind,
                direction: crossover_direction(kind, current_relation),
                previous_value_ms: last_value_ms,
                current_value_ms: value_ms,
              })
            }
            last_relation = Some(current_relation)
            last_value_ms = value_ms
          }
        }
    }
  }
  points
}

///|
fn performance_values(
  config : PaceModelConfig,
  laps : Array[StrategyLapComparison],
) -> Result[Array[(Int, Int)], ExplanationError] {
  let values : Array[(Int, Int)] = []
  for comparison in laps {
    let actual_delta = match
      tyre_pace_delta_ms(
        config,
        comparison.actual_compound,
        comparison.actual_tyre_age_laps,
        comparison.weather,
      ) {
      Ok(delta) => delta
      Err(error) =>
        return Err(
          explanation_error(
            TyreDeltaFailure,
            Some(comparison.lap),
            "could not calculate actual tyre pace delta: " + error.message,
          ),
        )
    }
    let simulated_delta = match
      tyre_pace_delta_ms(
        config,
        comparison.simulated_compound,
        comparison.simulated_tyre_age_laps,
        comparison.weather,
      ) {
      Ok(delta) => delta
      Err(error) =>
        return Err(
          explanation_error(
            TyreDeltaFailure,
            Some(comparison.lap),
            "could not calculate simulated tyre pace delta: " + error.message,
          ),
        )
    }
    values.push((comparison.lap, actual_delta - simulated_delta))
  }
  Ok(values)
}

///|
fn detect_performance_crossovers(
  config : PaceModelConfig,
  laps : Array[StrategyLapComparison],
) -> Result[Array[CrossoverPoint], ExplanationError] {
  match performance_values(config, laps) {
    Ok(values) => Ok(detect_value_crossovers(values, Performance, true))
    Err(error) => Err(error)
  }
}

///|
fn detect_strategic_crossovers(
  laps : Array[StrategyLapComparison],
) -> Array[CrossoverPoint] {
  let values : Array[(Int, Int)] = []
  for comparison in laps {
    values.push((comparison.lap, comparison.cumulative_time_gain_ms))
  }
  detect_value_crossovers(values, Strategic, true)
}

///|
fn detect_opponent_crossovers(
  laps : Array[StrategyLapComparison],
) -> Array[CrossoverPoint] {
  let values : Array[(Int, Int)] = []
  for comparison in laps {
    values.push(
      (comparison.lap, comparison.simulated_signed_gap_to_opponent_ms),
    )
  }
  detect_value_crossovers(values, Opponent, false)
}
