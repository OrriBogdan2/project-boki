extends RefCounted
## --sfx-set-check: the wall kick, ledge grab and mantle sounds (ClimbSfx, content/sfx/climb.json, docs/AUDIO.md).
## Each move has its own sound per weight class on file; a Hunter plays the one for its class, a little louder the
## heavier it is; it carries the footstep range (a rival 15 m off hears it, one 30 m off does not); and the
## movement code plays each from where it fires the move.

const MOVES := [ClimbSfx.KICK, ClimbSfx.GRAB, ClimbSfx.MANTLE]
const WEIGHT_ARCH := {"light": "archer", "medium": "dolm", "heavy": "ashwick"}
# the file that plays each move, and the call it makes
const WIRED := {
	"scripts/match/wall_moves.gd": ["ClimbSfx.play(h, ClimbSfx.KICK)", 2],
	"scripts/match/hunter.gd": ["ClimbSfx.play(self, ClimbSfx.GRAB)", 2],
}
const FAR_M := 30.0  # m: a Hunter this far off is past the footstep range

var ok: Callable


func run(main: Node, check_ok: Callable) -> void:
	ok = check_ok
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var h: Hunter = m.player
	var arch0 := h.arch
	Sfx.listener = h.pos
	for move in MOVES:
		var vols := []
		for cls in WEIGHT_ARCH:
			h.arch = WEIGHT_ARCH[cls]
			var want := "%s_%s" % [move, cls]
			Sfx.last_played.clear()
			Sfx.recent.clear()
			ClimbSfx.play(h, move)
			var named: bool = ClimbSfx.cue(h, move) == want and Sfx.take_count(want) == 4
			ok.call(named, "climb: %s plays %s (4 takes)" % [cls, want])
			ok.call(Sfx.last_played.has(want), "climb: %s %s sounds when played" % [cls, move])
			var reach: float = Sfx.sound_reach.get(want, 0.0)
			ok.call(reach == StepReach.RIVAL_M, "climb: %s carries the footstep range (%.0f m)" % [want, reach])
			vols.append(float(ClimbSfx.DB[move]) + float(StepSurface.WEIGHT_DB[cls]))
		ok.call(
			vols[0] < vols[1] and vols[1] < vols[2], "climb: %s is louder the heavier the Hunter (%s)" % [move, vols]
		)
	h.arch = arch0
	var near := Vector3(h.pos.x + 15.0, h.pos.y, h.pos.z)
	var far := Vector3(h.pos.x + FAR_M, h.pos.y, h.pos.z)
	var reach_m := StepReach.reach(h)
	ok.call(not is_nan(Sfx._distance_db(near, reach_m)), "climb: a rival's move 15 m off is heard")
	ok.call(is_nan(Sfx._distance_db(far, reach_m)), "climb: a rival's move %.0f m off is not" % FAR_M)
	for f in WIRED:
		var src := FileAccess.get_file_as_string("res://" + f)
		var want: Array = WIRED[f]
		ok.call(src.count(want[0]) == want[1], "climb: %s plays %s x%d" % [f, want[0], want[1]])
	var hunter_src := FileAccess.get_file_as_string("res://scripts/match/hunter.gd")
	var mantle := "ClimbSfx.play(self, ClimbSfx.MANTLE)"
	ok.call(hunter_src.count(mantle) == 1, "climb: the mantle sounds as you pull over the lip")
	m.queue_free()
