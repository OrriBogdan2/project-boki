#!/bin/bash
# Pip, ART-1: sculpt + paint, the clips, into the game. tools/art1/pip_build.sh WORKDIR [clips|all]
set -e
W=$1; R=$(cd "$(dirname "$0")/../.." && pwd); B=${BLENDER:-$HOME/tools/blender-4.5.15-linux-x64/blender}
[ "$2" = clips ] || "$B" -b --factory-startup --python "$R/tools/art1/pip_art1.py" -- "$W" 2>&1 | grep -E "Traceback|Error|rror:|UNPAINTED|NO WEIGHTS|^saved|^TRIS" | cut -c1-240
"$B" -b --python "$R/tools/art1/pip_clips.py" -- "$W/pip_art1.blend" "$W/pip.glb" 2>&1 | grep -E "Traceback|Error|rror:|^clips|^exported" | cut -c1-160
cp "$W/pip.glb" "$R/art/wardens/pip/pip.glb"
godot --headless --path "$R" --import > "$W/import.log" 2>&1 || true
