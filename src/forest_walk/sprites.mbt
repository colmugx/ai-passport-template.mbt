///|
/// Keeps the generated asset behind the Forest Walk package boundary.
fn build_fairy_walk_right_sheet() -> @graphics.SpriteSheet {
  @generated.build_fairy_walk_right_sheet()
}

///|
/// Builds a one-frame tree sprite sheet of the given size.
fn build_tree_sheet(width~ : Int, height~ : Int) -> @graphics.SpriteSheet {
  @graphics.SpriteSheet::from_colors(
    frame_width=width,
    frame_height=height,
    pixels=tree_pixels(width~, height~),
  )
}

///|
/// Generates one tree as row-major pixels: a jagged triangular canopy with
/// a shaded right side over a short trunk, `None` around it.
fn tree_pixels(width~ : Int, height~ : Int) -> Array[@core.Color?] {
  let leaf = @core.Color::rgb(r=58, g=110, b=74)
  let leaf_shade = @core.Color::rgb(r=40, g=84, b=56)
  let bark = @core.Color::rgb(r=96, g=72, b=50)
  let trunk_h = (height / 5).max(2)
  let canopy_bottom = height - trunk_h - 1
  let center = (width - 1) / 2
  fn at(x : Int, y : Int) -> @core.Color? {
    if y <= canopy_bottom {
      // Canopy: the half-width grows toward the base and the outermost
      // pixel of every other diagonal is dropped for a jagged edge.
      let hw = (y + 1) * (width / 2 - 1) / (canopy_bottom + 1) + 1
      let spread = x - center
      if spread.abs() <= hw && !(spread.abs() == hw && (x + y) % 2 == 0) {
        Some(if spread > 0 { leaf_shade } else { leaf })
      } else {
        None
      }
    } else if x == center || x == center + 1 {
      // Trunk: two columns under the canopy tip.
      Some(bark)
    } else {
      None
    }
  }
  let pixels : Array[@core.Color?] = []
  for y in 0..<height {
    for x in 0..<width {
      pixels.push(at(x, y))
    }
  }
  pixels
}
