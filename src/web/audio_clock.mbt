///|
/// One SDK render block: 32 ms of mono PCM at 16 kHz.
const AUDIO_CHUNK_SAMPLES : Int = 512

///|
/// Keep roughly four chunks queued, without rendering seconds ahead.
const AUDIO_LOOKAHEAD_SECONDS : Double = 0.12

///|
/// Leave a small gap between the unlock callback and sample zero.
const AUDIO_START_LEAD_SECONDS : Double = 0.02

///|
/// If a timer wakes just before the queue runs dry, wait for the next timer
/// and recover rather than racing WebAudio to schedule in the past.
const AUDIO_SCHEDULING_SAFETY_SECONDS : Double = 0.01

///|
/// Maps an audible sample position to the whole dotted-quarter beat. Int64
/// arithmetic keeps the rational boundary exact; no frame delta is integrated.
fn playback_beat(played_samples : Int64, dotted_quarter_bpm : Int) -> Int {
  if dotted_quarter_bpm <= 0 {
    abort("dotted-quarter BPM must be positive")
  }
  if played_samples <= 0L {
    return 0
  }
  (played_samples *
  dotted_quarter_bpm.to_int64() /
  (@audio.SAMPLE_RATE * 60).to_int64()).to_int()
}

///|
/// Pure gate used by the timer. Hiding the page must prevent any further
/// request for a Player chunk, regardless of queue depth.
fn should_schedule_chunk(
  context_running : Bool,
  hidden : Bool,
  next_start_time : Double,
  horizon : Double,
) -> Bool {
  context_running && !hidden && next_start_time < horizon
}

///|
/// Maps scheduled WebAudio time to the sample currently audible. On an
/// underrun, a new segment begins after a short silence at the Player's
/// current position; the previous segment is clamped at its final sample.
struct PlaybackTimeline {
  mut started : Bool
  mut first_audio_start_time : Double
  mut segment_start_time : Double
  mut segment_start_sample : Int64
  mut next_start_time : Double
  mut scheduled_samples : Int64
}

///|
fn PlaybackTimeline::new() -> PlaybackTimeline {
  {
    started: false,
    first_audio_start_time: 0.0,
    segment_start_time: 0.0,
    segment_start_sample: 0L,
    next_start_time: 0.0,
    scheduled_samples: 0L,
  }
}

///|
/// Starts sample zero or recovers after the queue has actually run dry.
/// Returns true only when a real underrun had to be recovered.
fn PlaybackTimeline::prepare(self : PlaybackTimeline, now : Double) -> Bool {
  if !self.started {
    let start = now + AUDIO_START_LEAD_SECONDS
    self.started = true
    self.first_audio_start_time = start
    self.segment_start_time = start
    self.next_start_time = start
    return false
  }
  if self.next_start_time < now {
    self.segment_start_sample = self.scheduled_samples
    self.segment_start_time = now + AUDIO_START_LEAD_SECONDS
    self.next_start_time = self.segment_start_time
    return true
  }
  false
}

///|
fn PlaybackTimeline::mark_scheduled(self : PlaybackTimeline) -> Unit {
  self.scheduled_samples += AUDIO_CHUNK_SAMPLES.to_int64()
  self.next_start_time += AUDIO_CHUNK_SAMPLES.to_double() /
    @audio.SAMPLE_RATE.to_double()
}

///|
fn PlaybackTimeline::played_samples(
  self : PlaybackTimeline,
  now : Double,
) -> Int64 {
  if !self.started {
    return 0L
  }
  let anchor_time = if self.segment_start_sample == 0L {
    self.first_audio_start_time
  } else {
    self.segment_start_time
  }
  let elapsed = (now - anchor_time).max(0.0)
  let samples = self.segment_start_sample +
    (elapsed * @audio.SAMPLE_RATE.to_double()).floor().to_int64()
  if samples > self.scheduled_samples {
    self.scheduled_samples
  } else {
    samples
  }
}
