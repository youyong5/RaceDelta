///|
fn expect_cli_error(
  result : Result[@racedelta.CliOptions, @racedelta.CliError],
  code : @racedelta.CliErrorCode,
  field : String,
) -> Unit raise {
  match result {
    Err(error) => {
      assert_true(error.code == code)
      assert_eq(error.field, field)
    }
    Ok(_) => assert_true(false)
  }
}

///|
fn m6_race_csv() -> String {
  "lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather\n" +
  "1,ALP,100000,SOFT,1,false,GREEN,DRY\n" +
  "1,BRV,100400,MEDIUM,1,false,GREEN,DRY\n" +
  "2,ALP,100120,SOFT,2,true,GREEN,DRY\n" +
  "2,BRV,100480,MEDIUM,2,false,GREEN,DRY\n" +
  "3,ALP,100000,MEDIUM,1,false,GREEN,DRY\n" +
  "3,BRV,100560,MEDIUM,3,false,GREEN,DRY\n" +
  "4,ALP,100080,MEDIUM,2,false,GREEN,DRY\n" +
  "4,BRV,100640,MEDIUM,4,false,GREEN,DRY"
}

///|
test "M6 parses a single-stop PLAN" {
  match @racedelta.parse_stop_plan("12:MEDIUM") {
    Ok(stops) => {
      assert_eq(stops.length(), 1)
      assert_eq(stops[0].pit_lap, 12)
      assert_eq(stops[0].next_compound, @racedelta.Medium)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "M6 parses a multi-stop PLAN without changing its order" {
  match @racedelta.parse_stop_plan("28:HARD,12:MEDIUM") {
    Ok(stops) => {
      assert_eq(stops.length(), 2)
      assert_eq(stops[0].pit_lap, 28)
      assert_eq(stops[1].pit_lap, 12)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "M6 parses the none PLAN" {
  match @racedelta.parse_stop_plan("none") {
    Ok(stops) => assert_eq(stops.length(), 0)
    Err(_) => assert_true(false)
  }
}

///|
test "M6 rejects an invalid PLAN lap" {
  match @racedelta.parse_stop_plan("0:MEDIUM") {
    Err(error) => assert_true(error.code == @racedelta.InvalidPlanLap)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 rejects an invalid PLAN compound" {
  match @racedelta.parse_stop_plan("12:SLICK") {
    Err(error) => assert_true(error.code == @racedelta.InvalidPlanCompound)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 rejects a PLAN item without a colon" {
  match @racedelta.parse_stop_plan("12MEDIUM") {
    Err(error) => assert_true(error.code == @racedelta.InvalidPlanFormat)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 rejects an empty PLAN item" {
  match @racedelta.parse_stop_plan("12:MEDIUM,") {
    Err(error) => assert_true(error.code == @racedelta.InvalidPlanFormat)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 rejects duplicate PLAN laps" {
  match @racedelta.parse_stop_plan("12:MEDIUM,12:HARD") {
    Err(error) => assert_true(error.code == @racedelta.DuplicatePlanLap)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 accepts required options in a different order" {
  match
    @racedelta.parse_cli_arguments([
      "--stops", "none", "examples/basic_race.csv", "--opponent", "BRV", "--driver",
      "ALP",
    ]) {
    Ok(options) => {
      assert_eq(options.input_path, "examples/basic_race.csv")
      assert_eq(options.target_driver, "ALP")
      assert_eq(options.opponent_driver, "BRV")
      assert_eq(options.stops.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "M6 reports a missing required option" {
  expect_cli_error(
    @racedelta.parse_cli_arguments([
      "examples/basic_race.csv", "--opponent", "BRV", "--stops", "none",
    ]),
    @racedelta.MissingRequiredOption,
    "driver",
  )
}

///|
test "M6 rejects an unknown command-line option" {
  expect_cli_error(
    @racedelta.parse_cli_arguments([
      "examples/basic_race.csv", "--driver", "ALP", "--opponent", "BRV", "--stops",
      "none", "--unknown",
    ]),
    @racedelta.UnknownArgument,
    "argument",
  )
}

///|
test "M6 accepts short output option" {
  match
    @racedelta.parse_cli_arguments([
      "examples/basic_race.csv", "--driver", "ALP", "--opponent", "BRV", "--stops",
      "none", "-o", "report.md",
    ]) {
    Ok(options) => assert_eq(options.output_path, Some("report.md"))
    Err(_) => assert_true(false)
  }
}

///|
test "M6 accepts long output option" {
  match
    @racedelta.parse_cli_arguments([
      "examples/basic_race.csv", "--driver", "ALP", "--opponent", "BRV", "--stops",
      "none", "--output", "report.md",
    ]) {
    Ok(options) => assert_eq(options.output_path, Some("report.md"))
    Err(_) => assert_true(false)
  }
}

///|
test "M6 preserves quoted Windows path values as single arguments" {
  match
    @racedelta.parse_cli_arguments([
      "C:\\Race Data\\basic race.csv", "--driver", "ALP", "--opponent", "BRV", "--stops",
      "none", "--output", "C:\\Reports\\RaceDelta report.md",
    ]) {
    Ok(options) => {
      assert_eq(options.input_path, "C:\\Race Data\\basic race.csv")
      assert_eq(options.output_path, Some("C:\\Reports\\RaceDelta report.md"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "M6 generates an end-to-end Markdown strategy report" {
  match @racedelta.parse_stop_plan("2:MEDIUM") {
    Err(_) => assert_true(false)
    Ok(stops) =>
      match
        @racedelta.generate_strategy_report(m6_race_csv(), "ALP", "BRV", stops) {
        Ok(report) => {
          assert_true(report.has_prefix("# RaceDelta Strategy Report\n"))
          assert_true(report.contains("## Strategy Comparison"))
        }
        Err(_) => assert_true(false)
      }
  }
}

///|
test "M6 maps CSV validation errors through the pure pipeline" {
  match @racedelta.generate_strategy_report("not a CSV", "ALP", "BRV", []) {
    Err(error) => assert_true(error.code == @racedelta.CsvValidationFailed)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 maps an unknown target driver through the pure pipeline" {
  match
    @racedelta.generate_strategy_report(m6_race_csv(), "MISSING", "BRV", []) {
    Err(error) => assert_true(error.code == @racedelta.StrategySimulationFailed)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 maps an unknown opponent driver through the pure pipeline" {
  match
    @racedelta.generate_strategy_report(m6_race_csv(), "ALP", "MISSING", []) {
    Err(error) => assert_true(error.code == @racedelta.StrategySimulationFailed)
    Ok(_) => assert_true(false)
  }
}

///|
test "M6 delegates invalid pit-lap range to M4" {
  match @racedelta.parse_stop_plan("4:MEDIUM") {
    Err(_) => assert_true(false)
    Ok(stops) =>
      match
        @racedelta.generate_strategy_report(m6_race_csv(), "ALP", "BRV", stops) {
        Err(error) =>
          assert_true(error.code == @racedelta.StrategySimulationFailed)
        Ok(_) => assert_true(false)
      }
  }
}

///|
test "M6 Markdown payload contains no CLI success log" {
  match @racedelta.generate_strategy_report(m6_race_csv(), "ALP", "BRV", []) {
    Ok(report) => {
      assert_false(report.contains("Report written to"))
      assert_false(report.contains("Success"))
    }
    Err(_) => assert_true(false)
  }
}
