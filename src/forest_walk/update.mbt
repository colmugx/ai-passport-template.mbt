const SUBPIXEL_UNITS_PER_PIXEL : Int = 16
const SCROLL_SIXTEENTH_PIXELS_PER_FRAME : Int = 9
const WALK_CYCLE_POSES : Int = 6
const EIGHTHS_PER_BAR : Int = 8

/// Pose buckets across a 4/4 bar are exactly `0,0,1,2,3,3,4,5`.
pub fn State::update(self : State, musical_eighths~ : Int) -> State {
  let frame = self.frame + 1
  let pose = musical_eighths * WALK_CYCLE_POSES / EIGHTHS_PER_BAR
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
