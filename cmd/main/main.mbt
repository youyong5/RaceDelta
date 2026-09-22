///|
fn command_arguments(argv : Array[String]) -> Array[String] {
  // @env.args includes the native executable prefix. Preserve all following
  // user-provided values, including absolute Windows paths and spaces.
  if argv.length() > 0 {
    argv[1:].to_owned()
  } else {
    argv
  }
}

///|
fn is_help_request(arguments : Array[String]) -> Bool {
  arguments.length() == 1 && (arguments[0] == "--help" || arguments[0] == "-h")
}

///|
async fn fail_cli(message : String) -> Unit {
  @stdio.stderr.write("error: " + message + "\n")
  // async 0.20.2 exposes no supported exit-code API. This public error
  // boundary terminates nonzero without using private exit functions or FFI.
  fail("")
}

///|
async fn main {
  let arguments = command_arguments(@env.args())
  if is_help_request(arguments) {
    @stdio.stdout.write(@lib.cli_help())
    return
  }
  let options = match @lib.parse_cli_arguments(arguments) {
    Ok(value) => value
    Err(error) => return fail_cli(error.message)
  }
  let csv = @fs.read_file(options.input_path).text() catch {
    error =>
      return fail_cli(
        "could not read input CSV `" +
        options.input_path +
        "`: " +
        error.to_string(),
      )
  }
  let report = match
    @lib.generate_strategy_report(
      csv,
      options.target_driver,
      options.opponent_driver,
      options.stops,
    ) {
    Ok(value) => value
    Err(error) => return fail_cli(error.message)
  }
  match options.output_path {
    None => @stdio.stdout.write(report)
    Some(path) => {
      @fs.write_file(path, report, create_mode=CreateOrTruncate) catch {
        error =>
          return fail_cli(
            "could not write report `" + path + "`: " + error.to_string(),
          )
      }
      @stdio.stderr.write("Report written to " + path + "\n")
    }
  }
}
