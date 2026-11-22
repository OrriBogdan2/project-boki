#!/bin/bash
# Packs one Hunter's art/wardens/<art>/<art>_meshy.glb from a rigged master, its Meshy clip files and decimate.py's
# output:  pack.sh ART RIG.glb DECIMATED.glb [ANIM.glb WALK.glb RUN.glb]
# (no clip files: RIG.glb already carries its six clips). Needs numpy and PIL (python3 with both).
set -eu
art=$1 rig=$2 dec=$3
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
py=${PYTHON:-python3}
# (a rig in centimetres under a scaled Armature node is put in metres first: flatten.py; others pass through)
$py "$here/flatten.py" "$tmp/rig.glb" "$rig"
$py "$here/graft.py" "$tmp/base.glb" "$tmp/rig.glb" "$dec"
clips=()
if [ $# -ge 6 ]; then
	n=0
	for f in "$4" "$5" "$6"; do
		$py "$here/flatten.py" "$tmp/clip$n.glb" "$f"
		n=$((n + 1))
	done
	clips=("$tmp/clip0.glb" "$tmp/clip1.glb=walk" "$tmp/clip2.glb=run")
fi
mkdir -p "art/wardens/$art"
$py "$here/../native_pack.py" "art/wardens/$art/${art}_meshy.glb" "$tmp/base.glb" "${clips[@]}" \
	--in-place=Crouch_Walk_with_Torch --max-tex=2048 --max-tex-maps=1024
rm -rf "$tmp"
