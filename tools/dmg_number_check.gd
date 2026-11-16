extends RefCounted
## --dmg-number-check: the shared damage number (Fx.number). Ten ticks from one source on one target
## roll into one label whose value is their sum; another source or target gets its own; a crit is
## larger than a normal hit and never rolls into the count; bigger hits sit in bigger size tiers;
## numbers keep off the reticle's screen area; the pool never grows. Prints DMGNUM PASS/FAIL.

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("DMGNUM %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var fx: Fx = m.fx
	fx.set_process(false)
	await main.get_tree().process_frame
	var P: Hunter = m.player
	var foes := m.hunters.filter(func(x): return x.team != P.team)
	ok(not foes.is_empty(), "setup: a rival")
	_ticks(m, fx, P, foes[0])
	_sizes(fx)
	_reticle(fx)
	_pool(fx)
	print("DMGNUM DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _live(fx: Fx) -> Array:
	return fx.nums.filter(func(n): return n["node"].visible)

## 10 burn-style ticks (a quarter second apart) through the real damage path.
func _ticks(m: Match, fx: Fx, src: Hunter, foe: Hunter) -> void:
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
	var tiers := [5.0, 60.0, 250.0].map(func(v): return Fx._num_size(v, false))
	ok(tiers[2] > tiers[1] and tiers[1] > tiers[0], "bigger hits are in bigger tiers %s" % [tiers])
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
