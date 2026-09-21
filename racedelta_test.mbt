///|
fn valid_csv() -> String {
  "lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather\n" +
  "1,ALP,90000,SOFT,3,false,GREEN,DRY\n" +
  "1,BRV,90500,MEDIUM,4,false,GREEN,DRY\n" +
  "2,ALP,90100,SOFT,4,true,GREEN,DRY\n" +
  "2,BRV,90600,MEDIUM,5,false,GREEN,DRY\n" +
  "3,ALP,90200,MEDIUM,1,false,GREEN,DRY\n" +
  "3,BRV,90700,MEDIUM,6,false,GREEN,DRY"
}

///|
fn expect_error(
  csv : String,
  code : @racedelta.RaceErrorCode,
  line : Int,
  field : String,
) -> Unit raise {
  match @racedelta.parse_race_csv(csv) {
    Err(error) => {
      assert_eq(error.code, code)
      assert_eq(error.line, line)
      assert_eq(error.field, field)
    }
    Ok(_) => assert_true(false)
  }
}

///|
test "project scaffold" {
  assert_eq(1 + 1, 2)
}

///|
test "parses two drivers" {
  match @racedelta.parse_race_csv(valid_csv()) {
    Ok(data) => {
      assert_eq(data.records.length(), 6)
      assert_eq(data.records[0].driver, "ALP")
      assert_eq(data.records[1].driver, "BRV")
      assert_eq(data.records[5].lap, 3)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "accepts CRLF" {
  match
    @racedelta.parse_race_csv(valid_csv().replace_all(old="\n", new="\r\n")) {
    Ok(data) => assert_eq(data.records.length(), 6)
    Err(_) => assert_true(false)
  }
}

///|
test "trims cell whitespace" {
  let csv = valid_csv().replace(
    old="1,ALP,90000,SOFT,3,false,GREEN,DRY",
    new=" 1 , ALP , 90000 , SOFT , 3 , false , GREEN , DRY ",
  )
  match @racedelta.parse_race_csv(csv) {
    Ok(data) => assert_eq(data.records[0].driver, "ALP")
    Err(_) => assert_true(false)
  }
}

///|
test "ignores blank lines" {
  let csv = "\n\n" +
    valid_csv().replace(
      old="1,BRV,90500,MEDIUM,4,false,GREEN,DRY",
      new="\n\n1,BRV,90500,MEDIUM,4,false,GREEN,DRY\n",
    ) +
    "\n\t\n"
  match @racedelta.parse_race_csv(csv) {
    Ok(data) => assert_eq(data.records.length(), 6)
    Err(_) => assert_true(false)
  }
}

///|
test "rejects invalid header" {
  expect_error(
    valid_csv().replace(old="lap,driver", new="driver,lap"),
    @racedelta.InvalidHeader,
    1,
    "header",
  )
}

///|
test "rejects wrong field count" {
  expect_error(
    valid_csv().replace(
      old="1,ALP,90000,SOFT,3,false,GREEN,DRY",
      new="1,ALP,90000",
    ),
    @racedelta.FieldCount,
    2,
    "row",
  )
}

///|
test "rejects invalid integer" {
  expect_error(
    valid_csv().replace(old="90000", new="fast"),
    @racedelta.InvalidInteger,
    2,
    "lap_time_ms",
  )
}

///|
test "rejects invalid compound" {
  expect_error(
    valid_csv().replace(old="SOFT", new="ULTRA"),
    @racedelta.InvalidValue,
    2,
    "compound",
  )
}

///|
test "rejects invalid pit boolean" {
  expect_error(
    valid_csv().replace(old="3,false,GREEN", new="3,TRUE,GREEN"),
    @racedelta.InvalidValue,
    2,
    "pit",
  )
}

///|
test "rejects invalid track status" {
  expect_error(
    valid_csv().replace(old="GREEN,DRY", new="YELLOW,DRY"),
    @racedelta.InvalidValue,
    2,
    "track_status",
  )
}

///|
test "rejects invalid weather" {
  expect_error(
    valid_csv().replace(old="GREEN,DRY", new="GREEN,RAIN"),
    @racedelta.InvalidValue,
    2,
    "weather",
  )
}

///|
test "rejects duplicate driver lap" {
  let csv = valid_csv() + "\n1,ALP,91000,SOFT,3,false,GREEN,DRY"
  expect_error(csv, @racedelta.DuplicateDriverLap, 8, "driver,lap")
}

///|
test "rejects missing lap number" {
  let csv = valid_csv().replace(
    old="2,ALP,90100,SOFT,4,true,GREEN,DRY\n",
    new="",
  )
  expect_error(csv, @racedelta.MissingLap, 0, "lap")
}

///|
test "rejects inconsistent driver laps" {
  let csv = valid_csv().replace(
    old="3,BRV,90700,MEDIUM,6,false,GREEN,DRY",
    new="",
  )
  expect_error(csv, @racedelta.InconsistentLaps, 0, "lap")
}

///|
test "rejects different track status on one lap" {
  let csv = valid_csv().replace(
    old="2,BRV,90600,MEDIUM,5,false,GREEN,DRY",
    new="2,BRV,90600,MEDIUM,5,false,SAFETY_CAR,DRY",
  )
  expect_error(csv, @racedelta.InconsistentTrackStatus, 5, "track_status")
}

///|
test "rejects different weather on one lap" {
  let csv = valid_csv().replace(
    old="2,BRV,90600,MEDIUM,5,false,GREEN,DRY",
    new="2,BRV,90600,MEDIUM,5,false,GREEN,DAMP",
  )
  expect_error(csv, @racedelta.InconsistentWeather, 5, "weather")
}

///|
test "rejects compound change without pit" {
  let csv = valid_csv().replace(
    old="2,BRV,90600,MEDIUM,5,false,GREEN,DRY",
    new="2,BRV,90600,HARD,5,false,GREEN,DRY",
  )
  expect_error(csv, @racedelta.InvalidTyreTransition, 5, "compound")
}

///|
test "rejects tyre age that does not increment" {
  let csv = valid_csv().replace(
    old="2,BRV,90600,MEDIUM,5,false,GREEN,DRY",
    new="2,BRV,90600,MEDIUM,4,false,GREEN,DRY",
  )
  expect_error(csv, @racedelta.InvalidTyreTransition, 5, "tyre_age_laps")
}

///|
test "rejects tyre age after pit" {
  let csv = valid_csv().replace(
    old="3,ALP,90200,MEDIUM,1,false,GREEN,DRY",
    new="3,ALP,90200,MEDIUM,2,false,GREEN,DRY",
  )
  expect_error(csv, @racedelta.InvalidTyreTransition, 6, "tyre_age_laps")
}

///|
test "normalizes record order" {
  let header = "lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather\n"
  let rows = "3,BRV,90700,MEDIUM,6,false,GREEN,DRY\n2,ALP,90100,SOFT,4,true,GREEN,DRY\n1,BRV,90500,MEDIUM,4,false,GREEN,DRY\n3,ALP,90200,MEDIUM,1,false,GREEN,DRY\n1,ALP,90000,SOFT,3,false,GREEN,DRY\n2,BRV,90600,MEDIUM,5,false,GREEN,DRY"
  match @racedelta.parse_race_csv(header + rows) {
    Ok(data) => {
      assert_eq(data.records[0].lap, 1)
      assert_eq(data.records[0].driver, "ALP")
      assert_eq(data.records[5].driver, "BRV")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "accepts dry damp wet transitions" {
  let csv = valid_csv()
    .replace(
      old="2,ALP,90100,SOFT,4,true,GREEN,DRY",
      new="2,ALP,90100,SOFT,4,true,GREEN,DAMP",
    )
    .replace(
      old="2,BRV,90600,MEDIUM,5,false,GREEN,DRY",
      new="2,BRV,90600,MEDIUM,5,false,GREEN,DAMP",
    )
    .replace(
      old="3,ALP,90200,MEDIUM,1,false,GREEN,DRY",
      new="3,ALP,90200,MEDIUM,1,false,GREEN,WET",
    )
    .replace(
      old="3,BRV,90700,MEDIUM,6,false,GREEN,DRY",
      new="3,BRV,90700,MEDIUM,6,false,GREEN,WET",
    )
  match @racedelta.parse_race_csv(csv) {
    Ok(data) => assert_eq(data.records[5].weather, @racedelta.Wet)
    Err(_) => assert_true(false)
  }
}

///|
test "accepts safety car lap" {
  let csv = valid_csv()
    .replace(
      old="2,ALP,90100,SOFT,4,true,GREEN,DRY",
      new="2,ALP,90100,SOFT,4,true,SAFETY_CAR,DRY",
    )
    .replace(
      old="2,BRV,90600,MEDIUM,5,false,GREEN,DRY",
      new="2,BRV,90600,MEDIUM,5,false,SAFETY_CAR,DRY",
    )
  match @racedelta.parse_race_csv(csv) {
    Ok(data) => assert_eq(data.records[2].track_status, @racedelta.SafetyCar)
    Err(_) => assert_true(false)
  }
}

///|
fn csv_with_rows(rows : String) -> String {
  "lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather\n" +
  rows
}

///|
fn analysis_for(csv : String) -> @racedelta.RaceAnalysis {
  match @racedelta.parse_race_csv(csv) {
    Ok(data) => @racedelta.analyze_race(data)
    Err(_) => panic()
  }
}

///|
fn base_analysis() -> @racedelta.RaceAnalysis {
  analysis_for(valid_csv())
}

///|
fn single_driver_csv() -> String {
  csv_with_rows(
    "1,ALP,100,SOFT,3,false,GREEN,DRY\n" +
    "2,ALP,110,SOFT,4,false,GREEN,DRY\n" +
    "3,ALP,120,SOFT,5,false,GREEN,DRY",
  )
}

///|
fn tie_csv() -> String {
  csv_with_rows(
    "1,ALP,100,SOFT,1,false,GREEN,DRY\n" +
    "1,BRV,100,SOFT,1,false,GREEN,DRY\n" +
    "2,ALP,100,SOFT,2,false,GREEN,DRY\n" +
    "2,BRV,100,SOFT,2,false,GREEN,DRY",
  )
}

///|
fn overtake_csv() -> String {
  csv_with_rows(
    "1,ALP,100,SOFT,1,false,GREEN,DRY\n" +
    "1,BRV,101,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,105,SOFT,2,false,GREEN,DRY\n" +
    "2,BRV,100,MEDIUM,2,false,GREEN,DRY",
  )
}

///|
test "M2 computes single driver cumulative times" {
  let analysis = analysis_for(single_driver_csv())
  assert_eq(analysis.lap_count, 3)
  assert_eq(analysis.states[0].cumulative_time_ms, 100)
  assert_eq(analysis.states[1].cumulative_time_ms, 210)
  assert_eq(analysis.states[2].cumulative_time_ms, 330)
}

///|
test "M2 computes multiple driver cumulative times by lap" {
  let analysis = base_analysis()
  assert_eq(analysis.states[0].cumulative_time_ms, 90000)
  assert_eq(analysis.states[1].cumulative_time_ms, 90500)
  assert_eq(analysis.states[2].cumulative_time_ms, 180100)
  assert_eq(analysis.states[3].cumulative_time_ms, 181100)
}

///|
test "M2 ranks drivers by cumulative time" {
  let analysis = analysis_for(overtake_csv())
  assert_eq(analysis.states[0].position, 1)
  assert_eq(analysis.states[1].position, 2)
  assert_eq(analysis.states[2].position, 2)
  assert_eq(analysis.states[3].position, 1)
}

///|
test "M2 calculates gap to leader" {
  let analysis = base_analysis()
  assert_eq(analysis.states[0].gap_to_leader_ms, 0)
  assert_eq(analysis.states[1].gap_to_leader_ms, 500)
  assert_eq(analysis.states[3].gap_to_leader_ms, 1000)
}

///|
test "M2 calculates interval to ahead" {
  let analysis = base_analysis()
  assert_eq(analysis.states[1].interval_to_ahead_ms, Some(500))
  assert_eq(analysis.states[3].interval_to_ahead_ms, Some(1000))
}

///|
test "M2 represents P1 interval as none" {
  let analysis = base_analysis()
  assert_eq(analysis.states[0].interval_to_ahead_ms, None)
  assert_eq(analysis.states[2].interval_to_ahead_ms, None)
}

///|
test "M2 uses driver name as equal time tie break" {
  let analysis = analysis_for(tie_csv())
  assert_eq(analysis.states[0].driver, "ALP")
  assert_eq(analysis.states[0].position, 1)
  assert_eq(analysis.states[1].driver, "BRV")
  assert_eq(analysis.states[1].position, 2)
}

///|
test "M2 equal time second place has zero leader gap" {
  let analysis = analysis_for(tie_csv())
  assert_eq(analysis.states[1].gap_to_leader_ms, 0)
  assert_eq(analysis.states[1].interval_to_ahead_ms, Some(0))
}

///|
test "M2 signed gap is positive when driver trails" {
  let analysis = base_analysis()
  assert_eq(@racedelta.signed_gap_ms(analysis, "BRV", "ALP", 2), Some(1000))
}

///|
test "M2 signed gap is negative when driver leads" {
  let analysis = base_analysis()
  assert_eq(@racedelta.signed_gap_ms(analysis, "ALP", "BRV", 2), Some(-1000))
}

///|
test "M2 signed gap is zero for equal cumulative time" {
  let analysis = analysis_for(tie_csv())
  assert_eq(@racedelta.signed_gap_ms(analysis, "ALP", "BRV", 2), Some(0))
}

///|
test "M2 unknown driver query returns none" {
  let analysis = base_analysis()
  assert_eq(@racedelta.find_lap_state(analysis, "XXX", 1), None)
  assert_eq(@racedelta.signed_gap_ms(analysis, "ALP", "XXX", 1), None)
  assert_eq(@racedelta.stints_for_driver(analysis, "XXX").length(), 0)
}

///|
test "M2 unknown lap query returns none" {
  let analysis = base_analysis()
  assert_eq(@racedelta.find_lap_state(analysis, "ALP", 99), None)
  assert_eq(@racedelta.signed_gap_ms(analysis, "ALP", "BRV", 99), None)
}

///|
test "M2 creates one stint without a pit stop" {
  let analysis = analysis_for(single_driver_csv())
  let stints = @racedelta.stints_for_driver(analysis, "ALP")
  assert_eq(stints.length(), 1)
  assert_eq(stints[0].stint_number, 1)
  assert_eq(stints[0].start_lap, 1)
  assert_eq(stints[0].end_lap, 3)
  assert_eq(stints[0].ended_by_pit, false)
}

///|
test "M2 one pit stop creates two stints" {
  let analysis = base_analysis()
  let stints = @racedelta.stints_for_driver(analysis, "ALP")
  assert_eq(stints.length(), 2)
  assert_eq(stints[0].end_lap, 2)
  assert_eq(stints[0].ended_by_pit, true)
  assert_eq(stints[1].start_lap, 3)
  assert_eq(stints[1].compound, @racedelta.Medium)
}

///|
test "M2 multiple pits create multiple stints" {
  let csv = csv_with_rows(
    "1,ALP,100,SOFT,1,false,GREEN,DRY\n" +
    "2,ALP,101,SOFT,2,true,GREEN,DRY\n" +
    "3,ALP,110,MEDIUM,1,true,GREEN,DRY\n" +
    "4,ALP,120,HARD,1,true,GREEN,DRY\n" +
    "5,ALP,130,SOFT,1,false,GREEN,DRY",
  )
  let stints = @racedelta.stints_for_driver(analysis_for(csv), "ALP")
  assert_eq(stints.length(), 4)
  assert_eq(stints[2].compound, @racedelta.Hard)
  assert_eq(stints[3].stint_number, 4)
}

///|
test "M2 pit with same compound still starts a new stint" {
  let csv = csv_with_rows(
    "1,ALP,100,SOFT,2,true,GREEN,DRY\n" + "2,ALP,110,SOFT,1,false,GREEN,DRY",
  )
  let stints = @racedelta.stints_for_driver(analysis_for(csv), "ALP")
  assert_eq(stints.length(), 2)
  assert_eq(stints[0].compound, @racedelta.Soft)
  assert_eq(stints[1].compound, @racedelta.Soft)
  assert_eq(stints[1].start_tyre_age_laps, 1)
}

///|
test "M2 stint boundaries and lap count are reconstructed" {
  let stints = @racedelta.stints_for_driver(base_analysis(), "ALP")
  assert_eq(stints[0].start_lap, 1)
  assert_eq(stints[0].end_lap, 2)
  assert_eq(stints[0].lap_count, 2)
  assert_eq(stints[1].start_lap, 3)
  assert_eq(stints[1].end_lap, 3)
  assert_eq(stints[1].lap_count, 1)
}

///|
test "M2 stint time includes its closing pit lap" {
  let stints = @racedelta.stints_for_driver(base_analysis(), "ALP")
  assert_eq(stints[0].total_time_ms, 180100)
}

///|
test "M2 final stint closes at final lap" {
  let stints = @racedelta.stints_for_driver(base_analysis(), "BRV")
  assert_eq(stints.length(), 1)
  assert_eq(stints[0].end_lap, 3)
  assert_eq(stints[0].ended_by_pit, false)
}

///|
test "M2 emits pit stop event with next compound" {
  let events = base_analysis().events
  match events[0] {
    @racedelta.PitStop(event) => {
      assert_eq(event.lap, 2)
      assert_eq(event.driver, "ALP")
      assert_eq(event.outgoing_compound, @racedelta.Soft)
      assert_eq(event.next_compound, Some(@racedelta.Medium))
    }
    _ => panic()
  }
}

///|
test "M2 final lap pit event has no next compound" {
  let csv = csv_with_rows(
    "1,ALP,100,SOFT,1,false,GREEN,DRY\n" + "2,ALP,110,SOFT,2,true,GREEN,DRY",
  )
  let events = analysis_for(csv).events
  match events[0] {
    @racedelta.PitStop(event) => assert_eq(event.next_compound, None)
    _ => panic()
  }
}

///|
fn changing_conditions_csv() -> String {
  csv_with_rows(
    "1,ALP,100,SOFT,1,false,GREEN,DRY\n" +
    "1,BRV,101,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,110,SOFT,2,false,SAFETY_CAR,DAMP\n" +
    "2,BRV,111,MEDIUM,2,false,SAFETY_CAR,DAMP\n" +
    "3,ALP,120,SOFT,3,false,GREEN,WET\n" +
    "3,BRV,121,MEDIUM,3,false,GREEN,WET",
  )
}

///|
test "M2 emits safety car start event" {
  let events = analysis_for(changing_conditions_csv()).events
  match events[0] {
    @racedelta.TrackStatusChange(event) => {
      assert_eq(event.lap, 2)
      assert_eq(event.previous, @racedelta.Green)
      assert_eq(event.current, @racedelta.SafetyCar)
    }
    _ => panic()
  }
}

///|
test "M2 emits safety car end event" {
  let events = analysis_for(changing_conditions_csv()).events
  match events[2] {
    @racedelta.TrackStatusChange(event) => {
      assert_eq(event.lap, 3)
      assert_eq(event.previous, @racedelta.SafetyCar)
      assert_eq(event.current, @racedelta.Green)
    }
    _ => panic()
  }
}

///|
test "M2 emits dry damp wet weather changes" {
  let events = analysis_for(changing_conditions_csv()).events
  match events[1] {
    @racedelta.WeatherChange(event) => {
      assert_eq(event.lap, 2)
      assert_eq(event.previous, @racedelta.Dry)
      assert_eq(event.current, @racedelta.Damp)
    }
    _ => panic()
  }
  match events[3] {
    @racedelta.WeatherChange(event) => {
      assert_eq(event.lap, 3)
      assert_eq(event.previous, @racedelta.Damp)
      assert_eq(event.current, @racedelta.Wet)
    }
    _ => panic()
  }
}

///|
test "M2 emits no first lap status change event" {
  let events = analysis_for(changing_conditions_csv()).events
  for event in events {
    match event {
      @racedelta.TrackStatusChange(change) => assert_true(change.lap > 1)
      @racedelta.WeatherChange(change) => assert_true(change.lap > 1)
      _ => ()
    }
  }
}

///|
test "M2 emits position changes" {
  let events = analysis_for(overtake_csv()).events
  assert_eq(events.length(), 2)
  match events[0] {
    @racedelta.PositionChange(change) => {
      assert_eq(change.lap, 2)
      assert_eq(change.driver, "ALP")
      assert_eq(change.previous_position, 1)
      assert_eq(change.current_position, 2)
    }
    _ => panic()
  }
  match events[1] {
    @racedelta.PositionChange(change) => {
      assert_eq(change.driver, "BRV")
      assert_eq(change.previous_position, 2)
      assert_eq(change.current_position, 1)
    }
    _ => panic()
  }
}

///|
test "M2 omits position changes when positions stay stable" {
  let events = base_analysis().events
  assert_eq(events.length(), 1)
  match events[0] {
    @racedelta.PitStop(_) => ()
    _ => panic()
  }
}

///|
test "M2 orders same lap event types and drivers deterministically" {
  let csv = csv_with_rows(
    "1,ALP,100,SOFT,1,false,GREEN,DRY\n" +
    "1,BRV,101,MEDIUM,1,false,GREEN,DRY\n" +
    "2,ALP,110,SOFT,2,true,SAFETY_CAR,DAMP\n" +
    "2,BRV,100,MEDIUM,2,false,SAFETY_CAR,DAMP",
  )
  let events = analysis_for(csv).events
  assert_eq(events.length(), 5)
  match events[0] {
    @racedelta.TrackStatusChange(change) => assert_eq(change.lap, 2)
    _ => panic()
  }
  match events[1] {
    @racedelta.WeatherChange(change) => assert_eq(change.lap, 2)
    _ => panic()
  }
  match events[2] {
    @racedelta.PitStop(event) => assert_eq(event.driver, "ALP")
    _ => panic()
  }
  match events[3] {
    @racedelta.PositionChange(change) => assert_eq(change.driver, "ALP")
    _ => panic()
  }
  match events[4] {
    @racedelta.PositionChange(change) => assert_eq(change.driver, "BRV")
    _ => panic()
  }
}

///|
test "M2 is stable when input row order differs" {
  let reordered = csv_with_rows(
    "3,BRV,90700,MEDIUM,6,false,GREEN,DRY\n" +
    "2,ALP,90100,SOFT,4,true,GREEN,DRY\n" +
    "1,BRV,90500,MEDIUM,4,false,GREEN,DRY\n" +
    "3,ALP,90200,MEDIUM,1,false,GREEN,DRY\n" +
    "1,ALP,90000,SOFT,3,false,GREEN,DRY\n" +
    "2,BRV,90600,MEDIUM,5,false,GREEN,DRY",
  )
  assert_eq(base_analysis(), analysis_for(reordered))
}

///|
fn basic_example_csv() -> String {
  csv_with_rows(
    "1,ALP,90120,SOFT,3,false,GREEN,DRY\n" +
    "1,BRV,90540,MEDIUM,5,false,GREEN,DRY\n" +
    "2,ALP,90310,SOFT,4,false,GREEN,DRY\n" +
    "2,BRV,90610,MEDIUM,6,true,GREEN,DRY\n" +
    "3,ALP,90480,SOFT,5,true,GREEN,DRY\n" +
    "3,BRV,91020,HARD,1,false,GREEN,DRY\n" +
    "4,ALP,91250,MEDIUM,1,false,GREEN,DRY\n" +
    "4,BRV,90890,HARD,2,false,GREEN,DRY",
  )
}

///|
test "M2 analyzes the basic example equivalent data" {
  let analysis = analysis_for(basic_example_csv())
  assert_eq(analysis.drivers, ["ALP", "BRV"])
  assert_eq(analysis.lap_count, 4)
  assert_eq(analysis.states.length(), 8)
  assert_eq(analysis.stints.length(), 4)
  assert_eq(analysis.events.length(), 2)
}

///|
fn mixed_example_csv() -> String {
  csv_with_rows(
    "1,ALP,90080,SOFT,2,false,GREEN,DRY\n" +
    "1,BRV,90420,MEDIUM,4,false,GREEN,DRY\n" +
    "2,ALP,91800,SOFT,3,true,SAFETY_CAR,DAMP\n" +
    "2,BRV,92010,MEDIUM,5,true,SAFETY_CAR,DAMP\n" +
    "3,ALP,99800,INTERMEDIATE,1,false,GREEN,DAMP\n" +
    "3,BRV,100120,INTERMEDIATE,1,false,GREEN,DAMP\n" +
    "4,ALP,109400,INTERMEDIATE,2,true,GREEN,WET\n" +
    "4,BRV,110050,INTERMEDIATE,2,true,GREEN,WET\n" +
    "5,ALP,115600,WET,1,false,GREEN,WET\n" +
    "5,BRV,116040,WET,1,false,GREEN,WET",
  )
}

///|
test "M2 analyzes the mixed conditions example equivalent data" {
  let analysis = analysis_for(mixed_example_csv())
  assert_eq(analysis.lap_count, 5)
  assert_eq(analysis.states.length(), 10)
  assert_eq(analysis.stints.length(), 6)
  assert_eq(analysis.events.length(), 8)
}

///|
test "M2 safety car lap uses input time without gap compression" {
  let analysis = analysis_for(mixed_example_csv())
  let alp_lap_2 = @racedelta.find_lap_state(analysis, "ALP", 2)
  let brv_lap_2 = @racedelta.find_lap_state(analysis, "BRV", 2)
  match (alp_lap_2, brv_lap_2) {
    (Some(alp), Some(brv)) => {
      assert_eq(alp.cumulative_time_ms, 181880)
      assert_eq(brv.cumulative_time_ms, 182430)
      assert_eq(brv.gap_to_leader_ms, 550)
    }
    _ => panic()
  }
}
