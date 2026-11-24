extends RefCounted
## New checks for the "anim" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	# the weapon tip on the hit area
	"--strike-reach-check": ["res://tools/strike_reach_check.gd", "strike_reach_check", null],
	# Kael tap strike, live aim, tether, ult momentum
	"--kael-tap-check": ["res://tools/kael_tap_check.gd", "kael_tap_check", null],
	"--kael-tap-clip": ["res://tools/kael_tap_clip.gd", "kael_tap_clip", null],  # Kael tap/hold/ult clips (GPU)
	"--pond-shots": ["res://tools/pond_shots.gd", "pond_shots", null],  # every Hunter on the pond walk (wade, swim)
	# every Hunter's win, lose and board beat
	"--result-pose-shots": ["res://tools/result_pose_shots.gd", "result_pose_shots", null],
	"--action-shots": ["res://tools/action_shots.gd", "action_shots", null],  # stomp, revive, drink strips
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
	"--warden-native-check": ["res://tools/warden_native_check.gd", "warden_native_check", null],  # Meshy skeleton
	"--live-audit": ["res://tools/live_audit.gd", "live_audit", null],  # Hunters as played, GPU renders
}
