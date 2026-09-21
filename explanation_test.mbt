///|
fn m5_performance_compounds(
  relation : Int,
) -> (@racedelta.Compound, @racedelta.Compound) {
  if relation > 0 {
    (@racedelta.Medium, @racedelta.Soft)
  } else if relation < 0 {
    (@racedelta.Soft, @racedelta.Medium)
  } else {
    (@racedelta.Medium, @racedelta.Medium)
  }
}

///|
fn m5_lap(
  lap : Int,
  performance_relation : Int,
  cumulative_gain_ms : Int,
  simulated_gap_ms : Int,
  lap_gain_ms : Int,
  actual_position : Int,
  simulated_position : Int,
  actual_pit : Bool,
  simulated_pit : Bool,
  track_status : @racedelta.TrackStatus,
  weather : @racedelta.Weather,
) -> @racedelta.StrategyLapComparison {
  let (actual_compound, simulated_compound) = m5_performance_compounds(
    performance_relation,
  )
  let simulated_cumulative_time_ms = lap * 100000
  let actual_cumulative_time_ms = simulated_cumulative_time_ms +
    cumulative_gain_ms
  {
    lap,
    neutral_lap_time_ms: 100000,
    weather,
    track_status,
    actual_lap_time_ms: 100000 + lap_gain_ms,
    actual_cumulative_time_ms,
    actual_compound,
    actual_tyre_age_laps: 1,
    actual_pit,
    actual_position,
    actual_signed_gap_to_opponent_ms: cumulative_gain_ms + simulated_gap_ms,
    simulated_lap_time_ms: 100000,
    simulated_cumulative_time_ms,
    simulated_compound,
    simulated_tyre_age_laps: 1,
    simulated_pit,
    simulated_position,
    simulated_signed_gap_to_opponent_ms: simulated_gap_ms,
    cumulative_time_gain_ms: cumulative_gain_ms,
  }
}

///|
fn m5_simulation(
  laps : Array[@racedelta.StrategyLapComparison],
) -> @racedelta.StrategySimulation {
  let final_lap = laps[laps.length() - 1]
  let mut actual_stop_count = 0
  let mut simulated_stop_count = 0
  for lap in laps {
    if lap.actual_pit {
      actual_stop_count = actual_stop_count + 1
    }
    if lap.simulated_pit {
      simulated_stop_count = simulated_stop_count + 1
    }
  }
  {
    request: { target_driver: "ALP", opponent_driver: "BRV", stops: [], },
    laps,
    summary: {
      target_driver: "ALP",
      opponent_driver: "BRV",
      lap_count: laps.length(),
      actual_stop_count,
      simulated_stop_count,
      actual_total_time_ms: final_lap.actual_cumulative_time_ms,
      simulated_total_time_ms: final_lap.simulated_cumulative_time_ms,
      time_gain_ms: final_lap.cumulative_time_gain_ms,
      actual_finish_position: final_lap.actual_position,
      simulated_finish_position: final_lap.simulated_position,
      positions_gained: final_lap.actual_position - final_lap.simulated_position,
      actual_final_signed_gap_to_opponent_ms: final_lap.actual_signed_gap_to_opponent_ms,
      simulated_final_signed_gap_to_opponent_ms: final_lap.simulated_signed_gap_to_opponent_ms,
      opponent_gap_gain_ms: final_lap.actual_signed_gap_to_opponent_ms -
      final_lap.simulated_signed_gap_to_opponent_ms,
    },
  }
}

///|
fn m5_explain(
  simulation : @racedelta.StrategySimulation,
) -> @racedelta.StrategyExplanation {
  match
    @racedelta.explain_strategy(
      @racedelta.default_pace_model_config(),
      simulation,
    ) {
    Ok(explanation) => explanation
    Err(_) => panic()
  }
}

///|
fn m5_explain_with_config(
  config : @racedelta.PaceModelConfig,
  simulation : @racedelta.StrategySimulation,
) -> @racedelta.StrategyExplanation {
  match @racedelta.explain_strategy(config, simulation) {
    Ok(explanation) => explanation
    Err(_) => panic()
  }
}

///|
fn m5_expect_error(
  result : Result[@racedelta.StrategyExplanation, @racedelta.ExplanationError],
  code : @racedelta.ExplanationErrorCode,
  lap : Int?,
) -> Unit raise {
  match result {
    Err(error) => {
      assert_eq(error.code, code)
      assert_eq(error.lap, lap)
    }
    Ok(_) => assert_true(false)
  }
}

///|
fn m5_two_lap_simulation() -> @racedelta.StrategySimulation {
  m5_simulation([
    m5_lap(
      1,
      0,
      0,
      100,
      0,
      2,
      2,
      false,
      false,
      @racedelta.Green,
      @racedelta.Dry,
    ),
    m5_lap(
      2,
      1,
      700,
      -100,
      700,
      2,
      1,
      false,
      false,
      @racedelta.Green,
      @racedelta.Dry,
    ),
  ])
}

///|
fn m5_turning_point(
  explanation : @racedelta.StrategyExplanation,
  lap : Int,
  kind : @racedelta.TurningPointKind,
) -> @racedelta.TurningPoint? {
  for point in explanation.turning_points {
    if point.lap == lap && point.kind == kind {
      return Some(point)
    }
  }
  None
}

///|
fn m5_has_turning_point(
  explanation : @racedelta.StrategyExplanation,
  lap : Int,
  kind : @racedelta.TurningPointKind,
) -> Bool {
  m5_turning_point(explanation, lap, kind) is Some(_)
}

///|
fn m5_config_with_pit_losses(
  green_pit_loss_ms : Int,
  safety_car_pit_loss_ms : Int,
) -> @racedelta.PaceModelConfig {
  let config = @racedelta.default_pace_model_config()
  {
    tyre_profiles: config.tyre_profiles,
    pit_loss_profile: { green_pit_loss_ms, safety_car_pit_loss_ms, },
  }
}

///|
test "M5 verdict is Improved only when final time gain is positive" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        1,
        0,
        1,
        2,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.verdict, @racedelta.Improved)
}

///|
test "M5 verdict is Worsened only when final time gain is negative" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        -1,
        0,
        -1,
        1,
        2,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.verdict, @racedelta.Worsened)
}

///|
test "M5 verdict is Unchanged when final time gain is zero" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.verdict, @racedelta.Unchanged)
}

///|
test "M5 detects performance Equal to Alternative Faster" {
  let explanation = m5_explain(m5_two_lap_simulation())
  let point = explanation.performance_crossovers[0]
  assert_eq(point.lap, 2)
  assert_eq(point.direction, @racedelta.AlternativeBecomesFaster)
  assert_eq(point.previous_value_ms, 0)
  assert_eq(point.current_value_ms, 700)
}

///|
test "M5 detects performance Equal to Actual Faster" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        -1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.performance_crossovers[0]
  assert_eq(point.lap, 2)
  assert_eq(point.direction, @racedelta.ActualBecomesFaster)
  assert_eq(point.current_value_ms, -700)
}

///|
test "M5 detects performance Actual Faster to Alternative Faster" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        -1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.performance_crossovers[1]
  assert_eq(point.lap, 2)
  assert_eq(point.direction, @racedelta.AlternativeBecomesFaster)
  assert_eq(point.previous_value_ms, -700)
  assert_eq(point.current_value_ms, 700)
}

///|
test "M5 detects performance Alternative Faster to Actual Faster" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        -1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.performance_crossovers[1]
  assert_eq(point.direction, @racedelta.ActualBecomesFaster)
  assert_eq(point.previous_value_ms, 700)
}

///|
test "M5 does not duplicate a performance crossover across zero" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        3,
        1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.performance_crossovers.length(), 1)
}

///|
test "M5 detects a performance crossover across zero with last nonzero value" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        -1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        3,
        1,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.performance_crossovers[1]
  assert_eq(point.lap, 3)
  assert_eq(point.previous_value_ms, -700)
  assert_eq(point.current_value_ms, 700)
}

///|
test "M5 detects strategic Equal to Better" {
  let explanation = m5_explain(m5_two_lap_simulation())
  let point = explanation.strategic_crossovers[0]
  assert_eq(point.lap, 2)
  assert_eq(point.direction, @racedelta.AlternativeBecomesBetter)
  assert_eq(point.current_value_ms, 700)
}

///|
test "M5 detects strategic Equal to Worse" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        -700,
        0,
        -700,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.strategic_crossovers[0]
  assert_eq(point.direction, @racedelta.ActualBecomesBetter)
  assert_eq(point.current_value_ms, -700)
}

///|
test "M5 detects strategic Worse to Better" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        -500,
        0,
        -500,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        500,
        0,
        1000,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.strategic_crossovers[1]
  assert_eq(point.direction, @racedelta.AlternativeBecomesBetter)
  assert_eq(point.previous_value_ms, -500)
}

///|
test "M5 detects strategic Better to Worse" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        500,
        0,
        500,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        -500,
        0,
        -1000,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.strategic_crossovers[1]
  assert_eq(point.direction, @racedelta.ActualBecomesBetter)
  assert_eq(point.previous_value_ms, 500)
}

///|
test "M5 does not duplicate a strategic crossover across zero" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        500,
        0,
        500,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        -500,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        3,
        0,
        500,
        0,
        500,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.strategic_crossovers.length(), 1)
}

///|
test "M5 initial opponent relationship is not a crossover" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        500,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        400,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.opponent_crossovers.length(), 0)
}

///|
test "M5 detects opponent behind to ahead" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        500,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        -500,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.opponent_crossovers[0]
  assert_eq(point.lap, 2)
  assert_eq(point.direction, @racedelta.TargetMovesAhead)
  assert_eq(point.previous_value_ms, 500)
}

///|
test "M5 detects opponent ahead to behind" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        -500,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        500,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(
    explanation.opponent_crossovers[0].direction,
    @racedelta.TargetFallsBehind,
  )
}

///|
test "M5 detects an opponent crossover through zero" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        500,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        3,
        0,
        0,
        -500,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let point = explanation.opponent_crossovers[0]
  assert_eq(point.lap, 3)
  assert_eq(point.previous_value_ms, 500)
  assert_eq(point.current_value_ms, -500)
}

///|
test "M5 returns empty crossover arrays when relationships do not change" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.performance_crossovers.length(), 0)
  assert_eq(explanation.strategic_crossovers.length(), 0)
  assert_eq(explanation.opponent_crossovers.length(), 0)
}

///|
test "M5 performance advantage excludes pit loss" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        -1,
        22000,
        0,
        22000,
        1,
        1,
        true,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(explanation.performance_crossovers[0].current_value_ms, -700)
}

///|
test "M5 emits a track status change turning point after lap one" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.SafetyCar,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_true(
    m5_has_turning_point(explanation, 2, @racedelta.TrackStatusChange),
  )
}

///|
test "M5 emits a weather change turning point after lap one" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Damp,
      ),
    ]),
  )
  assert_true(m5_has_turning_point(explanation, 2, @racedelta.WeatherChange))
}

///|
test "M5 emits an actual pit stop turning point" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(1, 0, 0, 0, 0, 1, 1, true, false, @racedelta.Green, @racedelta.Dry),
    ]),
  )
  assert_true(m5_has_turning_point(explanation, 1, @racedelta.ActualPitStop))
}

///|
test "M5 emits a simulated pit stop turning point" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(1, 0, 0, 0, 0, 1, 1, false, true, @racedelta.Green, @racedelta.Dry),
    ]),
  )
  assert_true(m5_has_turning_point(explanation, 1, @racedelta.SimulatedPitStop))
}

///|
test "M5 orders actual pit stop before simulated pit stop on one lap" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(1, 0, 0, 0, 0, 1, 1, true, true, @racedelta.Green, @racedelta.Dry),
    ]),
  )
  assert_eq(explanation.turning_points[0].kind, @racedelta.ActualPitStop)
  assert_eq(explanation.turning_points[1].kind, @racedelta.SimulatedPitStop)
}

///|
test "M5 emits a Safety Car pit opportunity for a simulated pit" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        true,
        @racedelta.SafetyCar,
        @racedelta.Dry,
      ),
    ]),
  )
  match m5_turning_point(explanation, 1, @racedelta.SafetyCarPitOpportunity) {
    Some(point) => assert_eq(point.impact_ms, Some(10000))
    None => assert_true(false)
  }
}

///|
test "M5 derives Safety Car opportunity savings from the supplied config" {
  let config = m5_config_with_pit_losses(31000, 7000)
  let explanation = m5_explain_with_config(
    config,
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        true,
        @racedelta.SafetyCar,
        @racedelta.Dry,
      ),
    ]),
  )
  match m5_turning_point(explanation, 1, @racedelta.SafetyCarPitOpportunity) {
    Some(point) => {
      assert_eq(point.impact_ms, Some(24000))
      assert_eq(
        point.message,
        "Simulated pit during Safety Car; modeled pit loss is 24.000 s lower than GREEN.",
      )
    }
    None => assert_true(false)
  }
}

///|
test "M5 emits a relative position gain when the difference increases" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        3,
        3,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        3,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_true(
    m5_has_turning_point(explanation, 2, @racedelta.RelativePositionGain),
  )
}

///|
test "M5 emits a relative position loss when the difference decreases" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        3,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        0,
        0,
        0,
        3,
        3,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_true(
    m5_has_turning_point(explanation, 2, @racedelta.RelativePositionLoss),
  )
}

///|
test "M5 selects the largest positive single-lap gain" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        100,
        0,
        100,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        500,
        0,
        400,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(
    explanation.best_lap_gain,
    Some({ lap: 2, lap_time_gain_ms: 400, cumulative_time_gain_ms: 500, }),
  )
  assert_true(m5_has_turning_point(explanation, 2, @racedelta.BestLapGain))
}

///|
test "M5 selects the most negative single-lap loss" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        -100,
        0,
        -100,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        -600,
        0,
        -500,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(
    explanation.worst_lap_loss,
    Some({ lap: 2, lap_time_gain_ms: -500, cumulative_time_gain_ms: -600, }),
  )
  assert_true(m5_has_turning_point(explanation, 2, @racedelta.WorstLapLoss))
}

///|
test "M5 selects the earlier lap when single-lap impacts tie" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        300,
        0,
        300,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        0,
        600,
        0,
        300,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        3,
        0,
        900,
        0,
        300,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  assert_eq(
    explanation.best_lap_gain,
    Some({ lap: 1, lap_time_gain_ms: 300, cumulative_time_gain_ms: 300, }),
  )
}

///|
test "M5 orders turning points by ascending lap" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(2, 0, 0, 0, 0, 1, 1, true, false, @racedelta.Green, @racedelta.Dry),
      m5_lap(
        3,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        true,
        @racedelta.SafetyCar,
        @racedelta.Dry,
      ),
    ]),
  )
  for index = 1; index < explanation.turning_points.length(); index = index + 1 {
    assert_true(
      explanation.turning_points[index - 1].lap <=
      explanation.turning_points[index].lap,
    )
  }
}

///|
test "M5 applies the documented same-lap turning point order" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        100,
        0,
        2,
        2,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
      m5_lap(
        2,
        1,
        700,
        -100,
        700,
        2,
        1,
        true,
        true,
        @racedelta.SafetyCar,
        @racedelta.Damp,
      ),
    ]),
  )
  assert_eq(explanation.turning_points[0].kind, @racedelta.TrackStatusChange)
  assert_eq(explanation.turning_points[1].kind, @racedelta.WeatherChange)
  assert_eq(explanation.turning_points[2].kind, @racedelta.ActualPitStop)
  assert_eq(explanation.turning_points[3].kind, @racedelta.SimulatedPitStop)
  assert_eq(
    explanation.turning_points[4].kind,
    @racedelta.SafetyCarPitOpportunity,
  )
  assert_eq(explanation.turning_points[5].kind, @racedelta.PerformanceCrossover)
  assert_eq(explanation.turning_points[6].kind, @racedelta.StrategicCrossover)
  assert_eq(explanation.turning_points[7].kind, @racedelta.OpponentCrossover)
  assert_eq(explanation.turning_points[8].kind, @racedelta.RelativePositionGain)
  assert_eq(explanation.turning_points[9].kind, @racedelta.BestLapGain)
}

///|
test "M5 formats positive signed milliseconds" {
  assert_eq(@racedelta.format_signed_ms(6200), "+6.200 s")
}

///|
test "M5 formats negative signed milliseconds" {
  assert_eq(@racedelta.format_signed_ms(-450), "-0.450 s")
}

///|
test "M5 formats zero signed milliseconds" {
  assert_eq(@racedelta.format_signed_ms(0), "0.000 s")
}

///|
test "M5 formats sub-second durations without floating point" {
  assert_eq(@racedelta.format_duration_ms(7), "0.007 s")
}

///|
test "M5 Markdown report has the RaceDelta title" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  assert_true(report.contains("# RaceDelta Strategy Report"))
}

///|
test "M5 Markdown verdict includes target opponent and time conclusion" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  assert_true(report.contains("- Target: ALP"))
  assert_true(report.contains("- Opponent: BRV"))
  assert_true(report.contains("- Verdict: Improved"))
  assert_true(report.contains("- Time gain: +0.700 s"))
}

///|
test "M5 Markdown report includes strategy comparison" {
  let simulation = m5_simulation([
    m5_lap(1, 0, 0, 0, 0, 1, 1, true, false, @racedelta.Green, @racedelta.Dry),
    m5_lap(2, 0, 0, 0, 0, 1, 1, false, true, @racedelta.Green, @racedelta.Dry),
  ])
  let report = @racedelta.render_strategy_markdown(m5_explain(simulation))
  assert_true(report.contains("## Strategy Comparison"))
  assert_true(report.contains("Actual stops: Lap 1 -> MEDIUM"))
  assert_true(report.contains("Simulated stops: Lap 2 -> no following lap"))
}

///|
test "M5 Markdown report includes all three crossover sections" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  assert_true(report.contains("### Performance crossovers"))
  assert_true(report.contains("### Strategic crossovers"))
  assert_true(report.contains("### Opponent crossovers"))
}

///|
test "M5 Markdown report writes None for absent crossovers" {
  let explanation = m5_explain(
    m5_simulation([
      m5_lap(
        1,
        0,
        0,
        0,
        0,
        1,
        1,
        false,
        false,
        @racedelta.Green,
        @racedelta.Dry,
      ),
    ]),
  )
  let report = @racedelta.render_strategy_markdown(explanation)
  assert_true(report.contains("### Performance crossovers\n\nNone"))
  assert_true(report.contains("### Strategic crossovers\n\nNone"))
  assert_true(report.contains("### Opponent crossovers\n\nNone"))
}

///|
test "M5 Markdown report includes key turning points" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  assert_true(report.contains("## Key Turning Points"))
  assert_true(report.contains("Best single-lap gain."))
}

///|
test "M5 Markdown report includes a per-lap trace table" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  assert_true(report.contains("| Lap | Actual tyre | Simulated tyre |"))
  assert_true(report.contains("| 1 | MEDIUM age 1 | MEDIUM age 1 |"))
  assert_true(report.contains("| 2 | MEDIUM age 1 | SOFT age 1 |"))
}

///|
test "M5 Markdown lap trace marks pit laps" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(
      m5_simulation([
        m5_lap(
          1,
          0,
          0,
          0,
          0,
          1,
          1,
          true,
          true,
          @racedelta.Green,
          @racedelta.Dry,
        ),
      ]),
    ),
  )
  assert_true(report.contains("MEDIUM age 1 (pit)"))
}

///|
test "M5 Markdown report states the assumptions and limitations" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  assert_true(report.contains("## Assumptions and Limitations"))
  assert_true(report.contains("Only the target driver's strategy changes."))
  assert_true(report.contains("Other drivers retain their observed lap times."))
  assert_true(
    report.contains(
      "Results are explanatory counterfactuals, not precise predictions.",
    ),
  )
}

///|
test "M5 Markdown report writes No stops explicitly" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  assert_true(report.contains("- Actual stops: No stops"))
  assert_true(report.contains("- Simulated stops: No stops"))
}

///|
test "M5 maps an invalid pace model to ExplanationError" {
  m5_expect_error(
    @racedelta.explain_strategy(
      m5_config_with_pit_losses(-1, 12000),
      m5_two_lap_simulation(),
    ),
    @racedelta.InvalidModel,
    None,
  )
}

///|
test "M5 rejects an empty simulation" {
  let simulation : @racedelta.StrategySimulation = {
    request: { target_driver: "ALP", opponent_driver: "BRV", stops: [], },
    laps: [],
    summary: {
      target_driver: "ALP",
      opponent_driver: "BRV",
      lap_count: 0,
      actual_stop_count: 0,
      simulated_stop_count: 0,
      actual_total_time_ms: 0,
      simulated_total_time_ms: 0,
      time_gain_ms: 0,
      actual_finish_position: 0,
      simulated_finish_position: 0,
      positions_gained: 0,
      actual_final_signed_gap_to_opponent_ms: 0,
      simulated_final_signed_gap_to_opponent_ms: 0,
      opponent_gap_gain_ms: 0,
    },
  }
  m5_expect_error(
    @racedelta.explain_strategy(
      @racedelta.default_pace_model_config(),
      simulation,
    ),
    @racedelta.EmptySimulation,
    None,
  )
}

///|
test "M5 rejects an inconsistent simulation" {
  let comparison = m5_lap(
    2,
    0,
    0,
    0,
    0,
    1,
    1,
    false,
    false,
    @racedelta.Green,
    @racedelta.Dry,
  )
  let simulation : @racedelta.StrategySimulation = {
    request: { target_driver: "ALP", opponent_driver: "BRV", stops: [], },
    laps: [comparison],
    summary: {
      target_driver: "ALP",
      opponent_driver: "BRV",
      lap_count: 1,
      actual_stop_count: 0,
      simulated_stop_count: 0,
      actual_total_time_ms: comparison.actual_cumulative_time_ms,
      simulated_total_time_ms: comparison.simulated_cumulative_time_ms,
      time_gain_ms: comparison.cumulative_time_gain_ms,
      actual_finish_position: comparison.actual_position,
      simulated_finish_position: comparison.simulated_position,
      positions_gained: 0,
      actual_final_signed_gap_to_opponent_ms: comparison.actual_signed_gap_to_opponent_ms,
      simulated_final_signed_gap_to_opponent_ms: comparison.simulated_signed_gap_to_opponent_ms,
      opponent_gap_gain_ms: 0,
    },
  }
  m5_expect_error(
    @racedelta.explain_strategy(
      @racedelta.default_pace_model_config(),
      simulation,
    ),
    @racedelta.InconsistentSimulation,
    Some(2),
  )
}

///|
test "M5 explanation does not mutate its input simulation" {
  let simulation = m5_two_lap_simulation()
  let snapshot = simulation
  let _ = m5_explain(simulation)
  assert_eq(simulation, snapshot)
}

///|
test "M5 explanation is deterministic" {
  let simulation = m5_two_lap_simulation()
  assert_eq(m5_explain(simulation), m5_explain(simulation))
}

///|
test "M5 Markdown rendering is deterministic" {
  let explanation = m5_explain(m5_two_lap_simulation())
  assert_eq(
    @racedelta.render_strategy_markdown(explanation),
    @racedelta.render_strategy_markdown(explanation),
  )
}

///|
test "M5 renders a stable complete Improved report snapshot" {
  let report = @racedelta.render_strategy_markdown(
    m5_explain(m5_two_lap_simulation()),
  )
  let expected = "# RaceDelta Strategy Report\n\n" +
    "## Verdict\n\n" +
    "- Target: ALP\n" +
    "- Opponent: BRV\n" +
    "- Verdict: Improved\n" +
    "- Time gain: +0.700 s\n" +
    "- Finish position: actual P2; simulated P1\n" +
    "- Positions gained/lost: +1\n" +
    "- Final opponent gap: actual +0.600 s; simulated -0.100 s\n\n" +
    "## Strategy Comparison\n\n" +
    "- Actual stops: No stops\n" +
    "- Simulated stops: No stops\n\n" +
    "## Crossovers\n\n" +
    "### Performance crossovers\n\n" +
    "- Lap 2: Alternative becomes faster (0.000 s -> +0.700 s)\n\n" +
    "### Strategic crossovers\n\n" +
    "- Lap 2: Alternative becomes better (0.000 s -> +0.700 s)\n\n" +
    "### Opponent crossovers\n\n" +
    "- Lap 2: Target moves ahead of opponent (+0.100 s -> -0.100 s)\n\n" +
    "## Key Turning Points\n\n" +
    "- Lap 2: Alternative becomes faster. Impact: +0.700 s.\n" +
    "- Lap 2: Alternative becomes better. Impact: +0.700 s.\n" +
    "- Lap 2: Target moves ahead of opponent. Impact: -0.100 s.\n" +
    "- Lap 2: Relative position improved.\n" +
    "- Lap 2: Best single-lap gain. Impact: +0.700 s.\n\n" +
    "## Lap Trace\n\n" +
    "| Lap | Actual tyre | Simulated tyre | Actual position | Simulated position | Actual gap to opponent | Simulated gap to opponent | Cumulative gain |\n" +
    "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |\n" +
    "| 1 | MEDIUM age 1 | MEDIUM age 1 | P2 | P2 | +0.100 s | +0.100 s | 0.000 s |\n" +
    "| 2 | MEDIUM age 1 | SOFT age 1 | P2 | P1 | +0.600 s | -0.100 s | +0.700 s |\n\n" +
    "## Assumptions and Limitations\n\n" +
    "- Only the target driver's strategy changes.\n" +
    "- Other drivers retain their observed lap times.\n" +
    "- Weather and track status remain fixed.\n" +
    "- No traffic, overtaking-cost, DRS, or driver-response model is included.\n" +
    "- Default pace parameters are illustrative, not official F1 data.\n" +
    "- Results are explanatory counterfactuals, not precise predictions.\n"
  assert_eq(report, expected)
}

///|
test "M5 renders a stable complete Worsened report snapshot" {
  let simulation = m5_simulation([
    m5_lap(
      1,
      0,
      -250,
      75,
      -250,
      1,
      2,
      false,
      false,
      @racedelta.Green,
      @racedelta.Dry,
    ),
  ])
  let report = @racedelta.render_strategy_markdown(m5_explain(simulation))
  let expected = "# RaceDelta Strategy Report\n\n" +
    "## Verdict\n\n" +
    "- Target: ALP\n" +
    "- Opponent: BRV\n" +
    "- Verdict: Worsened\n" +
    "- Time gain: -0.250 s\n" +
    "- Finish position: actual P1; simulated P2\n" +
    "- Positions gained/lost: -1\n" +
    "- Final opponent gap: actual -0.175 s; simulated +0.075 s\n\n" +
    "## Strategy Comparison\n\n" +
    "- Actual stops: No stops\n" +
    "- Simulated stops: No stops\n\n" +
    "## Crossovers\n\n" +
    "### Performance crossovers\n\n" +
    "None\n\n" +
    "### Strategic crossovers\n\n" +
    "- Lap 1: Actual becomes better (0.000 s -> -0.250 s)\n\n" +
    "### Opponent crossovers\n\n" +
    "None\n\n" +
    "## Key Turning Points\n\n" +
    "- Lap 1: Actual becomes better. Impact: -0.250 s.\n" +
    "- Lap 1: Worst single-lap loss. Impact: -0.250 s.\n\n" +
    "## Lap Trace\n\n" +
    "| Lap | Actual tyre | Simulated tyre | Actual position | Simulated position | Actual gap to opponent | Simulated gap to opponent | Cumulative gain |\n" +
    "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |\n" +
    "| 1 | MEDIUM age 1 | MEDIUM age 1 | P1 | P2 | -0.175 s | +0.075 s | -0.250 s |\n\n" +
    "## Assumptions and Limitations\n\n" +
    "- Only the target driver's strategy changes.\n" +
    "- Other drivers retain their observed lap times.\n" +
    "- Weather and track status remain fixed.\n" +
    "- No traffic, overtaking-cost, DRS, or driver-response model is included.\n" +
    "- Default pace parameters are illustrative, not official F1 data.\n" +
    "- Results are explanatory counterfactuals, not precise predictions.\n"
  assert_eq(report, expected)
}
