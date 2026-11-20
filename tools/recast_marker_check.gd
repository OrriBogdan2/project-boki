extends RefCounted
## --recast-marker-check: the world marker on what an open recast triggers (scripts/ui/recast_marker.gd,
## DECISIONS 2026-11-08), for Tenzo's Rock Hop, Neve's Rink Wall, Sparkle's Kitefall and Cinder's Flue Flight:
## it sits on the spot, shows the live key, fades with the window, is gone when the window closes and is the
## caster's alone. Prints RMCHECK PASS/FAIL.

var main: Node
var ak = null
var fails := 0
var n := 0

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("RMCHECK %-62s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _hop()
	await _wall()
	await _kitefall()
	await _flight()
	print("RMCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _marker(m: Match) -> RecastMarker:
	return m.get_node_or_null("RecastMarker") as RecastMarker

## The marker is up on `at` (ground plane), with the key of `action`, ring in `col`.
func _on(label: String, m: Match, at: Vector3, action: String, col: Color) -> void:
	var mk := _marker(m)
	var key: String = Settings.key_cap(action)
	var where := mk != null and Vector2(mk.position.x - at.x, mk.position.z - at.z).length() < 0.25
	ok(label + ": the marker sits on the spot", mk != null and mk.visible and where)
	ok(label + ": it shows the live key (" + key + ")", mk != null and mk._cap.text == key)
	var tint := mk != null and mk._mat.albedo_color.is_equal_approx(Color(col, mk._mat.albedo_color.a))
	ok(label + ": in the ability's colour", tint)

## The marker was refreshed by every step while the window was open; `idle` read back after `shut` says whether
## the last step called it (it only counts up in a frame, which these steps never run).
func _quiet(label: String, m: Match, shut: Callable) -> void:
	var mk := _marker(m)
	mk._idle = 1.0
	shut.call()
	ak.step(m, 0.05)
	ok(label, mk._idle >= 1.0)
	mk._process(0.0)
	ok(label + " (and it hides)", not mk.visible)

func _hop() -> void:
	var r: Array = ak.setup("dolm", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: DolmKit = P.ak
	ak.aim_at(P, r[4] + Vector3(14, 0, 0))
	P.dashes = P.max_dashes()
	K.on_dash(false)
	var t := 0.0
	while t < 3.0 and String(K.hop.st.get("phase", "")) != "skid":
		ak.step(m, 1.0 / 60.0)
		t += 1.0 / 60.0
	ak.step(m, 1.0 / 60.0)
	var spot: Dictionary = K.hop.spot_for(P.aim_dir(), int(K.dash_def()["hops"]) - int(K.hop.st["n"]) - 1)
	ok("hop: the skid after a landing has the next spot", String(K.hop.st["phase"]) == "skid" and not spot.is_empty())
	_on("hop", m, spot["at"], "dash", BreahHop.HOP_COL)
	var ahead: Vector3 = spot["at"] - P.pos
	ok("hop: it is toward the cursor", ahead.x > 0.5 and absf(ahead.z) < ahead.x)
	_quiet("only the caster sees it: a remote hunter shows none", m, func(): P.ctrl = "remote")
	P.ctrl = "local"
	ak.step(m, 0.05)
	_quiet("hop: last hop taken, no marker", m, func(): K.hop.st["n"] = int(K.dash_def()["hops"]))
	m.queue_free()
	await main.get_tree().process_frame

func _wall() -> void:
	var r: Array = ak.setup("rimewright", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	P.inp["sig"] = true
	ak.step(m, 0.05)
	P.inp["sig"] = false
	ak.step(m, 0.4)
	var w: Dictionary = K.wall["w"]
	var mid: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	ok("wall: still sliding, so E can freeze it", K.e_recastable())
	_on("wall", m, Vector3(mid.x, 0, mid.y), "signature", K.col_of(K.e_def()))
	_quiet("wall: frozen, no marker", m, K.e_recast)
	m.queue_free()
	await main.get_tree().process_frame

func _kitefall() -> void:
	var r: Array = ak.setup("mage", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: MageKit = P.ak
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	var t := 0.0
	while t < 4.0 and K.ult.phase() != MageUlt.AIR:
		ak.step(m, 1.0 / 60.0)
		t += 1.0 / 60.0
	ak.step(m, 1.0 / 60.0)
	ok("kitefall: she hangs, X would bring her down", K.ult.phase() == MageUlt.AIR)
	_on("kitefall", m, K.ult.leap["land"], "hunter_ult", K.col_of(K.x_def()))
	_quiet("kitefall: coming down, no marker", m, K.ult.recast)
	m.queue_free()
	await main.get_tree().process_frame

func _flight() -> void:
	var r: Array = ak.setup("ashwick", 16.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: AshwickKit = P.ak
	K.cd["x"] = 0.0
	ak.aim_at(P, r[4] + Vector3(16, 0, 0))
	HunterKeys.ult_pressed(P)
	ak.step(m, 0.3)
	ok("flight: she is flying, X would land her", K.jet.running())
	_on("flight", m, K.ground(P.pos), "hunter_ult", K.col_of(K.x_def()))
	_quiet("flight: landed, no marker", m, K.jet.recast)
	m.queue_free()
	await main.get_tree().process_frame
