///|
test "battery HUD formats runtime percentage and unknown reading" {
  inspect(battery_label(Some(82)), content="82%")
  inspect(battery_label(Some(0)), content="0%")
  inspect(battery_label(Some(100)), content="100%")
  inspect(battery_label(None), content="--%")
}
