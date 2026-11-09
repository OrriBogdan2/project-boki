extends RefCounted
## --zone-expiry-check: the shared zone expiry cue (AimKit.zone, docs/AIMKIT.md). The cue's numbers (steady
## before the last AimShapes.EXPIRY_T, then the fill fades out and the rim pulses twice), what AimDraw does
## with a zone's entry and node, and that every lingering kit zone registers with it while it stands.

var main: Node
var fails := 0
var n := 0
var ak = null
const DT := 1.0 / 60.0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("ZONEEXP %-58s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	_cue()
	await _draw()
	await _kits()
	print("ZONEEXP DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## The cue's shape: steady until the window, a fade to nothing, exactly two rim pulses.
func _cue() -> void:
	var t := AimShapes.EXPIRY_T
	ok("cue: the window is 0.5 s", is_equal_approx(t, 0.5))
	ok("cue: steady before the window", AimShapes.fill_k(t + 0.01) == 1.0 and AimShapes.rim_k(t + 0.01) == 1.0
			and AimShapes.look_k(2.0) == 1.0)
	ok("cue: the fill is gone at the end", AimShapes.fill_k(0.0) == 0.0 and AimShapes.look_k(0.0) == 0.0)
	var down := true
	var prev := 1.0
	var peaks := 0
	var up := false
	var last := 1.0
	var steps := 200
	for i in steps + 1:
		var left := t * (1.0 - float(i) / steps)
		var f := AimShapes.fill_k(left)
		down = down and f <= prev + 1e-6
		prev = f
		var r := AimShapes.rim_k(left)
		if r > last + 1e-6 and not up:
			up = true
		elif r < last - 1e-6 and up:
			up = false
			peaks += 1
		last = r
	ok("cue: the fill only fades", down)
	ok("cue: the rim pulses twice over the window", peaks == 2, "%d pulses" % peaks)
	ok("cue: a pulse is brighter than steady", AimShapes.rim_k(t * 0.75) > 1.2, "%.2f" % AimShapes.rim_k(t * 0.75))

## What AimDraw does with a registered zone: the entry gets "left", the node fades, a stale zone is released.
func _draw() -> void:
	var r: Array = ak.setup("gunslinger", 6.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var d := AimKit.layer(m)
	var node := MeshInstance3D.new()
	m.add_child(node)
	AimKit.circle(P, "z", {"self": true, "r": 2.0, "all": true})
	var k := AimKit.zone(P, "z", 3.0, node)
	d.rebuild()
	var steady_now := k == 1.0 and node.transparency == 0.0
	ok("draw: a long-lived zone is registered and steady", AimKit.zoned(P, "z") and steady_now)
	ok("draw: the entry carries the seconds left", is_equal_approx(float(AimKit.entry(P, "z")["left"]), 3.0))
	AimKit.circle(P, "z", {"self": true, "r": 2.0, "all": true})
	AimKit.zone(P, "z", 0.2, node)
	d.rebuild()
	ok("draw: inside the window the node fades", node.transparency > 0.3, "%.2f" % node.transparency)
	var steady := AimShapes._rim(AimKit.entry(P, "z").merged({"left": 9.0}, true))
	var pulse := AimShapes._rim(AimKit.entry(P, "z").merged({"left": 0.375}, true))
	ok("draw: inside the window the rim pulses", pulse.a > steady.a, "%.2f > %.2f" % [pulse.a, steady.a])
	ak.step(m, 0.2)
	d.rebuild()
	ok("draw: a zone its kit stopped calling is released and the node restored",
			not AimKit.zoned(P, "z") and node.transparency == 0.0)
	node.queue_free()
	await ak.done(m)

## id prefix of a zone this hunter has registered right now.
func _zoned(m: Match, P: Hunter, id: String) -> bool:
	var pre := "%d:%s" % [P.get_instance_id(), id]
	for k in AimKit.layer(m).zones:
		if String(k).begins_with(pre):
			return true
	return false

## Every lingering kit zone: cast it, step into it, and it must stand registered. {arch, name, id, life, go, secs}
## `life` is what the zone's data says it lasts (the report lists these).
func _kits() -> void:
	var cases := [
		{"arch": "gunslinger", "name": "Vex R fire zone", "id": "xz", "secs": 2.2, "go": _ult},
		{"arch": "ashwick", "name": "Cinder R flight trail", "id": "carpet", "secs": 0.8, "go": _ult},
		{"arch": "archer", "name": "Lace E arrow rain", "id": "rain", "secs": 0.8, "go": _cast_e},
		{"arch": "tender", "name": "Meeko E hearth zone", "id": "hearth", "secs": 0.3, "go": _cast_e},
		{"arch": "bulwark", "name": "Albert E hammer zone", "id": "e", "secs": 1.3, "go": _cast_e},
		{"arch": "bulwark", "name": "Albert R fissure scar", "id": "scar", "secs": 3.0, "go": _ult},
		{"arch": "ostra", "name": "Ostra R well", "id": "well", "secs": 1.4, "go": _ult},
		{"arch": "rimewright", "name": "Neve R rink", "id": "x", "secs": 0.5, "go": _ult},
		{"arch": "rimewright", "name": "Neve RMB spear zone", "id": "zone", "secs": 0.3, "go": _spear},
		{"arch": "rimewright", "name": "Neve ice path", "id": "slab", "secs": 0.4, "go": _skate},
		{"arch": "thief", "name": "Sable R encore ring", "id": "ult", "secs": 1.0, "go": _ult},
	]
	for c in cases:
		var r: Array = ak.setup(String(c["arch"]), 8.0, "", true)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var T: Hunter = r[2]
		T.teleport(P.pos + Vector3(0, 0, 14.0))
		ak.aim_at(P, P.pos + Vector3(8.0, 0, 0))
		var cast: bool = c["go"].call(m, P)
		ak.step(m, float(c["secs"]))
		await main.get_tree().process_frame      # the pooled effects (PinFx's rain) tick on frames
		await main.get_tree().process_frame
		AimKit.layer(m).rebuild()
		ok("%s registers with the expiry cue" % c["name"], cast and _zoned(m, P, String(c["id"])))
		await ak.done(m)

func _ult(_m: Match, P: Hunter) -> bool:
	P.ak.cd["x"] = 0.0
	return HunterKeys.ult_pressed(P)

func _cast_e(_m: Match, P: Hunter) -> bool:
	P.ak.cd["e"] = 0.0
	return P.ak.cast_e()

func _spear(_m: Match, P: Hunter) -> bool:
	(P.ak as RimewrightKit)._spear_land(P.pos + Vector3(6.0, 0, 0))
	return true

func _skate(_m: Match, P: Hunter) -> bool:
	return (P.ak as RimewrightKit).on_dash(false) or not (P.ak as RimewrightKit).rinkrun.is_empty()
