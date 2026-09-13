///|
/// Walking speed in discrete steps; clamped to 0..=3 (0 = standing still).
pub(all) struct Speed {
  level : Int
}

///|
/// Standing-still speed, reached by pressing Down from the starter speed.
pub fn Speed::zero() -> Speed {
  { level: 0, }
}

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
  priv speed : Speed
  priv walker_frame : Int // walker animation frame 0..=3
  priv paused : Bool
  priv song : @music.Song
  priv walker_sheet : @graphics.SpriteSheet // built once in State::new
  priv tree_sheets : Array[@graphics.SpriteSheet] // built once in State::new
}

///|
/// Builds one placeholder note of the given duration in song ticks
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
/// Creates the initial scene walking at speed 1 and unpaused. The runtime
/// constructs its own player from `song()` and owns audio callback timing.
pub fn State::new() -> State {
  let song = showcase_song()
  {
    frame: 0,
    scroll: 0,
    speed: { level: 1, },
    walker_frame: 0,
    paused: false,
    song,
    walker_sheet: build_walker_sheet(),
    tree_sheets: [
      build_tree_sheet(width=8, height=14),
      build_tree_sheet(width=10, height=16),
      build_tree_sheet(width=12, height=20),
    ],
  }
}

///|
/// Current walking speed.
pub fn State::speed(self : State) -> Speed {
  self.speed
}

///|
/// Whether the scene (and its music) is paused.
pub fn State::paused(self : State) -> Bool {
  self.paused
}

///|
/// Horizontal world scroll offset in pixels.
pub fn State::scroll(self : State) -> Int {
  self.scroll
}

///|
/// Walker animation frame, always 0..=3.
pub fn State::walker_frame(self : State) -> Int {
  self.walker_frame
}

///|
/// The walker's four-frame sprite sheet: four 12x20 placeholder poses
/// generated procedurally, one weight-shift beat each.
pub fn State::walker_sheet(self : State) -> @graphics.SpriteSheet {
  self.walker_sheet
}

///|
/// Monotonically increasing frame counter; it advances even while paused.
pub fn State::frame(self : State) -> Int {
  self.frame
}

///|
/// The four-voice showcase song driving the scene's music.
pub fn State::song(self : State) -> @music.Song {
  self.song
}

///|
