///|
/// Return the centralized, replaceable demonstration configuration for M3.
///
/// Values are integer milliseconds and are illustrative teaching assumptions,
/// not official F1 data for any circuit, tyre, team, or driver.
pub fn default_pace_model_config() -> PaceModelConfig {
  {
    tyre_profiles: [
      {
        compound: Soft,
        fresh_deltas: { dry_ms: -700, damp_ms: 6500, wet_ms: 24000, },
        degradation_ms_per_lap: 120,
        cliff_age_laps: 12,
        cliff_extra_ms_per_lap: 240,
      },
      {
        compound: Medium,
        fresh_deltas: { dry_ms: 0, damp_ms: 7000, wet_ms: 25000, },
        degradation_ms_per_lap: 80,
        cliff_age_laps: 20,
        cliff_extra_ms_per_lap: 180,
      },
      {
        compound: Hard,
        fresh_deltas: { dry_ms: 500, damp_ms: 7500, wet_ms: 26000, },
        degradation_ms_per_lap: 55,
        cliff_age_laps: 30,
        cliff_extra_ms_per_lap: 120,
      },
      {
        compound: Intermediate,
        fresh_deltas: { dry_ms: 4000, damp_ms: 0, wet_ms: 3500, },
        degradation_ms_per_lap: 95,
        cliff_age_laps: 22,
        cliff_extra_ms_per_lap: 180,
      },
      {
        compound: Wet,
        fresh_deltas: { dry_ms: 9000, damp_ms: 3000, wet_ms: 500, },
        degradation_ms_per_lap: 70,
        cliff_age_laps: 28,
        cliff_extra_ms_per_lap: 140,
      },
    ],
    pit_loss_profile: {
      green_pit_loss_ms: 22000,
      safety_car_pit_loss_ms: 12000,
    },
  }
}

///|
fn fresh_delta_ms(deltas : WeatherPaceDeltas, weather : Weather) -> Int {
  match weather {
    Dry => deltas.dry_ms
    Damp => deltas.damp_ms
    Wet => deltas.wet_ms
  }
}

///|
fn validated_profile(
  config : PaceModelConfig,
  compound : Compound,
) -> Result[TyreProfile, ModelError] {
  match validate_pace_model_config(config) {
    Err(error) => Err(error)
    Ok(_) =>
      match find_tyre_profile(config, compound) {
        Some(profile) => Ok(profile)
        None =>
          Err(
            model_error(
              MissingTyreProfile,
              "missing tyre profile for requested compound",
            ),
          )
      }
  }
}

///|
/// Calculate fresh pace plus linear and cliff degradation in integer milliseconds.
///
/// `tyre_age_laps` is the completed-lap age and must be at least one. A
/// positive result makes the lap slower than the neutral anchor; a negative
/// result makes it faster. Returns `ModelError` for an invalid configuration,
/// missing profile, or invalid tyre age.
pub fn tyre_pace_delta_ms(
  config : PaceModelConfig,
  compound : Compound,
  tyre_age_laps : Int,
  weather : Weather,
) -> Result[Int, ModelError] {
  let profile = match validated_profile(config, compound) {
    Ok(profile) => profile
    Err(error) => return Err(error)
  }
  if tyre_age_laps < 1 {
    return Err(model_error(InvalidTyreAge, "tyre age must be at least 1 lap"))
  }
  let linear_degradation_ms = (tyre_age_laps - 1) *
    profile.degradation_ms_per_lap
  let cliff_degradation_ms = if tyre_age_laps > profile.cliff_age_laps {
    (tyre_age_laps - profile.cliff_age_laps) * profile.cliff_extra_ms_per_lap
  } else {
    0
  }
  Ok(
    fresh_delta_ms(profile.fresh_deltas, weather) +
    linear_degradation_ms +
    cliff_degradation_ms,
  )
}

///|
/// Return the configured pit loss for a track status after validating the config.
///
/// The returned non-negative integer is milliseconds added on a pit lap.
/// Returns `ModelError` when `config` is invalid.
pub fn pit_loss_ms(
  config : PaceModelConfig,
  track_status : TrackStatus,
) -> Result[Int, ModelError] {
  match validate_pace_model_config(config) {
    Err(error) => Err(error)
    Ok(_) =>
      match track_status {
        Green => Ok(config.pit_loss_profile.green_pit_loss_ms)
        SafetyCar => Ok(config.pit_loss_profile.safety_car_pit_loss_ms)
      }
  }
}

///|
fn modeled_pit_loss_ms(
  config : PaceModelConfig,
  track_status : TrackStatus,
  pit : Bool,
) -> Result[Int, ModelError] {
  if pit {
    pit_loss_ms(config, track_status)
  } else {
    Ok(0)
  }
}

///|
/// Estimate observed lap time from a positive neutral anchor and model conditions.
///
/// Adds the tyre pace delta and, when `pit` is true, the configured track-status
/// pit loss. Returns a positive integer-millisecond lap time or `ModelError`
/// for invalid model input or a non-positive result.
pub fn estimate_lap_time_ms(
  config : PaceModelConfig,
  neutral_lap_time_ms : Int,
  compound : Compound,
  tyre_age_laps : Int,
  weather : Weather,
  track_status : TrackStatus,
  pit : Bool,
) -> Result[Int, ModelError] {
  if neutral_lap_time_ms < 1 {
    return Err(
      model_error(InvalidLapTime, "neutral lap time must be greater than zero"),
    )
  }
  let tyre_delta = match
    tyre_pace_delta_ms(config, compound, tyre_age_laps, weather) {
    Ok(delta) => delta
    Err(error) => return Err(error)
  }
  let pit_loss = match modeled_pit_loss_ms(config, track_status, pit) {
    Ok(loss) => loss
    Err(error) => return Err(error)
  }
  let predicted = neutral_lap_time_ms + tyre_delta + pit_loss
  if predicted < 1 {
    return Err(
      model_error(
        NonPositiveResult,
        "estimated lap time must be greater than zero",
      ),
    )
  }
  Ok(predicted)
}

///|
/// Derive a positive neutral anchor by removing modeled pace and pit effects.
///
/// This is the inverse of `estimate_lap_time_ms` for the same model inputs.
/// It preserves unmodeled observed effects in the anchor and returns
/// `ModelError` for invalid input or a non-positive derived time.
pub fn derive_neutral_lap_time_ms(
  config : PaceModelConfig,
  observed_lap_time_ms : Int,
  compound : Compound,
  tyre_age_laps : Int,
  weather : Weather,
  track_status : TrackStatus,
  pit : Bool,
) -> Result[Int, ModelError] {
  if observed_lap_time_ms < 1 {
    return Err(
      model_error(InvalidLapTime, "observed lap time must be greater than zero"),
    )
  }
  let tyre_delta = match
    tyre_pace_delta_ms(config, compound, tyre_age_laps, weather) {
    Ok(delta) => delta
    Err(error) => return Err(error)
  }
  let pit_loss = match modeled_pit_loss_ms(config, track_status, pit) {
    Ok(loss) => loss
    Err(error) => return Err(error)
  }
  let neutral = observed_lap_time_ms - tyre_delta - pit_loss
  if neutral < 1 {
    return Err(
      model_error(
        NonPositiveResult,
        "derived neutral lap time must be greater than zero",
      ),
    )
  }
  Ok(neutral)
}
