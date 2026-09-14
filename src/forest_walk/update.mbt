///|
/// Hold each of the six fairy poses for four 30 Hz simulation frames.
const WALK_FRAME_HOLD : Int = 4

///|
/// Pure state transition for one frame.
///
/// Reads the polled `@input.InputState` snapshot; `update` itself NEVER calls
/// `@input.InputState::advance` — the host loop owns frame boundaries. The
/// scene fields are recomputed into a new `State`. The `beat` argument remains
/// part of the portable app contract for a future audible six-frame phase;
/// this transitional animation uses simulation frames. Only the audio
/// runtime may advance the Player with actual output sample counts.
///
/// Controls: `Ok` toggles pause on a `just_pressed` edge only; `Up` raises
/// the speed one level and `Down` lowers it, both clamped to 0..=3 and both
/// working whether paused or not. While unpaused the world scrolls
/// `speed.level` pixels and the fairy pose advances every four moving frames.
/// Standing resets to pose 0. Pause freezes scroll and the exact current pose
/// while the general frame counter keeps counting.
pub fn State::update(
  self : State,
  input~ : @input.InputState,
  beat~ : Int,
) -> State {
  let _ = beat
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
  let (scroll, animation_frames, walker_frame) = if paused {
    (self.scroll, self.animation_frames, self.walker_frame)
  } else if level == 0 {
    (self.scroll, 0, 0)
  } else {
    let animation_frames = self.animation_frames + 1
    (
      self.scroll + level,
      animation_frames,
      animation_frames / WALK_FRAME_HOLD % 6,
    )
  }
  // Layer data and the immutable song are shared between snapshots.
  {
    frame,
    scroll,
    speed: { level, },
    animation_frames,
    walker_frame,
    paused,
    song: self.song,
    walker_sheet: self.walker_sheet,
    far_layer: self.far_layer,
    world_layer: self.world_layer,
    foreground_layer: self.foreground_layer,
  }
}
