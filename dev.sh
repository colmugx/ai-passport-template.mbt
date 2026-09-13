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
moon build --target js

# 2. Assemble the browser bundle into web/dist (transient build output,
#    never committed).
mkdir -p web/dist
cp _build/js/debug/build/web/web.js web/dist/web.js

# 3. Serve the browser shell; open the printed URL.
echo
echo "Forest Walk preview: http://localhost:${PORT}/"
echo "Controls: ArrowUp/ArrowDown walking speed, Space/Enter pause."
echo "Press Ctrl-C to stop."
exec python3 -m http.server "${PORT}" --bind 127.0.0.1 --directory web
