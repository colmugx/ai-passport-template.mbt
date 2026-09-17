pub struct State {
  priv frame : Int
  priv scroll_sixteenth : Int
  priv walker_frame : Int
  priv walker_sheet : @graphics.SpriteSheet
  priv far_layer : @generated.IndexedLayer
  priv world_layer : @generated.IndexedLayer
  priv foreground_layer : @generated.IndexedLayer
}

pub const MUSIC_DOTTED_QUARTER_BPM : Int = 76

pub fn State::new() -> State {
  {
    frame: 0,
    scroll_sixteenth: 0,
    walker_frame: 0,
    walker_sheet: build_fairy_walk_right_sheet(),
    far_layer: build_forest_far_layer(),
    world_layer: build_forest_world_layer(),
    foreground_layer: build_forest_foreground_layer(),
  }
}

pub fn State::scroll(self : State) -> Int {
  self.scroll_sixteenth / SUBPIXEL_UNITS_PER_PIXEL
}

pub fn State::walker_frame(self : State) -> Int {
  self.walker_frame
}

pub fn State::walker_sheet(self : State) -> @graphics.SpriteSheet {
  self.walker_sheet
}

pub fn State::frame(self : State) -> Int {
  self.frame
}
