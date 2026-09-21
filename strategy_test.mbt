///|
fn strategy_csv(rows : String) -> String {
  "lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather\n" +
  rows
}

///|
fn single_stop_race_csv() -> String {
  strategy_csv(
    "1,ALP,99300,SOFT,1,false,GREEN,DRY\n" +
    "1,BRV,100000,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,121420,SOFT,2,true,GREEN,DRY\n" +
    "2,BRV,100000,MEDIUM,2,false,GREEN,DRY\n" +
    "3,ALP,100000,MEDIUM,1,false,GREEN,DRY\n" +
    "3,BRV,100000,MEDIUM,3,false,GREEN,DRY\n" +
    "4,ALP,100080,MEDIUM,2,false,GREEN,DRY\n" +
    "4,BRV,100000,MEDIUM,4,false,GREEN,DRY",
  )
}

///|
fn multi_stop_race_csv() -> String {
  strategy_csv(
    "1,ALP,99300,SOFT,1,false,GREEN,DRY\n" +
    "1,BRV,100000,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,121420,SOFT,2,true,GREEN,DRY\n" +
    "2,BRV,100000,MEDIUM,2,false,GREEN,DRY\n" +
    "3,ALP,122000,MEDIUM,1,true,GREEN,DRY\n" +
    "3,BRV,100000,MEDIUM,3,false,GREEN,DRY\n" +
    "4,ALP,100500,HARD,1,false,GREEN,DRY\n" +
    "4,BRV,100000,MEDIUM,4,false,GREEN,DRY\n" +
    "5,ALP,100555,HARD,2,false,GREEN,DRY\n" +
    "5,BRV,100000,MEDIUM,5,false,GREEN,DRY",
  )
}

///|
fn safety_car_race_csv() -> String {
  strategy_csv(
    "1,ALP,99300,SOFT,1,false,GREEN,DRY\n" +
    "1,BRV,100000,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,111420,SOFT,2,true,SAFETY_CAR,DRY\n" +
    "2,BRV,100000,MEDIUM,2,false,SAFETY_CAR,DRY\n" +
    "3,ALP,100000,MEDIUM,1,false,GREEN,DRY\n" +
    "3,BRV,100000,MEDIUM,3,false,GREEN,DRY\n" +
    "4,ALP,100080,MEDIUM,2,false,GREEN,DRY\n" +
    "4,BRV,100000,MEDIUM,4,false,GREEN,DRY",
  )
}

///|
fn damp_race_csv() -> String {
  strategy_csv(
    "1,ALP,106500,SOFT,1,false,GREEN,DAMP\n" +
    "1,BRV,107000,MEDIUM,1,false,GREEN,DAMP\n" +
    "2,ALP,106620,SOFT,2,false,GREEN,DAMP\n" +
    "2,BRV,107080,MEDIUM,2,false,GREEN,DAMP",
  )
}

///|
fn wet_race_csv() -> String {
  strategy_csv(
    "1,ALP,124000,SOFT,1,false,GREEN,WET\n" +
    "1,BRV,125000,MEDIUM,1,false,GREEN,WET\n" +
    "2,ALP,124120,SOFT,2,false,GREEN,WET\n" +
    "2,BRV,125080,MEDIUM,2,false,GREEN,WET",
  )
}

///|
fn tie_race_csv() -> String {
  strategy_csv(
    "1,ALP,100000,MEDIUM,1,false,GREEN,DRY\n" +
    "1,BRV,100000,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,100080,MEDIUM,2,false,GREEN,DRY\n" +
    "2,BRV,100080,MEDIUM,2,false,GREEN,DRY",
  )
}

///|
fn neutral_failure_race_csv() -> String {
  strategy_csv(
    "1,ALP,8000,WET,1,false,GREEN,DRY\n" +
    "1,BRV,100000,MEDIUM,1,false,GREEN,DRY",
  )
}

///|
fn estimate_failure_race_csv() -> String {
  strategy_csv(
    "1,ALP,500,MEDIUM,1,false,GREEN,DRY\n" +
    "1,BRV,1000,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,580,MEDIUM,2,false,GREEN,DRY\n" +
    "2,BRV,1080,MEDIUM,2,false,GREEN,DRY",
  )
}

///|
fn request_with(
  stops : Array[@racedelta.PlannedPitStop],
) -> @racedelta.StrategyRequest {
  { target_driver: "ALP", opponent_driver: "BRV", stops, }
}

///|
fn planned_stop(
  lap : Int,
  compound : @racedelta.Compound,
) -> @racedelta.PlannedPitStop {
  { pit_lap: lap, next_compound: compound, }
}

///|
fn parse_data(csv : String) -> @racedelta.RaceData {
  match @racedelta.parse_race_csv(csv) {
    Ok(data) => data
    Err(_) => panic()
  }
}

///|
fn simulate(
  csv : String,
  request : @racedelta.StrategyRequest,
) -> @racedelta.StrategySimulation {
  match
    @racedelta.simulate_strategy(
      parse_data(csv),
      @racedelta.default_pace_model_config(),
      request,
    ) {
    Ok(result) => result
    Err(_) => panic()
  }
}

///|
fn invalid_pace_model() -> @racedelta.PaceModelConfig {
  let config = @racedelta.default_pace_model_config()
  {
    tyre_profiles: config.tyre_profiles,
    pit_loss_profile: {
      green_pit_loss_ms: -1,
      safety_car_pit_loss_ms: config.pit_loss_profile.safety_car_pit_loss_ms,
    },
  }
}

///|
fn expect_strategy_error(
  result : Result[@racedelta.StrategySimulation, @racedelta.StrategyError],
  code : @racedelta.StrategyErrorCode,
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
test "M4 replays matching single stop strategy exactly" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(2, @racedelta.Medium)]),
  )
  assert_eq(simulation.laps.length(), 4)
  for comparison in simulation.laps {
    assert_eq(comparison.actual_lap_time_ms, comparison.simulated_lap_time_ms)
    assert_eq(
      comparison.actual_cumulative_time_ms,
      comparison.simulated_cumulative_time_ms,
    )
    assert_eq(comparison.actual_compound, comparison.simulated_compound)
    assert_eq(
      comparison.actual_tyre_age_laps,
      comparison.simulated_tyre_age_laps,
    )
    assert_eq(comparison.actual_pit, comparison.simulated_pit)
    assert_eq(comparison.actual_position, comparison.simulated_position)
    assert_eq(comparison.cumulative_time_gain_ms, 0)
  }
}

///|
test "M4 replays matching multiple stop strategy exactly" {
  let simulation = simulate(
    multi_stop_race_csv(),
    request_with([
      planned_stop(2, @racedelta.Medium),
      planned_stop(3, @racedelta.Hard),
    ]),
  )
  assert_eq(simulation.laps.length(), 5)
  assert_eq(simulation.summary.actual_stop_count, 2)
  assert_eq(simulation.summary.simulated_stop_count, 2)
  assert_eq(simulation.summary.time_gain_ms, 0)
  assert_eq(simulation.summary.positions_gained, 0)
  assert_eq(simulation.summary.opponent_gap_gain_ms, 0)
}

///|
test "M4 matching replay preserves every target lap and cumulative time" {
  let simulation = simulate(
    multi_stop_race_csv(),
    request_with([
      planned_stop(2, @racedelta.Medium),
      planned_stop(3, @racedelta.Hard),
    ]),
  )
  assert_eq(simulation.laps[0].simulated_lap_time_ms, 99300)
  assert_eq(simulation.laps[1].simulated_lap_time_ms, 121420)
  assert_eq(simulation.laps[2].simulated_lap_time_ms, 122000)
  assert_eq(simulation.laps[4].simulated_cumulative_time_ms, 543775)
}

///|
test "M4 matching replay preserves position and all gains" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(2, @racedelta.Medium)]),
  )
  assert_eq(simulation.summary.actual_finish_position, 2)
  assert_eq(simulation.summary.simulated_finish_position, 2)
  assert_eq(simulation.summary.time_gain_ms, 0)
  assert_eq(simulation.summary.positions_gained, 0)
  assert_eq(simulation.summary.opponent_gap_gain_ms, 0)
}

///|
test "M4 empty stops creates a no pit strategy" {
  let simulation = simulate(single_stop_race_csv(), request_with([]))
  assert_eq(simulation.request.stops.length(), 0)
  assert_eq(simulation.summary.simulated_stop_count, 0)
  assert_eq(simulation.laps[0].simulated_pit, false)
  assert_eq(simulation.laps[1].simulated_pit, false)
  assert_eq(simulation.laps[2].simulated_pit, false)
  assert_eq(simulation.laps[3].simulated_pit, false)
}

///|
test "M4 can plan a first lap end pit stop" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(1, @racedelta.Medium)]),
  )
  assert_eq(simulation.laps[0].simulated_compound, @racedelta.Soft)
  assert_eq(simulation.laps[0].simulated_tyre_age_laps, 1)
  assert_eq(simulation.laps[0].simulated_pit, true)
  assert_eq(simulation.laps[1].simulated_compound, @racedelta.Medium)
  assert_eq(simulation.laps[1].simulated_tyre_age_laps, 1)
}

///|
test "M4 can move a pit earlier" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(1, @racedelta.Medium)]),
  )
  assert_eq(simulation.laps[1].simulated_lap_time_ms, 100000)
  assert_eq(simulation.summary.simulated_stop_count, 1)
}

///|
test "M4 can move a pit later" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(3, @racedelta.Medium)]),
  )
  assert_eq(simulation.laps[1].simulated_pit, false)
  assert_eq(simulation.laps[2].simulated_pit, true)
  assert_eq(simulation.laps[3].simulated_compound, @racedelta.Medium)
}

///|
test "M4 can replace a stop with a different compound" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(2, @racedelta.Hard)]),
  )
  assert_eq(simulation.laps[1].simulated_compound, @racedelta.Soft)
  assert_eq(simulation.laps[2].simulated_compound, @racedelta.Hard)
  assert_eq(simulation.laps[2].simulated_lap_time_ms, 100500)
}

///|
test "M4 same compound planned stop creates fresh tyres" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(2, @racedelta.Soft)]),
  )
  assert_eq(simulation.laps[1].simulated_pit, true)
  assert_eq(simulation.laps[2].simulated_compound, @racedelta.Soft)
  assert_eq(simulation.laps[2].simulated_tyre_age_laps, 1)
}

///|
test "M4 supports multiple planned pit stops" {
  let simulation = simulate(
    multi_stop_race_csv(),
    request_with([
      planned_stop(1, @racedelta.Medium),
      planned_stop(3, @racedelta.Hard),
    ]),
  )
  assert_eq(simulation.summary.simulated_stop_count, 2)
  assert_eq(simulation.laps[0].simulated_pit, true)
  assert_eq(simulation.laps[2].simulated_pit, true)
  assert_eq(simulation.laps[3].simulated_compound, @racedelta.Hard)
}

///|
test "M4 normalizes unordered planned stops" {
  let simulation = simulate(
    multi_stop_race_csv(),
    request_with([
      planned_stop(3, @racedelta.Hard),
      planned_stop(1, @racedelta.Medium),
    ]),
  )
  assert_eq(simulation.request.stops[0].pit_lap, 1)
  assert_eq(simulation.request.stops[1].pit_lap, 3)
}

///|
test "M4 returns comparisons in ascending lap order" {
  let simulation = simulate(
    multi_stop_race_csv(),
    request_with([
      planned_stop(3, @racedelta.Hard),
      planned_stop(1, @racedelta.Medium),
    ]),
  )
  assert_eq(simulation.laps[0].lap, 1)
  assert_eq(simulation.laps[1].lap, 2)
  assert_eq(simulation.laps[2].lap, 3)
  assert_eq(simulation.laps[3].lap, 4)
  assert_eq(simulation.laps[4].lap, 5)
}

///|
test "M4 replacement plan does not leak unplanned actual pits" {
  let simulation = simulate(single_stop_race_csv(), request_with([]))
  assert_eq(simulation.laps[1].actual_pit, true)
  assert_eq(simulation.laps[1].simulated_pit, false)
  assert_eq(simulation.laps[2].simulated_compound, @racedelta.Soft)
  assert_eq(simulation.laps[2].simulated_tyre_age_laps, 3)
}

///|
test "M4 pit lap uses outgoing tyre and next lap uses selected tyre" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(2, @racedelta.Hard)]),
  )
  assert_eq(simulation.laps[1].simulated_compound, @racedelta.Soft)
  assert_eq(simulation.laps[1].simulated_tyre_age_laps, 2)
  assert_eq(simulation.laps[1].simulated_pit, true)
  assert_eq(simulation.laps[2].simulated_compound, @racedelta.Hard)
  assert_eq(simulation.laps[2].simulated_tyre_age_laps, 1)
}

///|
test "M4 no pit tyre age increments continuously" {
  let simulation = simulate(single_stop_race_csv(), request_with([]))
  assert_eq(simulation.laps[0].simulated_tyre_age_laps, 1)
  assert_eq(simulation.laps[1].simulated_tyre_age_laps, 2)
  assert_eq(simulation.laps[2].simulated_tyre_age_laps, 3)
  assert_eq(simulation.laps[3].simulated_tyre_age_laps, 4)
}

///|
test "M4 green pit adds 22000 ms against the neutral anchor" {
  let simulation = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(1, @racedelta.Medium)]),
  )
  assert_eq(simulation.laps[0].neutral_lap_time_ms, 100000)
  assert_eq(simulation.laps[0].simulated_lap_time_ms, 121300)
}

///|
test "M4 safety car pit adds 12000 ms against the neutral anchor" {
  let simulation = simulate(
    safety_car_race_csv(),
    request_with([planned_stop(2, @racedelta.Medium)]),
  )
  assert_eq(simulation.laps[1].neutral_lap_time_ms, 100000)
  assert_eq(simulation.laps[1].simulated_lap_time_ms, 111420)
}

///|
test "M4 moving a pit to safety car shows the pit loss difference" {
  let original = simulate(
    safety_car_race_csv(),
    request_with([planned_stop(2, @racedelta.Medium)]),
  )
  let moved = simulate(
    safety_car_race_csv(),
    request_with([planned_stop(3, @racedelta.Medium)]),
  )
  assert_eq(
    original.laps[1].simulated_lap_time_ms - moved.laps[1].simulated_lap_time_ms,
    12000,
  )
  assert_eq(moved.laps[2].simulated_pit, true)
}

///|
test "M4 dry compound choice changes simulated lap time" {
  let soft = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(1, @racedelta.Soft)]),
  )
  let hard = simulate(
    single_stop_race_csv(),
    request_with([planned_stop(1, @racedelta.Hard)]),
  )
  assert_true(
    soft.laps[1].simulated_lap_time_ms < hard.laps[1].simulated_lap_time_ms,
  )
  assert_eq(soft.laps[1].simulated_lap_time_ms, 99300)
  assert_eq(hard.laps[1].simulated_lap_time_ms, 100500)
}

///|
test "M4 intermediate tyres use the DAMP fresh delta" {
  let simulation = simulate(
    damp_race_csv(),
    request_with([planned_stop(1, @racedelta.Intermediate)]),
  )
  assert_eq(simulation.laps[1].weather, @racedelta.Damp)
  assert_eq(simulation.laps[1].simulated_compound, @racedelta.Intermediate)
  assert_eq(simulation.laps[1].simulated_lap_time_ms, 100000)
}

///|
test "M4 wet tyres use the WET fresh delta" {
  let simulation = simulate(
    wet_race_csv(),
    request_with([planned_stop(1, @racedelta.Wet)]),
  )
  assert_eq(simulation.laps[1].weather, @racedelta.Wet)
  assert_eq(simulation.laps[1].simulated_compound, @racedelta.Wet)
  assert_eq(simulation.laps[1].simulated_lap_time_ms, 100500)
}

///|
test "M4 retains actual weather and track status on every comparison" {
  let simulation = simulate(
    safety_car_race_csv(),
    request_with([planned_stop(3, @racedelta.Hard)]),
  )
  assert_eq(simulation.laps[0].track_status, @racedelta.Green)
  assert_eq(simulation.laps[1].track_status, @racedelta.SafetyCar)
  assert_eq(simulation.laps[1].weather, @racedelta.Dry)
}

///|
test "M4 reports signed opponent gaps and final gains consistently" {
  let simulation = simulate(single_stop_race_csv(), request_with([]))
  let final_lap = simulation.laps[3]
  assert_eq(final_lap.actual_signed_gap_to_opponent_ms, 20800)
  assert_eq(final_lap.simulated_signed_gap_to_opponent_ms, -2080)
  assert_eq(final_lap.cumulative_time_gain_ms, 22880)
  assert_eq(simulation.summary.actual_final_signed_gap_to_opponent_ms, 20800)
  assert_eq(simulation.summary.simulated_final_signed_gap_to_opponent_ms, -2080)
  assert_eq(simulation.summary.opponent_gap_gain_ms, 22880)
}

///|
test "M4 recomputes target positions against unchanged actual rivals" {
  let data = parse_data(single_stop_race_csv())
  let analysis = @racedelta.analyze_race(data)
  let simulation = simulate(single_stop_race_csv(), request_with([]))
  match @racedelta.find_lap_state(analysis, "BRV", 4) {
    Some(opponent) => {
      assert_eq(opponent.cumulative_time_ms, 400000)
      assert_eq(
        simulation.laps[3].actual_cumulative_time_ms -
        simulation.laps[3].actual_signed_gap_to_opponent_ms,
        opponent.cumulative_time_ms,
      )
      assert_eq(
        simulation.laps[3].simulated_cumulative_time_ms -
        simulation.laps[3].simulated_signed_gap_to_opponent_ms,
        opponent.cumulative_time_ms,
      )
    }
    None => assert_true(false)
  }
}

///|
test "M4 summary reports finish position and position gain" {
  let simulation = simulate(single_stop_race_csv(), request_with([]))
  assert_eq(simulation.summary.actual_total_time_ms, 420800)
  assert_eq(simulation.summary.simulated_total_time_ms, 397920)
  assert_eq(simulation.summary.time_gain_ms, 22880)
  assert_eq(simulation.summary.actual_finish_position, 2)
  assert_eq(simulation.summary.simulated_finish_position, 1)
  assert_eq(simulation.summary.positions_gained, 1)
}

///|
test "M4 resolves simulated timing ties by driver name" {
  let simulation = simulate(tie_race_csv(), request_with([]))
  assert_eq(simulation.laps[0].actual_position, 1)
  assert_eq(simulation.laps[0].simulated_position, 1)
  assert_eq(simulation.summary.simulated_finish_position, 1)
}

///|
test "M4 simulation preserves its RaceData input" {
  let data = parse_data(single_stop_race_csv())
  let snapshot = data
  match
    @racedelta.simulate_strategy(
      data,
      @racedelta.default_pace_model_config(),
      request_with([]),
    ) {
    Ok(_) => assert_eq(data, snapshot)
    Err(_) => assert_true(false)
  }
}

///|
test "M4 simulation does not mutate the request and returns normalized stops" {
  let request = request_with([
    planned_stop(3, @racedelta.Hard),
    planned_stop(1, @racedelta.Medium),
  ])
  let snapshot = request
  let simulation = simulate(multi_stop_race_csv(), request)
  assert_eq(request, snapshot)
  assert_eq(simulation.request.stops[0].pit_lap, 1)
  assert_eq(simulation.request.stops[1].pit_lap, 3)
}

///|
test "M4 returns deterministic results for the same input" {
  let request = request_with([planned_stop(1, @racedelta.Hard)])
  let first = simulate(single_stop_race_csv(), request)
  let second = simulate(single_stop_race_csv(), request)
  assert_eq(first, second)
}

///|
test "M4 rejects an unknown target driver" {
  let request : @racedelta.StrategyRequest = {
    target_driver: "MISSING",
    opponent_driver: "BRV",
    stops: [],
  }
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request,
    ),
    @racedelta.UnknownTargetDriver,
    None,
  )
}

///|
test "M4 rejects an unknown opponent driver" {
  let request : @racedelta.StrategyRequest = {
    target_driver: "ALP",
    opponent_driver: "MISSING",
    stops: [],
  }
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request,
    ),
    @racedelta.UnknownOpponentDriver,
    None,
  )
}

///|
test "M4 rejects a target and opponent that are the same driver" {
  let request : @racedelta.StrategyRequest = {
    target_driver: "ALP",
    opponent_driver: "ALP",
    stops: [],
  }
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request,
    ),
    @racedelta.SameDriver,
    None,
  )
}

///|
test "M4 rejects a planned pit before lap one" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request_with([planned_stop(0, @racedelta.Medium)]),
    ),
    @racedelta.InvalidPitLap,
    Some(0),
  )
}

///|
test "M4 rejects a negative planned pit lap" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request_with([planned_stop(-1, @racedelta.Medium)]),
    ),
    @racedelta.InvalidPitLap,
    Some(-1),
  )
}

///|
test "M4 rejects a final lap planned pit" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request_with([planned_stop(4, @racedelta.Medium)]),
    ),
    @racedelta.InvalidPitLap,
    Some(4),
  )
}

///|
test "M4 rejects a planned pit beyond the race" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request_with([planned_stop(5, @racedelta.Medium)]),
    ),
    @racedelta.InvalidPitLap,
    Some(5),
  )
}

///|
test "M4 rejects duplicate planned pit laps" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      @racedelta.default_pace_model_config(),
      request_with([
        planned_stop(2, @racedelta.Medium),
        planned_stop(2, @racedelta.Hard),
      ]),
    ),
    @racedelta.DuplicatePitLap,
    Some(2),
  )
}

///|
test "M4 maps invalid pace models to a strategy error" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(single_stop_race_csv()),
      invalid_pace_model(),
      request_with([]),
    ),
    @racedelta.InvalidModel,
    None,
  )
}

///|
test "M4 maps impossible actual laps to a neutral anchor error" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(neutral_failure_race_csv()),
      @racedelta.default_pace_model_config(),
      request_with([]),
    ),
    @racedelta.NeutralLapFailure,
    Some(1),
  )
}

///|
test "M4 maps impossible replay laps to an estimate error" {
  expect_strategy_error(
    @racedelta.simulate_strategy(
      parse_data(estimate_failure_race_csv()),
      @racedelta.default_pace_model_config(),
      request_with([planned_stop(1, @racedelta.Soft)]),
    ),
    @racedelta.EstimatedLapFailure,
    Some(2),
  )
}
