///|
/// Maps a browser `KeyboardEvent.code` to the Forest Walk button it drives.
///
/// ArrowUp raises the walking speed, ArrowDown lowers it, and Space or Enter
/// toggles pause. Unmapped codes return `None` and leave the input untouched.
pub fn map_key(code : String) -> @input.Button? {
  match code {
    "ArrowUp" => Some(@input.Up)
    "ArrowDown" => Some(@input.Down)
    "Space" | "Enter" => Some(@input.Ok)
    _ => None
  }
}

///|
/// Tracks which mapped browser keys are currently held so auto-repeat keydown
/// bursts translate into a single `press` edge per physical key. Multiple
/// physical keys can map to one logical button; the button stays pressed until
/// its last physical key is released.
///
/// Pure browser-agnostic logic: the runtime feeds it `KeyboardEvent.code`
/// strings from the DOM events and forwards the transitions to the shared
/// `@input.InputState` via `press` / `release`. The frame loop owns
/// `InputState::advance`, exactly once per simulation step.
pub struct KeyState {
  priv held : Map[String, @input.Button]
}

///|
/// Creates an empty held-key tracker.
pub fn KeyState::new() -> KeyState {
  { held: Map([]), }
}

///|
/// Whether any held physical key currently drives `button`.
fn KeyState::holds_button(self : KeyState, button : @input.Button) -> Bool {
  for _code, held_button in self.held {
    if held_button == button {
      return true
    }
  }
  false
}

///|
/// Applies a keydown for `code`: records each mapped physical key only once
/// (auto-repeat guard), and presses its logical button only on the first key.
/// Returns whether a press transition was dispatched.
pub fn KeyState::handle_keydown(
  self : KeyState,
  code : String,
  input : @input.InputState,
) -> Bool {
  if self.held.contains(code) {
    return false
  }
  match map_key(code) {
    Some(button) => {
      let already_pressed = self.holds_button(button)
      self.held[code] = button
      if already_pressed {
        false
      } else {
        input.press(button)
        true
      }
    }
    None => false
  }
}

///|
/// Applies a keyup for `code`: forgets the held physical key, and releases its
/// logical button only when no other physical alias remains held. Returns
/// whether a release transition was dispatched.
pub fn KeyState::handle_keyup(
  self : KeyState,
  code : String,
  input : @input.InputState,
) -> Bool {
  match self.held.get(code) {
    Some(button) => {
      self.held.remove(code)
      if self.holds_button(button) {
        false
      } else {
        input.release(button)
        true
      }
    }
    None => false
  }
}

///|
/// Releases each held logical button once. The runtime calls this on window
/// blur so a key held across focus loss cannot stick down.
pub fn KeyState::release_all(
  self : KeyState,
  input : @input.InputState,
) -> Unit {
  if self.holds_button(@input.Up) {
    input.release(@input.Up)
  }
  if self.holds_button(@input.Down) {
    input.release(@input.Down)
  }
  if self.holds_button(@input.Ok) {
    input.release(@input.Ok)
  }
  self.held.clear()
}
