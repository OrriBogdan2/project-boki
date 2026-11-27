extends RefCounted
## --shot-falloff-check: a weapon's shot loses damage with the distance it flew, and a ramp-up weapon starts weak
## (ShotFalloff, content/rules/shot_falloff.json; applied in Match._shot_apply).
##  1. The classes: the rifle's falloff is the medium curve squeezed into its range, the sniper's ramp is the long ramp.
##  2. In play: the same shot lands on a foe up close, half way down the slope and at the weapon's range;
##     the damage ratios follow the curve.
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
	_curve(m, foe, rifle, "falloff: rifle")
	_curve(m, foe, sniper, "ramp + falloff: sniper")
	print("FALLOFF DONE, failures: %d" % bad)
	main.get_tree().quit()


func _wpn(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/weapons/%s.json" % id))["primary"]


func _data() -> void:
	var ex := {}
	ShotFalloff.add(ex, _wpn("rifle"), 9.5)
	var k := 9.5 / 17.5
	ok(ex.has("farf") and not ex.has("near"), "rifle: a falloff, no ramp")
	var fa: Array = ex["farf"]
	var squeezed: bool = absf(float(fa[0]) - 10.0 * k) < 0.01 and absf(float(fa[2]) - 9.5) < 0.01
	ok(squeezed and is_equal_approx(float(fa[1]), 0.4), "rifle: medium curve squeezed to 9.5 m, floor 0.4")
	var sx := {}
	ShotFalloff.add(sx, _wpn("sniper"), 16.0)
	var ramp_ok: bool = sx.has("near") and sx["near"].size() == 3 and is_equal_approx(float(sx["near"][0]), 0.5)
	ok(ramp_ok, "sniper: a ramp from half damage")
	var long_end := 17.5
	var ks := 16.0 / long_end
	var sq: bool = absf(float(sx["near"][2]) - 1.5 * ks) < 0.01 and absf(float(sx["near"][1]) - 9.0 * ks) < 0.01
	ok(sq, "sniper: long ramp squeezed to 16 m")
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


## Damage the foe loses to one `dmg` shot of `w` (its extras from ShotFalloff) that flew `trav` m before landing.
func _lost(m: Match, foe: Hunter, w: Dictionary, trav: float) -> float:
	var extra := {}
	ShotFalloff.add(extra, w, float(w["range"]))
	foe.hp = foe.max_hp
	foe.armor = 0.0
	foe.hurt_at = -100.0
	foe.vel = Vector3.ZERO
	var s := {"x": extra, "by": m.player, "dmg": 10.0, "start": FLAT, "vel": Vector2(1, 0), "col": Color.WHITE}
	s["team"] = m.player.team
	m._shot_apply(s, Vector3(trav, 0, 0), foe)
	return foe.max_hp - foe.hp


func _curve(m: Match, foe: Hunter, w: Dictionary, what: String) -> void:
	for i in 3:
		_lost(m, foe, w, 5.0)  # (the first hits on a fresh hunter are softened: not what is measured here)
	var rng := float(w["range"])
	var ref := _lost(m, foe, w, 0.0 if w.has("ramp") else 0.5)
	ok(ref > 0.0, "%s: a shot hurts (%.2f hp)" % [what, ref])
	var mid: Dictionary = ShotFalloff.data()["falloff"][w["falloff"]]
	var k := minf(1.0, rng / float(mid["end"]))
	var full := ref
	if w.has("ramp"):
		full = _lost(m, foe, w, 8.0)  # past the ramp, before the falloff: the full damage
	var near := _lost(m, foe, w, 0.2)
	var far := _lost(m, foe, w, rng)
	var half := _lost(m, foe, w, (float(mid["start"]) * k + rng) * 0.5)
	var floor_k: float = float(mid["floor"])
	var far_say := "%s: at its range the shot does the floor share (%.2f of full, want %.2f)"
	ok(absf(far / full - floor_k) < 0.02, far_say % [what, far / full, floor_k])
	var want_half := (1.0 + floor_k) * 0.5
	var half_say := "%s: half way down the slope it does %.2f of full (want %.2f)"
	ok(absf(half / full - want_half) < 0.03, half_say % [what, half / full, want_half])
	if w.has("ramp"):
		ok(absf(near / full - 0.5) < 0.03, "%s: up close it does half damage (%.2f)" % [what, near / full])
	else:
		ok(absf(near / full - 1.0) < 0.02, "%s: up close it does full damage (%.2f)" % [what, near / full])
