// Browser-only WebAudio adapter. The Player and timing policy live in MoonBit;
// JS only owns opaque browser handles and the actual AudioBufferSourceNodes.

///|
type WebAudioContext

///|
extern "js" fn js_open_audio_context(
  on_ready : (WebAudioContext) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #| (onReady, onError) => {
  #|   try {
  #|     const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  #|     if (!AudioContextClass) throw new Error("WebAudio AudioContext is unavailable");
  #|     onReady(new AudioContextClass());
  #|   } catch (error) {
  #|     onError(String(error));
  #|   }
  #| }

///|
extern "js" fn js_audio_current_time(ctx : WebAudioContext) -> Double =
  #| (ctx) => ctx.currentTime

///|
extern "js" fn js_audio_state(ctx : WebAudioContext) -> String =
  #| (ctx) => ctx.state

///|
/// Resume/suspend are asynchronous in browsers. Report the actual resulting
/// state, and surface rejections visibly instead of assuming success.
extern "js" fn js_audio_set_running(
  ctx : WebAudioContext,
  running : Bool,
  on_done : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #| (ctx, running, onDone, onError) => {
  #|   try {
  #|     const operation = running ? ctx.resume() : ctx.suspend();
  #|     Promise.resolve(operation).then(() => onDone(ctx.state)).catch(error => onError(String(error)));
  #|   } catch (error) {
  #|     onError(String(error));
  #|   }
  #| }

///|
/// Schedule exactly one mono SDK PCM16 block at its requested context time.
/// WebAudio resamples this 16 kHz content to the physical device if needed.
extern "js" fn js_schedule_pcm16(
  ctx : WebAudioContext,
  pcm : FixedArray[Int],
  start_time : Double,
) -> String =
  #| (ctx, pcm, startTime) => {
  #|   try {
  #|     if (startTime < ctx.currentTime) throw new Error("PCM block was scheduled in the past");
  #|     const buffer = ctx.createBuffer(1, pcm.length, 16000);
  #|     const channel = buffer.getChannelData(0);
  #|     for (let i = 0; i < pcm.length; i++) channel[i] = pcm[i] / 32768.0;
  #|     const source = ctx.createBufferSource();
  #|     source.buffer = buffer;
  #|     source.connect(ctx.destination);
  #|     source.start(startTime);
  #|     return "";
  #|   } catch (error) {
  #|     return String(error);
  #|   }
  #| }

///|
extern "js" fn js_start_audio_scheduler(
  interval_ms : Int,
  tick : () -> Unit,
) -> Unit =
  #| (intervalMs, tick) => { setInterval(tick, intervalMs); }

///|
extern "js" fn js_listen_enable_sound(handler : () -> Unit) -> Unit =
  #| (handler) => {
  #|   const button = document.getElementById("enable-sound");
  #|   if (!(button instanceof HTMLButtonElement)) throw new Error("Enable sound button is missing");
  #|   button.addEventListener("click", handler);
  #| }

///|
extern "js" fn js_set_sound_ui(status : String, enabled : Bool) -> Unit =
  #| (status, enabled) => {
  #|   const button = document.getElementById("enable-sound");
  #|   const label = document.getElementById("sound-status");
  #|   if (!(button instanceof HTMLButtonElement) || !label) throw new Error("Sound controls are missing");
  #|   button.hidden = enabled;
  #|   label.textContent = status;
  #| }

///|
extern "js" fn js_document_hidden() -> Bool =
  #| () => document.hidden

///|
extern "js" fn js_listen_visibility(handler : (Bool) -> Unit) -> Unit =
  #| (handler) => document.addEventListener("visibilitychange", () => handler(document.hidden))

///|
extern "js" fn js_log_audio_underrun(seconds_late : Double) -> Unit =
  #| (secondsLate) => console.warn("AI Passport audio scheduler underrun; restarting after silence", { secondsLate })

///|
extern "js" fn js_log_audio_error(message : String) -> Unit =
  #| (message) => console.error("AI Passport WebAudio error:", message)
