// Minimal browser surface for the preview runtime, via the MoonBit JS FFI.
// Opaque handle types below only exist on the JS backend; MoonBit never
// touches browser object internals beyond these declarations.

///|
type DomContext2D

///|
type DomImageData

///|
type DomEvent

///|
/// Current monotonic browser time in milliseconds (`performance.now()`).
extern "js" fn js_now() -> Double =
  #| () => performance.now()

///|
/// Finds the preview canvas by `id` (creating and appending one when
/// missing), sizes its backing store to the logical resolution, and returns
/// its 2D context with image smoothing disabled.
extern "js" fn js_setup_canvas(
  id : String,
  width : Int,
  height : Int,
) -> DomContext2D =
  #| (id, width, height) => {
  #|   let el = document.getElementById(id);
  #|   if (!(el instanceof HTMLCanvasElement)) {
  #|     el = document.createElement("canvas");
  #|     el.id = id;
  #|     document.body.appendChild(el);
  #|   }
  #|   el.width = width;
  #|   el.height = height;
  #|   const ctx = el.getContext("2d");
  #|   ctx.imageSmoothingEnabled = false;
  #|   return ctx;
  #| }

///|
/// Creates the persistent ImageData object that converted frames are written
/// into, so presenting a frame allocates nothing per pixel.
extern "js" fn js_create_image_data(
  ctx : DomContext2D,
  width : Int,
  height : Int,
) -> DomImageData =
  #| (ctx, width, height) => ctx.createImageData(width, height)

///|
/// Presents one RGBA frame: bulk-copies the buffer into the persistent
/// ImageData and blits it 1:1 onto the logical-size canvas. The 4x display
/// scale is CSS (`image-rendering: pixelated`), not canvas rasterization.
extern "js" fn js_present(
  ctx : DomContext2D,
  image : DomImageData,
  rgba : FixedArray[Byte],
) -> Unit =
  #| (ctx, image, rgba) => {
  #|   image.data.set(rgba);
  #|   ctx.putImageData(image, 0, 0);
  #| }

///|
/// Runs `tick` with the monotonic frame timestamp once per animation frame,
/// forever.
extern "js" fn js_start_frame_loop(tick : (Double) -> Unit) -> Unit =
  #| (tick) => {
  #|   const loop = (ts) => {
  #|     tick(ts);
  #|     requestAnimationFrame(loop);
  #|   };
  #|   requestAnimationFrame(loop);
  #| }

///|
extern "js" fn js_listen_keydown(handler : (DomEvent) -> Unit) -> Unit =
  #| (handler) => document.addEventListener("keydown", handler)

///|
extern "js" fn js_listen_keyup(handler : (DomEvent) -> Unit) -> Unit =
  #| (handler) => document.addEventListener("keyup", handler)

///|
extern "js" fn js_listen_blur(handler : () -> Unit) -> Unit =
  #| (handler) => window.addEventListener("blur", handler)

///|
extern "js" fn js_event_code(event : DomEvent) -> String =
  #| (event) => event.code

///|
extern "js" fn js_prevent_default(event : DomEvent) -> Unit =
  #| (event) => event.preventDefault()
