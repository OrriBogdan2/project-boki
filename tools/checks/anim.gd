extends RefCounted
## New checks for the "anim" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	# no clip stretches a skinned edge past 1.3x
	"--stretch-1-check": ["res://tools/stretch_check.gd", "stretch_check", "bulwark,gunslinger"],
	"--stretch-2-check": ["res://tools/stretch_check.gd", "stretch_check", "rimewright,dredge"],
	"--stretch-3-check": ["res://tools/stretch_check.gd", "stretch_check", "thief,ashwick"],
	"--stretch-4-check": ["res://tools/stretch_check.gd", "stretch_check", "juggernaut,tender"],
	"--stretch-5-check": ["res://tools/stretch_check.gd", "stretch_check", "archer,mage"],
	"--stretch-6-check": ["res://tools/stretch_check.gd", "stretch_check", "dolm,ostra"],
	"--stretch-7-check": ["res://tools/stretch_check.gd", "stretch_check", "gil"],
	# GPU: posed hunter clip frames, --geo-dir= --shots-dir=
	"--geo-shots": ["res://tools/geo_shots.gd", "geo_shots", null],
	"--native-upper-shots": ["res://tools/native_upper_shots.gd", "native_upper_shots", null],  # a swing on the run, frames
	"--warden-native-check": ["res://tools/warden_native_check.gd", "warden_native_check", null],  # Meshy skeleton
	"--live-audit": ["res://tools/live_audit.gd", "live_audit", null],  # Hunters as played, GPU renders
	# Meeko's sun and cloud: clear of the posed body in every state; GPU shots (--shots-dir=<dir> [--eye=<m>])
	"--meeko-companions-clip-check":
	["res://tools/meeko_companions_clip_check.gd", "meeko_companions_clip_check", null],
	"--meeko-companions-shots": ["res://tools/meeko_companions_shots.gd", "meeko_companions_shots", null],
}
