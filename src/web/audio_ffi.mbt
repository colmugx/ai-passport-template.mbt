// Browser-only WebAudio adapter. The music policy (gesture unlock,
// suspend/resume, beat derivation) lives in MoonBit; JS only owns opaque
// browser handles and the actual AudioBufferSourceNode.

///|
type WebAudioContext

///|
/// ArrayBuffer holding the fetched authored music file.
type WebAudioBytes

///|
/// Decoded AudioBuffer of the authored track.
type WebAudioBuffer

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
/// Fetches the authored music asset as raw bytes. The browser performs no
/// synthesis; whatever WAV/MP3 the author committed is served verbatim.
extern "js" fn js_fetch_music_binary(
  url : String,
  on_data : (WebAudioBytes) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #| (url, onData, onError) => {
  #|   fetch(url)
  #|     .then(response => {
  #|       if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
  #|       return response.arrayBuffer();
  #|     })
  #|     .then(data => onData(data))
  #|     .catch(error => onError(String(error)));
  #| }

///|
/// Native browser decoding of the authored WAV/MP3 into an AudioBuffer.
extern "js" fn js_decode_music(
  ctx : WebAudioContext,
  data : WebAudioBytes,
  on_ready : (WebAudioBuffer) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #| (ctx, data, onReady, onError) => {
  #|   ctx.decodeAudioData(data).then(onReady).catch(error => onError(String(error)));
  #| }

///|
/// Starts the decoded track as a looping source connected to the output and
/// reports (start context time, track duration). Native looping keeps the
/// boundary gap-free; suspend/resume of the context pauses and resumes the
/// same source without drift.
extern "js" fn js_start_music_loop(
  ctx : WebAudioContext,
  buffer : WebAudioBuffer,
) -> (Double, Double) =
  #| (ctx, buffer) => {
  #|   const source = ctx.createBufferSource();
  #|   source.buffer = buffer;
  #|   source.loop = true;
  #|   source.connect(ctx.destination);
  #|   const start = ctx.currentTime;
  #|   source.start(start);
  #|   return [start, buffer.duration];
  #| }

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
extern "js" fn js_log_audio_error(message : String) -> Unit =
  #| (message) => console.error("AI Passport WebAudio error:", message)
