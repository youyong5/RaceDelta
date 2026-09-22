///|
fn model_error(code : ModelErrorCode, message : String) -> ModelError {
  { code, message, }
}

///|
fn all_compounds() -> Array[Compound] {
  [Soft, Medium, Hard, Intermediate, Wet]
}

///|
fn profile_count(config : PaceModelConfig, compound : Compound) -> Int {
  let mut count = 0
  for profile in config.tyre_profiles {
    if profile.compound == compound {
      count = count + 1
    }
  }
  count
}

///|
fn find_tyre_profile(
  config : PaceModelConfig,
  compound : Compound,
) -> TyreProfile? {
  for profile in config.tyre_profiles {
    if profile.compound == compound {
      return Some(profile)
    }
  }
  None
}

///|
/// Validate that the model configuration has exactly one valid profile per compound.
///
/// Returns `Ok(())` only when every supported compound has exactly one profile,
/// degradation and cliff values are valid, and both pit losses are non-negative.
/// Otherwise returns a structured `ModelError` with a stable error code.
pub fn validate_pace_model_config(
  config : PaceModelConfig,
) -> Result[Unit, ModelError] {
  for compound in all_compounds() {
    let count = profile_count(config, compound)
    if count == 0 {
      return Err(
        model_error(
          MissingTyreProfile,
          "missing tyre profile for a required compound",
        ),
      )
    }
    if count > 1 {
      return Err(
        model_error(
          DuplicateTyreProfile,
          "duplicate tyre profile for a compound",
        ),
      )
    }
  }
  for profile in config.tyre_profiles {
    if profile.degradation_ms_per_lap < 0 {
      return Err(
        model_error(
          NegativeLinearDegradation,
          "linear tyre degradation must not be negative",
        ),
      )
    }
    if profile.cliff_age_laps < 1 {
      return Err(
        model_error(InvalidCliffAge, "cliff tyre age must be at least 1"),
      )
    }
    if profile.cliff_extra_ms_per_lap < 0 {
      return Err(
        model_error(
          NegativeCliffExtraDegradation,
          "cliff extra degradation must not be negative",
        ),
      )
    }
  }
  let pit_loss = config.pit_loss_profile
  if pit_loss.green_pit_loss_ms < 0 {
    return Err(
      model_error(
        NegativeGreenPitLoss,
        "green-flag pit loss must not be negative",
      ),
    )
  }
  if pit_loss.safety_car_pit_loss_ms < 0 {
    return Err(
      model_error(
        NegativeSafetyCarPitLoss,
        "Safety Car pit loss must not be negative",
      ),
    )
  }
  Ok(())
}
