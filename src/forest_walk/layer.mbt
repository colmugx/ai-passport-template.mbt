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
/// Draws one indexed scenery layer through the SDK Canvas. For each logical
/// destination pixel the world x is `screen_x + scroll_x`; its source column
/// is `ping_pong_x(world_x, layer.width)` and its source row is the
/// destination row. Transparent samples leave the existing canvas content
/// unchanged, so lower layers and the fairy stay visible through them.
/// Rendering allocates nothing: the layer data is fixed at scene
/// construction and every write goes through `Canvas::pixel`.
fn draw_indexed_layer(
  canvas~ : @graphics.Canvas,
  layer~ : @generated.IndexedLayer,
  scroll_x~ : Int,
) -> Unit {
  let screen_width = canvas.width()
  // Layers cover 160 rows; canvases taller than that would clip silently,
  // matching the SDK sprite and rectangle behaviour at the edges.
  let rows = canvas.height().min(layer.height)
  let layer_width = layer.width
  let palette = layer.palette
  let indices = layer.indices
  let transparent_index = layer.transparent_index
  for y in 0..<rows {
    let row = y * layer_width
    for x in 0..<screen_width {
      let index = indices[row + ping_pong_x(x + scroll_x, layer_width)].to_int()
      let skip = match transparent_index {
        Some(t) => index == t
        None => false
      }
      if skip {
        continue
      }
      canvas.pixel(x~, y~, color=palette[index])
    }
  }
}
