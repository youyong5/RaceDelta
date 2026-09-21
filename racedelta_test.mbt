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
