///|
/// Expands one RGB565 pixel into RGBA bytes at `offset` in `out`.
///
/// Channel expansion replicates the high bits (`(c << 3) | (c >> 2)` for
/// 5-bit channels, `(c << 2) | (c >> 4)` for 6-bit) so the full 0..=31 / 0..=63
/// range maps onto 0..=255 with the extremes fixed (0 stays 0, full stays
/// 255). Alpha is opaque. The browser preview observes exactly the RGB565
/// result the SDK rasterizer produced; it never draws with Canvas2D
/// primitives.
pub fn rgb565_to_rgba(
  pixel : Int,
  out~ : FixedArray[Byte],
  offset~ : Int,
) -> Unit {
  let r5 = (pixel >> 11) & 0x1f
  let g6 = (pixel >> 5) & 0x3f
  let b5 = pixel & 0x1f
  out[offset] = ((r5 << 3) | (r5 >> 2)).to_byte()
  out[offset + 1] = ((g6 << 2) | (g6 >> 4)).to_byte()
  out[offset + 2] = ((b5 << 3) | (b5 >> 2)).to_byte()
  out[offset + 3] = b'\xff'
}

///|
/// Reads one whole rendered frame through the SDK `FrameView` API and writes
/// it into `rgba` (`width * height * 4` bytes), using `row` as scratch.
///
/// This is the only path from the SDK framebuffer to the browser: rows are
/// copied with `FrameView::copy_rgb565_row` and converted one pixel at a
/// time into the reused buffers, so presenting a frame allocates nothing on
/// the MoonBit side. `row` must hold at least `view.width()` pixels and
/// `rgba` at least `width * height * 4` bytes.
pub fn convert_frame(
  view~ : @graphics.FrameView,
  rgba~ : FixedArray[Byte],
  row~ : FixedArray[Int],
) -> Unit {
  let width = view.width()
  for y in 0..<view.height() {
    let count = view.copy_rgb565_row(y~, out=row)
    let mut offset = y * width * 4
    for i in 0..<count {
      rgb565_to_rgba(row[i], out=rgba, offset~)
      offset += 4
    }
  }
}
