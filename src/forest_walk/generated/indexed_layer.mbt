///|
/// Hand-written support for the generated scenery layer files. Every
/// generated `build_*_layer` function assembles one of these records from a
/// compact palette plus one-byte hex-encoded pixel indices, so a full
/// 240x160 layer costs one byte array and a small palette at runtime instead
/// of thousands of color expressions. Layers are built once at scene
/// construction; rendering never reconstructs or resizes them.
pub(all) struct IndexedLayer {
  width : Int
  height : Int
  /// Opaque palette colors, the lookup target of `indices`. The slot at
  /// `transparent_index`, when present, is never sampled by the renderer.
  palette : FixedArray[@core.Color]
  /// Row-major one-byte palette indices, exactly `width * height` entries.
  indices : FixedArray[Byte]
  /// Palette index reserved for transparency; `None` for fully opaque layers.
  transparent_index : Int?
}

///|
/// Assembles one IndexedLayer from generated data, decoding the hex-encoded
/// index stream. The data is produced by tools/compile_layers.py and is
/// validated here so a malformed generated file aborts loudly at startup
/// instead of corrupting the scene.
fn indexed_layer(
  width~ : Int,
  height~ : Int,
  palette~ : Array[@core.Color],
  encoded~ : Array[String],
  transparent_index~ : Int?,
) -> IndexedLayer {
  let pixel_count = width * height
  let indices : FixedArray[Byte] = FixedArray::make(pixel_count, 0)
  let mut high = -1
  let mut count = 0
  for block in encoded {
    for digit in block {
      let code = digit.to_int()
      let nibble = if code >= 48 && code <= 57 {
        code - 48
      } else if code >= 65 && code <= 70 {
        code - 55
      } else {
        abort("generated layer has a non-hex character in its index stream")
      }
      if high < 0 {
        high = nibble
      } else {
        if count >= pixel_count {
          abort("generated layer has more indices than width * height")
        }
        indices[count] = (high * 16 + nibble).to_byte()
        count += 1
        high = -1
      }
    }
  }
  if high >= 0 || count != pixel_count {
    abort("generated layer index count does not match width * height")
  }
  let colors = FixedArray::from_array(palette)
  for i in 0..<count {
    if indices[i].to_int() >= colors.length() {
      abort("generated layer references a palette index outside the palette")
    }
  }
  match transparent_index {
    Some(t) =>
      if t < 0 || t >= colors.length() {
        abort("generated layer transparent index is outside the palette")
      }
    None => ()
  }
  { width, height, palette: colors, indices, transparent_index, }
}
