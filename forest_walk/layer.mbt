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
/// Compact scenery is presented at an integer scale on the full logical
/// Canvas. Rendering allocates nothing: the layer data is fixed at scene
/// construction and every write goes through `Canvas::pixel`.
fn floor_div(value : Int, divisor : Int) -> Int {
  let quotient = value / divisor
  let remainder = value % divisor
  if remainder < 0 {
    quotient - 1
  } else {
    quotient
  }
}

///|
/// Samples one compact indexed scenery layer into the logical Canvas.
///
/// Scenery assets are stored at 120x160 with `scale=2`, while the SDK and
/// Canvas remain full-resolution 240x320. Scroll offsets stay in logical
/// pixels; source coordinates are derived with floor division so negative
/// scrolls preserve the same ping-pong direction at half-resolution.
fn draw_indexed_layer(
  canvas~ : @graphics.Canvas,
  layer~ : IndexedLayer,
  scroll_x~ : Int,
) -> Unit {
  let scale = layer.scale
  let logical_width = layer.width * scale
  let logical_height = layer.height * scale
  let columns = canvas.width().min(logical_width)
  let rows = canvas.height().min(logical_height)
  let palette = layer.palette
  let indices = layer.indices
  let transparent = layer.transparent_index

  for x in 0..<columns {
    let source_x = ping_pong_x(
      floor_div(x + scroll_x, scale),
      layer.width,
    )
    for y in 0..<rows {
      let source_y = y / scale
      let index = indices[source_y * layer.width + source_x].to_int()
      let skip = match transparent {
        Some(t) => index == t
        None => false
      }
      if not(skip) {
        canvas.pixel(x~, y~, color=palette[index])
      }
    }
  }
}
