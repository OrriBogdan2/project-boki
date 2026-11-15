extends RefCounted
## --wild-type-cue-check: every wild Boki wears its type's ground cue (WildTypeCue).
##   1. all 18 types have a colour, and the colours are apart from each other and from the side colours
##   2. every species spawned wild shows the cue at full strength in its type colour, as a filled disc
##   3. a Boki with a Hunter keeps the hollow side ring, with no cue
##   4. the cue fades out as the capture scan fills, and when the Boki is no longer wild
## Never touches the save.

const SIDE := [SideColor.YOU, SideColor.ALLY, SideColor.FOE]
const MIN_APART := 0.1          # RGB distance between two type colours
const MIN_FROM_SIDE := 0.2      # RGB distance from a type colour to a side colour

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("WILDCUE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _frames(k: Kin, n: int) -> void:
	for i in n:
		k.render(1.0 / 30.0, 1.0)

func _colours() -> void:
	var types: Array = WildTypeCue.COLORS.keys()
	ok(types.size() == 18, "18 type colours (%d)" % types.size())
	var close := 0
	for i in types.size():
		for j in range(i + 1, types.size()):
			if _dist(WildTypeCue.COLORS[types[i]], WildTypeCue.COLORS[types[j]]) < MIN_APART:
				close += 1
				print("  too close: %s / %s" % [types[i], types[j]])
	ok(close == 0, "no two type colours within %.2f of each other" % MIN_APART)
	var near := 0
	for t in types:
		for s in SIDE:
			if _dist(WildTypeCue.COLORS[t], s) < MIN_FROM_SIDE:
				near += 1
				print("  near a side colour: %s" % t)
	ok(near == 0, "no type colour within %.2f of a Hunter side colour" % MIN_FROM_SIDE)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_colours()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "demo_kin": "cindle"})
	m.set_process(false)
	var P: Hunter = m.player
	var seen := {}
	var wrong := []
	for sid in Data.KIN:
		var k := m.spawn_wild(Save.new_kin(sid, "Wild"), P.pos + Vector3(30, 0, 0))
		_frames(k, 20)
		var want: Color = WildTypeCue.COLORS[WildTypeCue.type_of(k.sp)]
		var mat := k.ring.material_override as ShaderMaterial
		var got: Color = mat.get_shader_parameter("color")
		var filled := float(mat.get_shader_parameter("fill")) > 0.0
		var good := k.ring.visible and WildTypeCue.strength(k.ring) == 1.0 and filled
		if not good or _dist(Color(got, 1.0), want) > 0.01 or got.a < WildTypeCue.ALPHA - 0.01:
			wrong.append(sid)
		seen[WildTypeCue.type_of(k.sp)] = true
		k.queue_free()
		m.kins.erase(k)
	var msg := "all %d species spawn wild with the cue in their type colour %s"
	ok(wrong.is_empty(), msg % [Data.KIN.size(), wrong])
	ok(seen.size() >= 12, "the species cover %d types" % seen.size())
	var own: Kin = P.kin
	var own_mat := own.ring.material_override as ShaderMaterial
	var hollow := WildTypeCue.strength(own.ring) == 0.0 and own_mat.get_shader_parameter("fill") == null
	ok(hollow, "a Boki with a Hunter keeps the hollow side ring")
	var w := m.spawn_wild(Save.new_kin("cindle", "Wild"), P.pos + Vector3(30, 0, 0))
	_frames(w, 20)
	w._daze()
	_frames(w, 20)
	ok(w.state == "dazed" and w.ring.visible, "a dazed Boki keeps the cue (it can be scanned)")
	w.scan_by = P
	P.set_meta("cap", {"phase": "scan", "k": w, "t": float(Capture.rules()["scan_s"]) * 0.5})
	_frames(w, 40)
	var half := WildTypeCue.strength(w.ring)
	ok(absf(half - 0.5) < 0.02, "half way through the scan the cue is half strength (%.2f)" % half)
	P.set_meta("cap", {"phase": "scan", "k": w, "t": float(Capture.rules()["scan_s"])})
	_frames(w, 40)
	ok(WildTypeCue.strength(w.ring) == 0.0 and not w.ring.visible, "scan done: the cue is gone")
	P.remove_meta("cap")
	w.scan_by = null
	_frames(w, 40)
	ok(WildTypeCue.strength(w.ring) == 1.0, "the scan let go: it comes back")
	w.state = "active"
	_frames(w, 40)
	ok(WildTypeCue.strength(w.ring) == 0.0, "no longer wild: the cue fades out")
	print("WILDCUE DONE, failures: ", bad)
	main.get_tree().quit()
