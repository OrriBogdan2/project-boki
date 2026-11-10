extends RefCounted
## --boki-dash-check: item 185 (bug 181's root cause). With every Boki species bonded in turn, Sable's dash and
## Kael's RMB Lunge keep the no-Boki baseline: the same path while the move rolls (so the same duration and
## distance), the same kit move on every step (the animation frames) and the same i-frames. Dashes are the hero's
## own (DECISIONS 2026-11-05): a Boki rider that blinks, repeats or cuts a dash fails here. A speed stat is
## allowed (the agency rule, 2026-11-06), so the exit slide may differ by SLIDE_TOL.

const STEPS := 90                # 1.5 s at 60 Hz: the whole move and its recovery
const LUNGE_HOLD := 0.45         # s RMB held: past the tap's Slam, into the Lunge (tools/dash_frames.gd)
const POS_TOL := 0.01            # m a step's position may differ from the baseline's while the move rolls
const SLIDE_TOL := 0.06          # m the end point may differ: the exit hands over at run speed, a speed stat scales it
const CASES := {"thief": "dash", "juggernaut": "rmb"}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIDASH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh training match as `arch` on a levelled strip, the other Hunters far off, no monsters.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 185, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	hunter.set_arch(arch)
	hunter.unlock_all()
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(80, 0, 80))
	var w: World = m.world
	var hx := int(floor(hunter.pos.x))
	var hz := int(floor(hunter.pos.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi])
	for dz in range(-4, 5):
		for dx in range(-4, 16):
			if not w.inb(hx + dx, hz + dz):
				continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			w.stairs.erase(i)
			w.walls.erase(i)
			w.props.erase(i)
			w.bush.erase(i)
	hunter.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	return m

## Bonds `species` to the hunter ("" = no Boki) and returns the step-by-step trace of its dash or Lunge:
## [{x, z, move, roll, inv}] from the press on. Move input only on the dash's press (the Lunge aims at the cursor).
func _trace(m: Match, home: Vector3, slot: String, kin_ref: Kin, species: String) -> Array:
	var hunter: Hunter = m.player
	hunter.kin = kin_ref if species != "" else null
	if hunter.kin:
		kin_ref.species = species
		kin_ref.ks = KinLib.kin(species)
	# far off in every trial, bonded or not, so its body never bumps the hero (a rider acts from anywhere)
	kin_ref.teleport(home + Vector3(-60, 0, -60))
	hunter.apply_kin_bonus()
	hunter.teleport(home)
	hunter.vel = Vector3.ZERO
	hunter.inp["move"] = Vector2.ZERO
	hunter.inp["aim"] = home + Vector3(8, 0.9, 0)
	for i in 40:
		m.step(Match.DT)
	# training keeps spawning monsters: one on his spot stops the Lunge on its first step (a flaky baseline)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	hunter.teleport(home)
	hunter.vel = Vector3.ZERO
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	for key in hunter.ak.cd:
		hunter.ak.cd[key] = 0.0
	hunter.ak.ch_rmb = float(hunter.ak.rmb_charges())
	var out: Array = []
	var held := 0
	if slot == "dash":
		hunter.inp["move"] = Vector2(1, 0)
		hunter.do_dash()
		hunter.inp["move"] = Vector2.ZERO      # no walking after: a Boki's owner move speed is a stat, not the dash
	else:
		hunter.inp["sec"] = true
		hunter.inp["sec_hold"] = true
		held = int(LUNGE_HOLD / Match.DT)
	for i in STEPS:
		if i == held and slot == "rmb":
			hunter.inp["sec"] = false
			hunter.inp["sec_hold"] = false
		kin_ref.teleport(home + Vector3(-60, 0, -60))      # held off: its leash would warp it back into him
		m.step(Match.DT)
		out.append({"x": hunter.pos.x - home.x, "z": hunter.pos.z - home.z, "move": hunter.ak.anim_id,
			"roll": hunter.roll_t > 0.0, "inv": hunter.inv_t > 0.0})
	return out

## The trace's summary: roll steps, i-frame steps, distance at the end, and its kit moves in order.
func _sum(tr: Array) -> String:
	var rolls := 0
	var invs := 0
	var moves: Array = []
	for e in tr:
		rolls += int(e["roll"])
		invs += int(e["inv"])
		if moves.is_empty() or moves[-1] != e["move"]:
			moves.append(e["move"])
	var last: Dictionary = tr[-1]
	return "%d roll steps, %d i-frame steps, %.2f m, moves %s" % [rolls, invs,
		Vector2(last["x"], last["z"]).length(), ",".join(moves)]

## The first step where `tr` leaves the baseline, or -1. The path must match while the move rolls; after it
## the exit slide carries the run (HunterMove.dash_exit), which a Boki's speed stat legitimately scales, so only
## the end point is held to SLIDE_TOL there.
func _diverges(base: Array, tr: Array) -> int:
	for i in base.size():
		var a: Dictionary = base[i]
		var b: Dictionary = tr[i]
		var off := Vector2(a["x"] - b["x"], a["z"] - b["z"]).length()
		var rolling: bool = a["roll"] or (i > 0 and base[i - 1]["roll"])
		if (rolling and off > POS_TOL) or off > SLIDE_TOL \
				or a["move"] != b["move"] or a["roll"] != b["roll"] or a["inv"] != b["inv"]:
			return i
	return -1

## One fresh match per trial, so every dash starts from the same state (Sable's cartwheels alternate sides).
func _trial(main: Node, arch: String, species: String) -> Array:
	var m := _match(main, arch)
	var hunter: Hunter = m.player
	var kin_ref: Kin = hunter.kin
	var out: Array = []
	if kin_ref != null:
		out = _trace(m, hunter.pos, CASES[arch], kin_ref, species)
	m.queue_free()
	await main.get_tree().process_frame
	return out

func run(main: Node) -> void:
	Save.no_write = true
	if Save.d["roster"].is_empty():
		var tk := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(tk)
		Save.d["active"] = tk["uid"]
	var species: Array = Data.KIN.keys()
	species.sort()
	for arch in CASES:
		var slot: String = CASES[arch]
		var base: Array = await _trial(main, arch, "")
		ok(not base.is_empty(), "%s: the match gave the hunter a Boki to swap species on" % arch)
		if base.is_empty():
			continue
		print("BOKIDASH %s %s baseline: %s" % [arch, slot, _sum(base)])
		ok(not _sum(base).begins_with("0 roll"), "%s: the baseline %s travels" % [arch, slot])
		for sp: String in species:
			var tr: Array = await _trial(main, arch, sp)
			var at := _diverges(base, tr)
			ok(at < 0, "%s %s with %s matches the no-Boki baseline%s" % [arch, slot, sp,
				"" if at < 0 else " (leaves it at step %d: %s)" % [at, _sum(tr)]])
	print("BOKIDASH DONE, failures: %d" % bad)
	main.get_tree().quit()
