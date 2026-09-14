///|
/// Sub-pixel resolution of the scroll accumulator: four quarter-pixels per
/// logical pixel.
const SUBPIXEL_UNITS_PER_PIXEL : Int = 4

///|
/// Fixed horizontal movement of three quarter-pixels per simulation frame:
/// 0.75 logical pixels per 30 Hz update, or 22.5 pixels per second — 25%
/// slower than the original one-pixel-per-update pace. The accumulator keeps
/// the average exact, so rendered whole-pixel offsets never drift.
const SCROLL_QUARTER_PIXELS_PER_FRAME : Int = 3

///|
/// Pure state transition for one frame.
///
/// The scene fields are recomputed into a new `State`. The fairy pose is the
/// audible six-frame phase of the portable app contract: the runtime passes
/// the musical position in eighth notes (at the application tempo, one
/// dotted-quarter beat is three eighths), and one pose lasts exactly one
/// eighth — one full six-pose walk cycle per 6/8 bar. Music playback itself
/// lives entirely in the runtimes; no update touches any audio transport.
///
/// Every update advances the world by three quarter-pixels; the pose comes
/// only from `musical_eighths`, never from the simulation frame counter.
pub fn State::update(self : State, musical_eighths~ : Int) -> State {
  let frame = self.frame + 1
  // Layer data is shared between snapshots.
  {
    frame,
    scroll_quarter: self.scroll_quarter + SCROLL_QUARTER_PIXELS_PER_FRAME,
    walker_frame: musical_eighths % 6,
    walker_sheet: self.walker_sheet,
    far_layer: self.far_layer,
    world_layer: self.world_layer,
    foreground_layer: self.foreground_layer,
  }
}
