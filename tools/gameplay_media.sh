#!/bin/bash
# Encodes one gameplay clip: tools/gameplay_media.sh <capture.avi> <still.png> <start_s> <len_s> <out_prefix> [xfade_s]
# Cuts <len_s> seconds from <start_s>, makes it loop seamlessly (the last <xfade_s> seconds, default 0.6, dissolve into
# the first ones, so the last frame leads straight into the first), and writes <out_prefix>.mp4 (H.264 yuv420p,
# +faststart, lowest CRF that fits 4 MB), .webm (VP9) and .webp (the still). Capture: see tools/gameplay_media.gd.
set -euo pipefail
src=$1; still=$2; s=$3; len=$4; out=$5; x=${6:-0.6}
max=$((4 * 1000 * 1000))
total=$(awk -v l="$len" -v x="$x" 'BEGIN{print l + x}')
vf="[0:v]trim=start=${s}:duration=${total},setpts=PTS-STARTPTS,fps=30,scale=1920:1080:flags=lanczos:in_range=full:out_range=limited,format=yuv420p,split=3[a][b][c];"
vf+="[a]trim=start=${len}:duration=${x},setpts=PTS-STARTPTS[tail];[b]trim=duration=${x},setpts=PTS-STARTPTS[head];"
vf+="[tail][head]blend=all_expr='A*(1-T/${x})+B*(T/${x})'[mix];"
vf+="[c]trim=start=${x}:duration=$(awk -v l="$len" -v x="$x" 'BEGIN{print l - x}'),setpts=PTS-STARTPTS[mid];"
vf+="[mix][mid]concat=n=2:v=1:a=0,format=yuv420p[v]"
for crf in 18 20 22 24 26 28 30 33 36; do
  ffmpeg -v error -y -i "$src" -filter_complex "$vf" -map "[v]" -an -r 30 -c:v libx264 -preset slow -crf "$crf" \
    -pix_fmt yuv420p -movflags +faststart "$out.mp4"
  [ "$(stat -c %s "$out.mp4")" -lt "$max" ] && break
done
ffmpeg -v error -y -i "$src" -filter_complex "$vf" -map "[v]" -an -r 30 -c:v libvpx-vp9 -b:v 0 -crf 34 -row-mt 1 "$out.webm"
ffmpeg -v error -y -i "$still" -vf scale=1920:1080:flags=lanczos -c:v libwebp -quality 88 "$out.webp"
echo "$out crf=$crf mp4=$(stat -c %s "$out.mp4") webm=$(stat -c %s "$out.webm") webp=$(stat -c %s "$out.webp")"
