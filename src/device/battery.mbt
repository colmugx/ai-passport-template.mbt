///|
/// Raw state-of-charge reading from the device battery bridge. The C side
/// owns the CW2017 gauge over the shared BSP I2C bus; the integer crosses
/// the boundary unchanged. -1 means the reading is unavailable (gauge
/// missing, unreadable, or not yet initialized).
extern "c" fn battery_soc() -> Int = "ai_passport_battery_soc"

///|
/// Converts a bridge SOC reading into HUD battery data: only 0..100 is a
/// valid charge percentage. Anything else — the -1 read failure, or a chip
/// value outside the valid range — maps to `None`, so the HUD renders `--%`
/// instead of trusting a bad number.
fn battery_percent_from_soc(soc : Int) -> Int? {
  if soc >= 0 && soc <= 100 {
    Some(soc)
  } else {
    None
  }
}

///|
/// Current battery data for the device HUD. Hardware knowledge ends at the
/// FFI above; this is the only value `forest_draw` feeds into the scene.
fn device_battery_percent() -> Int? {
  battery_percent_from_soc(battery_soc())
}
