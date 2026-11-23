extends RefCounted
## --extract-board-check: a Hunter that extracts plays a short leave beat before the model hides (the source shows
## one; ours used to vanish). For all 12 Hunters through the real match code: the crouch dip then the jump's
## take-off play from the Hero's own clips, the model stays on screen for the whole beat (0.6 to 0.8 s), hides
## right after it, and a remote copy that only gets the "ext" event shows the same beat.
## With --shots-dir=<dir> (needs a renderer) it also saves frames of the beat for three Hunters.
## Never touches the save.

const DT := 1.0 / 60.0
const SHOT_ARCHS := ["juggernaut", "mage", "thief"]
const SHOT_EVERY := 7          # frames between shots (about 0.12 s)
const ARCHS := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger",
		"juggernaut", "mage", "ostra", "rimewright", "tender", "thief"]

var A
var bad := 0
var shots := ""

func ok(cond: bool, what: String) -> void:
	print("EXTRACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	if shots != "":
		m.cam.snap(h.pos)
	h.render(DT, 1.0)
	var sync: Node = WardenGlb.layers(h.model)      # (Sync, or Native on Meshy's own skeleton: WardenNative)
	sync.set_process(false)
	if h.visible:
		sync.call("_process", DT)

## Extract h now and step until its model hides: [seconds it stayed visible, clips seen].
func _beat(m: Match, h: Hunter, tag := "") -> Array:
	var t0 := m.time
	var seen := {}
	var shown := 0.0
	if h == m.player:
		m._extract(h, "hatch", "check")
	else:
		h.extracted = true      # (all a remote copy gets: the "ext" event and the snapshot flag)
	for f in 90:
		_frame(m, h)
		if tag != "" and f % SHOT_EVERY == 0:
			await RenderingServer.frame_post_draw
			h.m.get_tree().root.get_texture().get_image().save_png("%s/%s_%02d.png" % [shots, tag,
					int(f / float(SHOT_EVERY))])
		if not h.visible:
			break
		shown = m.time - t0
		var c := _cur(h)
		if c != "":
			seen[c] = true
	return [shown, seen]

func run(main: Node) -> void:
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots = a.substr(12)
			DirAccess.make_dir_recursive_absolute(shots)
			if main.get("fade") != null:
				main.fade.reveal(0.01)      # (past the title's fade)
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	for arch in ARCHS:
		var r: Array = A.setup(arch, 11.0, "", true)
		var m: Match = r[0]
		var P: Hunter = r[1]
		for f in 10:
			_frame(m, P)
		var sync: Node = WardenGlb.layers(P.model)
		if sync == null or (sync.get("clips") == null and sync.get("plays") == null):
			ok(false, "%s wears hand-keyed clips" % arch)
			continue
		ok(P.visible, "%s is on screen before extracting" % arch)
		var res: Array = await _beat(m, P, arch if shots != "" and arch in SHOT_ARCHS else "")
		var seen: Dictionary = res[1]
		ok(seen.has(_beat_clip(P, "dip")) and seen.has(_beat_clip(P, "rise")),
				"%s plays its dip and take-off (%s)" % [arch, seen.keys()])
		ok(res[0] >= 0.6 and res[0] <= 0.8, "%s stays on screen %.2f s, then hides" % [arch, res[0]])
		ok(not P.visible and P.extracted, "%s is hidden after the beat" % arch)
		var T: Hunter = r[2]       # a copy that is only told it extracted
		for f in 10:
			_frame(m, T)
		var rt: Array = await _beat(m, T)
		var rise := _beat_clip(T, "rise")
		ok(rt[0] >= 0.6 and rt[0] <= 0.8 and (rt[1] as Dictionary).has(rise),
				"%s: a copy told by the extract event shows the same beat (%.2f s)" % [arch, rt[0]])
		m.queue_free()
	print("EXTRACT_BOARD_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The clip playing: the hand-keyed clip's name, or on Meshy's own skeleton (WardenNative) the game state it plays.
func _cur(h: Hunter) -> String:
	var sync: Node = WardenGlb.layers(h.model)
	var clips: WardenClips = sync.get("clips")
	return clips.cur if clips else String(sync.get("cur"))

## The beat's dip ("dip") or take-off ("rise"): the Hero's crouch-in and air-rise clips, or Meshy's crouch and jump.
func _beat_clip(h: Hunter, part: String) -> String:
	var clips: WardenClips = WardenGlb.layers(h.model).get("clips")
	if clips == null:
		return "crouch" if part == "dip" else "jump"
	return String(clips.d["crouch"]["in"]) if part == "dip" else String(clips.d["air"]["rise"])
