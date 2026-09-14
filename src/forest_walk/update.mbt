///|
/// Hold each of the six fairy poses for four 30 Hz simulation frames.
const WALK_FRAME_HOLD : Int = 4

///|
/// Fixed horizontal movement of one logical pixel per simulation frame.
const SCROLL_PIXELS_PER_FRAME : Int = 1

///|
/// Pure state transition for one frame.
///
/// The scene fields are recomputed into a new `State`. The `beat` argument remains
/// part of the portable app contract for a future audible six-frame phase;
/// this transitional animation uses simulation frames. Music playback lives
/// entirely in the runtimes; no update touches any audio transport.
///
/// Every update advances the world by one logical pixel and walks through
/// all six fairy poses at 7.5 poses per second on a 30 Hz simulation clock.
pub fn State::update(self : State, beat~ : Int) -> State {
  let _ = beat
  let frame = self.frame + 1
  // Layer data is shared between snapshots.
  {
    frame,
    scroll: self.scroll + SCROLL_PIXELS_PER_FRAME,
    walker_frame: frame / WALK_FRAME_HOLD % 6,
    walker_sheet: self.walker_sheet,
    far_layer: self.far_layer,
    world_layer: self.world_layer,
    foreground_layer: self.foreground_layer,
  }
}
