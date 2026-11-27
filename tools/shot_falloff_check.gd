extends RefCounted
## --shot-falloff-check: a weapon's shot loses damage with the distance it flew, and a ramp-up weapon starts weak
## (ShotFalloff, content/rules/shot_falloff.json, reference metres; applied in Match._shot_apply).
##  1. The classes: the sniper gets the long falloff and ramp, Meeko's crook the seraph curve, in metres as they are.
##  2. In play: the same shot lands on a foe up close, mid-slope and at the weapon's range; the ratios follow the
##     curve, and the rifle (9.5 m, before the medium start at 10 m) does full damage at its range.
##  3. Every weapon names only classes that exist, and none keeps the old close_mult/far_mult keys.
## Never touches the save.

const FLAT := Vector3(0, 0, 0)

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("FALLOFF %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_data()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 41, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var foe: Hunter = null
	for h in m.hunters:
		if h.team != m.player.team:
			h.ctrl = "idle"
			foe = h
			break
	var rifle := _wpn("rifle")
	var sniper := _wpn("sniper")
	_curve(m, foe, sniper, "sniper", 10.0, {0.2: 0.5, 5.25: 0.75, 15.0: 0.7, 16.0: 0.58})
	_curve(m, foe, _wpn("lantern_crook"), "crook", 2.0, {0.3: 1.0, 4.75: 1.0, 6.75: 1.0 - 0.5 * 2.0 / 4.75, 8.4: 0.616})
	_curve(m, foe, rifle, "rifle", 2.0, {9.5: 1.0})
	print("FALLOFF DONE, failures: %d" % bad)
	main.get_tree().quit()


func _wpn(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/weapons/%s.json" % id))["primary"]


func _data() -> void:
	var sx := {}
	ShotFalloff.add(sx, _wpn("sniper"))
	ok(sx.get("farf", []) == [12.5, 0.4, 17.5], "sniper: long falloff, 12.5-17.5 m to 40%% (%s)" % [sx.get("farf")])
	var ramp_say := "sniper: long ramp, half damage to 1.5 m, full at 9 m (%s)" % [sx.get("near")]
	ok(sx.get("near", []) == [0.5, 1.5, 9.0], ramp_say)
	var cx := {}
	ShotFalloff.add(cx, _wpn("lantern_crook"))
	ok(cx.get("farf", []) == [4.75, 0.5, 9.5] and not cx.has("near"), "crook: seraph 4.75-9.5 m to 50%, no ramp")
	var cls: Dictionary = ShotFalloff.data()
	var clean := true
	for f in DirAccess.get_files_at("res://content/weapons"):
		if not f.ends_with(".json"):
			continue
		var w: Dictionary = _wpn(f.get_basename())
		clean = clean and not w.has("close_mult") and not w.has("far_mult") and not w.has("far_start")
		clean = clean and (not w.has("falloff") or cls["falloff"].has(w["falloff"]))
		clean = clean and (not w.has("ramp") or cls["ramp"].has(w["ramp"]))
	ok(clean, "every weapon names a known class; no old close_mult / far_mult keys")


## Damage the foe loses to one 10-damage shot of `w` (its extras from ShotFalloff) that flew `trav` m.
func _lost(m: Match, foe: Hunter, w: Dictionary, trav: float) -> float:
	var extra := {}
	ShotFalloff.add(extra, w)
	foe.hp = foe.max_hp
	foe.armor = 0.0
	foe.hurt_at = -100.0
	foe.vel = Vector3.ZERO
	var s := {"x": extra, "by": m.player, "dmg": 10.0, "start": FLAT, "vel": Vector2(1, 0), "col": Color.WHITE}
	s["team"] = m.player.team
	m._shot_apply(s, Vector3(trav, 0, 0), foe)
	return foe.max_hp - foe.hp


## The shot of `w` at each distance in `want` ({metres: share of full damage}); `full_at` is a distance with no curve.
func _curve(m: Match, foe: Hunter, w: Dictionary, what: String, full_at: float, want: Dictionary) -> void:
	for i in 3:
		_lost(m, foe, w, full_at)  # (the first hits on a fresh hunter are softened: not what is measured here)
	var full := _lost(m, foe, w, full_at)
	ok(full > 0.0, "%s: a shot hurts (%.2f hp at %.1f m)" % [what, full, full_at])
	for d in want:
		var got := _lost(m, foe, w, float(d)) / maxf(0.01, full)
		var say := "%s: at %.2f m it does %.2f of full (want %.2f)" % [what, d, got, want[d]]
		ok(absf(got - float(want[d])) < 0.03, say)
