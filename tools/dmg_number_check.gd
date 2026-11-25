extends RefCounted
## --dmg-number-check: the shared damage number (Fx.number). Ten ticks from one source on one target
## roll into one label whose value is their sum; another source or target gets its own; a crit is
## larger than a normal hit and never rolls into the count; bigger hits sit in bigger size tiers;
## numbers keep off the reticle's screen area; every kind (plain, armour, crit, empowered, shield, Fusion
## shell, heal, hurt) lands once through the real paths and reads in its HudStyle.NUM_STYLE colour and size,
## no two alike; the pool never grows; in a trio focusing one dummy for
## 3 s no more than DmgNumberTrio.MAX_OVERLAP numbers print over one spot. Prints DMGNUM PASS/FAIL.

const Trio := preload("res://tools/dmg_number_trio.gd")

## One hit of every kind through the real damage paths: the number it prints reads in its style (HudStyle),
## and any two kinds differ by colour (RGB distance >= KIND_DIST) or size (>= KIND_PX px at the same 30 dmg).
const KIND_DIST := 0.2
const KIND_PX := 3
var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	print("DMGNUM %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var fx: Fx = m.fx
	fx.set_process(false)
	await main.get_tree().process_frame
	var ply: Hunter = m.player
	var foes := m.hunters.filter(func(x): return x.team != ply.team)
	ok(not foes.is_empty(), "setup: a rival")
	_ticks(m, fx, ply, foes[0])
	_sizes(fx)
	_reticle(fx)
	_pool(fx)
	_kinds_read(m, fx, ply, foes[0])
	m.queue_free()
	await _trio()
	print("DMGNUM DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)


func _live(fx: Fx) -> Array:
	return fx.nums.filter(func(n): return n["node"].visible)


## 10 burn-style ticks (a quarter second apart) through the real damage path.
func _ticks(_m: Match, fx: Fx, src: Hunter, foe: Hunter) -> void:
	foe.max_hp = 1e6
	foe.hp = 1e6
	fx.nums.clear()
	for i in 10:
		foe.hurt(7.0, src, {"src": "abil", "tags": ["cinder_zone"]})
		fx._process(0.25)
	var dealt := 1e6 - foe.hp
	var live := _live(fx)
	ok(live.size() == 1, "10 ticks make 1 label (%d)" % live.size())
	if live.size() == 1:
		var shown := int((live[0]["node"] as Label3D).text)
		ok(absi(shown - int(round(dealt))) <= 1 and dealt > 0.0, "its value is their sum: %d of %.1f" % [shown, dealt])
	src.hurt(7.0, foe, {"src": "abil"})
	ok(_live(fx).size() == 2, "a different source and target gets its own label")
	fx.nums.clear()


func _sizes(fx: Fx) -> void:
	var hit := Fx._num_size(30.0, false)
	var crit := Fx._num_size(30.0, true)
	ok(crit > hit, "a crit is larger than a normal hit (%d vs %d)" % [crit, hit])
	var tiers := [5.0, 18.0, 45.0].map(func(v): return Fx._num_size(v, false))
	ok(tiers[2] > tiers[1] and tiers[1] > tiers[0], "bigger hits are in bigger tiers %s" % [tiers])
	# our scale (a Hunter has 124 to 193): a rifle round, an ability and an ult each read as their own size
	var ours := [8.0, 18.0, 45.0].map(func(v): return Fx._num_size(v, false))
	ok(
		ours[0] > Fx._num_size(4.0, false) and ours[1] > ours[0] and ours[2] > ours[1],
		"a round (8), an ability (18) and an ult (45) print at 3 sizes over a dart (4) %s" % [ours]
	)
	fx.nums.clear()
	var at := Vector3(0, 1, 0)
	fx.number(at, 10.0, Color.WHITE, false, "", "k")
	fx.number(at, 40.0, Color.WHITE, true, "", "k")
	var live := _live(fx)
	ok(live.size() == 1 and bool(live[0]["crit"]), "a crit right after a hit joins it, the label turns crit")
	fx._process(0.5)
	fx.number(at, 5.0, Color.WHITE, false, "", "k")
	ok(_live(fx).size() == 2, "a normal hit does not roll into a crit's number later")
	fx.nums.clear()


func _reticle(fx: Fx) -> void:
	var r := Fx.RETICLE_CLEAR_PX
	var c := Vector2(500, 300)
	var pushed := Fx.push_out(c + Vector2(10, 0), c, r)
	ok(pushed.distance_to(c) >= r - 0.01, "a point on the reticle is pushed out of its area")
	ok(Fx.push_out(c, c, r).distance_to(c) >= r - 0.01, "even one dead centre")
	var far := c + Vector2(200, 0)
	ok(Fx.push_out(far, c, r) == far, "a point away from it stays")
	var cam := fx.get_viewport().get_camera_3d()
	ok(cam != null, "setup: a camera")
	if cam == null:
		return
	var mouse := fx.get_viewport().get_mouse_position()
	var under := cam.project_position(mouse, 12.0)
	fx.nums.clear()
	fx.number(under, 20.0, Color.WHITE, false, "", "r")
	var l: Label3D = _live(fx)[0]["node"]
	var gap := cam.unproject_position(l.global_position).distance_to(mouse)
	ok(gap >= r - 40.0, "a number aimed at the reticle spawns clear of it (%.0f px, minus jitter)" % gap)
	fx.nums.clear()


func _pool(fx: Fx) -> void:
	var kids := fx.get_child_count()
	fx.nums.clear()
	for i in Fx.NUM_POOL * 3:
		fx.number(Vector3(i * 3.0, 1, 0), 9.0, Color.WHITE, false, "", "p%d" % i)
	ok(fx.get_child_count() == kids, "numbers reuse the pool, no labels are created")
	ok(_live(fx).size() <= Fx.NUM_POOL, "no more than %d live at once (%d)" % [Fx.NUM_POOL, _live(fx).size()])
	fx.nums.clear()


## Three attackers on one dummy for Trio.SECS s: the most numbers over one spot in any frame.
func _trio() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var fx: Fx = m.fx
	fx.set_process(false)
	await main.get_tree().process_frame
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var s := Trio.setup(m)
	ok((s["mates"] as Array).size() == 2, "setup: two teammates")
	fx.nums.clear()
	var most := 0
	var over := 0
	for f in int(Trio.SECS / Trio.DT):
		Trio.hit(s, f)
		m.step(Trio.DT)
		fx._process(Trio.DT)
		m.cam.snap(m.player.pos)
		var c := Trio.overlap(fx, m.cam)
		most = maxi(most, c)
		over += 1 if c > Trio.MAX_OVERLAP else 0
	ok((s["dummy"] as Hunter).hp < 1e6, "setup: the dummy took the hits")
	ok(
		most <= Trio.MAX_OVERLAP,
		(
			"trio focus %.0f s: at most %d numbers over one spot (%d; %d frames over)"
			% [Trio.SECS, Trio.MAX_OVERLAP, most, over]
		)
	)
	fx.nums.clear()
	m.queue_free()


func _last(fx: Fx) -> Dictionary:
	var live := _live(fx)
	return {} if live.is_empty() else live[live.size() - 1]


func _read(fx: Fx) -> Dictionary:
	var n := _last(fx)
	if n.is_empty():
		return {}
	var l: Label3D = n["node"]
	return {
		"col": l.modulate,
		"px": l.font_size,
		"text": l.text,
		"kind": int(n["kind"]),
		"crit": bool(n["crit"]),
		"outline": l.outline_size
	}


func _kinds_read(_m: Match, fx: Fx, ply: Hunter, foe: Hunter) -> void:
	Settings.set_v("damage_numbers", true, false)
	foe.max_hp = 1e6
	ply.max_hp = 1e6
	var got := {}
	var land := func(name: String, prep: Callable, who: Hunter, by: Hunter, opts: Dictionary) -> void:
		foe.armor = 0.0
		foe.shield = 0.0
		foe.shield_t = 0.0
		foe.merge_st = {}
		for h: Hunter in [foe, ply]:
			h.inv_t = 0.0
			h.hp = 1e6
		fx.nums.clear()
		fx.set_process(false)
		prep.call()
		if name != "heal":
			who.hurt(30.0, by, opts)
		else:
			fx.healed(who, 30.0)
		got[name] = _read(fx)
		ok(not (got[name] as Dictionary).is_empty(), "kind %s prints a number" % name)
	land.call("hit", func(): pass, foe, ply, {"src": "shot"})
	land.call("armour", func(): foe.armor = 200.0, foe, ply, {"src": "shot"})
	land.call("crit", func(): pass, foe, ply, {"src": "shot", "crit": true})
	land.call("empowered", func(): pass, foe, ply, {"src": "shot", "heavy": true})
	land.call(
		"shield",
		func():
			foe.shield = 200.0
			foe.shield_t = 30.0,
		foe,
		ply,
		{"src": "shot"}
	)
	land.call(
		"shell",
		func(): foe.merge_st = {"shell": 200.0, "shell_max": 200.0, "form": {"glow": Color.RED}},
		foe,
		ply,
		{"src": "shot"}
	)
	land.call("heal", func(): foe.hp = 1.0, foe, ply, {})
	land.call("hurt", func(): pass, ply, foe, {"src": "shot"})
	var want := {
		"hit": "hit",
		"armour": "armour",
		"crit": "crit",
		"empowered": "empowered",
		"shield": "shield",
		"shell": "shell",
		"heal": "heal",
		"hurt": "hurt"
	}
	for k in want:
		var r: Dictionary = got.get(k, {})
		if r.is_empty():
			continue
		var st := HudStyle.num_style(want[k])
		var hex: String = (r["col"] as Color).to_html(false)
		ok((r["col"] as Color).is_equal_approx(st["col"]), "%s number reads in its table colour %s" % [k, hex])
		ok(bool(r["crit"]) == bool(st["crit"]), "%s number: crit outline only on a crit" % k)
	ok(String((got.get("heal", {}) as Dictionary).get("text", "")).begins_with("+"), "a heal reads +N")
	var names := got.keys()
	var worst := 9.0
	var bad := 0
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Dictionary = got[names[i]]
			var b: Dictionary = got[names[j]]
			if a.is_empty() or b.is_empty():
				continue
			var ca: Color = a["col"]
			var cb: Color = b["col"]
			var dist := Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
			var dpx := absi(int(a["px"]) - int(b["px"]))
			var apart := dist >= KIND_DIST or dpx >= KIND_PX
			worst = minf(worst, dist if dpx < KIND_PX else 9.0)
			if not apart:
				bad += 1
				print("DMGNUM   alike: %s / %s (dist %.2f, px %d vs %d)" % [names[i], names[j], dist, a["px"], b["px"]])
	ok(bad == 0, "no two of the %d kinds look alike (closest same-size colour pair %.2f)" % [names.size(), worst])
	for k in got:
		var r: Dictionary = got[k]
		if not r.is_empty():
			print("DMGNUM   %s: %s %dpx outline %d" % [k, (r["col"] as Color).to_html(false), r["px"], r["outline"]])
	fx.nums.clear()
