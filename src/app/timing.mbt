///|
/// Application simulation rate in logical update steps per second. Hosts may
/// call `App::advance` at any rate (browser rAF ~60/120 Hz, device ~30 Hz);
/// the application alone decides when a logical Forest Walk simulation step
/// occurs, so the visible cadence is identical on every host.
pub const SIMULATION_HZ : Int = 30

///|
/// Upper bound on catch-up steps after a stall (tab suspension, debugger
/// breakpoint). At 30 Hz this lets at most 1/6 s of backlog run per frame.
const MAX_CATCHUP_STEPS : Int = 5

///|
/// Fixed-timestep accumulator for the 30 Hz simulation, integer-exact.
///
/// Time is banked in units of microseconds multiplied by `SIMULATION_HZ`, so
/// one whole simulation step corresponds to an accumulator value of exactly
/// 1_000_000 — the reciprocal of 30 Hz never has to be rounded, and the
/// long-run step rate is exactly 30 Hz with zero drift. A step is issued
/// when accumulated real time crosses each next multiple of 1/30 s; the
/// remainder is kept for the next call.
pub struct Stepper {
  priv mut acc : Int64 // banked time in us x SIMULATION_HZ
}

///|
/// Creates an empty accumulator.
pub fn Stepper::new() -> Stepper {
  { acc: 0L, }
}

///|
/// Feeds one frame delta in microseconds (negative values are treated as
/// zero) and returns how many simulation steps are due now. The backlog is
/// capped at `MAX_CATCHUP_STEPS` steps, so a suspended tab cannot trigger
/// hundreds of catch-up updates when it wakes.
pub fn Stepper::steps_due(self : Stepper, delta_us : Int64) -> Int {
  if delta_us <= 0L {
    return 0
  }
  let max_acc = MAX_CATCHUP_STEPS.to_int64() * 1_000_000L
  let fed = self.acc + delta_us * SIMULATION_HZ.to_int64()
  self.acc = if fed > max_acc { max_acc } else { fed }
  let steps = (self.acc / 1_000_000L).to_int()
  self.acc -= steps.to_int64() * 1_000_000L
  steps
}
