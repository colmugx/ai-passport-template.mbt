///|
/// The native bridge consumes rows synchronously and owns the physical DMA
/// strip. This package holds only one reusable logical RGB565 row.
pub struct EspDisplaySink {
  row : FixedArray[Int]
}

///|
pub fn EspDisplaySink::new() -> EspDisplaySink {
  { row: FixedArray::make(120, 0), }
}

///|
extern "c" fn display_begin() -> Unit = "ai_passport_display_begin"

///|
#borrow(row)
extern "c" fn display_row(y : Int, row : FixedArray[Int]) -> Unit = "ai_passport_display_row"

///|
extern "c" fn display_end() -> Unit = "ai_passport_display_end"

///|
pub impl @driver.DisplaySink for EspDisplaySink with fn present(
  self,
  frame~ : @graphics.FrameView,
) -> Unit {
  if frame.width() != 120 || frame.height() != 160 {
    abort("EspDisplaySink expects a 120 x 160 logical frame")
  }
  display_begin()
  for y in 0..<160 {
    let count = frame.copy_rgb565_row(y~, out=self.row)
    if count != 120 {
      abort("EspDisplaySink received a truncated RGB565 row")
    }
    display_row(y, self.row)
  }
  display_end()
}
