///|
/// The C ABI sees only small entry functions. MoonBit retains the scene,
/// logical framebuffer and display sink for the entire device run.
priv struct DeviceScene {
  mut state : @forest_walk.State
  canvas : @graphics.Canvas
  sink : EspDisplaySink
}

///|
priv struct SceneSlot {
  mut scene : DeviceScene?
}

///|
let scene_slot : SceneSlot = { scene: None, }

///|
#export_name("ai_passport_mbt_forest_init")
pub fn forest_init() -> Unit {
  if scene_slot.scene is Some(_) {
    abort("Forest Walk device scene initialized twice")
  }
  let state = @forest_walk.State::new()
  let canvas = @graphics.Canvas::logical()
  let sink = EspDisplaySink::new()
  scene_slot.scene = Some({ state, canvas, sink, })
}

///|
fn require_scene() -> DeviceScene {
  match scene_slot.scene {
    Some(scene) => scene
    None => abort("Forest Walk device scene used before initialization")
  }
}

///|
#export_name("ai_passport_mbt_forest_update")
pub fn forest_update() -> Unit {
  let scene = require_scene()
  scene.state = scene.state.update(beat=0)
}

///|
#export_name("ai_passport_mbt_forest_draw")
pub fn forest_draw() -> Unit {
  let scene = require_scene()
  scene.state.draw(canvas=scene.canvas, battery_percent=None)
}

///|
#export_name("ai_passport_mbt_forest_present")
pub fn forest_present() -> Unit {
  let scene = require_scene()
  @driver.DisplaySink::present(scene.sink, frame=scene.canvas.frame_view())
}
