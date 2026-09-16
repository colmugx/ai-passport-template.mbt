///|
/// The portable Forest Walk application: the single owner of long-lived
/// application state, valid on every host unchanged.
///
/// It owns the SDK logical `Canvas`, the Forest Walk `State`, the fixed-step
/// 30 Hz simulation clock, the musical-position source (audible playback
/// position with loop wrap and presentation lead, or the monotonic fallback
/// beat clock while audio is unavailable) and the application-level
/// volume/mute controls. It owns no platform transport: hosts feed it host
/// facts (`now_us`, `playback_position_us`, `presentation_lead_us`,
/// battery) and present `frame_view()` through their own display sink.
///
/// The dependency direction is the Project Contract: this package depends
/// only on the ai-passport SDK, `forest_walk` and `forest_walk/generated` —
/// never on DOM, WebAudio, JS FFI, ESP-IDF, BSP or C FFI.
pub struct App {
  priv canvas : @graphics.Canvas
  priv mut state : @forest_walk.State
  priv stepper : Stepper
  priv beat : BeatClock
  priv controls : Controls
  priv input : @input.InputState
  priv mut last_now_us : Int64?
}

///|
/// Creates the application with a logical 120x160 canvas and a fresh Forest
/// Walk scene, at the startup volume, audible, clock at zero and no time
/// baseline yet (the first `advance` latches it).
pub fn App::new() -> App {
  {
    canvas: @graphics.Canvas::logical(),
    state: @forest_walk.State::new(),
    stepper: Stepper::new(),
    beat: BeatClock::new(),
    controls: Controls::new(),
    input: @input.InputState::new(),
    last_now_us: None,
  }
}

///|
/// Latches one raw semantic button transition. Edges accumulate between
/// `advance` calls (events may arrive at any time) and are applied exactly
/// once per press transition at the next `advance` — one press edge
/// produces exactly one semantic action, with no auto-repeat.
pub fn App::input(self : App, button : @input.Button, pressed : Bool) -> Unit {
  if pressed {
    self.input.press(button)
  } else {
    self.input.release(button)
  }
}

///|
/// One host frame tick; returns nothing, hosts present after it.
///
/// `now_us` is the host's monotonic frame timestamp in microseconds. The
/// FIRST call establishes the time baseline and simulates nothing
/// (`delta_us = 0`): host clocks (browser `performance.now()`,
/// `esp_timer_get_time()`) already run before the application boots, and
/// time that elapsed before `App` execution began must not be simulated.
/// Afterwards each call measures `max(now_us - previous_now_us, 0)`, so
/// equal or earlier timestamps never rewind the clock. Hosts may call
/// this at any rate — the application alone decides when logical 30 Hz
/// simulation steps occur (catch-up is bounded).
///
/// `playback_position_us` is a host fact: the audible musical position. On
/// hosts whose position is monotonic across loops (the web host), it is
/// wrapped at the canonical PCM duration here, giving every host the same
/// loop-relative application timeline. `None` (or a non-positive position)
/// means playback is unavailable — locked, failed or absent — and the
/// monotonic fallback beat clock keeps the animation moving at tempo.
///
/// `presentation_lead_us` is a generic host calibration fact added to the
/// loop-relative position before deriving the musical eighth: the device
/// passes its hardware-measured 100 ms, the web host passes 0. No platform
/// test exists here; the lead may carry a wrapped position past the loop
/// end, and the eighth index then continues past the loop's final eighth,
/// matching the proven loop-boundary phase behavior.
pub fn App::advance(
  self : App,
  now_us : Int64,
  playback_position_us? : Int64,
  presentation_lead_us? : Int64 = 0L,
) -> Unit {
  let delta_us = match self.last_now_us {
    Some(previous) => {
      self.last_now_us = Some(now_us)
      if now_us > previous {
        now_us - previous
      } else {
        0L
      }
    }
    // First tick: only latch the host time baseline.
    None => {
      self.last_now_us = Some(now_us)
      0L
    }
  }
  self.apply_input_edges()
  let eighths = self.musical_position(
    delta_us~,
    playback_position_us.unwrap_or(0L),
    presentation_lead_us~,
  )
  let steps = self.stepper.steps_due(delta_us)
  for _ in 0..<steps {
    self.state = self.state.update(musical_eighths=eighths)
  }
}

///|
/// Applies latched button edges exactly once per host frame: UP/DOWN/OK map
/// to the application controls; the latches clear at the frame boundary.
fn App::apply_input_edges(self : App) -> Unit {
  if self.input.just_pressed(Up) {
    self.controls.apply(Up)
  }
  if self.input.just_pressed(Down) {
    self.controls.apply(Down)
  }
  if self.input.just_pressed(Ok) {
    self.controls.apply(Ok)
  }
  self.input.advance()
}

///|
/// Resolves the current musical position in whole eighth notes. A live
/// playback position (positive, with a known canonical duration) is wrapped
/// at the duration, advanced by the presentation lead and converted; without
/// one, the monotonic fallback clock accumulates this frame's delta so the
/// fairy never freezes while audio is locked or unavailable.
fn App::musical_position(
  self : App,
  delta_us~ : Int64,
  playback_position_us : Int64,
  presentation_lead_us~ : Int64,
) -> Int {
  let duration = @generated.AUDIO_DURATION_US
  if playback_position_us > 0L && duration > 0L {
    musical_eighths(
      loop_position_us(playback_position_us, duration) + presentation_lead_us,
      @forest_walk.MUSIC_DOTTED_QUARTER_BPM,
    )
  } else {
    self.beat.tick(delta_us)
    self.beat.eighths(@forest_walk.MUSIC_DOTTED_QUARTER_BPM)
  }
}

///|
/// Draws the current scene into the logical canvas. `battery_percent` is
/// semantic host data (`None` renders `--%`); drawing never advances the
/// simulation or audio transport.
pub fn App::draw(self : App, battery_percent~ : Int?) -> Unit {
  self.state.draw(canvas=self.canvas, battery_percent~)
}

///|
/// Read-only view of the presented logical framebuffer; hosts blit it
/// through their own display sink.
pub fn App::frame_view(self : App) -> @graphics.FrameView {
  self.canvas.frame_view()
}

///|
/// Remembered desired volume, `0..=100` (independent of the mute flag).
pub fn App::volume(self : App) -> Int {
  self.controls.volume()
}

///|
/// Whether output is muted.
pub fn App::muted(self : App) -> Bool {
  self.controls.muted()
}

///|
/// Monotonically increasing simulation frame counter (one per logical 30 Hz
/// step).
pub fn App::frame(self : App) -> Int {
  self.state.frame()
}

///|
/// Horizontal world scroll offset in whole logical pixels (floored from the
/// internal quarter-pixel accumulator; 22.5 px/s at 30 Hz).
pub fn App::scroll(self : App) -> Int {
  self.state.scroll()
}

///|
/// Current fairy pose, always `0..=5` (one pose per musical eighth).
pub fn App::walker_frame(self : App) -> Int {
  self.state.walker_frame()
}
