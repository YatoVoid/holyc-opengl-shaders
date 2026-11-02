#!/usr/bin/env bash
# Renders scenes offline to PPM frames and encodes them with ffmpeg.
#
#   scripts/record.sh [scene...]            docs/media/<scene>.mp4 and .gif, bloom on
#   scripts/record.sh --compare [scene...]  docs/media/<scene>-compare.mp4 and .gif,
#                                           a divider sweeping between bloom off (left)
#                                           and bloom on (right)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SECS="${SECS:-6}"
FPS=30
W=1280
H=720
FONT="$(fc-match -f '%{file}' 'DejaVu Sans:bold')"
COMPARE=0
if [ "${1:-}" = "--compare" ]; then
  COMPARE=1
  shift
fi
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(raymarch fractal particles plasma)

mkdir -p build docs/media
hcc src/main.HC -o build/lumen

GIF_FILTER="fps=12,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=bayer:bayer_scale=5"

render() {
  local scene="$1" bloom="$2" dir="$3"
  mkdir -p "$dir"
  ./build/lumen --render "$scene" "$dir" $((SECS * FPS)) "$FPS" "$W" "$H" "$bloom"
}

for scene in "${SCENES[@]}"; do
  work="$(mktemp -d "$ROOT/build/frames.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
  echo "rendering $scene"

  if [ "$COMPARE" = 1 ]; then
    render "$scene" 0 "$work/off"
    render "$scene" 1 "$work/on"
    divider="W*(0.5+0.4*sin(2*PI*T/$SECS))"
    bar="W*(0.5+0.4*sin(2*PI*t/$SECS))-2"
    graph="color=c=white:s=4x${H}:r=${FPS}[bar];\
[0:v][1:v]blend=all_expr='if(gte(X,$divider),B,A)'[mix];\
[mix][bar]overlay=x='$bar':y=0:shortest=1,\
drawtext=fontfile=$FONT:text='bloom off':x=24:y=24:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=10,\
drawtext=fontfile=$FONT:text='bloom on':x=w-tw-24:y=24:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=10[v]"
    ffmpeg -loglevel error -y -framerate "$FPS" -i "$work/off/f%05d.ppm" \
      -framerate "$FPS" -i "$work/on/f%05d.ppm" -filter_complex "$graph" -map '[v]' \
      -c:v libx264 -pix_fmt yuv420p -crf 28 -movflags +faststart "docs/media/$scene-compare.mp4"
    ffmpeg -loglevel error -y -i "docs/media/$scene-compare.mp4" \
      -vf "$GIF_FILTER" -loop 0 "docs/media/$scene-compare.gif"
  else
    render "$scene" 1 "$work/on"
    ffmpeg -loglevel error -y -framerate "$FPS" -i "$work/on/f%05d.ppm" \
      -c:v libx264 -pix_fmt yuv420p -crf 30 -movflags +faststart "docs/media/$scene.mp4"
    ffmpeg -loglevel error -y -framerate "$FPS" -i "$work/on/f%05d.ppm" \
      -vf "$GIF_FILTER" -loop 0 "docs/media/$scene.gif"
  fi

  rm -rf "$work"
  trap - EXIT
done
