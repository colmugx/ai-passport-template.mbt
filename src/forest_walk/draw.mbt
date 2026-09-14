///|
/// Screen x where the fairy walks; the world moves around her.
const FAIRY_X : Int = 26

///|
/// Ground line under the fairy's feet, chosen on the forest_world road
/// surface (the road's fully opaque rows are 114..129 in the generated
/// layer, so 126 puts her feet on the road's lower half).
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
  canvas.sprite(
    sheet~,
    frame=self.walker_frame,
    x=FAIRY_X,
    y=(FAIRY_BASELINE_Y - sheet.frame_height()).max(0),
  )
  draw_indexed_layer(
    canvas~,
    layer=self.foreground_layer,
    scroll_x=foreground_scroll_offset(scroll),
  )
  let battery_text = battery_label(battery_percent)
  // Four logical pixels of right margin keep the text clear of the four
  // 4x4 rounded-corner occlusion regions while y=4 clears the top strip.
  canvas.text(
    text=battery_text,
    x=(canvas.width() - @graphics.text_width(text=battery_text) - 4).max(0),
    y=4,
    color=@core.Color::rgb(r=31, g=51, b=53),
  )
}
