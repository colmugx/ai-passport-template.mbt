///|
test "smoke scene uses SDK logical dimensions and distinct RGB565 primaries" {
  let canvas = @graphics.Canvas::logical()
  draw_smoke_scene(canvas)
  let frame = canvas.frame_view()
  debug_inspect((frame.width(), frame.height()), content="(120, 160)")
  let row : FixedArray[Int] = FixedArray::make(120, 0)
  inspect(frame.copy_rgb565_row(y=30, out=row), content="120")
  inspect(row[10], content="63488")
  inspect(frame.copy_rgb565_row(y=60, out=row), content="120")
  inspect(row[50], content="2016")
  inspect(frame.copy_rgb565_row(y=100, out=row), content="120")
  inspect(row[100], content="31")
}
