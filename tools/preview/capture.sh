#!/bin/sh
# Regenerates docs/images/* (README previews) with headless Chrome + ffmpeg.
# Layout positions come from the real addon via export_layout.lua.
set -e
cd "$(dirname "$0")/../.."
CHROME=${CHROME:-google-chrome-stable}
OUT=docs/images
mkdir -p "$OUT"
lua5.1 tools/preview/export_layout.lua > tools/preview/layout.js
PAGE="file://$(pwd)/tools/preview/preview.html"

shot() { # scene width height file [t]
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --window-size="$2,$3" --virtual-time-budget=500 \
    --screenshot="$4" "$PAGE?scene=$1&t=${5:-0}" >/dev/null 2>&1
}

shot hud-cover 1792 768 "$OUT/hud-folded.png"
shot hud-left 1792 768 "$OUT/hud-folded-left.png"
shot hud-main 852 768 "$OUT/hud-unfolded.png"
shot menu 1792 768 "$OUT/menu.png"
shot picker 1792 768 "$OUT/spell-picker.png"
shot edit 1792 768 "$OUT/edit-layout.png"
shot setup 1792 768 "$OUT/setup-movement.png"

# Animated demo: 12 fps for 6 seconds.
FRAMES=$(mktemp -d)
i=0
while [ $i -lt 72 ]; do
  t=$(awk "BEGIN { printf \"%.3f\", $i / 12 }")
  shot demo 1792 768 "$FRAMES/f$(printf %03d $i).png" "$t"
  i=$((i + 1))
done
ffmpeg -loglevel error -y -framerate 12 -i "$FRAMES/f%03d.png" \
  -vf "scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
  "$OUT/demo.gif"
rm -rf "$FRAMES"
ls -la "$OUT"
