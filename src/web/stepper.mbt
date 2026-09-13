///|
/// Application simulation rate in update steps per second. requestAnimationFrame
/// may fire at the display refresh rate; the scene still updates at 30 Hz.
pub const SIMULATION_HZ : Double = 30.0

///|
/// Upper bound on catch-up steps after a stall (tab suspension, debugger
/// pause). At 30 Hz this lets at most 1/6 s of backlog run per frame.
const MAX_CATCHUP_STEPS : Int = 5

///|
/// Fixed-timestep accumulator for the frame loop.
///
/// `steps_due` turns one requestAnimationFrame delta into the number of whole
/// 1/30 s simulation steps to run and banks the remainder for the next frame.
/// The accumulated backlog is capped at `MAX_CATCHUP_STEPS` steps, so a
/// suspended tab cannot trigger hundreds of catch-up updates when it wakes.
pub struct Stepper {
  priv mut accumulated : Double
}

///|
/// Creates an empty accumulator.
pub fn Stepper::new() -> Stepper {
  { accumulated: 0.0, }
}

///|
/// Feeds one frame delta in seconds (negative values are treated as zero) and
/// returns how many simulation steps are due now.
pub fn Stepper::steps_due(self : Stepper, dt : Double) -> Int {
  let step = 1.0 / SIMULATION_HZ
  let max = step * MAX_CATCHUP_STEPS.to_double()
  let mut acc = self.accumulated + (if dt > 0.0 { dt } else { 0.0 })
  if acc > max {
    acc = max
  }
  let steps = (acc / step).floor().to_int()
  self.accumulated = acc - steps.to_double() * step
  steps
}
