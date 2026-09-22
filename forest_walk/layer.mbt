///|
/// Maps a world x coordinate onto one horizontal tile of a layer with the
/// given width using ping-pong tiling: `A | mirror(A) | A | mirror(A) ...`.
/// Samples past the right edge re-enter from the right of the mirrored tile,
/// which avoids an abrupt unmatched left/right seam without storing a
/// mirrored copy. `width` must be positive.
///
/// Example for width 4: x -2 -1 0 1 2 3 4 5 6 7 8 9 maps to
/// 1 0 0 1 2 3 3 2 1 0 0 1.
pub fn ping_pong_x(world_x : Int, width : Int) -> Int {
  let period = width * 2
  // Positive modulo keeps negative world coordinates on the same ring.
  let phase = (world_x % period + period) % period
  if phase < width {
    phase
  } else {
    period - 1 - phase
  }
}

///|
/// Far depth scroll: the mist forest advances at 1/8 of the world speed.
pub fn far_scroll_offset(scroll : Int) -> Int {
  scroll / 8
}

///|
/// Foreground depth scroll: close foliage advances at 3/2 of the world speed.
pub fn foreground_scroll_offset(scroll : Int) -> Int {
  scroll * 3 / 2
}

///|
/// Forest Walk keeps its authored 120x160 design coordinate system. The
/// 240x320 SDK Canvas is a 2x presentation surface only.
fn draw_design_pixel(
  canvas : @graphics.Canvas,
  x : Int,
  y : Int,
  color : @core.Color,
) -> Unit {
  let px = x * 2
  let py = y * 2
  canvas.pixel(x=px, y=py, color~)
  canvas.pixel(x=px + 1, y=py, color~)
  canvas.pixel(x=px, y=py + 1, color~)
  canvas.pixel(x=px + 1, y=py + 1, color~)
}

///|
/// Draws one scenery layer in the original 120x160 design coordinate system.
/// The final 240x320 SDK Canvas is only a presentation target: every design
/// pixel expands to one 2x2 block.
fn draw_indexed_layer(
  canvas~ : @graphics.Canvas,
  layer~ : IndexedLayer,
  scroll_x~ : Int,
) -> Unit {
  let columns = (canvas.width() / 2).min(layer.width)
  let rows = (canvas.height() / 2).min(layer.height)
  let palette = layer.palette
  let indices = layer.indices
  let transparent = layer.transparent_index
  for x in 0..<columns {
    let source_x = ping_pong_x(x + scroll_x, layer.width)
    for y in 0..<rows {
      let index = indices[y * layer.width + source_x].to_int()
      let skip = match transparent {
        Some(t) => index == t
        None => false
      }
      if skip {
        continue
      }
      draw_design_pixel(canvas, x, y, palette[index])
    }
  }
}
