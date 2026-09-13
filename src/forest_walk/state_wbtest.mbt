// Whitebox tests: these compile inside the forest_walk package and verify
// the showcase song's structure through the package-private authoring path.
// The SDK Song snapshot deliberately exposes no track arrays, so the
// per-track checks run on the authoring tracks that showcase_song() feeds
// to Song::new (which deep-copies them into the snapshot).

///|
test "showcase song uses the four documented roles, each with a rest" {
  let tracks = showcase_tracks()
  debug_inspect(tracks[0].instrument.waveform, content="Pulse12")
  debug_inspect(tracks[1].instrument.waveform, content="Pulse25")
  debug_inspect(tracks[2].instrument.waveform, content="Pulse50")
  debug_inspect(tracks[3].instrument.waveform, content="Triangle")
  for track in tracks {
    assert_true(track.notes.length() >= 1)
    let mut has_rest = false
    for n in track.notes {
      if n.pitch is None {
        has_rest = true
      }
    }
    assert_true(has_rest)
  }
  // The snapshot built from exactly these tracks carries all four of them.
  inspect(showcase_song().track_count(), content="4")
}
