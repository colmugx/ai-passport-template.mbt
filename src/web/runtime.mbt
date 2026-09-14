///|
/// DOM id of the preview canvas (see web/index.html).
const CANVAS_ID : String = "screen"

///|
/// Semantic battery fixture for the browser preview. The browser runtime has
/// no battery hardware; it supplies semantic data to the HUD only.
const BATTERY_PERCENT : Int = 82

///|
/// Everything the browser runtime owns: the SDK logical canvas and Forest
/// Walk scene, the 30 Hz accumulator, the visual beat clock, the WebAudio
/// context and the looping authored music, and presentation handles.
/// Browser APIs stay in this package;
/// `forest_walk` never sees them.
priv struct Runtime {
  canvas : @graphics.Canvas
  mut state : @forest_walk.State
  beat : BeatClock
  stepper : Stepper
  mut audio_context : WebAudioContext?
  // Audible music state: the context time the looping source started and
  // the authored track's duration anchor the playback-head beat.
  mut music_start_time : Double
  mut music_duration : Double
  mut sound_unlocked : Bool
  mut audio_failed : Bool
  mut audio_error_message : String?
  mut unlock_pending : Bool
  mut hidden : Bool
  // Reused scratch buffers for the FrameView -> RGBA conversion.
  row : FixedArray[Int]
  rgba : FixedArray[Byte]
  ctx : DomContext2D
  image : DomImageData
  mut last_now : Double
}

///|
/// One requestAnimationFrame tick: feeds the frame delta to the fixed-step
/// accumulator, runs the due 30 Hz simulation steps, then rasterizes and
/// presents the current state.
///
/// Before sound unlock the visual beat clock keeps the preview moving.
/// Afterwards, only the WebAudio playback head of the looping authored
/// track drives the pose. This frame path never touches audio transport.
fn frame_tick(rt : Runtime, now : Double) -> Unit {
  // rAF timestamps are milliseconds; the simulation and beat clocks run on
  // seconds.
  let dt = (now - rt.last_now) / 1000.0
  rt.last_now = now
  if !rt.sound_unlocked {
    rt.beat.tick(dt)
  }
  let steps = rt.stepper.steps_due(dt)
  for _ in 0..<steps {
    rt.state = rt.state.update(musical_eighths=audible_eighths(rt))
  }
  rt.state.draw(canvas=rt.canvas, battery_percent=Some(BATTERY_PERCENT))
  convert_frame(view=rt.canvas.frame_view(), rgba=rt.rgba, row=rt.row)
  js_present(rt.ctx, rt.image, rt.rgba)
}

///|
/// Browser entry point, run when the page script loads: builds the logical
/// 120x160 canvas and the fixed-speed ambient scene, tunes the pre-audio
/// visual clock to the application's music tempo, and starts the frame
/// loop. Music stays off until the explicit user gesture.
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
    beat: BeatClock::new(
      dotted_quarter_bpm=@forest_walk.MUSIC_DOTTED_QUARTER_BPM,
    ),
    stepper: Stepper::new(),
    audio_context: None,
    music_start_time: 0.0,
    music_duration: 0.0,
    sound_unlocked: false,
    audio_failed: false,
    audio_error_message: None,
    unlock_pending: false,
    hidden: js_document_hidden(),
    row: FixedArray::make(width, 0),
    rgba: FixedArray::make(width * height * 4, 0),
    ctx,
    image,
    last_now: js_now(),
  }
  install_audio(rt)
  js_start_frame_loop(ts => frame_tick(rt, ts))
}
