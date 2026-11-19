extends RefCounted
## --reticle-check: the aiming reticle (Reticle) and its settings (Settings > Gameplay > Reticle).
##   1. the defaults: the small broken ring with a dot, white, full opacity, outlined, smaller than the
##      old cross (13 px out from the cursor)
##   2. set every option: the settings file holds them (they belong to the player, not the run save) and
##      the reticle's draw style follows
##   3. every shape and colour draws without errors, with and without the outline
##   4. every hold slot of the 12 kits: the shared charge ring (AimKit.charge, drawn at the cursor) fills with
##      the hold and flashes at full; the aim and raise holds (a lane, a shield, a fan) show no ring
## Runs with a temporary XDG_DATA_HOME: it writes user://settings.cfg.

## Every hold slot of the 12 kits: [kit, what, input, ring, at]. at: where the ring sits, "body" where the source
## shows its charge arc round the hero (hero-ref juggernaut item 8: Kael's blast), else "cursor".
## Input: "lmb" held, "rmb" held, "dash" held, "e" pressed (it charges by itself). ring false: an aim or raise
## hold (a lane, a shield, a fan, a stream), which draws no ring.
## Tender and Thief have no hold slot.
const HOLDS := [
	["archer", "Heavy Shot", "rmb", true, "cursor"], ["archer", "bow draw", "lmb", false, ""],
	["ashwick", "Cinder Shot lane", "rmb", false, ""], ["ashwick", "Torch Lance stream", "lmb", false, ""],
	["bulwark", "hammer whirl", "lmb", true, "cursor"], ["bulwark", "Aegis", "rmb", false, ""],
	["dolm", "punch", "lmb", true, "cursor"], ["dolm", "Quakefall", "rmb", true, "cursor"],
	["dredge", "Brass Broadside fan", "e", false, ""],
	["gunslinger", "Longneedle", "e", true, "cursor"],
	["juggernaut", "blast", "lmb", true, "body"], ["juggernaut", "Lunge", "rmb", true, "cursor"],
	["mage", "Wirerun", "dash", true, "cursor"], ["mage", "Storm Rod", "rmb", true, "cursor"],
	["ostra", "Lantern Trade ends", "dash", false, ""],
	["rimewright", "Ice Spear aim", "rmb", false, ""], ["rimewright", "Skate", "dash", false, ""],
]
const HOLD_SECS := 2.5         # s each hold is kept down
const OLD_REACH := 13.0     # px: how far the old cross reached from the cursor at rest (gap 6 + arm 7)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RETICLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Settings.reset_all()
	var st := Reticle.style()
	var white: Color = Reticle.COLORS["white"][1]
	ok(st["shape"] == "default" and float(st["k"]) == 1.0 and st["outline"] == true, "defaults: %s" % str(st))
	ok((st["col"] as Color).is_equal_approx(white), "default colour: white at full opacity")
	ok(Reticle.RING_R + Reticle.LINE_W < OLD_REACH * 0.6, "the default is clearly smaller than the old cross")
	# ---------------------------------------------------------------- 2. set, persist, apply
	var want := {"reticle_shape": "cross", "reticle_size": 1.5, "reticle_col": "yellow", "reticle_alpha": 0.6,
		"reticle_outline": false}
	for key in want:
		Settings.set_v(key, want[key])
	var cf := ConfigFile.new()
	ok(cf.load(Settings.PATH) == OK, "the settings file exists")
	var saved := true
	for key in want:
		saved = saved and cf.get_value("s", key, null) == want[key]
	ok(saved, "every reticle option is in the settings file")
	var in_save: bool = Save.d.has("reticle_shape") or (Save.d.get("settings", {}) as Dictionary).has("reticle_shape")
	ok(not in_save, "nothing went into the run save")
	st = Reticle.style()
	var yellow: Color = Reticle.COLORS["yellow"][1]
	var col: Color = st["col"]
	ok(st["shape"] == "cross" and absf(float(st["k"]) - 1.5) < 0.001, "shape and size follow: %s" % str(st))
	ok(Color(col, 1.0).is_equal_approx(yellow) and absf(col.a - 0.6) < 0.001, "colour and opacity follow")
	ok(st["outline"] == false, "outline off follows")
	Settings.set_v("reticle_col", "nonsense")
	ok(Color(Reticle.style()["col"], 1.0).is_equal_approx(white), "an unknown colour id falls back to white")
	# ---------------------------------------------------------------- 3. every style draws
	var canvas := Control.new()
	canvas.size = Vector2(80, 80)
	main.add_child(canvas)
	var drawn := [0]
	canvas.draw.connect(func():
		for s in Reticle.SHAPES:
			for cid in Reticle.COLORS:
				Settings.v["reticle_shape"] = s[0]
				Settings.v["reticle_col"] = cid
				for outline in [true, false]:
					Settings.v["reticle_outline"] = outline
					Reticle.draw(canvas, Vector2(40, 40), 3.0)
					drawn[0] += 1)
	canvas.queue_redraw()
	for i in 3:
		await main.get_tree().process_frame
	var all_n := Reticle.SHAPES.size() * Reticle.COLORS.size() * 2
	ok(drawn[0] == all_n, "every shape x colour x outline draws (%d)" % drawn[0])
	canvas.queue_free()
	Settings.reset_all()
	await _holds(main)
	print("RETICLE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Holds one slot of `kit` for HOLD_SECS and reads the cursor ring each step: [first, max, rising, flared].
func _hold_run(ac: RefCounted, kit: String, input: String) -> Array:
	var r: Array = ac.setup(kit, 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K = P.ak
	var first := -1.0
	var top := -1.0
	var rising := true
	var flared := false
	var at := ""
	var t := 0.0
	P.fire_cd = 0.0
	K.cd["e"] = 0.0
	match input:
		"rmb":
			P.inp["sec_hold"] = true
			K.press_rmb()
		"dash":
			P.inp["dash_down"] = true
			P.do_dash()
		"e": K.use_e()
	while t < HOLD_SECS:
		P.inp["fire"] = input == "lmb"
		P.inp["sec_hold"] = input == "rmb"
		P.inp["dash_down"] = input == "dash"
		m.step(1.0 / 60.0)
		t += 1.0 / 60.0
		var rt := AimKit.reticle(P)
		var k := float(rt["charge"])
		if k >= 0.0:
			first = k if first < 0.0 else first
			rising = rising and (top >= 1.0 or k >= top - 0.001)      # (past full the shot goes and the ring resets)
			top = maxf(top, k)
			at = String(rt["at"])
		flared = flared or float(rt["flare"]) > 0.0
	m.queue_free()
	return [first, top, rising, flared, at]

func _holds(main: Node) -> void:
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	for row in HOLDS:
		var res: Array = _hold_run(ac, row[0], row[2])
		var tag := "%s %s" % [row[0], row[1]]
		if row[3]:
			var starts: bool = float(res[0]) >= 0.0 and float(res[0]) < 0.6
			var placed: bool = String(res[4]) == row[4]
			var good: bool = starts and bool(res[2]) and float(res[1]) >= 1.0 and bool(res[3]) and placed
			ok(good, "hold ring: %s fills from the start, never falls, flashes at full, at the %s %s"
					% [tag, row[4], str(res)])
		else:
			ok(float(res[1]) < 0.0, "hold ring: %s draws no ring (an aim or raise hold) %s" % [tag, str(res)])
		await main.get_tree().process_frame
