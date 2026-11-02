class_name LDSfx
extends RefCounted
## Linwick's and Dredge's per-ability sounds (made by tools/sfx_linwick_dredge.py). The kits register
## them into the Sfx autoload's stream table on setup, so sfx.gd's shared name list stays untouched.

const NAMES := [
	"lw_pilot", "lw_roar", "lw_bolt", "lw_bolt_hit", "lw_bash", "lw_bash_hit", "lw_shield", "lw_blaze", "lw_trail", "lw_hop",
	"dr_shot", "dr_throw", "dr_grab", "dr_reel", "dr_barge", "dr_anchor_wind", "dr_dive", "dr_quake", "dr_hop",
]

static var _done := false

static func ensure() -> void:
	if _done:
		return
	_done = true
	for n in NAMES:
		var path := "res://audio/%s.wav" % n
		if not Sfx.streams.has(n) and ResourceLoader.exists(path):
			Sfx.streams[n] = load(path)
