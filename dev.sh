#!/bin/sh
# Builds the Forest Walk browser preview and serves it on localhost.
#
# Usage: ./dev.sh          (or PORT=9000 ./dev.sh to change the port)
#
# Requires the MoonBit toolchain (https://www.moonbitlang.com) and python3
# for the static file server. No npm dependencies are involved.
set -eu

cd "$(dirname "$0")"

PORT="${PORT:-8000}"

if ! command -v moon >/dev/null 2>&1; then
  echo "error: 'moon' not found; install the MoonBit toolchain first." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: 'python3' not found; it provides the development file server." >&2
  exit 1
fi

# 1. Build the MoonBit JS target (the browser entry package is src/web).
moon build --target js --release

# 2. Assemble the browser bundle into web/dist (transient build output,
#    never committed).
mkdir -p web/dist
cp _build/js/release/build/web/web.js web/dist/web.js
# The authored music file (exactly one of forest_walk.wav/.mp3) is served
# under a fixed extensionless name; the browser decodes it natively.
music_source="$(ls assets/audio/forest_walk.wav assets/audio/forest_walk.mp3 2>/dev/null | head -n 1)"
if [ -z "$music_source" ]; then
  echo "error: no authored music in assets/audio (expected forest_walk.wav or .mp3)." >&2
  exit 1
fi
if [ "$(ls assets/audio/forest_walk.wav assets/audio/forest_walk.mp3 2>/dev/null | wc -l)" -ne 1 ]; then
  echo "error: ambiguous authored music; keep exactly one of forest_walk.wav/.mp3." >&2
  exit 1
fi
cp "$music_source" web/dist/music

# 3. Serve the browser shell; open the printed URL.
echo
echo "Forest Walk preview: http://localhost:${PORT}/"
echo "Ambient fixed-speed scene; keyboard controls are unused. Click Enable sound for music."
echo "Press Ctrl-C to stop."
exec python3 -m http.server "${PORT}" --bind 127.0.0.1 --directory web
