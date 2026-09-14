///|
/// C calls this symbol from app_main to prove MoonBit code is linked and run.
#export_name("ai_passport_mbt_probe")
pub fn probe() -> Int {
  0xA100 | 0x7E
}
