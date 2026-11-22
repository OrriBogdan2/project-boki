#!/bin/bash
# Packs one Hunter's art/wardens/<art>/<art>_meshy.glb from a rigged master, its Meshy clip files and decimate.py's
# output:  pack.sh ART RIG.glb DECIMATED.glb [ANIM.glb WALK.glb RUN.glb]
# (no clip files: RIG.glb already carries its six clips). Needs numpy and PIL (python3 with both).
set -eu
art=$1 rig=$2 dec=$3
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
py=${PYTHON:-python3}
$py "$here/graft.py" "$tmp/base.glb" "$rig" "$dec"
clips=()
[ $# -ge 6 ] && clips=("$4" "$5=walk" "$6=run")
mkdir -p "art/wardens/$art"
$py "$here/../native_pack.py" "art/wardens/$art/${art}_meshy.glb" "$tmp/base.glb" "${clips[@]}" \
	--in-place=Crouch_Walk_with_Torch --max-tex=2048 --max-tex-maps=1024
rm -rf "$tmp"
