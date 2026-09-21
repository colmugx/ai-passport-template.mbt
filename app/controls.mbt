///|
/// Master output volume at startup, in percent.
pub const VOLUME_STARTUP : Int = 80

///|
/// Volume change per UP/DOWN press, in percent.
pub const VOLUME_STEP : Int = 10

///|
/// Volume bounds in percent.
pub const VOLUME_MIN : Int = 0

///|
pub const VOLUME_MAX : Int = 100

///|
/// Application-level volume and mute semantics, identical on every host.
///
/// The desired volume is remembered separately from the mute flag: muting
/// silences the output but retains the remembered volume, UP/DOWN while
/// muted adjust the remembered value WITHOUT unmuting, and unmuting restores
/// it. Every action reacts once per press transition (no auto-repeat).
pub struct Controls {
  priv mut volume : Int // remembered desired volume, 0..=100
  priv mut muted : Bool
}

///|
/// Creates the controls at the startup volume, audible.
pub fn Controls::new() -> Controls {
  { volume: VOLUME_STARTUP, muted: false, }
}

///|
/// Remembered desired volume, `0..=100`.
pub fn Controls::volume(self : Controls) -> Int {
  self.volume
}

///|
/// Whether output is muted.
pub fn Controls::muted(self : Controls) -> Bool {
  self.muted
}

///|
/// Applies one press edge of a semantic button:
///
/// - UP: volume +10, clamped to 100,
/// - DOWN: volume -10, clamped to 0,
/// - OK: toggle mute.
///
/// UP/DOWN while muted change the remembered volume but never unmute; only
/// OK clears the mute, restoring the remembered volume.
pub fn Controls::apply(self : Controls, button : @input.Button) -> Unit {
  match button {
    Up => self.volume = (self.volume + VOLUME_STEP).min(VOLUME_MAX)
    Down => self.volume = (self.volume - VOLUME_STEP).max(VOLUME_MIN)
    Ok => self.muted = !self.muted
  }
}
