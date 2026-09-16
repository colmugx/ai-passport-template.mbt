///|
/// One ABI v0 frame tick (exported as `passport_frame`): advance the bridge
/// clock, feed the App the host facts (frame timestamp, best-effort
/// playback position, presentation lead 0 on the web host), mirror any
/// volume/mute deltas, refresh the battery cache, draw, and present the
/// logical frame into the linear-memory framebuffer (marks it dirty).
pub fn passport_frame(now_us : Int64) -> Unit {
  state.bridge.advance(now_us)
  // SDK 0.0.2 has no playback-available import, so availability must be
  // inferred from the raw position fact: before the browser AudioContext
  // unlocks, the host reports 0, which maps to None (fallback beat clock).
  // Once playback has begun, the web position is monotonic across loops and
  // never sits at a loop-relative 0 boundary, so `raw > 0` stays exact for
  // this host. Do not replicate this mapping on the device: its transport
  // reports availability separately and its loop boundary IS position 0.
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

///|
/// Wire button delivery (exported as `passport_input`): `button` is
/// 0=Up 1=Down 2=Ok and `pressed` is 1=press 0=release. Unknown codes are
/// ignored; events latch into the App and apply at the next
/// `passport_frame` — the same `@app` input logic the device will route
/// through in R2B.
pub fn passport_input(button : Int, pressed : Int) -> Unit {
  match @hostabi.to_button(button) {
    Some(btn) => state.app.input(btn, pressed != 0)
    None => ()
  }
}

///|
/// Byte offset of the persistent linear-memory framebuffer
/// (exported as `passport_fb_ptr`; the frozen ABI value 4096).
pub fn passport_fb_ptr() -> Int {
  @hostabi.FRAMEBUFFER_PTR
}

///|
/// Byte length of the framebuffer region: 120 * 160 RGB565 uint16 = 38400
/// (exported as `passport_fb_len`).
pub fn passport_fb_len() -> Int {
  @hostabi.FRAMEBUFFER_LEN
}

///|
/// Whether a frame has been presented since the last consume, reported as
/// `1`/`0` for the wasm boundary (exported as `passport_frame_dirty`).
pub fn passport_frame_dirty() -> Int {
  if state.bridge.frame_dirty() {
    1
  } else {
    0
  }
}

///|
/// Clears the dirty flag after the host has blitted the framebuffer
/// (exported as `passport_frame_consume`).
pub fn passport_frame_consume() -> Unit {
  state.bridge.consume()
}
