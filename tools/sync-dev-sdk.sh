#!/bin/sh
# Dev overlay: copy a local (unreleased) SDK checkout into
# .mooncakes/colmugx/ai-passport/ so this template can use SDK surfaces
# newer than the published release. Generated/ignored state only; rerun
# after changing the SDK checkout (and before every moon invocation if the
# registry re-materializes the published package over it).
#
# The SDK passport CLI is NOT part of the overlay (tools/passport.mbtx runs
# it from the SDK checkout): the published release this tree is stamped as
# declares no module dependencies, and cmd/passport is the only package
# importing moonbitlang/async, so keeping it would break dependency
# resolution.
#
#   tools/sync-dev-sdk.sh [sdk_dir]
#
# Default sdk_dir: the sibling checkout ../ai-passport.mbt; $AI_PASSPORT_SDK
# overrides it, an explicit argument overrides both.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_DIR="${1:-${AI_PASSPORT_SDK:-$ROOT/../ai-passport.mbt}}"

if [ ! -f "$SDK_DIR/moon.mod" ] || [ ! -d "$SDK_DIR/hosts" ]; then
    echo "sync-dev-sdk: not an ai-passport SDK checkout: $SDK_DIR" >&2
    exit 1
fi

DEST="$ROOT/.mooncakes/colmugx/ai-passport"
mkdir -p "$DEST"
# --delete keeps removals propagating: the overlay must mirror the SDK
# checkout, not accumulate stale files from older syncs. --delete-excluded
# applies that to the excludes too (a stale src/cmd from an older sync must
# not survive an exclude added later).
rsync -a --delete --delete-excluded \
    --exclude='.git' \
    --exclude='_build' \
    --exclude='.mooncakes' \
    --exclude='.agents' \
    --exclude='.github' \
    --exclude='.githooks' \
    --exclude='/src/cmd' \
    --exclude='/external' \
    "$SDK_DIR/" "$DEST/"

# Moon resolves dependencies against the published registry index, so an
# unpublished SDK moon.mod version would fail resolution outright. Stamp the
# overlay's module version to the release pinned in moon.mod: the declared
# dependency stays resolvable while the overlay carries the unreleased
# content.
PIN="$(sed -n 's/.*"colmugx\/ai-passport@\([0-9.]*\)".*/\1/p' "$ROOT/moon.mod" | head -n 1)"
if [ -z "$PIN" ]; then
    echo "sync-dev-sdk: moon.mod does not declare colmugx/ai-passport@<version>" >&2
    exit 1
fi
sed -i.bak "s/^version = \".*\"/version = \"$PIN\"/" "$DEST/moon.mod"
rm -f "$DEST/moon.mod.bak"

echo "sync-dev-sdk: overlay refreshed from $SDK_DIR (stamped as @$PIN)"
