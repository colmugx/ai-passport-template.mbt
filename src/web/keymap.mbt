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
/// bursts translate into a single `press` edge per physical key, and a keyup
/// only releases a key that is actually held.
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
/// Applies a keydown for `code`: dispatches `press` and records the key only
/// when it was not already held (auto-repeat guard), mapped keys only.
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
      self.held[code] = button
      input.press(button)
      true
    }
    None => false
  }
}

///|
/// Applies a keyup for `code`: dispatches `release` and forgets the key only
/// when it was actually held. Returns whether a release transition was
/// dispatched.
pub fn KeyState::handle_keyup(
  self : KeyState,
  code : String,
  input : @input.InputState,
) -> Bool {
  match self.held.get(code) {
    Some(button) => {
      self.held.remove(code)
      input.release(button)
      true
    }
    None => false
  }
}

///|
/// Releases every held key, dispatching `release` for each. The runtime calls
/// this on window blur so a key held across focus loss cannot stick down.
pub fn KeyState::release_all(
  self : KeyState,
  input : @input.InputState,
) -> Unit {
  for _code, button in self.held {
    input.release(button)
  }
  self.held.clear()
}
