///|
/// Device-only input delivery export: carries one raw physical button press
/// from the C button bridge into the portable App. The code is a
/// device-neutral fact fixed by the C ABI (`button_bridge.h`): 0 = Up,
/// 1 = Down, 2 = Ok; unknown codes are ignored. No control meaning lives
/// here — UP/DOWN/OK volume/mute semantics are owned solely by the shared
/// `@app.App` (its `Controls`), exactly as on the Wasm/Web path.
///
/// The BSP reports a press pulse rather than a clean press/release pair, so
/// the pulse is adapted to the portable input contract: exactly one
/// `just_pressed` edge is latched and immediately released. Held state is
/// left clear while the next `App::advance` applies exactly one action.
#export_name("ai_passport_mbt_input_press")
pub fn input_press(code : Int) -> Unit {
  let button : @input.Button = match code {
    0 => Up
    1 => Down
    2 => Ok
    _ => return
  }
  let scene = require_scene()
  scene.app.input(button, true)
  scene.app.input(button, false)
}
