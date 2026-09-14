///|
/// All scene state for the walking loop.
///
/// The scene fields are immutable from the outside: `State::update` returns a
/// new `State` instead of rewriting them, so a frame can be redrawn safely.
/// The runtime owns the mutable audio player and supplies its beat snapshot
/// to `update`. Fields are private; read them through the accessors.
pub struct State {
  priv frame : Int // monotonically increasing frame counter
  priv scroll : Int // horizontal world scroll offset in pixels
  priv walker_frame : Int // fairy animation frame 0..=5
  priv song : @music.Song
  priv walker_sheet : @graphics.SpriteSheet // built once in State::new
  // The three authored parallax layers, built once in State::new.
  priv far_layer : @generated.IndexedLayer
  priv world_layer : @generated.IndexedLayer
  priv foreground_layer : @generated.IndexedLayer
}

///|
/// Builds one note of the given duration in song ticks
/// (4 ticks per eighth note at the default v0.1 resolution).
fn note(midi~ : Int, ticks~ : Int) -> @music.Note {
  { pitch: @music.Pitch::from_midi(midi~), ticks, }
}

///|
/// Builds one rest of the given duration in song ticks.
fn rest(ticks~ : Int) -> @music.Note {
  { pitch: None, ticks, }
}

///|
/// Builds one monophonic voice for the showcase song from one of the SDK
/// instrument presets (whose role names are the showcase roles).
fn showcase_track(
  instrument~ : @music.Instrument,
  notes~ : Array[@music.Note],
) -> @music.Track {
  { instrument, notes, }
}

///|
/// Authors the four showcase tracks (Celesta, Woodwind Lead, Lyrical Strings,
/// Low Strings). Package private so the whitebox
/// tests verify the exact authoring data the song snapshot is built from.
fn showcase_tracks() -> Array[@music.Track] {
  [
    showcase_track(instrument=@music.Instrument::celesta(), notes=[
      note(midi=76, ticks=4),
      rest(ticks=4),
      note(midi=79, ticks=4),
      note(midi=83, ticks=4),
      rest(ticks=8),
    ]),
    showcase_track(instrument=@music.Instrument::woodwind(), notes=[
      note(midi=71, ticks=12),
      rest(ticks=12),
    ]),
    showcase_track(instrument=@music.Instrument::strings(), notes=[
      rest(ticks=8),
      note(midi=64, ticks=16),
    ]),
    showcase_track(instrument=@music.Instrument::low_strings(), notes=[
      note(midi=40, ticks=12),
      rest(ticks=4),
      note(midi=45, ticks=8),
    ]),
  ]
}

///|
/// Builds the four-voice Forest Walk showcase song (Celesta, Woodwind Lead,
/// Lyrical Strings, Low Strings over 6/8) as an
/// immutable SDK snapshot. Package private so the whitebox tests verify the
/// same snapshot the scene plays. The four-voice cap holds by construction,
/// so a violation would be a bug and aborts loudly instead of being
/// swallowed.
fn showcase_song() -> @music.Song {
  @music.Song::new(
    meter=@music.Meter::six_eight(),
    tempo=@music.Tempo::standard(),
    tracks=showcase_tracks(),
  ) catch {
    err => abort("showcase song violates four-voice cap: \{err}")
  }
}

///|
/// Creates the ambient scene. The runtime constructs its own player from
/// `song()` and owns audio callback timing.
pub fn State::new() -> State {
  let song = showcase_song()
  {
    frame: 0,
    scroll: 0,
    walker_frame: 0,
    song,
    walker_sheet: build_fairy_walk_right_sheet(),
    far_layer: build_forest_far_layer(),
    world_layer: build_forest_world_layer(),
    foreground_layer: build_forest_foreground_layer(),
  }
}

///|
/// Horizontal world scroll offset in pixels.
pub fn State::scroll(self : State) -> Int {
  self.scroll
}

///|
/// Fairy animation frame, always 0..=5.
pub fn State::walker_frame(self : State) -> Int {
  self.walker_frame
}

///|
/// The six-frame 28x32 right-facing fairy sprite sheet compiled from source art.
pub fn State::walker_sheet(self : State) -> @graphics.SpriteSheet {
  self.walker_sheet
}

///|
/// Monotonically increasing frame counter.
pub fn State::frame(self : State) -> Int {
  self.frame
}

///|
/// The four-voice showcase song driving the scene's music.
pub fn State::song(self : State) -> @music.Song {
  self.song
}

///|
