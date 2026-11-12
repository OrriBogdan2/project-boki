class_name GilKit
extends ArchKit
## Gil, the Novice Mage (content/archetypes/gil.json). A pet fish a spell stood up on two legs: everything out
## here is new to him. A control mage: Fencer (three rapier thrusts, every one steps in, the third slows),
## Grab Bag (a shuffled bag of potions, the next one always shown), Ground Swim (a dash under the ground that
## knocks up where he surfaces), Riptide (a spin that sends a waterspout down a line) and Tidal Wave (X: he
## surfs a wave down a line, untargetable, and lands with a shield). Passive Fish Out of Water: three different
## potion effects on one foe inside 5s Beach them. Every number lives in the JSON.

var bag: Array = []                 # the potions still in the bag; the last one is the next throw
var rng := RandomNumberGenerator.new()
var flying: Array = []              # thrown potions in the air: {at, from, t, left, v}
var puddles: Array = []             # slime puddles: {at, r, left, k, tick}
var marks := {}                     # foe instance id -> {mark: time it landed}
var beach_at := {}                  # foe instance id -> time it can be Beached again
var combo_n := 0
var combo_at := -9.0
var third_until := -9.0             # the third thrust's hits slow until then
var swim_t := 0.0                   # Ground Swim under way
var spin_t := -1.0                  # Riptide spin time (-1: not spinning)
var spin_tick := 0.0
var spouts: Array = []              # moving waterspouts: {p, y, dir, left, w, spd, hit}
var wave := {}                      # the Tidal Wave under way
var untarget_t := 0.0
var glow_t := 0.0
var aim_t := 0.0

func _setup() -> void:
	rng.seed = hash("gil_bag_%d" % h.get_instance_id())
	_refill()

# ------------------------------------------------------------------ the bag
func _refill() -> void:
	bag.clear()
	var counts: Dictionary = rmb_def().get("bag", {})
	for v in counts:
		for i in int(counts[v]):
			bag.append(String(v))
	# Fisher-Yates on the kit's own seeded generator (the match decides the order, not a global roll)
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = bag[i]
		bag[i] = bag[j]
		bag[j] = t

## The potion the next throw takes (shown on the HUD and glowing in his hand).
func next_vial() -> String:
	if bag.is_empty(): _refill()
	return String(bag.back()) if not bag.is_empty() else "thunder"

func _draw_vial() -> String:
	var v := next_vial()
	bag.pop_back()
	if bag.is_empty(): _refill()
	return v

func vial_def(v: String) -> Dictionary:
	return (rmb_def().get("vials", {}) as Dictionary).get(v, {})

func res_text() -> String:
	return String(vial_def(next_vial()).get("name", ""))

func slot_info(slot: String) -> Dictionary:
	var out := super.slot_info(slot)
	if slot in ["sec", "utility"]:
		var vd := vial_def(next_vial())
		out["short"] = String(vd.get("name", out["short"]))
		out["col"] = col_of(vd)
		out["next"] = next_vial()
	return out

# ------------------------------------------------------------------ LMB: Fencer
func lmb_override(held: bool, _dt: float) -> bool:
	if h.wid != "swordfish" or KinMerge.active(h):
		return false
	if not held or h.fire_cd > 0.0 or not h.can_fire():
		return true
	var ld := lmb_def()
	if m.time - combo_at > float(ld["chain_reset"]): combo_n = 0
	var i := combo_n % 3
	combo_at = m.time
	combo_n += 1
	h.combo_i = i + 1
	h._lunge(float(ld["step"][i]))
	if i == 2: third_until = m.time + 0.3
	h._strike(float(ld["dmg"][i]), float(ld["reach"][i]), float(ld["arc"][i]), float(ld["kb"]), {"heavy": i == 2})
	h.fire_cd = float(ld["rate"]) * (1.5 if i == 2 else 1.0)
	return true

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	# the swing's rays reach on_deal as "shot" hits (Gil's only shots; the vials are "abil")
	if String(o.get("src", "")) == "shot" and m.time < third_until and t != null and not t.dead:
		var ld := lmb_def()
		var slow := {"slow": float(ld["slow_t"]), "slow_k": float(ld["slow"]), "src": "abil", "ab": "primary"}
		slow["tags"] = ["primary", "lunge"]
		t.hurt(0.1, h, slow)

# ------------------------------------------------------------------ RMB: Grab Bag
func fire_rmb(c: Dictionary) -> void:
	if not spend_rmb():
		return
	var rd := rmb_def()
	var v := _draw_vial()
	var vd := vial_def(v)
	var at: Vector3
	var ft: float
	if c.get("air", false):
		at = ground(h.pos)
		ft = 0.25
	else:
		at = AimMode.place(h, float(rd["range"]) * (float(rd["hold_range"]) if c.get("hold", false) else 1.0))
		ft = float(rd["flight"]) + float(rd["flight_per_m"]) * Vector2(at.x - h.pos.x, at.z - h.pos.z).length()
	last_variant = String(c.get("variant", "tap"))
	tele_circle(at, float(vd["radius"]), col_of(vd), ft)
	flying.append({"at": at, "from": h.pos + Vector3(0, 1.3, 0), "t": ft, "left": ft, "v": v})
	m.sfx("throw", h.pos, -4.0, 1.15)

func rmb_hold_tick(t: float) -> void:
	# held past the tap: the landing circle follows the cursor, 50% further
	if t < float(rmb_def().get("hold", 0.25)):
		return
	if m.time >= aim_t:
		aim_t = m.time + 0.1
		var rd := rmb_def()
		var vd := vial_def(next_vial())
		m.fx.ring(AimMode.place(h, float(rd["range"]) * float(rd["hold_range"])), float(vd["radius"]), col_of(vd), 0.12)

func _shatter(it: Dictionary) -> void:
	var v := String(it["v"])
	var vd := vial_def(v)
	var at: Vector3 = it["at"]
	var r := float(vd["radius"])
	var col := col_of(vd)
	m.fx.burst(at + Vector3(0, 0.4, 0), col, 18 if v != "zeep" else 34, 5.0, 0.5, 6.0)
	m.fx.ring(at, r, col, 0.4)
	var sound := "boom" if v in ["thunder", "zeep", "fire"] else "whoosh"
	m.sfx(sound, at, -3.0, 1.2 if v != "zeep" else 0.8)
	var p := power("sec")
	for f in foes_in(at, r, 3.0):
		var o := {"src": "abil", "ab": "utility", "tags": ["utility", "gil_" + v]}
		var to := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		match v:
			"thunder":
				if to.length() < float(vd["core"]) + f.r:
					o["stun"] = float(vd["stun"])
					o["dr"] = true
			"slime":
				o["slow"] = float(vd["slow"])
				o["slow_k"] = float(vd["slow_k"])
			"air":
				var dir := to.normalized() if to.length() > 0.1 else h.aim_dir()
				o["kb"] = dir * float(vd["push"]) * 3.0
				o["lift"] = 3.0
			"fire":
				o["burn"] = float(vd["burn"])
				o["burn_for"] = float(vd["burn_t"])
			"zeep":
				o["lift"] = float(vd["lift"])
				o["stun"] = float(vd["knockup"])
				o["dr"] = true
		f.hurt(float(vd["dmg"]) * p, h, o)
		_mark(f, String(vd.get("mark", v)), col)
	if v == "slime":
		puddles.append({"at": at, "r": float(vd["puddle_r"]), "left": float(vd["puddle_t"]),
			"k": float(vd["puddle_k"]), "tick": 0.0})

# ------------------------------------------------------------------ passive: Fish Out of Water
func _mark(f: Ent, mk: String, col: Color) -> void:
	if f == null or f.dead:
		return
	var pd: Dictionary = d.get("passive", {})
	var key := f.get_instance_id()
	var have: Dictionary = marks.get(key, {})
	have[mk] = m.time
	for k in have.keys():
		if m.time - float(have[k]) > float(pd.get("window", 5.0)): have.erase(k)
	marks[key] = have
	var n := have.size()
	if n >= int(pd.get("need", 3)) and m.time >= float(beach_at.get(key, -99.0)):
		marks.erase(key)
		beach_at[key] = m.time + float(pd.get("cd", 8.0))
		f.hurt(0.1, h, {"stun": float(pd.get("stun", 0.75)), "src": "abil", "ab": "passive",
			"tags": ["passive", "beached"]})
		m.fx.burst(f.pos + Vector3(0, 0.6, 0), res_col(), 20, 4.0, 0.6, 8.0)
		m.sfx("unlock", f.pos, -4.0, 0.7)
		ComboMark.payoff(m, h, f)        # the Beach payoff: the foe flashes
	else:
		m.fx.word(f.pos + Vector3(0, 2.2, 0), "%d/%d" % [mini(n, 3), int(pd.get("need", 3))], col)

## The splash marks on `f`, for the ComboMark tag: a pip per different mark (three Beach it); the ring is the
## time the oldest mark has left (when it runs out the count drops).
func combo_read(f: Ent) -> Dictionary:
	var pd: Dictionary = d.get("passive", {})
	var win := float(pd.get("window", 5.0))
	var n := 0
	var left := win
	for stamp: float in marks.get(f.get_instance_id(), {}).values():
		var rest: float = win - (m.time - stamp)
		if rest > 0.0:
			n += 1
			left = minf(left, rest)
	if n == 0:
		return {}
	return {"icon": "tonic", "n": n, "max": int(pd.get("need", 3)), "left": left, "total": win}

## Different marks on a foe right now (tests and the HUD).
func marks_on(f: Ent) -> int:
	return int(combo_read(f).get("n", 0))

# ------------------------------------------------------------------ dash: Ground Swim
func on_dash(use_ex: bool) -> bool:
	if spin_t >= 0.0 or not wave.is_empty():
		return true             # the spin and the wave hold him (content/dash_flow/gil.json: lock)
	var dd := dash_def()
	if use_ex and not h.grounded:
		# the class long dash in the air: no ground to swim through, so no dive and no surfacing
		if spend_dash(true):
			travel(float(dd["dist"]), float(dd["time"]), {"trail": "dust"})
		return true
	if not spend_dash(false):
		return true
	travel(float(dd["dist"]), float(dd["time"]), {"trail": "dust"})
	swim_t = float(dd["time"]) * float(dash_feel()["time"])
	m.fx.burst(h.pos, col_of(dd), 12, 3.0, 0.4, 8.0)
	return true

func _surface() -> void:
	var dd := dash_def()
	m.fx.ring(h.pos, float(dd["radius"]), col_of(dd), 0.4)
	m.fx.burst(h.pos + Vector3(0, 0.3, 0), col_of(dd), 22, 5.0, 0.5, 10.0)
	m.sfx("whoosh", h.pos, -3.0, 0.8)
	for f in foes_in(h.pos, float(dd["radius"])):
		var o := {"lift": float(dd["lift"]), "stun": float(dd["knockup"]), "dr": true, "src": "abil", "ab": "dodge"}
		o["tags"] = ["dodge", "surface"]
		f.hurt(float(dd["dmg"]) * power("dash"), h, o)

# ------------------------------------------------------------------ E: Riptide
func cast_e() -> bool:
	if spin_t >= 0.0 or not wave.is_empty():
		return false
	spin_t = 0.0
	spin_tick = 0.0
	e_t = float(e_def()["spin_t"])
	return true

func e_recastable() -> bool:
	return spin_t >= 0.0

func e_recast() -> bool:
	if spin_t < 0.0:
		return false
	if spin_t >= 0.12:
		_release_spout()
	return true

func _e_end() -> void:
	if spin_t >= 0.0:
		_release_spout()

func move_k() -> float:
	return float(e_def().get("move_k", 0.7)) if spin_t >= 0.0 else 1.0

func _spin_k() -> float:
	return clampf(spin_t / float(e_def()["spin_t"]), 0.0, 1.0)

func _tick_spin(dt: float) -> void:
	var ed := e_def()
	spin_t += dt
	spin_tick -= dt
	if spin_tick > 0.0:
		return
	spin_tick = float(ed["every"])
	var k := _spin_k()
	var r := float(ed["spin_r"])
	m.fx.slash(h.pos + Vector3(0, 0.8, 0), m.time * 12.0, TAU, r, col_of(ed), k > 0.6)
	m.sfx("swipe", h.pos, -6.0, 0.9 + k * 0.7)
	for f in foes_in(h.pos, r):
		var dmg := lerpf(float(ed["tick"][0]), float(ed["tick"][1]), k) * power("kin")
		f.hurt(dmg, h, {"src": "abil", "ab": "k1", "tags": ["k1", "riptide"]})

func _release_spout() -> void:
	var ed := e_def()
	var k := _spin_k()
	spin_t = -1.0
	e_t = 0.0
	var dir := h.aim_dir()
	var length := lerpf(float(ed["range"][0]), float(ed["range"][1]), k)
	var w := lerpf(float(ed["width"][0]), float(ed["width"][1]), k)
	var spd := lerpf(float(ed["speed"][0]), float(ed["speed"][1]), k)
	tele_lane(h.pos, dir, length, w, col_of(ed), length / spd)
	spouts.append({"p": Vector2(h.pos.x, h.pos.z), "y": h.pos.y, "dir": dir, "left": length, "w": w, "spd": spd,
		"hit": {}, "lift": float(ed["lift"]), "stun": float(ed["knockup"]), "dmg": float(ed["dmg"]) * power("kin"),
		"col": col_of(ed), "ab": "k1"})
	m.sfx("whoosh", h.pos, -2.0, 0.7)

## Moves spouts and the wave down their lines; each foe is hit once.
func _tick_lines(list: Array, dt: float) -> void:
	for s in list.duplicate():
		var step := float(s["spd"]) * dt
		s["p"] = (s["p"] as Vector2) + (s["dir"] as Vector2) * step
		s["left"] = float(s["left"]) - step
		var at := Vector3(s["p"].x, float(s["y"]), s["p"].y)
		m.fx.burst(at + Vector3(0, 0.5, 0), s["col"], 3, 3.0, 0.4, -2.0)
		for f in foes_in(at, float(s["w"]) * 0.5 + 0.3, 3.0):
			var key: int = f.get_instance_id()
			if s["hit"].has(key): continue
			s["hit"][key] = true
			var o := {"lift": float(s["lift"]), "stun": float(s["stun"]), "dr": true, "src": "abil", "ab": s["ab"]}
			o["tags"] = [s["ab"], "gil_line"]
			if s.has("slow"):
				o["slow"] = float(s["stun"]) + float(s["slow"])
				o["slow_k"] = float(s["slow_k"])
			f.hurt(float(s["dmg"]), h, o)
			if s["ab"] == "ult": HeroUlt.landed(self, f)
		if float(s["left"]) <= 0.0:
			list.erase(s)

# ------------------------------------------------------------------ X: Tidal Wave
func cast_ult() -> bool:
	return HeroUlt.press(self, _start_wave)

func has_ult() -> bool:
	return true

func ult_running() -> bool:
	return untarget_t > 0.0

func _start_wave() -> bool:
	if spin_t >= 0.0: _release_spout()
	var xd := x_def()
	var dir := h.aim_dir()
	var t := float(xd["time"])
	var length := float(xd["range"])
	untarget_t = t
	tele_lane(h.pos, dir, length, float(xd["width"]), col_of(xd), 0.0)
	wave = {"p": Vector2(h.pos.x, h.pos.z) - dir * 0.5, "y": h.pos.y, "dir": dir, "left": length + 0.5,
		"w": float(xd["width"]), "spd": length / t, "hit": {}, "lift": float(xd["lift"]), "stun": float(xd["knockup"]),
		"slow": float(xd["slow"]), "slow_k": float(xd["slow_k"]),
		"dmg": float(xd["dmg"]) * power("ult"), "col": col_of(xd), "ab": "ult"}
	var ctx := {"slot": "ult", "ability": "tidal_wave", "level": rank("ult")}
	Effects.run([{"type": "dash", "speed": length / t, "time": t, "invuln": t}], h, ctx)
	m.sfx("whoosh", h.pos, 0.0, 0.6)
	return true

func _land_wave() -> void:
	var xd := x_def()
	h.shield = maxf(h.shield, float(xd["shield"]))
	h.shield_t = maxf(h.shield_t, float(xd["shield_t"]))
	m.fx.ring(h.pos, 2.0, col_of(xd), 0.4)
	m.fx.burst(h.pos + Vector3(0, 0.4, 0), col_of(xd), 24, 5.0, 0.5, 10.0)

func incoming(_by: Ent, dmg: float, o: Dictionary) -> Array:
	if untarget_t > 0.0:
		return [0.0, o]
	return [dmg, o]

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	for it in flying.duplicate():
		it["left"] = float(it["left"]) - dt
		var k := 1.0 - clampf(float(it["left"]) / maxf(0.01, float(it["t"])), 0.0, 1.0)
		var p: Vector3 = (it["from"] as Vector3).lerp(it["at"], k) + Vector3(0, sin(k * PI) * 2.0, 0)
		m.fx.burst(p, col_of(vial_def(String(it["v"]))), 1, 0.3, 0.25, 0.0)
		if float(it["left"]) <= 0.0:
			flying.erase(it)
			_shatter(it)
	for pd in puddles.duplicate():
		pd["left"] = float(pd["left"]) - dt
		pd["tick"] = float(pd["tick"]) - dt
		if float(pd["tick"]) <= 0.0:
			pd["tick"] = 0.25
			m.fx.ring(pd["at"], float(pd["r"]), Color("#7be05a", 0.5), 0.26)
			for f in foes_in(pd["at"], float(pd["r"])):
				f.slow_k = maxf(f.slow_k, float(pd["k"])) if f.slow_t > 0.0 else float(pd["k"])
				f.slow_t = maxf(f.slow_t, 0.35)
		if float(pd["left"]) <= 0.0:
			puddles.erase(pd)
	if swim_t > 0.0:
		swim_t -= dt
		m.fx.burst(ground(h.pos) + Vector3(0, 0.1, 0), col_of(dash_def()), 2, 1.5, 0.3, 4.0)
		if swim_t <= 0.0:
			_surface()
	if spin_t >= 0.0:
		_tick_spin(dt)
	_tick_lines(spouts, dt)
	if not wave.is_empty():
		var one := [wave]
		_tick_lines(one, dt)
		untarget_t -= dt
		if one.is_empty() or untarget_t <= 0.0:
			wave = {}
			untarget_t = 0.0
			_land_wave()
	# the next potion glows in his hand
	glow_t -= dt
	if glow_t <= 0.0 and not h.unseen and h.visible and not h.out:
		glow_t = 0.3
		var fw := h.aim_dir()
		var side := Vector2(-fw.y, fw.x)
		m.fx.burst(h.pos + Vector3(side.x * 0.35, 1.0, side.y * 0.35), col_of(vial_def(next_vial())), 1, 0.2, 0.3, 0.0)

func _drop_holds() -> void:
	spin_t = -1.0

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if HeroUlt.ready(self) and los and dist < float(x_def()["range"]) * 0.6:
		h.inp["aim"] = tgt.pos          # the wave rolls along the aim
		HunterKeys.ult_pressed(h)
		return
	if spin_t >= 0.0:
		if spin_t > 1.2 or dist > 3.5: use_e()
		return
	if float(cd["e"]) <= 0.0 and dist < 2.8:
		use_e()
	elif rmb_ready() and los and dist < float(rmb_def()["range"]) + 1.0:
		press_rmb()
