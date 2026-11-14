#!/bin/bash
# tools/muzzle_sheet.sh <framesdir> <out.mp4>: the 13 --muzzle-shots clips as one 4x4 sheet (ffmpeg).
D=$1; OUT=$2
ARCHS="archer ashwick bulwark dolm dredge gil gunslinger juggernaut mage ostra rimewright tender thief"
IN=""; FC=""; L=""; i=0
for a in $ARCHS; do
  IN="$IN -framerate 20 -i $D/${a}_%03d.jpg"
  FC="$FC[$i:v]scale=480:330:force_original_aspect_ratio=decrease,pad=480:330:(ow-iw)/2:(oh-ih)/2[v$i];"
  L="$L[v$i]"; i=$((i+1))
done
FC="$FC${L}xstack=inputs=13:layout=0_0|480_0|960_0|1440_0|0_330|480_330|960_330|1440_330|0_660|480_660|960_660|1440_660|0_990:fill=black[o]"
ffmpeg -y -loglevel error $IN -filter_complex "$FC" -map "[o]" -c:v libx264 -pix_fmt yuv420p -crf 30 -preset veryfast $OUT
