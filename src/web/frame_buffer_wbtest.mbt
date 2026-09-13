///|
test "rgb565_to_rgba expands the three channels with exact bit replication" {
  let buf : FixedArray[Byte] = FixedArray::make(8, b'\x00')
  // Full-scale primaries: 0 stays 0, full stays full, alpha is opaque.
  rgb565_to_rgba(0xf800, out=buf, offset=0)
  assert_eq(buf[0].to_int(), 255)
  assert_eq(buf[1].to_int(), 0)
  assert_eq(buf[2].to_int(), 0)
  assert_eq(buf[3].to_int(), 255)
  rgb565_to_rgba(0x07e0, out=buf, offset=0)
  assert_eq(buf[0].to_int(), 0)
  assert_eq(buf[1].to_int(), 255)
  assert_eq(buf[2].to_int(), 0)
  rgb565_to_rgba(0x001f, out=buf, offset=0)
  assert_eq(buf[2].to_int(), 255)
  rgb565_to_rgba(0xffff, out=buf, offset=0)
  assert_eq(buf[0].to_int(), 255)
  assert_eq(buf[1].to_int(), 255)
  assert_eq(buf[2].to_int(), 255)
  // Mid-range values replicate high bits: r5=25 -> 25<<3 | 25>>2 = 206,
  // g6=42 -> 42<<2 | 42>>4 = 170.
  rgb565_to_rgba(25 << 11, out=buf, offset=4)
  assert_eq(buf[4].to_int(), 206)
  rgb565_to_rgba(42 << 5, out=buf, offset=4)
  assert_eq(buf[5].to_int(), 170)
}

///|
test "convert_frame presents the SDK Canvas raster through FrameView" {
  let canvas = @graphics.Canvas::new(width=2, height=2)
  canvas.clear(color=@core.Color::rgb(r=255, g=0, b=0))
  canvas.pixel(x=1, y=0, color=@core.Color::rgb(r=0, g=255, b=0))
  canvas.pixel(x=0, y=1, color=@core.Color::rgb(r=0, g=0, b=255))
  let view = canvas.frame_view()
  inspect(view.width(), content="2")
  inspect(view.height(), content="2")
  let rgba : FixedArray[Byte] = FixedArray::make(2 * 2 * 4, b'\x00')
  let row : FixedArray[Int] = FixedArray::make(2, 0)
  convert_frame(view~, rgba~, row~)
  // Row 0: red then green; row 1: blue then red.
  let channels : Array[Int] = []
  for i in 0..<16 {
    if i % 4 != 3 {
      channels.push(rgba[i].to_int())
    }
  }
  debug_inspect(
    channels,
    content="[255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 0, 0]",
  )
  // Alpha is opaque for every pixel.
  for i in 3..<16 {
    if i % 4 == 3 {
      assert_eq(rgba[i].to_int(), 255)
    }
  }
}
