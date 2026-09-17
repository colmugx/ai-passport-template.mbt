/// One Web-host frame tick.
pub fn passport_frame(now_us : Int64) -> Unit {
  state.bridge.advance(now_us)
  // The Web Host reports 0 before audio is available. Once playback starts,
  // its position is monotonic across loops, so raw > 0 is the availability
  // boundary for this host only.
  let raw = @hostabi.host_playback_pos_us()
  let playback_position : Int64? = if raw > 0L { Some(raw) } else { None }
  state.app.advance(
    now_us,
    playback_position_us?=playback_position,
    presentation_lead_us=0L,
  )
  sync_audio_state(state)
  state.battery.refresh()
  state.app.draw(battery_percent=state.battery.percent())
  let sink : &@driver.DisplaySink = state.bridge
  sink.present(frame=state.app.frame_view())
}

pub fn passport_input(button : Int, pressed : Int) -> Unit {
  match @hostabi.to_button(button) {
    Some(btn) => state.app.input(btn, pressed != 0)
    None => ()
  }
}

pub fn passport_fb_ptr() -> Int {
  @hostabi.FRAMEBUFFER_PTR
}

pub fn passport_fb_len() -> Int {
  @hostabi.FRAMEBUFFER_LEN
}

pub fn passport_frame_dirty() -> Int {
  if state.bridge.frame_dirty() {
    1
  } else {
    0
  }
}

pub fn passport_frame_consume() -> Unit {
  state.bridge.consume()
}
