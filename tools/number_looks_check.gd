extends RefCounted
## --number-looks-check: a damage number takes one of three looks by what dealt the damage (Fx.Num,
## docs/HUD.md "Damage numbers"). In a three-hunter match with your Boki beside you:
##   1. the source picks the look: a burn or poison tick (or a hit flagged "tick"), a Boki's hit, else a direct hit
##   2. your direct hit keeps the current look: full size, the hit colour, the thin outline; a crit its colour,
##      thick ember outline and bigger pop; a hit on armour the armour colour
##   3. your Boki's hit: smaller, in its type colour, on its own number beside yours (never added onto yours);
##      a Boki's crit and a hit on armour keep those colours
##   4. a burn tick: small, the tick colour, lower on the body, a second of ticks on one number, never added onto
##      your hits
##   5. a rival's burn on a third hunter prints nothing (only numbers that involve you show)
##   6. the draw cost stays flat: no label is made per number (the pool keeps NUM_POOL), and a target taking all
##      three at once shows at most four labels
## Steps only the burns and the numbers (no AI, no other hits). Never touches the save.

const DT := 1.0 / 60.0
const SPECIES := "cindle"  # a venom Boki: its type colour is not a hit, crit or armour colour

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("NUMLOOKS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Settings.set_v("damage_numbers", true, false)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var you: Hunter = m.player
	var rivals: Array[Hunter] = []
	for h in m.hunters:
		h.inv_t = 0.0
		if h != you:
			h.ctrl = "idle"
			rivals.append(h)
	var foe := rivals[0]
	var rival := rivals[1]
	foe.teleport(you.pos + Vector3(5, 0, 0))
	rival.teleport(you.pos + Vector3(-12, 0, 0))
	var k: Kin = m.give_kin(you, Save.new_kin(SPECIES))
	k.brain.think_t = 1e9
	var labels0 := _labels(m)
	_kinds(you, k)
	_settle(m, foe)
	_direct(m, you, foe)
	_settle(m, foe)
	_boki(m, you, foe, k)
	_settle(m, foe)
	_ticks(m, you, foe)
	_settle(m, foe)
	_not_yours(m, foe, rival)
	_settle(m, foe)
	_flat(m, you, foe, k, labels0)
	print("NUMLOOKS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


# ---------------------------------------------------------------- 1. the source picks the look
func _kinds(you: Hunter, k: Kin) -> void:
	ok(Fx.num_kind(you, {"src": "shot"}) == Fx.Num.HIT, "a shot of yours is a direct hit")
	ok(Fx.num_kind(you, {"src": "abil", "crit": true}) == Fx.Num.HIT, "your ability crit is a direct hit")
	ok(Fx.num_kind(k, {"src": "kin"}) == Fx.Num.KIN, "your Boki's bite is a Boki hit")
	ok(
		Fx.num_kind(you, {"src": "burn"}) == Fx.Num.TICK and Fx.num_kind(k, {"src": "burn"}) == Fx.Num.TICK,
		"a burn or poison tick is a tick, whoever lit it"
	)
	ok(Fx.num_kind(you, {"src": "abil", "tick": true}) == Fx.Num.TICK, "a hit flagged as a tick is a tick")


# ---------------------------------------------------------------- 2. your direct hit: the current look
func _direct(m: Match, you: Hunter, foe: Hunter) -> void:
	foe.armor = 0.0
	foe.hurt(20.0, you, {"src": "shot"})
	var n := _newest(m)
	ok(_is(n, Fx.Num.HIT, HudStyle.HIT), "your hit: the hit look and colour")
	var l: Label3D = n.get("node")
	ok(
		l != null and l.font_size == m.fx._num_size(float(n["val"]), false) and l.outline_size == 14,
		"your hit: full size, thin outline"
	)
	_settle(m, foe)
	foe.hurt(20.0, you, {"src": "shot", "crit": true})
	n = _newest(m)
	l = n.get("node")
	ok(
		_is(n, Fx.Num.HIT, HudStyle.CRIT) and l.outline_size == 20 and l.outline_modulate == Fx.CRIT_OUTLINE,
		"your crit: the crit colour and thick ember outline"
	)
	ok(
		l.font_size == m.fx._num_size(float(n["val"]), true) and is_equal_approx(l.scale.x, Fx.CRIT_POP),
		"your crit: bigger, and it pops"
	)
	_settle(m, foe)
	foe.armor = 60.0
	foe.hurt(20.0, you, {"src": "shot"})
	ok(_is(_newest(m), Fx.Num.HIT, HudStyle.HIT_ARMOR), "your hit on armour: the armour colour")
	foe.armor = 0.0


# ---------------------------------------------------------------- 3. your Boki's hit
func _boki(m: Match, you: Hunter, foe: Hunter, k: Kin) -> void:
	var type_col := DexView.type_col(String(k.sp.get("type", "")))
	ok(
		not type_col.is_equal_approx(HudStyle.HIT) and not type_col.is_equal_approx(HudStyle.HIT_ARMOR),
		"the test Boki's type colour is its own (%s)" % String(k.sp.get("type", ""))
	)
	foe.hurt(20.0, you, {"src": "shot"})
	var yours := _newest(m)
	var yours_val := float(yours.get("val", 0.0))
	foe.hurt(20.0, k, {"src": "kin"})
	var n := _newest(m)
	ok(
		not is_same(n, yours) and is_equal_approx(float(yours.get("val", 0.0)), yours_val),
		"your Boki's hit: its own number, not added onto yours"
	)
	ok(_is(n, Fx.Num.KIN, type_col), "your Boki's hit: in its type colour")
	var l: Label3D = n.get("node")
	var yl: Label3D = yours.get("node")
	ok(
		(
			l != null
			and l.font_size == m.fx._num_size(float(n["val"]), false, false, Fx.Num.KIN)
			and l.font_size < m.fx._num_size(float(n["val"]), false)
		),
		"your Boki's hit: smaller than yours"
	)
	var gap := _gap(n, yours) if l != null and yl != null else 0.0
	ok(gap > 0.5, "your Boki's hit: beside yours, not on it (%.2f m)" % gap)
	_settle(m, foe)
	foe.hurt(20.0, k, {"src": "kin", "crit": true})
	n = _newest(m)
	l = n.get("node")
	ok(
		(
			_is(n, Fx.Num.KIN, HudStyle.CRIT)
			and l.outline_modulate == Fx.CRIT_OUTLINE
			and is_equal_approx(l.scale.x, Fx.CRIT_POP)
		),
		"your Boki's crit: the crit colour, outline and pop"
	)
	_settle(m, foe)
	foe.armor = 60.0
	foe.hurt(20.0, k, {"src": "kin"})
	ok(_is(_newest(m), Fx.Num.KIN, HudStyle.HIT_ARMOR), "your Boki's hit on armour: the armour colour")
	foe.armor = 0.0


# ---------------------------------------------------------------- 4. burn ticks
func _ticks(m: Match, you: Hunter, foe: Hunter) -> void:
	var dps := 8.0
	_light(foe, you, dps, 3.0)
	var seen := {}  # each tick number once, by its label (none is reused in 3 s)
	var most := 0
	var hit_num := {}
	var t := 0.0
	while t < 3.2:
		foe.tick_status(DT)
		m.fx._process(DT)
		t += DT
		if hit_num.is_empty() and t >= 0.5:
			foe.hurt(20.0, you, {"src": "shot"})
			hit_num = _newest(m)
		var on := 0
		for n in m.fx.nums:
			if n.has("val") and n["kind"] == Fx.Num.TICK:
				seen[(n["node"] as Label3D).get_instance_id()] = n
				on += int((n["node"] as Label3D).visible)
		most = maxi(most, on)
	var ticks: Array = seen.values()
	var total := 0.0
	var biggest := 0.0
	var looks_ok := not ticks.is_empty()
	for n in ticks:
		total += float(n["val"])
		biggest = maxf(biggest, float(n["val"]))
		var l: Label3D = n["node"]
		looks_ok = looks_ok and Color(l.modulate, 1.0).is_equal_approx(DotLook.COL)
		looks_ok = looks_ok and l.font_size == m.fx._num_size(float(n["val"]), false, false, Fx.Num.TICK)
	ok(looks_ok, "ticks: small, in the tick colour")
	ok(
		ticks.size() >= 3 and ticks.size() <= 4 and biggest <= dps * (Fx.TICK_WINDOW + 0.25) + 0.01,
		"ticks: a second of them on one number (%d numbers, biggest %.1f)" % [ticks.size(), biggest]
	)
	ok(absf(total - dps * 3.0) < 0.6, "ticks: together they add up to the burn (%.1f of %.1f)" % [total, dps * 3.0])
	ok(most <= 2, "ticks: at most one number gathering and one floating off (%d)" % most)
	ok(
		not hit_num.is_empty() and hit_num["kind"] == Fx.Num.HIT and float(hit_num["val"]) >= 19.0,
		"ticks: never added onto your hit"
	)
	if not ticks.is_empty() and not hit_num.is_empty():
		var low := (ticks[0]["base"] as Vector3).y < (hit_num["base"] as Vector3).y - 0.5
		ok(low, "ticks: lower on the body than your hits")


# ---------------------------------------------------------------- 5. not yours: nothing
func _not_yours(m: Match, foe: Hunter, rival: Hunter) -> void:
	var before := _shown(m)
	rival.hurt(30.0, foe, {"src": "shot"})
	_light(rival, foe, 8.0, 1.5)
	_run(m, [rival], 1.6)
	ok(_shown(m) == before and before == 0, "a rival's hit and burn on another hunter print nothing")


# ---------------------------------------------------------------- 6. the draw cost stays flat
func _flat(m: Match, you: Hunter, foe: Hunter, k: Kin, labels0: int) -> void:
	_light(foe, you, 8.0, 2.0)
	var most := 0
	var t := 0.0
	while t < 2.0:
		if fmod(t, 0.2) < DT:
			foe.hurt(6.0, you, {"src": "shot"})
			foe.hurt(4.0, k, {"src": "kin"})
		foe.tick_status(DT)
		m.fx._process(DT)
		most = maxi(most, _shown(m))
		t += DT
	ok(most <= 4, "your hits, your Boki's and a burn at once: at most 4 numbers on the target (%d)" % most)
	var labels := _labels(m)
	ok(labels == labels0 and m.fx.num_pool.size() == Fx.NUM_POOL, "no label made per number (%d labels)" % labels)


# ---------------------------------------------------------------- helpers
## Steps the burns on `who` and the numbers for `secs`.
func _run(m: Match, who: Array, secs: float) -> void:
	var t := 0.0
	while t < secs:
		for e: Ent in who:
			e.tick_status(DT)
		m.fx._process(DT)
		t += DT


## Lets every number float off, and heals the target so it stays up.
func _settle(m: Match, foe: Hunter) -> void:
	_run(m, [], 1.5)
	foe.hp = foe.max_hp


## Sets `who` burning: `dps` for `secs`, lit by `by` (what a flame or poison hit leaves).
func _light(who: Ent, by: Ent, dps: float, secs: float) -> void:
	who.burn_t = secs
	who.burn_dps = dps
	who.burn_by = by


func _newest(m: Match) -> Dictionary:
	for i in range(m.fx.nums.size() - 1, -1, -1):
		if m.fx.nums[i].has("val"):
			return m.fx.nums[i]
	return {}


func _is(n: Dictionary, kind: Fx.Num, col: Color) -> bool:
	if n.is_empty() or n["kind"] != kind:
		return false
	return Color((n["node"] as Label3D).modulate, 1.0).is_equal_approx(col)


## How far apart two numbers' spots are.
func _gap(a: Dictionary, b: Dictionary) -> float:
	return (a["base"] as Vector3).distance_to(b["base"] as Vector3)


## Damage numbers on screen now.
func _shown(m: Match) -> int:
	return m.fx.nums.filter(func(n): return n.has("val") and (n["node"] as Label3D).visible).size()


## Label3D nodes under Fx (numbers and words come from one pool).
func _labels(m: Match) -> int:
	return m.fx.get_children().filter(func(c): return c is Label3D).size()
