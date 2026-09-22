///|
/// Stable categories for command-line argument and PLAN parsing errors.
///
/// Codes distinguish missing, duplicate, and unknown arguments from malformed
/// or duplicate `LAP:COMPOUND` plan entries.
pub(all) enum CliErrorCode {
  MissingInputPath
  MissingRequiredOption
  MissingOptionValue
  DuplicateOption
  UnknownArgument
  UnexpectedPositional
  InvalidPlanFormat
  InvalidPlanLap
  InvalidPlanCompound
  DuplicatePlanLap
} derive(Eq)

///|
pub extend CliErrorCode with Eq::{not_equal, equal}

///|

///|
/// A deterministic, user-facing CLI parsing error.
///
/// `field` identifies the option or logical input field; `code` is stable for
/// programmatic handling and `message` is suitable for stderr output.
pub struct CliError {
  code : CliErrorCode
  field : String
  message : String
} derive(Eq)

///|
pub extend CliError with Eq::{not_equal, equal}

///|

///|
/// Parsed CLI input. File paths remain at the command boundary; simulation stays pure.
///
/// `target_driver` receives the replacement plan in `stops`; `opponent_driver`
/// is used for signed-gap comparison. `output_path` selects file output when present.
pub struct CliOptions {
  input_path : String
  target_driver : String
  opponent_driver : String
  stops : Array[PlannedPitStop]
  output_path : String?
} derive(Eq)

///|
pub extend CliOptions with Eq::{not_equal, equal}

///|

///|
/// Stable categories for the pure CSV-to-report pipeline.
///
/// Codes identify whether CSV validation, strategy simulation, or explanation
/// failed while producing a Markdown report.
pub(all) enum CliPipelineErrorCode {
  CsvValidationFailed
  StrategySimulationFailed
  ExplanationFailed
} derive(Eq)

///|
pub extend CliPipelineErrorCode with Eq::{not_equal, equal}

///|

///|
/// A user-facing error from the pure CSV-to-Markdown pipeline.
///
/// This keeps file I/O out of the core pipeline while exposing a stable failure
/// phase through `code` and a concise diagnostic through `message`.
pub struct CliPipelineError {
  code : CliPipelineErrorCode
  message : String
} derive(Eq)

///|
pub extend CliPipelineError with Eq::{not_equal, equal}

///|

///|
fn cli_error(code : CliErrorCode, field : String, message : String) -> CliError {
  { code, field, message, }
}

///|
fn parse_positive_plan_lap(text : String) -> Result[Int, CliError] {
  if text == "" {
    return Err(
      cli_error(
        InvalidPlanLap,
        "stops",
        "pit lap must be a positive decimal integer",
      ),
    )
  }
  let mut value = 0
  for char in text {
    if !char.is_ascii_digit() {
      return Err(
        cli_error(
          InvalidPlanLap,
          "stops",
          "pit lap must be a positive decimal integer",
        ),
      )
    }
    let digit = char.to_int() - '0'.to_int()
    if value > 214748364 || (value == 214748364 && digit > 7) {
      return Err(
        cli_error(
          InvalidPlanLap,
          "stops",
          "pit lap is outside the supported range",
        ),
      )
    }
    value = value * 10 + digit
  }
  if value < 1 {
    Err(
      cli_error(
        InvalidPlanLap,
        "stops",
        "pit lap must be a positive decimal integer",
      ),
    )
  } else {
    Ok(value)
  }
}

///|
fn parse_plan_compound(text : String) -> Result[Compound, CliError] {
  match text {
    "SOFT" => Ok(Soft)
    "MEDIUM" => Ok(Medium)
    "HARD" => Ok(Hard)
    "INTERMEDIATE" => Ok(Intermediate)
    "WET" => Ok(Wet)
    _ =>
      Err(
        cli_error(
          InvalidPlanCompound,
          "stops",
          "PLAN compound must be SOFT, MEDIUM, HARD, INTERMEDIATE, or WET",
        ),
      )
  }
}

///|
/// Parse `none` or a comma-separated sequence of `LAP:COMPOUND` pit stops.
///
/// Each lap must be a positive decimal integer and each compound is one of the
/// CSV v1 uppercase values. Duplicate laps and malformed items return a
/// structured `CliError`; lap range and ordering remain M4 validation concerns.
pub fn parse_stop_plan(
  plan : String,
) -> Result[Array[PlannedPitStop], CliError] {
  if plan == "none" {
    return Ok([])
  }
  if plan == "" {
    return Err(
      cli_error(
        InvalidPlanFormat,
        "stops",
        "PLAN must be `none` or comma-separated LAP:COMPOUND items",
      ),
    )
  }
  let stops : Array[PlannedPitStop] = []
  let items = plan.split(",").to_array()
  for raw_item in items {
    let item = raw_item.to_owned()
    if item == "" || item.trim().to_owned() != item {
      return Err(
        cli_error(
          InvalidPlanFormat,
          "stops",
          "PLAN must not contain empty or whitespace-padded items",
        ),
      )
    }
    let parts = item.split(":").to_array()
    if parts.length() != 2 || parts[0] == "" || parts[1] == "" {
      return Err(
        cli_error(
          InvalidPlanFormat,
          "stops",
          "each PLAN item must use the exact LAP:COMPOUND format",
        ),
      )
    }
    let pit_lap = match parse_positive_plan_lap(parts[0].to_owned()) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let next_compound = match parse_plan_compound(parts[1].to_owned()) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    for previous in stops {
      if previous.pit_lap == pit_lap {
        return Err(
          cli_error(
            DuplicatePlanLap,
            "stops",
            "PLAN must not contain duplicate pit laps",
          ),
        )
      }
    }
    stops.push({ pit_lap, next_compound, })
  }
  Ok(stops)
}

///|
fn option_requires_value(argument : String) -> Bool {
  match argument {
    "--driver" | "--opponent" | "--stops" | "-o" | "--output" => true
    _ => false
  }
}

///|
fn is_option(argument : String) -> Bool {
  argument.has_prefix("-")
}

///|
/// Parse program arguments after the executable prefix in any option order.
///
/// Requires one CSV path plus `--driver`, `--opponent`, and `--stops`; `-o` or
/// `--output` is optional. Returns `CliOptions` without file I/O or a
/// structured `CliError` for missing, duplicate, unknown, or malformed input.
pub fn parse_cli_arguments(
  arguments : Array[String],
) -> Result[CliOptions, CliError] {
  let mut input_path : String? = None
  let mut target_driver : String? = None
  let mut opponent_driver : String? = None
  let mut plan : String? = None
  let mut output_path : String? = None
  let mut index = 0
  while index < arguments.length() {
    let argument = arguments[index]
    if option_requires_value(argument) {
      if index + 1 >= arguments.length() || is_option(arguments[index + 1]) {
        return Err(
          cli_error(
            MissingOptionValue,
            argument,
            "option " + argument + " requires a value",
          ),
        )
      }
      let value = arguments[index + 1]
      match argument {
        "--driver" =>
          match target_driver {
            Some(_) =>
              return Err(
                cli_error(
                  DuplicateOption,
                  "driver",
                  "--driver may be provided only once",
                ),
              )
            None => target_driver = Some(value)
          }
        "--opponent" =>
          match opponent_driver {
            Some(_) =>
              return Err(
                cli_error(
                  DuplicateOption,
                  "opponent",
                  "--opponent may be provided only once",
                ),
              )
            None => opponent_driver = Some(value)
          }
        "--stops" =>
          match plan {
            Some(_) =>
              return Err(
                cli_error(
                  DuplicateOption,
                  "stops",
                  "--stops may be provided only once",
                ),
              )
            None => plan = Some(value)
          }
        "-o" | "--output" =>
          match output_path {
            Some(_) =>
              return Err(
                cli_error(
                  DuplicateOption,
                  "output",
                  "-o/--output may be provided only once",
                ),
              )
            None => output_path = Some(value)
          }
        _ => ()
      }
      index = index + 2
    } else if is_option(argument) {
      return Err(
        cli_error(UnknownArgument, "argument", "unknown option: " + argument),
      )
    } else {
      match input_path {
        None => input_path = Some(argument)
        Some(_) =>
          return Err(
            cli_error(
              UnexpectedPositional,
              "input",
              "only one input CSV path is accepted",
            ),
          )
      }
      index = index + 1
    }
  }
  let input_path = match input_path {
    Some(value) => value
    None =>
      return Err(
        cli_error(MissingInputPath, "input", "missing required input CSV path"),
      )
  }
  let target_driver = match target_driver {
    Some(value) => value
    None =>
      return Err(
        cli_error(
          MissingRequiredOption,
          "driver",
          "missing required --driver option",
        ),
      )
  }
  let opponent_driver = match opponent_driver {
    Some(value) => value
    None =>
      return Err(
        cli_error(
          MissingRequiredOption,
          "opponent",
          "missing required --opponent option",
        ),
      )
  }
  let plan = match plan {
    Some(value) => value
    None =>
      return Err(
        cli_error(
          MissingRequiredOption,
          "stops",
          "missing required --stops option",
        ),
      )
  }
  let stops = match parse_stop_plan(plan) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({ input_path, target_driver, opponent_driver, stops, output_path, })
}

///|
/// Convert validated CSV text into the stable M5 Markdown strategy report.
///
/// The pure pipeline parses CSV, applies the default illustrative pace model,
/// simulates `stops` for `target_driver`, explains the result against
/// `opponent_driver`, and renders Markdown. Returns `CliPipelineError` with a
/// stable phase code for CSV, simulation, or explanation failure.
pub fn generate_strategy_report(
  csv : String,
  target_driver : String,
  opponent_driver : String,
  stops : Array[PlannedPitStop],
) -> Result[String, CliPipelineError] {
  let data = match parse_race_csv(csv) {
    Ok(value) => value
    Err(error) =>
      return Err({
        code: CsvValidationFailed,
        message: "CSV validation failed at line " +
        error.line.to_string() +
        " (" +
        error.field +
        "): " +
        error.message,
      })
  }
  let request = { target_driver, opponent_driver, stops, }
  let simulation = match
    simulate_strategy(data, default_pace_model_config(), request) {
    Ok(value) => value
    Err(error) =>
      return Err({
        code: StrategySimulationFailed,
        message: "strategy simulation failed: " + error.message,
      })
  }
  match explain_strategy(default_pace_model_config(), simulation) {
    Ok(explanation) => Ok(render_strategy_markdown(explanation))
    Err(error) =>
      Err({
        code: ExplanationFailed,
        message: "strategy explanation failed: " + error.message,
      })
  }
}

///|
/// Return the stable, human-readable CLI usage text.
///
/// This has no side effects and describes the executable syntax, PLAN grammar,
/// supported compounds, output option, and help option.
pub fn cli_help() -> String {
  (
    #|RaceDelta — race strategy analyzer and counterfactual simulator
    #|
    #|Usage:
    #|  racedelta <input.csv> --driver <DRIVER> --opponent <DRIVER> --stops <PLAN> [-o <report.md>]
    #|
    #|Required:
    #|  <input.csv>             CSV v1 race data
    #|  --driver <DRIVER>       Target driver for the alternative strategy
    #|  --opponent <DRIVER>     Driver used for comparison
    #|  --stops <PLAN>          none or LAP:COMPOUND[,LAP:COMPOUND...]
    #|
    #|Optional:
    #|  -o, --output <PATH>     Write Markdown to PATH instead of stdout
    #|  -h, --help              Show this help text
    #|
    #|Compounds: SOFT, MEDIUM, HARD, INTERMEDIATE, WET
    #|
  )
}
