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
/// Draws one indexed scenery layer through the SDK Canvas, producing
/// exactly the framebuffer of the per-pixel formulation:
///
///   index = indices[y * width + ping_pong_x(x + scroll_x, width)]
///   transparent samples leave the canvas unchanged; others write
///   `palette[index]`
///
/// (see `ping_pong_x`, which stays the normative mapping). The cost
/// reductions are structural only — every destination pixel is written by
/// the same `Canvas::pixel` call with the same color:
///
/// - The horizontal mapping is identical for every row, so the ping-pong
///   source column is computed ONCE per destination column: the start
///   column and direction come from `scroll_x` modulo the `2 * width`
///   period, and the cursor then walks incrementally (no per-pixel
///   modulo). The `width - 1` and `0` plateaus of the ping-pong ring each
///   repeat once per period; the two boundary rules reproduce that
///   exactly, for any integer `scroll_x` (negative included, via the
///   positive start modulo).
/// - Traversing column-major keeps that column mapping shared by all
///   rows; within one layer every destination pixel is written at most
///   once, so visit order cannot change the framebuffer.
/// - Transparency is decided once per layer: samples are raw Bytes, so a
///   reserved index inside the Byte range compares bytewise and exactly,
///   a reserved index outside it can never match any sample (the layer
///   draws fully opaque), and fully opaque layers run a loop with no
///   transparency test at all. Transparent layers convert only the
///   samples they actually write.
/// - The inner row walk keeps a running index offset (`+= width` per row)
///   instead of recomputing `y * width + col`.
///
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
  // Start of the ping-pong walk for this layer: where screen x = 0 lands
  // on the 2 * width ring, and which half of the ring it is on.
  let period = layer_width * 2
  let phase = (scroll_x % period + period) % period
  let mut col = if phase < layer_width { phase } else { period - 1 - phase }
  let mut dir = if phase < layer_width { 1 } else { -1 }
  // Reserved transparency index as a comparable Byte. Samples are Bytes,
  // so a reserved index outside the Byte range matches no sample at all
  // and the layer draws as fully opaque (the constructor already
  // guarantees the index sits inside the palette).
  let transparent : Byte? = match layer.transparent_index {
    Some(t) if t >= 0 && t <= 255 => Some(t.to_byte())
    _ => None
  }
  match transparent {
    // Fully opaque layer: every sampled palette entry is written.
    None =>
      for x in 0..<screen_width {
        let mut source = col
        for y in 0..<rows {
          canvas.pixel(x~, y~, color=palette[indices[source].to_int()])
          source += layer_width
        }
        // One step right along the ping-pong ring; `width - 1` repeats
        // once when the upward walk reaches the mirror seam.
        let next = col + dir
        if next == layer_width {
          col = layer_width - 1
          dir = -1
        } else if next < 0 {
          col = 0
          dir = 1
        } else {
          col = next
        }
      }
    // Layer with transparency: raw-byte comparison against the reserved
    // index skips exactly the samples the per-pixel formulation skips.
    Some(transparent) =>
      for x in 0..<screen_width {
        let mut source = col
        for y in 0..<rows {
          let index = indices[source]
          if index != transparent {
            canvas.pixel(x~, y~, color=palette[index.to_int()])
          }
          source += layer_width
        }
        let next = col + dir
        if next == layer_width {
          col = layer_width - 1
          dir = -1
        } else if next < 0 {
          col = 0
          dir = 1
        } else {
          col = next
        }
      }
  }
}
