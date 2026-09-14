///|
/// The renderer reads which sample is audible, not the render-ahead Player's
/// beat. AudioContext.currentTime freezes during visibility suspension.
fn audible_beat(rt : Runtime) -> Int {
  if !rt.sound_unlocked {
    return rt.beat.beat()
  }
  match rt.audio_context {
    Some(ctx) =>
      playback_beat(
        rt.timeline.played_samples(js_audio_current_time(ctx)),
        rt.state.song().tempo().dotted_quarter_bpm,
      )
    None => abort("unlocked sound has no AudioContext")
  }
}

///|
fn refresh_sound_ui(rt : Runtime) -> Unit {
  if rt.audio_failed {
    match rt.audio_error_message {
      Some(message) =>
        js_set_sound_ui("Sound: error — \{message}", rt.sound_unlocked)
      None => abort("failed audio has no error message")
    }
  } else if !rt.sound_unlocked {
    if rt.unlock_pending {
      js_set_sound_ui("Sound: enabling…", false)
    } else {
      js_set_sound_ui("Sound: off", false)
    }
  } else if rt.hidden {
    js_set_sound_ui("Sound: suspended in background", true)
  } else {
    match rt.audio_context {
      Some(ctx) =>
        if js_audio_state(ctx) == "running" {
          js_set_sound_ui("Sound: on", true)
        } else {
          js_set_sound_ui("Sound: resuming…", true)
        }
      None => abort("unlocked sound has no AudioContext")
    }
  }
}

///|
fn audio_error(rt : Runtime, message : String) -> Unit {
  rt.unlock_pending = false
  rt.audio_failed = true
  rt.audio_error_message = Some(message)
  js_log_audio_error(message)
  refresh_sound_ui(rt)
}

///|
/// Only this timer callback may ask the SDK Player for PCM. It keeps around
/// 120 ms of 16 kHz mono audio scheduled, reusing the same 512-sample buffer.
/// A missed timer leaves silence, logs an underrun, and resumes at the next
/// unrendered Player sample instead of skipping the song forward.
fn audio_scheduler_tick(rt : Runtime) -> Unit {
  if rt.audio_failed || !rt.sound_unlocked || rt.hidden {
    return
  }
  match rt.audio_context {
    Some(ctx) => {
      let context_state = js_audio_state(ctx)
      let running = context_state == "running"
      if !running {
        if context_state != "suspended" {
          audio_error(rt, "AudioContext stopped unexpectedly: \{context_state}")
        }
        return
      }
      let now = js_audio_current_time(ctx)
      if rt.timeline.started &&
        rt.timeline.next_start_time >= now &&
        rt.timeline.next_start_time - now < AUDIO_SCHEDULING_SAFETY_SECONDS {
        return
      }
      let late = if rt.timeline.started {
        now - rt.timeline.next_start_time
      } else {
        0.0
      }
      if rt.timeline.prepare(now) {
        js_log_audio_underrun(late)
      }
      let horizon = now + AUDIO_LOOKAHEAD_SECONDS
      while should_schedule_chunk(
              running,
              rt.hidden,
              rt.timeline.next_start_time,
              horizon,
            ) {
        rt.player.render(out=rt.pcm)
        let error = js_schedule_pcm16(ctx, rt.pcm, rt.timeline.next_start_time)
        if error != "" {
          audio_error(rt, error)
          return
        }
        rt.timeline.mark_scheduled()
      }
    }
    None => abort("unlocked sound has no AudioContext")
  }
}

///|
/// The context's own time stops while the page is hidden, preserving queued
/// sources and the audible beat until playback resumes.
fn sync_audio_context(rt : Runtime) -> Unit {
  if rt.audio_failed || !rt.sound_unlocked {
    return
  }
  match rt.audio_context {
    Some(ctx) => {
      let should_run = !rt.hidden
      js_audio_set_running(
        ctx,
        should_run,
        state => {
          let desired_now = !rt.hidden
          if desired_now != should_run {
            sync_audio_context(rt)
          } else if (state == "running") != desired_now {
            audio_error(
              rt,
              "AudioContext did not reach requested state: \{state}",
            )
          } else {
            refresh_sound_ui(rt)
          }
        },
        error => audio_error(rt, error),
      )
      refresh_sound_ui(rt)
    }
    None => abort("unlocked sound has no AudioContext")
  }
}

///|
/// AudioContext construction and resume happen in this explicit click
/// gesture. The Song/Player were created at sample zero but have rendered no
/// PCM, so the first scheduled chunk always starts at the song beginning.
fn enable_sound(rt : Runtime) -> Unit {
  if rt.sound_unlocked || rt.unlock_pending {
    return
  }
  rt.audio_failed = false
  rt.audio_error_message = None
  rt.unlock_pending = true
  refresh_sound_ui(rt)
  js_open_audio_context(
    ctx => {
      rt.audio_context = Some(ctx)
      js_audio_set_running(
        ctx,
        true,
        state => {
          if state != "running" {
            audio_error(
              rt,
              "AudioContext did not enter running state: \{state}",
            )
            return
          }
          rt.sound_unlocked = true
          rt.unlock_pending = false
          if !rt.scheduler_started {
            rt.scheduler_started = true
            js_start_audio_scheduler(20, () => audio_scheduler_tick(rt))
          }
          if rt.hidden {
            sync_audio_context(rt)
          }
          refresh_sound_ui(rt)
        },
        error => audio_error(rt, error),
      )
    },
    error => audio_error(rt, error),
  )
}

///|
fn install_audio(rt : Runtime) -> Unit {
  refresh_sound_ui(rt)
  js_listen_enable_sound(() => enable_sound(rt))
  js_listen_visibility(hidden => {
    rt.hidden = hidden
    sync_audio_context(rt)
    refresh_sound_ui(rt)
  })
}
