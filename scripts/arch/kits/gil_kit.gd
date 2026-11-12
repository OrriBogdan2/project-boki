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
var puddles: Array = []             # slime puddles: {at, r, t, left, k, tick, node, rim, inside}
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
var lmb_t := -1.0                  # s the Tide Lunge has been charging (-1: not)
var lmb_was := false
var lmb_buf := 0.0                 # s a click still waits to thrust
var press_at := -9.0               # when the attack key went down
var tide := {}                     # the Tide Lunge under way: {left, dir, hit, full, dmg}

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

# ------------------------------------------------------------------ LMB: Fencer / Tide Lunge
const THRUSTS := ["gil_thrust_1", "gil_thrust_2", "gil_lunge"]   # KMovesGil, one per chain step
const BUFFER := 0.2             # s a click during a thrust's recovery waits to thrust next

## Each click thrusts (no auto-repeat for a player: holding is the Tide Lunge). Kept held past lmb.tide.after
## the press, he draws back into the Tide Lunge and lets it go on release. Bots keep the held chain.
func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "swordfish" or KinMerge.active(h):
		_drop_tide()
		return false
	var pressed := held and not lmb_was
	lmb_was = held
	if lmb_t >= 0.0:
		if not h.can_fire(): _drop_tide()
		elif held: _tide_tick(dt)
		else: _tide_lunge()
		return true
	if pressed:
		lmb_buf = BUFFER
		press_at = m.time
	lmb_buf -= dt
	var bot := h.ctrl != "local"
	if not h.can_fire():
		return true
	if h.fire_cd <= 0.0 and (lmb_buf > 0.0 or (bot and held)):
		lmb_buf = 0.0
		_thrust()
	elif held and not bot and m.time - press_at >= float(lmb_def()["tide"]["after"]):
		lmb_t = 0.0
		play("gil_tide_wind")
		vfx("tide_wind", h.pos)
	return true

func _thrust() -> void:
	var ld := lmb_def()
	if m.time - combo_at > float(ld["chain_reset"]): combo_n = 0
	var i := combo_n % 3
	combo_at = m.time
	combo_n += 1
	h.combo_i = i + 1
	h._lunge(float(ld["step"][i]))
	if i == 2: third_until = m.time + 0.3
	var how := {"heavy": i == 2, "own_look": true}
	h._strike(float(ld["dmg"][i]), float(ld["reach"][i]), float(ld["arc"][i]), float(ld["kb"]), how)
	h.fire_cd = float(ld["rate"]) * (1.5 if i == 2 else 1.0)
	play(THRUSTS[i])
	var o := {"len": float(ld["reach"][i]), "k": float(i)}      # k 1: the second thrust's own sound
	if i == 2: vfx("lunge", h.pos, h.aim_dir(), o)
	else: vfx("thrust", h.pos, h.aim_dir(), o)

func tide_k() -> float:
	var td: Dictionary = lmb_def()["tide"]
	return clampf(lmb_t / float(td["full"]), 0.0, 1.0)

## Charging: slowed, the point drawn back, water gathering on the bill; the lane shows how far he will go.
func _tide_tick(dt: float) -> void:
	var was := tide_k()
	lmb_t += dt
	var k := tide_k()
	var td: Dictionary = lmb_def()["tide"]
	var reach := float(td["reach"])
	AimKit.lane(h, "lmb", {"len": float(td["dist"][1]) + reach, "len0": float(td["dist"][0]) + reach,
			"width": float(td["w"]), "k": k, "fill": k, "col": col_of(lmb_def()), "col_full": res_col()})
	AimKit.charge(h, k, {"col": col_of(lmb_def()), "col2": res_col()})
	HeroVfx.of(m).hold(h, "tide_charge", k)
	if k >= 1.0 and was < 1.0:
		vfx("tide_full", h.pos)

## Let go: he drives down the lane behind the point; everyone along it is hit once as he passes.
func _tide_lunge() -> void:
	var td: Dictionary = lmb_def()["tide"]
	var k := tide_k()
	var full := k >= 1.0
	lmb_t = -1.0
	var dir := h.aim_dir()
	var dist := lerpf(float(td["dist"][0]), float(td["dist"][1]), k)
	var t := float(td["time"])
	Effects.run([{"type": "dash", "speed": dist / t, "time": t, "dir": dir, "invuln": 0.0}], h,
			{"slot": "primary", "ability": "tide_lunge", "level": 1})
	tide = {"left": t + 0.05, "dir": dir, "hit": {}, "full": full,
			"dmg": lerpf(float(td["dmg"][0]), float(td["dmg"][1]), k)}
	h.fire_cd = float(td["cd"])
	combo_n = 0
	play("gil_tide_lunge")
	vfx("tide_lunge", h.pos, dir, {"len": dist + float(td["reach"]), "full": full, "k": k})
	CombatBus.ability_used.emit(h, "tide_lunge", "primary")

func _tick_tide(dt: float) -> void:
	tide["left"] = float(tide["left"]) - dt
	var td: Dictionary = lmb_def()["tide"]
	var dir: Vector2 = tide["dir"]
	var tip := h.pos + Vector3(dir.x, 0, dir.y) * float(td["reach"]) * 0.5
	for f in foes_in(tip, float(td["reach"]) * 0.5 + float(td["w"]) * 0.5, 2.5):
		var key: int = f.get_instance_id()
		if tide["hit"].has(key): continue
		tide["hit"][key] = true
		var o := {"kb": dir * float(td["kb"]), "src": "abil", "ab": "primary", "tags": ["primary", "tide"]}
		f.hurt(float(tide["dmg"]), h, o)
		vfx("tide_hit", f.pos, dir, {"full": tide["full"]})
		if tide["full"]:
			_mark(f, String(td["mark"]), col_of(lmb_def()))
	if float(tide["left"]) <= 0.0:
		tide = {}

func _drop_tide() -> void:
	lmb_t = -1.0
	lmb_was = false
	if anim_id == "gil_tide_wind": anim_id = ""

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	# the thrust's rays reach on_deal as "shot" hits (Gil's only shots; the vials are "abil"), once a foe a thrust
	if String(o.get("src", "")) != "shot" or t == null:
		return
	if m.time >= third_until:
		vfx("thrust_hit", t.pos, h.aim_dir())
		return
	vfx("lunge_hit", t.pos, h.aim_dir())
	if not t.dead:
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
	flying.append({"at": at, "from": HeroVfx.of(m).anchor_pos(h, "hand_l"), "t": ft, "left": ft, "v": v})
	play("gil_throw")
	vfx("throw", h.pos)

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
	_shatter_look(v, at, r)
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
		_add_puddle(at, vd)

## Each bottle breaks in its own look (content/vfx/gil.json shatter_<vial>, sized to its circle).
func _shatter_look(v: String, at: Vector3, r: float) -> void:
	var dir := h.aim_dir()
	match v:
		"thunder": vfx("shatter_thunder", at, dir, {"r": r})
		"slime": vfx("shatter_slime", at, dir, {"r": r})
		"air": vfx("shatter_air", at, dir, {"r": r})
		"fire": vfx("shatter_fire", at, dir, {"r": r})
		_: vfx("shatter_zeep", at, dir, {"r": r})

const PUDDLE_PEAK := 0.05       # s the puddle's rim holds its white flare as it lands (3 frames at 60 fps)
const PUDDLE_SETTLE := 0.25     # s from landing to its steady glow (the flare eases out)
const PUDDLE_FADE := 0.4        # s it fades on an ease-out curve before its slow ends
const PUDDLE_FLARE := 0.6       # how far toward white the rim flares as it lands
const PUDDLE_RIM := 0.06        # share of the radius the lit rim takes
const PUDDLE_RIM_A := 0.85      # the rim's steady alpha
const PUDDLE_IN_A := 0.8        # the inside's alpha: the ring shader's wash tops out at 0.3 of it (0.24 by the rim)

## The slime's puddle slows whoever stands in it for puddle_t. It is drawn for exactly that long and on its radius:
## Gil's lit rim over a faint inside in the slime's colour (the wash: clear at the centre, rising toward the rim).
func _add_puddle(at: Vector3, vd: Dictionary) -> void:
	var r := float(vd["puddle_r"])
	var n := Node3D.new()
	var quad := Models.flat_quad(r * 2.0)
	var inside := Models.ring_mat(Color(col_of(vd), PUDDLE_IN_A), 0.0)
	inside.set_shader_parameter("wash", 1.0)
	var rim := Models.ring_mat(Arch.color(h.arch), PUDDLE_RIM)
	rim.set_shader_parameter("halo", 1.0)
	Models.part(n, quad, inside, Vector3(0, 0.06, 0))
	Models.part(n, quad, rim, Vector3(0, 0.08, 0))
	ShadowPolicy.off(n)
	m.add_child(n)
	n.global_position = at
	puddles.append({"at": at, "r": r, "t": float(vd["puddle_t"]), "left": float(vd["puddle_t"]),
		"k": float(vd["puddle_k"]), "tick": 0.0, "node": n, "rim": rim, "inside": inside})

## The puddle's glow now: the rim's flare as it lands, then steady, then the ease-out fade as it dries.
func _puddle_look(pd: Dictionary) -> void:
	var left := float(pd["left"])
	var age := float(pd["t"]) - left
	if age > PUDDLE_SETTLE and left > PUDDLE_FADE:
		return
	var flare := pow(1.0 - clampf((age - PUDDLE_PEAK) / (PUDDLE_SETTLE - PUDDLE_PEAK), 0.0, 1.0), 2.0)
	var fade := pow(clampf(left / PUDDLE_FADE, 0.0, 1.0), 2.0)
	var sig := Arch.color(h.arch)
	(pd["rim"] as ShaderMaterial).set_shader_parameter("color",
		Color(sig.lerp(Color.WHITE, PUDDLE_FLARE * flare), lerpf(PUDDLE_RIM_A, 1.0, flare) * fade))
	var inside: ShaderMaterial = pd["inside"]
	inside.set_shader_parameter("color", Color(inside.get_shader_parameter("color"), PUDDLE_IN_A * fade))

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
		vfx("beached", f.pos)
	else:
		m.fx.word(f.pos + Vector3(0, 2.2, 0), "%d/%d" % [mini(n, 3), int(pd.get("need", 3))], col)
		vfx("mark", f.pos)

## Different marks on a foe right now (tests and the HUD).
func marks_on(f: Ent) -> int:
	var pd: Dictionary = d.get("passive", {})
	var n := 0
	for k in marks.get(f.get_instance_id(), {}):
		if m.time - float(marks[f.get_instance_id()][k]) <= float(pd.get("window", 5.0)): n += 1
	return n

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
	swim_t = float(dd["time"]) * float(dash_feel()["time"])      # (before the dash: own_dash_trail reads it)
	travel(float(dd["dist"]), float(dd["time"]))
	# head first into the ground: the body goes fully under (gil_dive) and only the wake shows on top
	play("gil_dive")
	vfx("dive", h.pos, h.roll_dir, {"len": h.roll_speed * h.roll_t})
	return true

## Under the ground there is no body to leave after-images: the wake is the trail.
func own_dash_trail() -> bool:
	return swim_t > 0.0

func _surface() -> void:
	var dd := dash_def()
	play("gil_surface")
	vfx("surface", h.pos, h.aim_dir(), {"r": float(dd["radius"])})
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
	play("gil_spin")
	return true

func e_recastable() -> bool:
	return spin_t >= 0.0

## The spin's window for RecastCue: the ring runs over the whole spin, and at its end the spout goes by itself.
func recast_window() -> Dictionary:
	if spin_t < 0.0:
		return {}
	return RecastCue.window("e", e_t, float(e_def()["spin_t"]), h.pos, true, true)

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
	if spin_t >= 0.0:
		return float(e_def().get("move_k", 0.7))
	return float(lmb_def()["tide"]["walk_k"]) if lmb_t >= 0.0 else 1.0

func _spin_k() -> float:
	return clampf(spin_t / float(e_def()["spin_t"]), 0.0, 1.0)

func _tick_spin(dt: float) -> void:
	var ed := e_def()
	spin_t += dt
	HeroVfx.of(m).hold(h, "spin_spray", _spin_k())
	spin_tick -= dt
	if spin_tick > 0.0:
		return
	spin_tick = float(ed["every"])
	var k := _spin_k()
	var r := float(ed["spin_r"])
	vfx("spin", h.pos, h.aim_dir(), {"r": r, "k": k})
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
		"ab": "k1", "fx_t": 0.0})
	play("gil_spout")
	vfx("spout", h.pos, dir, {"len": length, "w": w, "k": k})

## Moves spouts and the wave down their lines; each foe is hit once.
func _tick_lines(list: Array, dt: float) -> void:
	for s in list.duplicate():
		var step := float(s["spd"]) * dt
		s["p"] = (s["p"] as Vector2) + (s["dir"] as Vector2) * step
		s["left"] = float(s["left"]) - step
		var at := Vector3(s["p"].x, float(s["y"]), s["p"].y)
		_line_look(s, at, dt)
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

## The moving head of a spout or the wave's crest, every LINE_FX_DT (local: the cast's own look carries the
## line for other games).
const LINE_FX_DT := 0.06
func _line_look(s: Dictionary, at: Vector3, dt: float) -> void:
	s["fx_t"] = float(s["fx_t"]) - dt
	if float(s["fx_t"]) > 0.0:
		return
	s["fx_t"] = LINE_FX_DT
	if s["ab"] == "ult": vfx("wave_crest", at, s["dir"], {"w": s["w"]})
	else: vfx("spout_col", at, s["dir"], {"w": s["w"]})

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
		"dmg": float(xd["dmg"]) * power("ult"), "ab": "ult", "fx_t": 0.0}
	var ctx := {"slot": "ult", "ability": "tidal_wave", "level": rank("ult")}
	# along the wave's own line: a bare dash steers by the move keys, so a moving cast surfed off the wave
	Effects.run([{"type": "dash", "speed": length / t, "time": t, "invuln": t, "dir": dir}], h, ctx)
	play("gil_surf")
	vfx("wave", h.pos, dir, {"len": length, "w": float(xd["width"])})
	return true

func _land_wave() -> void:
	var xd := x_def()
	h.shield = maxf(h.shield, float(xd["shield"]))
	h.shield_t = maxf(h.shield_t, float(xd["shield_t"]))
	play("gil_land")
	vfx("wave_land", h.pos)

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
			for f in foes_in(pd["at"], float(pd["r"])):
				f.slow_k = maxf(f.slow_k, float(pd["k"])) if f.slow_t > 0.0 else float(pd["k"])
				f.slow_t = maxf(f.slow_t, 0.35)
		if float(pd["left"]) <= 0.0:
			(pd["node"] as Node3D).queue_free()
			puddles.erase(pd)
		else:
			_puddle_look(pd)
	if swim_t > 0.0:
		swim_t -= dt
		if swim_t <= 0.0:
			_surface()
	_end_stale_hold()
	if spin_t >= 0.0:
		_tick_spin(dt)
	if not tide.is_empty():
		_tick_tide(dt)
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
		m.fx.burst(HeroVfx.of(m).anchor_pos(h, "hand_l"), col_of(vial_def(next_vial())), 1, 0.2, 0.3, 0.0)

func _drop_holds() -> void:
	spin_t = -1.0
	_drop_tide()
	_end_stale_hold()

## The held poses (under the ground, spinning, on the wave) stay on until their move replaces them; one whose
## move was cut short (a merge, a death) lets go here.
func _end_stale_hold() -> void:
	var stale := false
	match anim_id:
		"gil_dive": stale = swim_t <= 0.0
		"gil_spin": stale = spin_t < 0.0
		"gil_surf": stale = wave.is_empty()
	if stale:
		anim_id = ""

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
