// Whitebox tests pin the procedural tree builders' private contracts.

///|
test "tree sheets are three private one-frame sheets in distinct sizes" {
  let state = State::new()
  inspect(state.tree_sheets.length(), content="3")
  let small = build_tree_sheet(width=8, height=14)
  let mid = build_tree_sheet(width=10, height=16)
  let tall = build_tree_sheet(width=12, height=20)
  for sheet in [small, mid, tall] {
    inspect(sheet.frame_count(), content="1")
  }
  assert_eq(small.frame_width(), 8)
  assert_eq(small.frame_height(), 14)
  assert_eq(mid.frame_width(), 10)
  assert_eq(mid.frame_height(), 16)
  assert_eq(tall.frame_width(), 12)
  assert_eq(tall.frame_height(), 20)
}
