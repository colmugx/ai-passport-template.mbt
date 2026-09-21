///|
/// Explicit promotion of the Application trait methods below, replacing the
/// deprecated implicit impl-as-method promotion (warning E79).
pub extend App with @application.Application::{
  audio_output,
  render,
  button,
  update,
}

///|
pub impl @application.Application for App with fn update(
  self : App,
  ctx : @application.FrameContext,
) -> Unit {
  self.advance(
    ctx.now_us,
    playback_position_us?=self.music_position_us(),
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
/// The application entry the CLI-generated Host adapters load.
pub fn passport_main() -> &@application.Application {
  App::new()
}
