///|
test "ping-pong sampler maps the documented boundaries" {
  let width = 240
  inspect(ping_pong_x(-1, width), content="0")
  inspect(ping_pong_x(0, width), content="0")
  inspect(ping_pong_x(width - 1, width), content="239")
  inspect(ping_pong_x(width, width), content="239")
  inspect(ping_pong_x(width + 1, width), content="238")
  inspect(ping_pong_x(2 * width - 1, width), content="0")
  inspect(ping_pong_x(2 * width, width), content="0")
  inspect(ping_pong_x(2 * width + 1, width), content="1")
}

///|
test "ping-pong sampler mirrors a small tile without storing a copy" {
  // One tile of 0 1 2 3 followed by its mirror, repeating in both
  // directions: ... 3 2 1 0 | 0 1 2 3 | 3 2 1 0 | 0 1 2 3 ...
  let samples : Array[Int] = []
  for x in -2..<10 {
    samples.push(ping_pong_x(x, 4))
  }
  debug_inspect(samples, content="[1, 0, 0, 1, 2, 3, 3, 2, 1, 0, 0, 1]")
}

///|
test "layer depths displace at 1/8, 1x and 3/2 of the world scroll" {
  let scroll = 16
  inspect(far_scroll_offset(scroll), content="2")
  inspect(scroll, content="16")
  inspect(foreground_scroll_offset(scroll), content="24")
  assert_true(
    far_scroll_offset(scroll) < scroll &&
    scroll < foreground_scroll_offset(scroll),
  )
}
