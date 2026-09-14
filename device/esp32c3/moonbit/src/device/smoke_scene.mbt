///|
/// Draws an orientation and RGB565 diagnostic on the SDK's logical canvas.
/// The clipped corner blocks expose all four edges of the 120 x 160 frame.
pub fn draw_smoke_scene(canvas : @graphics.Canvas) -> Unit {
  let dark = @core.Color::rgb(r=8, g=12, b=24)
  let red = @core.Color::rgb(r=255, g=0, b=0)
  let green = @core.Color::rgb(r=0, g=255, b=0)
  let blue = @core.Color::rgb(r=0, g=0, b=255)
  let white = @core.Color::rgb(r=255, g=255, b=255)
  canvas.clear(color=dark)
  canvas.fill_rect(x=-2, y=14, w=42, h=35, color=red)
  canvas.fill_rect(x=40, y=49, w=40, h=35, color=green)
  canvas.fill_rect(x=80, y=84, w=42, h=35, color=blue)
  canvas.line(x0=0, y0=159, x1=119, y1=0, color=white)
  canvas.pixel(x=0, y=0, color=white)
  canvas.pixel(x=119, y=159, color=white)
  canvas.text(text="MBT RGB565", x=4, y=4, color=white)
}

///|
/// Runs the portable smoke scene through any SDK display sink.
pub fn present_smoke_scene(sink : &@driver.DisplaySink) -> Unit {
  let canvas = @graphics.Canvas::logical()
  draw_smoke_scene(canvas)
  sink.present(frame=canvas.frame_view())
}
