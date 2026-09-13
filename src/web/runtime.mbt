///|
/// DOM id of the preview canvas (see web/index.html).
const CANVAS_ID : String = "screen"

///|
/// Semantic battery fixture for the browser preview. The browser runtime has
/// no battery hardware; it supplies semantic data to the HUD only.
const BATTERY_PERCENT : Int = 82

///|
/// Everything the browser runtime owns: the SDK logical canvas and Forest
/// Walk scene, keyboard edge routing, the 30 Hz accumulator, the visual beat
/// clock, the SDK Player and WebAudio scheduling, and presentation handles.
/// Browser APIs stay in this package;
/// `forest_walk` never sees them.
priv struct Runtime {
  canvas : @graphics.Canvas
  mut state : @forest_walk.State
  input : @input.InputState
  keys : KeyState
  beat : BeatClock
  stepper : Stepper
  player : @audio.Player
  pcm : FixedArray[Int]
  timeline : PlaybackTimeline
  mut audio_context : WebAudioContext?
  mut sound_unlocked : Bool
  mut audio_failed : Bool
  mut audio_error_message : String?
  mut unlock_pending : Bool
  mut scheduler_started : Bool
  mut hidden : Bool
  // Reused scratch buffers for the FrameView -> RGBA conversion.
  row : FixedArray[Int]
  rgba : FixedArray[Byte]
  ctx : DomContext2D
  image : DomImageData
  mut last_now : Double
}

///|
/// Wires DOM keydown/keyup into `press`/`release` edges on the shared input.
/// Auto-repeat and stray keyups are filtered by `KeyState`; mapped keys
/// prevent the browser default (page scrolling) on keydown. Edges are only
/// consumed by `InputState::advance`, which the frame loop calls exactly once
/// per simulation step.
fn install_input(rt : Runtime) -> Unit {
  js_listen_keydown(event => {
    let code = js_event_code(event)
    if map_key(code) is Some(_) {
      js_prevent_default(event)
    }
    let _ = rt.keys.handle_keydown(code, rt.input)
  })
  js_listen_keyup(event => {
    let _ = rt.keys.handle_keyup(js_event_code(event), rt.input)
  })
  js_listen_blur(() => rt.keys.release_all(rt.input))
}

///|
/// One requestAnimationFrame tick: feeds the frame delta to the fixed-step
/// accumulator, runs the due 30 Hz simulation steps (advancing the input
/// edges exactly once per step), then rasterizes and presents the current
/// state.
///
/// Before sound unlock the T1 visual beat clock keeps the preview moving.
/// Afterwards, only the WebAudio playback head drives the pose. This frame
/// path never renders PCM or advances the SDK Player.
fn frame_tick(rt : Runtime, now : Double) -> Unit {
  // rAF timestamps are milliseconds; the simulation and beat clocks run on
  // seconds.
  let dt = (now - rt.last_now) / 1000.0
  rt.last_now = now
  if !rt.sound_unlocked {
    rt.beat.tick_active(dt, active=!rt.state.paused())
  }
  let steps = rt.stepper.steps_due(dt)
  for _ in 0..<steps {
    let was_paused = rt.state.paused()
    rt.state = rt.state.update(input=rt.input, beat=audible_beat(rt))
    rt.input.advance()
    if rt.state.paused() != was_paused {
      on_app_pause_changed(rt)
    }
  }
  rt.state.draw(canvas=rt.canvas, battery_percent=Some(BATTERY_PERCENT))
  convert_frame(view=rt.canvas.frame_view(), rgba=rt.rgba, row=rt.row)
  js_present(rt.ctx, rt.image, rt.rgba)
}

///|
/// Browser entry point, run when the page script loads: builds the logical
/// 120x160 canvas and the initial scene (walking at speed 1), reads the
/// showcase song's dotted-quarter tempo for the pre-audio visual clock,
/// constructs the runtime-owned Player, and starts the frame loop.
fn main {
  let canvas = @graphics.Canvas::logical()
  let state = @forest_walk.State::new()
  let width = canvas.width()
  let height = canvas.height()
  let ctx = js_setup_canvas(CANVAS_ID, width, height)
  let image = js_create_image_data(ctx, width, height)
  let rt : Runtime = {
    canvas,
    state,
    input: @input.InputState::new(),
    keys: KeyState::new(),
    beat: BeatClock::new(
      dotted_quarter_bpm=state.song().tempo().dotted_quarter_bpm,
    ),
    stepper: Stepper::new(),
    player: @audio.Player::new(song=state.song()),
    pcm: FixedArray::make(AUDIO_CHUNK_SAMPLES, 0),
    timeline: PlaybackTimeline::new(),
    audio_context: None,
    sound_unlocked: false,
    audio_failed: false,
    audio_error_message: None,
    unlock_pending: false,
    scheduler_started: false,
    hidden: js_document_hidden(),
    row: FixedArray::make(width, 0),
    rgba: FixedArray::make(width * height * 4, 0),
    ctx,
    image,
    last_now: js_now(),
  }
  install_input(rt)
  install_audio(rt)
  js_start_frame_loop(ts => frame_tick(rt, ts))
}
