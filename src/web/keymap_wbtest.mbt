///|
test "map_key covers the documented controls and ignores the rest" {
  debug_inspect(map_key("ArrowUp"), content="Some(Up)")
  debug_inspect(map_key("ArrowDown"), content="Some(Down)")
  debug_inspect(map_key("Space"), content="Some(Ok)")
  debug_inspect(map_key("Enter"), content="Some(Ok)")
  debug_inspect(map_key("KeyA"), content="None")
  debug_inspect(map_key("ShiftLeft"), content="None")
}

///|
test "KeyState dispatches one press edge per physical keydown" {
  let input = @input.InputState::new()
  let keys = KeyState::new()
  // First keydown presses; the auto-repeat keydowns do nothing.
  inspect(keys.handle_keydown("ArrowUp", input), content="true")
  inspect(keys.handle_keydown("ArrowUp", input), content="false")
  inspect(keys.handle_keydown("ArrowUp", input), content="false")
  inspect(input.pressed(@input.Up), content="true")
  input.advance()
  inspect(input.just_pressed(@input.Up), content="false")
  inspect(input.pressed(@input.Up), content="true")
}

///|
test "KeyState releases only held keys" {
  let input = @input.InputState::new()
  let keys = KeyState::new()
  inspect(keys.handle_keyup("Space", input), content="false")
  inspect(keys.handle_keydown("Space", input), content="true")
  inspect(input.pressed(@input.Ok), content="true")
  inspect(keys.handle_keyup("Space", input), content="true")
  inspect(input.pressed(@input.Ok), content="false")
  input.advance()
  inspect(input.just_released(@input.Ok), content="false")
  // Re-press after release works.
  inspect(keys.handle_keydown("Enter", input), content="true")
  inspect(input.pressed(@input.Ok), content="true")
}

///|
test "Space and Enter keep Ok held until the last alias is released" {
  let input = @input.InputState::new()
  let keys = KeyState::new()
  inspect(keys.handle_keydown("Space", input), content="true")
  input.advance()
  inspect(keys.handle_keydown("Enter", input), content="false")
  inspect(keys.handle_keydown("Enter", input), content="false")
  inspect(input.pressed(@input.Ok), content="true")
  inspect(input.just_pressed(@input.Ok), content="false")
  inspect(keys.handle_keyup("Space", input), content="false")
  inspect(input.pressed(@input.Ok), content="true")
  inspect(input.just_released(@input.Ok), content="false")
  inspect(keys.handle_keyup("Enter", input), content="true")
  inspect(input.pressed(@input.Ok), content="false")
  inspect(input.just_released(@input.Ok), content="true")
  inspect(keys.handle_keyup("Enter", input), content="false")
}

///|
test "Ok aliases also work when Enter is pressed first" {
  let input = @input.InputState::new()
  let keys = KeyState::new()
  inspect(keys.handle_keydown("Enter", input), content="true")
  inspect(keys.handle_keydown("Space", input), content="false")
  inspect(keys.handle_keyup("Enter", input), content="false")
  inspect(input.pressed(@input.Ok), content="true")
  inspect(keys.handle_keyup("Space", input), content="true")
  inspect(input.pressed(@input.Ok), content="false")
}

///|
test "KeyState release_all clears stuck keys on blur" {
  let input = @input.InputState::new()
  let keys = KeyState::new()
  let _ = keys.handle_keydown("ArrowUp", input)
  let _ = keys.handle_keydown("ArrowDown", input)
  let _ = keys.handle_keydown("Space", input)
  let _ = keys.handle_keydown("Enter", input)
  keys.release_all(input)
  inspect(input.pressed(@input.Up), content="false")
  inspect(input.pressed(@input.Down), content="false")
  inspect(input.pressed(@input.Ok), content="false")
  // After blur, a fresh keydown presses again.
  inspect(keys.handle_keydown("ArrowUp", input), content="true")
}

///|
test "KeyState ignores unmapped keys entirely" {
  let input = @input.InputState::new()
  let keys = KeyState::new()
  inspect(keys.handle_keydown("KeyA", input), content="false")
  inspect(keys.handle_keyup("KeyA", input), content="false")
  // Unmapped keys do not shadow later mapped presses.
  inspect(keys.handle_keydown("Enter", input), content="true")
}
