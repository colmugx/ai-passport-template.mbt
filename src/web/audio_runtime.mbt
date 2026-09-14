///|
/// URL of the authored music file inside the preview bundle. `dev.sh`
/// copies the single authored WAV or MP3 to this fixed name, so the runtime
/// needs no knowledge of which authoring format was chosen.
const MUSIC_ASSET_URL : String = "dist/music"

///|
/// The renderer reads which part of the track is audible, not a render-ahead
/// clock. AudioContext.currentTime freezes during visibility suspension, so
/// the musical position freezes with the audible music. The eighth index
/// drives the fairy pose: one pose per eighth note at the application tempo.
fn audible_eighths(rt : Runtime) -> Int {
  if !rt.sound_unlocked {
    return rt.beat.eighths()
  }
  match rt.audio_context {
    Some(ctx) => {
      let elapsed = js_audio_current_time(ctx) - rt.music_start_time
      music_eighths(
        loop_position(elapsed, rt.music_duration),
        @forest_walk.MUSIC_DOTTED_QUARTER_BPM,
      )
    }
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
/// Fetches the authored music file and starts it as a native looping
/// AudioBufferSourceNode. The browser decodes the authored WAV/MP3 itself;
/// no PCM synthesis runs in the preview. The audible beat anchors to the
/// context time this source started.
fn start_music(rt : Runtime, ctx : WebAudioContext) -> Unit {
  js_fetch_music_binary(
    MUSIC_ASSET_URL,
    data => {
      js_decode_music(
        ctx,
        data,
        buffer => {
          let (start_time, duration) = js_start_music_loop(ctx, buffer)
          rt.music_start_time = start_time
          rt.music_duration = duration
          rt.sound_unlocked = true
          rt.unlock_pending = false
          if rt.hidden {
            sync_audio_context(rt)
          }
          refresh_sound_ui(rt)
        },
        error => audio_error(rt, "music decode failed: \{error}"),
      )
    },
    error => audio_error(rt, "music asset fetch failed: \{error}"),
  )
}

///|
/// The context's own time stops while the page is hidden, preserving the
/// looping source and the audible beat until playback resumes.
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
/// gesture. The authored track starts from its beginning once the context is
/// running and the file has been decoded.
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
          start_music(rt, ctx)
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
