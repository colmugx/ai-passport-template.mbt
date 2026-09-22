///|
/// Screen x where the fairy walks; the world moves around her.
const FAIRY_X : Int = 26

///|
/// Ground line under the fairy's feet, chosen on the forest_world road
/// surface in the original 120x160 design space; 126 puts her feet on the
/// road's lower half before the scene is presented at 2x.
const FAIRY_BASELINE_Y : Int = 126

///|
fn battery_label(battery_percent : Int?) -> String {
  match battery_percent {
    Some(percent) => {
      if percent < 0 || percent > 100 {
        abort("battery percentage must be in 0..100")
      }
      "\{percent}%"
    }
    None => "--%"
  }
}

fn design_glyph(ch : Char) -> Int {
  match ch {
    '0' => 0x69996
    '1' => 0x4C44E
    '2' => 0x6934F
    '3' => 0xE161E
    '4' => 0x99F11
    '5' => 0xF8E1E
    '6' => 0x68E96
    '7' => 0xF1111
    '8' => 0x69696
    '9' => 0x69716
    '-' => 0x00F00
    '%' => 0x92481
    _ => 0
  }
}

///|
fn design_text_width(text : String) -> Int {
  let mut count = 0
  for _ in text {
    count += 1
  }
  if count == 0 {
    0
  } else {
    (count - 1) * 5 + 4
  }
}

///|
fn draw_design_text(
  canvas : @graphics.Canvas,
  text : String,
  x~ : Int,
  y~ : Int,
  color~ : @core.Color,
) -> Unit {
  let mut cx = x
  for ch in text {
    let pattern = design_glyph(ch)
    if pattern != 0 {
      for ry in 0..<5 {
        let row = (pattern >> ((4 - ry) * 4)) & 0xF
        for rx in 0..<4 {
          if (row & (1 << (3 - rx))) != 0 {
            draw_design_pixel(canvas, cx + rx, y + ry, color)
          }
        }
      }
    }
    cx += 5
  }
}

///|
///|
/// Draws the authored three-layer parallax scene, back to front:
///
/// 1. the far mist forest at 1/8 world speed (fully opaque base),
/// 2. the forest and walking road at world speed,
/// 3. the fixed six-frame fairy at `FAIRY_X`, feet on
///    `FAIRY_BASELINE_Y` on the road,
/// 4. the foreground foliage at 3/2 world speed, which may occlude the
///    fairy; its transparent pixels leave the scene below untouched,
/// 5. the battery HUD last, so it is never occluded.
///
/// The fairy pose index is `walker_frame`, advanced by every update.
/// `battery_percent` is semantic runtime data; no
/// hardware API is accessed by the application. Unknown readings appear as
/// `--%`. All rendering goes through the SDK Canvas; there is no procedural
/// scenery fallback.
pub fn State::draw(
  self : State,
  canvas~ : @graphics.Canvas,
  battery_percent~ : Int?,
) -> Unit {
  let scroll = self.scroll()
  draw_indexed_layer(
    canvas~,
    layer=self.far_layer,
    scroll_x=far_scroll_offset(scroll),
  )
  draw_indexed_layer(canvas~, layer=self.world_layer, scroll_x=scroll)
  let sheet = self.walker_sheet
  let frame_base = self.walker_frame * sheet.frame_width * sheet.frame_height
  let fairy_y = (FAIRY_BASELINE_Y - sheet.frame_height).max(0)
  for sy in 0..<sheet.frame_height {
    for sx in 0..<sheet.frame_width {
      let index = sheet.indices[
        frame_base + sy * sheet.frame_width + sx
      ].to_int()
      match sheet.palette[index] {
        Some(color) =>
          draw_design_pixel(canvas, FAIRY_X + sx, fairy_y + sy, color)
        None => ()
      }
    }
  }
  draw_indexed_layer(
    canvas~,
    layer=self.foreground_layer,
    scroll_x=foreground_scroll_offset(scroll),
  )
  let battery_text = battery_label(battery_percent)
  // Four logical pixels of right margin keep the text clear of the four
  // 4x4 rounded-corner occlusion regions while y=4 clears the top strip.
  let hud_color = @core.Color::rgb(r=31, g=51, b=53)
  draw_design_text(
    canvas,
    battery_text,
    x=(120 - design_text_width(battery_text) - 2).max(0),
    y=2,
    color=hud_color,
  )
}
