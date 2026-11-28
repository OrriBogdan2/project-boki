extends RefCounted
## --ship-sound-check: what the ear gets over the first 30 s of a match (the intro, the plan, the sail).
##  1. Every audio player start is logged with its stream and sim time (SHIP_SOUND row ...), and no stream may start
##     again sooner than GAP unless it is a held loop or a bed (those are meant to run on).
##  2. The main bed (`amb_match`, heard from the first frame) is a long loop: under BED_MIN_S its repeat is heard as a
##     tick-tock (the old 13 s bed swelled every 3 s and jumped in level where it wrapped).
## With `--live-secs=N` it only plays the match start in real time for N s and quits, for a movie with sound:
## godot --write-movie ship.avi --fixed-fps 60 --rendering-driver vulkan -- --ship-sound-check --live-secs=20

const SECS := 30.0  # length of the match start that is logged
const GAP := 4.0  # s: a one-shot stream may not start again sooner than this
const BED_MIN_S := 30.0  # s: the shortest main bed that does not read as a repeat

var bad := 0
var main: Node
var seen := {}  # player -> [playing, stream name]
var starts := {}  # stream name -> [sim times]


func ok(cond: bool, what: String) -> void:
	print("SHIP_SOUND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _name(p: Node) -> String:
	var st: AudioStream = p.stream
	if st == null:
		return "?"
	var n := st.resource_path.get_file()
	return n if n != "" else "gen:%s" % st.get_class()


## Logs each player that began a stream since the last frame (not a loop wrapping round: that follows the audio
## clock, not the sim's).
func _scan(node: Node, t: float) -> void:
	for c in node.get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer3D:
			var nm := _name(c)
			var prev: Array = seen.get(c, [false, ""])
			if c.playing and (not prev[0] or nm != prev[1]):
				starts[nm] = starts.get(nm, []) + [t]
			seen[c] = [c.playing, nm]
		_scan(c, t)


func _runs_on(nm: String) -> bool:
	for k in Sfx.loops:
		if _name(Sfx.loops[k]["p"]) == nm:
			return true
	return _name(Sfx.amb) == nm or nm.begins_with("amb_") or nm.begins_with("music_")


func run(mn: Node, _arg = null) -> void:
	main = mn
	Save.no_write = true
	SquadIntro._last_lineup = ""
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "squad_intro": true}
	o["cls"] = Arch.weight("gunslinger")
	o["arch"] = "gunslinger"
	m.start(o)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--live-secs="):
			for i in int(float(String(a).substr(12)) * 60.0):
				await main.get_tree().process_frame
			main.get_tree().quit()
			return
	m.set_process(false)
	for i in int(SECS / Match.DT):
		m.step(Match.DT)
		m.music_dir.tick(m, Match.DT)
		if m.intro:
			m.intro.frame(Match.DT)
		_scan(main.get_tree().root, i * Match.DT)
		if i % 30 == 0:
			await main.get_tree().process_frame
	for nm in starts:
		var ts: Array = starts[nm].map(func(t): return snappedf(t, 0.01))
		var gap := INF
		for j in range(1, ts.size()):
			gap = minf(gap, ts[j] - ts[j - 1])
		print("SHIP_SOUND row %s x%d at %s" % [nm, ts.size(), ts.slice(0, 12)])
		ok(_runs_on(nm) or gap >= GAP, "%s starts %d times, shortest gap %.2f s" % [nm, ts.size(), gap])
	var bed := Sfx.amb.stream.get_length()
	ok(bed >= BED_MIN_S, "the main bed %s is %.0f s long (at least %.0f)" % [_name(Sfx.amb), bed, BED_MIN_S])
	print("SHIP_SOUND_CHECK_DONE, failures: ", bad)
	m.queue_free()
	main.get_tree().quit(1 if bad > 0 else 0)
