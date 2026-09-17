priv struct Runtime {
  bridge : @hostabi.HostBridge
  app : @app.App
  battery : @battery.Battery
  mut applied_volume : Int
  mut applied_muted : Bool
}

fn pcm_noop(ptr : Int, samples : Int) -> Unit {
  let _ = ptr
  let _ = samples
}

fn Runtime::make() -> Runtime {
  let bridge = @hostabi.HostBridge::new(
    store_u16=@hostabi.store_u16,
    pcm_write=pcm_noop,
    battery_percent=@hostabi.host_battery_percent,
  )
  let source : &@battery.BatterySource = bridge
  let app = @app.App::new()
  {
    bridge,
    app,
    battery: @battery.Battery::new(source~),
    applied_volume: app.volume(),
    applied_muted: app.muted(),
  }
}

let state : Runtime = Runtime::make()

fn main {
  @hostabi.host_set_volume(state.app.volume())
  @hostabi.host_set_muted(if state.app.muted() { 1 } else { 0 })
  state.applied_volume = state.app.volume()
  state.applied_muted = state.app.muted()
}

fn sync_audio_state(rt : Runtime) -> Unit {
  let volume = rt.app.volume()
  if volume != rt.applied_volume {
    @hostabi.host_set_volume(volume)
    rt.applied_volume = volume
  }
  let muted = rt.app.muted()
  if muted != rt.applied_muted {
    @hostabi.host_set_muted(if muted { 1 } else { 0 })
    rt.applied_muted = muted
  }
}
