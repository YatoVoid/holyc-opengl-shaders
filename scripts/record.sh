#!/usr/bin/env bash
# Renders each scene offline to PPM frames, then encodes docs/media/<scene>.mp4
# and a looping docs/media/<scene>.gif. Usage: scripts/record.sh [scene...]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SECONDS_LONG="${SECONDS_LONG:-6}"
FPS=30
W=1280
H=720
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(raymarch fractal particles plasma)

mkdir -p build docs/media
[ -x build/lumen ] || hcc src/main.HC -o build/lumen

for scene in "${SCENES[@]}"; do
  tmp="$(mktemp -d "$ROOT/build/frames.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  echo "rendering $scene"
  ./build/lumen --render "$scene" "$tmp" $((SECONDS_LONG * FPS)) "$FPS" "$W" "$H"

  ffmpeg -loglevel error -y -framerate "$FPS" -i "$tmp/f%05d.ppm" \
    -c:v libx264 -pix_fmt yuv420p -crf 30 -movflags +faststart \
    "docs/media/$scene.mp4"

  ffmpeg -loglevel error -y -framerate "$FPS" -i "$tmp/f%05d.ppm" \
    -vf "fps=12,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=bayer:bayer_scale=5" \
    -loop 0 "docs/media/$scene.gif"

  rm -rf "$tmp"
  trap - EXIT
done
