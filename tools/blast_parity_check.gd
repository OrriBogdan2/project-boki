extends RefCounted
## --blast-parity-check: how a shot's explosion lands (Blast, content/rules/blast.json) and the armour ring's pitch.
##  1. The falloff curve: full to a quarter of the radius, 89 / 54 / 33 percent at half, three quarters and the edge.
##  2. In play: a foe at the middle, at half the radius and at the edge takes those shares of the same blast.
##  3. Rock between the blast and the foe: no damage; the same blast with "boom_open" hurts.
##  4. The armour ring's pitch falls from 1 on a full shell to the rules' pitch_empty on an empty one.
## Never touches the save.

const DT := 1.0 / 60.0
const RADIUS := 4.0
const DMG := 40.0

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("BLASTPAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_curve()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 41, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var foe := _foe(m)
	_in_play(m, foe)
	_cover(m, foe)
	_armour_pitch(foe)
	print("BLASTPAR DONE, failures: %d" % bad)
	main.get_tree().quit()


func _curve() -> void:
	var want := [[0.0, 1.0], [0.25, 1.0], [0.5, 0.89], [0.75, 0.54], [1.0, 0.33], [1.6, 0.33]]
	var all_ok := true
	for p in want:
		all_ok = all_ok and is_equal_approx(Blast.curve_k(float(p[0])), float(p[1]))
	ok(all_ok, "curve: 1 to a quarter radius, 0.89 at half, 0.54 at three quarters, 0.33 at the edge and past it")
	var falling := true
	for i in 100:
		falling = falling and Blast.curve_k(float(i + 1) / 100.0) <= Blast.curve_k(float(i) / 100.0)
	ok(falling, "curve: never rises with distance")


func _foe(m: Match) -> Hunter:
	for h in m.hunters:
		if h.team != m.player.team:
			h.ctrl = "idle"
			return h
	return null


## The hp a foe loses to one blast of DMG at `at` (the player's shot; `open` skips the cover test).
func _lost(m: Match, foe: Hunter, at: Vector3, open := false) -> float:
	foe.hp = foe.max_hp
	foe.armor = 0.0
	foe.hurt_at = -100.0
	foe.vel = Vector3.ZERO
	var extra := {"boom": RADIUS}
	if open:
		extra["boom_open"] = true
	m.spawn_shot(m.player, at + Vector3(0, 0.4, 0), Vector2.ZERO, DMG, 0.02, 0.1, Color.WHITE, extra)
	for i in 12:
		m.step(DT)
	return foe.max_hp - foe.hp


## A flat, rock-free row 5 m long near the player: [start point, +x direction as a Vector3].
func _row(m: Match, length: float) -> Vector3:
	var w := m.world
	for gx in range(4, w.w - 8):
		for gz in range(4, w.h - 4):
			var a := Vector3(gx + 0.5, w.ground_at(gx + 0.5, gz + 0.5), gz + 0.5)
			var flat := true
			for i in range(0, int(length) + 2):
				flat = flat and not w.is_block(a.x + i, a.z) and absf(w.ground_at(a.x + i, a.z) - a.y) < 0.05
				flat = flat and w.ground_at(a.x + i, a.z) > World.VOID + 1.0
			if flat:
				return a
	return Vector3.INF


func _in_play(m: Match, foe: Hunter) -> void:
	var a := _row(m, 6.0)
	ok(a != Vector3.INF, "found a flat open row for the blast")
	m.player.teleport(a + Vector3(-9.0, 0, 0))
	foe.teleport(a + Vector3(0.4, 0, 0))
	_lost(m, foe, a)  # (the first hit on a fresh hunter is softened: not what is measured here)
	foe.teleport(a + Vector3(0.4, 0, 0))
	var core := _lost(m, foe, a)
	ok(core > 0.0, "a blast hurts a foe near its middle (%.1f hp)" % core)
	for want in [[0.5, 0.89], [0.75, 0.54], [1.0, 0.33]]:
		foe.teleport(a + Vector3(RADIUS * float(want[0]), 0, 0))
		var share := _lost(m, foe, a) / core
		ok(
			absf(share - float(want[1])) < 0.03,
			"%.2f of the radius: %.2f of the core damage (want %.2f)" % [want[0], share, want[1]]
		)


## A rock tile with open ground a few metres either side of it, in the same row.
func _cover(m: Match, foe: Hunter) -> void:
	var w := m.world
	var at := Vector3.INF
	for gx in range(6, w.w - 8):
		for gz in range(4, w.h - 4):
			var rock := Vector3(gx + 0.5, 0, gz + 0.5)
			var near_ok := not w.is_block(rock.x - 2, rock.z) and not w.is_block(rock.x + 2, rock.z)
			if (
				w.is_block(rock.x, rock.z)
				and near_ok
				and absf(w.ground_at(rock.x - 2, rock.z) - w.ground_at(rock.x + 2, rock.z)) < 0.05
				and w.ground_at(rock.x - 2, rock.z) > World.VOID + 1.0
			):
				at = Vector3(rock.x - 2, w.ground_at(rock.x - 2, rock.z), rock.z)
				break
		if at != Vector3.INF:
			break
	ok(at != Vector3.INF, "found a rock with open ground on both sides")
	if at == Vector3.INF:
		return
	m.player.teleport(at + Vector3(-9.0, 0, 0))
	foe.teleport(at + Vector3(3.2, 0, 0))
	var behind := _lost(m, foe, at)
	var open := _lost(m, foe, at, true)
	ok(behind == 0.0, "rock between the blast and the foe: no damage (%.1f)" % behind)
	ok(open > 0.0, "the same blast with boom_open hurts through it (%.1f)" % open)
	foe.teleport(at + Vector3(-1.0, 0, 0))
	ok(_lost(m, foe, at) > 0.0, "the same blast hurts a foe on its own side of the rock")


func _armour_pitch(foe: Hunter) -> void:
	foe.max_armor = 100.0
	foe.armor = 100.0
	var full := ArmorRules.confirm_pitch(foe)
	foe.armor = 50.0
	var half := ArmorRules.confirm_pitch(foe)
	foe.armor = 0.0
	var empty := ArmorRules.confirm_pitch(foe)
	ok(is_equal_approx(full, 1.0), "armour ring on a full shell: pitch %.2f (want 1)" % full)
	ok(empty < half and half < full, "the pitch falls as the shell runs out (%.2f > %.2f > %.2f)" % [full, half, empty])
	ok(is_equal_approx(empty, 0.7), "an empty shell: %.2f (rules pitch_empty 0.7)" % empty)
	ok(is_equal_approx(ArmorRules.confirm_pitch(null), 1.0), "a target that is not a Hunter: pitch 1")
