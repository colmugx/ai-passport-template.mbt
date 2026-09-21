///|
/// Sub-pixel resolution of the scroll accumulator: sixteen units per logical
/// pixel. Fine enough to express the 16.875 px/s walking pace exactly (9
/// units per 30 Hz frame).
const SUBPIXEL_UNITS_PER_PIXEL : Int = 16

///|
/// Fixed horizontal movement of nine sixteenth-pixels per simulation frame:
/// 0.5625 logical pixels per 30 Hz update, or 16.875 pixels per second —
/// three quarters of the original 22.5 px/s pace, matching the 4/4 walk
/// cycle (six poses per bar) so the fairy covers the same ground per
/// footstep as before. The accumulator keeps the average exact, so rendered
/// whole-pixel offsets never drift.
const SCROLL_SIXTEENTH_PIXELS_PER_FRAME : Int = 9

///|
/// Poses per completed walk cycle. The six-frame sheet spans one 4/4 bar of
/// eight whole-eighth buckets. Integer mapping produces the exact sequence
/// `0,0,1,2,3,3,4,5`; pose 0 and pose 3 each occupy two eighth buckets while
/// the others occupy one. Across the full bar the average is 8/6 = 4/3
/// eighths per pose, and the cycle closes exactly on the bar line.
const WALK_CYCLE_POSES : Int = 6

///|
/// Eighths per 4/4 bar. The pose index is
/// floor(eighths * poses / eighths_per_bar) — integer-exactly
/// floor(eighths * 3 / 4) — so pose 0 always lands on the downbeat.
const EIGHTHS_PER_BAR : Int = 8

///|
/// Pure state transition for one frame.
///
/// The scene fields are recomputed into a new `State`. The fairy pose is the
/// audible six-frame phase of the portable app contract: the runtime passes
/// the musical position in whole eighth-note buckets at the application
/// tempo (114 quarter BPM, i.e. 76 dotted-quarter BPM), and the production
/// mapping `floor(eighths * 3 / 4) % 6` yields `0,0,1,2,3,3,4,5` across one
/// 4/4 bar. Music playback itself lives entirely in the runtimes; no update
/// touches any audio transport.
///
/// Every update advances the world by nine sixteenth-pixels; the pose comes
/// only from `musical_eighths`, never from the simulation frame counter.
pub fn State::update(self : State, musical_eighths~ : Int) -> State {
  let frame = self.frame + 1
  let pose = musical_eighths * WALK_CYCLE_POSES / EIGHTHS_PER_BAR
  // Layer data is shared between snapshots.
  {
    frame,
    scroll_sixteenth: self.scroll_sixteenth + SCROLL_SIXTEENTH_PIXELS_PER_FRAME,
    walker_frame: pose % WALK_CYCLE_POSES,
    walker_sheet: self.walker_sheet,
    far_layer: self.far_layer,
    world_layer: self.world_layer,
    foreground_layer: self.foreground_layer,
  }
}
