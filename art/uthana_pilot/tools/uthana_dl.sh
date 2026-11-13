#!/bin/bash
# usage: dl.sh <char> <motion> <out_prefix> : motion-only glb + glb with mesh at 30 fps
set -a; . ~/.config/boki/secrets.env; set +a
curl -s -L -u "$UTHANA_API_KEY:" -o "$3_anim.glb" -w "%{http_code} %{size_download}\n" "https://uthana.com/motion/animation/motion_viewer/$1/$2/glb/motion.glb?fps=30"
curl -s -L -u "$UTHANA_API_KEY:" -o "$3_mesh.glb" -w "%{http_code} %{size_download}\n" "https://uthana.com/motion/file/motion_viewer/$1/$2/glb/motion.glb?fps=30"
