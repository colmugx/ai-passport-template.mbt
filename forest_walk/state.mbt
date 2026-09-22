///|
/// All scene state for the walking loop.
///
/// The scene fields are immutable from the outside: `State::update` returns a
/// new `State` instead of rewriting them, so a frame can be redrawn safely.
/// Music is a file asset owned by the runtimes; the scene keeps no song
/// object. Fields are private; read them through the accessors.
pub struct State {
  priv frame : Int // monotonically increasing frame counter
  priv scroll_sixteenth : Int // horizontal scroll in sixteenth-pixels (see update.mbt)
  priv walker_frame : Int // fairy pose 0..=5, held 4/3 eighth notes per pose
  priv walker_sheet : IndexedSpriteSheet // built once in State::new
  // The three authored parallax layers, built once in State::new.
  priv far_layer : IndexedLayer
  priv world_layer : IndexedLayer
  priv foreground_layer : IndexedLayer
}

///|
/// Tempo the visual walk clock is tuned to. The authored music file does not
/// carry readable tempo metadata, so the cadence stays an application
/// constant: 76 dotted-quarter BPM — the same tempo as 114 quarter BPM in
/// 4/4, whose eighth note (263,158 us) is the conversion unit the runtimes
/// feed in. Runtimes that play audio derive the audible beat from their
/// playback head against this tempo; the SDK song/player types are not part
/// of this application.
pub const MUSIC_DOTTED_QUARTER_BPM : Int = 76

///|
/// Creates the ambient scene. Runtimes own music playback and audio
/// callback timing.
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

///|
/// Horizontal world scroll offset in whole logical pixels, floored from the
/// internal sixteenth-pixel accumulator.
pub fn State::scroll(self : State) -> Int {
  self.scroll_sixteenth / SUBPIXEL_UNITS_PER_PIXEL
}

///|
/// Fairy animation frame, always 0..=5.
pub fn State::walker_frame(self : State) -> Int {
  self.walker_frame
}

///|
/// The six-frame 28x32 right-facing fairy sprite sheet compiled from source art.
pub fn State::walker_sheet(self : State) -> @graphics.SpriteSheet {
  self.walker_sheet.to_sprite_sheet()
}

///|
/// Monotonically increasing frame counter.
pub fn State::frame(self : State) -> Int {
  self.frame
}
