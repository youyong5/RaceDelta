///|
let expected_header = "lap,driver,lap_time_ms,compound,tyre_age_laps,pit,track_status,weather"

///|
priv struct ParsedRecord {
  record : LapRecord
  line : Int
}

///|
fn csv_error(
  code : RaceErrorCode,
  line : Int,
  field : String,
  message : String,
) -> RaceError {
  { code, line, field, message, }
}

///|
fn parse_integer(
  text : String,
  line : Int,
  field : String,
) -> Result[Int, RaceError] {
  if text == "" {
    return Err(
      csv_error(InvalidInteger, line, field, "expected a decimal integer"),
    )
  }
  let mut value = 0
  for char in text {
    if !char.is_ascii_digit() {
      return Err(
        csv_error(InvalidInteger, line, field, "expected a decimal integer"),
      )
    }
    let digit = char.to_int() - '0'.to_int()
    if value > 214748364 || (value == 214748364 && digit > 7) {
      return Err(
        csv_error(
          InvalidInteger,
          line,
          field,
          "integer is outside the supported range",
        ),
      )
    }
    value = value * 10 + digit
  }
  Ok(value)
}

///|
fn parse_compound(text : String, line : Int) -> Result[Compound, RaceError] {
  match text {
    "SOFT" => Ok(Soft)
    "MEDIUM" => Ok(Medium)
    "HARD" => Ok(Hard)
    "INTERMEDIATE" => Ok(Intermediate)
    "WET" => Ok(Wet)
    _ =>
      Err(
        csv_error(
          InvalidValue,
          line,
          "compound",
          "compound must be SOFT, MEDIUM, HARD, INTERMEDIATE, or WET",
        ),
      )
  }
}

///|
fn parse_pit(text : String, line : Int) -> Result[Bool, RaceError] {
  match text {
    "true" => Ok(true)
    "false" => Ok(false)
    _ =>
      Err(
        csv_error(
          InvalidValue,
          line,
          "pit",
          "pit must be lowercase true or false",
        ),
      )
  }
}

///|
fn parse_track_status(
  text : String,
  line : Int,
) -> Result[TrackStatus, RaceError] {
  match text {
    "GREEN" => Ok(Green)
    "SAFETY_CAR" => Ok(SafetyCar)
    _ =>
      Err(
        csv_error(
          InvalidValue,
          line,
          "track_status",
          "track_status must be GREEN or SAFETY_CAR",
        ),
      )
  }
}

///|
fn parse_weather(text : String, line : Int) -> Result[Weather, RaceError] {
  match text {
    "DRY" => Ok(Dry)
    "DAMP" => Ok(Damp)
    "WET" => Ok(Wet)
    _ =>
      Err(
        csv_error(
          InvalidValue,
          line,
          "weather",
          "weather must be DRY, DAMP, or WET",
        ),
      )
  }
}

///|
fn parse_record(
  line_text : String,
  line : Int,
) -> Result[ParsedRecord, RaceError] {
  if line_text.contains("\"") {
    return Err(
      csv_error(
        UnsupportedCsvSyntax,
        line,
        "csv",
        "quoted CSV fields are not supported",
      ),
    )
  }
  let fields = line_text
    .split(",")
    .map(field => field.trim().to_owned())
    .to_array()
  if fields.length() != 8 {
    return Err(
      csv_error(FieldCount, line, "row", "expected exactly 8 CSV fields"),
    )
  }
  let lap = match parse_integer(fields[0], line, "lap") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if lap < 1 {
    return Err(csv_error(InvalidValue, line, "lap", "lap must be at least 1"))
  }
  if fields[1] == "" {
    return Err(
      csv_error(InvalidValue, line, "driver", "driver must not be empty"),
    )
  }
  let lap_time_ms = match parse_integer(fields[2], line, "lap_time_ms") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if lap_time_ms < 1 {
    return Err(
      csv_error(
        InvalidValue,
        line,
        "lap_time_ms",
        "lap_time_ms must be greater than zero",
      ),
    )
  }
  let compound = match parse_compound(fields[3], line) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let tyre_age_laps = match parse_integer(fields[4], line, "tyre_age_laps") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if tyre_age_laps < 1 {
    return Err(
      csv_error(
        InvalidValue,
        line,
        "tyre_age_laps",
        "tyre_age_laps must be at least 1",
      ),
    )
  }
  let pit = match parse_pit(fields[5], line) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let track_status = match parse_track_status(fields[6], line) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let weather = match parse_weather(fields[7], line) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    record: {
      lap,
      driver: fields[1],
      lap_time_ms,
      compound,
      tyre_age_laps,
      pit,
      track_status,
      weather,
    },
    line,
  })
}

///|
/// Parse, validate, and canonically sort a CSV v1 race input string.
///
/// Accepts CRLF or LF, ignores blank lines, trims ordinary cell whitespace, and
/// returns records sorted by lap then driver. It rejects unsupported quoted CSV
/// syntax, malformed fields, enum values, and cross-row race constraints with a
/// structured `RaceError` containing a CSV line and field.
pub fn parse_race_csv(input : String) -> Result[RaceData, RaceError] {
  let nonblank = []
  let lines = input.split("\n").to_array()
  for index = 0; index < lines.length(); index = index + 1 {
    let raw_line = lines[index].to_owned()
    if raw_line.trim() != "" {
      // Preserve header whitespace for exact-header validation while removing CRLF's CR.
      nonblank.push((index + 1, raw_line.trim_end(chars="\r").to_owned()))
    }
  }
  if nonblank.length() == 0 {
    return Err(
      csv_error(
        EmptyInput,
        0,
        "csv",
        "CSV input contains no header or data rows",
      ),
    )
  }
  if nonblank[0].1 != expected_header {
    return Err(
      csv_error(
        InvalidHeader,
        nonblank[0].0,
        "header",
        "header must exactly match CSV v1",
      ),
    )
  }
  let parsed = []
  for index = 1; index < nonblank.length(); index = index + 1 {
    let (line, text) = nonblank[index]
    match parse_record(text, line) {
      Ok(record) => parsed.push(record)
      Err(error) => return Err(error)
    }
  }
  if parsed.length() == 0 {
    return Err(
      csv_error(EmptyInput, 0, "csv", "CSV input contains no data rows"),
    )
  }
  parsed.sort_by((left, right) => {
    if left.record.lap != right.record.lap {
      left.record.lap - right.record.lap
    } else {
      left.record.driver.compare(right.record.driver)
    }
  })
  match validate_records(parsed) {
    Ok(records) => Ok({ records, })
    Err(error) => Err(error)
  }
}
