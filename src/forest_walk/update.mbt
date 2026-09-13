///|
/// Pure state transition for one frame.
///
/// Reads the polled `@input.InputState` snapshot; `update` itself NEVER calls
/// `@input.InputState::advance` — the host loop owns frame boundaries. The
/// scene fields are recomputed into a new `State`. The runtime reads a beat
/// snapshot from its player and passes it here; only the audio callback may
/// advance that player with the actual number of output samples.
///
/// Controls: `Ok` toggles pause on a `just_pressed` edge only; `Up` raises
/// the speed one level and `Down` lowers it, both clamped to 0..=3 and both
/// working whether paused or not. While unpaused the world scrolls
/// `speed.level` pixels and the walker pose follows `beat % 4` while moving.
/// A paused scene freezes scroll and walker pose while its frame counter
/// keeps counting. The runtime mirrors pause changes to its player.
pub fn State::update(
  self : State,
  input~ : @input.InputState,
  beat~ : Int,
) -> State {
  let frame = self.frame + 1
  let paused = if input.just_pressed(@input.Ok) {
    !self.paused
  } else {
    self.paused
  }
  // Speed keys react even while paused; the level is clamped on every change.
  let up = if input.just_pressed(@input.Up) { 1 } else { 0 }
  let down = if input.just_pressed(@input.Down) { 1 } else { 0 }
  let level = (self.speed.level + up - down).clamp(min=0, max=3)
  let (scroll, walker_frame) = if paused {
    (self.scroll, self.walker_frame)
  } else {
    (
      self.scroll + level,
      // One weight shift per large 6/8 beat; standing still holds the pose
      // even though the music (and so the beat) keeps advancing.
      if level > 0 {
        beat % 4
      } else {
        self.walker_frame
      },
    )
  }
  // Sprite sheets and the immutable song are shared between snapshots.
  {
    frame,
    scroll,
    speed: { level, },
    walker_frame,
    paused,
    song: self.song,
    walker_sheet: self.walker_sheet,
    tree_sheets: self.tree_sheets,
  }
}
