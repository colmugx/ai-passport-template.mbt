pub struct App {
  priv canvas : @graphics.Canvas
  priv mut state : @forest_walk.State
  priv stepper : Stepper
  priv beat : BeatClock
  priv controls : Controls
  priv input : @input.InputState
  priv mut last_now_us : Int64?
}

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

pub fn App::input(self : App, button : @input.Button, pressed : Bool) -> Unit {
  if pressed {
    self.input.press(button)
  } else {
    self.input.release(button)
  }
}

/// First tick establishes the host-time baseline. `Some(0)` is a valid live
/// playback position; `None` falls back to the monotonic beat clock.
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
    None => {
      self.last_now_us = Some(now_us)
      0L
    }
  }
  self.apply_input_edges()
  let eighths = self.musical_position(
    delta_us~,
    playback_position_us,
    presentation_lead_us~,
  )
  let steps = self.stepper.steps_due(delta_us)
  for _ in 0..<steps {
    self.state = self.state.update(musical_eighths=eighths)
  }
}

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

fn App::musical_position(
  self : App,
  delta_us~ : Int64,
  playback_position_us : Int64?,
  presentation_lead_us~ : Int64,
) -> Int {
  let duration = @generated.AUDIO_DURATION_US
  match playback_position_us {
    Some(position) if position >= 0L && duration > 0L =>
      musical_eighths(
        loop_position_us(position, duration) + presentation_lead_us,
        @forest_walk.MUSIC_DOTTED_QUARTER_BPM,
      )
    _ => {
      self.beat.tick(delta_us)
      self.beat.eighths(@forest_walk.MUSIC_DOTTED_QUARTER_BPM)
    }
  }
}

pub fn App::draw(self : App, battery_percent~ : Int?) -> Unit {
  self.state.draw(canvas=self.canvas, battery_percent~)
}

pub fn App::frame_view(self : App) -> @graphics.FrameView {
  self.canvas.frame_view()
}

pub fn App::volume(self : App) -> Int {
  self.controls.volume()
}

pub fn App::muted(self : App) -> Bool {
  self.controls.muted()
}

pub fn App::frame(self : App) -> Int {
  self.state.frame()
}

pub fn App::scroll(self : App) -> Int {
  self.state.scroll()
}

/// Pose mapping across each eight-eighth bar is `0,0,1,2,3,3,4,5`.
pub fn App::walker_frame(self : App) -> Int {
  self.state.walker_frame()
}
