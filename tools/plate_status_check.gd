extends "res://tools/archetype_check.gd"
## --plate-status-check: the one status row on an enemy plate (HudPlate.row, DECISIONS 2026-11-08 two-step abilities).
##   1. each crowd-control kind (stun, root, Ground, Daze, Slow) on a rival: its icon on the real HUD's plate, its
##      time left and the ring's total, and the time shrinks under the same total
##   2. each kit's mark (ArchKit.combo_marks) and a Boki combo setup: the icon in the kit's colour, stacks, time
##      left shrinking, gone when it runs out; Vex's Daze and Cinder's Ablaze take the place of the plain status
##   3. the order (what stops them, your marks, the rest) and at most HudPlate.ROW_MAX icons
##   4. a monster's bar carries the same row
##   5. no row past LabelCull.FAR_M, and a rival's plate never shows dash charges (DECISIONS 2026-11-06)
##   6. the payoff of Sable's Marks, Vex's Daze and Sparkle's Static flashes the body white (ComboMark.payoff)
## Real frames in a training match; reads HudPlate.shown. Never touches the save.

const NEAR := 5.0              # m to the rival dummy
const TIME_TOL := 0.06         # s of slack on a time read across a frame or two

## [what, icon, seconds]: each crowd-control kind, put on by _apply_cc
const CC := [["stun", "concussion", 2.0], ["root", "binding", 1.5], ["Ground", "bolas", 3.0],
	["Daze", "burst", 2.5], ["Slow", "snare", 3.0]]

## [arch, icon, stacks shown]: each kit's mark, put on by _apply_mark
const MARKS := [["thief", "gem", 3], ["gunslinger", "burst", 0], ["mage", "shock", 2], ["ashwick", "fireball", 10],
	["juggernaut", "slam", 0], ["rimewright", "breeze", 0]]

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	await _crowd_control()
	for mk in MARKS:
		await _mark(String(mk[0]), String(mk[1]), int(mk[2]))
	await _boki_setup()
	await _repeats()
	await _order()
	await _range_and_dashes()
	for arch in ["thief", "gunslinger", "mage"]:
		await _payoff(arch)
	print("PLATESTATUS DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## A match with the viewer on `arch` and a rival dummy NEAR away, seen, its plate drawn.
func _scene(arch: String) -> Array:
	var s := setup(arch, NEAR)
	(s[2] as Hunter).reveal_t = 1e6
	await _frames()
	return s

func _frames() -> void:
	for i in 2:
		await main.get_tree().process_frame

## What the HUD drew in `e`'s plate status row on the last frame.
func _row(m: Match, e: Hunter) -> Array:
	return (m.hud.plates.shown.get(e.nid, {}) as Dictionary).get("row", [])

func _icons(items: Array) -> Array:
	return items.map(func(it): return String(it["icon"]))

func _only(items: Array, icon: String) -> Dictionary:
	var hits := items.filter(func(it): return it["icon"] == icon)
	return hits[0] if hits.size() == 1 else {}

func _apply_cc(T: Hunter, what: String, secs: float) -> void:
	match what:
		"stun": T.stun_t = secs
		"root": T.root_t = secs
		"Ground": KitStatus.apply(T, "gnd", secs, 0.0, false, "check")
		"Daze": KitStatus.apply(T, "rat", secs, 0.0, false)
		"Slow":
			T.slow_k = 0.3
			T.slow_t = secs

func _clear_cc(T: Hunter) -> void:
	T.stun_t = 0.0
	T.root_t = 0.0
	T.slow_t = 0.0
	T.burn_t = 0.0
	T.set_meta("gnd_until", 0.0)
	KitStatus.clear_rattled(T)

## 1. One kind at a time: its icon alone, its time and ring total, then the time shrinking under the same total.
func _crowd_control() -> void:
	var s: Array = await _scene("juggernaut")
	var m: Match = s[0]
	var T: Hunter = s[2]
	ok("a seen rival's plate draws with an empty row", m.hud.plates.shown.has(T.nid) and _row(m, T).is_empty(),
		str(_row(m, T)))
	for cc in CC:
		var what := String(cc[0])
		var secs := float(cc[2])
		_apply_cc(T, what, secs)
		await _frames()
		var it := _only(_row(m, T), String(cc[1]))
		var fresh_ok := not it.is_empty() and absf(float(it["left"]) - secs) < TIME_TOL
		ok("%s: its icon (%s) on the plate with %.1f s left" % [what, cc[1], secs],
			fresh_ok and absf(float(it["total"]) - secs) < TIME_TOL and _row(m, T).size() == 1, str(_row(m, T)))
		step(m, 0.5)
		await _frames()
		var later := _only(_row(m, T), String(cc[1]))
		var shrunk := not later.is_empty() and absf(float(later["left"]) - (secs - 0.5)) < TIME_TOL
		ok("%s: the time shrinks under the same ring total" % what,
			shrunk and absf(float(later["total"]) - secs) < TIME_TOL, str(later))
		_clear_cc(T)
		await _frames()
	ok("all over: the row is empty", _row(m, T).is_empty(), str(_row(m, T)))
	await done(m)

func _apply_mark(arch: String, m: Match, K: ArchKit, T: Hunter) -> void:
	match arch:
		"thief": (K as ThiefKit).add_mark(T, 3, true)
		"gunslinger": (K as GunslingerKit).daze(T, 1.4)
		"mage": (K as MageKit).add_spark(T, 2)
		"ashwick": (K as AshwickKit).add_char(T, 10.0)
		"juggernaut": (K as JuggernautKit).slam_hit[T.get_instance_id()] = m.time
		"rimewright": (K as RimewrightKit).add_chill(T)

## 2. A kit's mark: the icon in the kit's colour with its stacks and time, shrinking, gone at the end; only the
## hunter who put it on sees it (the rival's own plate of you carries nothing).
func _mark(arch: String, icon: String, stacks: int) -> void:
	var s: Array = await _scene(arch)
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	_apply_mark(arch, m, P.ak, T)
	step(m, DT)
	await _frames()
	var it := _only(_row(m, T), icon)
	var shown := not it.is_empty() and float(it["left"]) > 0.0 and float(it["left"]) <= float(it["total"]) + 0.01
	ok("%s: its mark (%s) on the rival's plate with its time left" % [arch, icon], shown, str(_row(m, T)))
	if it.is_empty():
		await done(m)
		return
	ok("%s: in the kit's colour, %d stacks shown" % [arch, stacks],
		Color(it["col"]).is_equal_approx(P.ak.res_col()) and int(it["n"]) == stacks, str(it))
	ok("%s: one icon (a mark takes the place of the status it repeats)" % arch, _row(m, T).size() == 1,
		str(_icons(_row(m, T))))
	step(m, 0.5)
	await _frames()
	var later := _only(_row(m, T), icon)
	ok("%s: the time left shrinks" % arch, not later.is_empty() and float(later["left"]) < float(it["left"]) - 0.3,
		str(later))
	ok("%s: no mark in the rival's own row of you" % arch, m.hud.plates.row(T, P, []).is_empty())
	step(m, float(it["total"]) + 0.3)
	await _frames()
	ok("%s: gone when it runs out" % arch, _only(_row(m, T), icon).is_empty(), str(_row(m, T)))
	await done(m)

## A Boki combo setup (Combos) by the viewer: the bond icon with its window.
func _boki_setup() -> void:
	var s: Array = await _scene("thief")
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	T.marks["check"] = {"team": P.team, "owner": P, "until": m.time + 2.5, "window": 2.5}
	step(m, DT)
	await _frames()
	var it := _only(_row(m, T), "bond")
	ok("a Boki combo setup: the bond icon with its window", not it.is_empty() and float(it["total"]) == 2.5,
		str(_row(m, T)))
	await done(m)

## Vex's Daze and Cinder's Ablaze over the plain Daze and burn: one icon, the kit's, with the kit's time.
func _repeats() -> void:
	var s: Array = await _scene("ashwick")
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	(P.ak as AshwickKit).add_char(T, 40.0)
	step(m, DT)
	await _frames()
	var fire := _row(m, T).filter(func(it): return it["icon"] == "fireball")
	var mine := fire.size() == 1 and Color(fire[0]["col"]).is_equal_approx(P.ak.res_col())
	ok("Ablaze: one fireball, the kit's (burning %.1f s)" % T.burn_t, T.burn_t > 0.0 and mine, str(fire))
	await done(m)

## 3. Everything at once: stun, root, Ground, then the mark, then Daze, Slow, burn; four shown.
func _order() -> void:
	var s: Array = await _scene("thief")
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	for cc in CC:
		_apply_cc(T, String(cc[0]), float(cc[2]))
	T.burn_t = 2.0
	(P.ak as ThiefKit).add_mark(T, 2, true)
	step(m, DT)
	await _frames()
	var icons := _icons(_row(m, T))
	ok("all of it: stun, root, Ground, your mark; four at most (%s)" % [icons],
		icons == ["concussion", "binding", "bolas", "gem"])
	T.stun_t = 0.0
	T.root_t = 0.0
	T.set_meta("gnd_until", 0.0)
	await _frames()
	icons = _icons(_row(m, T))
	ok("those three over: your mark, then Daze, Slow, burn (%s)" % [icons],
		icons == ["gem", "burst", "snare", "fireball"])
	_monster(m, P)
	await done(m)

## 4. A monster's bar: the same row, the viewer's mark after its stun.
func _monster(m: Match, P: Hunter) -> void:
	var mob: Mob = m.spawn_mob("skitter", P.pos + Vector3(3, 0, 3))
	if mob == null:
		ok("a monster to mark", false)
		return
	mob.stun_t = 1.2
	(P.ak as ThiefKit).add_mark(mob, 1, true)
	m.step(DT)
	var icons := _icons(m.hud.plates.row(P, mob, HudPlate.statuses(mob)))
	ok("a stunned, marked monster: the same row (%s)" % [icons], icons == ["concussion", "gem"])

## 5. Past the plate cull range nothing is drawn, row included; near again it is. A rival short of dash charges
## shows none of it on the plate.
func _range_and_dashes() -> void:
	var s: Array = await _scene("thief")
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	T.stun_t = 30.0
	T.teleport(P.pos + Vector3(LabelCull.FAR_M + 10.0, 0, 0))
	m.hud.plates.shown.erase(T.nid)
	await _frames()
	ok("a stunned rival past LabelCull.FAR_M: no plate, no row", not m.hud.plates.shown.has(T.nid))
	T.teleport(P.pos + Vector3(NEAR, 0, 0))
	T.dashes = 0
	await _frames()
	var icons := _icons(_row(m, T))
	ok("back near: the row again (%s)" % [icons], icons == ["concussion"])
	ok("a rival out of dash charges: no dash on the plate", not ("dash" in icons))
	await done(m)

## 6. The payoff hit flashes the body white.
func _payoff(arch: String) -> void:
	var s: Array = await _scene(arch)
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	_apply_mark(arch, m, P.ak, T)
	T.flash_t = 0.0
	match arch:
		"thief":
			(P.ak as ThiefKit).primed_on = T
			T.hurt(10.0, P, {"src": "shot", "ab": ""})
		"gunslinger": T.hurt(10.0, P, {"src": "shot"})
		"mage": (P.ak as MageKit)._blowout(T)
	var stamp := float(T.get_meta(ComboMark.PAY_KEY, -9.0))
	var flashed := absf(stamp - float(m.time)) < 0.1 and T.flash_t >= ComboMark.FLASH_BODY - 0.05
	ok("%s: the payoff hit flashes the body white" % arch, flashed, "stamp %.2f flash %.3f" % [stamp, T.flash_t])
	await done(m)
