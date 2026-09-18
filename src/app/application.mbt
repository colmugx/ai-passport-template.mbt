///|
/// The SDK application contract, implemented by delegation to the portable
/// `App`: `update` is one `App::advance` frame tick with the Host facts,
/// `button` latches one semantic edge, `render` draws and returns the
/// logical frame view, and `audio_output` reports the desired output state
/// (Forest Walk always has audio state, so never `None`).
pub impl @application.Application for App with fn update(
  self : App,
  ctx : @application.FrameContext,
) -> Unit {
  self.advance(
    ctx.now_us,
    playback_position_us?=ctx.playback_position_us,
    presentation_lead_us=ctx.presentation_lead_us,
  )
}

///|
pub impl @application.Application for App with fn button(
  self : App,
  button : @input.Button,
  pressed : Bool,
) -> Unit {
  self.input(button, pressed)
}

///|
pub impl @application.Application for App with fn render(
  self : App,
  battery_percent : Int?,
) -> @graphics.FrameView {
  self.draw(battery_percent~)
  self.frame_view()
}

///|
pub impl @application.Application for App with fn audio_output(self : App) -> @application.AudioOutput? {
  Some({ volume: self.volume(), muted: self.muted(), })
}

///|
/// The application entry the SDK Host adapters load: one Forest Walk `App`
/// behind the application contract.
pub fn passport_main() -> &@application.Application {
  App::new()
}
