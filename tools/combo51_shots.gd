extends "res://tools/breah_shots.gd"
## --combo51-shots --shots-dir=<dir> --combo51-hero=juggernaut|dredge|ashwick: owner item 51's new combos for
## Zedran, Dredge and Linwick as strips (the Breah rig's 3-wide grid of crops round the hero, tools/breah_shots.gd)
## in a live Arena match, under xvfb with a renderer. <dir>/captions.txt gets "file: caption" per file.
## --combo51-part=<part> takes `_<hero>_<part>` instead (Zedran's "chain": the Warchain's tether and pull, on a
## map island long enough for its 24 m).

const LONG := 30                # m of flat ground the chain strips need, east of the spot

var part := ""

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--combo51-hero="):
			who = arg.substr(15)
		if arg.begins_with("--combo51-part="):
			part = arg.substr(15)
	hero_name = Arch.name_of(who).to_lower()
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await Callable(self, "_%s" % (who if part == "" else who + "_" + part)).call()
	_write_captions()
	print("COMBO51SHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## The parts' rig: an expedition map (the Arena's islands are too small for the chain), the spot on a flat run of
## LONG m.
func _setup() -> void:
	if part == "":
		await super._setup()
		return
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"arch": who, "cls": Arch.weight(who), "weapon": Arch.signature(who)}
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _long_spot(P.pos)
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	for x in m.hunters:
		if x != P and x != T:
			x.teleport(home + Vector3(-30, 0, 30))
	P.unlock_all()
	P.lvl = 6
	if m.hud: m.hud.guide_hidden = true       # (the kit panel would sit over the chain)
	await _reset(7.0)

func _long_spot(start: Vector3) -> Vector3:
	var W = m.world
	for z in range(8, W.h - 8, 2):
		for x in range(12, W.w - LONG - 4, 2):
			if _run_flat(W, x, z):
				return Vector3(x + 0.5, int(W.level[W.idx(x, z)]) * World.LEVEL, z + 0.5)
	return start

func _run_flat(W, x: int, z: int) -> bool:
	var lv: int = int(W.level[W.idx(x, z)])
	for dz in range(-3, 4):
		for dx in range(-10, LONG):
			var i: int = W.idx(x + dx, z + dz)
			var odd: bool = W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i)
			if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or odd:
				return false
	return true

## The step at `when` s into a _go (t steps by DT, so an exact float window can be skipped).
func _at(t: float, when: float) -> bool:
	return absf(t - when) < DT * 0.5

## Zedran: the Searing Wave held through the Rampage; the Slam Drive; an air dash in the Meteor Drop's hang.
func _juggernaut() -> void:
	var K: JuggernautKit = P.ak
	await _reset(10.0)
	var wave := func(t: float):
		P.inp["fire"] = t < 1.15
		if _at(t, 0.45):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t >= 0.5:
			P.inp["move"] = Vector2.ZERO
	var marks := _strip(
		"combo_wave_rampage_strip",
		"Zedran (item 51): the Searing Wave charging; Shift with it held, the Rampage's crouch; the drive, the"
			+ " charge kept; out of the drive, the wind-up pose back; let go, the wave leaves; the follow-through",
		[0.38, 0.55, 0.72, 0.98, 1.2, 1.4]
	)
	await _go(1.6, wave, marks)
	await _reset(7.5)
	var slam := func(t: float):
		if _at(t, 0.1):
			K.press_rmb()
		if _at(t, 0.25):
			P.do_dash()
	var smarks := _strip(
		"combo_slam_drive_strip",
		"Zedran (item 51): the Slam winding up; Shift in it, the Slam Drive goes at once along the strike's aim,"
			+ " the overhead pose kept; driving in; the drive's end; the Slam lands where it arrived; recovery",
		[0.2, 0.3, 0.42, 0.56, 0.76, 0.95]
	)
	await _go(1.2, slam, smarks)
	await _reset(6.0)
	var drop := func(t: float):
		P.inp["jump"] = t < DT
		if _at(t, 0.25):
			K.press_rmb()
		if _at(t, 0.36):
			P.inp["move"] = Vector2(0, 1)
			P.do_dash()
		if t >= 0.4:
			P.inp["move"] = Vector2.ZERO
	var dmarks := _strip(
		"combo_meteor_airdash_strip",
		"Zedran (item 51): the Meteor Drop's hang over its marker; Shift, the air dash goes in the gather pose;"
			+ " the dash's end, off to the side; the dive back onto the marker; the impact; the recovery",
		[0.34, 0.42, 0.55, 0.64, 0.76, 1.0]
	)
	await _go(1.3, drop, dmarks)

## Dredge: Shift in the Anchor's wind-up; Shift in the Broadside's charge.
func _dredge() -> void:
	await _reset(8.0)
	var anchor := func(t: float):
		if _at(t, 0.1):
			P.ak.use_e()
		if _at(t, 0.2):
			P.do_dash()
	var marks := _strip(
		"combo_anchor_barge_strip",
		"Dredge (item 51): the Anchor's wind-up, fist raised; Shift in it, the barge goes at once with the fist"
			+ " still up; arriving; the slam lands where he arrived; the dust; recovery",
		[0.16, 0.24, 0.34, 0.5, 0.62, 0.85]
	)
	await _go(1.1, anchor, marks)
	P.lvl = 6
	await _reset(8.0)
	var blast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		if _at(t, 0.5):
			P.inp["move"] = Vector2(0, 1)
			P.do_dash()
		if t >= 0.55:
			P.inp["move"] = Vector2.ZERO
	var bmarks := _strip(
		"combo_broadside_barge_strip",
		"Dredge (item 51): the Broadside charging behind its fan; Shift, the barge goes at once in the bracing"
			+ " pose; arrived, the fan has followed him; the first wave; the second wave; done",
		[0.4, 0.56, 0.8, 1.25, 1.85, 2.1]
	)
	await _go(2.3, blast, bmarks)

## Linwick: the lance held through a ram; Shift in the flight; a jump off the flight.
func _ashwick() -> void:
	P.lvl = 6
	await _reset(11.0)
	var lance := func(t: float):
		P.inp["fire"] = t < 1.4
		if _at(t, 0.6):
			P.do_dash()
	var marks := _strip(
		"combo_lance_ram_strip",
		"Linwick (item 51): the lance roaring; Shift with it held, the ram goes and the stream goes out; still"
			+ " ramming; the ram's end, the stream back at once (no pilot, no gap); roaring on; let go",
		[0.5, 0.66, 0.78, 0.94, 1.15, 1.5]
	)
	await _go(1.6, lance, marks)
	await _reset(14.0)
	P.teleport(home + Vector3(-5.0, 0, 0))      # (room on the island for the boosted flight)
	var poof := func(t: float):
		if (_at(t, 0.1)) or (_at(t, 0.8)):
			P.ak.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)        # (the second press lands early, still over the island)
		P.inp["dash"] = _at(t, 0.55)
		P.inp["move"] = Vector2(1, -0.4).normalized() if t >= 0.55 and t < 0.6 else Vector2.ZERO
	var pmarks := _strip(
		"combo_flight_poof_strip",
		"Linwick (item 51): flying over the carpet; Shift, a poof from the bellows (the air dash spent); the"
			+ " flight faster and bent its way; flying on; X again, landing; on foot, the carpet behind",
		[0.4, 0.58, 0.66, 0.74, 0.86, 1.1]
	)
	await _go(1.25, poof, pmarks)
	await _reset(14.0)
	var leap := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		P.inp["jump"] = (_at(t, 0.7)) or (_at(t, 0.95))
		P.inp["glide"] = t >= 0.95
	var lmarks := _strip(
		"combo_flight_leap_strip",
		"Linwick (item 51): flying; a jump leaps off the jet, its speed kept; rising; the glider opens with the"
			+ " flight's speed; gliding on; the carpet left behind",
		[0.6, 0.76, 0.88, 1.05, 1.3, 1.6]
	)
	await _go(1.7, leap, lmarks)

## Zedran's Warchain, as whole views (the chain is longer than a strip crop): it pays out as he backs away and
## holds taut at 24 m; backing away then pulling slingshots him in; a strafe held in the pull curves him in beside.
func _juggernaut_chain() -> void:
	var K: JuggernautKit = P.ak
	await _reset(-8.0)
	var taut := func(t: float):
		if _at(t, 0.1):
			K.cd["e"] = 0.0
			K.use_e()
		P.inp["move"] = Vector2(1, 0) if t > 0.4 else Vector2.ZERO
		_aim(T.pos)
	await _go(4.9, taut, [
		[0.45, "full", "warchain_taut_1", "Zedran Warchain: hooked on the dummy 8 m away, he starts backing off"],
		[2.6, "full", "warchain_taut_2", "Zedran Warchain: ~17 m, the chain paying out after him"],
		[4.6, "full", "warchain_taut_3", "Zedran Warchain: at 24 m it is taut and hot and holds: he keeps walking but"
				+ " stays at its end"]], -9.0)
	K.warchain.snap("")
	await _reset(9.0)
	var sling := func(t: float):
		if _at(t, 0.1):
			K.cd["e"] = 0.0
			K.use_e()
		P.inp["move"] = Vector2(-1, 0) if t > 0.45 and t < 1.0 else Vector2.ZERO
		if _at(t, 0.95):
			K.use_e()
		_aim(T.pos)
	await _go(1.5, sling, [
		[0.9, "full", "warchain_sling_1", "Zedran Warchain: hooked, backing away"],
		[1.07, "full", "warchain_sling_2", "Zedran Warchain: E while backing away: the slingshot, flying in faster"],
		[1.25, "full", "warchain_sling_3", "Zedran Warchain: arrived on the dummy, still moving"]], 4.5)
	await _reset(9.0)
	var steer := func(t: float):
		if _at(t, 0.1):
			K.cd["e"] = 0.0
			K.use_e()
		if _at(t, 0.6):
			K.use_e()
		P.inp["move"] = Vector2(0, 1) if t > 0.6 else Vector2.ZERO
		_aim(T.pos)
	await _go(1.3, steer, [
		[0.68, "full", "warchain_steer_1", "Zedran Warchain: E with a strafe held: the pull swings out that way"],
		[0.8, "full", "warchain_steer_2", "Zedran Warchain: curving round toward the dummy"],
		[0.95, "full", "warchain_steer_3", "Zedran Warchain: arriving beside it, not on its line"]], 4.5)
