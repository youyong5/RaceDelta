///|
fn compound_name(compound : Compound) -> String {
  match compound {
    Soft => "SOFT"
    Medium => "MEDIUM"
    Hard => "HARD"
    Intermediate => "INTERMEDIATE"
    Wet => "WET"
  }
}

///|
fn tyre_description(
  compound : Compound,
  tyre_age_laps : Int,
  pit : Bool,
) -> String {
  let pit_marker = if pit { " (pit)" } else { "" }
  compound_name(compound) + " age " + tyre_age_laps.to_string() + pit_marker
}

///|
fn verdict_name(verdict : StrategyVerdict) -> String {
  match verdict {
    Improved => "Improved"
    Worsened => "Worsened"
    Unchanged => "Unchanged"
  }
}

///|
fn signed_count(value : Int) -> String {
  if value > 0 {
    "+" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn stop_description(stops : Array[StrategyPitStop]) -> String {
  if stops.length() == 0 {
    "No stops"
  } else {
    let mut description = ""
    for index = 0; index < stops.length(); index = index + 1 {
      if index > 0 {
        description = description + ", "
      }
      let stop = stops[index]
      description = description + "Lap " + stop.lap.to_string() + " -> "
      match stop.next_compound {
        Some(compound) => description = description + compound_name(compound)
        None => description = description + "no following lap"
      }
    }
    description
  }
}

///|
fn crossover_section(
  title : String,
  crossovers : Array[CrossoverPoint],
) -> String {
  let mut section = "### " + title + "\n\n"
  if crossovers.length() == 0 {
    section = section + "None\n\n"
  } else {
    for point in crossovers {
      section = section +
        "- Lap " +
        point.lap.to_string() +
        ": " +
        crossover_direction_message(point.direction) +
        " (" +
        format_signed_ms(point.previous_value_ms) +
        " -> " +
        format_signed_ms(point.current_value_ms) +
        ")\n"
    }
    section = section + "\n"
  }
  section
}

///|
fn turning_points_section(turning_points : Array[TurningPoint]) -> String {
  let mut section = "## Key Turning Points\n\n"
  if turning_points.length() == 0 {
    section = section + "None\n\n"
  } else {
    for point in turning_points {
      let impact = match point.impact_ms {
        Some(value) => " Impact: " + format_signed_ms(value) + "."
        None => ""
      }
      section = section +
        "- Lap " +
        point.lap.to_string() +
        ": " +
        point.message +
        impact +
        "\n"
    }
    section = section + "\n"
  }
  section
}

///|
fn lap_trace_section(laps : Array[StrategyLapComparison]) -> String {
  let mut section = "## Lap Trace\n\n"
  section = section +
    "| Lap | Actual tyre | Simulated tyre | Actual position | Simulated position | Actual gap to opponent | Simulated gap to opponent | Cumulative gain |\n"
  section = section +
    "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |\n"
  for comparison in laps {
    section = section +
      "| " +
      comparison.lap.to_string() +
      " | " +
      tyre_description(
        comparison.actual_compound,
        comparison.actual_tyre_age_laps,
        comparison.actual_pit,
      ) +
      " | " +
      tyre_description(
        comparison.simulated_compound,
        comparison.simulated_tyre_age_laps,
        comparison.simulated_pit,
      ) +
      " | P" +
      comparison.actual_position.to_string() +
      " | P" +
      comparison.simulated_position.to_string() +
      " | " +
      format_signed_ms(comparison.actual_signed_gap_to_opponent_ms) +
      " | " +
      format_signed_ms(comparison.simulated_signed_gap_to_opponent_ms) +
      " | " +
      format_signed_ms(comparison.cumulative_time_gain_ms) +
      " |\n"
  }
  section + "\n"
}

///|
/// Render a stable English Markdown report from an already-derived explanation.
pub fn render_strategy_markdown(explanation : StrategyExplanation) -> String {
  let summary = explanation.summary
  let mut report = "# RaceDelta Strategy Report\n\n"
  report = report + "## Verdict\n\n"
  report = report + "- Target: " + explanation.target_driver + "\n"
  report = report + "- Opponent: " + explanation.opponent_driver + "\n"
  report = report + "- Verdict: " + verdict_name(explanation.verdict) + "\n"
  report = report +
    "- Time gain: " +
    format_signed_ms(summary.time_gain_ms) +
    "\n"
  report = report +
    "- Finish position: actual P" +
    summary.actual_finish_position.to_string() +
    "; simulated P" +
    summary.simulated_finish_position.to_string() +
    "\n"
  report = report +
    "- Positions gained/lost: " +
    signed_count(summary.positions_gained) +
    "\n"
  report = report +
    "- Final opponent gap: actual " +
    format_signed_ms(summary.actual_final_signed_gap_to_opponent_ms) +
    "; simulated " +
    format_signed_ms(summary.simulated_final_signed_gap_to_opponent_ms) +
    "\n\n"
  report = report + "## Strategy Comparison\n\n"
  report = report +
    "- Actual stops: " +
    stop_description(explanation.actual_stops) +
    "\n"
  report = report +
    "- Simulated stops: " +
    stop_description(explanation.simulated_stops) +
    "\n\n"
  report = report + "## Crossovers\n\n"
  report = report +
    crossover_section(
      "Performance crossovers",
      explanation.performance_crossovers,
    )
  report = report +
    crossover_section("Strategic crossovers", explanation.strategic_crossovers)
  report = report +
    crossover_section("Opponent crossovers", explanation.opponent_crossovers)
  report = report + turning_points_section(explanation.turning_points)
  report = report + lap_trace_section(explanation.laps)
  report = report + "## Assumptions and Limitations\n\n"
  report = report + "- Only the target driver's strategy changes.\n"
  report = report + "- Other drivers retain their observed lap times.\n"
  report = report + "- Weather and track status remain fixed.\n"
  report = report +
    "- No traffic, overtaking-cost, DRS, or driver-response model is included.\n"
  report = report +
    "- Default pace parameters are illustrative, not official F1 data.\n"
  report = report +
    "- Results are explanatory counterfactuals, not precise predictions.\n"
  report
}
