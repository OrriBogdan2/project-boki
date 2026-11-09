#!/bin/sh
# Albert's lmb_throw and lmb_slam, re-timed after the Blender export (docs/art/ANIM_QUALITY_AUDIT.md, Mossy item 3):
# the hand now travels at an even speed, so the biggest hand step in the audit falls from 0.51 to 0.42 (throw) and from
# 0.64 to 0.45 (slam) body heights. The throw's release stays at 0.12 s; the slam's impact lands at 0.10 s, not 0.08.
# new:old time anchors; run once on a fresh breaker.glb (it does not undo itself).
G=art/wardens/breaker/breaker.glb
python3 tools/art1/glb_retime.py $G lmb_throw 0.000:0.000,0.017:0.015,0.034:0.033,0.051:0.051,0.069:0.065,0.086:0.090,0.103:0.108,0.120:0.120,0.136:0.129,0.152:0.141,0.168:0.155,0.184:0.169,0.200:0.200
python3 tools/art1/glb_retime.py $G lmb_slam 0.000:0.000,0.017:0.009,0.033:0.019,0.050:0.031,0.067:0.042,0.083:0.054,0.100:0.083
